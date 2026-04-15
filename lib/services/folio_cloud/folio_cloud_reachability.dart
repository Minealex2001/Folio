import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Best-effort reachability check for Google APIs used by Firebase Auth.
///
/// En redes donde `*.googleapis.com` está bloqueado/inestable (p. ej. China),
/// ciertas operaciones pueden quedarse esperando a nivel de socket/TLS.
/// Esto permite fallar rápido antes de iniciar flows que dependen de Firebase.
Future<bool> folioGoogleApisReachable({
  Duration timeout = const Duration(seconds: 2),
}) async {
  final uri = Uri.https('identitytoolkit.googleapis.com', '/');
  try {
    final res = await http.get(uri).timeout(timeout);
    // Cualquier respuesta indica reachability (aunque sea 404/302/etc.).
    return res.statusCode > 0;
  } on TimeoutException catch (e, st) {
    log(
      'Reachability timeout to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    return false;
  } on SocketException catch (e, st) {
    log(
      'Reachability socket error to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    return false;
  } on HttpException catch (e, st) {
    log(
      'Reachability HTTP error to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    return false;
  } catch (e, st) {
    log(
      'Reachability unexpected error to ${uri.host}.',
      name: 'FolioCloudAuth',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

