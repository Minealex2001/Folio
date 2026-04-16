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
exports.folioCloudAiCompleteHttp = exports.folioCloudAiComplete = exports.monthlyInkRefill = exports.folioCloudTranscribeChunk = exports.createBillingPortalSession = exports.folioTrimVaultBackups = exports.folioRecordVaultBackupMeta = exports.folioGetLatestVaultBackupMeta = exports.folioUpsertVaultBackupIndex = exports.folioListBackupVaults = exports.folioTrimVaultBackupsByBytes = exports.folioListVaultBackups = exports.validateMicrosoftStoreEntitlements = exports.syncFolioCloudSubscriptionFromStripe = exports.createCheckoutSession = exports.closeCollabRoom = exports.removeCollabMember = exports.inviteCollabMember = exports.commitCollabMediaUpload = exports.prepareCollabMediaUpload = exports.joinCollabRoomByCode = exports.createCollabRoom = exports.stripeWebhook = exports.folioCloudAiPricing = void 0;
const path = __importStar(require("path"));
const dotenv_1 = require("dotenv");
// Carga `functions/.env` (gitignored). En deploy, Firebase también inyecta estas variables.
(0, dotenv_1.config)({ path: path.resolve(__dirname, "../.env") });
const admin = __importStar(require("firebase-admin"));
const crypto_1 = require("crypto");
const functionsV1 = __importStar(require("firebase-functions/v1"));
const https_1 = require("firebase-functions/v2/https");
const https_2 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const stripe_1 = __importDefault(require("stripe"));
const microsoft_store_1 = require("./microsoft_store");
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
function openAiAudioTranscriptionsUrl() {
    return `${openAiBaseUrl()}/audio/transcriptions`;
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
    console.error("Quill Cloud inference HTTP error", status, raw.slice(0, 800));
    const quotaHint = "Esto viene del proveedor de inferencia de Quill Cloud (clave, cuota, facturación o modelo), no del saldo de gotas Folio en Firestore. Revisa la configuración de la función y los límites del proveedor.";
    if (status === 401 || status === 403 || status === 429) {
        throw new AiHttpsError("failed-precondition", openAiMsg ? `${openAiMsg} ${quotaHint}` : quotaHint);
    }
    if (status === 400 || status === 404) {
        const hint = status === 404
            ? " Comprueba el modelo y la URL base configurados en la función."
            : "";
        throw new AiHttpsError("failed-precondition", (openAiMsg || `Quill Cloud HTTP ${status}`) + hint);
    }
    throw new AiHttpsError("internal", openAiMsg || "Quill Cloud devolvió un error. Inténtalo más tarde.");
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
/**
 * Devuelve a la app la tabla vigente de costes de tinta.
 * Asi los cambios se mantienen en un solo sitio: backend.
 */
exports.folioCloudAiPricing = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    return {
        costByOperation: INK_COST_BY_OPERATION,
        inkMaxPerRequest: INK_MAX_PER_REQUEST,
        promptLengthSurchargeThreshold: INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD,
        extraForLongPrompt: INK_EXTRA_FOR_LONG_PROMPT,
        tokensPerSurchargeUnit: INK_TOKENS_PER_SURCHARGE_UNIT,
        maxTokenSurcharge: INK_MAX_TOKEN_SURCHARGE,
    };
});
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
        console.error("Quill Cloud API error object", json.error);
        throw new AiHttpsError("internal", "AI provider error");
    }
    const content = (_d = (_c = (_b = json.choices) === null || _b === void 0 ? void 0 : _b[0]) === null || _c === void 0 ? void 0 : _c.message) === null || _d === void 0 ? void 0 : _d.content;
    const text = typeof content === "string" ? content : "";
    if (!text.trim()) {
        const reason = (_f = (_e = json.choices) === null || _e === void 0 ? void 0 : _e[0]) === null || _f === void 0 ? void 0 : _f.finish_reason;
        console.warn("Quill Cloud empty model output", { reason });
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
 * Inferencia Quill Cloud (chat completions; mismo path y cuerpo que APIs compatibles).
 */
async function callOpenAiGenerate(prompt) {
    const key = openAiApiKey();
    if (!key) {
        throw new AiHttpsError("failed-precondition", "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor).");
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
    throw new AiHttpsError("internal", "Quill Cloud: demasiados reintentos. Prueba más tarde.");
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
    // Recortamos profundidad/tamaño más adelante con límites de prompt/ink; aquí también
    // reforzamos compatibilidad con json_schema.strict del proveedor.
    return enforceStrictObjectSchema(raw);
}
function enforceStrictObjectSchema(node) {
    const clone = { ...node };
    const nodeType = typeof clone.type === "string" ? clone.type : undefined;
    if (nodeType === "object") {
        clone.additionalProperties = false;
    }
    const properties = clone.properties;
    if (properties && typeof properties === "object" && !Array.isArray(properties)) {
        const nextProps = {};
        for (const [key, value] of Object.entries(properties)) {
            if (value && typeof value === "object" && !Array.isArray(value)) {
                nextProps[key] = enforceStrictObjectSchema(value);
            }
            else {
                nextProps[key] = value;
            }
        }
        clone.properties = nextProps;
        const requiredKeys = Object.keys(nextProps);
        const existingRequired = Array.isArray(clone.required)
            ? clone.required.filter((v) => typeof v === "string")
            : [];
        // En strict json_schema, el proveedor exige que required incluya todas las keys de properties.
        clone.required = Array.from(new Set([...existingRequired, ...requiredKeys]));
    }
    const items = clone.items;
    if (items && typeof items === "object" && !Array.isArray(items)) {
        clone.items = enforceStrictObjectSchema(items);
    }
    const anyOf = clone.anyOf;
    if (Array.isArray(anyOf)) {
        clone.anyOf = anyOf.map((value) => {
            if (value && typeof value === "object" && !Array.isArray(value)) {
                return enforceStrictObjectSchema(value);
            }
            return value;
        });
    }
    const oneOf = clone.oneOf;
    if (Array.isArray(oneOf)) {
        clone.oneOf = oneOf.map((value) => {
            if (value && typeof value === "object" && !Array.isArray(value)) {
                return enforceStrictObjectSchema(value);
            }
            return value;
        });
    }
    const allOf = clone.allOf;
    if (Array.isArray(allOf)) {
        clone.allOf = allOf.map((value) => {
            if (value && typeof value === "object" && !Array.isArray(value)) {
                return enforceStrictObjectSchema(value);
            }
            return value;
        });
    }
    return clone;
}
async function callOpenAiChatStructured(input) {
    var _a, _b, _c, _d, _e, _f;
    const key = openAiApiKey();
    if (!key) {
        throw new AiHttpsError("failed-precondition", "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor).");
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
    throw new AiHttpsError("internal", "Quill Cloud: demasiados reintentos. Prueba más tarde.");
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
/**
 * Fusiona `billing.stripe` + `billing.microsoftStore` en `folioCloud` y tinta mensual.
 * Sin Stripe en servidor: solo se considera el slice de Microsoft Store + legacy.
 */
async function recomputeEffectiveFolioCloud(uid) {
    var _a, _b, _c, _d;
    const stripe = stripeClient();
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();
    const data = ((_a = snap.data()) !== null && _a !== void 0 ? _a : {});
    const billing = (_b = data.billing) !== null && _b !== void 0 ? _b : {};
    const stripeBilling = billing.stripe;
    const msBilling = billing.microsoftStore;
    let stripeStatus = "canceled";
    let stripePriceId;
    let stripeActiveFlag = false;
    if (stripeBilling) {
        stripeStatus = String((_c = stripeBilling.subscriptionStatus) !== null && _c !== void 0 ? _c : "canceled");
        const sp = stripeBilling.subscriptionPriceId;
        stripePriceId = typeof sp === "string" && sp ? sp : undefined;
        stripeActiveFlag = Boolean(stripeBilling.active);
    }
    else {
        const fc = data.folioCloud;
        if (fc) {
            stripeStatus = String((_d = fc.subscriptionStatus) !== null && _d !== void 0 ? _d : "canceled");
            const sp = fc.subscriptionPriceId;
            stripePriceId = typeof sp === "string" && sp ? sp : undefined;
            stripeActiveFlag =
                Boolean(fc.active) && stripeStatus !== "canceled";
        }
    }
    const msMonthlyActive = Boolean(msBilling === null || msBilling === void 0 ? void 0 : msBilling.subscriptionActive);
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
    const features = {
        backup: stripeFeatures.backup || msFeatures.backup,
        cloudAi: stripeFeatures.cloudAi || msFeatures.cloudAi,
        publishWeb: stripeFeatures.publishWeb || msFeatures.publishWeb,
        realtimeCollab: stripeFeatures.realtimeCollab || msFeatures.realtimeCollab,
    };
    const folioActive = stripeActiveFlag || msMonthlyActive;
    let subscriptionStatus = stripeStatus;
    if (msMonthlyActive &&
        (!stripeActiveFlag || stripeStatus === "canceled")) {
        subscriptionStatus = "active";
    }
    let stripeMonthlyActive = false;
    if (stripeActiveFlag && stripe && stripePriceId) {
        stripeMonthlyActive = await isMonthlySubscriptionPrice(stripe, stripePriceId);
    }
    const needsMonthlyInk = stripeMonthlyActive || msMonthlyActive;
    await ref.set({
        folioCloud: {
            subscriptionStatus,
            active: folioActive,
            features,
            subscriptionPriceId: stripePriceId !== null && stripePriceId !== void 0 ? stripePriceId : null,
            updatedAt: FieldValue.serverTimestamp(),
        },
    }, { merge: true });
    if (needsMonthlyInk) {
        const currentPeriodKey = monthPeriodKeyEuropeMadrid();
        const FieldPath = admin.firestore.FieldPath;
        const deleteDotted = {
            [new FieldPath("ink.monthlyBalance")]: FieldValue.delete(),
            [new FieldPath("ink.purchasedBalance")]: FieldValue.delete(),
            [new FieldPath("ink.monthlyPeriodKey")]: FieldValue.delete(),
            [new FieldPath("ink.updatedAt")]: FieldValue.delete(),
        };
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const txSnap = await tx.get(ref);
            const txData = ((_a = txSnap.data()) !== null && _a !== void 0 ? _a : {});
            const inkRaw = (_b = txData.ink) !== null && _b !== void 0 ? _b : {};
            const existingMonthly = inkBalanceField(inkRaw.monthlyBalance);
            const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
            const dottedMonthly = inkBalanceField(txData["ink.monthlyBalance"]);
            const dottedPurchased = inkBalanceField(txData["ink.purchasedBalance"]);
            const monthlyBalance = Math.max(existingMonthly, dottedMonthly);
            const purchasedBalance = Math.max(existingPurchased, dottedPurchased);
            const rawKey = typeof inkRaw.monthlyPeriodKey === "string"
                ? inkRaw.monthlyPeriodKey.trim()
                : "";
            const dottedKey = typeof txData["ink.monthlyPeriodKey"] === "string"
                ? String(txData["ink.monthlyPeriodKey"]).trim()
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
                ...deleteDotted,
            }, { merge: true });
        });
        let subIndexPrice = stripeMonthlyActive ? (stripePriceId !== null && stripePriceId !== void 0 ? stripePriceId : null) : null;
        if (stripeMonthlyActive && stripe && !subIndexPrice) {
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
            microsoftStoreMonthly: msMonthlyActive,
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
            const txSnap = await tx.get(ref);
            const txData = ((_a = txSnap.data()) !== null && _a !== void 0 ? _a : {});
            const inkRaw = (_b = txData.ink) !== null && _b !== void 0 ? _b : {};
            const existingPurchased = inkBalanceField(inkRaw.purchasedBalance);
            const dottedPurchased = inkBalanceField(txData["ink.purchasedBalance"]);
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
async function syncSubscriptionToUser(stripe, uid, status, priceId) {
    const active = status === "active" || status === "trialing" || status === "past_due";
    const ref = db.collection("users").doc(uid);
    await ref.set({
        billing: {
            stripe: {
                subscriptionStatus: status,
                subscriptionPriceId: priceId !== null && priceId !== void 0 ? priceId : null,
                active,
                updatedAt: FieldValue.serverTimestamp(),
            },
        },
    }, { merge: true });
    await recomputeEffectiveFolioCloud(uid);
}
async function grantMicrosoftStoreConsumableInk(uid, grants) {
    for (const g of grants) {
        if (g.drops <= 0)
            continue;
        const docId = (0, crypto_1.createHash)("sha256")
            .update(`${uid}:${g.dedupKey}`)
            .digest("hex")
            .slice(0, 64);
        const doneRef = db.collection("microsoftStoreProcessedPurchases").doc(docId);
        await db.runTransaction(async (tx) => {
            const doneSnap = await tx.get(doneRef);
            if (doneSnap.exists)
                return;
            tx.set(doneRef, {
                uid,
                dedupKey: g.dedupKey,
                drops: g.drops,
                processedAt: FieldValue.serverTimestamp(),
            });
            const uref = db.collection("users").doc(uid);
            tx.set(uref, {
                "ink.purchasedBalance": FieldValue.increment(g.drops),
                "ink.updatedAt": FieldValue.serverTimestamp(),
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
/** Igual que Firestore rules `folioRealtimeCollabOk`. */
async function assertFolioRealtimeCollabAllowed(uid) {
    var _a;
    const snap = await db.collection("users").doc(uid).get();
    const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const fc = data.folioCloud;
    const features = fc === null || fc === void 0 ? void 0 : fc.features;
    if ((fc === null || fc === void 0 ? void 0 : fc.active) !== true || (features === null || features === void 0 ? void 0 : features.realtimeCollab) !== true) {
        throw new https_1.HttpsError("permission-denied", "Real-time collaboration is not enabled for this account.");
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
function normalizeCollabJoinCode(raw) {
    // Debe coincidir con `CollabE2eCrypto.normalizeJoinCode` en el cliente (HKDF + índice).
    return raw.replace(/\s+/g, "").trim();
}
function collabJoinCodeKey(norm) {
    return (0, crypto_1.createHash)("sha256").update(norm, "utf8").digest("hex");
}
function generateCollabJoinCode() {
    const pick = () => {
        var _a;
        return (_a = COLLAB_JOIN_EMOJIS[Math.floor(Math.random() * COLLAB_JOIN_EMOJIS.length)]) !== null && _a !== void 0 ? _a : "\u{2B50}";
    };
    const a = pick();
    const b = pick();
    const n = String(Math.floor(Math.random() * 10000)).padStart(4, "0");
    return `${a}${b}${n}`;
}
exports.createCollabRoom = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioRealtimeCollabAllowed(uid);
    const vaultPageId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultPageId) === "string"
        ? request.data.vaultPageId.trim()
        : "";
    if (!vaultPageId || vaultPageId.length > 128) {
        throw new https_1.HttpsError("invalid-argument", "vaultPageId invalid");
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
                    throw new https_1.HttpsError("failed-precondition", "Room already created");
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
        }
        catch (e) {
            if (e instanceof Error && e.message === "join_code_collision") {
                continue;
            }
            throw e;
        }
    }
    throw new https_1.HttpsError("internal", "Could not allocate join code");
});
exports.joinCollabRoomByCode = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const raw = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.joinCode) === "string"
        ? request.data.joinCode.trim()
        : "";
    if (raw.length < 4 || raw.length > 64) {
        throw new https_1.HttpsError("invalid-argument", "Invalid join code");
    }
    const key = collabJoinCodeKey(normalizeCollabJoinCode(raw));
    const indexRef = db.collection("collabJoinIndex").doc(key);
    const idxSnap = await indexRef.get();
    if (!idxSnap.exists) {
        throw new https_1.HttpsError("not-found", "Room not found");
    }
    const roomId = (_c = idxSnap.data()) === null || _c === void 0 ? void 0 : _c.roomId;
    if (!roomId) {
        throw new https_1.HttpsError("not-found", "Room not found");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    await db.runTransaction(async (tx) => {
        var _a, _b;
        const snap = await tx.get(roomRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Room not found");
        }
        const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        const members = (_b = d.memberUids) !== null && _b !== void 0 ? _b : [];
        if (members.includes(uid)) {
            return;
        }
        if (members.length >= COLLAB_MAX_MEMBERS) {
            throw new https_1.HttpsError("failed-precondition", "Room is full");
        }
        tx.update(roomRef, {
            memberUids: FieldValue.arrayUnion(uid),
            [`memberJoinedAt.${uid}`]: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
        });
    });
    return { roomId };
});
exports.prepareCollabMediaUpload = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioRealtimeCollabAllowed(uid);
    const roomId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.roomId) === "string" ? request.data.roomId.trim() : "";
    if (!roomId) {
        throw new https_1.HttpsError("invalid-argument", "roomId required");
    }
    const blockId = typeof ((_c = request.data) === null || _c === void 0 ? void 0 : _c.blockId) === "string" ? request.data.blockId.trim() : "";
    if (!blockId || blockId.length > 128) {
        throw new https_1.HttpsError("invalid-argument", "blockId invalid");
    }
    const mediaKind = typeof ((_d = request.data) === null || _d === void 0 ? void 0 : _d.mediaKind) === "string" ? request.data.mediaKind.trim() : "";
    if (!COLLAB_ALLOWED_MEDIA_KINDS.has(mediaKind)) {
        throw new https_1.HttpsError("invalid-argument", "mediaKind invalid");
    }
    const sizeBytes = Number((_f = (_e = request.data) === null || _e === void 0 ? void 0 : _e.sizeBytes) !== null && _f !== void 0 ? _f : 0);
    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > COLLAB_MEDIA_MAX_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "sizeBytes invalid");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
        throw new https_1.HttpsError("not-found", "Room not found");
    }
    const room = (_g = roomSnap.data()) !== null && _g !== void 0 ? _g : {};
    const members = (_h = room.memberUids) !== null && _h !== void 0 ? _h : [];
    if (!members.includes(uid) && room.ownerUid !== uid) {
        throw new https_1.HttpsError("permission-denied", "Not a room member");
    }
    if (room.e2eV !== 1) {
        throw new https_1.HttpsError("failed-precondition", "Room must be e2eV=1");
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
exports.commitCollabMediaUpload = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioRealtimeCollabAllowed(uid);
    const roomId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.roomId) === "string" ? request.data.roomId.trim() : "";
    const mediaId = typeof ((_c = request.data) === null || _c === void 0 ? void 0 : _c.mediaId) === "string" ? request.data.mediaId.trim() : "";
    const blockId = typeof ((_d = request.data) === null || _d === void 0 ? void 0 : _d.blockId) === "string" ? request.data.blockId.trim() : "";
    const storagePath = typeof ((_e = request.data) === null || _e === void 0 ? void 0 : _e.storagePath) === "string" ? request.data.storagePath.trim() : "";
    const mediaKind = typeof ((_f = request.data) === null || _f === void 0 ? void 0 : _f.mediaKind) === "string" ? request.data.mediaKind.trim() : "";
    const mimeType = typeof ((_g = request.data) === null || _g === void 0 ? void 0 : _g.mimeType) === "string" ? request.data.mimeType.trim() : "";
    const fileName = typeof ((_h = request.data) === null || _h === void 0 ? void 0 : _h.fileName) === "string" ? request.data.fileName.trim() : "";
    const sizeBytes = Number((_k = (_j = request.data) === null || _j === void 0 ? void 0 : _j.sizeBytes) !== null && _k !== void 0 ? _k : 0);
    if (!roomId || !mediaId || !blockId || !storagePath || !mediaKind) {
        throw new https_1.HttpsError("invalid-argument", "Missing required media fields");
    }
    if (!COLLAB_ALLOWED_MEDIA_KINDS.has(mediaKind)) {
        throw new https_1.HttpsError("invalid-argument", "mediaKind invalid");
    }
    if (!storagePath.startsWith(`collab-media-e2e/${roomId}/${mediaId}`)) {
        throw new https_1.HttpsError("invalid-argument", "storagePath invalid");
    }
    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > COLLAB_MEDIA_MAX_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "sizeBytes invalid");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
        throw new https_1.HttpsError("not-found", "Room not found");
    }
    const room = (_l = roomSnap.data()) !== null && _l !== void 0 ? _l : {};
    const members = (_m = room.memberUids) !== null && _m !== void 0 ? _m : [];
    if (!members.includes(uid) && room.ownerUid !== uid) {
        throw new https_1.HttpsError("permission-denied", "Not a room member");
    }
    if (room.e2eV !== 1) {
        throw new https_1.HttpsError("failed-precondition", "Room must be e2eV=1");
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
    }
    catch (e) {
        const code = e.code;
        if (code === 6 || code === "6" || code === "already-exists") {
            throw new https_1.HttpsError("already-exists", "Media already committed");
        }
        throw e;
    }
    return { ok: true };
});
exports.inviteCollabMember = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioRealtimeCollabAllowed(uid);
    const roomId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.roomId) === "string" ? request.data.roomId.trim() : "";
    if (!roomId) {
        throw new https_1.HttpsError("invalid-argument", "roomId required");
    }
    const targetUid = typeof ((_c = request.data) === null || _c === void 0 ? void 0 : _c.targetUid) === "string"
        ? request.data.targetUid.trim()
        : "";
    if (!targetUid || targetUid === uid) {
        throw new https_1.HttpsError("invalid-argument", "targetUid invalid");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    await db.runTransaction(async (tx) => {
        var _a, _b;
        const snap = await tx.get(roomRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Room not found");
        }
        const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        if (d.ownerUid !== uid) {
            throw new https_1.HttpsError("permission-denied", "Only the owner can invite");
        }
        const members = (_b = d.memberUids) !== null && _b !== void 0 ? _b : [];
        if (members.includes(targetUid)) {
            return;
        }
        if (members.length >= COLLAB_MAX_MEMBERS) {
            throw new https_1.HttpsError("failed-precondition", `Room has at most ${COLLAB_MAX_MEMBERS} members`);
        }
        tx.update(roomRef, {
            memberUids: FieldValue.arrayUnion(targetUid),
            updatedAt: FieldValue.serverTimestamp(),
        });
    });
    return { ok: true };
});
exports.removeCollabMember = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const roomId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.roomId) === "string" ? request.data.roomId.trim() : "";
    if (!roomId) {
        throw new https_1.HttpsError("invalid-argument", "roomId required");
    }
    const targetUid = typeof ((_c = request.data) === null || _c === void 0 ? void 0 : _c.targetUid) === "string"
        ? request.data.targetUid.trim()
        : "";
    if (!targetUid) {
        throw new https_1.HttpsError("invalid-argument", "targetUid required");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(roomRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Room not found");
        }
        const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        const ownerUid = d.ownerUid;
        if (uid !== ownerUid && uid !== targetUid) {
            throw new https_1.HttpsError("permission-denied", "Not allowed");
        }
        if (targetUid === ownerUid) {
            throw new https_1.HttpsError("invalid-argument", "Cannot remove the owner");
        }
        tx.update(roomRef, {
            memberUids: FieldValue.arrayRemove(targetUid),
            updatedAt: FieldValue.serverTimestamp(),
        });
    });
    return { ok: true };
});
exports.closeCollabRoom = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const roomId = typeof ((_b = request.data) === null || _b === void 0 ? void 0 : _b.roomId) === "string" ? request.data.roomId.trim() : "";
    if (!roomId) {
        throw new https_1.HttpsError("invalid-argument", "roomId required");
    }
    const roomRef = db.collection("collabRooms").doc(roomId);
    const snap = await roomRef.get();
    if (!snap.exists) {
        throw new https_1.HttpsError("not-found", "Room not found");
    }
    const d = (_c = snap.data()) !== null && _c !== void 0 ? _c : {};
    const ownerUid = (_d = d.ownerUid) !== null && _d !== void 0 ? _d : "";
    if (!ownerUid || ownerUid != uid) {
        throw new https_1.HttpsError("permission-denied", "Only the owner can close the room");
    }
    const joinCodeKey = typeof d.joinCodeKey === "string" ? d.joinCodeKey.trim() : "";
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
exports.validateMicrosoftStoreEntitlements = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const collectionsId = String((_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.collectionsId) !== null && _c !== void 0 ? _c : "").trim();
    if (!collectionsId) {
        throw new https_1.HttpsError("invalid-argument", "collectionsId is required");
    }
    if (!(0, microsoft_store_1.microsoftStoreValidationConfigured)()) {
        throw new https_1.HttpsError("failed-precondition", "Microsoft Store validation is not configured on the server.");
    }
    const uid = request.auth.uid;
    const items = await (0, microsoft_store_1.queryMicrosoftStoreUserCollection)(collectionsId);
    const scan = (0, microsoft_store_1.scanMicrosoftStoreCollectionItems)(items);
    await db.collection("users").doc(uid).set({
        billing: {
            microsoftStore: {
                subscriptionActive: scan.subscriptionActive,
                subscriptionStoreProductId: scan.subscriptionStoreProductId,
                lastValidatedAt: FieldValue.serverTimestamp(),
                lastItemCount: items.length,
            },
        },
    }, { merge: true });
    await grantMicrosoftStoreConsumableInk(uid, scan.consumableGrants);
    await recomputeEffectiveFolioCloud(uid);
    return {
        ok: true,
        subscriptionActive: scan.subscriptionActive,
        storeItems: items.length,
    };
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
        var _a, _b;
        const meta = ((_a = f.metadata) !== null && _a !== void 0 ? _a : {});
        const rawSize = meta["size"];
        const sizeBytes = typeof rawSize === "number"
            ? rawSize
            : typeof rawSize === "string"
                ? Number(rawSize)
                : 0;
        const timeCreated = typeof meta["timeCreated"] === "string" ? meta["timeCreated"] : "";
        const parts = f.name.split("/");
        const fileName = (_b = parts[parts.length - 1]) !== null && _b !== void 0 ? _b : f.name;
        return {
            fileName,
            storagePath: f.name,
            sizeBytes: Number.isFinite(sizeBytes) && sizeBytes > 0 ? sizeBytes : 0,
            createdAt: timeCreated,
        };
    })
        .filter((x) => x.fileName.length > 0);
    items.sort((a, b) => b.fileName.localeCompare(a.fileName));
    return { items };
});
exports.folioTrimVaultBackupsByBytes = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const maxBytesRaw = (_c = request.data) === null || _c === void 0 ? void 0 : _c.maxBytes;
    const maxBytes = typeof maxBytesRaw === "number" && Number.isFinite(maxBytesRaw)
        ? Math.max(1, Math.min(50 * 1024 * 1024 * 1024, Math.trunc(maxBytesRaw)))
        : 5 * 1024 * 1024 * 1024; // default 5 GB
    const prefix = `users/${uid}/vaults/${vaultId}/backups/`;
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix, autoPaginate: true });
    const items = files.filter((f) => !f.name.endsWith("/"));
    const sizeOf = (f) => {
        var _a;
        const meta = ((_a = f === null || f === void 0 ? void 0 : f.metadata) !== null && _a !== void 0 ? _a : {});
        const raw = meta["size"];
        const n = typeof raw === "number" ? raw : typeof raw === "string" ? Number(raw) : 0;
        return Number.isFinite(n) && n > 0 ? n : 0;
    };
    // Oldest first by name (timestamps in filename sort lexicographically).
    items.sort((a, b) => a.name.localeCompare(b.name));
    let totalBytes = 0;
    for (const f of items)
        totalBytes += sizeOf(f);
    const toDelete = [];
    for (const f of items) {
        if (totalBytes <= maxBytes)
            break;
        const sz = sizeOf(f);
        toDelete.push(f);
        totalBytes -= sz;
    }
    let deleted = 0;
    const errors = [];
    for (const f of toDelete) {
        try {
            await f.delete();
            deleted++;
        }
        catch (e) {
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
exports.folioGetLatestVaultBackupMeta = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c, _d;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const ref = db
        .collection("users")
        .doc(uid)
        .collection("vaultBackups")
        .doc(vaultId);
    const snap = await ref.get();
    const data = ((_c = snap.data()) !== null && _c !== void 0 ? _c : {});
    return {
        ok: true,
        latest: {
            storagePath: typeof data.latestStoragePath === "string" ? data.latestStoragePath : "",
            fileName: typeof data.latestFileName === "string" ? data.latestFileName : "",
            fingerprint: typeof data.latestFingerprint === "string" ? data.latestFingerprint : "",
            sizeBytes: typeof data.latestSizeBytes === "number" ? data.latestSizeBytes : 0,
            containerFormat: typeof data.latestContainerFormat === "string"
                ? data.latestContainerFormat
                : "",
            updatedAt: (_d = data.latestUpdatedAt) !== null && _d !== void 0 ? _d : null,
        },
    };
});
exports.folioRecordVaultBackupMeta = (0, https_1.onCall)({ cors: true, invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    await assertFolioCloudBackupAllowed(uid);
    const vaultId = assertValidVaultId((_b = request.data) === null || _b === void 0 ? void 0 : _b.vaultId);
    const fileNameRaw = (_c = request.data) === null || _c === void 0 ? void 0 : _c.fileName;
    const storagePathRaw = (_d = request.data) === null || _d === void 0 ? void 0 : _d.storagePath;
    const fingerprintRaw = (_e = request.data) === null || _e === void 0 ? void 0 : _e.fingerprint;
    const sizeBytesRaw = (_f = request.data) === null || _f === void 0 ? void 0 : _f.sizeBytes;
    const containerFormatRaw = (_g = request.data) === null || _g === void 0 ? void 0 : _g.containerFormat;
    const vaultBytesRaw = (_h = request.data) === null || _h === void 0 ? void 0 : _h.vaultBytes;
    const attachmentsBytesRaw = (_j = request.data) === null || _j === void 0 ? void 0 : _j.attachmentsBytes;
    const fileName = typeof fileNameRaw === "string" ? fileNameRaw.trim() : "";
    const storagePath = typeof storagePathRaw === "string" ? storagePathRaw.trim() : "";
    const fingerprint = typeof fingerprintRaw === "string" ? fingerprintRaw.trim() : "";
    const containerFormat = typeof containerFormatRaw === "string" ? containerFormatRaw.trim() : "";
    const sizeBytes = typeof sizeBytesRaw === "number" && Number.isFinite(sizeBytesRaw)
        ? Math.max(0, Math.trunc(sizeBytesRaw))
        : 0;
    const vaultBytes = typeof vaultBytesRaw === "number" && Number.isFinite(vaultBytesRaw)
        ? Math.max(0, Math.trunc(vaultBytesRaw))
        : 0;
    const attachmentsBytes = typeof attachmentsBytesRaw === "number" && Number.isFinite(attachmentsBytesRaw)
        ? Math.max(0, Math.trunc(attachmentsBytesRaw))
        : 0;
    if (!fileName || fileName.length > 220) {
        throw new https_1.HttpsError("invalid-argument", "fileName invalid");
    }
    if (!storagePath || storagePath.length > 600) {
        throw new https_1.HttpsError("invalid-argument", "storagePath invalid");
    }
    if (!storagePath.startsWith(`users/${uid}/vaults/${vaultId}/backups/`)) {
        throw new https_1.HttpsError("invalid-argument", "storagePath invalid");
    }
    if (!fingerprint || fingerprint.length > 200) {
        throw new https_1.HttpsError("invalid-argument", "fingerprint invalid");
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
    batch.set(itemRef, {
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
    }, { merge: true });
    batch.set(vaultRef, {
        latestFileName: fileName,
        latestStoragePath: storagePath,
        latestFingerprint: fingerprint,
        latestContainerFormat: containerFormat.slice(0, 40),
        latestSizeBytes: sizeBytes,
        latestUpdatedAt: now,
    }, { merge: true });
    await batch.commit();
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
/**
 * Recibe segmentos de Whisper verbose_json y devuelve texto formateado
 * "Speaker N: ..." usando GPT-4o-mini para detectar cambios de hablante.
 */
async function _diarizeSegmentsWithGpt(segments, inferenceApiKey) {
    var _a, _b, _c, _d, _e, _f, _g;
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
                    content: "You are a speaker diarization assistant. Analyze transcript segments from a meeting " +
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
    const gptResult = (await resp.json());
    const raw = (_d = (_c = (_b = (_a = gptResult.choices) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.message) === null || _c === void 0 ? void 0 : _c.content) !== null && _d !== void 0 ? _d : "";
    const parsed = JSON.parse(raw);
    let turns = [];
    if (Array.isArray(parsed)) {
        turns = parsed;
    }
    else if (parsed && typeof parsed === "object") {
        const obj = parsed;
        const arr = (_g = (_f = (_e = obj["turns"]) !== null && _e !== void 0 ? _e : obj["speakers"]) !== null && _f !== void 0 ? _f : obj["segments"]) !== null && _g !== void 0 ? _g : Object.values(obj)[0];
        if (Array.isArray(arr))
            turns = arr;
    }
    if (!turns.length)
        throw new Error("Empty diarization response from model");
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
exports.folioCloudTranscribeChunk = (0, https_1.onCall)({ cors: true, invoker: "public", memory: "512MiB", timeoutSeconds: 60 }, async (request) => {
    var _a, _b, _c, _d, _e;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = request.data;
    const audioBase64 = typeof data.audioBase64 === "string" ? data.audioBase64.trim() : "";
    if (!audioBase64) {
        throw new https_1.HttpsError("invalid-argument", "audioBase64 required");
    }
    const language = typeof data.language === "string" ? data.language.trim() : "";
    const chargeInk = data.chargeInk === true;
    const baseInkCost = (_b = INK_COST_BY_OPERATION["transcribe_cloud"]) !== null && _b !== void 0 ? _b : 1;
    const inkAmountRaw = data.inkAmount;
    const inkCost = chargeInk &&
        typeof inkAmountRaw === "number" &&
        Number.isFinite(inkAmountRaw) &&
        inkAmountRaw >= 1
        ? Math.ceil(inkAmountRaw)
        : baseInkCost;
    let inkDebited = false;
    // ── Debitar Tinta si se solicita ─────────────────────────────────────────
    if (chargeInk) {
        const inkExhaustedMsg = "Tinta insuficiente para la transcripción en la nube. Compra un tintero, " +
            "espera la recarga mensual con suscripción activa, o usa transcripción local.";
        const userRef = db.collection("users").doc(uid);
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const snap = await tx.get(userRef);
            const dataDoc = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
            const fc = dataDoc.folioCloud;
            const hasSubCloudAi = (fc === null || fc === void 0 ? void 0 : fc.active) === true &&
                ((_b = fc === null || fc === void 0 ? void 0 : fc.features) === null || _b === void 0 ? void 0 : _b.cloudAi) === true;
            const { monthly, purchased } = readInkBalances(dataDoc);
            if (hasSubCloudAi) {
                if (monthly + purchased < inkCost) {
                    throw new https_1.HttpsError("resource-exhausted", inkExhaustedMsg);
                }
                const next = debitInkBalances(monthly, purchased, inkCost);
                tx.update(userRef, {
                    "ink.monthlyBalance": next.monthly,
                    "ink.purchasedBalance": next.purchased,
                    "ink.updatedAt": FieldValue.serverTimestamp(),
                });
            }
            else {
                if (purchased < inkCost) {
                    throw new https_1.HttpsError("resource-exhausted", inkExhaustedMsg);
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
    // ── Transcripción de audio (endpoint del proveedor Quill Cloud) ───────────
    const inferenceApiKey = openAiApiKey();
    if (!inferenceApiKey) {
        if (inkDebited) {
            await refundInkDropCharge(uid, inkCost).catch((e) => console.error("folioCloudTranscribeChunk: refund after missing key", e));
        }
        throw new https_1.HttpsError("failed-precondition", "Quill Cloud: inferencia no configurada en Cloud Functions (clave API del proveedor).");
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
        const resp = await fetch(openAiAudioTranscriptionsUrl(), {
            method: "POST",
            headers: { Authorization: `Bearer ${inferenceApiKey}` },
            body: form,
        });
        if (!resp.ok) {
            const errBody = await resp.text().catch(() => `HTTP ${resp.status}`);
            console.error("folioCloudTranscribeChunk: transcription API error", resp.status, errBody);
            throw new https_1.HttpsError("internal", `Transcription failed (${resp.status})`);
        }
        const verboseResult = (await resp.json());
        const rawText = ((_c = verboseResult.text) !== null && _c !== void 0 ? _c : "").trim();
        const segments = (_d = verboseResult.segments) !== null && _d !== void 0 ? _d : [];
        if (rawText.length === 0) {
            transcript = "";
        }
        else if (segments.length > 1) {
            // Diarización con el modelo de chat configurado
            try {
                transcript = await _diarizeSegmentsWithGpt(segments, inferenceApiKey);
            }
            catch (diarErr) {
                console.warn("folioCloudTranscribeChunk: diarization fallback to plain text", diarErr);
                transcript = `Speaker 1: ${rawText}`;
            }
        }
        else {
            // Un solo segmento: etiquetar como hablante 1
            transcript = `Speaker 1: ${rawText}`;
        }
    }
    catch (e) {
        if (inkDebited) {
            await refundInkDropCharge(uid, inkCost).catch((re) => console.error("folioCloudTranscribeChunk: refund after transcription error", re));
        }
        if (e instanceof https_1.HttpsError)
            throw e;
        throw new https_1.HttpsError("internal", "Transcription request failed");
    }
    // ── Leer saldos finales ───────────────────────────────────────────────────
    const finalSnap = await db.collection("users").doc(uid).get();
    const inkOut = readInkBalances(((_e = finalSnap.data()) !== null && _e !== void 0 ? _e : {}));
    return {
        transcript,
        ink: {
            monthlyBalance: inkOut.monthly,
            purchasedBalance: inkOut.purchased,
        },
    };
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
        const stripeMatch = data.subscriptionPriceId &&
            data.subscriptionPriceId === monthlyResolved;
        const msMonthly = data.microsoftStoreMonthly === true;
        if (!stripeMatch && !msMonthly) {
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