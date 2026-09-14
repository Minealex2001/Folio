import 'package:flutter_test/flutter_test.dart';
import 'package:folio/session/vault_session.dart';

/// Fase 7 de Quill 2.0 — provenance de contenido multimodal: la
/// transcripción de una reunión (Whisper) es contenido generado por
/// máquina, igual que un bloque que Quill materializa desde el chat o una
/// imagen generada — ambos ya marcan `Block.aiGenerated`. Antes, la
/// transcripción se escribía sin marcar nada.
void main() {
  VaultSession readySession() {
    final session = VaultSession();
    session.debugMarkUnlockedForTests();
    session.addPage(parentId: null);
    return session;
  }

  test('updateBlockTextStreaming marca aiGenerated (uso exclusivo de la transcripción en vivo)', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;

    session.updateBlockTextStreaming(page.id, blockId, 'transcripción parcial...');

    expect(session.pages.first.blocks.first.aiGenerated, isTrue);
  });

  test('markBlockAiGenerated marca un bloque existente sin tocar su texto', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;
    session.updateBlockText(page.id, blockId, 'transcripción final');

    session.markBlockAiGenerated(page.id, blockId);

    final block = session.pages.first.blocks.first;
    expect(block.aiGenerated, isTrue);
    expect(block.text, 'transcripción final');
  });

  test('una edición manual posterior limpia aiGenerated (comportamiento ya existente, sin romper)', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;
    session.updateBlockText(page.id, blockId, 'transcripción final');
    session.markBlockAiGenerated(page.id, blockId);
    expect(session.pages.first.blocks.first.aiGenerated, isTrue);

    session.updateBlockText(page.id, blockId, 'el usuario corrige esto a mano');

    expect(session.pages.first.blocks.first.aiGenerated, isNot(true));
  });
}
