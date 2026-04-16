class LocalEnv {
  LocalEnv._();

  static final Map<String, String> _values = <String, String>{};

  static String? get(String key) => _values[key];

  static bool has(String key) => (_values[key] ?? '').trim().isNotEmpty;

  static void setAll(Map<String, String> values) {
    _values
      ..clear()
      ..addAll(values);
  }
}

Map<String, String> parseDotEnv(String raw) {
  final out = <String, String>{};
  final lines = raw.split(RegExp(r'\r?\n'));
  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('#')) continue;

    var s = t;
    if (s.startsWith('export ')) {
      s = s.substring('export '.length).trimLeft();
    }

    final eq = s.indexOf('=');
    if (eq <= 0) continue;

    final key = s.substring(0, eq).trim();
    var value = s.substring(eq + 1).trim();

    if (value.length >= 2) {
      final q = value[0];
      final isQuoted = (q == '"' || q == "'") && value.endsWith(q);
      if (isQuoted) {
        value = value.substring(1, value.length - 1);
      }
    }

    if (key.isEmpty) continue;
    out[key] = value;
  }
  return out;
}

