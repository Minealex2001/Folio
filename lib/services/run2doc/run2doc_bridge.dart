import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'run2doc_markdown_codec.dart';

class Run2DocClientIdentity {
  const Run2DocClientIdentity({
    required this.appId,
    required this.appName,
    required this.appVersion,
    required this.integrationVersion,
  });

  final String appId;
  final String appName;
  final String appVersion;
  final String integrationVersion;
}

class Run2DocLaunchSession {
  static const int fixedPort = 45831;

  const Run2DocLaunchSession({
    required this.sessionId,
    required this.port,
    required this.nonce,
    required this.expiresAtUtc,
    required this.client,
  });

  final String sessionId;
  final int port;
  final String nonce;
  final DateTime expiresAtUtc;
  final Run2DocClientIdentity client;

  static Run2DocLaunchSession fromLaunchUri(
    Uri uri, {
    required Run2DocClientIdentity client,
  }) {
    final sessionId = uri.queryParameters['session']?.trim() ?? '';
    final nonce = uri.queryParameters['nonce']?.trim() ?? '';
    final appVersion = uri.queryParameters['appVersion']?.trim() ?? '';
    final integrationVersion =
        uri.queryParameters['integrationVersion']?.trim() ?? '';
    if (uri.scheme != 'folio' || uri.host != 'import') {
      throw const FormatException('Unsupported launch URI.');
    }
    if (sessionId.isEmpty ||
        nonce.isEmpty ||
        appVersion.isEmpty ||
        integrationVersion.isEmpty) {
      throw const FormatException(
        'Missing session, nonce, app version, or integration version.',
      );
    }
    return Run2DocLaunchSession(
      sessionId: sessionId,
      port: fixedPort,
      nonce: nonce,
      expiresAtUtc: DateTime.now().toUtc().add(
        Run2DocBridgeController.sessionTtl,
      ),
      client: client,
    );
  }
}

