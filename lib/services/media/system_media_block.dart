import 'dart:convert';

/// Serializa el payload de un bloque `systemMedia` (JSON).
String encodeSystemMediaBlockText(Map<String, Object?> payload) =>
    jsonEncode(payload);

/// Deserializa el texto de un bloque `systemMedia`.
Map<String, Object?> decodeSystemMediaBlockText(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {}
  return const {};
}
