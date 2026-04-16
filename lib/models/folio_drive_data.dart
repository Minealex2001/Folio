import 'dart:convert';

enum FolioDriveViewType { grid, list }

/// Carpeta visual dentro del bloque drive. No crea páginas hijas reales.
class FolioDriveFolder {
  FolioDriveFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.colorValue,
  });

  final String id;
  final String name;

  /// null = carpeta raíz.
  final String? parentId;

  /// Color ARGB del icono de carpeta. null = usar color primario del tema.
  final int? colorValue;

  FolioDriveFolder copyWith({
    String? id,
    String? name,
    Object? parentId = _sentinel,
    Object? colorValue = _sentinel,
  }) {
    return FolioDriveFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      colorValue: colorValue == _sentinel
          ? this.colorValue
          : colorValue as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (parentId != null) 'parentId': parentId,
    if (colorValue != null) 'colorValue': colorValue,
  };

  static FolioDriveFolder? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as String? ?? '').trim();
    final name = (raw['name'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    return FolioDriveFolder(
      id: id,
      name: name,
      parentId: raw['parentId'] as String?,
      colorValue: raw['colorValue'] as int?,
    );
  }

  static const Object _sentinel = Object();
}

/// Tipo de archivo almacenado en el drive.
enum FolioDriveFileType { file, image, video, audio }

/// Detecta el tipo a partir de la extensión del nombre/url.
FolioDriveFileType folioDriveFileTypeFromExtension(String name) {
  final ext = name.toLowerCase().split('.').last;
  const images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'svg'};
  const videos = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', 'flv'};
  const audios = {'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus'};
  if (images.contains(ext)) return FolioDriveFileType.image;
  if (videos.contains(ext)) return FolioDriveFileType.video;
  if (audios.contains(ext)) return FolioDriveFileType.audio;
  return FolioDriveFileType.file;
}

String folioDriveFileTypeName(FolioDriveFileType t) {
  switch (t) {
    case FolioDriveFileType.file:
      return 'file';
    case FolioDriveFileType.image:
      return 'image';
    case FolioDriveFileType.video:
      return 'video';
    case FolioDriveFileType.audio:
      return 'audio';
  }
}

FolioDriveFileType folioDriveFileTypeFromName(String? name) {
  switch (name) {
    case 'image':
      return FolioDriveFileType.image;
    case 'video':
      return FolioDriveFileType.video;
    case 'audio':
      return FolioDriveFileType.audio;
    default:
      return FolioDriveFileType.file;
  }
}

