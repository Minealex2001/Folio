import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/ai/openai_compatible_ai_service.dart';

/// Levanta un servidor HTTP local que sirve una respuesta SSE canned,
/// imitando `chat/completions` con `stream: true` de OpenAI, para probar el
/// parseo real de `completeStream` (incluyendo deltas de tool-calls) sin
/// depender de un backend real.
Future<HttpServer> _serveSse(List<String> dataLines) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    await req.drain();
    req.response.headers.contentType = ContentType('text', 'event-stream');
    for (final line in dataLines) {
      req.response.write('data: $line\n\n');
    }
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  });
  return server;
}

OpenAiCompatibleAiService _serviceFor(HttpServer server) => OpenAiCompatibleAiService(
  baseUrl: Uri.parse('http://${server.address.address}:${server.port}/v1'),
  timeout: const Duration(seconds: 5),
  defaultModel: 'gpt-4o-mini',
  apiKey: '',
  provider: 'openAi',
);

void main() {
  test('completeStream reconstruye el mismo texto final que los deltas SSE', () async {
    final server = await _serveSse([
      jsonEncode({
        'choices': [
          {
            'delta': {'content': 'Hola'},
          },
        ],
      }),
      jsonEncode({
        'choices': [
          {
            'delta': {'content': ', mundo.'},
          },
        ],
      }),
      jsonEncode({
        'choices': [],
        'usage': {'prompt_tokens': 12, 'completion_tokens': 5, 'total_tokens': 17},
      }),
    ]);
    addTearDown(server.close);

    final chunks = await _serviceFor(
      server,
    ).completeStream(const AiCompletionRequest(prompt: 'hola', model: 'auto')).toList();

    final fullText = chunks.map((c) => c.textDelta).join();
    expect(fullText, 'Hola, mundo.');
    expect(chunks.last.isFinal, isTrue);
    expect(chunks.last.usage?.totalTokens, 17);
  });

  test('completeStream reensambla argumentos de tool-call troceados por índice', () async {
    final server = await _serveSse([
      jsonEncode({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_abc',
                  'function': {'name': 'create_page', 'arguments': '{"tit'},
                },
              ],
            },
          },
        ],
      }),
      jsonEncode({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'function': {'arguments': 'le":"Notas"}'},
                },
              ],
            },
          },
        ],
      }),
    ]);
    addTearDown(server.close);

    final chunks = await _serviceFor(
      server,
    ).completeStream(const AiCompletionRequest(prompt: 'crea una pagina', model: 'auto')).toList();

    final finalChunk = chunks.last;
    expect(finalChunk.isFinal, isTrue);
    expect(finalChunk.hasToolCalls, isTrue);
    final call = finalChunk.toolCalls!.single;
    expect(call.id, 'call_abc');
    expect(call.name, 'create_page');
    expect(call.arguments['title'], 'Notas');
  });
}
