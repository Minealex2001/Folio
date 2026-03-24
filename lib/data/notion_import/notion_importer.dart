import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../models/block.dart';
import '../../models/folio_database_data.dart';

enum NotionExportFormat { markdown, html }

class NotionImportWarning {
  const NotionImportWarning(this.message);
  final String message;
}

class NotionParsedPage {
  const NotionParsedPage({
    required this.sourcePath,
    required this.sourceDirPath,
    required this.title,
    required this.blocks,
    this.parentSourcePath,
  });

  final String sourcePath;
  final String sourceDirPath;
  final String? parentSourcePath;
  final String title;
  final List<FolioBlock> blocks;
}

class NotionParsedExport {
  const NotionParsedExport({
    required this.format,
    required this.pages,
    required this.databases,
    required this.warnings,
  });

  final NotionExportFormat format;
  final List<NotionParsedPage> pages;
  final List<NotionParsedDatabase> databases;
  final List<NotionImportWarning> warnings;
}

class NotionParsedDatabase {
  const NotionParsedDatabase({
    required this.sourcePath,
    required this.title,
    required this.data,
  });

  final String sourcePath;
  final String title;
  final FolioDatabaseData data;
}

class NotionImportException implements Exception {
  NotionImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<void> extractNotionZipToDirectory(File zipFile, Directory outDir) async {
  if (!zipFile.existsSync()) {
    throw NotionImportException('No se encontro el ZIP de Notion.');
  }
  if (!outDir.existsSync()) {
    await outDir.create(recursive: true);
  }
  try {
    await extractFileToDisk(zipFile.path, outDir.path);
  } catch (e) {
    throw NotionImportException('No se pudo extraer el ZIP de Notion: $e');
  }
}

NotionParsedExport parseNotionExportDirectory(Directory rootDir) {
  final mdFiles = <File>[];
  final htmlFiles = <File>[];
  final csvFiles = <File>[];
  for (final entity in rootDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final lower = entity.path.toLowerCase();
    if (lower.endsWith('.md')) mdFiles.add(entity);
    if (lower.endsWith('.html') || lower.endsWith('.htm'))
      htmlFiles.add(entity);
    if (lower.endsWith('.csv')) csvFiles.add(entity);
  }

  if (mdFiles.isEmpty && htmlFiles.isEmpty && csvFiles.isEmpty) {
    throw NotionImportException(
      'No se detectaron archivos Markdown, HTML ni CSV.',
    );
  }

  final useMarkdown = mdFiles.length >= htmlFiles.length;
  final files = useMarkdown ? mdFiles : htmlFiles;
  final format = useMarkdown
      ? NotionExportFormat.markdown
      : NotionExportFormat.html;
  final warnings = <NotionImportWarning>[];

  final pages = files.map((f) {
    final rel = p.relative(f.path, from: rootDir.path).replaceAll(r'\', '/');
    final title = _cleanTitle(p.basenameWithoutExtension(f.path));
    final parentRel = _resolveParentSourcePath(rel, files, rootDir.path);
    final raw = f.readAsStringSync();
    final blocks = useMarkdown
        ? _parseMarkdownBlocks(raw, warnings)
        : _parseHtmlBlocks(raw, warnings);
    final safeBlocks = blocks.isEmpty
        ? [FolioBlock(id: 'tmp', type: 'paragraph', text: '')]
        : blocks;
    return NotionParsedPage(
      sourcePath: rel,
      sourceDirPath: p.dirname(f.path),
      parentSourcePath: parentRel,
      title: title.isEmpty ? 'Untitled' : title,
      blocks: safeBlocks,
    );
  }).toList()..sort((a, b) => a.sourcePath.compareTo(b.sourcePath));

  final databases = <NotionParsedDatabase>[];
  for (final csv in csvFiles) {
    try {
      final rel = p
          .relative(csv.path, from: rootDir.path)
          .replaceAll(r'\', '/');
      final title = _cleanTitle(p.basenameWithoutExtension(csv.path));
      final raw = csv.readAsStringSync();
      final data = _parseCsvAsDatabase(raw, titleHint: title);
      databases.add(
        NotionParsedDatabase(
          sourcePath: rel,
          title: title.isEmpty ? 'Database' : title,
          data: data,
        ),
      );
    } catch (e) {
      warnings.add(
        NotionImportWarning('No se pudo parsear DB CSV: ${csv.path} ($e)'),
      );
    }
  }

  return NotionParsedExport(
    format: format,
    pages: pages,
    databases: databases,
    warnings: warnings,
  );
}

FolioDatabaseData _parseCsvAsDatabase(
  String rawCsv, {
  required String titleHint,
}) {
  final lines = rawCsv
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return FolioDatabaseData.empty();
  }
  final header = _parseCsvLine(lines.first);
  final db = FolioDatabaseData.empty();
  db.properties = [];
  for (var i = 0; i < header.length; i++) {
    final name = header[i].trim().isEmpty
        ? 'Column ${i + 1}'
        : header[i].trim();
    db.properties.add(
      FolioDbProperty(
        id: i == 0 ? 'p_title' : 'p_${i + 1}',
        name: name,
        type: FolioDbPropertyType.text,
      ),
    );
  }
  if (db.properties.isEmpty) {
    db.properties.add(
      FolioDbProperty(
        id: 'p_title',
        name: titleHint,
        type: FolioDbPropertyType.text,
      ),
    );
  }
  db.rows = [];
  for (var r = 1; r < lines.length; r++) {
    final cells = _parseCsvLine(lines[r]);
    final row = FolioDbRow(id: 'r_${r - 1}');
    for (var c = 0; c < db.properties.length; c++) {
      final prop = db.properties[c];
      final v = c < cells.length ? cells[c].trim() : '';
      row.values[prop.id] = v;
    }
    final allEmpty = row.values.values.every((v) => '$v'.trim().isEmpty);
    if (!allEmpty) db.rows.add(row);
  }
  return db;
}

List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var inQuote = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        inQuote = !inQuote;
      }
      continue;
    }
    if (ch == ',' && !inQuote) {
      out.add(cur.toString());
      cur.clear();
      continue;
    }
    cur.write(ch);
  }
  out.add(cur.toString());
  return out;
}

