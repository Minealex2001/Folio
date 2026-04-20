import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/folio_app_package.dart';

const _keyOAuthTokens = 'folio_oauth_tokens';
const _keyApiKeys = 'folio_app_api_keys';

/// Estado de conexión de una integración.
enum IntegrationAuthState { notConnected, connecting, connected, error }

class IntegrationAuthStatus {
  const IntegrationAuthStatus({
    required this.state,
    this.errorMessage,
    this.connectedAt,
  });

  final IntegrationAuthState state;
  final String? errorMessage;
  final DateTime? connectedAt;

  bool get isConnected => state == IntegrationAuthState.connected;
}

/// Gestiona tokens OAuth2 y API keys de las integraciones de apps.
///
/// Los tokens se guardan en SharedPreferences (sin cifrar).
/// TODO (seguridad): migrar a flutter_secure_storage en producción.
class IntegrationAuthService extends ChangeNotifier {
  IntegrationAuthService._();

  static final IntegrationAuthService _instance = IntegrationAuthService._();
  static IntegrationAuthService get instance => _instance;

  // Map<integrationKey, accessToken>
  final Map<String, String> _oauthTokens = {};

  // Map<integrationKey, apiKey>
  final Map<String, String> _apiKeys = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final tokensRaw = prefs.getString(_keyOAuthTokens);
    if (tokensRaw != null) {
      try {
        _oauthTokens.addAll(
          Map<String, String>.from(
            (jsonDecode(tokensRaw) as Map).cast<String, String>(),
          ),
        );
      } catch (_) {}
    }

    final keysRaw = prefs.getString(_keyApiKeys);
    if (keysRaw != null) {
      try {
        _apiKeys.addAll(
          Map<String, String>.from(
            (jsonDecode(keysRaw) as Map).cast<String, String>(),
          ),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  IntegrationAuthStatus statusFor(String integrationKey) {
    if (_oauthTokens.containsKey(integrationKey) ||
        _apiKeys.containsKey(integrationKey)) {
      return const IntegrationAuthStatus(state: IntegrationAuthState.connected);
    }
    return const IntegrationAuthStatus(
      state: IntegrationAuthState.notConnected,
    );
  }

  String? accessTokenFor(String integrationKey) => _oauthTokens[integrationKey];

  String? apiKeyFor(String integrationKey) => _apiKeys[integrationKey];

  // ── OAuth2 ────────────────────────────────────────────────────────────────

  /// Inicia el flujo OAuth2 abriendo la URL de autorización.
  /// Actualmente implementa el flujo "open browser" — el usuario pega el token
  /// de retorno manualmente (hasta que se implemente un deep-link callback).
  Future<bool> beginOAuthFlow(FolioAppIntegration integration) async {
    if (integration.authorizationUrl == null) return false;

    // Validar la URL (evitar SSRF a IPs privadas)
    final uri = Uri.tryParse(integration.authorizationUrl!);
    if (uri == null || !_isPublicHttpsUrl(uri)) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Guarda un access token obtenido para una integración OAuth2.
  Future<void> saveOAuthToken(String integrationKey, String accessToken) async {
    _oauthTokens[integrationKey] = accessToken;
    await _persistTokens();
    notifyListeners();
  }

  // ── API Key ───────────────────────────────────────────────────────────────

  Future<void> saveApiKey(String integrationKey, String apiKey) async {
    _apiKeys[integrationKey] = apiKey;
    await _persistApiKeys();
    notifyListeners();
  }

  // ── Desconectar ───────────────────────────────────────────────────────────

  Future<void> disconnect(String integrationKey) async {
    _oauthTokens.remove(integrationKey);
    _apiKeys.remove(integrationKey);
    await _persistTokens();
    await _persistApiKeys();
    notifyListeners();
  }

  // ── Persistencia ──────────────────────────────────────────────────────────

  Future<void> _persistTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOAuthTokens, jsonEncode(_oauthTokens));
  }

  Future<void> _persistApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKeys, jsonEncode(_apiKeys));
  }

  // ── Seguridad ─────────────────────────────────────────────────────────────

  /// Retorna true si la URL es https y no apunta a localhost ni a IPs privadas.
  static bool _isPublicHttpsUrl(Uri uri) {
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return false;
    }
    // Rango 10.x.x.x, 172.16-31.x.x, 192.168.x.x
    final privateIp = RegExp(
      r'^(10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|192\.168\.\d+\.\d+)$',
    );
    if (privateIp.hasMatch(host)) return false;
    return true;
  }

  /// Muestra un diálogo para que el usuario pegue manualmente un token/api key.
  static Future<String?> showTokenInputDialog(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => value = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(value.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
