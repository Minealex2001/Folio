import 'dart:convert';

/// Tipo de renderer para un bloque personalizado de una app.
enum FolioAppBlockRendererType { webview, embedUrl, template }

/// Permiso que una app puede solicitar al usuario.
enum FolioAppPermission { internet, clipboard, fileSystem, camera }

String folioAppPermissionDisplayName(FolioAppPermission p) {
  switch (p) {
    case FolioAppPermission.internet:
      return 'Acceso a internet';
    case FolioAppPermission.clipboard:
      return 'Leer portapapeles';
    case FolioAppPermission.fileSystem:
      return 'Acceso a archivos';
    case FolioAppPermission.camera:
      return 'Cámara';
  }
}

/// Renderer de un bloque personalizado.
class FolioAppBlockRenderer {
  const FolioAppBlockRenderer({
    required this.type,
    this.htmlAsset,
    this.embedUrl,
  });

  final FolioAppBlockRendererType type;

  /// Ruta relativa al directorio assets/ del paquete. Solo para [FolioAppBlockRendererType.webview].
  final String? htmlAsset;

  /// URL a la que apunta el embed. Solo para [FolioAppBlockRendererType.embedUrl].
  final String? embedUrl;

  factory FolioAppBlockRenderer.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'webview').toLowerCase();
    final type = switch (typeStr) {
      'embed_url' => FolioAppBlockRendererType.embedUrl,
      'template' => FolioAppBlockRendererType.template,
      _ => FolioAppBlockRendererType.webview,
    };
    return FolioAppBlockRenderer(
      type: type,
      htmlAsset: json['htmlAsset'] as String?,
      embedUrl: json['embedUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'type': switch (type) {
      FolioAppBlockRendererType.webview => 'webview',
      FolioAppBlockRendererType.embedUrl => 'embed_url',
      FolioAppBlockRendererType.template => 'template',
    },
    if (htmlAsset != null) 'htmlAsset': htmlAsset,
    if (embedUrl != null) 'embedUrl': embedUrl,
  };
}

/// Tipo de bloque personalizado que añade una app.
class FolioAppBlockType {
  const FolioAppBlockType({
    required this.typeKey,
    required this.displayName,
    required this.icon,
    required this.section,
    required this.renderer,
    this.hint = '',
  });

  /// Clave namespaced en formato reverse-domain, p. ej. "com.mycompany.card".
  final String typeKey;
  final String displayName;

  /// Nombre de icono Material (codepointHex). Si no se reconoce, se usa widgets_outlined.
  final String icon;

  /// Sección del menú slash donde aparecerá.
  final String section;
  final String hint;
  final FolioAppBlockRenderer renderer;

  factory FolioAppBlockType.fromJson(Map<String, dynamic> json) {
    return FolioAppBlockType(
      typeKey: (json['typeKey'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? '').trim(),
      section: (json['section'] as String? ?? 'apps').trim(),
      hint: (json['hint'] as String? ?? '').trim(),
      renderer: json['renderer'] is Map
          ? FolioAppBlockRenderer.fromJson(
              Map<String, dynamic>.from(json['renderer'] as Map),
            )
          : const FolioAppBlockRenderer(
              type: FolioAppBlockRendererType.webview,
            ),
    );
  }

  Map<String, Object?> toJson() => {
    'typeKey': typeKey,
    'displayName': displayName,
    'icon': icon,
    'section': section,
    'hint': hint,
    'renderer': renderer.toJson(),
  };
}

/// Acción que ejecuta un slash command de una app.
enum FolioAppSlashActionType { http, prompt, oauthTrigger }

class FolioAppSlashAction {
  const FolioAppSlashAction({
    required this.type,
    this.url,
    this.method,
    this.bodyTemplate,
    this.prompt,
    this.integrationKey,
  });

  final FolioAppSlashActionType type;

  /// URL del endpoint HTTP. Solo para [FolioAppSlashActionType.http].
  final String? url;
  final String? method;

  /// Plantilla del body en JSON. Puede usar `{blockText}`, `{pageTitle}`.
  final String? bodyTemplate;

  /// Prompt de texto libre. Solo para [FolioAppSlashActionType.prompt].
  final String? prompt;

  /// Clave de integración OAuth que se requiere activa. Solo para [FolioAppSlashActionType.oauthTrigger].
  final String? integrationKey;

