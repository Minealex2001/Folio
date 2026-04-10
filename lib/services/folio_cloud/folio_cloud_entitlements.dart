import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'folio_cloud_billing.dart';
import 'folio_web_portal_api.dart';

/// En Windows/Linux el plugin usa un canal Pigeon que a menudo rompe con
/// `documentReferenceSnapshot` (stream). Misma SDK [cloud_firestore], pero solo
/// `.get()` es fiable; el tiempo real se aproxima con sondeo.
bool get _folioFirestoreUseGetPolling {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// En Windows (y a veces desktop) Firestore falla justo al [resumed] con el canal nativo aún frío.
bool _isTransientFirestoreHostChannelError(Object e) {
  if (e is FirebaseException) {
    final msg = '${e.message}'.toLowerCase();
    final code = e.code.toLowerCase();
    if (msg.contains('unable to establish connection') ||
        msg.contains('connection on channel') ||
        msg.contains('establish connection')) {
      return true;
    }
    // p. ej. [cloud_firestore/unknown] con mensaje genérico
    if (code == 'unknown' &&
        (msg.contains('channel') || msg.contains('connection'))) {
      return true;
    }
  }
  final s = e.toString().toLowerCase();
  return s.contains('unable to establish connection') ||
      s.contains('connection on channel') ||
      s.contains('establish connection on channel');
}

bool _folioBool(dynamic v) {
  if (v == true) return true;
  if (v == false) return false;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  for (final e in raw.entries) {
    out['${e.key}'] = e.value;
  }
  return out;
}

/// `true` si [data] parece caché vacía/antigua: sin `folioCloud.active` ni `subscriptionStatus`.
/// Así no ignoramos una baja real de suscripción cuando Stripe ya escribió `active: false`.
bool _folioCloudUserDocCacheLooksIncomplete(Map<String, dynamic>? data) {
  if (data == null) return true;
  final raw = data['folioCloud'];
  if (raw == null) return true;
  if (raw is! Map) return true;
  final m = _asStringKeyedMap(raw);
  if (m.containsKey('active')) return false;
  if (m.containsKey('subscriptionStatus')) return false;
  return true;
}

/// Gotas de tinta (servidor: Firestore `users/{uid}.ink.*`).
class FolioInkSnapshot {
  const FolioInkSnapshot({
    required this.monthlyBalance,
    required this.purchasedBalance,
    this.monthlyPeriodKey,
  });

  final int monthlyBalance;
  final int purchasedBalance;
  final String? monthlyPeriodKey;

  int get totalInk => monthlyBalance + purchasedBalance;

  static const FolioInkSnapshot empty = FolioInkSnapshot(
    monthlyBalance: 0,
    purchasedBalance: 0,
    monthlyPeriodKey: null,
  );

  /// Tope razonable solo para la recarga mensual (suscripción); evita que un bug de
  /// webhook distorsione la UI. La tinta comprada no tiene límite superior en cliente.
  /// Los negativos se muestran como 0 por campo; el servidor acota a ≥ 0 al cobrar.
  static const int _sanityMaxMonthlyInkField = 100000;

  static int _inkMonthlyFromDoc(num? v) {
    if (v == null) return 0;
    final n = v.toInt();
    if (n <= 0) return 0;
    if (n > _sanityMaxMonthlyInkField) {
      debugPrint(
        'FolioInkSnapshot: monthlyBalance=$n parece corrupto; mostrando como '
        '$_sanityMaxMonthlyInkField.',
      );
      return _sanityMaxMonthlyInkField;
    }
    return n;
  }

  static int _inkPurchasedFromDoc(num? v) {
    if (v == null) return 0;
    final n = v.toInt();
    if (n < 0) return 0;
    return n;
  }

  static FolioInkSnapshot fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return FolioInkSnapshot.empty;
    final raw = data['ink'];
    if (raw is Map) {
      final m = _asStringKeyedMap(raw);
      final monthlyFromMap = _inkMonthlyFromDoc(m['monthlyBalance'] as num?);
      final purchasedFromMap = _inkPurchasedFromDoc(
        m['purchasedBalance'] as num?,
      );
      final dottedMonthly = _inkMonthlyFromDoc(
        data['ink.monthlyBalance'] as num?,
      );
      final dottedPurchased = _inkPurchasedFromDoc(
        data['ink.purchasedBalance'] as num?,
      );

      // Si conviven ambas formas (mapa `ink` + claves literales con punto),
      // usa la más alta para evitar que el UI se quede "viejo" tras una compra.
      final monthly = monthlyFromMap >= dottedMonthly ? monthlyFromMap : dottedMonthly;
      final purchased =
          purchasedFromMap >= dottedPurchased ? purchasedFromMap : dottedPurchased;

      return FolioInkSnapshot(
        monthlyBalance: monthly,
        purchasedBalance: purchased,
        monthlyPeriodKey: m['monthlyPeriodKey']?.toString() ??
            data['ink.monthlyPeriodKey']?.toString(),
      );
    }
    // Copia plana por si el doc tuviera claves literales con punto (poco habitual).
    final dottedMonthly = data['ink.monthlyBalance'];
    final dottedPurchased = data['ink.purchasedBalance'];
    final dottedKey = data['ink.monthlyPeriodKey'];
    if (dottedMonthly != null ||
        dottedPurchased != null ||
        dottedKey != null) {
      return FolioInkSnapshot(
        monthlyBalance: _inkMonthlyFromDoc(dottedMonthly as num?),
        purchasedBalance: _inkPurchasedFromDoc(dottedPurchased as num?),
        monthlyPeriodKey: dottedKey?.toString(),
      );
    }
    return FolioInkSnapshot.empty;
  }
}

