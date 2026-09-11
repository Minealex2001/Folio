# Third-Party Notices — Folio

This file lists curated open-source and third-party components used by Folio.
Keep it aligned by hand with `lib/legal/third_party_licenses_catalog.dart`.

The full Dart/Flutter package license tree is also available in the app via
**About → Open source & third-party licenses → Flutter & Dart package licenses**
(Flutter `LicensePage` / `LicenseRegistry`), and in Flutter build `NOTICES` artifacts.

---

## Open source / runtime

### whisper.cpp

- License: MIT
- Copyright: Copyright (c) 2023 Georgi Gerganov and contributors
- Source: https://github.com/ggerganov/whisper.cpp
- Notes: Binary downloaded at runtime for local speech-to-text. GGML model
  weights have separate upstream terms; review per model.

### Iconify

- License: Varies by icon collection (typically MIT / Apache-2.0 / ISC)
- Source: https://iconify.design
- Notes: Icons are fetched at runtime from api.iconify.design.

### Passkeys Web SDK (`web/bundle.js`)

- License: ISC-style (Microsoft)
- Copyright: Copyright (c) Microsoft Corporation
- Source: https://github.com/corbado/flutter-passkeys/tree/main/packages/passkeys/passkeys

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

---

## Commercial / other terms

### Syncfusion Flutter PDF / PDF Viewer

- Packages: `syncfusion_flutter_pdf`, `syncfusion_flutter_pdfviewer`
- License: Syncfusion Community License Program or Syncfusion commercial license
- Terms: https://www.syncfusion.com/content/downloads/syncfusion_license.pdf
- Source: https://www.syncfusion.com/flutter-widgets

---

## Fonts

### Google Fonts families used by Folio

Loaded at runtime via the `google_fonts` package:

Outfit, Nunito, Inter, JetBrains Mono, Space Grotesk, DM Sans, Merriweather,
Poppins, Lexend, Oswald, Orbitron.

- Typical license: SIL Open Font License 1.1 (OFL-1.1)
- Source: https://fonts.google.com
- Confirm each family’s license on fonts.google.com when redistributing font files.

---

## Assets / trademarks

### Integration brand logos (`assets/appLogos`)

Logos for Jira, YouTrack, Trello, GitHub, GitLab, Slack, Microsoft Teams,
Spotify, and YouTube Music.

These are trademarks of their respective owners and are not open-source software.

---

## Dart & Flutter packages (direct dependencies)

Full license texts for these and their transitive dependencies are provided by
Flutter’s license registry. Short identifiers from package LICENSE files:

