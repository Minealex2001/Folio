import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

/// Verifica correo+contraseña Folio Cloud vía Identity Toolkit REST (HTTP).
///
/// En Windows/Linux el plugin [User.reauthenticateWithCredential] puede disparar
/// el canal `firebase_auth_plugin/id-token` desde un hilo no plataforma; esta
/// ruta evita ese código nativo manteniendo la misma comprobación de credenciales.
Future<void> verifyFolioCloudPasswordViaIdentityToolkit({
  required String email,
  required String password,
  String? expectedLocalId,
}) async {
  final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
  final uri = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
    '?key=${Uri.encodeQueryComponent(apiKey)}',
  );
  http.Response res;
  try {
    res = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'email': email.trim(),
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 15));
  } on TimeoutException catch (e, st) {
    log(
      'IdentityToolkit timeout posting to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    throw FirebaseAuthException(code: 'network-request-failed');
  } on SocketException catch (e, st) {
    log(
      'IdentityToolkit socket error posting to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    throw FirebaseAuthException(code: 'network-request-failed');
  } on HttpException catch (e, st) {
    log(
      'IdentityToolkit HTTP error posting to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    throw FirebaseAuthException(code: 'network-request-failed');
  }
  final body = jsonDecode(res.body);
  if (body is! Map<String, dynamic>) {
    throw FirebaseAuthException(
      code: 'unknown',
      message: 'Respuesta de autenticación no válida.',
    );
  }
  if (res.statusCode != 200) {
    final err = body['error'];
    final msg = err is Map && err['message'] is String
        ? err['message'] as String
        : 'UNKNOWN';
    throw _mapIdentityToolkitError(msg);
  }
  final uid = body['localId'] as String?;
  if (expectedLocalId != null &&
      expectedLocalId.isNotEmpty &&
      uid != null &&
      uid != expectedLocalId) {
    throw FirebaseAuthException(
      code: 'invalid-credential',
      message: 'El correo no coincide con la sesión actual.',
    );
  }
}

FirebaseAuthException _mapIdentityToolkitError(String message) {
  if (message.contains('INVALID_PASSWORD') ||
      message.contains('INVALID_LOGIN_CREDENTIALS')) {
    return FirebaseAuthException(code: 'wrong-password', message: message);
  }
  if (message.contains('EMAIL_NOT_FOUND')) {
    return FirebaseAuthException(code: 'user-not-found', message: message);
  }
  if (message.contains('USER_DISABLED')) {
    return FirebaseAuthException(code: 'user-disabled', message: message);
  }
  if (message.contains('TOO_MANY_ATTEMPTS')) {
    return FirebaseAuthException(code: 'too-many-requests', message: message);
  }
  if (message.contains('OPERATION_NOT_ALLOWED')) {
    return FirebaseAuthException(
      code: 'operation-not-allowed',
      message: message,
    );
  }
  if (message.contains('INVALID_EMAIL')) {
    return FirebaseAuthException(code: 'invalid-email', message: message);
  }
  return FirebaseAuthException(code: 'invalid-credential', message: message);
}
