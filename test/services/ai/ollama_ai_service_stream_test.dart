import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/ai/ollama_ai_service.dart';

/// Levanta un servidor HTTP local que sirve una respuesta NDJSON canned,
/// imitando `/api/chat` de Ollama con `stream: true`, para probar el parseo
/// real de `completeStream` sin depender de un Ollama real.
Future<HttpServer> _serveNdjson(List<Map<String, dynamic>> lines) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    await req.drain();
    req.response.headers.contentType = ContentType('application', 'x-ndjson');
    for (final line in lines) {
      req.response.write('${jsonEncode(line)}\n');
    }
    await req.response.close();
  });
  return server;
}

void main() {
  test('completeStream reconstruye el mismo texto final que un complete() equivalente', () async {
    final server = await _serveNdjson([
      {
        'message': {'role': 'assistant', 'content': 'Hola'},
        'done': false,
      },
      {
        'message': {'role': 'assistant', 'content': ', mundo'},
        'done': false,
      },
      {
        'message': {'role': 'assistant', 'content': '.'},
        'done': true,
        'prompt_eval_count': 10,
        'eval_count': 4,
      },
    ]);
    addTearDown(server.close);

    final service = OllamaAiService(
      baseUrl: Uri.parse('http://${server.address.address}:${server.port}'),
      timeout: const Duration(seconds: 5),
      defaultModel: 'llama3.1:8b',
    );

    final chunks = await service
        .completeStream(const AiCompletionRequest(prompt: 'hola', model: 'auto'))
        .toList();

    final fullText = chunks.map((c) => c.textDelta).join();
    expect(fullText, 'Hola, mundo.');
    expect(chunks.last.isFinal, isTrue);
    expect(chunks.last.usage?.promptTokens, 10);
    expect(chunks.last.usage?.completionTokens, 4);
  });

  test('completeStream reensambla tool_calls que llegan completas en el chunk final', () async {
    final server = await _serveNdjson([
      {
        'message': {'role': 'assistant', 'content': ''},
        'done': false,
      },
      {
        'message': {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'function': {
                'name': 'create_page',
                'arguments': {'title': 'Notas'},
              },
            },
          ],
        },
        'done': true,
      },
    ]);
    addTearDown(server.close);

    final service = OllamaAiService(
      baseUrl: Uri.parse('http://${server.address.address}:${server.port}'),
      timeout: const Duration(seconds: 5),
      defaultModel: 'llama3.1:8b',
    );

    final chunks = await service
        .completeStream(const AiCompletionRequest(prompt: 'crea una pagina', model: 'auto'))
        .toList();

    final finalChunk = chunks.last;
    expect(finalChunk.isFinal, isTrue);
    expect(finalChunk.hasToolCalls, isTrue);
    expect(finalChunk.toolCalls!.single.name, 'create_page');
    expect(finalChunk.toolCalls!.single.arguments['title'], 'Notas');
  });
}
