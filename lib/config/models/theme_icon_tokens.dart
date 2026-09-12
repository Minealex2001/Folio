import 'package:json_annotation/json_annotation.dart';

part 'theme_icon_tokens.g.dart';

@JsonSerializable()
class ThemeIconTokens {
  ThemeIconTokens({this.iconPackId = 'material_rounded'});

  /// Id de icon pack instalado (Fase 8) o uno de los bundled por defecto.
  final String iconPackId;

  factory ThemeIconTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeIconTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeIconTokensToJson(this);
}
