part of 'workspace_page.dart';

extension _WorkspacePageAiGeneratedImageModule on _WorkspacePageState {
  Widget _buildGeneratedImageCard(AiChatMessage message, int messageIndex) {
    final relPath = message.generatedImagePath;
    if (relPath == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prompt = message.generatedImagePrompt ?? '';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FolioRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: scheme.tertiaryContainer.withValues(alpha: 0.45),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.aiGeneratedImageLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(FolioRadius.sm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: _generatedImageBody(relPath, scheme, l10n),
                  ),
                ),
                if (prompt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    prompt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _insertGeneratedImageIntoPage(relPath),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(l10n.aiGeneratedImageInsertButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _generatedImageBody(
    String relPath,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List?>(
        key: ValueKey(relPath),
        future: VaultPaths.readAttachmentBytes(relPath),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 160,
              child: FolioLoadingIndicator(centered: true),
            );
          }
          final bytes = snap.data;
          if (bytes == null) {
            return _generatedImageError(scheme, l10n);
          }
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _generatedImageError(scheme, l10n),
          );
        },
      );
    }
    return FutureBuilder<Directory>(
      key: ValueKey(relPath),
      future: VaultPaths.vaultDirectory(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 160,
            child: FolioLoadingIndicator(centered: true),
          );
        }
        final file = File(p.join(snap.data!.path, relPath));
        if (!file.existsSync()) {
          return _generatedImageError(scheme, l10n);
        }
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _generatedImageError(scheme, l10n),
        );
      },
    );
  }

  Widget _generatedImageError(ColorScheme scheme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          l10n.aiGeneratedImageLoadError,
          style: TextStyle(color: scheme.error, fontSize: 13),
        ),
      ),
    );
  }

  void _insertGeneratedImageIntoPage(String relPath) {
    final page = _s.selectedPage;
    if (page == null) return;
    final l10n = AppLocalizations.of(context);
    final block = FolioBlock(
      id: '${page.id}_${const Uuid().v4()}',
      type: 'image',
      text: relPath,
      aiGenerated: true,
    );
    _s.appendBlock(pageId: page.id, block: block);

    final collabRoomId = page.collabRoomId?.trim();
    if (collabRoomId != null && collabRoomId.isNotEmpty) {
      final editorState = _blockEditorKeyForPage(page.id).currentState;
      if (editorState != null) {
        unawaited(
          VaultPaths.vaultDirectory().then((dir) {
            if (!mounted) return;
            final file = File(p.join(dir.path, relPath));
            editorState.notifyExternalImageInserted(
              pageId: page.id,
              blockId: block.id,
              localFile: file,
            );
          }),
        );
      }
      // Si el editor de esta página no está montado, el bloque queda
      // insertado localmente pero sin subir hasta que el usuario la abra
      // (limitación conocida — no hay sincronización perezosa de adjuntos
      // locales preexistentes independiente del picker de imagen).
    }

    _snack(l10n.aiGeneratedImageInsertedSnackbar);
  }
}
