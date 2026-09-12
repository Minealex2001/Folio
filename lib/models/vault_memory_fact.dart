/// Fase A4 del plan Quill/MCP — hechos duraderos que Quill incluye
/// automáticamente como contexto en cada llamada, pero que **solo el
/// usuario puede escribir** (vía el botón "Guardar como hecho" de
/// `IntentActionBar`, Fase A2) — nunca una tool que la IA invoque sola, para
/// no violar la disciplina de "nunca escritura silenciosa" ya presente en
/// el resto de la app (aprobación de clientes MCP, allowlists de lectura).
enum MemoryFactScope { temporary, permanent }

class VaultMemoryFact {
  const VaultMemoryFact({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.scope,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  /// `temporary`: hechos que solo importan durante un sprint/proyecto
  /// puntual — fáciles de limpiar en bloque. `permanent`: viven hasta que el
  /// usuario los borra a mano, igual que los presets de `QuillSystemPrompt`.
  /// La distinción es solo de gestión — ambos se envían igual como contexto.
  final MemoryFactScope scope;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'scope': scope.name,
      };

  factory VaultMemoryFact.fromJson(Map<String, dynamic> json) {
    return VaultMemoryFact(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      scope: MemoryFactScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => MemoryFactScope.permanent,
      ),
    );
  }

  VaultMemoryFact copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    MemoryFactScope? scope,
  }) {
    return VaultMemoryFact(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      scope: scope ?? this.scope,
    );
  }
}
