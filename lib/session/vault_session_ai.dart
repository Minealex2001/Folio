part of 'vault_session.dart';

extension VaultSessionAi on VaultSession {
  AiCompletionRequest _buildAgentCompletionRequest({
    required String userPrompt,
    required List<AiChatMessage> conversationMessages,
    required bool isEs,
    required String languageCode,
    required String referencePagesText,
    required String editTargetLine,
    required String pageBlocksContext,
    required List<AiFileAttachment> attachments,
    required String cloudInkOperation,
  }) {
    final isFirstTurn = conversationMessages.isEmpty;
    final agentIdentity = isEs
        ? 'Eres Quill, la asistente de IA integrada en Folio (notas locales, árbol de páginas, editor por bloques, búsqueda, libreta con cifrado opcional, panel de chat a la derecha). Ayudas con el contenido de las notas y con cómo usar la app; en modo chat sé clara, útil y natural.'
        : 'You are Quill, Folio\'s built-in AI assistant (local notes, page tree, block editor, search, optional encrypted vault, chat panel on the side). You help with note content and how to use the app; in chat mode be clear, helpful, and natural.';

    final schema = _agentResponseSchema;

    final systemPrompt = StringBuffer()
      ..writeln(agentIdentity)
      ..writeln()
      ..writeln(
        isFirstTurn
            ? _folioAgentInAppGuide(isEs: isEs)
            : _folioAgentInAppGuideCompact(isEs: isEs),
      )
      ..writeln()
      ..writeln(_aiLanguageRule(languageCode, isEsInstruction: isEs))
      ..writeln()
      ..writeln(
        isEs
            ? 'Devuelve SOLO JSON válido con este esquema:'
            : 'Return ONLY valid JSON with this schema:',
      )
      ..writeln('{')
      ..writeln(
        '"mode":"chat|summarize_current|append_current|replace_current|edit_current|create_page",',
      )
      ..writeln(
        '"reason":"${isEs ? 'explicación breve (1 frase) de por qué eliges ese modo' : 'brief explanation (1 sentence) of why you chose this mode'}",',
      )
      ..writeln(
        '"reply":"${isEs ? 'texto breve para usuario (1–4 frases máximo)' : 'brief user-facing text (max 1–4 sentences)'}",',
      )
      ..writeln(
        '"title":"${isEs ? 'solo para create_page' : 'only for create_page'}",',
      )
      ..writeln(
        '"threadTitle":"${isEs ? 'opcional (2-8 palabras) para renombrar la pestaña del chat SOLO en el primer turno; cadena vacía si no aplica' : 'optional (2-8 words) to rename the chat tab ONLY on the first turn; empty string if N/A'}",',
      )
      ..writeln(
        '"blocks":[{"type":"paragraph|h1|h2|h3|bullet|numbered|todo|quote|code|callout|toggle|divider|table|image|file|video|audio|meeting_note|bookmark|embed|equation|mermaid","text":"...","checked":false,"expanded":true,"codeLanguage":"dart","depth":0,"icon":"emoji","url":"https://...","imageWidth":0.8,"cols":2,"rows":[["a","b"]]}],',
      )
      ..writeln(
        '"operations":[{"kind":"update_page_title|update_block_text|update_block|replace_block|insert_after|insert_before|move_block|delete_block|table_add_column|table_set_cell","title":"${isEs ? 'nuevo título (solo update_page_title)' : 'new title (update_page_title only)'}","blockId":"id","text":"...","checked":false,"expanded":true,"codeLanguage":"dart","depth":0,"icon":"emoji","url":"https://...","imageWidth":0.8,"targetIndex":0,"block":{},"blocks":[],"header":"...","values":[],"row":0,"col":0,"value":"..."}]',
      )
      ..writeln('}')
      ..writeln()
      ..writeln(isEs ? 'Reglas:' : 'Rules:')
      ..writeln(
        '- summarize_current: ${isEs ? 'resume la página activa' : 'summarize the active page'}.',
      )
      ..writeln(
        '- append_current: ${isEs ? 'añade bloques a la página activa' : 'append blocks to the active page'}.',
      )
      ..writeln(
        '- replace_current: ${isEs ? 'sustituye bloques de la página activa' : 'replace blocks in the active page'}.',
      )
      ..writeln(
        '- edit_current: ${isEs ? 'edita con operations (usa blockId reales de la página en edición) y/o renombra con update_page_title' : 'edit with operations (use real blockIds from the page under edit) and/or rename with update_page_title'}.',
      )
      ..writeln(
        '- ${isEs ? 'Si el usuario pide modificar/corregir/actualizar/reescribir bloques existentes de la página abierta, usa SIEMPRE edit_current.' : 'If the user asks to modify/correct/update/rewrite existing blocks in the open page, ALWAYS use edit_current.'}',
      )
      ..writeln(
        '- ${isEs ? 'Si no hay pagina activa, NO uses summarize_current/append_current/replace_current/edit_current.' : 'If there is no active page, DO NOT use summarize_current/append_current/replace_current/edit_current.'}',
      )
      ..writeln(
        '- ${isEs ? 'Si el contexto de páginas está desactivado, no cites notas existentes; aun así puedes usar create_page cuando el usuario pida crear una página nueva.' : 'If page context is disabled, do not reference existing notes; you may still use create_page when the user asks for a new page.'}',
      )
      ..writeln(
        '- ${isEs ? 'Prioridad de decision: create_page > edit_current > append/replace/summarize > chat.' : 'Decision priority: create_page > edit_current > append/replace/summarize > chat.'}',
      )
      ..writeln(
        '- ${isEs ? 'Si el usuario pide crear una nota/pagina nueva, usa create_page.' : 'If the user asks to create a new note/page, use create_page.'}',
      )
      ..writeln(
        '- ${isEs ? 'Si pide corregir/actualizar/reescribir contenido existente de la pagina abierta, usa edit_current con operations.' : 'If the user asks to correct/update/rewrite existing content in the open page, use edit_current with operations.'}',
      )
      ..writeln(
        '- ${isEs ? 'No uses markdown fences ni texto fuera del JSON.' : 'Do not use markdown fences or extra text outside JSON.'}',
      );

    final contextMessage = StringBuffer()
      ..writeln(
        isEs
            ? 'Contenido de páginas (referencia; puede haber varias):'
            : 'Page contents (reference; there may be several):',
      )
      ..writeln(referencePagesText)
      ..writeln()
      ..writeln(editTargetLine)
      ..writeln(
        isEs
            ? 'Bloques de la página en edición (ids para operations):'
            : 'Blocks of the page under edit (ids for operations):',
      )
      ..writeln(pageBlocksContext.trim().isEmpty ? '[]' : pageBlocksContext);

    return AiCompletionRequest(
      cloudInkOperation: cloudInkOperation,
      systemPrompt: systemPrompt.toString().trim(),
      messages: <AiChatMessage>[
        ...conversationMessages,
        AiChatMessage.now(
          role: 'user',
          content: contextMessage.toString().trim(),
        ),
      ],
      // Importante: en Folio Cloud el backend puede priorizar `messages`; garantizamos
      // que el turno actual llegue como último user (Functions lo añade aunque haya historial).
      prompt: userPrompt.trim(),
      model: 'auto',
      attachments: attachments,
      temperature: 0.1,
      responseSchema: schema,
    );
  }

  Future<List<AiFileAttachment>> buildAiAttachmentsFromPaths(
    List<String> filePaths,
  ) async {
    final out = <AiFileAttachment>[];
    for (final rawPath in filePaths) {
      final fp = rawPath.trim();
      if (fp.isEmpty) continue;
      final f = File(fp);
      if (!f.existsSync()) continue;
      final mimeType = AiSafetyPolicy.detectMimeType(fp);
      final content = AiSafetyPolicy.isImageMimeType(mimeType)
          ? await AiSafetyPolicy.readImageAsBase64(f)
          : await AiSafetyPolicy.readAttachmentAsContext(f);
      if (content == null || content.trim().isEmpty) continue;
      out.add(
        AiFileAttachment(
          name: f.uri.pathSegments.isEmpty ? fp : f.uri.pathSegments.last,
          mimeType: mimeType,
          content: content,
        ),
      );
    }
    return out;
  }

