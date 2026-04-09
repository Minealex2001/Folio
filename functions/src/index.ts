import * as path from "path";
import { config as loadEnv } from "dotenv";

// Carga `functions/.env` (gitignored). En deploy, Firebase también inyecta estas variables.
loadEnv({ path: path.resolve(__dirname, "../.env") });

import * as admin from "firebase-admin";
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
  generate_insert: 4,
  generate_page: 6,
  chat_turn: 2,
  agent_main: 8,
  agent_followup: 3,
  edit_page_panel: 3,
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
  const ink = (data.ink as Record<string, unknown>) ?? {};
  return {
    monthly: inkBalanceField(ink.monthlyBalance),
    purchased: inkBalanceField(ink.purchasedBalance),
  };
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
  extra: number
): Promise<number> {
  if (extra <= 0) return 0;
  const ref = db.collection("users").doc(uid);
  let charged = 0;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const { monthly, purchased } = readInkBalances(data);
    const take = Math.min(extra, monthly + purchased);
    if (take <= 0) return;
    const next = debitInkBalances(monthly, purchased, take);
    charged = take;
    tx.update(ref, {
      "ink.monthlyBalance": next.monthly,
      "ink.purchasedBalance": next.purchased,
      "ink.updatedAt": FieldValue.serverTimestamp(),
    });
  });
  return charged;
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
}> {
  if (await isMonthlySubscriptionPrice(stripe, priceId)) {
    return { backup: true, cloudAi: true, publishWeb: true };
  }
  const legacy = stripePriceIdsLegacy();
  const explicitMonthly = priceFolioCloudMonthly().trim();
  if (explicitMonthly.length > 0) {
    return { backup: false, cloudAi: false, publishWeb: false };
  }
  if (!priceId || legacy.length === 0) {
    return { backup: true, cloudAi: true, publishWeb: true };
  }
  const active = legacy.includes(priceId);
  return {
    backup: active,
    cloudAi: active,
    publishWeb: active,
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
    await ref.set(
      {
        "ink.monthlyBalance": MONTHLY_INK_ALLOWANCE,
        "ink.monthlyPeriodKey": monthPeriodKeyEuropeMadrid(),
        "ink.updatedAt": FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
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
  { cors: false, memory: "256MiB" },
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

export const createCheckoutSession = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const stripe = stripeClient();
  if (!stripe) {
    throw new HttpsError("failed-precondition", "Stripe not configured on server");
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
  const cancelUrl = process.env.STRIPE_CHECKOUT_CANCEL_URL?.trim() || successUrl;
  const isSubscription = kind === "folio_cloud_monthly";
  let session: Stripe.Response<Stripe.Checkout.Session>;
  try {
    session = await stripe.checkout.sessions.create({
      mode: isSubscription ? "subscription" : "payment",
      line_items: [{ price: priceId, quantity: 1 }],
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
    console.error("createCheckoutSession: Stripe checkout.sessions.create", e);
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
});

/**
 * Si el webhook llegó tarde o falló, el cliente puede forzar la lectura del estado
 * en Stripe y actualizar Firestore (mismo `syncSubscriptionToUser` que el webhook).
 */
export const syncFolioCloudSubscriptionFromStripe = onCall(async (request) => {
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
  const subs = await stripe.subscriptions.list({
    customer: customerId,
    status: "all",
    limit: 20,
  });
  const priority = ["active", "trialing", "past_due", "unpaid"] as const;
  function pickSubscription(list: Stripe.Subscription[]): Stripe.Subscription | undefined {
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
      console.warn("syncFolioCloudSubscriptionFromStripe: search fallback failed", e);
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
});

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

/**
 * Lista `users/{uid}/backups/*` vía Admin SDK.
 * El cliente Windows/Linux no puede usar Storage listAll() (SDK C++ devuelve vacío).
 */
export const folioListVaultBackups = onCall({ cors: true }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const uid = request.auth.uid;
  await assertFolioCloudBackupAllowed(uid);
  const prefix = `users/${uid}/backups/`;
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
});

export const createBillingPortalSession = onCall(async (request) => {
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
});

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
    const prompt = (data?.prompt as string)?.trim() ?? "";
    if (!prompt) {
      throw new AiHttpsError("invalid-argument", "Missing prompt");
    }
    const kindRaw = (data?.operationKind as string)?.trim() ?? "";
    const operationKind =
      kindRaw.length > 0 && Object.prototype.hasOwnProperty.call(INK_COST_BY_OPERATION, kindRaw)
        ? kindRaw
        : "default";
    const baseCost = resolveInkCost(operationKind, prompt.length);
    const ref = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const dataDoc = snap.data() ?? {};
      const fc = dataDoc.folioCloud as Record<string, unknown> | undefined;
      const features = fc?.features as Record<string, unknown> | undefined;
      if (fc?.active !== true || features?.cloudAi !== true) {
        throw new AiHttpsError(
          "permission-denied",
          "Folio Cloud AI requires an active Folio Cloud subscription (cloud AI feature)."
        );
      }
      const { monthly, purchased } = readInkBalances(dataDoc);
      if (monthly + purchased < baseCost) {
        throw new AiHttpsError(
          "resource-exhausted",
          "Insufficient ink. Buy an ink pack in Folio Cloud settings, wait for your monthly refill, or switch to a local AI provider (Ollama / LM Studio)."
        );
      }
      const next = debitInkBalances(monthly, purchased, baseCost);
      tx.update(ref, {
        "ink.monthlyBalance": next.monthly,
        "ink.purchasedBalance": next.purchased,
        "ink.updatedAt": FieldValue.serverTimestamp(),
      });
    });

    try {
      const { text, totalTokenCount } = await callOpenAiGenerate(prompt);
      const extraWant = tokenSurchargeInk(totalTokenCount);
      const extraCharged = await chargeInkExtraIfPossible(uid, extraWant);
      const finalSnap = await ref.get();
      const inkOut = readInkBalances(
        (finalSnap.data() ?? {}) as Record<string, unknown>
      );
      const monthlyBalance = inkOut.monthly;
      const purchasedBalance = inkOut.purchased;
      return {
        text,
        ink: {
          monthlyBalance,
          purchasedBalance,
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
  });
