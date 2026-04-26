import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_logger.dart';
import 'telemetry_models.dart';

/// Sincroniza eventos de telemetría a Firestore en batches.
///
/// - Acumula eventos en memoria y hace flush periódico (cada 5 min) o al agregar
/// - Envía batches a `analytics_events/{uid}/events` solo con [FirebaseAuth] activo
/// - Las agregaciones diarias en `stats` las escriben Cloud Functions (reglas)
/// - Reintentos con backoff exponencial si falla el commit
/// - Un drain serializado y commits de como mucho [_maxWritesPerCommit] escrituras
class FolioFirestoreSync {
  FolioFirestoreSync._();

  static const _batchFlushIntervalSeconds = 300; // 5 minutos
  static const _initialRetryDelayMs = 1000;
  static const _maxRetryDelayMs = 30000;
  static const _maxWritesPerCommit = 100;

  static final List<TelemetryEvent> _eventQueue = [];
  static Timer? _flushTimer;
  static StreamSubscription<User?>? _authSub;
  static int _retryCount = 0;
  static String _lastUserId = '';

  /// Encadena drains para no solapar flushes.
  static Future<void> _flushChain = Future.value();

  static PackageInfo? _cachedPackageInfo;

  static Future<PackageInfo> _packageInfo() async =>
      _cachedPackageInfo ??= await PackageInfo.fromPlatform();

  /// Inicia el servicio de sincronización.
  /// Debe llamarse una vez al iniciar la app (en main.dart después de Firebase.init).
  static void initialize() {
    _startFlushTimer();
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      onUserChanged(user?.uid ?? '');
    });
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isNotEmpty) {
      _lastUserId = currentUid;
    }
    AppLogger.debug(
      'FolioFirestoreSync initialized',
      tag: 'telemetry-sync',
      context: {'userId': _lastUserId.isEmpty ? 'anonymous' : _lastUserId},
    );
  }

  /// Detiene el servicio y ejecuta un flush final.
  static Future<void> shutdown() async {
    _flushTimer?.cancel();
    _authSub?.cancel();
    _authSub = null;
    _flushChain = _flushChain.then((_) => _drainEventQueueBatches());
    await _flushChain;
  }

  /// Fuerza el envío inmediato de todos los eventos pendientes.
  static Future<void> flush() async {
    _flushChain = _flushChain.then((_) => _drainEventQueueBatches());
    await _flushChain;
  }

  /// Agrega un evento a la cola y programa envío (encadenado, sin await).
  static void addEvent(TelemetryEvent event) {
    _eventQueue.add(event);
    _flushChain = _flushChain.then((_) => _drainEventQueueBatches());
  }

  /// Cambia el usuario actual. Si cambió, ejecuta flush antes de limpiar.
  static Future<void> onUserChanged(String newUserId) async {
    if (_lastUserId != newUserId && _eventQueue.isNotEmpty) {
      _flushChain = _flushChain.then((_) => _drainEventQueueBatches());
      await _flushChain;
    }
    _lastUserId = newUserId;
  }

  // ============ PRIVADOS ============

  static void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: _batchFlushIntervalSeconds),
      (_) {
        if (_eventQueue.isNotEmpty) {
          _flushChain = _flushChain.then((_) => _drainEventQueueBatches());
        }
      },
    );
  }

  static Future<void> _drainEventQueueBatches() async {
    while (_eventQueue.isNotEmpty) {
      if (Firebase.apps.isEmpty) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        AppLogger.debug(
          'Telemetry flush skipped (no auth user)',
          tag: 'telemetry-sync',
          context: {'queued': _eventQueue.length},
        );
        return;
      }

      final take = _eventQueue.length > _maxWritesPerCommit
          ? _maxWritesPerCommit
          : _eventQueue.length;
      final chunk = List<TelemetryEvent>.from(_eventQueue.sublist(0, take));
      _eventQueue.removeRange(0, take);
      _retryCount = 0;

      final ok = await _sendBatchWithRetry(uid, chunk);
      if (!ok) break;
    }
  }

  static Future<bool> _sendBatchWithRetry(
    String userId,
    List<TelemetryEvent> events,
  ) async {
    if (events.isEmpty) return true;
    try {
      final info = await _packageInfo();
      final batch = FirebaseFirestore.instance.batch();

      for (final event in events) {
        final docRef = FirebaseFirestore.instance
            .collection('analytics_events')
            .doc(userId)
            .collection('events')
            .doc(event.id);

        batch.set(
          docRef,
          event.toFirestore(
            userId: userId,
            appVersion: info.version,
            buildNumber: info.buildNumber,
          ),
        );
      }

      await batch.commit();
      _retryCount = 0;
      AppLogger.debug(
        'Telemetry batch synced successfully',
        tag: 'telemetry-sync',
        context: {'userId': userId, 'eventCount': events.length},
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(
        'Failed to sync telemetry batch',
        tag: 'telemetry-sync',
        context: {'error': '$e', 'retryCount': _retryCount},
      );
      AppLogger.debug(
        'Telemetry sync stack',
        tag: 'telemetry-sync',
        context: {'stack': '$st'},
      );

      return _retryWithBackoff(userId, events);
    }
  }

  static Future<bool> _retryWithBackoff(
    String userId,
    List<TelemetryEvent> events,
  ) async {
    if (_retryCount >= 5) {
      AppLogger.warn(
        'Telemetry sync max retries exceeded',
        tag: 'telemetry-sync',
        context: {'userId': userId, 'eventCount': events.length},
      );
      _eventQueue.addAll(events);
      return false;
    }

    _retryCount++;
    final delayMs = (_initialRetryDelayMs * (1 << (_retryCount - 1)))
        .toInt()
        .clamp(0, _maxRetryDelayMs);

    AppLogger.debug(
      'Retrying telemetry sync',
      tag: 'telemetry-sync',
      context: {'retryCount': _retryCount, 'delayMs': delayMs},
    );

    await Future.delayed(Duration(milliseconds: delayMs));
    return _sendBatchWithRetry(userId, events);
  }
}
