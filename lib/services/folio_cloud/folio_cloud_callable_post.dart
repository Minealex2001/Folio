import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

/// Respuesta mínima POST (solo cabeceras permitidas en el protocolo callable).
class FolioCallableHttpResponse {
  FolioCallableHttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// POST al endpoint callable con **solo** `Content-Type` y `Authorization`.
///
/// La spec de Firebase rechaza cabeceras extra; `package:http` añade
/// `User-Agent` y puede provocar respuestas no JSON en Windows/Linux.
///
/// Errores de red/TLS/timeout se convierten en [FirebaseFunctionsException] para
/// que los consumidores puedan tratarlos como el SDK callable.
Future<FolioCallableHttpResponse> folioCallableHttpPost({
  required Uri uri,
  required String body,
  required String bearerToken,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 120),
}) async {
  final client = HttpClient();
  client.userAgent = null;
  client.connectionTimeout = connectionTimeout;
  try {
    final req = await client.postUrl(uri);
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $bearerToken',
    );
    req.write(body);
    final res = await req.close();
    final headers = <String, String>{};
    res.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name.toLowerCase()] = values.first;
      }
    });
    final text = await utf8.decoder.bind(res).timeout(bodyTimeout).join();
    return FolioCallableHttpResponse(
      statusCode: res.statusCode,
      body: text,
      headers: headers,
    );
  } on TimeoutException catch (e) {
    throw FirebaseFunctionsException(
      message: 'Cloud Functions request timed out: $e',
      code: 'deadline-exceeded',
    );
  } on HandshakeException catch (e) {
    throw FirebaseFunctionsException(
      message: 'TLS handshake failed calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } on TlsException catch (e) {
    throw FirebaseFunctionsException(
      message: 'TLS error calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } on SocketException catch (e) {
    throw FirebaseFunctionsException(
      message: 'Network error calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } on HttpException catch (e) {
    throw FirebaseFunctionsException(
      message: 'HTTP client error calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } on OSError catch (e) {
    throw FirebaseFunctionsException(
      message: 'Network error calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } catch (e) {
    if (e is FirebaseFunctionsException) rethrow;
    throw FirebaseFunctionsException(
      message: 'Network error calling Cloud Functions: $e',
      code: 'unavailable',
    );
  } finally {
    client.close(force: true);
  }
}
