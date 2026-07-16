import 'folio_exception.dart';

/// La libreta activa no se puede leer o decodificar (corrupción o corte de escritura).
class VaultCorruptionException extends FolioException {
  VaultCorruptionException(super.message, {this.cause, this.restoredFromBackup = false});

  final Object? cause;
  final bool restoredFromBackup;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}
