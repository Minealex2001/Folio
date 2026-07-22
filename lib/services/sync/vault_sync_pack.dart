import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../data/vault_paths.dart';
import '../../data/vault_payload.dart';
import 'vault_sync_merge.dart';

/// Formato wire compartido P2P / Cloud para snapshot lógico + adjuntos.
const String kVaultSyncPackFormat = 'folio.sync.pack.v1';

class VaultSyncPackAttachment {
  const VaultSyncPackAttachment({
    required this.path,
    required this.sha256Hex,
    required this.bytes,
  });

  final String path;
  final String sha256Hex;
  final Uint8List bytes;
}

class VaultSyncPack {
  const VaultSyncPack({
    required this.payload,
    required this.attachments,
  });

  final VaultPayload payload;
  final List<VaultSyncPackAttachment> attachments;

  List<int> encodeUtf8() {
    final map = <String, Object?>{
      'format': kVaultSyncPackFormat,
      'payload': payload.toJson(),
      'attachments': [
        for (final a in attachments)
          {
            'path': a.path,
            'sha256': a.sha256Hex,
            'dataB64': base64Encode(a.bytes),
          },
      ],
    };
    return utf8.encode(jsonEncode(map));
  }

  static bool looksLikePack(List<int> bytes) {
    try {
      final map = jsonDecode(utf8.decode(bytes));
      return map is Map && map['format'] == kVaultSyncPackFormat;
    } catch (_) {
      return false;
    }
  }

  /// Decodifica pack v1 o un snapshot legado (solo [VaultPayload] JSON).
  static VaultSyncPack decodeFlexible(List<int> bytes) {
    final map = jsonDecode(utf8.decode(bytes));
    if (map is! Map) {
      throw FormatException('Sync pack inválido');
    }
    if (map['format'] == kVaultSyncPackFormat) {
      final payloadRaw = map['payload'];
      if (payloadRaw is! Map) {
        throw FormatException('Sync pack sin payload');
      }
      final payload = VaultPayload.fromJson(
        Map<String, dynamic>.from(payloadRaw),
      );
      final attachments = <VaultSyncPackAttachment>[];
      final rawAtt = map['attachments'];
      if (rawAtt is List) {
        for (final item in rawAtt) {
          if (item is! Map) continue;
          final path = '${item['path'] ?? ''}'.trim().replaceAll(r'\', '/');
          final sha = '${item['sha256'] ?? ''}'.trim().toLowerCase();
          final b64 = '${item['dataB64'] ?? ''}';
          if (path.isEmpty || b64.isEmpty) continue;
          if (!path.startsWith('${VaultPaths.attachmentsDirName}/')) continue;
          final bytes = base64Decode(b64);
          attachments.add(
            VaultSyncPackAttachment(
              path: path,
              sha256Hex: sha.isEmpty ? '' : sha,
              bytes: Uint8List.fromList(bytes),
            ),
          );
        }
      }
      return VaultSyncPack(payload: payload, attachments: attachments);
    }
    // Legado: VaultPayload plano.
    return VaultSyncPack(
      payload: VaultPayload.fromJson(Map<String, dynamic>.from(map)),
      attachments: const [],
    );
  }
}

/// Construye un pack desde el payload en memoria + adjuntos en disco de la libreta.
Future<VaultSyncPack> buildVaultSyncPackFromDisk({
  required VaultPayload payload,
}) async {
  final paths = VaultSyncMergeEngine.collectAttachmentPaths(payload);
  final attachments = <VaultSyncPackAttachment>[];
  final vaultDir = await VaultPaths.vaultDirectory();
  final sha = Sha256();
  for (final rel in paths) {
    final file = File(p.join(vaultDir.path, rel));
    if (!file.existsSync()) continue;
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final hash = await sha.hash(bytes);
    final hex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    attachments.add(
      VaultSyncPackAttachment(path: rel, sha256Hex: hex, bytes: bytes),
    );
  }
  return VaultSyncPack(payload: payload, attachments: attachments);
}

/// Escribe adjuntos del pack en la libreta abierta (no sobrescribe si el SHA coincide).
Future<void> materializeVaultSyncPackAttachments(VaultSyncPack pack) async {
  if (pack.attachments.isEmpty) return;
  final vaultDir = await VaultPaths.vaultDirectory();
  final sha = Sha256();
  for (final att in pack.attachments) {
    final path = att.path.replaceAll(r'\', '/');
    if (!path.startsWith('${VaultPaths.attachmentsDirName}/')) continue;
    final file = File(p.join(vaultDir.path, path));
    if (file.existsSync() && att.sha256Hex.isNotEmpty) {
      final existing = await file.readAsBytes();
      final hash = await sha.hash(existing);
      final hex = hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (hex == att.sha256Hex) continue;
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(att.bytes, flush: true);
  }
}
