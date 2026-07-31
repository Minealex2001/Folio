import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/folio_distribution.dart';
import '../app_logger.dart';
import '../cloud_account/cloud_account_controller.dart';
import 'folio_cloud_billing.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_identity.dart';
import 'folio_microsoft_store_channel.dart';
import 'folio_microsoft_store_sync.dart';
import 'folio_spring_account_me.dart';
import 'folio_web_portal_api.dart';

import 'folio_cloud_exception.dart';

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
      AppLogger.warn(
        'monthlyBalance parece corrupto; mostrando valor acotado',
        tag: 'entitlements',
        context: {
          'monthlyBalance': n,
          'cappedTo': _sanityMaxMonthlyInkField,
        },
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
    required this.realtimeCollab,
    this.folioStaff = false,
    this.plan,
    this.backupQuotaBytes = 0,
    this.backupUsedBytes = 0,
    this.backupPurchasedBytes = 0,
    this.backupSubscriptionExtraBytes = 0,
    this.isFamily = false,
    this.isStudent = false,
    this.isStudentVerified = false,
    this.studentVerifiedUntil,
    this.studentEmail,
    this.familyOwnerUid,
    this.familySeats = 0,
    this.accountDeletionScheduledFor,
    FolioInkSnapshot? ink,
  }) : _ink = ink;

  /// Staff/admin (Firestore `users/{uid}.folioStaff`): nube ilimitada sin plan.
  final bool folioStaff;

  final bool active;
  final String? subscriptionStatus;

  /// `free` | `cloud` (Firestore `folioCloud.plan`); null en docs legacy.
  final String? plan;

  final bool backup;
  final bool cloudAi;
  final bool publishWeb;
  final bool realtimeCollab;

  final bool isFamily;
  final bool isStudent;
  final bool isStudentVerified;
  /// End of the 4-year student verification window (UTC/local from server ISO).
  final DateTime? studentVerifiedUntil;
  final String? studentEmail;
  final String? familyOwnerUid;
  final int familySeats;

  /// Days left until [studentVerifiedUntil]; null if not verified / no date.
  int? get studentVerificationDaysRemaining {
    final until = studentVerifiedUntil;
    if (!isStudentVerified || until == null) return null;
    final days = until.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  bool get studentVerificationExpiringSoon {
    final days = studentVerificationDaysRemaining;
    return days != null && days <= 30;
  }

  /// Si no es null, la cuenta tiene borrado programado (gracia de 30 días).
  final DateTime? accountDeletionScheduledFor;

  bool get hasPendingAccountDeletion => accountDeletionScheduledFor != null;

  /// Cuota de copias en la nube (bytes); `folioBackup.quotaBytes` en Firestore.
  final int backupQuotaBytes;

  /// Uso contabilizado (bytes); `folioBackup.usedBytes`.
  final int backupUsedBytes;

  /// Compras únicas / consumibles (bytes); `folioBackup.purchasedBytes`.
  final int backupPurchasedBytes;

  /// Ampliación por suscripciones Stripe a librerías de copia; `folioBackup.stripeSubscriptionExtraBytes`.
  final int backupSubscriptionExtraBytes;

  final FolioInkSnapshot? _ink;

  /// Espacio extra total (compras únicas + suscripciones de ampliación).
  int get backupExtraBytesTotal =>
      backupPurchasedBytes + backupSubscriptionExtraBytes;

  /// Tras hot reload puede existir un snapshot antiguo sin tinta; nunca devolver null.
  FolioInkSnapshot get ink => _ink ?? FolioInkSnapshot.empty;

  /// Plan free (500 MiB, backup+sync, 0 tinta).
  bool get isFreePlan =>
      plan == 'free' ||
      (active &&
          backup &&
          !cloudAi &&
          !publishWeb &&
          (subscriptionStatus?.toLowerCase() == 'free'));

  /// Suscripción de pago (no free tier).
  bool get isPaidPlan =>
      folioStaff || (active && !isFreePlan && (cloudAi || publishWeb || plan == 'cloud'));

  /// Alineado con reglas de Storage (`folioCloud.active` + feature o `folioStaff`).
  bool get canUseCloudBackup => folioStaff || (active && backup);

  /// Publicación web (Storage `published/` + Firestore `publishedPages`).
  bool get canPublishToWeb => folioStaff || (active && publishWeb);

  /// Colaboración en vivo (Firestore `collabRooms`).
  bool get canRealtimeCollab => folioStaff || (active && realtimeCollab);

  /// Alias usado por collab / UI (mismo significado que [canRealtimeCollab]).
  bool get canUseRealtimeCollab => canRealtimeCollab;

  /// Callable `folioCloudAiComplete`: suscripción con IA en la nube, tinta comprada, o staff.
  bool get canUseCloudAi =>
      folioStaff || (active && cloudAi) || ink.purchasedBalance > 0;

  static const FolioCloudSnapshot empty = FolioCloudSnapshot(
    active: false,
    subscriptionStatus: null,
    plan: null,
    backup: false,
    cloudAi: false,
    publishWeb: false,
    realtimeCollab: false,
    folioStaff: false,
    backupQuotaBytes: 0,
    backupUsedBytes: 0,
    backupPurchasedBytes: 0,
    backupSubscriptionExtraBytes: 0,
    isFamily: false,
    isStudent: false,
    isStudentVerified: false,
    studentVerifiedUntil: null,
    studentEmail: null,
    familyOwnerUid: null,
    familySeats: 0,
    accountDeletionScheduledFor: null,
  );

  static DateTime? _accountDeletionScheduledFor(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['accountDeletion'];
    if (raw is! Map) return null;
    final m = _asStringKeyedMap(raw);
    final v = m['scheduledFor'];
    if (v is DateTime) return v.toLocal();
    if (v is DateTime) return v.toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    // Firestore REST / mapas serializados: { "_seconds": … }
    if (v is Map) {
      final sec = v['_seconds'] ?? v['seconds'];
      if (sec is int) {
        return DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true)
            .toLocal();
      }
      if (sec is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (sec * 1000).round(),
          isUtc: true,
        ).toLocal();
      }
    }
    return null;
  }

  static int _folioBackupIntField(Map<String, dynamic>? data, String field) {
    if (data == null) return 0;
    final fb = data['folioBackup'];
    if (fb is! Map) return 0;
    final v = fb[field];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static FolioCloudSnapshot fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return FolioCloudSnapshot.empty;
    final raw = data['folioCloud'];
    if (raw is! Map) {
      return FolioCloudSnapshot(
        active: false,
        subscriptionStatus: null,
        plan: null,
        backup: false,
        cloudAi: false,
        publishWeb: false,
        realtimeCollab: false,
        folioStaff: _folioBool(data['folioStaff']),
        backupQuotaBytes: _folioBackupIntField(data, 'quotaBytes'),
        backupUsedBytes: _folioBackupIntField(data, 'usedBytes'),
        backupPurchasedBytes: _folioBackupIntField(data, 'purchasedBytes'),
        backupSubscriptionExtraBytes:
            _folioBackupIntField(data, 'stripeSubscriptionExtraBytes'),
        isFamily: false,
        isStudent: false,
        isStudentVerified: false,
        studentVerifiedUntil: null,
        studentEmail: null,
        familyOwnerUid: null,
        familySeats: 0,
        accountDeletionScheduledFor: _accountDeletionScheduledFor(data),
        ink: FolioInkSnapshot.fromUserDoc(data),
      );
    }
    final m = _asStringKeyedMap(raw);
    final features = _asStringKeyedMap(m['features']);
    bool f(String k) => _folioBool(features[k]);
    var active = _folioBool(m['active']);
    final statusNorm =
        m['subscriptionStatus']?.toString().trim().toLowerCase();
    final planFromRoot = m['plan']?.toString().trim().toLowerCase();
    final planFromFeatures = features['plan']?.toString().trim().toLowerCase();
    final planCandidate = planFromRoot ?? planFromFeatures;
    final plan =
        (planCandidate == 'free' || planCandidate == 'cloud') ? planCandidate : null;
    // Si `active` falta o quedó desincronizado pero el estado Stripe es de alta.
    if (!active &&
        (statusNorm == 'active' ||
            statusNorm == 'trialing' ||
            statusNorm == 'past_due')) {
      active = true;
    }
    // Free tier: active + plan/status free.
    if (!active && (plan == 'free' || statusNorm == 'free')) {
      active = true;
    }
    int seatsVal = 0;
    final sVal = m['familySeats'];
    if (sVal is int) {
      seatsVal = sVal;
    } else if (sVal is num) {
      seatsVal = sVal.toInt();
    } else if (sVal != null) {
      seatsVal = int.tryParse(sVal.toString()) ?? 0;
    }
    return FolioCloudSnapshot(
      active: active,
      subscriptionStatus: m['subscriptionStatus']?.toString(),
      plan: plan,
      backup: f('backup'),
      cloudAi: f('cloudAi'),
      publishWeb: f('publishWeb'),
      realtimeCollab: f('realtimeCollab'),
      folioStaff: _folioBool(data['folioStaff']),
      backupQuotaBytes: _folioBackupIntField(data, 'quotaBytes'),
      backupUsedBytes: _folioBackupIntField(data, 'usedBytes'),
      backupPurchasedBytes: _folioBackupIntField(data, 'purchasedBytes'),
      backupSubscriptionExtraBytes:
          _folioBackupIntField(data, 'stripeSubscriptionExtraBytes'),
      isFamily: _folioBool(m['isFamily']),
      isStudent: _folioBool(m['isStudent']),
      isStudentVerified: _folioBool(m['studentVerified']),
      studentVerifiedUntil: _parseInstant(m['studentVerifiedUntil']),
      studentEmail: m['studentEmail']?.toString(),
      familyOwnerUid: m['familyOwnerUid']?.toString(),
      familySeats: seatsVal,
      accountDeletionScheduledFor: _accountDeletionScheduledFor(data),
      ink: FolioInkSnapshot.fromUserDoc(data),
    );
  }

  static DateTime? _parseInstant(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}

