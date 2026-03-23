import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Copia de la DEK para desbloqueo rápido (Hello / biometría / passkey), **por cofre** ([vaultId]).
///
/// Usa [SharedPreferences]: en escritorio el almacén suele ser legible para el
/// usuario del SO; para mayor seguridad en producción conviene volver a un
/// plugin con Keychain/Keystore/DPAPI bien integrado (p. ej. con toolchain
/// Windows que incluya ATL para `flutter_secure_storage`).
class QuickUnlockStorage {
  QuickUnlockStorage();

  static String _dekKey(String vaultId) =>
      'folio_quick_unlock_dek_b64_$vaultId';
  static String _enabledKey(String vaultId) =>
      'folio_quick_unlock_enabled_$vaultId';

  Future<bool> isEnabled(String vaultId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_enabledKey(vaultId)) == '1';
  }

  Future<void> enableWithDek(String vaultId, Uint8List dek) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_dekKey(vaultId), base64Encode(dek));
    await p.setString(_enabledKey(vaultId), '1');
  }

  Future<void> disable(String vaultId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_dekKey(vaultId));
    await p.setString(_enabledKey(vaultId), '0');
  }

  Future<Uint8List?> readDek(String vaultId) async {
    final p = await SharedPreferences.getInstance();
    final b64 = p.getString(_dekKey(vaultId));
    if (b64 == null || b64.isEmpty) return null;
    return Uint8List.fromList(base64Decode(b64));
  }
}
