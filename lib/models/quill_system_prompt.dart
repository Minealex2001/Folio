class QuillSystemPrompt {
  final String id;
  final String name;
  final String prompt;
  final bool isSystemDefault;

  QuillSystemPrompt({
    required this.id,
    required this.name,
    required this.prompt,
    this.isSystemDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        'isSystemDefault': isSystemDefault,
      };

  factory QuillSystemPrompt.fromJson(Map<String, dynamic> json) {
    return QuillSystemPrompt(
      id: json['id'] as String,
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      isSystemDefault: json['isSystemDefault'] as bool? ?? false,
    );
  }

  QuillSystemPrompt copyWith({
    String? id,
    String? name,
    String? prompt,
    bool? isSystemDefault,
  }) {
    return QuillSystemPrompt(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
    );
  }
}
