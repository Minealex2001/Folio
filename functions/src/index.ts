import * as path from "path";
import { config as loadEnv } from "dotenv";

// Carga `functions/.env` (gitignored). En deploy, Firebase también inyecta estas variables.
loadEnv({ path: path.resolve(__dirname, "../.env") });

import "./admin_init";

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { createHash, randomBytes, randomInt } from "crypto";
import * as functionsV1 from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import Stripe from "stripe";

import {
  microsoftStoreValidationConfigured,
  queryMicrosoftStoreUserCollection,
  scanMicrosoftStoreCollectionItems,
} from "./microsoft_store";

export {
  aggregateDailyTelemetryStats,
  aggregateGlobalTelemetryStats,
  onTelemetryEventCreated,
} from "./telemetry";

export {
  folioUpsertIntegrationWebhookConnection,
  folioIntegrationWebhookProxy,
  folioRegisterIntegrationLinkCode,
  folioListPendingIntegrationCommands,
  folioAckIntegrationCommand,
  folioSlackCommand,
  folioTeamsCommand,
  folioSlackExchangeOAuth,
  folioTeamsExchangeOAuth,
} from "./slack_teams_integration";

export {
  folioSpotifyExchangeOAuth,
  folioSpotifyOAuthCallback,
  folioSpotifyApiProxy,
} from "./spotify_integration";

const db = admin.firestore();

/** HttpsError de 1st gen: la callable `folioCloudAiComplete` corre en CF 1st gen (no Cloud Run). */
const AiHttpsError = functionsV1.https.HttpsError;

/** Suscripción Folio Cloud: 500 gotas/mes (recarga día 1 + alta). */
const MONTHLY_INK_ALLOWANCE = 500;
const STUDENT_INK_ALLOWANCE = 1000;
const STUDENT_BACKUP_BASE_QUOTA_BYTES = 15 * 1024 * 1024 * 1024;
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

/** Tras inferencia remota (Quill Cloud), cargo extra por volumen de tokens (`usage.total_tokens`). */
const INK_TOKENS_PER_SURCHARGE_UNIT = 6000;
const INK_MAX_TOKEN_SURCHARGE = 10;

function stripeSecret(isDebug?: boolean): string {
  if (isDebug) {
    return process.env.STRIPE_TEST_SECRET_KEY?.trim() || process.env.STRIPE_SECRET_KEY?.trim() || "";
  }
  return process.env.STRIPE_SECRET_KEY?.trim() ?? "";
}

function webhookSecret(isTest?: boolean): string {
  if (isTest) {
    return process.env.STRIPE_TEST_WEBHOOK_SECRET?.trim() || process.env.STRIPE_WEBHOOK_SECRET?.trim() || "";
  }
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

function openAiAudioTranscriptionsUrl(): string {
  return `${openAiBaseUrl()}/audio/transcriptions`;
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
  console.error("Quill Cloud inference HTTP error", status, raw.slice(0, 800));
  const quotaHint =
    "Esto viene del proveedor de inferencia de Quill Cloud (clave, cuota, facturación o modelo), no del saldo de gotas Folio en Firestore. Revisa la configuración de la función y los límites del proveedor.";
  if (status === 401 || status === 403 || status === 429) {
    throw new AiHttpsError(
      "failed-precondition",
      openAiMsg ? `${openAiMsg} ${quotaHint}` : quotaHint
    );
  }
  if (status === 400 || status === 404) {
    const hint =
      status === 404
        ? " Comprueba el modelo y la URL base configurados en la función."
        : "";
    throw new AiHttpsError(
      "failed-precondition",
      (openAiMsg || `Quill Cloud HTTP ${status}`) + hint
    );
  }
  throw new AiHttpsError(
    "internal",
    openAiMsg || "Quill Cloud devolvió un error. Inténtalo más tarde."
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
    message?: {
      content?: string | null;
      tool_calls?: Array<{
        id?: string;
        function?: { name?: string; arguments?: string };
      }>;
    };
    finish_reason?: string;
  }>;
  usage?: { total_tokens?: number };
  error?: { message?: string };
};

function parseOpenAiSuccessResponse(raw: string): {
  text: string;
  totalTokenCount?: number;
  toolCalls?: OpenAiToolCall[];
} {
  let json: OpenAiOkJson;
  try {
    json = JSON.parse(raw) as OpenAiOkJson;
  } catch {
    throw new AiHttpsError("internal", "Invalid AI response");
  }
  if (json.error?.message) {
    console.error("Quill Cloud API error object", json.error);
    throw new AiHttpsError("internal", "AI provider error");
  }
  const message = json.choices?.[0]?.message;
  const content = message?.content;
  const text = typeof content === "string" ? content : "";
  const toolCalls = normalizeOpenAiToolCalls(message?.tool_calls);

  if (!text.trim() && !toolCalls) {
    const reason = json.choices?.[0]?.finish_reason;
    console.warn("Quill Cloud empty model output", { reason });
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
  return { text: text.trim(), totalTokenCount, toolCalls };
}

/**
 * Inferencia Quill Cloud (chat completions; mismo path y cuerpo que APIs compatibles).
 */
async function callOpenAiGenerate(prompt: string): Promise<{
  text: string;
  totalTokenCount?: number;
}> {
  const key = openAiApiKey();
  if (!key) {
    throw new AiHttpsError(
      "failed-precondition",
      "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor)."
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
    "Quill Cloud: demasiados reintentos. Prueba más tarde."
  );
}

/** Tool call tal como lo devuelve/espera la API de chat completions de OpenAI. */
type OpenAiToolCall = {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
};

type OpenAiChatMessage = {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
  /** Solo `role: "assistant"` cuando el turno anterior invocó una o más tools. */
  tool_calls?: OpenAiToolCall[];
  /** Solo `role: "tool"`: id de la tool call cuyo resultado transporta este mensaje. */
  tool_call_id?: string;
};

function normalizeOpenAiRole(raw: unknown): OpenAiChatMessage["role"] | null {
  const r = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (r === "system" || r === "user" || r === "assistant" || r === "tool") return r;
  return null;
}

function normalizeOpenAiToolCalls(raw: unknown): OpenAiToolCall[] | undefined {
  if (!Array.isArray(raw)) return undefined;
  const out: OpenAiToolCall[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const c = item as {
      id?: unknown;
      function?: { name?: unknown; arguments?: unknown };
    };
    const id = typeof c.id === "string" ? c.id.trim() : "";
    const name = typeof c.function?.name === "string" ? c.function.name.trim() : "";
    const args = typeof c.function?.arguments === "string" ? c.function.arguments : "";
    if (!id || !name) continue;
    out.push({ id, type: "function", function: { name, arguments: args } });
  }
  return out.length > 0 ? out : undefined;
}

/**
 * A diferencia del resto de mensajes, los de `role: "assistant"` con
 * `tool_calls` pueden llevar `content` vacío (el modelo no dijo nada en
 * texto, solo pidió invocar una acción), y los de `role: "tool"` necesitan
 * `tool_call_id` para que el proveedor los empareje con la tool call que
 * responden — sin eso, la API de OpenAI rechaza la petición.
 */
function normalizeOpenAiMessages(raw: unknown): OpenAiChatMessage[] {
  if (!Array.isArray(raw)) return [];
  const out: OpenAiChatMessage[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const m = item as {
      role?: unknown;
      content?: unknown;
      tool_calls?: unknown;
      tool_call_id?: unknown;
    };
    const role = normalizeOpenAiRole(m.role);
    if (!role) continue;
    const content = typeof m.content === "string" ? m.content.trim() : "";

    if (role === "tool") {
      const toolCallId = typeof m.tool_call_id === "string" ? m.tool_call_id.trim() : "";
      if (!toolCallId || !content) continue;
      out.push({ role, content, tool_call_id: toolCallId });
      continue;
    }

    if (role === "assistant") {
      const toolCalls = normalizeOpenAiToolCalls(m.tool_calls);
      if (!content && !toolCalls) continue;
      out.push({ role, content, ...(toolCalls ? { tool_calls: toolCalls } : {}) });
      continue;
    }

    if (!content) continue;
    out.push({ role, content });
  }
  return out;
}

/** Tools declaradas por el cliente (mismo formato que OpenAI-compatible local). */
function normalizeOpenAiTools(raw: unknown): Array<Record<string, unknown>> | undefined {
  if (!Array.isArray(raw) || raw.length === 0) return undefined;
  const out: Array<Record<string, unknown>> = [];
  for (const item of raw) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const t = item as Record<string, unknown>;
    const fn = t.function as Record<string, unknown> | undefined;
    if (t.type !== "function" || !fn || typeof fn.name !== "string" || !fn.name.trim()) {
      continue;
    }
    out.push(t);
    // Límite defensivo: un catálogo desproporcionado infla el prompt y el
    // riesgo de abuso del endpoint más de lo que cualquier turno legítimo necesita.
    if (out.length >= 40) break;
  }
  return out.length > 0 ? out : undefined;
}

function normalizeOpenAiToolChoice(raw: unknown): "auto" | "none" | "required" | undefined {
  const v = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (v === "auto" || v === "none" || v === "required") return v;
  return undefined;
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
  // reforzamos compatibilidad con json_schema.strict del proveedor.
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
    // En strict json_schema, el proveedor exige que required incluya todas las keys de properties.
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
  tools?: Array<Record<string, unknown>>;
  toolChoice?: "auto" | "none" | "required";
}): Promise<{ text: string; totalTokenCount?: number; toolCalls?: OpenAiToolCall[] }> {
  const key = openAiApiKey();
  if (!key) {
    throw new AiHttpsError(
      "failed-precondition",
      "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor)."
    );
  }

  const systemPrompt = (input.systemPrompt ?? "").trim();
  const prompt = (input.prompt ?? "").trim();
  // No filtrar por `content` a secas: un turno `assistant` de solo tool-calls
  // tiene `content` vacío legítimamente (ya lo valida normalizeOpenAiMessages).
  const normalizedMsgs = (input.messages ?? []).filter(
    (m) => m.content.trim() || (m.tool_calls && m.tool_calls.length > 0)
  );

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

  if (input.tools && input.tools.length > 0) {
    body.tools = input.tools;
    body.tool_choice = input.toolChoice ?? "auto";
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
    "Quill Cloud: demasiados reintentos. Prueba más tarde."
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
  const pre = await ref.get();
  if (isFolioStaffUser((pre.data() ?? {}) as Record<string, unknown>)) {
    return 0;
  }
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
    tools?: Array<Record<string, unknown>>;
    toolChoice?: "auto" | "none" | "required";
  },
  operationKind: string
): Promise<{
  text: string;
  toolCalls?: OpenAiToolCall[];
  ink: { monthlyBalance: number; purchasedBalance: number };
  inkCharged: number;
  inkBaseCharged: number;
  inkTokenSurcharge: number;
}> {
  const baseCost = resolveInkCost(operationKind, promptLengthForInk(input));
  const ref = db.collection("users").doc(uid);

  const inkExhaustedMsg =
    "Insufficient ink. Buy an ink pack in Folio Cloud settings, wait for your monthly refill with an active subscription, or switch to a local AI provider (Ollama / LM Studio).";

  const preSnap = await ref.get();
  const preData = (preSnap.data() ?? {}) as Record<string, unknown>;
  if (isFolioStaffUser(preData)) {
    const { text, toolCalls } = await callOpenAiChatStructured(input);
    const finalSnap = await ref.get();
    const inkOut = readInkBalances(
      (finalSnap.data() ?? {}) as Record<string, unknown>
    );
    return {
      text,
      toolCalls,
      ink: {
        monthlyBalance: inkOut.monthly,
        purchasedBalance: inkOut.purchased,
      },
      inkCharged: 0,
      inkBaseCharged: 0,
      inkTokenSurcharge: 0,
    };
  }

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
    const { text, totalTokenCount, toolCalls } = await callOpenAiChatStructured(input);
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
      toolCalls,
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

function isEmulatorMode(isDebug?: boolean): boolean {
  return isDebug === true || process.env.FUNCTIONS_EMULATOR === "true";
}

function stripeClient(isDebug?: boolean): Stripe | null {
  const key = stripeSecret(isEmulatorMode(isDebug));
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

function priceFolioCloudMonthly(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_FOLIO_CLOUD_MONTHLY?.trim() || process.env.STRIPE_PRICE_FOLIO_CLOUD_MONTHLY?.trim() || "";
  }
  return process.env.STRIPE_PRICE_FOLIO_CLOUD_MONTHLY?.trim() ?? "";
}

function priceFolioCloudFamily(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_FOLIO_CLOUD_FAMILY?.trim() || process.env.STRIPE_PRICE_FOLIO_CLOUD_FAMILY?.trim() || "";
  }
  return process.env.STRIPE_PRICE_FOLIO_CLOUD_FAMILY?.trim() ?? "";
}

function priceFolioCloudFamilyMember(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_FOLIO_CLOUD_FAMILY_MEMBER?.trim() || process.env.STRIPE_PRICE_FOLIO_CLOUD_FAMILY_MEMBER?.trim() || "";
  }
  return process.env.STRIPE_PRICE_FOLIO_CLOUD_FAMILY_MEMBER?.trim() ?? "";
}

function priceFolioCloudStudent(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_FOLIO_CLOUD_STUDENT?.trim() || process.env.STRIPE_PRICE_FOLIO_CLOUD_STUDENT?.trim() || "";
  }
  return process.env.STRIPE_PRICE_FOLIO_CLOUD_STUDENT?.trim() ?? "";
}

function priceInkSmall(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_INK_SMALL?.trim() || process.env.STRIPE_PRICE_INK_SMALL?.trim() || "";
  }
  return process.env.STRIPE_PRICE_INK_SMALL?.trim() ?? "";
}

function priceInkMedium(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_INK_MEDIUM?.trim() || process.env.STRIPE_PRICE_INK_MEDIUM?.trim() || "";
  }
  return process.env.STRIPE_PRICE_INK_MEDIUM?.trim() ?? "";
}

function priceInkLarge(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_INK_LARGE?.trim() || process.env.STRIPE_PRICE_INK_LARGE?.trim() || "";
  }
  return process.env.STRIPE_PRICE_INK_LARGE?.trim() ?? "";
}

/** Precio Stripe recurrente (mensual) — librería pequeña: +20 GB. Hereda STRIPE_PRICE_BACKUP_STORAGE_PACK si no hay _SMALL. */
function priceBackupStoragePackSmall(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return (
      process.env.STRIPE_TEST_PRICE_BACKUP_STORAGE_PACK_SMALL?.trim() ||
      process.env.STRIPE_TEST_PRICE_BACKUP_STORAGE_PACK?.trim() ||
      process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_SMALL?.trim() ||
      process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK?.trim() ||
      ""
    );
  }
  return (
    process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_SMALL?.trim() ||
    process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK?.trim() ||
    ""
  );
}

function priceBackupStoragePackMedium(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_BACKUP_STORAGE_PACK_MEDIUM?.trim() || process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_MEDIUM?.trim() || "";
  }
  return process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_MEDIUM?.trim() ?? "";
}

function priceBackupStoragePackLarge(isDebug?: boolean): string {
  if (isEmulatorMode(isDebug)) {
    return process.env.STRIPE_TEST_PRICE_BACKUP_STORAGE_PACK_LARGE?.trim() || process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_LARGE?.trim() || "";
  }
  return process.env.STRIPE_PRICE_BACKUP_STORAGE_PACK_LARGE?.trim() ?? "";
}

