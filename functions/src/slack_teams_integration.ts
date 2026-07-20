import * as admin from "firebase-admin";
import { createHmac, timingSafeEqual } from "crypto";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const LINK_CODE_TTL_MS = 15 * 60 * 1000;
const MAX_TASK_TITLE_LEN = 200;

type IntegrationProvider = "slack" | "teams";

function integrationWebhookHostAllowed(hostname: string): boolean {
  const h = hostname.toLowerCase();
  if (h === "hooks.slack.com") return true;
  if (h.endsWith(".logic.azure.com")) return true;
  if (h.endsWith(".powerplatform.com")) return true;
  if (h.endsWith(".office.com")) return true;
  if (h.endsWith(".office365.com")) return true;
  if (h.endsWith(".webhook.office.com")) return true;
  return false;
}

function slackSigningSecret(): string {
  return String(process.env.SLACK_SIGNING_SECRET ?? "").trim();
}

function normalizeCommandText(raw: string): string {
  let t = String(raw ?? "").trim();
  t = t.replace(/^<at>.*?<\/at>\s*/gi, "");
  t = t.replace(/^@\S+\s+/, "");
  return t.trim();
}

export type ParsedIntegrationCommand =
  | { kind: "link"; code: string }
  | { kind: "create_task"; title: string }
  | { kind: "unknown" };

export function parseIntegrationCommand(raw: string): ParsedIntegrationCommand {
  const text = normalizeCommandText(raw);
  const link = text.match(/^\/folio\s+link\s+([A-Za-z0-9]{6,12})$/i);
  if (link) {
    return { kind: "link", code: link[1].toUpperCase() };
  }
  const create = text.match(/^\/folio\s+create\s+task\s+"([^"]+)"$/i);
  if (create) {
    const title = create[1].trim();
    if (!title || title.length > MAX_TASK_TITLE_LEN) return { kind: "unknown" };
    return { kind: "create_task", title };
  }
  return { kind: "unknown" };
}

function ackLatencyMessage(): string {
  return (
    "Folio queued your command. It will run the next time you open Folio " +
    "(may take from seconds to days). / Folio ha encolado tu comando. " +
    "Se aplicará la próxima vez que abras Folio (puede tardar de segundos a días)."
  );
}

async function postWebhookJson(webhookUrl: string, payload: Record<string, unknown>) {
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

function verifySlackSignature(
  signingSecret: string,
  rawBody: Buffer,
  timestamp: string,
  signature: string,
): boolean {
  if (!signingSecret || !timestamp || !signature) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts)) return false;
  const ageSec = Math.abs(Date.now() / 1000 - ts);
  if (ageSec > 60 * 5) return false;
  const base = `v0:${timestamp}:${rawBody.toString("utf8")}`;
  const digest = createHmac("sha256", signingSecret).update(base).digest("hex");
  const expected = `v0=${digest}`;
  try {
    return timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
  } catch {
    return false;
  }
}

function verifyTeamsOutgoingHmac(
  securityToken: string,
  rawBody: Buffer,
  authorization: string,
): boolean {
  const token = securityToken.trim();
  if (!token || !authorization) return false;
  const hash = createHmac("sha256", Buffer.from(token, "utf8"))
    .update(rawBody)
    .digest("base64");
  const expected = `HMAC ${hash}`;
  try {
    return timingSafeEqual(Buffer.from(expected), Buffer.from(authorization.trim()));
  } catch {
    return false;
  }
}

async function resolveUserIndex(
  provider: IntegrationProvider,
  externalUserId: string,
): Promise<FirebaseFirestore.DocumentSnapshot | null> {
  const id = `${provider}_${externalUserId}`;
  const snap = await db.collection("integrationUserIndex").doc(id).get();
  return snap.exists ? snap : null;
}

