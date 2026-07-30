import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../../data/vault_paths.dart';
import '../../data/vault_payload.dart';
import 'vault_sync_merge.dart';

/// Formato wire compartido P2P / Cloud para snapshot lógico + adjuntos.
const String kVaultSyncPackFormat = 'folio.sync.pack.v1';

/// Umbral (bytes de adjuntos crudos, para encode; bytes de wire, para
/// decode) por encima del cual el trabajo se offloadea a un isolate. Por
/// debajo, el coste de spawnear el isolate supera lo que se ahorra.
const int _kSyncPackIsolateThresholdBytes = 256 * 1024;

/// Versión "plana" de [_encodeSyncPack], para correr dentro de un isolate:
/// solo recibe/devuelve tipos transferibles (String/num/bool/List/Map/bytes),
/// nunca instancias de [VaultPayload]/[VaultSyncPackAttachment].
List<int> _encodeSyncPackIsolate(Map<String, Object?> message) {
  final attachmentsRaw = message['attachments'] as List;
  final map = <String, Object?>{
    'format': kVaultSyncPackFormat,
    'payload': message['payload'],
    'attachments': [
      for (final raw in attachmentsRaw)
        {
          'path': (raw as Map)['path'],
          'sha256': raw['sha256'],
          'dataB64': base64Encode(raw['bytes'] as Uint8List),
        },
    ],
  };
  return utf8.encode(jsonEncode(map));
}

/// Versión "plana" de [VaultSyncPack.decodeFlexible] para isolate: devuelve
/// solo tipos transferibles; la reconstrucción a [VaultPayload]/
/// [VaultSyncPackAttachment] ocurre de vuelta en el isolate principal.
Map<String, Object?> _decodeSyncPackIsolate(Uint8List bytes) {
  final map = jsonDecode(utf8.decode(bytes));
  if (map is! Map) {
    throw const FormatException('Sync pack inválido');
  }
  if (map['format'] == kVaultSyncPackFormat) {
    final payloadRaw = map['payload'];
    if (payloadRaw is! Map) {
      throw const FormatException('Sync pack sin payload');
    }
    final attachments = <Map<String, Object?>>[];
    final rawAtt = map['attachments'];
    if (rawAtt is List) {
      for (final item in rawAtt) {
        if (item is! Map) continue;
        final path = '${item['path'] ?? ''}'.trim().replaceAll(r'\', '/');
        final sha = '${item['sha256'] ?? ''}'.trim().toLowerCase();
        final b64 = '${item['dataB64'] ?? ''}';
        if (path.isEmpty || b64.isEmpty) continue;
        if (!path.startsWith('${VaultPaths.attachmentsDirName}/')) continue;
        attachments.add({
          'path': path,
          'sha256': sha,
          'bytes': Uint8List.fromList(base64Decode(b64)),
        });
      }
    }
    return {
      'payload': Map<String, dynamic>.from(payloadRaw),
      'attachments': attachments,
    };
  }
  // Legado: VaultPayload plano.
  return {
    'payload': Map<String, dynamic>.from(map),
    'attachments': const <Map<String, Object?>>[],
  };
}

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

  /// Igual que [encodeUtf8], pero offloadea el `jsonEncode`+`base64Encode` a
  /// un isolate cuando los adjuntos son lo bastante grandes como para que
  /// merezca la pena (por debajo del umbral, corre inline: el spawn del
  /// isolate no compensa).
  Future<List<int>> encodeUtf8Async() async {
    final attachmentsBytes = attachments.fold<int>(
      0,
      (sum, a) => sum + a.bytes.length,
    );
    if (attachmentsBytes < _kSyncPackIsolateThresholdBytes) {
      return encodeUtf8();
    }
    final message = <String, Object?>{
      'payload': payload.toJson(),
      'attachments': [
        for (final a in attachments)
          {'path': a.path, 'sha256': a.sha256Hex, 'bytes': a.bytes},
      ],
    };
    return compute(_encodeSyncPackIsolate, message);
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

  /// Igual que [decodeFlexible], pero offloadea el `jsonDecode`+`base64Decode`
  /// a un isolate cuando el pack es lo bastante grande como para que merezca
  /// la pena (por debajo del umbral, corre inline).
  static Future<VaultSyncPack> decodeFlexibleAsync(List<int> bytes) async {
    if (bytes.length < _kSyncPackIsolateThresholdBytes) {
      return decodeFlexible(bytes);
    }
    final result = await compute(
      _decodeSyncPackIsolate,
      Uint8List.fromList(bytes),
    );
    final payload = VaultPayload.fromJson(
      Map<String, dynamic>.from(result['payload'] as Map),
    );
    final attachments = <VaultSyncPackAttachment>[
      for (final raw in result['attachments'] as List)
        VaultSyncPackAttachment(
          path: (raw as Map)['path'] as String,
          sha256Hex: raw['sha256'] as String,
          bytes: raw['bytes'] as Uint8List,
        ),
    ];
    return VaultSyncPack(payload: payload, attachments: attachments);
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
