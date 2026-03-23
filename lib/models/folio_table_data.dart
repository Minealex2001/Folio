import 'dart:convert';

/// Serialización del bloque `table` en [FolioBlock.text] (`v`, `cols`, `cells`).
class FolioTableData {
  FolioTableData({required this.cols, required List<String> cells})
    : cells = List<String>.from(cells);

  static const int currentVersion = 1;

  /// Columnas (>= 1).
  int cols;
  List<String> cells;

  int get rowCount => cols <= 0 ? 0 : (cells.length / cols).ceil();

  factory FolioTableData.empty({int cols = 2, int rows = 2}) {
    final c = cols.clamp(1, 32);
    final r = rows.clamp(1, 200);
    return FolioTableData(cols: c, cells: List<String>.filled(c * r, ''));
  }

  /// Normaliza longitud de [cells] a múltiplo de [cols].
  void normalize() {
    if (cols < 1) cols = 1;
    final need = rowCount * cols;
    while (cells.length < need) {
      cells.add('');
    }
    if (cells.length > need) {
      cells = cells.sublist(0, need);
    }
  }

  String encode() {
    normalize();
    return jsonEncode({'v': currentVersion, 'cols': cols, 'cells': cells});
  }

  static FolioTableData? tryParse(String text) {
    if (text.trim().isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final cols = (m['cols'] as num?)?.toInt() ?? 2;
      final raw = m['cells'];
      if (raw is! List) return null;
      final list = raw.map((e) => e?.toString() ?? '').toList();
      final d = FolioTableData(cols: cols.clamp(1, 32), cells: list);
      d.normalize();
      return d;
    } catch (_) {
      return null;
    }
  }

  String cellAt(int row, int col) {
    if (col < 0 || col >= cols || row < 0) return '';
    final i = row * cols + col;
    return i < cells.length ? cells[i] : '';
  }

  void setCell(int row, int col, String value) {
    if (col < 0 || col >= cols || row < 0) return;
    final i = row * cols + col;
    while (cells.length <= i) {
      cells.add('');
    }
    cells[i] = value;
  }

  void addRow() {
    normalize();
    for (var c = 0; c < cols; c++) {
      cells.add('');
    }
  }

  /// Elimina la última fila si queda al menos una.
  bool removeLastRow() {
    normalize();
    if (rowCount <= 1) return false;
    cells.removeRange(cells.length - cols, cells.length);
    return true;
  }

  void addCol() {
    normalize();
    final rows = rowCount;
    cols += 1;
    final next = <String>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        next.add(cellAt(r, c));
      }
      next.add('');
    }
    cells = next;
  }

  /// Elimina la última columna si queda al menos una.
  bool removeLastCol() {
    normalize();
    if (cols <= 1) return false;
    final rows = rowCount;
    final next = <String>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        next.add(cellAt(r, c));
      }
    }
    cells = next;
    cols -= 1;
    return true;
  }

  /// Texto plano para búsqueda (celdas separadas por espacio).
  static String plainTextFromJson(String text) {
    final d = tryParse(text);
    if (d == null) return '';
    return d.cells.where((e) => e.trim().isNotEmpty).join(' ');
  }
}
