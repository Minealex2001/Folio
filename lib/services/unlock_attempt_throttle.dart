import 'package:shared_preferences/shared_preferences.dart';

/// Lanzada cuando el desbloqueo está en cooldown por intentos fallidos previos.
class UnlockThrottledException implements Exception {
  const UnlockThrottledException(this.retryAfter);

  /// Cuánto falta para poder reintentar.
  final Duration retryAfter;

  @override
  String toString() => 'UnlockThrottledException(retryAfter: $retryAfter)';
}

/// Backoff progresivo por intentos fallidos de desbloqueo del vault, **por
/// libreta** ([vaultId]). No bloquea permanentemente al dueño legítimo: el
/// retraso crece con cada fallo consecutivo y se resetea a 0 en el primer
/// éxito. Estado no sensible (solo un contador y una marca de tiempo), vive
/// en [SharedPreferences] — debe poder leerse/escribirse antes de tener la
/// DEK, con el vault aún bloqueado (mismo patrón que `QuickUnlockStorage`).
class UnlockAttemptThrottle {
  static String _failCountKey(String vaultId) =>
      'folio_unlock_fail_count_$vaultId';
  static String _nextAllowedAtKey(String vaultId) =>
      'folio_unlock_next_allowed_at_ms_$vaultId';

  /// Retraso por intento fallido consecutivo (índice 0 = primer fallo).
  /// Los primeros 3 fallos no imponen espera; luego crece hasta un tope.
  static const List<Duration> _delaySchedule = [
    Duration.zero,
    Duration.zero,
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];
  static const Duration _maxDelay = Duration(seconds: 30);

  Duration _delayForFailCount(int failCount) {
    if (failCount <= 0) return Duration.zero;
    final index = failCount - 1;
    if (index < _delaySchedule.length) return _delaySchedule[index];
    return _maxDelay;
  }

  /// `null` si ya se puede reintentar; si no, cuánto falta.
  Future<Duration?> remainingWait(String vaultId) async {
    final id = vaultId.trim();
    if (id.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final nextAllowedAtMs = p.getInt(_nextAllowedAtKey(id));
    if (nextAllowedAtMs == null) return null;
    final remainingMs = nextAllowedAtMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return null;
    return Duration(milliseconds: remainingMs);
  }

  Future<void> recordFailure(String vaultId) async {
    final id = vaultId.trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final failCount = (p.getInt(_failCountKey(id)) ?? 0) + 1;
    await p.setInt(_failCountKey(id), failCount);
    final delay = _delayForFailCount(failCount);
    if (delay > Duration.zero) {
      final nextAllowedAtMs =
          DateTime.now().millisecondsSinceEpoch + delay.inMilliseconds;
      await p.setInt(_nextAllowedAtKey(id), nextAllowedAtMs);
    }
  }

  Future<void> recordSuccess(String vaultId) async {
    final id = vaultId.trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.remove(_failCountKey(id));
    await p.remove(_nextAllowedAtKey(id));
  }
}
