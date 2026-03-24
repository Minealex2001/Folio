# Folio Local Integration
# Version 1

## Overview

Folio exposes a local Windows-first integration that lets any external application send Markdown content directly into the active Folio vault.

The integration uses two layers:

1. `folio://import?...` to launch or focus Folio and arm a short-lived import session.
2. `http://127.0.0.1:45831` to send the actual Markdown payload as JSON.

This document describes the generic contract so any desktop or backend-assisted client can implement a Folio integration.

## Required Headers

Protected endpoints require these headers:

```http
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
X-Folio-Integration-Secret: <secret-from-env>
```

Header meaning:

- `X-Folio-App-Id`: stable identifier for the external application.
- `X-Folio-App-Name`: human-readable name shown in Folio approval UI.
- `X-Folio-App-Version`: version of the external application build. Folio stores this for diagnostics and settings display.
- `X-Folio-Integration-Version`: version of the Folio integration contract implemented by the client.
- `X-Folio-Integration-Secret`: shared secret configured on the Folio side outside the UI, typically via `.env`, `.env.local`, or `--dart-define`.

Approval behavior:

1. The first time a new `X-Folio-App-Id` requests a session, Folio asks the user for approval.
2. If only `X-Folio-App-Version` changes, Folio updates the stored version silently without showing the approval popup again.
3. If `X-Folio-Integration-Version` changes, Folio asks for approval again.

Folio resolves the secret in this order:

1. `--dart-define=FOLIO_INTEGRATION_SECRET=...`
2. `.env.local`
3. `.env`

If no secret is configured, protected endpoints reject the request.

## Integration Model

Recommended client flow:

1. Call `POST /session/start` to ask Folio for a fresh session.
2. Open the returned `deepLink`.
3. Poll `GET /health` or `GET /app`.
4. Send `POST /imports/markdown` with the returned `sessionId` and bearer `nonce`.

An external app may generate its own `sessionId` and `nonce`, but the recommended path is to let Folio generate them through `POST /session/start`.

## Deep Link

Format:

```text
folio://import?session=<sessionId>&nonce=<nonce>&appId=<appId>&appName=<appName>&appVersion=<appVersion>&integrationVersion=<integrationVersion>
```

Example:

```text
folio://import?session=8f2e9c1a&nonce=ab19f3d2&appId=sample-docs-desktop&appName=Sample%20Docs&appVersion=1.4.0&integrationVersion=1
```

## Session Bootstrap Endpoint

Recommended request:

```http
POST http://127.0.0.1:45831/session/start
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
X-Folio-Integration-Secret: <secret>
```

Supported aliases:

```http
POST /session/new
POST /start
```

Example response:

```json
{
  "ok": true,
  "sessionId": "18e6f1f3b2c_a1b2c3d4",
  "nonce": "fR5N0mD4f5nJY7q6x6lq4eQ7f8m8k9zA",
  "port": 45831,
  "appId": "sample-docs-desktop",
  "appName": "Sample Docs",
  "appVersion": "1.4.0",
  "integrationVersion": "1",
  "expiresAtUtc": "2026-03-24T20:25:00.000Z",
  "expiresInSeconds": 300,
  "deepLink": "folio://import?session=18e6f1f3b2c_a1b2c3d4&nonce=fR5N0mD4f5nJY7q6x6lq4eQ7f8m8k9zA&appId=sample-docs-desktop&appName=Sample%20Docs&appVersion=1.4.0&integrationVersion=1"
}
```

## Health Endpoint

Use this to check if Folio is running and listening on the fixed bridge port.

```http
GET http://127.0.0.1:45831/health
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
X-Folio-Integration-Secret: <secret>
```

Example response:

```json
{
  "ok": true,
  "appRunning": true,
  "clientApproved": true,
  "sessionId": "8f2e9c1a",
  "state": "ready",
  "port": 45831,
  "integrationVersion": "1"
}
```

## App Status Endpoint

Use this when the client needs more than a liveness check.

```http
GET http://127.0.0.1:45831/app
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
X-Folio-Integration-Secret: <secret>
```

`/status` is accepted as an alias.

Example response:

