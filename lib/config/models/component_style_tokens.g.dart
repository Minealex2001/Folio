// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_style_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComponentStyleEntry _$ComponentStyleEntryFromJson(
  Map<String, dynamic> json,
) => ComponentStyleEntry(
  radius: const NullableTokenRefDoubleConverter().fromJson(json['radius']),
  border: json['border'] as bool?,
  shadow: json['shadow'] as bool?,
  backgroundColor: const NullableTokenRefIntConverter().fromJson(
    json['backgroundColor'],
  ),
  opacity: const NullableTokenRefDoubleConverter().fromJson(json['opacity']),
  states: json['states'] == null
      ? null
      : ComponentStateStyle.fromJson(json['states'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ComponentStyleEntryToJson(
  ComponentStyleEntry instance,
) => <String, dynamic>{
  'radius': const NullableTokenRefDoubleConverter().toJson(instance.radius),
  'border': instance.border,
  'shadow': instance.shadow,
  'backgroundColor': const NullableTokenRefIntConverter().toJson(
    instance.backgroundColor,
  ),
  'opacity': const NullableTokenRefDoubleConverter().toJson(instance.opacity),
  'states': instance.states?.toJson(),
};

ComponentStyleTokens _$ComponentStyleTokensFromJson(
  Map<String, dynamic> json,
) => ComponentStyleTokens(
  components:
      (json['components'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          ComponentStyleEntry.fromJson(e as Map<String, dynamic>),
        ),
      ) ??
      const {},
);

Map<String, dynamic> _$ComponentStyleTokensToJson(
  ComponentStyleTokens instance,
) => <String, dynamic>{
  'components': instance.components.map((k, e) => MapEntry(k, e.toJson())),
};