/// Escucha la sesión Spring y el documento de cuenta (`/account/me`).
class FolioCloudEntitlementsController extends ChangeNotifier {
  FolioCloudEntitlementsController();

  CloudAccountController? _cloudAccount;

  void listenToCloudAccount(CloudAccountController cloud) {
    _cloudAccount?.removeListener(_onCloudAccountChanged);
    _cloudAccount = cloud;
    cloud.addListener(_onCloudAccountChanged);
    _onCloudAccountChanged();
  }

  void _onCloudAccountChanged() {
    final cloud = _cloudAccount;
    if (cloud == null) return;
    unawaited(_handleUidChange(cloud.uid));
  }

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

  /// Tras compra Microsoft Store: en el próximo [handleAppResumed] se revalida la colección en Functions.
  bool _pendingMicrosoftStoreSyncOnResume = false;

  String Function()? _resolveWebPortalBaseUrl;

  /// Espejo de `/api/folio/entitlement` (cuenta web). Vacío si no hay URL o sesión.
  FolioWebEntitlementSnapshot? webPortalEntitlement;

  /// Último fallo al refrescar el espejo web (p. ej. red o 503).
  FolioWebPortalException? webPortalRefreshError;

  bool get isAvailable => true;

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

  /// El portal web legacy validaba ID token Firebase; con Spring se omite.
  Future<void> refreshWebPortalEntitlement() async {
    _clearWebPortalMirror();
  }

