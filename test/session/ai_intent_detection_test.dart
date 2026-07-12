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

    test('detecta traduccion bilingue sin crear pagina nueva', () {
      final session = VaultSession();
      expect(
        session.detectBilingualTranslateIntentForTesting(
          'Traduce esta pagina e insertalo en la misma',
          languageCode: 'es',
        ),
        isTrue,
      );
      expect(
        session.detectBilingualTranslateIntentForTesting(
          'Translate this page and insert it in the same place',
          languageCode: 'en',
        ),
        isTrue,
      );
      expect(
        session.detectCreatePageIntentForTesting(
          'Traduce esta pagina e insertalo en la misma',
          languageCode: 'es',
        ),
        isFalse,
      );
      expect(
        session.detectEditIntentForTesting(
          'Traduce esta pagina e insertalo en la misma',
          languageCode: 'es',
        ),
        isTrue,
      );
    });

    test('sigue detectando create_page para nota nueva traducida', () {
      final session = VaultSession();
      expect(
        session.detectCreatePageIntentForTesting(
          'Crea una pagina nueva traducida al ingles',
          languageCode: 'es',
        ),
        isTrue,
      );
      expect(
        session.detectBilingualTranslateIntentForTesting(
          'Crea una pagina nueva traducida al ingles',
          languageCode: 'es',
        ),
        isFalse,
      );
    });
  });

  group('AI mode normalization', () {
    test('normaliza alias frecuentes a modos canonicos', () {
      final session = VaultSession();
      expect(session.normalizeAgentModeForTesting('create'), 'create_page');
      expect(session.normalizeAgentModeForTesting('edit'), 'edit_current');
      expect(session.normalizeAgentModeForTesting('append'), 'append_current');
      expect(session.normalizeAgentModeForTesting('replace'), 'replace_current');
      expect(session.normalizeAgentModeForTesting('summarize'), 'summarize_current');
    });
  });

  group('Bilingual translation response parsing', () {
    test('parsea translations desde objeto JSON', () {
      final session = VaultSession();
      final parsed = session.parseBilingualTranslationResponseForTesting(
        '{"translations":[{"blockId":"p1_b0","text":"Hello"}]}',
        allowedBlockIds: {'p1_b0'},
      );
      expect(parsed.length, 1);
      expect(parsed.first.blockId, 'p1_b0');
      expect(parsed.first.text, 'Hello');
    });
  });
}
