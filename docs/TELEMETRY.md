# Folio Telemetry

Since the Firebase → Spring Boot migration (see `MIGRACION_SPRINGBOOT.md`), Folio's client-side telemetry is **local-only and inert**: it does not send data to Firebase Analytics, Firestore, or any backend. This document describes the current state, not the pre-migration design.

## Current implementation

`FolioApp/lib/services/folio_telemetry.dart` (`FolioTelemetry`) keeps the same public API the app called before the migration (`logFeatureUsed`, `logContentAction`, `logNavigation`, `logSearch`, `logSyncEvent`, `logPerformance`, `logError`, `logUsageStats`, the onboarding-funnel loggers), so call sites throughout the app didn't need to change. Internally, every logging method now:

1. Checks `AppSettings.telemetryEnabled` (Settings → Privacy toggle) exactly as before.
2. If enabled, builds the same typed event object as before (see `telemetry_models.dart`).
3. **Only** writes a JSON snapshot of that single event to `SharedPreferences` under `folio_last_event_snapshot` — no network call, no Firebase Analytics event, no Firestore write.

This snapshot is what powers the **Settings → Privacy → Data sent → technical details** panel (`getLastEventSnapshot()`): it shows the *last* event recorded, purely for user transparency, and is never transmitted anywhere.

The one-time anonymous install id (`anonymousInstallId()`) is still generated and stored locally (`folio_anonymous_install_id`), but the old `folio_install` GA4 ping this fed into no longer exists — the id is currently unused beyond being available if a future telemetry backend is built.

## What this means in practice

- No usage/feature/navigation/error telemetry leaves the device today, regardless of the Settings → Privacy toggle.
- The **staff Telemetry dashboard** described in earlier versions of this doc (Firestore aggregates, `telemetryGlobalStats`) no longer has any data source and should be considered decommissioned unless rebuilt against the new backend.
- `google-services.json` / `GoogleService-Info.plist` / GA4 measurement IDs are no longer required for telemetry (they may still be referenced in old project files pending cleanup elsewhere in the migration).

## If real telemetry collection is wanted again

This is a product decision, not implied by this doc. If pursued, the natural path is a small first-party sink on `FolioBackend` (e.g. `POST /api/v1/telemetry`) writing to Postgres, or riding on the Actuator/Micrometer metrics pipeline added for backend observability — not a return to Firebase Analytics/Firestore. Any such change should update `FolioTelemetry`'s internal implementation (the public API can likely stay the same) and this document.

## Questions

See Folio's [Privacy Policy](https://folio.app/privacy) or support for privacy questions.
