import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Copia de la DEK para desbloqueo rápido (Hello / biometría / passkey).
///
/// Usa [SharedPreferences]: en escritorio el almacén suele ser legible para el
/// usuario del SO; para mayor seguridad en producción conviene volver a un
/// plugin con Keychain/Keystore/DPAPI bien integrado (p. ej. con toolchain
/// Windows que incluya ATL para `flutter_secure_storage`).
class QuickUnlockStorage {
  QuickUnlockStorage();

  static const _dekKey = 'folio_quick_unlock_dek_b64';
  static const _enabledKey = 'folio_quick_unlock_enabled';

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_enabledKey) == '1';
  }

  Future<void> enableWithDek(Uint8List dek) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_dekKey, base64Encode(dek));
    await p.setString(_enabledKey, '1');
  }

  Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_dekKey);
    await p.setString(_enabledKey, '0');
  }

  Future<Uint8List?> readDek() async {
    final p = await SharedPreferences.getInstance();
    final b64 = p.getString(_dekKey);
    if (b64 == null || b64.isEmpty) return null;
    return Uint8List.fromList(base64Decode(b64));
  }
}