/** 5 GiB base con suscripción Folio Cloud (backup). */
const FOLIO_BACKUP_BASE_QUOTA_BYTES = 5 * 1024 * 1024 * 1024;

/** 500 MiB base para cuentas free (copias + sync; sin tinta). */
const FREE_BACKUP_QUOTA_BYTES = 500 * 1024 * 1024;

/** Cuota efectiva para cuentas staff (`users/{uid}.folioStaff`): sin límite práctico en servidor. */
const FOLIO_STAFF_BACKUP_QUOTA_BYTES = Number.MAX_SAFE_INTEGER;

function isFolioStaffUser(data: Record<string, unknown>): boolean {
  return data.folioStaff === true;
}

/** Plan free explícito (`folioCloud.plan === "free"`). */
function isFolioCloudFreePlan(
  fc: Record<string, unknown> | undefined
): boolean {
  return fc?.plan === "free";
}

/**
 * Suscripción de pago (Stripe/MS/familia), no el free tier.
 * Docs legacy sin `plan` se tratan como de pago si `active` y status de suscripción real.
 */
function isFolioCloudPaidPlan(
  fc: Record<string, unknown> | undefined
): boolean {
  if (!fc || fc.active !== true) return false;
  if (fc.plan === "free") return false;
  if (fc.plan === "cloud") return true;
  const status = String(fc.subscriptionStatus ?? "");
  return (
    status === "active" || status === "trialing" || status === "past_due"
  );
}

const BACKUP_STORAGE_GRANT_SMALL_BYTES = 20 * 1024 * 1024 * 1024;
const BACKUP_STORAGE_GRANT_MEDIUM_BYTES = 75 * 1024 * 1024 * 1024;
const BACKUP_STORAGE_GRANT_LARGE_BYTES = 250 * 1024 * 1024 * 1024;

async function backupStorageBytesForPriceId(
  stripe: Stripe,
  priceId: string | undefined
): Promise<number> {
  if (!priceId) return 0;
  if (await catalogMatchesPrice(stripe, priceBackupStoragePackLarge(), priceId)) {
    return BACKUP_STORAGE_GRANT_LARGE_BYTES;
  }
  if (await catalogMatchesPrice(stripe, priceBackupStoragePackMedium(), priceId)) {
    return BACKUP_STORAGE_GRANT_MEDIUM_BYTES;
  }
  if (await catalogMatchesPrice(stripe, priceBackupStoragePackSmall(), priceId)) {
    return BACKUP_STORAGE_GRANT_SMALL_BYTES;
  }
  return 0;
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
  if (explicit && (await catalogMatchesPrice(stripe, explicit, priceId))) {
    return true;
  }
  const family = priceFolioCloudFamily();
  if (family && (await catalogMatchesPrice(stripe, family, priceId))) {
    return true;
  }
  const student = priceFolioCloudStudent();
  if (student && (await catalogMatchesPrice(stripe, student, priceId))) {
    return true;
  }
  const legacy = stripePriceIdsLegacy();
  return legacy.length > 0 && legacy.includes(priceId);
}

/** Suscripción Stripe que lleva el precio mensual Folio Cloud (no ampliaciones de copias). */
function pickFolioCloudMainSubscriptionFromList(
  list: Stripe.Subscription[],
  monthlyPriceId: string | null,
  studentPriceId: string | null
): Stripe.Subscription | undefined {
  const priority = ["active", "trialing", "past_due", "unpaid"] as const;
  const leg = stripePriceIdsLegacy();
  for (const st of priority) {
    const hit = list.find((s) => {
      if (s.status !== st) return false;
      return s.items.data.some((it) => {
        const pid = it.price?.id;
        if (!pid) return false;
        if (monthlyPriceId && pid === monthlyPriceId) return true;
        if (studentPriceId && pid === studentPriceId) return true;
        if (leg.length > 0 && leg.includes(pid)) return true;
        return false;
      });
    });
    if (hit) return hit;
  }
  return undefined;
}