class Run2DocMarkdownImportRequest {
  const Run2DocMarkdownImportRequest({
    required this.sessionId,
    required this.title,
    required this.markdown,
    required this.importMode,
    required this.clientAppId,
    required this.clientAppName,
    this.sourceApp,
    this.sourceUrl,
    this.parentPageId,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final String title;
  final String markdown;
  final FolioMarkdownImportMode importMode;
  final String clientAppId;
  final String clientAppName;
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
      clientAppId: (json['clientAppId'] as String? ?? '').trim(),
      clientAppName: (json['clientAppName'] as String? ?? '').trim(),
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

/// Petición para actualizar una página ya importada (PATCH /pages/{pageId}).
/// Solo soporta los modos [FolioMarkdownImportMode.replaceCurrentPage] y
/// [FolioMarkdownImportMode.appendToCurrentPage].
/// Puede enviar markdown en [markdown] o bloques JSON en [blocks]; si ambos
/// están presentes, [blocks] tiene precedencia (ver [isJsonMode]).
class Run2DocPageUpdateRequest {
  const Run2DocPageUpdateRequest({
    required this.pageId,
    required this.sessionId,
    this.markdown = '',
    required this.importMode,
    required this.clientAppId,
    required this.clientAppName,
    this.title,
    this.sourceApp,
    this.sourceUrl,
    this.blocks,
    this.metadata = const <String, Object?>{},
  });

  final String pageId;
  final String sessionId;
  final String markdown;

  /// Bloques JSON preconstruidos; si no es null y no está vacío, se usa en
  /// lugar de [markdown] (ver [isJsonMode]).
  final List<Map<String, dynamic>>? blocks;

  /// `true` cuando la petición lleva bloques JSON en lugar de Markdown.
  bool get isJsonMode => blocks != null && blocks!.isNotEmpty;

  /// Solo [FolioMarkdownImportMode.replaceCurrentPage] o
  /// [FolioMarkdownImportMode.appendToCurrentPage].
  final FolioMarkdownImportMode importMode;
  final String clientAppId;
  final String clientAppName;
  final String? title;
  final String? sourceApp;
  final String? sourceUrl;
  final Map<String, Object?> metadata;

  static Run2DocPageUpdateRequest fromJson(
    String pageId,
    Map<String, dynamic> json,
  ) {
    final sessionId = (json['sessionId'] as String? ?? '').trim();
    final markdown = (json['markdown'] as String? ?? '').trim();
    final blocksRaw = json['blocks'];
    List<Map<String, dynamic>>? blocks;
    if (blocksRaw is List && blocksRaw.isNotEmpty) {
      blocks = blocksRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (sessionId.isEmpty) {
      throw const FormatException('Field "sessionId" is required.');
    }
    if (markdown.isEmpty && (blocks == null || blocks.isEmpty)) {
      throw const FormatException('Field "markdown" or "blocks" is required.');
    }
    final mode = _parseUpdateMode(
      json['importMode'] as String? ?? 'replaceCurrentPage',
    );
    return Run2DocPageUpdateRequest(
      pageId: pageId,
      sessionId: sessionId,
      markdown: markdown,
      blocks: blocks,
      importMode: mode,
      clientAppId: (json['clientAppId'] as String? ?? '').trim(),
      clientAppName: (json['clientAppName'] as String? ?? '').trim(),
      title: (json['title'] as String?)?.trim(),
      sourceApp: (json['sourceApp'] as String?)?.trim(),
      sourceUrl: (json['sourceUrl'] as String?)?.trim(),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const <String, Object?>{},
    );
  }

  static FolioMarkdownImportMode _parseUpdateMode(String raw) {
    switch (raw.trim()) {
      case 'appendToCurrentPage':
        return FolioMarkdownImportMode.appendToCurrentPage;
      case 'replaceCurrentPage':
      default:
        return FolioMarkdownImportMode.replaceCurrentPage;
    }
  }
}

/// Petición para crear una nueva página desde bloques JSON (POST /imports/json).
class Run2DocJsonImportRequest {
  const Run2DocJsonImportRequest({
    required this.sessionId,
    required this.title,
    required this.blocks,
    required this.clientAppId,
    required this.clientAppName,
    this.parentPageId,
    this.sourceApp,
    this.sourceUrl,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final String title;
  final List<Map<String, dynamic>> blocks;
  final String clientAppId;
  final String clientAppName;
  final String? parentPageId;
  final String? sourceApp;
  final String? sourceUrl;
  final Map<String, Object?> metadata;

  static Run2DocJsonImportRequest fromJson(Map<String, dynamic> json) {
    final sessionId = (json['sessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) {
      throw const FormatException('Field "sessionId" is required.');
    }
    final blocksRaw = json['blocks'];
    if (blocksRaw is! List || blocksRaw.isEmpty) {
      throw const FormatException(
        'Field "blocks" is required and must be a non-empty array.',
      );
    }
    final blocks = blocksRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (blocks.isEmpty) {
      throw const FormatException(
        'Field "blocks" must contain valid block objects.',
      );
    }
    return Run2DocJsonImportRequest(
      sessionId: sessionId,
      title: (json['title'] as String? ?? '').trim(),
      blocks: blocks,
      clientAppId: (json['clientAppId'] as String? ?? '').trim(),
      clientAppName: (json['clientAppName'] as String? ?? '').trim(),
      parentPageId: (json['parentPageId'] as String?)?.trim(),
      sourceApp: (json['sourceApp'] as String?)?.trim(),
      sourceUrl: (json['sourceUrl'] as String?)?.trim(),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const <String, Object?>{},
    );
  }
}

class Run2DocBridgeController {
  static const headerAppId = 'x-folio-app-id';
  static const headerAppName = 'x-folio-app-name';
  static const headerAppVersion = 'x-folio-app-version';
  static const headerIntegrationVersion = 'x-folio-integration-version';
  static const headerSecret = 'x-folio-integration-secret';
  static const supportedIntegrationVersion = '1';

  Run2DocBridgeController({
    required Future<FolioMarkdownImportResult> Function(
      Run2DocMarkdownImportRequest request,
    )
    onImport,
    required Future<FolioMarkdownImportResult> Function(
      Run2DocPageUpdateRequest request,
    )
    onUpdate,
    required Future<List<Map<String, Object?>>> Function(String clientAppId)
    onListPages,
    required Future<FolioMarkdownImportResult> Function(
      Run2DocJsonImportRequest request,
    )
    onImportJson,
    required Future<bool> Function(Run2DocClientIdentity client)
    onApproveClient,
    required Future<void> Function(Run2DocClientIdentity client)
    onClientObserved,
    required bool Function(Run2DocClientIdentity client) isClientApproved,
    required String Function() secretProvider,
    required Map<String, Object?> Function() appInfoProvider,
    this.onEvent,
  }) : _onImport = onImport,
       _onUpdate = onUpdate,
       _onListPages = onListPages,
       _onImportJson = onImportJson,
       _onApproveClient = onApproveClient,
       _onClientObserved = onClientObserved,
       _isClientApproved = isClientApproved,
       _secretProvider = secretProvider,
       _appInfoProvider = appInfoProvider;

  final Future<FolioMarkdownImportResult> Function(
    Run2DocMarkdownImportRequest request,
  )
  _onImport;
  final Future<FolioMarkdownImportResult> Function(
    Run2DocPageUpdateRequest request,
  )
  _onUpdate;
  final Future<List<Map<String, Object?>>> Function(String clientAppId)
  _onListPages;
  final Future<FolioMarkdownImportResult> Function(
    Run2DocJsonImportRequest request,
  )
  _onImportJson;
  final Future<bool> Function(Run2DocClientIdentity client) _onApproveClient;
  final Future<void> Function(Run2DocClientIdentity client) _onClientObserved;
  final bool Function(Run2DocClientIdentity client) _isClientApproved;
  final String Function() _secretProvider;
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
    final current = _activeSession;
    final requestedSessionId = uri.queryParameters['session']?.trim() ?? '';
    final appId = uri.queryParameters['appId']?.trim();
    final appName = uri.queryParameters['appName']?.trim();
    final appVersion = uri.queryParameters['appVersion']?.trim();
    final integrationVersion = uri.queryParameters['integrationVersion']
        ?.trim();
    if ((appId == null || appId.isEmpty) &&
        current != null &&
        current.sessionId == requestedSessionId) {
      _armExpiry(current.expiresAtUtc);
      return current;
    }
    if (appId == null || appId.isEmpty) {
      throw const FormatException('Missing appId.');
    }
    final client = Run2DocClientIdentity(
      appId: appId,
      appName: (appName?.isNotEmpty ?? false) ? appName! : appId,
      appVersion: (appVersion?.isNotEmpty ?? false) ? appVersion! : '',
      integrationVersion: (integrationVersion?.isNotEmpty ?? false)
          ? integrationVersion!
          : '',
    );
    final session = Run2DocLaunchSession.fromLaunchUri(uri, client: client);
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

  Run2DocLaunchSession createSession(Run2DocClientIdentity client) {
    final now = DateTime.now().toUtc();
    final session = Run2DocLaunchSession(
      sessionId: _newSessionId(),
      port: Run2DocLaunchSession.fixedPort,
      nonce: _newNonce(),
      expiresAtUtc: now.add(sessionTtl),
      client: client,
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
    final path = request.uri.path;
    final isPageUpdate =
        request.method == 'PATCH' && path.startsWith('/pages/');
    final requiresSecret =
        path == '/health' ||
        path == '/app' ||
        path == '/status' ||
        path == '/imports/markdown' ||
        path == '/imports/json' ||
        path == '/pages' ||
        path == '/session/start' ||
        path == '/session/new' ||
        path == '/start' ||
        isPageUpdate;

    Run2DocClientIdentity? client;
    if (requiresSecret) {
      final mayPromptApproval =
          request.method == 'POST' &&
          (path == '/session/start' ||
              path == '/session/new' ||
              path == '/start');
      final auth = await _authorizeClient(
        request,
        mayPromptApproval: mayPromptApproval,
      );
      if (auth.error != null) {
        await _writeJson(request.response, auth.statusCode!, {
          'ok': false,
          'error': auth.error,
          'message': auth.message,
        });
        return;
      }
      client = auth.client!;
    }

    if (request.method == 'GET' && path == '/health') {
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'appRunning': true,
        'port': Run2DocLaunchSession.fixedPort,
        'importSessionActive': session != null,
        'sessionId': session?.sessionId,
        'state': session == null ? 'idle' : 'ready',
        'clientApproved': client != null && _isClientApproved(client),
        'integrationVersion': supportedIntegrationVersion,
      });
      return;
    }

    if (request.method == 'GET' && (path == '/app' || path == '/status')) {
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'appRunning': true,
        'bridgePort': Run2DocLaunchSession.fixedPort,
        'importSessionActive': session != null,
        'sessionId': session?.sessionId,
        'clientApproved': client != null && _isClientApproved(client),
        'client': client == null
            ? null
            : {
                'appId': client.appId,
                'appName': client.appName,
                'appVersion': client.appVersion,
                'integrationVersion': client.integrationVersion,
              },
        'integrationVersion': supportedIntegrationVersion,
        'app': _appInfoProvider(),
      });
      return;
    }

    if (request.method == 'POST' &&
        (path == '/session/start' ||
            path == '/session/new' ||
            path == '/start')) {
      final next = createSession(client!);
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'sessionId': next.sessionId,
        'nonce': next.nonce,
        'port': next.port,
        'appId': next.client.appId,
        'appName': next.client.appName,
        'appVersion': next.client.appVersion,
        'integrationVersion': next.client.integrationVersion,
        'expiresAtUtc': next.expiresAtUtc.toIso8601String(),
        'expiresInSeconds': sessionTtl.inSeconds,
        'deepLink': _buildDeepLink(next),
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

    // ---- GET /pages ---------------------------------------------------
    if (request.method == 'GET' && path == '/pages') {
      final pagesAuth =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (pagesAuth.trim() != 'Bearer ${session.nonce}') {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'UNAUTHORIZED',
          'message': 'Invalid session token.',
        });
        return;
      }
      final querySessionId = (request.uri.queryParameters['sessionId'] ?? '')
          .trim();
      if (querySessionId != session.sessionId) {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'SESSION_MISMATCH',
          'message': 'Request sessionId does not match the active session.',
        });
        return;
      }
      final c = client!;
      if (c.appId != session.client.appId) {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'CLIENT_MISMATCH',
          'message': 'Request app does not match the active session client.',
        });
        return;
      }
      try {
        final pages = await _onListPages(c.appId);
        await _writeJson(request.response, HttpStatus.ok, {
          'ok': true,
          'sessionId': session.sessionId,
          'pages': pages,
        });
      } on StateError catch (e) {
        final isLocked = e.message.contains('Unlock Folio');
        await _writeJson(
          request.response,
          isLocked ? HttpStatus.locked : HttpStatus.internalServerError,
          {
            'ok': false,
            'error': isLocked ? 'VAULT_LOCKED' : 'LIST_FAILED',
            'message': e.message,
          },
        );
      } catch (e) {
        await _writeJson(request.response, HttpStatus.internalServerError, {
          'ok': false,
          'error': 'LIST_FAILED',
          'message': e.toString(),
        });
      }
      return;
    }

