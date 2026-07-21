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
Object.defineProperty(exports, "__esModule", { value: true });
exports.folioTeamsCommand = exports.folioSlackCommand = exports.folioAckIntegrationCommand = exports.folioRegisterIntegrationLinkCode = exports.folioIntegrationWebhookProxy = exports.folioUpsertIntegrationWebhookConnection = void 0;
exports.parseIntegrationCommand = parseIntegrationCommand;
require("./admin_init");
const admin = __importStar(require("firebase-admin"));
const crypto_1 = require("crypto");
const https_1 = require("firebase-functions/v2/https");
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const LINK_CODE_TTL_MS = 15 * 60 * 1000;
const MAX_TASK_TITLE_LEN = 200;
function integrationWebhookHostAllowed(hostname) {
    const h = hostname.toLowerCase();
    if (h === "hooks.slack.com")
        return true;
    if (h.endsWith(".logic.azure.com"))
        return true;
    if (h.endsWith(".powerplatform.com"))
        return true;
    if (h.endsWith(".office.com"))
        return true;
    if (h.endsWith(".office365.com"))
        return true;
    if (h.endsWith(".webhook.office.com"))
        return true;
    return false;
}
function slackSigningSecret() {
    var _a;
    return String((_a = process.env.SLACK_SIGNING_SECRET) !== null && _a !== void 0 ? _a : "").trim();
}
function normalizeCommandText(raw) {
    let t = String(raw !== null && raw !== void 0 ? raw : "").trim();
    t = t.replace(/^<at>.*?<\/at>\s*/gi, "");
    t = t.replace(/^@\S+\s+/, "");
    return t.trim();
}
function parseIntegrationCommand(raw) {
    const text = normalizeCommandText(raw);
    const link = text.match(/^\/folio\s+link\s+([A-Za-z0-9]{6,12})$/i);
    if (link) {
        return { kind: "link", code: link[1].toUpperCase() };
    }
    const create = text.match(/^\/folio\s+create\s+task\s+"([^"]+)"$/i);
    if (create) {
        const title = create[1].trim();
        if (!title || title.length > MAX_TASK_TITLE_LEN)
            return { kind: "unknown" };
        return { kind: "create_task", title };
    }
    return { kind: "unknown" };
}
function ackLatencyMessage() {
    return ("Folio queued your command. It will run the next time you open Folio " +
        "(may take from seconds to days). / Folio ha encolado tu comando. " +
        "Se aplicará la próxima vez que abras Folio (puede tardar de segundos a días).");
}
async function postWebhookJson(webhookUrl, payload) {
    const resp = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    if (!resp.ok) {
        const body = await resp.text();
        throw new Error(`webhook_post_failed ${resp.status} ${body}`);
    }
}
function verifySlackSignature(signingSecret, rawBody, timestamp, signature) {
    if (!signingSecret || !timestamp || !signature)
        return false;
    const ts = Number(timestamp);
    if (!Number.isFinite(ts))
        return false;
    const ageSec = Math.abs(Date.now() / 1000 - ts);
    if (ageSec > 60 * 5)
        return false;
    const base = `v0:${timestamp}:${rawBody.toString("utf8")}`;
    const digest = (0, crypto_1.createHmac)("sha256", signingSecret).update(base).digest("hex");
    const expected = `v0=${digest}`;
    try {
        return (0, crypto_1.timingSafeEqual)(Buffer.from(expected), Buffer.from(signature));
    }
    catch {
        return false;
    }
}
function verifyTeamsOutgoingHmac(securityToken, rawBody, authorization) {
    const token = securityToken.trim();
    if (!token || !authorization)
        return false;
    const hash = (0, crypto_1.createHmac)("sha256", Buffer.from(token, "utf8"))
        .update(rawBody)
        .digest("base64");
    const expected = `HMAC ${hash}`;
    try {
        return (0, crypto_1.timingSafeEqual)(Buffer.from(expected), Buffer.from(authorization.trim()));
    }
    catch {
        return false;
    }
}
async function resolveUserIndex(provider, externalUserId) {
    const id = `${provider}_${externalUserId}`;
    const snap = await db.collection("integrationUserIndex").doc(id).get();
    return snap.exists ? snap : null;
}
async function handleLinkCommand(provider, externalUserId, code) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const normalized = code.toUpperCase();
    const codeRef = db.collection("integrationLinkCodes").doc(normalized);
    const codeSnap = await codeRef.get();
    if (!codeSnap.exists) {
        return "Invalid or expired link code. Generate a new one in Folio Settings → Integrations.";
    }
    const data = (_a = codeSnap.data()) !== null && _a !== void 0 ? _a : {};
    const expiresAt = (_d = (_c = (_b = data.expiresAt) === null || _b === void 0 ? void 0 : _b.toMillis) === null || _c === void 0 ? void 0 : _c.call(_b)) !== null && _d !== void 0 ? _d : 0;
    if (Date.now() > expiresAt) {
        await codeRef.delete();
        return "Link code expired. Generate a new one in Folio Settings → Integrations.";
    }
    if (String((_e = data.provider) !== null && _e !== void 0 ? _e : "") !== provider) {
        return "This link code was created for a different provider.";
    }
    const firebaseUid = String((_f = data.firebaseUid) !== null && _f !== void 0 ? _f : "").trim();
    const vaultId = String((_g = data.vaultId) !== null && _g !== void 0 ? _g : "").trim();
    const connectionId = String((_h = data.connectionId) !== null && _h !== void 0 ? _h : "").trim();
    const webhookUrl = String((_j = data.webhookUrl) !== null && _j !== void 0 ? _j : "").trim();
    if (!firebaseUid || !vaultId || !connectionId || !webhookUrl) {
        return "Link code is incomplete. Generate a new one in Folio.";
    }
    const indexId = `${provider}_${externalUserId}`;
    await db.collection("integrationUserIndex").doc(indexId).set({
        provider,
        externalUserId,
        firebaseUid,
        vaultId,
        connectionId,
        webhookUrl,
        teamsSecurityToken: String((_k = data.teamsSecurityToken) !== null && _k !== void 0 ? _k : "").trim() || null,
        linkedAt: FieldValue.serverTimestamp(),
    });
    await codeRef.delete();
    return "Linked! You can now use `/folio create task \"Title\"` (or `@Folio create task \"Title\"` in Teams).";
}
async function enqueueCreateTask(provider, externalUserId, title) {
    var _a, _b, _c, _d, _e;
    const indexSnap = await resolveUserIndex(provider, externalUserId);
    if (!indexSnap) {
        return "Account not linked. In Folio Settings → Integrations, generate a link code and run `/folio link CODE`.";
    }
    const index = (_a = indexSnap.data()) !== null && _a !== void 0 ? _a : {};
    const firebaseUid = String((_b = index.firebaseUid) !== null && _b !== void 0 ? _b : "").trim();
    const vaultId = String((_c = index.vaultId) !== null && _c !== void 0 ? _c : "").trim();
    if (!firebaseUid || !vaultId) {
        return "Link index is invalid. Re-link your account from Folio.";
    }
    const cmdRef = db
        .collection("users")
        .doc(firebaseUid)
        .collection("pendingIntegrationCommands")
        .doc();
    await cmdRef.set({
        provider,
        externalUserId,
        vaultId,
        connectionId: String((_d = index.connectionId) !== null && _d !== void 0 ? _d : "").trim(),
        webhookUrl: String((_e = index.webhookUrl) !== null && _e !== void 0 ? _e : "").trim(),
        command: "create_task",
        title,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
    });
    return ackLatencyMessage();
}
async function dispatchParsedCommand(provider, externalUserId, parsed) {
    if (parsed.kind === "link") {
        return handleLinkCommand(provider, externalUserId, parsed.code);
    }
    if (parsed.kind === "create_task") {
        return enqueueCreateTask(provider, externalUserId, parsed.title);
    }
    return ("Unknown command. Supported: `/folio link CODE`, `/folio create task \"Title\"`.");
}
// Registers (or updates) the caller's own webhook connection server-side so
// folioIntegrationWebhookProxy never has to trust a client-supplied URL.
exports.folioUpsertIntegrationWebhookConnection = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = ((_b = request.data) !== null && _b !== void 0 ? _b : {});
    const connectionId = String((_c = data.connectionId) !== null && _c !== void 0 ? _c : "").trim();
    const provider = String((_d = data.provider) !== null && _d !== void 0 ? _d : "").trim();
    const webhookUrl = String((_e = data.webhookUrl) !== null && _e !== void 0 ? _e : "").trim();
    if (!connectionId) {
        throw new https_1.HttpsError("invalid-argument", "missing_connection_id");
    }
    if (provider !== "slack" && provider !== "teams") {
        throw new https_1.HttpsError("invalid-argument", "invalid_provider");
    }
    if (!webhookUrl) {
        throw new https_1.HttpsError("invalid-argument", "missing_webhook_url");
    }
    let host;
    try {
        host = new URL(webhookUrl).hostname;
    }
    catch {
        throw new https_1.HttpsError("invalid-argument", "invalid_webhook_url");
    }
    if (!integrationWebhookHostAllowed(host)) {
        throw new https_1.HttpsError("permission-denied", "webhook_host_not_allowed");
    }
    const ref = db.collection("integrationWebhookConnections").doc(connectionId);
    const existing = await ref.get();
    if (existing.exists && String((_g = (_f = existing.data()) === null || _f === void 0 ? void 0 : _f.firebaseUid) !== null && _g !== void 0 ? _g : "") !== uid) {
        // connectionId is client-generated (uuid-like); a collision with
        // someone else's id should never silently reassign ownership.
        throw new https_1.HttpsError("already-exists", "connection_id_taken");
    }
    await ref.set({
        firebaseUid: uid,
        provider,
        webhookUrl,
        updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.folioIntegrationWebhookProxy = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = ((_b = request.data) !== null && _b !== void 0 ? _b : {});
    const provider = String((_c = data.provider) !== null && _c !== void 0 ? _c : "").trim();
    const connectionId = String((_d = data.connectionId) !== null && _d !== void 0 ? _d : "").trim();
    const payload = data.payload;
    if (provider !== "slack" && provider !== "teams") {
        throw new https_1.HttpsError("invalid-argument", "invalid_provider");
    }
    if (!connectionId || typeof payload !== "object" || payload === null) {
        throw new https_1.HttpsError("invalid-argument", "missing_connection_or_payload");
    }
    const connSnap = await db
        .collection("integrationWebhookConnections")
        .doc(connectionId)
        .get();
    if (!connSnap.exists) {
        throw new https_1.HttpsError("not-found", "connection_not_found");
    }
    const conn = connSnap.data();
    if (String((_e = conn.firebaseUid) !== null && _e !== void 0 ? _e : "") !== uid || String((_f = conn.provider) !== null && _f !== void 0 ? _f : "") !== provider) {
        throw new https_1.HttpsError("permission-denied", "not_your_connection");
    }
    const webhookUrl = String((_g = conn.webhookUrl) !== null && _g !== void 0 ? _g : "").trim();
    let host;
    try {
        host = new URL(webhookUrl).hostname;
    }
    catch {
        throw new https_1.HttpsError("invalid-argument", "invalid_webhook_url");
    }
    if (!integrationWebhookHostAllowed(host)) {
        throw new https_1.HttpsError("permission-denied", "webhook_host_not_allowed");
    }
    const resp = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    if (!resp.ok) {
        const body = await resp.text();
        throw new https_1.HttpsError("internal", `webhook_failed_${resp.status}: ${body}`);
    }
    return { ok: true };
});
exports.folioRegisterIntegrationLinkCode = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = ((_b = request.data) !== null && _b !== void 0 ? _b : {});
    const code = String((_c = data.code) !== null && _c !== void 0 ? _c : "").trim().toUpperCase();
    const vaultId = String((_d = data.vaultId) !== null && _d !== void 0 ? _d : "").trim();
    const connectionId = String((_e = data.connectionId) !== null && _e !== void 0 ? _e : "").trim();
    const provider = String((_f = data.provider) !== null && _f !== void 0 ? _f : "").trim();
    const webhookUrl = String((_g = data.webhookUrl) !== null && _g !== void 0 ? _g : "").trim();
    const teamsSecurityToken = String((_h = data.teamsSecurityToken) !== null && _h !== void 0 ? _h : "").trim();
    if (!/^[A-Z0-9]{8}$/.test(code)) {
        throw new https_1.HttpsError("invalid-argument", "invalid_code");
    }
    if (!vaultId || !connectionId || !webhookUrl) {
        throw new https_1.HttpsError("invalid-argument", "missing_fields");
    }
    if (provider !== "slack" && provider !== "teams") {
        throw new https_1.HttpsError("invalid-argument", "invalid_provider");
    }
    let host;
    try {
        host = new URL(webhookUrl).hostname;
    }
    catch {
        throw new https_1.HttpsError("invalid-argument", "invalid_webhook_url");
    }
    if (!integrationWebhookHostAllowed(host)) {
        throw new https_1.HttpsError("permission-denied", "webhook_host_not_allowed");
    }
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + LINK_CODE_TTL_MS);
    await db.collection("integrationLinkCodes").doc(code).set({
        firebaseUid: uid,
        vaultId,
        connectionId,
        provider,
        webhookUrl,
        teamsSecurityToken: teamsSecurityToken || null,
        expiresAt,
        createdAt: FieldValue.serverTimestamp(),
    });
    if (provider === "teams" && teamsSecurityToken) {
        await db.collection("teamsWebhookEndpoints").doc(connectionId).set({
            teamsSecurityToken,
            firebaseUid: uid,
            updatedAt: FieldValue.serverTimestamp(),
        });
    }
    return { ok: true, expiresAtMs: expiresAt.toMillis() };
});
exports.folioAckIntegrationCommand = (0, https_1.onCall)({ invoker: "public" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    if (!((_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = ((_b = request.data) !== null && _b !== void 0 ? _b : {});
    const commandId = String((_c = data.commandId) !== null && _c !== void 0 ? _c : "").trim();
    const success = data.success === true;
    const taskTitle = String((_d = data.taskTitle) !== null && _d !== void 0 ? _d : "").trim();
    const errorMessage = String((_e = data.errorMessage) !== null && _e !== void 0 ? _e : "").trim();
    if (!commandId) {
        throw new https_1.HttpsError("invalid-argument", "missing_command_id");
    }
    const cmdRef = db
        .collection("users")
        .doc(uid)
        .collection("pendingIntegrationCommands")
        .doc(commandId);
    const cmdSnap = await cmdRef.get();
    if (!cmdSnap.exists) {
        throw new https_1.HttpsError("not-found", "command_not_found");
    }
    const cmd = (_f = cmdSnap.data()) !== null && _f !== void 0 ? _f : {};
    if (String((_g = cmd.status) !== null && _g !== void 0 ? _g : "") !== "pending") {
        return { ok: true, duplicate: true };
    }
    const webhookUrl = String((_h = cmd.webhookUrl) !== null && _h !== void 0 ? _h : "").trim();
    const provider = String((_j = cmd.provider) !== null && _j !== void 0 ? _j : "").trim();
    await cmdRef.set({
        status: success ? "applied" : "failed",
        processedAt: FieldValue.serverTimestamp(),
        errorMessage: success ? null : errorMessage || "unknown_error",
    }, { merge: true });
    if (webhookUrl) {
        const text = success
            ? `✅ Folio created task "${taskTitle || "untitled"}".`
            : `❌ Folio could not create the task: ${errorMessage || "unknown error"}.`;
        try {
            if (provider === "teams") {
                await postWebhookJson(webhookUrl, {
                    type: "message",
                    attachments: [
                        {
                            contentType: "application/vnd.microsoft.card.adaptive",
                            content: {
                                $schema: "http://adaptivecards.io/schemas/adaptive-card.json",
                                type: "AdaptiveCard",
                                version: "1.4",
                                body: [{ type: "TextBlock", text, wrap: true }],
                            },
                        },
                    ],
                });
            }
            else {
                await postWebhookJson(webhookUrl, { text });
            }
        }
        catch (err) {
            console.warn("folioAckIntegrationCommand: confirmation webhook failed", err);
        }
    }
    return { ok: true };
});
exports.folioSlackCommand = (0, https_1.onRequest)({ cors: false, memory: "256MiB", invoker: "public" }, async (req, res) => {
    var _a, _b, _c, _d;
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    const secret = slackSigningSecret();
    if (!secret) {
        res.status(503).send("Slack signing secret not configured");
        return;
    }
    const rawBody = req.rawBody;
    if (!rawBody) {
        res.status(400).send("Missing raw body");
        return;
    }
    const timestamp = String((_a = req.headers["x-slack-request-timestamp"]) !== null && _a !== void 0 ? _a : "");
    const signature = String((_b = req.headers["x-slack-signature"]) !== null && _b !== void 0 ? _b : "");
    if (!verifySlackSignature(secret, rawBody, timestamp, signature)) {
        res.status(401).send("Invalid signature");
        return;
    }
    const body = typeof req.body === "object" && req.body !== null
        ? req.body
        : {};
    const userId = String((_c = body.user_id) !== null && _c !== void 0 ? _c : "").trim();
    const commandText = String((_d = body.text) !== null && _d !== void 0 ? _d : "").trim();
    const fullText = commandText ? `/folio ${commandText}` : "/folio";
    const parsed = parseIntegrationCommand(fullText);
    try {
        const message = await dispatchParsedCommand("slack", userId, parsed);
        res.json({ response_type: "ephemeral", text: message });
    }
    catch (err) {
        console.error("folioSlackCommand", err);
        res.status(500).json({ response_type: "ephemeral", text: "Internal error." });
    }
});
exports.folioTeamsCommand = (0, https_1.onRequest)({ cors: false, memory: "256MiB", invoker: "public" }, async (req, res) => {
    var _a, _b, _c, _d, _e, _f;
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    const rawBody = req.rawBody;
    if (!rawBody) {
        res.status(400).send("Missing raw body");
        return;
    }
    const connectionId = String((_a = req.query.connectionId) !== null && _a !== void 0 ? _a : "").trim();
    if (!connectionId) {
        res.status(400).send("Missing connectionId query parameter");
        return;
    }
    const endpointSnap = await db.collection("teamsWebhookEndpoints").doc(connectionId).get();
    const token = String((_c = (_b = endpointSnap.data()) === null || _b === void 0 ? void 0 : _b.teamsSecurityToken) !== null && _c !== void 0 ? _c : "").trim();
    if (!token) {
        res.status(401).send("Unknown Teams webhook endpoint");
        return;
    }
    const authorization = String((_d = req.headers.authorization) !== null && _d !== void 0 ? _d : "");
    if (!verifyTeamsOutgoingHmac(token, rawBody, authorization)) {
        res.status(401).send("Invalid HMAC");
        return;
    }
    const body = typeof req.body === "object" && req.body !== null
        ? req.body
        : {};
    const from = body.from;
    const userId = String((_e = from === null || from === void 0 ? void 0 : from.id) !== null && _e !== void 0 ? _e : "").trim();
    const text = String((_f = body.text) !== null && _f !== void 0 ? _f : "").trim();
    const parsed = parseIntegrationCommand(text);
    try {
        const message = await dispatchParsedCommand("teams", userId, parsed);
        res.json({ type: "message", text: message });
    }
    catch (err) {
        console.error("folioTeamsCommand", err);
        res.status(500).json({ type: "message", text: "Internal error." });
    }
});
//# sourceMappingURL=slack_teams_integration.js.map