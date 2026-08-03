import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../config/folio_backend_config.dart';
import '../../models/ytmusic_integration_state.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import '../app_logger.dart';

/// OAuth device-flow: abre el navegador del sistema (como Spotify) y hace poll.
class YtMusicAuthService {
  YtMusicAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _uuid = Uuid();

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    if (!folioCloudHasSession()) {
      throw StateError('Folio Cloud session required for YouTube Music.');
    }
    final idToken = await folioCloudBearerToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Folio Cloud session required for YouTube Music.');
    }
    final headers = <String, String>{
      'content-type': 'application/json',
      if (auth) 'authorization': 'Bearer $idToken',
    };
    final resp = await _client.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw StateError('ytmusic_invalid_response');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final google = '${map['googleError'] ?? ''}'.trim();
      final googleDesc = '${map['googleErrorDescription'] ?? ''}'.trim();
      final hint = '${map['hint'] ?? ''}'.trim();
      final message = '${map['message'] ?? map['error'] ?? map}'.trim();
      final detail = [
        if (google.isNotEmpty) google,
        if (googleDesc.isNotEmpty) googleDesc,
        if (hint.isNotEmpty) hint,
        if (message.isNotEmpty && google.isEmpty) message,
      ].join(' — ');
      throw StateError(
        detail.isEmpty
            ? 'ytmusic_http_${resp.statusCode}'
            : 'ytmusic_http_${resp.statusCode}: $detail',
      );
    }
    return map;
  }

  /// Abre el navegador para autorizar y espera tokens.
  Future<YtMusicConnection> connect({
    required String label,
    void Function(String userCode, String verificationUrl)? onUserCode,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final start = await _postJson(
      '/integrations/ytmusic/oauth-device/start',
      const {},
    );
    final deviceCode = '${start['device_code'] ?? ''}'.trim();
    final userCode = '${start['user_code'] ?? ''}'.trim();
    final verificationUrl =
        '${start['verification_url'] ?? start['verification_uri'] ?? 'https://www.google.com/device'}'
            .trim();
    final intervalSec = (start['interval'] as num?)?.toInt() ?? 5;
    if (deviceCode.isEmpty || userCode.isEmpty) {
      throw StateError('ytmusic_device_start_failed: $start');
    }

    onUserCode?.call(userCode, verificationUrl);
    AppLogger.info(
      'YT Music device flow started',
      tag: 'ytmusic',
      context: {'userCode': userCode},
    );

    final verify = Uri.tryParse(verificationUrl);
    if (verify != null) {
      try {
        await launchUrl(verify, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    final deadline = DateTime.now().add(timeout);
    var interval = Duration(seconds: intervalSec.clamp(3, 15));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      final poll = await _postJson(
        '/integrations/ytmusic/oauth-device/poll',
        {'deviceCode': deviceCode},
      );
      final err = '${poll['error'] ?? ''}'.trim();
      if (err == 'authorization_pending') {
        continue;
      }
      if (err == 'slow_down') {
        interval += const Duration(seconds: 2);
        continue;
      }
      if (err == 'access_denied' || err == 'expired_token') {
        throw StateError('ytmusic_oauth_$err');
      }
      final access = '${poll['access_token'] ?? ''}'.trim();
      final refresh = '${poll['refresh_token'] ?? ''}'.trim();
      final expiresIn = (poll['expires_in'] as num?)?.toInt() ?? 3600;
      if (access.isEmpty) {
        if (err.isNotEmpty) throw StateError('ytmusic_oauth_$err');
        continue;
      }
      return YtMusicConnection(
        id: _uuid.v4(),
        label: label.trim().isEmpty ? 'YouTube Music' : label.trim(),
        authMode: YtMusicAuthMode.oauth,
        accessToken: access,
        refreshToken: refresh.isEmpty ? access : refresh,
        expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      );
    }
    throw StateError('ytmusic_oauth_timeout');
  }

  Future<YtMusicConnection> refresh(YtMusicConnection connection) async {
    if (connection.isBrowser) return connection;
    final json = await _postJson(
      '/integrations/ytmusic/oauth-refresh',
      {'refreshToken': connection.refreshToken},
    );
    final access = '${json['access_token'] ?? ''}'.trim();
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    if (access.isEmpty) {
      throw StateError('ytmusic_refresh_failed: $json');
    }
    final newRefresh = '${json['refresh_token'] ?? ''}'.trim();
    return connection.copyWith(
      accessToken: access,
      refreshToken: newRefresh.isEmpty ? connection.refreshToken : newRefresh,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }
}