```json
{
  "ok": true,
  "appRunning": true,
  "bridgePort": 45831,
  "importSessionActive": true,
  "sessionId": "8f2e9c1a",
  "clientApproved": true,
  "client": {
    "appId": "sample-docs-desktop",
    "appName": "Sample Docs",
    "appVersion": "1.4.0",
    "integrationVersion": "1"
  },
  "integrationVersion": "1",
  "app": {
    "name": "Folio",
    "version": "0.0.1+1",
    "platform": "windows",
    "state": "unlocked",
    "isUnlocked": true,
    "vaultUsesEncryption": true,
    "activeVaultId": "vault_abc",
    "selectedPage": {
      "id": "page_123",
      "title": "Imported Document",
      "blockCount": 12,
      "lastImportInfo": {
        "clientAppId": "sample-docs-desktop",
        "clientAppName": "Sample Docs",
        "importedAtMs": 1711311300000,
        "importMode": "newPage",
        "sessionId": "8f2e9c1a",
        "sourceApp": "Sample Docs",
        "sourceUrl": "https://example.com/docs"
      }
    },
    "aiEnabled": false,
    "bridgePort": 45831,
    "importSession": {
      "sessionId": "8f2e9c1a",
      "port": 45831,
      "clientAppId": "sample-docs-desktop",
      "clientAppName": "Sample Docs",
      "clientAppVersion": "1.4.0",
      "integrationVersion": "1"
    },
    "approvedClients": [
      {
        "appId": "sample-docs-desktop",
        "appName": "Sample Docs",
        "appVersion": "1.4.0",
        "integrationVersion": "1",
        "approvedAtMs": 1711311000000
      }
    ],
    "timestampUtc": "2026-03-24T20:15:00.000Z"
  }
}
```

Useful fields:

- `appRunning`: confirms Folio is up.
- `importSessionActive`: tells the client whether a deep-link activation already armed a session.
- `app.state`: current Folio state such as `initializing`, `locked`, or `unlocked`.
- `app.isUnlocked`: useful before attempting import.
- `app.selectedPage`: useful for `replaceCurrentPage` and `appendToCurrentPage`.
- `app.selectedPage.lastImportInfo`: provenance trail for the last import on that page.

## Import Endpoint

```http
POST /imports/markdown
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
X-Folio-Integration-Secret: <secret>
Content-Type: application/json
```

Request body:

```json
{
  "sessionId": "8f2e9c1a",
  "sourceApp": "Sample Docs",
  "sourceUrl": "https://example.com/docs",
  "title": "Imported Document",
  "markdown": "# Imported Document\n\n## Overview\n\nGenerated by an external app.",
  "importMode": "newPage",
  "parentPageId": null,
  "metadata": {
    "origin": "desktop-client",
    "documentType": "reference"
  }
}
```

Fields:

- `sessionId`: required, must match the active session.
- `sourceApp`: optional provenance label.
- `sourceUrl`: optional source URL.
- `title`: recommended for a clean page title.
- `markdown`: required Markdown content.
- `importMode`: `newPage`, `replaceCurrentPage`, or `appendToCurrentPage`.
- `parentPageId`: optional target parent page.
- `metadata`: optional diagnostic or trace fields.

## Success Response

```json
{
  "ok": true,
  "sessionId": "8f2e9c1a",
  "pageId": "page_123",
  "title": "Imported Document",
  "blockCount": 12,
  "mode": "newPage",
  "message": "Imported successfully"
}
```

## Error Responses

Invalid payload:

```json
{
  "ok": false,
  "error": "INVALID_PAYLOAD",
  "message": "Field \"markdown\" is required."
}
```

Invalid token:

```json
{
  "ok": false,
  "error": "UNAUTHORIZED",
  "message": "Invalid session token."
}
```

Vault locked:

```json
{
  "ok": false,
  "error": "VAULT_LOCKED",
  "message": "Unlock Folio before importing."
}
```

Payload too large:

```json
{
  "ok": false,
  "error": "PAYLOAD_TOO_LARGE",
  "message": "Markdown payload exceeds the maximum allowed size."
}
```

App not approved:

```json
{
  "ok": false,
  "error": "APP_NOT_APPROVED",
  "message": "This app has not been approved in Folio yet."
}
```

Unsupported integration version:

```json
{
  "ok": false,
  "error": "UNSUPPORTED_INTEGRATION_VERSION",
  "message": "Unsupported X-Folio-Integration-Version."
}
```

## Fixed Port

Folio uses this fixed localhost port:

```text
45831
```

Clients do not need dynamic port discovery.

## Security Rules

