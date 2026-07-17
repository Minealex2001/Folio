# Folio — Inventario completo de funcionalidades implementadas

> Documento generado a partir de una exploración exhaustiva del código fuente.  
> Última revisión: 2026-05-05 (sincronizado con el estado del repositorio).

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
37. [Modo zen / escritura sin distracciones](#37-modo-zen--escritura-sin-distracciones)
38. [Bloques sincronizados](#38-bloques-sincronizados)
39. [Vista de grafo](#39-vista-de-grafo)
40. [Importar PDF con anotaciones](#40-importar-pdf-con-anotaciones)
41. [Lienzo infinito (canvas)](#41-lienzo-infinito-canvas)
42. [Pantalla de inicio (Home)](#42-pantalla-de-inicio-home)
43. [Hub de tareas de la libreta](#43-hub-de-tareas-de-la-libreta)
44. [Papelera de páginas](#44-papelera-de-páginas)

**Apéndice:** [configuración persistida (`AppSettings`)](#apéndice-configuración-persistida-appsettings)

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

**Windows (CMake / super_native_extensions):** si al compilar aparece `Get-Item : No se encontró el elemento ...\AppData` en `resolve_symlinks.ps1`, ejecutar tras `flutter pub get`: `powershell -ExecutionPolicy Bypass -File tool/apply_cargokit_resolve_symlink_patch.ps1`. El proyecto incluye `tool/windows/cargokit_resolve_symlinks.ps1` (script endurecido). En `windows/CMakeLists.txt` se fija la política **CMP0175** para reducir avisos de plugins como `webview_windows`.

**Escritorio (Windows / Linux) y Firebase Analytics:** el runner de Flutter no registra el plugin nativo de `firebase_analytics` en esas plataformas. `FolioTelemetry` evita todas las llamadas a Analytics ahí (no hay implementación Pigeon); Firebase Core, Auth y Firestore siguen usándose cuando aplica. El arranque también tolera fallos al cargar el acento del sistema (`SystemTheme`) y errores al inicializar bandeja / `window_manager` sin tumbar la app.

**Windows y Firebase Auth:** un bug del plugin puede cerrar el proceso tras iniciar sesión o con sesión restaurada (canal `id-token` desde hilo nativo incorrecto; [firebase/flutterfire#18210](https://github.com/firebase/flutterfire/issues/18210)). En `main.dart`, antes de `Firebase.initializeApp`, se activa `FirebaseAuthPlatform.disableIdTokenChannelOnWindows` y en `pubspec.yaml` hay un `dependency_overrides` de `firebase_auth_platform_interface` con el parche comunitario que omite esa suscripción en Windows (trade-off documentado en el PR: `idTokenChanges()` no emite por refrescos de token; `authStateChanges()` y `getIdToken()` siguen funcionando).

**Windows y passkeys:** `PasskeyAuthenticator` se crea solo cuando hace falta (desbloqueo o registro), para no enganchar PasskeysDoctor al iniciar. En la pantalla de bloqueo, si solo hay passkey (sin Hello), no se lanza WebAuthn automáticamente al abrir el bloqueo; el usuario puede usar el botón.

---

## 2. Editor de bloques

El editor es completamente personalizado (no usa un widget de terceros como editor principal). Está implementado en `lib/features/workspace/editor/block_editor/block_editor_state.dart` (parte de `block_editor.dart`; ~5 250 líneas) y sus ficheros de despacho asociados.

### Comportamiento general

- **Bloque sentinela**: siempre existe un párrafo vacío al final de la página para que el usuario pueda hacer clic y escribir.
- **Integración dual**: los bloques de texto enriquecido (`paragraph`, `h1`, `h2`, `h3`, `quote`, `callout`, `bullet`, `numbered`, `todo`, `toggle`) usan un `QuillController` WYSIWYG internamente, con persistencia dual en markdown + Delta JSON (`richTextDeltaJson`).
- **Modo solo lectura** (`readOnlyMode`): elimina controles de edición; útil para vistas de historial o publicaciones web.
- **Scroll TOC**: `scrollToBlock(blockId)` — desplazamiento animado con `Scrollable.ensureVisible` desde la tabla de contenidos lateral.
- **Índice de bloques ordenado**: `_orderedListNumber()` calcula el número correlativo para listas numeradas, respetando niveles de anidación.

---

## 3. Tipos de bloque

**31 tipos** en el menú `/` y el selector de tipo (`blockTypeTemplates` en `lib/features/workspace/editor/block_type_catalog.dart`). El modelo de página admite además tipos como `task` (tareas del sistema) que no están en esa lista del slash.

| Clave | Descripción |
|---|---|
| `paragraph` | Párrafo de texto rico (WYSIWYG) |
| `child_page` | Enlace a subpágina |
| `h1` | Encabezado 1 (WYSIWYG) |
| `h2` | Encabezado 2 (WYSIWYG) |
| `h3` | Encabezado 3 (WYSIWYG) |
| `quote` | Cita con barra lateral (WYSIWYG) |
| `divider` | Separador horizontal |
| `callout` | Bloque callout con icono emoji (WYSIWYG) |
| `bullet` | Lista de viñetas (WYSIWYG, anidable) |
| `numbered` | Lista numerada (WYSIWYG, anidable) |
| `todo` | Lista de tareas con checkbox (WYSIWYG, anidable) |
| `toggle` | Sección colapsable (WYSIWYG) |
| `image` | Imagen local, remota o URL |
| `bookmark` | Marcador de URL con título y favicon |
| `video` | Video local o URL |
| `audio` | Audio local |
| `meeting_note` | Nota de reunión con grabación y transcripción (beta) |
| `code` | Bloque de código con resaltado sintáctico |
| `file` | Archivo adjunto genérico |
| `table` | Tabla editable (`FolioTableData`) |
| `database` | Base de datos (beta, `FolioDatabaseData`) |
| `kanban` | Tablero Kanban de página (`FolioKanbanData`; detalle en la subsección *Tablero Kanban*) |
| `drive` | Integración Drive |
| `equation` | Ecuación LaTeX |
| `mermaid` | Diagrama Mermaid (fuente editable + preview) |
| `toc` | Tabla de contenidos automática |
| `breadcrumb` | Miga de pan de la página |
| `template_button` | Botón de plantilla con bloques predefinidos |
| `column_list` | Columnas de bloques |
| `canvas` | Lienzo infinito: nodos, formas, trazos y conectores ([§41](#41-lienzo-infinito-canvas)) |
| `embed` | Iframe/WebView (YouTube, web general) |

### Tablero Kanban (`kanban`)

- Configuración serializada en `block.text` como `FolioKanbanData` (`lib/models/folio_kanban_data.dart`).
- Vista de página: `KanbanBoardPage` (`lib/features/workspace/kanban/kanban_board_page.dart`) — columnas, tarjetas vinculadas a tareas, conmutación entre vista tablero y editor clásico (banner `kanbanClassicModeBanner`, acciones `kanbanToolbarOpenEditor` / `kanbanToolbarAddTask`).
- **Creación de tareas**: «Añadir tarea» y el «+» de columna crean un borrador local (`FolioTaskData.defaults`) y abren el mismo panel/sheet de detalle que al editar una tarjeta (`task_details_panel.dart`); no hay diálogos de creación aparte.
- Detalle de tarea en el tablero: fechas inicio/vencimiento, bloqueo y motivo, **recurrencia** (diaria / semanal / mensual / anual o derivada de `recurringRule` RRULE), **recordatorio** (icono compacto junto al selector; ver [§31](#31-captura-rápida-de-tarea)), tiempo invertido, prioridad, descripción, subtareas, integración Jira cuando aplica.
- El **selector de estado / columna** de una tarea sigue las columnas del **primer** bloque `kanban` de esa página (`VaultSession.kanbanDataForPage`): chips en el editor del bloque `task` y desplegable en el panel de detalle; si el usuario añade columnas personalizadas al tablero, la UI se actualiza al vuelo (notificación de sesión).
- Tarjetas **bloqueadas** (`FolioTaskData.blocked`): título en **rojo** y **tachado** en las vistas del tablero (columnas, lista, cuadrícula y línea de tiempo), en el hub global de tareas, en el bloque dentro del editor y en el campo título del detalle; no se pueden arrastrar entre columnas mientras siguen bloqueadas.
- Varias instancias del bloque en la misma página: aviso `kanbanMultipleBlocksSnack` (se usa el primero).

### Bloque `task` (tareas enriquecidas)

- **No** aparece en el menú `/` ni en `blockTypeTemplates` (sigue habiendo **31** tipos allí); el modelo de página sí admite `type: task` y la UI lo pinta en el editor (`folio_special_block_widgets.dart`) y en vistas globales.
- Contenido en `block.text`: JSON **`FolioTaskData`** (`lib/models/folio_task_data.dart`), con `tryParse` / `encode` retrocompatibles entre versiones del esquema.
- Campos destacados: `title`, `status` (`todo` / `in_progress` / `done`), `columnId`, `parentTaskId` (subtareas enlazadas), `blocked` + `blockedReason`, `priority`, `description`, `startDate` / `dueDate` (ISO), `recurrence` + `recurringRule` (RRULE iCalendar opcional), `reminderEnabled`, `timeSpentMinutes`, `tags`, `assignee`, `estimatedMinutes`, `storyPoints`, `customProperties`, `blockedByTaskIds`, metadatos de IA (`aiGenerated`, `aiContextPageId`, `confidenceScore`, `suggestedDueDate`, …), enlaces `external` / snapshot `jira`.
- En el editor: checkbox y barra rápida; vista expandida con metadatos; arrastre y APIs de sesión cuando el bloque se mueve entre páginas (`VaultSession.moveBlockToPage`, etc.).

### Selector de tipo de bloque

- Diálogo centrado en escritorio/tablet y bottom sheet en móvil: `BlockTypePickerDialog` / `BlockTypePickerSheet` en `lib/features/workspace/editor/block_editor_support_widgets.dart`.

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
3. Progreso de subida con ETA en tiempo real (solo Android/iOS/macOS; Windows/Linux usan modo simplificado sin barra de progreso).
4. En **Windows/Linux**, subidas y descargas de Storage usan la **API REST** (`folio_firebase_storage_rest.dart` / `folio_storage_transport.dart`) en lugar del plugin nativo, que envía eventos `taskEvent` desde un hilo de fondo y provoca el error `non-platform thread` del motor Flutter.

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

Quill es una función **estable** (fuera de beta): el panel de chat ya no muestra badge BETA y activar la IA en Ajustes no pide confirmación de fase beta. Sigue haciendo falta el aviso de alcance global (Quill es un ajuste de la app, no solo de la libreta actual).

### Ajustes → IA (orden)

Un solo panel con tres bloques:

1. **Básico** — hero con estado real (activo/proveedor/modelo), comparativa Cloud vs local (abierta si aún no hay setup; colapsable si ya hay), activar IA, proveedor y modelo.
2. **Experiencia Quill** — pensamiento, vista dividida, Copilot experimental e instrucciones personalizadas.
3. **Avanzado** (colapsado) — MCP local, ventana de contexto, endpoint, API key, timeout y listado de modelos.

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
| `create_page` | Crea una nueva página **con bloques de contenido ya redactados** (no solo el título) |

Si el modelo elige `create_page` sin contenido útil, Folio hace fallback a `generateStandalonePageWithAi` (generador dedicado con reintento) en lugar de dejar una página vacía. Frases tipo «créame una página…» se detectan como intención de creación (incluidos clíticos `crearme` / `créame`).

### Tool-calling (recomendado)

- Ajuste **`quillToolCallingEnabled`** (default **activado**): usa `runToolLoop` + `FolioToolRegistry` (mismas acciones que el MCP local).
- Con el flag desactivado, Quill usa el JSON legado (`mode`/`reply`/`blocks`).
- La tool `create_page` **rechaza** `blocks` vacío; el modelo debe rellenar contenido (p. ej. `mermaid` si piden diagramas).
- Las respuestas de chat son **completas por defecto**; breves solo si el usuario pide «corto»/«breve».
- **Paridad con MCP**: el bucle admite hasta **8** pasos (create + reintentos + cierre). El system prompt pide actuar como agente (preferir tools, no páginas solo-título). Si `create_page` deja pocos bloques útiles (&lt;4), Quill rellena con `generateContentWithAi` sobre esa página.

### Interfaz de chat (panel Quill)

Código principal: `lib/features/workspace/shell/workspace_page_ai_panel.dart` (cabecera, lista, compositor, móvil), `lib/features/workspace/shell/workspace_page_ai_threads.dart` (hoja selector de hilos), `lib/features/workspace/shell/ai_chat_reply_skeleton.dart` (shimmer), filas de mensaje en `workspace_page.dart`. Límites adaptativos: `QuillChatLayout` en `lib/app/ui_tokens.dart` (`mobile` / `dockNarrow` / `dockWide` / `split`).

#### Cabecera y modo de panel

- **Cabecera fina**: avatar + título del hilo + subtítulo de contexto; acciones (ajustes, menú, split, cerrar) en iconos compactos. Sin gradiente/badge pesado.
- Mini barra de **tokens / tinta** siempre visible bajo la cabecera.
- Menú **«⋮»** abre hoja con proveedor e ink (Folio Cloud).
- **Layout adaptativo**: dock estrecho (&lt;1280), dock amplio (≥1280), split (borde plano, sin sombra) y móvil (`DraggableScrollableSheet` ~0.55–0.95). El dock se **acota siempre al body** del workspace (bajo el AppBar): no puede crecer por encima del toolbar; el botón cerrar permanece accesible.

#### Hilos de conversación

- Fila compacta: selector del hilo activo (abre sheet con búsqueda) + renombrar / eliminar / **Nuevo chat**.
- El sheet de hilos (`workspace_page_ai_threads.dart`) conserva búsqueda y lista vertical.

#### Lista de mensajes

- Burbujas unificadas (avatar 28 px, `FolioRadius.lg`); typing/tool activity alineados.
- **Razonamiento**, typewriter, shimmer, feedback y snapshots de agente: sin cambios de comportamiento.

#### Compositor

- Fila compacta **siempre visible** (sin `ExpansionTile`): chips de tokens de la última respuesta, tinta restante y coste estimado; chips horizontales de contexto/`@`/adjuntos (o hint `aiContextComposerHelper`).
- El icono de marca de Quill es una **pluma** (`FolioIcons.quill` / `history_edu`) en chat, ajustes, onboarding, home y toolbar «Ask Quill».

#### Estado vacío y datos auxiliares

- Pantalla sin mensajes: icono, **`aiChatEmptyHint`** y botón **`aiChatEmptyFocusComposer`**.
- Tras cada respuesta: **`AiTokenUsage`** cuando el backend lo devuelve.
- **Adjuntos**: `AiFileAttachment` (nombre, MIME, contenido).

### Multi-hilo (persistencia y títulos)

- Varios hilos independientes guardados en la sesión/vault; la **UI** del selector se describe arriba en «Hilos de conversación».
- **Auto-renombre**: el primer turno puede fijar título vía `threadTitle` en el JSON de respuesta.
- **Renombrado manual** por diálogo.
- Subtítulo de contexto en cabecera: «página actual», «*N* páginas», «desactivado».

### Sistema de prompt

- Prompt de sistema bilingüe (español/inglés), seleccionado según locale.
- El asistente se identifica como "Quill".

### Bloques `task` en respuestas IA y herramientas Quill

- El pipeline de materialización (`vault_session_ai.dart`) acepta bloques `task` con `text` en JSON `FolioTaskData` o título plano; normaliza títulos vacíos y serializa con `encode()`.
- **`QuillToolExecutor`** (`lib/services/ai/quill_tools.dart`): acciones **`insertTasksFromEncodedLines`**, **`insertTodosFromLines`** y **`translatePageBilingual`** (traducción bilingüe: inserta cada bloque traducido justo después del original en la página abierta, procesando de abajo a arriba para no desplazar índices).
- **Traducción bilingüe en chat**: si el usuario pide traducir la página actual e insertar en el mismo sitio (p. ej. «traduce esta página e insértalo en la misma»), Quill detecta la intención (`AiIntentHints.translateBilingual`), evita `create_page` y ejecuta el atajo `translatePageBilinguallyWithAi` antes del agente JSON genérico. El comando slash `/ai translate` sin selección ni texto en el bloque dispara el mismo modo bilingüe sobre la página abierta.
- Comandos slash de IA (`workspace_page_ai_slash.dart`): prompts orientados a extraer *action items* como bloques `task` (JSON en `text` o campo `title`) o `todo` cuando basta una lista simple, con aplicación sobre la página abierta cuando el modo lo permite.

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

## 24.1 Copias en NAS / servidor externo

Copias cifradas hacia destinos de red **sin depender de Folio Cloud**. Escritorio (Windows prioritario); no disponible en web.

- **Copia programada automática**: pack **incremental** (mismo formato conceptual que el cloud-pack: blobs content-addressed + snapshot cifrado) en carpeta/UNC y/o WebDAV bajo `folio-packs/<vaultId>/`.
- **Exportación manual** y ZIPs legacy (`folio-scheduled-*` / `folio-backup-*`): siguen siendo ZIP completos.

### Destinos

| Destino | Protocolo | Credenciales |
|---------|-----------|--------------|
| **Carpeta de red** | SMB/UNC o unidad montada (`\\nas\share`, `Z:\backups`) | Usuario, contraseña y dominio opcionales (`WNetAddConnection2` en Windows) |
| **WebDAV** | HTTP(S) WebDAV (`webdav_client`) | Usuario y contraseña (Basic auth); contraseña en `flutter_secure_storage` |

Ambos pueden combinarse con la copia programada en **Folio Cloud** (suscripción).

### Configuración (Ajustes › Libreta)

- **Destino NAS o servidor** (carpeta de red y WebDAV): siempre visible; no requiere activar la copia programada. Sirve para restaurar, exportar manualmente o, si lo activas, incluir en copias automáticas.
- **Copia cifrada programada**: interruptor aparte con intervalo y destinos activos en cada ejecución.
- **Intervalo**: «En cada cambio» (debounce ~45 s tras persistir en disco) o 30 min…24 h. El modo continuo reutiliza el mismo runner pack/cloud; el timer de 15 min solo aplica a intervalos fijos.
- **Configurar carpeta de red** / **Configurar WebDAV**: diálogo con credenciales y probar conexión (visible sin copia programada).
- **Copias a conservar** (`retentionCount`): número de snapshots pack retenidos (y GC de blobs no referenciados). Los ZIP legacy no se generan en el ciclo automático.
- **Restaurar desde NAS o servidor**: listar packs incrementales (`folio-packs/…`) y ZIP `folio-scheduled-*` / `folio-backup-*`; importar como libreta nueva o sobrescribir la activa.
- Exportación manual: elegir archivo local (ZIP), carpeta/NAS o WebDAV si están configurados.

### Implementación

- Pack local/WebDAV: `lib/services/vault_pack/` (`VaultPackTransport`, `FolderVaultPackTransport`, `WebDavVaultPackTransport`, `uploadOpenVaultPack`).
- Builder compartido con Folio Cloud: `vault_pack_builder.dart` (usado también por `folio_cloud_pack_sync.dart`).
- Destinos ZIP (manual/legacy): `lib/services/backup_destinations/` (`BackupDestination`, `LocalFolderDestination`, `WebDavDestination`, `BackupExportRunner`).
- Credenciales: `lib/services/secure_credential_storage.dart`.
- SMB Windows: MethodChannel `folio/smb_network` (`windows/runner/smb_network_plugin.cpp`).
- Orquestación programada/continua: `lib/services/vault_scheduled_local_export.dart` + hook `onPersisted` en `folio_app.dart`.
- UI: `lib/features/settings/remote_backup_config_dialog.dart`, `remote_backup_restore_dialog.dart`.

### Ugreen NAS (orientativo)

1. Activar **SMB** y/o **WebDAV** en el panel del NAS.
2. Crear usuario con permiso de escritura en la carpeta de destino.
3. WebDAV: puertos habituales **5005** (HTTP) / **5006** (HTTPS).
4. En Windows, para copias programadas sin unidad montada: ruta UNC + credenciales en Folio.

---

## 25. Folio Cloud

Capa **opcional** en la nube (Firebase + Stripe y/o Microsoft Store). El núcleo de la app —caja fuerte, editor, sincronización local entre dispositivos, IA local— funciona **sin** Folio Cloud; si Firebase no arranca o no hay proyecto configurado, estas rutas quedan deshabilitadas. Resumen orientado a producto: [README.md](../README.md) («Building without Folio Cloud»); despliegue y secretos: [FOLIO_CLOUD_SECRETS.md](FOLIO_CLOUD_SECRETS.md).

### Cuenta y autoridad en servidor

- **Sesión Folio Cloud** = usuario **Firebase Auth**.
- Estado de plan, tinta y flags de funciones viven en Firestore `users/{uid}`; el cliente **no** es confiable: escritura de `folioCloud`, `ink` y campos de facturación vía **Admin SDK** en Cloud Functions y webhooks. Detalle: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).

### Entitlements (`folioCloud.features`)

El webhook de Stripe (y la recomputación tras Microsoft Store) rellena banderas que la app y las reglas usan como contrato:

| Flag | Rol |
|------|-----|
| `backup` | Copias ZIP **cifradas** en Storage bajo `users/{uid}/backups/**` |
| `cloudAi` | IA hospedada en Cloud Functions (claves del proveedor solo en servidor); consumo con **Ink** |
| `publishWeb` | HTML público en `published/{uid}/**` + índice Firestore `publishedPages` |
| `realtimeCollab` | Colaboración en vivo (salas Firestore, subida de medios colaborativos) cuando el plan lo incluye |

Implementación cliente: `lib/services/folio_cloud/folio_cloud_entitlements.dart` (`canUseCloudBackup`, `canUseCloudAi`, `canPublishToWeb`, `canRealtimeCollab`, etc.).

### Copia cifrada en la nube

- Subida manual y **gestión** (listar / importar / descargar legacy / borrar) desde Ajustes en un panel tipo papelera; **restauración** también desde onboarding o flujos de copia.
- Se pueden borrar tanto archivos **legacy** (ZIP/TAR.GZ) como la copia **incremental** (cloud-pack) de una libreta. El borrado del cloud-pack usa **`folioDeleteVaultCloudPack`**; el legacy, **`folioDeleteVaultLegacyBackup`**. Si tras borrar no queda ninguna copia, se **elimina por completo** la presencia de esa libreta en Folio Cloud (Storage bajo `vaults/{vaultId}/`, índice `vaultBackupIndex` y meta `vaultBackups`).
- Tras un **backup programado** (intervalo o «en cada cambio»), si el usuario activa «también subir a Folio Cloud» y tiene permiso, se sube un **cloud-pack** incremental (`uploadOpenVaultCloudPack` / índices en servidor). La copia local/WebDAV del mismo ciclo usa el pack incremental bajo `folio-packs/` (no un ZIP nuevo).
- En **Windows/Linux**, el SDK a veces no lista bien Storage; la app usa la callable **`folioListVaultBackups`** (lista con Admin SDK en servidor).
- Subidas (`putData`/`putFile`) y descargas (`getData`/`writeToFile`) en escritorio van por REST autenticada con ID token, evitando los canales `taskEvent` del plugin C++.
- **Cuota de almacenamiento** de copias y ampliaciones por suscripción («Biblioteca» pequeña/mediana/grande): catálogo en [FOLIO_CLOUD_STRIPE_PRODUCTS.md](FOLIO_CLOUD_STRIPE_PRODUCTS.md); callables de apoyo p. ej. `folioGetBackupStorageUsage`, `folioTrimVaultBackups`, `folioTrimVaultBackupsByBytes`, índice multi-libreta (`folioListBackupVaults`, `folioUpsertVaultBackupIndex`, …).

### IA en la nube

- Cliente: `lib/services/ai/folio_cloud_ai_service.dart` (`FolioCloudAiService`).
- Callable **`folioCloudAiComplete`** (Firebase Functions **1st gen**); fallback HTTP **`folioCloudAiCompleteHttp`** cuando el protocolo callable en escritorio devuelve 401 HTML (perímetro/IAM). Tabla de costes por `operationKind`, suplementos por tamaño y tokens: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).
- Uso permitido con **suscripción activa que incluya `cloudAi`** o con **tinta comprada** sin suscripción (reglas documentadas en backend).
- **`folioCloudAiPricing`**: expone al cliente precios/costes de referencia.
- **`folioCloudTranscribeChunk`**: transcripción por chunks (flujos de audio).

### Publicación web

- Exportar la página actual a HTML y publicar: `lib/services/folio_cloud/folio_cloud_publish.dart` (`publishHtmlPage`); UI y slug en `lib/features/workspace/shell/workspace_page_page_tools.dart` (**slug** vía `_showPublishWebSlugMenu`).

### Facturación

- **Stripe**: `createCheckoutSession`, `createBillingPortalSession`, webhook **`stripeWebhook`**; sincronización manual **`syncFolioCloudSubscriptionFromStripe`** si hace falta.
- **Microsoft Store** (build MSIX): compras y suscripción alineadas con el mismo modelo de productos; callable **`validateMicrosoftStoreEntitlements`** tras compra o «Sincronizar». Variables y Partner Center: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).
- Precios, tinteros y addons de almacenamiento: [FOLIO_CLOUD_STRIPE_PRODUCTS.md](FOLIO_CLOUD_STRIPE_PRODUCTS.md). Job programado **`monthlyInkRefill`** (recarga de gotas el día 1 para suscriptores mensuales).

### Telemetría

- Una copia detallada de eventos opcionales en Firestore **solo si hay sesión** Folio Cloud (Firebase UID en la ruta). No sustituye Analytics con ID de instalación anónimo. Ver [TELEMETRY.md](TELEMETRY.md).

### Cliente Windows/Linux y callables

- Donde el plugin `cloud_functions` no es fiable, las callables se invocan por **HTTP** con `Authorization: Bearer` (ID token), misma URL que documenta Firebase: `lib/services/folio_cloud/folio_cloud_callable.dart`.

### Cloud Functions (`functions/src/index.ts`, referencia)

| Área | Export(s) |
|------|-----------|
| Colaboración | `createCollabRoom`, `joinCollabRoomByCode`, `prepareCollabMediaUpload`, `commitCollabMediaUpload`, `inviteCollabMember`, `removeCollabMember`, `closeCollabRoom` |
| Pagos y cuenta | `createCheckoutSession`, `createBillingPortalSession`, `stripeWebhook`, `syncFolioCloudSubscriptionFromStripe`, `validateMicrosoftStoreEntitlements` |
| Copias / vault / almacenamiento | `folioListVaultBackups`, `folioDeleteVaultCloudPack`, `folioDeleteVaultLegacyBackup`, `folioGetBackupStorageUsage`, `folioTrimVaultBackups`, `folioTrimVaultBackupsByBytes`, `folioListBackupVaults`, `folioUpsertVaultBackupIndex`, `folioGetLatestVaultBackupMeta`, `folioRecordVaultBackupMeta`, … |
| Cloud pack (metadatos/restore) | `folioGetLatestCloudPackMeta`, `folioGetCloudPackRestoreWrap`, `folioCheckCloudPackBlobsExist`, `folioFinalizeCloudPack`, `folioDeleteVaultCloudPack` |
| IA | `folioCloudAiComplete`, `folioCloudAiCompleteHttp`, `folioCloudAiPricing`, `folioCloudTranscribeChunk` |
| Operaciones | `monthlyInkRefill` (programada) |
| Otras HTTP | `folioJiraExchangeOAuth`, `folioReportDiagnostic` (integración/diagnóstico; no son el núcleo «Folio Cloud» de suscripción) |

### Nota: distribución Windows

- Los artefactos **MSIX** y el instalador (`installer.iss`, CI) son la **distribución de la aplicación**; la Microsoft Store actúa además como **canal de pago** Folio Cloud en Windows. Los builds release suelen dejarse bajo `Output/` según el manifiesto.

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

- Atajo por defecto: `Ctrl+Shift+T` (también desde el sidebar).
- Flujo unificado con el detalle de tarea: se crea un **borrador** en la página Kanban destino y se abre el panel/sheet `task_details_panel.dart` (el mismo que al editar una tarjeta). Si hay varios tableros Kanban, primero se elige la página destino.
- El parser NLP **`TaskQuickCaptureParser`** (`lib/services/tasks/task_quick_capture_parser.dart`) sigue disponible en el código (fechas relativas, prioridad, estado, `#etiquetas`, alias de página) para usos futuros; ya no es el diálogo principal de captura.
- Servicios en `lib/services/tasks/`: recordatorios, notificaciones de escritorio (ver abajo), tests del parser y de recurrencia.

### Recordatorios y notificaciones

- **`TaskReminderService`** (`task_reminder_service.dart`): recorre bloques `task`, comprueba `reminderEnabled` y fechas de vencimiento; emite eventos para tareas **vencidas** o **con vencimiento hoy** (intervalo configurable, p. ej. cada hora).
- En **`FolioApp`** esos eventos se traducen en **notificaciones nativas** vía **`PlatformNotificationService`** (`platform_notification_service.dart`, `local_notifier`) en **Windows, macOS y Linux**, si el usuario activó las notificaciones en ajustes (`windowsNotificationsEnabled` en `AppSettings`; el nombre histórico cubre el toggle de escritorio). En **web** (y móvil sin plugin adicional) el servicio de bandeja no aplica; la lógica de detección sigue siendo reutilizable.
- **`advanceRecurrence`**: al completar ciclos, puede calcular la siguiente `dueDate` a partir de `recurrence` o de un `recurringRule` con prefijo `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`.

---

## 32. Temas y apariencia

### Modo de tema

- Claro / Oscuro / Seguir sistema (`ThemeMode`), configurable en `AppSettings.themeMode`.
- Opción **OLED** (negro puro) para el modo oscuro, configurable en `AppSettings.oledThemeEnabled`.

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
- Atajos `Ctrl +`, `Ctrl -` y `Ctrl 0` para ajustar/resetear la escala en caliente.
- El escalado se aplica con una estructura de árbol de widgets **estable** (siempre `ClipRect > OverflowBox > Transform.scale > SizedBox`, usando escala 1.0 cuando no hay override). Esto evita re-parentar el subárbol del `Navigator`/`FocusScope` al cruzar el límite de 1.0, que provocaba la aserción `_elements.contains(element)` del framework (`_FocusInheritedScope`).

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

### Explorador Iconify en Ajustes

En **Ajustes → Iconos personalizados**, debajo del formulario de importación manual:

- Búsqueda con debounce sobre la API pública gratuita de [Iconify](https://iconify.design) (`api.iconify.design`).
- Filtro por colección curada (Lucide, Tabler, Material Design, Phosphor, Remix, Carbon, Iconoir, Fluent UI, Solar o todas).
- Vista en grid con previsualización SVG; paginación «Cargar más».
- Al pulsar un icono: descarga SVG → `CustomIconImportService.importFromBytes()` → biblioteca local (`custom_icon:{uuid}`).
- Los iconos importados aparecen en la pestaña **Importados** del picker de página/callout.
- Requiere conexión a internet para buscar/descargar; tras importar funcionan offline.
- Atribución visible a Iconify (colecciones open source con licencias MIT/Apache/ISC según el set).
- Implementación: `lib/services/iconify/iconify_catalog_service.dart`, `lib/features/settings/widgets/iconify_icon_browser.dart`.

---

## 34. Onboarding

Flujo de bienvenida (`lib/features/onboarding/`):

- **Crear libreta nueva** (primera instalación): bienvenida → configuración de libreta (contraseña/cifrado) → **perfil de uso** → personalización (apariencia + bloqueo) → fiabilidad (copias + Windows) → privacidad y confianza (telemetría + mensaje local-first) → **Folio Cloud** (pitch visual con embudo opcional cuenta + checkout; omitible con «Continuar sin nube»; omitido si Firebase no está disponible) → introducción a Quill (si aplica) → listo con resumen de Cloud.
- **Libreta adicional**: flujo corto — bienvenida → libreta → perfil de uso → listo.
- **Perfil de uso** (`onboardingUsageProfile*`): hasta 3 usos (notas, tareas, proyectos, base de conocimiento, diario, estudio). Persistido en `AppSettings.usageIntents` (`folio_usage_intents`); personaliza el pitch de Folio Cloud y las páginas iniciales.
- **Páginas iniciales personalizadas**: si «Crear páginas iniciales de ayuda» está activo, `buildVaultStarterPages` genera **4–6 páginas** según el perfil.
- **Importar backup**: desde Folio Cloud (backup cifrado) o archivo local.
- **Importar desde Notion**: ZIP exportado.
- **Post-onboarding (home)**: checklist «Primera semana» incluye paso opcional «Mira qué incluye Folio Cloud»; tarjeta invitado de Folio Cloud (14 días, descartable) si no hay plan activo. Prefs: `folio_ws_home_cloud_guest_dismiss_{vaultId}`, `folio_ws_home_onboard_cloud_explore_{vaultId}`.
- **Conversión Cloud compartida**: `lib/services/folio_cloud/folio_cloud_conversion_flow.dart` (sign-in + checkout Stripe) usada en onboarding, Ajustes y workspace.

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
- Telemetría opcional (Analytics / eventos con sesión Cloud): ver `docs/TELEMETRY.md`; desactivable en Ajustes → Privacidad.

---

## 37. Modo zen / escritura sin distracciones

Implementado en `lib/features/workspace/shell/workspace_page.dart`.

- **Activación**: atajo `F11` (hotkey hardware en `_onHardwareKeyEvent`) o botón de la barra de herramientas del editor (`id: 'zen_mode'`).
- **Efecto sobre la interfaz**:
  - Oculta la barra de herramientas superior (`appBar: null`).
  - Oculta los paneles laterales (outline, backlinks, comentarios) y el resize handle.
  - Oculta el panel flotante de IA y el de colaboración.
  - Fija el ancho del contenido del editor a 740 px centrado.
  - Colapsa el sidebar (`effectiveSidebarW` devuelve 0.0).
- **Salida**: botón semitransparente superpuesto sobre el editor (`Icons.fullscreen_exit_rounded`) que llama a `setState(() => _zenMode = false)`; también disponible volviendo a pulsar `F11`.
- **Estado**: `bool _zenMode = false` en `_WorkspacePageState`.

---

## 38. Bloques sincronizados

Implementado en `lib/models/block.dart`, `lib/session/vault_session.dart` y `lib/features/workspace/editor/block_editor/`.

### Modelo de datos

- `FolioBlock.syncGroupId`: campo `String?` añadido al modelo de bloque. Persiste en JSON (`syncGroupId`) y se propaga en `copyWith()` con sentinel `clearSyncGroupId`.

### Operaciones en `VaultSession`

| Método | Descripción |
|---|---|
| `createSyncGroup(pageId, blockId)` | Asigna un nuevo UUID como `syncGroupId` al bloque origen |
| `insertSyncedBlock(targetPageId, syncGroupId)` | Inserta una copia del bloque en otra página con el mismo `syncGroupId` |
| `unsyncBlock(pageId, blockId)` | Borra el `syncGroupId` del bloque (desvincula sin borrar contenido) |
| `syncGroupBlockCount(syncGroupId)` | Devuelve cuántos bloques comparten ese grupo en toda la libreta |
| `updateBlockTextFull(pageId, blockId, text, deltaJson)` | Actualiza texto + Delta JSON y dispara la propagación |
| `_propagateSyncedBlockContent(syncGroupId, text, deltaJson)` | Propaga el contenido a todos los bloques del grupo en otras páginas |

### Integración en el editor

- Menú contextual del bloque: opciones `sync_create`, `sync_insert`, `sync_unsync`.
- Badge visual en `editable_markdown_block_row.dart`: icono `Icons.sync_rounded` + contador del grupo.
- Al perder el foco, `flushNow()` llama a `updateBlockTextFull` para propagar los cambios.

---

## 39. Vista de grafo

Implementado en `lib/features/workspace/graph/graph_view_screen.dart`.

- **Acceso**: botón en la barra de herramientas del workspace (`id: 'graph_view'`) → `Navigator.push` a `GraphViewScreen`.
- **Algoritmo**: layout force-directed con 200 iteraciones. Parámetros: repulsión = 5 000, spring = 0.04, damping = 0.85, gravedad central = 0.015.
- **Renderizado**:
  - Nodos como círculos con etiqueta de título de página; tamaño proporcional a backlinks.
  - Aristas mediante `CustomPainter` (`_EdgePainter`) con líneas semitransparentes.
  - `InteractiveViewer` para zoom y paneo libre.
- **Interacción**:
  - Hover sobre nodo: resalte visual (`_hoveredNodeId`).
  - Tap en nodo: `Navigator.pop()` + `onOpenPage(pageId)` para navegar a la página.
- **Filtro**: switch "Incluir páginas sin enlaces" (`_includeOrphans`) en el AppBar.
- **Estado vacío**: mensaje `graphViewEmpty` cuando no hay páginas con relaciones.

---

## 40. Importar PDF con anotaciones

Implementado en `lib/features/workspace/shell/workspace_page_page_tools.dart`.

- **Activación**: menú de importación → extensión `pdf` añadida a `allowedExtensions` en `FilePicker`.
- **Diálogo de opciones**: permite elegir entre:
  - **Solo anotaciones**: extrae marcas de texto (`PdfTextMarkupAnnotation`) y notas popup (`PdfPopupAnnotation`).
  - **Texto completo**: extrae todo el texto con `PdfTextExtractor.extractText()`.
- **Procesamiento**:
  - Abre el archivo con `PdfDocument(inputBytes: bytes)` de `syncfusion_flutter_pdf`.
  - Construye un documento Markdown con el contenido extraído.
  - Las anotaciones se formatean como bloques de cita `> [Anotación]: texto`.
- **Resultado**: llama a `_s.importMarkdownDocument(fileName, markdown)` para crear una nueva página en la libreta.
- **Feedback**: snackbar de éxito (`importPdfSuccess`) o error (`importPdfFailed`); aviso si no se encontró texto (`importPdfNoText`).

---

## 41. Lienzo infinito (canvas)

- Bloque `canvas` en el catálogo (`block_type_catalog.dart`, sección avanzada).
- Al abrir una página que contiene el bloque, la interfaz pasa a `CanvasPage` (`lib/features/workspace/canvas/canvas_page.dart`), del mismo modo que la vista dedicada del tablero Kanban.
- Motor `FolioCanvasBoard` (`lib/features/workspace/canvas/folio_canvas_board.dart`): pan y zoom ilimitados con `InteractiveViewer`; nodos de texto, formas geométricas, imágenes; conectores entre nodos; dibujo libre (trazos); persistencia con debounce de 500 ms en `FolioCanvasData` serializado en `block.text`.
- Más de un bloque `canvas` en la misma página muestra aviso localizado (`canvasMultipleBlocksSnack`); se utiliza el primero.

---

## 42. Pantalla de inicio (Home)

Vista central del workspace cuando **no hay página abierta** (`page == null` en `VaultSession`). `WorkspaceEditorSurface` (`lib/features/workspace/shell/workspace_editor_surface.dart`) muestra entonces `WorkspaceHomeView` (`lib/features/workspace/shell/workspace_home_view.dart`) con transición `AnimatedSwitcher`.

### Abrir siempre en Home

- Ajustes del workspace: interruptor **«Abrir al inicio»** (p. ej. `settingsWorkspaceOpenToHomeTitle` en l10n; el subtítulo aclara que aplica **tras desbloquear** el cofre) — persiste `folio_workspace_open_to_home` (`WorkspacePrefsKeys.openWorkspaceToHome`).
- Al aplicar la selección inicial de página, `VaultSession._applyInitialPageSelection()` (`lib/session/vault_session.dart`) lee esa preferencia: si está activa, deja `_selectedPageId == null` y se muestra Home en lugar de restaurar la última página guardada o la primera raíz.

### Cabecera y reloj

- Saludo según la hora local (`workspaceHomeGreetingMorning` / `Afternoon` / `Evening` / `Night`).
- Fecha larga y hora destacada; opciones en la hoja de personalización: **12 h / 24 h**, **mostrar segundos**, **mostrar zona horaria** (`workspaceHomeClock*` en `AppSettings`).

### Diseño en columnas

- `WorkspaceHomeColumnLayout`: **automático** (dos columnas si el ancho ≥ 880 px y el modo no es compacto/móvil), **una columna** o **dos columnas** forzadas (en dual, umbral reducido a 640 px).
- Ancho máximo del contenido ~1040 px en dos columnas y ~600 px en una.

### Módulos (ordenables y opcionales)

Los bloques de contenido se identifican por `WorkspaceHomeSectionIds` (`lib/app/app_settings.dart`): orden por defecto en columna izquierda `folio_cloud`, `vault_status`, `onboarding`, `whats_new`, `search`, `root_pages`, `mini_stats`, `recents`; en la derecha `tasks`, `quick_actions`, `tip`, `create_page`. El usuario puede **reordenar** listas izquierda/derecha y **mostrar u ocultar** cada sección desde el bottom sheet «personalizar» (icono de afinación en la cabecera).

| ID (interno) | Rol |
|---|---|
| `folio_cloud` | Tarjeta rápida Folio Cloud si hay Firebase y sesión iniciada |
| `vault_status` | Resumen / estado del cofre |
| `onboarding` | Tarjeta de bienvenida (lógica de primera vez y cierre) |
| `whats_new` | Novedades de versión (descarte por versión en prefs) |
| `search` | Campo que filtra **páginas recientes** por título; envío / icono abre **búsqueda global** con la consulta |
| `root_pages` | Hasta 8 páginas raíz como chips con icono |
| `mini_stats` | Conteo de páginas y tareas próximas |
| `recents` | Lista de visitas recientes (`RecentPageVisitsChangeNotifier`, `lib/features/workspace/recent_page_visits.dart`) |
| `tasks` | Tareas con vencimiento en **14 días**, franja semanal de conteos; chip opcional para **preguntar a la IA** sobre esas tareas si el runtime de IA está habilitado |
| `quick_actions` | Accesos: ajustes, **vista de grafo**, plantillas, bloquear cofre, sync de dispositivos, **tarea rápida**, **hub de tareas de la libreta** (lista global), carpeta raíz, importar Markdown |
| `tip` | Consejo del día (12 textos rotativos según fecha) |
| `create_page` | Botón principal crear página |

### Otras notas

- Vista adaptada a `compact` / `mobileOptimized` (menos columnas y márgenes).
- Cuenta Cloud y `FolioCloudEntitlementsController` alimentan la tarjeta Cloud y el estado de suscripción cuando aplica.

---

## 43. Hub de tareas de la libreta

Vista **`VaultTaskHubPage`** (`lib/features/workspace/tasks/vault_task_hub_page.dart`) que lista **todas** las tareas de la libreta **sin** necesidad de un bloque Kanban en la página: agrega entradas con `VaultSession.collectTaskBlocks` (bloques `task` y, opcionalmente, ítems `todo`).

### Acceso

- **Barra lateral** (`sidebar.dart`): acción dedicada cuando el cofre está desbloqueado (`onOpenVaultTaskHub`).
- **Home** → módulo **Accesos rápidos**: icono de tareas de la libreta (`onOpenVaultTasks` en `workspace_home_view.dart` / `workspace_editor_surface.dart`).

### Filtros y presets

Definidos en `vault_task_entry_filters.dart` (`VaultTaskListPreset`):

| Preset | Criterio (resumen) |
|---|---|
| `all` | Todas |
| `active` | No completadas |
| `done` | Completadas |
| `dueToday` | Vencen hoy |
| `next7Days` | Próximos 7 días |
| `overdue` | Vencidas (solo bloques `task`) |
| `noDueDate` | Sin fecha límite |

- Búsqueda por texto en título, título de página, **tags** y **assignee**.
- Opción para incluir o excluir tareas simples tipo **`todo`** además de bloques **`task`**.
- Lista ordenada por fecha de vencimiento y título; las subtareas con `parentTaskId` se omiten en la lista principal (la jerarquía se ve en la página).

### Acciones

- Abrir la **página y bloque** de una tarea (`onOpenTaskInPage`).
- **Mover** la tarea a otra página (diálogo de selección de página).

---

## 44. Papelera de páginas

Soft-delete de páginas y carpetas con retención de **30 días**. El borrado desde el sidebar ya no es irreversible: mueve el elemento a la papelera.

### Modelo y persistencia

- Campo `FolioPage.trashedAt` (ISO-8601 UTC; ausente = página activa).
- Esquema de vault **v8** (`kVaultPayloadVersion` en `vault_payload.dart`).
- Las páginas en papelera siguen en el blob del vault (bloques, revisiones, ACL, comentarios y adjuntos se conservan hasta el borrado definitivo).

### Comportamiento (`VaultSession`)

| API | Efecto |
|---|---|
| `movePageToTrash(id)` | Marca `trashedAt` en la página **y todo su subárbol activo** |
| `restoreFromTrash(id)` | Quita `trashedAt` del subárbol; si el padre ya no existe o sigue en papelera, la raíz vuelve a la raíz de la libreta |
| `permanentlyDeleteFromTrash(id)` | Hard-delete del subárbol (adjuntos no referenciados, revisiones, ACL, comentarios) |
| `emptyTrash()` | Hard-delete de todas las raíces en papelera |
| `purgeExpiredTrash()` | Hard-delete de entradas con más de 30 días (`trashRetention`) al desbloquear / cargar la libreta |

- Siempre debe quedar **≥1 página activa**.
- Árbol del sidebar, Home, menciones, grafo, tareas e índice de búsqueda usan solo `activePages`.

### UI

- Confirmación del menú del tile: «Mover a la papelera» (subárbol completo para carpetas/páginas con hijas).
- Entrada fija **Papelera** en el pie del sidebar (`showPageTrashSheet` en `page_trash_sheet.dart`): restaurar, eliminar definitivamente, vaciar, con aviso de retención 30 días.
- Badge de conteo cuando hay elementos en papelera.

---

## 45. Servidor MCP local de Folio

Folio puede exponer el mismo catálogo de acciones que usa Quill internamente (crear/editar páginas, gestionar libretas, buscar, etc.) a clientes MCP externos — Claude Desktop, Claude Code, Cursor, o cualquier otro cliente que hable el [Model Context Protocol](https://modelcontextprotocol.io) — para que puedan leer y gestionar tu libreta directamente, no solo el chat de Quill dentro de la app.

Es una capacidad **desactivada por defecto y solo disponible en desktop** (Windows/Mac/Linux; no aplica a web ni móvil, porque necesita abrir un socket TCP real del sistema operativo).

### Cómo activarlo

1. Ajustes → sección de IA → interruptor **«Servidor MCP local (beta)»**.
2. Al activarlo, Folio arranca un servidor HTTP en `127.0.0.1:45832` (puerto **fijo**) y usa un **token Bearer persistente** (se genera una vez y se reutiliza entre arranques).
3. En Ajustes se muestran el endpoint y el token activos (`http://127.0.0.1:45832/mcp`), necesarios para configurar el cliente MCP externo.
4. Al desactivarlo (o cerrar Folio), el servidor se detiene — el token guardado sigue válido la próxima vez que se active.

### Configuración en Cursor (`mcp.json`)

En **Ajustes → IA**, con el servidor activo:

- **«Copiar config de Cursor»** — JSON con `url` + `Authorization` (HTTP local; Cursor lo admite).
- **«Copiar JSON de Claude Desktop»** — JSON stdio vía `npx mcp-remote` + `--allow-http` para pegar en `%APPDATA%\Claude\claude_desktop_config.json` (requiere Node.js/npx).

**Importante — «Conector personalizado» de Claude:** ese formulario (Settings → Connectors → Add custom connector) conecta desde **los servidores de Anthropic**, no desde tu PC. Exige una URL **HTTPS pública**; `http(s)://127.0.0.1` **no funciona** (Anthropic no puede alcanzar tu máquina). El MCP de Folio es deliberadamente solo loopback, así que **no se puede configurar ahí**. Para Claude Desktop en el mismo equipo, usa el JSON de desarrollador (`claude_desktop_config.json`), no el conector personalizado.

Pégalo en `~/.cursor/mcp.json` / `%APPDATA%\Claude\claude_desktop_config.json`, fusionando con otros `mcpServers` si ya existen.

Ejemplo Cursor:

```json
{
  "mcpServers": {
    "folio": {
      "url": "http://127.0.0.1:45832/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

Ejemplo Claude Desktop (puente HTTP→stdio):

```json
{
  "mcpServers": {
    "folio": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "http://127.0.0.1:45832/mcp",
        "--allow-http",
        "--header",
        "Authorization:${AUTH_HEADER}"
      ],
      "env": {
        "AUTH_HEADER": "Bearer <token>"
      }
    }
  }
}
```

Folio debe estar abierto con el interruptor MCP activado. Tras guardar, recarga MCP en el cliente.

### Protocolo y transporte

- JSON-RPC 2.0 sobre Streamable HTTP local (endpoint único `POST /mcp`): métodos `initialize`, `tools/list`, `tools/call`, `ping`, y notificaciones sin respuesta (`notifications/initialized`).
- Respuestas JSON (`application/json`); `GET`/`DELETE` responden `405` (sin SSE). Tras `initialize` se envía `Mcp-Session-Id`.
- Versiones de protocolo negociadas: `2024-11-05`, `2025-03-26`, `2025-06-18`, `2025-11-25` (preferida `2025-03-26`).
- Toda petición requiere la cabecera `Authorization: Bearer <token>`; sin ella, o con un token distinto, el servidor responde `401` y un error JSON-RPC `-32001`.
- El servidor **solo** bindea a `127.0.0.1` (loopback) — nunca escucha en una interfaz de red. Valida `Origin` si viene presente (solo localhost / 127.0.0.1).

### Catálogo de acciones expuestas

El mismo `FolioToolRegistry` que usa el bucle de tool-calling interno de Quill (ver sección 23): creación y edición de contenido (`create_page`, `append_blocks_to_page`, `replace_page_blocks`, `edit_page_blocks`, `insert_blocks_at_position`, `insert_todos`, `insert_tasks`, `translate_page_bilingual`) y gestión de libretas/páginas (`create_folder`, `rename_page`, `move_page`, `reorder_page`, `duplicate_page`, `set_page_emoji`, `add_page_tag`/`remove_page_tag`, `trash_page`/`restore_page`/`permanently_delete_page`/`empty_trash`, `delete_folder_flatten_children`, `search_pages`, `list_children`). Un cliente MCP los descubre llamando a `tools/list`, que devuelve cada uno con su `inputSchema` (JSON Schema de argumentos).

A diferencia del chat interno de Quill, un cliente MCP no tiene "página actual": debe pasar siempre un `pageId` explícito en los argumentos de cada tool que lo requiera.

### Permisos: aprobación como con cualquier otra integración

El servidor MCP **no ejecuta ninguna acción para un cliente hasta que el usuario lo aprueba explícitamente** — mismo mecanismo de permisos que ya usan los demás puentes locales de Folio (el bridge de Integraciones y Run2Doc):

1. Cuando un cliente MCP se conecta por primera vez (llamada `initialize`, con su `clientInfo.name`/`version`), Folio muestra un diálogo de permiso describiendo qué podrá hacer el cliente (crear/editar páginas, gestionar libretas, buscar) y qué no (el servidor nunca escucha fuera de este equipo).
2. Si el usuario deniega, la conexión falla con un error MCP (`-32001`) y no se guarda nada.
3. Si el usuario permite, la aprobación se guarda igual que cualquier app aprobada (`AppSettings.approveIntegrationApp`, con el id `mcp:<nombre-del-cliente>`) y las siguientes conexiones de ese mismo cliente no vuelven a preguntar.
4. Si se llama a cualquier tool antes de `initialize`, o el cliente identificado no está aprobado, el servidor responde con un error MCP (`-32002` sin `initialize`, `-32001` sin aprobar) en vez de ejecutar la acción.

**Revocar el acceso:** como cualquier otra integración aprobada, los clientes MCP aprobados aparecen en **Ajustes → Integraciones**, junto a Run2Doc y el resto de apps aprobadas, con un botón para revocar el acceso en cualquier momento. Revocar borra la aprobación guardada; la próxima vez que ese cliente se conecte, tendrá que pedir permiso de nuevo.

### Seguridad — resumen

- Apagado por defecto (opt-in explícito).
- Solo loopback, nunca red.
- Puerto fijo `45832`; token Bearer persistente (no rota en cada arranque).
- Aprobación explícita por cliente antes de ejecutar cualquier tool, revocable desde Ajustes → Integraciones en cualquier momento.
- No hay límite de "cuánto" puede hacer un cliente aprobado dentro del catálogo de tools — la aprobación es a nivel de cliente, no de acción; revocar es la forma de cortar el acceso.

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
| `windowsNotificationsEnabled` | bool | Notificaciones de escritorio para recordatorios de tareas (Windows / macOS / Linux vía `local_notifier`) |
| `quillToolCallingEnabled` | bool | Bucle de tool-calling de Quill (default `true`; se puede desactivar en Ajustes; sección 23) |
| `mcpServerEnabled` | bool | Servidor MCP local activado (sección 45); desktop-only |
| `mcpServerAuthToken` | String | Token Bearer persistente del servidor MCP local (sección 45) |

---

## Apéndice: compatibilidad y correcciones de build

### Migración a Flutter 3.44 / Dart 3.12

- **`flutter_quill` actualizado a `11.5.1`** (el `pubspec.lock` quedaba en `11.5.0`). La `11.5.1` implementa el nuevo método `TextInputClient.onFocusReceived` requerido por Flutter 3.44+. Con `11.5.0`, `QuillRawEditorState` fallaba al compilar con el error *"missing implementations for these members"*.
- **`ListView` en `settings_page.dart`**: se corrigió un parámetro inexistente (`scrollCacheExtent: ScrollCacheExtent.pixels(480)`) por el parámetro real del framework `cacheExtent: 480`.

### Script de compilación y publicación (`builld_all.ps1`)

`builld_all.ps1` se rehízo con un **menú interactivo** (además del modo directo por parámetros para CI). Al ejecutarlo sin argumentos (`.\builld_all.ps1`) muestra un menú con:

- **Publicar RELEASE estable** en GitHub: compila el instalador Windows (`Folio-Setup-<semver>.exe` vía Inno Setup) y ejecuta `gh release create v<semver>` con `--generate-notes`.
- **Publicar PRE-RELEASE / Beta**: igual, pero con `--prerelease` (alimenta el canal Beta del updater, ver [RELEASES.md](RELEASES.md)).
- **Publicar solo notas** (changelog) sin adjuntar instalador.
- **Compilar TODO** (Windows ZIP + MSIX + APK + Linux), o cada plataforma por separado.
- **Generar solo el instalador Windows** (`.exe`).
- **Mantenimiento**: `flutter clean` y cambio de versión en `pubspec.yaml`.

Detalles de implementación:

- **Compatibilidad CI intacta:** si se pasa `-SkipAndroid`, `-SkipLinux`, `-SkipMicrosoftStore` o `-NonInteractive`, el script salta el menú y ejecuta `build-all` (comportamiento legado que usa el workflow `folio-build-all.yml`). También admite `-Action <acción>` para invocación directa.
- **Instalador dinámico:** genera un `.iss` temporal con rutas absolutas al `Release` actual y `OutputDir`, evitando las rutas fijas obsoletas. Requiere `ISCC.exe` (Inno Setup); localizado por PATH o rutas por defecto.
- **Publicación:** usa `gh` (GitHub CLI); valida que esté instalado y autenticado, y que el tag no exista antes de publicar. Parámetros: `-ReleaseTag`, `-ReleaseTarget`, `-PreRelease`, `-DraftRelease`, `-BumpVersion`, `-Yes`. El `target_commitish` se **autodetecta** (rama actual si existe en `origin`, o rama por defecto del remoto → `main`) para evitar el error `Invalid target_commitish` cuando la rama por defecto no es `master`.
- **Robustez de caché:** opción `-Clean` / entrada de menú para `flutter clean` (resuelve el error de `CMakeCache.txt` cuando el repo se mueve de carpeta).
- **Codificación:** el script se mantiene en ASCII para evitar fallos de parseo entre Windows PowerShell 5.1 (ANSI) y PowerShell 7 (UTF-8).
- **`installer.iss`:** se corrigieron las rutas absolutas obsoletas (`E:\Folio-1\...`) por rutas relativas al repositorio.
- **Versionado MSIX sincronizado:** `Build-WindowsStore` ejecuta `dart run msix:create --store --version <semver>.0` tomando la versión de `pubspec.yaml`. Partner Center rechaza paquetes con el mismo *full name* (p. ej. `...Folio-PrivateWorkspace_0.4.1.0_X64_`) si el contenido difiere, así que el `msix_version` debe subir en cada publicación. Antes quedaba fijo en `pubspec.yaml` (`msix_version: 0.4.1.0`) y provocaba el error *"You must upload at least one package / uniquely identified by their full names"*; ahora sigue automáticamente a la versión de la app (último segmento `0` según políticas de la Store).

### Toolchain de Windows (MSVC 14.51 / Visual Studio 18)

- Se añadió `-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` de forma global en `windows/CMakeLists.txt`. Los MSVC recientes convierten `<experimental/coroutine>` en error fatal (`STL1011`), lo que rompía la compilación de los plugins `audioplayers_windows`, `local_auth_windows` y `webview_windows` (que aún usan ese header vía C++/WinRT).

### Firebase en Windows (crash de arranque)

En Windows, con el engine de Flutter 3.44 y el SDK C++ de Firebase, la app crasheaba al arrancar (antes de mostrar la ventana) por dos causas independientes:

1. **`firebase_auth` — `__fastfail` (`0xC0000409`).** Los `EventChannel` nativos `id-token` y `auth-state` despachan desde un hilo en segundo plano. El engine actual trata el tráfico de canales fuera del hilo de plataforma como fatal, tumbando el proceso justo tras inicializar Firebase Auth.
   - **Fix:** fork local vendorizado de `firebase_auth_platform_interface` (`vendor/firebase_auth_platform_interface`, base oficial `9.0.2`) referenciado con `dependency_overrides` (path). El parche omite el registro de **ambos** canales en Windows cuando la app activa `FirebaseAuthPlatform.disableIdTokenChannelOnWindows = true` (se hace en `main.dart`). `authStateChanges()`/`idTokenChanges()` siguen emitiendo el usuario en caché al suscribirse, así que el estado de sesión persistido se refleja al arrancar; lo que se pierde es la reactividad en vivo del canal (nuevos cambios de sesión no se propagan por stream en Windows).

2. **`cloud_firestore` — `FirestoreInternalError` (excepción C++ no controlada, `0xE06D7363`).** El SDK C++ de Firestore lanza un error interno fatal al inicializarse en Windows con el toolchain/engine actual (persiste incluso tras actualizar a `cloud_firestore` con Firebase C++ 13.5.0).
   - **Fix:** Firestore queda **deshabilitado en Windows** mediante el guard central `folioFirestoreSupported` (`lib/services/folio_firestore_support.dart`). Todos los accesos a Firestore comprueban ese flag: las lecturas devuelven datos vacíos y las escrituras se ignoran o lanzan un error claro. Puntos protegidos: `FolioFirestoreSync` (telemetría), `FolioCloudEntitlementsController` (doc de usuario/derechos), `folio_cloud_publish` (publicación web), `CommunityTemplateStore` (galería comunitaria), `CollabSessionController` (colaboración en vivo), media E2E de colaboración en el editor de bloques y el panel de telemetría. El resto de plataformas (Android, iOS, macOS, Linux, Web) usan Firestore con normalidad.

- Se subieron las versiones de Firebase (`firebase_core ^4.10.0`, `firebase_auth ^6.5.0`, `firebase_auth_platform_interface ^9.0.0`, `cloud_firestore ^6.5.0`, `firebase_storage ^13.4.0`, `cloud_functions ^6.3.0`).

---

## Correcciones y mejoras de robustez (julio 2026)

### Tienda de Apps

- **`setState() during build`:** `AppStoreService.fetchRegistry()` aplaza el primer `notifyListeners()` tras un microtask; `AppStoreScreen` lanza `_refreshRegistry()` en `addPostFrameCallback`.
- **Overflows UI:** nombre de app integrada con `Expanded`; fila de tags/rating en tarjetas con `Wrap`.
- **Localización:** textos de la tienda (pantalla, tarjetas, detalle, errores de registry) migrados a `lib/l10n/` (6 idiomas). El servicio expone códigos de error (`registryErrorCode`) traducidos en la UI.
- **Persistencia:** `_finalizeInstall()` hace `await _saveInstalled()` antes de notificar.

### Telemetría (`FolioFirestoreSync`)

- Cada evento encolado guarda el `userId` de la sesión que lo generó (no el `currentUser` del momento del flush).
- Los eventos solo se eliminan de la cola tras un `batch.commit()` exitoso; los fallidos se reinsertan al frente.
- `onUserChanged` se encadena en `_flushChain` para no solapar drains.

### Folio Cloud

- **Callables IA (móvil/macOS):** timeout de 120 s en `folio_cloud_callable.dart` con mapeo a `deadline-exceeded`.
- **Cloud-pack:** rollback de snapshot y blobs nuevos si falla `folioFinalizeCloudPack`.
- **Logging:** `catch` silenciosos sustituidos por `AppLogger` en cloud-pack sync, backup metadata y entitlements.
- **IA cloud:** errores no tipados preservan el mensaje real antes de mapear a `unavailable`.
- **Entitlements:** cancelación serializada del listener de documento por UID (`await _docSub?.cancel()`).
- **Backup:** comprobación de existencia del archivo antes de `putFile`.

### Localización incremental

- **Drive:** Cancel/Delete/Rename/Mover/color de carpeta usan claves `l10n` existentes o nuevas (`driveMoveToFolderTitle`, `driveFolderColor`).
- **Kanban/Jira:** diálogos y mensajes de sync Jira migrados a claves `kanban*` y `jira*` en los 6 `.arb`.
- **Release notes** y **estado vacío del editor** (`workspaceEditorReadyHeadline`, tips `workspaceHomeTip0–3`).
- **Pendiente incremental:** `database_block_editor.dart` aún usa helper `_t(es, en)` en parte del editor de bases de datos; conviene migrar en una tanda dedicada.

## Correcciones del sistema de notas (páginas y bloques) — julio 2026

Revisión centrada en errores del editor de bloques, páginas y persistencia de notas.

### Pérdida de datos (rich text WYSIWYG)

- **Clonado de bloques:** `cloneBlocksWithNewIds` y `createPageFromTemplate` ahora copian `richTextDeltaJson`, evitando perder el formato Quill al duplicar bloques, instanciar plantillas o pegar. `syncGroupId` se omite a propósito para que el clon sea independiente.
- **Flush al navegar:** `_disposeControllers()` vacía a la sesión los cambios Quill con debounce pendiente (`_flushPendingQuill`) antes de descartar los timers, en vez de cancelarlos sin guardar.
- **Flush en blur:** al perder foco un bloque WYSIWYG se persiste con `updateBlockTextFull` (texto + Delta), no solo el Markdown.
- **Bloqueo del vault:** `VaultSession.lock()` ejecuta `flushPendingSave()` (persistencia inmediata) antes de limpiar la memoria de sesión, evitando perder el autosave con debounce de 450 ms.

### Lógica de bloques

- **Backspace:** en bloques Quill usa el estado real del documento (texto plano y selección), no el `TextEditingController` espejo que puede estar desfasado; el caret tras merge se posiciona con la longitud de texto plano del bloque previo (`_blockCaretLength`).
- **Caret tras primera palabra / centinela:** al insertar el bloque vacío final, el editor captura y restaura el offset desde Quill (no desde el controller sombra desfasado), hace flush del debounce antes de capturar, evita reconciliar el documento mientras hay foco/debounce pendiente y no devuelve el cursor al inicio si el bloque ya tiene texto.
- **Split (Enter) y merge:** `splitBlockAtCaret` y `mergeBlockUp` limpian `richTextDeltaJson` de los bloques afectados para que el Markdown sea la fuente de verdad y no se restaure contenido obsoleto al recargar.
- **Fuga de `FocusNode`:** el overlay de preview reutiliza un `FocusNode` cacheado por bloque (`_folioQuillPreviewFocusFor`) liberado en el teardown, en vez de crear uno nuevo en cada `build`.

### Async y concurrencia

- Comprobaciones `mounted` tras `await` en pegado de tabla, picker de emoji del callout y `catch` de subida cloud de notas de reunión.
- Transcripción de reuniones: los chunks de audio se procesan en serie (`_chunkChain`) para no mezclar la transcripción fuera de orden.

### Robustez del modelo

- `FolioBlock.fromJson` / `FolioPage.fromJson`: lectura tolerante de `id` (string, numérico legacy o nulo) sin `CastError` que rompa la carga del vault; `tags` filtra no-strings; `VaultPayload.fromJson` tolera claves/valores no esperados en revisiones y ACL.
- **Toggle legacy:** `FolioToggleData.parseOrLegacy` conserva como cuerpo el texto plano antiguo en vez de vaciarlo.
- **Retroenlaces:** `backlinkPagesFor` detecta también bloques `child_page` que apuntan a la página objetivo.
- **IDs únicos en columnas:** `FolioColumnsData.tryParse` deduplica los IDs de bloque de todas las columnas al cargar (reasignando IDs a duplicados/vacíos), evitando que un JSON corrupto/importado haga que varios bloques compartan el mismo `TextEditingController`.
- **Flush antes de bloquear:** `VaultSession` expone hooks (`addPendingFlushHook`) que `flushPendingSave()` ejecuta antes de persistir; el editor registra uno que vacía a la sesión todos los bloques Quill con debounce pendiente, cerrando la ventana de pérdida al bloquear por inactividad o pasar a segundo plano.

### Localización

- Bloques de columnas: eliminado el helper `_t(es, en)`; etiquetas de tipo de bloque y controles de columna migrados a claves `columnBlockType*` / `columnList*` en los 6 idiomas.
- Error inline de Mermaid (`mermaidInlineLoadError`), placeholder y etiqueta de ecuación (`equationEmptyPlaceholder`, `equationLatexLabel`) y fallback del botón de plantilla (`templateButtonDefaultLabel`) localizados.

### Notas

- Ambos pendientes menores previos (IDs duplicados de controllers en columnas y la ventana de pérdida en bloqueo por inactividad) quedaron resueltos con la deduplicación de IDs al parsear columnas y los hooks de flush previos a `flushPendingSave()`.

## Workaround REST de Firestore en Windows — julio 2026

En Windows el SDK nativo de Cloud Firestore (C++) crashea al inicializarse, por lo que estaba deshabilitado (`folioFirestoreSupported == false`) y todas las lecturas devolvían vacío. Efecto visible: la suscripción a Folio Cloud no aparecía en Ajustes, porque `FolioCloudEntitlementsController` no podía leer `users/{uid}`.

- **Cliente REST** (`lib/services/folio_cloud/folio_firestore_rest.dart`): lee documentos de Firestore por su [API REST](https://firebase.google.com/docs/firestore/use-rest-api) usando el ID token de Firebase Auth como Bearer (Auth sí funciona en escritorio, igual que las Cloud Functions por HTTP). Incluye un decodificador del formato `Value` de Firestore (`integerValue` como String, `mapValue`, `arrayValue`, etc.) a `Map` plano compatible con los `fromJson` de la app. Reutilizable vía `folioFirestoreRestGetDocument(path)` y el atajo `folioFirestoreRestGetUserDoc(uid)`.
- **Integración:** `_fetchUserDocFromServerWithRetries` usa el fallback REST cuando el SDK nativo no está disponible, con los mismos reintentos por arranque en frío. Como en Windows ya se usa sondeo (`_folioFirestoreUseGetPolling`) en vez de streams, todas las rutas de derechos (carga inicial, `handleAppResumed`, refresco manual, re-sync con Stripe) funcionan ahora.
- **Alcance:** solo lecturas puntuales (`get`); no reemplaza streams en tiempo real (se aproximan con el sondeo existente) ni escrituras. El helper queda disponible para que otras lecturas (páginas publicadas, plantillas de comunidad, etc.) lo adopten si se requiere en Windows.

## Auditoría de seguridad y mantenimiento — julio 2026

Correcciones derivadas de la revisión integral del repositorio (seguridad, datos, localización e higiene).

### Seguridad y cifrado del vault

- **Índice de búsqueda:** en libretas cifradas el índice (`search_index.json`) ya no se persiste en disco; se mantiene solo en RAM y se borra al reconstruir. Evita títulos y fragmentos en texto plano fuera del blob cifrado.
- **Desbloqueo rápido:** la DEK de quick unlock migra a `flutter_secure_storage` (DPAPI/Keychain); las copias legacy en SharedPreferences se migran en la primera lectura. Al revocar passkey se desactiva también el quick unlock.
- **Integraciones OAuth/API keys:** `IntegrationAuthService` persiste tokens en almacén seguro del SO con migración automática desde SharedPreferences.
- **Sync LAN entre dispositivos:** canal cifrado y autenticado con X25519 + HKDF + AES-256-GCM (`device_sync_crypto.dart`); snapshots y peticiones van sellados; peers no emparejados no pueden leer el vault.
- **Passkeys:** `FolioRpServer` valida tipo WebAuthn (`webauthn.create` / `webauthn.get`), challenge, origen y coincidencia de `credentialID` tras la respuesta del autenticador.
- **Auto-actualizador:** verificación SHA-256 del instalador contra el digest publicado en el asset de GitHub antes de ejecutar.

### Integridad de datos

- **Persistencia serializada:** mutex en `VaultPersistenceController`; `onAppBackgrounded` hace flush y luego lock en secuencia; flush obligatorio antes de imports y backups destructivos.
- **Escritura atómica:** `AtomicFileWriter` usa `rename` con reemplazo (sin ventana sin archivo); restore desde `.bak` también para `vault.keys` y `vault.mode`.
- **WebDAV:** timeouts de conexión/envío/recepción en operaciones de backup remoto.

### Localización y UI

- **Drive:** menús, panel de detalles, rutas raíz y tipos de archivo migrados a claves `drive*` en los 6 idiomas.
- **ListTile en Home:** secciones de recientes y tareas envueltas en `Material` para evitar el error de fondo invisible con `tileColor`.
- **Código muerto:** eliminado el catálogo duplicado en `lib/features/workspace/widgets/` (la versión activa es `editor/block_type_catalog.dart`).

### Higiene del repositorio

- `.gitignore` ampliado: `Output/`, `lib.zip`, `build_out.txt`; artefactos de build e instaladores fuera de git.
- **`folio_local_secrets.dart`:** se versiona con placeholders vacíos; copiar desde `.example` para desarrollo local (no está en `.gitignore`).
- **CI de localización:** script `tool/check_arb_parity.ps1` para comparar claves entre `app_*.arb`.

### Documentación ampliada (índice)

- **App Store / extensiones `.folioapp`:** `lib/features/app_store/`, `lib/services/app_store/`.
- **Integración YouTrack:** ajustes en `lib/features/settings/youtrack_integration_settings.dart` y `lib/services/youtrack/`.
- **Pantalla de recuperación:** `lib/features/vault/recovery_screen.dart` (restauración desde `.bak` local).
- **Dashboard de telemetría:** `lib/features/telemetry_dashboard/telemetry_dashboard_page.dart`.

### Pendiente (deuda conocida)

- `database_block_editor.dart` y partes de `settings_page.dart` / `kanban_board_page.dart` aún usan `_t(es,en)` o ternarios manuales; migración gradual a `.arb`.
- División de monolitos (`settings_page.dart`, `kanban_board_page.dart`, `block_editor_state.dart`) en módulos más pequeños.
- Unificación de bridges `integrations_bridge` / `run2doc_bridge` (puertos ya separados: 45831 / 45832).
- Endurecer Argon2id en nuevas libretas requiere migración de `vault.keys` existentes.
