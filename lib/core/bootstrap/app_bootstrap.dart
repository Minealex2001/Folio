import 'dart:async';

import '../../app/app_settings.dart';
import '../../services/app_logger.dart';
import '../../session/vault_session.dart';
import 'bootstrap_phase.dart';

/// Resultado del arranque de la libreta y módulos secundarios.
class BootstrapResult {
  const BootstrapResult({
    required this.vaultState,
    this.failedPhases = const {},
  });

  final VaultFlowState vaultState;
  final Set<BootstrapPhase> failedPhases;

  bool get recoveryMode => vaultState == VaultFlowState.recovery;
}

typedef SecondaryBootstrapRunner = Future<void> Function();

/// Orquesta el arranque por fases: la libreta bloquea la UI; el resto degrada.
class AppBootstrap {
  AppBootstrap({
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  final Set<BootstrapPhase> failedPhases = {};

  /// Fase crítica: abrir registro y libreta activa.
  Future<BootstrapResult> runVaultPhase() async {
    failedPhases.clear();
    try {
      await session.bootstrap();
    } catch (e, st) {
      AppLogger.error(
        'Vault bootstrap failed',
        tag: 'bootstrap',
        error: e,
        stackTrace: st,
      );
      failedPhases.add(BootstrapPhase.vaultOpen);
    }
    return BootstrapResult(
      vaultState: session.state,
      failedPhases: Set.unmodifiable(failedPhases),
    );
  }

  /// Ejecuta un runner de módulos secundarios capturando fallos sin bloquear.
  Future<void> runSecondaryPhase(
    BootstrapPhase phase,
    Future<void> Function() runner,
  ) async {
    try {
      await runner();
    } catch (e, st) {
      failedPhases.add(phase);
      AppLogger.warn(
        'Bootstrap phase degraded',
        tag: 'bootstrap',
        context: {'phase': phase.name, 'error': '$e'},
      );
      AppLogger.debug(
        'Bootstrap phase stack',
        tag: 'bootstrap',
        context: {'phase': phase.name, 'stack': '$st'},
      );
    }
  }
}