| Package | License | Copyright (from LICENSE when present) | Source |
| ------- | ------- | ------------------------------------- | ------ |
| cupertino_icons | MIT | Copyright (c) 2016 Vladimir Kharlampidi | https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons |
| cryptography | Apache-2.0 | — | https://github.com/dint-dev/cryptography |
| crypto | BSD-3-Clause | Copyright 2015, the Dart project authors | https://github.com/dart-lang/core/tree/main/pkgs/crypto |
| path_provider | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider |
| local_auth | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/local_auth/local_auth |
| uuid | MIT | Copyright (c) 2021 Yulian Kuncheff | https://github.com/Daegalus/dart-uuid |
| collection | BSD-3-Clause | Copyright 2015, the Dart project authors | https://github.com/dart-lang/core/tree/main/pkgs/collection |
| passkeys | BSD-3-Clause | Copyright (c) 2023, Corbado GmbH | https://github.com/corbado/flutter-passkeys/tree/main/packages/passkeys/passkeys |
| path | BSD-3-Clause | Copyright 2014, the Dart project authors | https://github.com/dart-lang/core/tree/main/pkgs/path |
| shared_preferences | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences |
| google_fonts | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/google_fonts |
| system_theme | BSD-3-Clause | Copyright (c) 2021, Bruno D'Luka | https://github.com/bdlukaa/system_theme |
| dynamic_color | Apache-2.0 | — | https://github.com/material-foundation/flutter-packages/tree/main/packages/dynamic_color |
| image_picker | Apache-2.0 | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/image_picker/image_picker |
| file_picker | MIT | Copyright (c) 2018 Miguel Ruivo | https://github.com/miguelpruivo/flutter_file_picker |
| flutter_code_editor | Apache-2.0 | — | https://github.com/akvelon/flutter-code-editor |
| highlight | MIT | Copyright (c) 2019 Rongjian Zhang | https://github.com/pd4d10/highlight |
| diff_match_patch | Apache-2.0 | — | https://github.com/jheyne/diff-match-patch |
| markdown | BSD-3-Clause | Copyright 2012, the Dart project authors | https://github.com/dart-lang/tools/tree/main/pkgs/markdown |
| flutter_markdown_plus | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/foresightmobile/flutter_markdown_plus |
| archive | MIT | Copyright (c) 2013-2021 Brendan Duncan | https://github.com/brendan-duncan/archive |
| video_player | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/video_player/video_player |
| url_launcher | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher |
| app_links | Apache-2.0 | — | https://github.com/llfbandit/app_links |
| emoji_picker_flutter | MIT | Copyright (c) 2024 Stefan Humm | https://github.com/Fintasys/emoji_picker_flutter |
| hotkey_manager | MIT | Copyright (c) 2022-2024 LiJianying | https://github.com/leanflutter/hotkey_manager |
| window_manager | MIT | Copyright (c) 2022-present LiJianying | https://github.com/leanflutter/window_manager |
| tray_manager | MIT | Copyright (c) 2022-present LiJianying | https://github.com/leanflutter/tray_manager |
| launch_at_startup | MIT | Copyright (c) 2023-present LiJianying | https://github.com/leanflutter/launch_at_startup |
| printing | Apache-2.0 | — | https://github.com/DavBfr/dart_pdf |
| http | BSD-3-Clause | Copyright 2014, the Dart project authors | https://github.com/dart-lang/http/tree/master/pkgs/http |
| flutter_secure_storage | BSD-3-Clause | Copyright 2017 German Saprykin | https://github.com/mogol/flutter_secure_storage/tree/develop/flutter_secure_storage |
| webdav_client | BSD-3-Clause | Copyright (c) 2020, MZERO | https://github.com/flymzero/webdav_client |
| package_info_plus | BSD-3-Clause | Copyright 2017 The Chromium Authors | https://github.com/fluttercommunity/plus_plugins/tree/main/packages/package_info_plus/package_info_plus |
| pub_semver | BSD-3-Clause | Copyright 2014, the Dart project authors | https://github.com/dart-lang/tools/tree/main/pkgs/pub_semver |
| video_player_win | BSD-3-Clause | Copyright 2022, jakky1 | https://github.com/jakky1/video_player_win |
| webview_flutter | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/webview_flutter/webview_flutter |
| webview_windows | BSD-3-Clause | Copyright (c) 2021 Niklas Schulze | https://github.com/jnschulze/flutter-webview-windows |
| flutter_math_fork | Apache-2.0 | — | https://github.com/simpleclub/flutter_math |
| flutter_svg | MIT | Copyright (c) 2018 Dan Field | https://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg |
| audioplayers | MIT | Copyright (c) 2017 Blue Fire | https://github.com/bluefireteam/audioplayers/tree/master/packages/audioplayers |
| record | BSD-3-Clause | Copyright 2022 openapi4j authors | https://github.com/llfbandit/record/tree/master/record |
| intl | BSD-3-Clause | Copyright 2013, the Dart project authors | https://github.com/dart-lang/i18n/tree/main/pkgs/intl |
| flutter_quill | MIT | Copyright (c) 2024 Flutter Quill project and open source contributors | https://github.com/singerdmx/flutter-quill |
| cross_file | BSD-3-Clause | Copyright 2013 The Flutter Authors | https://github.com/flutter/packages/tree/main/packages/cross_file |
| desktop_drop | Apache-2.0 | — | https://github.com/MixinNetwork/flutter-plugins/tree/main/packages/desktop_drop |
| super_clipboard | MIT | Copyright (c) 2022 Superlist, Matej Knopp and the contributors | https://github.com/superlistapp/super_native_extensions/tree/main/super_clipboard |
| local_notifier | MIT | Copyright (c) 2022-present LiJianying | https://github.com/leanflutter/local_notifier |
| idb_shim | BSD-2-Clause | Copyright (c) 2014, alextekartik | https://github.com/tekartik/idb_shim.dart/tree/master/idb_shim |
| dart_quill_delta | MIT | Copyright (c) 2024 Flutter Quill project and open source contributors | https://github.com/FlutterQuill/dart-quill-delta |
| flutter_colorpicker | MIT | Copyright (c) 2021 fuyumi | https://github.com/mchome/flutter_colorpicker |
| pdf | Apache-2.0 | — | https://github.com/DavBfr/dart_pdf |
| http_parser | BSD-3-Clause | Copyright 2014, the Dart project authors | https://github.com/dart-lang/http/tree/master/pkgs/http_parser |
| cbor | MIT | Copyright (c) 2016 Steve Hamblett | https://github.com/shamblett/cbor |
| pointycastle | MIT / Bouncy Castle | Copyright (c) 2000 - 2019 The Legion of the Bouncy Castle Inc. | https://github.com/bcgit/pc-dart |
| git | BSD-2-Clause | Copyright (c) 2012, Kevin Moore | https://github.com/kevmoo/git |
| json_annotation | BSD-3-Clause | Copyright 2017, the Dart project authors | https://github.com/google/json_serializable.dart/tree/master/json_annotation |
| stomp_dart_client | BSD-3-Clause | Copyright 2021 Tobias Kammerer (Blackhorse One GmbH) | https://github.com/blackhorse-one/stomp_dart |

