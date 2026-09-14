import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/folio_cloud_ai_service.dart';
import 'package:folio/services/ai/gemini_nano_ai_service.dart';
import 'package:folio/services/ai/lmstudio_ai_service.dart';
import 'package:folio/services/ai/ollama_ai_service.dart';
import 'package:folio/services/ai/openai_compatible_ai_service.dart';

/// Fase 7 de Quill 2.0 — `supportsVision` no es un `true` en bloque: para
/// Quill Cloud el modelo lo controla FolioBackend (afirmación justificada,
/// no una suposición), pero Ollama/LM Studio/OpenAI-compatible dejan al
/// usuario escribir cualquier nombre de modelo, así que usan la misma
/// heurística por substring ya aceptada para `supportsNativeToolCalling`.
void main() {
  group('modelNameLooksVisionCapable', () {
    test('reconoce modelos con visión conocidos', () {
      expect(modelNameLooksVisionCapable('gpt-4o'), isTrue);
      expect(modelNameLooksVisionCapable('gpt-4o-mini'), isTrue);
      expect(modelNameLooksVisionCapable('gemini-1.5-flash'), isTrue);
      expect(modelNameLooksVisionCapable('llava:13b'), isTrue);
      expect(modelNameLooksVisionCapable('qwen2.5-vl:7b'), isTrue);
    });

    test('no reconoce un modelo de texto plano', () {
      expect(modelNameLooksVisionCapable('llama3.1:8b'), isFalse);
      expect(modelNameLooksVisionCapable('mistral-nemo'), isFalse);
      expect(modelNameLooksVisionCapable('deepseek-coder'), isFalse);
    });

    test('es case-insensitive', () {
      expect(modelNameLooksVisionCapable('GPT-4O'), isTrue);
      expect(modelNameLooksVisionCapable('LLaVA'), isTrue);
    });
  });

  group('AiService.supportsVision por proveedor', () {
    test('Ollama: true con un modelo con visión conocida', () {
      final s = OllamaAiService(
        baseUrl: Uri.parse('http://localhost:11434'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'llava:13b',
      );
      expect(s.supportsVision, isTrue);
    });

    test('Ollama: false con un modelo de texto plano', () {
      final s = OllamaAiService(
        baseUrl: Uri.parse('http://localhost:11434'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'llama3.1:8b',
      );
      expect(s.supportsVision, isFalse);
    });

    test('Ollama: false con un modelo desconocido (nunca true por defecto)', () {
      final s = OllamaAiService(
        baseUrl: Uri.parse('http://localhost:11434'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'un-modelo-cualquiera-inventado',
      );
      expect(s.supportsVision, isFalse);
    });

    test('LM Studio: sigue la misma heurística por modelo', () {
      final vision = LmStudioAiService(
        baseUrl: Uri.parse('http://localhost:1234'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'moondream2',
      );
      final text = LmStudioAiService(
        baseUrl: Uri.parse('http://localhost:1234'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'mixtral-8x7b',
      );
      expect(vision.supportsVision, isTrue);
      expect(text.supportsVision, isFalse);
    });

    test('OpenAI-compatible: sigue la misma heurística por modelo', () {
      final vision = OpenAiCompatibleAiService(
        baseUrl: Uri.parse('https://api.openai.com'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'gpt-4o-mini',
        apiKey: 'x',
        provider: 'openAi',
      );
      final text = OpenAiCompatibleAiService(
        baseUrl: Uri.parse('https://api.openai.com'),
        timeout: const Duration(seconds: 30),
        defaultModel: 'gpt-3.5-turbo-instruct',
        apiKey: 'x',
        provider: 'openAi',
      );
      expect(vision.supportsVision, isTrue);
      expect(text.supportsVision, isFalse);
    });

    test('Quill Cloud: true — el modelo lo controla FolioBackend, no el usuario', () {
      expect(FolioCloudAiService().supportsVision, isTrue);
    });

    test('Gemini Nano: false — sin soporte de visión en el modelo on-device', () {
      expect(GeminiNanoAiService().supportsVision, isFalse);
    });
  });
}
