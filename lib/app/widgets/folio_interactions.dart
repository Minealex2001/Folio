import 'package:flutter/material.dart';
import '../ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

/// Widget helper para micro-interactions: scale + opacity en clics
class InteractiveContainer extends StatefulWidget {
  const InteractiveContainer({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 200),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;

  @override
  State<InteractiveContainer> createState() => _InteractiveContainerState();
}

class _InteractiveContainerState extends State<InteractiveContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _controller.forward();
  }

  void _onPointerUp(PointerUpEvent event) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

/// Animated shimmer loading effect
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

/// Smooth hover effect con elevation y color
class HoverElevationContainer extends StatefulWidget {
  const HoverElevationContainer({
    super.key,
    required this.child,
    this.onTap,
    this.elevation = 4.0,
    this.baseElevation = 0.0,
    this.hoverColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final double baseElevation;
  final Color? hoverColor;

  @override
  State<HoverElevationContainer> createState() =>
      _HoverElevationContainerState();
}

class _HoverElevationContainerState extends State<HoverElevationContainer> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedPhysicalModel(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        elevation: _isHovering ? widget.elevation : widget.baseElevation,
        shadowColor: scheme.shadow.withValues(
          alpha: _isHovering ? FolioAlpha.thumbHover : FolioAlpha.faint,
        ),
        color: Colors.transparent,
        child: GestureDetector(onTap: widget.onTap, child: widget.child),
      ),
    );
  }
}

/// Animated empty state con fade in
class FadingEmptyState extends StatefulWidget {
  const FadingEmptyState({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Duration duration;

  @override
  State<FadingEmptyState> createState() => _FadingEmptyStateState();
}

class _FadingEmptyStateState extends State<FadingEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

/// Slide + Fade transition para nuevos elementos
class SlideInTransition extends StatefulWidget {
  const SlideInTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.05),
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<SlideInTransition> createState() => _SlideInTransitionState();
}

class _SlideInTransitionState extends State<SlideInTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// Stagger animation para listas
class StaggeredListTransition extends StatelessWidget {
  const StaggeredListTransition({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration duration;
  final Duration staggerDelay;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return SlideInTransition(
          duration: duration,
          offset: const Offset(0, 0.04),
          curve: Curves.easeOut,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// Button con ripple y scale effect integrados
class FolioButton extends StatefulWidget {
  const FolioButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = FolioButtonVariant.filled,
    this.size = FolioButtonSize.normal,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final String label;
  final FolioButtonVariant variant;
  final FolioButtonSize size;
  final IconData? icon;
  final bool isLoading;

  @override
  State<FolioButton> createState() => _FolioButtonState();
}

enum FolioButtonVariant { filled, tonal, outlined }

enum FolioButtonSize { small, normal, large }

class _FolioButtonState extends State<FolioButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final buttonStyle = _buildButtonStyle(scheme, theme);

    final button = widget.variant == FolioButtonVariant.filled
        ? FilledButton(
            style: buttonStyle,
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: _buildLabel(),
          )
        : widget.variant == FolioButtonVariant.tonal
        ? FilledButton.tonal(
            style: buttonStyle,
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: _buildLabel(),
          )
        : OutlinedButton(
            style: buttonStyle,
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: _buildLabel(),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: button,
      ),
    );
  }

  Widget _buildLabel() {
    if (widget.isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
          Text(widget.label),
        ],
      );
    }
    return Text(widget.label);
  }

  ButtonStyle _buildButtonStyle(ColorScheme scheme, ThemeData theme) {
    final padding = switch (widget.size) {
      FolioButtonSize.small => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      FolioButtonSize.normal => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      FolioButtonSize.large => const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
    };

    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.xl),
        ),
      ),
    );
  }
}

/// Skeleton loading pattern para listas, grillas, etc.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.isLoading = true,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool isLoading;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(
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
    if (!widget.isLoading) {
      return widget.itemBuilder(context, 0);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, _) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(-1 - _shimmerAnimation.value, 0),
                    end: Alignment(1 - _shimmerAnimation.value, 0),
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcOver,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(FolioRadius.md),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Animated error state con retry button
class AnimatedErrorState extends StatefulWidget {
  const AnimatedErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  State<AnimatedErrorState> createState() => _AnimatedErrorStateState();
}

