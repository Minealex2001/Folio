import 'dart:convert';

import 'folio_app_package.dart';

/// Registro de una app instalada localmente en el dispositivo.
class InstalledFolioApp {
  InstalledFolioApp({
    required this.package,
    required this.installedAt,
    this.localPath,
    this.enabled = true,
    this.grantedPermissions = const [],
  });

  final FolioAppPackage package;
  final DateTime installedAt;

  /// Ruta absoluta al directorio extraído del .folioapp.
  final String? localPath;

  bool enabled;
  final List<FolioAppPermission> grantedPermissions;

  factory InstalledFolioApp.fromJson(Map<String, dynamic> json) {
    return InstalledFolioApp(
      package: FolioAppPackage.fromJson(
        Map<String, dynamic>.from(json['package'] as Map),
      ),
      installedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['installedAtMs'] as int?) ?? 0,
      ),
      localPath: json['localPath'] as String?,
      enabled: (json['enabled'] as bool?) ?? true,
      grantedPermissions:
          (json['grantedPermissions'] as List?)
              ?.cast<String>()
              .map(
                (s) => switch (s.toLowerCase()) {
                  'clipboard' => FolioAppPermission.clipboard,
                  'filesystem' ||
                  'file_system' => FolioAppPermission.fileSystem,
                  'camera' => FolioAppPermission.camera,
                  _ => FolioAppPermission.internet,
                },
              )
              .toList() ??
          const [],
    );
  }

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'installedAtMs': installedAt.millisecondsSinceEpoch,
    if (localPath != null) 'localPath': localPath,
    'enabled': enabled,
    if (grantedPermissions.isNotEmpty)
      'grantedPermissions': grantedPermissions
          .map(
            (p) => switch (p) {
              FolioAppPermission.internet => 'internet',
              FolioAppPermission.clipboard => 'clipboard',
              FolioAppPermission.fileSystem => 'file_system',
              FolioAppPermission.camera => 'camera',
            },
          )
          .toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  InstalledFolioApp copyWith({bool? enabled}) {
    return InstalledFolioApp(
      package: package,
      installedAt: installedAt,
      localPath: localPath,
      enabled: enabled ?? this.enabled,
      grantedPermissions: grantedPermissions,
    );
  }
}