async function findFolioCloudMainSubscription(
  stripe: Stripe,
  uid: string,
  customerId: string,
  initialList: Stripe.Subscription[]
): Promise<Stripe.Subscription | undefined> {
  let monthlyPriceId: string | null = null;
  const rawMonthly = priceFolioCloudMonthly();
  if (rawMonthly) {
    try {
      monthlyPriceId = await resolveCatalogIdToPriceId(stripe, rawMonthly);
    } catch {
      monthlyPriceId = null;
    }
  }

  let studentPriceId: string | null = null;
  const rawStudent = priceFolioCloudStudent();
  if (rawStudent) {
    try {
      studentPriceId = await resolveCatalogIdToPriceId(stripe, rawStudent);
    } catch {
      studentPriceId = null;
    }
  }

  let chosen = pickFolioCloudMainSubscriptionFromList(initialList, monthlyPriceId, studentPriceId);
  if (chosen) return chosen;
  const escapedUid = uid.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
  try {
    const byMeta = await stripe.subscriptions.search({
      query: `metadata['firebase_uid']:'${escapedUid}'`,
      limit: 20,
    });
    chosen = pickFolioCloudMainSubscriptionFromList(byMeta.data, monthlyPriceId, studentPriceId);
  } catch (e) {
    console.warn("findFolioCloudMainSubscription: search fallback failed", e);
  }
  return chosen;
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

/** Compras únicas (Stripe payment + Microsoft Store consumible); no incluye ampliaciones por suscripción. */
function folioBackupPurchasedField(data: Record<string, unknown>): number {
  const fb = data.folioBackup as Record<string, unknown> | undefined;
  const v = fb?.purchasedBytes;
  if (typeof v === "number" && Number.isFinite(v)) return Math.max(0, Math.trunc(v));
  return 0;
}

function folioBackupStripeSubscriptionExtraField(
  data: Record<string, unknown>
): number {
  const fb = data.folioBackup as Record<string, unknown> | undefined;
  const v = fb?.stripeSubscriptionExtraBytes;
  if (typeof v === "number" && Number.isFinite(v)) return Math.max(0, Math.trunc(v));
  return 0;
}

async function recomputeStripeBackupSubscriptionExtraBytes(
  stripe: Stripe,
  uid: string
): Promise<void> {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  const customerId = snap.get("stripeCustomerId") as string | undefined;
  if (!customerId?.trim()) {
    await ref.set(
      {
        folioBackup: {
          stripeSubscriptionExtraBytes: 0,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );
    await updateFolioBackupQuotaBytes(uid);
    return;
  }
  const okStatus = new Set(["active", "trialing", "past_due"]);
  const subs = await stripe.subscriptions.list({
    customer: customerId.trim(),
    status: "all",
    limit: 100,
  });
  let extra = 0;
  for (const sub of subs.data) {
    if (!okStatus.has(sub.status)) continue;
    for (const item of sub.items.data) {
      const pid = item.price?.id;
      if (!pid) continue;
      const b = await backupStorageBytesForPriceId(stripe, pid);
      if (b > 0) extra += b * (item.quantity ?? 1);
    }
  }
  await ref.set(
    {
      folioBackup: {
        stripeSubscriptionExtraBytes: extra,
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    { merge: true }
  );
  await updateFolioBackupQuotaBytes(uid);
}

function folioBackupUsedField(data: Record<string, unknown>): number {
  const fb = data.folioBackup as Record<string, unknown> | undefined;
  const v = fb?.usedBytes;
  if (typeof v === "number" && Number.isFinite(v)) return Math.max(0, Math.trunc(v));
  return 0;
}

/** Suma tamaños en Storage bajo users/{uid}/vaults/.../backups/ (ZIP/TAR legado). */
async function scanLegacyBackupArchiveBytes(uid: string): Promise<number> {
  const bucket = admin.storage().bucket();
  const prefix = `users/${uid}/vaults/`;
  const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
  let total = 0;
  for (const f of files) {
    const name = f.name;
    if (name.endsWith("/")) continue;
    if (!name.includes("/backups/")) continue;
    const lower = name.toLowerCase();
    if (
      !lower.endsWith(".tar.gz") &&
      !lower.endsWith(".tgz") &&
      !lower.endsWith(".zip")
    ) {
      continue;
    }
    const meta = f.metadata as Record<string, unknown> | undefined;
    const rawSize = meta?.size;
    const n =
      typeof rawSize === "number"
        ? rawSize
        : typeof rawSize === "string"
          ? Number(rawSize)
          : NaN;
    if (Number.isFinite(n) && n > 0) total += Math.trunc(n);
  }
  return total;
}

async function updateFolioBackupQuotaBytes(uid: string): Promise<void> {
  const ref = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    if (isFolioStaffUser(data)) {
      const purchased = folioBackupPurchasedField(data);
      const subExtra = folioBackupStripeSubscriptionExtraField(data);
      const used = folioBackupUsedField(data);
      tx.set(
        ref,
        {
          folioBackup: {
            purchasedBytes: purchased,
            usedBytes: used,
            quotaBytes: FOLIO_STAFF_BACKUP_QUOTA_BYTES,
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );
      return;
    }
    const fc = data.folioCloud as Record<string, unknown> | undefined;
    const features = fc?.features as Record<string, unknown> | undefined;
    const active = fc?.active === true;
    const backupOk = features?.backup === true;
    const purchased = folioBackupPurchasedField(data);
    const subExtra = folioBackupStripeSubscriptionExtraField(data);
    const used = folioBackupUsedField(data);

    const isStudent = fc?.isStudent === true;
    const freePlan = isFolioCloudFreePlan(fc);
    const baseQuota = freePlan
      ? FREE_BACKUP_QUOTA_BYTES
      : isStudent
        ? STUDENT_BACKUP_BASE_QUOTA_BYTES
        : FOLIO_BACKUP_BASE_QUOTA_BYTES;

    // Free: 500 MiB + compras únicas de almacenamiento; extras de suscripción solo en plan de pago.
    const quotaBytes =
      active && backupOk
        ? freePlan
          ? baseQuota + purchased
          : baseQuota + purchased + subExtra
        : 0;
    tx.set(
      ref,
      {
        folioBackup: {
          purchasedBytes: purchased,
          usedBytes: used,
          quotaBytes,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );
  });
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

/**
 * Fusiona `billing.stripe` + `billing.microsoftStore` en `folioCloud` y tinta mensual.
 * Sin Stripe en servidor: solo se considera el slice de Microsoft Store + legacy.
 */
async function recomputeEffectiveFolioCloud(uid: string): Promise<void> {
  const stripe = stripeClient();
  let email = "";
  try {
    const userRec = await admin.auth().getUser(uid);
    email = userRec.email ?? "";
  } catch (e) {
    // Ignorar
  }
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  const data = (snap.data() ?? {}) as Record<string, unknown>;
  const billing = (data.billing as Record<string, unknown>) ?? {};
  const stripeBilling = billing.stripe as Record<string, unknown> | undefined;
  const msBilling = billing.microsoftStore as Record<string, unknown> | undefined;

  const familyOwnerUid = data.familyOwnerUid as string | undefined;
  let ownerFc: any = null;
  if (familyOwnerUid) {
    const ownerSnap = await db.collection("users").doc(familyOwnerUid).get();
    if (ownerSnap.exists) {
      ownerFc = ownerSnap.data()?.folioCloud;
    }
  }

  let stripeStatus = "canceled";
  let stripePriceId: string | undefined;
  let stripeActiveFlag = false;
  let isFamily = false;
  let isStudent = false;

  if (familyOwnerUid) {
    stripeStatus = ownerFc?.subscriptionStatus ?? "canceled";
    stripePriceId = ownerFc?.subscriptionPriceId ?? undefined;
    // Solo heredar si el dueño tiene plan de pago (no free tier).
    const isFamilyMemberActive = isFolioCloudPaidPlan(
      ownerFc as Record<string, unknown> | undefined
    );
    stripeActiveFlag = isFamilyMemberActive;
    isFamily = true;
    isStudent = false;
  } else {
    if (stripeBilling) {
      stripeStatus = String(stripeBilling.subscriptionStatus ?? "canceled");
      const sp = stripeBilling.subscriptionPriceId;
      stripePriceId = typeof sp === "string" && sp ? sp : undefined;
      stripeActiveFlag = Boolean(stripeBilling.active);
    } else {
      const fc = data.folioCloud as Record<string, unknown> | undefined;
      if (fc) {
        stripeStatus = String(fc.subscriptionStatus ?? "canceled");
        const sp = fc.subscriptionPriceId;
        stripePriceId = typeof sp === "string" && sp ? sp : undefined;
        // No tratar plan free / status "free" como suscripción de pago.
        stripeActiveFlag =
          Boolean(fc.active) &&
          stripeStatus !== "canceled" &&
          stripeStatus !== "free" &&
          fc.plan !== "free";
      }
    }
  }

  const msMonthlyActive = Boolean(msBilling?.subscriptionActive);

  if (!familyOwnerUid && stripe && stripePriceId && stripeActiveFlag) {
    isStudent = await catalogMatchesPrice(stripe, priceFolioCloudStudent(), stripePriceId);
  }

  let stripeFeatures = {
    backup: false,
    cloudAi: false,
    publishWeb: false,
    realtimeCollab: false,
  };
  if (stripe && stripePriceId && stripeActiveFlag) {
    stripeFeatures = await folioCloudFeaturesFromPriceId(stripe, stripePriceId);
  }
  const msFeatures = msMonthlyActive
    ? {
        backup: true,
        cloudAi: true,
        publishWeb: true,
        realtimeCollab: true,
      }
    : {
        backup: false,
        cloudAi: false,
        publishWeb: false,
        realtimeCollab: false,
      };
  const paidActive = stripeActiveFlag || msMonthlyActive;
  let features = {
    backup: stripeFeatures.backup || msFeatures.backup,
    cloudAi: stripeFeatures.cloudAi || msFeatures.cloudAi,
    publishWeb: stripeFeatures.publishWeb || msFeatures.publishWeb,
    realtimeCollab:
      stripeFeatures.realtimeCollab || msFeatures.realtimeCollab,
  };

  let folioActive = paidActive;
  let folioPlan: "free" | "cloud" = "cloud";
  let subscriptionStatus = stripeStatus;
  if (
    msMonthlyActive &&
    (!stripeActiveFlag || stripeStatus === "canceled")
  ) {
    subscriptionStatus = "active";
  }

  if (!paidActive) {
    // Free tier: copias + sync (backup), 0 tinta, sin IA ni publishWeb.
    folioActive = true;
    folioPlan = "free";
    subscriptionStatus = "free";
    features = {
      backup: true,
      cloudAi: false,
      publishWeb: false,
      realtimeCollab: false,
    };
  } else {
    folioPlan = "cloud";
  }

  let stripeMonthlyActive = false;
  if (stripeActiveFlag && stripe && stripePriceId) {
    stripeMonthlyActive = await isMonthlySubscriptionPrice(stripe, stripePriceId);
  }
  const needsMonthlyInk = stripeMonthlyActive || msMonthlyActive;

  let familySeats = 0;
  if (familyOwnerUid) {
    familySeats = Number(ownerFc?.familySeats ?? 0);
  } else {
    familySeats = Number(stripeBilling?.familySeats ?? 0);
  }

  isFamily = !!familyOwnerUid || (familySeats > 0);
  const studentVerified = Boolean(stripeBilling?.studentVerified || billing?.studentVerified);

  const setPayload: any = {
    folioCloud: {
      subscriptionStatus,
      active: folioActive,
      plan: folioPlan,
      features,
      subscriptionPriceId: stripePriceId ?? null,
      isFamily,
      isStudent,
      studentVerified,
      familyOwnerUid: familyOwnerUid ?? null,
      familySeats,
      updatedAt: FieldValue.serverTimestamp(),
    },
  };
  if (email) {
    setPayload.email = email;
  }

  await ref.set(setPayload, { merge: true });

  if (needsMonthlyInk) {
    const currentPeriodKey = monthPeriodKeyEuropeMadrid();

    const FieldPath = admin.firestore.FieldPath;
    const deleteDotted: Record<string, unknown> = {
      [new FieldPath("ink.monthlyBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.purchasedBalance") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.monthlyPeriodKey") as unknown as string]:
        FieldValue.delete(),
      [new FieldPath("ink.updatedAt") as unknown as string]: FieldValue.delete(),
    };

    await db.runTransaction(async (tx) => {
      const txSnap = await tx.get(ref);
      const txData = (txSnap.data() ?? {}) as Record<string, unknown>;
      const inkRaw = (txData.ink as Record<string, unknown>) ?? {};
      const existingMonthly = inkBalanceField(inkRaw.monthlyBalance);
      const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);

      const dottedMonthly = inkBalanceField(txData["ink.monthlyBalance"]);
      const dottedPurchased = inkBalanceField(txData["ink.purchasedBalance"]);

      const monthlyBalance = Math.max(existingMonthly, dottedMonthly);
      const purchasedBalance = Math.max(existingPurchased, dottedPurchased);

      const rawKey =
        typeof inkRaw.monthlyPeriodKey === "string"
          ? inkRaw.monthlyPeriodKey.trim()
          : "";
      const dottedKey =
        typeof txData["ink.monthlyPeriodKey"] === "string"
          ? String(txData["ink.monthlyPeriodKey"]).trim()
          : "";
      const existingPeriodKey = rawKey || dottedKey;

      const shouldRefill =
        !existingPeriodKey || existingPeriodKey !== currentPeriodKey;

      const refillAllowance = isStudent ? STUDENT_INK_ALLOWANCE : MONTHLY_INK_ALLOWANCE;

      tx.set(
        ref,
        {
          ink: {
            monthlyBalance: shouldRefill ? refillAllowance : monthlyBalance,
            purchasedBalance,
            monthlyPeriodKey: currentPeriodKey,
            updatedAt: FieldValue.serverTimestamp(),
          },
          ...deleteDotted,
        },
        { merge: true }
      );
    });

    let subIndexPrice: string | null =
      stripeMonthlyActive ? (stripePriceId ?? null) : null;
    if (stripeMonthlyActive && stripe && !subIndexPrice) {
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
        microsoftStoreMonthly: msMonthlyActive,
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
      const txSnap = await tx.get(ref);
      const txData = (txSnap.data() ?? {}) as Record<string, unknown>;
      const inkRaw = (txData.ink as Record<string, unknown>) ?? {};
      const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
      const dottedPurchased = inkBalanceField(txData["ink.purchasedBalance"]);
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

  await updateFolioBackupQuotaBytes(uid);

  // Si es dueño del plan familiar, actualiza recursivamente los derechos de los miembros
  if (isFamily && !familyOwnerUid) {
    const familySnap = await db.collection("families").doc(uid).get();
    if (familySnap.exists) {
      const members = (familySnap.data()?.members as string[]) ?? [];
      for (const memberUid of members) {
        await recomputeEffectiveFolioCloud(memberUid);
      }
    }
  }
}

async function syncSubscriptionToUser(
  stripe: Stripe,
  uid: string,
  status: string,
  priceId: string | undefined,
  subObj?: Stripe.Subscription
): Promise<void> {
  const active =
    status === "active" || status === "trialing" || status === "past_due";

  let familySeats = 0;
  if (active) {
    let sub = subObj;
    if (!sub) {
      const ref = db.collection("users").doc(uid);
      const snap = await ref.get();
      const customerId = snap.get("stripeCustomerId") as string | undefined;
      if (customerId?.trim()) {
        const subs = await stripe.subscriptions.list({
          customer: customerId.trim(),
          status: "active",
          limit: 100,
        });
        sub = subs.data.find((s) =>
          s.items.data.some((it) => it.price?.id === priceId)
        );
      }
    }

    if (sub) {
      const seatPriceId = priceFolioCloudFamilyMember();
      const seatItem = sub.items.data.find(
        (item) => item.price?.id === seatPriceId
      );
      if (seatItem) {
        familySeats = Math.min(10, seatItem.quantity ?? 0);
      }
    }
  }

  const ref = db.collection("users").doc(uid);
  await ref.set(
    {
      billing: {
        stripe: {
          subscriptionStatus: status,
          subscriptionPriceId: priceId ?? null,
          active,
          familySeats,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
    },
    { merge: true }
  );
  await recomputeEffectiveFolioCloud(uid);
}

async function grantMicrosoftStoreConsumableInk(
  uid: string,
  grants: { dedupKey: string; drops: number }[]
): Promise<void> {
  for (const g of grants) {
    if (g.drops <= 0) continue;
    // Global doc id: a single real-world Store purchase can only ever be
    // claimed once across ALL Folio accounts, not just once per account.
    const globalDocId = createHash("sha256").update(g.dedupKey).digest("hex").slice(0, 64);
    // Legacy per-uid doc id (pre-fix): kept so purchases already credited
    // under the old scheme are never re-credited during migration.
    const legacyDocId = createHash("sha256")
      .update(`${uid}:${g.dedupKey}`)
      .digest("hex")
      .slice(0, 64);
    const globalRef = db.collection("microsoftStoreProcessedPurchases").doc(globalDocId);
    const legacyRef = db.collection("microsoftStoreProcessedPurchases").doc(legacyDocId);
    await db.runTransaction(async (tx) => {
      const [globalSnap, legacySnap] = await Promise.all([tx.get(globalRef), tx.get(legacyRef)]);
      if (globalSnap.exists) return; // already claimed globally, by this uid or another
      if (legacySnap.exists) {
        // Already credited pre-migration under the old per-uid key: backfill
        // the global marker so no account can double-claim it going
        // forward, without incrementing the balance again.
        tx.set(globalRef, {
          uid,
          dedupKey: g.dedupKey,
          drops: g.drops,
          processedAt: FieldValue.serverTimestamp(),
          migratedFromLegacy: true,
        });
        return;
      }
      tx.set(globalRef, {
        uid,
        dedupKey: g.dedupKey,
        drops: g.drops,
        processedAt: FieldValue.serverTimestamp(),
      });
      const uref = db.collection("users").doc(uid);
      tx.set(
        uref,
        {
          "ink.purchasedBalance": FieldValue.increment(g.drops),
          "ink.updatedAt": FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  }
}

async function grantMicrosoftStoreBackupStorage(
  uid: string,
  grants: { dedupKey: string; bytes: number }[]
): Promise<void> {
  for (const g of grants) {
    if (g.bytes <= 0) continue;
    const globalDocId = createHash("sha256")
      .update(`${g.dedupKey}:foliobackup`)
      .digest("hex")
      .slice(0, 64);
    const legacyDocId = createHash("sha256")
      .update(`${uid}:${g.dedupKey}:foliobackup`)
      .digest("hex")
      .slice(0, 64);
    const globalRef = db.collection("microsoftStoreProcessedBackupGrants").doc(globalDocId);
    const legacyRef = db.collection("microsoftStoreProcessedBackupGrants").doc(legacyDocId);
    await db.runTransaction(async (tx) => {
      const [globalSnap, legacySnap] = await Promise.all([tx.get(globalRef), tx.get(legacyRef)]);
      if (globalSnap.exists) return;
      if (legacySnap.exists) {
        tx.set(globalRef, {
          uid,
          dedupKey: g.dedupKey,
          bytes: g.bytes,
          processedAt: FieldValue.serverTimestamp(),
          migratedFromLegacy: true,
        });
        return;
      }
      tx.set(globalRef, {
        uid,
        dedupKey: g.dedupKey,
        bytes: g.bytes,
        processedAt: FieldValue.serverTimestamp(),
      });
      const uref = db.collection("users").doc(uid);
      tx.set(
        uref,
        {
          "folioBackup.purchasedBytes": FieldValue.increment(g.bytes),
          "folioBackup.updatedAt": FieldValue.serverTimestamp(),
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
  let totalBackupBytes = 0;
  for (const item of lineItems) {
    const priceObj = item.price;
    const linePriceId = typeof priceObj === "string" ? priceObj : priceObj?.id;
    const drops = await inkDropsForPriceId(stripe, linePriceId);
    if (drops > 0) totalAdded += drops * (item.quantity ?? 1);
    const b = await backupStorageBytesForPriceId(stripe, linePriceId);
    if (b > 0) totalBackupBytes += b * (item.quantity ?? 1);
  }

  const batch = db.batch();
  const userRef = db.collection("users").doc(uid);
  if (totalAdded > 0) {
    batch.set(
      userRef,
      {
        "ink.purchasedBalance": FieldValue.increment(totalAdded),
        "ink.updatedAt": FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  if (totalBackupBytes > 0) {
    batch.set(
      userRef,
      {
        "folioBackup.purchasedBytes": FieldValue.increment(totalBackupBytes),
        "folioBackup.updatedAt": FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  batch.set(doneRef, {
    uid,
    dropsAdded: totalAdded,
    backupBytesAdded: totalBackupBytes,
    processedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  if (totalBackupBytes > 0) {
    await updateFolioBackupQuotaBytes(uid);
  }
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
    const isMainMonthly = await isMonthlySubscriptionPrice(stripe, priceId);
    const backupTier = await backupStorageBytesForPriceId(stripe, priceId);
    if (isMainMonthly) {
      await syncSubscriptionToUser(stripe, uid, sub.status, priceId, sub);
    } else if (backupTier > 0) {
      await recomputeStripeBackupSubscriptionExtraBytes(stripe, uid);
    } else {
      console.warn(
        "checkout.session.completed: subscription price is neither Folio Cloud monthly nor backup add-on",
        priceId
      );
      await recomputeStripeBackupSubscriptionExtraBytes(stripe, uid);
    }
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
    let stripe = stripeClient();
    let whSecret = webhookSecret();
    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).send("Missing stripe-signature");
      return;
    }
    const rawBody = (req as { rawBody?: Buffer }).rawBody;
    if (!rawBody) {
      res.status(400).send("Missing raw body");
      return;
    }
    let event: Stripe.Event;
    try {
      if (!stripe || !whSecret) {
        throw new Error("Missing config");
      }
      event = stripe.webhooks.constructEvent(rawBody, sig, whSecret);
    } catch (err) {
      const testStripe = stripeClient(true);
      const testWhSecret = webhookSecret(true);
      if (testStripe && testWhSecret && (testStripe !== stripe || testWhSecret !== whSecret)) {
        try {
          event = testStripe.webhooks.constructEvent(rawBody, sig, testWhSecret);
          stripe = testStripe;
          console.log("Stripe webhook: verified signature using test secret key/webhook secret");
        } catch (testErr) {
          console.error("Webhook signature verification failed for both live and test secrets", err, testErr);
          res.status(400).send("Invalid signature");
          return;
        }
      } else {
        console.error("Webhook signature verification failed", err);
        res.status(400).send("Invalid signature");
        return;
      }
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
          const subUid = sub.metadata?.firebase_uid?.trim();
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
          const statusForBilling =
            event.type === "customer.subscription.deleted"
              ? "canceled"
              : sub.status;
          const isMain = await isMonthlySubscriptionPrice(stripe, priceId);
          if (isMain) {
            await syncSubscriptionToUser(
              stripe,
              subUid,
              statusForBilling,
              priceId,
              sub
            );
          }
          await recomputeStripeBackupSubscriptionExtraBytes(stripe, subUid);
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
  | "folio_family_monthly"
  | "folio_student_monthly"
  | "ink_small"
  | "ink_medium"
  | "ink_large"
  | "backup_storage_pack_small"
  | "backup_storage_pack_medium"
  | "backup_storage_pack_large";

/** Misma condición que Storage rules `folioCloudBackupOk` (copias en la nube). */
async function assertFolioCloudBackupAllowed(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() ?? {};
  if (isFolioStaffUser(data as Record<string, unknown>)) {
    return;
  }
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
  if (isFolioStaffUser(data as Record<string, unknown>)) {
    return;
  }
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

const COLLAB_JOIN_CODE_DIGITS = 6;
const COLLAB_JOIN_MAX_ATTEMPTS = 8;
const COLLAB_JOIN_WINDOW_MS = 5 * 60 * 1000;

function generateCollabJoinCode(): string {
  // CSPRNG (crypto.randomInt), no Math.random(): este código deriva la clave
  // AES de la sala vía HKDF, así que necesita entropía impredecible además de
  // espacio de búsqueda suficiente (2 emojis de 15 + 6 dígitos ≈ 225M combinaciones).
  const pick = () =>
    COLLAB_JOIN_EMOJIS[randomInt(COLLAB_JOIN_EMOJIS.length)] ?? "\u{2B50}";
  const a = pick();
  const b = pick();
  const n = String(randomInt(10 ** COLLAB_JOIN_CODE_DIGITS)).padStart(
    COLLAB_JOIN_CODE_DIGITS,
    "0"
  );
  return `${a}${b}${n}`;
}

// Limita intentos de adivinar el código de unión por uid autenticado, ya que
// el código deriva la clave E2E de la sala (no solo permiso de lectura).
async function checkAndRecordCollabJoinAttempt(uid: string): Promise<void> {
  const ref = db.collection("collabJoinAttempts").doc(uid);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() ?? {} : {};
    const windowStart = (data.windowStart as number | undefined) ?? 0;
    const count = (data.count as number | undefined) ?? 0;
    if (now - windowStart > COLLAB_JOIN_WINDOW_MS) {
      tx.set(ref, { windowStart: now, count: 1 });
      return;
    }
    if (count >= COLLAB_JOIN_MAX_ATTEMPTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many join code attempts. Try again later."
      );
    }
    tx.set(ref, { windowStart, count: count + 1 }, { merge: true });
  });
}

async function clearCollabJoinAttempts(uid: string): Promise<void> {
  await db.collection("collabJoinAttempts").doc(uid).delete().catch(() => {});
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
  await assertFolioRealtimeCollabAllowed(uid);
  await checkAndRecordCollabJoinAttempt(uid);

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
  await clearCollabJoinAttempts(uid);
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

function isStudentEmail(email: string): boolean {
  const domain = email.split("@").pop()?.toLowerCase() ?? "";
  if (/\.edu(\.[a-z]{2})?$/i.test(domain)) {
    return true;
  }

  const spanishUniversities = new Set([
    "uji.es", "uoc.edu", "upc.edu", "ub.edu", "uam.es", "uc3m.es", "upv.es",
    "uv.es", "ua.es", "um.es", "us.es", "uma.es", "unizar.es", "ehu.eus",
    "ehu.es", "uab.cat", "uab.es", "urjc.es", "ucm.es", "upf.edu", "uah.es",
    "ull.es", "unican.es", "unovi.es", "usal.es", "uva.es", "udc.es", "usc.es",
    "uvigo.es", "unex.es", "uca.es", "uco.es", "ugr.es", "uhu.es", "ujaen.es",
    "ual.es", "uclm.es", "unirioja.es", "upct.es", "upna.es", "udl.cat",
    "udl.es", "urv.cat", "urv.es", "udg.edu", "udg.es", "uib.es", "uib.cat",
    "uned.es"
  ]);

  if (spanishUniversities.has(domain)) {
    return true;
  }
  for (const uni of spanishUniversities) {
    if (domain.endsWith("." + uni)) {
      return true;
    }
  }

  return false;
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
    const isDebug = request.data?.debug === true;
    const stripe = stripeClient(isDebug);
    if (!stripe) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe not configured on server"
      );
    }
    const uid = request.auth.uid;
    let kindRaw = (request.data?.kind as string) ?? "folio_cloud_monthly";
    if (kindRaw === "backup_storage_pack") {
      kindRaw = "backup_storage_pack_small";
    }
    const kind = kindRaw as CheckoutKind;

    if (kind === "folio_student_monthly") {
      const userRef = db.collection("users").doc(uid);
      const userSnap = await userRef.get();
      const userData = userSnap.data() ?? {};
      const billing = userData.billing as Record<string, unknown> | undefined;
      const studentVerified = billing?.studentVerified === true;
      const email = request.auth.token.email as string | undefined;
      const isStudent = studentVerified || (email && isStudentEmail(email));
      if (!isStudent) {
        throw new HttpsError(
          "failed-precondition",
          "Para contratar la suscripción de estudiantes debes usar un correo de estudiante verificado."
        );
      }
    }

    const priceIdMap: Record<CheckoutKind, string> = {
      folio_cloud_monthly: priceFolioCloudMonthly(isDebug),
      folio_family_monthly: priceFolioCloudFamily(isDebug),
      folio_student_monthly: priceFolioCloudStudent(isDebug),
      ink_small: priceInkSmall(isDebug),
      ink_medium: priceInkMedium(isDebug),
      ink_large: priceInkLarge(isDebug),
      backup_storage_pack_small: priceBackupStoragePackSmall(isDebug),
      backup_storage_pack_medium: priceBackupStoragePackMedium(isDebug),
      backup_storage_pack_large: priceBackupStoragePackLarge(isDebug),
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
    const isSubscription =
      kind === "folio_cloud_monthly" ||
      kind === "folio_family_monthly" ||
      kind === "folio_student_monthly" ||
      kind === "backup_storage_pack_small" ||
      kind === "backup_storage_pack_medium" ||
      kind === "backup_storage_pack_large";
    let session: Stripe.Response<Stripe.Checkout.Session>;
    try {
      session = await stripe.checkout.sessions.create(
        {
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
          managed_payments: {
            enabled: true,
          },
        } as any,
        {
          apiVersion: "2025-03-31.basil" as any,
        }
      );
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
    const isDebug = request.data?.debug === true;
    const stripe = stripeClient(isDebug);
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
      limit: 100,
    });
    let chosen = await findFolioCloudMainSubscription(
      stripe,
      uid,
      customerId,
      subs.data
    );
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
      await syncSubscriptionToUser(stripe, uid, chosen.status, priceId, chosen);
      return { ok: true as const, status: chosen.status };
    }
    await syncSubscriptionToUser(stripe, uid, "canceled", undefined);
    return { ok: true as const, status: "canceled" as const };
  }
);

export const validateMicrosoftStoreEntitlements = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const collectionsId = String(
      (request.data as { collectionsId?: string })?.collectionsId ?? ""
    ).trim();
    if (!collectionsId) {
      throw new HttpsError("invalid-argument", "collectionsId is required");
    }
    if (!microsoftStoreValidationConfigured()) {
      throw new HttpsError(
        "failed-precondition",
        "Microsoft Store validation is not configured on the server."
      );
    }
    const uid = request.auth.uid;
    const items = await queryMicrosoftStoreUserCollection(collectionsId);
    const scan = scanMicrosoftStoreCollectionItems(items);
    await db.collection("users").doc(uid).set(
      {
        billing: {
          microsoftStore: {
            subscriptionActive: scan.subscriptionActive,
            subscriptionStoreProductId: scan.subscriptionStoreProductId,
            lastValidatedAt: FieldValue.serverTimestamp(),
            lastItemCount: items.length,
          },
        },
      },
      { merge: true }
    );
    await grantMicrosoftStoreConsumableInk(uid, scan.consumableGrants);
    await grantMicrosoftStoreBackupStorage(uid, scan.backupStorageGrants);
    await recomputeEffectiveFolioCloud(uid);
    return {
      ok: true as const,
      subscriptionActive: scan.subscriptionActive,
      storeItems: items.length,
    };
  }
);

function assertValidCloudPackBlobId(raw: unknown): string {
  const s = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (!/^[0-9a-f]{64}$/.test(s)) {
    throw new HttpsError("invalid-argument", "Invalid blobId");
  }
  return s;
}

function assertCloudPackSnapshotStoragePath(
  uid: string,
  vaultId: string,
  pathRaw: unknown
): string {
  const path = typeof pathRaw === "string" ? pathRaw.trim() : "";
  const prefix = `users/${uid}/vaults/${vaultId}/cloud-packs/snapshots/`;
  if (!path.startsWith(prefix) || path.includes("..")) {
    throw new HttpsError("invalid-argument", "Invalid snapshot storage path");
  }
  return path;
}

function parseCloudPackBlobSizeList(
  raw: unknown
): { blobId: string; sizeBytes: number }[] {
  if (!Array.isArray(raw)) return [];
  const out: { blobId: string; sizeBytes: number }[] = [];
  for (const x of raw) {
    if (x === null || typeof x !== "object") continue;
    const o = x as Record<string, unknown>;
    const blobId = assertValidCloudPackBlobId(o.blobId);
    const szRaw = o.sizeBytes;
    const sz =
      typeof szRaw === "number" && Number.isFinite(szRaw)
        ? Math.max(0, Math.trunc(szRaw))
        : 0;
    if (sz <= 0 || sz > 2 * 1024 * 1024 * 1024) continue;
    out.push({ blobId, sizeBytes: sz });
  }
  return out;
}

function effectiveBackupQuotaBytes(data: Record<string, unknown>): number {
  if (isFolioStaffUser(data)) {
    return FOLIO_STAFF_BACKUP_QUOTA_BYTES;
  }
  const fb = data.folioBackup as Record<string, unknown> | undefined;
  const q = fb?.quotaBytes;
  if (typeof q === "number" && Number.isFinite(q) && q >= 0) {
    return Math.trunc(q);
  }
  const fc = data.folioCloud as Record<string, unknown> | undefined;
  const features = fc?.features as Record<string, unknown> | undefined;
  if (fc?.active === true && features?.backup === true) {
    if (isFolioCloudFreePlan(fc)) {
      return FREE_BACKUP_QUOTA_BYTES + folioBackupPurchasedField(data);
    }
    const isStudent = fc?.isStudent === true;
    const base = isStudent
      ? STUDENT_BACKUP_BASE_QUOTA_BYTES
      : FOLIO_BACKUP_BASE_QUOTA_BYTES;
    return (
      base +
      folioBackupPurchasedField(data) +
      folioBackupStripeSubscriptionExtraField(data)
    );
  }
  return 0;
}

export const folioGetLatestCloudPackMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId)
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const wrapB64 =
      typeof data.cloudPackRestoreWrapB64 === "string"
        ? data.cloudPackRestoreWrapB64.trim()
        : "";
    const wrapKind = data.cloudPackRestoreWrapKind;
    const hasRestoreWrap =
      wrapB64.length > 0 &&
      (wrapKind === "vaultDek" || wrapKind === "packKey");
    return {
      ok: true as const,
      latest: {
        snapshotStoragePath:
          typeof data.latestCloudPackSnapshotPath === "string"
            ? data.latestCloudPackSnapshotPath
            : "",
        snapshotSizeBytes:
          typeof data.latestCloudPackSnapshotSizeBytes === "number"
            ? data.latestCloudPackSnapshotSizeBytes
            : 0,
        contentFingerprint:
          typeof data.latestCloudPackContentFingerprint === "string"
            ? data.latestCloudPackContentFingerprint
            : "",
        updatedAt: data.latestCloudPackUpdatedAt ?? null,
        hasRestoreWrap,
        wrapKind:
          wrapKind === "vaultDek" || wrapKind === "packKey" ? wrapKind : null,
      },
    };
  }
);

export const folioGetCloudPackRestoreWrap = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId)
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const wrapB64 =
      typeof data.cloudPackRestoreWrapB64 === "string"
        ? data.cloudPackRestoreWrapB64.trim()
        : "";
    const kind = data.cloudPackRestoreWrapKind;
    if (
      !wrapB64 ||
      (kind !== "vaultDek" && kind !== "packKey")
    ) {
      throw new HttpsError(
        "failed-precondition",
        "No hay envoltorio de recuperación para esta libreta. Sube una copia desde Folio con la contraseña indicada."
      );
    }
    return {
      ok: true as const,
      wrapB64,
      wrapKind: kind,
    };
  }
);

export const folioCheckCloudPackBlobsExist = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const rawIds = (request.data as any)?.blobIds;
    if (!Array.isArray(rawIds) || rawIds.length > 500) {
      throw new HttpsError("invalid-argument", "blobIds invalid");
    }
    const bucket = admin.storage().bucket();
    const missing: string[] = [];
    for (const id of rawIds) {
      const bid = assertValidCloudPackBlobId(id);
      const name = `users/${uid}/vaults/${vaultId}/cloud-packs/blobs/${bid}`;
      const [exists] = await bucket.file(name).exists();
      if (!exists) missing.push(bid);
    }
    return { missing };
  }
);

export const folioFinalizeCloudPack = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const snapPath = assertCloudPackSnapshotStoragePath(
      uid,
      vaultId,
      (request.data as any)?.snapshotStoragePath
    );
    const snapSizeRaw = (request.data as any)?.snapshotSizeBytes;
    const snapSize =
      typeof snapSizeRaw === "number" && Number.isFinite(snapSizeRaw)
        ? Math.max(0, Math.trunc(snapSizeRaw))
        : 0;
    if (snapSize <= 0 || snapSize > 256 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "snapshotSizeBytes invalid");
    }
    const fpRaw = (request.data as any)?.contentFingerprint;
    const fingerprint =
      typeof fpRaw === "string" ? fpRaw.trim().toLowerCase() : "";
    if (!fingerprint || fingerprint.length > 200 || !/^[0-9a-f]+$/.test(fingerprint)) {
      throw new HttpsError("invalid-argument", "contentFingerprint invalid");
    }

    const oldPathRaw = (request.data as any)?.oldSnapshotStoragePath;
    let oldSnapSize = 0;
    if (typeof oldPathRaw === "string" && oldPathRaw.trim()) {
      const op = oldPathRaw.trim();
      const okPrefix = `users/${uid}/vaults/${vaultId}/cloud-packs/snapshots/`;
      if (!op.startsWith(okPrefix) || op.includes("..")) {
        throw new HttpsError("invalid-argument", "oldSnapshotStoragePath invalid");
      }
      const oldSzRaw = (request.data as any)?.oldSnapshotSizeBytes;
      oldSnapSize =
        typeof oldSzRaw === "number" && Number.isFinite(oldSzRaw)
          ? Math.max(0, Math.trunc(oldSzRaw))
          : 0;
    }

    const newBlobs = parseCloudPackBlobSizeList((request.data as any)?.newBlobs);
    const deleteBlobs = parseCloudPackBlobSizeList((request.data as any)?.deleteBlobs);
    if (newBlobs.length > 2000 || deleteBlobs.length > 2000) {
      throw new HttpsError("invalid-argument", "Too many blob entries");
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const udata = (userSnap.data() ?? {}) as Record<string, unknown>;
    let used = folioBackupUsedField(udata);
    const quota = effectiveBackupQuotaBytes(udata);
    const legacyBytes = await scanLegacyBackupArchiveBytes(uid);

    const wrapB64Raw = (request.data as any)?.cloudPackRestoreWrapB64;
    const wrapKindRaw = (request.data as any)?.cloudPackRestoreWrapKind;
    let restoreWrapB64: string | null = null;
    let restoreWrapKind: "vaultDek" | "packKey" | null = null;
    if (wrapB64Raw != null && String(wrapB64Raw).trim() !== "") {
      if (wrapKindRaw !== "vaultDek" && wrapKindRaw !== "packKey") {
        throw new HttpsError(
          "invalid-argument",
          "cloudPackRestoreWrapKind must be vaultDek or packKey"
        );
      }
      const s = String(wrapB64Raw).trim();
      let buf: Buffer;
      try {
        buf = Buffer.from(s, "base64");
      } catch {
        throw new HttpsError("invalid-argument", "cloudPackRestoreWrapB64 invalid base64");
      }
      if (buf.length < 44 || buf.length > 4096) {
        throw new HttpsError("invalid-argument", "cloudPackRestoreWrapB64 size invalid");
      }
      restoreWrapB64 = s;
      restoreWrapKind = wrapKindRaw;
    }

    let delta = snapSize - oldSnapSize;
    for (const b of newBlobs) delta += b.sizeBytes;
    for (const b of deleteBlobs) delta -= b.sizeBytes;
    const newUsed = Math.max(0, used + delta);

    if (quota > 0 && newUsed + legacyBytes > quota) {
      throw new HttpsError(
        "resource-exhausted",
        "Se superó la cuota de almacenamiento de copias en la nube."
      );
    }

    const bucket = admin.storage().bucket();
    const [fileMeta] = await bucket.file(snapPath).getMetadata();
    const rawSz = (fileMeta as { size?: string | number }).size;
    const metaSize =
      typeof rawSz === "number"
        ? rawSz
        : typeof rawSz === "string"
          ? Number(rawSz)
          : 0;
    if (!Number.isFinite(metaSize) || metaSize <= 0 || Math.abs(metaSize - snapSize) > 16) {
      throw new HttpsError(
        "failed-precondition",
        "Snapshot not found in storage or size mismatch."
      );
    }

    await userRef.update({
      "folioBackup.usedBytes": newUsed,
      "folioBackup.updatedAt": FieldValue.serverTimestamp(),
    });

    const vaultBackupRef = db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId);
    const vaultPatch: Record<string, unknown> = {
      latestCloudPackSnapshotPath: snapPath,
      latestCloudPackSnapshotSizeBytes: snapSize,
      latestCloudPackContentFingerprint: fingerprint.slice(0, 200),
      latestCloudPackUpdatedAt: FieldValue.serverTimestamp(),
    };
    if (restoreWrapB64 != null && restoreWrapKind != null) {
      vaultPatch.cloudPackRestoreWrapB64 = restoreWrapB64;
      vaultPatch.cloudPackRestoreWrapKind = restoreWrapKind;
    }
    await vaultBackupRef.set(vaultPatch, { merge: true });

    return {
      ok: true as const,
      usedBytes: newUsed,
      quotaBytes: quota,
      legacyBytes,
      totalUsedBytes: newUsed + legacyBytes,
    };
  }
);

// Secreto por cuenta+libreta, generado una sola vez (get-or-create) y
// mezclado en la derivación de la clave de device-sync de libretas "en
// claro" (sin contraseña) — ver DeviceSyncKeyCache.plainPackKey en el
// cliente. Sin esto, esa clave era recalculable solo con uid+vaultId, que
// ya son parte de la propia ruta de Storage/Firestore.
export const folioEnsurePlainVaultSyncSecret = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const ref = db
      .collection("users")
      .doc(uid)
      .collection("plainVaultSyncSecrets")
      .doc(vaultId);
    const secretB64 = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const existing = snap.data()?.secret;
      if (typeof existing === "string" && existing.length > 0) {
        return existing;
      }
      const generated = randomBytes(32).toString("base64");
      tx.set(ref, {
        secret: generated,
        createdAt: FieldValue.serverTimestamp(),
      });
      return generated;
    });
    return { ok: true as const, secret: secretB64 };
  }
);

export const folioGetDeviceSyncMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultSync")
      .doc(vaultId)
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const formatVersion =
      typeof data.syncFormatVersion === "number" &&
      Number.isFinite(data.syncFormatVersion)
        ? Math.trunc(data.syncFormatVersion as number)
        : 1;
    return {
      ok: true as const,
      rev: typeof data.rev === "number" ? data.rev : 0,
      contentFingerprint:
        typeof data.contentFingerprint === "string"
          ? data.contentFingerprint
          : "",
      packStoragePath:
        typeof data.packStoragePath === "string" ? data.packStoragePath : "",
      packSizeBytes:
        typeof data.packSizeBytes === "number" ? data.packSizeBytes : 0,
      syncFormatVersion: formatVersion,
      manifestStoragePath:
        typeof data.manifestStoragePath === "string"
          ? data.manifestStoragePath
          : "",
      manifestSizeBytes:
        typeof data.manifestSizeBytes === "number"
          ? data.manifestSizeBytes
          : 0,
      deviceId: typeof data.deviceId === "string" ? data.deviceId : "",
      deviceName: typeof data.deviceName === "string" ? data.deviceName : "",
      displayName:
        typeof data.displayName === "string" ? data.displayName : "",
      vaultMode: typeof data.vaultMode === "string" ? data.vaultMode : "",
      packKeyKind:
        typeof data.packKeyKind === "string" ? data.packKeyKind : "",
      dekAccountWrapB64:
        typeof data.dekAccountWrapB64 === "string"
          ? data.dekAccountWrapB64
          : "",
      updatedAt: data.updatedAt ?? null,
    };
  }
);

function assertDeviceSyncPackStoragePath(
  uid: string,
  vaultId: string,
  raw: unknown
): string {
  const path = typeof raw === "string" ? raw.trim() : "";
  const prefix = `users/${uid}/vaults/${vaultId}/device-sync/packs/`;
  if (!path.startsWith(prefix) || path.includes("..") || !path.endsWith(".bin")) {
    throw new HttpsError("invalid-argument", "packStoragePath invalid");
  }
  if (path.length > 512) {
    throw new HttpsError("invalid-argument", "packStoragePath too long");
  }
  return path;
}

function assertDeviceSyncManifestStoragePath(
  uid: string,
  vaultId: string,
  raw: unknown
): string {
  const path = typeof raw === "string" ? raw.trim() : "";
  const prefix = `users/${uid}/vaults/${vaultId}/device-sync/manifests/`;
  if (!path.startsWith(prefix) || path.includes("..") || !path.endsWith(".bin")) {
    throw new HttpsError("invalid-argument", "manifestStoragePath invalid");
  }
  if (path.length > 512) {
    throw new HttpsError("invalid-argument", "manifestStoragePath too long");
  }
  return path;
}

export const folioFinalizeDeviceSync = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);

    const formatRaw = (request.data as any)?.syncFormatVersion;
    const syncFormatVersion =
      typeof formatRaw === "number" && Number.isFinite(formatRaw)
        ? Math.max(1, Math.trunc(formatRaw))
        : 1;
    const isV2 = syncFormatVersion >= 2;

    const fpRaw = (request.data as any)?.contentFingerprint;
    const fingerprint = typeof fpRaw === "string" ? fpRaw.trim() : "";
    if (!fingerprint || fingerprint.length > 200 || !/^[0-9a-f]+$/i.test(fingerprint)) {
      throw new HttpsError("invalid-argument", "contentFingerprint invalid");
    }
    const deviceIdRaw = (request.data as any)?.deviceId;
    const deviceId =
      typeof deviceIdRaw === "string" ? deviceIdRaw.trim().slice(0, 128) : "";
    const deviceNameRaw = (request.data as any)?.deviceName;
    const deviceName =
      typeof deviceNameRaw === "string"
        ? deviceNameRaw.trim().slice(0, 120)
        : "";

    let packPath = "";
    let packSize = 0;
    let manifestPath = "";
    let manifestSize = 0;
    let oldPackPath = "";
    let oldPackSize = 0;
    let oldManifestPath = "";
    let oldManifestSize = 0;

    if (isV2) {
      manifestPath = assertDeviceSyncManifestStoragePath(
        uid,
        vaultId,
        (request.data as any)?.manifestStoragePath
      );
      const manifestSizeRaw = (request.data as any)?.manifestSizeBytes;
      manifestSize =
        typeof manifestSizeRaw === "number" && Number.isFinite(manifestSizeRaw)
          ? Math.max(0, Math.trunc(manifestSizeRaw))
          : 0;
      if (manifestSize <= 0 || manifestSize > 16 * 1024 * 1024) {
        throw new HttpsError("invalid-argument", "manifestSizeBytes invalid");
      }
    } else {
      packPath = assertDeviceSyncPackStoragePath(
        uid,
        vaultId,
        (request.data as any)?.packStoragePath
      );
      const packSizeRaw = (request.data as any)?.packSizeBytes;
      packSize =
        typeof packSizeRaw === "number" && Number.isFinite(packSizeRaw)
          ? Math.max(0, Math.trunc(packSizeRaw))
          : 0;
      if (packSize <= 0 || packSize > 80 * 1024 * 1024) {
        throw new HttpsError("invalid-argument", "packSizeBytes invalid");
      }
    }

    // Rutas "old*" son solo para cuota/cleanup: si vienen de otra libreta o
    // están corruptas, ignorarlas (no tumbar el finalize del pack nuevo).
    const oldPathRaw = (request.data as any)?.oldPackStoragePath;
    if (typeof oldPathRaw === "string" && oldPathRaw.trim()) {
      try {
        oldPackPath = assertDeviceSyncPackStoragePath(uid, vaultId, oldPathRaw);
        const oldSzRaw = (request.data as any)?.oldPackSizeBytes;
        oldPackSize =
          typeof oldSzRaw === "number" && Number.isFinite(oldSzRaw)
            ? Math.max(0, Math.trunc(oldSzRaw))
            : 0;
      } catch {
        oldPackPath = "";
        oldPackSize = 0;
      }
    }
    const oldManifestRaw = (request.data as any)?.oldManifestStoragePath;
    if (typeof oldManifestRaw === "string" && oldManifestRaw.trim()) {
      try {
        oldManifestPath = assertDeviceSyncManifestStoragePath(
          uid,
          vaultId,
          oldManifestRaw
        );
        const oldMzRaw = (request.data as any)?.oldManifestSizeBytes;
        oldManifestSize =
          typeof oldMzRaw === "number" && Number.isFinite(oldMzRaw)
            ? Math.max(0, Math.trunc(oldMzRaw))
            : 0;
      } catch {
        oldManifestPath = "";
        oldManifestSize = 0;
      }
    }

    const newBlobs = parseCloudPackBlobSizeList((request.data as any)?.newBlobs);
    const deleteBlobs = parseCloudPackBlobSizeList(
      (request.data as any)?.deleteBlobs
    );
    if (newBlobs.length > 2000 || deleteBlobs.length > 2000) {
      throw new HttpsError("invalid-argument", "Too many blob entries");
    }

    const userRef = db.collection("users").doc(uid);
    const syncRef = userRef.collection("vaultSync").doc(vaultId);
    const bucket = admin.storage().bucket();

    const primaryPath = isV2 ? manifestPath : packPath;
    const primarySize = isV2 ? manifestSize : packSize;
    const [fileMeta] = await bucket.file(primaryPath).getMetadata();
    const rawSz = (fileMeta as { size?: string | number }).size;
    const metaSize =
      typeof rawSz === "number"
        ? rawSz
        : typeof rawSz === "string"
          ? Number(rawSz)
          : 0;
    if (
      !Number.isFinite(metaSize) ||
      metaSize <= 0 ||
      Math.abs(metaSize - primarySize) > 16
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Sync pack/manifest not found in storage or size mismatch."
      );
    }

    const legacyBytes = await scanLegacyBackupArchiveBytes(uid);

    const { newUsed, quota, newRev } = await db.runTransaction(async (tx) => {
      const [userSnap, prevSync] = await Promise.all([
        tx.get(userRef),
        tx.get(syncRef),
      ]);
      const udata = (userSnap.data() ?? {}) as Record<string, unknown>;
      const used = folioBackupUsedField(udata);
      const quota = effectiveBackupQuotaBytes(udata);
      let delta = primarySize - (isV2 ? oldManifestSize : oldPackSize);
      // Migración v1→v2: restar pack monolítico antiguo.
      if (isV2 && oldPackSize > 0) delta -= oldPackSize;
      for (const b of newBlobs) delta += b.sizeBytes;
      for (const b of deleteBlobs) delta -= b.sizeBytes;
      const newUsed = Math.max(0, used + delta);
      if (quota > 0 && newUsed + legacyBytes > quota) {
        throw new HttpsError(
          "resource-exhausted",
          "Se superó la cuota de almacenamiento de copias en la nube."
        );
      }
      const prevRev =
        typeof prevSync.data()?.rev === "number"
          ? Math.trunc(prevSync.data()!.rev as number)
          : 0;
      const newRev = prevRev + 1;

      tx.update(userRef, {
        "folioBackup.usedBytes": newUsed,
        "folioBackup.updatedAt": FieldValue.serverTimestamp(),
      });

      const patch: Record<string, unknown> = {
        rev: newRev,
        contentFingerprint: fingerprint.slice(0, 200).toLowerCase(),
        deviceId,
        deviceName,
        syncFormatVersion: isV2 ? 2 : 1,
        updatedAt: FieldValue.serverTimestamp(),
      };
      const displayNameRaw = (request.data as any)?.displayName;
      if (typeof displayNameRaw === "string" && displayNameRaw.trim()) {
        patch.displayName = displayNameRaw.trim().slice(0, 120);
      }
      const vaultModeRaw = (request.data as any)?.vaultMode;
      if (
        typeof vaultModeRaw === "string" &&
        (vaultModeRaw.trim() === "plain" || vaultModeRaw.trim() === "encrypted")
      ) {
        patch.vaultMode = vaultModeRaw.trim();
      }
      const packKeyKindRaw = (request.data as any)?.packKeyKind;
      if (
        typeof packKeyKindRaw === "string" &&
        (packKeyKindRaw.trim() === "account" ||
          packKeyKindRaw.trim() === "vault")
      ) {
        patch.packKeyKind = packKeyKindRaw.trim();
      }
      const dekWrapRaw = (request.data as any)?.dekAccountWrapB64;
      if (typeof dekWrapRaw === "string" && dekWrapRaw.trim()) {
        const w = dekWrapRaw.trim();
        // Límite razonable (~4 KiB) para DEK envuelta.
        if (w.length <= 8192) {
          patch.dekAccountWrapB64 = w;
        }
      }
      if (isV2) {
        patch.manifestStoragePath = manifestPath;
        patch.manifestSizeBytes = manifestSize;
        patch.packStoragePath = "";
        patch.packSizeBytes = 0;
      } else {
        patch.packStoragePath = packPath;
        patch.packSizeBytes = packSize;
      }
      tx.set(syncRef, patch, { merge: true });
      return { newUsed, quota, newRev };
    });

    if (oldPackPath && oldPackPath !== packPath) {
      try {
        await bucket.file(oldPackPath).delete({ ignoreNotFound: true });
      } catch {
        // ignore
      }
    }
    if (oldManifestPath && oldManifestPath !== manifestPath) {
      try {
        await bucket.file(oldManifestPath).delete({ ignoreNotFound: true });
      } catch {
        // ignore
      }
    }

    return {
      ok: true as const,
      rev: newRev,
      usedBytes: newUsed,
      quotaBytes: quota,
      totalUsedBytes: newUsed + legacyBytes,
      syncFormatVersion: isV2 ? 2 : 1,
    };
  }
);

export const folioListDeviceSyncVaults = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultSync")
      .get();
    const vaults = snap.docs.map((d) => {
      const data = (d.data() ?? {}) as Record<string, unknown>;
      const pack =
        typeof data.packStoragePath === "string"
          ? data.packStoragePath.trim()
          : "";
      const manifest =
        typeof data.manifestStoragePath === "string"
          ? data.manifestStoragePath.trim()
          : "";
      const fp =
        typeof data.contentFingerprint === "string"
          ? data.contentFingerprint.trim()
          : "";
      return {
        vaultId: d.id,
        displayName:
          typeof data.displayName === "string" ? data.displayName.trim() : "",
        vaultMode:
          typeof data.vaultMode === "string" ? data.vaultMode.trim() : "",
        rev: typeof data.rev === "number" ? Math.trunc(data.rev) : 0,
        contentFingerprint: fp,
        hasCloudPack: fp.length > 0 && (pack.length > 0 || manifest.length > 0),
      };
    });
    vaults.sort((a, b) => a.vaultId.localeCompare(b.vaultId));
    return { vaults };
  }
);

