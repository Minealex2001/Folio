# Folio Local Integration
# Version 2 (v1 legacy compatible)

## Overview

Folio exposes a local Windows-first integration that lets any external application send Markdown content directly into the active Folio vault.

The integration uses two layers:

1. `folio://import?...` to launch or focus Folio and arm a short-lived import session.
2. `http://127.0.0.1:45831` to send the actual Markdown payload as JSON.

## Versioning and Encryption Policy

- Integration version `2` is the current contract and requires encrypted content payloads for:
  - `POST /imports/markdown`
  - `POST /imports/json`
  - `PATCH /pages/{pageId}`
- Integration version `1` is legacy-compatible and still accepted, but content payloads are not encrypted.
- Folio shows this distinction in the approval UI so users can identify whether an integration sends content encrypted or plaintext.

For version `2`, clients must send an envelope:

```json
{
  "sessionId": "8f2e9c1a",
  "encryptedPayload": {
    "alg": "AES-256-GCM",
    "iv": "base64url-iv",
    "tag": "base64url-tag",
    "ciphertext": "base64url-ciphertext"
  }
}
```

Encryption details for `v2`:

- Algorithm: `AES-256-GCM`
- Key derivation input: `folio-integrations-v2|<sessionId>|<nonce>`
- The decrypted payload must be a JSON object with the same fields expected by each endpoint.

This document describes the generic contract so any desktop or backend-assisted client can implement a Folio integration.

## Required Headers

Protected endpoints require these headers:

```http
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 2
```

Header meaning:

- `X-Folio-App-Id`: stable identifier for the external application.
- `X-Folio-App-Name`: human-readable name shown in Folio approval UI.
- `X-Folio-App-Version`: version of the external application build. Folio stores this for diagnostics and settings display.
- `X-Folio-Integration-Version`: version of the Folio integration contract implemented by the client.

Supported versions:

- `2`: current, encrypted content required.
- `1`: legacy, plaintext content allowed.

Approval behavior:

1. The first time a new `X-Folio-App-Id` requests a session, Folio asks the user for approval.
2. If only `X-Folio-App-Version` changes, Folio updates the stored version silently without showing the approval popup again.
3. If `X-Folio-Integration-Version` changes, Folio asks for approval again.

Folio no longer requires a shared secret for local integration.
Access control is enforced through app identity headers, explicit app approval, and short-lived session nonces.

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
X-Folio-Integration-Version: 2
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
  "integrationVersion": "2",
  "expiresAtUtc": "2026-03-24T20:25:00.000Z",
  "expiresInSeconds": 300,
  "deepLink": "folio://import?session=18e6f1f3b2c_a1b2c3d4&nonce=fR5N0mD4f5nJY7q6x6lq4eQ7f8m8k9zA&appId=sample-docs-desktop&appName=Sample%20Docs&appVersion=1.4.0&integrationVersion=2"
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

## Update Page Endpoint

Updates the content of a page that the calling app originally imported.

**Privacy rule:** only the app whose `X-Folio-App-Id` matches the `clientAppId` stored in `page.lastImportInfo` may update that page. Native pages (created inside Folio, with no import history) are always rejected with `403 FORBIDDEN`.

```http
PATCH /pages/{pageId}
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
Content-Type: application/json
```

Path parameter:

- `pageId`: the UUID of the page to update (e.g. `page_123`).

Request body:

```json
{
  "sessionId": "8f2e9c1a",
  "title": "Updated Document",
  "markdown": "# Updated Document\n\n## Changes\n\nContent refreshed by the external app.",
  "importMode": "replaceCurrentPage",
  "sourceApp": "Sample Docs",
  "sourceUrl": "https://example.com/docs",
  "metadata": {
    "origin": "desktop-client",
    "revision": "2"
  }
}
```

Fields:

- `sessionId`: required, must match the active session.
- `markdown`: required Markdown content.
- `importMode`: `replaceCurrentPage` (default) or `appendToCurrentPage`. `newPage` is not accepted.
- `title`: optional override for the page title (only applied in replace mode when the parsed Markdown does not provide its own title).
- `sourceApp`, `sourceUrl`, `metadata`: optional provenance fields, same as the import endpoint.

### Success Response

```json
{
  "ok": true,
  "sessionId": "8f2e9c1a",
  "pageId": "page_123",
  "title": "Updated Document",
  "blockCount": 9,
  "mode": "replaceCurrentPage",
  "message": "Updated successfully"
}
```

