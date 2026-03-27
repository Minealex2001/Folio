import 'dart:typed_data';

import '../crypto/vault_crypto.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

enum VaultStarterContent {
  enabled,
  disabled,
}

List<FolioPage> buildVaultStarterPages(VaultStarterContent starterContent) {
  if (starterContent == VaultStarterContent.disabled) {
    return const [];
  }
  return [
    FolioPage(
      id: 'starter_home',
      title: 'Empieza aquí',
      blocks: [
        FolioBlock(
          id: 'starter_home_b0',
          type: 'h1',
          text: 'Tu cofre ya está listo',
        ),
        FolioBlock(
          id: 'starter_home_b1',
          type: 'paragraph',
          text:
              'Folio organiza tus páginas en un árbol, edita contenido por bloques y mantiene los datos en este dispositivo. Esta mini guía te deja un mapa rápido de lo que puedes hacer desde el primer minuto.',
        ),
        FolioBlock(
          id: 'starter_home_b2',
          type: 'callout',
          text:
              'Puedes borrar, renombrar o mover estas páginas cuando quieras. Son solo una base para arrancar más rápido.',
          icon: '💡',
        ),
        FolioBlock(
          id: 'starter_home_b3',
          type: 'h2',
          text: 'Lo más útil para empezar',
        ),
        FolioBlock(
          id: 'starter_home_b4',
          type: 'bullet',
          text: 'Pulsa / dentro de un párrafo para insertar encabezados, listas, tablas, bloques de código, Mermaid y más.',
        ),
        FolioBlock(
          id: 'starter_home_b5',
          type: 'bullet',
          text: 'Usa el panel lateral para crear páginas y subpáginas, y reorganiza el árbol según tu forma de trabajar.',
        ),
        FolioBlock(
          id: 'starter_home_b6',
          type: 'bullet',
          text: 'Abre Ajustes para activar IA, configurar copia de seguridad, cambiar idioma o añadir desbloqueo rápido.',
        ),
        FolioBlock(
          id: 'starter_home_b7',
          type: 'divider',
          text: '',
        ),
        FolioBlock(
          id: 'starter_home_b8',
          type: 'todo',
          text: 'Crear mi primera página de trabajo',
          checked: false,
        ),
        FolioBlock(
          id: 'starter_home_b9',
          type: 'todo',
          text: 'Probar el menú / para insertar un bloque nuevo',
          checked: false,
        ),
        FolioBlock(
          id: 'starter_home_b10',
          type: 'todo',
          text: 'Revisar Ajustes y decidir si quiero activar Quill o un método de desbloqueo rápido',
          checked: false,
        ),
      ],
    ),
    FolioPage(
      id: 'starter_capabilities',
      title: 'Qué puede hacer Folio',
      blocks: [
        FolioBlock(
          id: 'starter_capabilities_b0',
          type: 'h2',
          text: 'Capacidades principales',
        ),
        FolioBlock(
          id: 'starter_capabilities_b1',
          type: 'bullet',
          text: 'Tomar notas con estructura libre usando párrafos, títulos, listas, checklists, citas y divisores.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b2',
          type: 'bullet',
          text: 'Trabajar con bloques especiales como tablas, bases de datos, archivos, audio, vídeo, embeds y diagramas Mermaid.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b3',
          type: 'bullet',
          text: 'Buscar contenido, revisar historial de página y mantener revisiones dentro del mismo cofre.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b4',
          type: 'bullet',
          text: 'Exportar o importar datos, incluyendo copia del cofre e importación desde Notion.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b5',
          type: 'h2',
          text: 'Atajos rápidos',
        ),
        FolioBlock(
          id: 'starter_capabilities_b6',
          type: 'bullet',
          text: 'Ctrl+N crea una página nueva.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b7',
          type: 'bullet',
          text: 'Ctrl+K o Ctrl+F abre la búsqueda.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b8',
          type: 'bullet',
          text: 'Ctrl+, abre Ajustes y Ctrl+L bloquea el cofre.',
        ),
        FolioBlock(
          id: 'starter_capabilities_b9',
          type: 'callout',
          text:
              'La IA no se activa por defecto. Si decides usar Quill, la configuras en Ajustes y eliges proveedor, modelo y permisos de contexto.',
          icon: '🧠',
        ),
      ],
    ),
    FolioPage(
      id: 'starter_quill',
      title: 'Quill y privacidad',
      blocks: [
        FolioBlock(
          id: 'starter_quill_b0',
          type: 'h2',
          text: 'Qué puede hacer Quill',
        ),
        FolioBlock(
          id: 'starter_quill_b1',
          type: 'bullet',
          text: 'Resumir, reescribir o expandir el contenido de una página.',
        ),
        FolioBlock(
          id: 'starter_quill_b2',
          type: 'bullet',
          text: 'Responder dudas sobre bloques, atajos y formas de organizar tus notas en Folio.',
        ),
        FolioBlock(
          id: 'starter_quill_b3',
          type: 'bullet',
          text: 'Trabajar con la página abierta como contexto o con varias páginas que selecciones como referencia.',
        ),
        FolioBlock(
          id: 'starter_quill_b4',
          type: 'h2',
          text: 'Privacidad y seguridad',
        ),
        FolioBlock(
          id: 'starter_quill_b5',
          type: 'paragraph',
          text:
              'Tus páginas viven en este dispositivo. Si habilitas IA, revisa qué contexto compartes y con qué proveedor. Si olvidas la contraseña maestra de un cofre cifrado, Folio no puede recuperarlo por ti.',
        ),
        FolioBlock(
          id: 'starter_quill_b6',
          type: 'callout',
          text:
              'Haz una copia del cofre cuando tengas contenido importante. La copia conserva los datos y adjuntos, pero no transfiere Hello ni passkeys entre dispositivos.',
          icon: '🔐',
        ),
        FolioBlock(
          id: 'starter_quill_b7',
          type: 'paragraph',
          text: 'Prueba rápida de Mermaid:',
        ),
        FolioBlock(
          id: 'starter_quill_b8',
          type: 'mermaid',
          text: 'graph TD\nInicio[Crear cofre] --> Organizar[Organizar páginas]\nOrganizar --> Escribir[Escribir y enlazar ideas]\nEscribir --> Revisar[Buscar, revisar y mejorar]',
        ),
      ],
    ),
  ];
}