function assertAppProfilePackPath(uid: string, raw: unknown): string {
  const path = typeof raw === "string" ? raw.trim() : "";
  const prefix = `users/${uid}/app-profile/packs/`;
  if (!path.startsWith(prefix) || path.includes("..") || !path.endsWith(".bin")) {
    throw new HttpsError("invalid-argument", "packStoragePath invalid");
  }
  if (path.length > 512) {
    throw new HttpsError("invalid-argument", "packStoragePath too long");
  }
  return path;
}

function assertVaultProfilePackPath(
  uid: string,
  vaultId: string,
  raw: unknown
): string {
  const path = typeof raw === "string" ? raw.trim() : "";
  const prefix = `users/${uid}/vault-profiles/${vaultId}/packs/`;
  if (!path.startsWith(prefix) || path.includes("..") || !path.endsWith(".bin")) {
    throw new HttpsError("invalid-argument", "packStoragePath invalid");
  }
  if (path.length > 512) {
    throw new HttpsError("invalid-argument", "packStoragePath too long");
  }
  return path;
}

export const folioGetAppProfileMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("appProfile")
      .doc("meta")
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const wrapB64 =
      typeof data.restoreWrapB64 === "string" ? data.restoreWrapB64.trim() : "";
    return {
      ok: true as const,
      rev: typeof data.rev === "number" ? data.rev : 0,
      contentFingerprint:
        typeof data.contentFingerprint === "string"
          ? data.contentFingerprint
          : "",
      packStoragePath:
        typeof data.packStoragePath === "string" ? data.packStoragePath : "",
      packSizeBytes:
        typeof data.packSizeBytes === "number" ? data.packSizeBytes : 0,
      hasRestoreWrap: wrapB64.length > 0,
      iconIds: Array.isArray(data.iconIds) ? data.iconIds : [],
      updatedAt: data.updatedAt ?? null,
    };
  }
);

