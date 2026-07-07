/// La libreta activa no se puede leer o decodificar (corrupción o corte de escritura).
class VaultCorruptionException implements Exception {
  VaultCorruptionException(this.message, {this.cause, this.restoredFromBackup = false});

  final String message;
  final Object? cause;
  final bool restoredFromBackup;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}
