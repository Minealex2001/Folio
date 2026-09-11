// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visual_style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VisualStyle _$VisualStyleFromJson(Map<String, dynamic> json) => VisualStyle(
  densityMode: json['densityMode'] as String? ?? 'compact',
  densityScale: (json['densityScale'] as num?)?.toDouble() ?? 1.0,
  glassSidebarOpacity: const NullableTokenRefDoubleConverter().fromJson(
    json['glassSidebarOpacity'],
  ),
  glassDialogOpacity: const NullableTokenRefDoubleConverter().fromJson(
    json['glassDialogOpacity'],
  ),
  glassMenuOpacity: const NullableTokenRefDoubleConverter().fromJson(
    json['glassMenuOpacity'],
  ),
  glassPanelOpacity: const NullableTokenRefDoubleConverter().fromJson(
    json['glassPanelOpacity'],
  ),
  borderEnabled: json['borderEnabled'] as bool? ?? false,
  borderWidth: const NullableTokenRefDoubleConverter().fromJson(
    json['borderWidth'],
  ),
  borderOpacity: const NullableTokenRefDoubleConverter().fromJson(
    json['borderOpacity'],
  ),
  windowTitleBar: json['windowTitleBar'] as String? ?? 'native',
  windowCorners: json['windowCorners'] as String?,
  windowBackdrop: json['windowBackdrop'] as String? ?? 'none',
  cursorHover: json['cursorHover'] as String? ?? 'basic',
  cursorResize: json['cursorResize'] as String? ?? 'resizeColumn',
  cursorText: json['cursorText'] as String? ?? 'text',
  iconStyle: json['iconStyle'] as String?,
  iconSize: const NullableTokenRefDoubleConverter().fromJson(json['iconSize']),
  iconStrokeWidth: (json['iconStrokeWidth'] as num?)?.toDouble(),
);

Map<String, dynamic> _$VisualStyleToJson(
  VisualStyle instance,
) => <String, dynamic>{
  'densityMode': instance.densityMode,
  'densityScale': instance.densityScale,
  'glassSidebarOpacity': const NullableTokenRefDoubleConverter().toJson(
    instance.glassSidebarOpacity,
  ),
  'glassDialogOpacity': const NullableTokenRefDoubleConverter().toJson(
    instance.glassDialogOpacity,
  ),
  'glassMenuOpacity': const NullableTokenRefDoubleConverter().toJson(
    instance.glassMenuOpacity,
  ),
  'glassPanelOpacity': const NullableTokenRefDoubleConverter().toJson(
    instance.glassPanelOpacity,
  ),
  'borderEnabled': instance.borderEnabled,
  'borderWidth': const NullableTokenRefDoubleConverter().toJson(
    instance.borderWidth,
  ),
  'borderOpacity': const NullableTokenRefDoubleConverter().toJson(
    instance.borderOpacity,
  ),
  'windowTitleBar': instance.windowTitleBar,
  'windowCorners': instance.windowCorners,
  'windowBackdrop': instance.windowBackdrop,
  'cursorHover': instance.cursorHover,
  'cursorResize': instance.cursorResize,
  'cursorText': instance.cursorText,
  'iconStyle': instance.iconStyle,
  'iconSize': const NullableTokenRefDoubleConverter().toJson(instance.iconSize),
  'iconStrokeWidth': instance.iconStrokeWidth,
};
