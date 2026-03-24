import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';

class WorkspaceEditorSurface extends StatelessWidget {
  const WorkspaceEditorSurface({
    super.key,
    required this.compact,
    required this.page,
    required this.titleController,
    required this.onTitleChanged,
    required this.onCreatePage,
    required this.editor,
    this.trailingActions = const <Widget>[],
  });

  final bool compact;
  final FolioPage? page;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCreatePage;
  final Widget editor;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : FolioSpace.sm,
        0,
        compact ? 0 : FolioSpace.md,
        compact ? 0 : FolioSpace.md,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: Material(
          color: scheme.surface,
          elevation: compact ? 0 : 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.1),
          borderRadius: compact
              ? BorderRadius.zero
              : BorderRadius.circular(FolioRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: page == null
                ? _WorkspaceEmptyState(
                    key: const ValueKey('workspace_empty'),
                    onCreatePage: onCreatePage,
                  )
                : Padding(
                    key: ValueKey('workspace_page_${page!.id}'),
                    padding: const EdgeInsets.fromLTRB(
                      FolioSpace.lg,
                      FolioSpace.md,
                      FolioSpace.lg,
                      FolioSpace.sm,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact
                              ? double.infinity
                              : FolioDesktop.editorMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: titleController,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      filled: false,
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).untitled,
                                      isDense: true,
                                      hintStyle: TextStyle(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    onChanged: onTitleChanged,
                                  ),
                                ),
                                if (!compact) ...trailingActions,
                              ],
                            ),
                            const SizedBox(height: FolioSpace.xs),
                            Expanded(child: editor),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({super.key, required this.onCreatePage});

  final VoidCallback onCreatePage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FolioSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(FolioRadius.xl),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 42,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: FolioSpace.lg),
            Text(
              l10n.noPages,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FolioSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                l10n.quillWorkspaceTourBodyUnavailable,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: FolioSpace.lg),
            FilledButton.icon(
              onPressed: onCreatePage,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.createPage),
            ),
          ],
        ),
      ),
    );
  }
}
