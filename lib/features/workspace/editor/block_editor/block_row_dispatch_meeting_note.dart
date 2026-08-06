part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowMeetingNote(_BlockRowScope s) {
  if (s.block.type != 'meeting_note') return null;
  final st = s.st;
  final block = s.block;
  final page = s.page;
  final scheme = s.scheme;
  final theme = s.theme;
  final context = s.context;
  final ctrl = s.ctrl;
  final focus = s.focus;
  final marker = s.marker;
  final dragHandle = s.dragHandle;
  final menu = s.menu;
  final showActions = s.showActions;
  final showInlineEditControls = s.showInlineEditControls;
  final index = s.index;
  final readOnlyMode = s.readOnlyMode;
  final rawU = (block.url ?? '').trim();
  final transcriptPreview = block.text.trim();
  final hasMeetingContent = rawU.isNotEmpty || transcriptPreview.isNotEmpty;
  final compactView =
      hasMeetingContent &&
      !showInlineEditControls &&
      !showActions &&
      !focus.hasFocus;
  final previewText = transcriptPreview.isEmpty
      ? 'Sin transcripcion'
      : transcriptPreview;
  final l10n = AppLocalizations.of(context);
  // Fase F1 del rediseño UX del editor: color de identidad propio (en vez
  // del `outlineVariant` genérico que comparte con bloques sin acento
  // definido) — mismo lenguaje visual que code/mermaid/database.
  final accentTone = _blockAccentToneFor('meeting_note')!;
  final accentBorder = calloutBorderForTone(scheme, accentTone, preset: st._calloutPreset);
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: calloutBackgroundForTone(scheme, accentTone, preset: st._calloutPreset),
              borderRadius: BorderRadius.circular(12),
              // `BoxDecoration.borderRadius` exige color uniforme en los 4
              // lados (solo el ancho puede variar) — el acento se marca
              // engrosando el lado izquierdo, no aclarando los demás.
              border: Border(
                left: BorderSide(color: accentBorder, width: 3),
                top: BorderSide(color: accentBorder),
                right: BorderSide(color: accentBorder),
                bottom: BorderSide(color: accentBorder),
              ),
            ),
            child: compactView
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.meetingNoteTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (rawU.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.audio_file_rounded,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                          // Fase D3 del rediseño UX del editor: acción
                          // EXPLÍCITA (nunca detección automática silenciosa,
                          // que violaría el "nunca invasivo" del brief) para
                          // extraer estructura de la reunión — reutiliza el
                          // mismo popover de IA anclado a selección de la
                          // Fase D1, no un pipeline nuevo. "Extraer tareas de
                          // acción" ya existe como intent (`actionItems`);
                          // este botón solo lo hace alcanzable desde aquí.
                          if (!readOnlyMode &&
                              transcriptPreview.isNotEmpty &&
                              st.widget.onAiSlashCommand != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => st.showAiSelectionPopover(
                                blockId: block.id,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  FolioIcons.quillOutlined,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  )
                : (rawU.isEmpty
                      ? MeetingNoteBlockWidget(
                          block: block,
                          page: page,
                          session: st._s,
                          appSettings: st.widget.appSettings,
                          scheme: scheme,
                          resolvedFile: null,
                          folioCloudEntitlements: s.folioCloudEntitlements,
                        )
                      : FutureBuilder<File?>(
                          future: st._resolveBlockUrlFileCached(rawU),
                          builder: (ctx, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 48,
                                child: FolioLoadingIndicator(centered: true),
                              );
                            }
                            return MeetingNoteBlockWidget(
                              block: block,
                              page: page,
                              session: st._s,
                              appSettings: st.widget.appSettings,
                              scheme: scheme,
                              resolvedFile: snap.data,
                              folioCloudEntitlements:
                                  s.folioCloudEntitlements,
                            );
                          },
                        )),
          ),
        ),
      ],
    ),
  );
}