/// Server-written subscription flags under `users/{uid}` (Stripe webhooks).
class FolioCloudSnapshot {
  const FolioCloudSnapshot({
    required this.active,
    this.subscriptionStatus,
    required this.backup,
    required this.cloudAi,
    required this.publishWeb,
    FolioInkSnapshot? ink,
  }) : _ink = ink;

  final bool active;
  final String? subscriptionStatus;
  final bool backup;
  final bool cloudAi;
  final bool publishWeb;
  final FolioInkSnapshot? _ink;

  /// Tras hot reload puede existir un snapshot antiguo sin tinta; nunca devolver null.
  FolioInkSnapshot get ink => _ink ?? FolioInkSnapshot.empty;

  /// Alineado con reglas de Storage (`folioCloud.active` + feature).
  bool get canUseCloudBackup => active && backup;

  /// Publicación web (Storage `published/` + Firestore `publishedPages`).
  bool get canPublishToWeb => active && publishWeb;

  /// Callable `folioCloudAiComplete`: suscripción con IA en la nube, o tinta comprada (sin suscripción).
  bool get canUseCloudAi =>
      (active && cloudAi) || ink.purchasedBalance > 0;

  static const FolioCloudSnapshot empty = FolioCloudSnapshot(
    active: false,
    subscriptionStatus: null,
    backup: false,
    cloudAi: false,
    publishWeb: false,
  );

  static FolioCloudSnapshot fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return FolioCloudSnapshot.empty;
    final raw = data['folioCloud'];
    if (raw is! Map) {
      return FolioCloudSnapshot(
        active: false,
        subscriptionStatus: null,
        backup: false,
        cloudAi: false,
        publishWeb: false,
        ink: FolioInkSnapshot.fromUserDoc(data),
      );
    }
    final m = _asStringKeyedMap(raw);
    final features = _asStringKeyedMap(m['features']);
    bool f(String k) => _folioBool(features[k]);
    var active = _folioBool(m['active']);
    final statusNorm =
        m['subscriptionStatus']?.toString().trim().toLowerCase();
    // Si `active` falta o quedó desincronizado pero el estado Stripe es de alta.
    if (!active &&
        (statusNorm == 'active' ||
            statusNorm == 'trialing' ||
            statusNorm == 'past_due')) {
      active = true;
    }
    return FolioCloudSnapshot(
      active: active,
      subscriptionStatus: m['subscriptionStatus']?.toString(),
      backup: f('backup'),
      cloudAi: f('cloudAi'),
      publishWeb: f('publishWeb'),
      ink: FolioInkSnapshot.fromUserDoc(data),
    );
  }
}

