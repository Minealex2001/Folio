import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Definición mínima del catálogo (icono, sección, beta). Los textos vienen de [AppLocalizations].
class BlockTypeTemplate {
  const BlockTypeTemplate({
    required this.key,
    required this.icon,
    required this.section,
    this.beta = false,
  });

  final String key;
  final IconData icon;
  final BlockTypeSection section;
  final bool beta;

  BlockTypeDef resolve(AppLocalizations l10n) {
    return BlockTypeDef(
      key: key,
      label: blockTypeLabelForKey(key, l10n),
      hint: blockTypeHintForKey(key, l10n),
      icon: icon,
      section: section,
      beta: beta,
    );
  }
}

/// Orden estable del menú `/` y del selector de tipo (localizar etiquetas con [resolveBlockTypeCatalog]).
const List<BlockTypeTemplate> blockTypeTemplates = [
  BlockTypeTemplate(
    key: 'paragraph',
    icon: Icons.notes_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'child_page',
    icon: Icons.description_outlined,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'h1',
    icon: Icons.looks_one_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'h2',
    icon: Icons.looks_two_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'h3',
    icon: Icons.looks_3_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'quote',
    icon: Icons.format_quote_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'divider',
    icon: Icons.horizontal_rule_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'callout',
    icon: Icons.lightbulb_outline_rounded,
    section: BlockTypeSection.basicText,
  ),
  BlockTypeTemplate(
    key: 'bullet',
    icon: Icons.format_list_bulleted_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeTemplate(
    key: 'numbered',
    icon: Icons.format_list_numbered_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeTemplate(
    key: 'todo',
    icon: Icons.check_box_outlined,
    section: BlockTypeSection.lists,
  ),
  BlockTypeTemplate(
    key: 'toggle',
    icon: Icons.unfold_more_rounded,
    section: BlockTypeSection.lists,
  ),
  BlockTypeTemplate(
    key: 'image',
    icon: Icons.image_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'bookmark',
    icon: Icons.bookmark_outline_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'video',
    icon: Icons.play_circle_outline_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'audio',
    icon: Icons.graphic_eq_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'meeting_note',
    icon: Icons.mic_rounded,
    section: BlockTypeSection.media,
    beta: true,
  ),
  BlockTypeTemplate(
    key: 'code',
    icon: Icons.code_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'file',
    icon: Icons.attach_file_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'table',
    icon: Icons.table_chart_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'database',
    icon: Icons.dataset_rounded,
    section: BlockTypeSection.media,
    beta: true,
  ),
  BlockTypeTemplate(
    key: 'kanban',
    icon: Icons.view_kanban_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'drive',
    icon: Icons.drive_folder_upload_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeTemplate(
    key: 'equation',
    icon: Icons.functions_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'mermaid',
    icon: Icons.account_tree_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'toc',
    icon: Icons.list_alt_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'breadcrumb',
    icon: Icons.hiking_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'template_button',
    icon: Icons.smart_button_outlined,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'column_list',
    icon: Icons.view_column_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'canvas',
    icon: Icons.gesture_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeTemplate(
    key: 'embed',
    icon: Icons.web_rounded,
    section: BlockTypeSection.embeds,
  ),
];

enum BlockTypeSection { basicText, lists, media, advanced, embeds, apps }

String blockSectionTitle(BlockTypeSection section, AppLocalizations l10n) {
  switch (section) {
    case BlockTypeSection.basicText:
      return l10n.blockTypeSectionBasicText;
    case BlockTypeSection.lists:
      return l10n.blockTypeSectionLists;
    case BlockTypeSection.media:
      return l10n.blockTypeSectionMedia;
    case BlockTypeSection.advanced:
      return l10n.blockTypeSectionAdvanced;
    case BlockTypeSection.embeds:
      return l10n.blockTypeSectionEmbeds;
    case BlockTypeSection.apps:
      return 'Apps';
  }
}

/// Devuelve el icono asociado al tipo de bloque, o [Icons.widgets_outlined] si no se encuentra.
IconData blockTypeIconForKey(String key) {
  for (final t in blockTypeTemplates) {
    if (t.key == key) return t.icon;
  }
  return Icons.widgets_outlined;
}

String blockTypeLabelForKey(String key, AppLocalizations l10n) {
  switch (key) {
    case 'paragraph':
      return l10n.blockTypeParagraphLabel;
    case 'child_page':
      return l10n.blockTypeChildPageLabel;
    case 'h1':
      return l10n.blockTypeH1Label;
    case 'h2':
      return l10n.blockTypeH2Label;
    case 'h3':
      return l10n.blockTypeH3Label;
    case 'quote':
      return l10n.blockTypeQuoteLabel;
    case 'divider':
      return l10n.blockTypeDividerLabel;
    case 'callout':
      return l10n.blockTypeCalloutLabel;
    case 'bullet':
      return l10n.blockTypeBulletLabel;
    case 'numbered':
      return l10n.blockTypeNumberedLabel;
    case 'todo':
      return l10n.blockTypeTodoLabel;
    case 'task':
      return l10n.blockTypeTaskLabel;
    case 'toggle':
      return l10n.blockTypeToggleLabel;
    case 'image':
      return l10n.blockTypeImageLabel;
    case 'bookmark':
      return l10n.blockTypeBookmarkLabel;
    case 'video':
      return l10n.blockTypeVideoLabel;
    case 'audio':
      return l10n.blockTypeAudioLabel;
    case 'meeting_note':
      return l10n.blockTypeMeetingNoteLabel;
    case 'code':
      return l10n.blockTypeCodeLabel;
    case 'file':
      return l10n.blockTypeFileLabel;
    case 'table':
      return l10n.blockTypeTableLabel;
    case 'database':
      return l10n.blockTypeDatabaseLabel;
    case 'kanban':
      return l10n.blockTypeKanbanLabel;
    case 'drive':
      return l10n.blockTypeDriveLabel;
    case 'canvas':
      return l10n.blockTypeCanvasLabel;
    case 'equation':
      return l10n.blockTypeEquationLabel;
    case 'mermaid':
      return l10n.blockTypeMermaidLabel;
    case 'toc':
      return l10n.blockTypeTocLabel;
    case 'breadcrumb':
      return l10n.blockTypeBreadcrumbLabel;
    case 'template_button':
      return l10n.blockTypeTemplateButtonLabel;
    case 'column_list':
      return l10n.blockTypeColumnListLabel;
    case 'embed':
      return l10n.blockTypeEmbedLabel;
    default:
      return key;
  }
}

String blockTypeHintForKey(String key, AppLocalizations l10n) {
  switch (key) {
    case 'paragraph':
      return l10n.blockTypeParagraphHint;
    case 'child_page':
      return l10n.blockTypeChildPageHint;
    case 'h1':
      return l10n.blockTypeH1Hint;
    case 'h2':
      return l10n.blockTypeH2Hint;
    case 'h3':
      return l10n.blockTypeH3Hint;
    case 'quote':
      return l10n.blockTypeQuoteHint;
    case 'divider':
      return l10n.blockTypeDividerHint;
    case 'callout':
      return l10n.blockTypeCalloutHint;
    case 'bullet':
      return l10n.blockTypeBulletHint;
    case 'numbered':
      return l10n.blockTypeNumberedHint;
    case 'todo':
      return l10n.blockTypeTodoHint;
    case 'task':
      return l10n.blockTypeTaskHint;
    case 'toggle':
      return l10n.blockTypeToggleHint;
    case 'image':
      return l10n.blockTypeImageHint;
    case 'bookmark':
      return l10n.blockTypeBookmarkHint;
    case 'video':
      return l10n.blockTypeVideoHint;
    case 'audio':
      return l10n.blockTypeAudioHint;
    case 'meeting_note':
      return l10n.blockTypeMeetingNoteHint;
    case 'code':
      return l10n.blockTypeCodeHint;
    case 'file':
      return l10n.blockTypeFileHint;
    case 'table':
      return l10n.blockTypeTableHint;
    case 'database':
      return l10n.blockTypeDatabaseHint;
    case 'kanban':
      return l10n.blockTypeKanbanHint;
    case 'drive':
      return l10n.blockTypeDriveHint;
    case 'canvas':
      return l10n.blockTypeCanvasHint;
    case 'equation':
      return l10n.blockTypeEquationHint;
    case 'mermaid':
      return l10n.blockTypeMermaidHint;
    case 'toc':
      return l10n.blockTypeTocHint;
    case 'breadcrumb':
      return l10n.blockTypeBreadcrumbHint;
    case 'template_button':
      return l10n.blockTypeTemplateButtonHint;
    case 'column_list':
      return l10n.blockTypeColumnListHint;
    case 'embed':
      return l10n.blockTypeEmbedHint;
    default:
      return '';
  }
}

List<BlockTypeDef> resolveBlockTypeCatalog(AppLocalizations l10n) {
  return [for (final t in blockTypeTemplates) t.resolve(l10n)];
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

List<BlockTypeDef> filterBlockTypeCatalog(String query, AppLocalizations l10n) {
  final normalizedQuery = query.trim().toLowerCase();
  final resolved = resolveBlockTypeCatalog(l10n);
  if (normalizedQuery.isEmpty) return resolved;
  return resolved.where((definition) {
    return definition.key.contains(normalizedQuery) ||
        definition.label.toLowerCase().contains(normalizedQuery) ||
        definition.hint.toLowerCase().contains(normalizedQuery);
  }).toList();
}
