/// Excepción de API Folio Cloud (antes `FolioCloudException`).
///
/// [code] usa la misma convención kebab-case que las callables legacy
/// (`unauthenticated`, `permission-denied`, `resource-exhausted`, …).
class FolioCloudException implements Exception {
  FolioCloudException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'FolioCloudException($code): $message';
}

/// Excepción de autenticación Folio Cloud (antes `FolioAuthException`).
///
/// Preferir [FolioSpringAuthException] en flujos Spring nuevos; esta clase
/// mantiene el contrato `code`/`message` que ya capturan pantallas de UI.
class FolioAuthException implements Exception {
  FolioAuthException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => 'FolioAuthException($code): ${message ?? ''}';
}