### Error Responses

Page not found:

```json
{
  "ok": false,
  "error": "PAGE_NOT_FOUND",
  "message": "PAGE_NOT_FOUND"
}
```

App did not originally import this page:

```json
{
  "ok": false,
  "error": "FORBIDDEN",
  "message": "App did not import this page."
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

## List Pages Endpoint

Returns all pages that the calling app originally imported into Folio. Useful for discovering `pageId` values needed by the Update Page endpoint.

```http
GET /pages?sessionId=<sessionId>
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
```

Query parameter:

- `sessionId`: required, must match the active session.

### Success Response

```json
{
  "ok": true,
  "sessionId": "8f2e9c1a",
  "pages": [
    {
      "pageId": "page_123",
      "title": "My Imported Document",
      "emoji": "📄",
      "parentId": null,
      "blockCount": 14,
      "icons": ["💡", "✅"],
      "importedAtMs": 1711324800000,
      "importMode": "newPage",
      "sourceApp": "Sample Docs",
      "sourceUrl": "https://example.com/docs"
    }
  ]
}
```

Response fields per page:

- `pageId`: UUID used in PATCH `/pages/{pageId}`.
- `title`: current page title.
- `emoji`: current page emoji when present.
- `parentId`: UUID of the parent page, or `null`.
- `blockCount`: number of content blocks.
- `icons`: unique normalized block icon values currently present in that page.
- `importedAtMs`: Unix timestamp (ms) of the last import/update.
- `importMode`: `newPage`, `replaceCurrentPage`, or `appendToCurrentPage`.
- `sourceApp`, `sourceUrl`: optional provenance fields from the last import, only present when they were set.

**Privacy rule:** only pages whose `lastImportInfo.clientAppId` matches the `X-Folio-App-Id` header are returned. Native pages and pages imported by other apps are never included.

### Error Responses

Standard errors (`UNAUTHORIZED`, `SESSION_MISMATCH`, `NO_ACTIVE_SESSION`, `VAULT_LOCKED`) follow the same shape as the Import Markdown endpoint.

---

## Custom Emojis Endpoint

Folio exposes an app-scoped custom emoji catalog for external integrations.

**Isolation rule:** each app only sees and manages the custom emojis stored under its own `X-Folio-App-Id`. Apps never receive entries imported by other apps.

### List Custom Emojis

```http
GET /app/custom-emojis?sessionId=<sessionId>
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
```

Example response:

```json
{
  "ok": true,
  "sessionId": "8f2e9c1a",
  "items": [
    {
      "id": "rocket",
      "label": "Rocket",
      "source": "data:image/svg+xml,%3Csvg%3E%3C/svg%3E",
      "filePath": "C:\\icons\\rocket.svg",
      "mimeType": "image/svg+xml",
      "createdAtMs": 1711324800000
    }
  ]
}
```

### Replace the Whole Catalog

```http
PUT /app/custom-emojis
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
Content-Type: application/json
```

Request body:

```json
{
  "sessionId": "8f2e9c1a",
  "items": [
    {
      "id": "rocket",
      "label": "Rocket",
      "source": "data:image/svg+xml,%3Csvg%3E%3C/svg%3E",
      "filePath": "C:\\icons\\rocket.svg",
      "mimeType": "image/svg+xml",
      "createdAtMs": 1711324800000
    }
  ]
}
```

### Create or Update a Single Custom Emoji

```http
PATCH /app/custom-emojis/{emojiId}
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
Content-Type: application/json
```

Request body:

```json
{
  "sessionId": "8f2e9c1a",
  "label": "Rocket",
  "source": "data:image/svg+xml,%3Csvg%3E%3C/svg%3E",
  "filePath": "C:\\icons\\rocket.svg",
  "mimeType": "image/svg+xml",
  "createdAtMs": 1711324800000
}
```

Required fields:

- `sessionId`: must match the active session.
- `filePath`: required logical or local path for the imported asset.
- `mimeType`: required MIME type.

### Delete a Single Custom Emoji

```http
DELETE /app/custom-emojis/{emojiId}?sessionId=<sessionId>
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
```

All four operations are protected by the same approval, session, nonce, and client identity checks used by the other integration endpoints.

---

## Import JSON Blocks Endpoint

Creates a new page from pre-parsed JSON blocks, bypassing Markdown parsing entirely. Useful for rich content that does not translate cleanly to Markdown.

```http
POST /imports/json
Host: 127.0.0.1:45831
Authorization: Bearer <nonce>
X-Folio-App-Id: sample-docs-desktop
X-Folio-App-Name: Sample Docs
X-Folio-App-Version: 1.4.0
X-Folio-Integration-Version: 1
Content-Type: application/json
```

Request body:

```json
{
  "sessionId": "8f2e9c1a",
  "title": "My Rich Document",
  "blocks": [
    { "type": "h1", "text": "My Rich Document" },
    { "type": "paragraph", "text": "This block was sent as JSON." },
    {
      "type": "task",
      "text": "{\"v\":1,\"title\":\"Review changes\",\"status\":\"todo\",\"priority\":\"high\",\"dueDate\":\"2026-06-01\"}"
    },
    { "type": "code", "text": "print('hello')", "codeLanguage": "python" }
  ],
  "parentPageId": null,
  "sourceApp": "Sample Docs",
  "sourceUrl": "https://example.com/doc/42",
  "metadata": { "revision": "3" }
}
```

Fields:

- `sessionId`: required, must match the active session.
- `title`: optional page title (default: `"Imported page"` if omitted or empty).
- `blocks`: required non-empty array of block objects (see Block Schema below).
- `parentPageId`: optional UUID of the parent page.
- `sourceApp`, `sourceUrl`, `metadata`: optional provenance fields.

### Block Schema

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string` | No | Auto-generated UUID if absent or empty. |
| `type` | `string` | Yes | See block type list below. |
| `text` | `string` | No | Inline Markdown text, or JSON string for `task`/`toggle` types. |
| `depth` | `int` | No | Indentation level (default `0`). |
| `checked` | `bool` | No | Checked state for `todo` blocks. |
| `expanded` | `bool` | No | Expanded state for `toggle` blocks. |
| `codeLanguage` | `string` | No | Syntax highlight grammar for `code` blocks (e.g. `dart`, `python`). |
| `icon` | `string` | No | Emoji/icon string for blocks (commonly `callout`), normalized by Folio. |
| `url` | `string` | No | File path or URL for `file`, `video`, `audio`, `image`, `bookmark`, `embed` blocks. |
| `imageWidth` | `float` | No | Relative width for `image` blocks (`0.2`–`1.0`, default `1.0`). |