  factory FolioAppSlashAction.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'http').toLowerCase();
    final type = switch (typeStr) {
      'prompt' => FolioAppSlashActionType.prompt,
      'oauth_trigger' => FolioAppSlashActionType.oauthTrigger,
      _ => FolioAppSlashActionType.http,
    };
    return FolioAppSlashAction(
      type: type,
      url: json['url'] as String?,
      method: json['method'] as String?,
      bodyTemplate: json['bodyTemplate'] as String?,
      prompt: json['prompt'] as String?,
      integrationKey: json['integrationKey'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'type': switch (type) {
      FolioAppSlashActionType.http => 'http',
      FolioAppSlashActionType.prompt => 'prompt',
      FolioAppSlashActionType.oauthTrigger => 'oauth_trigger',
    },
    if (url != null) 'url': url,
    if (method != null) 'method': method,
    if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
    if (prompt != null) 'prompt': prompt,
    if (integrationKey != null) 'integrationKey': integrationKey,
  };
}

/// Slash command personalizado que añade una app.
class FolioAppSlashCommand {
  const FolioAppSlashCommand({
    required this.key,
    required this.displayName,
    required this.icon,
    required this.action,
    this.hint = '',
  });

  /// Clave namespaced, p. ej. "com.mycompany.create_issue".
  final String key;
  final String displayName;
  final String icon;
  final String hint;
  final FolioAppSlashAction action;

  factory FolioAppSlashCommand.fromJson(Map<String, dynamic> json) {
    return FolioAppSlashCommand(
      key: (json['key'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? '').trim(),
      hint: (json['hint'] as String? ?? '').trim(),
      action: json['action'] is Map
          ? FolioAppSlashAction.fromJson(
              Map<String, dynamic>.from(json['action'] as Map),
            )
          : const FolioAppSlashAction(type: FolioAppSlashActionType.http),
    );
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'displayName': displayName,
    'icon': icon,
    'hint': hint,
    'action': action.toJson(),
  };
}

/// Tipo de autenticación de una integración.
enum FolioAppIntegrationAuthType { oauth2, apiKey }

/// Integración OAuth / API key que añade una app.
class FolioAppIntegration {
  const FolioAppIntegration({
    required this.key,
    required this.displayName,
    required this.iconUrl,
    required this.authType,
    this.authorizationUrl,
    this.tokenUrl,
    this.scopes = const [],
    this.apiKeyLabel,
  });

  /// Clave namespaced, p. ej. "com.mycompany.github".
  final String key;
  final String displayName;
  final String iconUrl;
  final FolioAppIntegrationAuthType authType;

  /// Solo para [FolioAppIntegrationAuthType.oauth2].
  final String? authorizationUrl;
  final String? tokenUrl;
  final List<String> scopes;

  /// Etiqueta del campo para el API key. Solo para [FolioAppIntegrationAuthType.apiKey].
  final String? apiKeyLabel;

