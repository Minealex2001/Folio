part of 'settings_page.dart';

/// Rail de navegación persistente para Settings en ventanas de escritorio
/// anchas (>= [FolioDesktop.mediumBreakpoint]): sustituye a la rejilla de
/// tarjetas + drill-in total que se usa en anchos menores.
class _SettingsSectionRail extends StatelessWidget {
  const _SettingsSectionRail({
    required this.sections,
    required this.selectedId,
    required this.onSelect,
    required this.scheme,
    required this.searchController,
    required this.l10n,
  });

  final List<_SettingsSectionNavItem> sections;
  final _SettingsSectionId selectedId;
  final ValueChanged<_SettingsSectionId> onSelect;
  final ColorScheme scheme;
  final TextEditingController searchController;
  final AppLocalizations l10n;

  static IconData _iconFor(_SettingsSectionId id) {
    switch (id) {
      case _SettingsSectionId.cloud:
        return Icons.cloud_outlined;
      case _SettingsSectionId.vault:
        return Icons.lock_outline_rounded;
      case _SettingsSectionId.appearance:
        return Icons.palette_outlined;
      case _SettingsSectionId.desktop:
        return Icons.desktop_windows_rounded;
      case _SettingsSectionId.ai:
        return FolioIcons.quillOutlined;
      case _SettingsSectionId.sync:
        return Icons.sync_rounded;
      case _SettingsSectionId.about:
        return Icons.info_outline_rounded;
      case _SettingsSectionId.integrations:
        return Icons.extension_outlined;
      case _SettingsSectionId.organization:
        return Icons.groups_outlined;
      case _SettingsSectionId.personalization:
        return Icons.dashboard_customize_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: FolioDesktop.settingsRailWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: FolioSpace.md,
          horizontal: FolioSpace.sm,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: FolioSpace.sm),
            child: Semantics(
              label: l10n.settingsSearchSections,
              textField: true,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l10n.settingsSearchSectionsHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FolioRadius.md),
                  ),
                ),
              ),
            ),
          ),
          for (final sec in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: FolioSpace.xxs),
              child: _SettingsRailTile(
                sec: sec,
                icon: _iconFor(sec.id),
                selected: sec.id == selectedId,
                scheme: scheme,
                onTap: () => onSelect(sec.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsRailTile extends StatefulWidget {
  const _SettingsRailTile({
    required this.sec,
    required this.icon,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final _SettingsSectionNavItem sec;
  final IconData icon;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  State<_SettingsRailTile> createState() => _SettingsRailTileState();
}

class _SettingsRailTileState extends State<_SettingsRailTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final selected = widget.selected;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(FolioRadius.md),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: FolioMotion.short2,
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.sm,
              vertical: FolioSpace.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.secondaryContainer
                  : (_isHovered
                        ? scheme.surfaceContainer
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: selected ? fg : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    widget.sec.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuTile extends StatefulWidget {
  const _SettingsMenuTile({
    required this.sec,
    required this.l10n,
    required this.scheme,
    required this.app,
    required this.cloud,
    required this.installedVersionLabel,
    required this.onTap,
  });

  final _SettingsSectionNavItem sec;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final AppSettings app;
  final CloudAccountController cloud;
  final String installedVersionLabel;
  final VoidCallback onTap;

  @override
  State<_SettingsMenuTile> createState() => _SettingsMenuTileState();
}

class _SettingsMenuTileState extends State<_SettingsMenuTile> {
  bool _isHovered = false;

  String _providerLabel(AiProvider provider, AppLocalizations l10n) {
    switch (provider) {
      case AiProvider.ollama:
        return l10n.aiProviderOllamaName;
      case AiProvider.lmStudio:
        return l10n.aiProviderLmStudioName;
      case AiProvider.quillCloud:
        return 'Quill Cloud';
      case AiProvider.openAi:
        return 'OpenAI';
      case AiProvider.gemini:
        return 'Gemini';
      case AiProvider.geminiNano:
        switch (OnDeviceAiBridge.cachedBrandOrDefault) {
          case OnDeviceAiBrand.samsung:
            return l10n.aiProviderGalaxyAiByGemini;
          case OnDeviceAiBrand.google:
          case OnDeviceAiBrand.other:
            return l10n.aiProviderGeminiNano;
        }
      case AiProvider.none:
        return l10n.aiProviderNone;
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    List<Color> gradientColors;
    String subtitle;

    switch (widget.sec.id) {
      case _SettingsSectionId.cloud:
        icon = Icons.cloud_outlined;
        gradientColors = const [Color(0xFF42A5F5), Color(0xFF1E88E5)];
        subtitle = widget.cloud.isSignedIn
            ? (widget.cloud.email ?? 'Sesión iniciada')
            : 'Configura tu cuenta';
        break;
      case _SettingsSectionId.vault:
        icon = Icons.lock_outline_rounded;
        gradientColors = const [Color(0xFFAB47BC), Color(0xFF7B1FA2)];
        subtitle = 'Copia de seguridad, seguridad y datos';
        break;
      case _SettingsSectionId.appearance:
        icon = Icons.palette_outlined;
        gradientColors = const [Color(0xFFFF7043), Color(0xFFE64A19)];
        subtitle = widget.l10n.settingsSectionAppearanceHeroDescription;
        break;
      case _SettingsSectionId.desktop:
        icon = Icons.desktop_windows_rounded;
        gradientColors = const [Color(0xFF5C6BC0), Color(0xFF3949AB)];
        subtitle = widget.l10n.settingsSectionDesktopHeroDescription;
        break;
      case _SettingsSectionId.ai:
        icon = FolioIcons.quillOutlined;
        gradientColors = const [Color(0xFF26A69A), Color(0xFF00796B)];
        subtitle = widget.app.aiEnabled
            ? 'Proveedor: ${_providerLabel(widget.app.aiProvider, widget.l10n)}'
            : 'Deshabilitado';
        break;
      case _SettingsSectionId.sync:
        icon = Icons.sync_rounded;
        gradientColors = const [Color(0xFFEC407A), Color(0xFFC2185B)];
        subtitle = 'Sincronizar tus dispositivos';
        break;
      case _SettingsSectionId.about:
        icon = Icons.info_outline_rounded;
        gradientColors = const [Color(0xFF00F3FF), Color(0xFFFF00FF)];
        subtitle = 'Versión ${widget.installedVersionLabel}';
        break;
      case _SettingsSectionId.integrations:
        icon = Icons.extension_outlined;
        gradientColors = const [Color(0xFF26C6DA), Color(0xFF0097A7)];
        subtitle = 'Conexiones con Jira, YouTrack y más';
        break;
      case _SettingsSectionId.organization:
        icon = Icons.groups_outlined;
        gradientColors = const [Color(0xFF66BB6A), Color(0xFF2E7D32)];
        subtitle = widget.l10n.settingsOrganizationHeroSubtitle;
        break;
      case _SettingsSectionId.personalization:
        icon = Icons.dashboard_customize_outlined;
        gradientColors = const [Color(0xFF8D6E63), Color(0xFF5D4037)];
        subtitle = 'Motor de layout, tema y dashboard (beta)';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isHovered
                        ? widget.scheme.primary.withValues(alpha: 0.5)
                        : widget.scheme.outlineVariant.withValues(alpha: 0.35),
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  color: _isHovered
                      ? widget.scheme.surfaceContainer
                      : widget.scheme.surfaceContainerLow,
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: widget.scheme.shadow.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.sec.label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: widget.scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchItem {
  final _SettingsSectionId category;
  final String title;
  final String description;
  final List<String> keywords;
  final Widget Function(BuildContext context) builder;

  _SearchItem({
    required this.category,
    required this.title,
    required this.description,
    required this.keywords,
    required this.builder,
  });
}

/// Tema (system/light/dark/OLED) + acento — compartido entre Apariencia y
/// Personalización. Solo una sección es visible a la vez, así el control
/// aparece en ambas rutas sin duplicarse en pantalla.
class _ThemeAndAccentControls extends StatelessWidget {
  const _ThemeAndAccentControls({required this.appSettings});

  final AppSettings appSettings;

  static const _accentPresets = <int>[
    0xFF00F3FF,
    0xFF1565C0,
    0xFF0277BD,
    0xFF6A1B9A,
    0xFFAD1457,
    0xFF2E7D32,
    0xFF558B2F,
    0xFFBF360C,
    0xFF00695C,
    0xFF283593,
    0xFF4E342E,
    0xFF37474F,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<FolioThemeMode>(
                segments: [
                  ButtonSegment<FolioThemeMode>(
                    value: FolioThemeMode.system,
                    label: Text(l10n.systemTheme),
                    icon: const Icon(Icons.brightness_auto, size: 18),
                  ),
                  ButtonSegment<FolioThemeMode>(
                    value: FolioThemeMode.light,
                    label: Text(l10n.lightTheme),
                    icon: const Icon(Icons.light_mode_outlined, size: 18),
                  ),
                  ButtonSegment<FolioThemeMode>(
                    value: FolioThemeMode.dark,
                    label: Text(l10n.darkTheme),
                    icon: const Icon(Icons.dark_mode_outlined, size: 18),
                  ),
                  ButtonSegment<FolioThemeMode>(
                    value: FolioThemeMode.oled,
                    label: Text(l10n.oledTheme),
                    icon: const Icon(Icons.contrast, size: 18),
                  ),
                ],
                selected: {appSettings.themeMode},
                onSelectionChanged: (s) {
                  appSettings.setThemeMode(s.first);
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.settingsAccentColorTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<FolioAccentColorMode>(
                segments: [
                  ButtonSegment<FolioAccentColorMode>(
                    value: FolioAccentColorMode.followSystem,
                    label: Text(FolioAdaptive.currentPlatformName()),
                    icon: const Icon(Icons.palette_outlined, size: 18),
                  ),
                  ButtonSegment<FolioAccentColorMode>(
                    value: FolioAccentColorMode.folioDefault,
                    label: Text(l10n.settingsAccentFolioDefault),
                    icon: const Icon(Icons.brush_outlined, size: 18),
                  ),
                  ButtonSegment<FolioAccentColorMode>(
                    value: FolioAccentColorMode.custom,
                    label: Text(l10n.settingsAccentCustom),
                    icon: const Icon(Icons.color_lens_outlined, size: 18),
                  ),
                ],
                selected: {appSettings.accentColorMode},
                onSelectionChanged: (s) {
                  appSettings.setAccentColorMode(s.first);
                },
              ),
            ),
            if (appSettings.accentColorMode == FolioAccentColorMode.custom) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.color_lens,
                  color: Color(appSettings.customAccentArgb),
                ),
                title: Text(l10n.settingsAccentPickColor),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (ctx) {
                      return FolioDialog(
                        title: Text(l10n.settingsAccentPickColor),
                        content: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final a in _accentPresets)
                              Material(
                                color: Color(a),
                                elevation: 2,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.pop(ctx, a),
                                  child: const SizedBox(width: 44, height: 44),
                                ),
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.cancel),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked != null) {
                    await appSettings.setCustomAccentArgb(picked);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

