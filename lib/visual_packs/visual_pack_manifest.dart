import '../config/json_schema_version.dart';

/// Metadatos de un pack visual — separado de `theme`/`layout`/`dashboard`
/// (Fase 8 del plan de personalización) para que un bundle exportado sea
/// legible sin tener que deserializar los tres documentos completos.
class VisualPackManifest {
  const VisualPackManifest({
    this.schemaVersion = kFolioConfigSchemaVersion,
    required this.id,
    required this.name,
    required this.description,
    this.author,
    this.version = '1.0.0',
  });

  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String? author;
  final String version;

  factory VisualPackManifest.fromJson(Map<String, dynamic> json) {
    return VisualPackManifest(
      schemaVersion: json['schemaVersion'] as int? ?? kFolioConfigSchemaVersion,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String?,
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'description': description,
    if (author != null) 'author': author,
    'version': version,
  };
}
