import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_catalog_labels.dart';
import '../../services/folio_cloud/folio_cloud_catalog_prices.dart';

/// Contenido visual reutilizable del pitch de Folio Cloud (página o onboarding).
class FolioCloudPitchContent extends StatefulWidget {
  const FolioCloudPitchContent({
    super.key,
    required this.onPrimaryCta,
    required this.primaryCtaLabel,
    this.primaryIcon = Icons.subscriptions_outlined,
    this.busy = false,
    this.headlineOverride,
    this.highlightFeatureIndex = 0,
    this.embedded = false,
    this.onSkip,
    this.skipLabel,
  });

  final VoidCallback onPrimaryCta;
  final String primaryCtaLabel;
  final IconData primaryIcon;
  final bool busy;
  final String? headlineOverride;
  final int highlightFeatureIndex;
  final bool embedded;
  final VoidCallback? onSkip;
  final String? skipLabel;

  @override
  State<FolioCloudPitchContent> createState() => _FolioCloudPitchContentState();
}

class _FolioCloudPitchContentState extends State<FolioCloudPitchContent>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late AnimationController _heroPulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.embedded ? 900 : 1650),
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

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
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
            offset: Offset(
              0,
              slideY * MediaQuery.sizeOf(context).height * (1 - t),
            ),
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
    final headline =
        widget.headlineOverride ?? l10n.folioCloudPitchHeadline;
    final heroSize = widget.embedded ? 72.0 : 112.0;
    final iconSize = widget.embedded ? 36.0 : 56.0;

    Widget featureCard({
      required int stepIndex,
      required IconData icon,
      required String title,
      required String body,
      required List<Color> accent,
      required Color onAccent,
      required bool highlighted,
    }) {
      final anim = _interval(0.22 + stepIndex * 0.11, 0.62 + stepIndex * 0.11);
      return _fadeSlide(
        animation: anim,
        slideY: 0.04,
        child: Container(
          padding: EdgeInsets.all(widget.embedded ? 14 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FolioRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: 0.75),
                scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(
              color: highlighted
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.primary.withValues(alpha: 0.15),
              width: highlighted ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: highlighted ? 0.12 : 0.06,
                ),
                blurRadius: highlighted ? 24 : 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: widget.embedded ? 40 : 48,
                height: widget.embedded ? 40 : 48,
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
                child: Icon(icon, color: onAccent, size: widget.embedded ? 20 : 24),
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
    final hi = widget.highlightFeatureIndex.clamp(0, 2);

    Widget hero() {
      return _fadeSlide(
        animation: heroAnim,
        slideY: widget.embedded ? 0.06 : 0.12,
        child: AnimatedBuilder(
          animation: _heroPulse,
          builder: (context, child) {
            final pulse = 1.0 + (_heroPulse.value * (widget.embedded ? 0.02 : 0.04));
            return Transform.scale(scale: pulse, child: child);
          },
          child: Container(
            width: heroSize,
            height: heroSize,
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
            child: Icon(Icons.cloud_rounded, size: iconSize, color: scheme.onPrimary),
          ),
        ),
      );
    }

    Widget leftColumn({required bool wide}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide)
            Center(child: hero()),
          if (!wide) SizedBox(height: widget.embedded ? FolioSpace.md : FolioSpace.lg),
          if (wide) ...[
            _fadeSlide(
              animation: heroAnim,
              slideY: 0.10,
              child: Row(
                children: [
                  hero(),
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
            const SizedBox(height: FolioSpace.lg),
          ],
          _fadeSlide(
            animation: headlineAnim,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                headline,
                style: (wide
                        ? theme.textTheme.headlineMedium
                        : (widget.embedded
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall))
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
                fontSize: widget.embedded ? 14 : null,
              ),
              textAlign: wide ? TextAlign.left : TextAlign.center,
            ),
          ),
          const SizedBox(height: FolioSpace.md),
          _fadeSlide(
            animation: subAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FolioRadius.xl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.35),
                    scheme.surface.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    wide ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: wide
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.folioCloudPitchPremiumMonthlyLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<FolioCloudCatalogPricesSnapshot>(
                          future: FolioCloudCatalogPricesService.getPricing(),
                          builder: (context, snap) {
                            return Text(
                              FolioCloudCatalogLabels.subscribeMonthly(
                                context,
                                l10n,
                                snap.data,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: widget.embedded ? FolioSpace.md : FolioSpace.xl),
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
                  minimumSize: Size.fromHeight(widget.embedded ? 48 : 54),
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
          if (widget.onSkip != null && widget.skipLabel != null) ...[
            const SizedBox(height: FolioSpace.sm),
            Center(
              child: TextButton(
                onPressed: widget.busy ? null : widget.onSkip,
                child: Text(widget.skipLabel!),
              ),
            ),
          ],
          if (!widget.embedded) ...[
            const SizedBox(height: FolioSpace.md),
            Center(
              child: _fadeSlide(
                animation: _interval(0.85, 1.0),
                child: Text(
                  '${l10n.folioCloudFeatureBackup} · ${l10n.folioCloudFeatureCloudAi} · ${l10n.folioCloudFeaturePublishWeb}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
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
            highlighted: hi == 0,
          ),
          const SizedBox(height: FolioSpace.sm),
          featureCard(
            stepIndex: 1,
            icon: FolioIcons.quill,
            title: l10n.onboardingFolioCloudFeatureAiTitle,
            body: l10n.onboardingFolioCloudFeatureAiBody,
            accent: [
              scheme.tertiary,
              Color.lerp(scheme.tertiary, scheme.tertiaryContainer, 0.35)!,
            ],
            onAccent: scheme.onTertiary,
            highlighted: hi == 1,
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
            highlighted: hi == 2,
          ),
        ],
      );
    }

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftColumn(wide: false),
          const SizedBox(height: FolioSpace.md),
          rightColumn(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: leftColumn(wide: true)),
              const SizedBox(width: FolioSpace.xl),
              Expanded(flex: 6, child: rightColumn()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leftColumn(wide: false),
            const SizedBox(height: FolioSpace.xl),
            rightColumn(),
          ],
        );
      },
    );
  }
}

/// Fondo decorativo del pitch (orbes + gradiente).
class FolioCloudPitchBackground extends StatelessWidget {
  const FolioCloudPitchBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(scheme.primaryContainer, scheme.surface, 0.2)!,
                  scheme.surface,
                  Color.lerp(scheme.tertiaryContainer, scheme.surface, 0.4)!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.3),
                    scheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 180,
          left: -100,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.tertiary.withValues(alpha: 0.25),
                    scheme.tertiary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
