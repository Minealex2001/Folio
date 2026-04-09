import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../../firebase_options.dart';
import 'folio_cloud_callable_post.dart'
    if (dart.library.html) 'folio_cloud_callable_post_stub.dart'
    as callable_post;

/// Región de despliegue de Cloud Functions (debe coincidir con `firebase deploy`).
const String kFolioCloudFunctionsRegion = 'us-central1';

/// `cloud_functions` no registra implementación nativa en Windows (ni en Linux en
/// muchos builds); el SDK usa un canal Pigeon que no existe y falla en runtime.
/// En esas plataformas usamos el [protocolo HTTP callable] de Firebase.
///
/// [protocolo HTTP callable]: https://firebase.google.com/docs/functions/callable-reference
bool get folioHttpsCallableUsesHttp {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

String _trimLeadingBom(String s) {
  var t = s.trimLeft();
  if (t.isNotEmpty && t.codeUnitAt(0) == 0xfeff) {
    t = t.substring(1);
  }
  return t.trimLeft();
}

String _previewForCallableFailure(String body) {
  final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'Cuerpo vacío.';
  const max = 200;
  return collapsed.length <= max
      ? collapsed
      : '${collapsed.substring(0, max)}…';
}

FirebaseFunctions get _folioFunctions => FirebaseFunctions.instanceFor(
  app: Firebase.app(),
  region: kFolioCloudFunctionsRegion,
);

/// Equivalente a [HttpsCallable.call] (devuelve el payload `result` del protocolo).
Future<dynamic> callFolioHttpsCallable(
  String name, [
  Object? parameters,
]) async {
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (folioHttpsCallableUsesHttp) {
    return _callFolioHttpsViaHttp(name, parameters);
  }
  final callable = _folioFunctions.httpsCallable(name);
  final res = await callable.call(parameters);
  return res.data;
}

Future<dynamic> _callFolioHttpsViaHttp(String name, Object? parameters) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseFunctionsException(
      message: 'Must be signed in to call Cloud Functions',
      code: 'unauthenticated',
    );
  }

  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
  final uri = Uri.parse(
    'https://$kFolioCloudFunctionsRegion-$projectId.cloudfunctions.net/$name',
  );

  Object? dataPayload;
  if (parameters == null) {
    dataPayload = null;
  } else if (parameters is Map) {
    dataPayload = Map<String, dynamic>.from(parameters);
  } else {
    dataPayload = parameters;
  }

  /// 401 / UNAUTHENTICATED: token caducado o rechazado; un segundo intento con
  /// [User.getIdToken] forzado suele resolverlo en escritorio.
  for (var attempt = 0; attempt < 2; attempt++) {
    final forceRefresh = attempt > 0;
    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseFunctionsException(
        message:
            'No ID token for Cloud Functions. Sign in to Folio Cloud again.',
        code: 'unauthenticated',
      );
    }

    final resp = await callable_post.folioCallableHttpPost(
      uri: uri,
      body: jsonEncode(<String, dynamic>{'data': dataPayload}),
      bearerToken: idToken,
    );

    final jsonText = _trimLeadingBom(resp.body);
    final contentType = (resp.headers['content-type'] ?? '').toLowerCase();

    final looksLikeHtml =
        contentType.contains('html') || jsonText.trimLeft().startsWith('<');

    /// 401 + HTML típico de Google (p. ej. IAM de Cloud Run). Mensaje al usuario
    /// centrado en suscripción Folio Cloud; causa técnica en docs del repo.
    final googleCloudRunIam401 =
        resp.statusCode == 401 &&
        looksLikeHtml &&
        (jsonText.contains('Unauthorized') || jsonText.contains('Error 401'));
    if (googleCloudRunIam401) {
      if (name == 'folioCloudAiComplete') {
        try {
          return await _callFolioCloudAiHttpFallback(
            baseCallableUri: uri,
            dataPayload: dataPayload,
            user: user,
          );
        } on FirebaseFunctionsException catch (_) {
          // Si el fallback falla, cae al mensaje guiado existente para soporte.
        }
      }
      throw FirebaseFunctionsException(
        message:
            'No se pudo usar Folio Cloud: el servicio en la nube rechazó la '
            'conexión (401). Folio Cloud solo está disponible con suscripción '
            'activa e inicio de sesión en tu cuenta en Ajustes. Comprueba plan, '
            'tinta e «IA en la nube». Si ya estás suscrito y el fallo continúa, '
            'contacta con soporte de Folio.',
        code: 'permission-denied',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonText.isEmpty ? null : jsonDecode(jsonText);
    } catch (_) {
      if (resp.statusCode == 401 && attempt == 0 && !looksLikeHtml) {
        continue;
      }
      if (resp.statusCode == 429) {
        throw FirebaseFunctionsException(
          message:
              'El servicio en la nube rechazó la petición (HTTP 429, respuesta no JSON). '
              'Espera unos segundos y reintenta; si continúa, revisa cuotas o tinta en Ajustes.',
          code: 'unavailable',
        );
      }
      final preview = _previewForCallableFailure(jsonText);
      final hint = looksLikeHtml
          ? 'El servidor respondió HTML (revisa región $kFolioCloudFunctionsRegion, despliegue de $name y proyecto $projectId). '
          : '';
      throw FirebaseFunctionsException(
        message:
            'Cloud Functions no devolvió JSON (HTTP ${resp.statusCode}). $hint$preview',
        code: 'unknown',
      );
    }
    if (decoded is! Map) {
      if (resp.statusCode == 401 && attempt == 0 && !looksLikeHtml) {
        continue;
      }
      throw FirebaseFunctionsException(
        message: 'Unexpected response from Cloud Functions',
        code: 'unknown',
      );
    }
    final map = decoded.cast<String, dynamic>();

    if (map.containsKey('error')) {
      final err = map['error'];
      var message = 'Cloud Function error';
      var code = 'unknown';
      if (err is Map) {
        message = err['message']?.toString() ?? message;
        final status = err['status'];
        if (status != null) {
          code = status.toString().toLowerCase();
        }
        // gRPC / variantes sin status estándar
        final msgL = message.toLowerCase();
        if (code == 'unknown' &&
            (msgL.contains('insufficient ink') ||
                msgL.contains('ink pack') ||
                msgL.contains('monthly refill'))) {
          code = 'resource-exhausted';
        }
      }
      final looksLikeBadAuth =
          resp.statusCode == 401 ||
          code == 'unauthenticated' ||
          message.toUpperCase().contains('UNAUTHENTICATED');
      if (looksLikeBadAuth && attempt == 0) {
        continue;
      }
      throw FirebaseFunctionsException(message: message, code: code);
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 401 && attempt == 0 && !looksLikeHtml) {
        continue;
      }
      // 429: a veces Cloud Run (capacidad); a veces el propio callable devuelve 429 con JSON {error} ya manejado arriba.
      if (resp.statusCode == 429) {
        throw FirebaseFunctionsException(
          message:
              'El servicio en la nube rechazó la petición por límite de uso o saturación (HTTP 429). '
              'Espera unos segundos y vuelve a intentarlo. Si pasa a menudo, revisa tu saldo de tinta '
              'en Ajustes; para callables que siguen en v2, también cuotas o concurrencia en Cloud Run.',
          code: 'unavailable',
        );
      }
      throw FirebaseFunctionsException(
        message: 'HTTP ${resp.statusCode} calling $name',
        code: 'unknown',
      );
    }
    return map['result'];
  }

  throw FirebaseFunctionsException(
    message:
        'Cloud Functions rejected the session (401). Sign out and sign in to Folio Cloud again.',
    code: 'unauthenticated',
  );
}