  factory FolioAppIntegration.fromJson(Map<String, dynamic> json) {
    final authStr = (json['authType'] as String? ?? 'oauth2').toLowerCase();
    final authType = switch (authStr) {
      'api_key' => FolioAppIntegrationAuthType.apiKey,
      _ => FolioAppIntegrationAuthType.oauth2,
    };
    return FolioAppIntegration(
      key: (json['key'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      iconUrl: (json['iconUrl'] as String? ?? '').trim(),
      authType: authType,
      authorizationUrl: json['authorizationUrl'] as String?,
      tokenUrl: json['tokenUrl'] as String?,
      scopes: (json['scopes'] as List?)?.cast<String>() ?? const [],
      apiKeyLabel: json['apiKeyLabel'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'displayName': displayName,
    'iconUrl': iconUrl,
    'authType': switch (authType) {
      FolioAppIntegrationAuthType.oauth2 => 'oauth2',
      FolioAppIntegrationAuthType.apiKey => 'api_key',
    },
    if (authorizationUrl != null) 'authorizationUrl': authorizationUrl,
    if (tokenUrl != null) 'tokenUrl': tokenUrl,
    if (scopes.isNotEmpty) 'scopes': scopes,
    if (apiKeyLabel != null) 'apiKeyLabel': apiKeyLabel,
  };
}

/// Tipo de acción de un AI Transformer.
enum FolioAppAiTransformerActionType { prompt, externalApi }

class FolioAppAiTransformerAction {
  const FolioAppAiTransformerAction({
    required this.type,
    this.systemPrompt,
    this.endpointUrl,
  });

  final FolioAppAiTransformerActionType type;

  /// System prompt para [FolioAppAiTransformerActionType.prompt].
  final String? systemPrompt;

  /// URL del endpoint externo para [FolioAppAiTransformerActionType.externalApi].
  final String? endpointUrl;

  factory FolioAppAiTransformerAction.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'prompt').toLowerCase();
    final type = switch (typeStr) {
      'external_api' => FolioAppAiTransformerActionType.externalApi,
      _ => FolioAppAiTransformerActionType.prompt,
    };
    return FolioAppAiTransformerAction(
      type: type,
      systemPrompt: json['systemPrompt'] as String?,
      endpointUrl: json['endpointUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'type': switch (type) {
      FolioAppAiTransformerActionType.prompt => 'prompt',
      FolioAppAiTransformerActionType.externalApi => 'external_api',
    },
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
    if (endpointUrl != null) 'endpointUrl': endpointUrl,
  };
}

/// AI Transformer que añade una app (transforma una página en otra cosa).
class FolioAppAiTransformer {
  const FolioAppAiTransformer({
    required this.key,
    required this.displayName,
    required this.icon,
    required this.action,
    this.description = '',
  });

  /// Clave namespaced, p. ej. "com.mycompany.to_slide_deck".
  final String key;
  final String displayName;
  final String icon;
  final String description;
  final FolioAppAiTransformerAction action;

  factory FolioAppAiTransformer.fromJson(Map<String, dynamic> json) {
    return FolioAppAiTransformer(
      key: (json['key'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      action: json['action'] is Map
          ? FolioAppAiTransformerAction.fromJson(
              Map<String, dynamic>.from(json['action'] as Map),
            )
          : const FolioAppAiTransformerAction(
              type: FolioAppAiTransformerActionType.prompt,
            ),
    );
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'displayName': displayName,
    'icon': icon,
    'description': description,
    'action': action.toJson(),
  };
}

/// Manifiesto completo de un paquete de app Folio (manifest.json dentro del .folioapp).
class FolioAppPackage {
  const FolioAppPackage({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    this.iconUrl = '',
    this.websiteUrl = '',
    this.isBuiltIn = false,
    this.permissions = const [],
    this.blockTypes = const [],
    this.slashCommands = const [],
    this.integrations = const [],
    this.aiTransformers = const [],
  });

  /// ID namespaced en formato reverse-domain, p. ej. "com.mycompany.myapp".
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String iconUrl;
  final String websiteUrl;

  /// Indica que la app está integrada en Folio y no requiere descarga.
  final bool isBuiltIn;
  final List<FolioAppPermission> permissions;
  final List<FolioAppBlockType> blockTypes;
  final List<FolioAppSlashCommand> slashCommands;
  final List<FolioAppIntegration> integrations;
  final List<FolioAppAiTransformer> aiTransformers;

  factory FolioAppPackage.fromJson(Map<String, dynamic> json) {
    List<FolioAppPermission> parsePermissions(dynamic raw) {
      if (raw is! List) return const [];
      return raw.cast<String>().map((s) {
        return switch (s.toLowerCase()) {
          'clipboard' => FolioAppPermission.clipboard,
          'filesystem' || 'file_system' => FolioAppPermission.fileSystem,
          'camera' => FolioAppPermission.camera,
          _ => FolioAppPermission.internet,
        };
      }).toList();
    }

    return FolioAppPackage(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      version: (json['version'] as String? ?? '').trim(),
      author: (json['author'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      iconUrl: (json['iconUrl'] as String? ?? '').trim(),
      websiteUrl: (json['websiteUrl'] as String? ?? '').trim(),
      isBuiltIn: (json['isBuiltIn'] as bool?) ?? false,
      permissions: parsePermissions(json['permissions']),
      blockTypes:
          (json['blockTypes'] as List?)
              ?.map(
                (e) => FolioAppBlockType.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      slashCommands:
          (json['slashCommands'] as List?)
              ?.map(
                (e) => FolioAppSlashCommand.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      integrations:
          (json['integrations'] as List?)
              ?.map(
                (e) => FolioAppIntegration.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      aiTransformers:
          (json['aiTransformers'] as List?)
              ?.map(
                (e) => FolioAppAiTransformer.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }

  factory FolioAppPackage.fromJsonString(String raw) {
    return FolioAppPackage.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    if (iconUrl.isNotEmpty) 'iconUrl': iconUrl,
    if (websiteUrl.isNotEmpty) 'websiteUrl': websiteUrl,
    if (isBuiltIn) 'isBuiltIn': true,
    if (permissions.isNotEmpty)
      'permissions': permissions
          .map(
            (p) => switch (p) {
              FolioAppPermission.internet => 'internet',
              FolioAppPermission.clipboard => 'clipboard',
              FolioAppPermission.fileSystem => 'file_system',
              FolioAppPermission.camera => 'camera',
            },
          )
          .toList(),
    if (blockTypes.isNotEmpty)
      'blockTypes': blockTypes.map((b) => b.toJson()).toList(),
    if (slashCommands.isNotEmpty)
      'slashCommands': slashCommands.map((c) => c.toJson()).toList(),
    if (integrations.isNotEmpty)
      'integrations': integrations.map((i) => i.toJson()).toList(),
    if (aiTransformers.isNotEmpty)
      'aiTransformers': aiTransformers.map((t) => t.toJson()).toList(),
  };

  /// Valida que el ID es de formato reverse-domain con al menos 2 segmentos.
  static bool isValidId(String id) {
    final parts = id.split('.');
    if (parts.length < 2) return false;
    final validSegment = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$');
    return parts.every(validSegment.hasMatch);
  }

  /// Devuelve true si el package pide el permiso [p].
  bool hasPermission(FolioAppPermission p) => permissions.contains(p);
}
