import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../ui_tokens.dart';
import 'folio_dialog.dart';
import 'folio_skeletons.dart';

/// Modal dialog that loads Stripe Checkout or Billing Portal in an in-app WebView.
/// On success/cancel navigation patterns, it automatically pops and returns [true] or [false].
class FolioInAppCheckoutDialog extends StatefulWidget {
  const FolioInAppCheckoutDialog({
    super.key,
    required this.url,
    required this.scheme,
  });

  final String url;
  final ColorScheme scheme;

  /// Helper to check if the current platform runtime supports in-app WebViews.
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  State<FolioInAppCheckoutDialog> createState() => _FolioInAppCheckoutDialogState();
}

class _FolioInAppCheckoutDialogState extends State<FolioInAppCheckoutDialog> {
  WebViewController? _mobile;
  WebviewController? _windows;
  StreamSubscription<String>? _windowsUrlSub;

  bool _loading = true;
  String? _error;
  bool _winReady = false;

  bool get _useWindows => !kIsWeb && Platform.isWindows;
  bool get _useMobileWebView => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      _error = 'Invalid URL';
      _loading = false;
      return;
    }

    if (_useWindows) {
      _windows = WebviewController();
      unawaited(_initWindows(uri.toString()));
    } else if (_useMobileWebView) {
      _mobile = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) setState(() => _loading = true);
              _checkUrl(url);
            },
            onPageFinished: (String url) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (WebResourceError error) {
              AppLogger.warn(
                'Mobile WebView resource error',
                tag: 'checkout',
                context: {'description': error.description},
              );
            },
            onUrlChange: (UrlChange change) {
              if (change.url != null) {
                _checkUrl(change.url!);
              }
            },
          ),
        )
        ..loadRequest(uri);
      _loading = false; // Mobile controller initializes synchronously
    }
  }

  Future<void> _initWindows(String url) async {
    final c = _windows;
    if (c == null) return;
    try {
      await c.initialize();
      await c.setBackgroundColor(Colors.transparent);
      await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      _windowsUrlSub = c.url.listen((currentUrl) {
        _checkUrl(currentUrl);
      });

      unawaited(c.loadingState.forEach((state) {
        if (mounted) {
          setState(() {
            _loading = state == LoadingState.loading;
          });
        }
      }));

      await c.loadUrl(url);
      if (mounted) {
        setState(() {
          _winReady = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _checkUrl(String url) {
    AppLogger.debug(
      'Navigated URL',
      tag: 'checkout',
      context: {'url': url},
    );
    final cleanUrl = url.trim().toLowerCase();

    // 1. Success detection: Stripe success redirects containing session_id
    // or exact return hits back to success path.
    if (cleanUrl.contains('session_id=') ||
        cleanUrl.endsWith('/success') ||
        cleanUrl.contains('/success?') ||
        cleanUrl.contains('success=true')) {
      AppLogger.info(
        'Intercepted success URL',
        tag: 'checkout',
        context: {'url': url},
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    // 2. Cancel detection: Stripe cancel redirects containing cancel keyword.
    if ((cleanUrl.contains('cancel') || cleanUrl.endsWith('/cancel')) &&
        !cleanUrl.contains('billing.stripe.com')) {
      AppLogger.info(
        'Intercepted cancel URL',
        tag: 'checkout',
        context: {'url': url},
      );
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    // 3. Base domain redirect detection (Stripe back arrow / Billing Portal exit).
    // If the URL has navigated away from Stripe back to our configured app or company domains,
    // we consider the portal/checkout flow to be exited.
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasAuthority) {
      final host = uri.host.toLowerCase();
      if (host == 'minealexgames.com' ||
          host == 'www.minealexgames.com' ||
          host == 'folio.app' ||
          host == 'www.folio.app' ||
          host == 'localhost') {
        AppLogger.info(
          'Intercepted return host',
          tag: 'checkout',
          context: {'host': host, 'url': url},
        );
        if (mounted) {
          Navigator.of(context).pop(false);
        }
        return;
      }
    }
  }

  Future<bool> _showExitConfirmation() async {
    final confirm = await FolioDialog.confirm(
      context,
      title: Text(_t('¿Cancelar Pago?', 'Cancel Payment?')),
      content: Text(_t(
        'Se interrumpirá la transacción en curso. ¿Estás seguro de que deseas salir?',
        'The ongoing transaction will be interrupted. Are you sure you want to exit?',
      )),
      cancelLabel: _t('No, continuar', 'No, continue'),
      confirmLabel: _t('Sí, salir', 'Yes, exit'),
      destructive: true,
    );
    return confirm ?? false;
  }

  @override
  void dispose() {
    unawaited(_windowsUrlSub?.cancel());
    final w = _windows;
    if (w != null) {
      unawaited(w.dispose());
    }
    super.dispose();
  }

  String _t(String es, String en) {
    try {
      final code = Localizations.localeOf(context).languageCode;
      return code == 'es' ? es : en;
    } catch (_) {
      return en;
    }
  }

  Widget _buildBrandChip(String label) {
    final scheme = widget.scheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        color: scheme.surface,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
          fontSize: 9.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = widget.scheme;

    final media = MediaQuery.of(context);
    final wide = media.size.width >= 900;

    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                _t('Ocurrió un error al cargar la pasarela de pago.', 'An error occurred while loading the checkout window.'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.settingsClose),
              ),
            ],
          ),
        ),
      );
    } else {
      Widget webViewWidget = const SizedBox.shrink();
      if (_useWindows) {
        final c = _windows;
        if (c != null && _winReady) {
          webViewWidget = Webview(
            c,
            permissionRequested: (controller, url, kind) async => WebviewPermissionDecision.allow,
          );
        } else {
          webViewWidget = const FolioLoadingIndicator(centered: true);
        }
      } else if (_useMobileWebView && _mobile != null) {
        webViewWidget = WebViewWidget(controller: _mobile!);
      }

      body = Stack(
        children: [
          Positioned.fill(child: webViewWidget),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: scheme.surface.withValues(alpha: 0.92),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingLockIcon(scheme: scheme),
                        const SizedBox(height: 24),
                        Text(
                          _t('Conectando con pasarela segura...', 'Connecting to secure checkout...'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t('ENCRIPTACIÓN SSL DE 256 BITS', '256-BIT SSL ENCRYPTION'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              _t(
                                'Folio no almacena los datos de tu tarjeta.',
                                'Folio does not store your card details.',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildBrandChip('VISA'),
                            _buildBrandChip('Mastercard'),
                            _buildBrandChip('AMEX'),
                            _buildBrandChip('Stripe'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final dialogContent = Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.security_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _t('Pago Seguro', 'Secure Payment'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final confirm = await _showExitConfirmation();
              if (confirm && mounted && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
            tooltip: l10n.settingsClose,
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      body: body,
    );

    final wrappedContent = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showExitConfirmation();
        if (confirm && context.mounted) Navigator.of(context).pop();
      },
      child: wide
          ? Dialog(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FolioRadius.xl),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: SizedBox(
                width: 960,
                height: 750,
                child: dialogContent,
              ),
            )
          : Dialog.fullscreen(
              child: dialogContent,
            ),
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: wrappedContent,
    );
  }
}

class _PulsingLockIcon extends StatefulWidget {
  const _PulsingLockIcon({required this.scheme});
  final ColorScheme scheme;

  @override
  State<_PulsingLockIcon> createState() => _PulsingLockIconState();
}

class _PulsingLockIconState extends State<_PulsingLockIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 24.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.scheme.primaryContainer.withValues(alpha: 0.25),
            boxShadow: [
              BoxShadow(
                color: widget.scheme.primary.withValues(alpha: 0.15),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 4,
              ),
            ],
            border: Border.all(
              color: widget.scheme.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.lock_outline_rounded,
              size: 38,
              color: widget.scheme.primary,
            ),
          ),
        );
      },
    );
  }
}
