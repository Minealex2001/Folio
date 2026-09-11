import 'common_license_texts.dart';
import 'third_party_license.dart';

/// Curated inventory of third-party components Folio incorporates or ships.
///
/// Keep this list aligned by hand with `THIRD_PARTY_NOTICES.md` and
/// `docs/LICENSE_AUDIT.md`. Do not invent licenses or URLs.
abstract final class ThirdPartyLicensesCatalog {
  static final List<ThirdPartyLicenseEntry> entries = [
    // --- Open source / runtime (non-pub curated) ---
    ThirdPartyLicenseEntry(
      id: 'whisper-cpp',
      name: 'whisper.cpp',
      license: 'MIT',
      copyright: 'Copyright (c) 2023 Georgi Gerganov and contributors',
      description:
          'Speech-to-text binary downloaded at runtime for local transcription.',
      sourceUrl: 'https://github.com/ggerganov/whisper.cpp',
      licenseText: CommonLicenseTexts.withCopyright(
        'Copyright (c) 2023 Georgi Gerganov and contributors',
        CommonLicenseTexts.mit,
      ),
      category: ThirdPartyLicenseCategory.openSource,
    ),
    ThirdPartyLicenseEntry(
      id: 'passkeys-web-bundle',
      name: 'Passkeys Web SDK (web/bundle.js)',
      license: 'ISC-style (Microsoft)',
      copyright: 'Copyright (c) Microsoft Corporation',
      description:
          'Bundled JavaScript used by the web passkeys integration '
          '(Corbado flutter-passkeys).',
      sourceUrl:
          'https://github.com/corbado/flutter-passkeys/tree/main/packages/passkeys/passkeys',
      licenseText: CommonLicenseTexts.microsoftPermissive,
      category: ThirdPartyLicenseCategory.nativeOrRuntime,
    ),
    ThirdPartyLicenseEntry(
      id: 'iconify',
      name: 'Iconify',
      license: 'Varies by icon set (typically MIT / Apache-2.0 / ISC)',
      copyright: null,
      description:
          'Icon catalog loaded at runtime from api.iconify.design. '
          'Individual icon collections keep their upstream licenses.',
      sourceUrl: 'https://iconify.design',
      category: ThirdPartyLicenseCategory.openSource,
    ),
    ThirdPartyLicenseEntry(
      id: 'syncfusion-flutter-pdf',
      name: 'Syncfusion Flutter PDF / PDF Viewer',
      license: 'Syncfusion Community / Commercial',
      copyright: 'Copyright Syncfusion Inc.',
      description:
          'syncfusion_flutter_pdf and syncfusion_flutter_pdfviewer. '
          'Requires a valid Syncfusion Community or commercial license.',
      sourceUrl: 'https://www.syncfusion.com/flutter-widgets',
      licenseText: CommonLicenseTexts.syncfusionNotice,
      category: ThirdPartyLicenseCategory.other,
    ),

    // --- Dart / Flutter direct packages ---
    _pkg(
      id: 'cupertino_icons',
      name: 'cupertino_icons',
      license: 'MIT',
      copyright: 'Copyright (c) 2016 Vladimir Kharlampidi',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons',
    ),
    _pkg(
      id: 'cryptography',
      name: 'cryptography',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/dint-dev/cryptography',
    ),
    _pkg(
      id: 'crypto',
      name: 'crypto',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2015, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/core/tree/main/pkgs/crypto',
    ),
    _pkg(
      id: 'path_provider',
      name: 'path_provider',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider',
    ),
    _pkg(
      id: 'local_auth',
      name: 'local_auth',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/local_auth/local_auth',
    ),
    _pkg(
      id: 'uuid',
      name: 'uuid',
      license: 'MIT',
      copyright: 'Copyright (c) 2021 Yulian Kuncheff',
      sourceUrl: 'https://github.com/Daegalus/dart-uuid',
    ),
    _pkg(
      id: 'collection',
      name: 'collection',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2015, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/core/tree/main/pkgs/collection',
    ),
    _pkg(
      id: 'passkeys',
      name: 'passkeys',
      license: 'BSD-3-Clause',
      copyright: 'Copyright (c) 2023, Corbado GmbH',
      sourceUrl:
          'https://github.com/corbado/flutter-passkeys/tree/main/packages/passkeys/passkeys',
    ),
    _pkg(
      id: 'path',
      name: 'path',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2014, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/core/tree/main/pkgs/path',
    ),
    _pkg(
      id: 'shared_preferences',
      name: 'shared_preferences',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences',
    ),
    _pkg(
      id: 'google_fonts',
      name: 'google_fonts',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/google_fonts',
    ),
    _pkg(
      id: 'system_theme',
      name: 'system_theme',
      license: 'BSD-3-Clause',
      copyright: "Copyright (c) 2021, Bruno D'Luka",
      sourceUrl: 'https://github.com/bdlukaa/system_theme',
    ),
    _pkg(
      id: 'dynamic_color',
      name: 'dynamic_color',
      license: 'Apache-2.0',
      sourceUrl:
          'https://github.com/material-foundation/flutter-packages/tree/main/packages/dynamic_color',
    ),
    _pkg(
      id: 'image_picker',
      name: 'image_picker',
      license: 'Apache-2.0',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/image_picker/image_picker',
    ),
    _pkg(
      id: 'file_picker',
      name: 'file_picker',
      license: 'MIT',
      copyright: 'Copyright (c) 2018 Miguel Ruivo',
      sourceUrl: 'https://github.com/miguelpruivo/flutter_file_picker',
    ),
    _pkg(
      id: 'flutter_code_editor',
      name: 'flutter_code_editor',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/akvelon/flutter-code-editor',
    ),
    _pkg(
      id: 'highlight',
      name: 'highlight',
      license: 'MIT',
      copyright: 'Copyright (c) 2019 Rongjian Zhang',
      sourceUrl: 'https://github.com/pd4d10/highlight',
    ),
    _pkg(
      id: 'diff_match_patch',
      name: 'diff_match_patch',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/jheyne/diff-match-patch',
    ),
    _pkg(
      id: 'markdown',
      name: 'markdown',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2012, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/tools/tree/main/pkgs/markdown',
    ),
    _pkg(
      id: 'flutter_markdown_plus',
      name: 'flutter_markdown_plus',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl: 'https://github.com/foresightmobile/flutter_markdown_plus',
    ),
    _pkg(
      id: 'archive',
      name: 'archive',
      license: 'MIT',
      copyright: 'Copyright (c) 2013-2021 Brendan Duncan',
      sourceUrl: 'https://github.com/brendan-duncan/archive',
    ),
    _pkg(
      id: 'video_player',
      name: 'video_player',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/video_player/video_player',
    ),
    _pkg(
      id: 'url_launcher',
      name: 'url_launcher',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher',
    ),
    _pkg(
      id: 'app_links',
      name: 'app_links',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/llfbandit/app_links',
    ),
    _pkg(
      id: 'emoji_picker_flutter',
      name: 'emoji_picker_flutter',
      license: 'MIT',
      copyright: 'Copyright (c) 2024 Stefan Humm',
      sourceUrl: 'https://github.com/Fintasys/emoji_picker_flutter',
    ),
    _pkg(
      id: 'hotkey_manager',
      name: 'hotkey_manager',
      license: 'MIT',
      copyright: 'Copyright (c) 2022-2024 LiJianying',
      sourceUrl: 'https://github.com/leanflutter/hotkey_manager',
    ),
    _pkg(
      id: 'window_manager',
      name: 'window_manager',
      license: 'MIT',
      copyright: 'Copyright (c) 2022-present LiJianying',
      sourceUrl: 'https://github.com/leanflutter/window_manager',
    ),
    _pkg(
      id: 'tray_manager',
      name: 'tray_manager',
      license: 'MIT',
      copyright: 'Copyright (c) 2022-present LiJianying',
      sourceUrl: 'https://github.com/leanflutter/tray_manager',
    ),
    _pkg(
      id: 'launch_at_startup',
      name: 'launch_at_startup',
      license: 'MIT',
      copyright: 'Copyright (c) 2023-present LiJianying',
      sourceUrl: 'https://github.com/leanflutter/launch_at_startup',
    ),
    _pkg(
      id: 'printing',
      name: 'printing',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/DavBfr/dart_pdf',
    ),
    _pkg(
      id: 'http',
      name: 'http',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2014, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/http/tree/master/pkgs/http',
    ),
    _pkg(
      id: 'flutter_secure_storage',
      name: 'flutter_secure_storage',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2017 German Saprykin',
      sourceUrl:
          'https://github.com/mogol/flutter_secure_storage/tree/develop/flutter_secure_storage',
    ),
    _pkg(
      id: 'webdav_client',
      name: 'webdav_client',
      license: 'BSD-3-Clause',
      copyright: 'Copyright (c) 2020, MZERO',
      sourceUrl: 'https://github.com/flymzero/webdav_client',
    ),
    _pkg(
      id: 'package_info_plus',
      name: 'package_info_plus',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2017 The Chromium Authors',
      sourceUrl:
          'https://github.com/fluttercommunity/plus_plugins/tree/main/packages/package_info_plus/package_info_plus',
    ),
    _pkg(
      id: 'pub_semver',
      name: 'pub_semver',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2014, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/tools/tree/main/pkgs/pub_semver',
    ),
    _pkg(
      id: 'video_player_win',
      name: 'video_player_win',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2022, jakky1',
      sourceUrl: 'https://github.com/jakky1/video_player_win',
    ),
    _pkg(
      id: 'webview_flutter',
      name: 'webview_flutter',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/webview_flutter/webview_flutter',
    ),
    _pkg(
      id: 'webview_windows',
      name: 'webview_windows',
      license: 'BSD-3-Clause',
      copyright: 'Copyright (c) 2021 Niklas Schulze',
      sourceUrl: 'https://github.com/jnschulze/flutter-webview-windows',
    ),
    _pkg(
      id: 'flutter_math_fork',
      name: 'flutter_math_fork',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/simpleclub/flutter_math',
    ),
    _pkg(
      id: 'flutter_svg',
      name: 'flutter_svg',
      license: 'MIT',
      copyright: 'Copyright (c) 2018 Dan Field',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg',
    ),
    _pkg(
      id: 'audioplayers',
      name: 'audioplayers',
      license: 'MIT',
      copyright: 'Copyright (c) 2017 Blue Fire',
      sourceUrl:
          'https://github.com/bluefireteam/audioplayers/tree/master/packages/audioplayers',
    ),
    _pkg(
      id: 'record',
      name: 'record',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2022 openapi4j authors',
      sourceUrl: 'https://github.com/llfbandit/record/tree/master/record',
    ),
    _pkg(
      id: 'intl',
      name: 'intl',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013, the Dart project authors',
      sourceUrl: 'https://github.com/dart-lang/i18n/tree/main/pkgs/intl',
    ),
    _pkg(
      id: 'flutter_quill',
      name: 'flutter_quill',
      license: 'MIT',
      copyright:
          'Copyright (c) 2024 Flutter Quill project and open source contributors',
      sourceUrl: 'https://github.com/singerdmx/flutter-quill',
    ),
    _pkg(
      id: 'cross_file',
      name: 'cross_file',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2013 The Flutter Authors',
      sourceUrl:
          'https://github.com/flutter/packages/tree/main/packages/cross_file',
    ),
    _pkg(
      id: 'desktop_drop',
      name: 'desktop_drop',
      license: 'Apache-2.0',
      sourceUrl:
          'https://github.com/MixinNetwork/flutter-plugins/tree/main/packages/desktop_drop',
    ),
    _pkg(
      id: 'super_clipboard',
      name: 'super_clipboard',
      license: 'MIT',
      copyright: 'Copyright (c) 2022 Superlist, Matej Knopp and the contributors',
      sourceUrl:
          'https://github.com/superlistapp/super_native_extensions/tree/main/super_clipboard',
    ),
    _pkg(
      id: 'local_notifier',
      name: 'local_notifier',
      license: 'MIT',
      copyright: 'Copyright (c) 2022-present LiJianying',
      sourceUrl: 'https://github.com/leanflutter/local_notifier',
    ),
    _pkg(
      id: 'idb_shim',
      name: 'idb_shim',
      license: 'BSD-2-Clause',
      copyright: 'Copyright (c) 2014, alextekartik',
      sourceUrl: 'https://github.com/tekartik/idb_shim.dart/tree/master/idb_shim',
    ),
    _pkg(
      id: 'dart_quill_delta',
      name: 'dart_quill_delta',
      license: 'MIT',
      copyright:
          'Copyright (c) 2024 Flutter Quill project and open source contributors',
      sourceUrl: 'https://github.com/FlutterQuill/dart-quill-delta',
    ),
    _pkg(
      id: 'flutter_colorpicker',
      name: 'flutter_colorpicker',
      license: 'MIT',
      copyright: 'Copyright (c) 2021 fuyumi',
      sourceUrl: 'https://github.com/mchome/flutter_colorpicker',
    ),
    _pkg(
      id: 'pdf',
      name: 'pdf',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/DavBfr/dart_pdf',
    ),
    _pkg(
      id: 'http_parser',
      name: 'http_parser',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2014, the Dart project authors',
      sourceUrl:
          'https://github.com/dart-lang/http/tree/master/pkgs/http_parser',
    ),
    _pkg(
      id: 'cbor',
      name: 'cbor',
      license: 'MIT',
      copyright: 'Copyright (c) 2016 Steve Hamblett',
      sourceUrl: 'https://github.com/shamblett/cbor',
    ),
    _pkg(
      id: 'pointycastle',
      name: 'pointycastle',
      license: 'MIT / Bouncy Castle',
      copyright:
          'Copyright (c) 2000 - 2019 The Legion of the Bouncy Castle Inc.',
      sourceUrl: 'https://github.com/bcgit/pc-dart',
    ),
    _pkg(
      id: 'git',
      name: 'git',
      license: 'BSD-2-Clause',
      copyright: 'Copyright (c) 2012, Kevin Moore',
      sourceUrl: 'https://github.com/kevmoo/git',
    ),
    _pkg(
      id: 'json_annotation',
      name: 'json_annotation',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2017, the Dart project authors',
      sourceUrl:
          'https://github.com/google/json_serializable.dart/tree/master/json_annotation',
    ),
    _pkg(
      id: 'stomp_dart_client',
      name: 'stomp_dart_client',
      license: 'BSD-3-Clause',
      copyright: 'Copyright 2021 Tobias Kammerer (Blackhorse One GmbH)',
      sourceUrl: 'https://github.com/blackhorse-one/stomp_dart',
    ),

    // --- FolioBackend (Maven / Spring Boot) runtime deps from pom.xml ---
    _backend(
      id: 'be-spring-boot',
      name: 'Spring Boot (starters)',
      license: 'Apache-2.0',
      copyright: 'Copyright Spring / VMware',
      description:
          'Direct starters: web, websocket, security, data-jpa, validation, '
          'actuator, aop (parent 3.3.5).',
      sourceUrl: 'https://github.com/spring-projects/spring-boot',
    ),
    _backend(
      id: 'be-resilience4j',
      name: 'resilience4j-spring-boot3',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/resilience4j/resilience4j',
    ),
    _backend(
      id: 'be-micrometer-prometheus',
      name: 'micrometer-registry-prometheus',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/micrometer-metrics/micrometer',
    ),
    _backend(
      id: 'be-flyway',
      name: 'Flyway (flyway-core / flyway-database-postgresql)',
      license: 'Apache-2.0',
      copyright: 'Copyright (C) Red Gate Software Ltd',
      sourceUrl: 'https://github.com/flyway/flyway',
    ),
    _backend(
      id: 'be-postgresql-jdbc',
      name: 'PostgreSQL JDBC Driver',
      license: 'BSD-2-Clause',
      sourceUrl: 'https://github.com/pgjdbc/pgjdbc',
    ),
    _backend(
      id: 'be-springdoc-openapi',
      name: 'springdoc-openapi-starter-webmvc-ui',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/springdoc/springdoc-openapi',
    ),
    _backend(
      id: 'be-jjwt',
      name: 'JJWT (jjwt-api / jjwt-impl / jjwt-jackson)',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/jwtk/jjwt',
    ),
    _backend(
      id: 'be-bouncycastle',
      name: 'Bouncy Castle (bcprov-jdk18on)',
      license: 'Bouncy Castle Licence',
      copyright:
          'Copyright (c) 2000 - 2024 The Legion of the Bouncy Castle Inc.',
      sourceUrl: 'https://www.bouncycastle.org',
      licenseText: '''
Copyright (c) 2000-2024 The Legion Of The Bouncy Castle Inc. (https://www.bouncycastle.org)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''',
    ),
    _backend(
      id: 'be-stripe-java',
      name: 'stripe-java',
      license: 'MIT',
      sourceUrl: 'https://github.com/stripe/stripe-java',
    ),
    _backend(
      id: 'be-aws-sdk-s3',
      name: 'AWS SDK for Java v2 (s3)',
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/aws/aws-sdk-java-v2',
    ),

    // --- Fonts (via google_fonts at runtime) ---
    ThirdPartyLicenseEntry(
      id: 'fonts-google-fonts-families',
      name: 'Google Fonts families used by Folio',
      license: 'OFL-1.1 (typical)',
      copyright: 'Copyright (c) the respective font authors',
      description:
          'Families loaded via google_fonts: Outfit, Nunito, Inter, '
          'JetBrains Mono, Space Grotesk, DM Sans, Merriweather, Poppins, '
          'Lexend, Oswald, Orbitron. Confirm each family\'s license on '
          'fonts.google.com if redistributing font files.',
      sourceUrl: 'https://fonts.google.com',
      licenseText: CommonLicenseTexts.silOfl11,
      category: ThirdPartyLicenseCategory.fonts,
    ),

    // --- Assets / trademarks ---
    ThirdPartyLicenseEntry(
      id: 'assets-app-logos',
      name: 'Integration brand logos (assets/appLogos)',
      license: 'Trademark / brand asset',
      copyright: 'Respective trademark owners',
      description:
          'PNG logos for third-party services (Jira, YouTrack, Trello, '
          'GitHub, GitLab, Slack, Microsoft Teams, Spotify, YouTube Music). '
          'Not open-source software; trademarks remain with their owners.',
      sourceUrl: null,
      category: ThirdPartyLicenseCategory.assets,
    ),
  ];

