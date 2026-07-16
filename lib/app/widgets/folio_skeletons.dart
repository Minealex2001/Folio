import 'package:flutter/material.dart';

/// Animated shimmer loading effect. Primitiva base de todos los skeletons de
/// este archivo — envuelve cualquier child con un barrido de brillo animado.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - _animation.value, 0),
              end: Alignment(1 - _animation.value, 0),
              colors: [
                Colors.transparent,
                scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcOver,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Tamaño estándar de [FolioLoadingIndicator]: [small] para spinners inline
/// (dentro de un botón o fila), [normal] para el estado de carga de una
/// página o sección completa.
enum FolioLoadingSize { small, normal }

/// Indicador de carga circular estándar del design system, con los tamaños y
/// grosores de trazo que ya se repetían de forma ad hoc por toda la app.
class FolioLoadingIndicator extends StatelessWidget {
  const FolioLoadingIndicator({
    super.key,
    this.size = FolioLoadingSize.normal,
    this.color,
    this.centered = false,
    this.value,
  });

  final FolioLoadingSize size;
  final Color? color;
  final bool centered;

  /// Progreso determinado (0.0-1.0), p. ej. para descargas con porcentaje
  /// conocido. `null` (por defecto) muestra el spinner indeterminado.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final indicator = switch (size) {
      FolioLoadingSize.small => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
          value: value,
        ),
      ),
      FolioLoadingSize.normal => SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: color,
          value: value,
        ),
      ),
    };
    return centered ? Center(child: indicator) : indicator;
  }
}

/// Un bloque de color de esqueleto con bordes redondeados.
class FolioSkeletonBlock extends StatelessWidget {
  const FolioSkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Esqueleto animado para la cuadrícula de plantillas de la comunidad.
class FolioTemplateGallerySkeleton extends StatelessWidget {
  const FolioTemplateGallerySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 164,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          final scheme = Theme.of(context).colorScheme;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FolioSkeletonBlock(width: 28, height: 28, borderRadius: 6),
                    Spacer(),
                    FolioSkeletonBlock(width: 32, height: 18, borderRadius: 999),
                  ],
                ),
                SizedBox(height: 12),
                FolioSkeletonBlock(width: 120, height: 14),
                SizedBox(height: 8),
                FolioSkeletonBlock(width: 80, height: 10),
                Spacer(),
                FolioSkeletonBlock(width: double.infinity, height: 10),
                SizedBox(height: 4),
                FolioSkeletonBlock(width: 140, height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Esqueleto animado para las filas de miembros familiares en configuración.
class FolioFamilySeatsSkeleton extends StatelessWidget {
  const FolioFamilySeatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(3, (index) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                FolioSkeletonBlock(width: 36, height: 36, borderRadius: 999),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FolioSkeletonBlock(width: 140, height: 12),
                      SizedBox(height: 6),
                      FolioSkeletonBlock(width: 80, height: 9),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                FolioSkeletonBlock(width: 24, height: 24, borderRadius: 999),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Esqueleto animado para listas genéricas (por ejemplo, copias de seguridad).
class FolioSkeletonList extends StatelessWidget {
  const FolioSkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FolioSkeletonBlock(width: 180, height: 14),
                      SizedBox(height: 8),
                      FolioSkeletonBlock(width: 110, height: 10),
                    ],
                  ),
                ),
                FolioSkeletonBlock(width: 24, height: 24, borderRadius: 6),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Esqueleto animado para las filas de una tabla de precios.
class FolioPricingTableSkeleton extends StatelessWidget {
  const FolioPricingTableSkeleton({super.key, this.rowCount = 6});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(rowCount, (index) {
          final scheme = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FolioSkeletonBlock(width: 130, height: 12),
                        SizedBox(height: 6),
                        FolioSkeletonBlock(width: 90, height: 8),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  FolioSkeletonBlock(width: 45, height: 16),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
