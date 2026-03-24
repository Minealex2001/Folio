import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'run2doc_markdown_codec.dart';

class Run2DocLaunchSession {
  static const int fixedPort = 45831;

  const Run2DocLaunchSession({
    required this.sessionId,
    required this.port,
    required this.nonce,
    required this.expiresAtUtc,
  });

  final String sessionId;
  final int port;
  final String nonce;
  final DateTime expiresAtUtc;

  static Run2DocLaunchSession fromLaunchUri(Uri uri) {
    final sessionId = uri.queryParameters['session']?.trim() ?? '';
    final nonce = uri.queryParameters['nonce']?.trim() ?? '';
    if (uri.scheme != 'folio' || uri.host != 'import') {
      throw const FormatException('Unsupported launch URI.');
    }
    if (sessionId.isEmpty || nonce.isEmpty) {
      throw const FormatException('Missing session or nonce.');
    }
    return Run2DocLaunchSession(
      sessionId: sessionId,
      port: fixedPort,
      nonce: nonce,
      expiresAtUtc: DateTime.now().toUtc().add(
        Run2DocBridgeController.sessionTtl,
      ),
    );
  }
}

class Run2DocMarkdownImportRequest {
  const Run2DocMarkdownImportRequest({
    required this.sessionId,
    required this.title,
    required this.markdown,
    required this.importMode,
    this.sourceApp,
    this.sourceUrl,
    this.parentPageId,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final String title;
  final String markdown;
  final FolioMarkdownImportMode importMode;
  final String? sourceApp;
  final String? sourceUrl;
  final String? parentPageId;
  final Map<String, Object?> metadata;

  static Run2DocMarkdownImportRequest fromJson(Map<String, dynamic> json) {
    final sessionId = (json['sessionId'] as String? ?? '').trim();
    final title = (json['title'] as String? ?? '').trim();
    final markdown = (json['markdown'] as String? ?? '').trim();
    final mode = _parseImportMode(json['importMode'] as String? ?? 'newPage');
    if (sessionId.isEmpty) {
      throw const FormatException('Field "sessionId" is required.');
    }
    if (markdown.isEmpty) {
      throw const FormatException('Field "markdown" is required.');
    }
    return Run2DocMarkdownImportRequest(
      sessionId: sessionId,
      title: title.isEmpty ? 'Imported page' : title,
      markdown: markdown,
      importMode: mode,
      sourceApp: (json['sourceApp'] as String?)?.trim(),
      sourceUrl: (json['sourceUrl'] as String?)?.trim(),
      parentPageId: (json['parentPageId'] as String?)?.trim(),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const <String, Object?>{},
    );
  }

  static FolioMarkdownImportMode _parseImportMode(String raw) {
    switch (raw.trim()) {
      case 'replaceCurrentPage':
        return FolioMarkdownImportMode.replaceCurrentPage;
      case 'appendToCurrentPage':
        return FolioMarkdownImportMode.appendToCurrentPage;
      case 'newPage':
      default:
        return FolioMarkdownImportMode.newPage;
    }
  }
}

class Run2DocBridgeController {
  Run2DocBridgeController({
    required Future<FolioMarkdownImportResult> Function(
      Run2DocMarkdownImportRequest request,
    )
    onImport,
    required Map<String, Object?> Function() appInfoProvider,
    this.onEvent,
  }) : _onImport = onImport,
       _appInfoProvider = appInfoProvider;

  final Future<FolioMarkdownImportResult> Function(
    Run2DocMarkdownImportRequest request,
  )
  _onImport;
  final Map<String, Object?> Function() _appInfoProvider;
  final void Function(String message)? onEvent;

  static const int maxPayloadBytes = 2 * 1024 * 1024;
  static const Duration sessionTtl = Duration(minutes: 5);
  static final Random _secureRandom = Random.secure();

  HttpServer? _server;
  Run2DocLaunchSession? _activeSession;
  Timer? _expiryTimer;

  Run2DocLaunchSession? get activeSession => _activeSession;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      Run2DocLaunchSession.fixedPort,
      shared: false,
    );
    unawaited(_listen(_server!));
  }

  Future<Run2DocLaunchSession> activateFromUri(Uri uri) async {
    await start();
    final session = Run2DocLaunchSession.fromLaunchUri(uri);
    final current = _activeSession;
    if (current != null &&
        current.sessionId == session.sessionId &&
        current.nonce == session.nonce) {
      _armExpiry(current.expiresAtUtc);
      return current;
    }
    _activeSession = session;
    _armExpiry(session.expiresAtUtc);
    return session;
  }

  Run2DocLaunchSession createSession() {
    final now = DateTime.now().toUtc();
    final session = Run2DocLaunchSession(
      sessionId: _newSessionId(),
      port: Run2DocLaunchSession.fixedPort,
      nonce: _newNonce(),
      expiresAtUtc: now.add(sessionTtl),
    );
    _activeSession = session;
    _armExpiry(session.expiresAtUtc);
    return session;
  }

