import 'dart:convert';

/// Preferencias de la integración «Media del sistema» (SMTC / MediaSession / MPRIS).
class SystemMediaIntegrationState {
  const SystemMediaIntegrationState({
    this.enabled = false,
    this.zenPauseOnExit = true,
  });

  final bool enabled;
  final bool zenPauseOnExit;

  static const SystemMediaIntegrationState empty = SystemMediaIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'zenPauseOnExit': zenPauseOnExit,
      };

  static SystemMediaIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    return SystemMediaIntegrationState(
      enabled: m['enabled'] == true,
      zenPauseOnExit: m['zenPauseOnExit'] != false,
    );
  }

  String encode() => jsonEncode(toJson());

  SystemMediaIntegrationState copyWith({
    bool? enabled,
    bool? zenPauseOnExit,
  }) {
    return SystemMediaIntegrationState(
      enabled: enabled ?? this.enabled,
      zenPauseOnExit: zenPauseOnExit ?? this.zenPauseOnExit,
    );
  }
}
