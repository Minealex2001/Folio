import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/folio_app_package.dart';
import '../../models/folio_app_registry_entry.dart';
import '../../models/installed_folio_app.dart';
import 'app_extension_registry.dart';
import 'folio_app_package_loader.dart';
import 'folio_built_in_apps.dart';

/// URL del registry público por defecto.
const _defaultRegistryUrl =
    'https://raw.githubusercontent.com/folio-editor/folio-app-registry/main/registry.json';

const _keyInstalledApps = 'folio_installed_apps_v1';
const _keyRegistryCache = 'folio_app_registry_cache';
const _keyRegistryUrl = 'folio_app_registry_url';

/// Resultado de una operación de instalación.
sealed class AppInstallResult {}

class AppInstallSuccess extends AppInstallResult {
  AppInstallSuccess(this.app);
  final InstalledFolioApp app;
}

class AppInstallError extends AppInstallResult {
  AppInstallError(this.message);
  final String message;
}

/// Servicio central de la Tienda de Apps de Folio.
///
/// Gestiona la lista de apps instaladas, la descarga desde el registry,
/// la instalación desde archivos locales y la sincronización con [AppExtensionRegistry].
class AppStoreService extends ChangeNotifier {
  AppStoreService._() : _loader = const FolioAppPackageLoader();

  static final AppStoreService instance = AppStoreService._();

  final FolioAppPackageLoader _loader;

  // ── Estado ────────────────────────────────────────────────────────────────

  List<InstalledFolioApp> _installed = [];
  FolioAppRegistry _registry = FolioAppRegistry.empty;
  bool _loadingRegistry = false;
  String? _registryError;

  List<InstalledFolioApp> get installedApps => List.unmodifiable(_installed);

  FolioAppRegistry get registry => _registry;
  bool get loadingRegistry => _loadingRegistry;
  String? get registryError => _registryError;

  /// Apps oficiales integradas en Folio (no requieren descarga).
  List<FolioAppPackage> get builtInApps => FolioBuiltInApps.all;

  // ── Inicialización ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadInstalled();
    _syncRegistry();
    unawaited(fetchRegistry());
  }

  Future<void> _loadInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInstalledApps);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _installed = list.map(InstalledFolioApp.fromJson).toList();
    } catch (_) {
      _installed = [];
    }
    _syncRegistry();
  }

  Future<void> _saveInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_installed.map((a) => a.toJson()).toList());
    await prefs.setString(_keyInstalledApps, json);
  }

  void _syncRegistry() {
    AppExtensionRegistry.instance.loadFromInstalledApps(_installed);
  }

  // ── Registry público ──────────────────────────────────────────────────────

  /// Recupera el registry remoto. Si falla, usa la caché local.
  Future<void> fetchRegistry() async {
    _loadingRegistry = true;
    _registryError = null;
    notifyListeners();

    try {
      final url = await _registryUrl();
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _registry = FolioAppRegistry.fromJsonString(response.body);
        await _cacheRegistry(response.body);
      } else {
        _registryError = 'Error ${response.statusCode} al cargar el registry.';
        await _loadCachedRegistry();
      }
    } catch (e) {
      _registryError = 'Sin conexión. Mostrando caché local.';
      await _loadCachedRegistry();
    }

    _loadingRegistry = false;
    notifyListeners();
  }

  Future<String> _registryUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRegistryUrl) ?? _defaultRegistryUrl;
  }

  Future<void> setRegistryUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegistryUrl, url);
  }

  Future<void> _cacheRegistry(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegistryCache, raw);
  }

  Future<void> _loadCachedRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyRegistryCache);
    if (cached != null) {
      try {
        _registry = FolioAppRegistry.fromJsonString(cached);
      } catch (_) {}
    }
  }

  // ── Instalación ───────────────────────────────────────────────────────────

  /// Instala una app oficial integrada (sin descarga ni descompresión).
  AppInstallResult installBuiltIn(String appId) {
    final pkg = FolioBuiltInApps.all.firstWhere(
      (p) => p.id == appId,
      orElse: () => throw ArgumentError('App integrada no encontrada: $appId'),
    );
    return _finalizeInstall(pkg, null, []);
  }

  /// Instala una app desde [bytes] (contenido de un archivo .folioapp).
  Future<AppInstallResult> installFromBytes(
    Uint8List bytes, {
    required List<FolioAppPermission> grantedPermissions,
  }) async {
    final destDir = await _installsDirectory();
    final result = await _loader.loadFromBytes(bytes, destinationDir: destDir);

    if (result is FolioAppLoadError) {
      return AppInstallError(result.message);
    }

    final success = result as FolioAppLoadSuccess;
    return _finalizeInstall(
      success.package,
      success.extractedPath,
      grantedPermissions,
    );
  }

  /// Instala una app descargando desde la URL del registry.
  Future<AppInstallResult> installFromRegistry(
    FolioAppRegistryEntry entry, {
    required List<FolioAppPermission> grantedPermissions,
  }) async {
    // Validar URL de descarga
    final uri = Uri.tryParse(entry.downloadUrl);
    if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
      return AppInstallError(
        'URL de descarga inválida o no segura: ${entry.downloadUrl}',
      );
    }

    final Uint8List bytes;
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        return AppInstallError(
          'Error descargando app: HTTP ${response.statusCode}',
        );
      }
      bytes = response.bodyBytes;
    } catch (e) {
      return AppInstallError('Error de red al descargar: $e');
    }

    return installFromBytes(bytes, grantedPermissions: grantedPermissions);
  }

  AppInstallResult _finalizeInstall(
    FolioAppPackage package,
    String? extractedPath,
    List<FolioAppPermission> grantedPermissions,
  ) {
    // Eliminar instalación anterior si existe
    _installed.removeWhere((a) => a.package.id == package.id);

    final app = InstalledFolioApp(
      package: package,
      installedAt: DateTime.now(),
      localPath: extractedPath,
      enabled: true,
      grantedPermissions: grantedPermissions,
    );

    _installed.add(app);
    _syncRegistry();
    _saveInstalled();
    notifyListeners();

    return AppInstallSuccess(app);
  }

  // ── Gestión de apps instaladas ────────────────────────────────────────────

  Future<void> uninstall(String appId) async {
    final idx = _installed.indexWhere((a) => a.package.id == appId);
    if (idx < 0) return;

    final app = _installed[idx];
    if (app.localPath != null) {
      try {
        await _loader.uninstall(app.localPath!);
      } catch (_) {}
    }

    _installed.removeAt(idx);
    _syncRegistry();
    await _saveInstalled();
    notifyListeners();
  }

  Future<void> setEnabled(String appId, {required bool enabled}) async {
    final idx = _installed.indexWhere((a) => a.package.id == appId);
    if (idx < 0) return;
    _installed[idx] = _installed[idx].copyWith(enabled: enabled);
    _syncRegistry();
    await _saveInstalled();
    notifyListeners();
  }

  bool isInstalled(String appId) =>
      _installed.any((a) => a.package.id == appId);

  InstalledFolioApp? installedById(String appId) {
    final idx = _installed.indexWhere((a) => a.package.id == appId);
    return idx >= 0 ? _installed[idx] : null;
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  Future<String> _installsDirectory() async {
    final base = await getApplicationSupportDirectory();
    return p.join(base.path, 'folio_apps');
  }
}
