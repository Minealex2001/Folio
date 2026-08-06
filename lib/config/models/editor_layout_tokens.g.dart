// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_layout_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EditorLayoutTokens _$EditorLayoutTokensFromJson(Map<String, dynamic> json) =>
    EditorLayoutTokens(
      lineHeightScale: (json['lineHeightScale'] as num?)?.toDouble() ?? 1.0,
      blockSpacing: const NullableTokenRefDoubleConverter().fromJson(
        json['blockSpacing'],
      ),
      cursorWidth: (json['cursorWidth'] as num?)?.toDouble() ?? 2.0,
      cursorBlink: json['cursorBlink'] as bool? ?? true,
      selectionColor: const NullableTokenRefIntConverter().fromJson(
        json['selectionColor'],
      ),
      selectionRadius: const NullableTokenRefDoubleConverter().fromJson(
        json['selectionRadius'],
      ),
      selectionAnimated: json['selectionAnimated'] as bool? ?? true,
      markdownSymbolVisibility:
          json['markdownSymbolVisibility'] as String? ?? 'editingOnly',
      calloutStyle: json['calloutStyle'] as String? ?? 'notion',
    );

Map<String, dynamic> _$EditorLayoutTokensToJson(EditorLayoutTokens instance) =>
    <String, dynamic>{
      'lineHeightScale': instance.lineHeightScale,
      'blockSpacing': const NullableTokenRefDoubleConverter().toJson(
        instance.blockSpacing,
      ),
      'cursorWidth': instance.cursorWidth,
      'cursorBlink': instance.cursorBlink,
      'selectionColor': const NullableTokenRefIntConverter().toJson(
        instance.selectionColor,
      ),
      'selectionRadius': const NullableTokenRefDoubleConverter().toJson(
        instance.selectionRadius,
      ),
      'selectionAnimated': instance.selectionAnimated,
      'markdownSymbolVisibility': instance.markdownSymbolVisibility,
      'calloutStyle': instance.calloutStyle,
    };