    // ---- PATCH /pages/{pageId} ----------------------------------------
    if (isPageUpdate) {
      final pathSegments = path.split('/');
      final pageId = pathSegments.length >= 3 ? pathSegments[2] : '';
      if (pageId.isEmpty) {
        await _writeJson(request.response, HttpStatus.badRequest, {
          'ok': false,
          'error': 'INVALID_PATH',
          'message': 'Missing pageId in path.',
        });
        return;
      }
      final updateAuth =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (updateAuth.trim() != 'Bearer ${session.nonce}') {
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
        final c = client!;
        final payload = Run2DocPageUpdateRequest.fromJson(
          pageId,
          Map<String, dynamic>.from(decoded),
        ).copyWithClient(c);
        if (c.appId != session.client.appId) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'ok': false,
            'error': 'CLIENT_MISMATCH',
            'message': 'Request app does not match the active session client.',
          });
          return;
        }
        if (payload.sessionId != session.sessionId) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'ok': false,
            'error': 'SESSION_MISMATCH',
            'message': 'Request sessionId does not match the active session.',
          });
          return;
        }
        final result = await _onUpdate(payload);
        onEvent?.call('Actualización Run2Doc completada: ${result.pageTitle}.');
        await _writeJson(request.response, HttpStatus.ok, {
          'ok': true,
          'sessionId': session.sessionId,
          'pageId': result.pageId,
          'title': result.pageTitle,
          'blockCount': result.blockCount,
          'mode': result.mode.name,
          'message': 'Updated successfully',
        });
      } on FormatException catch (e) {
        await _writeJson(request.response, HttpStatus.badRequest, {
          'ok': false,
          'error': 'INVALID_PAYLOAD',
          'message': e.message,
        });
      } on StateError catch (e) {
        final isLocked = e.message.contains('Unlock Folio');
        final isNotOwner = e.message == 'NOT_OWNER';
        final isNotFound = e.message == 'PAGE_NOT_FOUND';
        final statusCode = isLocked
            ? HttpStatus.locked
            : isNotOwner
            ? HttpStatus.forbidden
            : isNotFound
            ? HttpStatus.notFound
            : HttpStatus.conflict;
        final errorCode = isLocked
            ? 'VAULT_LOCKED'
            : isNotOwner
            ? 'FORBIDDEN'
            : isNotFound
            ? 'PAGE_NOT_FOUND'
            : 'UPDATE_REJECTED';
        await _writeJson(request.response, statusCode, {
          'ok': false,
          'error': errorCode,
          'message': isNotOwner ? 'App did not import this page.' : e.message,
        });
      } on HttpException catch (e) {
        await _writeJson(request.response, HttpStatus.requestEntityTooLarge, {
          'ok': false,
          'error': 'PAYLOAD_TOO_LARGE',
          'message': e.message,
        });
      } catch (e) {
        await _writeJson(request.response, HttpStatus.internalServerError, {
          'ok': false,
          'error': 'UPDATE_FAILED',
          'message': e.toString(),
        });
      }
      return;
    }

    if (request.method == 'POST' && path == '/imports/json') {
      final jsonAuth =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (jsonAuth.trim() != 'Bearer ${session.nonce}') {
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
          'message': 'JSON payload exceeds the maximum allowed size.',
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
        final c = client!;
        final payload = Run2DocJsonImportRequest.fromJson(
          Map<String, dynamic>.from(decoded),
        ).copyWithClient(c);
        if (c.appId != session.client.appId) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'ok': false,
            'error': 'CLIENT_MISMATCH',
            'message': 'Request app does not match the active session client.',
          });
          return;
        }
        if (payload.sessionId != session.sessionId) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'ok': false,
            'error': 'SESSION_MISMATCH',
            'message': 'Request sessionId does not match the active session.',
          });
          return;
        }
        final result = await _onImportJson(payload);
        onEvent?.call(
          'Importación JSON Run2Doc completada: ${result.pageTitle}.',
        );
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
      return;
    }

    if (request.method != 'POST' || path != '/imports/markdown') {
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
      final c = client!;
      final payload = Run2DocMarkdownImportRequest.fromJson(
        Map<String, dynamic>.from(decoded),
      ).copyWithClient(c);
      if (c.appId != session.client.appId) {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'CLIENT_MISMATCH',
          'message': 'Request app does not match the active session client.',
        });
        return;
      }
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

  String _buildDeepLink(Run2DocLaunchSession session) {
    return 'folio://import?session=${Uri.encodeComponent(session.sessionId)}'
        '&nonce=${Uri.encodeComponent(session.nonce)}'
        '&appId=${Uri.encodeComponent(session.client.appId)}'
        '&appName=${Uri.encodeComponent(session.client.appName)}'
        '&appVersion=${Uri.encodeComponent(session.client.appVersion)}'
        '&integrationVersion=${Uri.encodeComponent(session.client.integrationVersion)}';
  }

  Future<_Run2DocClientAuth> _authorizeClient(
    HttpRequest request, {
    required bool mayPromptApproval,
  }) async {
    final secret = request.headers.value(headerSecret)?.trim() ?? '';
    final appId = request.headers.value(headerAppId)?.trim() ?? '';
    final appNameHeader = request.headers.value(headerAppName)?.trim() ?? '';
    final appVersionHeader =
        request.headers.value(headerAppVersion)?.trim() ?? '';
    final integrationVersionHeader =
        request.headers.value(headerIntegrationVersion)?.trim() ?? '';
    if (appId.isEmpty) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_APP_ID',
        message: 'Header X-Folio-App-Id is required.',
      );
    }
    if (appVersionHeader.isEmpty) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_APP_VERSION',
        message: 'Header X-Folio-App-Version is required.',
      );
    }
    if (integrationVersionHeader.isEmpty) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_INTEGRATION_VERSION',
        message: 'Header X-Folio-Integration-Version is required.',
      );
    }
    if (integrationVersionHeader != supportedIntegrationVersion) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'UNSUPPORTED_INTEGRATION_VERSION',
        message: 'Unsupported X-Folio-Integration-Version.',
      );
    }
    if (secret.isEmpty) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.unauthorized,
        error: 'MISSING_SECRET',
        message: 'Header X-Folio-Integration-Secret is required.',
      );
    }
    if (secret != _secretProvider()) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.unauthorized,
        error: 'INVALID_SECRET',
        message: 'Invalid integration secret.',
      );
    }
    final client = Run2DocClientIdentity(
      appId: appId,
      appName: appNameHeader.isEmpty ? appId : appNameHeader,
      appVersion: appVersionHeader,
      integrationVersion: integrationVersionHeader,
    );
    if (_isClientApproved(client)) {
      await _onClientObserved(client);
      return _Run2DocClientAuth.success(client);
    }
    if (!mayPromptApproval) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.forbidden,
        error: 'APP_NOT_APPROVED',
        message: 'This app has not been approved in Folio yet.',
      );
    }
    final approved = await _onApproveClient(client);
    if (!approved) {
      return const _Run2DocClientAuth.error(
        statusCode: HttpStatus.forbidden,
        error: 'APP_NOT_APPROVED',
        message: 'The app was not approved by the user.',
      );
    }
    return _Run2DocClientAuth.success(client);
  }
}

