import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/ai/folio_cloud_ai_service.dart';

/// Fase 7 de Quill 2.0 — antes, `FolioCloudAiService` nunca leía
/// `request.attachments` en ningún punto: cualquier imagen/PDF/texto
/// adjunto se descartaba en silencio para este proveedor (a diferencia de
/// Ollama/LM Studio/OpenAI-compatible, que ya mandaban imágenes reales).
/// Estos tests prueban `_buildCompletePayload` (expuesto vía
/// `buildCompletePayloadForTesting`, ver ese archivo) sin red real.
void main() {
  final service = FolioCloudAiService();

  test('sin adjuntos, comportamiento igual que antes (sin campo attachments)', () {
    final payload = service.buildCompletePayloadForTesting(
      const AiCompletionRequest(prompt: 'hola', model: 'auto'),
    );
    expect(payload.containsKey('attachments'), isFalse);
    expect(payload['prompt'], 'hola');
  });

  test('un adjunto de imagen se incluye en el campo attachments del payload', () {
    final payload = service.buildCompletePayloadForTesting(
      const AiCompletionRequest(
        prompt: 'describe esta imagen',
        model: 'auto',
        attachments: [
          AiFileAttachment(name: 'foto.png', mimeType: 'image/png', content: 'YmFzZTY0'),
        ],
      ),
    );
    expect(payload['attachments'], [
      {'name': 'foto.png', 'mimeType': 'image/png', 'content': 'YmFzZTY0'},
    ]);
    // El texto del prompt no se toca al añadir una imagen.
    expect(payload['prompt'], 'describe esta imagen');
  });

  test('un adjunto de texto se fusiona en el prompt, no va en attachments', () {
    final payload = service.buildCompletePayloadForTesting(
      const AiCompletionRequest(
        prompt: 'resume esto',
        model: 'auto',
        attachments: [
          AiFileAttachment(name: 'notas.txt', mimeType: 'text/plain', content: 'contenido del archivo'),
        ],
      ),
    );
    expect(payload.containsKey('attachments'), isFalse);
    expect(payload['prompt'], contains('resume esto'));
    expect(payload['prompt'], contains('notas.txt'));
    expect(payload['prompt'], contains('contenido del archivo'));
  });

  test('mezcla de imagen y texto: la imagen va a attachments, el texto se fusiona en prompt', () {
    final payload = service.buildCompletePayloadForTesting(
      const AiCompletionRequest(
        prompt: 'analiza esto',
        model: 'auto',
        attachments: [
          AiFileAttachment(name: 'foto.png', mimeType: 'image/png', content: 'AAAA'),
          AiFileAttachment(name: 'notas.txt', mimeType: 'text/plain', content: 'texto plano'),
        ],
      ),
    );
    expect(payload['attachments'], hasLength(1));
    expect((payload['attachments'] as List).single, {
      'name': 'foto.png',
      'mimeType': 'image/png',
      'content': 'AAAA',
    });
    expect(payload['prompt'], contains('texto plano'));
  });
}
