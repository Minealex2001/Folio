import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../../firebase_options.dart';
import 'folio_cloud_identity.dart';
import 'folio_spring_account_me.dart';

/// Workaround para leer Cloud Firestore en plataformas donde el SDK nativo no
/// es fiable (Windows: el plugin C++ crashea al inicializarse). En vez del SDK
/// usamos la [API REST de Firestore] con el ID token de Firebase Auth (que sí
/// funciona en escritorio) como Bearer, igual que hacemos con las Cloud
/// Functions vía protocolo HTTP callable.
///
/// Solo lecturas puntuales (`get`); no reemplaza streams en tiempo real, que se
/// aproximan con sondeo en el llamador.
///
/// [API REST de Firestore]: https://firebase.google.com/docs/firestore/use-rest-api
class FolioFirestoreRestException implements Exception {
  FolioFirestoreRestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() =>
      'FolioFirestoreRestException(status=$statusCode, body=$body)';
}

/// GET de un documento (`users/{uid}`, etc.) por REST. Devuelve el documento
/// decodificado a un `Map` plano (compatible con los `fromJson` de la app), un
/// mapa vacío si el documento no existe (404), o `null` si no se puede resolver
/// (sin sesión, en web, o token no disponible).
///
/// [documentPath] es la ruta relativa al documento, p. ej. `users/abc123`.
Future<Map<String, dynamic>?> folioFirestoreRestGetDocument(
  String documentPath, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  // En modo Spring, `users/{uid}` se lee vía `/account/me` (no Firestore REST).
  if (FolioBackendConfig.useSpring) {
    final parts = documentPath.split('/');
    if (parts.length == 2 && parts[0] == 'users') {
      return folioSpringFetchAccountMeAsUserDoc(timeout: timeout);
    }
    return null;
  }
  // En web el SDK nativo de Firestore funciona; este workaround es para desktop.
  if (kIsWeb) return null;
  if (Firebase.apps.isEmpty) return null;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/'
    '(default)/documents/$documentPath',
  );

  // 401: token caducado/rechazado; un segundo intento con refresh forzado lo
  // suele resolver (mismo criterio que las Cloud Functions por HTTP).
  for (var attempt = 0; attempt < 2; attempt++) {
    final idToken = await folioCloudBearerToken(forceRefresh: attempt > 0);
    if (idToken == null || idToken.isEmpty) return null;

    final http.Response res;
    try {
      res = await http
          .get(uri, headers: {'Authorization': 'Bearer $idToken'})
          .timeout(timeout);
    } on TimeoutException {
      rethrow;
    }

    // Documento inexistente: para la app equivale a "sin datos".
    if (res.statusCode == 404) return <String, dynamic>{};
    if (res.statusCode == 401 && attempt == 0) continue;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw FolioFirestoreRestException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return <String, dynamic>{};
    final fields = decoded['fields'];
    if (fields is! Map) return <String, dynamic>{};
    return _decodeFirestoreFields(fields);
  }
  return null;
}

/// Lista documentos de una colección por REST (sin SDK nativo).
///
/// [collectionPath] p. ej. `users/{uid}/pendingIntegrationCommands`.
/// Devuelve pares `(documentId, fields)` decodificados.
Future<List<({String id, Map<String, dynamic> data})>>
    folioFirestoreRestListDocuments(
  String collectionPath, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (FolioBackendConfig.useSpring) {
    // Listados Firestore REST no tienen equivalente genérico en Spring aún.
    return const [];
  }
  if (kIsWeb) return const [];
  if (Firebase.apps.isEmpty) return const [];
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const [];

  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/'
    '(default)/documents/$collectionPath',
  );

  for (var attempt = 0; attempt < 2; attempt++) {
    final idToken = await folioCloudBearerToken(forceRefresh: attempt > 0);
    if (idToken == null || idToken.isEmpty) return const [];

    final http.Response res;
    try {
      res = await http
          .get(uri, headers: {'Authorization': 'Bearer $idToken'})
          .timeout(timeout);
    } on TimeoutException {
      rethrow;
    }

    if (res.statusCode == 404) return const [];
    if (res.statusCode == 401 && attempt == 0) continue;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw FolioFirestoreRestException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return const [];
    final docs = decoded['documents'];
    if (docs is! List) return const [];

    final out = <({String id, Map<String, dynamic> data})>[];
    for (final doc in docs) {
      if (doc is! Map) continue;
      final name = doc['name']?.toString() ?? '';
      final id = name.contains('/') ? name.split('/').last : name;
      if (id.isEmpty) continue;
      final fields = doc['fields'];
      if (fields is! Map) continue;
      out.add((id: id, data: _decodeFirestoreFields(fields)));
    }
    return out;
  }
  return const [];
}

/// Atajo para `users/{uid}` (derechos Folio Cloud, tinta, copias).
Future<Map<String, dynamic>?> folioFirestoreRestGetUserDoc(String uid) {
  return folioFirestoreRestGetDocument('users/$uid');
}

/// Convierte el mapa `fields` del formato REST de Firestore a un `Map` plano.
Map<String, dynamic> _decodeFirestoreFields(Map fields) {
  final out = <String, dynamic>{};
  for (final entry in fields.entries) {
    out['${entry.key}'] = _decodeFirestoreValue(entry.value);
  }
  return out;
}

/// Decodifica un `Value` del formato REST de Firestore a su valor Dart nativo.
dynamic _decodeFirestoreValue(Object? value) {
  if (value is! Map) return null;
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('booleanValue')) return value['booleanValue'] == true;
  if (value.containsKey('integerValue')) {
    // Firestore serializa enteros como String en JSON.
    final raw = value['integerValue'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }
  if (value.containsKey('doubleValue')) {
    final raw = value['doubleValue'];
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw');
  }
  if (value.containsKey('stringValue')) {
    return value['stringValue']?.toString();
  }
  if (value.containsKey('timestampValue')) {
    return value['timestampValue']?.toString();
  }
  if (value.containsKey('bytesValue')) {
    return value['bytesValue']?.toString();
  }
  if (value.containsKey('referenceValue')) {
    return value['referenceValue']?.toString();
  }
  if (value.containsKey('geoPointValue')) {
    final gp = value['geoPointValue'];
    if (gp is Map) {
      return <String, dynamic>{
        'latitude': gp['latitude'],
        'longitude': gp['longitude'],
      };
    }
    return null;
  }
  if (value.containsKey('arrayValue')) {
    final arr = value['arrayValue'];
    final values = arr is Map ? arr['values'] : null;
    if (values is List) {
      return values.map(_decodeFirestoreValue).toList();
    }
    return <dynamic>[];
  }
  if (value.containsKey('mapValue')) {
    final mv = value['mapValue'];
    final nested = mv is Map ? mv['fields'] : null;
    if (nested is Map) return _decodeFirestoreFields(nested);
    return <String, dynamic>{};
  }
  return null;
}
