import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultPaths {
  VaultPaths._();

  static const String vaultDirName = 'folio_vault';
  static const String wrappedDekFile = 'vault.keys';
  static const String cipherPayloadFile = 'vault.bin';
  static const String rpStateFile = 'webauthn_rp.json';

  static Future<Directory> vaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, vaultDirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> wrappedDekPath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, wrappedDekFile));
  }

  static Future<File> cipherPayloadPath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, cipherPayloadFile));
  }

  static Future<File> rpStatePath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, rpStateFile));
  }

  static Future<bool> vaultExists() async {
    final f = await wrappedDekPath();
    return f.existsSync();
  }
}