class _AnimatedErrorStateState extends State<AnimatedErrorState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_controller),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(FolioSpace.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(FolioRadius.xl),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 40,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: FolioSpace.lg),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: FolioSpace.md),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: FolioSpace.lg),
                  FilledButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Form input con validación animada y feedback visual
class AnimatedFormInput extends StatefulWidget {
  const AnimatedFormInput({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final IconData? prefixIcon;

  @override
  State<AnimatedFormInput> createState() => _AnimatedFormInputState();
}

class _AnimatedFormInputState extends State<AnimatedFormInput> {
  String? _error;
  bool _isFocused = false;
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validateOnChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateOnChange);
    super.dispose();
  }

  void _validateOnChange() {
    setState(() {
      _hasContent = widget.controller.text.isNotEmpty;
      _error = widget.validator(widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = _error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          child: Focus(
            onFocusChange: (focused) {
              setState(() => _isFocused = focused);
            },
            child: TextField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon)
                    : null,
                suffixIcon: _hasContent && !hasError
                    ? Icon(Icons.check_circle, color: scheme.primary)
                    : hasError
                    ? Icon(Icons.error, color: scheme.error)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                  borderSide: BorderSide(color: scheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                  borderSide: BorderSide(
                    color: hasError ? scheme.error : scheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                  borderSide: BorderSide(color: scheme.error),
                ),
                filled: true,
                fillColor: _isFocused
                    ? scheme.primaryContainer.withValues(alpha: 0.1)
                    : scheme.surfaceContainer,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: FolioSpace.sm),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(
                  parent: AlwaysStoppedAnimation(1.0),
                  curve: Curves.easeOut,
                ),
              ),
              child: Text(
                _error!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog con backdrop animation
class AnimatedDialogWrapper extends StatefulWidget {
  const AnimatedDialogWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AnimatedDialogWrapper> createState() => _AnimatedDialogWrapperState();
}

class _AnimatedDialogWrapperState extends State<AnimatedDialogWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Search input con sugerencias y estados
class AnimatedSearchInput extends StatefulWidget {
  const AnimatedSearchInput({
    super.key,
    required this.onSearch,
    this.suggestions = const [],
    this.onSuggestionTap,
    this.placeholder = 'Search...',
  });

  final ValueChanged<String> onSearch;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;
  final String placeholder;

  @override
  State<AnimatedSearchInput> createState() => _AnimatedSearchInputState();
}

class _AnimatedSearchInputState extends State<AnimatedSearchInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  bool _showSuggestions = false;
  late final AnimationController _suggestionController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _suggestionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  void _toggleSuggestions(bool show) {
    if (show) {
      _suggestionController.forward();
    } else {
      _suggestionController.reverse();
    }
    setState(() => _showSuggestions = show);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filteredSuggestions = _controller.text.isEmpty
        ? widget.suggestions
        : widget.suggestions
              .where(
                (s) => s.toLowerCase().contains(_controller.text.toLowerCase()),
              )
              .toList();

    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: (value) {
            widget.onSearch(value);
            if (value.isNotEmpty && widget.suggestions.isNotEmpty) {
              _toggleSuggestions(true);
            } else {
              _toggleSuggestions(false);
            }
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: widget.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.md,
              vertical: FolioSpace.sm,
            ),
          ),
        ),
        if (_showSuggestions && filteredSuggestions.isNotEmpty)
          SizeTransition(
            sizeFactor: _suggestionController,
            child: Container(
              margin: const EdgeInsets.only(top: FolioSpace.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(FolioRadius.md),
                border: Border.all(color: scheme.outline),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = filteredSuggestions[index];
                  return ListTile(
                    title: Text(suggestion),
                    onTap: () {
                      _controller.text = suggestion;
                      widget.onSuggestionTap?.call(suggestion);
                      _toggleSuggestions(false);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
