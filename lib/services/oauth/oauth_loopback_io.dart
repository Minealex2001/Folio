import 'dart:async';
import 'dart:io';

class OAuthCancelledException implements Exception {
  const OAuthCancelledException([this.message = 'oauth_cancelled']);
  final String message;
  @override
  String toString() => message;
}

String readOsEnv(String key) => (Platform.environment[key] ?? '').trim();

/// Escucha el redirect loopback `http://127.0.0.1:$port/callback`.
Future<String> awaitLoopbackOAuthCode({
  required int port,
  required String expectedState,
  Future<void>? whenCancelled,
}) async {
  HttpServer server;
  try {
    server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
  } catch (e) {
    throw StateError(
      'No se pudo abrir el callback OAuth en '
      'http://127.0.0.1:$port/callback. '
      'Comprueba que el puerto $port esté libre. Detalle: $e',
    );
  }

  final completer = Completer<String>();
  late StreamSubscription<HttpRequest> sub;
  sub = server.listen((request) async {
    try {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final state = (request.uri.queryParameters['state'] ?? '').trim();
      final code = (request.uri.queryParameters['code'] ?? '').trim();
      final err = (request.uri.queryParameters['error'] ?? '').trim();
      if (state != expectedState) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<h2>OAuth error</h2><p>Invalid state.</p>');
        await request.response.close();
        return;
      }
      if (err.isNotEmpty) {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<h2>OAuth cancelado</h2><p>$err</p><p>Puedes cerrar esta pestaña.</p>',
        );
        await request.response.close();
        if (!completer.isCompleted) {
          completer.completeError(const OAuthCancelledException());
        }
        return;
      }
      if (code.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<h2>OAuth error</h2><p>Missing code.</p>');
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<h2>Conectado</h2><p>Ya puedes volver a Folio. Puedes cerrar esta pestaña.</p>',
      );
      await request.response.close();
      if (!completer.isCompleted) completer.complete(code);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  });

  if (whenCancelled != null) {
    unawaited(whenCancelled.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(const OAuthCancelledException());
      }
      unawaited(sub.cancel());
      unawaited(server.close(force: true));
    }));
  }

  return completer.future;
}
