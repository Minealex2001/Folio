# Folio Telemetry

Folio uses **privacy-first telemetry** to understand how people use the app and to improve reliability. **Optional usage statistics** can be turned off in **Settings → Privacy**.

## Install signal (always)

Once per installation, the client sends a single Firebase Analytics event **`folio_install`** with anonymous fields (`app_version`, `build_number`, `folio_platform`). This runs **even when optional usage statistics are disabled**, so install counts in GA4 stay meaningful. It does **not** include notebook content or titles.

## Two channels

1. **Firebase Analytics**: optional events (feature usage, navigation, etc.) use an **anonymous installation ID** (`setUserId`) when usage statistics are **on**. The **`folio_install`** ping is independent of that toggle. No Folio Cloud account is required for Analytics.
2. **Firestore** (`analytics_events/{firebaseAuthUid}/events`): a **copy** of optional telemetry events is written **only when the user is signed in** with Firebase Auth (Folio Cloud session). Documents include the authenticated **Firebase UID** in the path and in the payload as `userId`. This is **not** the same as the anonymous Analytics ID.

Staff dashboards use Firestore data under `analytics_events` and `telemetryGlobalStats`. **Install totals across all users (including anonymous)** are viewed in **Google Analytics / GA4** (event `folio_install` or stream reports), not in the in-app Firestore dashboard.

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

Errors and crashes when optional usage statistics are enabled; may overlap with optional automatic crash reports.

### Usage statistics

Aggregated counts or sizes where explicitly logged.

## Privacy

1. **Note content is not collected** — only product telemetry as described.
2. **User control** — optional usage statistics can be disabled in Settings; **other** Analytics events stop. The one-time **`folio_install`** signal still fires once per install (anonymous).
3. **No ads / no sale** of telemetry as a product.
4. **Firestore** detailed copies require **Folio Cloud sign-in**; **Analytics** uses the **anonymous install ID**.

## Google Analytics on every platform (troubleshooting)

The Dart client does not gate Analytics by OS. If GA4 shows traffic for only one platform, check **Firebase Console** and native project files:

| Platform | Checklist |
|----------|-----------|
| **Android** | App registered; `google-services.json` in `android/app/`; SHA keys for release if needed. |
| **iOS** | App registered with bundle `com.minealexgames.folio`. Add **`GoogleService-Info.plist`** to the Xcode **Runner** target (often not committed; download from Firebase after `flutterfire configure`). Without it, iOS builds send **no** Analytics data. |
| **Web** | Web app in Firebase with **measurement ID**; `lib/firebase_options.dart` includes `measurementId` for `web`. Traffic may appear under the **Web** data stream. |
| **Windows / Linux** | `DefaultFirebaseOptions` uses the **same Web app** (`measurementId`); events typically appear as **Web** in GA4, not as Android. |
| **macOS** | Bundle ID **`com.minealexgames.folio.macos`** (see `macos/Runner/Configs/AppInfo.xcconfig`) must match a **macOS** (or Apple) app registered in Firebase; download options with `flutterfire configure` and align `lib/firebase_options.dart` `macos` if you add a new Firebase app. |

After changes, validate with **GA4 DebugView** on a real device per platform.

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
- **Scheduled** global aggregation (**hourly**, UTC minute 15) reads per-user `stats` into `telemetryGlobalStats` for **today** and **yesterday** so the staff dashboard’s “today” document is populated during the day.

## Retention

Operational retention follows your Firebase project configuration and admin practices; this document does not define legal retention periods.

## Questions

See Folio’s [Privacy Policy](https://folio.app/privacy) or support for privacy questions.