export const folioGetAppProfileRestoreWrap = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("appProfile")
      .doc("meta")
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const wrapB64 =
      typeof data.restoreWrapB64 === "string" ? data.restoreWrapB64.trim() : "";
    return {
      ok: true as const,
      restoreWrapB64: wrapB64,
    };
  }
);

export const folioFinalizeAppProfile = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const packPath = assertAppProfilePackPath(
      uid,
      (request.data as any)?.packStoragePath
    );
    const packSizeRaw = (request.data as any)?.packSizeBytes;
    const packSize =
      typeof packSizeRaw === "number" && Number.isFinite(packSizeRaw)
        ? Math.max(0, Math.trunc(packSizeRaw))
        : 0;
    if (packSize <= 0 || packSize > 16 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "packSizeBytes invalid");
    }
    const fpRaw = (request.data as any)?.contentFingerprint;
    const fingerprint =
      typeof fpRaw === "string" ? fpRaw.trim().toLowerCase() : "";
    if (!fingerprint || fingerprint.length > 200 || !/^[0-9a-f]+$/i.test(fingerprint)) {
      throw new HttpsError("invalid-argument", "contentFingerprint invalid");
    }
    const iconIdsRaw = (request.data as any)?.iconIds;
    const iconIds: string[] = [];
    if (Array.isArray(iconIdsRaw)) {
      for (const id of iconIdsRaw) {
        if (typeof id !== "string") continue;
        const t = id.trim();
        if (t && t.length <= 128 && !t.includes("/") && !t.includes("..")) {
          iconIds.push(t);
        }
      }
    }
    if (iconIds.length > 500) {
      throw new HttpsError("invalid-argument", "Too many iconIds");
    }

    let oldPackSize = 0;
    let oldPackPath = "";
    const oldPathRaw = (request.data as any)?.oldPackStoragePath;
    if (typeof oldPathRaw === "string" && oldPathRaw.trim()) {
      oldPackPath = assertAppProfilePackPath(uid, oldPathRaw);
      const oldSzRaw = (request.data as any)?.oldPackSizeBytes;
      oldPackSize =
        typeof oldSzRaw === "number" && Number.isFinite(oldSzRaw)
          ? Math.max(0, Math.trunc(oldSzRaw))
          : 0;
    }

    const wrapB64Raw = (request.data as any)?.restoreWrapB64;
    let restoreWrapB64: string | null = null;
    if (wrapB64Raw != null && String(wrapB64Raw).trim() !== "") {
      const s = String(wrapB64Raw).trim();
      let buf: Buffer;
      try {
        buf = Buffer.from(s, "base64");
      } catch {
        throw new HttpsError("invalid-argument", "restoreWrapB64 invalid");
      }
      if (buf.length < 44 || buf.length > 4096) {
        throw new HttpsError("invalid-argument", "restoreWrapB64 size invalid");
      }
      restoreWrapB64 = s;
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const udata = (userSnap.data() ?? {}) as Record<string, unknown>;
    let used = folioBackupUsedField(udata);
    const quota = effectiveBackupQuotaBytes(udata);
    const legacyBytes = await scanLegacyBackupArchiveBytes(uid);
    const delta = packSize - oldPackSize;
    const newUsed = Math.max(0, used + delta);
    if (quota > 0 && newUsed + legacyBytes > quota) {
      throw new HttpsError(
        "resource-exhausted",
        "Se superó la cuota de almacenamiento de copias en la nube."
      );
    }

    const bucket = admin.storage().bucket();
    const [fileMeta] = await bucket.file(packPath).getMetadata();
    const rawSz = (fileMeta as { size?: string | number }).size;
    const metaSize =
      typeof rawSz === "number"
        ? rawSz
        : typeof rawSz === "string"
          ? Number(rawSz)
          : 0;
    if (!Number.isFinite(metaSize) || metaSize <= 0 || Math.abs(metaSize - packSize) > 16) {
      throw new HttpsError(
        "failed-precondition",
        "App profile pack not found or size mismatch."
      );
    }

    const metaRef = userRef.collection("appProfile").doc("meta");
    const prev = await metaRef.get();
    const prevRev =
      typeof prev.data()?.rev === "number"
        ? Math.trunc(prev.data()!.rev as number)
        : 0;

    await userRef.update({
      "folioBackup.usedBytes": newUsed,
      "folioBackup.updatedAt": FieldValue.serverTimestamp(),
    });

    const patch: Record<string, unknown> = {
      rev: prevRev + 1,
      contentFingerprint: fingerprint.slice(0, 200),
      packStoragePath: packPath,
      packSizeBytes: packSize,
      iconIds,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (restoreWrapB64 != null) {
      patch.restoreWrapB64 = restoreWrapB64;
    }
    await metaRef.set(patch, { merge: true });

    if (oldPackPath && oldPackPath !== packPath) {
      try {
        await bucket.file(oldPackPath).delete({ ignoreNotFound: true });
      } catch {
        // ignore
      }
    }

    return {
      ok: true as const,
      rev: prevRev + 1,
      usedBytes: newUsed,
      quotaBytes: quota,
      totalUsedBytes: newUsed + legacyBytes,
    };
  }
);