  Future<({String text, AiTokenUsage? usage})> previewRewriteBlockWithAi({
    required String pageId,
    required String blockId,
    required String instruction,
    List<AiFileAttachment> attachments = const [],
    String? overrideBlockText,
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final block = _blockById(page, blockId);
    if (block == null) throw StateError('Bloque no encontrado.');
    final blockContent = overrideBlockText ?? block.text;
    final prompt =
        '${VaultSession._quillIdentityLeadEs}'
        'Tarea: reescribir un bloque sin resumir la página completa. '
        'Devuelve exclusivamente el texto final del bloque, sin markdown fences ni explicación.\n\n'
        'Página: ${page.title}\n'
        'Bloque actual:\n$blockContent\n\n'
        'Instrucción:\n${instruction.trim()}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        attachments: attachments,
        cloudInkOperation: 'rewrite_block',
      ),
    );
    final text = result.text.trim();
    if (text.isEmpty) throw StateError('La IA devolvió texto vacío.');
    return (text: text, usage: result.usage);
  }

  Future<String> rewriteBlockWithAi({
    required String pageId,
    required String blockId,
    required String instruction,
    List<AiFileAttachment> attachments = const [],
  }) async {
    final preview = await previewRewriteBlockWithAi(
      pageId: pageId,
      blockId: blockId,
      instruction: instruction,
      attachments: attachments,
    );
    updateBlockText(pageId, blockId, preview.text);
    return preview.text;
  }

  /// Resume un fragmento (p. ej. selección) sin modificar el bloque hasta que la UI aplique el texto.
  Future<({String text, AiTokenUsage? usage})> summarizeSelectionWithAi({
    required String pageId,
    required String blockId,
    required String selectionText,
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final block = _blockById(page, blockId);
    if (block == null) throw StateError('Bloque no encontrado.');
    final body = selectionText.trim().isEmpty ? block.text : selectionText;
    final lang = _aiOutputLanguageName(
      languageCode,
      isEsInstruction: true,
    );
    final prompt =
        '${VaultSession._quillIdentityLeadEs}'
        'Resume el siguiente fragmento en $lang de forma breve (viñetas si ayuda). '
        'Sin título ni preámbulo.\n\n'
        'Página: ${page.title}\n'
        'Fragmento:\n$body';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'summarize_selection',
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  /// Extrae fechas y tareas accionables como lista numerada o con viñetas.
  Future<({String text, AiTokenUsage? usage})> extractTasksAndDatesWithAi({
    required String pageId,
    required String blockId,
    required String selectionText,
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final block = _blockById(page, blockId);
    if (block == null) throw StateError('Bloque no encontrado.');
    final body = selectionText.trim().isEmpty ? block.text : selectionText;
    final lang = _aiOutputLanguageName(
      languageCode,
      isEsInstruction: true,
    );
    final prompt =
        '${VaultSession._quillIdentityLeadEs}'
        'Del texto siguiente, extrae: (1) fechas o plazos mencionados, (2) tareas accionables claras. '
        'Salida en $lang, formato markdown simple (listas). Si no hay nada, di «Nada detectado».\n\n'
        'Página: ${page.title}\n'
        'Texto:\n$body';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'extract_tasks',
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  Future<({String text, AiTokenUsage? usage})> summarizePageWithAi(
    String pageId, {
    List<AiFileAttachment> attachments = const [],
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final languageRule = _aiLanguageRule(
      languageCode,
      isEsInstruction: true,
    );
    final prompt =
        '${VaultSession._quillIdentityLeadEs}'
        '$languageRule\n'
      'Resume esta página de forma breve y accionable.\n'
        'Título: ${page.title}\n'
        'Contenido:\n${page.plainTextContent}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        attachments: attachments,
        cloudInkOperation: 'summarize_page',
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  Future<void> generateContentWithAi({
    required String pageId,
    required String prompt,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final fullPrompt =
        '${VaultSession._quillIdentityLeadEs}'
        'Genera NUEVO contenido para insertar en una página existente. '
        'Por defecto sé detallado y completo; adapta la extensión si el usuario dice «corto», «breve», «largo» o «detallado». '
        'No hagas resumen del contexto salvo que se pida explícitamente.\n'
        'Salida preferida: JSON válido con forma {"blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|callout|divider","text":"...","checked":false,"codeLanguage":"dart","depth":0,"icon":"emoji"}]}.\n'
        'También puedes devolver markdown estructurado si no puedes JSON. Sin markdown fences.\n\n'
        'Contexto de la página: ${page.title}\n'
        'Contenido actual:\n${page.plainTextContent}\n\n'
        'Solicitud:\n${prompt.trim()}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: fullPrompt,
        model: 'auto',
        attachments: attachments,
        cloudInkOperation: 'generate_insert',
      ),
    );
    final parsed = _parseAiHybridOutput(result.text, defaultTitle: page.title);
    final generated = _materializeAiBlocks(page.id, parsed.blocks);
    for (final line in generated) {
      insertBlockAfter(
        pageId: page.id,
        afterBlockId: page.blocks.last.id,
        block: line,
      );
    }
  }

  Future<String> generateStandalonePageWithAi({
    required String prompt,
    String? parentId,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final result = await ai.complete(
      AiCompletionRequest(
        prompt:
            '${VaultSession._quillIdentityLeadEs}'
            'Genera una página completa de notas. Por defecto sé detallado y exhaustivo (mínimo 10-15 bloques): párrafo introductorio, secciones con h2/h3, párrafos elaborados, listas y bloques de código si aplica. Si el usuario pide «corto» o «breve» limita a ~5 bloques. Adapta la extensión exactamente a lo que pida el usuario.\n'
            'Salida preferida: JSON válido con forma {"title":"...","blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|callout|divider","text":"...","checked":false,"codeLanguage":"dart","depth":0,"icon":"emoji"}]}.\n'
            'Si no puedes JSON, devuelve markdown estructurado. Sin markdown fences.\n\n'
            'Solicitud:\n${prompt.trim()}',
        model: 'auto',
        attachments: attachments,
        cloudInkOperation: 'generate_page',
      ),
    );
    final draft = _parseAiHybridOutput(
      result.text,
      defaultTitle: 'Nueva página IA',
    );
    final id = VaultSession._uuid.v4();
    final blocks = _materializeAiBlocks(id, draft.blocks);
    _pages.add(
      FolioPage(
        id: id,
        title: draft.title.trim().isEmpty ? 'Nueva página IA' : draft.title,
        parentId: parentId,
        blocks: blocks,
      ),
    );
    _selectedPageId = id;
    _notifySessionListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  List<String> _resolveAiChatContextPageIds({
    required bool includePageContext,
    required List<String> contextPageIds,
    String? scopePageId,
  }) {
    if (!includePageContext) return const [];
    final seen = <String>{};
    final out = <String>[];
    void add(String id) {
      if (_pageById(id) == null) return;
      if (seen.add(id)) out.add(id);
    }

    if (contextPageIds.isNotEmpty) {
      for (final id in contextPageIds) {
        add(id);
      }
      return out;
    }
    if (scopePageId != null) add(scopePageId);
    return out;
  }

  String _buildAiChatPagesTextContext(
    List<String> pageIds, {
    required bool isEs,
    String? activePageId,
  }) {
    if (pageIds.isEmpty) {
      return isEs
          ? '(No hay páginas de texto en el contexto.)'
          : '(No pages in the text context.)';
    }
    const maxPages = 3;
    const maxCharsPerPage = 6000;
    const maxTotalChars = 14000;
    final buf = StringBuffer();
    var refIndex = 0;
    final limitedPageIds = pageIds.length <= maxPages
        ? pageIds
        : pageIds.sublist(0, maxPages);
    for (var i = 0; i < limitedPageIds.length; i++) {
      if (buf.length >= maxTotalChars) break;
      final p = _pageById(limitedPageIds[i]);
      if (p == null) continue;
      if (buf.isNotEmpty) buf.writeln();
      final isActive = activePageId != null && p.id == activePageId;
      if (isActive) {
        buf.writeln('[ACTIVE_PAGE] ${p.title}');
      } else {
        refIndex++;
        buf.writeln('[REFERENCE_PAGE $refIndex] ${p.title}');
      }
      final content = p.plainTextContent;
      if (content.length <= maxCharsPerPage) {
        buf.writeln(content);
      } else {
        buf.writeln('${content.substring(0, maxCharsPerPage)}\n…');
      }
    }
    return buf.toString();
  }

  String _plainChatContextFromPageIds(List<String> pageIds) {
    if (pageIds.isEmpty) return '';
    final b = StringBuffer('\n\nContexto de páginas:\n');
    for (final id in pageIds) {
      final p = _pageById(id);
      if (p == null) continue;
      b.writeln('Título: ${p.title}');
      b.writeln(p.plainTextContent);
      b.writeln();
    }
    return b.toString();
  }

  /// Ayuda in-app inyectada en el agente: evita que «página» se interprete como web genérica.
  String _folioAgentInAppGuide({required bool isEs}) {
    if (isEs) {
      return '''
IDENTIDAD: Tu nombre es Quill. Si te presentas o hablas de ti, usa ese nombre.

=== Folio — no confundir con sitios web genéricos ===
En Folio, «página» = nota del árbol lateral con bloques (párrafo, imagen, tabla…). El usuario pregunta por Folio salvo que cite explícitamente WordPress, HTML, React, etc.
NO respondas con etiquetas HTML <img>, CMS ni frameworks web ante frases como «añadir imagen a la página», «bloque», «nota», «mi página en Folio».

Ayuda frecuente (respuestas breves y concretas):
• Imagen: con una página abierta, botón flotante + (abajo a la derecha) → bloque «Imagen». Alternativa: en un párrafo escribe / y elige «Imagen». En bloque vacío, «Elegir imagen»: en escritorio suele abrir el selector de archivos; en móvil, galería. Pegar una URL directa a un archivo de imagen en un bloque de texto puede convertirlo en bloque imagen. Menú ⋮ del bloque: cambiar o quitar imagen; puedes ajustar el ancho mostrado.
• Otros bloques: mismo botón + o comando / en párrafo (tabla, archivo, código, etc.).
• Panel de chat con Quill (si está activo): a la derecha; icono de libro incluye u omite texto de páginas en el contexto; otro icono elige varias páginas de referencia.
• Ajustes: engranaje. Búsqueda: lupa. Bloquear libreta: candado.
'''
          .trim();
    }
    return '''
IDENTITY: Your name is Quill. When you introduce yourself or refer to yourself, use that name.

=== Folio — not a generic website ===
In Folio a "page" is a sidebar note made of blocks. The user means Folio unless they explicitly name WordPress, HTML, React, etc.
Do NOT answer Folio how-to questions with HTML <img>, CMS steps, or web frameworks.

Quick help (be concise):
• Image: With a page open, floating + (bottom-right) → "Image" block. Or type / in a paragraph and pick Image. In an empty image block use "Choose image" (desktop: file picker; mobile: gallery). Pasting a direct image file URL in a text block may turn it into an image block. Block ⋮ menu: replace/clear; adjust width.
• Other blocks: same + button or / in a paragraph.
• Quill chat panel (when enabled): on the right; book icon toggles page text in context; another icon picks multiple reference pages.
• Settings: gear. Search: magnifying glass. Lock vault: padlock.
'''
        .trim();
  }

  String _folioAgentInAppGuideCompact({required bool isEs}) {
    if (isEs) {
      return '''
IDENTIDAD: Tu nombre es Quill.
En Folio, «página» = nota con bloques (no web). No des tutoriales HTML/WordPress salvo petición explícita.
Para imágenes y bloques: botón + o comando / en un párrafo.
'''
          .trim();
    }
    return '''
IDENTITY: Your name is Quill.
In Folio, a "page" is a note made of blocks (not a website). Do not give HTML/WordPress tutorials unless explicitly requested.
For images/blocks: use the + button or / command in a paragraph.
'''
        .trim();
  }

  String _baseLanguageCode(String languageCode) {
    final code = languageCode.trim().toLowerCase();
    if (code.isEmpty) return 'es';
    if (code.contains('_')) return code.split('_').first;
    if (code.contains('-')) return code.split('-').first;
    return code;
  }

  String _aiOutputLanguageName(
    String languageCode, {
    required bool isEsInstruction,
  }) {
    switch (_baseLanguageCode(languageCode)) {
      case 'es':
        return isEsInstruction ? 'español' : 'Spanish';
      case 'en':
        return isEsInstruction ? 'inglés' : 'English';
      case 'pt':
        return isEsInstruction ? 'portugués de Brasil' : 'Brazilian Portuguese';
      case 'ca':
        return isEsInstruction ? 'catalán/valenciano' : 'Catalan/Valencian';
      case 'gl':
        return isEsInstruction ? 'gallego' : 'Galician';
      case 'eu':
        return isEsInstruction ? 'euskera' : 'Basque';
      default:
        return isEsInstruction ? 'español' : 'English';
    }
  }

  String _aiLanguageRule(
    String languageCode, {
    required bool isEsInstruction,
  }) {
    final language = _aiOutputLanguageName(
      languageCode,
      isEsInstruction: isEsInstruction,
    );
    return isEsInstruction
        ? 'Responde SIEMPRE en $language. Mantén ese idioma incluso si las instrucciones internas están en otro idioma.'
        : 'Always respond in $language. Keep that language even if internal instructions are in another language.';
  }

  Future<({String text, AiTokenUsage? usage})> chatWithAi({
    required List<AiChatMessage> messages,
    required String prompt,
    String? scopePageId,
    bool includePageContext = true,
    List<String> contextPageIds = const [],
    List<AiFileAttachment> attachments = const [],
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final effective = _resolveAiChatContextPageIds(
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      scopePageId: scopePageId,
    );
    final scopedContext = includePageContext
        ? _plainChatContextFromPageIds(effective)
        : '';
    final isEsChat = languageCode.toLowerCase().startsWith('es');
    final folioGuide = _folioAgentInAppGuide(isEs: isEsChat);
    final languageRule = _aiLanguageRule(
      languageCode,
      isEsInstruction: isEsChat,
    );
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: '$folioGuide\n\n$languageRule\n\n${prompt.trim()}$scopedContext',
        model: 'auto',
        messages: messages,
        attachments: attachments,
        cloudInkOperation: 'chat_turn',
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  Future<AgentChatOutcome> agentChatWithAi({
    required List<AiChatMessage> messages,
    required String prompt,
    String? scopePageId,
    bool includePageContext = true,
    List<String> contextPageIds = const [],
    List<AiFileAttachment> attachments = const [],
    String languageCode = 'es',
    String? cloudInkOperation,
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    await pingAi();
    AiTokenUsage? lastUsage;
    AgentChatOutcome finish(String reply) =>
        AgentChatOutcome(reply: reply, usage: lastUsage);
    final isEs = languageCode.toLowerCase().startsWith('es');
    final scopePage = scopePageId == null ? null : _pageById(scopePageId);
    final effectiveContextIds = _resolveAiChatContextPageIds(
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      scopePageId: scopePageId,
    );
    final wantsSubpage = _looksLikeSubpageIntent(
      prompt,
      languageCode: languageCode,
    );
    final wantsCreatePage = _looksLikeCreatePageIntent(
      prompt,
      languageCode: languageCode,
    );
    final wantsEditExistingBlocks =
        scopePage != null &&
        includePageContext &&
        _looksLikeEditIntent(prompt, languageCode: languageCode);
    final promptTrimmed = prompt.trim();
    AppLogger.info(
      'Agent chat started',
      tag: 'ai.agent',
      context: {
        'languageCode': languageCode,
        'hasScopePage': scopePage != null,
        'includePageContext': includePageContext,
        'contextPageCount': effectiveContextIds.length,
        'wantsSubpage': wantsSubpage,
        'wantsCreatePage': wantsCreatePage,
        'wantsEditExistingBlocks': wantsEditExistingBlocks,
        'promptPreview': promptTrimmed.length > 140
            ? '${promptTrimmed.substring(0, 140)}...'
            : promptTrimmed,
      },
    );
    final referencePagesText = includePageContext
        ? _buildAiChatPagesTextContext(
            effectiveContextIds,
            isEs: isEs,
            activePageId: scopePageId,
          )
        : (isEs
              ? 'El usuario desactivó el contexto de páginas: no debes asumir ni citar contenido de notas.'
              : 'The user disabled page context: do not assume or quote note contents.');
    final pageBlocksContext =
        includePageContext && scopePage != null && wantsEditExistingBlocks
        ? _buildAgentPageBlocksContext(scopePage)
        : '';
    final editTargetLine = scopePage == null
        ? (isEs
              ? 'Página en edición: ninguna abierta.'
              : 'Page under edit: none open.')
        : (isEs
              ? 'Página en edición (resumen/añadir/reemplazar/editar bloques aplican SOLO aquí): ${scopePage.title}'
              : 'Page under edit (summarize/append/replace/edit blocks apply ONLY here): ${scopePage.title}');
    String resolveCloudInkOperation() {
      final raw = (cloudInkOperation ?? '').trim();
      if (raw.isNotEmpty) return raw;
      return 'agent_main';
    }

    try {
      if (wantsCreatePage) {
        if (wantsSubpage && scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: 'create_page',
              reason: isEs
                  ? 'Detecté intención de crear subpágina pero no hay página activa.'
                  : 'Detected subpage creation intent but there is no active page.',
              reply: isEs
                  ? 'Selecciona primero una página para crear la subpágina dentro.'
                  : 'Select a page first to create the subpage inside it.',
              isEs: isEs,
            ),
          );
        }

        final createdId = await generateStandalonePageWithAi(
          prompt: prompt,
          parentId: wantsSubpage ? scopePage?.id : null,
          attachments: attachments,
        );
        final created = _pageById(createdId);
        return finish(
          _formatAgentDecisionReply(
            mode: 'create_page',
            reason: isEs
                ? 'Detecté intención de crear página y ejecuté creación directa.'
                : 'Detected page creation intent and executed direct creation.',
            reply: isEs
                ? 'He creado la página "${created?.title ?? 'Nueva página IA'}" con contenido inicial.'
                : 'I created the page "${created?.title ?? 'New AI page'}" with initial content.',
            isEs: isEs,
          ),
        );
      }

      final result = await ai.complete(
        _buildAgentCompletionRequest(
          cloudInkOperation: resolveCloudInkOperation(),
          userPrompt: prompt,
          conversationMessages: messages,
          isEs: isEs,
          languageCode: languageCode,
          referencePagesText: referencePagesText,
          editTargetLine: editTargetLine,
          pageBlocksContext: pageBlocksContext,
          attachments: attachments,
        ),
      );
      lastUsage = result.usage ?? lastUsage;
      final decoded = _decodeJsonObjectLenient(result.text);
      var mode = _normalizeAgentMode(decoded['mode'] as String?);
      var reason = (decoded['reason'] as String? ?? '').trim();
      var reply = (decoded['reply'] as String? ?? '').trim();
      final title = (decoded['title'] as String? ?? 'Nueva página IA').trim();
      final rawBlocks = decoded['blocks'];
      dynamic rawOperations = decoded['operations'];
      final parsedBlocks = rawBlocks is List
          ? _parseAiBlocksFromDynamicList(rawBlocks)
          : const <_AiBlockSpec>[];

      final hasOperations = rawOperations is List && rawOperations.isNotEmpty;
      if (mode == 'edit_current' && !hasOperations) {
        // Si el modelo eligió editar pero no trajo operaciones aplicables, corregimos
        // (cuando realmente hay intención de edición) o degradamos a chat.
        if (!wantsEditExistingBlocks) {
          mode = 'chat';
        } else {
          final correction = await ai.complete(
            AiCompletionRequest(
              cloudInkOperation: 'agent_followup',
              systemPrompt: isEs
                  ? 'Eres Quill. Devuelve SOLO JSON válido según el schema. No inventes blockId.'
                  : 'You are Quill. Return ONLY valid JSON per schema. Do not invent blockId.',
              prompt:
                  '${isEs ? 'Completa la edición con operaciones aplicables.' : 'Complete the edit with applicable operations.'}\n'
                  '${isEs ? 'Devuelve SOLO JSON con mode="edit_current" y operations no vacía usando blockId reales.' : 'Return ONLY JSON with mode="edit_current" and a non-empty operations list using real blockIds.'}\n\n'
                  '$editTargetLine\n'
                  '${isEs ? 'Bloques de la página en edición (ids válidos):' : 'Blocks of the page under edit (valid ids):'}\n$pageBlocksContext\n\n'
                  '${isEs ? 'Mensaje del usuario:' : 'User message:'}\n${prompt.trim()}',
              model: 'auto',
              messages: messages,
              attachments: attachments,
              temperature: 0.1,
              responseSchema: _agentResponseSchema,
            ),
          );
          lastUsage = correction.usage ?? lastUsage;
          final correctionDecoded = _decodeJsonObjectLenient(correction.text);
          final correctionMode = _normalizeAgentMode(
            correctionDecoded['mode'] as String?,
          );
          final correctionOps = correctionDecoded['operations'];
          final correctionReason =
              (correctionDecoded['reason'] as String? ?? '').trim();
          final correctionReply = (correctionDecoded['reply'] as String? ?? '')
              .trim();
          if (correctionMode == 'edit_current' &&
              correctionOps is List &&
              correctionOps.isNotEmpty) {
            mode = correctionMode;
            rawOperations = correctionOps;
            if (correctionReason.isNotEmpty) reason = correctionReason;
            if (correctionReply.isNotEmpty) reply = correctionReply;
          } else {
            mode = 'chat';
          }
        }
      }
      if ((mode == 'append_current' ||
              mode == 'replace_current' ||
              mode == 'create_page') &&
          parsedBlocks.isEmpty) {
        // Salida no accionable: forzamos chat; para create_page, el flujo de corrección existente
        // puede volver a intentarlo más abajo si el modelo respondió con reply en chat.
        mode = 'chat';
      }
      if (wantsEditExistingBlocks && mode != 'edit_current') {
        final correction = await ai.complete(
          AiCompletionRequest(
            cloudInkOperation: 'agent_followup',
            systemPrompt: isEs
                ? 'Eres Quill. Devuelve SOLO JSON válido según el schema. No inventes blockId.'
                : 'You are Quill. Return ONLY valid JSON per schema. Do not invent blockId.',
            prompt:
                '${isEs ? 'Corrige la salida a edición de bloques existentes.' : 'Correct the output to existing-block editing.'}\n'
                '${isEs ? 'Devuelve mode="edit_current" y operations no vacía usando blockId reales de la página en edición.' : 'Return mode="edit_current" and a non-empty operations list using real blockIds from the page under edit.'}\n'
                '${isEs ? 'No crees páginas nuevas ni reemplaces todo el contenido.' : 'Do not create new pages or replace all content.'}\n\n'
                '$editTargetLine\n'
                '${isEs ? 'Bloques de la página en edición (ids válidos):' : 'Blocks of the page under edit (valid ids):'}\n$pageBlocksContext\n\n'
                '${isEs ? 'Mensaje del usuario:' : 'User message:'}\n${prompt.trim()}',
            model: 'auto',
            messages: messages,
            attachments: attachments,
            temperature: 0.1,
            responseSchema: _agentResponseSchema,
          ),
        );
        lastUsage = correction.usage ?? lastUsage;
        final correctionDecoded = _decodeJsonObjectLenient(correction.text);
        final correctionMode = _normalizeAgentMode(
          correctionDecoded['mode'] as String?,
        );
        final correctionOps = correctionDecoded['operations'];
        final correctionReason = (correctionDecoded['reason'] as String? ?? '')
            .trim();
        final correctionReply = (correctionDecoded['reply'] as String? ?? '')
            .trim();
        if (correctionMode == 'edit_current' &&
            correctionOps is List &&
            correctionOps.isNotEmpty) {
          mode = correctionMode;
          rawOperations = correctionOps;
          if (correctionReason.isNotEmpty) reason = correctionReason;
          if (correctionReply.isNotEmpty) reply = correctionReply;
        }
      }
      AppLogger.info(
        'Agent mode selected',
        tag: 'ai.agent',
        context: {
          'mode': mode,
          'reason': reason,
          'blocksCount': parsedBlocks.length,
          'hasOperations': rawOperations is List && rawOperations.isNotEmpty,
        },
      );

      _maybeApplyAgentThreadTitle(
        decoded['threadTitle'] as String?,
        conversationMessages: messages,
      );

      if (mode == 'summarize_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para resumir.'
                        : 'There is no active page to summarize.'),
              isEs: isEs,
            ),
          );
        }
        final summary = await summarizePageWithAi(
          scopePage.id,
          attachments: attachments,
          languageCode: languageCode,
        );
        lastUsage = summary.usage ?? lastUsage;
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: summary.text.isNotEmpty
                ? summary.text
                : (reply.isNotEmpty
                      ? reply
                      : (isEs ? 'Resumen vacío.' : 'Empty summary.')),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'append_current' || mode == 'replace_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para editar.'
                        : 'There is no active page to edit.'),
              isEs: isEs,
            ),
          );
        }
        final materialized = _materializeAiBlocks(scopePage.id, parsedBlocks);
        if (mode == 'replace_current') {
          scopePage.blocks = materialized;
        } else {
          scopePage.blocks.addAll(materialized);
        }
        _notifySessionListeners();
        scheduleSave(trackRevisionForPageId: scopePage.id);
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty
                ? reply
                : (mode == 'replace_current'
                      ? 'He actualizado la página.'
                      : 'He añadido contenido a la página.'),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'edit_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para editar.'
                        : 'There is no active page to edit.'),
              isEs: isEs,
            ),
          );
        }
        final changed = _applyAgentEditOperations(scopePage, rawOperations);
        if (changed) {
          _notifySessionListeners();
          scheduleSave(trackRevisionForPageId: scopePage.id);
        }
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty
                ? reply
                : (changed
                      ? (isEs
                            ? 'He editado bloques existentes de la página.'
                            : 'I edited existing page blocks.')
                      : (isEs
                            ? 'No se pudieron aplicar cambios en bloques existentes.'
                            : 'Could not apply edits to existing blocks.')),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'create_page') {
        if (wantsSubpage && scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason.isNotEmpty
                  ? reason
                  : (isEs
                        ? 'Solicitaste crear una subpágina pero no hay página activa.'
                        : 'You requested a subpage but there is no active page.'),
              reply: isEs
                  ? 'Selecciona una página y vuelvo a crear la subpágina dentro de ella.'
                  : 'Select a page and I will create the subpage inside it.',
              isEs: isEs,
            ),
          );
        }
        final id = VaultSession._uuid.v4();
        final blocks = _materializeAiBlocks(id, parsedBlocks);
        _pages.add(
          FolioPage(
            id: id,
            title: title.isEmpty ? 'Nueva página IA' : title,
            parentId: wantsSubpage ? scopePage?.id : null,
            blocks: blocks,
          ),
        );
        _selectedPageId = id;
        _notifySessionListeners();
        scheduleSave(trackRevisionForPageId: id);
        AppLogger.info(
          'Page created by agent',
          tag: 'ai.agent',
          context: {
            'pageId': id,
            'isSubpage': wantsSubpage,
            'parentId': wantsSubpage ? scopePage?.id : null,
            'title': title.isEmpty ? 'Nueva página IA' : title,
            'blocksCount': blocks.length,
          },
        );
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty ? reply : 'He creado una nueva página.',
            isEs: isEs,
          ),
        );
      }

      if (reply.isNotEmpty) {
        if (mode == 'chat' &&
            _looksLikeCreatePageIntent(prompt, languageCode: languageCode)) {
          if (wantsSubpage && scopePage == null) {
            return finish(
              _formatAgentDecisionReply(
                mode: 'create_page',
                reason: isEs
                    ? 'Detecté intención de crear subpágina pero no hay página activa.'
                    : 'Detected subpage creation intent but there is no active page.',
                reply: isEs
                    ? 'Selecciona primero una página para crear la subpágina dentro.'
                    : 'Select a page first to create the subpage inside it.',
                isEs: isEs,
              ),
            );
          }
          // Llamada de corrección estructurada: el modelo respondió en modo chat
          // cuando debería haber usado create_page. Pedimos JSON directamente.
          final createCorrection = await ai.complete(
            AiCompletionRequest(
              cloudInkOperation: 'agent_followup',
              systemPrompt: isEs
                  ? 'Eres Quill. Devuelve SOLO JSON válido según el schema.'
                  : 'You are Quill. Return ONLY valid JSON per schema.',
              prompt:
                  '${isEs ? VaultSession._quillIdentityLeadEs : VaultSession._quillIdentityLeadEn}'
                  '${isEs ? 'Respondiste en modo chat, pero el usuario quiere crear una nueva página. Devuelve SOLO JSON con mode=create_page, el título en "title" y los bloques en "blocks" usando el formato nativo de Folio. Por defecto genera contenido detallado y completo (mínimo 10-15 bloques), salvo que el mensaje original pida algo corto.' : 'You responded in chat mode, but the user wants to create a new page. Return ONLY JSON with mode=create_page, the title in "title" and the blocks in "blocks" using Folio native block format. By default generate detailed, comprehensive content (minimum 10-15 blocks), unless the original message asked for something short.'}\n'
                  '${isEs ? 'Formato de bloque nativo:' : 'Native block format:'} {"type":"paragraph|h1|h2|h3|bullet|numbered|todo|quote|code|callout|toggle|divider|table|image|file|video|audio|meeting_note|bookmark|embed|equation|mermaid","text":"...","checked":false,"expanded":true,"codeLanguage":"dart","depth":0,"icon":"emoji","url":"https://...","imageWidth":0.8,"cols":2,"rows":[["a","b"]]}\n'
                  '${isEs ? 'No uses markdown fences ni texto fuera del JSON.' : 'Do not use markdown fences or text outside JSON.'}\n\n'
                  '${isEs ? 'Mensaje original:' : 'Original message:'}\n${prompt.trim()}',
              model: 'auto',
              messages: messages,
              attachments: attachments,
              temperature: 0.1,
              responseSchema: _agentResponseSchema,
            ),
          );
          lastUsage = createCorrection.usage ?? lastUsage;
          final createDecoded = _decodeJsonObjectLenient(createCorrection.text);
          final createTitle = (createDecoded['title'] as String? ?? '').trim();
          final rawCreateBlocks = createDecoded['blocks'];
          if (rawCreateBlocks is List && rawCreateBlocks.isNotEmpty) {
            final createSpecs = _parseAiBlocksFromDynamicList(rawCreateBlocks);
            if (createSpecs.isNotEmpty) {
              final id = VaultSession._uuid.v4();
              final blocks = _materializeAiBlocks(id, createSpecs);
              _pages.add(
                FolioPage(
                  id: id,
                  title: createTitle.isEmpty
                      ? (isEs ? 'Nueva página IA' : 'New AI page')
                      : createTitle,
                  parentId: wantsSubpage ? scopePage?.id : null,
                  blocks: blocks,
                ),
              );
              _selectedPageId = id;
              _notifySessionListeners();
              scheduleSave(trackRevisionForPageId: id);
              AppLogger.info(
                'Created page from structured JSON correction call',
                tag: 'ai.agent',
                context: {
                  'pageId': id,
                  'isSubpage': wantsSubpage,
                  'blocksCount': blocks.length,
                },
              );
              return finish(
                _formatAgentDecisionReply(
                  mode: 'create_page',
                  reason: isEs
                      ? 'Corregí el modo y generé la página en formato JSON estructurado.'
                      : 'Corrected the mode and generated the page in structured JSON format.',
                  reply: isEs
                      ? 'He creado la página con el contenido generado.'
                      : 'I created the page with the generated content.',
                  isEs: isEs,
                ),
              );
            }
          }
        }
        if (scopePage != null &&
            includePageContext &&
            mode == 'chat' &&
            _looksLikeEditIntent(prompt, languageCode: languageCode) &&
            _applyRecoveredEditFromChatReply(scopePage, reply)) {
          _notifySessionListeners();
          scheduleSave(trackRevisionForPageId: scopePage.id);
          return finish(
            _formatAgentDecisionReply(
              mode: 'edit_current',
              reason: isEs
                  ? 'Detecté edición implícita y apliqué la tabla devuelta en Markdown.'
                  : 'Detected implicit edit intent and applied markdown table output.',
              reply: isEs
                  ? 'He actualizado la tabla existente de la página.'
                  : 'I updated the existing table in the page.',
              isEs: isEs,
            ),
          );
        }
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply,
            isEs: isEs,
          ),
        );
      }
      final fallbackChat = await chatWithAi(
        messages: messages,
        prompt: prompt,
        scopePageId: scopePageId,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        attachments: attachments,
        languageCode: languageCode,
      );
      AppLogger.warn(
        'Agent returned non-actionable response, using chat fallback',
        tag: 'ai.agent',
        context: {'mode': mode, 'reason': reason},
      );
      lastUsage = fallbackChat.usage ?? lastUsage;
      return finish(
        _formatAgentDecisionReply(
          mode: mode,
          reason: reason,
          reply: fallbackChat.text,
          isEs: isEs,
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Agent JSON flow failed, attempting recovery',
        tag: 'ai.agent',
        error: e,
        stackTrace: st,
      );
      if (scopePage != null && includePageContext) {
        try {
          final recovery = await ai.complete(
            AiCompletionRequest(
              cloudInkOperation: 'agent_followup',
              prompt:
                  '${isEs ? VaultSession._quillIdentityLeadEs : VaultSession._quillIdentityLeadEn}'
                  '${isEs ? 'La respuesta anterior no fue JSON válido. Corrige y devuelve SOLO JSON para editar la página actual.' : 'The previous response was not valid JSON. Fix it and return ONLY JSON to edit the current page.'}\n'
                  '{'
                  '"mode":"edit_current",'
                  '"reason":"${isEs ? 'motivo breve' : 'short reason'}",'
                  '"reply":"${isEs ? 'texto breve' : 'short text'}",'
                  '"operations":[{"kind":"update_page_title|update_block_text|update_block|replace_block|insert_after|insert_before|move_block|delete_block|table_add_column|table_set_cell","title":"...","blockId":"id","text":"...","checked":false,"expanded":true,"codeLanguage":"dart","depth":0,"icon":"emoji","url":"https://...","imageWidth":0.8,"targetIndex":0,"block":{},"blocks":[],"header":"...","values":[],"row":0,"col":0,"value":"..."}]'
                  '}\n'
                  '${isEs ? 'No escribas explicación, solo JSON.' : 'Do not write explanations, only JSON.'}\n\n'
                  '${isEs ? 'Bloques de la página (ids):' : 'Page blocks (ids):'}\n${_buildAgentPageBlocksContext(scopePage)}\n\n'
                  '${isEs ? 'Mensaje original del usuario:' : 'Original user message:'}\n${prompt.trim()}',
              model: 'auto',
              messages: messages,
              attachments: attachments,
              temperature: 0.1,
              responseSchema: _agentResponseSchema,
            ),
          );
          lastUsage = recovery.usage ?? lastUsage;
          final recovered = _decodeJsonObjectLenient(recovery.text);
          final mode = _normalizeAgentMode(recovered['mode'] as String?);
          final reason = (recovered['reason'] as String? ?? '').trim();
          final reply = (recovered['reply'] as String? ?? '').trim();
          if (mode == 'edit_current') {
            final changed = _applyAgentEditOperations(
              scopePage,
              recovered['operations'],
            );
            if (changed) {
              _notifySessionListeners();
              scheduleSave(trackRevisionForPageId: scopePage.id);
              return finish(
                _formatAgentDecisionReply(
                  mode: mode,
                  reason: reason.isEmpty
                      ? (isEs
                            ? 'Recuperé una salida estructurada y apliqué la edición.'
                            : 'Recovered structured output and applied the edit.')
                      : reason,
                  reply: reply.isEmpty
                      ? (isEs
                            ? 'He editado bloques existentes de la página.'
                            : 'I edited existing page blocks.')
                      : reply,
                  isEs: isEs,
                ),
              );
            }
          }
        } catch (recoveryError, recoveryStack) {
          AppLogger.error(
            'Agent edit recovery failed',
            tag: 'ai.agent',
            error: recoveryError,
            stackTrace: recoveryStack,
            context: {'scopePageId': scopePage.id},
          );
          // Si también falla la recuperación, caemos a chat.
        }
      }
      final fallbackChat = await chatWithAi(
        messages: messages,
        prompt: prompt,
        scopePageId: scopePageId,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        attachments: attachments,
        languageCode: languageCode,
      );
      lastUsage = fallbackChat.usage ?? lastUsage;
      final wantsCreate = _looksLikeCreatePageIntent(
        prompt,
        languageCode: languageCode,
      );
      if (wantsCreate) {
        if (wantsSubpage && scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: 'create_page',
              reason: isEs
                  ? 'Detecté intención de crear subpágina pero no hay página activa.'
                  : 'Detected subpage creation intent but there is no active page.',
              reply: isEs
                  ? 'Selecciona primero una página para crear la subpágina dentro.'
                  : 'Select a page first to create the subpage inside it.',
              isEs: isEs,
            ),
          );
        }
        // Llamada estructurada específica para create_page (el flujo principal
        // falló con JSON inválido — intentamos una llamada directa de creación).
        final createFallback = await ai.complete(
          AiCompletionRequest(
            cloudInkOperation: 'agent_followup',
            prompt:
                '${isEs ? VaultSession._quillIdentityLeadEs : VaultSession._quillIdentityLeadEn}'
                '${isEs ? 'La respuesta anterior no fue JSON válido. El usuario quiere crear una página. Devuelve SOLO JSON con mode=create_page, el título en "title" y los bloques en "blocks". Por defecto genera contenido detallado y completo (mínimo 10-15 bloques), salvo que el mensaje original pida algo corto.' : 'The previous response was not valid JSON. The user wants to create a page. Return ONLY JSON with mode=create_page, the title in "title" and the blocks in "blocks". By default generate detailed, comprehensive content (minimum 10-15 blocks), unless the original message asked for something short.'}\n'
                '${isEs ? 'Formato de bloque:' : 'Block format:'} {"type":"paragraph|h1|h2|h3|bullet|numbered|todo|quote|code|callout|toggle|divider|table|image|file|video|audio|meeting_note|bookmark|embed|equation|mermaid","text":"...","checked":false,"expanded":true,"codeLanguage":"dart","depth":0,"icon":"emoji","url":"https://...","imageWidth":0.8,"cols":2,"rows":[["a","b"]]}\n'
                '${isEs ? 'No uses markdown fences ni texto fuera del JSON.' : 'Do not use markdown fences or text outside JSON.'}\n\n'
                '${isEs ? 'Mensaje original:' : 'Original message:'}\n${prompt.trim()}',
            model: 'auto',
            messages: messages,
            attachments: attachments,
            temperature: 0.1,
            responseSchema: _agentResponseSchema,
          ),
        );
        lastUsage = createFallback.usage ?? lastUsage;
        final createFbDecoded = _decodeJsonObjectLenient(createFallback.text);
        final createFbTitle = (createFbDecoded['title'] as String? ?? '')
            .trim();
        final rawFbBlocks = createFbDecoded['blocks'];
        if (rawFbBlocks is List && rawFbBlocks.isNotEmpty) {
          final fbSpecs = _parseAiBlocksFromDynamicList(rawFbBlocks);
          if (fbSpecs.isNotEmpty) {
            final id = VaultSession._uuid.v4();
            final blocks = _materializeAiBlocks(id, fbSpecs);
            _pages.add(
              FolioPage(
                id: id,
                title: createFbTitle.isEmpty
                    ? (isEs ? 'Nueva página IA' : 'New AI page')
                    : createFbTitle,
                parentId: wantsSubpage ? scopePage?.id : null,
                blocks: blocks,
              ),
            );
            _selectedPageId = id;
            _notifySessionListeners();
            scheduleSave(trackRevisionForPageId: id);
            AppLogger.warn(
              'Created page from structured fallback call (main JSON failed)',
              tag: 'ai.agent',
              context: {
                'pageId': id,
                'isSubpage': wantsSubpage,
                'blocksCount': blocks.length,
              },
            );
            return finish(
              _formatAgentDecisionReply(
                mode: 'create_page',
                reason: isEs
                    ? 'La respuesta inicial no fue JSON válido; generé la página con una llamada estructurada.'
                    : 'Initial response was not valid JSON; generated the page with a structured call.',
                reply: isEs
                    ? 'He creado la página con el contenido generado.'
                    : 'I created the page with the generated content.',
                isEs: isEs,
              ),
            );
          }
        }
      }
      return finish(
        _formatAgentDecisionReply(
          mode: 'chat',
          reason: isEs
              ? 'No pude estructurar la acción; respondo en modo conversación.'
              : 'I could not structure the action; responding in chat mode.',
          reply: fallbackChat.text,
          isEs: isEs,
        ),
      );
    }
  }

  String _buildAgentPageBlocksContext(FolioPage page, {int maxBlocks = 80}) {
    final slice = page.blocks.length <= maxBlocks
        ? page.blocks
        : page.blocks.sublist(0, maxBlocks);
    final items = slice.map((b) {
      final preview = _agentBlockPreview(b);
      final m = <String, dynamic>{
        'id': b.id,
        'type': b.type,
        'preview': preview,
        if (preview.endsWith('...')) 'isTruncated': true,
      };
      if (b.type == 'table') {
        final t = FolioTableData.tryParse(b.text);
        if (t != null) {
          m['tableCols'] = t.cols;
          m['tableRows'] = t.rowCount;
        }
      }
      return m;
    }).toList();
    return jsonEncode(items);
  }

  String _agentBlockPreview(FolioBlock block) {
    final raw =
        (block.type == 'table'
                ? FolioTableData.plainTextFromJson(block.text)
                : block.text)
            .trim();
    if (raw.isEmpty) return '';
    return raw.length <= 140 ? raw : '${raw.substring(0, 140)}...';
  }

  bool _applyAgentEditOperations(FolioPage page, dynamic rawOperations) {
    if (rawOperations is! List) return false;
    var changed = false;
    for (final opRaw in rawOperations) {
      if (opRaw is! Map) continue;
      final op = Map<String, dynamic>.from(opRaw);
      final kind = (op['kind'] as String? ?? '').trim().toLowerCase();

      if (kind == 'update_page_title') {
        final newTitle = (op['title'] as String? ?? '').trim();
        if (newTitle.isNotEmpty) {
          page.title = newTitle;
          changed = true;
        }
        continue;
      }

      final blockId = (op['blockId'] as String? ?? '').trim();
      final index = blockId.isEmpty
          ? -1
          : page.blocks.indexWhere((b) => b.id == blockId);
      if (index < 0 && blockId.isNotEmpty && kind != 'update_page_title') {
        AppLogger.warn(
          'Agent operation skipped: blockId not found',
          tag: 'ai.agent',
          context: {'kind': kind, 'blockId': blockId},
        );
      }

      if (kind == 'update_block_text') {
        final text = (op['text'] as String? ?? '').trim();
        if (index >= 0 && text.isNotEmpty) {
          page.blocks[index].text = text;
          changed = true;
        }
        continue;
      }

      if (kind == 'update_block') {
        if (index < 0) continue;
        final block = page.blocks[index];
        final text = (op['text'] as String? ?? '').trim();
        if (text.isNotEmpty && text != block.text) {
          block.text = text;
          changed = true;
        }
        final checked = op['checked'];
        if (checked is bool &&
            block.type == 'todo' &&
            checked != block.checked) {
          block.checked = checked;
          changed = true;
        }
        final expanded = op['expanded'];
        if (expanded is bool &&
            block.type == 'toggle' &&
            expanded != block.expanded) {
          block.expanded = expanded;
          changed = true;
        }
        final codeLanguage = (op['codeLanguage'] as String? ?? '').trim();
        if (block.type == 'code' &&
            codeLanguage.isNotEmpty &&
            codeLanguage != block.codeLanguage) {
          block.codeLanguage = codeLanguage;
          changed = true;
        }
        final depth = (op['depth'] as num?)?.toInt();
        if (depth != null && depth >= 0 && depth != block.depth) {
          block.depth = depth;
          changed = true;
        }
        final icon = (op['icon'] as String? ?? '').trim();
        if (icon.isNotEmpty && icon != block.icon) {
          block.icon = icon;
          changed = true;
        }
        final url = (op['url'] as String? ?? '').trim();
        if (url.isNotEmpty && url != block.url) {
          block.url = url;
          changed = true;
        }
        final imageWidth = (op['imageWidth'] as num?)?.toDouble();
        if (imageWidth != null &&
            imageWidth > 0 &&
            imageWidth <= 1.0 &&
            imageWidth != block.imageWidth) {
          block.imageWidth = imageWidth;
          changed = true;
        }
        continue;
      }

      if (kind == 'replace_block') {
        final blockMap = op['block'];
        if (index >= 0 && blockMap is Map) {
          final parsed = _parseAiBlocksFromDynamicList([
            Map<String, dynamic>.from(blockMap),
          ]);
          final mats = _materializeAiBlocks(page.id, parsed);
          if (mats.isNotEmpty) {
            page.blocks[index] = mats.first;
            changed = true;
          }
        }
        continue;
      }

      if (kind == 'insert_after') {
        final blocks = op['blocks'];
        if (index >= 0 && blocks is List) {
          final parsed = _parseAiBlocksFromDynamicList(blocks);
          final mats = _materializeAiBlocks(page.id, parsed);
          if (mats.isNotEmpty) {
            page.blocks.insertAll(index + 1, mats);
            changed = true;
          }
        }
        continue;
      }

      if (kind == 'insert_before') {
        final blocks = op['blocks'];
        if (index >= 0 && blocks is List) {
          final parsed = _parseAiBlocksFromDynamicList(blocks);
          final mats = _materializeAiBlocks(page.id, parsed);
          if (mats.isNotEmpty) {
            page.blocks.insertAll(index, mats);
            changed = true;
          }
        }
        continue;
      }

      if (kind == 'move_block') {
        if (index < 0) continue;
        final targetIndex = (op['targetIndex'] as num?)?.toInt();
        if (targetIndex == null) continue;
        final block = page.blocks.removeAt(index);
        var insertAt = targetIndex;
        if (insertAt < 0) insertAt = 0;
        if (insertAt > page.blocks.length) insertAt = page.blocks.length;
        page.blocks.insert(insertAt, block);
        changed = true;
        continue;
      }

      if (kind == 'delete_block') {
        if (index >= 0 && page.blocks.length > 1) {
          page.blocks.removeAt(index);
          changed = true;
        }
        continue;
      }

      if (kind == 'table_add_column') {
        if (index < 0 || page.blocks[index].type != 'table') continue;
        final table = FolioTableData.tryParse(page.blocks[index].text);
        if (table == null) continue;
        final header = (op['header'] as String? ?? '').trim();
        final valuesRaw = op['values'];
        final values = valuesRaw is List
            ? valuesRaw.map((e) => e?.toString() ?? '').toList()
            : const <String>[];
        final previousCols = table.cols;
        table.addCol();
        final newCol = previousCols;
        if (header.isNotEmpty) {
          table.setCell(0, newCol, header);
        }
        for (var row = 1; row < table.rowCount; row++) {
          final i = row - 1;
          final value = i < values.length ? values[i] : '';
          if (value.isNotEmpty) {
            table.setCell(row, newCol, value);
          }
        }
        page.blocks[index].text = table.encode();
        changed = true;
        continue;
      }

      if (kind == 'table_set_cell') {
        if (index < 0 || page.blocks[index].type != 'table') continue;
        final table = FolioTableData.tryParse(page.blocks[index].text);
        if (table == null) continue;
        final row = (op['row'] as num?)?.toInt();
        final col = (op['col'] as num?)?.toInt();
        final value = (op['value'] as String? ?? '');
        if (row == null || col == null || row < 0 || col < 0) continue;
        table.setCell(row, col, value);
        page.blocks[index].text = table.encode();
        changed = true;
      }
    }
    return changed;
  }

  Map<String, dynamic> get _agentResponseSchema => <String, dynamic>{
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, dynamic>{
      'mode': <String, dynamic>{'type': 'string'},
      'reason': <String, dynamic>{'type': 'string'},
      'reply': <String, dynamic>{'type': 'string'},
      'title': <String, dynamic>{'type': 'string'},
      'threadTitle': <String, dynamic>{'type': 'string'},
      'blocks': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'additionalProperties': false,
          'properties': <String, dynamic>{
            'type': <String, dynamic>{'type': 'string'},
            'text': <String, dynamic>{'type': 'string'},
            'checked': <String, dynamic>{'type': 'boolean'},
            'expanded': <String, dynamic>{'type': 'boolean'},
            'codeLanguage': <String, dynamic>{'type': 'string'},
            'depth': <String, dynamic>{'type': 'integer', 'minimum': 0},
            'icon': <String, dynamic>{'type': 'string'},
            'url': <String, dynamic>{'type': 'string'},
            'imageWidth': <String, dynamic>{'type': 'number'},
            'cols': <String, dynamic>{'type': 'integer'},
            'rows': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{
                'type': 'array',
                'items': <String, dynamic>{'type': 'string'},
              },
            },
          },
          'required': <String>[
            'type',
            'text',
            'checked',
            'expanded',
            'codeLanguage',
            'depth',
            'icon',
            'url',
            'imageWidth',
            'cols',
            'rows',
          ],
        },
      },
      'operations': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'additionalProperties': false,
          'properties': <String, dynamic>{
            'type': <String, dynamic>{'type': 'string'},
            'at': <String, dynamic>{'type': 'integer'},
            'index': <String, dynamic>{'type': 'integer'},
            'before': <String, dynamic>{'type': 'string'},
            'text': <String, dynamic>{'type': 'string'},
            'value': <String, dynamic>{'type': 'string'},
            'col': <String, dynamic>{'type': 'integer'},
            'row': <String, dynamic>{'type': 'integer'},
            'title': <String, dynamic>{'type': 'string'},
            'rows': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{
                'type': 'array',
                'items': <String, dynamic>{'type': 'string'},
              },
            },
          },
          'required': <String>[
            'type',
            'at',
            'index',
            'before',
            'text',
            'value',
            'col',
            'row',
            'title',
            'rows',
          ],
        },
      },
    },
    'required': <String>[
      'mode',
      'reason',
      'reply',
      'title',
      'threadTitle',
      'blocks',
      'operations',
    ],
  };

  bool _looksLikeEditIntent(String prompt, {required String languageCode}) {
    final p = _normalizeIntentText(prompt);
    if (p.contains('?') && p.length < 42) return false;
    const negationPrefixes = [
      'no ',
      'no,',
      "don't ",
      'dont ',
      'do not ',
      'sin ',
      'evitar ',
      'without ',
      'avoid ',
    ];
    if (negationPrefixes.any(p.startsWith)) return false;
    if (_looksLikeCreatePageIntent(prompt, languageCode: languageCode)) {
      return false;
    }

    final explicitExistingTargets = [
      'pagina actual',
      'esta pagina',
      'current page',
      'this page',
      'bloque',
      'blocks',
      'block ',
    ];
    final editVerbs = [
      'edita',
      'editar',
      'modifica',
      'modificar',
      'actualiza',
      'actualizar',
      'corrige',
      'corregir',
      'reescribe',
      'rewrite',
      'edit',
      'update',
      'modify',
      'fix',
    ];
    final hasEditVerb = editVerbs.any((v) => _containsIntentPhrase(p, v));
    final hasExistingTarget = explicitExistingTargets.any(
      (t) => _containsIntentPhrase(p, t),
    );
    if (hasEditVerb && hasExistingTarget) return true;

    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.edit,
      languageCode: languageCode,
    );
    return hints.any((h) => _containsIntentPhrase(p, h));
  }

  bool _looksLikeCreatePageIntent(
    String prompt, {
    required String languageCode,
  }) {
    final p = _normalizeIntentText(prompt);
    const weakConversationalStarts = [
      'que es',
      'como funciona',
      'explica',
      'what is',
      'how does',
      'explain',
    ];
    if (weakConversationalStarts.any((s) => p.startsWith(s))) return false;

    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.createPage,
      languageCode: languageCode,
    );
    if (hints.any((h) => _containsIntentPhrase(p, h))) return true;

    final hasPagina =
        _containsIntentPhrase(p, 'pagina') ||
        _containsIntentPhrase(p, 'page') ||
        _containsIntentPhrase(p, 'nota') ||
        _containsIntentPhrase(p, 'note') ||
        _containsIntentPhrase(p, 'documento') ||
        _containsIntentPhrase(p, 'document');
    final hasCreateVerb =
        _containsIntentPhrase(p, 'crea') ||
        _containsIntentPhrase(p, 'crear') ||
        _containsIntentPhrase(p, 'creame') ||
        _containsIntentPhrase(p, 'genera') ||
        _containsIntentPhrase(p, 'generate') ||
        _containsIntentPhrase(p, 'create') ||
        _containsIntentPhrase(p, 'hazme') ||
        _containsIntentPhrase(p, 'from scratch') ||
        _containsIntentPhrase(p, 'desde cero');
    return hasPagina && hasCreateVerb;
  }

  bool _looksLikeSubpageIntent(String prompt, {required String languageCode}) {
    final p = _normalizeIntentText(prompt);
    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.subpage,
      languageCode: languageCode,
    );
    return hints.any((h) => _containsIntentPhrase(p, h));
  }

  bool _containsIntentPhrase(String normalizedText, String phrase) {
    final p = phrase.trim().toLowerCase();
    if (p.isEmpty) return false;
    if (p.contains(' ')) return normalizedText.contains(p);
    final tokens = normalizedText
        .split(RegExp(r'[^a-z0-9_]+'))
        .where((t) => t.isNotEmpty);
    return tokens.contains(p);
  }

  String _normalizeIntentText(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  bool _applyRecoveredEditFromChatReply(FolioPage page, String reply) {
    final htmlSpecs = _parseHtmlToSpecs(reply);
    if (htmlSpecs.isNotEmpty) {
      final blocks = _materializeAiBlocks(page.id, htmlSpecs);
      final tableIdx = page.blocks.indexWhere((b) => b.type == 'table');
      if (tableIdx >= 0) {
        final firstTable = blocks.firstWhereOrNull((b) => b.type == 'table');
        if (firstTable != null) {
          page.blocks[tableIdx].text = firstTable.text;
          return true;
        }
      }
      page.blocks.addAll(blocks);
      return true;
    }
    final recoveredTable = _parseFirstMarkdownTable(reply);
    if (recoveredTable == null) return false;
    final tableIdx = page.blocks.indexWhere((b) => b.type == 'table');
    if (tableIdx >= 0) {
      page.blocks[tableIdx].text = recoveredTable.encode();
      return true;
    }
    page.blocks.add(
      FolioBlock(
        id: '${page.id}_${VaultSession._uuid.v4()}',
        type: 'table',
        text: recoveredTable.encode(),
      ),
    );
    return true;
  }

  String? _createPageFromRecoveredReply(
    String reply, {
    required bool isEs,
    String? parentId,
  }) {
    final cleanedRaw = _stripAgentDecisionHeader(reply);
    final cleaned = _stripConversationalPreambleForRecoveredPage(cleanedRaw);
    final htmlSpecs = _parseHtmlToSpecs(cleaned);
    final markdownSpecs = _parseMarkdownToSpecs(cleaned);
    final chosen = htmlSpecs.isNotEmpty ? htmlSpecs : markdownSpecs;
    final finalSpecs = chosen.isEmpty
        ? <_AiBlockSpec>[_AiBlockSpec(type: 'paragraph', text: cleaned.trim())]
        : chosen;
    if (finalSpecs.isEmpty || cleaned.trim().isEmpty) return null;
    final id = VaultSession._uuid.v4();
    final blocks = _materializeAiBlocks(id, finalSpecs);
    final title =
        _extractRecoveredPageTitle(cleanedRaw) ??
        _extractTitleFromHtml(cleaned) ??
        (isEs ? 'Nueva página IA' : 'New AI page');
    _pages.add(
      FolioPage(
        id: id,
        title: title.trim().isEmpty
            ? (isEs ? 'Nueva página IA' : 'New AI page')
            : title.trim(),
        parentId: parentId,
        blocks: blocks,
      ),
    );
    _selectedPageId = id;
    _notifySessionListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  String? _extractRecoveredPageTitle(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final subpageRe = RegExp(
      r'^\s*(?:[-*]\s*)?(?:📌\s*)?(?:\*\*)?(?:subp[aá]gina|subpage|child page)(?:\*\*)?\s*:\s*["“]?(.+?)["”]?\s*$',
      caseSensitive: false,
    );
    final headingRe = RegExp(r'^\s*#{1,2}\s+(.+?)\s*$');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final sub = subpageRe.firstMatch(line);
      if (sub != null) {
        final t = _stripMarkdownInlineDecorations(sub.group(1) ?? '');
        if (t.isNotEmpty) return t;
      }
      final heading = headingRe.firstMatch(line);
      if (heading != null) {
        final t = _stripMarkdownInlineDecorations(heading.group(1) ?? '');
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  String _stripConversationalPreambleForRecoveredPage(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final kept = <String>[];
    var started = false;
    final subpageRe = RegExp(
      r'^\s*(?:[-*]\s*)?(?:📌\s*)?(?:\*\*)?(?:subp[aá]gina|subpage|child page)(?:\*\*)?\s*:\s*',
      caseSensitive: false,
    );
    bool isStructural(String l) {
      final t = l.trimLeft();
      if (t.startsWith('#') ||
          t.startsWith('- ') ||
          t.startsWith('* ') ||
          t.startsWith('>') ||
          t.startsWith('|') ||
          t.startsWith('```')) {
        return true;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(t)) return true;
      return subpageRe.hasMatch(t);
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final normalized = _normalizeIntentText(trimmed);
      if (!started) {
        final looksPreamble =
            normalized.startsWith('aqui tienes') ||
            normalized.startsWith('te dejo') ||
            normalized.startsWith('a continuacion') ||
            normalized.startsWith('here is') ||
            normalized.startsWith('here you have') ||
            normalized.startsWith('i created');
        if (trimmed.isEmpty ||
            looksPreamble ||
            trimmed == '---' ||
            trimmed == '___') {
          continue;
        }
        if (isStructural(trimmed)) {
          started = true;
          if (!subpageRe.hasMatch(trimmed)) {
            kept.add(line);
          }
          continue;
        }
        started = true;
        kept.add(line);
        continue;
      }
      if (subpageRe.hasMatch(trimmed)) {
        // Ya usamos esta línea como posible título.
        continue;
      }
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  String _stripMarkdownInlineDecorations(String input) {
    var out = input.trim();
    out = out.replaceAll(RegExp(r'[*_`]+'), '');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out.trim();
  }

  String _stripAgentDecisionHeader(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    var skipping = true;
    for (final line in lines) {
      final t = line.trimLeft();
      if (skipping &&
          (t.startsWith('🧠') ||
              t.startsWith('💡') ||
              t.startsWith('**Decisión') ||
              t.startsWith('**Motivo') ||
              t.startsWith('**Agent decision') ||
              t.startsWith('**Reason'))) {
        continue;
      }
      if (skipping && t.isEmpty) {
        continue;
      }
      skipping = false;
      out.add(line);
    }
    return out.join('\n').trim();
  }

  String _normalizeAgentMode(String? raw) {
    const allowed = {
      'chat',
      'summarize_current',
      'append_current',
      'replace_current',
      'edit_current',
      'create_page',
    };
    final value = (raw ?? '').trim().toLowerCase();
    if (allowed.contains(value)) return value;

    const aliases = <String, String>{
      'create': 'create_page',
      'createpage': 'create_page',
      'new_page': 'create_page',
      'newpage': 'create_page',
      'edit': 'edit_current',
      'update': 'edit_current',
      'append': 'append_current',
      'replace': 'replace_current',
      'summarize': 'summarize_current',
      'summary': 'summarize_current',
    };
    final aliased = aliases[value];
    if (aliased != null) return aliased;

    final split = value
        .split(RegExp(r'[|,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final token in split) {
      if (allowed.contains(token)) return token;
      final mapped = aliases[token];
      if (mapped != null) return mapped;
    }
    if (value.contains('create_page')) return 'create_page';
    if (value.contains('edit_current')) return 'edit_current';
    if (value.contains('replace_current')) return 'replace_current';
    if (value.contains('append_current')) return 'append_current';
    if (value.contains('summarize_current')) return 'summarize_current';
    return 'chat';
  }

  String? _extractTitleFromHtml(String html) {
    final titleMatch = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      final t = _stripHtmlTags(titleMatch.group(1) ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    final h1Match = RegExp(
      r'<h1[^>]*>([\s\S]*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1Match != null) {
      final t = _stripHtmlTags(h1Match.group(1) ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  List<_AiBlockSpec> _parseHtmlToSpecs(String raw) {
    if (!_looksLikeHtml(raw)) return const [];
    var html = raw.replaceAll('\r\n', '\n');
    html = html.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );
    final specs = <_AiBlockSpec>[];

    final h1 = RegExp(
      r'<h1[^>]*>(.*?)</h1>',
      caseSensitive: false,
      dotAll: true,
    );
    final h2 = RegExp(
      r'<h2[^>]*>(.*?)</h2>',
      caseSensitive: false,
      dotAll: true,
    );
    final h3 = RegExp(
      r'<h3[^>]*>(.*?)</h3>',
      caseSensitive: false,
      dotAll: true,
    );
    final p = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
    final li = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final bq = RegExp(
      r'<blockquote[^>]*>(.*?)</blockquote>',
      caseSensitive: false,
      dotAll: true,
    );
    final pre = RegExp(
      r'<pre[^>]*>(.*?)</pre>',
      caseSensitive: false,
      dotAll: true,
    );
    final hr = RegExp(r'<hr[^>]*/?>', caseSensitive: false, dotAll: true);

    final table = _parseFirstHtmlTable(html);
    if (table != null) {
      specs.add(
        _AiBlockSpec(
          type: 'table',
          text: '',
          tableCols: table.cols,
          tableRows: _tableRowsFromData(table),
        ),
      );
    }
    for (final m in h1.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h1', text: t));
    }
    for (final m in h2.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h2', text: t));
    }
    for (final m in h3.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h3', text: t));
    }
    for (final m in p.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'paragraph', text: t));
    }
    for (final m in li.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'bullet', text: t));
    }
    for (final m in bq.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'quote', text: t));
    }
    for (final m in pre.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) {
        specs.add(_AiBlockSpec(type: 'code', text: t, codeLanguage: 'text'));
      }
    }
    if (hr.hasMatch(html)) {
      specs.add(const _AiBlockSpec(type: 'divider', text: ''));
    }
    return specs;
  }

  bool _looksLikeHtml(String s) {
    final t = s.toLowerCase();
    return t.contains('<html') ||
        t.contains('<body') ||
        t.contains('<p>') ||
        t.contains('<h1') ||
        t.contains('<table') ||
        t.contains('</');
  }

  String _stripHtmlTags(String s) {
    return s
        .replaceAll(
          RegExp(r'<br\s*/?>', caseSensitive: false, dotAll: true),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  FolioTableData? _parseFirstHtmlTable(String html) {
    final tableMatch = RegExp(
      r'<table[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return null;
    final tableHtml = tableMatch.group(1) ?? '';
    final rowMatches = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(tableHtml).toList();
    if (rowMatches.isEmpty) return null;
    final rows = <List<String>>[];
    for (final rowMatch in rowMatches) {
      final rowHtml = rowMatch.group(1) ?? '';
      final cellMatches = RegExp(
        r'<t[hd][^>]*>(.*?)</t[hd]>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(rowHtml);
      final row = <String>[];
      for (final cell in cellMatches) {
        row.add(_stripHtmlTags(cell.group(1) ?? ''));
      }
      if (row.isNotEmpty) rows.add(row);
    }
    if (rows.isEmpty) return null;
    final cols = rows
        .fold<int>(0, (m, r) => r.length > m ? r.length : m)
        .clamp(1, 32);
    final cells = <String>[];
    for (final row in rows) {
      for (var c = 0; c < cols; c++) {
        cells.add(c < row.length ? row[c] : '');
      }
    }
    return FolioTableData(cols: cols, cells: cells);
  }

  List<List<String>> _tableRowsFromData(FolioTableData table) {
    final rows = <List<String>>[];
    for (var r = 0; r < table.rowCount; r++) {
      final row = <String>[];
      for (var c = 0; c < table.cols; c++) {
        row.add(table.cellAt(r, c));
      }
      rows.add(row);
    }
    return rows;
  }

  FolioTableData? _parseFirstMarkdownTable(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length - 1; i++) {
      final header = lines[i];
      final sep = lines[i + 1];
      if (!_isMarkdownTableRow(header) || !_isMarkdownTableSeparator(sep)) {
        continue;
      }
      final rows = <List<String>>[_splitMarkdownRow(header)];
      var j = i + 2;
      while (j < lines.length && _isMarkdownTableRow(lines[j])) {
        rows.add(_splitMarkdownRow(lines[j]));
        j++;
      }
      if (rows.isEmpty) return null;
      final cols = rows
          .fold<int>(0, (m, r) => r.length > m ? r.length : m)
          .clamp(1, 32);
      final cells = <String>[];
      for (final row in rows) {
        for (var c = 0; c < cols; c++) {
          cells.add(c < row.length ? row[c] : '');
        }
      }
      return FolioTableData(cols: cols, cells: cells);
    }
    return null;
  }

  bool _isMarkdownTableRow(String line) {
    return line.contains('|') && line.split('|').length >= 3;
  }

  bool _isMarkdownTableSeparator(String line) {
    if (!line.contains('|')) return false;
    final cells = _splitMarkdownRow(line);
    if (cells.isEmpty) return false;
    for (final c in cells) {
      final t = c.replaceAll(':', '').replaceAll('-', '').trim();
      if (t.isNotEmpty) return false;
    }
    return true;
  }

  List<String> _splitMarkdownRow(String line) {
    var work = line.trim();
    if (work.startsWith('|')) work = work.substring(1);
    if (work.endsWith('|')) work = work.substring(0, work.length - 1);
    return work.split('|').map((c) => c.trim()).toList();
  }

  String _formatAgentDecisionReply({
    required String mode,
    required String reason,
    required String reply,
    required bool isEs,
  }) {
    final cleanMode = mode.trim().isEmpty ? 'chat' : mode.trim();
    final cleanReason = reason.trim().isEmpty
        ? (isEs
              ? 'Selección automática según el contexto del mensaje.'
              : 'Automatic selection based on message context.')
        : reason.trim();
    final cleanReply = reply.trim().isEmpty
        ? (isEs ? 'Listo.' : 'Done.')
        : reply.trim();
    final decisionLabel = isEs ? 'Decisión de Quill' : "Quill's decision";
    final reasonLabel = isEs ? 'Motivo' : 'Reason';
    return '🧠 **$decisionLabel:** `$cleanMode`\n'
        '💡 **$reasonLabel:** $cleanReason\n\n'
        '$cleanReply';
  }

  Future<String> editPageWithAi({
    required String pageId,
    required String prompt,
    required List<AiChatMessage> messages,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final result = await ai.complete(
      AiCompletionRequest(
        cloudInkOperation: 'edit_page_panel',
        prompt:
            '${VaultSession._quillIdentityLeadEs}'
            'Decide si la solicitud del usuario es para editar la página activa o para responder en chat.\n'
            'Devuelve SOLO JSON válido con este esquema:\n'
            '{'
            '"mode":"edit|chat",'
            '"reply":"texto breve para el usuario",'
            '"operations":[{"kind":"update_page_title|append_blocks|replace_page","title":"nuevo título si renombrar","blocks":[...]}]'
            '}\n'
            'Para renombrar la página usa una operación {"kind":"update_page_title","title":"..."} (puede ir sola o junto a otras).\n'
            'Bloques permitidos: paragraph,h1,h2,h3,bullet,numbered,todo,quote,code,callout,toggle,divider,table,image,file,video,audio,meeting_note,bookmark,embed,equation,mermaid.\n'
            'Para table usa: {"type":"table","cols":N,"rows":[["c1","c2"],["v1","v2"]]}.\n'
            'Para code puedes añadir codeLanguage. Para todo puedes añadir checked.\n'
            'No uses markdown ni texto fuera del JSON.\n\n'
            'Página actual:\n'
            'Título: ${page.title}\n'
            'Contenido:\n${page.plainTextContent}\n\n'
            'Solicitud del usuario:\n${prompt.trim()}',
        model: 'auto',
        messages: messages,
        attachments: attachments,
      ),
    );
    final decoded = _decodeJsonObjectLenient(result.text);
    final mode = (decoded['mode'] as String? ?? 'chat').trim().toLowerCase();
    final reply = (decoded['reply'] as String? ?? '').trim();
    if (mode != 'edit') {
      if (reply.isNotEmpty) return reply;
      return 'Entendido.';
    }
    final ops = decoded['operations'];
    if (ops is! List || ops.isEmpty) {
      return reply.isNotEmpty ? reply : 'No encontré cambios para aplicar.';
    }
    var changed = false;
    for (final op in ops) {
      if (op is! Map<String, dynamic>) continue;
      final kind = (op['kind'] as String? ?? '').trim().toLowerCase();
      if (kind == 'update_page_title') {
        final newTitle = (op['title'] as String? ?? '').trim();
        if (newTitle.isNotEmpty) {
          page.title = newTitle;
          changed = true;
        }
        continue;
      }
      final rawBlocks = op['blocks'];
      if (rawBlocks is! List) continue;
      final parsedBlocks = _parseAiBlocksFromDynamicList(rawBlocks);
      final materialized = _materializeAiBlocks(page.id, parsedBlocks);
      if (kind == 'replace_page') {
        page.blocks = materialized;
        changed = true;
        continue;
      }
      if (kind == 'append_blocks') {
        for (final b in materialized) {
          page.blocks.add(b);
        }
        changed = true;
      }
    }
    if (changed) {
      _notifySessionListeners();
      scheduleSave(trackRevisionForPageId: page.id);
      return reply.isNotEmpty ? reply : 'He aplicado los cambios en la página.';
    }
    return reply.isNotEmpty ? reply : 'No se aplicaron cambios.';
  }

  _AiPageDraft _parseAiHybridOutput(
    String raw, {
    required String defaultTitle,
  }) {
    final cleaned = raw
        .trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      final map = _decodeJsonObjectLenient(cleaned);
      final title = (map['title'] as String? ?? defaultTitle).trim();
      final blocksRaw = map['blocks'] as List<dynamic>? ?? const [];
      final blocks = _parseAiBlocksFromDynamicList(blocksRaw);
      if (blocks.isEmpty) {
        blocks.addAll(_parseMarkdownToSpecs(cleaned));
      }
      return _AiPageDraft(title: title, blocks: blocks);
    } catch (_) {
      final recoveredBlocks = _recoverBlocksFromMalformedJson(cleaned);
      if (recoveredBlocks.isNotEmpty) {
        return _AiPageDraft(title: defaultTitle, blocks: recoveredBlocks);
      }
      final specs = _parseMarkdownToSpecs(cleaned);
      return _AiPageDraft(title: defaultTitle, blocks: specs);
    }
  }

  Map<String, dynamic> _decodeJsonObjectLenient(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final first = raw.indexOf('{');
      final last = raw.lastIndexOf('}');
      if (first >= 0 && last > first) {
        final slice = raw.substring(first, last + 1);
        return jsonDecode(slice) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  List<_AiBlockSpec> _recoverBlocksFromMalformedJson(String raw) {
    final out = <_AiBlockSpec>[];
    final blockRegex = RegExp(
      r'"type"\s*:\s*"([^"]+)"[\s\S]*?"text"\s*:\s*"([^"]+)"',
      multiLine: true,
    );
    for (final m in blockRegex.allMatches(raw)) {
      final type = _normalizeAiBlockType(m.group(1) ?? 'paragraph');
      final text = (m.group(2) ?? '').replaceAll(r'\"', '"').trim();
      if (text.isEmpty && type != 'divider') continue;
      out.add(_AiBlockSpec(type: type, text: text));
    }
    return out;
  }

  List<_AiBlockSpec> _parseAiBlocksFromDynamicList(List<dynamic> blocksRaw) {
    final blocks = <_AiBlockSpec>[];
    for (final e in blocksRaw) {
      if (e is String) {
        final text = e.trim();
        if (text.isNotEmpty) {
          blocks.add(_AiBlockSpec(type: 'paragraph', text: text));
        }
        continue;
      }
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final type = _normalizeAiBlockType(
        (map['type'] as String? ?? 'paragraph').trim(),
      );
      if (type == 'divider') {
        blocks.add(const _AiBlockSpec(type: 'divider', text: ''));
        continue;
      }
      if (type == 'table') {
        final cols = (map['cols'] as num?)?.toInt();
        final rawRows = map['rows'];
        final rows = <List<String>>[];
        if (rawRows is List) {
          for (final row in rawRows) {
            if (row is List) {
              rows.add(row.map((c) => c?.toString() ?? '').toList());
            }
          }
        }
        blocks.add(
          _AiBlockSpec(
            type: 'table',
            text: '',
            tableCols: cols,
            tableRows: rows,
          ),
        );
        continue;
      }
      final text = (map['text'] as String? ?? '').trim();
      final url = (map['url'] as String? ?? '').trim();
      if (text.isEmpty && !_aiBlockTypeAllowsEmptyText(type, url: url)) {
        continue;
      }
      blocks.add(
        _AiBlockSpec(
          type: type,
          text: text,
          checked: map['checked'] as bool?,
          codeLanguage: map['codeLanguage'] as String?,
          depth: (map['depth'] as num?)?.toInt(),
          icon: map['icon'] as String?,
          url: url.isEmpty ? null : url,
          imageWidth: (map['imageWidth'] as num?)?.toDouble(),
          expanded: map['expanded'] as bool?,
        ),
      );
    }
    return blocks;
  }

  List<_AiBlockSpec> _parseMarkdownToSpecs(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((e) => e.trimRight())
        .toList();
    final out = <_AiBlockSpec>[];
    final paragraphBuffer = <String>[];
    String? codeFenceLang;
    final codeBuffer = <String>[];

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) return;
      final text = paragraphBuffer.join('\n').trim();
      paragraphBuffer.clear();
      if (text.isNotEmpty) {
        out.add(_AiBlockSpec(type: 'paragraph', text: text));
      }
    }

    void flushCode() {
      if (codeFenceLang == null) return;
      final text = codeBuffer.join('\n').trimRight();
      codeBuffer.clear();
      final lang = codeFenceLang!;
      codeFenceLang = null;
      if (text.isNotEmpty) {
        out.add(
          _AiBlockSpec(
            type: 'code',
            text: text,
            codeLanguage: lang.isEmpty ? 'dart' : lang,
          ),
        );
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('```')) {
        if (codeFenceLang == null) {
          flushParagraph();
          codeFenceLang = line.substring(3).trim();
        } else {
          flushCode();
        }
        continue;
      }
      if (codeFenceLang != null) {
        codeBuffer.add(raw);
        continue;
      }
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (line == '---' || line == '***') {
        flushParagraph();
        out.add(const _AiBlockSpec(type: 'divider', text: ''));
        continue;
      }
      if (line.startsWith('# ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h1', text: line.substring(2).trim()));
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h2', text: line.substring(3).trim()));
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h3', text: line.substring(4).trim()));
        continue;
      }
      if (line.startsWith('- [ ] ') || line.startsWith('* [ ] ')) {
        flushParagraph();
        out.add(
          _AiBlockSpec(
            type: 'todo',
            text: line.substring(6).trim(),
            checked: false,
          ),
        );
        continue;
      }
      if (line.startsWith('- [x] ') || line.startsWith('* [x] ')) {
        flushParagraph();
        out.add(
          _AiBlockSpec(
            type: 'todo',
            text: line.substring(6).trim(),
            checked: true,
          ),
        );
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'bullet', text: line.substring(2).trim()));
        continue;
      }
      final numbered = RegExp(r'^\d+\.\s+').firstMatch(line);
      if (numbered != null) {
        flushParagraph();
        out.add(
          _AiBlockSpec(
            type: 'numbered',
            text: line.substring(numbered.end).trim(),
          ),
        );
        continue;
      }
      if (line.startsWith('> ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'quote', text: line.substring(2).trim()));
        continue;
      }
      paragraphBuffer.add(line);
    }

    flushParagraph();
    flushCode();
    if (out.isEmpty) {
      final fallback = markdown.trim();
      out.add(
        _AiBlockSpec(
          type: 'paragraph',
          text: fallback.isEmpty ? 'Sin contenido' : fallback,
        ),
      );
    }
    return out;
  }

  List<FolioBlock> _materializeAiBlocks(
    String pageId,
    List<_AiBlockSpec> specs,
  ) {
    const urlOnlyTypes = {
      'image',
      'file',
      'video',
      'audio',
      'meeting_note',
      'bookmark',
      'embed',
    };
    final out = <FolioBlock>[];
    for (final s in specs) {
      final type = _normalizeAiBlockType(s.type);
      final text = s.text.trim();
      final url = s.url?.trim();
      final hasUrl = url != null && url.isNotEmpty;
      final canUseUrlOnly = urlOnlyTypes.contains(type) && hasUrl;
      if (type != 'divider' &&
          type != 'table' &&
          text.isEmpty &&
          !canUseUrlOnly) {
        continue;
      }
      out.add(
        FolioBlock(
          id: '${pageId}_${VaultSession._uuid.v4()}',
          type: type,
          text: type == 'divider'
              ? ''
              : (type == 'table' ? _buildTableBlockText(s) : text),
          checked: type == 'todo' ? (s.checked ?? false) : null,
          codeLanguage: type == 'code'
              ? (s.codeLanguage?.trim().isEmpty ?? true
                    ? 'dart'
                    : s.codeLanguage)
              : null,
          depth: s.depth ?? 0,
          icon: s.icon,
          url: hasUrl ? url : null,
          imageWidth: s.imageWidth,
          expanded: s.expanded,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        FolioBlock(
          id: '${pageId}_${VaultSession._uuid.v4()}',
          type: 'paragraph',
          text: '',
        ),
      );
    }
    return out;
  }

  @visibleForTesting
  List<FolioBlock> parseAiOutputForTesting(
    String output, {
    String pageId = 'test_page',
    String defaultTitle = 'Test',
  }) {
    final parsed = _parseAiHybridOutput(output, defaultTitle: defaultTitle);
    return _materializeAiBlocks(pageId, parsed.blocks);
  }

  @visibleForTesting
  String normalizeAgentModeForTesting(String? raw) => _normalizeAgentMode(raw);

  @visibleForTesting
  bool detectEditIntentForTesting(
    String prompt, {
    String languageCode = 'es',
  }) => _looksLikeEditIntent(prompt, languageCode: languageCode);

  @visibleForTesting
  bool detectCreatePageIntentForTesting(
    String prompt, {
    String languageCode = 'es',
  }) => _looksLikeCreatePageIntent(prompt, languageCode: languageCode);

  @visibleForTesting
  bool detectSubpageIntentForTesting(
    String prompt, {
    String languageCode = 'es',
  }) => _looksLikeSubpageIntent(prompt, languageCode: languageCode);

  bool _aiBlockTypeAllowsEmptyText(String type, {required String url}) {
    if (type == 'divider' || type == 'table') return true;
    if (url.isEmpty) return false;
    return const {
      'image',
      'file',
      'video',
      'audio',
      'meeting_note',
      'bookmark',
      'embed',
    }.contains(type);
  }

  String _normalizeAiBlockType(String raw) {
    const supported = {
      'paragraph',
      'h1',
      'h2',
      'h3',
      'bullet',
      'numbered',
      'todo',
      'toggle',
      'code',
      'quote',
      'divider',
      'callout',
      'table',
      'image',
      'file',
      'video',
      'audio',
      'bookmark',
      'embed',
      'equation',
      'mermaid',
      'meeting_note',
    };
    final normalized = raw.trim().toLowerCase();
    final type = normalized.contains('|')
        ? normalized.split('|').first.trim()
        : normalized;
    return supported.contains(type) ? type : 'paragraph';
  }

  String _buildTableBlockText(_AiBlockSpec spec) {
    final colsFromSpec = spec.tableCols ?? 0;
    var cols = colsFromSpec > 0 ? colsFromSpec : 0;
    final rows = spec.tableRows ?? const <List<String>>[];
    if (cols <= 0 && rows.isNotEmpty) {
      cols = rows.fold<int>(
        0,
        (maxCols, row) => row.length > maxCols ? row.length : maxCols,
      );
    }
    cols = cols.clamp(1, 32);
    final cells = <String>[];
    if (rows.isEmpty) {
      return FolioTableData.empty(cols: cols, rows: 2).encode();
    }
    for (final row in rows) {
      for (var c = 0; c < cols; c++) {
        cells.add(c < row.length ? row[c] : '');
      }
    }
    return FolioTableData(cols: cols, cells: cells).encode();
  }
}

class _AiPageDraft {
  const _AiPageDraft({required this.title, required this.blocks});

  final String title;
  final List<_AiBlockSpec> blocks;
}

class _AiBlockSpec {
  const _AiBlockSpec({
    required this.type,
    required this.text,
    this.checked,
    this.codeLanguage,
    this.tableCols,
    this.tableRows,
    this.depth,
    this.icon,
    this.url,
    this.imageWidth,
    this.expanded,
  });

  final String type;
  final String text;
  final bool? checked;
  final String? codeLanguage;
  final int? tableCols;
  final List<List<String>>? tableRows;
  // Campos del formato nativo FolioBlock
  final int? depth;
  final String? icon;
  final String? url;
  final double? imageWidth;
  final bool? expanded;
}
