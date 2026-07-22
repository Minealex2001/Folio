/// Excepción base compartida por los clientes de API de integraciones
/// (GitHub, GitLab, Slack, Teams), que hasta ahora duplicaban los mismos
/// campos y el mismo formato de `toString()` en 4 clases idénticas.
abstract class IntegrationApiException implements Exception {
  const IntegrationApiException(
    this.message, {
    this.statusCode,
    this.body,
    this.uri,
    this.method,
  });

  final String message;
  final int? statusCode;
  final String? body;
  final String? uri;
  final String? method;

  /// Nombre de la excepción concreta, usado en `toString()` (ej. "GitHubApiException").
  String get exceptionName;

  @override
  String toString() {
    final code = statusCode;
    final m = (method ?? '').trim().isEmpty ? '' : '${method!.trim()} ';
    final u = (uri ?? '').trim().isEmpty ? '' : ' ${uri!.trim()}';
    final b = (body ?? '').trim().isEmpty ? '' : ' | body=${body!.trim()}';
    return '$exceptionName($code): $m$message$u$b';
  }
}
