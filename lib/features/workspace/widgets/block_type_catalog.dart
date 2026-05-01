import 'package:flutter/material.dart';

const blockTypeCatalog = <BlockTypeDef>[
  BlockTypeDef(
    key: 'paragraph',
    label: 'Texto',
    hint: 'Párrafo',
    icon: Icons.notes_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'child_page',
    label: 'Página',
    hint: 'Subpágina enlazada',
    icon: Icons.description_outlined,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'h1',
    label: 'Encabezado 1',
    hint: 'Título grande  ·  #',
    icon: Icons.looks_one_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'h2',
    label: 'Encabezado 2',
    hint: 'Subtítulo  ·  ##',
    icon: Icons.looks_two_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'h3',
    label: 'Encabezado 3',
    hint: 'Encabezado menor  ·  ###',
    icon: Icons.looks_3_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'quote',
    label: 'Cita',
    hint: 'Texto citado',
    icon: Icons.format_quote_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'divider',
    label: 'Divisor',
    hint: 'Separador  ·  ---',
    icon: Icons.horizontal_rule_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'callout',
    label: 'Bloque destacado',
    hint: 'Aviso con icono',
    icon: Icons.lightbulb_outline_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeDef(
    key: 'bullet',
    label: 'Lista con viñetas',
    hint: 'Lista con puntos',
    icon: Icons.format_list_bulleted_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeDef(
    key: 'numbered',
    label: 'Lista numerada',
    hint: 'Lista 1, 2, 3',
    icon: Icons.format_list_numbered_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeDef(
    key: 'todo',
    label: 'Lista de tareas',
    hint: 'Checklist',
    icon: Icons.check_box_outlined,
    section: BlockTypeSection.lists,
  ),
  BlockTypeDef(
    key: 'task',
    label: 'Tarea enriquecida',
    hint: 'Estado / prioridad / fecha',
    icon: Icons.task_alt_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeDef(
    key: 'toggle',
    label: 'Desplegable',
    hint: 'Mostrar/ocultar contenido',
    icon: Icons.unfold_more_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeDef(
    key: 'image',
    label: 'Imagen',
    hint: 'Imagen local o externa',
    icon: Icons.image_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'bookmark',
    label: 'Marcador con vista previa',
    hint: 'Tarjeta con enlace',
    icon: Icons.bookmark_outline_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'video',
    label: 'Vídeo',
    hint: 'Archivo o enlace',
    icon: Icons.play_circle_outline_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'audio',
    label: 'Audio',
    hint: 'Reproductor de audio',
    icon: Icons.graphic_eq_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'code',
    label: 'Código (Java, Python…)',
    hint: 'Bloque con sintaxis',
    icon: Icons.code_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'file',
    label: 'Archivo / PDF',
    hint: 'Adjunto o PDF',
    icon: Icons.attach_file_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'table',
    label: 'Tabla',
    hint: 'Filas y columnas',
    icon: Icons.table_chart_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'database',
    label: 'Base de datos',
    hint: 'Vista lista/tabla/tablero',
    icon: Icons.dataset_rounded,
    section: BlockTypeSection.media,
    beta: true,
  ),
  BlockTypeDef(
    key: 'equation',
    label: 'Ecuación (LaTeX)',
    hint: 'Fórmulas matemáticas',
    icon: Icons.functions_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'mermaid',
    label: 'Diagrama (Mermaid)',
    hint: 'Diagrama de flujo o esquema',
    icon: Icons.account_tree_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'toc',
    label: 'Tabla de contenidos',
    hint: 'Índice automático',
    icon: Icons.list_alt_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'breadcrumb',
    label: 'Migas de pan',
    hint: 'Ruta de navegación',
    icon: Icons.hiking_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'template_button',
    label: 'Botón de plantilla',
    hint: 'Insertar bloque predefinido',
    icon: Icons.smart_button_outlined,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'column_list',
    label: 'Columnas',
    hint: 'Diseño en columnas',
    icon: Icons.view_column_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'canvas',
    label: 'Lienzo infinito',
    hint: 'Pizarra libre con nodos, formas y flechas',
    icon: Icons.gesture_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'embed',
    label: 'Incrustado web',
    hint: 'YouTube, Figma, Docs…',
    icon: Icons.web_rounded,
    section: BlockTypeSection.embeds,
  ),
];

enum BlockTypeSection { basicText, lists, media, advanced, embeds }

String blockSectionTitle(BlockTypeSection section) {
  switch (section) {
    case BlockTypeSection.basicText:
      return 'Texto básico';
    case BlockTypeSection.lists:
      return 'Listas';
    case BlockTypeSection.media:
      return 'Multimedia y datos';
    case BlockTypeSection.advanced:
      return 'Avanzado y diseño';
    case BlockTypeSection.embeds:
      return 'Integraciones';
  }
}

class BlockTypeDef {
  const BlockTypeDef({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.section,
    this.beta = false,
  });

  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final BlockTypeSection section;
  final bool beta;
}

List<BlockTypeDef> filterBlockTypeCatalog(String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return blockTypeCatalog;
  return blockTypeCatalog.where((definition) {
    return definition.key.contains(normalizedQuery) ||
        definition.label.toLowerCase().contains(normalizedQuery) ||
        definition.hint.toLowerCase().contains(normalizedQuery);
  }).toList();
}
