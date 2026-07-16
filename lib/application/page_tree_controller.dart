import 'package:flutter/foundation.dart';

import '../models/folio_page.dart';

/// Árbol de páginas: orden, hijos y selección.
class PageTreeController extends ChangeNotifier {
  PageTreeController({
    required List<FolioPage> Function() pagesProvider,
    required Map<String, List<String>> Function() orderProvider,
    required void Function(Map<String, List<String>> order) orderUpdater,
    required String? Function() selectedIdProvider,
    required void Function(String? id) selectedIdUpdater,
  }) : _pagesProvider = pagesProvider,
       _orderProvider = orderProvider,
       _orderUpdater = orderUpdater,
       _selectedIdProvider = selectedIdProvider,
       _selectedIdUpdater = selectedIdUpdater;

  final List<FolioPage> Function() _pagesProvider;
  final Map<String, List<String>> Function() _orderProvider;
  final void Function(Map<String, List<String>> order) _orderUpdater;
  final String? Function() _selectedIdProvider;
  final void Function(String? id) _selectedIdUpdater;

  String _orderKeyForParent(String? parentId) => parentId ?? '';

  List<FolioPage> get pages => List.unmodifiable(_pagesProvider());
  String? get selectedPageId => _selectedIdProvider();

  FolioPage? pageById(String id) {
    for (final p in _pagesProvider()) {
      if (p.id == id) return p;
    }
    return null;
  }

  FolioPage? get selectedPage {
    final id = selectedPageId;
    if (id == null) return null;
    return pageById(id);
  }

  void ensureOrderForCurrentPages() {
    final pages = _pagesProvider();
    final order = Map<String, List<String>>.from(_orderProvider());
    final byId = <String, FolioPage>{for (final p in pages) p.id: p};
    for (final entry in order.entries.toList()) {
      final next = List<String>.from(entry.value)
        ..removeWhere((id) => !byId.containsKey(id));
      if (next.isEmpty) {
        order.remove(entry.key);
      } else {
        order[entry.key] = next;
      }
    }
    final childrenByParent = <String, List<String>>{};
    for (final p in pages) {
      final key = _orderKeyForParent(p.parentId);
      (childrenByParent[key] ??= <String>[]).add(p.id);
    }
    for (final entry in childrenByParent.entries) {
      final existing = order.putIfAbsent(entry.key, () => <String>[]);
      final present = existing.toSet();
      for (final id in entry.value) {
        if (!present.contains(id)) {
          existing.add(id);
        }
      }
    }
    _orderUpdater(order);
  }

  List<String> pageOrderForParent(String? parentId) {
    ensureOrderForCurrentPages();
    return List.unmodifiable(
      _orderProvider()[_orderKeyForParent(parentId)] ?? const <String>[],
    );
  }

  List<FolioPage> childrenForParent(String? parentId) {
    ensureOrderForCurrentPages();
    final order = _orderProvider()[_orderKeyForParent(parentId)] ?? const [];
    final byId = <String, FolioPage>{
      for (final p in _pagesProvider())
        if (!p.isTrashed) p.id: p,
    };
    return order
        .map((id) => byId[id])
        .whereType<FolioPage>()
        .toList(growable: false);
  }

  void selectPage(String? pageId) {
    _selectedIdUpdater(pageId);
    notifyListeners();
  }

  bool isDescendant({required String ancestorId, required String nodeId}) {
    final pages = _pagesProvider();
    String? current = nodeId;
    while (current != null) {
      if (current == ancestorId) return true;
      FolioPage? page;
      for (final p in pages) {
        if (p.id == current) {
          page = p;
          break;
        }
      }
      current = page?.parentId;
    }
    return false;
  }
}
