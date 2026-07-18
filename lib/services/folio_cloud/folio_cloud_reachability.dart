import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../app_logger.dart';

/// Best-effort reachability check for Google APIs used by Firebase Auth.
///
/// En redes donde `*.googleapis.com` está bloqueado/inestable (p. ej. China),
/// ciertas operaciones pueden quedarse esperando a nivel de socket/TLS.
/// Esto permite fallar rápido antes de iniciar flows que dependen de Firebase.
///
/// En web no se puede comprobar reachability vía socket/fetch cross-origin;
/// se delega en Firebase para que gestione el error de red si lo hubiera.
Future<bool> folioGoogleApisReachable({
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (kIsWeb) return true;
  final uri = Uri.https('identitytoolkit.googleapis.com', '/');
  try {
    final res = await http.get(uri).timeout(timeout);
    // Cualquier respuesta indica reachability (aunque sea 404/302/etc.).
    return res.statusCode > 0;
  } on TimeoutException catch (e, st) {
    AppLogger.warn(
      'Reachability timeout',
      tag: 'auth',
      context: {'host': uri.host},
    );
    AppLogger.debug(
      'Reachability timeout detail',
      tag: 'auth',
      context: {'error': '$e', 'stack': '$st'},
    );
    return false;
  } on SocketException catch (e, st) {
    AppLogger.warn(
      'Reachability socket error',
      tag: 'auth',
      context: {'host': uri.host, 'error': '$e'},
    );
    AppLogger.debug(
      'Reachability socket detail',
      tag: 'auth',
      context: {'stack': '$st'},
    );
    return false;
  } on HttpException catch (e, st) {
    AppLogger.warn(
      'Reachability HTTP error',
      tag: 'auth',
      context: {'host': uri.host, 'error': '$e'},
    );
    AppLogger.debug(
      'Reachability HTTP detail',
      tag: 'auth',
      context: {'stack': '$st'},
    );
    return false;
  } catch (e, st) {
    AppLogger.warn(
      'Reachability unexpected error',
      tag: 'auth',
      context: {'host': uri.host, 'error': '$e'},
    );
    AppLogger.debug(
      'Reachability unexpected detail',
      tag: 'auth',
      context: {'stack': '$st'},
    );
    return false;
  }
}