/// Listens to Auth + Firestore `users/{uid}` for Folio Cloud entitlements.
class FolioCloudEntitlementsController extends ChangeNotifier {
  FolioCloudEntitlementsController() {
    if (Firebase.apps.isEmpty) return;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  Timer? _userDocPollTimer;

  FolioCloudSnapshot snapshot = FolioCloudSnapshot.empty;

  /// UID al que corresponde el último snapshot (evita mostrar datos de otra cuenta).
  String? _subscribedUid;

  /// Resultado del último `get(server)` en esta sesión; la caché del stream a veces lo contradice.
  FolioCloudSnapshot? _serverFetchTruth;

  /// Última sync forzada con Stripe (evita spam al reanudar la app).
  DateTime? _lastStripeSync;

  /// Tras abrir Checkout: en el próximo [handleAppResumed] se llama a Stripe una vez por si el webhook fue lento.
  bool _pendingStripeSyncOnResume = false;

  String Function()? _resolveWebPortalBaseUrl;

  /// Espejo de `/api/folio/entitlement` (cuenta web). Vacío si no hay URL o sesión.
  FolioWebEntitlementSnapshot? webPortalEntitlement;

  /// Último fallo al refrescar el espejo web (p. ej. red o 503).
  FolioWebPortalException? webPortalRefreshError;

  bool get isAvailable => Firebase.apps.isNotEmpty;

  /// Desde [FolioApp]: URL efectiva (prefs + `FOLIO_WEB_PORTAL_BASE_URL`).
  void setWebPortalBaseUrlResolver(String Function() resolve) {
    _resolveWebPortalBaseUrl = resolve;
  }

  String _effectiveWebPortalBaseUrl() {
    final f = _resolveWebPortalBaseUrl;
    if (f == null) return '';
    return f().trim();
  }

  void _clearWebPortalMirror() {
    webPortalEntitlement = null;
    webPortalRefreshError = null;
  }

  /// Fuerza ID token y consulta el portal Next.js. No altera Firestore.
  Future<void> refreshWebPortalEntitlement() async {
    if (!isAvailable) {
      _clearWebPortalMirror();
      notifyListeners();
      return;
    }
    final base = _effectiveWebPortalBaseUrl();
    if (base.isEmpty) {
      _clearWebPortalMirror();
      notifyListeners();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _clearWebPortalMirror();
      notifyListeners();
      return;
    }
    final uid = user.uid;
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        webPortalEntitlement = null;
        webPortalRefreshError = FolioWebPortalException(
          FolioWebPortalErrorKind.unauthorized,
          detail: 'missing_id_token',
        );
        notifyListeners();
        return;
      }
      final snap = await fetchFolioWebEntitlement(
        portalBaseUrl: base,
        idToken: token,
      );
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      webPortalEntitlement = snap;
      webPortalRefreshError = null;
      notifyListeners();
    } on FolioWebPortalException catch (e) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      webPortalEntitlement = null;
      webPortalRefreshError = e;
      notifyListeners();
      debugPrint('FolioCloudEntitlements: web portal: $e');
    } catch (e, st) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      webPortalEntitlement = null;
      webPortalRefreshError = FolioWebPortalException(
        FolioWebPortalErrorKind.network,
        detail: '$e',
      );
      notifyListeners();
      debugPrint('FolioCloudEntitlements: web portal: $e\n$st');
    }
  }

  /// Marcar que el usuario abrió el pago en el navegador; al volver a la app se sincroniza con Stripe una vez.
  void scheduleStripeSyncOnNextResume() {
    _pendingStripeSyncOnResume = true;
  }

  static const int _firestoreServerFetchMaxAttempts = 7;

  Future<Map<String, dynamic>?> _fetchUserDocFromServerWithRetries(
    String uid, {
    Duration leadingDelay = Duration.zero,
  }) async {
    if (leadingDelay > Duration.zero) {
      await Future<void>.delayed(leadingDelay);
    }
    for (var attempt = 0; attempt < _firestoreServerFetchMaxAttempts; attempt++) {
      if (attempt > 0) {
        // Backoff: 600ms, 1.1s, 1.6s… — en Windows el canal a veces tarda varios segundos.
        await Future<void>.delayed(
          Duration(milliseconds: 350 + 550 * attempt),
        );
      }
      try {
        final serverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
        return serverDoc.data();
      } catch (e, st) {
        final transient = _isTransientFirestoreHostChannelError(e);
        final canRetry =
            attempt < _firestoreServerFetchMaxAttempts - 1 && transient;
        if (canRetry) {
          continue;
        }
        if (transient) {
          try {
            final cached = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
            debugPrint(
              'FolioCloudEntitlements: server fetch falló; usando última caché local.',
            );
            return cached.data();
          } catch (_) {/* ignore */}
        }
        debugPrint(
          'FolioCloudEntitlements: fetch server users/$uid: $e',
        );
        if (!transient) {
          debugPrint('$st');
        }
        return null;
      }
    }
    return null;
  }

  /// `get(Source.server)` de `users/{uid}` sin re-suscribir al stream (p. ej. al volver de segundo plano).
  Future<void> refreshUserDocFromServer({
    Duration leadingDelay = Duration.zero,
  }) async {
    if (!isAvailable) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final serverData = await _fetchUserDocFromServerWithRetries(
      uid,
      leadingDelay: leadingDelay,
    );
    if (serverData == null ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    final parsed = FolioCloudSnapshot.fromUserDoc(serverData);
    snapshot = parsed;
    _serverFetchTruth = parsed;
    notifyListeners();
  }

  /// Tras `folioCloudAiComplete`: aplica saldos devueltos por el servidor sin esperar al stream.
  void applyInkBalancesFromCloudAi({
    required int monthlyBalance,
    required int purchasedBalance,
  }) {
    final prev = snapshot;
    final periodKey = prev.ink.monthlyPeriodKey;
    final ink = FolioInkSnapshot(
      monthlyBalance: monthlyBalance,
      purchasedBalance: purchasedBalance,
      monthlyPeriodKey: periodKey,
    );
    snapshot = FolioCloudSnapshot(
      active: prev.active,
      subscriptionStatus: prev.subscriptionStatus,
      backup: prev.backup,
      cloudAi: prev.cloudAi,
      publishWeb: prev.publishWeb,
      ink: ink,
    );
    notifyListeners();
  }

  /// Al reactivar la app: datos frescos de Firestore y, si aplica, una sync con Stripe tras checkout.
  Future<void> handleAppResumed() async {
    if (!isAvailable) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Windows: el motor Flutter + Pigeon a menudo necesitan >1s tras resumed.
    await refreshUserDocFromServer(
      leadingDelay: const Duration(milliseconds: 1200),
    );
    if (!_pendingStripeSyncOnResume) return;
    _pendingStripeSyncOnResume = false;
    _lastStripeSync = null;
    try {
      await syncFolioCloudSubscriptionFromStripe();
    } catch (e) {
      debugPrint('FolioCloudEntitlements: post-checkout Stripe sync: $e');
    }
    await refreshUserDocFromServer(
      leadingDelay: const Duration(milliseconds: 400),
    );
    unawaited(refreshWebPortalEntitlement());
  }

  void _cancelUserDocPoll() {
    _userDocPollTimer?.cancel();
    _userDocPollTimer = null;
  }

  void _onUser(User? user) {
    unawaited(_docSub?.cancel());
    _docSub = null;
    _cancelUserDocPoll();
    if (user == null) {
      _subscribedUid = null;
      _serverFetchTruth = null;
      _pendingStripeSyncOnResume = false;
      snapshot = FolioCloudSnapshot.empty;
      _clearWebPortalMirror();
      notifyListeners();
      return;
    }
    final accountChanged = _subscribedUid != user.uid;
    _subscribedUid = user.uid;
    if (accountChanged) {
      _serverFetchTruth = null;
      _pendingStripeSyncOnResume = false;
      snapshot = FolioCloudSnapshot.empty;
      _clearWebPortalMirror();
      notifyListeners();
    }
    unawaited(_subscribeUserDoc(user.uid));
    unawaited(refreshWebPortalEntitlement());
  }

  /// Refresca `users/{uid}` desde el servidor y luego escucha cambios (evita caché local obsoleta).
  Future<void> _subscribeUserDoc(String uid) async {
    Map<String, dynamic>? serverData =
        await _fetchUserDocFromServerWithRetries(uid);
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (serverData != null) {
      final parsed = FolioCloudSnapshot.fromUserDoc(serverData);
      snapshot = parsed;
      _serverFetchTruth = parsed;
      notifyListeners();
    } else {
      _serverFetchTruth = null;
    }

    if (FirebaseAuth.instance.currentUser?.uid != uid) return;

    unawaited(_maybeSyncStripeAfterServerRead(uid, serverData));

    if (_folioFirestoreUseGetPolling) {
      _userDocPollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        unawaited(refreshUserDocFromServer());
      });
      return;
    }

    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            if (FirebaseAuth.instance.currentUser?.uid != uid) return;
            final next = FolioCloudSnapshot.fromUserDoc(doc.data());
            if (doc.metadata.isFromCache && _serverFetchTruth != null) {
              final s = _serverFetchTruth!;
              if (s.active &&
                  !next.active &&
                  _folioCloudUserDocCacheLooksIncomplete(doc.data())) {
                return;
              }
            }
            snapshot = next;
            notifyListeners();
            if (!doc.metadata.isFromCache) {
              _serverFetchTruth = next;
            }
          },
          onError: (Object e, StackTrace st) {
            debugPrint('FolioCloudEntitlements: Firestore snapshots: $e');
            debugPrint('$st');
          },
        );
  }

  /// Si el documento en servidor no refleja suscripción, un sync con Stripe actualiza Firestore.
  Future<void> _maybeSyncStripeAfterServerRead(
    String uid,
    Map<String, dynamic>? serverData,
  ) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (snapshot.active) return;
    final cid = serverData?['stripeCustomerId'];
    if (cid is! String || cid.trim().isEmpty) return;
    final now = DateTime.now();
    if (_lastStripeSync != null &&
        now.difference(_lastStripeSync!) < const Duration(minutes: 2)) {
      return;
    }
    _lastStripeSync = now;
    try {
      await syncFolioCloudSubscriptionFromStripe();
    } catch (e) {
      debugPrint('FolioCloudEntitlements: sync Stripe omitido o fallido: $e');
    }
  }

  /// Llamar tras volver del checkout o si la UI sigue desactualizada.
  Future<void> refreshSubscriptionFromStripe() async {
    if (!isAvailable) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _lastStripeSync = null;
    try {
      await syncFolioCloudSubscriptionFromStripe();
    } catch (e) {
      debugPrint('FolioCloudEntitlements: refreshSubscriptionFromStripe: $e');
      rethrow;
    }
    final data = await _fetchUserDocFromServerWithRetries(uid);
    if (data != null && FirebaseAuth.instance.currentUser?.uid == uid) {
      final parsed = FolioCloudSnapshot.fromUserDoc(data);
      snapshot = parsed;
      _serverFetchTruth = parsed;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelUserDocPoll();
    unawaited(_authSub?.cancel());
    unawaited(_docSub?.cancel());
    super.dispose();
  }
}
