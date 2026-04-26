# Folio Telemetry

Folio uses **privacy-first telemetry** to understand how people use the app and to improve reliability. Telemetry is enabled by default and can be turned off in **Settings → Privacy**.

## Two channels

1. **Firebase Analytics** (when telemetry is on): events use an **anonymous installation ID** (`setUserId` on the client). No Folio Cloud account is required.
2. **Firestore** (`analytics_events/{firebaseAuthUid}/events`): a **copy** of the same kinds of events is written **only when the user is signed in** with Firebase Auth (Folio Cloud session). Documents include the authenticated **Firebase UID** in the path and in the payload as `userId`. This is **not** the same as the anonymous Analytics ID.

Aggregations and staff dashboards use Firestore data under `analytics_events` and `telemetryGlobalStats`.

## What we collect

### Feature usage

Opening the editor, board, search, settings, and other features.

### Content interactions

Creating, editing, or deleting notes and boards; viewing content; publishing (where applicable).

### Navigation

Screen transitions (route names) to understand flow. Volume may be throttled on the client.

### Search and filtering

Search-related signals where instrumented.

### Synchronization

Cloud pack upload/download and other sync operations: success or failure, duration when available.

### Performance

Durations for selected operations (not every keystroke).

### Errors

Errors and crashes when telemetry is enabled; may overlap with optional automatic crash reports.

### Usage statistics

Aggregated counts or sizes where explicitly logged.

## Privacy

1. **Note content is not collected** — only product telemetry as described.
2. **User control** — disable telemetry in Settings; collection stops for new events.
3. **No ads / no sale** of telemetry as a product.
4. **Firestore** detailed copies require **Folio Cloud sign-in**; **Analytics** uses the **anonymous install ID**.

## In the app

### Everyone

Under **Settings → Privacy → Data sent**: category examples, privacy note, and an optional **technical details** panel showing the last locally recorded event snapshot (JSON-shaped map: `timestamp`, `type`, `data`).

### Staff

Users with `folioStaff == true` can open the **Telemetry dashboard** in Settings for aggregates and recent Firestore events.

## Technical model

### Storage paths

- Raw events: `analytics_events/{firebaseAuthUid}/events/{eventId}`
- Daily per-user stats (written by Cloud Functions): `analytics_events/{firebaseAuthUid}/stats/{YYYY-MM-DD}`
- Global rollups: `telemetryGlobalStats/{YYYY-MM-DD}`
- Daily UID index for cheaper aggregation (backend only): `telemetryDailyUserIndex/{YYYY-MM-DD}` with field `userIds` (array)

### Event document shape (Firestore)

Fields are largely **flat** on the document root, for example:

- `timestamp`, `type`, `userId` (Firebase Auth UID), `appVersion`, `buildNumber`
- Type-specific fields (e.g. `featureName`, `durationMs`, `syncType`, `success`) as appropriate
- Optional nested maps where the event type requires them

There is **no** generic `data` wrapper at the root of the Firestore document; the Settings “technical details” panel shows a small **local snapshot** with a nested `data` map for display only.

### Cloud Functions

- **Trigger** on new `analytics_events/{uid}/events/{id}` updates `telemetryDailyUserIndex` for the current UTC day.
- **Scheduled** job aggregates the current UTC day per user into `stats` (uses the index; falls back to a collection-group scan if the index doc is empty).
- **Nightly** global aggregation reads per-user `stats` into `telemetryGlobalStats`.

## Retention

Operational retention follows your Firebase project configuration and admin practices; this document does not define legal retention periods.

## Questions

See Folio’s [Privacy Policy](https://folio.app/privacy) or support for privacy questions.
