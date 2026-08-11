import 'dart:async';

/// Token cooperativo para abortar una petición de Quill en curso.
///
/// - [abortTrigger] se usa con `http.AbortableRequest` (Quill Cloud).
/// - [addOnCancel] registra cleanup de proveedores `dart:io` (`HttpClient.close`).
/// - [isCancelled] permite salir del tool-loop entre pasos sin esperar a la red.
class AiCancelToken {
  final Completer<void> _abort = Completer<void>();
  final List<void Function()> _onCancel = <void Function()>[];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Completar este future aborta un [http.AbortableRequest] en curso.
  Future<void> get abortTrigger => _abort.future;

  /// Registra un callback invocado una sola vez al cancelar (p. ej. cerrar
  /// el [HttpClient] del proveedor local). Si ya estaba cancelado, se llama
  /// de inmediato.
  void addOnCancel(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _onCancel.add(callback);
  }

  void removeOnCancel(void Function() callback) {
    _onCancel.remove(callback);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_abort.isCompleted) {
      _abort.complete();
    }
    final listeners = List<void Function()>.of(_onCancel);
    _onCancel.clear();
    for (final cb in listeners) {
      try {
        cb();
      } catch (_) {}
    }
  }
}

/// Lanzada cuando el usuario (u otro llamador) cancela la generación de Quill.
/// La UI no debe mostrar snack de error ante esta excepción.
class AiRequestCancelledException implements Exception {
  const AiRequestCancelledException([this.message = 'Quill request cancelled']);

  final String message;

  @override
  String toString() => message;
}
