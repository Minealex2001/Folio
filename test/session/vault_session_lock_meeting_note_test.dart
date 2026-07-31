/// Regresión: `lock()` en una libreta cifrada llamaba a
/// `MeetingNoteSessionController.instance.cancelAndTeardown()` sin esperarlo
/// (`unawaited`) y sin guardar nada — si había una nota de reunión grabándose
/// en ese momento, la grabación completa (audio + transcript) se perdía en
/// silencio. El fix reemplaza esa llamada por
/// `saveActiveRecordingBeforeTeardown()`, ahora esperada por `lock()`.
///
/// Este test cubre el caso base (sin grabación activa): `lock()` debe seguir
/// completando con normalidad y sin colgarse cuando el controller de notas
/// de reunión está en `idle` — es decir, el nuevo `await` no introduce un
/// hang ni una excepción para el camino común.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
import 'package:folio/session/vault_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('VaultSession.lock() y notas de reunión', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_lock_meeting_note_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
      MeetingNoteSessionController.instance.debugResetForTest();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      MeetingNoteSessionController.instance.debugResetForTest();
      VaultPaths.clearActiveVaultId();
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test(
      'lock() completa sin colgarse cuando no hay grabación activa (idle)',
      () async {
        const vaultId = 'lock-meeting-note-vault';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);

        final session = VaultSession();
        session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
        session.addPage(parentId: null);

        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.idle,
        );

        await session
            .lock()
            .timeout(const Duration(seconds: 5));

        // El guardado best-effort no debe alterar el estado del controller
        // de notas de reunión cuando no había nada grabándose.
        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.idle,
        );
      },
    );
  });
}
