import '../../models/block.dart';
import '../../models/folio_columns_data.dart';
import '../../models/folio_database_data.dart';
import '../../models/folio_page.dart';
import '../../models/folio_table_data.dart';
import '../../models/folio_toggle_data.dart';
import '../../models/folio_task_data.dart';
import '../../models/folio_kanban_data.dart';

enum FolioMarkdownImportMode {
  newPage,
  replaceCurrentPage,
  appendToCurrentPage,
}

class FolioMarkdownDocument {
  const FolioMarkdownDocument({required this.title, required this.blocks});

  final String title;
  final List<FolioBlock> blocks;
}

class FolioMarkdownImportResult {
  const FolioMarkdownImportResult({
    required this.pageId,
    required this.pageTitle,
    required this.mode,
    required this.blockCount,
  });

  final String pageId;
  final String pageTitle;
  final FolioMarkdownImportMode mode;
  final int blockCount;
}

class FolioMarkdownCodec {
  static const _defaultTitle = 'Imported page';

  static FolioMarkdownDocument parseDocument(
    String markdown, {
    required String pageId,
    String? fallbackTitle,
    String? sourceApp,
    String? sourceUrl,
  }) {
    final normalized = markdown.replaceAll('\r\n', '\n').trim();
    final frontMatter = _extractFrontMatter(normalized);
    final body = frontMatter.body.trim();
    final title = fallbackTitle?.trim().isNotEmpty == true
        ? fallbackTitle!.trim()
        : (frontMatter.title ??
              _extractFirstHeadingTitle(body) ??
              _defaultTitle);
    final blocks = _parseBlocks(
      body.isEmpty ? '# $title' : body,
      pageId: pageId,
      sourceApp: sourceApp,
      sourceUrl: sourceUrl,
    );
    return FolioMarkdownDocument(
      title: title,
      blocks: blocks.isEmpty
          ? [FolioBlock(id: '${pageId}_b0', type: 'paragraph', text: '')]
          : blocks,
    );
  }

  /// Un solo bloque como Markdown (misma lógica que [exportPage]).
  static String? exportBlockMarkdown(
    FolioBlock block,
    FolioPage page,
    Map<int, int> numberedCounters,
  ) =>
      _renderBlock(block, page, numberedCounters);

  static String exportPage(FolioPage page, {bool includeFrontMatter = true}) {
    final out = <String>[];
    if (includeFrontMatter) {
      out.add('---');
      out.add('title: ${_yamlEscape(page.title)}');
      out.add('pageId: ${_yamlEscape(page.id)}');
      out.add('exportedAt: ${DateTime.now().toUtc().toIso8601String()}');
      out.add('---');
      out.add('');
    }

    final counters = <int, int>{};
    var wroteTitle = false;
    for (final block in page.blocks) {
      final rendered = _renderBlock(block, page, counters);
      if (rendered == null || rendered.trim().isEmpty) continue;
      if (block.type == 'h1') {
        wroteTitle = true;
      }
      if (out.isNotEmpty && out.last.isNotEmpty) {
        out.add('');
      }
      out.add(rendered);
    }

    if (!wroteTitle) {
      final titleHeading =
          '# ${page.title.trim().isEmpty ? _defaultTitle : page.title.trim()}';
      if (out.isNotEmpty && out.first == '---') {
        final insertAt = includeFrontMatter ? 5 : 0;
        out.insert(insertAt, titleHeading);
        out.insert(insertAt + 1, '');
      } else if (out.isEmpty) {
        out.add(titleHeading);
      } else {
        out.insert(0, '');
        out.insert(0, titleHeading);
      }
    }

    return '${out.join('\n').trimRight()}\n';
  }

  /// Parses a Markdown string into a list of [FolioBlock]s.
  /// The [pageId] is used as a prefix for generated block IDs.
  static List<FolioBlock> parseBlocks(
    String markdown, {
    required String pageId,
  }) => _parseBlocks(markdown, pageId: pageId);