  Future<void> clearActiveSession() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _activeSession = null;
  }

  Future<void> close() async {
    await clearActiveSession();
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> dispose() => close();

  Future<void> _listen(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handleRequest(request));
      }
    } catch (_) {
      // El cierre explícito del servidor termina el stream.
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final session = _activeSession;

    if (request.method == 'GET' && request.uri.path == '/health') {
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'appRunning': true,
        'port': Run2DocLaunchSession.fixedPort,
        'importSessionActive': session != null,
        'sessionId': session?.sessionId,
        'state': session == null ? 'idle' : 'ready',
      });
      return;
    }

    if (request.method == 'GET' &&
        (request.uri.path == '/app' || request.uri.path == '/status')) {
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'appRunning': true,
        'bridgePort': Run2DocLaunchSession.fixedPort,
        'importSessionActive': session != null,
        'sessionId': session?.sessionId,
        'app': _appInfoProvider(),
      });
      return;
    }

    if (request.method == 'POST' &&
        (request.uri.path == '/session/start' ||
            request.uri.path == '/session/new' ||
            request.uri.path == '/start')) {
      final next = createSession();
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'sessionId': next.sessionId,
        'nonce': next.nonce,
        'port': next.port,
        'expiresAtUtc': next.expiresAtUtc.toIso8601String(),
        'expiresInSeconds': sessionTtl.inSeconds,
        'deepLink':
            'folio://import?session=${Uri.encodeComponent(next.sessionId)}&nonce=${Uri.encodeComponent(next.nonce)}',
      });
      return;
    }

    if (session == null) {
      await _writeJson(request.response, HttpStatus.serviceUnavailable, {
        'ok': false,
        'error': 'NO_ACTIVE_SESSION',
        'message': 'No active Run2Doc import session.',
      });
      return;
    }

    if (request.method != 'POST' || request.uri.path != '/imports/markdown') {
      await _writeJson(request.response, HttpStatus.notFound, {
        'ok': false,
        'error': 'NOT_FOUND',
        'message': 'Unsupported endpoint.',
      });
      return;
    }

    final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final expected = 'Bearer ${session.nonce}';
    if (auth.trim() != expected) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'ok': false,
        'error': 'UNAUTHORIZED',
        'message': 'Invalid session token.',
      });
      return;
    }

    if (request.contentLength > maxPayloadBytes) {
      await _writeJson(request.response, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': 'PAYLOAD_TOO_LARGE',
        'message': 'Markdown payload exceeds the maximum allowed size.',
      });
      return;
    }

    try {
      final rawBody = await utf8.decoder.bind(request).join();
      if (utf8.encode(rawBody).length > maxPayloadBytes) {
        throw const HttpException('Payload too large.');
      }
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map) {
        throw const FormatException('JSON object expected.');
      }
      final payload = Run2DocMarkdownImportRequest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (payload.sessionId != session.sessionId) {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'SESSION_MISMATCH',
          'message': 'Request sessionId does not match the active session.',
        });
        return;
      }
      final result = await _onImport(payload);
      onEvent?.call('Importación Run2Doc completada: ${result.pageTitle}.');
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'sessionId': session.sessionId,
        'pageId': result.pageId,
        'title': result.pageTitle,
        'blockCount': result.blockCount,
        'mode': result.mode.name,
        'message': 'Imported successfully',
      });
    } on FormatException catch (e) {
      await _writeJson(request.response, HttpStatus.badRequest, {
        'ok': false,
        'error': 'INVALID_PAYLOAD',
        'message': e.message,
      });
    } on StateError catch (e) {
      final isLocked = e.message.contains('Unlock Folio');
      await _writeJson(
        request.response,
        isLocked ? HttpStatus.locked : HttpStatus.conflict,
        {
          'ok': false,
          'error': isLocked ? 'VAULT_LOCKED' : 'IMPORT_REJECTED',
          'message': e.message,
        },
      );
    } on HttpException catch (e) {
      await _writeJson(request.response, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': 'PAYLOAD_TOO_LARGE',
        'message': e.message,
      });
    } catch (e) {
      await _writeJson(request.response, HttpStatus.internalServerError, {
        'ok': false,
        'error': 'IMPORT_FAILED',
        'message': e.toString(),
      });
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> payload,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }

  void _armExpiry(DateTime expiresAtUtc) {
    _expiryTimer?.cancel();
    final remaining = expiresAtUtc.difference(DateTime.now().toUtc());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () async {
        await clearActiveSession();
      },
    );
  }

  static String _newSessionId() {
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(16);
    final suffix = _randomToken(8);
    return '${ms}_$suffix';
  }

  static String _newNonce() => _randomToken(24);

  static String _randomToken(int byteLength) {
    final bytes = List<int>.generate(
      byteLength,
      (_) => _secureRandom.nextInt(256),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
