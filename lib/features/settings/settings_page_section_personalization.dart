part of 'settings_page.dart';

/// Primera superficie visible del sistema de personalización de UI (Fases
/// 0-7 del plan) — deliberadamente mínima y aislada en su propio archivo
/// (mismo motivo que `settings_page_section_organization.dart`): el resto
/// de `_SettingsPageState` es la clase más grande/riesgosa del repo, así
/// que esta sección no le añade campos ni lógica nueva, solo lee/escribe
/// [LayoutEngineController]/[ThemeConfigController] directamente.
extension _SettingsPagePersonalizationSection on _SettingsPageState {
  Widget _buildPersonalizationSection({
    required ColorScheme scheme,
    required _SettingsSectionId? activeSection,
  }) {
    return Visibility(
      visible: activeSection == _SettingsSectionId.personalization,
      maintainState: false,
      child: KeyedSubtree(
        key: const ValueKey(_SettingsSectionId.personalization),
        child: _SettingsPanel(
          margin: const EdgeInsets.only(bottom: 24),
          child: _PersonalizationSectionBody(
            appSettings: _app,
            layoutEngine: _layoutEngine,
            themeConfig: _themeConfig,
            dashboardGrid: _dashboardGrid,
            activePack: _activePack,
          ),
        ),
      ),
    );
  }
}

class _PersonalizationSectionBody extends StatelessWidget {
  const _PersonalizationSectionBody({
    required this.appSettings,
    required this.layoutEngine,
    required this.themeConfig,
    required this.dashboardGrid,
    required this.activePack,
  });

  final AppSettings appSettings;
  final LayoutEngineController layoutEngine;
  final ThemeConfigController themeConfig;
  final DashboardGridController dashboardGrid;
  final ActivePackController activePack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([layoutEngine, themeConfig, activePack]),
      builder: (context, _) {
        final sidebar = layoutEngine.panelFor(PanelRegionIds.sidebarLeft);
        final theme = themeConfig.config;
        final cornerScale = theme.shape.radiusMd == 0
            ? 1.0
            : theme.shape.radiusMd / kFolioDefaultTheme.shape.radiusMd;
        final spacingScale = theme.spacing.md == 0
            ? 1.0
            : theme.spacing.md / kFolioDefaultTheme.spacing.md;
        final motionSpeed = theme.motion.short2Ms == 0
            ? 1.0
            : kFolioDefaultTheme.motion.short2Ms / theme.motion.short2Ms;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SettingsPanelHeroCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Personalización (beta)',
              description:
                  'Motor de layout, tema y dashboard nuevos — esta pantalla '
                  'controla directamente los controllers en vivo que ya '
                  'renderiza la app.',
              chips: [
                _SettingsInfoChip(
                  icon: Icons.view_sidebar_outlined,
                  label: 'Motor de paneles',
                ),
                _SettingsInfoChip(
                  icon: Icons.palette_outlined,
                  label: 'Motor de tema',
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _ThemeAndAccentControls(appSettings: appSettings),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Panel lateral',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sidebar == null
                        ? 'Región no disponible.'
                        : 'Ancho actual: ${sidebar.width?.toStringAsFixed(0) ?? '—'} px',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bloquear panel lateral'),
                    subtitle: const Text(
                      'Impide redimensionar/mover el sidebar hasta que se '
                      'desbloquee de nuevo.',
                    ),
                    value: sidebar?.locked ?? false,
                    onChanged: sidebar == null
                        ? null
                        : (value) => layoutEngine.setLocked(
                            PanelRegionIds.sidebarLeft,
                            value,
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(layoutEngine.resetToDefault()),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer layout de paneles'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Editor de tema',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Forma, densidad, movimiento y transparencia. El modo '
                    'claro/oscuro y el acento están arriba (igual que en '
                    'Apariencia).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ThemeSlider(
                    label: 'Redondez de esquinas',
                    value: cornerScale,
                    min: 0.0,
                    max: 2.0,
                    onChanged: themeConfig.setCornerRoundness,
                  ),
                  _ThemeSlider(
                    label: 'Densidad de espaciado',
                    value: spacingScale,
                    min: 0.6,
                    max: 1.6,
                    onChanged: themeConfig.setSpacingDensity,
                  ),
                  _ThemeSlider(
                    label: 'Velocidad de movimiento',
                    value: motionSpeed,
                    min: 0.4,
                    max: 2.5,
                    onChanged: themeConfig.setMotionSpeed,
                  ),
                  _ThemeSlider(
                    label: 'Opacidad de superficies',
                    value: theme.surfaceOpacity,
                    min: 0.5,
                    max: 1.0,
                    onChanged: themeConfig.setSurfaceOpacity,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(themeConfig.resetToDefault()),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer tema'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Plantillas de dashboard',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Developer, Writer, Research, Student, Planning, Gaming — '
                    'cambia el contenido del dashboard de inicio. Tus '
                    'ediciones a una plantilla ya instalada se conservan al '
                    'volver a ella.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DashboardTemplatePicker(controller: dashboardGrid),
                ],
              ),
            ),
            const Divider(height: 1),
            _VisualPacksSection(
              appSettings: appSettings,
              layoutEngine: layoutEngine,
              themeConfig: themeConfig,
              dashboardGrid: dashboardGrid,
              activePack: activePack,
            ),
          ],
        );
      },
    );
  }
}

