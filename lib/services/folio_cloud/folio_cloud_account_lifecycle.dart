import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../app_logger.dart';
import '../platform/browser_file_download.dart';
import 'folio_cloud_callable.dart';

/// Callables de borrado/exportación de cuenta Folio Cloud.
class FolioCloudAccountLifecycle {
  FolioCloudAccountLifecycle._();

  static Future<DateTime> requestAccountDeletion({bool debug = false}) async {
    final raw = await callFolioHttpsCallable('requestAccountDeletion', {
      if (debug) 'debug': true,
    });
    final map = _asMap(raw);
    final iso = map['scheduledFor']?.toString();
    final dt = iso == null ? null : DateTime.tryParse(iso);
    if (dt == null) {
      throw StateError('requestAccountDeletion: missing scheduledFor');
    }
    return dt.toLocal();
  }

  static Future<void> cancelAccountDeletion({bool debug = false}) async {
    await callFolioHttpsCallable('cancelAccountDeletion', {
      if (debug) 'debug': true,
    });
  }

  static Future<String> updateDisplayName(
    String displayName, {
    bool debug = false,
  }) async {
    final raw = await callFolioHttpsCallable('updateAccountDisplayName', {
      'displayName': displayName.trim(),
      if (debug) 'debug': true,
    });
    final map = _asMap(raw);
    final name = map['displayName']?.toString().trim();
    if (name == null || name.isEmpty) {
      throw StateError('updateAccountDisplayName: missing displayName');
    }
    return name;
  }

  /// Exporta metadatos de cuenta a un JSON.
  /// Devuelve la ruta (escritorio), el nombre de archivo (web) o `null` si cancela.
  static Future<String?> exportAccountDataAndSave({bool debug = false}) async {
    final raw = await callFolioHttpsCallable('exportAccountData', {
      if (debug) 'debug': true,
    });
    final map = _asMap(raw);
    final data = map['data'] ?? map;
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = 'folio-cloud-account-export-$stamp.json';
    final bytes = Uint8List.fromList(utf8.encode(encoded));

    if (kIsWeb) {
      folioTriggerBrowserDownload(fileName, bytes);
      AppLogger.info(
        'account export downloaded (web)',
        tag: 'account_lifecycle',
        context: {'bytes': bytes.length},
      );
      return fileName;
    }

    final path = await FilePicker.saveFile(
      dialogTitle: fileName,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;

    await File(path).writeAsString(encoded);
    AppLogger.info(
      'account export saved',
      tag: 'account_lifecycle',
      context: {'path': path, 'bytes': encoded.length},
    );
    return path;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry('$k', v));
    }
    throw StateError('Unexpected callable payload: ${raw.runtimeType}');
  }
}
