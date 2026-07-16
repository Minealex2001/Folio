import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/merge_l10n_fragment.dart <arb_path> <fragment_json>');
    exit(1);
  }
  final arbPath = args[0];
  final fragmentPath = args[1];
  final arbFile = File(arbPath);
  final fragmentFile = File(fragmentPath);
  final arbText = arbFile.readAsStringSync();
  final fragment =
      jsonDecode(fragmentFile.readAsStringSync()) as Map<String, dynamic>;

  final lastBrace = arbText.lastIndexOf('}');
  if (lastBrace < 0) {
    stderr.writeln('Invalid ARB: $arbPath');
    exit(1);
  }
  final prefix = arbText.substring(0, lastBrace).trimRight();
  final needsComma = !prefix.endsWith(',') && !prefix.endsWith('{');
  final buffer = StringBuffer();
  buffer.write(prefix);
  if (needsComma) buffer.write(',');
  buffer.writeln();
  var first = true;
  for (final entry in fragment.entries) {
    if (!first) buffer.writeln(',');
    first = false;
    final key = entry.key;
    final value = entry.value;
    final encodedValue = jsonEncode(value);
    buffer.write('  "$key": $encodedValue');
  }
  buffer.writeln();
  buffer.write('}');
  arbFile.writeAsStringSync(buffer.toString());
  stdout.writeln('Merged ${fragment.length} keys into $arbPath');
}
