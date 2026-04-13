import * as path from "path";
import { config as loadEnv } from "dotenv";

// Carga `functions/.env` (gitignored). En deploy, Firebase también inyecta estas variables.
loadEnv({ path: path.resolve(__dirname, "../.env") });

import * as admin from "firebase-admin";
import { createHash } from "crypto";
import * as functionsV1 from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import Stripe from "stripe";

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

/** HttpsError de 1st gen: la callable `folioCloudAiComplete` corre en CF 1st gen (no Cloud Run). */
const AiHttpsError = functionsV1.https.HttpsError;

/** Suscripción Folio Cloud: 500 gotas/mes (recarga día 1 + alta). */
const MONTHLY_INK_ALLOWANCE = 500;
const INK_TIMEZONE = "Europe/Madrid";

/** Coste base por tipo de operación (cliente envía `operationKind`; desconocidos → `default`). */
const INK_COST_BY_OPERATION: Record<string, number> = {
  rewrite_block: 1,
  summarize_selection: 1,
  extract_tasks: 2,
  summarize_page: 2,
  generate_insert: 3,
  generate_page: 5,
  chat_turn: 2,
  agent_main: 6,
  agent_followup: 3,
  edit_page_panel: 3,
  transcribe_cloud: 1,
  default: 2,
};

/** Tope de gotas cobradas en una sola callable (anti-abuso). */
const INK_MAX_PER_REQUEST = 16;
/** Si el prompt supera esta longitud, se suma [INK_EXTRA_FOR_LONG_PROMPT]. */
const INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD = 32000;
const INK_EXTRA_FOR_LONG_PROMPT = 2;

/** Tras OpenAI, cargo extra por volumen de tokens (`usage.total_tokens`). */
const INK_TOKENS_PER_SURCHARGE_UNIT = 6000;
const INK_MAX_TOKEN_SURCHARGE = 10;

function stripeSecret(): string {
  return process.env.STRIPE_SECRET_KEY?.trim() ?? "";
}

function webhookSecret(): string {
  return process.env.STRIPE_WEBHOOK_SECRET?.trim() ?? "";
}

function openAiApiKey(): string {
  return process.env.OPENAI_API_KEY?.trim() ?? "";
}

function openAiBaseUrl(): string {
  return (
    process.env.OPENAI_BASE_URL?.trim() || "https://api.openai.com/v1"
  ).replace(/\/+$/, "");
}

function openAiModel(): string {
  return process.env.OPENAI_MODEL?.trim() || "gpt-4o-mini";
}

function openAiMaxOutputTokens(): number {
  const raw = process.env.OPENAI_MAX_OUTPUT_TOKENS?.trim();
  if (!raw) return 8192;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1) return 8192;
  return Math.min(16384, Math.trunc(n));
}

function openAiTemperature(): number {
  const raw = process.env.OPENAI_TEMPERATURE?.trim();
  if (!raw) return 0.7;
  const n = Number(raw);
  if (!Number.isFinite(n)) return 0.7;
  return Math.min(2, Math.max(0, n));
}

const OPENAI_MAX_429_RETRIES = 3;
const OPENAI_MAX_SPIN_GUARD = 8;

function openAiChatCompletionsUrl(): string {
  return `${openAiBaseUrl()}/chat/completions`;
}

function parseOpenAiApiErrorMessage(raw: string): string {
  try {
    const errBody = JSON.parse(raw) as {
      error?: { message?: string };
    };
    return (errBody.error?.message ?? "").trim();
  } catch {
    return "";
  }
}

async function sleepMs(ms: number): Promise<void> {
  await new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function openAiFetchChatCompletion(
  apiKey: string,
  body: Record<string, unknown>
): Promise<{ status: number; raw: string }> {
  const url = openAiChatCompletionsUrl();
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  return { status: res.status, raw };
}

function throwOpenAiHttpError(status: number, raw: string): never {
  const openAiMsg = parseOpenAiApiErrorMessage(raw);
  console.error("OpenAI HTTP error", status, raw.slice(0, 800));
  const quotaHint =
    "Esto viene de la API de OpenAI (clave, cuota, facturación o modelo), no del saldo de gotas Folio en Firestore. Revisa OPENAI_API_KEY y límites en platform.openai.com.";
  if (status === 401 || status === 403 || status === 429) {
    throw new AiHttpsError(
      "failed-precondition",
      openAiMsg ? `${openAiMsg} ${quotaHint}` : quotaHint
    );
  }
  if (status === 400 || status === 404) {
    const hint =
      status === 404
        ? " Comprueba OPENAI_MODEL y OPENAI_BASE_URL."
        : "";
    throw new AiHttpsError(
      "failed-precondition",
      (openAiMsg || `OpenAI API HTTP ${status}`) + hint
    );
  }
  throw new AiHttpsError(
    "internal",
    openAiMsg || "AI provider returned an error. Try again later."
  );
}

function resolveInkCost(operationKind: string, promptLength: number): number {
  const base =
    INK_COST_BY_OPERATION[operationKind] ?? INK_COST_BY_OPERATION.default;
  let cost = base;
  if (promptLength > INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD) {
    cost += INK_EXTRA_FOR_LONG_PROMPT;
  }
  return Math.min(cost, INK_MAX_PER_REQUEST);
}

/**
 * Devuelve a la app la tabla vigente de costes de tinta.
 * Asi los cambios se mantienen en un solo sitio: backend.
 */
export const folioCloudAiPricing = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    return {
      costByOperation: INK_COST_BY_OPERATION,
      inkMaxPerRequest: INK_MAX_PER_REQUEST,
      promptLengthSurchargeThreshold: INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD,
      extraForLongPrompt: INK_EXTRA_FOR_LONG_PROMPT,
      tokensPerSurchargeUnit: INK_TOKENS_PER_SURCHARGE_UNIT,
      maxTokenSurcharge: INK_MAX_TOKEN_SURCHARGE,
    };
  }
);

function debitInkBalances(
  monthly: number,
  purchased: number,
  cost: number
): { monthly: number; purchased: number } {
  if (cost <= 0) return { monthly, purchased };
  if (monthly >= cost) {
    return { monthly: monthly - cost, purchased };
  }
  return { monthly: 0, purchased: purchased - (cost - monthly) };
}

/**
 * Lee gotas desde Firestore: entero ≥ 0 por campo.
 * Evita que un saldo negativo en un solo campo haga que la suma real sea < 0 mientras la app
 * (FolioInkSnapshot) muestra solo el otro campo positivo y parece haber tinta.
 */
function inkBalanceField(v: unknown): number {
  if (typeof v === "number" && Number.isFinite(v)) {
    return Math.max(0, Math.trunc(v));
  }
  if (typeof v === "string") {
    const t = v.trim();
    if (t.length === 0) return 0;
    const n = Number(t);
    if (Number.isFinite(n)) return Math.max(0, Math.trunc(n));
  }
  return 0;
}

function readInkBalances(data: Record<string, unknown>): {
  monthly: number;
  purchased: number;
} {
  // Forma esperada: `ink` es un mapa {monthlyBalance, purchasedBalance, ...}.
  // En algunos despliegues antiguos/datos corruptos, los campos pueden existir como
  // claves literales con punto: "ink.monthlyBalance". Soportamos ambos para no
  // bloquear IA/backup por un detalle de forma.
  const ink = (data.ink as Record<string, unknown>) ?? {};

  const monthly =
    inkBalanceField(ink.monthlyBalance) ||
    inkBalanceField(data["ink.monthlyBalance"]);
  const purchased =
    inkBalanceField(ink.purchasedBalance) ||
    inkBalanceField(data["ink.purchasedBalance"]);

  return { monthly, purchased };
}

function tokenSurchargeInk(totalTokenCount: number | undefined): number {
  if (totalTokenCount == null || totalTokenCount <= 0) return 0;
  return Math.min(
    INK_MAX_TOKEN_SURCHARGE,
    Math.floor(totalTokenCount / INK_TOKENS_PER_SURCHARGE_UNIT)
  );
}

type OpenAiOkJson = {
  choices?: Array<{
    message?: { content?: string | null };
    finish_reason?: string;
  }>;
  usage?: { total_tokens?: number };
  error?: { message?: string };
};

function parseOpenAiSuccessResponse(raw: string): {
  text: string;
  totalTokenCount?: number;
} {
  let json: OpenAiOkJson;
  try {
    json = JSON.parse(raw) as OpenAiOkJson;
  } catch {
    throw new AiHttpsError("internal", "Invalid AI response");
  }
  if (json.error?.message) {
    console.error("OpenAI API error object", json.error);
    throw new AiHttpsError("internal", "AI provider error");
  }
  const content = json.choices?.[0]?.message?.content;
  const text = typeof content === "string" ? content : "";
  if (!text.trim()) {
    const reason = json.choices?.[0]?.finish_reason;
    console.warn("OpenAI empty output", { reason });
    const hint =
      reason === "content_filter"
        ? " (contenido filtrado por políticas del proveedor)"
        : "";
    throw new AiHttpsError(
      "internal",
      `Empty AI response. Try a shorter prompt.${hint}`
    );
  }
  const totalTokenCount =
    typeof json.usage?.total_tokens === "number"
      ? json.usage.total_tokens
      : undefined;
  return { text: text.trim(), totalTokenCount };
}

/**
 * Inferencia vía OpenAI Chat Completions (o API compatible: mismo path y cuerpo).
 */
