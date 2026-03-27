class FolioPageImportInfo {
  FolioPageImportInfo({
    required this.clientAppId,
    required this.clientAppName,
    required this.importedAtMs,
    required this.importMode,
    this.sessionId,
    this.sourceApp,
    this.sourceUrl,
    Map<String, Object?>? metadata,
  }) : metadata = Map<String, Object?>.from(metadata ?? const {});

  final String clientAppId;
  final String clientAppName;
  final int importedAtMs;
  final String importMode;
  final String? sessionId;
  final String? sourceApp;
  final String? sourceUrl;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toJson() => {
    'clientAppId': clientAppId,
    'clientAppName': clientAppName,
    'importedAtMs': importedAtMs,
    'importMode': importMode,
    if (sessionId != null) 'sessionId': sessionId,
    if (sourceApp != null) 'sourceApp': sourceApp,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory FolioPageImportInfo.fromJson(Map<String, dynamic> json) {
    return FolioPageImportInfo(
      clientAppId: json['clientAppId'] as String? ?? 'unknown-client',
      clientAppName: json['clientAppName'] as String? ?? 'Unknown client',
      importedAtMs: (json['importedAtMs'] as num?)?.toInt() ?? 0,
      importMode: json['importMode'] as String? ?? 'newPage',
      sessionId: json['sessionId'] as String?,
      sourceApp: json['sourceApp'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const <String, Object?>{},
    );
  }
}