export const folioGetVaultProfileMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultProfiles")
      .doc(vaultId)
      .get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    return {
      ok: true as const,
      rev: typeof data.rev === "number" ? data.rev : 0,
      contentFingerprint:
        typeof data.contentFingerprint === "string"
          ? data.contentFingerprint
          : "",
      packStoragePath:
        typeof data.packStoragePath === "string" ? data.packStoragePath : "",
      packSizeBytes:
        typeof data.packSizeBytes === "number" ? data.packSizeBytes : 0,
      hasRestoreWrap:
        typeof data.restoreWrapB64 === "string" &&
        (data.restoreWrapB64 as string).trim().length > 0,
      updatedAt: data.updatedAt ?? null,
    };
  }
);

export const folioFinalizeVaultProfile = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const packPath = assertVaultProfilePackPath(
      uid,
      vaultId,
      (request.data as any)?.packStoragePath
    );
    const packSizeRaw = (request.data as any)?.packSizeBytes;
    const packSize =
      typeof packSizeRaw === "number" && Number.isFinite(packSizeRaw)
        ? Math.max(0, Math.trunc(packSizeRaw))
        : 0;
    if (packSize <= 0 || packSize > 8 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "packSizeBytes invalid");
    }
    const fpRaw = (request.data as any)?.contentFingerprint;
    const fingerprint =
      typeof fpRaw === "string" ? fpRaw.trim().toLowerCase() : "";
    if (!fingerprint || fingerprint.length > 200 || !/^[0-9a-f]+$/i.test(fingerprint)) {
      throw new HttpsError("invalid-argument", "contentFingerprint invalid");
    }

    let oldPackSize = 0;
    let oldPackPath = "";
    const oldPathRaw = (request.data as any)?.oldPackStoragePath;
    if (typeof oldPathRaw === "string" && oldPathRaw.trim()) {
      oldPackPath = assertVaultProfilePackPath(uid, vaultId, oldPathRaw);
      const oldSzRaw = (request.data as any)?.oldPackSizeBytes;
      oldPackSize =
        typeof oldSzRaw === "number" && Number.isFinite(oldSzRaw)
          ? Math.max(0, Math.trunc(oldSzRaw))
          : 0;
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const udata = (userSnap.data() ?? {}) as Record<string, unknown>;
    let used = folioBackupUsedField(udata);
    const quota = effectiveBackupQuotaBytes(udata);
    const legacyBytes = await scanLegacyBackupArchiveBytes(uid);
    const delta = packSize - oldPackSize;
    const newUsed = Math.max(0, used + delta);
    if (quota > 0 && newUsed + legacyBytes > quota) {
      throw new HttpsError(
        "resource-exhausted",
        "Se superó la cuota de almacenamiento de copias en la nube."
      );
    }

    const bucket = admin.storage().bucket();
    const [fileMeta] = await bucket.file(packPath).getMetadata();
    const rawSz = (fileMeta as { size?: string | number }).size;
    const metaSize =
      typeof rawSz === "number"
        ? rawSz
        : typeof rawSz === "string"
          ? Number(rawSz)
          : 0;
    if (!Number.isFinite(metaSize) || metaSize <= 0 || Math.abs(metaSize - packSize) > 16) {
      throw new HttpsError(
        "failed-precondition",
        "Vault profile pack not found or size mismatch."
      );
    }

    const metaRef = userRef.collection("vaultProfiles").doc(vaultId);
    const prev = await metaRef.get();
    const prevRev =
      typeof prev.data()?.rev === "number"
        ? Math.trunc(prev.data()!.rev as number)
        : 0;

    await userRef.update({
      "folioBackup.usedBytes": newUsed,
      "folioBackup.updatedAt": FieldValue.serverTimestamp(),
    });

    await metaRef.set(
      {
        rev: prevRev + 1,
        contentFingerprint: fingerprint.slice(0, 200),
        packStoragePath: packPath,
        packSizeBytes: packSize,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (oldPackPath && oldPackPath !== packPath) {
      try {
        await bucket.file(oldPackPath).delete({ ignoreNotFound: true });
      } catch {
        // ignore
      }
    }

    return {
      ok: true as const,
      rev: prevRev + 1,
      usedBytes: newUsed,
      quotaBytes: quota,
      totalUsedBytes: newUsed + legacyBytes,
    };
  }
);

export const folioGetBackupStorageUsage = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const snap = await db.collection("users").doc(uid).get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const usedCloud = folioBackupUsedField(data);
    const legacyBytes = await scanLegacyBackupArchiveBytes(uid);
    const fc = data.folioCloud as Record<string, unknown> | undefined;
    const freePlan = isFolioCloudFreePlan(fc);
    const isStudent = fc?.isStudent === true;
    const baseQuotaBytes = freePlan
      ? FREE_BACKUP_QUOTA_BYTES
      : isStudent
        ? STUDENT_BACKUP_BASE_QUOTA_BYTES
        : FOLIO_BACKUP_BASE_QUOTA_BYTES;
    return {
      ok: true as const,
      usedBytes: usedCloud + legacyBytes,
      cloudPackUsedBytes: usedCloud,
      legacyBackupBytes: legacyBytes,
      quotaBytes: effectiveBackupQuotaBytes(data),
      purchasedBytes: folioBackupPurchasedField(data),
      subscriptionExtraBytes: folioBackupStripeSubscriptionExtraField(data),
      baseQuotaBytes,
      plan: freePlan ? "free" : "cloud",
    };
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
        const meta = (f.metadata ?? {}) as Record<string, unknown>;
        const rawSize = meta["size"];
        const sizeBytes =
          typeof rawSize === "number"
            ? rawSize
            : typeof rawSize === "string"
              ? Number(rawSize)
              : 0;
        const timeCreated =
          typeof meta["timeCreated"] === "string" ? meta["timeCreated"] : "";
        const parts = f.name.split("/");
        const fileName = parts[parts.length - 1] ?? f.name;
        return {
          fileName,
          storagePath: f.name,
          sizeBytes: Number.isFinite(sizeBytes) && sizeBytes > 0 ? sizeBytes : 0,
          createdAt: timeCreated,
        };
      })
      .filter((x) => x.fileName.length > 0);
    items.sort((a, b) => b.fileName.localeCompare(a.fileName));

    const vSnap = await db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId)
      .get();
    const vd = (vSnap.data() ?? {}) as Record<string, unknown>;
    const cpPath =
      typeof vd.latestCloudPackSnapshotPath === "string"
        ? vd.latestCloudPackSnapshotPath.trim()
        : "";
    let cloudPack: Record<string, unknown> | null = null;
    if (cpPath) {
      const fn = cpPath.split("/").pop() ?? "snap.bin";
      const sz =
        typeof vd.latestCloudPackSnapshotSizeBytes === "number"
          ? vd.latestCloudPackSnapshotSizeBytes
          : 0;
      const upd = vd.latestCloudPackUpdatedAt;
      let createdAt = "";
      if (upd instanceof admin.firestore.Timestamp) {
        createdAt = upd.toDate().toISOString();
      }
      cloudPack = {
        fileName: fn,
        storagePath: cpPath,
        sizeBytes: sz,
        createdAt,
        isCloudPack: true,
      };
    }

    return { items, cloudPack };
  }
);

function storageObjectSizeBytes(f: {
  metadata?: Record<string, unknown>;
}): number {
  const meta = (f.metadata ?? {}) as Record<string, unknown>;
  const raw = meta["size"];
  const n =
    typeof raw === "number" ? raw : typeof raw === "string" ? Number(raw) : 0;
  return Number.isFinite(n) && n > 0 ? n : 0;
}

/** Borra Storage + índice + meta Firestore de una libreta sin copias. */
async function purgeVaultCloudBackupPresence(
  uid: string,
  vaultId: string
): Promise<{ freedBytes: number; failed: string[] }> {
  const bucket = admin.storage().bucket();
  const vaultPrefix = `users/${uid}/vaults/${vaultId}/`;
  const [allFiles] = await bucket.getFiles({
    prefix: vaultPrefix,
    autoPaginate: true,
  });
  const files = allFiles.filter((f) => !f.name.endsWith("/"));
  let freedBytes = 0;
  const failed: string[] = [];
  for (const f of files) {
    freedBytes += storageObjectSizeBytes(f);
    try {
      await f.delete();
    } catch (e: unknown) {
      console.warn("purgeVaultCloudBackupPresence: delete failed", f.name, e);
      failed.push(f.name);
    }
  }

  const userRef = db.collection("users").doc(uid);
  const vaultBackupRef = userRef.collection("vaultBackups").doc(vaultId);
  try {
    const itemsSnap = await vaultBackupRef.collection("items").get();
    const batch = db.batch();
    for (const d of itemsSnap.docs) {
      batch.delete(d.ref);
    }
    batch.delete(vaultBackupRef);
    batch.delete(userRef.collection("vaultBackupIndex").doc(vaultId));
    await batch.commit();
  } catch (e: unknown) {
    console.warn(
      "purgeVaultCloudBackupPresence: firestore purge failed",
      vaultId,
      e
    );
  }

  return { freedBytes, failed };
}

async function vaultCloudBackupHasRemainingFiles(
  uid: string,
  vaultId: string
): Promise<boolean> {
  const bucket = admin.storage().bucket();
  for (const sub of ["backups/", "cloud-packs/"] as const) {
    const prefix = `users/${uid}/vaults/${vaultId}/${sub}`;
    const [files] = await bucket.getFiles({
      prefix,
      autoPaginate: false,
      maxResults: 5,
    });
    if (files.some((f) => !f.name.endsWith("/"))) return true;
  }
  return false;
}