/// Entrada de archivo en el bloque drive.
class FolioDriveEntry {
  FolioDriveEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.fileType,
    this.folderId,
    this.sizeBytes,
    this.addedAtMs,
    this.sourcePageId,
    this.sourceBlockId,
  });

  final String id;
  final String name;

  /// Ruta relativa del vault (`attachments/uuid.ext`) o URI remota.
  final String url;

  final FolioDriveFileType fileType;

  /// null = carpeta raíz.
  final String? folderId;
  final int? sizeBytes;
  final int? addedAtMs;

  /// Si fue importado de otro bloque del vault, se conserva la referencia.
  final String? sourcePageId;
  final String? sourceBlockId;

  /// true si el archivo fue subido directamente en este drive (no importado).
  bool get isOwnAttachment =>
      sourcePageId == null && url.startsWith('attachments/');

  FolioDriveEntry copyWith({
    String? id,
    String? name,
    String? url,
    FolioDriveFileType? fileType,
    Object? folderId = _sentinel,
    int? sizeBytes,
    int? addedAtMs,
    Object? sourcePageId = _sentinel,
    Object? sourceBlockId = _sentinel,
  }) {
    return FolioDriveEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      fileType: fileType ?? this.fileType,
      folderId: folderId == _sentinel ? this.folderId : folderId as String?,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      sourcePageId: sourcePageId == _sentinel
          ? this.sourcePageId
          : sourcePageId as String?,
      sourceBlockId: sourceBlockId == _sentinel
          ? this.sourceBlockId
          : sourceBlockId as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'fileType': folioDriveFileTypeName(fileType),
    if (folderId != null) 'folderId': folderId,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (addedAtMs != null) 'addedAtMs': addedAtMs,
    if (sourcePageId != null) 'sourcePageId': sourcePageId,
    if (sourceBlockId != null) 'sourceBlockId': sourceBlockId,
  };

  static FolioDriveEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as String? ?? '').trim();
    final name = (raw['name'] as String? ?? '').trim();
    final url = (raw['url'] as String? ?? '').trim();
    if (id.isEmpty || url.isEmpty) return null;
    return FolioDriveEntry(
      id: id,
      name: name.isEmpty ? url.split('/').last : name,
      url: url,
      fileType: folioDriveFileTypeFromName(raw['fileType'] as String?),
      folderId: raw['folderId'] as String?,
      sizeBytes: raw['sizeBytes'] is num
          ? (raw['sizeBytes'] as num).toInt()
          : null,
      addedAtMs: raw['addedAtMs'] is num
          ? (raw['addedAtMs'] as num).toInt()
          : null,
      sourcePageId: raw['sourcePageId'] as String?,
      sourceBlockId: raw['sourceBlockId'] as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Configuración JSON del bloque `drive` ([FolioBlock.text]).
class FolioFileDriveData {
  FolioFileDriveData({
    this.v = 1,
    this.viewType = FolioDriveViewType.grid,
    List<FolioDriveFolder>? folders,
    List<FolioDriveEntry>? entries,
  }) : folders = List.unmodifiable(folders ?? const []),
       entries = List.unmodifiable(entries ?? const []);

  final int v;
  final FolioDriveViewType viewType;
  final List<FolioDriveFolder> folders;
  final List<FolioDriveEntry> entries;

  static FolioFileDriveData defaults() => FolioFileDriveData();

  FolioFileDriveData copyWith({
    int? v,
    FolioDriveViewType? viewType,
    List<FolioDriveFolder>? folders,
    List<FolioDriveEntry>? entries,
  }) {
    return FolioFileDriveData(
      v: v ?? this.v,
      viewType: viewType ?? this.viewType,
      folders: folders ?? this.folders,
      entries: entries ?? this.entries,
    );
  }

  /// Devuelve true si mover [folder] a [newParentId] crearía un ciclo.
  bool wouldCreateCycle(String folderId, String? newParentId) {
    if (newParentId == null) return false;
    if (newParentId == folderId) return true;
    // Sube por el árbol a partir de newParentId.
    final byId = {for (final f in folders) f.id: f};
    String? cursor = newParentId;
    while (cursor != null) {
      if (cursor == folderId) return true;
      cursor = byId[cursor]?.parentId;
    }
    return false;
  }

  String encode() => jsonEncode({
    'v': v,
    'viewType': viewType.name,
    'folders': folders.map((f) => f.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  });

  static FolioFileDriveData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioFileDriveData.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final rawViewType = (m['viewType'] as String?)?.trim().toLowerCase();
      final viewType = FolioDriveViewType.values.firstWhere(
        (e) => e.name == rawViewType,
        orElse: () => FolioDriveViewType.grid,
      );
      final rawFolders = m['folders'];
      final folders = <FolioDriveFolder>[];
      if (rawFolders is List) {
        for (final f in rawFolders) {
          final folder = FolioDriveFolder.tryParse(f);
          if (folder != null) folders.add(folder);
        }
      }
      final rawEntries = m['entries'];
      final entries = <FolioDriveEntry>[];
      if (rawEntries is List) {
        for (final e in rawEntries) {
          final entry = FolioDriveEntry.tryParse(e);
          if (entry != null) entries.add(entry);
        }
      }
      return FolioFileDriveData(
        v: (m['v'] as num?)?.toInt() ?? 1,
        viewType: viewType,
        folders: folders,
        entries: entries,
      );
    } catch (_) {
      return null;
    }
  }
}
