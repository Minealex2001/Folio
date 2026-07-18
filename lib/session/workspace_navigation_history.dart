/// Historial de visitas a páginas del workspace (estilo navegador).
///
/// Cada entrada es un [pageId] o `null` (pantalla de inicio / sin página).
final class WorkspaceNavigationHistory {
  WorkspaceNavigationHistory({this.maxEntries = 50});

  final int maxEntries;

  final List<String?> _stack = <String?>[];
  int _index = -1;

  bool get canGoBack => _index > 0;

  bool get canGoForward => _index >= 0 && _index < _stack.length - 1;

  /// Entrada actual del cursor, o `null` si el historial está vacío.
  /// `null` como valor de la entrada significa Home.
  String? get current {
    if (_index < 0 || _index >= _stack.length) return null;
    return _stack[_index];
  }

  bool get isEmpty => _stack.isEmpty;

  void clear() {
    _stack.clear();
    _index = -1;
  }

  /// Sustituye el historial por una sola entrada (p. ej. tras desbloquear).
  void seed(String? pageId) {
    _stack
      ..clear()
      ..add(pageId);
    _index = 0;
  }

  /// Registra una visita. Si coincide con la actual, no hace nada.
  /// Al navegar desde el medio del stack, trunca el forward (como el navegador).
  void record(String? pageId) {
    if (_index >= 0 && _index < _stack.length && _stack[_index] == pageId) {
      return;
    }
    if (_index >= 0 && _index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(pageId);
    _index = _stack.length - 1;
    while (_stack.length > maxEntries) {
      _stack.removeAt(0);
      _index--;
    }
  }

  /// Retrocede saltando entradas inválidas. Devuelve `true` si el cursor se movió.
  bool goBack({required bool Function(String? pageId) isValid}) {
    if (!canGoBack) return false;
    var i = _index - 1;
    while (i >= 0) {
      if (isValid(_stack[i])) {
        _index = i;
        return true;
      }
      i--;
    }
    return false;
  }

  /// Avanza saltando entradas inválidas. Devuelve `true` si el cursor se movió.
  bool goForward({required bool Function(String? pageId) isValid}) {
    if (!canGoForward) return false;
    var i = _index + 1;
    while (i < _stack.length) {
      if (isValid(_stack[i])) {
        _index = i;
        return true;
      }
      i++;
    }
    return false;
  }
}
