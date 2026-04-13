part of 'workspace_page.dart';

extension _WorkspacePageToolsModule on _WorkspacePageState {
  String _suggestMarkdownFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.md';
  }

  Future<FolioMarkdownImportMode?> _askMarkdownImportMode() {
    final page = _s.selectedPage;
    if (page == null) {
      return Future.value(FolioMarkdownImportMode.newPage);
    }
    final l10n = AppLocalizations.of(context)!;
    return showDialog<FolioMarkdownImportMode>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.markdownImportModeDialogTitle),
        content: Text(l10n.markdownImportModeDialogBody),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.newPage),
            child: Text(l10n.markdownImportModeNewPage),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.appendToCurrentPage),
            child: Text(l10n.markdownImportModeAppend),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.replaceCurrentPage),
            child: Text(l10n.markdownImportModeReplace),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentPageAsTemplate() async {
    final page = _s.selectedPage;
    if (page == null) return;
    final l10n = AppLocalizations.of(context);
    String name = page.title.isNotEmpty ? page.title : l10n.untitledFallback;
    String description = '';
    String category = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(l10n.saveAsTemplateTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  onChanged: (v) => category = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    _s.savePageAsTemplate(
      page.id,
      name: name.trim().isNotEmpty ? name.trim() : null,
      description: description.trim(),
      category: category.trim(),
    );
    if (!mounted) return;
    _snack(l10n.templateSaved);
  }

  Future<void> _importMarkdownFile() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context)!;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final path = pick.files.single.path;
    if (path == null || path.trim().isEmpty) {
      _snack(l10n.markdownImportCouldNotReadPath);
      return;
    }
    final mode = await _askMarkdownImportMode();
    if (mode == null) return;
    try {
      final markdown = await File(path).readAsString();
      final title = pick.files.single.name.replaceFirst(
        RegExp(r'\.(md|markdown)$', caseSensitive: false),
        '',
      );
      final result = _s.importMarkdownDocument(
        markdown,
        title: title,
        mode: mode,
      );
      if (!mounted) return;
      _snack(
        l10n.markdownImportedBlocks(result.pageTitle, result.blockCount),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.markdownImportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToMarkdown() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context)!;
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportMarkdownFileDialogTitle,
      fileName: _suggestMarkdownFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      final markdown = _s.exportPageAsMarkdown(page.id);
      await File(destination).writeAsString(markdown);
      if (!mounted) return;
      _snack(l10n.markdownExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.markdownExportFailedWithError('$e'));
    }
  }

  String _suggestWebSlugFromTitle(String title) {
    var s = title.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.isEmpty) return 'page';
    if (s.length > 48) {
      s = s.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
    }
    return s.isEmpty ? 'page' : s;
  }

  Future<void> _publishCurrentPageToWeb() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10nRoot = AppLocalizations.of(context)!;
    if (Firebase.apps.isEmpty) {
      _snack(l10nRoot.firebaseUnavailablePublish);
      return;
    }
    if (!widget.cloudAccountController.isSignedIn) {
      _snack(l10nRoot.signInCloudToPublishWeb);
      return;
    }
    if (!widget.folioCloudEntitlements.snapshot.canPublishToWeb) {
      _snack(l10nRoot.planMissingWebPublish);
      return;
    }
    final slugController = TextEditingController(
      text: _suggestWebSlugFromTitle(page.title),
    );
    final snap = widget.folioCloudEntitlements.snapshot;
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(l10n.publishWebDialogTitle),
            content: TextField(
              controller: slugController,
              decoration: InputDecoration(
                labelText: l10n.publishWebSlugLabel,
                hintText: l10n.publishWebSlugHint,
                helperText: l10n.publishWebSlugHelper,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.publishWebAction),
              ),
            ],
          );
        },
      );
      if (go != true || !mounted) return;
      final slug = slugController.text.trim();
      if (slug.isEmpty) {
        _snack(l10nRoot.publishWebEmptySlug);
        return;
      }
      String? appIconDataUri;
      try {
        final data = await rootBundle.load('assets/icons/folio.ico');
        appIconDataUri =
            'data:image/x-icon;base64,${base64Encode(data.buffer.asUint8List())}';
      } catch (_) {}
      final html = folioPageExportHtmlDocument(
        page,
        appIconDataUri: appIconDataUri,
        pagePublishedSubtitle: l10nRoot.pageHtmlExportPublishedWithFolio,
      );
      final res = await publishHtmlPage(
        slug: slug,
        html: html,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      _snack(l10nRoot.publishWebSuccessWithUrl('${res.publicUrl}'));
      await launchUrl(res.publicUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(l10nRoot.publishWebFailedWithError('$e'));
    } finally {
      slugController.dispose();
    }
  }
}
