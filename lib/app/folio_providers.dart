import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/vault_persistence_controller.dart';
import '../session/vault_session.dart';

/// Estado de flujo de la libreta (onboarding, lock, workspace, recovery).
final vaultFlowStateProvider = Provider<VaultFlowState>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

/// Página seleccionada en el workspace.
final selectedPageProvider = Provider<String?>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

/// Estado de guardado en disco.
final saveStatusProvider = Provider<SaveStatus>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

/// Sesión activa de Folio.
final vaultSessionProvider = Provider<VaultSession>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
