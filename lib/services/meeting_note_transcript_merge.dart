/// Utilidades para fusionar fragmentos de transcripción de reunión.
class MeetingNoteTranscriptMerge {
  MeetingNoteTranscriptMerge._();

  static String merge(String current, String incoming) {
    final base = current.trimRight();
    final add = incoming.trim();
    if (add.isEmpty) return current;
    if (base.isEmpty) return add;

    final baseLines = base
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final addLines = add.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (baseLines.isEmpty) return add;
    if (addLines.isEmpty) return base;

    var consumedFirstIncoming = false;
    final lastIndex = baseLines.length - 1;
    final lastLine = baseLines[lastIndex];
    final firstIncoming = addLines.first;

    final parsedLast = _parseSpeakerLine(lastLine);
    final parsedFirst = _parseSpeakerLine(firstIncoming);

    if (parsedLast != null && parsedFirst != null) {
      if (parsedLast.speakerId == parsedFirst.speakerId &&
          _shouldContinueParagraph(parsedLast.text, parsedFirst.text)) {
        baseLines[lastIndex] =
            'Speaker ${parsedLast.speakerId}: ${_joinSegments(parsedLast.text, parsedFirst.text)}';
        consumedFirstIncoming = true;
      }
    } else if (parsedLast == null && parsedFirst == null) {
      if (_shouldContinueParagraph(lastLine, firstIncoming)) {
        baseLines[lastIndex] = _joinSegments(lastLine, firstIncoming);
        consumedFirstIncoming = true;
      }
    }

    final remainingIncoming = consumedFirstIncoming
        ? addLines.skip(1).toList()
        : addLines;
    if (remainingIncoming.isNotEmpty) baseLines.addAll(remainingIncoming);
    return baseLines.join('\n');
  }

  static _SpeakerLine? _parseSpeakerLine(String line) {
    final m = RegExp(r'^\s*Speaker\s+(\d+)\s*:\s*(.+?)\s*$').firstMatch(line);
    if (m == null) return null;
    final speakerId = int.tryParse(m.group(1) ?? '');
    final text = (m.group(2) ?? '').trim();
    if (speakerId == null || text.isEmpty) return null;
    return _SpeakerLine(speakerId: speakerId, text: text);
  }

  static bool _shouldContinueParagraph(String previousText, String nextText) {
    final prev = previousText.trimRight();
    final next = nextText.trimLeft();
    if (prev.isEmpty || next.isEmpty) return false;

    final hardStop = RegExp(r'[\.!\?…]["”’\)\]]*$').hasMatch(prev);
    if (!hardStop) return true;

    if (RegExp(r'^[,.;:\)\]]').hasMatch(next)) return true;
    if (RegExp(r'^[a-z]').hasMatch(next)) return true;
    if (RegExp(
      r'^(y|e|o|u|de|que|pero|pues|entonces|and|but|or|so|because|then)\b',
      caseSensitive: false,
    ).hasMatch(next)) {
      return true;
    }
    return false;
  }

  static String _joinSegments(String left, String right) {
    final a = left.trimRight();
    final b = right.trimLeft();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    if (a.endsWith('-')) return '$a$b';
    if (RegExp(r'^[,.;:!?\)]').hasMatch(b)) return '$a$b';
    return '$a $b';
  }
}

class _SpeakerLine {
  const _SpeakerLine({required this.speakerId, required this.text});

  final int speakerId;
  final String text;
}