  static List<ThirdPartyLicenseEntry> get uiEntries =>
      entries.where((e) => e.showInAboutUi).toList(growable: false);

  static List<ThirdPartyLicenseEntry> get noticesEntries =>
      entries.where((e) => e.includeInNoticesFile).toList(growable: false);

  static List<ThirdPartyLicenseEntry> byCategory(
    ThirdPartyLicenseCategory category,
  ) =>
      uiEntries.where((e) => e.category == category).toList(growable: false);

  static ThirdPartyLicenseEntry? findById(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}

ThirdPartyLicenseEntry _pkg({
  required String id,
  required String name,
  required String license,
  required String sourceUrl,
  String? copyright,
  String? description,
}) {
  return ThirdPartyLicenseEntry(
    id: id,
    name: name,
    license: license,
    copyright: copyright,
    description: description,
    sourceUrl: sourceUrl,
    category: ThirdPartyLicenseCategory.dartPackages,
  );
}

ThirdPartyLicenseEntry _backend({
  required String id,
  required String name,
  required String license,
  required String sourceUrl,
  String? copyright,
  String? description,
  String? licenseText,
}) {
  return ThirdPartyLicenseEntry(
    id: id,
    name: name,
    license: license,
    copyright: copyright,
    description: description,
    sourceUrl: sourceUrl,
    licenseText: licenseText,
    category: ThirdPartyLicenseCategory.backendPackages,
  );
}
