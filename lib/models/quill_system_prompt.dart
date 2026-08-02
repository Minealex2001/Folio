class QuillSystemPrompt {
  final String id;
  final String name;
  final String prompt;
  final bool isSystemDefault;

  /// Marca presets de tarea acotada (traducir, resumir, código) cuyo texto
  /// debe añadirse SOBRE la identidad general de Quill en vez de
  /// reemplazarla por completo, para que una instrucción de "sé conciso"
  /// del preset no anule silenciosamente "sé completo por defecto".
  /// Los presets generales/creados por el usuario quedan en `false` para
  /// conservar el reemplazo total (p. ej. un preset propio de "sé breve").
  final bool isNarrowTask;

  QuillSystemPrompt({
    required this.id,
    required this.name,
    required this.prompt,
    this.isSystemDefault = false,
    this.isNarrowTask = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        'isSystemDefault': isSystemDefault,
        'isNarrowTask': isNarrowTask,
      };

  factory QuillSystemPrompt.fromJson(Map<String, dynamic> json) {
    return QuillSystemPrompt(
      id: json['id'] as String,
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      isSystemDefault: json['isSystemDefault'] as bool? ?? false,
      isNarrowTask: json['isNarrowTask'] as bool? ?? false,
    );
  }

  QuillSystemPrompt copyWith({
    String? id,
    String? name,
    String? prompt,
    bool? isSystemDefault,
    bool? isNarrowTask,
  }) {
    return QuillSystemPrompt(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
      isNarrowTask: isNarrowTask ?? this.isNarrowTask,
    );
  }
}