/** Borra el cloud-pack (blobs + snapshots) de una libreta y ajusta la cuota. */
export const folioDeleteVaultCloudPack = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);

    const packPrefix = `users/${uid}/vaults/${vaultId}/cloud-packs/`;
    const bucket = admin.storage().bucket();
    const [packFiles] = await bucket.getFiles({
      prefix: packPrefix,
      autoPaginate: true,
    });
    const files = packFiles.filter((f) => !f.name.endsWith("/"));

    let freedBytes = 0;
    const errors: string[] = [];
    for (const f of files) {
      freedBytes += storageObjectSizeBytes(f);
      try {
        await f.delete();
      } catch (e: unknown) {
        console.warn("folioDeleteVaultCloudPack: delete failed", f.name, e);
        errors.push(f.name);
      }
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const udata = (userSnap.data() ?? {}) as Record<string, unknown>;
    let used = folioBackupUsedField(udata);
    let newUsed = Math.max(0, used - freedBytes);
    await userRef.update({
      "folioBackup.usedBytes": newUsed,
      "folioBackup.updatedAt": FieldValue.serverTimestamp(),
    });

    const vaultBackupRef = userRef.collection("vaultBackups").doc(vaultId);
    await vaultBackupRef.set(
      {
        latestCloudPackSnapshotPath: FieldValue.delete(),
        latestCloudPackSnapshotSizeBytes: FieldValue.delete(),
        latestCloudPackContentFingerprint: FieldValue.delete(),
        latestCloudPackUpdatedAt: FieldValue.delete(),
        cloudPackRestoreWrapB64: FieldValue.delete(),
        cloudPackRestoreWrapKind: FieldValue.delete(),
      },
      { merge: true }
    );

    let vaultRemoved = false;
    if (errors.length === 0) {
      const stillHas = await vaultCloudBackupHasRemainingFiles(uid, vaultId);
      if (!stillHas) {
        const purged = await purgeVaultCloudBackupPresence(uid, vaultId);
        // Los bytes del cloud-pack ya se restaron; el purge solo limpia restos (cuota legacy no usa usedBytes).
        errors.push(...purged.failed);
        vaultRemoved = purged.failed.length === 0;
        const refreshed = await userRef.get();
        newUsed = folioBackupUsedField(
          (refreshed.data() ?? {}) as Record<string, unknown>
        );
      }
    }

    return {
      ok: errors.length === 0,
      freedBytes,
      usedBytes: newUsed,
      deletedFiles: files.length - errors.length,
      vaultRemoved,
      failed: errors.slice(0, 10),
    };
  }
);

/**
 * Borra un archivo legacy (ZIP/TAR.GZ) de copias. Si la libreta se queda sin
 * copias, elimina la presencia completa de esa libreta en Folio Cloud.
 */
export const folioDeleteVaultLegacyBackup = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const storagePathRaw = (request.data as any)?.storagePath;
    const storagePath =
      typeof storagePathRaw === "string" ? storagePathRaw.trim() : "";
    const okPrefix = `users/${uid}/vaults/${vaultId}/backups/`;
    if (
      !storagePath ||
      !storagePath.startsWith(okPrefix) ||
      storagePath.includes("..") ||
      storagePath.endsWith("/")
    ) {
      throw new HttpsError("invalid-argument", "storagePath invalid");
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (exists) {
      try {
        await file.delete();
      } catch (e: unknown) {
        console.warn("folioDeleteVaultLegacyBackup: delete failed", storagePath, e);
        throw new HttpsError("internal", "Failed to delete backup file");
      }
    }

    const fileName = storagePath.split("/").pop() ?? "";
    const userRef = db.collection("users").doc(uid);
    const vaultBackupRef = userRef.collection("vaultBackups").doc(vaultId);
    if (fileName) {
      try {
        await vaultBackupRef.collection("items").doc(fileName).delete();
      } catch (_) {
        // ignore missing item meta
      }
    }

    const vaultSnap = await vaultBackupRef.get();
    const vd = (vaultSnap.data() ?? {}) as Record<string, unknown>;
    if (
      typeof vd.latestStoragePath === "string" &&
      vd.latestStoragePath.trim() === storagePath
    ) {
      await vaultBackupRef.set(
        {
          latestFileName: FieldValue.delete(),
          latestStoragePath: FieldValue.delete(),
          latestFingerprint: FieldValue.delete(),
          latestContainerFormat: FieldValue.delete(),
          latestSizeBytes: FieldValue.delete(),
          latestUpdatedAt: FieldValue.delete(),
        },
        { merge: true }
      );
    }

    let vaultRemoved = false;
    const stillHas = await vaultCloudBackupHasRemainingFiles(uid, vaultId);
    if (!stillHas) {
      const purged = await purgeVaultCloudBackupPresence(uid, vaultId);
      if (purged.failed.length === 0) {
        vaultRemoved = true;
      }
      // Si había cloud-pack residual rarísimo, restar cuota.
      if (purged.freedBytes > 0) {
        const userSnap = await userRef.get();
        const used = folioBackupUsedField(
          (userSnap.data() ?? {}) as Record<string, unknown>
        );
        await userRef.update({
          "folioBackup.usedBytes": Math.max(0, used - purged.freedBytes),
          "folioBackup.updatedAt": FieldValue.serverTimestamp(),
        });
      }
    }

    return { ok: true as const, vaultRemoved };
  }
);

export const folioTrimVaultBackupsByBytes = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const maxBytesRaw = (request.data as any)?.maxBytes;
    const maxBytes =
      typeof maxBytesRaw === "number" && Number.isFinite(maxBytesRaw)
        ? Math.max(1, Math.min(50 * 1024 * 1024 * 1024, Math.trunc(maxBytesRaw)))
        : 5 * 1024 * 1024 * 1024; // default 5 GB

    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files.filter((f) => !f.name.endsWith("/"));

    const sizeOf = (f: any): number => {
      const meta = (f?.metadata ?? {}) as Record<string, unknown>;
      const raw = meta["size"];
      const n =
        typeof raw === "number" ? raw : typeof raw === "string" ? Number(raw) : 0;
      return Number.isFinite(n) && n > 0 ? n : 0;
    };

    // Oldest first by name (timestamps in filename sort lexicographically).
    items.sort((a, b) => a.name.localeCompare(b.name));

    let totalBytes = 0;
    for (const f of items) totalBytes += sizeOf(f);

    const toDelete: typeof items = [];
    for (const f of items) {
      if (totalBytes <= maxBytes) break;
      const sz = sizeOf(f);
      toDelete.push(f);
      totalBytes -= sz;
    }

    let deleted = 0;
    const errors: string[] = [];
    for (const f of toDelete) {
      try {
        await f.delete();
        deleted++;
      } catch (e: unknown) {
        console.warn("folioTrimVaultBackupsByBytes: delete failed", f.name, e);
        errors.push(f.name);
      }
    }
    return {
      ok: errors.length === 0,
      deleted,
      remainingBytes: Math.max(0, totalBytes),
      failed: errors.slice(0, 10),
    };
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

    const userRef = db.collection("users").doc(uid);
    const [indexSnap, vaultBackupsSnap] = await Promise.all([
      userRef.collection("vaultBackupIndex").get(),
      userRef.collection("vaultBackups").get(),
    ]);
    const nameById = new Map<string, string>();
    for (const d of indexSnap.docs) {
      const data = d.data() as Record<string, unknown>;
      const name =
        typeof data.displayName === "string" ? data.displayName.trim() : "";
      if (name) nameById.set(d.id, name);
    }
    // Solo libretas con copias reales (legacy backups/ o cloud-pack).
    // Excluye las que solo tienen device-sync/ u otras carpetas no-backup.
    const hasCloudPackMeta = new Set<string>();
    for (const d of vaultBackupsSnap.docs) {
      const data = d.data() as Record<string, unknown>;
      const cp =
        typeof data.latestCloudPackSnapshotPath === "string"
          ? data.latestCloudPackSnapshotPath.trim()
          : "";
      if (cp) hasCloudPackMeta.add(d.id);
    }
    const withRealBackups = (
      await Promise.all(
        vaultIds.map(async (id) => {
          if (hasCloudPackMeta.has(id)) return id;
          if (await vaultCloudBackupHasRemainingFiles(uid, id)) return id;
          return null;
        })
      )
    ).filter((id): id is string => id != null);

    const vaults = withRealBackups.map((id) => ({
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

export const folioGetLatestVaultBackupMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const ref = db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId);
    const snap = await ref.get();
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    return {
      ok: true as const,
      latest: {
        storagePath:
          typeof data.latestStoragePath === "string" ? data.latestStoragePath : "",
        fileName: typeof data.latestFileName === "string" ? data.latestFileName : "",
        fingerprint:
          typeof data.latestFingerprint === "string" ? data.latestFingerprint : "",
        sizeBytes: typeof data.latestSizeBytes === "number" ? data.latestSizeBytes : 0,
        containerFormat:
          typeof data.latestContainerFormat === "string"
            ? data.latestContainerFormat
            : "",
        updatedAt: data.latestUpdatedAt ?? null,
      },
    };
  }
);

