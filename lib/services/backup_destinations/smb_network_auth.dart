import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/vault_backup.dart';

/// Autenticación SMB/UNC para rutas de red en Windows.
class SmbNetworkAuth {
  SmbNetworkAuth({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('folio/smb_network');

  final MethodChannel _channel;

  static bool isUncPath(String path) {
    final p = path.trim();
    return p.startsWith(r'\\') || p.startsWith('//');
  }

  /// Raíz del recurso compartido (`\\server\share`) para una ruta UNC.
  static String? uncShareRoot(String path) {
    final normalized = path.trim().replaceAll('/', r'\');
    if (!normalized.startsWith(r'\\')) return null;
    final withoutPrefix = normalized.substring(2);
    final parts = withoutPrefix.split(r'\');
    if (parts.length < 2) return null;
    final server = parts[0].trim();
    final share = parts[1].trim();
    if (server.isEmpty || share.isEmpty) return null;
    return '\\\\$server\\$share';
  }

  bool credentialsNeeded({
    required String path,
    required bool folderRequiresAuth,
    String? username,
    String? password,
  }) {
    if (!isUncPath(path)) return false;
    if (folderRequiresAuth) return true;
    final u = (username ?? '').trim();
    final p = (password ?? '').trim();
    return u.isNotEmpty || p.isNotEmpty;
  }

  Future<void> withConnection({
    required String path,
    bool folderRequiresAuth = false,
    String? username,
    String? password,
    String? domain,
    required Future<void> Function() action,
  }) async {
    final shareRoot = uncShareRoot(path);
    final u = (username ?? '').trim();
    final p = password ?? '';

    if (shareRoot == null || !isUncPath(path)) {
      await action();
      return;
    }

    if (!credentialsNeeded(
      path: path,
      folderRequiresAuth: folderRequiresAuth,
      username: username,
      password: password,
    )) {
      await action();
      return;
    }

    if (!Platform.isWindows) {
      throw VaultBackupException(
        'En este sistema monta el recurso de red manualmente o usa WebDAV.',
      );
    }

    if (u.isEmpty) {
      throw VaultBackupException(
        'Se requiere usuario para acceder al recurso de red.',
      );
    }

    var connected = false;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'connectShare',
        <String, Object?>{
          'shareRoot': shareRoot,
          'username': u,
          'password': p,
          'domain': (domain ?? '').trim(),
        },
      );
      final ok = result?['success'] == true;
      if (!ok) {
        final code = result?['errorCode'];
        final message = (result?['message'] ?? '').toString().trim();
        throw VaultBackupException(
          message.isNotEmpty
              ? message
              : 'No se pudo conectar al recurso de red (código $code).',
        );
      }
      connected = true;
      await action();
    } on PlatformException catch (e) {
      debugPrint('SmbNetworkAuth: $e');
      throw VaultBackupException(
        e.message ?? 'Error al conectar con el recurso de red.',
      );
    } finally {
      if (connected) {
        try {
          await _channel.invokeMethod<void>(
            'disconnectShare',
            <String, Object?>{'shareRoot': shareRoot},
          );
        } catch (e) {
          debugPrint('SmbNetworkAuth disconnect: $e');
        }
      }
    }
  }
}