async function callOpenAiGenerate(prompt: string): Promise<{
  text: string;
  totalTokenCount?: number;
}> {
  const key = openAiApiKey();
  if (!key) {
    throw new AiHttpsError(
      "failed-precondition",
      "Server AI not configured (set OPENAI_API_KEY on Cloud Functions)"
    );
  }

  const body: Record<string, unknown> = {
    model: openAiModel(),
    messages: [{ role: "user", content: prompt }],
    max_tokens: openAiMaxOutputTokens(),
    temperature: openAiTemperature(),
  };

  let r429 = 0;
  for (let spin = 0; spin < OPENAI_MAX_SPIN_GUARD; spin++) {
    const { status, raw } = await openAiFetchChatCompletion(key, body);

    if (status === 429 && r429 < OPENAI_MAX_429_RETRIES) {
      r429++;
      await sleepMs(400 * 2 ** (r429 - 1));
      continue;
    }
    if (status === 429) {
      throwOpenAiHttpError(status, raw);
    }
    r429 = 0;

    if (status < 200 || status >= 300) {
      throwOpenAiHttpError(status, raw);
    }

    return parseOpenAiSuccessResponse(raw);
  }

  throw new AiHttpsError(
    "internal",
    "OpenAI request stopped after too many retries. Try again later."
  );
}

type OpenAiChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

function normalizeOpenAiRole(raw: unknown): OpenAiChatMessage["role"] | null {
  const r = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (r === "system" || r === "user" || r === "assistant") return r;
  return null;
}

function normalizeOpenAiMessages(raw: unknown): OpenAiChatMessage[] {
  if (!Array.isArray(raw)) return [];
  const out: OpenAiChatMessage[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const m = item as { role?: unknown; content?: unknown };
    const role = normalizeOpenAiRole(m.role);
    const content = typeof m.content === "string" ? m.content.trim() : "";
    if (!role || !content) continue;
    out.push({ role, content });
  }
  return out;
}

function normalizeOptionalString(raw: unknown, maxLen: number): string {
  const s = typeof raw === "string" ? raw.trim() : "";
  if (!s) return "";
  return s.length <= maxLen ? s : s.slice(0, maxLen);
}

function normalizeOptionalNumber(raw: unknown): number | undefined {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return undefined;
  return raw;
}

function normalizeClientMaxTokens(raw: unknown): number | undefined {
  const n = normalizeOptionalNumber(raw);
  if (n == null) return undefined;
  const t = Math.trunc(n);
  if (t < 1) return undefined;
  return Math.min(openAiMaxOutputTokens(), t);
}

function normalizeClientTemperature(raw: unknown): number | undefined {
  const n = normalizeOptionalNumber(raw);
  if (n == null) return undefined;
  return Math.min(2, Math.max(0, n));
}

function normalizeResponseSchema(raw: unknown): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object") return null;
  if (Array.isArray(raw)) return null;
  // Recortamos profundidad/tamaño más adelante con límites de prompt/ink; aquí también
  // reforzamos compatibilidad con json_schema.strict de OpenAI.
  return enforceStrictObjectSchema(raw as Record<string, unknown>);
}

function enforceStrictObjectSchema(
  node: Record<string, unknown>
): Record<string, unknown> {
  const clone: Record<string, unknown> = { ...node };

  const nodeType = typeof clone.type === "string" ? clone.type : undefined;
  if (nodeType === "object") {
    clone.additionalProperties = false;
  }

  const properties = clone.properties;
  if (properties && typeof properties === "object" && !Array.isArray(properties)) {
    const nextProps: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(properties as Record<string, unknown>)) {
      if (value && typeof value === "object" && !Array.isArray(value)) {
        nextProps[key] = enforceStrictObjectSchema(value as Record<string, unknown>);
      } else {
        nextProps[key] = value;
      }
    }
    clone.properties = nextProps;

    const requiredKeys = Object.keys(nextProps);
    const existingRequired = Array.isArray(clone.required)
      ? clone.required.filter((v): v is string => typeof v === "string")
      : [];
    // En strict json_schema, OpenAI exige que required incluya todas las keys de properties.
    clone.required = Array.from(new Set([...existingRequired, ...requiredKeys]));
  }

  const items = clone.items;
  if (items && typeof items === "object" && !Array.isArray(items)) {
    clone.items = enforceStrictObjectSchema(items as Record<string, unknown>);
  }

  const anyOf = clone.anyOf;
  if (Array.isArray(anyOf)) {
    clone.anyOf = anyOf.map((value) => {
      if (value && typeof value === "object" && !Array.isArray(value)) {
        return enforceStrictObjectSchema(value as Record<string, unknown>);
      }
      return value;
    });
  }

  const oneOf = clone.oneOf;
  if (Array.isArray(oneOf)) {
    clone.oneOf = oneOf.map((value) => {
      if (value && typeof value === "object" && !Array.isArray(value)) {
        return enforceStrictObjectSchema(value as Record<string, unknown>);
      }
      return value;
    });
  }

  const allOf = clone.allOf;
  if (Array.isArray(allOf)) {
    clone.allOf = allOf.map((value) => {
      if (value && typeof value === "object" && !Array.isArray(value)) {
        return enforceStrictObjectSchema(value as Record<string, unknown>);
      }
      return value;
    });
  }

  return clone;
}

async function callOpenAiChatStructured(input: {
  prompt?: string;
  systemPrompt?: string;
  messages?: OpenAiChatMessage[];
  responseSchema?: Record<string, unknown> | null;
  maxTokens?: number;
  temperature?: number;
}): Promise<{ text: string; totalTokenCount?: number }> {
  const key = openAiApiKey();
  if (!key) {
    throw new AiHttpsError(
      "failed-precondition",
      "Server AI not configured (set OPENAI_API_KEY on Cloud Functions)"
    );
  }

  const systemPrompt = (input.systemPrompt ?? "").trim();
  const prompt = (input.prompt ?? "").trim();
  const normalizedMsgs = (input.messages ?? []).filter((m) => m.content.trim());

  const messages: OpenAiChatMessage[] = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  if (normalizedMsgs.length > 0) {
    messages.push(...normalizedMsgs);
  }
  // Asegura que el turno actual del usuario nunca se pierda aunque haya historial.
  if (prompt) {
    messages.push({ role: "user", content: prompt });
  }
  if (messages.length === 0) {
    throw new AiHttpsError("invalid-argument", "Missing prompt/messages");
  }

  const body: Record<string, unknown> = {
    model: openAiModel(),
    messages,
    max_tokens: input.maxTokens ?? openAiMaxOutputTokens(),
    temperature: input.temperature ?? openAiTemperature(),
  };

  const schema = input.responseSchema ?? null;
  if (schema) {
    body.response_format = {
      type: "json_schema",
      json_schema: {
        name: "folio_response",
        schema,
        strict: true,
      },
    };
  }

  let r429 = 0;
  for (let spin = 0; spin < OPENAI_MAX_SPIN_GUARD; spin++) {
    const { status, raw } = await openAiFetchChatCompletion(key, body);

    if (status === 429 && r429 < OPENAI_MAX_429_RETRIES) {
      r429++;
      await sleepMs(400 * 2 ** (r429 - 1));
      continue;
    }
    if (status === 429) {
      throwOpenAiHttpError(status, raw);
    }
    r429 = 0;

    if (status < 200 || status >= 300) {
      throwOpenAiHttpError(status, raw);
    }

    return parseOpenAiSuccessResponse(raw);
  }

  throw new AiHttpsError(
    "internal",
    "OpenAI request stopped after too many retries. Try again later."
  );
}

