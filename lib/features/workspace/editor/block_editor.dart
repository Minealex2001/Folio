import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart'
    show kPrimaryButton, kSecondaryMouseButton;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, setEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show HitTestResult, RenderMetaData;
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_icon_picker.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../crypto/collab_e2e_crypto.dart';
import '../../../data/folio_internal_link.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../data/vault_paths.dart';
import '../../../app/ui_tokens.dart';
import '../../../models/block.dart';
import '../../../models/folio_template_button_data.dart';
import '../../../models/folio_database_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_table_data.dart';
import '../../../services/integrations/integrations_markdown_codec.dart';
import '../../../session/vault_session.dart';
import '../../../services/ai/ai_types.dart';
import '../../../services/folio_cloud/folio_cloud_callable.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import 'code_block_languages.dart';
import 'block_editor_support_widgets.dart';
import 'block_type_catalog.dart';
import 'database_block_editor.dart';
import 'folio_mermaid_preview.dart';
import 'file_video_previews.dart';
import 'folio_text_format.dart';
import 'folio_embed_webview.dart';
import 'folio_youtube.dart';
import 'link_title_fetch.dart';
import 'paste_url_sheet.dart';
import 'folio_special_block_widgets.dart';
import 'meeting_note_block_widget.dart';
import 'table_block_editor.dart';
import 'ai_typewriter_message.dart';
import 'block_editor/block_row_registry.dart';
import 'block_editor/block_editor_callout.dart';
import 'block_editor/block_row_chrome.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'richtext/markdown_quill_codec.dart';

part 'block_editor/block_row_scope.dart';
part 'block_editor/block_row_marker.dart';
part 'block_editor/block_row_dispatch.dart';
part 'block_editor/block_row_dispatch_image.dart';
part 'block_editor/block_row_dispatch_table.dart';
part 'block_editor/block_row_dispatch_database.dart';
part 'block_editor/block_row_dispatch_equation.dart';
part 'block_editor/block_row_dispatch_mermaid.dart';
part 'block_editor/block_row_dispatch_code.dart';
part 'block_editor/block_row_dispatch_divider.dart';
part 'block_editor/block_row_dispatch_file.dart';
part 'block_editor/block_row_dispatch_bookmark.dart';
part 'block_editor/block_row_dispatch_embed.dart';
part 'block_editor/block_row_dispatch_audio.dart';
part 'block_editor/block_row_dispatch_meeting_note.dart';
part 'block_editor/block_row_dispatch_video.dart';
part 'block_editor/block_row_dispatch_toggle.dart';
part 'block_editor/block_row_dispatch_toc.dart';
part 'block_editor/block_row_dispatch_breadcrumb.dart';
part 'block_editor/block_row_dispatch_child_page.dart';
part 'block_editor/block_row_dispatch_template_button.dart';
part 'block_editor/block_row_dispatch_task.dart';
part 'block_editor/block_row_dispatch_column_list.dart';
part 'block_editor/editable_markdown_block_row.dart';
part 'block_editor/block_row_extensions.dart';
part 'block_editor/block_editor_state.dart';
part 'block_editor/block_list_row.dart';
part 'block_editor/special_row_chrome.dart';
part 'block_editor/state_tail_and_fill.dart';
/// `null` si el texto del bloque no es comando `/…`; si no, filtro tras la `/` (puede ser vacío).
String? _slashFilterFromBlockText(String text) {
  if (!text.startsWith('/')) return null;
  if (text.contains('\n')) return null;
  final tail = text.substring(1);
  if (tail.contains(' ')) return null;
  return tail;
}

int? _mentionTriggerStartFromSelection(String text, TextSelection selection) {
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset;
  if (caret <= 0 || caret > text.length) return null;
  var start = caret - 1;
  while (start >= 0) {
    final code = text.codeUnitAt(start);
    if (code == 0x20 || code == 0x0A || code == 0x0D || code == 0x09) {
      break;
    }
    start--;
  }
  start += 1;
  if (start >= caret) return null;
  if (text.codeUnitAt(start) != 0x40 /* @ */ ) return null;
  final tail = text.substring(start + 1, caret);
  if (tail.contains(RegExp(r'[\[\]\(\)]'))) return null;
  return start;
}

String? _mentionFilterFromSelection(String text, TextSelection selection) {
  final start = _mentionTriggerStartFromSelection(text, selection);
  if (start == null) return null;
  final caret = selection.baseOffset;
  return text.substring(start + 1, caret);
}

bool _usesCodeControllerForBlockType(String type) =>
    type == 'code' || type == 'mermaid' || type == 'equation';

List<BlockTypeDef> _catalogFiltered(String q, AppLocalizations l10n) {
  return filterBlockTypeCatalog(q, l10n);
}

const _stylableBlockTypes = <String>{
  'paragraph',
  'h1',
  'h2',
  'h3',
  'bullet',
  'numbered',
  'todo',
  'quote',
  'callout',
};

const _blockFontScaleOptions = <double>[0.9, 1.0, 1.15, 1.3];
const _blockTextColorRoles = <String?>[
  null,
  'subtle',
  'primary',
  'secondary',
  'tertiary',
  'error',
];
const _blockBackgroundRoles = <String?>[
  null,
  'surface',
  'primary',
  'secondary',
  'tertiary',
  'error',
];

List<BlockTypeDef> _inlineSlashActionCatalog(AppLocalizations l10n) => [
  BlockTypeDef(
    key: 'cmd_duplicate_prev',
    label: l10n.blockEditorCmdDuplicatePrev,
    hint: l10n.blockEditorCmdDuplicatePrevHint,
    icon: Icons.copy_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_insert_date',
    label: l10n.blockEditorCmdInsertDate,
    hint: l10n.blockEditorCmdInsertDateHint,
    icon: Icons.event_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_mention_page',
    label: l10n.blockEditorCmdMentionPage,
    hint: l10n.blockEditorCmdMentionPageHint,
    icon: Icons.insert_link_outlined,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_turn_into',
    label: l10n.blockEditorCmdTurnInto,
    hint: l10n.blockEditorCmdTurnIntoHint,
    icon: Icons.swap_horiz_rounded,
    section: BlockTypeSection.advanced,
  ),
];

enum _MeetingAiPayload { transcript, audio, both }

class _CollabUploadProgress {
  const _CollabUploadProgress({
    required this.encrypting,
    this.progress,
    this.eta,
    this.error,
  });

  final bool encrypting;
  final double? progress;
  final Duration? eta;
  final String? error;
}

class BlockEditor extends StatefulWidget {
  const BlockEditor({
    super.key,
    required this.session,
    required this.appSettings,
    this.readOnlyMode = false,
    this.folioCloudEntitlements,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final bool readOnlyMode;
  final FolioCloudEntitlementsController? folioCloudEntitlements;

  @override
  State<BlockEditor> createState() => BlockEditorState();
}


