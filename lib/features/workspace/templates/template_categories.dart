import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Taxonomía fija de categorías de plantillas de página. Misma lista que
/// `CommunityTemplatesService.CATEGORY_IDS` en el backend — no hay codegen
/// compartido entre ambos repos, mantener sincronizadas a mano.
const List<String> kFolioTemplateCategoryIds = [
  'personal',
  'work',
  'meetings',
  'projects',
  'study',
  'habits',
  'journal',
  'finance',
  'health',
  'travel',
  'recipes',
  'writing',
  'software',
  'other',
];

const String kFolioTemplateCategoryOther = 'other';

/// Nombre localizado de una categoría de la taxonomía fija.
String templateCategoryLabel(AppLocalizations l10n, String categoryId) {
  switch (categoryId) {
    case 'personal':
      return l10n.templateCategoryPersonal;
    case 'work':
      return l10n.templateCategoryWork;
    case 'meetings':
      return l10n.templateCategoryMeetings;
    case 'projects':
      return l10n.templateCategoryProjects;
    case 'study':
      return l10n.templateCategoryStudy;
    case 'habits':
      return l10n.templateCategoryHabits;
    case 'journal':
      return l10n.templateCategoryJournal;
    case 'finance':
      return l10n.templateCategoryFinance;
    case 'health':
      return l10n.templateCategoryHealth;
    case 'travel':
      return l10n.templateCategoryTravel;
    case 'recipes':
      return l10n.templateCategoryRecipes;
    case 'writing':
      return l10n.templateCategoryWriting;
    case 'software':
      return l10n.templateCategorySoftware;
    default:
      return l10n.templateCategoryOther;
  }
}

/// Normaliza una categoría (posiblemente texto libre heredado de antes de la
/// taxonomía fija) a un id conocido; cualquier valor vacío o no reconocido cae
/// en 'other' sin mutar el dato guardado.
String normalizeFolioTemplateCategory(String raw) {
  final trimmed = raw.trim().toLowerCase();
  return kFolioTemplateCategoryIds.contains(trimmed)
      ? trimmed
      : kFolioTemplateCategoryOther;
}

/// Acento de color por categoría: un tono distinto por id repartiendo el
/// círculo cromático a partes iguales, ajustado en luminosidad según el tema
/// claro/oscuro. Evita mantener una lista de 14 colores elegidos a mano.
Color folioTemplateCategoryColor(BuildContext context, String categoryId) {
  final index = kFolioTemplateCategoryIds.indexOf(
    normalizeFolioTemplateCategory(categoryId),
  );
  final hue =
      (index < 0 ? 0 : index) * (360 / kFolioTemplateCategoryIds.length);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return HSLColor.fromAHSL(1, hue, 0.55, isDark ? 0.72 : 0.42).toColor();
}

/// Icono representativo de un tipo de bloque, para la tira de iconos de
/// preview de la galería de plantillas.
IconData folioBlockTypeIcon(String? blockType) {
  switch (blockType) {
    case 'h1':
    case 'h2':
    case 'h3':
      return Icons.title_rounded;
    case 'todo':
    case 'task':
      return Icons.check_box_outlined;
    case 'code':
      return Icons.code_rounded;
    case 'mermaid':
      return Icons.schema_rounded;
    case 'equation':
      return Icons.functions_rounded;
    case 'image':
      return Icons.image_rounded;
    case 'table':
      return Icons.table_chart_rounded;
    case 'quote':
      return Icons.format_quote_rounded;
    case 'callout':
      return Icons.info_outline_rounded;
    case 'file':
      return Icons.insert_drive_file_rounded;
    case 'video':
      return Icons.video_library_rounded;
    case 'audio':
      return Icons.audiotrack_rounded;
    case 'bookmark':
      return Icons.bookmark_border_rounded;
    case 'database':
      return Icons.storage_rounded;
    case 'toggle':
      return Icons.play_arrow_rounded;
    default:
      return Icons.notes_rounded;
  }
}

/// Hasta 5 iconos de tipo de bloque distintos presentes en una plantilla,
/// en orden de aparición.
List<IconData> folioTemplateBlockTypeIcons(Iterable<String> blockTypes) {
  final seen = <String>{};
  final icons = <IconData>[];
  for (final type in blockTypes) {
    if (!seen.add(type)) continue;
    icons.add(folioBlockTypeIcon(type));
    if (icons.length >= 5) break;
  }
  return icons;
}
