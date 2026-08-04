import 'package:json_annotation/json_annotation.dart';

part 'theme_elevation_tokens.g.dart';

@JsonSerializable()
class ThemeElevationTokens {
  ThemeElevationTokens({
    this.none = 0,
    this.appBarScrolled = 1,
    this.menu = 4,
    this.shadowOpacity = 0.08,
  });

  final double none;
  final double appBarScrolled;
  final double menu;

  /// Opacidad base de sombra (mapea a `FolioAlpha.faint` hoy).
  final double shadowOpacity;

  factory ThemeElevationTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeElevationTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeElevationTokensToJson(this);
}
