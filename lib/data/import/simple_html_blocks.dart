import '../../models/block.dart';

/// Parser HTML -> bloques Folio (subset seguro).
///
/// Está pensado para importación rápida desde HTML simple (Notion export y similares).
/// No intenta ser un parser HTML completo.
List<FolioBlock> folioParseHtmlBlocks(String input) {
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
    }
  }

  if (out.isEmpty) {
    out.add(FolioBlock(id: 'tmp', type: 'paragraph', text: _stripHtml(html)));
  }
  return out;
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

