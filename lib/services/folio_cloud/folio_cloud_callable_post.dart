import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'folio_cloud_exception.dart';

/// Respuesta mínima POST (solo cabeceras Content-Type + Authorization).
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

/// POST HTTP con cabeceras mínimas (útil para proxies Spring).
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
    throw FolioCloudException(
      message: 'Folio Cloud request timed out: $e',
      code: 'deadline-exceeded',
    );
  } on HandshakeException catch (e) {
    throw FolioCloudException(
      message: 'TLS handshake failed: $e',
      code: 'unavailable',
    );
  } on TlsException catch (e) {
    throw FolioCloudException(
      message: 'TLS error: $e',
      code: 'unavailable',
    );
  } on SocketException catch (e) {
    throw FolioCloudException(
      message: 'Network error: $e',
      code: 'unavailable',
    );
  } on HttpException catch (e) {
    throw FolioCloudException(
      message: 'HTTP client error: $e',
      code: 'unavailable',
    );
  } on OSError catch (e) {
    throw FolioCloudException(
      message: 'Network error: $e',
      code: 'unavailable',
    );
  } catch (e) {
    if (e is FolioCloudException) rethrow;
    throw FolioCloudException(
      message: 'Network error: $e',
      code: 'unavailable',
    );
  } finally {
    client.close(force: true);
  }
}