extension on Run2DocMarkdownImportRequest {
  Run2DocMarkdownImportRequest copyWithClient(Run2DocClientIdentity client) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return Run2DocMarkdownImportRequest(
      sessionId: sessionId,
      title: title,
      markdown: markdown,
      importMode: importMode,
      clientAppId: client.appId,
      clientAppName: client.appName,
      sourceApp: sourceApp,
      sourceUrl: sourceUrl,
      parentPageId: parentPageId,
      metadata: nextMetadata,
    );
  }
}

extension on Run2DocPageUpdateRequest {
  Run2DocPageUpdateRequest copyWithClient(Run2DocClientIdentity client) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return Run2DocPageUpdateRequest(
      pageId: pageId,
      sessionId: sessionId,
      markdown: markdown,
      blocks: blocks,
      importMode: importMode,
      clientAppId: client.appId,
      clientAppName: client.appName,
      title: title,
      sourceApp: sourceApp,
      sourceUrl: sourceUrl,
      metadata: nextMetadata,
    );
  }
}

extension on Run2DocJsonImportRequest {
  Run2DocJsonImportRequest copyWithClient(Run2DocClientIdentity client) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return Run2DocJsonImportRequest(
      sessionId: sessionId,
      title: title,
      blocks: blocks,
      clientAppId: client.appId,
      clientAppName: client.appName,
      parentPageId: parentPageId,
      sourceApp: sourceApp,
      sourceUrl: sourceUrl,
      metadata: nextMetadata,
    );
  }
}

class _Run2DocClientAuth {
  const _Run2DocClientAuth.success(this.client)
    : statusCode = null,
      error = null,
      message = null;

  const _Run2DocClientAuth.error({
    required this.statusCode,
    required this.error,
    required this.message,
  }) : client = null;

  final Run2DocClientIdentity? client;
  final int? statusCode;
  final String? error;
  final String? message;
}
