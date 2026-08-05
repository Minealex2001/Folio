import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';

part 'accessibility_config.g.dart';

/// Preferencias de accesibilidad (Fase 22, punto 11 del brief) —
/// transversales al usuario, no por-tema, así que viven en su propia
/// categoría de [ConfigStore] en vez de anidadas en [ThemeConfig] (mismo
/// tratamiento que `AppSettings.uiScale` hoy).
@JsonSerializable()
class AccessibilityConfig {
  AccessibilityConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    this.contrast = 'normal',
    this.reduceMotion = false,
    this.largeHitTargets = false,
  });

  final int schemaVersion;

  /// 'normal' | 'high'.
  final String contrast;
  final bool reduceMotion;
  final bool largeHitTargets;

  factory AccessibilityConfig.fromJson(Map<String, dynamic> json) =>
      _$AccessibilityConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AccessibilityConfigToJson(this);

  AccessibilityConfig copyWith({
    String? contrast,
    bool? reduceMotion,
    bool? largeHitTargets,
  }) {
    return AccessibilityConfig(
      schemaVersion: schemaVersion,
      contrast: contrast ?? this.contrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      largeHitTargets: largeHitTargets ?? this.largeHitTargets,
    );
  }
}
