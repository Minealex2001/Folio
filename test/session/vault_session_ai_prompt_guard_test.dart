import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas de regresión sobre el prompt del agente JSON (camino legado).
void main() {
  test('el schema del agente ya no limita reply a 1–4 frases', () {
    final source = File('lib/session/vault_session_ai.dart').readAsStringSync();
    expect(source.contains('1–4 frases'), isFalse);
    expect(source.contains('max 1–4 sentences'), isFalse);
    expect(source.contains('completo por defecto'), isTrue);
    expect(
      source.contains('NUNCA dejes blocks vacío ni digas al usuario que añada'),
      isTrue,
    );
  });
}