class _ThemeSlider extends StatelessWidget {
  const _ThemeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: clamped,
              min: min,
              max: max,
              label: clamped.toStringAsFixed(2),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fase 8 del plan de personalización: selector de packs visuales builtin +
/// exportar/importar el setup actual. Aplicar un pack reemplaza tema,
/// layout y dashboard a la vez, directo en los controllers en vivo (ver
/// `VisualPackInstaller`) — no hay una vista previa separada, la app
/// cambia de verdad al tocar "Aplicar".
class _VisualPacksSection extends StatefulWidget {
  const _VisualPacksSection({
    required this.appSettings,
    required this.layoutEngine,
    required this.themeConfig,
    required this.dashboardGrid,
    required this.activePack,
  });

  final AppSettings appSettings;
  final LayoutEngineController layoutEngine;
  final ThemeConfigController themeConfig;
  final DashboardGridController dashboardGrid;
  final ActivePackController activePack;

  @override
  State<_VisualPacksSection> createState() => _VisualPacksSectionState();
}

class _VisualPacksSectionState extends State<_VisualPacksSection> {
  bool _busy = false;

  VisualPackInstaller get _installer => VisualPackInstaller(
    layoutEngineController: widget.layoutEngine,
    themeConfigController: widget.themeConfig,
    dashboardGridController: widget.dashboardGrid,
    activePackController: widget.activePack,
  );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _applyPack(VisualPack pack) async {
    setState(() => _busy = true);
    try {
      // El picker de acento vive en AppSettings y, al cambiar, reescribe
      // accentMode/light/dark del ThemeConfig. Hay que alinearlo con el pack
      // *antes* de apply; luego apply vuelve a poner shape/OLED/dashboard.
      final accentMode = switch (pack.theme.accentMode) {
        'followSystem' => FolioAccentColorMode.followSystem,
        'folioDefault' => FolioAccentColorMode.folioDefault,
        _ => FolioAccentColorMode.custom,
      };
      if (accentMode == FolioAccentColorMode.custom) {
        await widget.appSettings.setCustomAccentArgb(pack.theme.light.seedArgb);
      }
      await widget.appSettings.setAccentColorMode(accentMode);
      await _installer.apply(pack);
      _snack('Pack "${pack.manifest.name}" aplicado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCurrent() async {
    final result = await showDialog<({String name, String author})>(
      context: context,
      builder: (context) => const _ExportPackDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final export = VisualPackExport(
        layoutEngineController: widget.layoutEngine,
        themeConfigController: widget.themeConfig,
        dashboardGridController: widget.dashboardGrid,
      );
      final slug = result.name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final id = slug.isEmpty ? 'custom_pack' : slug;
      final json = export.exportAsJson(
        id: id,
        name: result.name.trim(),
        author: result.author.trim().isEmpty ? null : result.author.trim(),
      );
      final bytes = Uint8List.fromList(utf8.encode(json));
      final fileName = '$id.folio-pack.json';
      if (kIsWeb) {
        folioTriggerBrowserDownload(fileName, bytes);
      } else {
        final path = await FilePicker.saveFile(
          dialogTitle: 'Guardar pack visual',
          fileName: fileName,
        );
        if (path == null) return;
        await File(path).writeAsBytes(bytes);
      }
      _snack('Setup actual exportado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPack() async {
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: kIsWeb,
      );
      if (pick == null || pick.files.isEmpty) return;
      final picked = pick.files.single;
      String jsonText;
      if (picked.bytes != null) {
        jsonText = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        jsonText = await File(picked.path!).readAsString();
      } else {
        _snack('No se pudo leer el archivo.');
        return;
      }
      final pack = VisualPack.fromJson(
        jsonDecode(jsonText) as Map<String, dynamic>,
      );
      await _installer.apply(pack);
      _snack('Pack "${pack.manifest.name}" importado y aplicado.');
    } catch (e) {
      _snack('No se pudo importar el pack: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = builtinVisualPacks();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Packs visuales',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aplica un pack para cambiar tema, layout y dashboard de golpe. '
            'También puedes exportar tu setup actual o importar uno.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pack in packs)
                _VisualPackCard(
                  pack: pack,
                  active: widget.activePack.activePackId == pack.manifest.id,
                  onApply: _busy ? null : () => unawaited(_applyPack(pack)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_exportCurrent()),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Exportar setup actual'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_importPack()),
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: const Text('Importar pack…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisualPackCard extends StatelessWidget {
  const _VisualPackCard({
    required this.pack,
    required this.active,
    required this.onApply,
  });

  final VisualPack pack;
  final bool active;
  final VoidCallback? onApply;

  List<Color> get _swatchColors {
    final lightArgb = pack.theme.light.seedArgb;
    final darkArgb = pack.theme.dark.seedArgb;
    final colors = <Color>[Color(lightArgb)];
    if (darkArgb != lightArgb) {
      colors.add(Color(darkArgb));
    }
    // Minealex Games: segundo acento de marca (magenta) aunque el seed sea uno.
    if (pack.manifest.id == 'minealex_games') {
      colors.add(const Color(0xFFFF00FF));
    }
    return colors.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatches = _swatchColors;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < swatches.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: swatches[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pack.manifest.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active)
                Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            pack.manifest.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: active ? null : onApply,
              child: Text(active ? 'Activo' : 'Aplicar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPackDialog extends StatefulWidget {
  const _ExportPackDialog();

  @override
  State<_ExportPackDialog> createState() => _ExportPackDialogState();
}

class _ExportPackDialogState extends State<_ExportPackDialog> {
  final _nameController = TextEditingController();
  final _authorController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exportar setup actual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre del pack'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(labelText: 'Autor (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            name: _nameController.text.trim().isEmpty
                ? 'Mi pack'
                : _nameController.text.trim(),
            author: _authorController.text.trim(),
          )),
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}
