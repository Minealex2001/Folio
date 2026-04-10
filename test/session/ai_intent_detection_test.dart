import 'package:flutter_test/flutter_test.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('AI intent detection', () {
    test('detecta create_page en ES con nota/pagina', () {
      final session = VaultSession();
      expect(
        session.detectCreatePageIntentForTesting(
          'Crea una nota nueva sobre arquitectura limpia',
          languageCode: 'es',
        ),
        isTrue,
      );
      expect(
        session.detectCreatePageIntentForTesting(
          'Genera una pagina desde cero sobre testing',
          languageCode: 'es',
        ),
        isTrue,
      );
    });

    test('detecta create_page en EN con new note/page', () {
      final session = VaultSession();
      expect(
        session.detectCreatePageIntentForTesting(
          'Create a new note for sprint planning',
          languageCode: 'en',
        ),
        isTrue,
      );
      expect(
        session.detectCreatePageIntentForTesting(
          'Generate page from scratch about APIs',
          languageCode: 'en',
        ),
        isTrue,
      );
    });

    test('prefiere edit intent cuando hay verbo + objetivo existente', () {
      final session = VaultSession();
      expect(
        session.detectEditIntentForTesting(
          'Edita la pagina actual y corrige estos bloques',
          languageCode: 'es',
        ),
        isTrue,
      );
      expect(
        session.detectEditIntentForTesting(
          'Update this page and fix current blocks',
          languageCode: 'en',
        ),
        isTrue,
      );
    });

    test('detecta subpage intent en ES y EN', () {
      final session = VaultSession();
      expect(
        session.detectSubpageIntentForTesting(
          'Crea una subpagina dentro de esta pagina',
          languageCode: 'es',
        ),
        isTrue,
      );
      expect(
        session.detectSubpageIntentForTesting(
          'Create a child page under current page',
          languageCode: 'en',
        ),
        isTrue,
      );
    });
  });

  group('AI mode normalization', () {
    test('normaliza alias frecuentes a modos canonicos', () {
      final session = VaultSession();
      expect(session.normalizeAgentModeForTesting('edit'), 'edit_current');
      expect(session.normalizeAgentModeForTesting('update'), 'edit_current');
      expect(session.normalizeAgentModeForTesting('create'), 'create_page');
      expect(session.normalizeAgentModeForTesting('new_page'), 'create_page');
      expect(session.normalizeAgentModeForTesting('summary'), 'summarize_current');
      expect(session.normalizeAgentModeForTesting('append'), 'append_current');
    });
  });
}

