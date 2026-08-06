/// Fase E0A del rediseño UX del editor — capa estructural ortogonal al
/// modelo de bloques: una [Section] referencia un rango CONTIGUO de bloques
/// existentes en `FolioPage.blocks` (por id de primer/último bloque, no una
/// lista de ids arbitraria — ver `BlockRange`), y guarda metadata propia
/// (icono/color/estado/prioridad/tags/responsable/progreso/colapsado). Los
/// `FolioBlock` referenciados no cambian en absoluto — `Section` no es un
/// tipo de bloque nuevo, es "estructura de documento", como una carpeta que
/// agrupa archivos sin tocarlos.
///
/// Documentos sin secciones (el caso de hoy, `FolioPage.sections == null`)
/// siguen funcionando exactamente igual — el editor sintetiza en memoria una
/// única sección raíz virtual que envuelve todos los bloques, nunca
/// persistida (ver `BlockEditorState` Fase E0C). Nada se escribe a disco
/// hasta que el usuario cree una sección real.
library;

import 'block.dart';
import 'folio_page.dart';

/// Rango contiguo sobre `FolioPage.blocks`, delimitado por el id del primer
/// y del último bloque incluidos (ambos inclusive). Deliberadamente NO una
/// `List<String>` de ids: una sección normalmente contiene bloques
/// consecutivos, no dispersos — un rango es más barato de mover (dos
/// punteros, no una lista a resincronizar en cada edición), usa menos
/// memoria, y es trivial de reconstruir. Si un caso de uso real para
/// bloques no contiguos apareciera, se extendería a `List<BlockRange>` sin
/// romper este caso base.
class BlockRange {
  const BlockRange({required this.firstBlockId, required this.lastBlockId});

  final String firstBlockId;
  final String lastBlockId;

  Map<String, dynamic> toJson() => {
    'firstBlockId': firstBlockId,
    'lastBlockId': lastBlockId,
  };

  factory BlockRange.fromJson(Map<String, dynamic> j) => BlockRange(
    firstBlockId: j['firstBlockId'] as String,
    lastBlockId: j['lastBlockId'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is BlockRange &&
      other.firstBlockId == firstBlockId &&
      other.lastBlockId == lastBlockId;

  @override
  int get hashCode => Object.hash(firstBlockId, lastBlockId);

  @override
  String toString() => 'BlockRange($firstBlockId..$lastBlockId)';
}

/// Metadata de una [Section]. Deliberadamente pequeña y capada — el brief
/// pide "icono/color/estado/prioridad/tags/responsable/progreso", no un
/// esquema de metadata sin límite: `state`/`priority` son enums de texto
/// cerrados (no texto libre), `tags` es libre pero sin schema propio, y no
/// hay campo de comentarios aquí — Folio ya tiene un sistema de comentarios
/// real (`lib/features/workspace/history/comments_panel.dart`); si una
/// sección necesita comentarios, se engancha a ese sistema existente por
/// `sectionId`, no se construye uno nuevo aquí.
class SectionMetadata {
  const SectionMetadata({
    this.icon,
    this.color,
    this.state,
    this.priority,
    this.tags = const [],
    this.assignee,
    this.progress,
    this.collapsed = false,
  });

  final String? icon;

  /// Color ARGB. `null` = sin color asignado (usa el color de tema por defecto).
  final int? color;

  /// 'notStarted' | 'inProgress' | 'done' — capado, no texto libre.
  final String? state;

  /// 'low' | 'medium' | 'high' — capado, no texto libre.
  final String? priority;

  final List<String> tags;

  /// Id o nombre de usuario responsable. Sin schema de usuario propio.
  final String? assignee;

  /// 0.0..1.0. `null` = derivar de bloques de tarea hijos cuando sea
  /// posible (Fase E3); un valor explícito siempre gana.
  final double? progress;

  final bool collapsed;

  SectionMetadata copyWith({
    String? icon,
    bool clearIcon = false,
    int? color,
    bool clearColor = false,
    String? state,
    bool clearState = false,
    String? priority,
    bool clearPriority = false,
    List<String>? tags,
    String? assignee,
    bool clearAssignee = false,
    double? progress,
    bool clearProgress = false,
    bool? collapsed,
  }) {
    return SectionMetadata(
      icon: clearIcon ? null : (icon ?? this.icon),
      color: clearColor ? null : (color ?? this.color),
      state: clearState ? null : (state ?? this.state),
      priority: clearPriority ? null : (priority ?? this.priority),
      tags: tags ?? this.tags,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      progress: clearProgress ? null : (progress ?? this.progress),
      collapsed: collapsed ?? this.collapsed,
    );
  }

  Map<String, dynamic> toJson() => {
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
    if (state != null) 'state': state,
    if (priority != null) 'priority': priority,
    if (tags.isNotEmpty) 'tags': tags,
    if (assignee != null) 'assignee': assignee,
    if (progress != null) 'progress': progress,
    if (collapsed) 'collapsed': true,
  };

  factory SectionMetadata.fromJson(Map<String, dynamic> j) => SectionMetadata(
    icon: j['icon'] as String?,
    color: (j['color'] as num?)?.toInt(),
    state: j['state'] as String?,
    priority: j['priority'] as String?,
    tags: (j['tags'] as List<dynamic>?)?.map((e) => '$e').toList() ?? const [],
    assignee: j['assignee'] as String?,
    progress: (j['progress'] as num?)?.toDouble(),
    collapsed: (j['collapsed'] as bool?) ?? false,
  );
}

class Section {
  Section({
    required this.id,
    required this.title,
    required this.range,
    this.metadata = const SectionMetadata(),
  });

  final String id;
  String title;
  BlockRange range;
  SectionMetadata metadata;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'range': range.toJson(),
    if (metadata.toJson().isNotEmpty) 'metadata': metadata.toJson(),
  };

  factory Section.fromJson(Map<String, dynamic> j) => Section(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    range: BlockRange.fromJson(Map<String, dynamic>.from(j['range'] as Map)),
    metadata: j['metadata'] is Map
        ? SectionMetadata.fromJson(Map<String, dynamic>.from(j['metadata'] as Map))
        : const SectionMetadata(),
  );
}

/// Resuelve un [BlockRange] contra `page.blocks` por posición (no requiere
/// que los ids sean contiguos en el propio rango de índices más allá de que
/// `firstBlockId` aparezca antes o en la misma posición que `lastBlockId`).
/// Casos borde, todos devolviendo listas vacías en vez de lanzar (un rango
/// con un id borrado no debe romper el render, solo dejar de mostrar nada
/// para esa sección hasta que E0B recalcule el rango):
/// - `firstBlockId`/`lastBlockId` no encontrados en `page.blocks`.
/// - `lastBlockId` aparece antes que `firstBlockId` (rango invertido/corrupto).
List<FolioBlock> blocksInRange(FolioPage page, BlockRange range) {
  final firstIdx = page.blocks.indexWhere((b) => b.id == range.firstBlockId);
  if (firstIdx < 0) return const [];
  final lastIdx = page.blocks.indexWhere(
    (b) => b.id == range.lastBlockId,
    firstIdx,
  );
  if (lastIdx < firstIdx) return const [];
  return page.blocks.sublist(firstIdx, lastIdx + 1);
}
