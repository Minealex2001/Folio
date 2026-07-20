import "./admin_init";
import { onRequest } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";

const SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token";
const SPOTIFY_API_BASE = "https://api.spotify.com";

function spotifyOauthClientId(): string {
  return process.env.SPOTIFY_OAUTH_CLIENT_ID?.trim() ?? "";
}

function readJsonBody(req: { body?: unknown }): Record<string, unknown> {
  const raw = req.body;
  if (typeof raw === "string") {
    try {
      return JSON.parse(raw || "{}") as Record<string, unknown>;
    } catch {
      return {};
    }
  }
  return (raw ?? {}) as Record<string, unknown>;
}

function isValidLoopbackRedirect(redirectUri: string): boolean {
  try {
    const u = new URL(redirectUri);
    return (
      u.protocol === "http:" &&
      u.hostname === "127.0.0.1" &&
      u.port === "45748" &&
      u.pathname.endsWith("/callback")
    );
  } catch {
    return false;
  }
}

/**
 * Intercambio authorization_code → tokens (Spotify OAuth PKCE).
 */
export const folioSpotifyExchangeOAuth = onRequest(
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
    const body = readJsonBody(req);
    const code = String(body.code ?? "").trim();
    const redirectUri = String(body.redirectUri ?? "").trim();
    const clientId = String(body.clientId ?? "").trim() || spotifyOauthClientId();
    const codeVerifier = String(body.codeVerifier ?? "").trim();
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
      res.status(200).json(JSON.parse(text) as Record<string, unknown>);
    } catch {
      res.status(502).json({ error: "invalid_token_response" });
    }
  },
);

/**
 * Callback OAuth Web: página HTML tras autorizar en Spotify.
 */
export const folioSpotifyOAuthCallback = onRequest(
  { cors: true, memory: "128MiB", invoker: "public" },
  async (req, res) => {
    const err = String(req.query.error ?? "").trim();
    res.set("Content-Type", "text/html; charset=utf-8");
    if (err) {
      res.status(200).send(
        `<h2>OAuth cancelado</h2><p>${err}</p><p>Puedes cerrar esta pestaña.</p>`,
      );
      return;
    }
    res.status(200).send(
      "<h2>Conectado</h2><p>Ya puedes volver a Folio. Puedes cerrar esta pestaña.</p>",
    );
  },
);

/**
 * Proxy autenticado para Web API de Spotify (CORS en build Web).
 */
export const folioSpotifyApiProxy = onRequest(
  { cors: true, memory: "256MiB", invoker: "public" },
  async (req, res) => {
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
    const authHeader = String(req.headers.authorization ?? "");
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      res.status(401).json({ error: "missing_auth" });
      return;
    }
    try {
      await getAuth().verifyIdToken(match[1]!);
    } catch {
      res.status(401).json({ error: "invalid_auth" });
      return;
    }
    const body = readJsonBody(req);
    const method = String(body.method ?? "GET").toUpperCase();
    const path = String(body.path ?? "").trim();
    const accessToken = String(body.accessToken ?? "").trim();
    if (!path.startsWith("/v1/") || !accessToken) {
      res.status(400).json({ error: "invalid_request" });
      return;
    }
    const allowed = ["GET", "PUT", "POST", "DELETE"];
    if (!allowed.includes(method)) {
      res.status(400).json({ error: "invalid_method" });
      return;
    }
    const headers: Record<string, string> = {
      authorization: `Bearer ${accessToken}`,
    };
    const extraHeaders = body.headers;
    if (extraHeaders && typeof extraHeaders === "object") {
      for (const [k, v] of Object.entries(extraHeaders as Record<string, unknown>)) {
        if (typeof v === "string") headers[k.toLowerCase()] = v;
      }
    }
    let fetchBody: string | undefined;
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
    let parsed: unknown = text;
    if (text.trim().startsWith("{") || text.trim().startsWith("[")) {
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = text;
      }
    } else if (text.trim() === "") {
      parsed = null;
    }
    res.status(200).json({
      status: apiResp.status,
      body: parsed,
    });
  },
);