async function refundInkDropCharge(uid: string, amount: number): Promise<void> {
  if (amount <= 0) return;
  const ref = db.collection("users").doc(uid);
  await ref.set(
    {
      "ink.purchasedBalance": FieldValue.increment(amount),
      "ink.updatedAt": FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function chargeInkExtraIfPossible(
  uid: string,
  extra: number,
  allowSubscriptionInk: boolean
): Promise<number> {
  if (extra <= 0) return 0;
  const ref = db.collection("users").doc(uid);
  let charged = 0;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const { monthly, purchased } = readInkBalances(data);
    const effectiveMonthly = allowSubscriptionInk ? monthly : 0;
    const take = Math.min(extra, effectiveMonthly + purchased);
    if (take <= 0) return;
    const next = debitInkBalances(effectiveMonthly, purchased, take);
    charged = take;
    tx.update(ref, {
      "ink.monthlyBalance": allowSubscriptionInk ? next.monthly : 0,
      "ink.purchasedBalance": next.purchased,
      "ink.updatedAt": FieldValue.serverTimestamp(),
    });
  });
  return charged;
}

function normalizeOperationKind(raw: unknown): string {
  const kindRaw = typeof raw === "string" ? raw.trim() : "";
  if (
    kindRaw.length > 0 &&
    Object.prototype.hasOwnProperty.call(INK_COST_BY_OPERATION, kindRaw)
  ) {
    return kindRaw;
  }
  return "default";
}

function normalizePrompt(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.trim();
}

function promptLengthForInk(input: {
  prompt?: string;
  systemPrompt?: string;
  messages?: OpenAiChatMessage[];
}): number {
  let n = 0;
  const p = (input.prompt ?? "").trim();
  if (p) n += p.length;
  const sp = (input.systemPrompt ?? "").trim();
  if (sp) n += sp.length;
  const msgs = input.messages ?? [];
  for (const m of msgs) {
    if (m?.content) n += String(m.content).length;
  }
  return n;
}

async function runFolioCloudAiForUid(
  uid: string,
  input: {
    prompt?: string;
    systemPrompt?: string;
    messages?: OpenAiChatMessage[];
    responseSchema?: Record<string, unknown> | null;
    maxTokens?: number;
    temperature?: number;
  },
  operationKind: string
): Promise<{
  text: string;
  ink: { monthlyBalance: number; purchasedBalance: number };
  inkCharged: number;
  inkBaseCharged: number;
  inkTokenSurcharge: number;
}> {
  const baseCost = resolveInkCost(operationKind, promptLengthForInk(input));
  const ref = db.collection("users").doc(uid);

  const inkExhaustedMsg =
    "Insufficient ink. Buy an ink pack in Folio Cloud settings, wait for your monthly refill with an active subscription, or switch to a local AI provider (Ollama / LM Studio).";

  let allowSubscriptionInk = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const dataDoc = snap.data() ?? {};
    const fc = dataDoc.folioCloud as Record<string, unknown> | undefined;
    const features = fc?.features as Record<string, unknown> | undefined;
    const hasSubCloudAi =
      fc?.active === true && features?.cloudAi === true;
    allowSubscriptionInk = hasSubCloudAi;

    const { monthly, purchased } = readInkBalances(dataDoc);

    if (hasSubCloudAi) {
      if (monthly + purchased < baseCost) {
        throw new AiHttpsError("resource-exhausted", inkExhaustedMsg);
      }
      const next = debitInkBalances(monthly, purchased, baseCost);
      tx.update(ref, {
        "ink.monthlyBalance": next.monthly,
        "ink.purchasedBalance": next.purchased,
        "ink.updatedAt": FieldValue.serverTimestamp(),
      });
    } else {
      if (purchased < baseCost) {
        throw new AiHttpsError("resource-exhausted", inkExhaustedMsg);
      }
      const next = debitInkBalances(0, purchased, baseCost);
      tx.update(ref, {
        "ink.monthlyBalance": 0,
        "ink.purchasedBalance": next.purchased,
        "ink.updatedAt": FieldValue.serverTimestamp(),
      });
    }
  });

  try {
    const { text, totalTokenCount } = await callOpenAiChatStructured(input);
    const extraWant = tokenSurchargeInk(totalTokenCount);
    const extraCharged = await chargeInkExtraIfPossible(
      uid,
      extraWant,
      allowSubscriptionInk
    );
    const finalSnap = await ref.get();
    const inkOut = readInkBalances(
      (finalSnap.data() ?? {}) as Record<string, unknown>
    );
    return {
      text,
      ink: {
        monthlyBalance: inkOut.monthly,
        purchasedBalance: inkOut.purchased,
      },
      inkCharged: baseCost + extraCharged,
      inkBaseCharged: baseCost,
      inkTokenSurcharge: extraCharged,
    };
  } catch (e: unknown) {
    try {
      await refundInkDropCharge(uid, baseCost);
    } catch (refundErr) {
      console.error("folioCloudAiComplete: refund after AI failure", refundErr);
    }
    throw e;
  }
}

function callableLikeErrorBody(code: string, message: string): {
  error: { status: string; message: string };
} {
  const status = code.replace(/-/g, "_").toUpperCase();
  return {
    error: {
      status,
      message,
    },
  };
}

async function verifiedUidFromBearerToken(
  authHeader: string | undefined
): Promise<string> {
  const raw = (authHeader ?? "").trim();
  const match = raw.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new AiHttpsError("unauthenticated", "Login required");
  }
  const idToken = match[1].trim();
  if (!idToken) {
    throw new AiHttpsError("unauthenticated", "Login required");
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded.uid;
  } catch {
    throw new AiHttpsError("unauthenticated", "Login required");
  }
}

function stripeClient(): Stripe | null {
  const key = stripeSecret();
  if (!key) return null;
  return new Stripe(key, { apiVersion: "2025-02-24.acacia" });
}

/** Convierte errores de Stripe (o genéricos) en mensaje seguro para el cliente callable. */
function stripeCallErrorMessage(err: unknown): string {
  if (err instanceof Error && err.message) {
    return err.message.slice(0, 500);
  }
  if (err && typeof err === "object" && "message" in err) {
    return String((err as { message: string }).message).slice(0, 500);
  }
  return "Unknown error";
}

function priceFolioCloudMonthly(): string {
  return process.env.STRIPE_PRICE_FOLIO_CLOUD_MONTHLY?.trim() ?? "";
}

function priceInkSmall(): string {
  return process.env.STRIPE_PRICE_INK_SMALL?.trim() ?? "";
}

function priceInkMedium(): string {
  return process.env.STRIPE_PRICE_INK_MEDIUM?.trim() ?? "";
}

function priceInkLarge(): string {
  return process.env.STRIPE_PRICE_INK_LARGE?.trim() ?? "";
}

/**
 * Las variables pueden ser `price_...` o `prod_...`. Checkout necesita un Price;
 * si pasas un producto, se usa su precio por defecto (Dashboard → producto → precio por defecto).
 */
async function resolveCatalogIdToPriceId(
  stripe: Stripe,
  raw: string
): Promise<string> {
  const id = raw.trim();
  if (!id) {
    throw new HttpsError("failed-precondition", "Empty Stripe catalog id");
  }
  if (id.startsWith("price_")) {
    return id;
  }
  if (id.startsWith("prod_")) {
    const product = await stripe.products.retrieve(id);
    const dp = product.default_price;
    if (!dp) {
      throw new HttpsError(
        "failed-precondition",
        `Stripe product ${id} has no default price. Open the product in the Dashboard and set a default price.`
      );
    }
    return typeof dp === "string" ? dp : dp.id;
  }
  throw new HttpsError(
    "failed-precondition",
    `Invalid Stripe catalog id (use price_... or prod_...): ${id}`
  );
}

/** Comprueba si el price id real de Stripe coincide con la variable (price o product). */
async function catalogMatchesPrice(
  stripe: Stripe,
  envCatalogId: string,
  actualPriceId: string | undefined
): Promise<boolean> {
  if (!actualPriceId || !envCatalogId.trim()) return false;
  const env = envCatalogId.trim();
  if (env.startsWith("price_")) {
    return env === actualPriceId;
  }
  if (env.startsWith("prod_")) {
    const price = await stripe.prices.retrieve(actualPriceId);
    const prod = price.product;
    const prodId = typeof prod === "string" ? prod : prod?.id;
    return prodId === env;
  }
  return false;
}

/** @deprecated usar STRIPE_PRICE_FOLIO_CLOUD_MONTHLY */
function stripePriceIdsLegacy(): string[] {
  const raw = process.env.STRIPE_PRICE_IDS_FOLIO_CLOUD?.trim() ?? "";
  if (!raw) return [];
  return raw.split(",").map((s) => s.trim()).filter(Boolean);
}

async function isMonthlySubscriptionPrice(
  stripe: Stripe,
  priceId: string | undefined
): Promise<boolean> {
  if (!priceId) return false;
  const explicit = priceFolioCloudMonthly();
  if (explicit) {
    return catalogMatchesPrice(stripe, explicit, priceId);
  }
  const legacy = stripePriceIdsLegacy();
  return legacy.length > 0 && legacy.includes(priceId);
}

async function folioCloudFeaturesFromPriceId(
  stripe: Stripe,
  priceId: string | undefined
): Promise<{
  backup: boolean;
  cloudAi: boolean;
  publishWeb: boolean;
  realtimeCollab: boolean;
}> {
  if (await isMonthlySubscriptionPrice(stripe, priceId)) {
    return {
      backup: true,
      cloudAi: true,
      publishWeb: true,
      realtimeCollab: true,
    };
  }
  const legacy = stripePriceIdsLegacy();
  const explicitMonthly = priceFolioCloudMonthly().trim();
  if (explicitMonthly.length > 0) {
    return {
      backup: false,
      cloudAi: false,
      publishWeb: false,
      realtimeCollab: false,
    };
  }
  if (!priceId || legacy.length === 0) {
    return {
      backup: true,
      cloudAi: true,
      publishWeb: true,
      realtimeCollab: true,
    };
  }
  const active = legacy.includes(priceId);
  return {
    backup: active,
    cloudAi: active,
    publishWeb: active,
    realtimeCollab: active,
  };
}

async function inkDropsForPriceId(
  stripe: Stripe,
  priceId: string | undefined
): Promise<number> {
  if (!priceId) return 0;
  const small = priceInkSmall();
  const med = priceInkMedium();
  const large = priceInkLarge();
  if (small && (await catalogMatchesPrice(stripe, small, priceId))) return 300;
  if (med && (await catalogMatchesPrice(stripe, med, priceId))) return 1000;
  if (large && (await catalogMatchesPrice(stripe, large, priceId))) return 2500;
  return 0;
}

function monthPeriodKeyEuropeMadrid(d = new Date()): string {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: INK_TIMEZONE,
    year: "numeric",
    month: "2-digit",
  });
  const parts = fmt.formatToParts(d);
  const y = parts.find((p) => p.type === "year")?.value ?? "1970";
  const m = parts.find((p) => p.type === "month")?.value ?? "01";
  return `${y}-${m}`;
}