String? _resolveParentSourcePath(
  String relPath,
  List<File> files,
  String rootPath,
) {
  final fileSet = files
      .map((f) => p.relative(f.path, from: rootPath).replaceAll(r'\', '/'))
      .toSet();
  var currentDir = p.dirname(relPath).replaceAll(r'\', '/');
  while (currentDir != '.' && currentDir != '/') {
    for (final ext in const ['.md', '.html', '.htm']) {
      final candidate = '$currentDir$ext';
      if (fileSet.contains(candidate)) return candidate;
    }
    final parent = p.dirname(currentDir).replaceAll(r'\', '/');
    if (parent == currentDir) break;
    currentDir = parent;
  }
  return null;
}

String _cleanTitle(String title) {
  return title
      .replaceAll(RegExp(r'\s+[0-9a-fA-F]{32}$'), '')
      .replaceAll(RegExp(r'\s+[0-9a-fA-F]{8,}$'), '')
      .trim();
}

List<FolioBlock> _parseMarkdownBlocks(
  String input,
  List<NotionImportWarning> warnings,
) {
  final out = <FolioBlock>[];
  final lines = input.replaceAll('\r\n', '\n').split('\n');
  var i = 0;
  while (i < lines.length) {
    final line = lines[i].trimRight();
    final t = line.trim();
    if (t.isEmpty) {
      i++;
      continue;
    }
    if (t.startsWith('```')) {
      final lang = t.substring(3).trim();
      i++;
      final buf = StringBuffer();
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        buf.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) i++;
      out.add(
        FolioBlock(
          id: 'tmp',
          type: 'code',
          text: buf.toString().trimRight(),
          codeLanguage: lang.isEmpty ? 'text' : lang,
        ),
      );
      continue;
    }
    final todo = RegExp(r'^[-*]\s+\[( |x|X)\]\s+(.*)$').firstMatch(t);
    if (todo != null) {
      out.add(
        FolioBlock(
          id: 'tmp',
          type: 'todo',
          text: _stripMdInline(todo.group(2) ?? ''),
          checked: (todo.group(1) ?? '').toLowerCase() == 'x',
        ),
      );
      i++;
      continue;
    }
    if (t.startsWith('# ')) {
      out.add(
        FolioBlock(id: 'tmp', type: 'h1', text: _stripMdInline(t.substring(2))),
      );
      i++;
      continue;
    }
    if (t.startsWith('## ')) {
      out.add(
        FolioBlock(id: 'tmp', type: 'h2', text: _stripMdInline(t.substring(3))),
      );
      i++;
      continue;
    }
    if (t.startsWith('### ')) {
      out.add(
        FolioBlock(id: 'tmp', type: 'h3', text: _stripMdInline(t.substring(4))),
      );
      i++;
      continue;
    }
    if (t == '---' || t == '***') {
      out.add(FolioBlock(id: 'tmp', type: 'divider', text: ''));
      i++;
      continue;
    }
    if (t.startsWith('> ')) {
      out.add(
        FolioBlock(
          id: 'tmp',
          type: 'quote',
          text: _stripMdInline(t.substring(2)),
        ),
      );
      i++;
      continue;
    }
    if (t.startsWith('- ') ||
        t.startsWith('* ') ||
        RegExp(r'^\d+\.\s+').hasMatch(t)) {
      final bulletText = t.replaceFirst(RegExp(r'^(-|\*|\d+\.)\s+'), '');
      out.add(
        FolioBlock(id: 'tmp', type: 'bullet', text: _stripMdInline(bulletText)),
      );
      i++;
      continue;
    }

    final imageMatch = RegExp(r'!\[(.*?)\]\((.*?)\)').firstMatch(t);
    if (imageMatch != null) {
      final src = (imageMatch.group(2) ?? '').trim();
      if (src.isNotEmpty) {
        out.add(FolioBlock(id: 'tmp', type: 'image', text: src));
      }
      i++;
      continue;
    }

    final linkOnlyMatch = RegExp(r'^\[(.*?)\]\((.*?)\)$').firstMatch(t);
    if (linkOnlyMatch != null) {
      final label = (linkOnlyMatch.group(1) ?? '').trim();
      final url = (linkOnlyMatch.group(2) ?? '').trim();
      if (url.isNotEmpty) {
        final isVideo = RegExp(
          r'\.(mp4|mov|avi|mkv|webm)$',
          caseSensitive: false,
        ).hasMatch(url);
        out.add(
          FolioBlock(
            id: 'tmp',
            type: isVideo ? 'video' : 'file',
            text: label.isEmpty ? url : label,
            url: url,
          ),
        );
        i++;
        continue;
      }
    }

    final paragraph = <String>[t];
    i++;
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      final next = lines[i].trim();
      if (next.startsWith('#') ||
          next.startsWith('- ') ||
          next.startsWith('* ') ||
          next.startsWith('> ') ||
          next.startsWith('```')) {
        break;
      }
      paragraph.add(next);
      i++;
    }
    out.add(
      FolioBlock(
        id: 'tmp',
        type: 'paragraph',
        text: _stripMdInline(paragraph.join(' ')),
      ),
    );
  }

  if (out.isEmpty) {
    warnings.add(
      const NotionImportWarning('Pagina vacia importada como parrafo vacio.'),
    );
  }
  return out;
}

List<FolioBlock> _parseHtmlBlocks(
  String input,
  List<NotionImportWarning> warnings,
) {
  final out = <FolioBlock>[];
  final html = input.replaceAll('\r\n', '\n');

  final tagPattern = RegExp(
    r'<(h1|h2|h3|p|li|blockquote|pre|hr|img)\b[^>]*>(.*?)</\1>|<(hr|img)\b[^>]*/?>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in tagPattern.allMatches(html)) {
    final tag = (match.group(1) ?? match.group(3) ?? '').toLowerCase();
    final body = match.group(2) ?? '';
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
        out.add(FolioBlock(id: 'tmp', type: tag, text: _stripHtml(body)));
        break;
      case 'p':
        final text = _stripHtml(body);
        if (text.isNotEmpty) {
          out.add(FolioBlock(id: 'tmp', type: 'paragraph', text: text));
        }
        break;
      case 'li':
        final text = _stripHtml(body);
        if (text.toLowerCase().startsWith('[ ] ') ||
            text.toLowerCase().startsWith('[x] ')) {
          out.add(
            FolioBlock(
              id: 'tmp',
              type: 'todo',
              text: text.substring(4),
              checked: text.toLowerCase().startsWith('[x] '),
            ),
          );
        } else {
          out.add(FolioBlock(id: 'tmp', type: 'bullet', text: text));
        }
        break;
      case 'blockquote':
        out.add(FolioBlock(id: 'tmp', type: 'quote', text: _stripHtml(body)));
        break;
      case 'pre':
        out.add(
          FolioBlock(
            id: 'tmp',
            type: 'code',
            text: _stripHtml(body),
            codeLanguage: 'text',
          ),
        );
        break;
      case 'hr':
        out.add(FolioBlock(id: 'tmp', type: 'divider', text: ''));
        break;
      case 'img':
        final src = RegExp(
          "src=[\"']([^\"']+)[\"']",
          caseSensitive: false,
        ).firstMatch(match.group(0) ?? '');
        final path = (src?.group(1) ?? '').trim();
        if (path.isNotEmpty) {
          out.add(FolioBlock(id: 'tmp', type: 'image', text: path));
        }
        break;
      default:
        warnings.add(
          NotionImportWarning('Etiqueta HTML no soportada: <$tag>.'),
        );
    }
  }

  if (out.isEmpty) {
    final fallback = _stripHtml(html);
    out.add(FolioBlock(id: 'tmp', type: 'paragraph', text: fallback));
    warnings.add(
      const NotionImportWarning(
        'HTML sin bloques reconocibles; se aplico fallback de texto.',
      ),
    );
  }
  return out;
}

String _stripMdInline(String s) {
  return s
      .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
      .replaceAll(RegExp(r'_([^_]+)_'), r'$1')
      .replaceAll(RegExp(r'~~([^~]+)~~'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), r'$1')
      .trim();
}

String _stripHtml(String s) {
  return s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