class VaultRepository {
  static const String _modeEncrypted = 'encrypted';
  static const String _modePlain = 'plain';

  Future<bool> isPlaintextVault() async {
    final modePath = await VaultPaths.vaultModePath();
    if (!modePath.existsSync()) return false;
    final raw = await modePath.readAsString();
    return raw.trim().toLowerCase() == _modePlain;
  }

  /// Crea cofre nuevo: escribe `vault.keys` y `vault.bin`.
  Future<Uint8List?> createVault({
    String? password,
    bool encrypted = true,
    List<FolioPage>? initialPages,
    VaultStarterContent starterContent = VaultStarterContent.enabled,
  }) async {
    final payload = VaultPayload(
      pages: initialPages ?? buildVaultStarterPages(starterContent),
    );
    final modePath = await VaultPaths.vaultModePath();
    final payloadPath = await VaultPaths.cipherPayloadPath();
    final wrappedPath = await VaultPaths.wrappedDekPath();
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw StateError('Se requiere contraseña para cofre cifrado');
      }
      final dekBytes = VaultCrypto.randomBytes(VaultCrypto.dekLength);
      final wrapped = await VaultCrypto.wrapDek(
        dek: dekBytes,
        password: password,
      );
      final dek = await VaultCrypto.dekFromBytes(dekBytes);
      final enc = await VaultCrypto.encryptPayload(
        plain: payload.encodeUtf8(),
        dek: dek,
      );
      await wrappedPath.writeAsBytes(wrapped);
      await payloadPath.writeAsBytes(enc);
      await modePath.writeAsString(_modeEncrypted, flush: true);
      return dekBytes;
    }
    if (wrappedPath.existsSync()) {
      await wrappedPath.delete();
    }
    await payloadPath.writeAsBytes(payload.encodeUtf8());
    await modePath.writeAsString(_modePlain, flush: true);
    return null;
  }

  Future<Uint8List> unlockWithPassword(String password) async {
    final wrapped = await (await VaultPaths.wrappedDekPath()).readAsBytes();
    return VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
  }

  Future<VaultPayload> loadPayload(List<int>? dekBytes) async {
    final raw = await (await VaultPaths.cipherPayloadPath()).readAsBytes();
    if (await isPlaintextVault()) {
      return VaultPayload.decodeUtf8(raw);
    }
    if (dekBytes == null) {
      throw StateError('Se requiere DEK para abrir cofre cifrado');
    }
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final clear = await VaultCrypto.decryptPayload(blob: raw, dek: dek);
    return VaultPayload.decodeUtf8(clear);
  }

  Future<void> savePayload(VaultPayload payload, List<int>? dekBytes) async {
    if (await isPlaintextVault()) {
      await (await VaultPaths.cipherPayloadPath()).writeAsBytes(
        payload.encodeUtf8(),
      );
      return;
    }
    if (dekBytes == null) {
      throw StateError('Se requiere DEK para guardar cofre cifrado');
    }
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    await (await VaultPaths.cipherPayloadPath()).writeAsBytes(enc);
  }

  Future<void> rewrapDek({
    required String currentPassword,
    required String newPassword,
  }) async {
    final wrappedPath = await VaultPaths.wrappedDekPath();
    final wrapped = await wrappedPath.readAsBytes();
    final dek = await VaultCrypto.unwrapDek(
      wrapped: wrapped,
      password: currentPassword,
    );
    final rewrapped = await VaultCrypto.wrapDek(
      dek: dek,
      password: newPassword,
    );
    await wrappedPath.writeAsBytes(rewrapped, flush: true);
  }

  /// Pasa un cofre en texto plano a cifrado con [password]. Sobreescribe
  /// `vault.mode`, `vault.keys` y `vault.bin`.
  Future<Uint8List> encryptPlainVaultWithPassword({
    required VaultPayload payload,
    required String password,
  }) async {
    if (!(await isPlaintextVault())) {
      throw StateError('El cofre no está en modo texto plano');
    }
    if (password.isEmpty) {
      throw StateError('Se requiere contraseña');
    }
    final dekBytes = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    final wrapped = await VaultCrypto.wrapDek(
      dek: dekBytes,
      password: password,
    );
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    final modePath = await VaultPaths.vaultModePath();
    final payloadPath = await VaultPaths.cipherPayloadPath();
    final wrappedPath = await VaultPaths.wrappedDekPath();
    await wrappedPath.writeAsBytes(wrapped, flush: true);
    await payloadPath.writeAsBytes(enc, flush: true);
    await modePath.writeAsString(_modeEncrypted, flush: true);
    return dekBytes;
  }
}