async function syncSubscriptionToUser(
  stripe: Stripe,
  uid: string,
  status: string,
  priceId: string | undefined
): Promise<void> {
  const features = await folioCloudFeaturesFromPriceId(stripe, priceId);
  const active =
    status === "active" || status === "trialing" || status === "past_due";
  const monthly = await isMonthlySubscriptionPrice(stripe, priceId);
  const ref = db.collection("users").doc(uid);
  await ref.set(
    {
      folioCloud: {
        subscriptionStatus: status,
        active,
        features,
        subscriptionPriceId: priceId ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    { merge: true }
  );
  if (active && monthly) {
    // Importante: sincronizar desde Stripe NO debe “recargar” la tinta cada vez.
    // Solo recargamos si cambia el periodo mensual o si faltan campos.
    const currentPeriodKey = monthPeriodKeyEuropeMadrid();

    const FieldPath = admin.firestore.FieldPath;
    const deleteDotted: Record<string, unknown> = {
      // Si existen campos literales con punto (bug/datos manuales), los borramos.
      [new FieldPath("ink.monthlyBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.purchasedBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.monthlyPeriodKey") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.updatedAt") as unknown as string]: FieldValue.delete(),
    };

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = (snap.data() ?? {}) as Record<string, unknown>;
      const inkRaw = (data.ink as Record<string, unknown>) ?? {};
      const existingMonthly = inkBalanceField(inkRaw.monthlyBalance);
      const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);

      const dottedMonthly = inkBalanceField(data["ink.monthlyBalance"]);
      const dottedPurchased = inkBalanceField(data["ink.purchasedBalance"]);

      const monthlyBalance = Math.max(existingMonthly, dottedMonthly);
      const purchasedBalance = Math.max(existingPurchased, dottedPurchased);

      const rawKey =
        typeof inkRaw.monthlyPeriodKey === "string"
          ? inkRaw.monthlyPeriodKey.trim()
          : "";
      const dottedKey =
        typeof data["ink.monthlyPeriodKey"] === "string"
          ? String(data["ink.monthlyPeriodKey"]).trim()
          : "";
      const existingPeriodKey = rawKey || dottedKey;

      const shouldRefill =
        !existingPeriodKey || existingPeriodKey !== currentPeriodKey;

      tx.set(
        ref,
        {
          ink: {
            monthlyBalance: shouldRefill ? MONTHLY_INK_ALLOWANCE : monthlyBalance,
            purchasedBalance,
            monthlyPeriodKey: currentPeriodKey,
            updatedAt: FieldValue.serverTimestamp(),
          },
          // Limpieza de duplicados (si los hubiera).
          ...deleteDotted,
        },
        { merge: true }
      );
    });

    let subIndexPrice: string | null = priceId ?? null;
    if (!subIndexPrice) {
      const rawMonthly = priceFolioCloudMonthly();
      if (rawMonthly) {
        try {
          subIndexPrice = await resolveCatalogIdToPriceId(stripe, rawMonthly);
        } catch {
          subIndexPrice = null;
        }
      }
    }
    await db.collection("folioCloudSubscribers").doc(uid).set(
      {
        subscriptionPriceId: subIndexPrice,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } else {
    await db.collection("folioCloudSubscribers").doc(uid).delete().catch(() => undefined);

    const FieldPathInactive = admin.firestore.FieldPath;
    const deleteDottedInactive: Record<string, unknown> = {
      [new FieldPathInactive("ink.monthlyBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPathInactive("ink.purchasedBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPathInactive("ink.monthlyPeriodKey") as unknown as string]:
        FieldValue.delete(),
      [new FieldPathInactive("ink.updatedAt") as unknown as string]:
        FieldValue.delete(),
    };

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = (snap.data() ?? {}) as Record<string, unknown>;
      const inkRaw = (data.ink as Record<string, unknown>) ?? {};
      const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
      const dottedPurchased = inkBalanceField(data["ink.purchasedBalance"]);
      const purchasedBalance = Math.max(existingPurchased, dottedPurchased);

      tx.set(
        ref,
        {
          ink: {
            monthlyBalance: 0,
            purchasedBalance,
            monthlyPeriodKey: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          ...deleteDottedInactive,
        },
        { merge: true }
      );
    });
  }
}

async function isWebhookAlreadyProcessed(eventId: string): Promise<boolean> {
  const snap = await db.collection("stripeWebhookEvents").doc(eventId).get();
  return snap.exists;
}

async function recordWebhookProcessed(eventId: string): Promise<void> {
  await db.collection("stripeWebhookEvents").doc(eventId).set({
    processedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Firestore a veces no tiene `stripeCustomerId` si el webhook de checkout falló.
 * Buscamos una suscripción con metadata.firebase_uid y persistimos el customer.
 */
async function ensureStripeCustomerId(
  stripe: Stripe,
  uid: string
): Promise<string | undefined> {
  const ref = db.collection("users").doc(uid);
  const existing = (await ref.get()).get("stripeCustomerId") as string | undefined;
  if (existing) return existing;
  const escapedUid = uid.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
  try {
    const search = await stripe.subscriptions.search({
      query: `metadata['firebase_uid']:'${escapedUid}'`,
      limit: 10,
    });
    for (const sub of search.data) {
      const c = sub.customer;
      const cid = typeof c === "string" ? c : c?.id;
      if (cid) {
        await ref.set({ stripeCustomerId: cid }, { merge: true });
        return cid;
      }
    }
  } catch (e) {
    console.warn("ensureStripeCustomerId: subscription search failed", e);
  }
  return undefined;
}

/**
 * Crédito de gotas por Checkout modo payment; idempotente por sesión (evita duplicar con
 * `checkout.session.async_payment_succeeded`).
 */
async function grantPaymentCheckoutInkIfNeeded(
  stripe: Stripe,
  uid: string,
  expanded: Stripe.Checkout.Session
): Promise<void> {
  const doneRef = db.collection("stripeProcessedCheckouts").doc(expanded.id);
  const doneSnap = await doneRef.get();
  if (doneSnap.exists) return;
  if (expanded.payment_status !== "paid") return;

  const lineItems = expanded.line_items?.data ?? [];
  let totalAdded = 0;
  for (const item of lineItems) {
    const priceObj = item.price;
    const linePriceId = typeof priceObj === "string" ? priceObj : priceObj?.id;
    const drops = await inkDropsForPriceId(stripe, linePriceId);
    if (drops > 0) totalAdded += drops * (item.quantity ?? 1);
  }

  const batch = db.batch();
  if (totalAdded > 0) {
    batch.set(
      db.collection("users").doc(uid),
      {
        "ink.purchasedBalance": FieldValue.increment(totalAdded),
        "ink.updatedAt": FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  batch.set(doneRef, {
    uid,
    dropsAdded: totalAdded,
    processedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

async function handleCheckoutSessionCompleted(
  stripe: Stripe,
  session: Stripe.Checkout.Session
): Promise<void> {
  const uid =
    (typeof session.metadata?.firebase_uid === "string"
      ? session.metadata.firebase_uid
      : ""
    ).trim() || session.client_reference_id?.trim() || "";
  if (!uid) {
    console.error(
      "checkout session: missing firebase_uid and client_reference_id",
      session.id
    );
    return;
  }
  const expanded = await stripe.checkout.sessions.retrieve(session.id, {
    expand: ["line_items.data.price", "subscription"],
  });
  let customerId: string | undefined =
    typeof expanded.customer === "string"
      ? expanded.customer
      : expanded.customer?.id;

  const mode = expanded.mode;
  if (mode === "subscription") {
    const rawSub = expanded.subscription;
    let sub: Stripe.Subscription | undefined;
    if (rawSub && typeof rawSub === "object" && "id" in rawSub) {
      sub = rawSub as Stripe.Subscription;
    } else if (typeof rawSub === "string") {
      sub = await stripe.subscriptions.retrieve(rawSub);
    }
    if (!sub) {
      console.error("checkout.session.completed: missing subscription", {
        sessionId: session.id,
        subscription: rawSub,
      });
      throw new Error(
        "checkout.session.completed: subscription missing after successful payment"
      );
    }
    if (!customerId) {
      const c = sub.customer;
      customerId = typeof c === "string" ? c : c?.id;
    }
    const priceId = sub.items.data[0]?.price?.id;
    if (customerId) {
      await db
        .collection("users")
        .doc(uid)
        .set({ stripeCustomerId: customerId }, { merge: true });
    }
    await syncSubscriptionToUser(stripe, uid, sub.status, priceId);
    // Misma sesión puede incluir ítems one-time (p. ej. pack de tinta) además de la sub.
    // `grantPaymentCheckoutInkIfNeeded` solo suma gotas para precios de tinta; el precio
    // de la suscripción devuelve 0 en `inkDropsForPriceId`.
    if (expanded.payment_status !== "paid") {
      console.warn(
        "checkout session: subscription mode, not paid yet — ink add-on will apply on async success",
        expanded.id,
        expanded.payment_status
      );
      return;
    }
    await grantPaymentCheckoutInkIfNeeded(stripe, uid, expanded);
    return;
  }
  if (customerId) {
    await db.collection("users").doc(uid).set({ stripeCustomerId: customerId }, { merge: true });
  }
  if (mode === "payment") {
    if (expanded.payment_status !== "paid") {
      console.warn(
        "checkout session: payment mode, not paid yet — will retry on async success",
        expanded.id,
        expanded.payment_status
      );
      return;
    }
    await grantPaymentCheckoutInkIfNeeded(stripe, uid, expanded);
  }
}

export const stripeWebhook = onRequest(
  // Stripe necesita invocar este endpoint sin auth (valida con firma Stripe).
  // En Functions v2 (Cloud Run), si no se marca como público, Cloud Run rechaza con 401
  // antes de que podamos verificar `stripe-signature`.
  { cors: false, memory: "256MiB", invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const stripe = stripeClient();
    const whSecret = webhookSecret();
    if (!stripe || !whSecret) {
      console.warn("Stripe webhook: missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET");
      res.status(503).send("Stripe not configured");
      return;
    }
    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).send("Missing stripe-signature");
      return;
    }
    let event: Stripe.Event;
    try {
      const rawBody = (req as { rawBody?: Buffer }).rawBody;
      if (!rawBody) {
        res.status(400).send("Missing raw body");
        return;
      }
      event = stripe.webhooks.constructEvent(rawBody, sig, whSecret);
    } catch (err) {
      console.error("Webhook signature verification failed", err);
      res.status(400).send("Invalid signature");
      return;
    }
    const stripeEventId = event.id;
    if (await isWebhookAlreadyProcessed(stripeEventId)) {
      res.json({ received: true, duplicate: true });
      return;
    }
    try {
      switch (event.type) {
        case "checkout.session.completed":
        case "checkout.session.async_payment_succeeded": {
          await handleCheckoutSessionCompleted(stripe, event.data.object as Stripe.Checkout.Session);
          break;
        }
        case "customer.subscription.created":
        case "customer.subscription.updated":
        case "customer.subscription.deleted": {
          const sub = event.data.object as Stripe.Subscription;
          const subUid = sub.metadata?.firebase_uid;
          if (!subUid) break;
          const customerRef =
            typeof sub.customer === "string" ? sub.customer : sub.customer?.id;
          if (customerRef) {
            await db.collection("users").doc(subUid).set(
              { stripeCustomerId: customerRef },
              { merge: true }
            );
          }
          const priceId = sub.items.data[0]?.price?.id;
          if (event.type === "customer.subscription.deleted") {
            await syncSubscriptionToUser(stripe, subUid, "canceled", priceId);
          } else {
            await syncSubscriptionToUser(stripe, subUid, sub.status, priceId);
          }
          break;
        }
        default:
          break;
      }
      await recordWebhookProcessed(stripeEventId);
      res.json({ received: true });
    } catch (e) {
      console.error("Webhook handler error", e);
      res.status(500).send("Handler error");
    }
  }
);

export type CheckoutKind =
  | "folio_cloud_monthly"
  | "ink_small"
  | "ink_medium"
  | "ink_large";

/** Misma condición que Storage rules `folioCloudBackupOk` (copias en la nube). */
async function assertFolioCloudBackupAllowed(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() ?? {};
  const fc = data.folioCloud as Record<string, unknown> | undefined;
  const features = fc?.features as Record<string, unknown> | undefined;
  if (fc?.active !== true || features?.backup !== true) {
    throw new HttpsError(
      "permission-denied",
      "Folio Cloud backup is not active for this account."
    );
  }
}

/** Igual que Firestore rules `folioRealtimeCollabOk`. */
async function assertFolioRealtimeCollabAllowed(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() ?? {};
  const fc = data.folioCloud as Record<string, unknown> | undefined;
  const features = fc?.features as Record<string, unknown> | undefined;
  if (fc?.active !== true || features?.realtimeCollab !== true) {
    throw new HttpsError(
      "permission-denied",
      "Real-time collaboration is not enabled for this account."
    );
  }
}

const COLLAB_MAX_MEMBERS = 24;
const COLLAB_MEDIA_MAX_BYTES = 80 * 1024 * 1024;
const COLLAB_ALLOWED_MEDIA_KINDS = new Set(["image", "video", "audio", "file"]);

const COLLAB_JOIN_EMOJIS = [
  "\u{1F331}",
  "\u{2B50}",
  "\u{1F319}",
  "\u{1F525}",
  "\u{1F308}",
  "\u{2728}",
  "\u{1F3AF}",
  "\u{1F380}",
  "\u{1F4BB}",
  "\u{1F3D6}",
  "\u{26A1}",
  "\u{1F342}",
  "\u{1F341}",
  "\u{1F30A}",
  "\u{1F3AE}",
];

function normalizeCollabJoinCode(raw: string): string {
  // Debe coincidir con `CollabE2eCrypto.normalizeJoinCode` en el cliente (HKDF + índice).
  return raw.replace(/\s+/g, "").trim();
}

function collabJoinCodeKey(norm: string): string {
  return createHash("sha256").update(norm, "utf8").digest("hex");
}

function generateCollabJoinCode(): string {
  const pick = () =>
    COLLAB_JOIN_EMOJIS[Math.floor(Math.random() * COLLAB_JOIN_EMOJIS.length)] ??
    "\u{2B50}";
  const a = pick();
  const b = pick();
  const n = String(Math.floor(Math.random() * 10000)).padStart(4, "0");
  return `${a}${b}${n}`;
}

export const createCollabRoom = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  await assertFolioRealtimeCollabAllowed(uid);

  const vaultPageId =
    typeof request.data?.vaultPageId === "string"
      ? request.data.vaultPageId.trim()
      : "";
  if (!vaultPageId || vaultPageId.length > 128) {
    throw new HttpsError("invalid-argument", "vaultPageId invalid");
  }

  const roomRef = db.collection("collabRooms").doc();

  for (let attempt = 0; attempt < 28; attempt++) {
    const joinCode = generateCollabJoinCode();
    const norm = normalizeCollabJoinCode(joinCode);
    if (norm.length < 4) {
      continue;
    }
    const key = collabJoinCodeKey(norm);
    const indexRef = db.collection("collabJoinIndex").doc(key);
    const now = FieldValue.serverTimestamp();
    try {
      await db.runTransaction(async (tx) => {
        const idxSnap = await tx.get(indexRef);
        if (idxSnap.exists) {
          throw new Error("join_code_collision");
        }
        const roomSnap = await tx.get(roomRef);
        if (roomSnap.exists) {
          throw new HttpsError("failed-precondition", "Room already created");
        }
        tx.set(indexRef, {
          roomId: roomRef.id,
          ownerUid: uid,
          createdAt: now,
        });
        tx.set(roomRef, {
          ownerUid: uid,
          vaultPageId,
          memberUids: [uid],
          memberJoinedAt: { [uid]: now },
          e2eV: 1,
          contentVersion: 0,
          joinCodeKey: key,
          createdAt: now,
          updatedAt: now,
        });
      });
      return { roomId: roomRef.id, joinCode };
    } catch (e: unknown) {
      if (e instanceof Error && e.message === "join_code_collision") {
        continue;
      }
      throw e;
    }
  }
  throw new HttpsError("internal", "Could not allocate join code");
});

export const joinCollabRoomByCode = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  const raw =
    typeof request.data?.joinCode === "string"
      ? request.data.joinCode.trim()
      : "";
  if (raw.length < 4 || raw.length > 64) {
    throw new HttpsError("invalid-argument", "Invalid join code");
  }
  const key = collabJoinCodeKey(normalizeCollabJoinCode(raw));
  const indexRef = db.collection("collabJoinIndex").doc(key);
  const idxSnap = await indexRef.get();
  if (!idxSnap.exists) {
    throw new HttpsError("not-found", "Room not found");
  }
  const roomId = idxSnap.data()?.roomId as string | undefined;
  if (!roomId) {
    throw new HttpsError("not-found", "Room not found");
  }
  const roomRef = db.collection("collabRooms").doc(roomId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Room not found");
    }
    const d = snap.data() ?? {};
    const members = (d.memberUids as string[] | undefined) ?? [];
    if (members.includes(uid)) {
      return;
    }
    if (members.length >= COLLAB_MAX_MEMBERS) {
      throw new HttpsError("failed-precondition", "Room is full");
    }
    tx.update(roomRef, {
      memberUids: FieldValue.arrayUnion(uid),
      [`memberJoinedAt.${uid}`]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { roomId };
});

export const prepareCollabMediaUpload = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  await assertFolioRealtimeCollabAllowed(uid);

  const roomId =
    typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId required");
  }
  const blockId =
    typeof request.data?.blockId === "string" ? request.data.blockId.trim() : "";
  if (!blockId || blockId.length > 128) {
    throw new HttpsError("invalid-argument", "blockId invalid");
  }
  const mediaKind =
    typeof request.data?.mediaKind === "string" ? request.data.mediaKind.trim() : "";
  if (!COLLAB_ALLOWED_MEDIA_KINDS.has(mediaKind)) {
    throw new HttpsError("invalid-argument", "mediaKind invalid");
  }
  const sizeBytes = Number(request.data?.sizeBytes ?? 0);
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > COLLAB_MEDIA_MAX_BYTES) {
    throw new HttpsError("invalid-argument", "sizeBytes invalid");
  }

  const roomRef = db.collection("collabRooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Room not found");
  }
  const room = roomSnap.data() ?? {};
  const members = (room.memberUids as string[] | undefined) ?? [];
  if (!members.includes(uid) && room.ownerUid !== uid) {
    throw new HttpsError("permission-denied", "Not a room member");
  }
  if ((room.e2eV as number | undefined) !== 1) {
    throw new HttpsError("failed-precondition", "Room must be e2eV=1");
  }

  const mediaRef = roomRef.collection("media").doc();
  const mediaId = mediaRef.id;
  const storagePath = `collab-media-e2e/${roomId}/${mediaId}`;

  return {
    mediaId,
    storagePath,
    roomId,
    blockId,
    mediaKind,
  };
});

export const commitCollabMediaUpload = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  await assertFolioRealtimeCollabAllowed(uid);

  const roomId =
    typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";
  const mediaId =
    typeof request.data?.mediaId === "string" ? request.data.mediaId.trim() : "";
  const blockId =
    typeof request.data?.blockId === "string" ? request.data.blockId.trim() : "";
  const storagePath =
    typeof request.data?.storagePath === "string" ? request.data.storagePath.trim() : "";
  const mediaKind =
    typeof request.data?.mediaKind === "string" ? request.data.mediaKind.trim() : "";
  const mimeType =
    typeof request.data?.mimeType === "string" ? request.data.mimeType.trim() : "";
  const fileName =
    typeof request.data?.fileName === "string" ? request.data.fileName.trim() : "";
  const sizeBytes = Number(request.data?.sizeBytes ?? 0);

  if (!roomId || !mediaId || !blockId || !storagePath || !mediaKind) {
    throw new HttpsError("invalid-argument", "Missing required media fields");
  }
  if (!COLLAB_ALLOWED_MEDIA_KINDS.has(mediaKind)) {
    throw new HttpsError("invalid-argument", "mediaKind invalid");
  }
  if (!storagePath.startsWith(`collab-media-e2e/${roomId}/${mediaId}`)) {
    throw new HttpsError("invalid-argument", "storagePath invalid");
  }
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > COLLAB_MEDIA_MAX_BYTES) {
    throw new HttpsError("invalid-argument", "sizeBytes invalid");
  }

  const roomRef = db.collection("collabRooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Room not found");
  }
  const room = roomSnap.data() ?? {};
  const members = (room.memberUids as string[] | undefined) ?? [];
  if (!members.includes(uid) && room.ownerUid !== uid) {
    throw new HttpsError("permission-denied", "Not a room member");
  }
  if ((room.e2eV as number | undefined) !== 1) {
    throw new HttpsError("failed-precondition", "Room must be e2eV=1");
  }

  const mediaRef = roomRef.collection("media").doc(mediaId);
  try {
    await mediaRef.create({
      roomId,
      mediaId,
      blockId,
      storagePath,
      mediaKind,
      mimeType,
      fileName,
      sizeBytes,
      e2eV: 1,
      uploaderUid: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e: unknown) {
    const code = (e as { code?: unknown }).code;
    if (code === 6 || code === "6" || code === "already-exists") {
      throw new HttpsError("already-exists", "Media already committed");
    }
    throw e;
  }

  return { ok: true };
});

