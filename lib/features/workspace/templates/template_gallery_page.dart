import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page_template.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../services/folio_cloud/folio_cloud_reachability.dart';
import '../../../services/community_templates/community_template_store.dart';
import '../../../session/vault_session.dart';
import 'template_categories.dart';
import '../../onboarding/cloud_sign_in_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../app/widgets/folio_error_card.dart';

/// Pantalla completa de galería de plantillas (locales y comunidad).

class TemplateGalleryResult {
  const TemplateGalleryResult({this.template});

  final FolioPageTemplate? template;
}

String _templateGalleryCloudAuthError(AppLocalizations l10n, String code) {
  switch (code.trim().toLowerCase()) {
    case 'invalid-email':
      return l10n.cloudAuthErrorInvalidEmail;
    case 'wrong-password':
      return l10n.cloudAuthErrorWrongPassword;
    case 'user-not-found':
      return l10n.cloudAuthErrorUserNotFound;
    case 'user-disabled':
      return l10n.cloudAuthErrorUserDisabled;
    case 'invalid-credential':
      return l10n.cloudAuthErrorInvalidCredential;
    case 'password-reset-required':
      return l10n.cloudAuthErrorPasswordResetRequired;
    case 'invalid-token':
      return l10n.cloudAuthErrorInvalidToken;
    case 'token-expired':
      return l10n.cloudAuthErrorTokenExpired;
    case 'token-used':
      return l10n.cloudAuthErrorTokenUsed;
    case 'already-verified':
      return l10n.cloudAccountVerificationNowVerified;
    case 'network-request-failed':
      return l10n.cloudAuthErrorNetwork;
    case 'too-many-requests':
      return l10n.cloudAuthErrorTooManyRequests;
    case 'operation-not-allowed':
      return l10n.cloudAuthErrorOperationNotAllowed;
    default:
      return l10n.cloudAuthErrorGeneric;
  }
}

/// Abre la galería de plantillas como pantalla completa (no diálogo).
Future<TemplateGalleryResult?> openTemplateGalleryPage({
  required BuildContext context,
  required VaultSession session,
  required CloudAccountController cloud,
}) {
  return Navigator.of(context).push<TemplateGalleryResult>(
    MaterialPageRoute<TemplateGalleryResult>(
      builder: (context) => TemplateGalleryPage(session: session, cloud: cloud),
    ),
  );
}

enum _TemplateSortMode { recent, name }

class TemplateGalleryPage extends StatefulWidget {
  const TemplateGalleryPage({
    super.key,
    required this.session,
    required this.cloud,
  });

  final VaultSession session;
  final CloudAccountController cloud;

  @override
  State<TemplateGalleryPage> createState() => _TemplateGalleryPageState();
}

