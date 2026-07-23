/// Regresión: BackupExportRunner.exportToDestinations no debe exportar una
/// libreta vacía sobre un destino que ya tiene backups. A diferencia de los
/// packs incrementales, este export no dedupe por fingerprint, así que un
/// ZIP vacío subido aquí terminaría expulsando la última copia buena tras
/// suficientes ciclos de `pruneOld`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/app/app_settings.dart';
import 'package:folio/data/vault_backup.dart';
import 'package:folio/services/backup_destinations/backup_destination.dart';
import 'package:folio/services/backup_destinations/backup_export_runner.dart';
import 'package:folio/session/vault_session.dart';

class _FakeDestination implements BackupDestination {
  _FakeDestination({required this.existingBackups});

  final List<RemoteBackupEntry> existingBackups;
  bool uploadCalled = false;

  @override
  String get label => 'fake';

  @override
  Future<void> ping() async {}

  @override
  Future<void> uploadZip(File zipFile, String fileName) async {
    uploadCalled = true;
  }

  @override
  Future<List<RemoteBackupEntry>> listZipBackups() async => existingBackups;

  @override
  Future<void> download(String fileName, File dest) async {}

  @override
  Future<void> pruneOld(int keepN) async {}
}

void main() {
  group('BackupExportRunner empty-vault guard', () {
    test(
      'refuses to export an empty vault over a destination with existing backups',
      () async {
        final session = VaultSession();
        session.debugMarkUnlockedForTests();
        expect(session.pages, isEmpty);

        final dest = _FakeDestination(
          existingBackups: const [RemoteBackupEntry(name: 'folio-backup-old.zip')],
        );
        final runner = BackupExportRunner();

        await expectLater(
          runner.exportToDestinations(
            session: session,
            prefs: const VaultBackupPrefs(),
            vaultId: 'test-vault',
            onlyDestinations: [dest],
          ),
          throwsA(isA<VaultBackupException>()),
        );
        expect(dest.uploadCalled, isFalse);
      },
    );

    test(
      'allows exporting an empty vault when the destination has no prior backups',
      () async {
        final session = VaultSession();
        session.debugMarkUnlockedForTests();

        final dest = _FakeDestination(existingBackups: const []);
        // No se llega a crear el ZIP real (requiere una libreta completa),
        // así que solo verificamos que el guard no bloquea este caso: el
        // primer chequeo (destinos con backups previos) no se dispara.
        var guardTriggered = false;
        try {
          await BackupExportRunner().exportToDestinations(
            session: session,
            prefs: const VaultBackupPrefs(),
            vaultId: 'test-vault',
            onlyDestinations: [dest],
          );
        } on VaultBackupException catch (e) {
          guardTriggered = e.toString().contains('vacía');
        } catch (_) {
          // Falla más adelante en la creación real del ZIP; no es lo que
          // este test valida.
        }
        expect(guardTriggered, isFalse);
        expect(dest.uploadCalled, isFalse); // no llega tan lejos en este test
      },
    );
  });
}