async function handleLinkCommand(
  provider: IntegrationProvider,
  externalUserId: string,
  code: string,
): Promise<string> {
  const normalized = code.toUpperCase();
  const codeRef = db.collection("integrationLinkCodes").doc(normalized);
  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    return "Invalid or expired link code. Generate a new one in Folio Settings → Integrations.";
  }
  const data = codeSnap.data() ?? {};
  const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
  if (Date.now() > expiresAt) {
    await codeRef.delete();
    return "Link code expired. Generate a new one in Folio Settings → Integrations.";
  }
  if (String(data.provider ?? "") !== provider) {
    return "This link code was created for a different provider.";
  }
  const firebaseUid = String(data.firebaseUid ?? "").trim();
  const vaultId = String(data.vaultId ?? "").trim();
  const connectionId = String(data.connectionId ?? "").trim();
  const webhookUrl = String(data.webhookUrl ?? "").trim();
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
    teamsSecurityToken: String(data.teamsSecurityToken ?? "").trim() || null,
    linkedAt: FieldValue.serverTimestamp(),
  });
  await codeRef.delete();
  return "Linked! You can now use `/folio create task \"Title\"` (or `@Folio create task \"Title\"` in Teams).";
}

async function enqueueCreateTask(
  provider: IntegrationProvider,
  externalUserId: string,
  title: string,
): Promise<string> {
  const indexSnap = await resolveUserIndex(provider, externalUserId);
  if (!indexSnap) {
    return "Account not linked. In Folio Settings → Integrations, generate a link code and run `/folio link CODE`.";
  }
  const index = indexSnap.data() ?? {};
  const firebaseUid = String(index.firebaseUid ?? "").trim();
  const vaultId = String(index.vaultId ?? "").trim();
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
    connectionId: String(index.connectionId ?? "").trim(),
    webhookUrl: String(index.webhookUrl ?? "").trim(),
    command: "create_task",
    title,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  return ackLatencyMessage();
}

async function dispatchParsedCommand(
  provider: IntegrationProvider,
  externalUserId: string,
  parsed: ParsedIntegrationCommand,
): Promise<string> {
  if (parsed.kind === "link") {
    return handleLinkCommand(provider, externalUserId, parsed.code);
  }
  if (parsed.kind === "create_task") {
    return enqueueCreateTask(provider, externalUserId, parsed.title);
  }
  return (
    "Unknown command. Supported: `/folio link CODE`, `/folio create task \"Title\"`."
  );
}

export const folioIntegrationWebhookProxy = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const data = (request.data ?? {}) as Record<string, unknown>;
    const provider = String(data.provider ?? "").trim() as IntegrationProvider;
    const webhookUrl = String(data.webhookUrl ?? "").trim();
    const payload = data.payload;
    if (provider !== "slack" && provider !== "teams") {
      throw new HttpsError("invalid-argument", "invalid_provider");
    }
    if (!webhookUrl || typeof payload !== "object" || payload === null) {
      throw new HttpsError("invalid-argument", "missing_webhook_or_payload");
    }
    let host: string;
    try {
      host = new URL(webhookUrl).hostname;
    } catch {
      throw new HttpsError("invalid-argument", "invalid_webhook_url");
    }
    if (!integrationWebhookHostAllowed(host)) {
      throw new HttpsError("permission-denied", "webhook_host_not_allowed");
    }
    const resp = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!resp.ok) {
      const body = await resp.text();
      throw new HttpsError("internal", `webhook_failed_${resp.status}: ${body}`);
    }
    return { ok: true };
  },
);

export const folioRegisterIntegrationLinkCode = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;
    const code = String(data.code ?? "").trim().toUpperCase();
    const vaultId = String(data.vaultId ?? "").trim();
    const connectionId = String(data.connectionId ?? "").trim();
    const provider = String(data.provider ?? "").trim() as IntegrationProvider;
    const webhookUrl = String(data.webhookUrl ?? "").trim();
    const teamsSecurityToken = String(data.teamsSecurityToken ?? "").trim();
    if (!/^[A-Z0-9]{8}$/.test(code)) {
      throw new HttpsError("invalid-argument", "invalid_code");
    }
    if (!vaultId || !connectionId || !webhookUrl) {
      throw new HttpsError("invalid-argument", "missing_fields");
    }
    if (provider !== "slack" && provider !== "teams") {
      throw new HttpsError("invalid-argument", "invalid_provider");
    }
    let host: string;
    try {
      host = new URL(webhookUrl).hostname;
    } catch {
      throw new HttpsError("invalid-argument", "invalid_webhook_url");
    }
    if (!integrationWebhookHostAllowed(host)) {
      throw new HttpsError("permission-denied", "webhook_host_not_allowed");
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
  },
);

