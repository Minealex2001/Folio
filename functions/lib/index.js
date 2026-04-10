"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.folioCloudAiCompleteHttp = exports.folioCloudAiComplete = exports.monthlyInkRefill = exports.createBillingPortalSession = exports.folioTrimVaultBackups = exports.folioUpsertVaultBackupIndex = exports.folioListBackupVaults = exports.folioListVaultBackups = exports.syncFolioCloudSubscriptionFromStripe = exports.createCheckoutSession = exports.stripeWebhook = void 0;
const path = __importStar(require("path"));
const dotenv_1 = require("dotenv");
// Carga `functions/.env` (gitignored). En deploy, Firebase también inyecta estas variables.
(0, dotenv_1.config)({ path: path.resolve(__dirname, "../.env") });
const admin = __importStar(require("firebase-admin"));
const functionsV1 = __importStar(require("firebase-functions/v1"));
const https_1 = require("firebase-functions/v2/https");
const https_2 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const stripe_1 = __importDefault(require("stripe"));
admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
/** HttpsError de 1st gen: la callable `folioCloudAiComplete` corre en CF 1st gen (no Cloud Run). */
const AiHttpsError = functionsV1.https.HttpsError;
/** Suscripción Folio Cloud: 500 gotas/mes (recarga día 1 + alta). */
const MONTHLY_INK_ALLOWANCE = 500;
const INK_TIMEZONE = "Europe/Madrid";
/** Coste base por tipo de operación (cliente envía `operationKind`; desconocidos → `default`). */
const INK_COST_BY_OPERATION = {
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
function stripeSecret() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_SECRET_KEY) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function webhookSecret() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_WEBHOOK_SECRET) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function openAiApiKey() {
    var _a, _b;
    return (_b = (_a = process.env.OPENAI_API_KEY) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function openAiBaseUrl() {
    var _a;
    return (((_a = process.env.OPENAI_BASE_URL) === null || _a === void 0 ? void 0 : _a.trim()) || "https://api.openai.com/v1").replace(/\/+$/, "");
}
function openAiModel() {
    var _a;
    return ((_a = process.env.OPENAI_MODEL) === null || _a === void 0 ? void 0 : _a.trim()) || "gpt-4o-mini";
}
function openAiMaxOutputTokens() {
    var _a;
    const raw = (_a = process.env.OPENAI_MAX_OUTPUT_TOKENS) === null || _a === void 0 ? void 0 : _a.trim();
    if (!raw)
        return 8192;
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 1)
        return 8192;
    return Math.min(16384, Math.trunc(n));
}
function openAiTemperature() {
    var _a;
    const raw = (_a = process.env.OPENAI_TEMPERATURE) === null || _a === void 0 ? void 0 : _a.trim();
    if (!raw)
        return 0.7;
    const n = Number(raw);
    if (!Number.isFinite(n))
        return 0.7;
    return Math.min(2, Math.max(0, n));
}
const OPENAI_MAX_429_RETRIES = 3;
const OPENAI_MAX_SPIN_GUARD = 8;
function openAiChatCompletionsUrl() {
    return `${openAiBaseUrl()}/chat/completions`;
}
function parseOpenAiApiErrorMessage(raw) {
    var _a, _b;
    try {
        const errBody = JSON.parse(raw);
        return ((_b = (_a = errBody.error) === null || _a === void 0 ? void 0 : _a.message) !== null && _b !== void 0 ? _b : "").trim();
    }
    catch {
        return "";
    }
}
async function sleepMs(ms) {
    await new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}
async function openAiFetchChatCompletion(apiKey, body) {
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
function throwOpenAiHttpError(status, raw) {
    const openAiMsg = parseOpenAiApiErrorMessage(raw);
    console.error("OpenAI HTTP error", status, raw.slice(0, 800));
    const quotaHint = "Esto viene de la API de OpenAI (clave, cuota, facturación o modelo), no del saldo de gotas Folio en Firestore. Revisa OPENAI_API_KEY y límites en platform.openai.com.";
    if (status === 401 || status === 403 || status === 429) {
        throw new AiHttpsError("failed-precondition", openAiMsg ? `${openAiMsg} ${quotaHint}` : quotaHint);
    }
    if (status === 400 || status === 404) {
        const hint = status === 404
            ? " Comprueba OPENAI_MODEL y OPENAI_BASE_URL."
            : "";
        throw new AiHttpsError("failed-precondition", (openAiMsg || `OpenAI API HTTP ${status}`) + hint);
    }
    throw new AiHttpsError("internal", openAiMsg || "AI provider returned an error. Try again later.");
}
function resolveInkCost(operationKind, promptLength) {
    var _a;
    const base = (_a = INK_COST_BY_OPERATION[operationKind]) !== null && _a !== void 0 ? _a : INK_COST_BY_OPERATION.default;
    let cost = base;
    if (promptLength > INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD) {
        cost += INK_EXTRA_FOR_LONG_PROMPT;
    }
    return Math.min(cost, INK_MAX_PER_REQUEST);
}
function debitInkBalances(monthly, purchased, cost) {
    if (cost <= 0)
        return { monthly, purchased };
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
function inkBalanceField(v) {
    if (typeof v === "number" && Number.isFinite(v)) {
        return Math.max(0, Math.trunc(v));
    }
    if (typeof v === "string") {
        const t = v.trim();
        if (t.length === 0)
            return 0;
        const n = Number(t);
        if (Number.isFinite(n))
            return Math.max(0, Math.trunc(n));
    }
    return 0;
}
function readInkBalances(data) {
    var _a;
    // Forma esperada: `ink` es un mapa {monthlyBalance, purchasedBalance, ...}.
    // En algunos despliegues antiguos/datos corruptos, los campos pueden existir como
    // claves literales con punto: "ink.monthlyBalance". Soportamos ambos para no
    // bloquear IA/backup por un detalle de forma.
    const ink = (_a = data.ink) !== null && _a !== void 0 ? _a : {};
    const monthly = inkBalanceField(ink.monthlyBalance) ||
        inkBalanceField(data["ink.monthlyBalance"]);
    const purchased = inkBalanceField(ink.purchasedBalance) ||
        inkBalanceField(data["ink.purchasedBalance"]);
    return { monthly, purchased };
}
function tokenSurchargeInk(totalTokenCount) {
    if (totalTokenCount == null || totalTokenCount <= 0)
        return 0;
    return Math.min(INK_MAX_TOKEN_SURCHARGE, Math.floor(totalTokenCount / INK_TOKENS_PER_SURCHARGE_UNIT));
}
function parseOpenAiSuccessResponse(raw) {
    var _a, _b, _c, _d, _e, _f, _g;
    let json;
    try {
        json = JSON.parse(raw);
    }
    catch {
        throw new AiHttpsError("internal", "Invalid AI response");
    }
    if ((_a = json.error) === null || _a === void 0 ? void 0 : _a.message) {
        console.error("OpenAI API error object", json.error);
        throw new AiHttpsError("internal", "AI provider error");
    }
    const content = (_d = (_c = (_b = json.choices) === null || _b === void 0 ? void 0 : _b[0]) === null || _c === void 0 ? void 0 : _c.message) === null || _d === void 0 ? void 0 : _d.content;
    const text = typeof content === "string" ? content : "";
    if (!text.trim()) {
        const reason = (_f = (_e = json.choices) === null || _e === void 0 ? void 0 : _e[0]) === null || _f === void 0 ? void 0 : _f.finish_reason;
        console.warn("OpenAI empty output", { reason });
        const hint = reason === "content_filter"
            ? " (contenido filtrado por políticas del proveedor)"
            : "";
        throw new AiHttpsError("internal", `Empty AI response. Try a shorter prompt.${hint}`);
    }
    const totalTokenCount = typeof ((_g = json.usage) === null || _g === void 0 ? void 0 : _g.total_tokens) === "number"
        ? json.usage.total_tokens
        : undefined;
    return { text: text.trim(), totalTokenCount };
}
/**
 * Inferencia vía OpenAI Chat Completions (o API compatible: mismo path y cuerpo).
 */
async function callOpenAiGenerate(prompt) {
    const key = openAiApiKey();
    if (!key) {
        throw new AiHttpsError("failed-precondition", "Server AI not configured (set OPENAI_API_KEY on Cloud Functions)");
    }
    const body = {
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
    throw new AiHttpsError("internal", "OpenAI request stopped after too many retries. Try again later.");
}
function normalizeOpenAiRole(raw) {
    const r = typeof raw === "string" ? raw.trim().toLowerCase() : "";
    if (r === "system" || r === "user" || r === "assistant")
        return r;
    return null;
}
function normalizeOpenAiMessages(raw) {
    if (!Array.isArray(raw))
        return [];
    const out = [];
    for (const item of raw) {
        if (!item || typeof item !== "object")
            continue;
        const m = item;
        const role = normalizeOpenAiRole(m.role);
        const content = typeof m.content === "string" ? m.content.trim() : "";
        if (!role || !content)
            continue;
        out.push({ role, content });
    }
    return out;
}
function normalizeOptionalString(raw, maxLen) {
    const s = typeof raw === "string" ? raw.trim() : "";
    if (!s)
        return "";
    return s.length <= maxLen ? s : s.slice(0, maxLen);
}
function normalizeOptionalNumber(raw) {
    if (typeof raw !== "number" || !Number.isFinite(raw))
        return undefined;
    return raw;
}
function normalizeClientMaxTokens(raw) {
    const n = normalizeOptionalNumber(raw);
    if (n == null)
        return undefined;
    const t = Math.trunc(n);
    if (t < 1)
        return undefined;
    return Math.min(openAiMaxOutputTokens(), t);
}
function normalizeClientTemperature(raw) {
    const n = normalizeOptionalNumber(raw);
    if (n == null)
        return undefined;
    return Math.min(2, Math.max(0, n));
}
function normalizeResponseSchema(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    if (Array.isArray(raw))
        return null;
    // Recortamos profundidad/tamaño más adelante con límites de prompt/ink; aquí solo validamos forma.
    return raw;
}
async function callOpenAiChatStructured(input) {
    var _a, _b, _c, _d, _e, _f;
    const key = openAiApiKey();
    if (!key) {
        throw new AiHttpsError("failed-precondition", "Server AI not configured (set OPENAI_API_KEY on Cloud Functions)");
    }
    const systemPrompt = ((_a = input.systemPrompt) !== null && _a !== void 0 ? _a : "").trim();
    const prompt = ((_b = input.prompt) !== null && _b !== void 0 ? _b : "").trim();
    const normalizedMsgs = ((_c = input.messages) !== null && _c !== void 0 ? _c : []).filter((m) => m.content.trim());
    const messages = [];
    if (systemPrompt)
        messages.push({ role: "system", content: systemPrompt });
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
    const body = {
        model: openAiModel(),
        messages,
        max_tokens: (_d = input.maxTokens) !== null && _d !== void 0 ? _d : openAiMaxOutputTokens(),
        temperature: (_e = input.temperature) !== null && _e !== void 0 ? _e : openAiTemperature(),
    };
    const schema = (_f = input.responseSchema) !== null && _f !== void 0 ? _f : null;
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
    throw new AiHttpsError("internal", "OpenAI request stopped after too many retries. Try again later.");
}
async function refundInkDropCharge(uid, amount) {
    if (amount <= 0)
        return;
    const ref = db.collection("users").doc(uid);
    await ref.set({
        "ink.purchasedBalance": FieldValue.increment(amount),
        "ink.updatedAt": FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function chargeInkExtraIfPossible(uid, extra, allowSubscriptionInk) {
    if (extra <= 0)
        return 0;
    const ref = db.collection("users").doc(uid);
    let charged = 0;
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(ref);
        const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        const { monthly, purchased } = readInkBalances(data);
        const effectiveMonthly = allowSubscriptionInk ? monthly : 0;
        const take = Math.min(extra, effectiveMonthly + purchased);
        if (take <= 0)
            return;
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
function normalizeOperationKind(raw) {
    const kindRaw = typeof raw === "string" ? raw.trim() : "";
    if (kindRaw.length > 0 &&
        Object.prototype.hasOwnProperty.call(INK_COST_BY_OPERATION, kindRaw)) {
        return kindRaw;
    }
    return "default";
}
function normalizePrompt(raw) {
    if (typeof raw !== "string")
        return "";
    return raw.trim();
}
function promptLengthForInk(input) {
    var _a, _b, _c;
    let n = 0;
    const p = ((_a = input.prompt) !== null && _a !== void 0 ? _a : "").trim();
    if (p)
        n += p.length;
    const sp = ((_b = input.systemPrompt) !== null && _b !== void 0 ? _b : "").trim();
    if (sp)
        n += sp.length;
    const msgs = (_c = input.messages) !== null && _c !== void 0 ? _c : [];
    for (const m of msgs) {
        if (m === null || m === void 0 ? void 0 : m.content)
            n += String(m.content).length;
    }
    return n;
}
async function runFolioCloudAiForUid(uid, input, operationKind) {
    var _a;
    const baseCost = resolveInkCost(operationKind, promptLengthForInk(input));
    const ref = db.collection("users").doc(uid);
    const inkExhaustedMsg = "Insufficient ink. Buy an ink pack in Folio Cloud settings, wait for your monthly refill with an active subscription, or switch to a local AI provider (Ollama / LM Studio).";
    let allowSubscriptionInk = false;
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(ref);
        const dataDoc = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        const fc = dataDoc.folioCloud;
        const features = fc === null || fc === void 0 ? void 0 : fc.features;
        const hasSubCloudAi = (fc === null || fc === void 0 ? void 0 : fc.active) === true && (features === null || features === void 0 ? void 0 : features.cloudAi) === true;
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
        }
        else {
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
        const extraCharged = await chargeInkExtraIfPossible(uid, extraWant, allowSubscriptionInk);
        const finalSnap = await ref.get();
        const inkOut = readInkBalances(((_a = finalSnap.data()) !== null && _a !== void 0 ? _a : {}));
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
    }
    catch (e) {
        try {
            await refundInkDropCharge(uid, baseCost);
        }
        catch (refundErr) {
            console.error("folioCloudAiComplete: refund after AI failure", refundErr);
        }
        throw e;
    }
}
function callableLikeErrorBody(code, message) {
    const status = code.replace(/-/g, "_").toUpperCase();
    return {
        error: {
            status,
            message,
        },
    };
}
async function verifiedUidFromBearerToken(authHeader) {
    const raw = (authHeader !== null && authHeader !== void 0 ? authHeader : "").trim();
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
    }
    catch {
        throw new AiHttpsError("unauthenticated", "Login required");
    }
}
function stripeClient() {
    const key = stripeSecret();
    if (!key)
        return null;
    return new stripe_1.default(key, { apiVersion: "2025-02-24.acacia" });
}
/** Convierte errores de Stripe (o genéricos) en mensaje seguro para el cliente callable. */
function stripeCallErrorMessage(err) {
    if (err instanceof Error && err.message) {
        return err.message.slice(0, 500);
    }
    if (err && typeof err === "object" && "message" in err) {
        return String(err.message).slice(0, 500);
    }
    return "Unknown error";
}
function priceFolioCloudMonthly() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_PRICE_FOLIO_CLOUD_MONTHLY) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function priceInkSmall() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_PRICE_INK_SMALL) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function priceInkMedium() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_PRICE_INK_MEDIUM) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function priceInkLarge() {
    var _a, _b;
    return (_b = (_a = process.env.STRIPE_PRICE_INK_LARGE) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
/**
 * Las variables pueden ser `price_...` o `prod_...`. Checkout necesita un Price;
 * si pasas un producto, se usa su precio por defecto (Dashboard → producto → precio por defecto).
 */
async function resolveCatalogIdToPriceId(stripe, raw) {
    const id = raw.trim();
    if (!id) {
        throw new https_1.HttpsError("failed-precondition", "Empty Stripe catalog id");
    }
    if (id.startsWith("price_")) {
        return id;
    }
    if (id.startsWith("prod_")) {
        const product = await stripe.products.retrieve(id);
        const dp = product.default_price;
        if (!dp) {
            throw new https_1.HttpsError("failed-precondition", `Stripe product ${id} has no default price. Open the product in the Dashboard and set a default price.`);
        }
        return typeof dp === "string" ? dp : dp.id;
    }
    throw new https_1.HttpsError("failed-precondition", `Invalid Stripe catalog id (use price_... or prod_...): ${id}`);
}
/** Comprueba si el price id real de Stripe coincide con la variable (price o product). */
async function catalogMatchesPrice(stripe, envCatalogId, actualPriceId) {
    if (!actualPriceId || !envCatalogId.trim())
        return false;
    const env = envCatalogId.trim();
    if (env.startsWith("price_")) {
        return env === actualPriceId;
    }
    if (env.startsWith("prod_")) {
        const price = await stripe.prices.retrieve(actualPriceId);
        const prod = price.product;
        const prodId = typeof prod === "string" ? prod : prod === null || prod === void 0 ? void 0 : prod.id;
        return prodId === env;
    }
    return false;
}
/** @deprecated usar STRIPE_PRICE_FOLIO_CLOUD_MONTHLY */
function stripePriceIdsLegacy() {
    var _a, _b;
    const raw = (_b = (_a = process.env.STRIPE_PRICE_IDS_FOLIO_CLOUD) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
    if (!raw)
        return [];
    return raw.split(",").map((s) => s.trim()).filter(Boolean);
}
async function isMonthlySubscriptionPrice(stripe, priceId) {
    if (!priceId)
        return false;
    const explicit = priceFolioCloudMonthly();
    if (explicit) {
        return catalogMatchesPrice(stripe, explicit, priceId);
    }
    const legacy = stripePriceIdsLegacy();
    return legacy.length > 0 && legacy.includes(priceId);
}
async function folioCloudFeaturesFromPriceId(stripe, priceId) {
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
async function inkDropsForPriceId(stripe, priceId) {
    if (!priceId)
        return 0;
    const small = priceInkSmall();
    const med = priceInkMedium();
    const large = priceInkLarge();
    if (small && (await catalogMatchesPrice(stripe, small, priceId)))
        return 300;
    if (med && (await catalogMatchesPrice(stripe, med, priceId)))
        return 1000;
    if (large && (await catalogMatchesPrice(stripe, large, priceId)))
        return 2500;
    return 0;
}
function monthPeriodKeyEuropeMadrid(d = new Date()) {
    var _a, _b, _c, _d;
    const fmt = new Intl.DateTimeFormat("en-CA", {
        timeZone: INK_TIMEZONE,
        year: "numeric",
        month: "2-digit",
    });
    const parts = fmt.formatToParts(d);
    const y = (_b = (_a = parts.find((p) => p.type === "year")) === null || _a === void 0 ? void 0 : _a.value) !== null && _b !== void 0 ? _b : "1970";
    const m = (_d = (_c = parts.find((p) => p.type === "month")) === null || _c === void 0 ? void 0 : _c.value) !== null && _d !== void 0 ? _d : "01";
    return `${y}-${m}`;
}
async function syncSubscriptionToUser(stripe, uid, status, priceId) {
    const features = await folioCloudFeaturesFromPriceId(stripe, priceId);
    const active = status === "active" || status === "trialing" || status === "past_due";
    const monthly = await isMonthlySubscriptionPrice(stripe, priceId);
    const ref = db.collection("users").doc(uid);
    await ref.set({
        folioCloud: {
            subscriptionStatus: status,
            active,
            features,
            subscriptionPriceId: priceId !== null && priceId !== void 0 ? priceId : null,
            updatedAt: FieldValue.serverTimestamp(),
        },
    }, { merge: true });
    if (active && monthly) {
        // Importante: sincronizar desde Stripe NO debe “recargar” la tinta cada vez.
        // Solo recargamos si cambia el periodo mensual o si faltan campos.
        const currentPeriodKey = monthPeriodKeyEuropeMadrid();
        const FieldPath = admin.firestore.FieldPath;
        const deleteDotted = {
            // Si existen campos literales con punto (bug/datos manuales), los borramos.
            [new FieldPath("ink.monthlyBalance")]: FieldValue.delete(),
            [new FieldPath("ink.purchasedBalance")]: FieldValue.delete(),
            [new FieldPath("ink.monthlyPeriodKey")]: FieldValue.delete(),
            [new FieldPath("ink.updatedAt")]: FieldValue.delete(),
        };
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const snap = await tx.get(ref);
            const data = ((_a = snap.data()) !== null && _a !== void 0 ? _a : {});
            const inkRaw = (_b = data.ink) !== null && _b !== void 0 ? _b : {};
            const existingMonthly = inkBalanceField(inkRaw.monthlyBalance);
            const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
            const dottedMonthly = inkBalanceField(data["ink.monthlyBalance"]);
            const dottedPurchased = inkBalanceField(data["ink.purchasedBalance"]);
            const monthlyBalance = Math.max(existingMonthly, dottedMonthly);
            const purchasedBalance = Math.max(existingPurchased, dottedPurchased);
            const rawKey = typeof inkRaw.monthlyPeriodKey === "string"
                ? inkRaw.monthlyPeriodKey.trim()
                : "";
            const dottedKey = typeof data["ink.monthlyPeriodKey"] === "string"
                ? String(data["ink.monthlyPeriodKey"]).trim()
                : "";
            const existingPeriodKey = rawKey || dottedKey;
            const shouldRefill = !existingPeriodKey || existingPeriodKey !== currentPeriodKey;
            tx.set(ref, {
                ink: {
                    monthlyBalance: shouldRefill ? MONTHLY_INK_ALLOWANCE : monthlyBalance,
                    purchasedBalance,
                    monthlyPeriodKey: currentPeriodKey,
                    updatedAt: FieldValue.serverTimestamp(),
                },
                // Limpieza de duplicados (si los hubiera).
                ...deleteDotted,
            }, { merge: true });
        });
        let subIndexPrice = priceId !== null && priceId !== void 0 ? priceId : null;
        if (!subIndexPrice) {
            const rawMonthly = priceFolioCloudMonthly();
            if (rawMonthly) {
                try {
                    subIndexPrice = await resolveCatalogIdToPriceId(stripe, rawMonthly);
                }
                catch {
                    subIndexPrice = null;
                }
            }
        }
        await db.collection("folioCloudSubscribers").doc(uid).set({
            subscriptionPriceId: subIndexPrice,
            updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    else {
        await db.collection("folioCloudSubscribers").doc(uid).delete().catch(() => undefined);
        const FieldPathInactive = admin.firestore.FieldPath;
        const deleteDottedInactive = {
            [new FieldPathInactive("ink.monthlyBalance")]: FieldValue.delete(),
            [new FieldPathInactive("ink.purchasedBalance")]: FieldValue.delete(),
            [new FieldPathInactive("ink.monthlyPeriodKey")]: FieldValue.delete(),
            [new FieldPathInactive("ink.updatedAt")]: FieldValue.delete(),
        };
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const snap = await tx.get(ref);
            const data = ((_a = snap.data()) !== null && _a !== void 0 ? _a : {});
            const inkRaw = (_b = data.ink) !== null && _b !== void 0 ? _b : {};
            const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
            const dottedPurchased = inkBalanceField(data["ink.purchasedBalance"]);
            const purchasedBalance = Math.max(existingPurchased, dottedPurchased);
            tx.set(ref, {
                ink: {
                    monthlyBalance: 0,
                    purchasedBalance,
                    monthlyPeriodKey: FieldValue.delete(),
                    updatedAt: FieldValue.serverTimestamp(),
                },
                ...deleteDottedInactive,
            }, { merge: true });
        });
    }
}
async function isWebhookAlreadyProcessed(eventId) {
    const snap = await db.collection("stripeWebhookEvents").doc(eventId).get();
    return snap.exists;
}
async function recordWebhookProcessed(eventId) {
    await db.collection("stripeWebhookEvents").doc(eventId).set({
        processedAt: FieldValue.serverTimestamp(),
    });
}
/**
 * Firestore a veces no tiene `stripeCustomerId` si el webhook de checkout falló.
 * Buscamos una suscripción con metadata.firebase_uid y persistimos el customer.
 */
async function ensureStripeCustomerId(stripe, uid) {
    const ref = db.collection("users").doc(uid);
    const existing = (await ref.get()).get("stripeCustomerId");
    if (existing)
        return existing;
    const escapedUid = uid.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
    try {
        const search = await stripe.subscriptions.search({
            query: `metadata['firebase_uid']:'${escapedUid}'`,
            limit: 10,
        });
        for (const sub of search.data) {
            const c = sub.customer;
            const cid = typeof c === "string" ? c : c === null || c === void 0 ? void 0 : c.id;
            if (cid) {
                await ref.set({ stripeCustomerId: cid }, { merge: true });
                return cid;
            }
        }
    }
    catch (e) {
        console.warn("ensureStripeCustomerId: subscription search failed", e);
    }
    return undefined;
}
/**
 * Crédito de gotas por Checkout modo payment; idempotente por sesión (evita duplicar con
 * `checkout.session.async_payment_succeeded`).
 */
async function grantPaymentCheckoutInkIfNeeded(stripe, uid, expanded) {
    var _a, _b, _c;
    const doneRef = db.collection("stripeProcessedCheckouts").doc(expanded.id);
    const doneSnap = await doneRef.get();
    if (doneSnap.exists)
        return;
    if (expanded.payment_status !== "paid")
        return;
    const lineItems = (_b = (_a = expanded.line_items) === null || _a === void 0 ? void 0 : _a.data) !== null && _b !== void 0 ? _b : [];
    let totalAdded = 0;
    for (const item of lineItems) {
        const priceObj = item.price;
        const linePriceId = typeof priceObj === "string" ? priceObj : priceObj === null || priceObj === void 0 ? void 0 : priceObj.id;
        const drops = await inkDropsForPriceId(stripe, linePriceId);
        if (drops > 0)
            totalAdded += drops * ((_c = item.quantity) !== null && _c !== void 0 ? _c : 1);
    }
    const batch = db.batch();
    if (totalAdded > 0) {
        batch.set(db.collection("users").doc(uid), {
            "ink.purchasedBalance": FieldValue.increment(totalAdded),
            "ink.updatedAt": FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    batch.set(doneRef, {
        uid,
        dropsAdded: totalAdded,
        processedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
}
async function handleCheckoutSessionCompleted(stripe, session) {
    var _a, _b, _c, _d, _e;
    const uid = (typeof ((_a = session.metadata) === null || _a === void 0 ? void 0 : _a.firebase_uid) === "string"
        ? session.metadata.firebase_uid
        : "").trim() || ((_b = session.client_reference_id) === null || _b === void 0 ? void 0 : _b.trim()) || "";
    if (!uid) {
        console.error("checkout session: missing firebase_uid and client_reference_id", session.id);
        return;
    }
    const expanded = await stripe.checkout.sessions.retrieve(session.id, {
        expand: ["line_items.data.price", "subscription"],
    });
    let customerId = typeof expanded.customer === "string"
        ? expanded.customer
        : (_c = expanded.customer) === null || _c === void 0 ? void 0 : _c.id;
    const mode = expanded.mode;
    if (mode === "subscription") {
        const rawSub = expanded.subscription;
        let sub;
        if (rawSub && typeof rawSub === "object" && "id" in rawSub) {
            sub = rawSub;
        }
        else if (typeof rawSub === "string") {
            sub = await stripe.subscriptions.retrieve(rawSub);
        }
        if (!sub) {
            console.error("checkout.session.completed: missing subscription", {
                sessionId: session.id,
                subscription: rawSub,
            });
            throw new Error("checkout.session.completed: subscription missing after successful payment");
        }
        if (!customerId) {
            const c = sub.customer;
            customerId = typeof c === "string" ? c : c === null || c === void 0 ? void 0 : c.id;
        }
        const priceId = (_e = (_d = sub.items.data[0]) === null || _d === void 0 ? void 0 : _d.price) === null || _e === void 0 ? void 0 : _e.id;
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
            console.warn("checkout session: subscription mode, not paid yet — ink add-on will apply on async success", expanded.id, expanded.payment_status);
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
            console.warn("checkout session: payment mode, not paid yet — will retry on async success", expanded.id, expanded.payment_status);
            return;
        }
        await grantPaymentCheckoutInkIfNeeded(stripe, uid, expanded);
    }
}
exports.stripeWebhook = (0, https_2.onRequest)(
// Stripe necesita invocar este endpoint sin auth (valida con firma Stripe).
// En Functions v2 (Cloud Run), si no se marca como público, Cloud Run rechaza con 401
// antes de que podamos verificar `stripe-signature`.
{ cors: false, memory: "256MiB", invoker: "public" }, async (req, res) => {
    var _a, _b, _c, _d;
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
    let event;
    try {
        const rawBody = req.rawBody;
        if (!rawBody) {
            res.status(400).send("Missing raw body");
            return;
        }
        event = stripe.webhooks.constructEvent(rawBody, sig, whSecret);
    }
    catch (err) {
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
                await handleCheckoutSessionCompleted(stripe, event.data.object);
                break;
            }
            case "customer.subscription.created":
            case "customer.subscription.updated":
            case "customer.subscription.deleted": {
                const sub = event.data.object;
                const subUid = (_a = sub.metadata) === null || _a === void 0 ? void 0 : _a.firebase_uid;
                if (!subUid)
                    break;
                const customerRef = typeof sub.customer === "string" ? sub.customer : (_b = sub.customer) === null || _b === void 0 ? void 0 : _b.id;
                if (customerRef) {
                    await db.collection("users").doc(subUid).set({ stripeCustomerId: customerRef }, { merge: true });
                }
                const priceId = (_d = (_c = sub.items.data[0]) === null || _c === void 0 ? void 0 : _c.price) === null || _d === void 0 ? void 0 : _d.id;
                if (event.type === "customer.subscription.deleted") {
                    await syncSubscriptionToUser(stripe, subUid, "canceled", priceId);
                }
                else {
                    await syncSubscriptionToUser(stripe, subUid, sub.status, priceId);
                }
                break;
            }
            default:
                break;
        }
        await recordWebhookProcessed(stripeEventId);
        res.json({ received: true });
    }
    catch (e) {
        console.error("Webhook handler error", e);
        res.status(500).send("Handler error");
    }
});
/** Misma condición que Storage rules `folioCloudBackupOk` (copias en la nube). */
async function assertFolioCloudBackupAllowed(uid) {
    var _a;
    const snap = await db.collection("users").doc(uid).get();
    const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const fc = data.folioCloud;
    const features = fc === null || fc === void 0 ? void 0 : fc.features;
    if ((fc === null || fc === void 0 ? void 0 : fc.active) !== true || (features === null || features === void 0 ? void 0 : features.backup) !== true) {
        throw new https_1.HttpsError("permission-denied", "Folio Cloud backup is not active for this account.");
    }
}
function assertValidVaultId(raw) {
    const vaultId = typeof raw === "string" ? raw.trim() : "";
    if (!vaultId) {
        throw new https_1.HttpsError("invalid-argument", "vaultId is required");
    }
    // Reject path traversal and unexpected separators.
    if (vaultId.includes("/") || vaultId.includes("\\") || vaultId.includes("..")) {
        throw new https_1.HttpsError("invalid-argument", "Invalid vaultId");
    }
    if (vaultId.length > 96) {
        throw new https_1.HttpsError("invalid-argument", "Invalid vaultId");
    }
    return vaultId;
}
/**
 * Callable v2 corre en Cloud Run (2nd gen). Para soportar escritorio vía HTTP callable
 * (`Authorization: Bearer <ID token>`), el servicio debe permitir invocación pública
 * o Cloud Run devolverá 401 HTML antes de ejecutar la función.
 */
exports.createCheckoutSession = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const stripe = stripeClient();
    if (!stripe) {
        throw new https_1.HttpsError("failed-precondition", "Stripe not configured on server");
    }
    const uid = request.auth.uid;
    const kind = (_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.kind) !== null && _c !== void 0 ? _c : "folio_cloud_monthly";
    const priceIdMap = {
        folio_cloud_monthly: priceFolioCloudMonthly(),
        ink_small: priceInkSmall(),
        ink_medium: priceInkMedium(),
        ink_large: priceInkLarge(),
    };
    const rawCatalogId = (_d = priceIdMap[kind]) === null || _d === void 0 ? void 0 : _d.trim();
    if (!rawCatalogId) {
        throw new https_1.HttpsError("failed-precondition", `Stripe catalog id not configured for kind: ${kind}`);
    }
    let priceId;
    try {
        priceId = await resolveCatalogIdToPriceId(stripe, rawCatalogId);
    }
    catch (e) {
        if (e instanceof https_1.HttpsError)
            throw e;
        console.error("resolveCatalogIdToPriceId", e);
        throw new https_1.HttpsError("failed-precondition", `Stripe: ${stripeCallErrorMessage(e)}`);
    }
    const successUrl = ((_e = process.env.STRIPE_CHECKOUT_SUCCESS_URL) === null || _e === void 0 ? void 0 : _e.trim()) ||
        ((_f = process.env.BILLING_PORTAL_RETURN_URL) === null || _f === void 0 ? void 0 : _f.trim()) ||
        "https://folio.app";
    const cancelUrl = ((_g = process.env.STRIPE_CHECKOUT_CANCEL_URL) === null || _g === void 0 ? void 0 : _g.trim()) || successUrl;
    const isSubscription = kind === "folio_cloud_monthly";
    let session;
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
    }
    catch (e) {
        console.error("createCheckoutSession: Stripe checkout.sessions.create", e);
        throw new https_1.HttpsError("failed-precondition", `Stripe: ${stripeCallErrorMessage(e)}`);
    }
    if (!session.url) {
        throw new https_1.HttpsError("failed-precondition", "Stripe did not return a checkout URL");
    }
    return { url: session.url };
});
exports.syncFolioCloudSubscriptionFromStripe = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const stripe = stripeClient();
    if (!stripe) {
        throw new https_1.HttpsError("failed-precondition", "Stripe not configured on server");
    }
    const uid = request.auth.uid;
    const customerId = await ensureStripeCustomerId(stripe, uid);
    if (!customerId) {
        throw new https_1.HttpsError("failed-precondition", "No Stripe customer yet. Complete checkout first.");
    }
    const subs = await stripe.subscriptions.list({
        customer: customerId,
        status: "all",
        limit: 20,
    });
    const priority = ["active", "trialing", "past_due", "unpaid"];
    function pickSubscription(list) {
        for (const st of priority) {
            const hit = list.find((s) => s.status === st);
            if (hit)
                return hit;
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
        }
        catch (e) {
            console.warn("syncFolioCloudSubscriptionFromStripe: search fallback failed", e);
        }
    }
    if (chosen) {
        const c = chosen.customer;
        const cid = typeof c === "string" ? c : c === null || c === void 0 ? void 0 : c.id;
        if (cid && cid !== customerId) {
            await db
                .collection("users")
                .doc(uid)
                .set({ stripeCustomerId: cid }, { merge: true });
        }
        const priceId = (_c = (_b = chosen.items.data[0]) === null || _b === void 0 ? void 0 : _b.price) === null || _c === void 0 ? void 0 : _c.id;
        await syncSubscriptionToUser(stripe, uid, chosen.status, priceId);
        return { ok: true, status: chosen.status };
    }
    await syncSubscriptionToUser(stripe, uid, "canceled", undefined);
    return { ok: true, status: "canceled" };
});
exports.folioListVaultBackups = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files
        .filter((f) => !f.name.endsWith("/"))
        .map((f) => {
        var _a;
        const parts = f.name.split("/");
        const fileName = (_a = parts[parts.length - 1]) !== null && _a !== void 0 ? _a : f.name;
        return { fileName, storagePath: f.name };
    })
        .filter((x) => x.fileName.length > 0);
    items.sort((a, b) => b.fileName.localeCompare(a.fileName));
    return { items };
});
exports.folioListBackupVaults = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const bucket = admin.storage().bucket();
    const prefix = `users/${uid}/vaults/`;
    const [, , apiResponse] = (await bucket.getFiles({
        prefix,
        delimiter: "/",
        autoPaginate: false,
    }));
    const prefixes = (_b = apiResponse === null || apiResponse === void 0 ? void 0 : apiResponse.prefixes) !== null && _b !== void 0 ? _b : [];
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
    const nameById = new Map();
    for (const d of indexSnap.docs) {
        const data = d.data();
        const name = typeof data.displayName === "string" ? data.displayName.trim() : "";
        if (name)
            nameById.set(d.id, name);
    }
    const vaults = vaultIds.map((id) => {
        var _a;
        return ({
            vaultId: id,
            displayName: (_a = nameById.get(id)) !== null && _a !== void 0 ? _a : "",
        });
    });
    return { vaults };
});
exports.folioUpsertVaultBackupIndex = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const displayNameRaw = (_c = request.data) === null || _c === void 0 ? void 0 : _c.displayName;
    const displayName = typeof displayNameRaw === "string" ? displayNameRaw.trim() : "";
    await db
        .collection("users")
        .doc(uid)
        .collection("vaultBackupIndex")
        .doc(vaultId)
        .set({
        displayName: displayName.slice(0, 120),
        updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.folioTrimVaultBackups = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const maxCountRaw = (_c = request.data) === null || _c === void 0 ? void 0 : _c.maxCount;
    const maxCount = typeof maxCountRaw === "number" && Number.isFinite(maxCountRaw)
        ? Math.max(1, Math.min(50, Math.trunc(maxCountRaw)))
        : 10;
    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files.filter((f) => !f.name.endsWith("/"));
    items.sort((a, b) => a.name.localeCompare(b.name));
    const toDelete = items.length > maxCount ? items.slice(0, items.length - maxCount) : [];
    let deleted = 0;
    const errors = [];
    for (const f of toDelete) {
        try {
            await f.delete();
            deleted++;
        }
        catch (e) {
            console.warn("folioTrimVaultBackups: delete failed", f.name, e);
            errors.push(f.name);
        }
    }
    return { ok: errors.length === 0, deleted, failed: errors.slice(0, 10) };
});
exports.createBillingPortalSession = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const stripe = stripeClient();
    if (!stripe) {
        throw new https_1.HttpsError("failed-precondition", "Stripe not configured on server");
    }
    const uid = request.auth.uid;
    const customerId = await ensureStripeCustomerId(stripe, uid);
    if (!customerId) {
        throw new https_1.HttpsError("failed-precondition", "No Stripe customer yet. Complete checkout first.");
    }
    const baseUrl = ((_b = process.env.BILLING_PORTAL_RETURN_URL) === null || _b === void 0 ? void 0 : _b.trim()) || "https://folio.app";
    let session;
    try {
        session = await stripe.billingPortal.sessions.create({
            customer: customerId,
            return_url: baseUrl,
        });
    }
    catch (e) {
        console.error("createBillingPortalSession: Stripe billingPortal.sessions.create", e);
        throw new https_1.HttpsError("failed-precondition", `Stripe: ${stripeCallErrorMessage(e)}`);
    }
    if (!session.url) {
        throw new https_1.HttpsError("failed-precondition", "Stripe did not return a billing portal URL");
    }
    return { url: session.url };
});
exports.monthlyInkRefill = (0, scheduler_1.onSchedule)({
    schedule: "0 8 1 * *",
    timeZone: INK_TIMEZONE,
    memory: "256MiB",
}, async () => {
    const stripe = stripeClient();
    const monthlyRaw = priceFolioCloudMonthly();
    if (!monthlyRaw || !stripe) {
        console.warn("monthlyInkRefill: STRIPE_PRICE_FOLIO_CLOUD_MONTHLY or Stripe key not set");
        return;
    }
    let monthlyResolved;
    try {
        monthlyResolved = await resolveCatalogIdToPriceId(stripe, monthlyRaw);
    }
    catch (e) {
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
        if (data.subscriptionPriceId &&
            data.subscriptionPriceId !== monthlyResolved) {
            continue;
        }
        const ref = db.collection("users").doc(uid);
        batch.set(ref, {
            "ink.monthlyBalance": MONTHLY_INK_ALLOWANCE,
            "ink.monthlyPeriodKey": periodKey,
            "ink.updatedAt": FieldValue.serverTimestamp(),
        }, { merge: true });
        n++;
        if (n >= 500) {
            await batch.commit();
            batch = db.batch();
            n = 0;
        }
    }
    if (n > 0)
        await batch.commit();
    console.log(`monthlyInkRefill: done ${periodKey}`);
});
/**
 * IA en nube en Cloud Functions **1st gen** (URL `*.cloudfunctions.net`, sin servicio Cloud Run v2).
 * Así se evita el perímetro IAM / límites típicos de Run que en Windows suelen aparecer como HTTP 429 o 401 HTML.
 */
