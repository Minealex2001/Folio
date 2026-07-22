import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/data/folio_settings_profile_format.dart';
import 'package:folio/services/settings/settings_profile_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('FolioSettingsProfile round-trip preserves kind and icons', () {
    final profile = FolioSettingsProfile(
      kind: FolioSettingsProfileKind.app,
      settings: <String, Object?>{
        'themeMode': 'dark',
      },
      secrets: <String, String>{'aiApiKey': 'sk-test'},
      icons: const [
        FolioSettingsIconRef(
          id: 'icon-1',
          label: 'Star',
          source: 'file',
          mimeType: 'image/png',
          createdAtMs: 123,
        ),
      ],
      exportedAtMs: 42,
    );

    final decoded = FolioSettingsProfile.decodeUtf8(profile.encodeUtf8());
    expect(decoded.kind, FolioSettingsProfileKind.app);
    expect(decoded.settings['themeMode'], 'dark');
    expect(decoded.secrets['aiApiKey'], 'sk-test');
    expect(decoded.icons, hasLength(1));
    expect(decoded.icons.first.id, 'icon-1');
    expect(decoded.icons.first.mimeType, 'image/png');
  });

  test('buildAppProfile excludes device-local sync runtime fields', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.setThemeMode(ThemeMode.dark);

    final profile = const SettingsProfileBuilder().buildAppProfile(settings);
    expect(profile.kind, FolioSettingsProfileKind.app);
    expect(profile.settings.containsKey('syncDeviceId'), isFalse);
    expect(profile.settings.containsKey('syncLastSuccessMs'), isFalse);
    expect(profile.settings.containsKey('syncPendingConflicts'), isFalse);
    expect(
      profile.settings.containsKey('lockScreenAutoQuickUnlockDone'),
      isFalse,
    );
    expect(profile.settings['themeMode'], 'dark');
    expect(profile.settings.containsKey('cloudAppProfileSyncEnabled'), isTrue);
    // Device id exists locally but must not be exported.
    expect(settings.syncDeviceId, isNotEmpty);
  });
}
