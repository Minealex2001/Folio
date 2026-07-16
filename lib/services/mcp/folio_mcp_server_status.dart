import 'package:flutter/foundation.dart';

/// Puerto/token del servidor MCP local en ejecución, para que la pantalla de
/// Ajustes los muestre sin necesitar una referencia directa al
/// `FolioMcpServer` (que vive en `_FolioAppState`).
class FolioMcpServerInfo {
  const FolioMcpServerInfo({required this.port, required this.authToken});

  final int port;
  final String authToken;
}

/// `null` cuando el servidor no está corriendo. Lo actualiza `folio_app.dart`
/// cada vez que arranca/para el servidor según `AppSettings.mcpServerEnabled`.
final ValueNotifier<FolioMcpServerInfo?> folioMcpServerStatus = ValueNotifier(null);
