import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import '../folio_cloud/folio_cloud_organizations.dart';
import 'cloud_account_controller.dart';

/// Fase 12 del roadmap de Organizations — lista de organizaciones del usuario +
/// preferencia de "organización activa" persistida localmente.
///
/// Deliberadamente NO modifica [FolioSpringAuthSession] (núcleo de auth, muy
/// sensible) — es un controlador separado que la observa. Igual que el resto
/// de la app compone controladores en `main.dart`.
///
/// La "organización activa" es solo una preferencia de UI para saber qué
/// mostrar por defecto — NUNCA se usa como fuente de autorización. El
/// servidor revalida la pertenencia del usuario a la organización en cada
/// petición (ver `OrganizationPermissionService` en el backend).
class OrganizationContextController extends ChangeNotifier {
  OrganizationContextController({required CloudAccountController account})
      : _account = account {
    _account.addListener(_onAccountChanged);
  }

  static const _kActiveOrgIdKeyPrefix = 'folio_active_organization_id_v1';

  final CloudAccountController _account;

  String get _activeOrgKey {
    final uid = _account.uid ?? '_none';
    return '${_kActiveOrgIdKeyPrefix}_$uid';
  }

  List<OrganizationSummary> _organizations = const [];
  String? _activeOrganizationId;
  bool _loading = false;
  Object? _lastError;
  String? _restoredForUid;

  List<OrganizationSummary> get organizations => _organizations;
  bool get loading => _loading;
  Object? get lastError => _lastError;

  String? get activeOrganizationId => _activeOrganizationId;

  OrganizationSummary? get activeOrganization {
    final id = _activeOrganizationId;
    if (id == null) return null;
    for (final org in _organizations) {
      if (org.id == id) return org;
    }
    return null;
  }

  /// La organización personal del usuario (siempre existe una vez cargada la
  /// lista) — punto de partida por defecto antes de que el usuario elija un
  /// equipo.
  OrganizationSummary? get personalOrganization {
    for (final org in _organizations) {
      if (org.isPersonal) return org;
    }
    return null;
  }

  void _onAccountChanged() {
    if (!_account.isSignedIn) {
      _organizations = const [];
      _activeOrganizationId = null;
      _restoredForUid = null;
      notifyListeners();
      return;
    }
    // Cambio de cuenta activa (multi-cuenta): recargar orgs de esa sesión.
    if (_restoredForUid != _account.uid) {
      unawaited(refresh());
    }
  }

  /// Carga (o recarga) la lista de organizaciones del usuario y restaura la
  /// preferencia de organización activa guardada localmente. Llamar tras el
  /// login / arranque de sesión, igual que `ensureSpringSessionRestored`.
  Future<void> refresh() async {
    if (!_account.isSignedIn) return;
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final orgs = await fetchMyOrganizations();
      _organizations = orgs;
      final uid = _account.uid;
      if (_restoredForUid != uid) {
        await _restoreActiveOrganizationId();
        _restoredForUid = uid;
      }
      if (_activeOrganizationId == null ||
          !orgs.any((o) => o.id == _activeOrganizationId)) {
        // Fallback: la personal si la activa guardada ya no es válida (org
        // borrada, o el usuario abandonó el equipo).
        await setActiveOrganizationId(personalOrganization?.id ?? orgs.firstOrNull?.id);
        return;
      }
    } catch (e, st) {
      _lastError = e;
      AppLogger.warn(
        'organizationContext refresh failed',
        tag: 'org',
        context: {'error': '$e', 'stack': '$st'},
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setActiveOrganizationId(String? id) async {
    _activeOrganizationId = id;
    final prefs = await SharedPreferences.getInstance();
    final key = _activeOrgKey;
    if (id == null || id.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
    notifyListeners();
  }

  Future<void> _restoreActiveOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _activeOrgKey;
    _activeOrganizationId = prefs.getString(key) ??
        prefs.getString('folio_active_organization_id_v1');
  }

  @override
  void dispose() {
    _account.removeListener(_onAccountChanged);
    super.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