export const inviteCollabMember = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  await assertFolioRealtimeCollabAllowed(uid);

  const roomId =
    typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId required");
  }
  const targetUid =
    typeof request.data?.targetUid === "string"
      ? request.data.targetUid.trim()
      : "";
  if (!targetUid || targetUid === uid) {
    throw new HttpsError("invalid-argument", "targetUid invalid");
  }

  const roomRef = db.collection("collabRooms").doc(roomId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Room not found");
    }
    const d = snap.data() ?? {};
    if (d.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Only the owner can invite");
    }
    const members = (d.memberUids as string[] | undefined) ?? [];
    if (members.includes(targetUid)) {
      return;
    }
    if (members.length >= COLLAB_MAX_MEMBERS) {
      throw new HttpsError(
        "failed-precondition",
        `Room has at most ${COLLAB_MAX_MEMBERS} members`
      );
    }
    tx.update(roomRef, {
      memberUids: FieldValue.arrayUnion(targetUid),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

export const removeCollabMember = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;

  const roomId =
    typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId required");
  }
  const targetUid =
    typeof request.data?.targetUid === "string"
      ? request.data.targetUid.trim()
      : "";
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid required");
  }

  const roomRef = db.collection("collabRooms").doc(roomId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Room not found");
    }
    const d = snap.data() ?? {};
    const ownerUid = d.ownerUid as string;
    if (uid !== ownerUid && uid !== targetUid) {
      throw new HttpsError("permission-denied", "Not allowed");
    }
    if (targetUid === ownerUid) {
      throw new HttpsError("invalid-argument", "Cannot remove the owner");
    }
    tx.update(roomRef, {
      memberUids: FieldValue.arrayRemove(targetUid),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

export const closeCollabRoom = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;

  const roomId =
    typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId required");
  }

  const roomRef = db.collection("collabRooms").doc(roomId);
  const snap = await roomRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Room not found");
  }
  const d = snap.data() ?? {};
  const ownerUid = (d.ownerUid as string | undefined) ?? "";
  if (!ownerUid || ownerUid != uid) {
    throw new HttpsError("permission-denied", "Only the owner can close the room");
  }

  const joinCodeKey =
    typeof d.joinCodeKey === "string" ? d.joinCodeKey.trim() : "";

  const mediaPrefix = `collab-media-e2e/${roomId}/`;
  const bestEffortStorageDelete = admin
    .storage()
    .bucket()
    .deleteFiles({ prefix: mediaPrefix })
    .catch(() => undefined);
  const bestEffortJoinDelete = joinCodeKey
    ? db.collection("collabJoinIndex").doc(joinCodeKey).delete().catch(() => undefined)
    : Promise.resolve();

  await Promise.all([
    db.recursiveDelete(roomRef),
    bestEffortStorageDelete,
    bestEffortJoinDelete,
  ]);

  return { ok: true };
});

