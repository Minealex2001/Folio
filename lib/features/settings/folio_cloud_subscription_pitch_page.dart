import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

/// Pantalla breve con beneficios de Folio Cloud antes de registrarse o abrir checkout.
class FolioCloudSubscriptionPitchPage extends StatefulWidget {
  const FolioCloudSubscriptionPitchPage({
    super.key,
    required this.onPrimaryCta,
    required this.primaryCtaLabel,
    this.primaryIcon = Icons.subscriptions_outlined,
    this.busy = false,
  });

  final VoidCallback onPrimaryCta;
  final String primaryCtaLabel;
  final IconData primaryIcon;
  final bool busy;

  @override
  State<FolioCloudSubscriptionPitchPage> createState() =>
      _FolioCloudSubscriptionPitchPageState();
}

class _FolioCloudSubscriptionPitchPageState
    extends State<FolioCloudSubscriptionPitchPage>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late AnimationController _heroPulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _heroPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _heroPulse.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: curve),
    );
  }

  Widget _fadeSlide({
    required Animation<double> animation,
    required Widget child,
    double slideY = 0.07,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final opacity = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slideY * MediaQuery.sizeOf(context).height * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget featureCard({
      required int stepIndex,
      required IconData icon,
      required String title,
      required String body,
      required List<Color> accent,
      required Color onAccent,
    }) {
      final anim = _interval(0.22 + stepIndex * 0.11, 0.62 + stepIndex * 0.11);
      return _fadeSlide(
        animation: anim,
        slideY: 0.04,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FolioRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                scheme.surface.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: FolioShadows.card(scheme),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: accent,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.last.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: onAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final heroAnim = _interval(0.0, 0.24, curve: Curves.easeOutCubic);
    final headlineAnim = _interval(0.08, 0.32);
    final subAnim = _interval(0.14, 0.38);
    final ctaAnim = _interval(0.72, 1.0, curve: Curves.easeOutBack);

    Widget leftColumn({required bool wide}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) const SizedBox(height: 8),
          if (!wide)
            Center(
              child: _fadeSlide(
                animation: heroAnim,
                slideY: 0.12,
                child: AnimatedBuilder(
                  animation: _heroPulse,
                  builder: (context, child) {
                    final pulse = 1.0 + (_heroPulse.value * 0.04);
                    return Transform.scale(
                      scale: pulse,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.tertiary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: -4,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.cloud_rounded,
                      size: 56,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          if (!wide) const SizedBox(height: FolioSpace.lg),
          if (wide)
            _fadeSlide(
              animation: heroAnim,
              slideY: 0.10,
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _heroPulse,
                    builder: (context, child) {
                      final pulse = 1.0 + (_heroPulse.value * 0.035);
                      return Transform.scale(scale: pulse, child: child);
                    },
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.cloud_rounded,
                        size: 54,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      l10n.folioCloudPitchScreenTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (wide) const SizedBox(height: FolioSpace.lg),
          _fadeSlide(
            animation: headlineAnim,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                l10n.folioCloudPitchHeadline,
                style: (wide ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: wide ? TextAlign.left : TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: FolioSpace.md),
          _fadeSlide(
            animation: subAnim,
            child: Text(
              l10n.folioCloudPitchSubhead,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
              textAlign: wide ? TextAlign.left : TextAlign.center,
            ),
          ),
          const SizedBox(height: FolioSpace.xl),
          _fadeSlide(
            animation: ctaAnim,
            slideY: 0.05,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FolioRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: widget.busy ? null : widget.onPrimaryCta,
                icon: Icon(widget.primaryIcon, size: 22),
                label: Text(
                  widget.primaryCtaLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FolioRadius.lg),
                  ),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: FolioSpace.md),
          if (!wide)
            Center(
              child: _fadeSlide(
                animation: _interval(0.85, 1.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      size: 17,
                      color: scheme.primary.withValues(alpha: 0.9),
                    ),
                    Text(
                      l10n.folioCloudFeatureBackup,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '·',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    Text(
                      l10n.folioCloudFeatureCloudAi,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '·',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    Text(
                      l10n.folioCloudFeaturePublishWeb,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (wide)
            _fadeSlide(
              animation: _interval(0.85, 1.0),
              child: Text(
                '${l10n.folioCloudFeatureBackup} · ${l10n.folioCloudFeatureCloudAi} · ${l10n.folioCloudFeaturePublishWeb}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    Widget rightColumn() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          featureCard(
            stepIndex: 0,
            icon: Icons.backup_rounded,
            title: l10n.onboardingFolioCloudFeatureBackupTitle,
            body: l10n.onboardingFolioCloudFeatureBackupBody,
            accent: [
              scheme.primary,
              Color.lerp(scheme.primary, scheme.primaryContainer, 0.4)!,
            ],
            onAccent: scheme.onPrimary,
          ),
          const SizedBox(height: FolioSpace.sm),
          featureCard(
            stepIndex: 1,
            icon: Icons.auto_awesome_rounded,
            title: l10n.onboardingFolioCloudFeatureAiTitle,
            body: l10n.onboardingFolioCloudFeatureAiBody,
            accent: [
              scheme.tertiary,
              Color.lerp(scheme.tertiary, scheme.tertiaryContainer, 0.35)!,
            ],
            onAccent: scheme.onTertiary,
          ),
          const SizedBox(height: FolioSpace.sm),
          featureCard(
            stepIndex: 2,
            icon: Icons.public_rounded,
            title: l10n.onboardingFolioCloudFeatureWebTitle,
            body: l10n.onboardingFolioCloudFeatureWebBody,
            accent: [
              scheme.secondary,
              Color.lerp(scheme.secondary, scheme.secondaryContainer, 0.35)!,
            ],
            onAccent: scheme.onSecondary,
          ),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.folioCloudPitchScreenTitle),
      ),
      body: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(scheme.primaryContainer, scheme.surface, 0.35)!,
                    scheme.surface,
                    Color.lerp(scheme.tertiaryContainer, scheme.surface, 0.55)!,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          // Orbes decorativos
          Positioned(
            top: -60,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.tertiary.withValues(alpha: 0.18),
                      scheme.tertiary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewH = constraints.maxHeight;
                final wide = constraints.maxWidth >= 980;
                final pad = EdgeInsets.fromLTRB(
                  wide ? FolioSpace.xl : FolioSpace.md,
                  FolioSpace.sm,
                  wide ? FolioSpace.xl : FolioSpace.md,
                  FolioSpace.xl,
                );

                if (wide) {
                  return SizedBox(
                    height: viewH,
                    child: Padding(
                      padding: pad,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: LayoutBuilder(
                              builder: (context, colConstraints) {
                                return SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: colConstraints.maxHeight,
                                    ),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: leftColumn(wide: true),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: FolioSpace.xl),
                          Expanded(
                            flex: 6,
                            child: LayoutBuilder(
                              builder: (context, colConstraints) {
                                return SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: colConstraints.maxHeight,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        featureCard(
                                          stepIndex: 0,
                                          icon: Icons.backup_rounded,
                                          title: l10n
                                              .onboardingFolioCloudFeatureBackupTitle,
                                          body: l10n
                                              .onboardingFolioCloudFeatureBackupBody,
                                          accent: [
                                            scheme.primary,
                                            Color.lerp(
                                              scheme.primary,
                                              scheme.primaryContainer,
                                              0.4,
                                            )!,
                                          ],
                                          onAccent: scheme.onPrimary,
                                        ),
                                        featureCard(
                                          stepIndex: 1,
                                          icon: Icons.auto_awesome_rounded,
                                          title: l10n
                                              .onboardingFolioCloudFeatureAiTitle,
                                          body: l10n
                                              .onboardingFolioCloudFeatureAiBody,
                                          accent: [
                                            scheme.tertiary,
                                            Color.lerp(
                                              scheme.tertiary,
                                              scheme.tertiaryContainer,
                                              0.35,
                                            )!,
                                          ],
                                          onAccent: scheme.onTertiary,
                                        ),
                                        featureCard(
                                          stepIndex: 2,
                                          icon: Icons.public_rounded,
                                          title: l10n
                                              .onboardingFolioCloudFeatureWebTitle,
                                          body: l10n
                                              .onboardingFolioCloudFeatureWebBody,
                                          accent: [
                                            scheme.secondary,
                                            Color.lerp(
                                              scheme.secondary,
                                              scheme.secondaryContainer,
                                              0.35,
                                            )!,
                                          ],
                                          onAccent: scheme.onSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: pad,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewH),
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn(wide: false),
                          const SizedBox(height: FolioSpace.xl),
                          rightColumn(),
                          const SizedBox(height: FolioSpace.lg),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