**Supported `type` values:** `paragraph`, `h1`, `h2`, `h3`, `bullet`, `numbered`, `todo`, `task`, `toggle`, `code`, `mermaid`, `equation`, `image`, `table`, `quote`, `divider`, `callout`, `file`, `video`, `audio`, `bookmark`, `embed`, `toc`, `breadcrumb`, `child_page`.

**`task` block `text` format:**

```json
{"v":1,"title":"Task title","status":"todo","priority":"high","dueDate":"2026-06-01"}
```

- `status`: `"todo"` | `"in_progress"` | `"done"`.
- `priority`: `"low"` | `"medium"` | `"high"` | `null`.
- `dueDate`: ISO 8601 date string `"YYYY-MM-DD"` | `null`.

### Success Response

```json
{
  "ok": true,
  "sessionId": "8f2e9c1a",
  "pageId": "page_456",
  "title": "My Rich Document",
  "blockCount": 4,
  "mode": "newPage",
  "message": "Imported successfully"
}
```

---

## Update Page — JSON Blocks Mode

The [Update Page](#update-page-endpoint) endpoint also accepts a `blocks` array instead of `markdown`. When `blocks` is present in the request body, it takes precedence and Markdown parsing is skipped entirely.

```json
{
  "sessionId": "8f2e9c1a",
  "importMode": "replaceCurrentPage",
  "blocks": [
    { "type": "h1", "text": "Refreshed Document" },
    { "type": "paragraph", "text": "Content sourced from a structured data model." }
  ]
}
```

- `blocks` and `markdown` are mutually exclusive. If both are provided, `blocks` takes precedence.
- The same ownership rule applies: only the app that originally imported the page may update it.
- Both `replaceCurrentPage` and `appendToCurrentPage` modes are supported.

---

## Fixed Port

Folio uses this fixed localhost port:

```text
45831
```

Clients do not need dynamic port discovery.

## Security Rules

- Folio binds the bridge only to `127.0.0.1`.
- Protected endpoints require `X-Folio-App-Id`, `X-Folio-App-Name`, `X-Folio-App-Version`, and `X-Folio-Integration-Version`.
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

1. Configure `appId`, `appName`, `appVersion`, and `integrationVersion`.
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
