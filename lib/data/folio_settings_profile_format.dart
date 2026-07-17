import 'dart:convert';

/// Formato de perfil de ajustes Folio Cloud (app o libreta).
const int kFolioSettingsProfileFormatVersion = 1;

enum FolioSettingsProfileKind { app, vault }

String folioSettingsProfileKindWire(FolioSettingsProfileKind k) {
  switch (k) {
    case FolioSettingsProfileKind.app:
      return 'app';
    case FolioSettingsProfileKind.vault:
      return 'vault';
  }
}

FolioSettingsProfileKind? folioSettingsProfileKindParse(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'app':
      return FolioSettingsProfileKind.app;
    case 'vault':
      return FolioSettingsProfileKind.vault;
    default:
      return null;
  }
}

/// Referencia a un icono custom (sin ruta absoluta local).
class FolioSettingsIconRef {
  const FolioSettingsIconRef({
    required this.id,
    required this.label,
    required this.source,
    required this.mimeType,
    required this.createdAtMs,
  });

  final String id;
  final String label;
  final String source;
  final String mimeType;
  final int createdAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'source': source,
        'mimeType': mimeType,
        'createdAtMs': createdAtMs,
      };

  factory FolioSettingsIconRef.fromJson(Map raw) {
    return FolioSettingsIconRef(
      id: (raw['id'] as String? ?? '').trim(),
      label: (raw['label'] as String? ?? '').trim(),
      source: (raw['source'] as String? ?? '').trim(),
      mimeType: (raw['mimeType'] as String? ?? '').trim(),
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Perfil en claro (antes de cifrar el pack).
class FolioSettingsProfile {
  const FolioSettingsProfile({
    this.formatVersion = kFolioSettingsProfileFormatVersion,
    required this.kind,
    required this.settings,
    this.secrets = const {},
    this.icons = const [],
    this.integrationIconsByApp = const {},
    this.vaultId,
    this.exportedAtMs = 0,
  });

  final int formatVersion;
  final FolioSettingsProfileKind kind;
  final Map<String, Object?> settings;
  final Map<String, String> secrets;
  final List<FolioSettingsIconRef> icons;
  final Map<String, List<FolioSettingsIconRef>> integrationIconsByApp;
  final String? vaultId;
  final int exportedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'formatVersion': formatVersion,
        'kind': folioSettingsProfileKindWire(kind),
        'settings': settings,
        if (secrets.isNotEmpty) 'secrets': secrets,
        if (icons.isNotEmpty)
          'icons': icons.map((e) => e.toJson()).toList(growable: false),
        if (integrationIconsByApp.isNotEmpty)
          'integrationIconsByApp': {
            for (final e in integrationIconsByApp.entries)
              e.key: e.value.map((i) => i.toJson()).toList(growable: false),
          },
        if (vaultId != null && vaultId!.isNotEmpty) 'vaultId': vaultId,
        if (exportedAtMs > 0) 'exportedAtMs': exportedAtMs,
      };

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  factory FolioSettingsProfile.fromJson(Map<String, dynamic> j) {
    final kind = folioSettingsProfileKindParse(j['kind']?.toString()) ??
        FolioSettingsProfileKind.app;
    final settingsRaw = j['settings'];
    final settings = <String, Object?>{};
    if (settingsRaw is Map) {
      for (final e in settingsRaw.entries) {
        settings['${e.key}'] = e.value;
      }
    }
    final secrets = <String, String>{};
    final secretsRaw = j['secrets'];
    if (secretsRaw is Map) {
      for (final e in secretsRaw.entries) {
        final v = e.value;
        if (v is String && v.isNotEmpty) {
          secrets['${e.key}'] = v;
        }
      }
    }
    final icons = <FolioSettingsIconRef>[];
    final iconsRaw = j['icons'];
    if (iconsRaw is List) {
      for (final item in iconsRaw) {
        if (item is Map) {
          final ref = FolioSettingsIconRef.fromJson(item);
          if (ref.id.isNotEmpty) icons.add(ref);
        }
      }
    }
    final integrationIcons = <String, List<FolioSettingsIconRef>>{};
    final integRaw = j['integrationIconsByApp'];
    if (integRaw is Map) {
      for (final e in integRaw.entries) {
        final key = '${e.key}'.trim();
        if (key.isEmpty || e.value is! List) continue;
        final list = <FolioSettingsIconRef>[];
        for (final item in e.value as List) {
          if (item is Map) {
            final ref = FolioSettingsIconRef.fromJson(item);
            if (ref.id.isNotEmpty) list.add(ref);
          }
        }
        if (list.isNotEmpty) {
          integrationIcons[key] = list;
        }
      }
    }
    return FolioSettingsProfile(
      formatVersion:
          (j['formatVersion'] as num?)?.toInt() ?? kFolioSettingsProfileFormatVersion,
      kind: kind,
      settings: settings,
      secrets: secrets,
      icons: icons,
      integrationIconsByApp: integrationIcons,
      vaultId: (j['vaultId'] as String?)?.trim(),
      exportedAtMs: (j['exportedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  static FolioSettingsProfile decodeUtf8(List<int> bytes) {
    final map = jsonDecode(utf8.decode(bytes));
    if (map is! Map) {
      throw FormatException('Settings profile inválido');
    }
    return FolioSettingsProfile.fromJson(Map<String, dynamic>.from(map));
  }
}