- Folio binds the bridge only to `127.0.0.1`.
- Protected endpoints require `X-Folio-App-Id`, `X-Folio-App-Name`, `X-Folio-App-Version`, `X-Folio-Integration-Version`, and `X-Folio-Integration-Secret`.
- New apps must be explicitly approved by the Folio user.
- Session authorization uses a bearer token derived from the deep-link `nonce`.
- Sessions expire automatically after a short time.
- Payload size is limited.
- If the vault is locked, Folio rejects the import instead of writing partial content.

## Markdown Coverage

Current Folio import/export focuses on structures that map cleanly to the internal block model:

- headings `#`, `##`, `###`
- paragraphs
- bullet lists
- numbered lists
- task lists
- blockquotes
- GitHub alerts `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, `CAUTION`
- fenced code blocks, including `diff`
- Mermaid blocks
- basic Markdown tables
- image lines like `![alt](url)`

Unsupported constructs are degraded safely when necessary.

## Java Example

```java
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

HttpClient client = HttpClient.newHttpClient();

HttpRequest bootstrapRequest = HttpRequest.newBuilder()
    .uri(URI.create("http://127.0.0.1:45831/session/start"))
    .header("X-Folio-App-Id", "sample-docs-desktop")
    .header("X-Folio-App-Name", "Sample Docs")
    .header("X-Folio-App-Version", "1.4.0")
    .header("X-Folio-Integration-Version", "1")
    .header("X-Folio-Integration-Secret", integrationSecret)
    .POST(HttpRequest.BodyPublishers.noBody())
    .build();

HttpResponse<String> bootstrapResponse = client.send(
    bootstrapRequest,
    HttpResponse.BodyHandlers.ofString()
);

String sessionId = "...";
String nonce = "...";
String deepLink = "...";

Runtime.getRuntime().exec(new String[] {
    "rundll32", "url.dll,FileProtocolHandler", deepLink
});

String json = """
{
  "sessionId": "8f2e9c1a",
  "sourceApp": "Sample Docs",
  "sourceUrl": "https://example.com/docs",
  "title": "Imported Document",
  "markdown": "# Imported Document\\n\\n## Overview\\n\\nGenerated by an external app.",
  "importMode": "newPage"
}
""";

HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("http://127.0.0.1:45831/imports/markdown"))
    .header("Authorization", "Bearer " + nonce)
    .header("X-Folio-App-Id", "sample-docs-desktop")
    .header("X-Folio-App-Name", "Sample Docs")
    .header("X-Folio-App-Version", "1.4.0")
    .header("X-Folio-Integration-Version", "1")
    .header("X-Folio-Integration-Secret", integrationSecret)
    .header("Content-Type", "application/json")
    .POST(HttpRequest.BodyPublishers.ofString(json))
    .build();

HttpResponse<String> response = client.send(
    request,
    HttpResponse.BodyHandlers.ofString()
);
System.out.println(response.statusCode());
System.out.println(response.body());
```

## Frontend Orchestration Guidance

Recommended UI flow for a button like `Send to Folio`:

1. Configure `appId`, `appName`, `appVersion`, `integrationVersion`, and the shared secret.
2. Optionally call `GET /app` to see whether Folio is already running and unlocked.
3. Call `POST /session/start`.
4. Approve the app in Folio if requested.
5. Open the returned `deepLink`.
6. Poll `/health` or `/app` briefly until Folio reports an active import session.
7. Send `POST /imports/markdown`.
8. Surface success or error feedback to the user.

Example `fetch` call:

```ts
await fetch('http://127.0.0.1:45831/imports/markdown', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${nonce}`,
    'X-Folio-App-Id': 'sample-docs-desktop',
    'X-Folio-App-Name': 'Sample Docs',
    'X-Folio-App-Version': '1.4.0',
    'X-Folio-Integration-Version': '1',
    'X-Folio-Integration-Secret': integrationSecret,
  },
  body: JSON.stringify({
    sessionId,
    sourceApp: 'Sample Docs',
    sourceUrl,
    title,
    markdown,
    importMode: 'newPage',
  }),
});
```

If your frontend cannot launch desktop protocols or call localhost reliably, let a desktop shell or backend helper own the orchestration.

## Suggested End-to-End Test

1. Generate or collect Markdown in your external app.
2. Call `POST /session/start` with the required headers.
3. Approve the app in Folio if requested.
4. Launch the returned `deepLink`.
5. Confirm `GET /health` returns `ok: true`.
6. Confirm `GET /app` returns the expected state.
7. Send `POST /imports/markdown`.
8. Verify Folio creates or updates the page.
9. Optionally export that page back to Markdown and verify the roundtrip result.
