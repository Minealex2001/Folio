# License audit — FolioApp

Date: 2026-08-09  
Scope: Folio Flutter app (`FolioApp`). Independent of `meeting_note` / Call.md feature work.

## Method

- Direct dependencies from `pubspec.yaml` / `pubspec.lock`.
- LICENSE / copyright read from pub-cache package trees.
- Assets, `web/bundle.js`, `google_fonts` families, Iconify, whisper.cpp, Syncfusion reviewed separately.
- Transitive Dart/Flutter packages are exposed in-app via Flutter `LicensePage` / `LicenseRegistry` (not duplicated in the curated catalog).

Categories: **A** attribution UI, **B** license notice, **C** no About UI required, **D** unclear / pending.

## Call.md / VideoDB

| Status | Detail |
| ------ | ------ |
| Pre-audit | No `Call.md` / `VideoDB` matches in FolioApp source. |
| Parallel work | Another agent is implementing related functionality (`meeting_note`, etc.). |
| Closing re-audit | See section **Call.md re-audit** below. Until verified, classification is **D — PENDING**. |
| UI | Do **not** list Call.md as incorporated code unless re-audit finds reused code subject to attribution. |

## Summary inventory (curated)

| Component | Type | License | Copyright / notes | Source | In Folio? | Action | Cat |
| --------- | ---- | ------- | ----------------- | ------ | --------- | ------ | --- |
| Direct pub packages (see catalog) | Dart package | MIT / BSD / Apache / etc. | From each LICENSE | pub / GitHub | Yes | Include in curated list + Flutter LicensePage | A/B |
| FolioBackend Maven runtime deps | Java library | Apache-2.0 / MIT / BSD / BC | See Backend section | FolioBackend/pom.xml | Cloud backend | Include in About (Backend category) | A/B |
| FolioBackend test-only deps | Java (test) | Apache-2.0 / MIT | — | FolioBackend/pom.xml | Test only | Audit only; not in About UI | C |
| syncfusion_flutter_pdf / pdfviewer | Commercial SDK | Syncfusion Community / Commercial | Syncfusion Inc. | syncfusion.com | Yes | Include notice | A/B |
| google_fonts + listed families | Package + fonts | BSD-3-Clause + OFL-1.1 (typical) | Flutter Authors / font authors | fonts.google.com | Yes (runtime) | Include fonts entry | A/B |
| Iconify | Runtime API | Varies by set | — | iconify.design | Yes (network) | Include | A |
| whisper.cpp | Downloaded binary | MIT | Georgi Gerganov et al. | github.com/ggerganov/whisper.cpp | Yes (runtime download) | Include | A/B |
| GGML models (whisper) | Model weights | Model-specific | Hugging Face / upstream | huggingface.co/ggerganov/whisper.cpp | Downloaded | Document; review per model | D |
| web/bundle.js | Bundled JS | ISC-style Microsoft | Microsoft Corporation | Corbado passkeys / Microsoft | Yes (web) | Include | A/B |
| assets/appLogos/* | Brand assets | Trademark | Respective owners | — | Yes | Include trademark note | A |
| Folio brand icons | First-party | Folio | Folio | — | Yes | Not third-party | C |
| PDFium (via printing) | Native (transitive) | See printing/build NOTICES | — | DavBfr/dart_pdf | Build | Flutter LicensePage / build NOTICES | B |
| WebView2 (Windows) | Platform | Microsoft terms | Microsoft | — | Windows | Platform; not curated as Folio OSS | C/D |
| Call.md | External project | PENDING | PENDING | PENDING | Unknown until re-audit | Omit from UI while PENDING | D |

## Shown in About UI

All `showInAboutUi: true` entries in `lib/legal/third_party_licenses_catalog.dart`, plus the Flutter `LicensePage` entry for the full package tree.

### FolioBackend (runtime)

Verified from `FolioBackend/pom.xml` and upstream LICENSE / Maven metadata:

| Artifact | License | Source |
| -------- | ------- | ------ |
| Spring Boot starters (3.3.5 parent) | Apache-2.0 | spring-projects/spring-boot |
| resilience4j-spring-boot3 2.2.0 | Apache-2.0 | resilience4j/resilience4j |
| micrometer-registry-prometheus | Apache-2.0 | micrometer-metrics/micrometer |
| flyway-core / flyway-database-postgresql | Apache-2.0 | flyway/flyway |
| postgresql (JDBC) | BSD-2-Clause | pgjdbc/pgjdbc |
| springdoc-openapi-starter-webmvc-ui 2.6.0 | Apache-2.0 | springdoc/springdoc-openapi |
| jjwt-api / jjwt-impl / jjwt-jackson 0.12.6 | Apache-2.0 | jwtk/jjwt |
| bcprov-jdk18on 1.78.1 | Bouncy Castle Licence | bouncycastle.org |
| stripe-java 28.4.0 | MIT | stripe/stripe-java |
| software.amazon.awssdk:s3 2.29.45 | Apache-2.0 | aws/aws-sdk-java-v2 |

Test-scoped: spring-boot-starter-test, spring-security-test, testcontainers (junit-jupiter, postgresql, localstack), okhttp mockwebserver → **C** (not in About UI).

## Included in THIRD_PARTY_NOTICES.md

Same curated inventory (`includeInNoticesFile: true`). Full transitive package texts remain available via Flutter-generated NOTICES at build time and in-app `LicensePage`.

## Reused third-party code (non-pub)

- `web/bundle.js` — Microsoft permissive header (passkeys web).
- Syncfusion packages — proprietary terms (not OSS).
- whisper.cpp — downloaded upstream binary (not vendored in repo).

## Inspiration / reimplementation (not attributed as reused code)

- Notion / Obsidian visual packs: Folio-authored packs inspired by aesthetics.
- Mermaid preview via mermaid.ink remote rendering (no mermaid.js vendored).
- Call.md: see re-audit; do not treat functional inspiration as code reuse.

## Pending review

- Whisper GGML model license terms per selected model size.
- Exact Syncfusion Community vs commercial entitlement for Folio distribution (ops/legal, not code).
- Call.md attribution until feature branch is re-audited.

## Call.md re-audit

Performed at implementation close (same workspace snapshot):

- Grep for `Call.md`, `call.md`, `VideoDB`, `videodb`, SPDX / Copyright headers in `lib/`: **no Call.md / VideoDB hits**.
- `meeting_note` settings section exists as Folio code; no provenance headers attributing Call.md.
- **Classification: PENDING / no verified reused Call.md code in this tree.** Omit Call.md from About UI and notices until verified reuse lands.

## Maintenance

When adding a dependency or vendored asset:

1. Update `docs/LICENSE_AUDIT.md`.
2. Update `lib/legal/third_party_licenses_catalog.dart`.
3. Update `THIRD_PARTY_NOTICES.md` by hand in the same change.