  /// Marcar que el usuario abrió el pago en el navegador; al volver a la app se sincroniza con Stripe una vez.
  void scheduleStripeSyncOnNextResume() {
    _pendingStripeSyncOnResume = true;
  }

  /// Tras completar un flujo de compra en Microsoft Store (Windows).
  void scheduleMicrosoftStoreSyncOnNextResume() {
    if (!FolioDistribution.showMicrosoftStoreIntegration) return;
    _pendingMicrosoftStoreSyncOnResume = true;
  }

  Future<Map<String, dynamic>?> _fetchUserDocFromServerWithRetries(
    String uid, {
    Duration leadingDelay = Duration.zero,
  }) async {
    if (leadingDelay > Duration.zero) {
      await Future<void>.delayed(leadingDelay);
    }
    try {
      return await folioSpringFetchAccountMeAsUserDoc();
    } catch (e, st) {
      AppLogger.error(
        'Spring account/me fetch failed',
        tag: 'entitlements',
        error: e,
        stackTrace: st,
        context: {'uid': uid},
      );
      return null;
    }
  }

  /// `get` de cuenta Spring sin re-suscribir el poll.
  Future<void> refreshUserDocFromServer({
    Duration leadingDelay = Duration.zero,
  }) async {
    if (!isAvailable) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    final serverData = await _fetchUserDocFromServerWithRetries(
      uid,
      leadingDelay: leadingDelay,
    );
    if (serverData == null ||
        folioCloudCurrentUid() != uid) {
      return;
    }
    final parsed = FolioCloudSnapshot.fromUserDoc(serverData);
    snapshot = parsed;
    _serverFetchTruth = parsed;
    notifyListeners();
    if (parsed.canUseCloudBackup) {
      unawaited(refreshBackupStorageUsageFromServer());
    }
  }