class _TemplateGalleryPageState extends State<TemplateGalleryPage>
    with SingleTickerProviderStateMixin {
  static const int _communityPageSize = 40;

  String _filter = '';
  String _category = '';
  String? _selectedId;
  _TemplateSortMode _sortMode = _TemplateSortMode.recent;

  late TabController _tabController;
  final CommunityTemplateStore _communityStore = CommunityTemplateStore();
  List<CommunityTemplateEntry> _communityEntries = [];
  var _communityLoading = false;
  var _communityLoadingMore = false;
  String? _communityError;
  String? _selectedCommunityId;
  var _communityUseBusy = false;
  CommunityTemplateSort _communitySort = CommunityTemplateSort.recent;
  int _communityPage = 0;
  int _communityTotal = 0;
  Timer? _communitySearchDebounce;

  List<FolioPageTemplate> get _allTemplates => widget.session.pageTemplates;

  List<String> get _categories {
    final present = _allTemplates
        .map((template) => normalizeFolioTemplateCategory(template.category))
        .toSet();
    return kFolioTemplateCategoryIds
        .where((categoryId) => present.contains(categoryId))
        .toList();
  }

  List<FolioPageTemplate> get _templates {
    final query = _filter.trim().toLowerCase();
    final filtered = _allTemplates.where((template) {
      if (_category.isNotEmpty &&
          normalizeFolioTemplateCategory(template.category) != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      return template.name.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.category.toLowerCase().contains(query) ||
          _previewTextFor(template).toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortMode) {
        case _TemplateSortMode.recent:
          return b.createdAtMs.compareTo(a.createdAtMs);
        case _TemplateSortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return filtered;
  }

  FolioPageTemplate? get _selected {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final template in _allTemplates) {
      if (template.id == selectedId) return template;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _syncSelection();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _communitySearchDebounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      unawaited(_loadCommunityTemplates());
    }
  }

  /// Espera a que el usuario deje de teclear antes de volver a pedir al
  /// servidor (a diferencia del filtro local, que es en memoria e instantáneo).
  void _scheduleCommunitySearch() {
    _communitySearchDebounce?.cancel();
    _communitySearchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadCommunityTemplates());
    });
  }

  bool get _communityHasMore => _communityEntries.length < _communityTotal;

  CommunityTemplateEntry? get _selectedCommunity {
    final id = _selectedCommunityId;
    if (id == null) return null;
    for (final e in _communityEntries) {
      if (e.docId == id) return e;
    }
    return null;
  }

  /// Búsqueda/filtro/orden/paginación en servidor (Fase 4): `reset: true`
  /// (default) sustituye la página actual; `reset: false` añade la siguiente
  /// página al final (botón "Cargar más").
  Future<void> _loadCommunityTemplates({bool reset = true}) async {
    if (!CommunityTemplateStore.isFirebaseReady) {
      setState(() {
        _communityError = '';
        _communityLoading = false;
      });
      return;
    }
    if (!reset && (_communityLoadingMore || !_communityHasMore)) return;
    final nextPage = reset ? 0 : _communityPage + 1;
    setState(() {
      if (reset) {
        _communityLoading = true;
      } else {
        _communityLoadingMore = true;
      }
      _communityError = null;
    });
    try {
      final result = await _communityStore.search(
        query: _filter,
        category: _category.isEmpty ? null : _category,
        sort: _communitySort,
        page: nextPage,
        limit: _communityPageSize,
      );
      if (!mounted) return;
      setState(() {
        _communityEntries = reset
            ? result.items
            : [..._communityEntries, ...result.items];
        _communityTotal = result.total;
        _communityPage = result.page;
        _communityLoading = false;
        _communityLoadingMore = false;
        _communityError = null;
        _syncCommunitySelection();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _communityLoading = false;
        _communityLoadingMore = false;
        _communityError = '$e';
      });
    }
  }

  void _syncCommunitySelection() {
    final visible = _communityEntries;
    if (visible.isEmpty) {
      _selectedCommunityId = null;
      return;
    }
    if (!visible.any((e) => e.docId == _selectedCommunityId)) {
      _selectedCommunityId = visible.first.docId;
    }
  }

  Future<void> _openCloudSignIn() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isAvailable) return;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final ok = await folioGoogleApisReachable();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cloudAuthErrorNetwork)));
        return;
      }
    }
    if (!mounted) return;
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CloudSignInDialog(
        l10n: l10n,
        cloud: widget.cloud,
        onAuthError: (c) => _templateGalleryCloudAuthError(l10n, c),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _shareToCommunity(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isAvailable || !CommunityTemplateStore.isFirebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityUnavailable)),
      );
      return;
    }
    if (!widget.cloud.isSignedIn) {
      await _openCloudSignIn();
      if (!widget.cloud.isSignedIn || !mounted) return;
    }
    final confirm = await FolioDialog.confirm(
      context,
      title: Text(l10n.templateCommunityShareTitle),
      content: Text(l10n.templateCommunityShareBody),
      confirmLabel: l10n.templateCommunityShareConfirm,
    );
    if (confirm != true || !mounted) return;
    try {
      await _communityStore.publishTemplate(template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityShareSuccess)),
      );
      await _loadCommunityTemplates();
    } on CommunityTemplateApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'community_template_upload_banned'
          ? l10n.templateCommunityUploadBanned
          : l10n.templateCommunityShareError(e.message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityShareError('$e'))),
      );
    }
  }

  Future<void> _reportCommunityListing(CommunityTemplateEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isSignedIn) {
      await _openCloudSignIn();
      if (!widget.cloud.isSignedIn || !mounted) return;
    }
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.templateCommunityReportTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.templateCommunityReportBody),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.templateCommunityReportReasonHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.templateCommunityReportConfirm),
            ),
          ],
        );
      },
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await _communityStore.reportTemplate(entry.docId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityReportSuccess)),
      );
    } on CommunityTemplateApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'already_reported'
          ? l10n.templateCommunityReportAlready
          : l10n.templateCommunityReportError(e.message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityReportError('$e'))),
      );
    }
  }

  Future<void> _useCommunitySelection() async {
    final l10n = AppLocalizations.of(context);
    final entry = _selectedCommunity;
    if (entry == null || _communityUseBusy) return;
    if (!widget.cloud.isSignedIn) {
      await _openCloudSignIn();
      if (!widget.cloud.isSignedIn || !mounted) return;
    }
    setState(() => _communityUseBusy = true);
    try {
      final parsed = await _communityStore.downloadTemplate(
        entry.storageDownloadUrl,
        storagePath: entry.storagePath,
      );
      unawaited(_communityStore.recordDownload(entry.docId));
      if (!mounted) return;
      const uuid = Uuid();
      final forPage = FolioPageTemplate(
        id: uuid.v4(),
        name: parsed.name,
        description: parsed.description,
        emoji: parsed.emoji,
        category: parsed.category,
        createdAtMs: parsed.createdAtMs,
        blocks: parsed.blocks,
      );
      Navigator.pop(context, TemplateGalleryResult(template: forPage));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityDownloadError('$e'))),
      );
    } finally {
      if (mounted) setState(() => _communityUseBusy = false);
    }
  }

  /// Descarga el contenido real de una plantilla de comunidad y lo muestra en
  /// un diálogo de solo lectura, sin comprometerse todavía a usarla/guardarla
  /// (y sin contar como descarga a efectos de popularidad).
  Future<void> _previewCommunityTemplate(CommunityTemplateEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isSignedIn) {
      await _openCloudSignIn();
      if (!widget.cloud.isSignedIn || !mounted) return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: FolioLoadingIndicator()),
    );
    try {
      final parsed = await _communityStore.downloadTemplate(
        entry.storageDownloadUrl,
        storagePath: entry.storagePath,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => _TemplateContentPreviewDialog(template: parsed),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityDownloadError('$e'))),
      );
    }
  }

  Future<void> _addCommunityToVault(CommunityTemplateEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isSignedIn) {
      await _openCloudSignIn();
      if (!widget.cloud.isSignedIn || !mounted) return;
    }
    try {
      final parsed = await _communityStore.downloadTemplate(
        entry.storageDownloadUrl,
        storagePath: entry.storagePath,
      );
      unawaited(_communityStore.recordDownload(entry.docId));
      final local = _communityStore.copyIntoVault(parsed);
      widget.session.addTemplate(local);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityAddedToVault)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityDownloadError('$e'))),
      );
    }
  }

  Future<void> _deleteCommunityListing(CommunityTemplateEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.cloud.isSignedIn) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.templateCommunityDeleteTitle),
      content: Text(l10n.templateCommunityDeleteBody(entry.name)),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await _communityStore.deleteMyTemplate(
        docId: entry.docId,
        storagePath: entry.storagePath,
      );
      if (!mounted) return;
      setState(() {
        _communityEntries = _communityEntries
            .where((e) => e.docId != entry.docId)
            .toList();
        _syncCommunitySelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityDeleteSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateCommunityDeleteError('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final templates = _templates;
    final selected = _selected;
    final totalTemplates = _allTemplates.length;
    final communityList = _communityEntries;
    final communitySelected = _selectedCommunity;
    final isLocalTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) {
            final tabIsLocal = _tabController.index == 0;
            final line = tabIsLocal
                ? (totalTemplates == templates.length
                      ? l10n.templateCount(totalTemplates)
                      : l10n.templateFilteredCount(
                          templates.length,
                          totalTemplates,
                        ))
                : (communityList.length == _communityTotal
                      ? l10n.templateCount(_communityTotal)
                      : l10n.templateFilteredCount(
                          communityList.length,
                          _communityTotal,
                        ));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.templateGalleryTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: l10n.templateGalleryTabLocal),
            Tab(text: l10n.templateGalleryTabCommunity),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLocalTab(
                    l10n: l10n,
                    theme: theme,
                    scheme: scheme,
                    templates: templates,
                    selected: selected,
                  ),
                  _buildCommunityTab(
                    l10n: l10n,
                    theme: theme,
                    scheme: scheme,
                    communityList: communityList,
                    communitySelected: communitySelected,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: Text(l10n.clear),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const TemplateGalleryResult()),
                    child: Text(l10n.templateBlankPage),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        _footerUseEnabled(
                          isLocalTab: isLocalTab,
                          selected: selected,
                          communitySelected: communitySelected,
                        )
                        ? () => _footerUse(
                            isLocalTab: isLocalTab,
                            selected: selected,
                          )
                        : null,
                    child: _communityUseBusy
                        ? FolioLoadingIndicator(
                            size: FolioLoadingSize.small,
                            color: scheme.onPrimary,
                          )
                        : Text(l10n.templateUse),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _footerUseEnabled({
    required bool isLocalTab,
    required FolioPageTemplate? selected,
    required CommunityTemplateEntry? communitySelected,
  }) {
    if (_communityUseBusy) return false;
    if (isLocalTab) return selected != null;
    return communitySelected != null &&
        !(_communityLoading && _communityEntries.isEmpty);
  }

  Future<void> _footerUse({
    required bool isLocalTab,
    required FolioPageTemplate? selected,
  }) async {
    if (isLocalTab) {
      if (selected != null) _use(selected);
      return;
    }
    await _useCommunitySelection();
  }

  Widget _buildLocalTab({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme scheme,
    required List<FolioPageTemplate> templates,
    required FolioPageTemplate? selected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: l10n.templateSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filter = value;
                            _syncSelection();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _importTemplate,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text(l10n.templateImport),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<_TemplateSortMode>(
                      value: _sortMode,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _sortMode = value;
                          _syncSelection();
                        });
                      },
                      items: [
                        DropdownMenuItem(
                          value: _TemplateSortMode.recent,
                          child: Text(l10n.templateSortRecent),
                        ),
                        DropdownMenuItem(
                          value: _TemplateSortMode.name,
                          child: Text(l10n.templateSortName),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(l10n.searchFilterAll),
                            selected: _category.isEmpty,
                            onSelected: (_) {
                              setState(() {
                                _category = '';
                                _syncSelection();
                              });
                            },
                          ),
                        ),
                        for (final category in _categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                templateCategoryLabel(l10n, category),
                              ),
                              selected: _category == category,
                              onSelected: (_) {
                                setState(() {
                                  _category = _category == category
                                      ? ''
                                      : category;
                                  _syncSelection();
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: templates.isEmpty
                      ? _TemplateEmptyState(
                          isFiltering:
                              _filter.trim().isNotEmpty || _category.isNotEmpty,
                          onImport: _importTemplate,
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 172,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: templates.length,
                          itemBuilder: (_, index) {
                            final template = templates[index];
                            return _TemplateCard(
                              template: template,
                              previewText: _previewTextFor(template),
                              selected: template.id == _selectedId,
                              onTap: () =>
                                  setState(() => _selectedId = template.id),
                              onDoubleTap: () => _use(template),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 292,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selected == null
                ? const SizedBox(
                    key: ValueKey('empty_detail'),
                    width: 292,
                    child: _TemplateNoSelectionPanel(),
                  )
                : SizedBox(
                    key: ValueKey(selected.id),
                    width: 292,
                    child: _TemplateDetailPanel(
                      template: selected,
                      previewText: _previewTextFor(selected),
                      onPreview: () => _previewLocalTemplate(selected),
                      onUse: () => _use(selected),
                      onEdit: () => _editTemplate(selected),
                      onDelete: () => _confirmDelete(selected),
                      onExport: () => _exportTemplate(selected),
                      onShareToCommunity: () {
                        unawaited(_shareToCommunity(selected));
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTab({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme scheme,
    required List<CommunityTemplateEntry> communityList,
    required CommunityTemplateEntry? communitySelected,
  }) {
    if (!CommunityTemplateStore.isFirebaseReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.templateCommunityUnavailable,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_communityLoading && _communityEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: FolioTemplateGallerySkeleton(),
      );
    }

    if (_communityError != null && _communityEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FolioErrorCard(
              title: l10n.templateCommunityRefresh,
              message: l10n.templateCommunityLoadError(_communityError!),
              icon: Icons.cloud_off_rounded,
              onRetry: _loadCommunityTemplates,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: l10n.templateSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() => _filter = value);
                          _scheduleCommunitySearch();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: l10n.templateCommunityRefresh,
                      onPressed: _communityLoading
                          ? null
                          : _loadCommunityTemplates,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 4),
                    DropdownButton<CommunityTemplateSort>(
                      value: _communitySort,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _communitySort = value);
                        unawaited(_loadCommunityTemplates());
                      },
                      items: [
                        DropdownMenuItem(
                          value: CommunityTemplateSort.recent,
                          child: Text(l10n.templateSortRecent),
                        ),
                        DropdownMenuItem(
                          value: CommunityTemplateSort.popular,
                          child: Text(l10n.templateSortPopular),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l10n.searchFilterAll),
                          selected: _category.isEmpty,
                          onSelected: (_) {
                            setState(() => _category = '');
                            unawaited(_loadCommunityTemplates());
                          },
                        ),
                      ),
                      for (final category in kFolioTemplateCategoryIds)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(templateCategoryLabel(l10n, category)),
                            selected: _category == category,
                            onSelected: (_) {
                              setState(() {
                                _category = _category == category
                                    ? ''
                                    : category;
                              });
                              unawaited(_loadCommunityTemplates());
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: communityList.isEmpty
                      ? Center(
                          child: Text(
                            l10n.templateCommunityEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 164,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount:
                              communityList.length +
                              (_communityHasMore ? 1 : 0),
                          itemBuilder: (_, index) {
                            if (index >= communityList.length) {
                              return Center(
                                child: _communityLoadingMore
                                    ? const FolioLoadingIndicator(
                                        size: FolioLoadingSize.small,
                                      )
                                    : TextButton(
                                        onPressed: () => unawaited(
                                          _loadCommunityTemplates(reset: false),
                                        ),
                                        child: Text(
                                          l10n.templateCommunityLoadMore,
                                        ),
                                      ),
                              );
                            }
                            final entry = communityList[index];
                            return _CommunityTemplateCard(
                              entry: entry,
                              previewText: entry.description,
                              selected: entry.docId == _selectedCommunityId,
                              onTap: () => setState(
                                () => _selectedCommunityId = entry.docId,
                              ),
                              onDoubleTap: () async {
                                setState(
                                  () => _selectedCommunityId = entry.docId,
                                );
                                await _useCommunitySelection();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 292,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: communitySelected == null
                ? const SizedBox(
                    key: ValueKey('comm_empty'),
                    width: 292,
                    child: _TemplateNoSelectionPanel(),
                  )
                : SizedBox(
                    key: ValueKey(communitySelected.docId),
                    width: 292,
                    child: _CommunityTemplateDetailPanel(
                      entry: communitySelected,
                      l10n: l10n,
                      isOwner: widget.cloud.uid == communitySelected.ownerUid,
                      canReport: widget.cloud.isSignedIn,
                      onPreview: () {
                        unawaited(_previewCommunityTemplate(communitySelected));
                      },
                      onUse: () {
                        unawaited(_useCommunitySelection());
                      },
                      onAddToVault: () {
                        unawaited(_addCommunityToVault(communitySelected));
                      },
                      onDelete: () {
                        unawaited(_deleteCommunityListing(communitySelected));
                      },
                      onReport: () {
                        unawaited(_reportCommunityListing(communitySelected));
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _filter = '';
      _category = '';
      _sortMode = _TemplateSortMode.recent;
      _communitySort = CommunityTemplateSort.recent;
      _syncSelection();
    });
    unawaited(_loadCommunityTemplates());
  }

  void _syncSelection() {
    final visibleTemplates = _templates;
    if (visibleTemplates.isEmpty) {
      _selectedId = null;
      return;
    }
    if (!visibleTemplates.any((template) => template.id == _selectedId)) {
      _selectedId = visibleTemplates.first.id;
    }
  }

  void _use(FolioPageTemplate template) {
    Navigator.pop(context, TemplateGalleryResult(template: template));
  }

  /// Ya está en memoria (sin descarga ni sesión): abre el diálogo de
  /// contenido directamente, a diferencia de la versión de comunidad.
  Future<void> _previewLocalTemplate(FolioPageTemplate template) {
    return showDialog<void>(
      context: context,
      builder: (_) => _TemplateContentPreviewDialog(template: template),
    );
  }

  Future<void> _editTemplate(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    String emoji = template.emoji ?? '';
    String name = template.name;
    String description = template.description;
    String category = normalizeFolioTemplateCategory(template.category);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => FolioDialog(
          title: Text(l10n.templateEdit),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: emoji,
                  decoration: InputDecoration(
                    labelText: l10n.templateEmojiLabel,
                  ),
                  onChanged: (value) => setDialogState(() => emoji = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  onChanged: (value) => setDialogState(() => name = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (value) =>
                      setDialogState(() => description = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  items: [
                    for (final categoryId in kFolioTemplateCategoryIds)
                      DropdownMenuItem(
                        value: categoryId,
                        child: Text(templateCategoryLabel(l10n, categoryId)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => category = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true || !mounted) return;

    widget.session.updateTemplate(
      FolioPageTemplate(
        id: template.id,
        name: name.trim(),
        description: description.trim(),
        emoji: emoji.trim().isEmpty ? null : emoji.trim(),
        category: category.trim(),
        createdAtMs: template.createdAtMs,
        blocks: template.blocks,
      ),
    );

    setState(_syncSelection);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.templateUpdated)));
  }

  Future<void> _confirmDelete(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await FolioDialog.confirm(
      context,
      title: Text(l10n.templateDeleteConfirmTitle),
      content: Text(l10n.templateDeleteConfirmBody(template.name)),
      confirmLabel: l10n.delete,
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    widget.session.deleteTemplate(template.id);
    setState(_syncSelection);
  }

  Future<void> _importTemplate() async {
    final l10n = AppLocalizations.of(context);
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['folio-template', 'json'],
      allowMultiple: false,
      dialogTitle: l10n.templateImportPickTitle,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;

    final path = pick.files.single.path;
    if (path == null) return;

    try {
      final template = widget.session.importTemplateFromFile(path);
      if (!mounted) return;
      setState(() {
        _selectedId = template.id;
        _syncSelection();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateImportSuccess)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateImportError('$error'))),
      );
    }
  }

  Future<void> _exportTemplate(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final safeName = template.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.templateExportPickTitle,
      fileName: '$safeName.folio-template',
    );
    if (destination == null || !mounted) return;

    try {
      widget.session.exportTemplateToFile(template, destination);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateExportSuccess)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateExportError('$error'))),
      );
    }
  }

  String _previewTextFor(FolioPageTemplate template) {
    for (final block in template.blocks) {
      final text = block.text.trim();
      if (text.isNotEmpty) return text.replaceAll('\n', ' ');
    }
    return '';
  }
}

class _CommunityTemplateCard extends StatelessWidget {
  const _CommunityTemplateCard({
    required this.entry,
    required this.previewText,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final CommunityTemplateEntry entry;
  final String previewText;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emoji = entry.emoji.trim().isEmpty ? '\u{1F4C4}' : entry.emoji.trim();
    final l10n = AppLocalizations.of(context);
    final categoryColor = folioTemplateCategoryColor(context, entry.category);
    final borderColor = selected ? scheme.secondary : scheme.outlineVariant;
    final borderWidth = selected ? 2.0 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                // Border.paint no admite colores distintos por lado junto a un
                // borderRadius; el acento de categoría se pinta aparte, debajo.
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(selected ? 28 : 12),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.onSecondaryContainer.withAlpha(26)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${entry.blockCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    templateCategoryLabel(
                      l10n,
                      normalizeFolioTemplateCategory(entry.category),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer.withAlpha(185)
                          : categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      previewText.trim().isEmpty
                          ? AppLocalizations.of(context).templatePreviewEmpty
                          : previewText.replaceAll('\n', ' '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onSecondaryContainer.withAlpha(210)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: ColoredBox(color: categoryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityTemplateDetailPanel extends StatelessWidget {
  const _CommunityTemplateDetailPanel({
    required this.entry,
    required this.l10n,
    required this.isOwner,
    required this.canReport,
    required this.onPreview,
    required this.onUse,
    required this.onAddToVault,
    required this.onDelete,
    required this.onReport,
  });

  final CommunityTemplateEntry entry;
  final AppLocalizations l10n;
  final bool isOwner;
  final bool canReport;
  final VoidCallback onPreview;
  final VoidCallback onUse;
  final VoidCallback onAddToVault;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emoji = entry.emoji.trim().isEmpty ? '\u{1F4C4}' : entry.emoji.trim();
    final createdLabel = entry.createdAt == null
        ? ''
        : _CommunityTemplateDetailPanel._formatDate(entry.createdAt!);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (entry.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.view_agenda_outlined,
                  label: l10n.templateBlockCount(entry.blockCount),
                ),
                _MetaChip(
                  icon: Icons.sell_outlined,
                  label: templateCategoryLabel(
                    l10n,
                    normalizeFolioTemplateCategory(entry.category),
                  ),
                ),
                if (createdLabel.isNotEmpty)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: l10n.templateCreatedOn(createdLabel),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.contentLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.description.trim().isEmpty
                    ? l10n.templatePreviewEmpty
                    : entry.description.replaceAll('\n', ' '),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templatePreviewAction),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateUse),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddToVault,
              icon: const Icon(Icons.library_add_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateCommunityAddToVault),
            ),
            if (canReport) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined, size: 18),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                label: Text(l10n.templateCommunityReportTitle),
              ),
            ],
            if (isOwner) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                label: Text(
                  l10n.templateCommunityDeleteTitle,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

/// Vista de solo lectura del contenido real de una plantilla ya descargada,
/// para decidir si usarla/guardarla antes de comprometerse.
class _TemplateContentPreviewDialog extends StatelessWidget {
  const _TemplateContentPreviewDialog({required this.template});

  final FolioPageTemplate template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final previewBlocks = template.blocks
        .where((b) => b.text.trim().isNotEmpty)
        .toList();

    return Dialog(
      child: SizedBox(
        width: 480,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    template.emoji ?? '📄',
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (template.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  template.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.templateBlockCount(template.blocks.length),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: previewBlocks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.templatePreviewEmpty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: previewBlocks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final block = previewBlocks[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                folioBlockTypeIcon(block.type),
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  block.text.replaceAll('\n', ' '),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.previewText,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final FolioPageTemplate template;
  final String previewText;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final categoryColor = folioTemplateCategoryColor(
      context,
      template.category,
    );
    final blockTypeIcons = folioTemplateBlockTypeIcons(
      template.blocks.map((b) => b.type),
    );
    final borderColor = selected ? scheme.secondary : scheme.outlineVariant;
    final borderWidth = selected ? 2.0 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                // Border.paint no admite colores distintos por lado junto a un
                // borderRadius; el acento de categoría se pinta aparte, debajo.
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(selected ? 28 : 12),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        template.emoji ?? '📄',
                        style: const TextStyle(fontSize: 26),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.onSecondaryContainer.withAlpha(26)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${template.blocks.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    template.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          templateCategoryLabel(
                            l10n,
                            normalizeFolioTemplateCategory(template.category),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? scheme.onSecondaryContainer.withAlpha(185)
                                : categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final icon in blockTypeIcons)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            icon,
                            size: 13,
                            color: selected
                                ? scheme.onSecondaryContainer.withAlpha(185)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      previewText.isEmpty
                          ? AppLocalizations.of(context).templatePreviewEmpty
                          : previewText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onSecondaryContainer.withAlpha(210)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: ColoredBox(color: categoryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateDetailPanel extends StatelessWidget {
  const _TemplateDetailPanel({
    required this.template,
    required this.previewText,
    required this.onPreview,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onShareToCommunity,
  });

  final FolioPageTemplate template;
  final String previewText;
  final VoidCallback onPreview;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onShareToCommunity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  template.emoji ?? '📄',
                  style: const TextStyle(fontSize: 36),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  tooltip: l10n.templateEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (template.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                template.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.view_agenda_outlined,
                  label: l10n.templateBlockCount(template.blocks.length),
                ),
                _MetaChip(
                  icon: Icons.sell_outlined,
                  label: templateCategoryLabel(
                    l10n,
                    normalizeFolioTemplateCategory(template.category),
                  ),
                ),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: l10n.templateCreatedOn(
                    _formatDate(template.createdAtMs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.contentLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                previewText.isEmpty ? l10n.templatePreviewEmpty : previewText,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templatePreviewAction),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateUse),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateEdit),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateExport),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onShareToCommunity,
              icon: const Icon(Icons.public_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.templateCommunityShareTitle),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text(l10n.delete, style: TextStyle(color: scheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(int createdAtMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _TemplateEmptyState extends StatelessWidget {
  const _TemplateEmptyState({
    required this.isFiltering,
    required this.onImport,
  });

  final bool isFiltering;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltering ? Icons.search_off_rounded : Icons.layers_outlined,
                size: 34,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltering ? l10n.noSearchResults : l10n.templateEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(l10n.templateImport),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateNoSelectionPanel extends StatelessWidget {
  const _TemplateNoSelectionPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context).templateSelectHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