Future<dynamic> _callFolioCloudAiHttpFallback({
  required Uri baseCallableUri,
  required Object? dataPayload,
  required User user,
}) async {
  final idToken = await user.getIdToken(true);
  if (idToken == null || idToken.isEmpty) {
    throw FirebaseFunctionsException(
      message: 'No ID token for Cloud Functions. Sign in to Folio Cloud again.',
      code: 'unauthenticated',
    );
  }

  final fallbackUri = baseCallableUri.replace(
    path: '/folioCloudAiCompleteHttp',
  );
  final resp = await callable_post.folioCallableHttpPost(
    uri: fallbackUri,
    body: jsonEncode(<String, dynamic>{'data': dataPayload}),
    bearerToken: idToken,
  );

  final jsonText = _trimLeadingBom(resp.body);
  dynamic decoded;
  try {
    decoded = jsonText.isEmpty ? null : jsonDecode(jsonText);
  } catch (_) {
    throw FirebaseFunctionsException(
      message:
          'Cloud Functions fallback no devolvió JSON (HTTP ${resp.statusCode}). ${_previewForCallableFailure(jsonText)}',
      code: 'unknown',
    );
  }

  if (decoded is! Map) {
    throw FirebaseFunctionsException(
      message: 'Unexpected response from Cloud Functions fallback',
      code: 'unknown',
    );
  }
  final map = decoded.cast<String, dynamic>();

  if (map.containsKey('error')) {
    final err = map['error'];
    var message = 'Cloud Function error';
    var code = 'unknown';
    if (err is Map) {
      message = err['message']?.toString() ?? message;
      final status = err['status'];
      if (status != null) {
        code = status.toString().toLowerCase().replaceAll('_', '-');
      }
    }
    throw FirebaseFunctionsException(message: message, code: code);
  }

  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw FirebaseFunctionsException(
      message: 'HTTP ${resp.statusCode} calling folioCloudAiCompleteHttp',
      code: 'unknown',
    );
  }

  return map['result'];
}