  /// Ajusta [backupUsedBytes] con `folioGetBackupStorageUsage` (incluye ZIP/TAR legado en `backups/`).
  Future<void> refreshBackupStorageUsageFromServer() async {
    if (!isAvailable) return;
    if (!snapshot.canUseCloudBackup) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    try {
      final m = await folioGetBackupStorageUsageCallable();
      final u = m['usedBytes'];
      final used = u is int ? u : int.tryParse('$u') ?? snapshot.backupUsedBytes;
      final q = m['quotaBytes'];
      final quota = q is int ? q : int.tryParse('$q') ?? snapshot.backupQuotaBytes;
      final prev = snapshot;
      snapshot = FolioCloudSnapshot(
        active: prev.active,
        subscriptionStatus: prev.subscriptionStatus,
        plan: prev.plan,
        backup: prev.backup,
        cloudAi: prev.cloudAi,
        publishWeb: prev.publishWeb,
        realtimeCollab: prev.realtimeCollab,
        folioStaff: prev.folioStaff,
        backupQuotaBytes: quota,
        backupUsedBytes: used,
        backupPurchasedBytes: prev.backupPurchasedBytes,
        backupSubscriptionExtraBytes: prev.backupSubscriptionExtraBytes,
        isFamily: prev.isFamily,
        isStudent: prev.isStudent,
        isStudentVerified: prev.isStudentVerified,
        studentVerifiedUntil: prev.studentVerifiedUntil,
        studentEmail: prev.studentEmail,
        familyOwnerUid: prev.familyOwnerUid,
        familySeats: prev.familySeats,
        accountDeletionScheduledFor: prev.accountDeletionScheduledFor,
        ink: prev.ink,
      );
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'backup usage callable failed',
        tag: 'entitlements',
        error: e,
        stackTrace: st,
      );
    }
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
      plan: prev.plan,
      backup: prev.backup,
      cloudAi: prev.cloudAi,
      publishWeb: prev.publishWeb,
      realtimeCollab: prev.realtimeCollab,
      folioStaff: prev.folioStaff,
      backupQuotaBytes: prev.backupQuotaBytes,
      backupUsedBytes: prev.backupUsedBytes,
      backupPurchasedBytes: prev.backupPurchasedBytes,
      backupSubscriptionExtraBytes: prev.backupSubscriptionExtraBytes,
      isFamily: prev.isFamily,
      isStudent: prev.isStudent,
      isStudentVerified: prev.isStudentVerified,
      studentVerifiedUntil: prev.studentVerifiedUntil,
      studentEmail: prev.studentEmail,
      familyOwnerUid: prev.familyOwnerUid,
      familySeats: prev.familySeats,
      accountDeletionScheduledFor: prev.accountDeletionScheduledFor,
      ink: ink,
    );
    notifyListeners();
  }

  /// Al reactivar la app: datos frescos de Firestore y, si aplica, una sync con Stripe tras checkout.
  Future<void> handleAppResumed() async {
    if (!isAvailable) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    // Windows: el motor Flutter + Pigeon a menudo necesitan >1s tras resumed.
    await refreshUserDocFromServer(
      leadingDelay: const Duration(milliseconds: 1200),
    );
    if (_pendingStripeSyncOnResume) {
      _pendingStripeSyncOnResume = false;
      _lastStripeSync = null;
      try {
        await syncFolioCloudSubscriptionFromStripe();
      } catch (e, st) {
        AppLogger.error(
          'post-checkout Stripe sync failed',
          tag: 'entitlements',
          error: e,
          stackTrace: st,
        );
      }
      await refreshUserDocFromServer(
        leadingDelay: const Duration(milliseconds: 400),
      );
    }
    if (_pendingMicrosoftStoreSyncOnResume &&
        FolioMicrosoftStoreChannel.isRuntimeSupported &&
        FolioDistribution.showMicrosoftStoreIntegration) {
      _pendingMicrosoftStoreSyncOnResume = false;
      try {
        await syncFolioMicrosoftStoreEntitlementsFromDevice();
      } catch (e, st) {
        AppLogger.error(
          'post-Store purchase sync failed',
          tag: 'entitlements',
          error: e,
          stackTrace: st,
        );
      }
      await refreshUserDocFromServer(
        leadingDelay: const Duration(milliseconds: 400),
      );
    }
    unawaited(refreshWebPortalEntitlement());
  }

  void _cancelUserDocPoll() {
    _userDocPollTimer?.cancel();
    _userDocPollTimer = null;
  }

  Future<void> _handleUidChange(String? uid) async {
    _cancelUserDocPoll();
    if (uid == null || uid.isEmpty) {
      _subscribedUid = null;
      _serverFetchTruth = null;
      _pendingStripeSyncOnResume = false;
      _pendingMicrosoftStoreSyncOnResume = false;
      snapshot = FolioCloudSnapshot.empty;
      _clearWebPortalMirror();
      notifyListeners();
      return;
    }
    final accountChanged = _subscribedUid != uid;
    _subscribedUid = uid;
    if (accountChanged) {
      _serverFetchTruth = null;
      _pendingStripeSyncOnResume = false;
      _pendingMicrosoftStoreSyncOnResume = false;
      snapshot = FolioCloudSnapshot.empty;
      _clearWebPortalMirror();
      notifyListeners();
    }
    await _subscribeUserDoc(uid);
    unawaited(refreshWebPortalEntitlement());
  }

  /// Refresca la cuenta desde Spring y arranca poll periódico.
  Future<void> _subscribeUserDoc(String uid) async {
    Map<String, dynamic>? serverData =
        await _fetchUserDocFromServerWithRetries(uid);
    if (folioCloudCurrentUid() != uid) return;
    if (serverData == null) {
      try {
        await callFolioHttpsCallable('ensureUserDocExists');
        serverData = await _fetchUserDocFromServerWithRetries(uid);
      } catch (e) {
        // Ignorar
      }
    }
    if (folioCloudCurrentUid() != uid) return;
    if (serverData != null) {
      final parsed = FolioCloudSnapshot.fromUserDoc(serverData);
      AppLogger.debug(
        'Server user doc loaded',
        tag: 'entitlements',
        context: {
          'uid': uid,
          'active': parsed.active,
          'plan': parsed.plan,
          'subscriptionStatus': parsed.subscriptionStatus,
          'folioStaff': parsed.folioStaff,
          'canUseCloudBackup': parsed.canUseCloudBackup,
        },
      );
      snapshot = parsed;
      _serverFetchTruth = parsed;
      notifyListeners();
      if (parsed.canUseCloudBackup) {
        unawaited(refreshBackupStorageUsageFromServer());
      }
    } else {
      _serverFetchTruth = null;
    }

    if (folioCloudCurrentUid() != uid) return;

    unawaited(_maybeSyncStripeAfterServerRead(uid, serverData));

    _userDocPollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (folioCloudCurrentUid() != uid) return;
      unawaited(refreshUserDocFromServer());
    });
  }

  /// Si el documento en servidor no refleja suscripción, un sync con Stripe actualiza el estado.
  Future<void> _maybeSyncStripeAfterServerRead(
    String uid,
    Map<String, dynamic>? serverData,
  ) async {
    if (folioCloudCurrentUid() != uid) return;
    if (snapshot.active && (snapshot.isStudent || !snapshot.isStudentVerified)) return;
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
      AppLogger.warn(
        'sync Stripe omitido o fallido',
        tag: 'entitlements',
        context: {'error': '$e'},
      );
    }
  }

  /// Llamar tras volver del checkout o si la UI sigue desactualizada.
  Future<void> refreshSubscriptionFromStripe() async {
    if (!isAvailable) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    _lastStripeSync = null;
    try {
      await syncFolioCloudSubscriptionFromStripe();
    } catch (e, st) {
      AppLogger.error(
        'refreshSubscriptionFromStripe failed',
        tag: 'entitlements',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    final data = await _fetchUserDocFromServerWithRetries(uid);
    if (data != null && folioCloudCurrentUid() == uid) {
      final parsed = FolioCloudSnapshot.fromUserDoc(data);
      snapshot = parsed;
      _serverFetchTruth = parsed;
      notifyListeners();
    }
  }

  /// Sincroniza derechos Microsoft Store → Firestore (Windows, app desde la Tienda).
  Future<void> refreshMicrosoftStoreEntitlements() async {
    if (!isAvailable) return;
    if (!FolioMicrosoftStoreChannel.isRuntimeSupported) return;
    if (!FolioDistribution.showMicrosoftStoreIntegration) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    try {
      await syncFolioMicrosoftStoreEntitlementsFromDevice();
    } catch (e, st) {
      AppLogger.error(
        'refreshMicrosoftStoreEntitlements failed',
        tag: 'entitlements',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    final data = await _fetchUserDocFromServerWithRetries(uid);
    if (data != null && folioCloudCurrentUid() == uid) {
      final parsed = FolioCloudSnapshot.fromUserDoc(data);
      snapshot = parsed;
      _serverFetchTruth = parsed;
      notifyListeners();
    }
  }

  /// Una sola acción: revalida Stripe y, en Windows, Microsoft Store; actualiza el snapshot si al menos un canal responde.
  Future<void> refreshFolioCloudBillingFromServers() async {
    if (!isAvailable) return;
    final uid = folioCloudCurrentUid();
    if (uid == null) return;
    _lastStripeSync = null;

    String? stripeErr;
    try {
      await syncFolioCloudSubscriptionFromStripe();
    } catch (e, st) {
      stripeErr = '$e';
      AppLogger.error(
        'refreshFolioCloudBillingFromServers Stripe failed',
        tag: 'entitlements',
        error: e,
        stackTrace: st,
      );
    }

    String? msErr;
    if (FolioMicrosoftStoreChannel.isRuntimeSupported &&
        FolioDistribution.showMicrosoftStoreIntegration) {
      try {
        await syncFolioMicrosoftStoreEntitlementsFromDevice();
      } catch (e, st) {
        msErr = '$e';
        AppLogger.error(
          'refreshFolioCloudBillingFromServers MS failed',
          tag: 'entitlements',
          error: e,
          stackTrace: st,
        );
      }
    }

    final data = await _fetchUserDocFromServerWithRetries(uid);
    if (data != null && folioCloudCurrentUid() == uid) {
      try {
        final parsed = FolioCloudSnapshot.fromUserDoc(data);
        snapshot = parsed;
        _serverFetchTruth = parsed;
        notifyListeners();
      } catch (e, st) {
        AppLogger.error(
          'refreshFolioCloudBillingFromServers parse failed',
          tag: 'entitlements',
          error: e,
          stackTrace: st,
        );
      }
    }

    final win = FolioMicrosoftStoreChannel.isRuntimeSupported &&
        FolioDistribution.showMicrosoftStoreIntegration;
    final stripeOk = stripeErr == null;
    final msOk = !win || msErr == null;
    if (!win) {
      if (!stripeOk) {
        throw Exception(stripeErr);
      }
      return;
    }
    if (!stripeOk && !msOk) {
      throw Exception('$stripeErr\n$msErr');
    }
  }

  @override
  void dispose() {
    _cloudAccount?.removeListener(_onCloudAccountChanged);
    _cancelUserDocPoll();
    _cancelUserDocPoll();
    super.dispose();
  }
}