export const folioRecordVaultBackupMeta = onCall(
  { cors: true, invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);

    const vaultId = assertValidVaultId((request.data as any)?.vaultId);
    const fileNameRaw = (request.data as any)?.fileName;
    const storagePathRaw = (request.data as any)?.storagePath;
    const fingerprintRaw = (request.data as any)?.fingerprint;
    const sizeBytesRaw = (request.data as any)?.sizeBytes;
    const containerFormatRaw = (request.data as any)?.containerFormat;
    const vaultBytesRaw = (request.data as any)?.vaultBytes;
    const attachmentsBytesRaw = (request.data as any)?.attachmentsBytes;

    const fileName = typeof fileNameRaw === "string" ? fileNameRaw.trim() : "";
    const storagePath =
      typeof storagePathRaw === "string" ? storagePathRaw.trim() : "";
    const fingerprint =
      typeof fingerprintRaw === "string" ? fingerprintRaw.trim() : "";
    const containerFormat =
      typeof containerFormatRaw === "string" ? containerFormatRaw.trim() : "";
    const sizeBytes =
      typeof sizeBytesRaw === "number" && Number.isFinite(sizeBytesRaw)
        ? Math.max(0, Math.trunc(sizeBytesRaw))
        : 0;
    const vaultBytes =
      typeof vaultBytesRaw === "number" && Number.isFinite(vaultBytesRaw)
        ? Math.max(0, Math.trunc(vaultBytesRaw))
        : 0;
    const attachmentsBytes =
      typeof attachmentsBytesRaw === "number" && Number.isFinite(attachmentsBytesRaw)
        ? Math.max(0, Math.trunc(attachmentsBytesRaw))
        : 0;

    if (!fileName || fileName.length > 220) {
      throw new HttpsError("invalid-argument", "fileName invalid");
    }
    if (!storagePath || storagePath.length > 600) {
      throw new HttpsError("invalid-argument", "storagePath invalid");
    }
    if (!storagePath.startsWith(`users/${uid}/vaults/${vaultId}/backups/`)) {
      throw new HttpsError("invalid-argument", "storagePath invalid");
    }
    if (!fingerprint || fingerprint.length > 200) {
      throw new HttpsError("invalid-argument", "fingerprint invalid");
    }

    const now = FieldValue.serverTimestamp();
    const itemRef = db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId)
      .collection("items")
      .doc(fileName);
    const vaultRef = db
      .collection("users")
      .doc(uid)
      .collection("vaultBackups")
      .doc(vaultId);

    const batch = db.batch();
    batch.set(
      itemRef,
      {
        uid,
        vaultId,
        fileName,
        storagePath,
        fingerprint,
        containerFormat: containerFormat.slice(0, 40),
        sizeBytes,
        vaultBytes,
        attachmentsBytes,
        createdAt: now,
      },
      { merge: true }
    );
    batch.set(
      vaultRef,
      {
        latestFileName: fileName,
        latestStoragePath: storagePath,
        latestFingerprint: fingerprint,
        latestContainerFormat: containerFormat.slice(0, 40),
        latestSizeBytes: sizeBytes,
        latestUpdatedAt: now,
      },
      { merge: true }
    );
    await batch.commit();
    return { ok: true as const };
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
  const isDebug = request.data?.debug === true;
  const stripe = stripeClient(isDebug);
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
  inferenceApiKey: string
): Promise<string> {
  const segmentList = segments
    .map((s) => `[${s.start.toFixed(1)}s-${s.end.toFixed(1)}s]: "${s.text.trim()}"`)
    .join("\n");

  const resp = await fetch(openAiChatCompletionsUrl(), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${inferenceApiKey}`,
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
    throw new Error(`Diarization HTTP ${resp.status}: ${body}`);
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

  if (!turns.length) throw new Error("Empty diarization response from model");

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

    // ── Debitar Tinta si se solicita (cuentas staff: sin cargo) ──────────────
    if (chargeInk) {
      const userRef = db.collection("users").doc(uid);
      const preStaffSnap = await userRef.get();
      const skipInkForStaff = isFolioStaffUser(
        (preStaffSnap.data() ?? {}) as Record<string, unknown>
      );
      if (!skipInkForStaff) {
        const inkExhaustedMsg =
          "Tinta insuficiente para la transcripción en la nube. Compra un tintero, " +
          "espera la recarga mensual con suscripción activa, o usa transcripción local.";

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
    }

    // ── Transcripción de audio (endpoint del proveedor Quill Cloud) ───────────
    const inferenceApiKey = openAiApiKey();
    if (!inferenceApiKey) {
      if (inkDebited) {
        await refundInkDropCharge(uid, inkCost).catch((e) =>
          console.error("folioCloudTranscribeChunk: refund after missing key", e)
        );
      }
      throw new HttpsError(
        "failed-precondition",
        "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor)."
      );
    }

    let transcript = "";
    try {
      const audioBuffer = Buffer.from(audioBase64, "base64");
      const blob = new Blob([audioBuffer], { type: "audio/wav" });

      // Reintentos con backoff ante fallos transitorios del proveedor (mismo
      // patrón que openAiFetchChatCompletion / OPENAI_MAX_429_RETRIES).
      const maxTranscribeRetries = 2;
      let resp: Response | undefined;
      let lastErrBody = "";
      for (let attempt = 0; attempt <= maxTranscribeRetries; attempt++) {
        const form = new FormData();
        form.append("file", blob, "chunk.wav");
        // gpt-4o-mini-transcribe: mejor calidad que whisper-1, soporta verbose_json
        form.append("model", "gpt-4o-mini-transcribe");
        if (language && language !== "auto") {
          form.append("language", language.slice(0, 2).toLowerCase());
        }
        form.append("response_format", "verbose_json");

        resp = await fetch(openAiAudioTranscriptionsUrl(), {
          method: "POST",
          headers: { Authorization: `Bearer ${inferenceApiKey}` },
          body: form,
        });

        if (resp.ok) break;

        const attemptStatus = resp.status;
        lastErrBody = await resp.text().catch(() => `HTTP ${attemptStatus}`);
        const transient =
          resp.status === 429 ||
          resp.status === 502 ||
          resp.status === 503 ||
          resp.status === 504;
        if (!transient || attempt === maxTranscribeRetries) break;
        await sleepMs(400 * 2 ** attempt);
      }

      if (!resp || !resp.ok) {
        console.error(
          "folioCloudTranscribeChunk: transcription API error",
          resp?.status,
          lastErrBody
        );
        throw new HttpsError("internal", `Transcription failed (${resp?.status ?? "unknown"})`);
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
        // Diarización con el modelo de chat configurado
        try {
          transcript = await _diarizeSegmentsWithGpt(segments, inferenceApiKey);
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
    const studentRaw = priceFolioCloudStudent();
    const familyRaw = priceFolioCloudFamily();

    if (!stripe) {
      console.warn("monthlyInkRefill: Stripe key not set");
      return;
    }

    let monthlyResolved: string | null = null;
    let studentResolved: string | null = null;
    let familyResolved: string | null = null;

    try {
      if (monthlyRaw) monthlyResolved = await resolveCatalogIdToPriceId(stripe, monthlyRaw);
      if (studentRaw) studentResolved = await resolveCatalogIdToPriceId(stripe, studentRaw);
      if (familyRaw) familyResolved = await resolveCatalogIdToPriceId(stripe, familyRaw);
    } catch (e) {
      console.error("monthlyInkRefill: resolve prices", e);
    }

    const indexSnap = await db.collection("folioCloudSubscribers").get();
    const periodKey = monthPeriodKeyEuropeMadrid();
    let batch = db.batch();
    let n = 0;
    for (const doc of indexSnap.docs) {
      const uid = doc.id;
      const data = doc.data();
      const priceId = data.subscriptionPriceId;
      const msMonthly = data.microsoftStoreMonthly === true;

      const isMonthly = msMonthly || (priceId && (priceId === monthlyResolved || priceId === familyResolved));
      const isStudent = priceId && priceId === studentResolved;

      if (!isMonthly && !isStudent) {
        continue;
      }

      const refillAllowance = isStudent ? STUDENT_INK_ALLOWANCE : MONTHLY_INK_ALLOWANCE;
      const ref = db.collection("users").doc(uid);
      batch.set(
        ref,
        {
          "ink.monthlyBalance": refillAllowance,
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
    const tools = normalizeOpenAiTools(data?.tools);
    const toolChoice = normalizeOpenAiToolChoice(data?.toolChoice);
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
        tools,
        toolChoice,
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
      const tools = normalizeOpenAiTools(payload.tools);
      const toolChoice = normalizeOpenAiToolChoice(payload.toolChoice);
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
          tools,
          toolChoice,
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

const FOLIO_JIRA_DEFAULT_CLOUD_CLIENT_ID =
  "7HEIa3N2dGmMWWscFmYnjGRLNSjzg8hI";

function jiraOauthEnvClientId(): string {
  return process.env.JIRA_OAUTH_CLIENT_ID?.trim() || FOLIO_JIRA_DEFAULT_CLOUD_CLIENT_ID;
}

function jiraOauthEnvClientSecret(): string {
  return process.env.JIRA_OAUTH_CLIENT_SECRET?.trim() ?? "";
}

/**
 * Intercambio authorization_code → tokens (Jira Cloud 3LO).
 * Invocación pública: el código OAuth es de un solo uso y corta vida; el redirect
 * debe ser loopback Folio (mismo puerto que el cliente).
 */
export const folioJiraExchangeOAuth = onRequest(
  { cors: true, memory: "256MiB", invoker: "public" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    const secret = jiraOauthEnvClientSecret();
    if (!secret) {
      res.status(503).json({ error: "jira_oauth_not_configured" });
      return;
    }
    const raw =
      typeof req.body === "string"
        ? (() => {
            try {
              return JSON.parse(req.body || "{}") as Record<string, unknown>;
            } catch {
              return {};
            }
          })()
        : ((req.body ?? {}) as Record<string, unknown>);
    const code = String(raw.code ?? "").trim();
    let redirectUri = String(raw.redirectUri ?? "").trim();
    const clientIdRaw = String(raw.clientId ?? "").trim();
    const clientId = clientIdRaw || jiraOauthEnvClientId();
    // PKCE (RFC 7636): opcional para no romper apps clientes viejas que aún
    // no lo envían (esas tampoco mandaron code_challenge en /authorize).
    const codeVerifier = String(raw.codeVerifier ?? "").trim();
    if (!code || !redirectUri) {
      res.status(400).json({ error: "missing_code_or_redirect" });
      return;
    }
    try {
      const u = new URL(redirectUri);
      if (u.protocol !== "http:" || u.hostname !== "127.0.0.1") {
        res.status(400).json({ error: "invalid_redirect_uri" });
        return;
      }
      if (u.port !== "45747") {
        res.status(400).json({ error: "invalid_redirect_uri" });
        return;
      }
      if (!u.pathname.endsWith("/callback")) {
        res.status(400).json({ error: "invalid_redirect_uri" });
        return;
      }
      redirectUri = u.toString();
    } catch {
      res.status(400).json({ error: "invalid_redirect_uri" });
      return;
    }

    const tokenResp = await fetch("https://auth.atlassian.com/oauth/token", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization:
          "Basic " +
          Buffer.from(`${clientId}:${secret}`, "utf8").toString("base64"),
      },
      body: JSON.stringify({
        grant_type: "authorization_code",
        client_id: clientId,
        client_secret: secret,
        code,
        redirect_uri: redirectUri,
        ...(codeVerifier ? { code_verifier: codeVerifier } : {}),
      }),
    });
    const text = await tokenResp.text();
    if (!tokenResp.ok) {
      console.warn("folioJiraExchangeOAuth: Atlassian error", tokenResp.status, text);
      res.status(502).json({
        error: "atlassian_token_failed",
        status: tokenResp.status,
        body: text.length > 800 ? `${text.slice(0, 800)}…` : text,
      });
      return;
    }
    try {
      const json = JSON.parse(text) as Record<string, unknown>;
      res.status(200).json(json);
    } catch {
      res.status(502).json({ error: "invalid_atlassian_json" });
    }
  }
);

/**
 * Informes de diagnóstico opcionales desde el cliente (fallos, “reportar bug”).
 * Sin autenticación Firebase: no incluir datos de libreta; solo metadatos y trozo de log.
 */
export const folioReportDiagnostic = onRequest(
  { cors: true, memory: "256MiB", invoker: "public" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    const raw =
      typeof req.body === "string"
        ? (() => {
            try {
              return JSON.parse(req.body || "{}") as Record<string, unknown>;
            } catch {
              return {};
            }
          })()
        : ((req.body ?? {}) as Record<string, unknown>);
    const installId = String(raw.installId ?? "").trim().slice(0, 120);
    const kind = String(raw.kind ?? "manual").trim().slice(0, 64);
    const appVersion = String(raw.appVersion ?? "").trim().slice(0, 64);
    const platform = String(raw.platform ?? "").trim().slice(0, 64);
    const channel = String(raw.channel ?? "").trim().slice(0, 64);
    const userNote = String(raw.userNote ?? "").trim().slice(0, 2000);
    const logExcerpt = String(raw.logExcerpt ?? "").trim().slice(0, 12000);
    if (!installId) {
      res.status(400).json({ error: "missing_install_id" });
      return;
    }
    try {
      const ytBaseUrl = (process.env.YOUTRACK_BASE_URL ?? "").trim();
      const ytToken = (process.env.YOUTRACK_TOKEN ?? "").trim();
      const ytProjectId = (process.env.YOUTRACK_PROJECT_ID ?? "").trim();

      let savedToYouTrack = false;

      if (ytBaseUrl && ytToken && ytProjectId) {
        const cleanBaseUrl = ytBaseUrl.replace(/\/+$/, "");
        const summary = `Diagnostic Report (${kind}): ${platform} - ${appVersion}`;
        const description = [
          `# Diagnostic Report`,
          `**Install ID:** ${installId}`,
          `**Kind:** ${kind}`,
          `**App Version:** ${appVersion}`,
          `**Platform:** ${platform}`,
          `**Channel:** ${channel}`,
          `**Telemetry Enabled:** ${Boolean(raw.telemetryEnabled)}`,
          ``,
          `## User Note`,
          userNote ? userNote : `*No user note provided*`,
          ``,
          `## Log Excerpt`,
          `\`\`\``,
          logExcerpt ? logExcerpt : `*No logs provided*`,
          `\`\`\``
        ].join("\n");

        try {
          const ytResponse = await fetch(`${cleanBaseUrl}/api/issues`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${ytToken}`,
            },
            body: JSON.stringify({
              project: { id: ytProjectId },
              summary,
              description,
            }),
          });

          if (ytResponse.ok) {
            savedToYouTrack = true;
          } else {
            const errText = await ytResponse.text();
            console.error(`YouTrack issue creation failed: ${ytResponse.status} ${errText}`);
          }
        } catch (ytErr) {
          console.error("YouTrack integration error", ytErr);
        }
      }

      if (!savedToYouTrack) {
        await db.collection("folio_diagnostics").add({
          createdAt: FieldValue.serverTimestamp(),
          installId,
          kind,
          appVersion,
          platform,
          channel,
          userNote,
          logExcerpt,
          telemetryEnabled: Boolean(raw.telemetryEnabled),
        });
      }
      res.status(200).json({ ok: true, savedToYouTrack });
    } catch (e) {
      console.error("folioReportDiagnostic", e);
      res.status(500).json({ error: "write_failed" });
    }
  }
);

// ─── Lógica para Gestión de Familia y Estudiantes ────────────────────────────

export const inviteFamilyMember = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const email = String(request.data?.email ?? "").trim().toLowerCase();
    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required");
    }
    const callerUid = request.auth.uid;
    const isDebug = request.data?.debug === true;
    const stripe = stripeClient(isDebug);
    if (!stripe) {
      throw new HttpsError("failed-precondition", "Stripe not configured.");
    }

    let targetUser: admin.auth.UserRecord;
    try {
      targetUser = await admin.auth().getUserByEmail(email);
    } catch (e: any) {
      if (e.code === "auth/user-not-found") {
        throw new HttpsError(
          "not-found",
          "El usuario con este correo no está registrado en Folio Cloud."
        );
      }
      throw new HttpsError("internal", `Error buscando usuario: ${e.message}`);
    }
    const targetUid = targetUser.uid;
    if (targetUid === callerUid) {
      throw new HttpsError("invalid-argument", "No puedes invitarte a ti mismo.");
    }

    const ownerRef = db.collection("users").doc(callerUid);
    const targetRef = db.collection("users").doc(targetUid);
    const familyRef = db.collection("families").doc(callerUid);

    const ownerSnap = await ownerRef.get();
    const ownerData = ownerSnap.data() ?? {};
    const fc = ownerData.folioCloud as Record<string, any> | undefined;

    const isMember = !!fc?.familyOwnerUid;
    if (isMember) {
      throw new HttpsError(
        "failed-precondition",
        "Los miembros de una familia no pueden invitar a otras personas."
      );
    }

    const active = fc?.active === true;
    if (!active) {
      throw new HttpsError(
        "failed-precondition",
        "Debes tener una suscripción activa para invitar miembros."
      );
    }

    if (fc?.isStudent === true) {
      throw new HttpsError(
        "failed-precondition",
        "La suscripción de estudiantes no admite añadir miembros familiares."
      );
    }

    const billing = ownerData.billing as Record<string, any> | undefined;
    const stripeBilling = billing?.stripe as Record<string, any> | undefined;
    const familySeats = Number(stripeBilling?.familySeats ?? 0);

    const familySnap = await familyRef.get();
    const familyData = familySnap.data() ?? { members: [] };
    const currentMembers = (familyData.members as string[]) ?? [];

    if (currentMembers.length >= familySeats) {
      throw new HttpsError(
        "resource-exhausted",
        `Has alcanzado el límite de miembros permitidos por tus ranuras contratadas (${familySeats}). Adquiere más ranuras en los ajustes de facturación.`
      );
    }
    if (currentMembers.length >= 10) {
      throw new HttpsError(
        "resource-exhausted",
        "Has alcanzado el límite máximo absoluto de 10 miembros familiares."
      );
    }

    const targetSnap = await targetRef.get();
    const targetData = targetSnap.data() ?? {};
    const targetFamilyOwner = targetData.familyOwnerUid as string | undefined;
    if (targetFamilyOwner) {
      if (targetFamilyOwner === callerUid) {
        throw new HttpsError("already-exists", "El usuario ya está en tu familia.");
      }
      throw new HttpsError("already-exists", "El usuario ya pertenece a otra familia.");
    }

    const targetFc = targetData.folioCloud as Record<string, any> | undefined;
    if (targetFc?.active === true && !targetFc?.familyOwnerUid) {
      throw new HttpsError(
        "failed-precondition",
        "El usuario ya tiene una suscripción premium activa."
      );
    }

    await db.runTransaction(async (tx) => {
      tx.set(
        targetRef,
        {
          familyOwnerUid: callerUid,
        },
        { merge: true }
      );

      tx.set(
        familyRef,
        {
          ownerUid: callerUid,
          members: FieldValue.arrayUnion(targetUid),
          [`membersInfo.${targetUid}`]: {
            email: targetUser.email || email,
            displayName: targetUser.displayName || "",
          },
        },
        { merge: true }
      );
    });

    await recomputeEffectiveFolioCloud(targetUid);
    await recomputeEffectiveFolioCloud(callerUid);

    return { ok: true };
  }
);

export const removeFamilyMember = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const memberUid = String(request.data?.memberUid ?? "").trim();
    if (!memberUid) {
      throw new HttpsError("invalid-argument", "memberUid is required");
    }
    const callerUid = request.auth.uid;
    const isDebug = request.data?.debug === true;
    const stripe = stripeClient(isDebug);
    if (!stripe) {
      throw new HttpsError("failed-precondition", "Stripe not configured.");
    }

    const targetRef = db.collection("users").doc(memberUid);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "Miembro no encontrado.");
    }
    const targetData = targetSnap.data() ?? {};
    const familyOwnerUid = targetData.familyOwnerUid as string | undefined;

    if (!familyOwnerUid) {
      throw new HttpsError(
        "failed-precondition",
        "El usuario no pertenece a ninguna familia."
      );
    }

    if (callerUid !== familyOwnerUid && callerUid !== memberUid) {
      throw new HttpsError(
        "permission-denied",
        "No tienes permiso para eliminar a este miembro de la familia."
      );
    }

    // No direct Stripe operations on member removal. The slot is freed up in Firestore.
    // To stop paying for the slot, the owner manages seats inside the Stripe Billing Portal.

    await db.runTransaction(async (tx) => {
      const familyRef = db.collection("families").doc(familyOwnerUid);

      tx.update(familyRef, {
        members: FieldValue.arrayRemove(memberUid),
        [`membersInfo.${memberUid}`]: FieldValue.delete(),
      });

      tx.update(targetRef, {
        familyOwnerUid: FieldValue.delete(),
      });
    });

    await recomputeEffectiveFolioCloud(memberUid);
    await recomputeEffectiveFolioCloud(familyOwnerUid);

    return { ok: true };
  }
);

export const verifyStudentStatus = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const customEmail = String(request.data?.email ?? "").trim().toLowerCase();
    const email = customEmail || (request.auth.token.email as string | undefined);
    if (!email) {
      throw new HttpsError("invalid-argument", "No email found. Provide an email.");
    }
    const verified = isStudentEmail(email);
    if (verified) {
      const ref = db.collection("users").doc(uid);
      await ref.set(
        {
          billing: {
            studentVerified: true,
          },
        },
        { merge: true }
      );
      await recomputeEffectiveFolioCloud(uid);
    }
    return { ok: true, verified };
  }
);

export const getFamilyDetails = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() ?? {};
    const familyOwnerUid = userData.familyOwnerUid as string | undefined;
    const ownerUid = familyOwnerUid || uid;

    const familySnap = await db.collection("families").doc(ownerUid).get();
    if (!familySnap.exists) {
      return { members: [], membersInfo: {} };
    }
    const familyData = familySnap.data() ?? {};
    return {
      members: familyData.members ?? [],
      membersInfo: familyData.membersInfo ?? {},
    };
  }
);

export const onUserCreated = functionsV1.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      email: user.email ?? "",
      displayName: user.displayName ?? "",
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await recomputeEffectiveFolioCloud(uid);
  }
});

export const ensureUserDocExists = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        email: request.auth.token.email ?? "",
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      await recomputeEffectiveFolioCloud(uid);
    }
    return { ok: true };
  }
);
