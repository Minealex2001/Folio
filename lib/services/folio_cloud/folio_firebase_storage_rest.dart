import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Workaround para subir/descargar en Firebase Storage en plataformas donde el
/// plugin nativo envía eventos `taskEvent` desde un hilo de fondo (Windows y
/// Linux). El motor de Flutter en escritorio exige que los mensajes de canal
/// lleguen en el hilo de plataforma; de lo contrario registra error y en
/// release puede terminar el proceso.
///
/// Usamos la [API REST de Firebase Storage] con el ID token de Auth como
/// Bearer, igual que [folio_firestore_rest.dart] para Firestore.
///
/// [API REST de Firebase Storage]: https://firebase.google.com/docs/storage/web/download-files#download_data_via_rest
bool get folioStorageUseRestTransport {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class FolioFirebaseStorageRestException implements Exception {
  FolioFirebaseStorageRestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() =>
      'FolioFirebaseStorageRestException(status=$statusCode, body=$body)';
}

Future<String> _idTokenWithRetry() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Not signed in');
  }
  for (var attempt = 0; attempt < 2; attempt++) {
    final token = await user.getIdToken(attempt > 0);
    if (token != null && token.isNotEmpty) return token;
  }
  throw StateError('Firebase ID token unavailable');
}

String _encodeObjectName(String objectPath) {
  return Uri.encodeComponent(objectPath);
}

Uri _objectMediaUri(String bucket, String objectPath) {
  final encoded = _encodeObjectName(objectPath);
  return Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media',
  );
}

Uri _objectUploadUri(String bucket, String objectPath, {bool resumable = false}) {
  final encoded = _encodeObjectName(objectPath);
  final uploadType = resumable ? 'resumable' : 'media';
  return Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
    '?name=$encoded&uploadType=$uploadType',
  );
}

Map<String, String> _authHeaders(String idToken, {String? contentType}) {
  return <String, String>{
    'Authorization': 'Bearer $idToken',
    if (contentType != null && contentType.isNotEmpty)
      'Content-Type': contentType,
  };
}

void _ensureSuccess(http.BaseResponse response, {String? body}) {
  final code = response.statusCode;
  if (code >= 200 && code < 300) return;
  throw FolioFirebaseStorageRestException(code, body ?? '');
}

/// Sube bytes con `uploadType=media` (objetos pequeños/medianos).
Future<void> folioFirebaseStorageRestPutData(
  Reference ref,
  Uint8List data, {
  SettableMetadata? metadata,
}) async {
  final idToken = await _idTokenWithRetry();
  final contentType =
      metadata?.contentType?.trim() ?? 'application/octet-stream';
  final uri = _objectUploadUri(ref.bucket, ref.fullPath);
  http.Response res;
  try {
    res = await http
        .post(
          uri,
          headers: _authHeaders(idToken, contentType: contentType),
          body: data,
        )
        .timeout(const Duration(minutes: 10));
  } on TimeoutException {
    rethrow;
  }
  _ensureSuccess(res, body: res.body);
}

/// Sube un archivo con sesión resumible (copias grandes sin `taskEvent`).
Future<void> folioFirebaseStorageRestPutFile(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  if (!await file.exists()) {
    throw StateError('File does not exist: ${file.path}');
  }
  final length = await file.length();
  if (length <= 0) {
    throw StateError('File is empty: ${file.path}');
  }

  final idToken = await _idTokenWithRetry();
  final contentType =
      metadata?.contentType?.trim() ?? 'application/octet-stream';
  final startUri = _objectUploadUri(ref.bucket, ref.fullPath, resumable: true);

  final metadataBody = <String, dynamic>{'contentType': contentType};
  final customMetadata = metadata?.customMetadata;
  if (customMetadata != null && customMetadata.isNotEmpty) {
    metadataBody['metadata'] = customMetadata;
  }

  final startRes = await http
      .post(
        startUri,
        headers: <String, String>{
          ..._authHeaders(idToken, contentType: 'application/json; charset=utf-8'),
          'X-Goog-Upload-Protocol': 'resumable',
          'X-Goog-Upload-Command': 'start',
        },
        body: jsonEncode(metadataBody),
      )
      .timeout(const Duration(minutes: 2));

  _ensureSuccess(startRes, body: startRes.body);
  final uploadUrl = startRes.headers['x-goog-upload-url'];
  if (uploadUrl == null || uploadUrl.isEmpty) {
    throw StateError('Resumable upload session missing x-goog-upload-url');
  }

  final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
  request.headers.addAll(<String, String>{
    'Authorization': 'Bearer $idToken',
    'Content-Length': '$length',
    'X-Goog-Upload-Command': 'upload, finalize',
    'X-Goog-Upload-Offset': '0',
  });
  request.sink.addStream(file.openRead());
  await request.sink.close();

  final client = http.Client();
  try {
    final uploadRes = await client
        .send(request)
        .timeout(const Duration(minutes: 30));
    final body = await uploadRes.stream.bytesToString();
    _ensureSuccess(uploadRes, body: body);
  } on TimeoutException {
    rethrow;
  } finally {
    client.close();
  }
}

/// Descarga bytes sin `writeToFile` / `taskEvent`.
Future<Uint8List> folioFirebaseStorageRestGetData(
  Reference ref,
  int maxBytes, {
  Duration timeout = const Duration(minutes: 10),
}) async {
  final idToken = await _idTokenWithRetry();
  final uri = _objectMediaUri(ref.bucket, ref.fullPath);
  final res = await http
      .get(uri, headers: _authHeaders(idToken))
      .timeout(timeout);
  _ensureSuccess(res, body: res.body);
  final data = res.bodyBytes;
  if (data.length > maxBytes) {
    throw StateError(
      'Downloaded object exceeds maxBytes ($maxBytes): ${data.length}',
    );
  }
  if (data.isEmpty) {
    throw StateError('Downloaded object is empty');
  }
  return data;
}

/// Descarga a disco por REST (evita `Reference.writeToFile` en escritorio).
Future<void> folioFirebaseStorageRestWriteToFile(
  Reference ref,
  File destination, {
  Duration timeout = const Duration(minutes: 30),
}) async {
  final data = await folioFirebaseStorageRestGetData(
    ref,
    512 * 1024 * 1024,
    timeout: timeout,
  );
  await destination.parent.create(recursive: true);
  await destination.writeAsBytes(data, flush: true);
}
