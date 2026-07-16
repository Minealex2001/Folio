import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/backup_destinations/backup_destination.dart';
import 'package:folio/services/backup_destinations/smb_network_auth.dart';

void main() {
  group('SmbNetworkAuth', () {
    test('detecta rutas UNC', () {
      expect(SmbNetworkAuth.isUncPath(r'\\nas\share\folio'), isTrue);
      expect(SmbNetworkAuth.isUncPath('//nas/share/folio'), isTrue);
      expect(SmbNetworkAuth.isUncPath(r'C:\backups'), isFalse);
    });

    test('extrae raíz de recurso compartido', () {
      expect(
        SmbNetworkAuth.uncShareRoot(r'\\192.168.1.10\backups\folio'),
        r'\\192.168.1.10\backups',
      );
      expect(SmbNetworkAuth.uncShareRoot(r'C:\local'), isNull);
    });
  });

  group('isFolioBackupZipName', () {
    test('acepta nombres de copia Folio', () {
      expect(
        isFolioBackupZipName('folio-scheduled-2026-01-01T00-00-00Z.zip'),
        isTrue,
      );
      expect(isFolioBackupZipName('folio-backup-test.zip'), isTrue);
      expect(isFolioBackupZipName('other.zip'), isFalse);
    });
  });

  group('scheduledVaultBackupFileName', () {
    test('genera nombre con prefijo programado', () {
      final name = scheduledVaultBackupFileName(
        at: DateTime.utc(2026, 1, 1, 12, 30, 45),
      );
      expect(name, startsWith('folio-scheduled-'));
      expect(name, endsWith('.zip'));
      expect(name, isNot(contains(':')));
    });
  });
}
