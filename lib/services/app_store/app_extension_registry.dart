import 'package:flutter/material.dart';

import '../../features/workspace/editor/block_type_catalog.dart';
import '../../models/folio_app_package.dart';
import '../../models/installed_folio_app.dart';

/// Registry singleton que mantiene en memoria todas las extensiones registradas
/// por apps instaladas y habilitadas.
///
/// Debe llamarse [loadFromInstalledApps] cada vez que cambia la lista de apps
/// instaladas o se habilita/deshabilita una app.
class AppExtensionRegistry extends ChangeNotifier {
  AppExtensionRegistry._();

  static final AppExtensionRegistry _instance = AppExtensionRegistry._();
  static AppExtensionRegistry get instance => _instance;

  // ── Extensiones registradas ────────────────────────────────────────────────

  List<BlockTypeDef> _blockTypes = const [];
  List<BlockTypeDef> _slashCommands = const [];
  List<FolioAppAiTransformer> _aiTransformers = const [];
  Map<String, FolioAppIntegration> _integrations = const {};

  /// Tipos de bloque custom registrados por apps (para el selector de bloque y slash menu).
  List<BlockTypeDef> get registeredBlockTypes => _blockTypes;

  /// Slash commands registrados por apps (para el menú `/`).
  List<BlockTypeDef> get registeredSlashCommands => _slashCommands;

  /// AI Transformers registrados por apps.
  List<FolioAppAiTransformer> get registeredAiTransformers => _aiTransformers;

  /// Mapa de integraciones por clave namespaced.
  Map<String, FolioAppIntegration> get registeredIntegrations => _integrations;

  // ── Mapa de lookup rápido ──────────────────────────────────────────────────

  /// Devuelve el [FolioAppBlockType] original para una clave namespaced, null si no existe.
  FolioAppBlockType? blockTypeForKey(String key) => _blockTypeMap[key];

  /// Devuelve el [FolioAppSlashCommand] original para una clave namespaced, null si no existe.
  FolioAppSlashCommand? slashCommandForKey(String key) => _slashCommandMap[key];

  Map<String, FolioAppBlockType> _blockTypeMap = const {};
  Map<String, FolioAppSlashCommand> _slashCommandMap = const {};

  /// Mapa de appId → localPath de las apps instaladas y habilitadas.
  Map<String, String> _installedLocalPaths = const {};
  Map<String, String> get installedLocalPaths => _installedLocalPaths;

  // ── Carga ──────────────────────────────────────────────────────────────────

  /// Reconstruye todos los registros a partir de la lista de apps instaladas.
  /// Solo se consideran apps con [InstalledFolioApp.enabled] == true.
  void loadFromInstalledApps(List<InstalledFolioApp> apps) {
    final blockTypes = <BlockTypeDef>[];
    final slashCmds = <BlockTypeDef>[];
    final transformers = <FolioAppAiTransformer>[];
    final integrations = <String, FolioAppIntegration>{};
    final blockTypeMap = <String, FolioAppBlockType>{};
    final slashCommandMap = <String, FolioAppSlashCommand>{};
    final localPaths = <String, String>{};

    for (final app in apps) {
      if (!app.enabled) continue;
      final pkg = app.package;

      if (app.localPath?.isNotEmpty == true) {
        localPaths[pkg.id] = app.localPath!;
      }

      for (final bt in pkg.blockTypes) {
        if (bt.typeKey.isEmpty || !bt.typeKey.contains('.')) continue;
        blockTypeMap[bt.typeKey] = bt;
        blockTypes.add(_toBlockTypeDef(bt));
      }

      for (final cmd in pkg.slashCommands) {
        if (cmd.key.isEmpty || !cmd.key.contains('.')) continue;
        slashCommandMap[cmd.key] = cmd;
        slashCmds.add(_slashCommandToBlockTypeDef(cmd));
      }

      for (final t in pkg.aiTransformers) {
        if (t.key.isEmpty) continue;
        transformers.add(t);
      }

      for (final i in pkg.integrations) {
        if (i.key.isEmpty) continue;
        integrations[i.key] = i;
      }
    }

    _blockTypes = List.unmodifiable(blockTypes);
    _slashCommands = List.unmodifiable(slashCmds);
    _aiTransformers = List.unmodifiable(transformers);
    _integrations = Map.unmodifiable(integrations);
    _blockTypeMap = Map.unmodifiable(blockTypeMap);
    _slashCommandMap = Map.unmodifiable(slashCommandMap);
    _installedLocalPaths = Map.unmodifiable(localPaths);

    notifyListeners();
  }

  // ── Conversiones ──────────────────────────────────────────────────────────

  BlockTypeDef _toBlockTypeDef(FolioAppBlockType bt) {
    return BlockTypeDef(
      key: bt.typeKey,
      label: bt.displayName,
      hint: bt.hint,
      icon: Icons.widgets_outlined,
      section: BlockTypeSection.apps,
    );
  }

  BlockTypeDef _slashCommandToBlockTypeDef(FolioAppSlashCommand cmd) {
    return BlockTypeDef(
      key: cmd.key,
      label: cmd.displayName,
      hint: cmd.hint,
      icon: Icons.bolt_rounded,
      section: BlockTypeSection.apps,
    );
  }
}
