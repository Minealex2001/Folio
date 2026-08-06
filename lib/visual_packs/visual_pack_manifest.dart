import 'package:pub_semver/pub_semver.dart';

import '../config/json_schema_version.dart';

/// Plataformas donde este pack se recomienda instalar (Fase 32, anexo del
/// brief) — todos `true` por defecto (sin restricción). Pensado para
/// efectos que no tienen sentido en todas partes (ej. backdrop blur de
/// ventana en Android) — ver `platform_capability_resolver.dart`.
class PlatformSupport {
  const PlatformSupport({
    this.supportsDesktop = true,
    this.supportsMobile = true,
    this.supportsWeb = true,
  });

  final bool supportsDesktop;
  final bool supportsMobile;
  final bool supportsWeb;

  factory PlatformSupport.fromJson(Map<String, dynamic> json) {
    return PlatformSupport(
      supportsDesktop: json['supportsDesktop'] as bool? ?? true,
      supportsMobile: json['supportsMobile'] as bool? ?? true,
      supportsWeb: json['supportsWeb'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'supportsDesktop': supportsDesktop,
    'supportsMobile': supportsMobile,
    'supportsWeb': supportsWeb,
  };
}

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
    this.minAppVersion,
    this.maxAppVersion,
    this.platformSupport,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String? author;
  final String version;

  /// Compatibilidad con la versión de Folio (Fase 32, marketplace) — `null`
  /// = sin restricción. Todos los packs builtin se quedan `null`.
  final String? minAppVersion;
  final String? maxAppVersion;

  /// `null` = sin restricción de plataforma (equivalente a
  /// `PlatformSupport()` con los tres flags en `true`).
  final PlatformSupport? platformSupport;

  factory VisualPackManifest.fromJson(Map<String, dynamic> json) {
    return VisualPackManifest(
      schemaVersion: json['schemaVersion'] as int? ?? kFolioConfigSchemaVersion,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String?,
      version: json['version'] as String? ?? '1.0.0',
      minAppVersion: json['minAppVersion'] as String?,
      maxAppVersion: json['maxAppVersion'] as String?,
      platformSupport: json['platformSupport'] == null
          ? null
          : PlatformSupport.fromJson(
              json['platformSupport'] as Map<String, dynamic>,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'description': description,
    if (author != null) 'author': author,
    'version': version,
    if (minAppVersion != null) 'minAppVersion': minAppVersion,
    if (maxAppVersion != null) 'maxAppVersion': maxAppVersion,
    if (platformSupport != null) 'platformSupport': platformSupport!.toJson(),
  };

  /// `true` si [currentAppVersion] cae dentro de
  /// `[minAppVersion, maxAppVersion]` (límites inclusivos, cualquiera de
  /// los dos puede ser `null` = sin límite en ese extremo). Una versión de
  /// app no parseable, o límites no parseables, se tratan como
  /// compatibles — degradar es más seguro que bloquear una instalación por
  /// un string de versión inesperado.
  bool isCompatible(String currentAppVersion) {
    final current = _tryParse(currentAppVersion);
    if (current == null) return true;

    final min = minAppVersion == null ? null : _tryParse(minAppVersion!);
    if (min != null && current < min) return false;

    final max = maxAppVersion == null ? null : _tryParse(maxAppVersion!);
    if (max != null && current > max) return false;

    return true;
  }

  static Version? _tryParse(String value) {
    try {
      return Version.parse(value);
    } on FormatException {
      return null;
    }
  }
}
