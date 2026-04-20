import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/folio_app_package.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/ai_types.dart';

/// Resultado de ejecutar un AI Transformer.
sealed class AiTransformerResult {}

class AiTransformerSuccess extends AiTransformerResult {
  AiTransformerSuccess(this.outputText);
  final String outputText;
}

class AiTransformerError extends AiTransformerResult {
  AiTransformerError(this.message);
  final String message;
}

/// Ejecuta [FolioAppAiTransformer] sobre el contenido de una página.
///
/// Soporta dos modos:
/// - [FolioAppAiTransformerActionType.prompt]: usa el [AiService] configurado en Folio.
/// - [FolioAppAiTransformerActionType.externalApi]: POST al endpoint de la app.
class AiTransformerExecutor {
  const AiTransformerExecutor({this.aiService});

  final AiService? aiService;

  /// Ejecuta el transformer [transformer] sobre [pageText].
  Future<AiTransformerResult> execute(
    FolioAppAiTransformer transformer, {
    required String pageText,
    required String pageTitle,
  }) async {
    final action = transformer.action;
    switch (action.type) {
      case FolioAppAiTransformerActionType.prompt:
        return _runPrompt(action, pageText: pageText, pageTitle: pageTitle);
      case FolioAppAiTransformerActionType.externalApi:
        return _callExternalApi(
          action,
          pageText: pageText,
          pageTitle: pageTitle,
        );
    }
  }

  Future<AiTransformerResult> _runPrompt(
    FolioAppAiTransformerAction action, {
    required String pageText,
    required String pageTitle,
  }) async {
    final service = aiService;
    if (service == null) {
      return AiTransformerError(
        'No hay proveedor de IA configurado. Ve a Ajustes → IA para configurar uno.',
      );
    }
    if (action.systemPrompt == null || action.systemPrompt!.isEmpty) {
      return AiTransformerError(
        'El transformer no tiene system prompt definido.',
      );
    }

    final userMessage = 'Título: $pageTitle\n\nContenido:\n$pageText';

    try {
      final models = await service.listModels().timeout(
        const Duration(seconds: 5),
      );
      final model = models.isNotEmpty ? models.first : 'default';
      final result = await service
          .complete(
            AiCompletionRequest(
              prompt: userMessage,
              model: model,
              systemPrompt: action.systemPrompt,
              temperature: 0.7,
            ),
          )
          .timeout(const Duration(seconds: 120));
      return AiTransformerSuccess(result.text);
    } on AiServiceUnreachableException catch (e) {
      return AiTransformerError('Servicio IA no disponible: $e');
    } catch (e) {
      return AiTransformerError('Error al ejecutar transformer: $e');
    }
  }

  Future<AiTransformerResult> _callExternalApi(
    FolioAppAiTransformerAction action, {
    required String pageText,
    required String pageTitle,
  }) async {
    if (action.endpointUrl == null || action.endpointUrl!.isEmpty) {
      return AiTransformerError(
        'El transformer no tiene endpoint URL definido.',
      );
    }

    final uri = Uri.tryParse(action.endpointUrl!);
    if (uri == null || uri.scheme != 'https') {
      return AiTransformerError('La URL del endpoint debe ser https.');
    }

    final body = jsonEncode({'pageTitle': pageTitle, 'pageText': pageText});

    try {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return AiTransformerError(
          'Error del servidor externo: HTTP ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body);
      final output =
          (json is Map
                  ? json['output'] ?? json['text'] ?? json['result']
                  : null)
              as String?;
      if (output == null) {
        return AiTransformerError(
          'Respuesta del endpoint no contiene campo "output", "text" o "result".',
        );
      }
      return AiTransformerSuccess(output);
    } catch (e) {
      return AiTransformerError('Error de red al llamar al endpoint: $e');
    }
  }
}
