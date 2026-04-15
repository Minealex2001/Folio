import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;

import '../crypto/vault_crypto.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

enum VaultStarterContent {
  enabled,
  disabled,
}

List<FolioPage> buildVaultStarterPages(
  VaultStarterContent starterContent,
  AppLocalizations l10n,
) {
  if (starterContent == VaultStarterContent.disabled) {
    return const [];
  }
  return [
    FolioPage(
      id: 'starter_home',
      title: l10n.vaultStarterHomeTitle,
      blocks: [
        FolioBlock(
          id: 'starter_home_b0',
          type: 'h1',
          text: l10n.vaultStarterHomeHeading,
        ),
        FolioBlock(
          id: 'starter_home_b1',
          type: 'paragraph',
          text: l10n.vaultStarterHomeIntro,
        ),
        FolioBlock(
          id: 'starter_home_b2',
          type: 'callout',
          text: l10n.vaultStarterHomeCallout,
          icon: '💡',
        ),
        FolioBlock(
          id: 'starter_home_b3',
          type: 'h2',
          text: l10n.vaultStarterHomeSectionTips,
        ),
        FolioBlock(
          id: 'starter_home_b4',
          type: 'bullet',
          text: l10n.vaultStarterHomeBulletSlash,
        ),
        FolioBlock(
          id: 'starter_home_b5',
          type: 'bullet',
          text: l10n.vaultStarterHomeBulletSidebar,
        ),
        FolioBlock(
          id: 'starter_home_b6',
          type: 'bullet',
          text: l10n.vaultStarterHomeBulletSettings,
        ),
        FolioBlock(
          id: 'starter_home_b7',
          type: 'divider',
          text: '',
        ),
        FolioBlock(
          id: 'starter_home_b8',
          type: 'todo',
          text: l10n.vaultStarterHomeTodo1,
          checked: false,
        ),
        FolioBlock(
          id: 'starter_home_b9',
          type: 'todo',
          text: l10n.vaultStarterHomeTodo2,
          checked: false,
        ),
        FolioBlock(
          id: 'starter_home_b10',
          type: 'todo',
          text: l10n.vaultStarterHomeTodo3,
          checked: false,
        ),
      ],
    ),
    FolioPage(
      id: 'starter_capabilities',
      title: l10n.vaultStarterCapabilitiesTitle,
      blocks: [
        FolioBlock(
          id: 'starter_capabilities_b0',
          type: 'h2',
          text: l10n.vaultStarterCapabilitiesSectionMain,
        ),
        FolioBlock(
          id: 'starter_capabilities_b1',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesBullet1,
        ),
        FolioBlock(
          id: 'starter_capabilities_b2',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesBullet2,
        ),
        FolioBlock(
          id: 'starter_capabilities_b3',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesBullet3,
        ),
        FolioBlock(
          id: 'starter_capabilities_b4',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesBullet4,
        ),
        FolioBlock(
          id: 'starter_capabilities_b5',
          type: 'h2',
          text: l10n.vaultStarterCapabilitiesSectionShortcuts,
        ),
        FolioBlock(
          id: 'starter_capabilities_b6',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesShortcutN,
        ),
        FolioBlock(
          id: 'starter_capabilities_b7',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesShortcutSearch,
        ),
        FolioBlock(
          id: 'starter_capabilities_b8',
          type: 'bullet',
          text: l10n.vaultStarterCapabilitiesShortcutSettings,
        ),
        FolioBlock(
          id: 'starter_capabilities_b9',
          type: 'callout',
          text: l10n.vaultStarterCapabilitiesAiCallout,
          icon: '🧠',
        ),
      ],
    ),
    FolioPage(
      id: 'starter_quill',
      title: l10n.vaultStarterQuillTitle,
      blocks: [
        FolioBlock(
          id: 'starter_quill_b0',
          type: 'h2',
          text: l10n.vaultStarterQuillSectionWhat,
        ),
        FolioBlock(
          id: 'starter_quill_b1',
          type: 'bullet',
          text: l10n.vaultStarterQuillBullet1,
        ),
        FolioBlock(
          id: 'starter_quill_b2',
          type: 'bullet',
          text: l10n.vaultStarterQuillBullet2,
        ),
        FolioBlock(
          id: 'starter_quill_b3',
          type: 'bullet',
          text: l10n.vaultStarterQuillBullet3,
        ),
        FolioBlock(
          id: 'starter_quill_b4',
          type: 'h2',
          text: l10n.vaultStarterQuillSectionPrivacy,
        ),
        FolioBlock(
          id: 'starter_quill_b5',
          type: 'paragraph',
          text: l10n.vaultStarterQuillPrivacyBody,
        ),
        FolioBlock(
          id: 'starter_quill_b6',
          type: 'callout',
          text: l10n.vaultStarterQuillBackupCallout,
          icon: '🔐',
        ),
        FolioBlock(
          id: 'starter_quill_b7',
          type: 'paragraph',
          text: l10n.vaultStarterQuillMermaidCaption,
        ),
        FolioBlock(
          id: 'starter_quill_b8',
          type: 'mermaid',
          text: l10n.vaultStarterQuillMermaidSource,
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

  /// Crea libreta nueva: escribe `vault.keys` y `vault.bin`.
  Future<Uint8List?> createVault({
    String? password,
    bool encrypted = true,
    List<FolioPage>? initialPages,
    VaultStarterContent starterContent = VaultStarterContent.enabled,
    AppLocalizations? starterL10n,
  }) async {
    final l10n = starterL10n ?? lookupAppLocalizations(const Locale('es'));
    final payload = VaultPayload(
      pages: initialPages ?? buildVaultStarterPages(starterContent, l10n),
    );
    final modePath = await VaultPaths.vaultModePath();
    final payloadPath = await VaultPaths.cipherPayloadPath();
    final wrappedPath = await VaultPaths.wrappedDekPath();
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw StateError('Se requiere contraseña para libreta cifrada');
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
      throw StateError('Se requiere DEK para abrir libreta cifrada');
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
      throw StateError('Se requiere DEK para guardar libreta cifrada');
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

  /// Pasa una libreta en texto plano a cifrado con [password]. Sobreescribe
  /// `vault.mode`, `vault.keys` y `vault.bin`.
  Future<Uint8List> encryptPlainVaultWithPassword({
    required VaultPayload payload,
    required String password,
  }) async {
    if (!(await isPlaintextVault())) {
      throw StateError('La libreta no está en modo texto plano');
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