exports.folioCloudAiComplete = functionsV1
    .region("us-central1")
    .runWith({ memory: "512MB", timeoutSeconds: 120 })
    .https.onCall(async (data, context) => {
    var _a;
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new AiHttpsError("unauthenticated", "Login required");
    }
    const uid = context.auth.uid;
    const prompt = normalizePrompt(data === null || data === void 0 ? void 0 : data.prompt);
    const systemPrompt = normalizeOptionalString(data === null || data === void 0 ? void 0 : data.systemPrompt, 20000);
    const messages = normalizeOpenAiMessages(data === null || data === void 0 ? void 0 : data.messages);
    const responseSchema = normalizeResponseSchema(data === null || data === void 0 ? void 0 : data.responseSchema);
    const maxTokens = normalizeClientMaxTokens(data === null || data === void 0 ? void 0 : data.maxTokens);
    const temperature = normalizeClientTemperature(data === null || data === void 0 ? void 0 : data.temperature);
    if (!prompt && messages.length === 0) {
        throw new AiHttpsError("invalid-argument", "Missing prompt/messages");
    }
    const operationKind = normalizeOperationKind(data === null || data === void 0 ? void 0 : data.operationKind);
    return runFolioCloudAiForUid(uid, {
        prompt,
        systemPrompt: systemPrompt || undefined,
        messages: messages.length > 0 ? messages : undefined,
        responseSchema,
        maxTokens,
        temperature,
    }, operationKind);
});
/**
 * Fallback HTTP para escritorio: evita bloqueos de infraestructura callable
 * cuando un despliegue previo o IAM externo interfiere con `onCall`.
 */
exports.folioCloudAiCompleteHttp = functionsV1
    .region("us-central1")
    .runWith({ memory: "512MB", timeoutSeconds: 120 })
    .https.onRequest(async (req, res) => {
    res.set("Cache-Control", "no-store");
    if (req.method !== "POST") {
        res.status(405).json(callableLikeErrorBody("invalid-argument", "Method not allowed"));
        return;
    }
    try {
        const uid = await verifiedUidFromBearerToken(req.header("authorization"));
        const body = req.body && typeof req.body === "object"
            ? req.body
            : {};
        const payload = body.data && typeof body.data === "object"
            ? body.data
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
        const result = await runFolioCloudAiForUid(uid, {
            prompt,
            systemPrompt: systemPrompt || undefined,
            messages: messages.length > 0 ? messages : undefined,
            responseSchema,
            maxTokens,
            temperature,
        }, operationKind);
        res.status(200).json({ result });
    }
    catch (e) {
        if (e instanceof AiHttpsError || e instanceof https_1.HttpsError) {
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
//# sourceMappingURL=index.js.map