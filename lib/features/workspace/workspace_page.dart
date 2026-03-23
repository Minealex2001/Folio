import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/folio_page.dart';
import 'widgets/editor_area.dart';
import 'widgets/sidebar.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  static final _random = Random();

  late final List<FolioPage> _pages;
  late String _selectedPageId;
  late final TextEditingController _contentController;

  FolioPage get _selectedPage =>
      _pages.firstWhere((p) => p.id == _selectedPageId);

  @override
  void initState() {
    super.initState();
    _pages = [
      FolioPage(
        id: '1',
        title: 'Bienvenida',
        content:
            'Esta es Folio, un espacio de trabajo simple.\n\n'
            'Puedes crear, renombrar y eliminar páginas; el contenido se guarda en memoria mientras la app está abierta.',
      ),
      FolioPage(
        id: '2',
        title: 'Notas del día',
        content:
            '- Probar crear una página nueva con +\n'
            '- Renombrar con doble clic o el lápiz\n'
            '- Eliminar con la papelera (queda al menos una)',
      ),
      FolioPage(
        id: '3',
        title: 'Borrador',
        content: '',
      ),
    ];
    _selectedPageId = _pages.first.id;
    _contentController = TextEditingController(text: _selectedPage.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _syncControllerToSelection() {
    _contentController.text = _selectedPage.content;
    _contentController.selection = TextSelection.collapsed(
      offset: _contentController.text.length,
    );
  }

  void _selectPage(String id) {
    setState(() {
      _selectedPageId = id;
    });
    _syncControllerToSelection();
  }

  void _onContentChanged(String value) {
    _selectedPage.content = value;
  }

  void _addPage() {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final page = FolioPage(
      id: id,
      title: 'Nueva página',
      content: '',
    );
    setState(() {
      _pages.add(page);
      _selectedPageId = id;
    });
    _syncControllerToSelection();
  }

  void _deletePage(String id) {
    if (_pages.length <= 1) return;
    final index = _pages.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final wasSelected = _selectedPageId == id;
    setState(() {
      _pages.removeAt(index);
      if (wasSelected) {
        final newIndex = index.clamp(0, _pages.length - 1);
        _selectedPageId = _pages[newIndex].id;
      }
    });
    if (wasSelected) {
      _syncControllerToSelection();
    }
  }

  void _renamePage(BuildContext context, FolioPage page) {
    final titleController = TextEditingController(text: page.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar página'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final next = titleController.text.trim();
              if (next.isNotEmpty) {
                setState(() => page.title = next);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Folio'),
        backgroundColor: const Color(0xFFE8E8E8),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 280,
            child: ColoredBox(
              color: const Color(0xFFEEEEEE),
              child: Sidebar(
                pages: _pages,
                selectedPageId: _selectedPageId,
                onPageSelected: _selectPage,
                onAddPage: _addPage,
                onDeletePage: _deletePage,
                onRenamePage: _renamePage,
                canDelete: _pages.length > 1,
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: EditorArea(
                pageTitle: _selectedPage.title,
                contentController: _contentController,
                onContentChanged: _onContentChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
