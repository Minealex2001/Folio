part of 'package:folio/features/workspace/editor/block_editor.dart';

/// The block "⋮" context menu: building its item list and dispatching the
/// chosen action. Split out of `block_editor_state.dart` as one bounded,
/// self-contained pair of methods (menu construction has no other callers
/// interleaved with it). Matches the `_BlockRowBuild` mixin convention.
mixin _BlockContextMenu on State<BlockEditor> {
  BlockEditorState get _menuSelf => this as BlockEditorState;

  void _onBlockMenuChosen(
    String v,
    BuildContext menuContext,
    FolioPage page,
    FolioBlock b,
    int index,
  ) {
    final st = _menuSelf;
    if (v == 'del') {
      if (page.blocks.length > 1) {
        if (b.type == 'meeting_note') {
          final idx = page.blocks.indexWhere((it) => it.id == b.id);
          if (idx > 0) {
            st._pendingFocusIndex = idx - 1;
            st._pendingCursorOffset = page.blocks[idx - 1].text.length;
          } else if (page.blocks.length > 1) {
            st._pendingFocusIndex = 0;
            st._pendingCursorOffset = 0;
          }
          st._s.removeBlockIfMultiple(page.id, b.id);
        } else {
          st._deleteSelectedBlocks(page, st._selectedIdsForAction(page, b.id));
        }
      } else {
        // Si es el ultimo bloque, lo dejamos como parrafo vacio
        // para no romper la regla de pagina no vacia.
        st._s.changeBlockType(page.id, b.id, 'paragraph');
        st._s.updateBlockText(page.id, b.id, '');
        st._s.updateBlockUrl(page.id, b.id, null);
        final j = st._controllerBlockIds.indexOf(b.id);
        if (j >= 0 && j < st._controllers.length) {
          st._ignoreShortcuts = true;
          st._controllers[j].clear();
          st._ignoreShortcuts = false;
        }
        st._pendingFocusBlockId = b.id;
        st._pendingCursorOffset = 0;
        if (mounted) setState(() {});
      }
    } else if (v == 'ai_rewrite') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final c = TextEditingController();
        final rewriteL10n = AppLocalizations.of(menuContext);
        final go = await showDialog<bool>(
          context: menuContext,
          builder: (ctx) => FolioDialog(
            title: Text(rewriteL10n.aiRewriteDialogTitle),
            content: TextField(
              controller: c,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: rewriteL10n.aiInstructionHint,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(rewriteL10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(rewriteL10n.aiApply),
              ),
            ],
          ),
        );
        final instruction = c.text.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          c.dispose();
        });
        if (go != true || instruction.isEmpty) return;
        try {
          final preview = await st._s.previewRewriteBlockWithAi(
            pageId: page.id,
            blockId: b.id,
            instruction: instruction,
          );
          if (!mounted) return;

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final baseStyle = theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            height: 1.35,
          );
          if (!menuContext.mounted) return;
          final previewL10n = AppLocalizations.of(menuContext);
          final accept = await showDialog<bool>(
            context: menuContext,
            builder: (ctx) {
              return FolioDialog(
                title: Text(previewL10n.aiPreviewTitle),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    child: FolioAiTypewriterMessage(
                      fullText: preview.text,
                      style:
                          baseStyle ??
                          TextStyle(color: scheme.onSurface, height: 1.35),
                      selectable: true,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(previewL10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(previewL10n.aiApply),
                  ),
                ],
              );
            },
          );
          if (accept != true || !mounted) return;

          await st._applyTypewriterToBlock(
            pageId: page.id,
            blockId: b.id,
            fullText: preview.text,
          );
        } catch (e) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.aiGenericErrorWithReason('$e'))),
          );
        }
      });
    } else if (v == 'pick_type') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final choice = await st._openBlockTypePicker(menuContext);
        if (!mounted || choice == null) return;
        final blockId = b.id;
        var preservedOff = 0;
        final i0 = page.blocks.indexWhere((x) => x.id == blockId);
        if (i0 >= 0 && i0 < st._controllers.length) {
          if (_stylableBlockTypes.contains(b.type)) {
            final qc = st._quillByBlockId[blockId];
            if (qc != null && qc.selection.isValid) {
              preservedOff = qc.selection.baseOffset.clamp(
                0,
                qc.document.toPlainText().length,
              );
            }
          } else {
            final c = st._controllers[i0];
            if (c.selection.isValid) {
              preservedOff = c.selection.baseOffset.clamp(0, c.text.length);
            }
          }
        }
        st._pendingFocusBlockId = blockId;
        st._pendingCursorOffset = preservedOff;
        st._s.changeBlockType(page.id, blockId, choice);
        final p2 = st._s.selectedPage;
        if (p2 != null && mounted) {
          final j = p2.blocks.indexWhere((x) => x.id == blockId);
          if (j >= 0 && j < st._controllers.length) {
            final nb = p2.blocks[j];
            final len = nb.text.length;
            final off = preservedOff.clamp(0, len);
            st._ignoreShortcuts = true;
            st._controllers[j].value = TextEditingValue(
              text: nb.text,
              selection: TextSelection.collapsed(offset: off),
            );
            st._ignoreShortcuts = false;
          }
        }
        if (mounted) setState(() {});
      });
    } else if (v == 'appearance') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(st._editBlockAppearance(page, b));
      });
    } else if (v == 'up' && index > 0) {
      st._moveBlock(page.id, b.id, -1);
    } else if (v == 'down' && index < page.blocks.length - 1) {
      st._moveBlock(page.id, b.id, 1);
    } else if (v == 'dup') {
      final selectedIds = st._selectedIdsForAction(page, b.id);
      if (selectedIds.length > 1) {
        st._duplicateSelectedBlocks(page, selectedIds);
      } else {
        st._duplicateBlock(page, b, index);
      }
    } else if (v == 'open_external') {
      final target = b.type == 'image'
          ? b.text
          : (const {
                  'file',
                  'video',
                  'audio',
                  'bookmark',
                  'embed',
                }.contains(b.type)
                ? b.url
                : null);
      unawaited(st._openBlockUrlExternal(target));
    } else if (v == 'copy_link') {
      final target = b.type == 'image'
          ? b.text.trim()
          : (const {
                  'file',
                  'video',
                  'audio',
                  'bookmark',
                  'embed',
                }.contains(b.type)
                ? (b.url ?? '').trim()
                : '');
      if (target.isNotEmpty) {
        unawaited(Clipboard.setData(ClipboardData(text: target)));
      }
    } else if (v == 'size_smaller') {
      st._nudgeImageWidth(page, b, -0.1);
    } else if (v == 'size_larger') {
      st._nudgeImageWidth(page, b, 0.1);
    } else if (v == 'size_50') {
      st._s.setBlockImageWidth(page.id, b.id, 0.5);
    } else if (v == 'size_75') {
      st._s.setBlockImageWidth(page.id, b.id, 0.75);
    } else if (v == 'size_100') {
      st._s.setBlockImageWidth(page.id, b.id, 1.0);
    } else if (v == 'img_pick') {
      unawaited(st._pickImageForBlock(page.id, b.id, index));
    } else if (v == 'img_clear') {
      unawaited(st._clearImageBlock(page.id, b.id, index));
    } else if (v == 'child_create') {
      st._s.createChildPageLinkedToBlock(pageId: page.id, blockId: b.id);
      setState(() {});
    } else if (v == 'child_link') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final picked = await st._pickPageForChildBlock(
          menuContext,
          excludeId: page.id,
        );
        if (picked == null || !mounted) return;
        st._s.updateBlockText(page.id, b.id, picked);
        setState(() {});
      });
    } else if (v == 'child_open') {
      final cid = b.text.trim();
      if (cid.isNotEmpty) {
        st._s.selectPage(cid);
      }
    } else if (v == 'file_pick') {
      unawaited(st._pickFileForBlock(page.id, b.id));
    } else if (v == 'file_clear') {
      st._clearBlockUrl(page.id, b.id);
    } else if (v == 'video_pick') {
      unawaited(st._pickVideoForBlock(page.id, b.id));
    } else if (v == 'video_clear') {
      st._clearBlockUrl(page.id, b.id);
    } else if (v == 'audio_pick') {
      unawaited(st._pickAudioForBlock(page.id, b.id));
    } else if (v == 'audio_clear') {
      st._clearBlockUrl(page.id, b.id);
    } else if (v == 'template_edit_label') {
      unawaited(st._editTemplateButtonLabel(page.id, b));
    } else if (v == 'bookmark_set_url') {
      unawaited(st._editBookmarkUrlDialog(page.id, b.id, index));
    } else if (v == 'bookmark_clear') {
      st._clearBlockUrl(page.id, b.id);
      st._s.updateBlockText(page.id, b.id, '');
      final j = st._controllerBlockIds.indexOf(b.id);
      if (j >= 0 && j < st._controllers.length) {
        st._ignoreShortcuts = true;
        st._controllers[j].clear();
        st._ignoreShortcuts = false;
      }
      if (mounted) setState(() {});
    } else if (v == 'embed_set_url') {
      unawaited(st._editEmbedUrlDialog(page.id, b.id, index));
    } else if (v == 'embed_clear') {
      st._clearBlockUrl(page.id, b.id);
      st._s.updateBlockText(page.id, b.id, '');
      final j = st._controllerBlockIds.indexOf(b.id);
      if (j >= 0 && j < st._controllers.length) {
        st._ignoreShortcuts = true;
        st._controllers[j].clear();
        st._ignoreShortcuts = false;
      }
      if (mounted) setState(() {});
    } else if (v == 'spotify_set_url') {
      unawaited(st._editSpotifyUrlDialog(page.id, b.id, index));
    } else if (v == 'spotify_clear') {
      st._clearBlockUrl(page.id, b.id);
      st._s.updateBlockText(page.id, b.id, '');
      if (mounted) setState(() {});
    } else if (v == 'table_row_add') {
      st._mutateTable(page.id, b.id, index, (d) => d.addRow());
    } else if (v == 'table_row_rem') {
      st._mutateTable(page.id, b.id, index, (d) => d.removeLastRow());
    } else if (v == 'table_col_add') {
      st._mutateTable(page.id, b.id, index, (d) => d.addCol());
    } else if (v == 'table_col_rem') {
      st._mutateTable(page.id, b.id, index, (d) => d.removeLastCol());
    } else if (v == 'db_row_add') {
      st._mutateDatabase(page.id, b.id, index, (d) {
        d.rows.add(
          FolioDbRow(id: '${page.id}_r_${BlockEditorState._uuid.v4()}'),
        );
      });
    } else if (v == 'db_col_add') {
      st._mutateDatabase(page.id, b.id, index, (d) {
        d.properties.add(
          FolioDbProperty(
            id: 'p_${BlockEditorState._uuid.v4()}',
            name: 'Propiedad ${d.properties.length + 1}',
            type: FolioDbPropertyType.text,
          ),
        );
      });
    } else if (v == 'code_lang') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final id = await st._openCodeLanguageSheet(menuContext, b);
        if (!mounted || id == null) return;
        st._onCodeLanguagePicked(page.id, b.id, index, id);
      });
    } else if (v == 'mermaid_edit') {
      setState(() => st._mermaidEditingSourceIds.add(b.id));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p2 = st._s.selectedPage;
        if (p2 == null) return;
        final j = p2.blocks.indexWhere((x) => x.id == b.id);
        if (j < 0 || j >= st._focusNodes.length) return;
        st._focusNodes[j].requestFocus();
      });
    } else if (v == 'mermaid_hide') {
      setState(() => st._mermaidEditingSourceIds.remove(b.id));
    } else if (v == 'meeting_copy_transcript') {
      final text = b.text.trim();
      if (text.isNotEmpty) {
        unawaited(Clipboard.setData(ClipboardData(text: text)));
      }
    } else if (v == 'meeting_send_to_ai') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await st._openMeetingNoteAiDialog(menuContext, page, b);
      });
    } else if (v == 'meeting_transcribe') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final file = await st._resolveBlockUrlFileCached(b.url);
        if (file == null || !mounted) return;
        await showPostHocTranscribeDialog(
          context: menuContext,
          session: st._s,
          appSettings: st.widget.appSettings,
          page: page,
          block: b,
          audioFile: file,
          entitlements: st.widget.folioCloudEntitlements,
        );
      });
    } else if (v == 'callout_pick_icon') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final emoji = await st._pickEmoji(menuContext);
        if (!mounted || emoji == null) return;
        st._s.updateBlockIcon(page.id, b.id, emoji);
      });
    } else if (v == 'callout_tone_info') {
      st._s.updateBlockIcon(page.id, b.id, '💡');
    } else if (v == 'callout_tone_success') {
      st._s.updateBlockIcon(page.id, b.id, '✅');
    } else if (v == 'callout_tone_warning') {
      st._s.updateBlockIcon(page.id, b.id, '⚠️');
    } else if (v == 'callout_tone_error') {
      st._s.updateBlockIcon(page.id, b.id, '🚨');
    } else if (v == 'callout_tone_note') {
      st._s.updateBlockIcon(page.id, b.id, 'ℹ️');
    } else if (v == 'sync_create') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final groupId = st._s.createSyncGroup(page.id, b.id);
        unawaited(Clipboard.setData(ClipboardData(text: groupId)));
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncedBlockCreated)));
      });
    } else if (v == 'sync_unsync') {
      st._s.unsyncBlock(page.id, b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).syncedBlockUnsynced),
        ),
      );
    } else if (v == 'sync_insert') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        final groupId = await showDialog<String>(
          context: context,
          builder: (ctx) => _SyncedBlockInsertDialog(l10n: l10n),
        );
        if (!mounted || groupId == null || groupId.isEmpty) return;
        final ok = st._s.insertSyncedBlock(page.id, b.id, groupId);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).syncedBlockIdInvalid),
            ),
          );
        }
      });
    }
  }

  List<PopupMenuEntry<String>> _buildBlockMenuItems(
    BuildContext ctx, {
    required FolioPage page,
    required FolioBlock b,
    required int index,
  }) {
    final st = _menuSelf;
    PopupMenuItem<String> item(
      BuildContext c, {
      required String value,
      required IconData icon,
      required String label,
      Color? iconColor,
    }) {
      final scheme = Theme.of(c).colorScheme;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      );
    }

    final data = b.type == 'table' ? FolioTableData.tryParse(b.text) : null;
    final db = b.type == 'database' ? FolioDatabaseData.tryParse(b.text) : null;
    final rows = data?.rowCount ?? 0;
    final cols = data?.cols ?? 0;
    final linkTarget = b.type == 'image'
        ? b.text.trim()
        : (const {
                'file',
                'video',
                'audio',
                'bookmark',
                'embed',
              }.contains(b.type)
              ? (b.url ?? '').trim()
              : '');
    final hasExternalTarget = linkTarget.isNotEmpty;
    final mediaSizeTypes = {
      'image',
      'file',
      'video',
      'bookmark',
      'embed',
      'audio',
    };
    final isChildLinked =
        b.type == 'child_page' &&
        b.text.trim().isNotEmpty &&
        st._s.pages.any((p) => p.id == b.text.trim());
    final l10n = AppLocalizations.of(ctx);
    return [
      if (st._s.aiEnabled)
        item(
          ctx,
          value: 'ai_rewrite',
          icon: Icons.auto_fix_high_rounded,
          label: l10n.blockEditorMenuRewriteWithAi,
        ),
      if (index > 0)
        item(
          ctx,
          value: 'up',
          icon: Icons.keyboard_arrow_up_rounded,
          label: l10n.blockEditorMenuMoveUp,
        ),
      if (index < page.blocks.length - 1)
        item(
          ctx,
          value: 'down',
          icon: Icons.keyboard_arrow_down_rounded,
          label: l10n.blockEditorMenuMoveDown,
        ),
      item(
        ctx,
        value: 'dup',
        icon: Icons.copy_all_rounded,
        label: l10n.blockEditorMenuDuplicateBlock,
      ),
      if (st._blockSupportsAppearance(b))
        item(
          ctx,
          value: 'appearance',
          icon: Icons.palette_outlined,
          label: l10n.blockEditorMenuAppearance,
        ),
      if (b.type == 'callout') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'callout_pick_icon',
          icon: Icons.emoji_emotions_outlined,
          label: l10n.blockEditorMenuCalloutIcon,
        ),
        item(
          ctx,
          value: 'callout_tone_info',
          icon: Icons.lightbulb_outline_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeInfo),
        ),
        item(
          ctx,
          value: 'callout_tone_success',
          icon: Icons.task_alt_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeSuccess),
        ),
        item(
          ctx,
          value: 'callout_tone_warning',
          icon: Icons.warning_amber_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeWarning),
        ),
        item(
          ctx,
          value: 'callout_tone_error',
          icon: Icons.report_problem_outlined,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeError),
        ),
        item(
          ctx,
          value: 'callout_tone_note',
          icon: Icons.info_outline_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeNote),
        ),
      ],
      if (hasExternalTarget)
        item(
          ctx,
          value: 'open_external',
          icon: Icons.open_in_new_rounded,
          label: AppLocalizations.of(ctx).openExternal,
        ),
      if (hasExternalTarget)
        item(
          ctx,
          value: 'copy_link',
          icon: Icons.link_rounded,
          label: l10n.blockEditorCopyLink,
        ),
      if (mediaSizeTypes.contains(b.type)) ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'size_smaller',
          icon: Icons.remove_rounded,
          label: AppLocalizations.of(ctx).blockSizeSmaller,
        ),
        item(
          ctx,
          value: 'size_larger',
          icon: Icons.add_rounded,
          label: AppLocalizations.of(ctx).blockSizeLarger,
        ),
        item(
          ctx,
          value: 'size_50',
          icon: Icons.photo_size_select_small_rounded,
          label: AppLocalizations.of(ctx).blockSizeHalf,
        ),
        item(
          ctx,
          value: 'size_75',
          icon: Icons.photo_size_select_large_rounded,
          label: AppLocalizations.of(ctx).blockSizeThreeQuarter,
        ),
        item(
          ctx,
          value: 'size_100',
          icon: Icons.fit_screen_rounded,
          label: AppLocalizations.of(ctx).blockSizeFull,
        ),
      ],
      if (b.type == 'child_page') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'child_create',
          icon: Icons.note_add_rounded,
          label: l10n.blockEditorMenuCreateSubpage,
        ),
        item(
          ctx,
          value: 'child_link',
          icon: Icons.link_rounded,
          label: l10n.blockEditorMenuLinkPage,
        ),
        if (isChildLinked)
          item(
            ctx,
            value: 'child_open',
            icon: Icons.open_in_new_rounded,
            label: l10n.blockEditorMenuOpenSubpage,
          ),
      ],
      if (b.type == 'image') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'img_pick',
          icon: Icons.image_rounded,
          label: l10n.blockEditorMenuPickImage,
        ),
        if (b.text.isNotEmpty)
          item(
            ctx,
            value: 'img_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveImage,
          ),
      ],
      if (b.type == 'code') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'code_lang',
          icon: Icons.translate_rounded,
          label: l10n.blockEditorMenuCodeLanguage,
        ),
      ],
      if (b.type == 'mermaid') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'mermaid_edit',
          icon: Icons.edit_note_rounded,
          label: l10n.blockEditorMenuEditDiagram,
        ),
        if (st._mermaidEditingSourceIds.contains(b.id))
          item(
            ctx,
            value: 'mermaid_hide',
            icon: Icons.visibility_rounded,
            label: l10n.blockEditorMenuBackToPreview,
          ),
      ],
      if (b.type == 'file') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'file_pick',
          icon: Icons.attach_file_rounded,
          label: l10n.blockEditorMenuChangeFile,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'file_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveFile,
          ),
      ],
      if (b.type == 'video') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'video_pick',
          icon: Icons.video_settings_rounded,
          label: l10n.blockEditorMenuChangeVideo,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'video_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveVideo,
          ),
      ],
      if (b.type == 'audio') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'audio_pick',
          icon: Icons.audio_file_rounded,
          label: l10n.blockEditorMenuChangeAudio,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'audio_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveAudio,
          ),
      ],
      if (b.type == 'template_button') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'template_edit_label',
          icon: Icons.title_rounded,
          label: l10n.blockEditorMenuEditLabel,
        ),
      ],
      if (b.type == 'bookmark') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'bookmark_set_url',
          icon: Icons.link_rounded,
          label: AppLocalizations.of(ctx).bookmarkSetUrl,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'bookmark_clear',
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(ctx).bookmarkRemove,
          ),
      ],
      if (b.type == 'embed') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'embed_set_url',
          icon: Icons.language_rounded,
          label: AppLocalizations.of(ctx).embedSetUrl,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'embed_clear',
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(ctx).embedRemove,
          ),
      ],
      if (b.type == 'spotify') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'spotify_set_url',
          icon: Icons.music_note_rounded,
          label: AppLocalizations.of(ctx).embedSetUrl,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'spotify_clear',
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(ctx).embedRemove,
          ),
      ],
      if (b.type == 'meeting_note') ...[
        const PopupMenuDivider(),
        if (b.text.trim().isNotEmpty)
          item(
            ctx,
            value: 'meeting_copy_transcript',
            icon: Icons.copy_rounded,
            label: AppLocalizations.of(ctx).meetingNoteCopyTranscript,
          ),
        if (st._s.aiEnabled)
          item(
            ctx,
            value: 'meeting_send_to_ai',
            icon: Icons.auto_fix_high_rounded,
            label: AppLocalizations.of(ctx).meetingNoteSendToAi,
          ),
        if ((b.url ?? '').trim().isNotEmpty && b.text.trim().isEmpty)
          item(
            ctx,
            value: 'meeting_transcribe',
            icon: Icons.subtitles_rounded,
            label: AppLocalizations.of(ctx).meetingNoteTranscribeNow,
          ),
      ],
      if (b.type == 'table' && data != null) ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'table_row_add',
          icon: Icons.table_rows_rounded,
          label: l10n.blockEditorMenuAddRow,
        ),
        if (rows > 1)
          item(
            ctx,
            value: 'table_row_rem',
            icon: Icons.table_rows_outlined,
            label: l10n.blockEditorMenuRemoveLastRow,
          ),
        item(
          ctx,
          value: 'table_col_add',
          icon: Icons.view_column_rounded,
          label: l10n.blockEditorMenuAddColumn,
        ),
        if (cols > 1)
          item(
            ctx,
            value: 'table_col_rem',
            icon: Icons.view_column_outlined,
            label: l10n.blockEditorMenuRemoveLastColumn,
          ),
      ],
      if (b.type == 'database' && db != null) ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'db_row_add',
          icon: Icons.playlist_add_rounded,
          label: l10n.blockEditorMenuAddRow,
        ),
        item(
          ctx,
          value: 'db_col_add',
          icon: Icons.add_chart_rounded,
          label: l10n.blockEditorMenuAddProperty,
        ),
      ],
      const PopupMenuDivider(),
      if (b.syncGroupId == null)
        item(
          ctx,
          value: 'sync_create',
          icon: Icons.sync_rounded,
          label: l10n.syncedBlockCreate,
        ),
      if (b.syncGroupId != null)
        item(
          ctx,
          value: 'sync_unsync',
          icon: Icons.sync_disabled_rounded,
          label: l10n.syncedBlockUnsync,
        ),
      item(
        ctx,
        value: 'sync_insert',
        icon: Icons.add_link_rounded,
        label: l10n.syncedBlockInsert,
      ),
      const PopupMenuDivider(),
      item(
        ctx,
        value: 'pick_type',
        icon: Icons.auto_awesome_motion_rounded,
        iconColor: Theme.of(ctx).colorScheme.primary,
        label: l10n.blockEditorMenuChangeBlockType,
      ),
      const PopupMenuDivider(),
      item(
        ctx,
        value: 'del',
        icon: Icons.delete_forever_rounded,
        iconColor: Theme.of(ctx).colorScheme.error,
        label: l10n.blockEditorMenuDeleteBlock,
      ),
    ];
  }
}
