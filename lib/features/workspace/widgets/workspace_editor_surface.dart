import 'dart:math';

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
    this.onOpenSearch,
    required this.editor,
    required this.editorMaxWidth,
  });

  final bool compact;
  final FolioPage? page;
  final List<String> pagePath;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCreatePage;
  final VoidCallback? onOpenSearch;
  final Widget editor;
  final double editorMaxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : FolioSpace.md,
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
                    onOpenSearch: onOpenSearch,
                  )
                : Padding(
                    key: ValueKey('workspace_page_${page!.id}'),
                    padding: const EdgeInsets.fromLTRB(
                      FolioSpace.xl,
                      FolioSpace.md,
                      FolioSpace.xl,
                      FolioSpace.sm,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? double.infinity : editorMaxWidth,
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

class _WorkspaceEmptyState extends StatefulWidget {
  const _WorkspaceEmptyState({
    super.key,
    required this.onCreatePage,
    this.onOpenSearch,
  });

  final VoidCallback onCreatePage;
  final VoidCallback? onOpenSearch;

  @override
  State<_WorkspaceEmptyState> createState() => _WorkspaceEmptyStateState();
}

class _WorkspaceEmptyStateState extends State<_WorkspaceEmptyState>
    with SingleTickerProviderStateMixin {
  static const _tipsEs = <String>[
    'Tip: crea una pagina y usa / para insertar bloques rapidamente.',
    'Folio guarda cambios automaticamente. Solo empieza a escribir.',
    'Usa buscar para saltar entre paginas y volver al flujo rapido.',
    'Las subpaginas te ayudan a mantener cada tema bien organizado.',
  ];
  static const _tipsEn = <String>[
    'Tip: create a page and use / to insert blocks quickly.',
    'Folio auto-saves your changes. Just start writing.',
    'Use search to jump across pages and keep momentum.',
    'Subpages help keep each topic clean and structured.',
  ];

  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<Offset> _textSlide;
  String? _selectedTip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _iconScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedTip != null) return;
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    final tips = isEs ? _tipsEs : _tipsEn;
    _selectedTip = tips[Random().nextInt(tips.length)];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    final tip = _selectedTip ?? _tipsEn.first;
    final headline = isEs ? 'Tu espacio esta listo' : 'Your workspace is ready';
    final subtitle = isEs
        ? 'Crea una pagina para empezar a escribir o usa buscar para volver a una nota existente.'
        : 'Create a page to start writing, or use search to jump back to an existing note.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(FolioSpace.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primaryContainer,
                          scheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(FolioRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 44,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: FolioSpace.lg),
                SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: FolioSpace.md),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: FolioSpace.lg),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(FolioSpace.md),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(FolioRadius.lg),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: FolioAlpha.track,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: FolioSpace.sm),
                            Expanded(
                              child: Text(
                                tip,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FolioSpace.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Wrap(
                    spacing: FolioSpace.sm,
                    runSpacing: FolioSpace.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onCreatePage,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.createPage),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenSearch,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(l10n.search),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            color: scheme.onSurfaceVariant.withValues(
              alpha: FolioAlpha.emphasis,
            ),
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