  static List<FolioBlock> _parseBlocks(
    String markdown, {
    required String pageId,
    String? sourceApp,
    String? sourceUrl,
  }) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final out = <FolioBlock>[];
    final paragraph = <String>[];
    var i = 0;

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join('\n').trim();
      paragraph.clear();
      if (text.isEmpty) return;
      out.add(
        FolioBlock(
          id: _blockId(pageId, out.length),
          type: 'paragraph',
          text: text,
        ),
      );
    }

    void addSourceBookmark() {
      final url = sourceUrl?.trim() ?? '';
      if (url.isEmpty) return;
      final label = sourceApp?.trim().isNotEmpty == true
          ? 'Imported from ${sourceApp!.trim()}'
          : 'Imported source';
      out.add(
        FolioBlock(
          id: _blockId(pageId, out.length),
          type: 'bookmark',
          text: label,
          url: url,
        ),
      );
    }

    while (i < lines.length) {
      final raw = lines[i];
      final trimmed = raw.trimRight();
      final t = trimmed.trim();

      if (t.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      final codeStart = _parseFenceStart(t);
      if (codeStart != null) {
        flushParagraph();
        final lang = codeStart;
        final buffer = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buffer.add(lines[i]);
          i++;
        }
        if (i < lines.length) {
          i++;
        }
        final content = buffer.join('\n').trimRight();
        if (content.isNotEmpty) {
          if (lang == 'mermaid') {
            out.add(
              FolioBlock(
                id: _blockId(pageId, out.length),
                type: 'mermaid',
                text: content,
              ),
            );
          } else if (lang == 'math') {
            out.add(
              FolioBlock(
                id: _blockId(pageId, out.length),
                type: 'equation',
                text: content,
              ),
            );
          } else {
            out.add(
              FolioBlock(
                id: _blockId(pageId, out.length),
                type: 'code',
                text: content,
                codeLanguage: lang.isEmpty ? 'plaintext' : lang,
              ),
            );
          }
        }
        continue;
      }

      if (_looksLikeMarkdownTable(lines, i)) {
        flushParagraph();
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        final table = _parseMarkdownTable(tableLines);
        if (table != null) {
          out.add(
            FolioBlock(
              id: _blockId(pageId, out.length),
              type: 'table',
              text: table.encode(),
            ),
          );
        }
        continue;
      }

      if (t.startsWith('>')) {
        flushParagraph();
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          quoteLines.add(lines[i]);
          i++;
        }
        final quoted = quoteLines
            .map((line) => line.replaceFirst(RegExp(r'^\s*>\s?'), ''))
            .toList();
        final alert = _parseAlertBlock(quoted);
        if (alert != null) {
          out.add(
            FolioBlock(
              id: _blockId(pageId, out.length),
              type: 'callout',
              text: alert.body,
              icon: alert.icon,
            ),
          );
        } else {
          out.add(
            FolioBlock(
              id: _blockId(pageId, out.length),
              type: 'quote',
              text: quoted.join('\n').trim(),
            ),
          );
        }
        continue;
      }

      if (t == '---' || t == '***') {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: 'divider',
            text: '',
          ),
        );
        i++;
        continue;
      }

      final image = _imageOnlyLine(t);
      if (image != null) {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: 'image',
            text: image.url,
          ),
        );
        i++;
        continue;
      }

      final heading = _parseHeading(t);
      if (heading != null) {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: heading.$1,
            text: heading.$2,
          ),
        );
        i++;
        continue;
      }

      final todo = _parseTodo(raw);
      if (todo != null) {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: 'todo',
            text: todo.text,
            checked: todo.checked,
            depth: todo.depth,
          ),
        );
        i++;
        continue;
      }

      final bullet = _parseBullet(raw);
      if (bullet != null) {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: 'bullet',
            text: bullet.text,
            depth: bullet.depth,
          ),
        );
        i++;
        continue;
      }

      final numbered = _parseNumbered(raw);
      if (numbered != null) {
        flushParagraph();
        out.add(
          FolioBlock(
            id: _blockId(pageId, out.length),
            type: 'numbered',
            text: numbered.text,
            depth: numbered.depth,
          ),
        );
        i++;
        continue;
      }

      paragraph.add(t);
      i++;
    }

    flushParagraph();
    if (out.isEmpty) {
      addSourceBookmark();
      if (out.isEmpty) {
        out.add(
          FolioBlock(id: '${pageId}_b0', type: 'paragraph', text: markdown),
        );
      }
      return out;
    }

    if ((sourceUrl?.trim().isNotEmpty ?? false) &&
        out.every((block) => block.type != 'bookmark')) {
      out.insert(
        0,
        FolioBlock(
          id: _blockId(pageId, out.length),
          type: 'bookmark',
          text: sourceApp?.trim().isNotEmpty == true
              ? 'Imported from ${sourceApp!.trim()}'
              : 'Imported source',
          url: sourceUrl!.trim(),
        ),
      );
    }
    return out;
  }

  static String _blockId(String pageId, int index) {
    return '${pageId}_${DateTime.now().microsecondsSinceEpoch}_$index';
  }

  static String? _parseFenceStart(String line) {
    if (!line.startsWith('```')) return null;
    return line.substring(3).trim().toLowerCase();
  }

  static ({String url, String alt})? _imageOnlyLine(String line) {
    final match = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(line);
    if (match == null) return null;
    return (alt: match.group(1) ?? '', url: (match.group(2) ?? '').trim());
  }

  static (String, String)? _parseHeading(String line) {
    final match = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (match == null) return null;
    final depth = match.group(1)!.length;
    final type = switch (depth) {
      1 => 'h1',
      2 => 'h2',
      _ => 'h3',
    };
    return (type, match.group(2)!.trim());
  }

  static ({String text, bool checked, int depth})? _parseTodo(String line) {
    final match = RegExp(r'^(\s*)[-*+]\s+\[([ xX])\]\s+(.+)$').firstMatch(line);
    if (match == null) return null;
    return (
      text: match.group(3)!.trim(),
      checked: match.group(2)!.toLowerCase() == 'x',
      depth: _depthFromIndent(match.group(1) ?? ''),
    );
  }

  static ({String text, int depth})? _parseBullet(String line) {
    final match = RegExp(r'^(\s*)[-*+]\s+(.+)$').firstMatch(line);
    if (match == null) return null;
    final body = match.group(2)!.trim();
    if (body.startsWith('[')) return null;
    return (text: body, depth: _depthFromIndent(match.group(1) ?? ''));
  }

  static ({String text, int depth})? _parseNumbered(String line) {
    final match = RegExp(r'^(\s*)\d+\.\s+(.+)$').firstMatch(line);
    if (match == null) return null;
    return (
      text: match.group(2)!.trim(),
      depth: _depthFromIndent(match.group(1) ?? ''),
    );
  }

  static int _depthFromIndent(String rawIndent) {
    final spaces = rawIndent.replaceAll('\t', '  ').length;
    return (spaces ~/ 2).clamp(0, 3);
  }

  static ({String icon, String body})? _parseAlertBlock(List<String> lines) {
    if (lines.isEmpty) return null;
    final first = lines.first.trim();
    final match = RegExp(
      r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(first);
    if (match == null) return null;
    final kind = match.group(1)!.toUpperCase();
    final rest = <String>[];
    final firstTail = match.group(2)?.trim() ?? '';
    if (firstTail.isNotEmpty) {
      rest.add(firstTail);
    }
    if (lines.length > 1) {
      rest.addAll(lines.skip(1).map((e) => e.trimRight()));
    }
    return (icon: _iconForAlertKind(kind), body: rest.join('\n').trim());
  }

  static String _iconForAlertKind(String kind) {
    switch (kind) {
      case 'TIP':
        return '💡';
      case 'IMPORTANT':
        return '📌';
      case 'WARNING':
        return '⚠️';
      case 'CAUTION':
        return '⛔';
      case 'NOTE':
      default:
        return '📝';
    }
  }

  static String _alertKindForBlock(FolioBlock block) {
    switch ((block.icon ?? '').trim()) {
      case '💡':
        return 'TIP';
      case '📌':
        return 'IMPORTANT';
      case '⚠️':
        return 'WARNING';
      case '⛔':
        return 'CAUTION';
      case '📝':
      default:
        return 'NOTE';
    }
  }

  static ({String? title, String body}) _extractFrontMatter(String text) {
    if (!text.startsWith('---\n')) {
      return (title: null, body: text);
    }
    final end = text.indexOf('\n---\n', 4);
    if (end < 0) {
      return (title: null, body: text);
    }
    final head = text.substring(4, end);
    final body = text.substring(end + 5);
    String? title;
    for (final line in head.split('\n')) {
      final match = RegExp(
        r'^title:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line.trim());
      if (match != null) {
        title = _stripWrappingQuotes(match.group(1)!.trim());
        break;
      }
    }
    return (title: title, body: body);
  }

  static String _stripWrappingQuotes(String value) {
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static String? _extractFirstHeadingTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final heading = _parseHeading(line.trim());
      if (heading == null) continue;
      if (heading.$1 == 'h1' && heading.$2.trim().isNotEmpty) {
        return heading.$2.trim();
      }
    }
    return null;
  }

  static bool _looksLikeMarkdownTable(List<String> lines, int index) {
    if (index + 1 >= lines.length) return false;
    final first = lines[index].trim();
    final second = lines[index + 1].trim();
    if (!first.startsWith('|') || !second.startsWith('|')) return false;
    final cells = _splitTableRow(second);
    if (cells.isEmpty) return false;
    return cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()));
  }

  static FolioTableData? _parseMarkdownTable(List<String> tableLines) {
    if (tableLines.length < 2) return null;
    final rows = <List<String>>[];
    rows.add(_splitTableRow(tableLines.first));
    for (final line in tableLines.skip(2)) {
      final row = _splitTableRow(line);
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }
    final cols = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    if (cols == 0) return null;
    final cells = <String>[];
    for (final row in rows) {
      final normalized = List<String>.from(row);
      while (normalized.length < cols) {
        normalized.add('');
      }
      cells.addAll(normalized.take(cols));
    }
    return FolioTableData(cols: cols, cells: cells);
  }

  static List<String> _splitTableRow(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) return const [];
    final body = trimmed.endsWith('|')
        ? trimmed.substring(1, trimmed.length - 1)
        : trimmed.substring(1);
    return body.split('|').map((cell) => cell.trim()).toList();
  }

  static String? _renderBlock(
    FolioBlock block,
    FolioPage page,
    Map<int, int> numberedCounters,
  ) {
    final indent = '  ' * block.depth;
    switch (block.type) {
      case 'paragraph':
        _resetNumberedCounters(numberedCounters, block.depth);
        return block.text.trim();
      case 'h1':
        _resetNumberedCounters(numberedCounters, 0);
        return '# ${block.text.trim()}';
      case 'h2':
        _resetNumberedCounters(numberedCounters, 0);
        return '## ${block.text.trim()}';
      case 'h3':
        _resetNumberedCounters(numberedCounters, 0);
        return '### ${block.text.trim()}';
      case 'bullet':
        _resetNumberedCounters(numberedCounters, block.depth);
        return '$indent- ${block.text.trim()}';
      case 'todo':
        _resetNumberedCounters(numberedCounters, block.depth);
        return '$indent- [${block.checked == true ? 'x' : ' '}] ${block.text.trim()}';
      case 'task':
        _resetNumberedCounters(numberedCounters, block.depth);
        final task = FolioTaskData.tryParse(block.text);
        if (task == null) return null;
        final taskDone = task.status == 'done';
        final taskLine = StringBuffer(
          '$indent- [${taskDone ? 'x' : ' '}] ${task.title.trim()}',
        );
        final extras = <String>[];
        if (task.priority != null) extras.add('priority: ${task.priority}');
        if (task.dueDate != null) extras.add('due: ${task.dueDate}');
        if (extras.isNotEmpty) taskLine.write(' <!-- ${extras.join(', ')} -->');
        return taskLine.toString();
      case 'numbered':
        final next = (numberedCounters[block.depth] ?? 0) + 1;
        numberedCounters[block.depth] = next;
        _dropDeeperCounters(numberedCounters, block.depth);
        return '$indent$next. ${block.text.trim()}';
      case 'quote':
        _resetNumberedCounters(numberedCounters, block.depth);
        return block.text
            .split('\n')
            .map((line) => '> ${line.trimRight()}')
            .join('\n');
      case 'callout':
        _resetNumberedCounters(numberedCounters, block.depth);
        final kind = _alertKindForBlock(block);
        final body = block.text.trim().isEmpty
            ? ''
            : '\n${block.text.split('\n').map((line) => '> ${line.trimRight()}').join('\n')}';
        return '> [!$kind]$body';
      case 'divider':
        _resetNumberedCounters(numberedCounters, 0);
        return '---';
      case 'code':
        _resetNumberedCounters(numberedCounters, 0);
        final lang = (block.codeLanguage ?? 'plaintext').trim();
        return '```$lang\n${block.text.trimRight()}\n```';
      case 'mermaid':
        _resetNumberedCounters(numberedCounters, 0);
        return '```mermaid\n${block.text.trimRight()}\n```';
      case 'equation':
        _resetNumberedCounters(numberedCounters, 0);
        return '```math\n${block.text.trimRight()}\n```';
      case 'image':
        _resetNumberedCounters(numberedCounters, 0);
        return '![image](${block.text.trim()})';
      case 'bookmark':
      case 'embed':
      case 'file':
      case 'video':
      case 'audio':
        _resetNumberedCounters(numberedCounters, 0);
        final url = (block.url ?? block.text).trim();
        if (url.isEmpty) return null;
        final label = block.text.trim().isEmpty ? url : block.text.trim();
        return '[$label]($url)';
      case 'table':
        _resetNumberedCounters(numberedCounters, 0);
        return _renderTable(block);
      case 'toggle':
        _resetNumberedCounters(numberedCounters, 0);
        final toggle = FolioToggleData.tryParse(block.text);
        if (toggle == null) return _renderOpaqueBlock(block);
        return [
          '<details>',
          '<summary>${toggle.title}</summary>',
          '',
          toggle.body,
          '',
          '</details>',
        ].join('\n');
      case 'kanban':
        _resetNumberedCounters(numberedCounters, 0);
        return _renderKanbanExport(block, page);
      case 'database':
      case 'column_list':
      case 'template_button':
      case 'toc':
      case 'breadcrumb':
      case 'child_page':
        _resetNumberedCounters(numberedCounters, 0);
        return _renderOpaqueBlock(block);
      default:
        _resetNumberedCounters(numberedCounters, 0);
        return block.text.trim();
    }
  }

  static String _renderKanbanExport(FolioBlock block, FolioPage page) {
    final data =
        FolioKanbanData.tryParse(block.text) ?? FolioKanbanData.defaults();
    final lines = <String>[
      '<!-- folio:kanban (tasks on this page) -->',
      if (!data.includeSimpleTodos) '<!-- kanban: checklist items excluded -->',
    ];
    var taskLines = 0;
    for (final b in page.blocks) {
      if (b.type == 'task') {
        final task = FolioTaskData.tryParse(b.text);
        if (task == null) continue;
        final taskDone = task.status == 'done';
        lines.add('- [${taskDone ? 'x' : ' '}] ${task.title.trim()}');
        taskLines++;
      } else if (data.includeSimpleTodos && b.type == 'todo') {
        lines.add('- [${b.checked == true ? 'x' : ' '}] ${b.text.trim()}');
        taskLines++;
      }
    }
    if (taskLines == 0) {
      lines.add('<!-- (no task/todo blocks on page) -->');
    }
    return lines.join('\n');
  }

  static String _renderTable(FolioBlock block) {
    final table = FolioTableData.tryParse(block.text);
    if (table == null || table.rowCount == 0) {
      return _renderOpaqueBlock(block);
    }
    final header = <String>[];
    final divider = <String>[];
    for (var col = 0; col < table.cols; col++) {
      header.add(_escapeTableCell(table.cellAt(0, col)));
      divider.add('---');
    }
    final lines = <String>[
      '| ${header.join(' | ')} |',
      '| ${divider.join(' | ')} |',
    ];
    for (var row = 1; row < table.rowCount; row++) {
      final cells = <String>[];
      for (var col = 0; col < table.cols; col++) {
        cells.add(_escapeTableCell(table.cellAt(row, col)));
      }
      lines.add('| ${cells.join(' | ')} |');
    }
    return lines.join('\n');
  }

  static String _escapeTableCell(String value) {
    return value.replaceAll('|', r'\|').replaceAll('\n', '<br>');
  }

  static String _renderOpaqueBlock(FolioBlock block) {
    final text = block.type == 'database'
        ? (FolioDatabaseData.plainTextFromJson(block.text).trim().isEmpty
              ? block.text
              : FolioDatabaseData.plainTextFromJson(block.text))
        : (block.type == 'column_list'
              ? _columnsPlainText(block.text)
              : block.text);
    return '```folio-block type=${block.type}\n${text.trimRight()}\n```';
  }

  static String _columnsPlainText(String raw) {
    final data = FolioColumnsData.tryParse(raw);
    if (data == null) return raw;
    final parts = <String>[];
    for (var i = 0; i < data.columns.length; i++) {
      final content = data.columns[i].blocks
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n');
      parts.add('Column ${i + 1}\n$content');
    }
    return parts.join('\n\n');
  }

  static void _resetNumberedCounters(Map<int, int> counters, int depth) {
    counters.remove(depth);
    _dropDeeperCounters(counters, depth);
  }

  static void _dropDeeperCounters(Map<int, int> counters, int depth) {
    final keys = counters.keys.where((key) => key > depth).toList();
    for (final key in keys) {
      counters.remove(key);
    }
  }

  static String _yamlEscape(String value) {
    final escaped = value.replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
