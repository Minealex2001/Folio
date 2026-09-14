import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/openai_compatible_ai_service.dart';

/// Fase 7.5 de Quill 2.0 — antes, `generateImage` nunca enviaba
/// `response_format` (correcto solo para la familia `gpt-image-*`, que lo
/// rechaza) y solo leía `data[0].b64_json`, nunca `url`. Un modelo como
/// `dall-e-3` (que por defecto devuelve `url`) se reportaba como "respuesta
/// de imagen vacía" pese a haber generado la imagen con éxito. Levanta un
/// servidor HTTP local real (mismo patrón que
/// `openai_compatible_ai_service_stream_test.dart`) para probar el request y
/// el parseo de la respuesta real, sin mocks.
Future<HttpServer> _serveJson(
  Map<String, dynamic> Function(Map<String, dynamic> requestBody) responder,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final raw = await utf8.decodeStream(req);
    final requestBody = jsonDecode(raw) as Map<String, dynamic>;
    final response = responder(requestBody);
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(response));
    await req.response.close();
  });
  return server;
}

OpenAiCompatibleAiService _serviceFor(
  HttpServer server, {
  String defaultModel = 'gpt-4o-mini',
  String provider = 'openAi',
}) => OpenAiCompatibleAiService(
  baseUrl: Uri.parse('http://${server.address.address}:${server.port}/v1'),
  timeout: const Duration(seconds: 5),
  defaultModel: defaultModel,
  apiKey: '',
  provider: provider,
);

void main() {
  test('para gpt-image-*, no envía response_format y lee b64_json', () async {
    Map<String, dynamic>? capturedRequest;
    final server = await _serveJson((req) {
      capturedRequest = req;
      return {
        'data': [
          {'b64_json': 'AAAA'},
        ],
      };
    });
    addTearDown(server.close);

    final result = await _serviceFor(server).generateImage(prompt: 'un gato');

    expect(capturedRequest!.containsKey('response_format'), isFalse);
    expect(result.bytes, base64Decode('AAAA'));
    expect(result.mimeType, 'image/png');
  });

  test('para un modelo custom que no es gpt-image-*, pide explícitamente b64_json', () async {
    Map<String, dynamic>? capturedRequest;
    final server = await _serveJson((req) {
      capturedRequest = req;
      return {
        'data': [
          {'b64_json': 'BBBB'},
        ],
      };
    });
    addTearDown(server.close);

    await _serviceFor(server, defaultModel: 'dall-e-3', provider: 'custom').generateImage(
      prompt: 'un gato',
    );

    expect(capturedRequest!['response_format'], 'b64_json');
  });

  test('si el proveedor devuelve url en vez de b64_json, falla con un mensaje específico', () async {
    final server = await _serveJson(
      (req) => {
        'data': [
          {'url': 'https://example.com/gato.png'},
        ],
      },
    );
    addTearDown(server.close);

    await expectLater(
      _serviceFor(server, defaultModel: 'dall-e-3', provider: 'custom').generateImage(prompt: 'x'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('URL'),
        ),
      ),
    );
  });

  test('data vacío sigue reportándose como respuesta vacía', () async {
    final server = await _serveJson((req) => {'data': <dynamic>[]});
    addTearDown(server.close);

    await expectLater(
      _serviceFor(server).generateImage(prompt: 'x'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('vacía')),
      ),
    );
  });

  test('un b64_json corrupto da un error claro, no un FormatException crudo', () async {
    final server = await _serveJson(
      (req) => {
        'data': [
          {'b64_json': 'esto-no-es-base64-válido!!'},
        ],
      },
    );
    addTearDown(server.close);

    await expectLater(
      _serviceFor(server).generateImage(prompt: 'x'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('corrupta')),
      ),
    );
  });
}