Syncfusion packages are listed under **Commercial / other terms** above (not as OSS MIT/BSD).

---

## FolioBackend (Maven / Spring Boot)

Source: `FolioBackend/pom.xml` (Spring Boot parent **3.3.5**). Runtime / compile
dependencies only are listed in the About UI. Test-scoped artifacts are
documented in `docs/LICENSE_AUDIT.md` and omitted from the app list.

| Component | License | Source |
| --------- | ------- | ------ |
| Spring Boot starters (web, websocket, security, data-jpa, validation, actuator, aop) | Apache-2.0 | https://github.com/spring-projects/spring-boot |
| resilience4j-spring-boot3 | Apache-2.0 | https://github.com/resilience4j/resilience4j |
| micrometer-registry-prometheus | Apache-2.0 | https://github.com/micrometer-metrics/micrometer |
| Flyway (flyway-core / flyway-database-postgresql) | Apache-2.0 | https://github.com/flyway/flyway |
| PostgreSQL JDBC Driver | BSD-2-Clause | https://github.com/pgjdbc/pgjdbc |
| springdoc-openapi-starter-webmvc-ui | Apache-2.0 | https://github.com/springdoc/springdoc-openapi |
| JJWT (jjwt-api / jjwt-impl / jjwt-jackson) | Apache-2.0 | https://github.com/jwtk/jjwt |
| Bouncy Castle (bcprov-jdk18on) | Bouncy Castle Licence | https://www.bouncycastle.org |
| stripe-java | MIT | https://github.com/stripe/stripe-java |
| AWS SDK for Java v2 (s3) | Apache-2.0 | https://github.com/aws/aws-sdk-java-v2 |

### Test-only (not shown in About UI)

| Component | Scope | License (typical) | Notes |
| --------- | ----- | ----------------- | ----- |
| spring-boot-starter-test | test | Apache-2.0 | Dev/test |
| spring-security-test | test | Apache-2.0 | Dev/test |
| testcontainers (junit-jupiter, postgresql, localstack) | test | MIT | Dev/test |
| okhttp3 mockwebserver | test | Apache-2.0 | Dev/test |

---

## Call.md

Not listed. No verified incorporation of Call.md source into Folio at the time of this notice. See `docs/LICENSE_AUDIT.md`.
