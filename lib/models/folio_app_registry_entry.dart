import 'dart:convert';

/// Entrada en el registry público de la tienda de apps de Folio.
class FolioAppRegistryEntry {
  const FolioAppRegistryEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.iconUrl,
    required this.downloadUrl,
    this.tags = const [],
    this.verifiedByFolio = false,
    this.installs = 0,
    this.rating = 0.0,
    this.websiteUrl = '',
    this.changelog = '',
  });

  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String iconUrl;
  final String downloadUrl;
  final List<String> tags;
  final bool verifiedByFolio;
  final int installs;
  final double rating;
  final String websiteUrl;
  final String changelog;

  factory FolioAppRegistryEntry.fromJson(Map<String, dynamic> json) {
    return FolioAppRegistryEntry(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      author: (json['author'] as String? ?? '').trim(),
      version: (json['version'] as String? ?? '').trim(),
      iconUrl: (json['iconUrl'] as String? ?? '').trim(),
      downloadUrl: (json['downloadUrl'] as String? ?? '').trim(),
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      verifiedByFolio: (json['verifiedByFolio'] as bool?) ?? false,
      installs: (json['installs'] as int?) ?? 0,
      rating: ((json['rating'] as num?) ?? 0.0).toDouble(),
      websiteUrl: (json['websiteUrl'] as String? ?? '').trim(),
      changelog: (json['changelog'] as String? ?? '').trim(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'author': author,
    'version': version,
    'iconUrl': iconUrl,
    'downloadUrl': downloadUrl,
    if (tags.isNotEmpty) 'tags': tags,
    'verifiedByFolio': verifiedByFolio,
    'installs': installs,
    'rating': rating,
    if (websiteUrl.isNotEmpty) 'websiteUrl': websiteUrl,
    if (changelog.isNotEmpty) 'changelog': changelog,
  };
}

/// El registry completo: lista de entradas con metadatos opcionales del feed.
class FolioAppRegistry {
  const FolioAppRegistry({
    required this.apps,
    this.updatedAt,
    this.feedVersion = 1,
  });

  final List<FolioAppRegistryEntry> apps;
  final DateTime? updatedAt;
  final int feedVersion;

  factory FolioAppRegistry.fromJson(Map<String, dynamic> json) {
    return FolioAppRegistry(
      apps:
          (json['apps'] as List?)
              ?.map(
                (e) => FolioAppRegistryEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      feedVersion: (json['feedVersion'] as int?) ?? 1,
    );
  }

  factory FolioAppRegistry.fromJsonString(String raw) {
    return FolioAppRegistry.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  static const FolioAppRegistry empty = FolioAppRegistry(apps: []);
}
