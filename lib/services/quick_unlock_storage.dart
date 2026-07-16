import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Copia de la DEK para desbloqueo rápido (Hello / biometría / passkey), **por libreta** ([vaultId]).
///
/// La DEK se guarda en el almacén seguro del SO (Keychain / Keystore / DPAPI)
/// vía `flutter_secure_storage`. El flag de habilitado (no sensible) vive en
/// [SharedPreferences]. Las DEK que quedaran de versiones anteriores en
/// SharedPreferences se migran automáticamente al almacén seguro en la primera
/// lectura.
class QuickUnlockStorage {
  QuickUnlockStorage({FlutterSecureStorage? storage})
    : _secure =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _secure;

  static String _dekKey(String vaultId) =>
      'folio_quick_unlock_dek_b64_$vaultId';
  static String _enabledKey(String vaultId) =>
      'folio_quick_unlock_enabled_$vaultId';

  Future<bool> isEnabled(String vaultId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_enabledKey(vaultId)) == '1';
  }

  Future<void> enableWithDek(String vaultId, Uint8List dek) async {
    await _secure.write(key: _dekKey(vaultId), value: base64Encode(dek));
    final p = await SharedPreferences.getInstance();
    // Limpia cualquier copia legacy en texto claro.
    await p.remove(_dekKey(vaultId));
    await p.setString(_enabledKey(vaultId), '1');
  }

  Future<void> disable(String vaultId) async {
    try {
      await _secure.delete(key: _dekKey(vaultId));
    } catch (_) {
      // Best-effort: seguimos limpiando el resto aunque falle el plugin.
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_dekKey(vaultId));
    await p.setString(_enabledKey(vaultId), '0');
  }

  Future<Uint8List?> readDek(String vaultId) async {
    String? b64;
    try {
      b64 = await _secure.read(key: _dekKey(vaultId));
    } catch (_) {
      b64 = null;
    }
    if (b64 == null || b64.isEmpty) {
      // Migración desde SharedPreferences (versiones anteriores).
      final p = await SharedPreferences.getInstance();
      final legacy = p.getString(_dekKey(vaultId));
      if (legacy == null || legacy.isEmpty) return null;
      b64 = legacy;
      try {
        await _secure.write(key: _dekKey(vaultId), value: legacy);
        await p.remove(_dekKey(vaultId));
      } catch (_) {
        // Si el almacén seguro no está disponible, mantenemos el valor legacy
        // para no bloquear el desbloqueo; se reintentará en la próxima lectura.
      }
    }
    try {
      return Uint8List.fromList(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }
}
