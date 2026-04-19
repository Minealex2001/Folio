# Folio — Inventario completo de funcionalidades implementadas

> Documento generado a partir de una exploración exhaustiva del código fuente.  
> Última actualización sincronizada con la rama principal del repositorio.

---

## Índice

1. [Plataformas soportadas](#1-plataformas-soportadas)
2. [Editor de bloques](#2-editor-de-bloques)
3. [Tipos de bloque](#3-tipos-de-bloque)
4. [Rich text WYSIWYG (Quill)](#4-rich-text-wysiwyg-quill)
5. [Barra de formato flotante](#5-barra-de-formato-flotante)
6. [Menú slash `/`](#6-menú-slash-)
7. [Sistema @mention de páginas](#7-sistema-mention-de-páginas)
8. [Atajos de teclado del editor](#8-atajos-de-teclado-del-editor)
9. [Atajos Markdown inline](#9-atajos-markdown-inline)
10. [Atajos globales remapeables](#10-atajos-globales-remapeables)
11. [Selección múltiple de bloques](#11-selección-múltiple-de-bloques)
12. [Drag & drop de bloques](#12-drag--drop-de-bloques)
13. [Duplicar bloques](#13-duplicar-bloques)
14. [Apariencia de bloques](#14-apariencia-de-bloques)
15. [Historial de versiones por página](#15-historial-de-versiones-por-página)
16. [Undo / Redo por página](#16-undo--redo-por-página)
17. [Inserción de medios](#17-inserción-de-medios)
18. [Redimensionado de imágenes](#18-redimensionado-de-imágenes)
19. [Pegado inteligente de URLs](#19-pegado-inteligente-de-urls)
20. [Notas de reunión (beta)](#20-notas-de-reunión-beta)
21. [Colaboración en tiempo real](#21-colaboración-en-tiempo-real)
22. [Sincronización P2P entre dispositivos](#22-sincronización-p2p-entre-dispositivos)
23. [Asistente IA Quill](#23-asistente-ia-quill)
24. [Contexto IA con `@`](#24-contexto-ia-con-)
25. [Folio Cloud](#25-folio-cloud)
26. [Seguridad de libreta (Vault)](#26-seguridad-de-libreta-vault)
27. [Importación de contenido](#27-importación-de-contenido)
28. [Exportación de contenido](#28-exportación-de-contenido)
29. [Integración con Jira](#29-integración-con-jira)
30. [Búsqueda global](#30-búsqueda-global)
31. [Captura rápida de tarea](#31-captura-rápida-de-tarea)
32. [Temas y apariencia](#32-temas-y-apariencia)
33. [Iconos de página personalizados](#33-iconos-de-página-personalizados)
34. [Onboarding](#34-onboarding)
35. [Actualizador integrado](#35-actualizador-integrado)
36. [Diagnóstico y reporte de bugs](#36-diagnóstico-y-reporte-de-bugs)

---

## 1. Plataformas soportadas

| Plataforma | Estado |
|---|---|
| Android | ✅ |
| iOS | ✅ |
| Windows (x64) | ✅ |
| Linux (x64) | ✅ |
| macOS (arm64 / x64) | ✅ |
| Web | ✅ |

La app es **local-first**: los datos se almacenan en disco; la nube (Firebase) es opcional.

---

## 2. Editor de bloques

El editor es completamente personalizado (no usa un widget de terceros como editor principal). Está implementado en `lib/features/workspace/editor/block_editor/block_editor_state.dart` (~5 000 líneas) y sus ficheros de despacho asociados.

### Comportamiento general

- **Bloque sentinela**: siempre existe un párrafo vacío al final de la página para que el usuario pueda hacer clic y escribir.
- **Integración dual**: los bloques de texto enriquecido (`paragraph`, `h1`, `h2`, `h3`, `quote`, `callout`, `bullet`, `numbered`, `todo`, `toggle`) usan un `QuillController` WYSIWYG internamente, con persistencia dual en markdown + Delta JSON (`richTextDeltaJson`).
- **Modo solo lectura** (`readOnlyMode`): elimina controles de edición; útil para vistas de historial o publicaciones web.
- **Scroll TOC**: `scrollToBlock(blockId)` — desplazamiento animado con `Scrollable.ensureVisible` desde la tabla de contenidos lateral.
- **Índice de bloques ordenado**: `_orderedListNumber()` calcula el número correlativo para listas numeradas, respetando niveles de anidación.

---

## 3. Tipos de bloque

31+ tipos catalogados en `lib/features/workspace/editor/block_editor/block_type_catalog.dart`:

| Clave | Descripción |
|---|---|
| `paragraph` | Párrafo de texto rico (WYSIWYG) |
| `h1` | Encabezado 1 (WYSIWYG) |
| `h2` | Encabezado 2 (WYSIWYG) |
| `h3` | Encabezado 3 (WYSIWYG) |
| `quote` | Cita con barra lateral (WYSIWYG) |
| `callout` | Bloque callout con icono emoji (WYSIWYG) |
| `bullet` | Lista de viñetas (WYSIWYG, anidable) |
| `numbered` | Lista numerada (WYSIWYG, anidable) |
| `todo` | Lista de tareas con checkbox (WYSIWYG, anidable) |
| `toggle` | Sección colapsable (WYSIWYG) |
| `divider` | Separador horizontal |
| `image` | Imagen local, remota o URL |
| `video` | Video local o URL |
| `audio` | Audio local |
| `file` | Archivo adjunto genérico |
| `bookmark` | Marcador de URL con título y favicon |
| `embed` | Iframe/WebView (YouTube, web general) |
| `code` | Bloque de código con resaltado sintáctico |
| `equation` | Ecuación LaTeX |
| `mermaid` | Diagrama Mermaid (fuente editable + preview) |
| `table` | Tabla editable (`FolioTableData`) |
| `database` | Base de datos (beta, `FolioDatabaseData`) |
| `kanban` | Tablero kanban (beta) |
| `toc` | Tabla de contenidos automática |
| `breadcrumb` | Miga de pan de la página |
| `template_button` | Botón de plantilla con bloques predefinidos |
| `column_list` | Columnas de bloques |
| `child_page` | Enlace a subpágina |
| `meeting_note` | Nota de reunión con grabación y transcripción (beta) |
| `drive` | Integración Drive |
| `task` | Tarea del sistema (`lib/services/tasks/`) |

### Selector de tipo de bloque

- Diálogo centrado en escritorio/tablet: `BlockTypePickerDialog`
- Bottom sheet en móvil Android: `BlockTypePickerSheet`

---

## 4. Rich text WYSIWYG (Quill)

Disponible en los tipos `paragraph`, `h1`, `h2`, `h3`, `quote`, `callout`, `bullet`, `numbered`, `todo`, `toggle`.

- Basado en `flutter_quill` con codec Markdown propio (`FolioMarkdownQuillCodec`).
- **Persistencia dual**: el texto visible es Markdown; el documento Quill (Delta JSON) se guarda en `block.richTextDeltaJson`.
- **Reconversión automática**: si `block.text` cambia externamente (undo/redo, sync, IA), el documento Quill se reconcilia con `_reconcileStylableQuillDocumentsWithModel()`.
- **Flush en pérdida de foco**: debounce de 200 ms durante la edición; flush inmediato al perder el foco.

### Formatos inline soportados (mediante Quill + `folioToggleWrap`)

| Formato | Markdown | Quill attribute |
|---|---|---|
| **Negrita** | `**texto**` | `bold` |
| *Cursiva* | `_texto_` | `italic` |
| <u>Subrayado</u> | `<u>texto</u>` | `underline` |
| ~~Tachado~~ | `~~texto~~` | `strike` |
| `Código inline` | `` `texto` `` | `code` |
| [Enlace](url) | `[label](url)` | `link` |

---

## 5. Barra de formato flotante

- Aparece sobre el texto seleccionado cuando un bloque WYSIWYG tiene selección activa (`_selectionActiveBlockId`).
- Implementada en `FolioFormatToolbar` (`lib/features/workspace/editor/folio_text_format.dart`).
- Barra con scroll horizontal + flechas `‹ ›` cuando el contenido supera el ancho disponible (`_FolioToolbarScrollStrip`).

### Acciones de la barra de formato

| Botón | Acción |
|---|---|
| 🎨 Paleta | Apariencia del bloque (color de texto, fondo, tamaño) |
| **B** | Negrita (`**...**`) |
| *I* | Cursiva (`_..._`) |
| <u>U</u> | Subrayado (`<u>...</u>`) |
| `</>` | Código inline (`` `...` ``) |
| ~~S~~ | Tachado (`~~...~~`) |
| 🔗 | Insertar enlace (diálogo URL + etiqueta) |
| @página | Mencionar página (abre selector de página) |
| @usuario | Mención de usuario (opcional) |
| @fecha | Insertar fecha (opcional) |
| ∑ | Matemáticas inline `\( \)` (opcional) |

---

## 6. Menú slash `/`

Se activa escribiendo `/` en un bloque de texto compatible.

- **Filtrado**: la lista se filtra por el texto escrito tras `/`.
- **Orden por recientes**: los tipos usados recientemente aparecen primero (`_slashRecentByType`); límite de historial recortado con `_trimSlashRecents()`.
- **Navegación teclado**: `↑` / `↓` mueven la selección, `Enter` confirma, `Esc` cierra.
- **Auto-scroll**: `_ensurePopupSelectionVisible()` mantiene el ítem seleccionado visible en la lista.

### Acciones inline del menú slash (comandos especiales)

| Comando | Acción |
|---|---|
| `cmd_insert_date` | Inserta la fecha actual formateada con locale |
| `cmd_mention_page` | Abre selector de página e inserta mención markdown |
| `cmd_duplicate_prev` | Duplica el bloque anterior |
| `cmd_turn_into` | Abre selector de tipo para convertir el bloque actual |

---

## 7. Sistema @mention de páginas

- Se activa escribiendo `@` en un bloque de texto compatible.
- Muestra un panel flotante (`BlockEditorInlineMentionList`) con las páginas de la libreta filtradas por título.
- **Navegación teclado**: `↑` / `↓` / `Enter` / `Esc`.
- Al confirmar, inserta el enlace como `[@Título](folio://open/<pageId>) ` en el texto del bloque.
- Filtrado y ordenación por relevancia: coincidencia exacta > prefijo > contiene.

---

## 8. Atajos de teclado del editor

| Atajo | Acción |
|---|---|
| `Ctrl+Z` / `Cmd+Z` | Deshacer (undo de página) |
| `Ctrl+Shift+Z` / `Ctrl+Y` | Rehacer (redo de página) |
| `Ctrl+D` / `Cmd+D` | Duplicar bloque actual |
| `Ctrl+V` / `Cmd+V` | Pegar (inteligente: detecta URL, Markdown multilínea) |
| `Tab` | Indentar bloque |
| `Shift+Tab` | Desindentar bloque |
| `Enter` | Crear nuevo bloque (configurable con `enterCreatesNewBlock`) |
| `Shift+Enter` | Salto de línea dentro del bloque |
| `Backspace` (al inicio, bloque vacío) | Eliminar bloque y subir al anterior |
| `Backspace` (al inicio, con texto) | Fusionar bloque con el anterior (`mergeBlockUp`) |
| `↑` / `↓` en menú `/` | Navegar lista slash |
| `Enter` en menú `/` | Confirmar selección slash |
| `Esc` en menú `/` o `@` | Cerrar menú flotante |

---

## 9. Atajos Markdown inline

Aplicados automáticamente al escribir en bloques compatibles (`_tryMarkdownShortcut`):

| Escritura | Resultado |
|---|---|
| `- ` o `* ` | Convierte a bloque `bullet` |
| `[] ` o `[ ] ` | Convierte a bloque `todo` |
| ` ``` ` o ` ```<lang> ` | Convierte a bloque `code` (con lenguaje opcional) |
| `# Texto` | Convierte a bloque `h1` |
| `## Texto` | Convierte a bloque `h2` |
| `### Texto` | Convierte a bloque `h3` |

> Los encabezados con solo `# ` (sin texto) no se convierten para evitar perder el foco mientras se escribe.

---

## 10. Atajos globales remapeables

8 atajos globales configurables en `lib/app/folio_in_app_shortcuts.dart`:

| Atajo por defecto | Acción |
|---|---|
| `Ctrl+K` | Búsqueda global |
| `Ctrl+N` | Nueva página |
| `Ctrl+Shift+T` | Captura rápida de tarea |
| `Ctrl+,` | Ajustes |
| `Ctrl+L` | Bloquear libreta |
| `Alt+]` | Siguiente página |
| `Alt+[` | Página anterior |
| `Ctrl+W` | Cerrar página |

Todos son remapeables por el usuario.

---

## 11. Selección múltiple de bloques

- **Click simple**: selecciona un bloque.
- **Ctrl+Click / Cmd+Click**: alterna la selección del bloque (aditiva).
- **Shift+Click**: selecciona un rango desde el ancla hasta el bloque clicado.
- **Arrastre con ratón (drag selection)**: `_beginDragSelection` → `_updateDragSelection` → `_endDragSelection`.
- Las acciones del menú contextual (duplicar, eliminar, mover) operan sobre todos los bloques seleccionados.
- La selección se limpia al cambiar de página o al hacer click fuera.

---

## 12. Drag & drop de bloques

- Implementado con `ReorderableListView` + `ReorderableDragStartListener`.
- Callback `_onBlocksReordered(page, oldIndex, newIndex)` → `_s.reorderBlockAt(pageId, oldIndex, newIndex)`.
- El foco se restaura al bloque que tenía el foco antes del reordenado.

---

## 13. Duplicar bloques

- **Ctrl+D**: duplica el bloque con foco.
- **Menú contextual del bloque**: opción "Duplicar".
- **Menú slash**: comando `cmd_duplicate_prev` duplica el bloque anterior.
- Multi-selección: `_duplicateSelectedBlocks(page, blockIds)` clona todos los seleccionados y los inserta justo después del último.
- Implementación: `_s.cloneBlocksWithNewIds(pageId, blocks)` asigna nuevos IDs a los clones.

---

## 14. Apariencia de bloques

Disponible para todos los bloques WYSIWYG mediante `FolioBlockAppearance`.

### Color de texto (`textColorRole`)

| Rol | Color M3 |
|---|---|
| `default` (null) | `onSurface` (por defecto) |
| `subtle` | `onSurfaceVariant` |
| `primary` | `primary` |
| `secondary` | `secondary` |
| `tertiary` | `tertiary` |
| `error` | `error` |

### Color de fondo (`backgroundRole`)

| Rol | Color M3 |
|---|---|
| `none` (null) | Sin fondo |
| `surface` | `surfaceContainerHigh` α 72% |
| `primary` | `primaryContainer` α 62% |
| `secondary` | `secondaryContainer` α 62% |
| `tertiary` | `tertiaryContainer` α 62% |
| `error` | `errorContainer` α 70% |

### Tamaño de fuente (`fontScale`)

| Etiqueta | Factor |
|---|---|
| S | 0,85× |
| M | 1,00× (por defecto) |
| L | 1,15× |
| XL | 1,30× |

El selector se presenta como un bottom sheet con preview en tiempo real y botón "Restablecer".

---

## 15. Historial de versiones por página

- `PageHistoryScreen` (`lib/features/workspace/history/page_history_sheet.dart`).
- Lista de revisiones con timestamps.
- **Vista diff**: `PageRevisionDiffView` muestra los cambios entre la versión seleccionada y la actual.
- **Restauración**: diálogo de confirmación antes de revertir.
- Presentación adaptativa: diálogo 760×720 px en escritorio, ruta de pantalla completa en móvil.

---

## 16. Undo / Redo por página

- Implementado en `VaultSession` (`lib/session/vault_session.dart`).
- **Stacks independientes por página**: `_undoByPage` / `_redoByPage` (Map keyed por `pageId`).
- **Límite**: `_maxUndoStepsPerPage = 100` pasos.
- **Coalescing**: escritura continua se agrupa para no saturar el historial.
- API pública: `undoPageEdits(pageId)` / `redoPageEdits(pageId)`, `canUndoSelectedPage`, `canRedoSelectedPage`.

---

## 17. Inserción de medios

### Imágenes

- Picker de archivos local (Android, iOS, Windows, Linux, macOS).
- URL remota (detección automática de extensión: `.png`, `.jpg`, `.gif`, `.webp`, `.bmp`, `.svg`).
- Si el texto de un bloque párrafo es una URL de imagen, se convierte automáticamente a bloque `image`.

### Video

- Picker local.
- URL remota.

### Audio

- Picker local.

### Archivos adjuntos (`file`)

- Picker local.
- El bloque muestra nombre, tamaño y botón de apertura externa (`launchUrl`).

### Collab media (salas de colaboración)

- Los medios se cifran con AES-256-GCM antes de subir a Firebase Storage.
- Al bajar, se descifran y se cachean en disco (`_collabMediaCacheDir`).
- URI interna: `collab-media://<roomId>/<mediaId>`.
- Ver [§21 Colaboración](#21-colaboración-en-tiempo-real) para el flujo completo.

---

## 18. Redimensionado de imágenes

- Factor de ancho: 20%–100% en pasos de 10% (`_nudgeImageWidth`, delta ±0,1).
- Botones rápidos: «Más pequeño», «Más grande», «50%», «75%», «100%».
- El factor se persiste en `block.imageWidth` (rango 0,2–1,0).
- Los controles se muestran como toolbar por encima de la imagen cuando el bloque está activo.

---

## 19. Pegado inteligente de URLs

Al pegar (`Ctrl+V`) una URL en un bloque de texto, se muestra un bottom sheet con opciones:

| Modo (`FolioPasteUrlMode`) | Comportamiento |
|---|---|
| `markdownUrl` | Inserta `[hostname](url)` |
| `embed` | Convierte el bloque a `embed` con la URL |
| `bookmark` | Convierte el bloque a `bookmark`; obtiene el título de la página automáticamente (`fetchWebPageTitle`) |
| `vaultMention` | Inserta `[título](url)`; obtiene el título de la web; detecta YouTube y añade `▶` |

Si el texto pegado es multilínea con sintaxis Markdown, se parsea como bloques completos (`_pasteMarkdownAsBlocks`).

---

## 20. Notas de reunión (beta)

Bloque `meeting_note` implementado en `lib/features/workspace/editor/meeting_note_block_widget.dart`.

### Estados del bloque

`idle` → `setup` → `recording` → `cloudProcessing` → `completed`

### Proveedores de transcripción

| Proveedor | Descripción |
|---|---|
| **Local (Whisper.cpp)** | Inferencia local sin conexión |
| **Quill Cloud** | Transcripción en la nube vía API de Folio |

### Servicio Whisper local (`lib/services/whisper_service.dart`)

- Modelos disponibles: `tiny` (74 MB) y `base-q8_0`.
- Plataformas: Windows x64, macOS arm64, Linux x64.
- El binario `whisper.cpp` se descarga automáticamente desde GitHub Releases.
- Los modelos se descargan desde HuggingFace.

### Funcionalidades avanzadas

- **Diarización** (`DiarizationService`): diferenciación de hablantes.
- **Mezcla de audio** (`AudioMixerService`): mezcla micrófono + audio del sistema.
- **Audio del sistema** (`SystemAudioService`): captura del audio de la pantalla.
- **Perfil de hardware** (`TranscriptionHardwareProfile`): ajusta parámetros según la capacidad del dispositivo.
- **Idiomas**: auto-detección, `es`, `en` y más.

---

## 21. Colaboración en tiempo real

### Salas de colaboración

Implementado en `lib/services/collab/collab_session_controller.dart`.

- Backend: Firestore colección `collabRooms/{roomId}`.
- **E2E v1**: clave de sala AES-256-GCM empaquetada en `wrappedRoomKey` (campo `e2eV: 1`).
- `CollabE2eCrypto.unwrapRoomKeyB64()` desempaqueta la clave usando el código de unión (`joinCode`) normalizado.
- Fallback de polling en Windows/Linux (Firestore Realtime no disponible → polling periódico).

### Chat de sala

- Mensajes cifrados E2E: `CollabChatMessageView` (id, authorUid, authorName, text, createdAtMs).
- Contador de mensajes no leídos.
- Panel adaptativo: panel lateral en escritorio, bottom sheet en móvil.

### Multimedia cifrado en salas

1. **Subida**: `_uploadCollabMediaForBlock()` → `prepareCollabMediaUpload` (Cloud Function) → cifrado AES-256-GCM → Firebase Storage → `commitCollabMediaUpload` (Cloud Function).
2. **Descarga**: Firestore lookup (`collabRooms/{roomId}/media/{mediaId}`) → Firebase Storage → descifrado AES-256-GCM → caché local.
3. Progreso de subida con ETA en tiempo real (solo Android/iOS/macOS; Windows/Linux usan modo simplificado por limitación de `firebase_storage`).

---

## 22. Sincronización P2P entre dispositivos

Implementado en `lib/services/device_sync/device_sync_controller.dart`.

### Protocolo de red

| Parámetro | Valor |
|---|---|
| Grupo multicast UDP | `239.255.42.99` |
| Puerto discovery | `45839` |
| Puerto de datos (TCP) | `45840` |
| Intervalo Hello | 4 s |
| Tiempo hasta stale | 18 s |

### Características

- **Emparejamiento**: handshake de petición/aceptación bilateral; los peers emparejados se persisten en `SharedPreferences`.
- **Relay opcional**: `syncRelayEnabled` permite atravesar NATs cuando el multicast no funciona.
- **Snapshot export/import**: la sincronización transfiere snapshots completos de la libreta.
- **Detección de conflictos**: fingerprint de base + detección de cambio concurrente (local y remoto modificaron desde el mismo baseline).  
  - Si hay conflicto: no sobrescribir local → registrar en `syncPendingConflicts` → confirmar sync para evitar reintentos.
- **Peers estables**: la última IP conocida de un peer se conserva incluso si el discovery falla (redes con multicast inestable).
- Supresión de callback `onPersisted` durante `applySyncSnapshotBytes` para evitar bucles push↔import.

---

## 23. Asistente IA Quill

### Proveedores (`AiProvider`)

| Proveedor | Descripción |
|---|---|
| `none` | Sin IA |
| `ollama` | Servidor Ollama local |
| `lmStudio` | LM Studio local |
| `quillCloud` | API de inferencia de Folio Cloud |

### Modos de operación (`lib/session/vault_session_ai.dart`)

| Modo | Descripción |
|---|---|
| `chat` | Conversación libre con contexto |
| `summarize_current` | Resume el contenido de la página actual |
| `append_current` | Añade el resultado al final de la página |
| `replace_current` | Reemplaza el contenido de la página |
| `edit_current` | Edita secciones específicas de la página |
| `create_page` | Crea una nueva página con el resultado |

### Interfaz de chat (`lib/features/workspace/shell/workspace_page_ai_panel.dart`)

- Entrada: `Enter` envía, `Ctrl+Enter` inserta salto de línea.
- Menú de contexto con navegación teclado (`↑` / `↓` / `Enter` / `Esc`).
- Respuestas renderizadas con animación typewriter (30 ms tick, 4–14 chars/tick según longitud).
- Feedback por mensaje: `helpful` / `not_helpful`.
- Adjuntos de archivo: `AiFileAttachment` (nombre, MIME type, contenido).
- Conteo de tokens: `AiTokenUsage`.

### Multi-hilo (`lib/features/workspace/shell/workspace_page_ai_threads.dart`)

- Varios hilos de conversación independientes.
- **Auto-renombre**: el primer turno de cada hilo genera automáticamente un título vía `threadTitle` en la respuesta JSON.
- Diálogo de renombrado manual.
- Subtítulo de contexto: "página actual", "N páginas", "desactivado".

### Sistema de prompt

- Prompt de sistema bilingüe (español/inglés), seleccionado según locale.
- El asistente se identifica como "Quill".

---

## 24. Contexto IA con `@`

`lib/features/workspace/shell/workspace_page_ai_context.dart`

El usuario puede añadir contexto al chat IA usando el menú `@` en el campo de entrada:

| Ítem de contexto | Descripción |
|---|---|
| `currentPage` | Contenido completo de la página abierta |
| `page` | Páginas específicas de la libreta (con sub-filtrado por título) |
| `meetingNote` | Nota de reunión (si está disponible en la página) |
| `addFile` | Adjuntar archivo del disco |

---

## 25. Folio Cloud

### Backup cifrado

- Backup de la libreta cifrado y almacenado en Firebase Storage.
- Restauración desde el backup durante el onboarding.

### Publicación de páginas web

- Exportar una página como página web pública.
- **Slug personalizable**: `_showPublishWebSlugMenu` permite definir la URL amigable.
- Implementado en `lib/features/workspace/shell/workspace_page_page_tools.dart`.

### Microsoft Store

- La app se distribuye a través de Microsoft Store (ver `installer.iss` para el instalador MSIX).
- `Folio-MicrosoftStore-0.0.3-5.msix` en `/Output/`.

### Suscripción y entitlements

- Sistema de suscripción con entitlements gestionado en Folio Cloud.
- Controla el acceso a funciones premium (Cloud AI, backup, collab ilimitado, etc.).

### Cloud Functions (TypeScript)

Funciones en `functions/src/`:

| Función | Propósito |
|---|---|
| `prepareCollabMediaUpload` | Reserva slot en Storage + crea doc Firestore |
| `commitCollabMediaUpload` | Confirma la subida y registra metadatos |
| (otras) | Gestión de rooms, entitlements, AI relay |

---

## 26. Seguridad de libreta (Vault)

### Cifrado

- Cifrado opcional a nivel de libreta: `VaultCrypto`.
- Las claves se derivan de la contraseña maestra.

### Autenticación

- **Contraseña maestra**: campo con toggle mostrar/ocultar (`FolioPasswordField`).
- **Passkeys**: autenticación sin contraseña vía passkeys estándar (`passkeys_android`, `passkeys_doctor`).
- **Windows Hello**: autenticación biométrica / PIN en Windows (`local_auth_android` + Windows Hello integration).
- Diálogo de verificación de identidad reutilizable: `VaultIdentityVerifyDialog`.

### Bloqueo automático

- Pantalla de bloqueo (`lib/features/lock_screen/`).
- La libreta puede configurarse para bloquearse automáticamente tras un tiempo de inactividad.

### Onboarding seguro

- Durante el onboarding se puede elegir cifrado + contraseña.

---

## 27. Importación de contenido

| Fuente | Detalles |
|---|---|
| **Notion** | ZIP exportado desde Notion; parser en `lib/data/` |
| **HTML** | HTML simple; conversión a bloques Folio |
| **Markdown** | Pegado de texto multilínea con sintaxis MD → bloques (`_pasteMarkdownAsBlocks` / `FolioMarkdownCodec.parseBlocks`) |

---

## 28. Exportación de contenido

Desde el panel de herramientas de página (`workspace_page_page_tools.dart`):

| Formato | Extensión |
|---|---|
| Markdown | `.md` |
| HTML | `.html` |
| Texto plano | `.txt` |
| PDF | `.pdf` (vía `printing`) |

---

## 29. Integración con Jira

Implementada en `lib/services/jira/` (3 ficheros: `jira_auth_service.dart`, `jira_api_client.dart`, `jira_sync_service.dart`).

### Autenticación

- OAuth 2.0 (3LO) con PKCE contra Atlassian Cloud.
- Client ID oficial de Folio: `7HEIa3N2dGmMWWscFmYnjGRLNSjzg8hI`.
- Loopback OAuth en puerto fijo `45747` (redirect URI registrado en Atlassian).
- `JiraAuthCancelToken`: permite cancelar el flujo de autenticación en curso.
- Override de Client ID configurable en Ajustes para desarrollo/testing.

### Sincronización

- Obtención de issues/tareas desde Jira Cloud (`jira_api_client.dart`).
- Sincronización bidireccional de tareas (`jira_sync_service.dart`).
- Estado persistido en `JiraIntegrationState` (`lib/models/jira_integration_state.dart`).

---

## 30. Búsqueda global

- Atajo por defecto: `Ctrl+K`.
- Busca en todos los títulos y contenidos de páginas de la libreta.
- Navegación por resultados con teclado.

---

## 31. Captura rápida de tarea

- Atajo por defecto: `Ctrl+Shift+T`.
- Permite crear una tarea rápidamente sin abrir ninguna página.
- Integrado con `lib/services/tasks/`.

---

## 32. Temas y apariencia

### Modo de tema

- Claro / Oscuro / Seguir sistema (`ThemeMode`), configurable en `AppSettings.themeMode`.

### Color de acento (`FolioAccentColorMode`)

| Modo | Descripción |
|---|---|
| `followSystem` | Usa el color dinámico del SO (Material You) |
| `folioDefault` | Color de marca de Folio |
| `custom` | Color personalizado elegido por el usuario |

### Fuente

- Fuente principal: **Outfit**.

### Escala de UI

- `uiScale` (double) + `uiScaleMode` configurable en ajustes.
- Permite aumentar o reducir el tamaño de toda la interfaz.

### Design tokens

`lib/app/ui_tokens.dart`:
- `FolioRadius`: radios de esquinas consistentes.
- `FolioSpace`: espaciados estándar.
- `FolioMotion`: duraciones y curvas de animación.

---

## 33. Iconos de página personalizados

Picker con tres pestañas:

| Pestaña | Contenido |
|---|---|
| Recientes / Rápidos | Emojis predefinidos (💡 ✅ ⚠️ 🚨 ℹ️ 📌 🧠 🚀 …) |
| Importados | SVG/PNG importados por el usuario |
| Todos los emojis | Selector completo de emojis |

- Icono personalizado: texto libre / emoji único.
- Opción "Quitar" para eliminar el icono.
- Implementado en `showFolioIconPicker()`.

---

## 34. Onboarding

Flujo de bienvenida (`lib/features/onboarding/`):

- **Crear libreta nueva**: nombre, icono, opción de cifrado.
- **Importar backup**: desde Folio Cloud (backup cifrado) o archivo local.
- **Importar desde Notion**: ZIP exportado.

---

## 35. Actualizador integrado

- `lib/services/updater/`: comprueba nuevas versiones disponibles.
- Notificación in-app cuando hay una actualización.
- Descarga e instalación guiada (Windows: `.msix`; macOS: `.dmg`; Linux: AppImage).

---

## 36. Diagnóstico y reporte de bugs

- URL de reporte: `kFolioBugReportUrl`.
- Flags de build: `folio_build_flags` (debug/profile/release, plataforma, versión).
- Log estructurado: `AppLogger` (`lib/services/app_logger.dart`).
- Historial de sesiones IA y gestión de hilos persistida localmente.

---

## Apéndice: configuración persistida (`AppSettings`)

| Clave | Tipo | Descripción |
|---|---|---|
| `themeMode` | enum | Tema (claro/oscuro/sistema) |
| `accentColorMode` | enum | Modo de color de acento |
| `uiScale` | double | Factor de escala de UI |
| `uiScaleMode` | enum | Modo de escala (auto/manual) |
| `aiProvider` | enum | Proveedor IA seleccionado |
| `syncEnabled` | bool | Sync P2P activada |
| `syncRelayEnabled` | bool | Relay P2P activado |
| `syncDeviceId` | String | ID único del dispositivo |
| `syncDeviceName` | String | Nombre del dispositivo en la red |
| `syncPendingConflicts` | List | Conflictos de sync pendientes de resolución |
| `syncLastSuccessMs` | int | Timestamp del último sync exitoso |
| `enterCreatesNewBlock` | bool | `Enter` crea nuevo bloque (vs salto de línea) |
