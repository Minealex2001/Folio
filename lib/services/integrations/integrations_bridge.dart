import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'integrations_markdown_codec.dart';

class IntegrationsClientIdentity {
  const IntegrationsClientIdentity({
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

class IntegrationsLaunchSession {
  static const int fixedPort = 45831;

  const IntegrationsLaunchSession({
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
  final IntegrationsClientIdentity client;

  static IntegrationsLaunchSession fromLaunchUri(
    Uri uri, {
    required IntegrationsClientIdentity client,
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
    return IntegrationsLaunchSession(
      sessionId: sessionId,
      port: fixedPort,
      nonce: nonce,
      expiresAtUtc: DateTime.now().toUtc().add(
        IntegrationsBridgeController.sessionTtl,
      ),
      client: client,
    );
  }
}

class IntegrationsMarkdownImportRequest {
  const IntegrationsMarkdownImportRequest({
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

  static IntegrationsMarkdownImportRequest fromJson(Map<String, dynamic> json) {
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
    return IntegrationsMarkdownImportRequest(
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
class IntegrationsPageUpdateRequest {
  const IntegrationsPageUpdateRequest({
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

  static IntegrationsPageUpdateRequest fromJson(
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
    return IntegrationsPageUpdateRequest(
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
class IntegrationsJsonImportRequest {
  const IntegrationsJsonImportRequest({
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

  static IntegrationsJsonImportRequest fromJson(Map<String, dynamic> json) {
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
    return IntegrationsJsonImportRequest(
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

class IntegrationsCustomEmojiUpsertRequest {
  const IntegrationsCustomEmojiUpsertRequest({
    required this.emojiId,
    required this.sessionId,
    required this.clientAppId,
    required this.clientAppName,
    required this.label,
    required this.source,
    required this.filePath,
    required this.mimeType,
    required this.createdAtMs,
  });

  final String emojiId;
  final String sessionId;
  final String clientAppId;
  final String clientAppName;
  final String label;
  final String source;
  final String filePath;
  final String mimeType;
  final int createdAtMs;

  static IntegrationsCustomEmojiUpsertRequest fromJson(
    String emojiId,
    Map<String, dynamic> json,
  ) {
    final sessionId = (json['sessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) {
      throw const FormatException('Field "sessionId" is required.');
    }
    final normalizedId = emojiId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Emoji id is required.');
    }
    final label = (json['label'] as String? ?? '').trim();
    final source = (json['source'] as String? ?? '').trim();
    final filePath = (json['filePath'] as String? ?? '').trim();
    final mimeType = (json['mimeType'] as String? ?? '').trim();
    if (filePath.isEmpty) {
      throw const FormatException('Field "filePath" is required.');
    }
    if (mimeType.isEmpty) {
      throw const FormatException('Field "mimeType" is required.');
    }
    return IntegrationsCustomEmojiUpsertRequest(
      emojiId: normalizedId,
      sessionId: sessionId,
      clientAppId: (json['clientAppId'] as String? ?? '').trim(),
      clientAppName: (json['clientAppName'] as String? ?? '').trim(),
      label: label,
      source: source,
      filePath: filePath,
      mimeType: mimeType,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class IntegrationsCustomEmojiDeleteRequest {
  const IntegrationsCustomEmojiDeleteRequest({
    required this.emojiId,
    required this.sessionId,
    required this.clientAppId,
    required this.clientAppName,
  });

  final String emojiId;
  final String sessionId;
  final String clientAppId;
  final String clientAppName;

  static IntegrationsCustomEmojiDeleteRequest fromRequest(
    String emojiId,
    HttpRequest request,
  ) {
    final normalizedId = emojiId.trim();
    final sessionId = (request.uri.queryParameters['sessionId'] ?? '').trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Emoji id is required.');
    }
    if (sessionId.isEmpty) {
      throw const FormatException('Query parameter "sessionId" is required.');
    }
    return IntegrationsCustomEmojiDeleteRequest(
      emojiId: normalizedId,
      sessionId: sessionId,
      clientAppId: '',
      clientAppName: '',
    );
  }
}

class IntegrationsBridgeController {
  static const headerAppId = 'x-folio-app-id';
  static const headerAppName = 'x-folio-app-name';
  static const headerAppVersion = 'x-folio-app-version';
  static const headerIntegrationVersion = 'x-folio-integration-version';
  static const legacyIntegrationVersion = '1';
  static const supportedIntegrationVersion = '2';
  static const List<String> supportedIntegrationVersions = <String>[
    legacyIntegrationVersion,
    supportedIntegrationVersion,
  ];
  static const v2EncryptionAlgorithm = 'AES-256-GCM';

  IntegrationsBridgeController({
    required Future<FolioMarkdownImportResult> Function(
      IntegrationsMarkdownImportRequest request,
    )
    onImport,
    required Future<FolioMarkdownImportResult> Function(
      IntegrationsPageUpdateRequest request,
    )
    onUpdate,
    required Future<List<Map<String, Object?>>> Function(String clientAppId)
    onListPages,
    required Future<List<Map<String, Object?>>> Function(String clientAppId)
    onListCustomEmojis,
    required Future<FolioMarkdownImportResult> Function(
      IntegrationsJsonImportRequest request,
    )
    onImportJson,
    required Future<void> Function(
      String clientAppId,
      List<Map<String, Object?>> items,
    )
    onReplaceCustomEmojis,
    required Future<Map<String, Object?>> Function(
      IntegrationsCustomEmojiUpsertRequest request,
    )
    onUpsertCustomEmoji,
    required Future<void> Function(IntegrationsCustomEmojiDeleteRequest request)
    onDeleteCustomEmoji,
    required Future<bool> Function(IntegrationsClientIdentity client)
    onApproveClient,
    required Future<void> Function(IntegrationsClientIdentity client)
    onClientObserved,
    required bool Function(IntegrationsClientIdentity client) isClientApproved,
    required Map<String, Object?> Function() appInfoProvider,
    this.onEvent,
    this.resolveLocale,
    this.allowedOrigins = const [],
    int port = IntegrationsLaunchSession.fixedPort,
  }) : _onImport = onImport,
       _onUpdate = onUpdate,
       _onListPages = onListPages,
       _onListCustomEmojis = onListCustomEmojis,
       _onImportJson = onImportJson,
       _onReplaceCustomEmojis = onReplaceCustomEmojis,
       _onUpsertCustomEmoji = onUpsertCustomEmoji,
       _onDeleteCustomEmoji = onDeleteCustomEmoji,
       _onApproveClient = onApproveClient,
       _onClientObserved = onClientObserved,
       _isClientApproved = isClientApproved,
       _appInfoProvider = appInfoProvider,
       _port = port;

  final Future<FolioMarkdownImportResult> Function(
    IntegrationsMarkdownImportRequest request,
  )
  _onImport;
  final Future<FolioMarkdownImportResult> Function(
    IntegrationsPageUpdateRequest request,
  )
  _onUpdate;
  final Future<List<Map<String, Object?>>> Function(String clientAppId)
  _onListPages;
  final Future<List<Map<String, Object?>>> Function(String clientAppId)
  _onListCustomEmojis;
  final Future<FolioMarkdownImportResult> Function(
    IntegrationsJsonImportRequest request,
  )
  _onImportJson;
  final Future<void> Function(
    String clientAppId,
    List<Map<String, Object?>> items,
  )
  _onReplaceCustomEmojis;
  final Future<Map<String, Object?>> Function(
    IntegrationsCustomEmojiUpsertRequest,
  )
  _onUpsertCustomEmoji;
  final Future<void> Function(IntegrationsCustomEmojiDeleteRequest)
  _onDeleteCustomEmoji;
  final Future<bool> Function(IntegrationsClientIdentity client)
  _onApproveClient;
  final Future<void> Function(IntegrationsClientIdentity client)
  _onClientObserved;
  final bool Function(IntegrationsClientIdentity client) _isClientApproved;
  final Map<String, Object?> Function() _appInfoProvider;
  final void Function(String message)? onEvent;
  final Locale Function()? resolveLocale;
  final List<String> allowedOrigins;

  void _notifyLocalizedEvent(String Function(AppLocalizations l10n) message) {
    final loc = resolveLocale?.call() ?? const Locale('es');
    onEvent?.call(message(lookupAppLocalizations(loc)));
  }

  static const int maxPayloadBytes = 2 * 1024 * 1024;
  static const Duration sessionTtl = Duration(minutes: 5);
  static final Random _secureRandom = Random.secure();
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Sha256 _sha256 = Sha256();

  HttpServer? _server;
  IntegrationsLaunchSession? _activeSession;
  Timer? _expiryTimer;
  int _port;

  IntegrationsLaunchSession? get activeSession => _activeSession;
  int get port => _port;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
      shared: false,
    );
    _port = _server!.port;
    unawaited(_listen(_server!));
  }

  Future<IntegrationsLaunchSession> activateFromUri(Uri uri) async {
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
    final client = IntegrationsClientIdentity(
      appId: appId,
      appName: (appName?.isNotEmpty ?? false) ? appName! : appId,
      appVersion: (appVersion?.isNotEmpty ?? false) ? appVersion! : '',
      integrationVersion: (integrationVersion?.isNotEmpty ?? false)
          ? integrationVersion!
          : '',
    );
    final session = IntegrationsLaunchSession.fromLaunchUri(
      uri,
      client: client,
    );
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

  IntegrationsLaunchSession createSession(IntegrationsClientIdentity client) {
    final now = DateTime.now().toUtc();
    final session = IntegrationsLaunchSession(
      sessionId: _newSessionId(),
      port: _port,
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
    final corsOrigin = _resolvedCorsOrigin(request);
    if (corsOrigin != null) {
      _applyCorsHeaders(request.response, corsOrigin);
    }
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    final session = _activeSession;
    final path = request.uri.path;
    final isPageUpdate =
        request.method == 'PATCH' && path.startsWith('/pages/');
    final isCustomEmojiCollection = path == '/app/custom-emojis';
    final isCustomEmojiItem = path.startsWith('/app/custom-emojis/');
    final requiresClientIdentity =
        path == '/health' ||
        path == '/app' ||
        path == '/status' ||
        path == '/imports/markdown' ||
        path == '/imports/json' ||
        path == '/pages' ||
        path == '/session/start' ||
        path == '/session/new' ||
        path == '/start' ||
        isCustomEmojiCollection ||
        isCustomEmojiItem ||
        isPageUpdate;

    IntegrationsClientIdentity? client;
    if (requiresClientIdentity) {
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
        'port': _port,
        'importSessionActive': session != null,
        'sessionId': session?.sessionId,
        'state': session == null ? 'idle' : 'ready',
        'clientApproved': client != null && _isClientApproved(client),
        'integrationVersion': supportedIntegrationVersion,
        'supportedIntegrationVersions': supportedIntegrationVersions,
      });
      return;
    }

    if (request.method == 'GET' && (path == '/app' || path == '/status')) {
      await _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'appRunning': true,
        'bridgePort': _port,
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
        'supportedIntegrationVersions': supportedIntegrationVersions,
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
        'message': 'No active Integrations import session.',
      });
      return;
    }

    if (isCustomEmojiCollection || isCustomEmojiItem) {
      final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (auth.trim() != 'Bearer ${session.nonce}') {
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'UNAUTHORIZED',
          'message': 'Invalid session token.',
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

      if (request.method == 'GET' && isCustomEmojiCollection) {
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
        final items = await _onListCustomEmojis(c.appId);
        await _writeJson(request.response, HttpStatus.ok, {
          'ok': true,
          'sessionId': session.sessionId,
          'items': items,
        });
        return;
      }

      if (request.method == 'PUT' && isCustomEmojiCollection) {
        try {
          final rawBody = await utf8.decoder.bind(request).join();
          if (utf8.encode(rawBody).length > maxPayloadBytes) {
            throw const HttpException('Payload too large.');
          }
          final decoded = jsonDecode(rawBody);
          if (decoded is! Map) {
            throw const FormatException('JSON object expected.');
          }
          final body = Map<String, dynamic>.from(decoded);
          final sessionId = (body['sessionId'] as String? ?? '').trim();
          if (sessionId != session.sessionId) {
            await _writeJson(request.response, HttpStatus.unauthorized, {
              'ok': false,
              'error': 'SESSION_MISMATCH',
              'message': 'Request sessionId does not match the active session.',
            });
            return;
          }
          final itemsRaw = body['items'];
          if (itemsRaw is! List) {
            throw const FormatException('Field "items" must be an array.');
          }
          final items = itemsRaw
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .toList(growable: false);
          await _onReplaceCustomEmojis(c.appId, items);
          await _writeJson(request.response, HttpStatus.ok, {
            'ok': true,
            'sessionId': session.sessionId,
            'count': items.length,
          });
        } on FormatException catch (e) {
          await _writeJson(request.response, HttpStatus.badRequest, {
            'ok': false,
            'error': 'INVALID_PAYLOAD',
            'message': e.message,
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
            'error': 'CUSTOM_EMOJI_UPDATE_FAILED',
            'message': e.toString(),
          });
        }
        return;
      }

      if (request.method == 'PATCH' && isCustomEmojiItem) {
        final emojiId = path.substring('/app/custom-emojis/'.length);
        try {
          final rawBody = await utf8.decoder.bind(request).join();
          if (utf8.encode(rawBody).length > maxPayloadBytes) {
            throw const HttpException('Payload too large.');
          }
          final decoded = jsonDecode(rawBody);
          if (decoded is! Map) {
            throw const FormatException('JSON object expected.');
          }
          final payload = IntegrationsCustomEmojiUpsertRequest.fromJson(
            emojiId,
            Map<String, dynamic>.from(decoded),
          ).copyWithClient(c);
          if (payload.sessionId != session.sessionId) {
            await _writeJson(request.response, HttpStatus.unauthorized, {
              'ok': false,
              'error': 'SESSION_MISMATCH',
              'message': 'Request sessionId does not match the active session.',
            });
            return;
          }
          final item = await _onUpsertCustomEmoji(payload);
          await _writeJson(request.response, HttpStatus.ok, {
            'ok': true,
            'sessionId': session.sessionId,
            'item': item,
          });
        } on FormatException catch (e) {
          await _writeJson(request.response, HttpStatus.badRequest, {
            'ok': false,
            'error': 'INVALID_PAYLOAD',
            'message': e.message,
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
            'error': 'CUSTOM_EMOJI_UPDATE_FAILED',
            'message': e.toString(),
          });
        }
        return;
      }

      if (request.method == 'DELETE' && isCustomEmojiItem) {
        final emojiId = path.substring('/app/custom-emojis/'.length);
        try {
          final payload = IntegrationsCustomEmojiDeleteRequest.fromRequest(
            emojiId,
            request,
          ).copyWithClient(c);
          if (payload.sessionId != session.sessionId) {
            await _writeJson(request.response, HttpStatus.unauthorized, {
              'ok': false,
              'error': 'SESSION_MISMATCH',
              'message': 'Request sessionId does not match the active session.',
            });
            return;
          }
          await _onDeleteCustomEmoji(payload);
          await _writeJson(request.response, HttpStatus.ok, {
            'ok': true,
            'sessionId': session.sessionId,
            'deletedId': payload.emojiId,
          });
        } on FormatException catch (e) {
          await _writeJson(request.response, HttpStatus.badRequest, {
            'ok': false,
            'error': 'INVALID_PAYLOAD',
            'message': e.message,
          });
        } catch (e) {
          await _writeJson(request.response, HttpStatus.internalServerError, {
            'ok': false,
            'error': 'CUSTOM_EMOJI_DELETE_FAILED',
            'message': e.toString(),
          });
        }
        return;
      }
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
      final c = client!;
      try {
        final rawBody = await utf8.decoder.bind(request).join();
        if (utf8.encode(rawBody).length > maxPayloadBytes) {
          throw const HttpException('Payload too large.');
        }
        final decoded = await _decodePayloadJson(
          rawBody: rawBody,
          client: c,
          session: session,
        );
        if (decoded is! Map) {
          throw const FormatException('JSON object expected.');
        }
        final payload = IntegrationsPageUpdateRequest.fromJson(
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
        _notifyLocalizedEvent(
          (l10n) => l10n.integrationSnackPageUpdateDone(result.pageTitle),
        );
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
      } on _IntegrationsPayloadException catch (e) {
        await _writeJson(request.response, e.statusCode, {
          'ok': false,
          'error': e.error,
          'message': e.message,
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
      final c = client!;
      try {
        final rawBody = await utf8.decoder.bind(request).join();
        if (utf8.encode(rawBody).length > maxPayloadBytes) {
          throw const HttpException('Payload too large.');
        }
        final decoded = await _decodePayloadJson(
          rawBody: rawBody,
          client: c,
          session: session,
        );
        if (decoded is! Map) {
          throw const FormatException('JSON object expected.');
        }
        final payload = IntegrationsJsonImportRequest.fromJson(
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
        _notifyLocalizedEvent(
          (l10n) => l10n.integrationSnackJsonImportDone(result.pageTitle),
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
      } on _IntegrationsPayloadException catch (e) {
        await _writeJson(request.response, e.statusCode, {
          'ok': false,
          'error': e.error,
          'message': e.message,
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
    final c = client!;

    try {
      final rawBody = await utf8.decoder.bind(request).join();
      if (utf8.encode(rawBody).length > maxPayloadBytes) {
        throw const HttpException('Payload too large.');
      }
      final decoded = await _decodePayloadJson(
        rawBody: rawBody,
        client: c,
        session: session,
      );
      if (decoded is! Map) {
        throw const FormatException('JSON object expected.');
      }
      final payload = IntegrationsMarkdownImportRequest.fromJson(
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
      _notifyLocalizedEvent(
        (l10n) => l10n.integrationSnackMarkdownImportDone(result.pageTitle),
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
    } on _IntegrationsPayloadException catch (e) {
      await _writeJson(request.response, e.statusCode, {
        'ok': false,
        'error': e.error,
        'message': e.message,
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
        'error': 'IMPORT_FAILED',
        'message': e.toString(),
      });
    }
  }

  String? _resolvedCorsOrigin(HttpRequest request) {
    if (allowedOrigins.isEmpty) return null;
    if (allowedOrigins.any((allowed) => allowed.trim() == '*')) {
      return '*';
    }
    final origin = request.headers.value('origin');
    if (origin == null) return null;
    final normalized = origin.trim().toLowerCase();
    for (final allowed in allowedOrigins) {
      if (allowed.toLowerCase() == normalized) return origin.trim();
    }
    return null;
  }

  void _applyCorsHeaders(HttpResponse response, String origin) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PATCH, PUT, DELETE, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, '
          'X-Folio-App-Id, X-Folio-App-Name, '
          'X-Folio-App-Version, X-Folio-Integration-Version',
    );
    if (origin != '*') {
      response.headers.set('Vary', 'Origin');
    }
  }

  Future<Object?> _decodePayloadJson({
    required String rawBody,
    required IntegrationsClientIdentity client,
    required IntegrationsLaunchSession session,
  }) async {
    final decoded = jsonDecode(rawBody);
    if (client.integrationVersion.trim() != supportedIntegrationVersion) {
      return decoded;
    }
    if (decoded is! Map) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message: 'Encrypted payload must be a JSON object.',
      );
    }
    final body = Map<String, dynamic>.from(decoded);
    final sessionId = (body['sessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message: 'Field "sessionId" is required for encrypted payload.',
      );
    }
    final encryptedRaw = body['encryptedPayload'];
    if (encryptedRaw is! Map) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'ENCRYPTION_REQUIRED',
        message:
            'Integration version 2 requires encryptedPayload envelope.',
      );
    }
    final encrypted = Map<String, dynamic>.from(encryptedRaw);
    final alg = (encrypted['alg'] as String? ?? '').trim();
    if (alg != v2EncryptionAlgorithm) {
      throw _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'UNSUPPORTED_ENCRYPTION_ALGORITHM',
        message: 'Only $v2EncryptionAlgorithm is supported.',
      );
    }
    final ivB64 = (encrypted['iv'] as String? ?? '').trim();
    final tagB64 = (encrypted['tag'] as String? ?? '').trim();
    final cipherB64 = (encrypted['ciphertext'] as String? ?? '').trim();
    if (ivB64.isEmpty || tagB64.isEmpty || cipherB64.isEmpty) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message:
            'encryptedPayload must include alg, iv, tag, and ciphertext.',
      );
    }

    final iv = _decodeBase64Flexible(ivB64);
    final tag = _decodeBase64Flexible(tagB64);
    final cipherText = _decodeBase64Flexible(cipherB64);
    if (iv.length != 12 || tag.length != 16 || cipherText.isEmpty) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message: 'Invalid iv, tag, or ciphertext length.',
      );
    }

    final keyMaterial = utf8.encode(
      'folio-integrations-v2|$sessionId|${session.nonce}',
    );
    final digest = await _sha256.hash(keyMaterial);
    final key = SecretKey(digest.bytes);

    List<int> clearBytes;
    try {
      clearBytes = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: iv, mac: Mac(tag)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'DECRYPTION_FAILED',
        message: 'Encrypted payload could not be decrypted.',
      );
    } on StateError {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'DECRYPTION_FAILED',
        message: 'Encrypted payload could not be decrypted.',
      );
    }

    final clearText = utf8.decode(clearBytes);
    final clearDecoded = jsonDecode(clearText);
    if (clearDecoded is! Map) {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message: 'Decrypted payload must be a JSON object.',
      );
    }
    final payload = Map<String, dynamic>.from(clearDecoded);
    payload['sessionId'] = sessionId;
    return payload;
  }

  List<int> _decodeBase64Flexible(String value) {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final missingPadding = normalized.length % 4;
    if (missingPadding != 0) {
      normalized =
          '$normalized${List<String>.filled(4 - missingPadding, '=').join()}';
    }
    try {
      return base64Decode(normalized);
    } on FormatException {
      throw const _IntegrationsPayloadException(
        statusCode: HttpStatus.badRequest,
        error: 'INVALID_ENCRYPTION_ENVELOPE',
        message: 'Invalid base64 value in encryptedPayload.',
      );
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

  String _buildDeepLink(IntegrationsLaunchSession session) {
    return 'folio://import?session=${Uri.encodeComponent(session.sessionId)}'
        '&nonce=${Uri.encodeComponent(session.nonce)}'
        '&appId=${Uri.encodeComponent(session.client.appId)}'
        '&appName=${Uri.encodeComponent(session.client.appName)}'
        '&appVersion=${Uri.encodeComponent(session.client.appVersion)}'
        '&integrationVersion=${Uri.encodeComponent(session.client.integrationVersion)}';
  }

  Future<_IntegrationsClientAuth> _authorizeClient(
    HttpRequest request, {
    required bool mayPromptApproval,
  }) async {
    final appId = request.headers.value(headerAppId)?.trim() ?? '';
    final appNameHeader = request.headers.value(headerAppName)?.trim() ?? '';
    final appVersionHeader =
        request.headers.value(headerAppVersion)?.trim() ?? '';
    final integrationVersionHeader =
        request.headers.value(headerIntegrationVersion)?.trim() ?? '';
    if (appId.isEmpty) {
      return const _IntegrationsClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_APP_ID',
        message: 'Header X-Folio-App-Id is required.',
      );
    }
    if (appVersionHeader.isEmpty) {
      return const _IntegrationsClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_APP_VERSION',
        message: 'Header X-Folio-App-Version is required.',
      );
    }
    if (integrationVersionHeader.isEmpty) {
      return const _IntegrationsClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'MISSING_INTEGRATION_VERSION',
        message: 'Header X-Folio-Integration-Version is required.',
      );
    }
    if (!supportedIntegrationVersions.contains(integrationVersionHeader)) {
      return _IntegrationsClientAuth.error(
        statusCode: HttpStatus.badRequest,
        error: 'UNSUPPORTED_INTEGRATION_VERSION',
        message:
            'Unsupported X-Folio-Integration-Version. Supported versions: ${supportedIntegrationVersions.join(', ')}.',
      );
    }
    final client = IntegrationsClientIdentity(
      appId: appId,
      appName: appNameHeader.isEmpty ? appId : appNameHeader,
      appVersion: appVersionHeader,
      integrationVersion: integrationVersionHeader,
    );
    if (_isClientApproved(client)) {
      await _onClientObserved(client);
      return _IntegrationsClientAuth.success(client);
    }
    if (!mayPromptApproval) {
      return const _IntegrationsClientAuth.error(
        statusCode: HttpStatus.forbidden,
        error: 'APP_NOT_APPROVED',
        message: 'This app has not been approved in Folio yet.',
      );
    }
    final approved = await _onApproveClient(client);
    if (!approved) {
      return const _IntegrationsClientAuth.error(
        statusCode: HttpStatus.forbidden,
        error: 'APP_NOT_APPROVED',
        message: 'The app was not approved by the user.',
      );
    }
    return _IntegrationsClientAuth.success(client);
  }
}

extension on IntegrationsMarkdownImportRequest {
  IntegrationsMarkdownImportRequest copyWithClient(
    IntegrationsClientIdentity client,
  ) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return IntegrationsMarkdownImportRequest(
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

extension on IntegrationsPageUpdateRequest {
  IntegrationsPageUpdateRequest copyWithClient(
    IntegrationsClientIdentity client,
  ) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return IntegrationsPageUpdateRequest(
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

extension on IntegrationsJsonImportRequest {
  IntegrationsJsonImportRequest copyWithClient(
    IntegrationsClientIdentity client,
  ) {
    final nextMetadata = <String, Object?>{
      ...metadata,
      'clientAppVersion': client.appVersion,
      'integrationVersion': client.integrationVersion,
    };
    return IntegrationsJsonImportRequest(
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

extension on IntegrationsCustomEmojiUpsertRequest {
  IntegrationsCustomEmojiUpsertRequest copyWithClient(
    IntegrationsClientIdentity client,
  ) {
    return IntegrationsCustomEmojiUpsertRequest(
      emojiId: emojiId,
      sessionId: sessionId,
      clientAppId: client.appId,
      clientAppName: client.appName,
      label: label,
      source: source,
      filePath: filePath,
      mimeType: mimeType,
      createdAtMs: createdAtMs,
    );
  }
}

extension on IntegrationsCustomEmojiDeleteRequest {
  IntegrationsCustomEmojiDeleteRequest copyWithClient(
    IntegrationsClientIdentity client,
  ) {
    return IntegrationsCustomEmojiDeleteRequest(
      emojiId: emojiId,
      sessionId: sessionId,
      clientAppId: client.appId,
      clientAppName: client.appName,
    );
  }
}

class _IntegrationsClientAuth {
  const _IntegrationsClientAuth.success(this.client)
    : statusCode = null,
      error = null,
      message = null;

  const _IntegrationsClientAuth.error({
    required this.statusCode,
    required this.error,
    required this.message,
  }) : client = null;

  final IntegrationsClientIdentity? client;
  final int? statusCode;
  final String? error;
  final String? message;
}

class _IntegrationsPayloadException implements Exception {
  const _IntegrationsPayloadException({
    required this.statusCode,
    required this.error,
    required this.message,
  });

  final int statusCode;
  final String error;
  final String message;
}
