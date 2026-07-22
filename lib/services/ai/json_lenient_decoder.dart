import 'dart:convert';

/// Decodifica un objeto JSON tolerando texto extra alrededor (p. ej. cuando
/// un modelo envuelve su respuesta en prosa o en fences de markdown pese a
/// que se le pidió JSON puro). Si el `jsonDecode` directo falla, recorta
/// desde la primera `{` hasta la última `}` y reintenta.
///
/// Compartido entre el camino JSON legado de `agentChatWithAi`
/// (`vault_session_ai.dart`) y la emulación de tool-calling
/// (`ai_tool_json_emulation.dart`) para proveedores/modelos sin `tools` nativo.
Map<String, dynamic> decodeJsonObjectLenient(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    final first = raw.indexOf('{');
    final last = raw.lastIndexOf('}');
    if (first >= 0 && last > first) {
      final slice = raw.substring(first, last + 1);
      return jsonDecode(slice) as Map<String, dynamic>;
    }
    rethrow;
  }
}
