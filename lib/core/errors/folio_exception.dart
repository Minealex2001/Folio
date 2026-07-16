/// Base para las excepciones tipadas de Folio: un [message] más el `toString`
/// por defecto, factorizados para que las excepciones simples no repitan
/// cada una `implements Exception { ... String toString() => message; }`.
///
/// No obliga a nada: las excepciones con forma propia (código de estado,
/// causa, etc.) pueden seguir usando `implements Exception` directamente y
/// sobrescribir `toString` si el mensaje plano no les sirve.
abstract class FolioException implements Exception {
  const FolioException(this.message);

  final String message;

  @override
  String toString() => message;
}