export const folioAckIntegrationCommand = onCall(
  { invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;
    const commandId = String(data.commandId ?? "").trim();
    const success = data.success === true;
    const taskTitle = String(data.taskTitle ?? "").trim();
    const errorMessage = String(data.errorMessage ?? "").trim();
    if (!commandId) {
      throw new HttpsError("invalid-argument", "missing_command_id");
    }
    const cmdRef = db
      .collection("users")
      .doc(uid)
      .collection("pendingIntegrationCommands")
      .doc(commandId);
    const cmdSnap = await cmdRef.get();
    if (!cmdSnap.exists) {
      throw new HttpsError("not-found", "command_not_found");
    }
    const cmd = cmdSnap.data() ?? {};
    if (String(cmd.status ?? "") !== "pending") {
      return { ok: true, duplicate: true };
    }
    const webhookUrl = String(cmd.webhookUrl ?? "").trim();
    const provider = String(cmd.provider ?? "").trim();
    await cmdRef.set(
      {
        status: success ? "applied" : "failed",
        processedAt: FieldValue.serverTimestamp(),
        errorMessage: success ? null : errorMessage || "unknown_error",
      },
      { merge: true },
    );
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
        } else {
          await postWebhookJson(webhookUrl, { text });
        }
      } catch (err) {
        console.warn("folioAckIntegrationCommand: confirmation webhook failed", err);
      }
    }
    return { ok: true };
  },
);

export const folioSlackCommand = onRequest(
  { cors: false, memory: "256MiB", invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const secret = slackSigningSecret();
    if (!secret) {
      res.status(503).send("Slack signing secret not configured");
      return;
    }
    const rawBody = (req as { rawBody?: Buffer }).rawBody;
    if (!rawBody) {
      res.status(400).send("Missing raw body");
      return;
    }
    const timestamp = String(req.headers["x-slack-request-timestamp"] ?? "");
    const signature = String(req.headers["x-slack-signature"] ?? "");
    if (!verifySlackSignature(secret, rawBody, timestamp, signature)) {
      res.status(401).send("Invalid signature");
      return;
    }
    const body = typeof req.body === "object" && req.body !== null
      ? (req.body as Record<string, unknown>)
      : {};
    const userId = String(body.user_id ?? "").trim();
    const commandText = String(body.text ?? "").trim();
    const fullText = commandText ? `/folio ${commandText}` : "/folio";
    const parsed = parseIntegrationCommand(fullText);
    try {
      const message = await dispatchParsedCommand("slack", userId, parsed);
      res.json({ response_type: "ephemeral", text: message });
    } catch (err) {
      console.error("folioSlackCommand", err);
      res.status(500).json({ response_type: "ephemeral", text: "Internal error." });
    }
  },
);

export const folioTeamsCommand = onRequest(
  { cors: false, memory: "256MiB", invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const rawBody = (req as { rawBody?: Buffer }).rawBody;
    if (!rawBody) {
      res.status(400).send("Missing raw body");
      return;
    }
    const connectionId = String(req.query.connectionId ?? "").trim();
    if (!connectionId) {
      res.status(400).send("Missing connectionId query parameter");
      return;
    }
    const endpointSnap = await db.collection("teamsWebhookEndpoints").doc(connectionId).get();
    const token = String(endpointSnap.data()?.teamsSecurityToken ?? "").trim();
    if (!token) {
      res.status(401).send("Unknown Teams webhook endpoint");
      return;
    }
    const authorization = String(req.headers.authorization ?? "");
    if (!verifyTeamsOutgoingHmac(token, rawBody, authorization)) {
      res.status(401).send("Invalid HMAC");
      return;
    }
    const body = typeof req.body === "object" && req.body !== null
      ? (req.body as Record<string, unknown>)
      : {};
    const from = body.from as Record<string, unknown> | undefined;
    const userId = String(from?.id ?? "").trim();
    const text = String(body.text ?? "").trim();
    const parsed = parseIntegrationCommand(text);
    try {
      const message = await dispatchParsedCommand("teams", userId, parsed);
      res.json({ type: "message", text: message });
    } catch (err) {
      console.error("folioTeamsCommand", err);
      res.status(500).json({ type: "message", text: "Internal error." });
    }
  },
);
