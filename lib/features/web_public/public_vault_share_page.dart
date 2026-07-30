import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../services/folio_cloud/folio_cloud_vault_share.dart';

/// Viewer de libreta pública en `https://folio…/s/{token}` (poll meta/content).
class PublicVaultSharePage extends StatefulWidget {
  const PublicVaultSharePage({super.key, required this.token});

  final String token;

  @override
  State<PublicVaultSharePage> createState() => _PublicVaultSharePageState();
}

class _PublicVaultSharePageState extends State<PublicVaultSharePage> {
  static const _pollInterval = Duration(seconds: 8);

  Timer? _timer;
  String _title = 'Folio';
  String _status = 'Cargando…';
  String? _error;
  int _rev = -1;
  Map<String, dynamic>? _data;
  String? _currentPageId;

  @override
  void initState() {
    super.initState();
    unawaited(_tick());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final meta = await fetchVaultPublicMetaUnauthed(widget.token);
      final name = '${meta['displayName'] ?? ''}'.trim();
      final rev = (meta['rev'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (name.isNotEmpty) {
        setState(() => _title = name);
      }
      if (rev == _rev && _data != null) {
        setState(() {
          _error = null;
          _status = 'Al día · rev $_rev';
        });
        return;
      }
      final content = await fetchVaultPublicContentUnauthed(widget.token);
      if (!mounted) return;
      setState(() {
        _data = content;
        _rev = rev;
        _error = null;
        _status = 'Actualizado · rev $rev';
        final pages = _pages;
        if (_currentPageId == null && pages.isNotEmpty) {
          _currentPageId = '${pages.first['id'] ?? ''}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _status = 'Error al cargar';
      });
    }
  }

  List<Map<String, dynamic>> get _pages {
    final raw = _data?['pages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  Map<String, dynamic>? get _currentPage {
    final pages = _pages;
    if (pages.isEmpty) return null;
    final id = _currentPageId;
    if (id != null) {
      for (final p in pages) {
        if ('${p['id']}' == id) return p;
      }
    }
    return pages.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages;
    final page = _currentPage;
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surface.withValues(alpha: 0.92),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.lg,
                  vertical: FolioSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Solo lectura · Folio',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (_error != null && _data == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(FolioSpace.xl),
                  child: Text(
                    'No se pudo cargar esta libreta.\n$_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 240,
                          child: _NavList(
                            pages: pages,
                            currentId: '${page?['id'] ?? ''}',
                            onSelect: (id) =>
                                setState(() => _currentPageId = id),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: scheme.outlineVariant,
                        ),
                        Expanded(child: _PageBody(page: page)),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.28,
                          child: _NavList(
                            pages: pages,
                            currentId: '${page?['id'] ?? ''}',
                            onSelect: (id) =>
                                setState(() => _currentPageId = id),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        Expanded(child: _PageBody(page: page)),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.pages,
    required this.currentId,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> pages;
  final String currentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (pages.isEmpty) {
      return const Center(child: Text('Sin páginas'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(FolioSpace.sm),
      itemCount: pages.length,
      itemBuilder: (context, i) {
        final p = pages[i];
        final id = '${p['id'] ?? ''}';
        final emoji = '${p['emoji'] ?? ''}'.trim();
        final title = '${p['title'] ?? 'Sin título'}';
        final selected = id == currentId;
        return ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: scheme.primary.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          title: Text(
            emoji.isEmpty ? title : '$emoji $title',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onSelect(id),
        );
      },
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final Map<String, dynamic>? page;

  @override
  Widget build(BuildContext context) {
    if (page == null) {
      return Center(
        child: Text(
          'Cargando contenido…',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final emoji = '${page!['emoji'] ?? ''}'.trim();
    final title = '${page!['title'] ?? 'Sin título'}';
    final blocks = page!['blocks'];
    final blockList = blocks is List
        ? blocks.whereType<Map>().map((e) => e.map((k, v) => MapEntry('$k', v)))
        : const <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.xl,
        FolioSpace.lg,
        FolioSpace.xl,
        FolioSpace.xl,
      ),
      children: [
        Text(
          emoji.isEmpty ? title : '$emoji $title',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: FolioSpace.lg),
        ..._renderBlocks(context, blockList.toList()),
      ],
    );
  }

  List<Widget> _renderBlocks(
    BuildContext context,
    List<Map<String, dynamic>> blocks,
  ) {
    final out = <Widget>[];
    final bullets = <Widget>[];

    void flushBullets() {
      if (bullets.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: FolioSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bullets.toList(),
          ),
        ),
      );
      bullets.clear();
    }

    for (final b in blocks) {
      final type = '${b['type'] ?? 'paragraph'}';
      final text = '${b['text'] ?? ''}';
      if (type == 'bulleted_list_item' || type == 'bullet') {
        bullets.add(
          Padding(
            padding: const EdgeInsets.only(left: FolioSpace.sm, bottom: 4),
            child: Text('• $text'),
          ),
        );
        continue;
      }
      flushBullets();
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: FolioSpace.sm),
          child: _blockWidget(context, type, text),
        ),
      );
    }
    flushBullets();
    return out;
  }

  Widget _blockWidget(BuildContext context, String type, String text) {
    final theme = Theme.of(context).textTheme;
    return switch (type) {
      'h1' => Text(text, style: theme.headlineMedium),
      'h2' => Text(text, style: theme.headlineSmall),
      'h3' => Text(text, style: theme.titleLarge),
      'quote' => Padding(
          padding: const EdgeInsets.only(left: FolioSpace.md),
          child: Text(
            text,
            style: theme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      'code' || 'code_block' => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FolioSpace.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(FolioRadius.sm),
          ),
          child: Text(text, style: theme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        ),
      'divider' => const Divider(),
      'numbered_list_item' || 'number' => Text('1. $text'),
      _ => Text(text, style: theme.bodyLarge),
    };
  }
}
