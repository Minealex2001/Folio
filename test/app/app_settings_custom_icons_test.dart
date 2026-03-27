import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';

void main() {
  test('persists custom icons across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();

    const entry = CustomIconEntry(
      id: 'icon-1',
      label: 'Wave',
      source: 'data:image/svg+xml,%3Csvg%3E%3C/svg%3E',
      filePath: r'C:\icons\wave.svg',
      mimeType: 'image/svg+xml',
      createdAtMs: 42,
    );

    await settings.addOrUpdateCustomIcon(entry);

    final reloaded = AppSettings();
    await reloaded.load();

    expect(reloaded.customIcons, hasLength(1));
    expect(reloaded.customIcons.single.id, 'icon-1');
    expect(reloaded.customIcons.single.token, 'custom_icon:icon-1');
    expect(reloaded.customIconForToken('custom_icon:icon-1')?.label, 'Wave');
  });

  test('preserves animated custom icon mime types across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();

    const entry = CustomIconEntry(
      id: 'party',
      label: 'Party',
      source: 'https://example.com/party.gif',
      filePath: r'C:\icons\party.gif',
      mimeType: 'image/gif',
      createdAtMs: 77,
    );

    await settings.addOrUpdateCustomIcon(entry);

    final reloaded = AppSettings();
    await reloaded.load();

    expect(reloaded.customIconForToken('custom_icon:party')?.mimeType, 'image/gif');
  });

  test('persists integration custom icons isolated by appId', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();

    const entryA = CustomIconEntry(
      id: 'rocket',
      label: 'Rocket',
      source: 'data:image/svg+xml,%3Csvg%3E%3C/svg%3E',
      filePath: r'C:\icons\rocket.svg',
      mimeType: 'image/svg+xml',
      createdAtMs: 100,
    );
    const entryB = CustomIconEntry(
      id: 'star',
      label: 'Star',
      source: 'data:image/svg+xml,%3Csvg%3E%3C/svg%3E',
      filePath: r'C:\icons\star.svg',
      mimeType: 'image/svg+xml',
      createdAtMs: 200,
    );

    await settings.addOrUpdateIntegrationCustomIconForApp('app-a', entryA);
    await settings.addOrUpdateIntegrationCustomIconForApp('app-b', entryB);

    final reloaded = AppSettings();
    await reloaded.load();

    expect(reloaded.integrationCustomIconsForApp('app-a'), hasLength(1));
    expect(reloaded.integrationCustomIconsForApp('app-a').single.id, 'rocket');
    expect(reloaded.integrationCustomIconsForApp('app-b'), hasLength(1));
    expect(reloaded.integrationCustomIconsForApp('app-b').single.id, 'star');
    expect(reloaded.integrationCustomIconsForApp('app-c'), isEmpty);
  });
}
