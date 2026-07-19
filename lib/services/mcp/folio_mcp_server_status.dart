import 'package:flutter/foundation.dart';

/// Estado del servidor MCP local para la pantalla de Ajustes, sin necesidad
/// de una referencia directa al `FolioMcpServer` (que vive en `_FolioAppState`).
///
/// [isRunning] es `true` solo tras un `bind` exitoso. Si el ajuste está
/// activado pero el bind falló, se publica con `isRunning: false` y
/// [errorMessage] para no fingir que el endpoint responde.
class FolioMcpServerInfo {
  const FolioMcpServerInfo({
    required this.port,
    required this.authToken,
    this.isRunning = true,
    this.errorMessage,
  });

  final int port;
  final String authToken;
  final bool isRunning;
  final String? errorMessage;
}

/// `null` cuando el ajuste MCP está desactivado. Lo actualiza `folio_app.dart`
/// cada vez que arranca/para el servidor según `AppSettings.mcpServerEnabled`.
final ValueNotifier<FolioMcpServerInfo?> folioMcpServerStatus =
    ValueNotifier(null);
