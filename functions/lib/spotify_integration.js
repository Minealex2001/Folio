"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.folioSpotifyApiProxy = exports.folioSpotifyOAuthCallback = exports.folioSpotifyExchangeOAuth = void 0;
require("./admin_init");
const https_1 = require("firebase-functions/v2/https");
const auth_1 = require("firebase-admin/auth");
const SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token";
const SPOTIFY_API_BASE = "https://api.spotify.com";
function spotifyOauthClientId() {
    var _a, _b;
    return (_b = (_a = process.env.SPOTIFY_OAUTH_CLIENT_ID) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function readJsonBody(req) {
    const raw = req.body;
    if (typeof raw === "string") {
        try {
            return JSON.parse(raw || "{}");
        }
        catch {
            return {};
        }
    }
    return (raw !== null && raw !== void 0 ? raw : {});
}
function isValidLoopbackRedirect(redirectUri) {
    try {
        const u = new URL(redirectUri);
        return (u.protocol === "http:" &&
            u.hostname === "127.0.0.1" &&
            u.port === "45748" &&
            u.pathname.endsWith("/callback"));
    }
    catch {
        return false;
    }
}
/**
 * Intercambio authorization_code → tokens (Spotify OAuth PKCE).
 */
exports.folioSpotifyExchangeOAuth = (0, https_1.onRequest)({ cors: true, memory: "256MiB", invoker: "public" }, async (req, res) => {
    var _a, _b, _c, _d;
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
    const body = readJsonBody(req);
    const code = String((_a = body.code) !== null && _a !== void 0 ? _a : "").trim();
    const redirectUri = String((_b = body.redirectUri) !== null && _b !== void 0 ? _b : "").trim();
    const clientId = String((_c = body.clientId) !== null && _c !== void 0 ? _c : "").trim() || spotifyOauthClientId();
    const codeVerifier = String((_d = body.codeVerifier) !== null && _d !== void 0 ? _d : "").trim();
    if (!code || !redirectUri || !clientId || !codeVerifier) {
        res.status(400).json({ error: "missing_fields" });
        return;
    }
    if (!isValidLoopbackRedirect(redirectUri)) {
        res.status(400).json({ error: "invalid_redirect_uri" });
        return;
    }
    const params = new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: clientId,
        code_verifier: codeVerifier,
    });
    const tokenResp = await fetch(SPOTIFY_TOKEN_URL, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: params.toString(),
    });
    const text = await tokenResp.text();
    if (!tokenResp.ok) {
        console.warn("folioSpotifyExchangeOAuth:", tokenResp.status, text);
        res.status(502).json({
            error: "spotify_token_failed",
            status: tokenResp.status,
            body: text.length > 800 ? `${text.slice(0, 800)}…` : text,
        });
        return;
    }
    try {
        res.status(200).json(JSON.parse(text));
    }
    catch {
        res.status(502).json({ error: "invalid_token_response" });
    }
});
/**
 * Callback OAuth Web: página HTML tras autorizar en Spotify.
 */
exports.folioSpotifyOAuthCallback = (0, https_1.onRequest)({ cors: true, memory: "128MiB", invoker: "public" }, async (req, res) => {
    var _a;
    const err = String((_a = req.query.error) !== null && _a !== void 0 ? _a : "").trim();
    res.set("Content-Type", "text/html; charset=utf-8");
    if (err) {
        res.status(200).send(`<h2>OAuth cancelado</h2><p>${err}</p><p>Puedes cerrar esta pestaña.</p>`);
        return;
    }
    res.status(200).send("<h2>Conectado</h2><p>Ya puedes volver a Folio. Puedes cerrar esta pestaña.</p>");
});
/**
 * Proxy autenticado para Web API de Spotify (CORS en build Web).
 */
exports.folioSpotifyApiProxy = (0, https_1.onRequest)({ cors: true, memory: "256MiB", invoker: "public" }, async (req, res) => {
    var _a, _b, _c, _d;
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "method_not_allowed" });
        return;
    }
    const authHeader = String((_a = req.headers.authorization) !== null && _a !== void 0 ? _a : "");
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!match) {
        res.status(401).json({ error: "missing_auth" });
        return;
    }
    try {
        await (0, auth_1.getAuth)().verifyIdToken(match[1]);
    }
    catch {
        res.status(401).json({ error: "invalid_auth" });
        return;
    }
    const body = readJsonBody(req);
    const method = String((_b = body.method) !== null && _b !== void 0 ? _b : "GET").toUpperCase();
    const path = String((_c = body.path) !== null && _c !== void 0 ? _c : "").trim();
    const accessToken = String((_d = body.accessToken) !== null && _d !== void 0 ? _d : "").trim();
    if (!path.startsWith("/v1/") || !accessToken) {
        res.status(400).json({ error: "invalid_request" });
        return;
    }
    const allowed = ["GET", "PUT", "POST", "DELETE"];
    if (!allowed.includes(method)) {
        res.status(400).json({ error: "invalid_method" });
        return;
    }
    const headers = {
        authorization: `Bearer ${accessToken}`,
    };
    const extraHeaders = body.headers;
    if (extraHeaders && typeof extraHeaders === "object") {
        for (const [k, v] of Object.entries(extraHeaders)) {
            if (typeof v === "string")
                headers[k.toLowerCase()] = v;
        }
    }
    let fetchBody;
    if (body.body != null) {
        fetchBody = typeof body.body === "string" ? body.body : JSON.stringify(body.body);
        if (!headers["content-type"]) {
            headers["content-type"] = "application/json";
        }
    }
    const apiResp = await fetch(`${SPOTIFY_API_BASE}${path}`, {
        method,
        headers,
        body: fetchBody,
    });
    const text = await apiResp.text();
    let parsed = text;
    if (text.trim().startsWith("{") || text.trim().startsWith("[")) {
        try {
            parsed = JSON.parse(text);
        }
        catch {
            parsed = text;
        }
    }
    else if (text.trim() === "") {
        parsed = null;
    }
    res.status(200).json({
        status: apiResp.status,
        body: parsed,
    });
});
//# sourceMappingURL=spotify_integration.js.map