function assertValidVaultId(raw: unknown): string {
  const vaultId = typeof raw === "string" ? raw.trim() : "";
  if (!vaultId) {
    throw new HttpsError("invalid-argument", "vaultId is required");
  }
  // Reject path traversal and unexpected separators.
  if (vaultId.includes("/") || vaultId.includes("\\") || vaultId.includes("..")) {
    throw new HttpsError("invalid-argument", "Invalid vaultId");
  }
  if (vaultId.length > 96) {
    throw new HttpsError("invalid-argument", "Invalid vaultId");
  }
  return vaultId;
}

/**
 * Callable v2 corre en Cloud Run (2nd gen). Para soportar escritorio vía HTTP callable
 * (`Authorization: Bearer <ID token>`), el servicio debe permitir invocación pública
 * o Cloud Run devolverá 401 HTML antes de ejecutar la función.
 */
export const createCheckoutSession = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const stripe = stripeClient();
    if (!stripe) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe not configured on server"
      );
    }
    const uid = request.auth.uid;
    const kind = (request.data?.kind as CheckoutKind) ?? "folio_cloud_monthly";
    const priceIdMap: Record<CheckoutKind, string> = {
      folio_cloud_monthly: priceFolioCloudMonthly(),
      ink_small: priceInkSmall(),
      ink_medium: priceInkMedium(),
      ink_large: priceInkLarge(),
    };
    const rawCatalogId = priceIdMap[kind]?.trim();
    if (!rawCatalogId) {
      throw new HttpsError(
        "failed-precondition",
        `Stripe catalog id not configured for kind: ${kind}`
      );
    }
    let priceId: string;
    try {
      priceId = await resolveCatalogIdToPriceId(stripe, rawCatalogId);
    } catch (e: unknown) {
      if (e instanceof HttpsError) throw e;
      console.error("resolveCatalogIdToPriceId", e);
      throw new HttpsError(
        "failed-precondition",
        `Stripe: ${stripeCallErrorMessage(e)}`
      );
    }
    const successUrl =
      process.env.STRIPE_CHECKOUT_SUCCESS_URL?.trim() ||
      process.env.BILLING_PORTAL_RETURN_URL?.trim() ||
      "https://folio.app";
    const cancelUrl =
      process.env.STRIPE_CHECKOUT_CANCEL_URL?.trim() || successUrl;
    const isSubscription = kind === "folio_cloud_monthly";
    let session: Stripe.Response<Stripe.Checkout.Session>;
    try {
      session = await stripe.checkout.sessions.create({
        mode: isSubscription ? "subscription" : "payment",
        line_items: [{ price: priceId, quantity: 1 }],
        // Cupones/códigos creados en Stripe Dashboard (Product catalog → Coupons).
        allow_promotion_codes: true,
        success_url: successUrl.includes("?")
          ? `${successUrl}&session_id={CHECKOUT_SESSION_ID}`
          : `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: cancelUrl,
        client_reference_id: uid,
        metadata: { firebase_uid: uid },
        subscription_data: isSubscription
          ? {
              metadata: { firebase_uid: uid },
            }
          : undefined,
        payment_intent_data: !isSubscription
          ? {
              metadata: { firebase_uid: uid },
            }
          : undefined,
      });
    } catch (e: unknown) {
      console.error(
        "createCheckoutSession: Stripe checkout.sessions.create",
        e
      );
      throw new HttpsError(
        "failed-precondition",
        `Stripe: ${stripeCallErrorMessage(e)}`
      );
    }
    if (!session.url) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe did not return a checkout URL"
      );
    }
    return { url: session.url };
  }
);

export const syncFolioCloudSubscriptionFromStripe = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const stripe = stripeClient();
    if (!stripe) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe not configured on server"
      );
    }
    const uid = request.auth.uid;
    const customerId = await ensureStripeCustomerId(stripe, uid);
    if (!customerId) {
      throw new HttpsError(
        "failed-precondition",
        "No Stripe customer yet. Complete checkout first."
      );
    }
    const subs = await stripe.subscriptions.list({
      customer: customerId,
      status: "all",
      limit: 20,
    });
    const priority = ["active", "trialing", "past_due", "unpaid"] as const;
    function pickSubscription(
      list: Stripe.Subscription[]
    ): Stripe.Subscription | undefined {
      for (const st of priority) {
        const hit = list.find((s) => s.status === st);
        if (hit) return hit;
      }
      return undefined;
    }
    let chosen = pickSubscription(subs.data);
    if (!chosen) {
      const escapedUid = uid.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
      try {
        const byMeta = await stripe.subscriptions.search({
          query: `metadata['firebase_uid']:'${escapedUid}'`,
          limit: 10,
        });
        chosen = pickSubscription(byMeta.data);
      } catch (e) {
        console.warn(
          "syncFolioCloudSubscriptionFromStripe: search fallback failed",
          e
        );
      }
    }
    if (chosen) {
      const c = chosen.customer;
      const cid = typeof c === "string" ? c : c?.id;
      if (cid && cid !== customerId) {
        await db
          .collection("users")
          .doc(uid)
          .set({ stripeCustomerId: cid }, { merge: true });
      }
      const priceId = chosen.items.data[0]?.price?.id;
      await syncSubscriptionToUser(stripe, uid, chosen.status, priceId);
      return { ok: true as const, status: chosen.status };
    }
    await syncSubscriptionToUser(stripe, uid, "canceled", undefined);
    return { ok: true as const, status: "canceled" as const };
  }
);

export const folioListVaultBackups = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files
      .filter((f) => !f.name.endsWith("/"))
      .map((f) => {
        const parts = f.name.split("/");
        const fileName = parts[parts.length - 1] ?? f.name;
        return { fileName, storagePath: f.name };
      })
      .filter((x) => x.fileName.length > 0);
    items.sort((a, b) => b.fileName.localeCompare(a.fileName));
    return { items };
  }
);

export const folioListBackupVaults = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const bucket = admin.storage().bucket();
    const prefix = `users/${uid}/vaults/`;
    const [, , apiResponse] = (await bucket.getFiles({
      prefix,
      delimiter: "/",
      autoPaginate: false,
    })) as unknown as [unknown, unknown, { prefixes?: string[] }];
    const prefixes = apiResponse?.prefixes ?? [];
    const vaultIds = prefixes
      .map((p) => p.replace(prefix, "").replace(/\/$/, ""))
      .map((x) => x.trim())
      .filter((x) => x.length > 0);
    vaultIds.sort((a, b) => a.localeCompare(b));

    const indexSnap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultBackupIndex")
      .get();
    const nameById = new Map<string, string>();
    for (const d of indexSnap.docs) {
      const data = d.data() as Record<string, unknown>;
      const name =
        typeof data.displayName === "string" ? data.displayName.trim() : "";
      if (name) nameById.set(d.id, name);
    }
    const vaults = vaultIds.map((id) => ({
      vaultId: id,
      displayName: nameById.get(id) ?? "",
    }));
    return { vaults };
  }
);

export const folioUpsertVaultBackupIndex = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const displayNameRaw = (request.data as any)?.displayName;
    const displayName =
      typeof displayNameRaw === "string" ? displayNameRaw.trim() : "";
    await db
      .collection("users")
      .doc(uid)
      .collection("vaultBackupIndex")
      .doc(vaultId)
      .set(
        {
          displayName: displayName.slice(0, 120),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    return { ok: true };
  }
);

export const folioTrimVaultBackups = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const maxCountRaw = (request.data as any)?.maxCount;
    const maxCount =
      typeof maxCountRaw === "number" && Number.isFinite(maxCountRaw)
        ? Math.max(1, Math.min(50, Math.trunc(maxCountRaw)))
        : 10;
    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files.filter((f) => !f.name.endsWith("/"));
    items.sort((a, b) => a.name.localeCompare(b.name));
    const toDelete =
      items.length > maxCount ? items.slice(0, items.length - maxCount) : [];
    let deleted = 0;
    const errors: string[] = [];
    for (const f of toDelete) {
      try {
        await f.delete();
        deleted++;
      } catch (e: unknown) {
        console.warn("folioTrimVaultBackups: delete failed", f.name, e);
        errors.push(f.name);
      }
    }
    return { ok: errors.length === 0, deleted, failed: errors.slice(0, 10) };
  }
);

export const createBillingPortalSession = onCall(
  { invoker: "public" },
  async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const stripe = stripeClient();
  if (!stripe) {
    throw new HttpsError("failed-precondition", "Stripe not configured on server");
  }
  const uid = request.auth.uid;
  const customerId = await ensureStripeCustomerId(stripe, uid);
  if (!customerId) {
    throw new HttpsError(
      "failed-precondition",
      "No Stripe customer yet. Complete checkout first."
    );
  }
  const baseUrl = process.env.BILLING_PORTAL_RETURN_URL?.trim() || "https://folio.app";
  let session: Stripe.Response<Stripe.BillingPortal.Session>;
  try {
    session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: baseUrl,
    });
  } catch (e: unknown) {
    console.error("createBillingPortalSession: Stripe billingPortal.sessions.create", e);
    throw new HttpsError(
      "failed-precondition",
      `Stripe: ${stripeCallErrorMessage(e)}`
    );
  }
  if (!session.url) {
    throw new HttpsError(
      "failed-precondition",
      "Stripe did not return a billing portal URL"
    );
  }
  return { url: session.url };
  }
);

// ─── Diarización de segmentos vía GPT-4o-mini ────────────────────────────────

interface _WhisperSegment {
  id: number;
  start: number;
  end: number;
  text: string;
}

/**
 * Recibe segmentos de Whisper verbose_json y devuelve texto formateado
 * "Speaker N: ..." usando GPT-4o-mini para detectar cambios de hablante.
 */
async function _diarizeSegmentsWithGpt(
  segments: _WhisperSegment[],
  openaiKey: string
): Promise<string> {
  const segmentList = segments
    .map((s) => `[${s.start.toFixed(1)}s-${s.end.toFixed(1)}s]: "${s.text.trim()}"`)
    .join("\n");

  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content:
            "You are a speaker diarization assistant. Analyze transcript segments from a meeting " +
            "audio recording and identify speaker turns. " +
            "Return ONLY a JSON object with a 'turns' array: {\"turns\":[{\"speaker\":1,\"text\":\"...\"},...]}. " +
            "Rules: merge consecutive segments from the same speaker into one turn; " +
            "detect speaker changes using question-answer patterns, conversational cues, " +
            "and pauses (gap > 0.8 s between segment end and next start); " +
            "use integers starting from 1 for speaker IDs; " +
            "if the audio clearly has only one speaker, use speaker 1 for all text.",
        },
        { role: "user", content: segmentList },
      ],
      temperature: 0,
      max_tokens: 1500,
      response_format: { type: "json_object" },
    }),
  });

  if (!resp.ok) {
    const body = await resp.text().catch(() => `HTTP ${resp.status}`);
    throw new Error(`GPT diarization HTTP ${resp.status}: ${body}`);
  }

  const gptResult = (await resp.json()) as {
    choices: Array<{ message: { content: string } }>;
  };
  const raw = gptResult.choices?.[0]?.message?.content ?? "";

  interface DiarTurn { speaker: number; text: string }
  const parsed = JSON.parse(raw) as unknown;
  let turns: DiarTurn[] = [];
  if (Array.isArray(parsed)) {
    turns = parsed as DiarTurn[];
  } else if (parsed && typeof parsed === "object") {
    const obj = parsed as Record<string, unknown>;
    const arr =
      obj["turns"] ?? obj["speakers"] ?? obj["segments"] ?? Object.values(obj)[0];
    if (Array.isArray(arr)) turns = arr as DiarTurn[];
  }

  if (!turns.length) throw new Error("Empty diarization response from GPT");

  return turns
    .filter((t) => typeof t.text === "string" && t.text.trim().length > 0)
    .map((t) => `Speaker ${t.speaker}: ${t.text.trim()}`)
    .join("\n");
}

/**
 * Transcribe un fragmento de audio WAV (base64) vía gpt-4o-mini-transcribe,
 * con diarización automática de hablantes usando GPT-4o-mini.
 * Si `chargeInk` es true, debita 1 gota de tinta (tranche de 5 minutos).
 * En caso de fallo de transcripción, reembolsa la tinta cobrada.
 */
export const folioCloudTranscribeChunk = onCall(
  { cors: true, invoker: "public", memory: "512MiB", timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = request.data as Record<string, unknown>;

    const audioBase64 = typeof data.audioBase64 === "string" ? data.audioBase64.trim() : "";
    if (!audioBase64) {
      throw new HttpsError("invalid-argument", "audioBase64 required");
    }

    const language = typeof data.language === "string" ? data.language.trim() : "";
    const chargeInk = data.chargeInk === true;

    const baseInkCost = INK_COST_BY_OPERATION["transcribe_cloud"] ?? 1;
    const inkAmountRaw = data.inkAmount;
    const inkCost =
      chargeInk &&
      typeof inkAmountRaw === "number" &&
      Number.isFinite(inkAmountRaw) &&
      inkAmountRaw >= 1
        ? Math.ceil(inkAmountRaw)
        : baseInkCost;
    let inkDebited = false;

    // ── Debitar Tinta si se solicita ─────────────────────────────────────────
    if (chargeInk) {
      const inkExhaustedMsg =
        "Tinta insuficiente para la transcripción en la nube. Compra un tintero, " +
        "espera la recarga mensual con suscripción activa, o usa transcripción local.";

      const userRef = db.collection("users").doc(uid);
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(userRef);
        const dataDoc = snap.data() ?? {};
        const fc = dataDoc.folioCloud as Record<string, unknown> | undefined;
        const hasSubCloudAi =
          fc?.active === true &&
          (fc?.features as Record<string, unknown>)?.cloudAi === true;

        const { monthly, purchased } = readInkBalances(dataDoc);
        if (hasSubCloudAi) {
          if (monthly + purchased < inkCost) {
            throw new HttpsError("resource-exhausted", inkExhaustedMsg);
          }
          const next = debitInkBalances(monthly, purchased, inkCost);
          tx.update(userRef, {
            "ink.monthlyBalance": next.monthly,
            "ink.purchasedBalance": next.purchased,
            "ink.updatedAt": FieldValue.serverTimestamp(),
          });
        } else {
          if (purchased < inkCost) {
            throw new HttpsError("resource-exhausted", inkExhaustedMsg);
          }
          const next = debitInkBalances(0, purchased, inkCost);
          tx.update(userRef, {
            "ink.monthlyBalance": 0,
            "ink.purchasedBalance": next.purchased,
            "ink.updatedAt": FieldValue.serverTimestamp(),
          });
        }
      });
      inkDebited = true;
    }

    // ── Llamar a OpenAI Whisper ───────────────────────────────────────────────
    const openaiKey = openAiApiKey();
    if (!openaiKey) {
      if (inkDebited) {
        await refundInkDropCharge(uid, inkCost).catch((e) =>
          console.error("folioCloudTranscribeChunk: refund after missing key", e)
        );
      }
      throw new HttpsError(
        "failed-precondition",
        "Server AI not configured (set OPENAI_API_KEY on Cloud Functions)"
      );
    }

    let transcript = "";
    try {
      const audioBuffer = Buffer.from(audioBase64, "base64");
      const blob = new Blob([audioBuffer], { type: "audio/wav" });
      const form = new FormData();
      form.append("file", blob, "chunk.wav");
      // gpt-4o-mini-transcribe: mejor calidad que whisper-1, soporta verbose_json
      form.append("model", "gpt-4o-mini-transcribe");
      if (language && language !== "auto") {
        form.append("language", language.slice(0, 2).toLowerCase());
      }
      form.append("response_format", "verbose_json");

      const resp = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { Authorization: `Bearer ${openaiKey}` },
        body: form,
      });

      if (!resp.ok) {
        const errBody = await resp.text().catch(() => `HTTP ${resp.status}`);
        console.error("folioCloudTranscribeChunk: transcription API error", resp.status, errBody);
        throw new HttpsError("internal", `Transcription failed (${resp.status})`);
      }

      const verboseResult = (await resp.json()) as {
        text: string;
        segments?: _WhisperSegment[];
      };
      const rawText = (verboseResult.text ?? "").trim();
      const segments = verboseResult.segments ?? [];

      if (rawText.length === 0) {
        transcript = "";
      } else if (segments.length > 1) {
        // Diarización con GPT-4o-mini
        try {
          transcript = await _diarizeSegmentsWithGpt(segments, openaiKey);
        } catch (diarErr) {
          console.warn(
            "folioCloudTranscribeChunk: diarization fallback to plain text",
            diarErr
          );
          transcript = `Speaker 1: ${rawText}`;
        }
      } else {
        // Un solo segmento: etiquetar como hablante 1
        transcript = `Speaker 1: ${rawText}`;
      }
    } catch (e) {
      if (inkDebited) {
        await refundInkDropCharge(uid, inkCost).catch((re) =>
          console.error("folioCloudTranscribeChunk: refund after transcription error", re)
        );
      }
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", "Transcription request failed");
    }

    // ── Leer saldos finales ───────────────────────────────────────────────────
    const finalSnap = await db.collection("users").doc(uid).get();
    const inkOut = readInkBalances(
      (finalSnap.data() ?? {}) as Record<string, unknown>
    );
    return {
      transcript,
      ink: {
        monthlyBalance: inkOut.monthly,
        purchasedBalance: inkOut.purchased,
      },
    };
  }
);

export const monthlyInkRefill = onSchedule(
  {
    schedule: "0 8 1 * *",
    timeZone: INK_TIMEZONE,
    memory: "256MiB",
  },
  async () => {
    const stripe = stripeClient();
    const monthlyRaw = priceFolioCloudMonthly();
    if (!monthlyRaw || !stripe) {
      console.warn(
        "monthlyInkRefill: STRIPE_PRICE_FOLIO_CLOUD_MONTHLY or Stripe key not set"
      );
      return;
    }
    let monthlyResolved: string;
    try {
      monthlyResolved = await resolveCatalogIdToPriceId(stripe, monthlyRaw);
    } catch (e) {
      console.error("monthlyInkRefill: resolveCatalogIdToPriceId", e);
      return;
    }
    const indexSnap = await db.collection("folioCloudSubscribers").get();
    const periodKey = monthPeriodKeyEuropeMadrid();
    let batch = db.batch();
    let n = 0;
    for (const doc of indexSnap.docs) {
      const uid = doc.id;
      const data = doc.data();
      if (
        data.subscriptionPriceId &&
        data.subscriptionPriceId !== monthlyResolved
      ) {
        continue;
      }
      const ref = db.collection("users").doc(uid);
      batch.set(
        ref,
        {
          "ink.monthlyBalance": MONTHLY_INK_ALLOWANCE,
          "ink.monthlyPeriodKey": periodKey,
          "ink.updatedAt": FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      n++;
      if (n >= 500) {
        await batch.commit();
        batch = db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
    console.log(`monthlyInkRefill: done ${periodKey}`);
  }
);

/**
 * IA en nube en Cloud Functions **1st gen** (URL `*.cloudfunctions.net`, sin servicio Cloud Run v2).
 * Así se evita el perímetro IAM / límites típicos de Run que en Windows suelen aparecer como HTTP 429 o 401 HTML.
 */
export const folioCloudAiComplete = functionsV1
  .region("us-central1")
  .runWith({ memory: "512MB", timeoutSeconds: 120 })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new AiHttpsError("unauthenticated", "Login required");
    }
    const uid = context.auth.uid;
    const prompt = normalizePrompt(data?.prompt);
    const systemPrompt = normalizeOptionalString(data?.systemPrompt, 20000);
    const messages = normalizeOpenAiMessages(data?.messages);
    const responseSchema = normalizeResponseSchema(data?.responseSchema);
    const maxTokens = normalizeClientMaxTokens(data?.maxTokens);
    const temperature = normalizeClientTemperature(data?.temperature);
    if (!prompt && messages.length === 0) {
      throw new AiHttpsError("invalid-argument", "Missing prompt/messages");
    }
    const operationKind = normalizeOperationKind(data?.operationKind);
    return runFolioCloudAiForUid(
      uid,
      {
        prompt,
        systemPrompt: systemPrompt || undefined,
        messages: messages.length > 0 ? messages : undefined,
        responseSchema,
        maxTokens,
        temperature,
      },
      operationKind
    );
  });

/**
 * Fallback HTTP para escritorio: evita bloqueos de infraestructura callable
 * cuando un despliegue previo o IAM externo interfiere con `onCall`.
 */
export const folioCloudAiCompleteHttp = functionsV1
  .region("us-central1")
  .runWith({ memory: "512MB", timeoutSeconds: 120 })
  .https.onRequest(async (req, res) => {
    res.set("Cache-Control", "no-store");
    if (req.method !== "POST") {
      res.status(405).json(
        callableLikeErrorBody("invalid-argument", "Method not allowed")
      );
      return;
    }

    try {
      const uid = await verifiedUidFromBearerToken(req.header("authorization"));
      const body =
        req.body && typeof req.body === "object"
          ? (req.body as Record<string, unknown>)
          : {};
      const payload =
        body.data && typeof body.data === "object"
          ? (body.data as Record<string, unknown>)
          : body;
      const prompt = normalizePrompt(payload.prompt);
      const systemPrompt = normalizeOptionalString(payload.systemPrompt, 20000);
      const messages = normalizeOpenAiMessages(payload.messages);
      const responseSchema = normalizeResponseSchema(payload.responseSchema);
      const maxTokens = normalizeClientMaxTokens(payload.maxTokens);
      const temperature = normalizeClientTemperature(payload.temperature);
      if (!prompt && messages.length === 0) {
        throw new AiHttpsError("invalid-argument", "Missing prompt/messages");
      }
      const operationKind = normalizeOperationKind(payload.operationKind);
      const result = await runFolioCloudAiForUid(
        uid,
        {
          prompt,
          systemPrompt: systemPrompt || undefined,
          messages: messages.length > 0 ? messages : undefined,
          responseSchema,
          maxTokens,
          temperature,
        },
        operationKind
      );
      res.status(200).json({ result });
    } catch (e: unknown) {
      if (e instanceof AiHttpsError || e instanceof HttpsError) {
        res
          .status(200)
          .json(callableLikeErrorBody(e.code, e.message || "Cloud Function error"));
        return;
      }
      console.error("folioCloudAiCompleteHttp: internal error", e);
      res
        .status(200)
        .json(callableLikeErrorBody("internal", "Internal error"));
    }
  });
