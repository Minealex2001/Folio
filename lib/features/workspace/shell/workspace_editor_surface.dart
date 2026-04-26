import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import 'workspace_home_view.dart';

class WorkspaceEditorSurface extends StatelessWidget {
  const WorkspaceEditorSurface({
    super.key,
    required this.compact,
    required this.mobileOptimized,
    required this.readOnlyMode,
    required this.page,
    required this.pagePath,
    required this.titleController,
    required this.onTitleChanged,
    required this.onCreatePage,
    this.onOpenSearch,
    required this.editor,
    required this.editorMaxWidth,
    this.propertiesSection,
    required this.session,
    required this.appSettings,
    required this.onSelectPage,
    this.onOpenTaskInPage,
    this.onAskAiAboutUpcomingTasks,
    this.onOpenSettings,
    this.onOpenGraph,
    this.onOpenTemplateGallery,
    this.onLockVault,
    this.onForceSyncDevices,
    this.onQuickAddTask,
    this.onAddRootFolder,
    this.onImportMarkdown,
    required this.cloudAccount,
    required this.folioCloudEntitlements,
    required this.mobilePreviewReadOnly,
    required this.onOpenReleaseNotes,
  });

  final bool compact;
  final bool mobileOptimized;
  final bool readOnlyMode;
  final FolioPage? page;
  final List<String> pagePath;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCreatePage;
  final void Function([String? initialQuery])? onOpenSearch;
  final Widget editor;
  final double editorMaxWidth;
  final Widget? propertiesSection;
  final VaultSession session;
  final AppSettings appSettings;
  final ValueChanged<String> onSelectPage;
  final void Function(String pageId, String blockId)? onOpenTaskInPage;
  final VoidCallback? onAskAiAboutUpcomingTasks;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenGraph;
  final VoidCallback? onOpenTemplateGallery;
  final VoidCallback? onLockVault;
  final VoidCallback? onForceSyncDevices;
  final VoidCallback? onQuickAddTask;
  final VoidCallback? onAddRootFolder;
  final VoidCallback? onImportMarkdown;
  final CloudAccountController cloudAccount;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final bool mobilePreviewReadOnly;
  final Future<void> Function(BuildContext context) onOpenReleaseNotes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final outerPadding = mobileOptimized
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(
            compact ? 0 : FolioSpace.md,
            0,
            compact ? 0 : FolioSpace.md,
            compact ? 0 : FolioSpace.md,
          );
    final contentPadding = mobileOptimized
        ? const EdgeInsets.fromLTRB(
            FolioSpace.md,
            FolioSpace.sm,
            FolioSpace.md,
            FolioSpace.xs,
          )
        : const EdgeInsets.fromLTRB(
            FolioSpace.xl,
            FolioSpace.md,
            FolioSpace.xl,
            FolioSpace.sm,
          );
    return Padding(
      padding: outerPadding,
      child: AnimatedContainer(
        duration: FolioMotion.medium1,
        curve: FolioMotion.emphasized,
        child: Material(
          color: scheme.surface,
          elevation: compact || mobileOptimized ? FolioElevation.none : 2,
          shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.faint),
          borderRadius: compact || mobileOptimized
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
                ? WorkspaceHomeView(
                    key: const ValueKey('workspace_home'),
                    session: session,
                    appSettings: appSettings,
                    onCreatePage: onCreatePage,
                    onOpenSearch: onOpenSearch,
                    onSelectPage: onSelectPage,
                    compact: compact,
                    mobileOptimized: mobileOptimized,
                    onOpenTaskInPage: onOpenTaskInPage,
                    onAskAiAboutUpcomingTasks: onAskAiAboutUpcomingTasks,
                    onOpenSettings: onOpenSettings,
                    onOpenGraph: onOpenGraph,
                    onOpenTemplateGallery: onOpenTemplateGallery,
                    onLockVault: onLockVault,
                    onForceSyncDevices: onForceSyncDevices,
                    onQuickAddTask: onQuickAddTask,
                    onAddRootFolder: onAddRootFolder,
                    onImportMarkdown: onImportMarkdown,
                    cloudAccount: cloudAccount,
                    folioCloudEntitlements: folioCloudEntitlements,
                    mobilePreviewReadOnly: mobilePreviewReadOnly,
                    onOpenReleaseNotes: onOpenReleaseNotes,
                  )
                : Padding(
                    key: ValueKey('workspace_page_${page!.id}'),
                    padding: contentPadding,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact || mobileOptimized
                              ? double.infinity
                              : editorMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (pagePath.isNotEmpty)
                              _PagePathRow(
                                pathSegments: pagePath,
                                compact: mobileOptimized,
                              ),
                            if (pagePath.isNotEmpty)
                              const SizedBox(height: FolioSpace.xs),
                            if (readOnlyMode)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: mobileOptimized ? 6 : 0,
                                ),
                                child: Text(
                                  titleController.text.trim().isEmpty
                                      ? AppLocalizations.of(context).untitled
                                      : titleController.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (mobileOptimized
                                              ? theme.textTheme.headlineMedium
                                              : theme.textTheme.headlineSmall)
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurface,
                                          ),
                                ),
                              )
                            else
                              TextField(
                                controller: titleController,
                                minLines: 1,
                                maxLines: 3,
                                keyboardType: TextInputType.multiline,
                                style:
                                    (mobileOptimized
                                            ? theme.textTheme.headlineMedium
                                            : theme.textTheme.headlineSmall)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  isDense: mobileOptimized,
                                  contentPadding: mobileOptimized
                                      ? const EdgeInsets.symmetric(vertical: 6)
                                      : null,
                                  hintText: AppLocalizations.of(
                                    context,
                                  ).untitled,
                                  hintStyle: TextStyle(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: FolioAlpha.emphasis,
                                    ),
                                  ),
                                ),
                                onChanged: onTitleChanged,
                              ),
                            ?propertiesSection,
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

class _PagePathRow extends StatelessWidget {
  const _PagePathRow({required this.pathSegments, required this.compact});

  final List<String> pathSegments;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: compact ? 20 : 24,
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
              fontSize: compact ? 11 : null,
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
