import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';

class WorkspaceEditorSurface extends StatelessWidget {
  const WorkspaceEditorSurface({
    super.key,
    required this.compact,
    required this.page,
    required this.pagePath,
    required this.titleController,
    required this.onTitleChanged,
    required this.onCreatePage,
    required this.editor,
  });

  final bool compact;
  final FolioPage? page;
  final List<String> pagePath;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCreatePage;
  final Widget editor;

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
        duration: FolioMotion.medium1,
        curve: FolioMotion.emphasized,
        child: Material(
          color: scheme.surface,
          elevation: compact ? FolioElevation.none : 2,
          shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.faint),
          borderRadius: compact
              ? BorderRadius.zero
              : BorderRadius.circular(FolioRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: FolioMotion.short2,
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
                            if (pagePath.isNotEmpty)
                              _PagePathRow(pathSegments: pagePath),
                            if (pagePath.isNotEmpty)
                              const SizedBox(height: FolioSpace.xs),
                            TextField(
                              controller: titleController,
                              minLines: 1,
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: AppLocalizations.of(context).untitled,
                                hintStyle: TextStyle(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: FolioAlpha.emphasis,
                                  ),
                                ),
                              ),
                              onChanged: onTitleChanged,
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

class _PagePathRow extends StatelessWidget {
  const _PagePathRow({required this.pathSegments});

  final List<String> pathSegments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pathSegments.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: scheme.onSurfaceVariant.withValues(alpha: FolioAlpha.emphasis),
          ),
        ),
        itemBuilder: (context, index) {
          return Text(
            pathSegments[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: index == pathSegments.length - 1
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }
}
