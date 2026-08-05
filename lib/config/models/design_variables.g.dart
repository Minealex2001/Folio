// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_variables.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignVariables _$DesignVariablesFromJson(Map<String, dynamic> json) =>
    DesignVariables(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
      id: json['id'] as String? ?? 'default',
      entries:
          (json['entries'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$DesignVariablesToJson(DesignVariables instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'entries': instance.entries,
    };
