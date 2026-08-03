# Folio â€” Inventario completo de funcionalidades implementadas

> Documento generado a partir de una exploraciÃ³n exhaustiva del cÃ³digo fuente.  
> Ãšltima revisiÃ³n: 2026-07-31 (sincronizado con el estado del repositorio).

---

## Ãndice

1. [Plataformas soportadas](#1-plataformas-soportadas)
2. [Editor de bloques](#2-editor-de-bloques)
3. [Tipos de bloque](#3-tipos-de-bloque)
4. [Rich text WYSIWYG (Quill)](#4-rich-text-wysiwyg-quill)
5. [Barra de formato flotante](#5-barra-de-formato-flotante)
6. [MenÃº slash `/`](#6-menÃº-slash-)
7. [Sistema @mention de pÃ¡ginas](#7-sistema-mention-de-pÃ¡ginas)
8. [Atajos de teclado del editor](#8-atajos-de-teclado-del-editor)
9. [Atajos Markdown inline](#9-atajos-markdown-inline)
10. [Atajos globales remapeables](#10-atajos-globales-remapeables)
11. [SelecciÃ³n mÃºltiple de bloques](#11-selecciÃ³n-mÃºltiple-de-bloques)
12. [Drag & drop de bloques](#12-drag--drop-de-bloques)
13. [Duplicar bloques](#13-duplicar-bloques)
14. [Apariencia de bloques](#14-apariencia-de-bloques)
15. [Historial de versiones por pÃ¡gina](#15-historial-de-versiones-por-pÃ¡gina)
16. [Undo / Redo por pÃ¡gina](#16-undo--redo-por-pÃ¡gina)
17. [InserciÃ³n de medios](#17-inserciÃ³n-de-medios)
18. [Redimensionado de imÃ¡genes](#18-redimensionado-de-imÃ¡genes)
19. [Pegado inteligente de URLs](#19-pegado-inteligente-de-urls)
20. [Notas de reuniÃ³n (beta)](#20-notas-de-reuniÃ³n-beta)
21. [ColaboraciÃ³n en tiempo real](#21-colaboraciÃ³n-en-tiempo-real)
22. [SincronizaciÃ³n P2P entre dispositivos](#22-sincronizaciÃ³n-p2p-entre-dispositivos)
23. [Asistente IA Quill](#23-asistente-ia-quill)
24. [Contexto IA con `@`](#24-contexto-ia-con-)
25. [Folio Cloud](#25-folio-cloud)
26. [Seguridad de libreta (Vault)](#26-seguridad-de-libreta-vault)
27. [ImportaciÃ³n de contenido](#27-importaciÃ³n-de-contenido)
28. [ExportaciÃ³n de contenido](#28-exportaciÃ³n-de-contenido)
29. [IntegraciÃ³n con Jira](#29-integraciÃ³n-con-jira)
30. [BÃºsqueda global](#30-bÃºsqueda-global)
31. [Captura rÃ¡pida de tarea](#31-captura-rÃ¡pida-de-tarea)
32. [Temas y apariencia](#32-temas-y-apariencia)
33. [Iconos de pÃ¡gina personalizados](#33-iconos-de-pÃ¡gina-personalizados)
34. [Onboarding](#34-onboarding)
35. [Actualizador integrado](#35-actualizador-integrado)
36. [DiagnÃ³stico y reporte de bugs](#36-diagnÃ³stico-y-reporte-de-bugs)
37. [Modo zen / escritura sin distracciones](#37-modo-zen--escritura-sin-distracciones)
38. [Bloques sincronizados](#38-bloques-sincronizados)
39. [Vista de grafo](#39-vista-de-grafo)
40. [Importar PDF con anotaciones](#40-importar-pdf-con-anotaciones)
41. [Lienzo infinito (canvas)](#41-lienzo-infinito-canvas)
42. [Pantalla de inicio (Home)](#42-pantalla-de-inicio-home)
43. [Hub de tareas de la libreta](#43-hub-de-tareas-de-la-libreta)
44. [Papelera de pÃ¡ginas](#44-papelera-de-pÃ¡ginas)

**ApÃ©ndice:** [configuraciÃ³n persistida (`AppSettings`)](#apÃ©ndice-configuraciÃ³n-persistida-appsettings)

---

## 1. Plataformas soportadas

| Plataforma | Estado |
|---|---|
| Android | âœ… |
| iOS | âœ… |
| Windows (x64) | âœ… |
| Linux (x64) | âœ… |
| macOS (arm64 / x64) | âœ… |
| Web | âœ… |

La app es **local-first**: los datos se almacenan en disco; la nube (Firebase) es opcional.

**Windows (CMake / super_native_extensions):** si al compilar aparece `Get-Item : No se encontrÃ³ el elemento ...\AppData` en `resolve_symlinks.ps1`, ejecutar tras `flutter pub get`: `powershell -ExecutionPolicy Bypass -File tool/apply_cargokit_resolve_symlink_patch.ps1`. El proyecto incluye `tool/windows/cargokit_resolve_symlinks.ps1` (script endurecido). En `windows/CMakeLists.txt` se fija la polÃ­tica **CMP0175** para reducir avisos de plugins como `webview_windows`.

**Escritorio (Windows / Linux) y Firebase Analytics:** el runner de Flutter no registra el plugin nativo de `firebase_analytics` en esas plataformas. `FolioTelemetry` evita todas las llamadas a Analytics ahÃ­ (no hay implementaciÃ³n Pigeon); Firebase Core, Auth y Firestore siguen usÃ¡ndose cuando aplica. El arranque tambiÃ©n tolera fallos al cargar el acento del sistema (`SystemTheme`) y errores al inicializar bandeja / `window_manager` sin tumbar la app.

**Windows y Firebase Auth:** un bug del plugin puede cerrar el proceso tras iniciar sesiÃ³n o con sesiÃ³n restaurada (canal `id-token` desde hilo nativo incorrecto; [firebase/flutterfire#18210](https://github.com/firebase/flutterfire/issues/18210)). En `main.dart`, antes de `Firebase.initializeApp`, se activa `FirebaseAuthPlatform.disableIdTokenChannelOnWindows` y en `pubspec.yaml` hay un `dependency_overrides` de `firebase_auth_platform_interface` con el parche comunitario que omite esa suscripciÃ³n en Windows (trade-off documentado en el PR: `idTokenChanges()` no emite por refrescos de token; `authStateChanges()` y `getIdToken()` siguen funcionando).

**Windows y passkeys:** `PasskeyAuthenticator` se crea solo cuando hace falta (desbloqueo o registro), para no enganchar PasskeysDoctor al iniciar. En la pantalla de bloqueo, si solo hay passkey (sin Hello), no se lanza WebAuthn automÃ¡ticamente al abrir el bloqueo; el usuario puede usar el botÃ³n.

---

## 2. Editor de bloques

El editor es completamente personalizado (no usa un widget de terceros como editor principal). EstÃ¡ implementado en `lib/features/workspace/editor/block_editor/block_editor_state.dart` (parte de `block_editor.dart`; ~5 250 lÃ­neas) y sus ficheros de despacho asociados.

### Comportamiento general

- **Bloque sentinela**: siempre existe un pÃ¡rrafo vacÃ­o al final de la pÃ¡gina para que el usuario pueda hacer clic y escribir.
- **IntegraciÃ³n dual**: los bloques de texto enriquecido (`paragraph`, `h1`, `h2`, `h3`, `quote`, `callout`, `bullet`, `numbered`, `todo`, `toggle`) usan un `QuillController` WYSIWYG internamente, con persistencia dual en markdown + Delta JSON (`richTextDeltaJson`).
- **Modo solo lectura** (`readOnlyMode`): elimina controles de ediciÃ³n; Ãºtil para vistas de historial o publicaciones web.
- **Scroll TOC**: `scrollToBlock(blockId)` â€” desplazamiento animado con `Scrollable.ensureVisible` desde la tabla de contenidos lateral.
- **Ãndice de bloques ordenado**: `_orderedListNumber()` calcula el nÃºmero correlativo para listas numeradas, respetando niveles de anidaciÃ³n.

### Controles de bloque (UI compacta estilo Notion)

Implementados en `lib/app/folio_block_controls.dart`:

- **`BlockButton`**: botones compactos (`primary` / `secondary` / `tertiary` / `destructive`) con radio 12px, distintos del tema pill global de diÃ¡logos.
- **`FolioBlockToolbar`**: barra de acciones externa que va **debajo** del contenido del bloque (database, columnas, etc.).
- **`FolioTableGutterButton`**: botones `+` integrados en la rejilla de tablas (gutter derecho para columna, inferior para fila; menÃº en esquina para pegar/eliminar).
- **`FolioBlockResizeHandle`**: asa en la esquina inferior derecha para redimensionar media con `imageWidth` arrastrando horizontalmente (imagen, video, embed, file, spotify). El arrastre usa el ancho completo de la fila como referencia. `bookmark` ocupa siempre el ancho completo (sin asa). Sustituye la antigua toolbar de presets de ancho.

---

## 3. Tipos de bloque

**31 tipos** en el menÃº `/` y el selector de tipo (`blockTypeTemplates` en `lib/features/workspace/editor/block_type_catalog.dart`). El modelo de pÃ¡gina admite ademÃ¡s tipos como `task` (tareas del sistema) que no estÃ¡n en esa lista del slash.

| Clave | DescripciÃ³n |
|---|---|
| `paragraph` | PÃ¡rrafo de texto rico (WYSIWYG) |
| `child_page` | Enlace a subpÃ¡gina |
| `h1` | Encabezado 1 (WYSIWYG) |
| `h2` | Encabezado 2 (WYSIWYG) |
| `h3` | Encabezado 3 (WYSIWYG) |
| `quote` | Cita con barra lateral (WYSIWYG) |
| `divider` | Separador horizontal |
| `callout` | Bloque callout con icono emoji (WYSIWYG) |
| `bullet` | Lista de viÃ±etas (WYSIWYG, anidable) |
| `numbered` | Lista numerada (WYSIWYG, anidable) |
| `todo` | Lista de tareas con checkbox (WYSIWYG, anidable) |
| `toggle` | SecciÃ³n colapsable (WYSIWYG) |
| `image` | Imagen local, remota o URL |
| `bookmark` | Marcador de URL con tÃ­tulo y favicon |
| `video` | Video local o URL |
| `audio` | Audio local |
| `meeting_note` | Nota de reuniÃ³n con grabaciÃ³n y transcripciÃ³n (beta) |
| `code` | Bloque de cÃ³digo con resaltado sintÃ¡ctico |
| `file` | Archivo adjunto genÃ©rico |
| `table` | Tabla editable (`FolioTableData`) |
| `database` | Base de datos (beta, `FolioDatabaseData`) |
| `kanban` | Tablero Kanban de pÃ¡gina (`FolioKanbanData`; detalle en la subsecciÃ³n *Tablero Kanban*) |
| `drive` | IntegraciÃ³n Drive |
| `equation` | EcuaciÃ³n LaTeX |
| `mermaid` | Diagrama Mermaid (fuente editable + preview) |
| `toc` | Tabla de contenidos automÃ¡tica |
| `breadcrumb` | Miga de pan de la pÃ¡gina |
| `template_button` | BotÃ³n de plantilla con bloques predefinidos |
| `column_list` | Columnas de bloques |
| `canvas` | Lienzo infinito: nodos, formas, trazos y conectores ([Â§41](#41-lienzo-infinito-canvas)) |
| `embed` | Iframe/WebView (YouTube, web general) |

### Tablero Kanban (`kanban`)

- ConfiguraciÃ³n serializada en `block.text` como `FolioKanbanData` (`lib/models/folio_kanban_data.dart`).
- Vista de pÃ¡gina: `KanbanBoardPage` (`lib/features/workspace/kanban/kanban_board_page.dart`) â€” columnas, tarjetas vinculadas a tareas, conmutaciÃ³n entre vista tablero y editor clÃ¡sico (banner `kanbanClassicModeBanner`, acciones `kanbanToolbarOpenEditor` / `kanbanToolbarAddTask`).
- **Ancho completo**: en vista tablero (y tambiÃ©n Drive/Canvas dedicados) el contenido ignora `editorContentWidth` y usa todo el ancho del panel; las columnas Kanban reparten el espacio disponible (mÃ­n. 260 px; scroll horizontal si no caben).
- **CreaciÃ³n de tareas**: Â«AÃ±adir tareaÂ» y el Â«+Â» de columna crean un borrador local (`FolioTaskData.defaults`) y abren el mismo panel/sheet de detalle que al editar una tarjeta (`task_details_panel.dart`); no hay diÃ¡logos de creaciÃ³n aparte.
- Detalle de tarea en el tablero: fechas inicio/vencimiento, bloqueo y motivo, **recurrencia** (diaria / semanal / mensual / anual o derivada de `recurringRule` RRULE), **recordatorio** (icono compacto junto al selector; ver [Â§31](#31-captura-rÃ¡pida-de-tarea)), tiempo invertido, prioridad, descripciÃ³n, subtareas, integraciÃ³n Jira cuando aplica.
- El **selector de estado / columna** de una tarea sigue las columnas del **primer** bloque `kanban` de esa pÃ¡gina (`VaultSession.kanbanDataForPage`): chips en el editor del bloque `task` y desplegable en el panel de detalle; si el usuario aÃ±ade columnas personalizadas al tablero, la UI se actualiza al vuelo (notificaciÃ³n de sesiÃ³n).
- Tarjetas **bloqueadas** (`FolioTaskData.blocked`): tÃ­tulo en **rojo** y **tachado** en las vistas del tablero (columnas, lista, cuadrÃ­cula y lÃ­nea de tiempo), en el hub global de tareas, en el bloque dentro del editor y en el campo tÃ­tulo del detalle; no se pueden arrastrar entre columnas mientras siguen bloqueadas.
- Varias instancias del bloque en la misma pÃ¡gina: aviso `kanbanMultipleBlocksSnack` (se usa el primero).

### Bloque `task` (tareas enriquecidas)

- **No** aparece en el menÃº `/` ni en `blockTypeTemplates` (sigue habiendo **31** tipos allÃ­); el modelo de pÃ¡gina sÃ­ admite `type: task` y la UI lo pinta en el editor (`folio_special_block_widgets.dart`) y en vistas globales.
- Contenido en `block.text`: JSON **`FolioTaskData`** (`lib/models/folio_task_data.dart`), con `tryParse` / `encode` retrocompatibles entre versiones del esquema.
- Campos destacados: `title`, `status` (`todo` / `in_progress` / `done`), `columnId`, `parentTaskId` (subtareas enlazadas), `blocked` + `blockedReason`, `priority`, `description`, `startDate` / `dueDate` (ISO), `recurrence` + `recurringRule` (RRULE iCalendar opcional), `reminderEnabled`, `timeSpentMinutes`, `tags`, `assignee`, `estimatedMinutes`, `storyPoints`, `customProperties`, `blockedByTaskIds`, metadatos de IA (`aiGenerated`, `aiContextPageId`, `confidenceScore`, `suggestedDueDate`, â€¦), enlaces `external` / snapshot `jira`.
- En el editor: checkbox y barra rÃ¡pida; vista expandida con metadatos; arrastre y APIs de sesiÃ³n cuando el bloque se mueve entre pÃ¡ginas (`VaultSession.moveBlockToPage`, etc.).

### Selector de tipo de bloque

- DiÃ¡logo centrado en escritorio/tablet y bottom sheet en mÃ³vil: `BlockTypePickerDialog` / `BlockTypePickerSheet` en `lib/features/workspace/editor/block_editor_support_widgets.dart`.

---

## 4. Rich text WYSIWYG (Quill)

Disponible en los tipos `paragraph`, `h1`, `h2`, `h3`, `quote`, `callout`, `bullet`, `numbered`, `todo`, `toggle`.

- Basado en `flutter_quill` con codec Markdown propio (`FolioMarkdownQuillCodec`).
- **Persistencia dual**: el texto visible es Markdown; el documento Quill (Delta JSON) se guarda en `block.richTextDeltaJson`.
- **ReconversiÃ³n automÃ¡tica**: si `block.text` cambia externamente (undo/redo, sync, IA), el documento Quill se reconcilia con `_reconcileStylableQuillDocumentsWithModel()`.
- **Flush en pÃ©rdida de foco**: debounce de 200 ms durante la ediciÃ³n; flush inmediato al perder el foco.

### Formatos inline soportados (mediante Quill + `folioToggleWrap`)

| Formato | Markdown | Quill attribute |
|---|---|---|
| **Negrita** | `**texto**` | `bold` |
| *Cursiva* | `_texto_` | `italic` |
| <u>Subrayado</u> | `<u>texto</u>` | `underline` |
| ~~Tachado~~ | `~~texto~~` | `strike` |
| `CÃ³digo inline` | `` `texto` `` | `code` |
| [Enlace](url) | `[label](url)` | `link` |

---

## 5. Barra de formato flotante

- Aparece sobre el texto seleccionado cuando un bloque WYSIWYG tiene selecciÃ³n activa (`_selectionActiveBlockId`).
- Implementada en `FolioFormatToolbar` (`lib/features/workspace/editor/folio_text_format.dart`).
- Barra con scroll horizontal + flechas `â€¹ â€º` cuando el contenido supera el ancho disponible (`_FolioToolbarScrollStrip`).

### Acciones de la barra de formato

| BotÃ³n | AcciÃ³n |
|---|---|
| ðŸŽ¨ Paleta | Apariencia del bloque (color de texto, fondo, tamaÃ±o) |
| **B** | Negrita (`**...**`) |
| *I* | Cursiva (`_..._`) |
| <u>U</u> | Subrayado (`<u>...</u>`) |
| `</>` | CÃ³digo inline (`` `...` ``) |
| ~~S~~ | Tachado (`~~...~~`) |
| ðŸ”— | Insertar enlace (diÃ¡logo URL + etiqueta) |
| @pÃ¡gina | Mencionar pÃ¡gina (abre selector de pÃ¡gina) |
| @usuario | MenciÃ³n de usuario (opcional) |
| @fecha | Insertar fecha (opcional) |
| âˆ‘ | MatemÃ¡ticas inline `\( \)` (opcional) |

---

## 6. MenÃº slash `/`

Se activa escribiendo `/` en un bloque de texto compatible.

- **Filtrado**: la lista se filtra por el texto escrito tras `/`.
- **Orden por recientes**: los tipos usados recientemente aparecen primero (`_slashRecentByType`); lÃ­mite de historial recortado con `_trimSlashRecents()`.
- **NavegaciÃ³n teclado**: `â†‘` / `â†“` mueven la selecciÃ³n, `Enter` confirma, `Esc` cierra.
- **Auto-scroll**: `_ensurePopupSelectionVisible()` mantiene el Ã­tem seleccionado visible en la lista.

### Acciones inline del menÃº slash (comandos especiales)

| Comando | AcciÃ³n |
|---|---|
| `cmd_insert_date` | Inserta la fecha actual formateada con locale |
| `cmd_mention_page` | Abre selector de pÃ¡gina e inserta menciÃ³n markdown |
| `cmd_duplicate_prev` | Duplica el bloque anterior |
| `cmd_turn_into` | Abre selector de tipo para convertir el bloque actual |

---

## 7. Sistema @mention de pÃ¡ginas

- Se activa escribiendo `@` en un bloque de texto compatible.
- Muestra un panel flotante (`BlockEditorInlineMentionList`) con las pÃ¡ginas de la libreta filtradas por tÃ­tulo.
- **NavegaciÃ³n teclado**: `â†‘` / `â†“` / `Enter` / `Esc`.
- Al confirmar, inserta el enlace como `[@TÃ­tulo](folio://open/<pageId>) ` en el texto del bloque.
- Filtrado y ordenaciÃ³n por relevancia: coincidencia exacta > prefijo > contiene.

---

## 8. Atajos de teclado del editor

| Atajo | AcciÃ³n |
|---|---|
| `Ctrl+Z` / `Cmd+Z` | Deshacer (undo de pÃ¡gina) |
| `Ctrl+Shift+Z` / `Ctrl+Y` | Rehacer (redo de pÃ¡gina) |
| `Ctrl+D` / `Cmd+D` | Duplicar bloque actual |
| `Ctrl+V` / `Cmd+V` | Pegar (inteligente: detecta URL, Markdown multilÃ­nea) |
| `Tab` | Indentar bloque |
| `Shift+Tab` | Desindentar bloque |
| `Enter` | Crear nuevo bloque (configurable con `enterCreatesNewBlock`) |
| `Shift+Enter` | Salto de lÃ­nea dentro del bloque |
| `Backspace` (al inicio, bloque vacÃ­o) | Eliminar bloque y subir al anterior |
| `Backspace` (al inicio, con texto) | Fusionar bloque con el anterior (`mergeBlockUp`) |
| `â†‘` / `â†“` en menÃº `/` | Navegar lista slash |
| `Enter` en menÃº `/` | Confirmar selecciÃ³n slash |
| `Esc` en menÃº `/` o `@` | Cerrar menÃº flotante |

---

## 9. Atajos Markdown inline

Aplicados automÃ¡ticamente al escribir en bloques compatibles (`_tryMarkdownShortcut`), tambiÃ©n en el camino WYSIWYG (Quill) al hacer flush del documento:

| Escritura | Resultado |
|---|---|
| `- ` o `* ` | Convierte a bloque `bullet` |
| `[] ` o `[ ] ` | Convierte a bloque `todo` |
| ` ``` ` o ` ```<lang> ` | Convierte a bloque `code` (con lenguaje opcional) |
| `# Texto` | Convierte a bloque `h1` |
| `## Texto` | Convierte a bloque `h2` |
| `### Texto` | Convierte a bloque `h3` |

> Los encabezados con solo `# ` (sin texto) no se convierten para evitar perder el foco mientras se escribe.
>
> Si `- ` / `* ` / `[] ` se escriben en una **lÃ­nea nueva** dentro de un pÃ¡rrafo (p. ej. tras `Shift+Enter`), Folio parte el bloque: el texto anterior permanece y se inserta un bloque `bullet`/`todo` debajo (modelo 1 Ã­tem = 1 bloque). AsÃ­ no quedan listas markdown â€œfalsasâ€ dentro de un solo pÃ¡rrafo.

---

## 10. Atajos globales remapeables

8 atajos globales configurables en `lib/app/folio_in_app_shortcuts.dart`:

| Atajo por defecto | AcciÃ³n |
|---|---|
| `Ctrl+K` | BÃºsqueda global |
| `Ctrl+N` | Nueva pÃ¡gina |
| `Ctrl+Shift+T` | Captura rÃ¡pida de tarea |
| `Ctrl+,` | Ajustes |
| `Ctrl+L` | Bloquear libreta |
| `Alt+]` | Siguiente pÃ¡gina |
| `Alt+[` | PÃ¡gina anterior |
| `Ctrl+W` | Cerrar pÃ¡gina |

Todos son remapeables por el usuario.

### Historial de navegaciÃ³n (botones 4/5 del ratÃ³n)

En escritorio, los botones laterales del ratÃ³n (atrÃ¡s / adelante) navegan como en un navegador:

- **AtrÃ¡s (botÃ³n 4)**: si hay una pantalla apilada (ajustes, grafo, galerÃ­a de plantillas, etc.), la cierra (`Navigator.maybePop`). Si no, vuelve a la pÃ¡gina o Home visitado anteriormente.
- **Adelante (botÃ³n 5)**: avanza en el historial de pÃ¡ginas/Home (no reabre rutas `push`).
- El historial vive en `WorkspaceNavigationHistory` (`lib/session/workspace_navigation_history.dart`), enganchado a `VaultSession.selectPage` / `clearSelectedPage`. Se inicializa al desbloquear y se vacÃ­a al bloquear o cambiar de libreta.
- `Alt+[` / `Alt+]` siguen siendo pÃ¡gina adyacente en la lista, no historial.

---

## 11. SelecciÃ³n mÃºltiple de bloques

- **Click simple**: selecciona un bloque.
- **Ctrl+Click / Cmd+Click**: alterna la selecciÃ³n del bloque (aditiva).
- **Shift+Click**: selecciona un rango desde el ancla hasta el bloque clicado.
- **Arrastre con ratÃ³n (drag selection)**: `_beginDragSelection` â†’ `_updateDragSelection` â†’ `_endDragSelection`.
- Las acciones del menÃº contextual (duplicar, eliminar, mover) operan sobre todos los bloques seleccionados.
- La selecciÃ³n se limpia al cambiar de pÃ¡gina o al hacer click fuera.

---

## 12. Drag & drop de bloques

- Implementado con `ReorderableListView` + `ReorderableDragStartListener`.
- Callback `_onBlocksReordered(page, oldIndex, newIndex)` â†’ `_s.reorderBlockAt(pageId, oldIndex, newIndex)`.
- El foco se restaura al bloque que tenÃ­a el foco antes del reordenado.

---

## 13. Duplicar bloques

- **Ctrl+D**: duplica el bloque con foco.
- **MenÃº contextual del bloque**: opciÃ³n "Duplicar".
- **MenÃº slash**: comando `cmd_duplicate_prev` duplica el bloque anterior.
- Multi-selecciÃ³n: `_duplicateSelectedBlocks(page, blockIds)` clona todos los seleccionados y los inserta justo despuÃ©s del Ãºltimo.
- ImplementaciÃ³n: `_s.cloneBlocksWithNewIds(pageId, blocks)` asigna nuevos IDs a los clones.

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
| `surface` | `surfaceContainerHigh` Î± 72% |
| `primary` | `primaryContainer` Î± 62% |
| `secondary` | `secondaryContainer` Î± 62% |
| `tertiary` | `tertiaryContainer` Î± 62% |
| `error` | `errorContainer` Î± 70% |

### TamaÃ±o de fuente (`fontScale`)

| Etiqueta | Factor |
|---|---|
| S | 0,85Ã— |
| M | 1,00Ã— (por defecto) |
| L | 1,15Ã— |
| XL | 1,30Ã— |

El selector se presenta como un bottom sheet con preview en tiempo real y botÃ³n "Restablecer".

---

## 15. Historial de versiones por pÃ¡gina

- `PageHistoryScreen` (`lib/features/workspace/history/page_history_sheet.dart`).
- **Formato v1 (canÃ³nico local):** la libreta vive en `<vault>/repo/` (Ã¡rbol) + `<vault>/versions/` (snapshots). Tras migrar o crear una libreta nueva se escribe `vault.format=1` y `vault.v1-verified` (fingerprint de pÃ¡ginas/bloques). **`vault.bin` no se borra en el mismo turno que la migraciÃ³n**: se conserva (y se crea `vault.bin.pre-migration`) hasta un sync/backup externo exitoso (`cleanupV0AfterSuccessfulSync`). Los backups/cloud pueden usar bytes equivalentes al blob como formato de intercambio.
- **Integridad anti-pÃ©rdida:** la migraciÃ³n escribe en `repo.tmp/`, hace round-trip `compose` + comparaciÃ³n de fingerprints (pÃ¡ginas/bloques, incl. `kanban`/`task`), y solo entonces hace swap a `repo/` y escribe el marker. Una lÃ­nea malformada en `blocks.jsonl` **aborta** la carga (no se omiten bloques en silencio). Persistencia v1 tambiÃ©n usa staging `repo.tmp` â†’ swap.
- **RecuperaciÃ³n:** si el Ã¡rbol v1 no carga, la app entra en `RecoveryScreen` (no cae en silencio a un `vault.bin` obsoleto). Si existe `vault.bin.pre-migration`, se ofrece restaurarlo (rollback); tambiÃ©n `.bak`, ZIP de backup y exportaciÃ³n de emergencia. Rollback vÃ­a `VaultMigrationTool.rollbackMigration`.
- **v0 (legacy):** revisiones en memoria (`pageRevisions`) dentro del payload monolÃ­tico; la migraciÃ³n a v1 es obligatoria en Beta y **materializa cada revisiÃ³n** como snapshot (antigua â†’ reciente) mÃ¡s un snapshot del estado actual.
- Lista filtrada por pÃ¡gina (estilo `git log -- path`): solo snapshots cuyo `meta.json`/`blocks.jsonl` de esa pÃ¡gina cambiÃ³.
- **Un snapshot por cambio real** tras idle de ediciÃ³n (dedupe por hash); el guardado rÃ¡pido del Ã¡rbol no crea versiones. Labels desde el tÃ­tulo en `meta.json`.
- **Vista diff:** `PageRevisionDiffView` compara la versiÃ³n con la anterior (tambiÃ©n en v1, extrayendo la pÃ¡gina del zip del snapshot).
- **RestauraciÃ³n** `restoreVersion(pageId, versionId)`: meta completa (tÃ­tulo, emoji, tags, properties, bloques) sin tocar otras pÃ¡ginas.
- **Borrar versiÃ³n** en v1: soft-hide por pÃ¡gina en `repo/vault/hidden_versions.json` (no borra el snapshot global de la libreta).
- PresentaciÃ³n adaptativa: diÃ¡logo 760Ã—720 px en escritorio, ruta de pantalla completa en mÃ³vil.

---

## 16. Undo / Redo por pÃ¡gina

- Implementado en `VaultSession` (`lib/session/vault_session.dart`).
- **Stacks independientes por pÃ¡gina**: `_undoByPage` / `_redoByPage` (Map keyed por `pageId`).
- **LÃ­mite**: `_maxUndoStepsPerPage = 100` pasos.
- **Coalescing**: escritura continua se agrupa para no saturar el historial.
- API pÃºblica: `undoPageEdits(pageId)` / `redoPageEdits(pageId)`, `canUndoSelectedPage`, `canRedoSelectedPage`.

---

## 17. InserciÃ³n de medios

### ImÃ¡genes

- Picker de archivos local (Android, iOS, Windows, Linux, macOS).
- URL remota (detecciÃ³n automÃ¡tica de extensiÃ³n: `.png`, `.jpg`, `.gif`, `.webp`, `.bmp`, `.svg`).
- Si el texto de un bloque pÃ¡rrafo es una URL de imagen, se convierte automÃ¡ticamente a bloque `image`.

### Video

- Picker local.
- URL remota.

### Audio

- Picker local.

### Archivos adjuntos (`file`)

- Picker local.
- El bloque muestra nombre, tamaÃ±o y botÃ³n de apertura externa (`launchUrl`).

### Collab media (salas de colaboraciÃ³n)

- Los medios se cifran con AES-256-GCM antes de subir a Firebase Storage.
- Al bajar, se descifran y se cachean en disco (`_collabMediaCacheDir`).
- URI interna: `collab-media://<roomId>/<mediaId>`.
- Ver [Â§21 ColaboraciÃ³n](#21-colaboraciÃ³n-en-tiempo-real) para el flujo completo.

---

## 18. Redimensionado de imÃ¡genes

- Factor de ancho: 20%â€“100% (`imageWidth` en el bloque, rango 0,2â€“1,0).
- Redimensionar: arrastrar el asa inferior derecha en bloques de media (`FolioBlockResizeHandle`).
- Atajos del menÃº contextual: Â«MÃ¡s pequeÃ±oÂ» / Â«MÃ¡s grandeÂ» (Â±10%), Â«50%Â», Â«75%Â», Â«100%Â».

---

## 19. Pegado inteligente de URLs

Al pegar (`Ctrl+V`) una URL en un bloque de texto (WYSIWYG vÃ­a Quill), en bloques de media vacÃ­os (embed, spotify, imagen, etc.) o en un marcador, se muestra un bottom sheet con opciones:

| Modo (`FolioPasteUrlMode`) | Comportamiento |
|---|---|
| `markdownUrl` | Inserta `[hostname](url)` |
| `embed` | Convierte el bloque a `embed` con la URL |
| `bookmark` | Convierte el bloque a `bookmark`; obtiene el tÃ­tulo de la pÃ¡gina automÃ¡ticamente (`fetchWebPageTitle`) |
| `vaultMention` | Inserta `[tÃ­tulo](url)`; obtiene el tÃ­tulo de la web; detecta YouTube y aÃ±ade `â–¶` |

Si el texto pegado es multilÃ­nea con sintaxis Markdown, se parsea como bloques completos (`_pasteMarkdownAsBlocks`).

---

## 20. Notas de reuniÃ³n (beta)

Bloque `meeting_note` implementado en `lib/features/workspace/editor/meeting_note_block_widget.dart`.

### Alcance y riesgo (EU AI Act)

Solo **transcripciÃ³n de texto** + **diarizaciÃ³n de hablantes** (`Speaker N`). No hay anÃ¡lisis de emociones, tono afectivo ni biometrÃ­a de identidad. Nivel de riesgo: **limitado** (transparencia). Detalle: [AI_COMPLIANCE.md](AI_COMPLIANCE.md).

### Estados del bloque

`idle` â†’ `setup` â†’ `recording` â†’ `cloudProcessing` â†’ `completed`

### Proveedores de transcripciÃ³n

| Proveedor | DescripciÃ³n |
|---|---|
| **Local (Whisper.cpp)** | Inferencia local sin conexiÃ³n |
| **Quill Cloud** | TranscripciÃ³n en la nube vÃ­a API de Folio |

### Servicio Whisper local (`lib/services/whisper_service.dart`)

- Modelos disponibles: `tiny` (74 MB) y `base-q8_0`.
- Plataformas: Windows x64, macOS arm64, Linux x64.
- El binario `whisper.cpp` se descarga automÃ¡ticamente desde GitHub Releases.
- Los modelos se descargan desde HuggingFace.

### Funcionalidades avanzadas

- **Proceso aparte (worker)**: captura, mezcla, Whisper y diarizaciÃ³n corren en un proceso OS distinto (`--meeting-worker`, IPC TCP localhost). AsÃ­ un OOM o crash del pipeline no tumba Folio. Cliente: `MeetingNoteSessionController`.
- **NavegaciÃ³n en segundo plano**: al cambiar de pÃ¡gina la sesiÃ³n sigue; barra en el footer del sidebar (`MeetingNoteActiveBar`, mismo estilo que media) visible solo mientras hay grabaciÃ³n/procesado.
- **DiarizaciÃ³n** (`DiarizationService`): diferenciaciÃ³n de hablantes.
- **Mezcla de audio** (`AudioMixerService`): mezcla micrÃ³fono + audio del sistema.
- **Audio del sistema** (`SystemAudioService`): captura del audio de la pantalla.
- **Perfil de hardware** (`TranscriptionHardwareProfile`): ajusta parÃ¡metros segÃºn la capacidad del dispositivo.
- **Idiomas**: auto-detecciÃ³n, `es`, `en` y mÃ¡s.

---

## 21. ColaboraciÃ³n en tiempo real

### Salas de colaboraciÃ³n

Implementado en `lib/services/collab/collab_session_controller.dart`.

- Backend: Firestore colecciÃ³n `collabRooms/{roomId}`.
- **E2E v1**: clave de sala AES-256-GCM empaquetada en `wrappedRoomKey` (campo `e2eV: 1`).
- `CollabE2eCrypto.unwrapRoomKeyB64()` desempaqueta la clave usando el cÃ³digo de uniÃ³n (`joinCode`) normalizado.
- Fallback de polling en Windows/Linux (Firestore Realtime no disponible â†’ polling periÃ³dico).

### Chat de sala

- Mensajes cifrados E2E: `CollabChatMessageView` (id, authorUid, authorName, text, createdAtMs).
- Contador de mensajes no leÃ­dos.
- Panel adaptativo: panel lateral en escritorio, bottom sheet en mÃ³vil.

### Multimedia cifrado en salas

1. **Subida**: `_uploadCollabMediaForBlock()` â†’ `prepareCollabMediaUpload` (Cloud Function) â†’ cifrado AES-256-GCM â†’ Firebase Storage â†’ `commitCollabMediaUpload` (Cloud Function).
2. **Descarga**: Firestore lookup (`collabRooms/{roomId}/media/{mediaId}`) â†’ Firebase Storage â†’ descifrado AES-256-GCM â†’ cachÃ© local.
3. Progreso de subida con ETA en tiempo real (solo Android/iOS/macOS; Windows/Linux usan modo simplificado sin barra de progreso).
4. En **Windows/Linux**, subidas y descargas de Storage usan la **API REST** (`folio_firebase_storage_rest.dart` / `folio_storage_transport.dart`) en lugar del plugin nativo, que envÃ­a eventos `taskEvent` desde un hilo de fondo y provoca el error `non-platform thread` del motor Flutter.

---

## 22. SincronizaciÃ³n P2P entre dispositivos

Implementado en `lib/services/device_sync/device_sync_controller.dart`. El merge lÃ³gico es compartido con Folio Cloud (`lib/services/sync/vault_sync_merge.dart`).

### Protocolo de red

| ParÃ¡metro | Valor |
|---|---|
| Grupo multicast UDP | `239.255.42.99` |
| Puerto discovery | `45839` |
| Puerto de datos (TCP) | `45840` |
| Intervalo Hello | 4 s |
| Tiempo hasta stale | 18 s |

### CaracterÃ­sticas

- **Emparejamiento**: handshake de peticiÃ³n/aceptaciÃ³n bilateral; los peers emparejados se persisten en `SharedPreferences`.
- **Relay opcional**: `syncRelayEnabled` permite atravesar NATs cuando el multicast no funciona (flag de UI; el relay en sÃ­ no estÃ¡ implementado â€” la sync por internet va por Folio Cloud).
- **Pack de sync**: export/import usa `folio.sync.pack.v1` (`VaultSyncPack`): payload lÃ³gico + adjuntos content-addressed bajo `attachments/`.
- **Merge semÃ¡ntico (pÃ¡gina/bloque)**: `VaultSyncMergeEngine` hace uniÃ³n a 3 vÃ­as (local Â· remoto Â· baseline). PÃ¡ginas/bloques distintos se conservan; el mismo bloque editado en ambos lados genera conflicto **granular** (se mantiene local, el remoto se guarda en historial/revisiÃ³n). Tombstones de pÃ¡ginas borradas evitan resucitar contenido.
- **ResoluciÃ³n de conflictos**: UI tipo merge de Git (`SyncConflictMergeSheet`) con tÃ­tulo de pÃ¡gina legible, diff por hunks (tu versiÃ³n / la otra / ambas), aplicar merge, mantener local o aceptar remoto. Acceso desde el chip de sync, banner del editor, Home y Ajustes (misma UI). La cola de conflictos se persiste por libreta (`SyncConflictStore`) y se restaura al desbloquear; el contador `syncPendingConflicts` se alinea con la cola real.
- **Peers estables**: la Ãºltima IP conocida de un peer se conserva incluso si el discovery falla (redes con multicast inestable).
- SupresiÃ³n de callback `onPersisted` durante `applySyncSnapshotBytes` para evitar bucles pushâ†”import.

---

## 23. Asistente IA Quill

Quill es una funciÃ³n **estable** (fuera de beta): el panel de chat muestra el subtÃ­tulo fijo **Â«Asistente IAÂ»** (transparencia EU AI Act). Activar la IA en Ajustes pide un diÃ¡logo de consentimiento (uso de IA + alcance global de la app). DocumentaciÃ³n: [AI_COMPLIANCE.md](AI_COMPLIANCE.md).

Los bloques insertados por Quill llevan `aiGenerated: true` (icono en el editor; se limpia al editar a mano).

### Ajustes â†’ IA (orden)

Un solo panel con tres bloques:

1. **BÃ¡sico** â€” hero con estado real (activo/proveedor/modelo), comparativa Cloud vs local (abierta si aÃºn no hay setup; colapsable si ya hay), activar IA, documentaciÃ³n de IA, proveedor y modelo.
2. **Experiencia Quill** â€” pensamiento, vista dividida, Copilot experimental e instrucciones personalizadas.
3. **Avanzado** (colapsado) â€” MCP local, ventana de contexto, endpoint, API key, timeout y listado de modelos.

### Proveedores (`AiProvider`)

| Proveedor | DescripciÃ³n |
|---|---|
| `none` | Sin IA |
| `ollama` | Servidor Ollama local (**solo escritorio**) |
| `lmStudio` | LM Studio local (**solo escritorio**) |
| `quillCloud` | API de inferencia de Folio Cloud |
| `openAi` / `gemini` | BYOK con API key propia |

En **web**, **Android** e **iOS** no hay Ollama/LM Studio (`aiLocalProvidersSupported == false`); Quill se activa con Folio Cloud (y opcionalmente OpenAI/Gemini con clave).

### Modos de operaciÃ³n (`lib/session/vault_session_ai.dart`)

| Modo | DescripciÃ³n |
|---|---|
| `chat` | ConversaciÃ³n libre con contexto |
| `summarize_current` | Resume el contenido de la pÃ¡gina actual |
| `append_current` | AÃ±ade el resultado al final de la pÃ¡gina |
| `replace_current` | Reemplaza el contenido de la pÃ¡gina |
| `edit_current` | Edita secciones especÃ­ficas de la pÃ¡gina |
| `create_page` | Crea una nueva pÃ¡gina **con bloques de contenido ya redactados** (no solo el tÃ­tulo) |

Si el modelo elige `create_page` sin contenido Ãºtil, Folio hace fallback a `generateStandalonePageWithAi` (generador dedicado con reintento) en lugar de dejar una pÃ¡gina vacÃ­a. Frases tipo Â«crÃ©ame una pÃ¡ginaâ€¦Â» se detectan como intenciÃ³n de creaciÃ³n (incluidos clÃ­ticos `crearme` / `crÃ©ame`).

### Tool-calling (recomendado)

- Ajuste **`quillToolCallingEnabled`** (default **activado**): usa `runToolLoop` + `FolioToolRegistry` (mismas acciones que el MCP local).
- Con el flag desactivado, Quill usa el JSON legado (`mode`/`reply`/`blocks`).
- La tool `create_page` **rechaza** `blocks` vacÃ­o; el modelo debe rellenar contenido (p. ej. `mermaid` si piden diagramas).
- Las respuestas de chat son **completas por defecto**; breves solo si el usuario pide Â«cortoÂ»/Â«breveÂ».
- **Paridad con MCP**: el bucle admite hasta **14** pasos (create + reintentos + cierre). El system prompt pide actuar como agente (preferir tools, encadenar multi-paso sin pedir permiso por cada uno; no pÃ¡ginas solo-tÃ­tulo). Si `create_page` deja pocos bloques Ãºtiles (&lt;4), Quill rellena con `generateContentWithAi` sobre esa pÃ¡gina.
- Modelo OpenAI por defecto (BYOK / seed / fallback Cloud Functions): **`gpt-5.4-mini-2026-03-17`** (sobreescribible con `OPENAI_MODEL`).

### Generación de imágenes

Quill puede generar una imagen a partir de un prompt de texto, con contexto de página opcional (solo si el usuario activa el toggle, apagado por defecto).

- **Dos caminos**: tool `generate_image` disponible para el agente en el chat normal (conversacional), y una entrada dedicada — icono «Generar imagen» en el compositor — que abre un prompt + toggle «usar contexto de la página actual» + botón Generar, sin depender de que el modelo decida invocar la tool.
- **Siempre se muestra en el chat primero**: la imagen aparece como una tarjeta con chip «Generado por IA», el prompt como subtítulo, y un botón persistente **«Insertar en la página»** — nunca se inserta automáticamente.
- **Insertar**: crea un bloque `image` (`aiGenerated: true`) en la página abierta; en una sala de colaboración con el editor de esa página montado, dispara la misma subida cifrada que el picker de imagen local.
- **Proveedores**: `quillCloud` (backend Spring Boot → API de imágenes de OpenAI, modelo `gpt-image-2-2026-04-21` por defecto, configurable desde el panel de administración) y BYOK `openAi`/endpoint OpenAI-compatible (incluye servidores locales tipo LocalAI/ComfyUI-shim). `ollama`/`lmStudio` no soportan generación de imágenes hoy y lo reportan con un mensaje claro.
- **Tinta**: operación de costo plano `generate_image` (sin recargo por tokens), apagable sin redeploy vía el flag de administración `FEATURE_FLAG_AI_IMAGE_GENERATION_ENABLED`.
- Código: `lib/services/ai/folio_tool_registry.dart` (tool), `lib/session/vault_session_ai.dart` (`generateImageForChatDirect`, wiring del tool-loop), `lib/features/workspace/shell/workspace_page_ai_generated_image.dart` (tarjeta de chat), `lib/features/workspace/shell/workspace_page_ai_panel.dart` (entrada dedicada). Backend: `FolioBackend` `ai/AiController.java` (`POST /api/v1/ai/generate-image`), `ai/HttpOpenAiClient.java`.

### Modo Plan (híbrido)

Toggle **por conversaciÃ³n** en el compositor del panel Quill (efÃ­mero, apagado por defecto; no se guarda en Ajustes ni en el JSON del hilo):

1. **Propuesta**: `agentChatWithAiPlanProposal` hace una sola completion con `toolChoice: 'none'`. El plan se muestra como **tarjeta/artefacto editable** (estilo Cursor/Claude): documento de pasos, secciÃ³n **Ajustar** (revisiÃ³n por notas), **Rechazar** o **Aprobar y ejecutar**. Metadata `agentPlan` con `status`, `planText` y contexto. **No muta la bÃ³veda**.
2. **Aprobar**: botÃ³n bajo el plan (usa el texto editado), o mensaje corto afirmativo (Â«sÃ­Â», Â«ejecutaÂ», â€¦) con plan pendiente â†’ ejecuciÃ³n con hasta **28** pasos. El texto del plan aprobado se inyecta como **contrato** en el prompt de ejecuciÃ³n (no solo en extras) para que el agente no lo olvide.
3. **Ajustar**: el usuario edita el texto del plan y/o pide una revisiÃ³n (Â«Revisar planÂ») que regenera solo el documento pendiente.
4. **Cancelar/Rechazar**: marca `status: cancelled` (no-op sobre la bÃ³veda).
5. **ConfirmaciÃ³n extra**: solo en la ejecuciÃ³n de un plan aprobado, `FolioToolRegistry.onConfirmIrreversibleTool` pausa `permanently_delete_page` y `empty_trash`. La ruta normal y el MCP **no** pasan ese callback.
6. **`create_folder`**: exige `title` descriptivo (evita carpetas Â«Nuevo FolioÂ» sin renombrar).

CÃ³digo: `workspace_page_ai_plan.dart`, APIs en `vault_session_ai.dart`.

### Interfaz de chat (panel Quill)

CÃ³digo principal: `lib/features/workspace/shell/workspace_page_ai_panel.dart` (cabecera, lista, compositor, mÃ³vil), `lib/features/workspace/shell/workspace_page_ai_threads.dart` (hoja selector de hilos), `lib/features/workspace/shell/workspace_page_ai_plan.dart` (modo Plan), `lib/features/workspace/shell/ai_chat_reply_skeleton.dart` (shimmer), filas de mensaje en `workspace_page.dart`. LÃ­mites adaptativos: `QuillChatLayout` en `lib/app/ui_tokens.dart` (`mobile` / `dockNarrow` / `dockWide` / `split`).

#### Cabecera y modo de panel

- **Cabecera fina**: avatar + tÃ­tulo del hilo + subtÃ­tulo de contexto; acciones (ajustes, menÃº, split, cerrar) en iconos compactos. Sin gradiente/badge pesado.
- Mini barra de **tokens / tinta** siempre visible bajo la cabecera.
- MenÃº **Â«â‹®Â»** abre hoja con proveedor e ink (Folio Cloud).
- **Layout adaptativo**: dock estrecho (&lt;1280), dock amplio (â‰¥1280), split (borde plano, sin sombra) y mÃ³vil (`DraggableScrollableSheet` ~0.55â€“0.95). El dock se **acota siempre al body** del workspace (bajo el AppBar): no puede crecer por encima del toolbar; el botÃ³n cerrar permanece accesible.

#### Hilos de conversaciÃ³n

- Fila compacta: selector del hilo activo (abre sheet con bÃºsqueda) + renombrar / eliminar / **Nuevo chat**.
- El sheet de hilos (`workspace_page_ai_threads.dart`) conserva bÃºsqueda y lista vertical.

#### Lista de mensajes

- Burbujas unificadas (avatar 28 px, `FolioRadius.lg`); typing/tool activity alineados.
- **Razonamiento**, typewriter, shimmer, feedback y snapshots de agente: sin cambios de comportamiento.

#### Compositor

- Fila compacta **siempre visible** (sin `ExpansionTile`): chips de tokens de la Ãºltima respuesta, tinta restante y coste estimado; chips horizontales de contexto/`@`/adjuntos (o hint `aiContextComposerHelper`).
- El icono de marca de Quill es una **pluma** (`FolioIcons.quill` / `history_edu`) en chat, ajustes, onboarding, home y toolbar Â«Ask QuillÂ».

#### Estado vacÃ­o y datos auxiliares

- Pantalla sin mensajes: icono, **`aiChatEmptyHint`** y botÃ³n **`aiChatEmptyFocusComposer`**.
- Tras cada respuesta: **`AiTokenUsage`** cuando el backend lo devuelve.
- **Adjuntos**: `AiFileAttachment` (nombre, MIME, contenido).

### Multi-hilo (persistencia y tÃ­tulos)

- Varios hilos independientes guardados en la sesiÃ³n/vault; la **UI** del selector se describe arriba en Â«Hilos de conversaciÃ³nÂ».
- **Auto-renombre**: el primer turno puede fijar tÃ­tulo vÃ­a `threadTitle` en el JSON de respuesta.
- **Renombrado manual** por diÃ¡logo.
- SubtÃ­tulo de contexto en cabecera: Â«pÃ¡gina actualÂ», Â«*N* pÃ¡ginasÂ», Â«desactivadoÂ».

### Sistema de prompt

- Prompt de sistema bilingÃ¼e (espaÃ±ol/inglÃ©s), seleccionado segÃºn locale.
- El asistente se identifica como "Quill".

### Bloques `task` en respuestas IA y herramientas Quill

- El pipeline de materializaciÃ³n (`vault_session_ai.dart`) acepta bloques `task` con `text` en JSON `FolioTaskData` o tÃ­tulo plano; normaliza tÃ­tulos vacÃ­os y serializa con `encode()`.
- **`QuillToolExecutor`** (`lib/services/ai/quill_tools.dart`): acciones **`insertTasksFromEncodedLines`**, **`insertTodosFromLines`** y **`translatePageBilingual`** (traducciÃ³n bilingÃ¼e: inserta cada bloque traducido justo despuÃ©s del original en la pÃ¡gina abierta, procesando de abajo a arriba para no desplazar Ã­ndices).
- **TraducciÃ³n bilingÃ¼e en chat**: si el usuario pide traducir la pÃ¡gina actual e insertar en el mismo sitio (p. ej. Â«traduce esta pÃ¡gina e insÃ©rtalo en la mismaÂ»), Quill detecta la intenciÃ³n (`AiIntentHints.translateBilingual`), evita `create_page` y ejecuta el atajo `translatePageBilinguallyWithAi` antes del agente JSON genÃ©rico. El comando slash `/ai translate` sin selecciÃ³n ni texto en el bloque dispara el mismo modo bilingÃ¼e sobre la pÃ¡gina abierta.
- Comandos slash de IA (`workspace_page_ai_slash.dart`): prompts orientados a extraer *action items* como bloques `task` (JSON en `text` o campo `title`) o `todo` cuando basta una lista simple, con aplicaciÃ³n sobre la pÃ¡gina abierta cuando el modo lo permite.

---

## 24. Contexto IA con `@`

`lib/features/workspace/shell/workspace_page_ai_context.dart`

El usuario puede aÃ±adir contexto al chat IA usando el menÃº `@` en el campo de entrada. Las menciones de pÃ¡gina muestran la etiqueta de transparencia: **Â«MenciÃ³n de IA â€“ analiza contenido de esta pÃ¡ginaÂ»**.

| Ãtem de contexto | DescripciÃ³n |
|---|---|
| `currentPage` | Contenido completo de la pÃ¡gina abierta |
| `page` | PÃ¡ginas especÃ­ficas de la libreta (con sub-filtrado por tÃ­tulo) |
| `meetingNote` | Nota de reuniÃ³n (si estÃ¡ disponible en la pÃ¡gina) |
| `addFile` | Adjuntar archivo del disco |

---

## 24.1 Copias en NAS / servidor externo

Copias cifradas hacia destinos de red **sin depender de Folio Cloud**. Escritorio (Windows prioritario); no disponible en web.

- **Copia programada automÃ¡tica**: pack **incremental** (mismo formato conceptual que el cloud-pack: blobs content-addressed + snapshot cifrado) en carpeta/UNC y/o WebDAV bajo `folio-packs/<vaultId>/`.
- **ExportaciÃ³n manual** y ZIPs legacy (`folio-scheduled-*` / `folio-backup-*`): siguen siendo ZIP completos.

### Destinos

| Destino | Protocolo | Credenciales |
|---------|-----------|--------------|
| **Carpeta de red** | SMB/UNC o unidad montada (`\\nas\share`, `Z:\backups`) | Usuario, contraseÃ±a y dominio opcionales (`WNetAddConnection2` en Windows) |
| **WebDAV** | HTTP(S) WebDAV (`webdav_client`) | Usuario y contraseÃ±a (Basic auth); contraseÃ±a en `flutter_secure_storage` |

Ambos pueden combinarse con la copia programada en **Folio Cloud** (suscripciÃ³n).

### ConfiguraciÃ³n (Ajustes â€º Libreta)

- **Destino NAS o servidor** (carpeta de red y WebDAV): siempre visible; no requiere activar la copia programada. Sirve para restaurar, exportar manualmente o, si lo activas, incluir en copias automÃ¡ticas.
- **Copia cifrada programada**: interruptor aparte con intervalo y destinos activos en cada ejecuciÃ³n.
- **Intervalo**: Â«En cada cambioÂ» (debounce ~45 s tras persistir en disco) o 30 minâ€¦24 h. El modo continuo reutiliza el mismo runner pack/cloud; el timer de 15 min solo aplica a intervalos fijos.
- **Configurar carpeta de red** / **Configurar WebDAV**: diÃ¡logo con credenciales y probar conexiÃ³n (visible sin copia programada).
- **Copias a conservar** (`retentionCount`): nÃºmero de snapshots pack retenidos (y GC de blobs no referenciados). Los ZIP legacy no se generan en el ciclo automÃ¡tico.
- **Restaurar desde NAS o servidor**: listar packs incrementales (`folio-packs/â€¦`) y ZIP `folio-scheduled-*` / `folio-backup-*`; importar como libreta nueva o sobrescribir la activa.
- ExportaciÃ³n manual: elegir archivo local (ZIP), carpeta/NAS o WebDAV si estÃ¡n configurados.

### ImplementaciÃ³n

- Pack local/WebDAV: `lib/services/vault_pack/` (`VaultPackTransport`, `FolderVaultPackTransport`, `WebDavVaultPackTransport`, `uploadOpenVaultPack`).
- Builder compartido con Folio Cloud: `vault_pack_builder.dart` (usado tambiÃ©n por `folio_cloud_pack_sync.dart`).
- Destinos ZIP (manual/legacy): `lib/services/backup_destinations/` (`BackupDestination`, `LocalFolderDestination`, `WebDavDestination`, `BackupExportRunner`).
- Credenciales: `lib/services/secure_credential_storage.dart`.
- SMB Windows: MethodChannel `folio/smb_network` (`windows/runner/smb_network_plugin.cpp`).
- OrquestaciÃ³n programada/continua: `lib/services/vault_scheduled_local_export.dart` + hook `onPersisted` en `folio_app.dart`.
- UI: `lib/features/settings/remote_backup_config_dialog.dart`, `remote_backup_restore_dialog.dart`.

### Ugreen NAS (orientativo)

1. Activar **SMB** y/o **WebDAV** en el panel del NAS.
2. Crear usuario con permiso de escritura en la carpeta de destino.
3. WebDAV: puertos habituales **5005** (HTTP) / **5006** (HTTPS).
4. En Windows, para copias programadas sin unidad montada: ruta UNC + credenciales en Folio.

---

## 25. Folio Cloud

Capa **opcional** en la nube (Firebase + Stripe y/o Microsoft Store). El nÃºcleo de la app â€”caja fuerte, editor, sincronizaciÃ³n local entre dispositivos, IA localâ€” funciona **sin** Folio Cloud; si Firebase no arranca o no hay proyecto configurado, estas rutas quedan deshabilitadas. Resumen orientado a producto: [README.md](../README.md) (Â«Building without Folio CloudÂ»); despliegue y secretos: [FOLIO_CLOUD_SECRETS.md](FOLIO_CLOUD_SECRETS.md).

### Entorno staging (no producciÃ³n)

- Proyecto Firebase **`folio-staging-minealex`** (alias `staging` en `.firebaserc`). ProducciÃ³n sigue siendo `folio-minealexgames`.
- Deploy backend a staging: `npm run deploy:staging:backend` desde `functions/` (Functions + reglas Firestore/Storage). ProducciÃ³n: `npm run deploy:production`.
- Cliente de prueba: `flutter run --dart-define=FOLIO_FIREBASE_ENV=staging` (usa [`lib/firebase_options_staging.dart`](../lib/firebase_options_staging.dart)).
- GuÃ­a: [FOLIO_CLOUD_STAGING.md](FOLIO_CLOUD_STAGING.md).

### Cuenta y autoridad en servidor

- **SesiÃ³n Folio Cloud** = usuario **Firebase Auth**.
- Estado de plan, tinta y flags de funciones viven en Firestore `users/{uid}`; el cliente **no** es confiable: escritura de `folioCloud`, `ink` y campos de facturaciÃ³n vÃ­a **Admin SDK** en Cloud Functions y webhooks. Detalle: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).

### GestiÃ³n de cuenta (borrado, datos, Ajustes)

- **Ajustes â†’ Folio Cloud** usa subsections planas (mismo patrÃ³n que Libreta): **Cuenta**, **Plan**, **Tinta**, **Copias**, **Familia**, **PublicaciÃ³n**, **Zona peligrosa**. Packs de tinta/almacenamiento y el portal web van a sheets/diÃ¡logos (no cards apiladas en el scroll).
- **Nombre visible**: editable en Cuenta (`updateAccountDisplayName`) â€” actualiza Firebase Auth, `users/{uid}.displayName` y, si aplica, `families/*/membersInfo`.
- **Descargar mis datos** (`exportAccountData`): JSON de metadatos de cuenta (perfil, plan, tinta, cuota, familia, Ã­ndices de copias, publicados, collab). **No** incluye el contenido cifrado de libretas locales.
- **Eliminar cuenta** (`requestAccountDeletion`): reauth + agenda borrado en **30 dÃ­as** (`users/{uid}.accountDeletion.scheduledFor`). Durante la gracia el acceso y la suscripciÃ³n siguen activos; se puede **cancelar** (`cancelAccountDeletion`). Los checkouts nuevos quedan bloqueados.
- Job diario **`processScheduledAccountDeletions`**: purga Stripe (cancela suscripciones + customer), Storage/Firestore ligados al uid, familia/collab/Ã­ndices, y borra el usuario Auth. **`onUserDeleted`** repite la purga como red de seguridad.
- Las **libretas locales del dispositivo no se tocan** al borrar o cerrar sesiÃ³n Cloud.

### Entitlements (`folioCloud.features`)

El webhook de Stripe (y la recomputaciÃ³n tras Microsoft Store) rellena banderas que la app y las reglas usan como contrato. **Toda cuenta Firebase** recibe ademÃ¡s un **plan free** (`folioCloud.plan = "free"`) sin suscripciÃ³n de pago:

| Plan | `plan` | Cuota copias | Features | Tinta mensual |
|------|--------|--------------|----------|---------------|
| Gratuito (cuenta) | `free` | **500 MiB** | `backup` (+ sync multi-dispositivo); sin `cloudAi` / `publishWeb` / `realtimeCollab` | **0** |
| Folio Cloud de pago | `cloud` | 5 GiB (15 GiB estudiante) + extras Â«BibliotecaÂ» | segÃºn precio | 500 (1000 estudiante) |

Al suscribirse, los 500 MiB se **sustituyen** por la cuota del plan de pago (no se suman).

| Flag | Rol |
|------|-----|
| `backup` | Copias ZIP **cifradas** en Storage bajo `users/{uid}/backups/**` y **sync multi-dispositivo** (packs en `device-sync/`) |
| `cloudAi` | IA hospedada en Cloud Functions (claves del proveedor solo en servidor); consumo con **Ink** |
| `publishWeb` | HTML pÃºblico en `published/{uid}/**` + Ã­ndice Firestore `publishedPages` |
| `realtimeCollab` | ColaboraciÃ³n en vivo (salas Firestore, subida de medios colaborativos) cuando el plan lo incluye |

ImplementaciÃ³n cliente: `lib/services/folio_cloud/folio_cloud_entitlements.dart` (`canUseCloudBackup`, `isFreePlan`, `isPaidPlan`, `canUseCloudAi`, `canPublishToWeb`, `canRealtimeCollab`, etc.).

### SincronizaciÃ³n multi-dispositivo (casi en tiempo real)

Distinta de la **copia/restauraciÃ³n** (reemplazo consciente): la sync automÃ¡tica **siempre hace merge** con el mismo motor que P2P.

- Cliente: `lib/services/folio_cloud/folio_cloud_device_sync.dart` (`FolioCloudDeviceSyncController`) + transporte incremental `folio_cloud_device_sync_incremental.dart`.
- Tras persistir y **~10 s sin nuevos guardados** (idle de ediciÃ³n), sube **blobs content-addressed** (payload + adjuntos) a `users/{uid}/vaults/{vaultId}/device-sync/blobs/` y un **manifiesto cifrado** en `device-sync/manifests/`; finaliza con **`folioFinalizeDeviceSync`** (`syncFormatVersion: 2`, seÃ±al en Firestore `users/{uid}/vaultSync/{vaultId}`). Compat: packs monolÃ­ticos v1 en `device-sync/packs/` se siguen pudiendo **descargar**; el siguiente push migra a v2.
- Indicador unificado en el workspace (una sola nube): **guardado local** + **sync Folio Cloud**. Al pulsarlo, sheet con estado en este dispositivo, todas las libretas, error, progreso por blobs, **Sincronizar ahora** (`syncNow()`), y conflictos pendientes. El nombre visible de cada libreta viaja en el pack (`VaultPayload.displayName`) y se aplica al registro local tras el merge.
- **No exige libreta desbloqueada** para sincronizar: con la UI en bloqueo se usa sync **headless** sobre disco (`HeadlessDeviceSyncVault` vÃ­a `VaultStorage`, tambiÃ©n en web). En formato **v1** el headless lee/escribe el Ã¡rbol `repo/` (canÃ³nico); **no** usa `vault.bin` residual (quedarÃ­a obsoleto tras migrar/editar y provocarÃ­a que un dispositivo bloqueado empujara un snapshot viejo). La DEK (o clave estable de vault en claro) se cachea en almacÃ©n seguro tras el primer desbloqueo / al bloquear (`DeviceSyncKeyCache`); las libretas en claro usan clave determinista por cuenta+vaultId. **Pull** de la libreta activa cada **~30 s** en primer plano (listener Firestore o poll); **todas las libretas** cada **~15 min**. En segundo plano (app pausada **o ventana sin foco** en desktop) se pausa el poll y el listener; al volver a ser la ventana activa / resumed, pull inmediato de la activa. Al cambiar de libreta activa, **push inmediato** de la que se abandona (aÃºn desbloqueada) y **pull inmediato** de la nueva. El **push** normal espera **~10 s de inactividad** tras el Ãºltimo guardado local (el usuario dejÃ³ de editar); al cambiar de pÃ¡gina, si habÃ­a push pendiente, se hace flush.
- Cifrado del **pack en la nube** con la clave de perfil de cuenta Folio Cloud (todos los dispositivos firmados pueden bajarlo). La DEK de cada libreta viaja en `dekAccountWrapB64` / `dek.accountwrap` para materializar sin desbloquear. Compat: packs antiguos cifrados con DEK de libreta se siguen pudiendo leer si hay clave local o wrap.
- Al desbloquear/cachear DEK se sube el bootstrap de inmediato (no espera al debounce del push).
- Otros dispositivos escuchan el doc (`snapshots`) en primer plano o, en **Windows** (sin Firestore nativo), hacen **polling REST ~30 s** de la activa solo en primer plano; tras un push propio hay burst 1/2/4 s. Linux/macOS/mÃ³vil usan snapshots.
- Conflictos de bloque: se conserva lo local; lo remoto va a revisiones `sync_remote_*` (historial de pÃ¡gina + banner en el editor). ResoluciÃ³n con merge por hunks desde el chip de sync, banner del editor, Home o **Ajustes â†’ Folio Cloud** / SincronizaciÃ³n (P2P); cola persistente por libreta y mismo contador `syncPendingConflicts`.
- Toggle en Ajustes â†’ Folio Cloud: `AppSettings.cloudDeviceSyncEnabled` (requiere `canUseCloudBackup`).
- Callables: `folioGetDeviceSyncMeta`, `folioFinalizeDeviceSync` (v1 pack o v2 manifiesto + `newBlobs`/`deleteBlobs`). Al finalizar, `oldPackStoragePath` / `oldManifestStoragePath` invÃ¡lidos o de otra libreta se **ignoran** (no fallan el push); el cliente solo envÃ­a rutas que pertenecen al `vaultId` actual (evita el error al sincronizar una libreta reciÃ©n creada en la web tras otra activa). Antes de omitir la subida de un blob por cachÃ©, **comprueba que exista** en Storage; si falta, lo re-sube. No borra blobs obsoletos al instante (evita 404 en pulls concurrentes); ante pull 404 repara con push local.

### Perfil de ajustes (cuenta + libreta)

Backup cifrado de **preferencias** (no del contenido de la libreta), separado en dos capas:

| Capa | Alcance | Storage / Firestore |
|------|---------|---------------------|
| **Perfil de app** | Tema, IA, atajos, iconos custom, layout, telemetrÃ­a, integracionesâ€¦ | `users/{uid}/app-profile/` + `users/{uid}/appProfile/meta` |
| **Perfil por libreta** | Copias programadas, onboarding home, contraseÃ±as de backup (en ciphertext) | `users/{uid}/vault-profiles/{vaultId}/` + `users/{uid}/vaultProfiles/{vaultId}` |

- Cliente: `lib/services/folio_cloud/folio_cloud_settings_sync.dart` (`FolioCloudSettingsSyncController`), formato `lib/data/folio_settings_profile_format.dart`, builder/applier en `lib/services/settings/`.
- Pack AES-GCM (mismo patrÃ³n que cloud-pack); clave de perfil de app independiente del vault; iconos custom como blobs en `app-profile/icons/{iconId}`.
- **Clave canÃ³nica de cuenta**: al push/pull se prioriza el `restoreWrapB64` del servidor sobre la cachÃ© local (evita packs cifrados con clave huÃ©rfana tras carreras multi-dispositivo). Si el MAC falla tras adoptar el wrap, se corta el auto-reintento y se ofrece el diÃ¡logo restaurar / empezar de nuevo; Â«empezar de nuevoÂ» (`keepLocalAndPush`) **reescribe** pack + wrap alineados.
- Excluye estado local al dispositivo (`syncDeviceId`, `syncLastSuccessMs`, `syncPendingConflicts`, `lockScreenAutoQuickUnlockDone`).
- Toggle `AppSettings.cloudAppProfileSyncEnabled`; al detectar perfil remoto tras login: diÃ¡logo restaurar / empezar de nuevo **solo si el fingerprint/`updatedAt` remoto no coinciden con el Ãºltimo perfil ya reconocido en este dispositivo** (persistido en prefs); si el local ya coincide con la nube, no se pregunta. Ajustes â†’ Folio Cloud (subir/restaurar) y Ajustes â†’ Libreta (restaurar prefs de la libreta).
- Callables: `folioGetAppProfileMeta`, `folioGetAppProfileRestoreWrap`, `folioFinalizeAppProfile`, `folioGetVaultProfileMeta`, `folioFinalizeVaultProfile` (cuota `folioBackup.usedBytes`, entitlement `canUseCloudBackup`).

### Copia cifrada en la nube

- Subida manual y **gestiÃ³n** (listar / importar / descargar legacy / borrar) desde Ajustes en un panel tipo papelera; **restauraciÃ³n** tambiÃ©n desde onboarding o flujos de copia.
- Se pueden borrar tanto archivos **legacy** (ZIP/TAR.GZ) como la copia **incremental** (cloud-pack) de una libreta. El borrado del cloud-pack usa **`folioDeleteVaultCloudPack`**; el legacy, **`folioDeleteVaultLegacyBackup`**. Si tras borrar no queda ninguna copia, se **elimina por completo** la presencia de esa libreta en Folio Cloud (Storage bajo `vaults/{vaultId}/`, Ã­ndice `vaultBackupIndex` y meta `vaultBackups`).
- Tras un **backup programado** (intervalo o Â«en cada cambioÂ»), si el usuario activa Â«tambiÃ©n subir a Folio CloudÂ» y tiene permiso, se sube un **cloud-pack** incremental (`uploadOpenVaultCloudPack` / Ã­ndices en servidor). La copia local/WebDAV del mismo ciclo usa el pack incremental bajo `folio-packs/` (no un ZIP nuevo). El envoltorio de recuperaciÃ³n del cloud-pack se toma de `vault.keys` (libreta cifrada) o se genera automÃ¡ticamente (libreta en claro); **no se pide contraseÃ±a** en la copia programada ni en la sync.
- En **Windows/Linux**, el SDK a veces no lista bien Storage; la app usa la callable **`folioListVaultBackups`** (lista con Admin SDK en servidor).
- Subidas (`putData`/`putFile`) y descargas (`getData`/`writeToFile`) en escritorio van por REST autenticada con ID token, evitando los canales `taskEvent` del plugin C++.
- **`folioListBackupVaults`** solo incluye libretas con copias reales (`backups/` legacy o `cloud-packs/` / meta de cloud-pack); **no** lista las que solo tienen sync multi-dispositivo (`device-sync/`), que va por separado.
- **Cuota de almacenamiento** de copias: **500 MiB** en plan free; con suscripciÃ³n base **5 GiB** (estudiante **15 GiB**) y ampliaciones (Â«BibliotecaÂ» pequeÃ±a/mediana/grande). CatÃ¡logo en [FOLIO_CLOUD_STRIPE_PRODUCTS.md](FOLIO_CLOUD_STRIPE_PRODUCTS.md); callables de apoyo p. ej. `folioGetBackupStorageUsage`, `folioTrimVaultBackups`, `folioTrimVaultBackupsByBytes`, Ã­ndice multi-libreta (`folioListBackupVaults`, `folioUpsertVaultBackupIndex`, â€¦).
- **Importar todas al iniciar sesiÃ³n** (onboarding Â«desde Folio CloudÂ» o Ajustes â†’ cuenta): aviso, descarga e importa todas las libretas con cloud-pack conservando el `vaultId` remoto. Si la libreta local estÃ¡ vacÃ­a, la primera ocupa ese slot; si tiene contenido, se conserva y todas se aÃ±aden. La contraseÃ±a de la **cuenta** se usa solo como `restorePassword` del envoltorio; el desbloqueo habitual sigue siendo la master de cada libreta. Fallback: pedir master de esa libreta si no coincide. Cliente: `folio_cloud_import_all_vaults.dart` + `folio_cloud_import_all_dialog.dart`. La descarga va a memoria (`ExtractedVaultBackup` / `downloadCloudPackToMemoryForRestore`) para funcionar tambiÃ©n en web.
- **Multi-libreta en web**: IndexedDB admite varias libretas; `prepareNewVault` / cambiar libreta / `importCloudVaultAsLocalFromMemory` e importar-todas desde Folio Cloud no dependen de `Directory` nativo. El import ZIP local y Notion siguen siendo solo escritorio (aviso en onboarding web).

### IA en la nube

- Cliente: `lib/services/ai/folio_cloud_ai_service.dart` (`FolioCloudAiService`).
- Callable **`folioCloudAiComplete`** (Firebase Functions **1st gen**); fallback HTTP **`folioCloudAiCompleteHttp`** cuando el protocolo callable en escritorio devuelve 401 HTML (perÃ­metro/IAM). Tabla de costes por `operationKind` (~3Ã— respecto a la era GPT-4o-mini, alineada a GPT-5.4-mini), suplementos por tamaÃ±o y tokens: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).
- Uso permitido con **suscripciÃ³n activa que incluya `cloudAi`** o con **tinta comprada** sin suscripciÃ³n (reglas documentadas en backend).
- **`folioCloudAiPricing`**: expone al cliente precios/costes de referencia (gotas por operaciÃ³n).
- **`folioCloudCatalogPrices`**: importes Stripe (`unit_amount` + `currency`) del catÃ¡logo (tinta, suscripciÃ³n, librerÃ­as) para la UI; la app formatea con locale y ya no hardcodea euros en l10n.
- **`folioCloudTranscribeChunk`**: transcripciÃ³n por chunks (modelo `OPENAI_TRANSCRIBE_MODEL`, default `gpt-4o-transcribe`; coste base `transcribe_cloud` = 2 gotas).

### PublicaciÃ³n web

- Exportar la pÃ¡gina actual a HTML y publicar: `lib/services/folio_cloud/folio_cloud_publish.dart` (`publishHtmlPage`); UI y slug en `lib/features/workspace/shell/workspace_page_page_tools.dart` (**slug** vÃ­a `_showPublishWebSlugMenu`).
- **Modo Spring** (`FolioBackendConfig.useSpring`): sube HTML con `folioSpringStoragePutData` a `published/{uid}/{slug}.html` (`folioCloudCurrentUid`) y registra/actualiza el Ã­ndice con `POST`/`PUT /api/v1/published-pages` (`storagePath`); listado `GET â€¦/mine`; borrado `DELETE â€¦/{id}` (el servidor elimina el objeto). Sin Firestore; usable en Windows. Modo Firebase sin cambios (`publishedPages` + Storage download URL).

### Compartir libreta completa

- **Enlace pÃºblico vivo** (solo lectura en el navegador): API `/api/v1/vault-shares/public/**`; la URL que se copia/comparte es **`/s/{token}`** en la app web â€” **`https://folio.com.es`** (prod) o **`https://beta.folio.com.es`** (si la sesiÃ³n web corre en beta, o con `--dart-define=FOLIO_WEB_BASE_URL=â€¦`). La ruta monta la **misma app** (`BlockEditor` + Ã¡rbol de pÃ¡ginas en solo lectura), no un HTML aparte. Poll meta/content. Gate `publishWeb`. Aviso en UI: el contenido del enlace estÃ¡ en claro en el servidor.
- **Invitar persona (editor)**: `/api/v1/vault-shares/members/**`. Correo + cÃ³digo E2E (`VaultShareCrypto`). Aparece en el listado del sidebar como Â«Compartidas conmigoÂ»; **no puede eliminar** la libreta (solo abandonar). Sync vÃ­a device-sync del owner (`ownerUid` en meta/finalize + ACL storage).
- Cliente: `folio_cloud_vault_share.dart`, `folio_web_urls.dart` (prod + foliobeta), `vault_share_sheet.dart`, rutas web `PublicVaultSharePage` / reset / verify, `VaultEntry.ownership`, gates en `deleteVaultById` / `wipeVaultAndReset`.

### Cliente web (Vercel / dominios MineAlex)

- Build estÃ¡tico Flutter web desplegado en Vercel (`vercel.json`, `vercel-build.sh`); hosts canÃ³nicos: **https://beta.folio.com.es** (beta) y **https://folio.com.es** (producciÃ³n). Las rutas pÃºblicas (`/s/â€¦`, `/reset-password`, `/verify-email`) funcionan en ambos vÃ­a rewrite a `index.html`.
- Lecturas/escrituras de Firebase Storage desde el browser requieren CORS en el bucket (`storage-cors.json` â†’ `gs://folio-minealexgames.firebasestorage.app`). Incluye `*` para que `flutter run -d chrome` (`localhost:<puerto>`) no falle; las reglas Auth siguen protegiendo objetos. Detalle: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md) (Â«Storage CORSÂ»).
- Esos mismos hosts deben estar en Firebase Auth â†’ Authorized domains.
- Si Vercel **Deployment Protection** (SSO) estÃ¡ activo en Production, la app y `manifest.json` redirigen al login de Vercel; desactivar protecciÃ³n pÃºblica en beta/prod o limitarla a previews.
- **PWA instalable**: `web/manifest.json` (`display: standalone`, iconos 192/512 + maskable), meta tags iOS en `index.html`, service worker de Flutter (`flutter build web` sin `--pwa-strategy=none`). En la sidebar web: botÃ³n **Instalar Folio** (prompt nativo vÃ­a `beforeinstallprompt`, o guÃ­a manual en Safari/iOS). Headers en `vercel.json` para `manifest.json` y `flutter_service_worker.js`. La instalaciÃ³n completa requiere HTTPS (beta/prod); en local probar con `flutter run -d chrome --release`.
- **Sin buscador de actualizaciones** (`FolioDistribution.offersGitHubSelfUpdate == false` en web): la web se actualiza al redeploy; no hay Â«Buscar actualizacionesÂ» ni chequeo al arrancar.
- **IA como en mÃ³vil**: sin Ollama/LM Studio; Quill Cloud (y BYOK OpenAI/Gemini si se configura).

### FacturaciÃ³n

- **Stripe**: `createCheckoutSession`, `createBillingPortalSession`, webhook **`stripeWebhook`**; sincronizaciÃ³n manual **`syncFolioCloudSubscriptionFromStripe`** si hace falta.
- **Tarifa estudiante**: en Ajustes â†’ Folio Cloud se puede verificar un correo institucional (`verifyStudentStatus`) y contratar `folio_student_monthly` (cuota 15â€¯GiB, 1000 tinta/mes; sin familia). La elegibilidad es **solo por dominio** (no se demuestra posesiÃ³n del buzÃ³n):
  - CatÃ¡logo mundial de instituciones de educaciÃ³n superior [JetBrains/swot](https://github.com/JetBrains/swot) vÃ­a `swot-node`.
  - Overlay Folio de dominios regionales de educaciÃ³n no universitaria en EspaÃ±a (p. ej. `educa.jcyl.es`, `edu.gva.es`, `g.educaand.es`, `xtec.cat`, â€¦) para institutos/FP (prioridad sobre la lista `abused` de SWOT cuando coinciden).
  - Resto de dominios en la lista `abused` de SWOT se rechazan.
  - ImplementaciÃ³n: `functions/src/student_email.ts`; gate tambiÃ©n en checkout si el email de Auth ya califica.
- **Microsoft Store** (build MSIX): compras y suscripciÃ³n alineadas con el mismo modelo de productos; callable **`validateMicrosoftStoreEntitlements`** tras compra o Â«SincronizarÂ». Variables y Partner Center: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).
- Precios, tinteros y addons de almacenamiento: [FOLIO_CLOUD_STRIPE_PRODUCTS.md](FOLIO_CLOUD_STRIPE_PRODUCTS.md). Job programado **`monthlyInkRefill`** (recarga de gotas el dÃ­a 1 para suscriptores mensuales).

### TelemetrÃ­a

- Una copia detallada de eventos opcionales en Firestore **solo si hay sesiÃ³n** Folio Cloud (Firebase UID en la ruta). No sustituye Analytics con ID de instalaciÃ³n anÃ³nimo. Ver [TELEMETRY.md](TELEMETRY.md).

### Cliente Windows/Linux y callables

- Donde el plugin `cloud_functions` no es fiable, las callables se invocan por **HTTP** con `Authorization: Bearer` (ID token), misma URL que documenta Firebase: `lib/services/folio_cloud/folio_cloud_callable.dart`.

### Cloud Functions (`functions/src/index.ts`, referencia)

| Ãrea | Export(s) |
|------|-----------|
| ColaboraciÃ³n | `createCollabRoom`, `joinCollabRoomByCode`, `prepareCollabMediaUpload`, `commitCollabMediaUpload`, `inviteCollabMember`, `removeCollabMember`, `closeCollabRoom` |
| Pagos y cuenta | `createCheckoutSession`, `createBillingPortalSession`, `stripeWebhook`, `syncFolioCloudSubscriptionFromStripe`, `validateMicrosoftStoreEntitlements`, `folioCloudCatalogPrices` |
| Copias / vault / almacenamiento | `folioListVaultBackups`, `folioDeleteVaultCloudPack`, `folioDeleteVaultLegacyBackup`, `folioGetBackupStorageUsage`, `folioTrimVaultBackups`, `folioTrimVaultBackupsByBytes`, `folioListBackupVaults`, `folioUpsertVaultBackupIndex`, `folioGetLatestVaultBackupMeta`, `folioRecordVaultBackupMeta`, â€¦ |
| Cloud pack (metadatos/restore) | `folioGetLatestCloudPackMeta`, `folioGetCloudPackRestoreWrap`, `folioCheckCloudPackBlobsExist`, `folioFinalizeCloudPack`, `folioDeleteVaultCloudPack` |
| Sync multi-dispositivo | `folioGetDeviceSyncMeta`, `folioFinalizeDeviceSync`, `folioListDeviceSyncVaults` |
| IA | `folioCloudAiComplete`, `folioCloudAiCompleteHttp`, `folioCloudAiPricing`, `folioCloudTranscribeChunk` |
| Operaciones | `monthlyInkRefill` (programada) |
| Otras HTTP | `folioJiraExchangeOAuth`, `folioReportDiagnostic` (integraciÃ³n/diagnÃ³stico; no son el nÃºcleo Â«Folio CloudÂ» de suscripciÃ³n) |

### Nota: distribuciÃ³n Windows

- Los artefactos **MSIX** y el instalador (`installer.iss`, CI) son la **distribuciÃ³n de la aplicaciÃ³n**; la Microsoft Store actÃºa ademÃ¡s como **canal de pago** Folio Cloud en Windows. Los builds release suelen dejarse bajo `Output/` segÃºn el manifiesto.

---

## 26. Seguridad de libreta (Vault)

### Cifrado

- Cifrado opcional a nivel de libreta: `VaultCrypto`.
- Las claves se derivan de la contraseÃ±a maestra.

### AutenticaciÃ³n

- **ContraseÃ±a maestra**: campo con toggle mostrar/ocultar (`FolioPasswordField`).
- **Passkeys**: autenticaciÃ³n sin contraseÃ±a vÃ­a passkeys estÃ¡ndar (`passkeys_android`, `passkeys_doctor`).
- **Windows Hello**: autenticaciÃ³n biomÃ©trica / PIN en Windows (`local_auth_android` + Windows Hello integration).
- DiÃ¡logo de verificaciÃ³n de identidad reutilizable: `VaultIdentityVerifyDialog`.

### Bloqueo automÃ¡tico

- Pantalla de bloqueo (`lib/features/lock_screen/`).
- La libreta puede configurarse para bloquearse automÃ¡ticamente tras un tiempo de inactividad.

### Onboarding seguro

- Durante el onboarding se puede elegir cifrado + contraseÃ±a.

### RecuperaciÃ³n de una libreta vaciada por sync (2026-07-23) y anti-wipe del Ã¡rbol v1

- **Incidente:** en una libreta de usuario, la UI mostrÃ³ 0 folios pese a que `vault.bin.bak` conservaba ~30 pÃ¡ginas (p. ej. una pÃ¡gina de tareas con kanban). El sync headless tratÃ³ la libreta como vacÃ­a (`loadPayload empty` vÃ­a `vault.bin` obsoleto tras migrar a v1), instalÃ³ remoto y el cliente llegÃ³ a **pushear 0 pÃ¡ginas** a device-sync. Una instancia Debug abierta volviÃ³ a persistir `repo/tree.json = {}` tras una recuperaciÃ³n manual.
- **RecuperaciÃ³n:** restauraciÃ³n manual desde `vault.bin.bak` (sin borrar el `.bak`) recomponiendo el Ã¡rbol y regenerando snapshots por revisiÃ³n; copias congeladas aparte antes de aplicar.
- **Blindaje:** `VaultLocalStorage.decomposeAndStoreAt` rechaza sustituir un `repo/` con pÃ¡ginas por un payload vacÃ­o; `persistNow` (v1) no escribe sesiÃ³n vacÃ­a sobre Ã¡rbol no vacÃ­o; `HeadlessDeviceSyncVault.applyRemotePack` no instala remoto vacÃ­o ni pisa un Ã¡rbol local si `loadPayload` falla pero hay pÃ¡ginas en disco; `_formatVersion` infiere v1 si existe `repo/tree.json` aunque falte el marker.

### AuditorÃ­a de continuidad (2026-07-23) â€” huecos cerrados por rutas equivalentes

Tras el blindaje anterior (headless sync), una auditorÃ­a de todos los caminos equivalentes
encontrÃ³ que **el mismo incidente era reproducible por otras dos rutas** que no tenÃ­an guard.
Se corrigieron en esta sesiÃ³n, cada una con test de regresiÃ³n (fallan sin el fix, pasan con Ã©l):

- **`VaultSession.applySyncSnapshotBytes`** (sync con sesiÃ³n desbloqueada / LAN P2P) y
  `resolveSyncConflictAcceptRemote`: no tenÃ­an el guard "remoto vacÃ­o sobre local no vacÃ­o"
  que sÃ­ tenÃ­a `HeadlessDeviceSyncVault.applyRemotePack`. Un pack remoto espuriamente vacÃ­o
  (manifiesto corrupto/incompleto, o un dispositivo con el bug antiguo) podÃ­a vaciar `_pages`
  en memoria de inmediato (antes de persistir); el guard de `persistNow` protegÃ­a el disco,
  pero el siguiente push automÃ¡tico serializaba la sesiÃ³n ya vacÃ­a y sobreescribÃ­a la copia
  buena en la nube. Ahora ambos mÃ©todos rechazan un remoto de 0 pÃ¡ginas cuando el local no
  estÃ¡ vacÃ­o, igual que el camino headless. Test: `test/session/vault_session_sync_guard_test.dart`.
- **`VaultSession.lock()` con libretas sin cifrar**: retornaba de inmediato
  (`if (!vaultUsesEncryption) return;`) sin vaciar el guardado v1 pendiente
  (`_v1TreeSaveTimer`, debounce 450 ms). Si el usuario cambiaba de libreta (`switchVault`)
  antes de que expirara ese debounce, el guardado pendiente de la libreta abandonada podÃ­a
  completarse despuÃ©s de que `VaultPaths` ya apuntara a la libreta nueva, escribiendo
  contenido de la libreta vieja dentro del Ã¡rbol de la nueva (contaminaciÃ³n cruzada). `lock()`
  ahora vacÃ­a siempre el guardado pendiente antes de decidir si hay mÃ¡s trabajo que hacer para
  libretas cifradas. Test: `test/session/vault_session_lock_flush_test.dart`.
- **AsimetrÃ­a headless vs sesiÃ³n UI en detecciÃ³n de formato**: `HeadlessDeviceSyncVault._formatVersion`
  ya caÃ­a a comprobar `repo/tree.json` si el marker `vault.format` faltaba; el camino de sesiÃ³n
  UI (`VaultMigrationTool.readTreeFormatVersion` / `VaultFormatHandler.detectFormat`) no lo
  hacÃ­a y podÃ­a tratar una libreta ya migrada como v0 tras un crash entre el swap atÃ³mico y la
  escritura del marker. Ahora ambos caminos comparten el mismo fallback. Test:
  `test/git/vault_migration_tool_test.dart` (grupo "marker vs tree.json").
- **`unlockWithDeviceAuth`/`unlockWithPasskey` sin manejo de `VaultCorruptionException`**:
  a diferencia de `unlockWithPassword`, no llevaban a `VaultFlowState.recovery` ante un Ã¡rbol
  v1 no verificable â€” la excepciÃ³n se propagaba sin capturar, dejando la DEK asignada sin
  transiciÃ³n de estado. Ahora los tres caminos de desbloqueo comparten el mismo manejo. Test
  ejecutado para `unlockWithDeviceAuth` (`test/session/vault_session_unlock_corruption_test.dart`);
  `unlockWithPasskey` recibiÃ³ el mismo cambio estructural pero no tiene test propio (requerirÃ­a
  simular la ceremonia WebAuthn completa).

### Segunda ronda (2026-07-23) â€” los 5 riesgos residuales, cerrados

Los cinco caminos que la primera ronda dejÃ³ documentados-pero-sin-fix se cerraron en una
sesiÃ³n posterior, cada uno con test de regresiÃ³n (fallan sin el fix, pasan con Ã©l salvo donde
se indica lo contrario):

- **Camino v0 sin guard**: `VaultRepository.savePayload` (nuevo `_existingV0PageCount`) y la
  rama `format < 1` de `HeadlessDeviceSyncVault.savePayload` ahora rechazan sustituir un
  `vault.bin` con pÃ¡ginas por un payload vacÃ­o, igual que `decomposeAndStoreAt` en v1 â€” best
  effort: si no se puede leer el contenido existente (corrupto, primera escritura), no bloquea.
  Tests: `test/data/vault_repository_empty_overwrite_test.dart`,
  `test/services/folio_cloud/headless_device_sync_vault_v0_guard_test.dart`.
- **Lectura de Ã¡rbol vacÃ­o como vÃ¡lida**: `VaultLocalStorage.loadFromTree()`/`loadFromTreeAt()`
  ahora comparan un resultado de 0 pÃ¡ginas contra el **Ãºltimo snapshot conocido** en
  `versions/` (vÃ­a su `fileManifest`, sin descomprimir el zip) â€” si ese snapshot tenÃ­a pÃ¡ginas,
  lanza `VaultCorruptionException` en vez de aceptar la libreta como vacÃ­a legÃ­tima. Una
  libreta genuinamente nueva (sin snapshots todavÃ­a) no dispara esto. Test:
  `test/git/vault_local_storage_test.dart` (grupo "loadFromTreeAt").
- **Import/restore de backup** (`vault_backup.dart` `applyImportToVaultRoot`): escritura
  atÃ³mica de `vault.bin`/`vault.keys`/`vault.mode` vÃ­a `AtomicFileWriter` (antes `File.copy`
  directo) y adjuntos por staging + swap (carpeta `.importing` â†’ rename, la anterior se
  renombra a `.pre-import` en vez de borrarse). AdemÃ¡s, **bug de correctness real**: el import
  no invalidaba `repo/`/`vault.format`/`vault.v1-verified`, asÃ­ que restaurar un backup sobre
  una libreta ya migrada a v1 no tenÃ­a ningÃºn efecto visible (el bootstrap seguÃ­a leyendo el
  Ã¡rbol viejo). Ahora `_invalidateStaleV1TreeAfterImport` renombra `repo/`â†’`repo.pre-import` y
  `versions/`â†’`versions.pre-import` (conservados, no borrados) y borra los markers, forzando
  una remigraciÃ³n desde el `vault.bin` reciÃ©n importado. Test:
  `test/data/vault_backup_import_test.dart`.
- **Backups programados/cloud-pack** (`vault_pack_sync.dart`, `folio_cloud_pack_sync.dart`,
  `folio_cloud_backup.dart`, `backup_export_runner.dart`): los cuatro rechazan ahora subir/
  exportar una libreta local vacÃ­a cuando el destino ya tiene contenido (fingerprint/meta
  previo en los tres primeros; `listZipBackups()` no vacÃ­o en el export runner). Test con
  transporte/destino falso ejecutado para `vault_pack_sync.dart`
  (`test/services/vault_pack/vault_pack_sync_empty_guard_test.dart`) y
  `backup_export_runner.dart` (`test/services/backup_destinations/backup_export_runner_empty_guard_test.dart`);
  `folio_cloud_pack_sync.dart`/`folio_cloud_backup.dart` reciben el mismo guard estructural sin
  test propio (requerirÃ­a mockear Firebase Storage/Functions).
- **`VaultSnapshotManager.restoreSnapshot`**: ya no borra el Ã¡rbol destino antes de repoblarlo.
  Ahora copia a una carpeta de staging en el mismo volumen (`repo.restore-tmp`) y solo hace el
  swap atÃ³mico (`repo` â†’ `repo.restore-old` â†’ borrar) si la copia completa tuvo Ã©xito; si falla
  a mitad, el Ã¡rbol destino queda intacto. Test:
  `test/git/vault_local_storage_test.dart` ("restoreSnapshot leaves targetTreeDir untouched...").

### ValidaciÃ³n end-to-end contra Firebase real (2026-07-23)

Todo lo anterior se habÃ­a verificado solo con `flutter test` (directorios temporales, sin red).
Para cerrar ese hueco (`folio-staging-minealex` no estÃ¡ aprovisionado: sin plan Blaze, sin
Cloud Functions habilitadas) se montÃ³ el **emulador local de Firebase** (Auth + Firestore +
Storage + Functions, proyecto demo `demo-folio-emulator-test`, config en `firebase.json` â†’
`emulators`) y se ejercitÃ³ el pipeline real de device-sync v2 (push/pull incremental por
blobs content-addressed + Cloud Function `folioFinalizeDeviceSync`/`folioGetDeviceSyncMeta`)
simulando dos dispositivos sobre la misma cuenta:

- `tool/verify_device_sync_against_emulator.dart` â€” script Dart plano (sin bindings de
  Flutter, porque `Firebase.initializeApp()` de los plugins no funciona bajo `flutter test`:
  falta el canal de plataforma) que habla directo por REST con los cuatro emuladores, usando
  el mismo cifrado y las mismas rutas que la app real. Uso: arrancar
  `firebase emulators:start --only auth,firestore,storage,functions --project demo-folio-emulator-test`
  (requiere Java 21+; el proyecto no viene con uno instalado por defecto) y luego
  `dart run tool/verify_device_sync_against_emulator.dart`.
- Escenario probado: dispositivo A sube 1 pÃ¡gina â†’ dispositivo B la descubre
  (`folioGetDeviceSyncMeta`) y descifra correctamente â†’ B edita y aÃ±ade una pÃ¡gina, sube â†’
  A vuelve a preguntar y descifra correctamente el contenido de B (2 pÃ¡ginas). Todas las
  comprobaciones pasan contra Auth/Firestore/Storage/Functions reales (emulados), no mocks.
- **Dos bugs reales encontrados y arreglados en el camino:**
  1. `folio_cloud_callable.dart` (`_callFolioHttpsViaHttp`, camino Windows/Linux â€” el Ãºnico que
     usa protocolo HTTP directo porque `cloud_functions` no tiene implementaciÃ³n nativa ahÃ­):
     leÃ­a `DefaultFirebaseOptions.currentPlatform.projectId` (siempre producciÃ³n) en vez de
     `Firebase.app().options.projectId` â€” con `FOLIO_FIREBASE_ENV=staging` en Windows, **todas**
     las callables apuntaban silenciosamente a producciÃ³n en vez de a staging. Ahora usa el
     proyecto con el que de verdad se inicializÃ³ Firebase, y admite redirigir al emulador vÃ­a
     `FolioCloudFunctionsEmulator.hostAndPort` (solo para tests, nunca activo en la app
     empaquetada).
  2. `functions/src/index.ts`: `const FieldValue = admin.firestore.FieldValue;` (import estilo
     namespace) se resolvÃ­a a `undefined` en el runtime del emulador de Functions, rompiendo
     `folioFinalizeDeviceSync` (y, al ser una constante compartida, potencialmente cualquier
     otra funciÃ³n que escribe en Firestore). Corregido usando el import modular
     `import { FieldValue } from "firebase-admin/firestore"`. No confirmado si esto tambiÃ©n
     ocurrÃ­a en producciÃ³n real (no se pudo probar sin aprovisionar staging), pero el fix es
     el patrÃ³n recomendado por Firebase y no tiene downside.

### Incidente real en producciÃ³n (2026-07-23): contaminaciÃ³n cruzada entre libretas

Justo despuÃ©s de la sesiÃ³n anterior, `switchVault()` (botÃ³n de cambiar de libreta en la
barra lateral) provocÃ³ un crash real (`PathNotFoundException` al renombrar
`repo.tmp/pages/.../blocks.jsonl.tmp`) **y contaminaciÃ³n cruzada de verdad**: el contenido
de "Libreta 1" (sin cifrar) quedÃ³ escrito encima del Ã¡rbol de otra libreta cifrada,
sustituyendo su contenido real.

- **Causa raÃ­z confirmada:** `VaultSession.persistNow()` (formato v1) no tenÃ­a ningÃºn mutex,
  a diferencia de `VaultPersistenceController._activeWrite` en v0. El debounce de guardado
  (`_v1TreeSaveTimer`, 450 ms) dispara `unawaited(persistNow())` â€” si ese timer ya se habÃ­a
  disparado (la llamada estaba "en vuelo", sin que nadie la esperara) justo cuando el usuario
  cambiaba de libreta, `lock()`/`flushPendingSave()` solo cancelaban el timer (no-op si ya
  disparÃ³) y lanzaban **una segunda llamada `persistNow()` concurrente**. Dos consecuencias:
  1. Ambas llamadas podÃ­an pisarse escribiendo/borrando `repo.tmp` a la vez â†’ el crash
     (`Cannot rename ... blocks.jsonl.tmp`, archivo borrado por la otra llamada a mitad).
  2. Peor: la llamada suelta original, al resolver `VaultPaths.vaultDirectory()` de forma
     perezosa, podÃ­a hacerlo **despuÃ©s** de que `switchVault()` ya hubiera cambiado
     `VaultPaths.activeVaultId` a la libreta nueva â€” escribiendo el payload de la libreta
     vieja (todavÃ­a en memoria) dentro del directorio de la libreta nueva. Esto es
     precisamente lo que pasÃ³: el contenido de "Libreta 1" reemplazÃ³ el Ã¡rbol real de la
     otra libreta.
- **RecuperaciÃ³n aplicada:** se restaurÃ³ la libreta afectada desde su Ãºltimo snapshot local
  (`VaultSnapshotManager.restoreSnapshot`, ya con el swap atÃ³mico arreglado en esta misma
  sesiÃ³n) tras congelar copias de ambas carpetas de libreta. Se perdieron las ediciones
  hechas ese mismo dÃ­a despuÃ©s del snapshot (pÃ¡ginas borradas ese dÃ­a reaparecieron); no se
  perdiÃ³ contenido de fondo.
- **Blindaje:** `VaultSession._v1ActiveWrite` â€” mutex real (mismo patrÃ³n que
  `VaultPersistenceController`): cualquier llamador a `persistNow()` (incluida una llamada
  suelta previa) debe esperar su turno. Como `lock()`/`flushPendingSave()` tambiÃ©n pasan por
  este mutex, `switchVault()` ya no puede cambiar `VaultPaths.activeVaultId` mientras quede
  un guardado v1 de verdad en vuelo â€” cierra tanto el crash de `repo.tmp` como la
  contaminaciÃ³n cruzada. Tests (fallan sin el fix, reproduciendo el mismo
  `PathAccessException` visto en producciÃ³n, pasan con Ã©l):
  `test/session/vault_session_persist_mutex_test.dart`.

---

## 27. ImportaciÃ³n de contenido

| Fuente | Detalles |
|---|---|
| **Notion** | ZIP exportado desde Notion; parser en `lib/data/` |
| **HTML** | HTML simple; conversiÃ³n a bloques Folio |
| **Markdown** | Pegado de texto multilÃ­nea con sintaxis MD â†’ bloques (`_pasteMarkdownAsBlocks` / `FolioMarkdownCodec.parseBlocks`) |

---

## 28. ExportaciÃ³n de contenido

Desde el panel de herramientas de pÃ¡gina (`workspace_page_page_tools.dart`):

| Formato | ExtensiÃ³n |
|---|---|
| Markdown | `.md` |
| HTML | `.html` |
| Texto plano | `.txt` |
| PDF | `.pdf` (vÃ­a `printing`) |

---

## 29. IntegraciÃ³n con Jira

Implementada en `lib/services/jira/` (3 ficheros: `jira_auth_service.dart`, `jira_api_client.dart`, `jira_sync_service.dart`).

### AutenticaciÃ³n

- OAuth 2.0 (3LO) con PKCE contra Atlassian Cloud.
- Client ID oficial de Folio: `7HEIa3N2dGmMWWscFmYnjGRLNSjzg8hI`.
- Loopback OAuth en puerto fijo `45747` (redirect URI registrado en Atlassian).
- `JiraAuthCancelToken`: permite cancelar el flujo de autenticaciÃ³n en curso.
- Override de Client ID configurable en Ajustes para desarrollo/testing.

### SincronizaciÃ³n

- ObtenciÃ³n de issues/tareas desde Jira Cloud (`jira_api_client.dart`).
- SincronizaciÃ³n bidireccional de tareas (`jira_sync_service.dart`).
- Estado persistido en `JiraIntegrationState` (`lib/models/jira_integration_state.dart`).

---

## 30. BÃºsqueda global

- Atajo por defecto: `Ctrl+K`.
- Busca en todos los tÃ­tulos y contenidos de pÃ¡ginas de la libreta.
- NavegaciÃ³n por resultados con teclado.

---

## 31. Captura rÃ¡pida de tarea

- Atajo por defecto: `Ctrl+Shift+T` (tambiÃ©n desde el sidebar).
- Flujo unificado con el detalle de tarea: se crea un **borrador** en la pÃ¡gina Kanban destino y se abre el panel/sheet `task_details_panel.dart` (el mismo que al editar una tarjeta). Si hay varios tableros Kanban, primero se elige la pÃ¡gina destino.
- El parser NLP **`TaskQuickCaptureParser`** (`lib/services/tasks/task_quick_capture_parser.dart`) sigue disponible en el cÃ³digo (fechas relativas, prioridad, estado, `#etiquetas`, alias de pÃ¡gina) para usos futuros; ya no es el diÃ¡logo principal de captura.
- Servicios en `lib/services/tasks/`: recordatorios, notificaciones de escritorio (ver abajo), tests del parser y de recurrencia.

### Recordatorios y notificaciones

- **`TaskReminderService`** (`task_reminder_service.dart`): recorre bloques `task`, comprueba `reminderEnabled` y fechas de vencimiento; emite eventos para tareas **vencidas** o **con vencimiento hoy** (intervalo configurable, p. ej. cada hora).
- En **`FolioApp`** esos eventos se traducen en **notificaciones nativas** vÃ­a **`PlatformNotificationService`** (`platform_notification_service.dart`, `local_notifier`) en **Windows, macOS y Linux**, si el usuario activÃ³ las notificaciones en ajustes (`windowsNotificationsEnabled` en `AppSettings`; el nombre histÃ³rico cubre el toggle de escritorio). En **web** (y mÃ³vil sin plugin adicional) el servicio de bandeja no aplica; la lÃ³gica de detecciÃ³n sigue siendo reutilizable.
- **`advanceRecurrence`**: al completar ciclos, puede calcular la siguiente `dueDate` a partir de `recurrence` o de un `recurringRule` con prefijo `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`.

---

## 32. Temas y apariencia

### Modo de tema

- Sistema / Claro / Oscuro / OLED (`FolioThemeMode`), configurable en `AppSettings.themeMode`.
- **OLED** es un modo de primer nivel (no un toggle aparte): fuerza superficies en negro puro; el acento (marca Folio o seed) se conserva.
- MigraciÃ³n: el antiguo `oledThemeEnabled` + tema oscuro/sistema se convierte a `FolioThemeMode.oled` al cargar.

### Color de acento (`FolioAccentColorMode`)

| Modo | DescripciÃ³n |
|---|---|
| `followSystem` | Usa el color dinÃ¡mico del SO (Material You) vÃ­a `ColorScheme.fromSeed` |
| `folioDefault` | Paleta de marca Folio (Minealex): `ColorScheme` explÃ­cito claro/oscuro en `lib/app/folio_brand_palette.dart` (cyan neÃ³n `#00F3FF`, magenta, lima, superficies Deep Space Blue); no se deriva de un seed Material 3 |
| `custom` | Color personalizado elegido por el usuario (`ColorScheme.fromSeed`) |

Con el modo OLED, las superficies del esquema oscuro resuelto se fuerzan a negro puro conservando primary/secondary/tertiary.

### Fuente

- Fuente principal: **Outfit**.

### Escala de UI

- `uiScale` (double) + `uiScaleMode` configurable en ajustes.
- Permite aumentar o reducir el tamaÃ±o de toda la interfaz.
- Atajos `Ctrl +`, `Ctrl -` y `Ctrl 0` para ajustar/resetear la escala en caliente.
- El escalado se aplica con una estructura de Ã¡rbol de widgets **estable** (siempre `ClipRect > OverflowBox > Transform.scale > SizedBox`, usando escala 1.0 cuando no hay override). Esto evita re-parentar el subÃ¡rbol del `Navigator`/`FocusScope` al cruzar el lÃ­mite de 1.0, que provocaba la aserciÃ³n `_elements.contains(element)` del framework (`_FocusInheritedScope`).

### Design tokens

`lib/app/ui_tokens.dart`:
- `FolioRadius`: radios de esquinas consistentes.
- `FolioSpace`: espaciados estÃ¡ndar.
- `FolioMotion`: duraciones y curvas de animaciÃ³n.

### Banner DEBUG de Flutter

- El `MaterialApp` de Folio desactiva `debugShowCheckedModeBanner` para no mostrar la cinta Â«DEBUGÂ» en builds de depuraciÃ³n.

---

## 33. Iconos de pÃ¡gina personalizados

Picker con tres pestaÃ±as:

| PestaÃ±a | Contenido |
|---|---|
| Recientes / RÃ¡pidos | Emojis predefinidos (ðŸ’¡ âœ… âš ï¸ ðŸš¨ â„¹ï¸ ðŸ“Œ ðŸ§  ðŸš€ â€¦) |
| Importados | SVG/PNG importados por el usuario |
| Todos los emojis | Selector completo de emojis |

- Icono personalizado: texto libre / emoji Ãºnico.
- OpciÃ³n "Quitar" para eliminar el icono.
- Implementado en `showFolioIconPicker()`.

### Explorador Iconify en Ajustes

En **Ajustes â†’ Iconos personalizados**, debajo del formulario de importaciÃ³n manual:

- BÃºsqueda con debounce sobre la API pÃºblica gratuita de [Iconify](https://iconify.design) (`api.iconify.design`).
- Filtro por colecciÃ³n curada (Lucide, Tabler, Material Design, Phosphor, Remix, Carbon, Iconoir, Fluent UI, Solar o todas).
- Vista en grid con previsualizaciÃ³n SVG; paginaciÃ³n Â«Cargar mÃ¡sÂ».
- Al pulsar un icono: descarga SVG â†’ `CustomIconImportService.importFromBytes()` â†’ biblioteca local (`custom_icon:{uuid}`).
- Los iconos importados aparecen en la pestaÃ±a **Importados** del picker de pÃ¡gina/callout.
- Requiere conexiÃ³n a internet para buscar/descargar; tras importar funcionan offline.
- AtribuciÃ³n visible a Iconify (colecciones open source con licencias MIT/Apache/ISC segÃºn el set).
- ImplementaciÃ³n: `lib/services/iconify/iconify_catalog_service.dart`, `lib/features/settings/widgets/iconify_icon_browser.dart`.

---

## 34. Onboarding

Flujo de bienvenida (`lib/features/onboarding/`):

- **Crear libreta nueva** (primera instalaciÃ³n): bienvenida â†’ configuraciÃ³n de libreta (contraseÃ±a/cifrado) â†’ **perfil de uso** â†’ personalizaciÃ³n (apariencia + bloqueo) â†’ fiabilidad (copias + Windows) â†’ privacidad y confianza (telemetrÃ­a + mensaje local-first) â†’ **Folio Cloud** (pitch visual con embudo opcional cuenta + checkout; omitible con Â«Continuar sin nubeÂ»; omitido si Firebase no estÃ¡ disponible) â†’ introducciÃ³n a Quill (si aplica) â†’ listo con resumen de Cloud.
- **Libreta adicional**: flujo corto â€” bienvenida â†’ libreta â†’ perfil de uso â†’ listo.
- **Perfil de uso** (`onboardingUsageProfile*`): hasta 3 usos (notas, tareas, proyectos, base de conocimiento, diario, estudio). Persistido en `AppSettings.usageIntents` (`folio_usage_intents`); personaliza el pitch de Folio Cloud y las pÃ¡ginas iniciales.
- **PÃ¡ginas iniciales personalizadas**: si Â«Crear pÃ¡ginas iniciales de ayudaÂ» estÃ¡ activo, `buildVaultStarterPages` genera **4â€“6 pÃ¡ginas** segÃºn el perfil.
- **Importar backup**: desde Folio Cloud (backup cifrado) o archivo local.
- **Importar desde Notion**: ZIP exportado.
- **Post-onboarding (home)**: checklist Â«Primera semanaÂ» incluye paso opcional Â«Mira quÃ© incluye Folio CloudÂ»; tarjeta invitado de Folio Cloud (14 dÃ­as, descartable) si no hay plan activo. Prefs: `folio_ws_home_cloud_guest_dismiss_{vaultId}`, `folio_ws_home_onboard_cloud_explore_{vaultId}`.
- **ConversiÃ³n Cloud compartida**: `lib/services/folio_cloud/folio_cloud_conversion_flow.dart` (sign-in + checkout Stripe) usada en onboarding, Ajustes y workspace.

---

## 35. Actualizador integrado

- `lib/services/updater/`: comprueba nuevas versiones en GitHub Releases (`Minealex2001/Folio`).
- DiÃ¡logo in-app al arranque y en Ajustes â†’ Acerca de cuando hay actualizaciÃ³n.
- **Patch notes antes de actualizar**: el diÃ¡logo muestra el body del release (Markdown) junto a la confirmaciÃ³n (`UpdateAvailableDialogContent`), para leer las novedades antes de descargar/instalar.
- Descarga e instalaciÃ³n guiada (Windows: instalador Inno `.exe`; Android: abre la URL del `.apk`).
- Canales `stable` / `beta` en Ajustes.
- **No aplica en web** ni en builds de Microsoft Store / Play Store (`offersGitHubSelfUpdate`); en tiendas se abre la ficha correspondiente.

---

## 36. DiagnÃ³stico y reporte de bugs

- Reporte manual â†’ `POST /api/v1/diagnostics/report` â†’ YouTrack (sin GitHub). AnÃ³nimo OK; con Folio Cloud el reporte queda ligado al usuario y visible en Ajustes â†’ Privacidad hasta resolverse (puedes aÃ±adir mÃ¡s info).
- Flags de build: `folio_build_flags` (p. ej. banner BETA).
- Log estructurado unificado: `AppLogger` (`lib/services/app_logger.dart`).
  - Destinos: terminal (`debugPrint`, visible en `flutter run`), DevTools (`dart:developer` log) y archivo `folio.log` (sink no-web; entra en reportes de diagnÃ³stico).
  - Niveles: `debug` / `info` / `warn` / `error`. Tags: `folio.<tag>` (p. ej. `bootstrap`, `env`, `vault`, `cloud_sync`, `settings_sync`, `auth`, `onboarding`, `workspace`, `settings`, `persistence`, `entitlements`, `checkout`, `backup`, `smb`, `web-portal`, `store`).
  - Contexto opcional JSON (`context:`) con ids, conteos y cÃ³digos â€” nunca contraseÃ±as, claves, tokens ni contenido de pÃ¡ginas.
  - MigraciÃ³n: residuales `debugPrint`/`print` de sync cloud, entitlements, env, checkout, backups, vault, SMB, portal web y Store unificados en `AppLogger`.
- Historial de sesiones IA y gestiÃ³n de hilos persistida localmente.
- TelemetrÃ­a opcional (Analytics / eventos con sesiÃ³n Cloud): ver `docs/TELEMETRY.md`; desactivable en Ajustes â†’ Privacidad.

---

## 37. Modo zen / escritura sin distracciones

Implementado en `lib/features/workspace/shell/workspace_page.dart` y `lib/desktop/desktop_window_fullscreen.dart`.

- **ActivaciÃ³n**: atajo `F11` (hotkey hardware en `_onHardwareKeyEvent`) o botÃ³n de la barra de herramientas del editor (`id: 'zen_mode'`).
- **Efecto sobre la interfaz**:
  - Oculta la barra de herramientas superior (`appBar: null`).
  - Oculta los paneles laterales (outline, backlinks, comentarios) y el resize handle.
  - Oculta el panel flotante de IA y el de colaboraciÃ³n.
  - Fija el ancho del contenido del editor a 740 px centrado.
  - Colapsa el sidebar (`effectiveSidebarW` devuelve 0.0).
- **Pantalla completa OS (escritorio)**: al entrar en zen, la ventana pasa a fullscreen vÃ­a `window_manager` (`DesktopWindowFullscreen`). El estado `_zenOsFullscreen` es independiente de `_zenMode`: en el overlay se puede salir o volver a entrar en fullscreen sin abandonar el modo zen. Al salir del zen (o al disponer la pÃ¡gina) se restaura la ventana. Escape u otras salidas nativas sincronizan el icono vÃ­a `onWindowLeaveFullScreen` / `onWindowEnterFullScreen` sin forzar la salida del zen. En web/mÃ³vil el zen es solo UI (sin fullscreen OS).
- **Salida del zen**: botÃ³n del overlay (`Icons.self_improvement_rounded`) o volver a pulsar `F11` / toolbar; restaura UI y fullscreen OS.
- **Estado**: `bool _zenMode` y `bool _zenOsFullscreen` en `_WorkspacePageState`.

---

## 38. Bloques sincronizados

Implementado en `lib/models/block.dart`, `lib/session/vault_session.dart` y `lib/features/workspace/editor/block_editor/`.

### Modelo de datos

- `FolioBlock.syncGroupId`: campo `String?` aÃ±adido al modelo de bloque. Persiste en JSON (`syncGroupId`) y se propaga en `copyWith()` con sentinel `clearSyncGroupId`.

### Operaciones en `VaultSession`

| MÃ©todo | DescripciÃ³n |
|---|---|
| `createSyncGroup(pageId, blockId)` | Asigna un nuevo UUID como `syncGroupId` al bloque origen |
| `insertSyncedBlock(targetPageId, syncGroupId)` | Inserta una copia del bloque en otra pÃ¡gina con el mismo `syncGroupId` |
| `unsyncBlock(pageId, blockId)` | Borra el `syncGroupId` del bloque (desvincula sin borrar contenido) |
| `syncGroupBlockCount(syncGroupId)` | Devuelve cuÃ¡ntos bloques comparten ese grupo en toda la libreta |
| `updateBlockTextFull(pageId, blockId, text, deltaJson)` | Actualiza texto + Delta JSON y dispara la propagaciÃ³n |
| `_propagateSyncedBlockContent(syncGroupId, text, deltaJson)` | Propaga el contenido a todos los bloques del grupo en otras pÃ¡ginas |

### IntegraciÃ³n en el editor

- MenÃº contextual del bloque: opciones `sync_create`, `sync_insert`, `sync_unsync`.
- Badge visual en `editable_markdown_block_row.dart`: icono `Icons.sync_rounded` + contador del grupo.
- Al perder el foco, `flushNow()` llama a `updateBlockTextFull` para propagar los cambios.

---

## 39. Vista de grafo

Implementado en `lib/features/workspace/graph/graph_view_screen.dart` y `lib/features/workspace/graph/graph_model.dart`.

- **Acceso**: botÃ³n en la barra de herramientas del workspace (`id: 'graph_view'`) â†’ `Navigator.push` a `GraphViewScreen`.
- **Relaciones incluidas**:
  - **Enlaces** (`GraphEdgeKind.link`): menciones `@`, URIs `folio://open/<id>` y bloques `child_page` (vÃ­a `backlinkPagesFor`).
  - **JerarquÃ­a** (`GraphEdgeKind.hierarchy`): relaciÃ³n carpeta/folio del sidebar (`parentId` â†’ hijo).
- **Algoritmo**: layout force-directed en isolate con clusters por carpeta (`graph_layout.dart`). Carpetas se colocan como hubs; pÃ¡ginas hijas en Ã³rbita cercana; muelle jerÃ¡rquico fuerte + repulsiÃ³n atenuada padreâ†”hijo; masa mayor en carpetas. Enlaces dÃ©biles entre clusters.
- **Renderizado**:
  - Estilo tipo grafo de red: cÃ­rculos de tamaÃ±o segÃºn grado (hubs grandes, pÃ¡ginas pequeÃ±as), malla de enlaces fina y esqueleto jerÃ¡rquico mÃ¡s marcado.
  - Color por carpeta: cada carpeta recibe un color estable (hash del id); las pÃ¡ginas heredan el de la carpeta ancestro mÃ¡s cercana; sin carpeta usan el color del tema.
  - Etiquetas hasta ~250 nodos; con mÃ¡s, solo en hover (emoji de carpeta tambiÃ©n).
  - Leyenda: trazo fino = enlace, trazo grueso = carpeta/jerarquÃ­a.
  - `InteractiveViewer` para zoom y paneo libre (mÃ­n. scale 0.015); al abrir encaja el canvas en el viewport. Se desactiva mientras se arrastra un nodo.
- **InteracciÃ³n**:
  - Hover sobre nodo: resalte visual y cursor grab.
  - Arrastrar nodo: gesto dedicado que gana al paneo; la posiciÃ³n se guarda en la sesiÃ³n de la vista.
  - Tap (sin arrastre) en nodo: `Navigator.pop()` + `onOpenPage(pageId)`.
- **Filtro**: switch "Incluir pÃ¡ginas sin enlaces" (`_includeOrphans`) en el AppBar; cuenta como conectado cualquier nodo con arista de enlace o jerarquÃ­a.
- **Estado vacÃ­o**: mensaje `graphViewEmpty` cuando no hay relaciones entre folios ni carpetas.

---

## 40. Importar PDF con anotaciones

Implementado en `lib/features/workspace/shell/workspace_page_page_tools.dart`.

- **ActivaciÃ³n**: menÃº de importaciÃ³n â†’ extensiÃ³n `pdf` aÃ±adida a `allowedExtensions` en `FilePicker`.
- **DiÃ¡logo de opciones**: permite elegir entre:
  - **Solo anotaciones**: extrae marcas de texto (`PdfTextMarkupAnnotation`) y notas popup (`PdfPopupAnnotation`).
  - **Texto completo**: extrae todo el texto con `PdfTextExtractor.extractText()`.
- **Procesamiento**:
  - Abre el archivo con `PdfDocument(inputBytes: bytes)` de `syncfusion_flutter_pdf`.
  - Construye un documento Markdown con el contenido extraÃ­do.
  - Las anotaciones se formatean como bloques de cita `> [AnotaciÃ³n]: texto`.
- **Resultado**: llama a `_s.importMarkdownDocument(fileName, markdown)` para crear una nueva pÃ¡gina en la libreta.
- **Feedback**: snackbar de Ã©xito (`importPdfSuccess`) o error (`importPdfFailed`); aviso si no se encontrÃ³ texto (`importPdfNoText`).

---

## 41. Lienzo infinito (canvas)

- Bloque `canvas` en el catÃ¡logo (`block_type_catalog.dart`, secciÃ³n avanzada).
- Al abrir una pÃ¡gina que contiene el bloque, la interfaz pasa a `CanvasPage` (`lib/features/workspace/canvas/canvas_page.dart`), del mismo modo que la vista dedicada del tablero Kanban.
- Motor `FolioCanvasBoard` (`lib/features/workspace/canvas/folio_canvas_board.dart`): pan y zoom ilimitados con `InteractiveViewer`; nodos de texto, formas geomÃ©tricas, imÃ¡genes; conectores entre nodos; dibujo libre (trazos); persistencia con debounce de 500 ms en `FolioCanvasData` serializado en `block.text`.
- MÃ¡s de un bloque `canvas` en la misma pÃ¡gina muestra aviso localizado (`canvasMultipleBlocksSnack`); se utiliza el primero.

---

## 42. Pantalla de inicio (Home)

Vista central del workspace cuando **no hay pÃ¡gina abierta** (`page == null` en `VaultSession`). `WorkspaceEditorSurface` (`lib/features/workspace/shell/workspace_editor_surface.dart`) muestra entonces `WorkspaceHomeView` (`lib/features/workspace/shell/workspace_home_view.dart`) con transiciÃ³n `AnimatedSwitcher`.

### Abrir siempre en Home

- Ajustes del workspace: interruptor **Â«Abrir al inicioÂ»** (p. ej. `settingsWorkspaceOpenToHomeTitle` en l10n; el subtÃ­tulo aclara que aplica **tras desbloquear** el cofre) â€” persiste `folio_workspace_open_to_home` (`WorkspacePrefsKeys.openWorkspaceToHome`).
- Al aplicar la selecciÃ³n inicial de pÃ¡gina, `VaultSession._applyInitialPageSelection()` (`lib/session/vault_session.dart`) lee esa preferencia: si estÃ¡ activa, deja `_selectedPageId == null` y se muestra Home en lugar de restaurar la Ãºltima pÃ¡gina guardada o la primera raÃ­z.

### Cabecera y reloj

- Saludo segÃºn la hora local (`workspaceHomeGreetingMorning` / `Afternoon` / `Evening` / `Night`).
- Fecha larga y hora destacada; opciones en la hoja de personalizaciÃ³n: **12 h / 24 h**, **mostrar segundos**, **mostrar zona horaria** (`workspaceHomeClock*` en `AppSettings`).

### DiseÃ±o en columnas

- `WorkspaceHomeColumnLayout`: **automÃ¡tico** (dos columnas si el ancho â‰¥ 880 px y el modo no es compacto/mÃ³vil), **una columna** o **dos columnas** forzadas (en dual, umbral reducido a 640 px).
- Ancho mÃ¡ximo del contenido ~1040 px en dos columnas y ~600 px en una.

### MÃ³dulos (ordenables y opcionales)

Los bloques de contenido se identifican por `WorkspaceHomeSectionIds` (`lib/app/app_settings.dart`): orden por defecto en columna izquierda `folio_cloud`, `vault_status`, `onboarding`, `whats_new`, `search`, `root_pages`, `mini_stats`, `recents`; en la derecha `tasks`, `quick_actions`, `tip`, `create_page`. El usuario puede **reordenar** listas izquierda/derecha y **mostrar u ocultar** cada secciÃ³n desde el bottom sheet Â«personalizarÂ» (icono de afinaciÃ³n en la cabecera).

| ID (interno) | Rol |
|---|---|
| `folio_cloud` | Tarjeta rÃ¡pida Folio Cloud si hay Firebase y sesiÃ³n iniciada |
| `vault_status` | Resumen / estado del cofre |
| `onboarding` | Tarjeta de bienvenida (lÃ³gica de primera vez y cierre) |
| `whats_new` | Novedades de versiÃ³n (descarte por versiÃ³n en prefs) |
| `search` | Campo que filtra **pÃ¡ginas recientes** por tÃ­tulo; envÃ­o / icono abre **bÃºsqueda global** con la consulta |
| `root_pages` | Hasta 8 pÃ¡ginas raÃ­z como chips con icono |
| `mini_stats` | Conteo de pÃ¡ginas y tareas prÃ³ximas |
| `recents` | Lista de visitas recientes (`RecentPageVisitsChangeNotifier`, `lib/features/workspace/recent_page_visits.dart`) |
| `tasks` | Tareas con vencimiento en **14 dÃ­as**, franja semanal de conteos; chip opcional para **preguntar a la IA** sobre esas tareas si el runtime de IA estÃ¡ habilitado |
| `quick_actions` | Accesos: ajustes, **vista de grafo**, plantillas, bloquear cofre, sync de dispositivos, **tarea rÃ¡pida**, **hub de tareas de la libreta** (lista global), carpeta raÃ­z, importar Markdown |
| `tip` | Consejo del dÃ­a (12 textos rotativos segÃºn fecha) |
| `create_page` | BotÃ³n principal crear pÃ¡gina |

### Otras notas

- Vista adaptada a `compact` / `mobileOptimized` (menos columnas y mÃ¡rgenes).
- Cuenta Cloud y `FolioCloudEntitlementsController` alimentan la tarjeta Cloud y el estado de suscripciÃ³n cuando aplica.

---

## 43. Hub de tareas de la libreta

Vista **`VaultTaskHubPage`** (`lib/features/workspace/tasks/vault_task_hub_page.dart`) que lista **todas** las tareas de la libreta **sin** necesidad de un bloque Kanban en la pÃ¡gina: agrega entradas con `VaultSession.collectTaskBlocks` (bloques `task` y, opcionalmente, Ã­tems `todo`).

### Acceso

- **Barra lateral** (`sidebar.dart`): acciÃ³n dedicada cuando el cofre estÃ¡ desbloqueado (`onOpenVaultTaskHub`).
- **Home** â†’ mÃ³dulo **Accesos rÃ¡pidos**: icono de tareas de la libreta (`onOpenVaultTasks` en `workspace_home_view.dart` / `workspace_editor_surface.dart`).

### Filtros y presets

Definidos en `vault_task_entry_filters.dart` (`VaultTaskListPreset`):

| Preset | Criterio (resumen) |
|---|---|
| `all` | Todas |
| `active` | No completadas |
| `done` | Completadas |
| `dueToday` | Vencen hoy |
| `next7Days` | PrÃ³ximos 7 dÃ­as |
| `overdue` | Vencidas (solo bloques `task`) |
| `noDueDate` | Sin fecha lÃ­mite |

- BÃºsqueda por texto en tÃ­tulo, tÃ­tulo de pÃ¡gina, **tags** y **assignee**.
- OpciÃ³n para incluir o excluir tareas simples tipo **`todo`** ademÃ¡s de bloques **`task`**.
- Lista ordenada por fecha de vencimiento y tÃ­tulo; las subtareas con `parentTaskId` se omiten en la lista principal (la jerarquÃ­a se ve en la pÃ¡gina).

### Acciones

- Abrir la **pÃ¡gina y bloque** de una tarea (`onOpenTaskInPage`).
- **Mover** la tarea a otra pÃ¡gina (diÃ¡logo de selecciÃ³n de pÃ¡gina).

---

## 44. Papelera de pÃ¡ginas

Soft-delete de pÃ¡ginas y carpetas con retenciÃ³n de **30 dÃ­as**. El borrado desde el sidebar ya no es irreversible: mueve el elemento a la papelera.

### Modelo y persistencia

- Campo `FolioPage.trashedAt` (ISO-8601 UTC; ausente = pÃ¡gina activa).
- Esquema de vault **v10** (`kVaultPayloadVersion` en `vault_payload.dart`): incluye `displayName` de la libreta para que el sync multi-dispositivo (y P2P) propague renombres entre dispositivos. El sidebar tolera ciclos `parentId`/orden tras un merge (rompe ciclos, limita profundidad, no repite nodos).
- Las pÃ¡ginas en papelera siguen en el blob del vault (bloques, revisiones, ACL, comentarios y adjuntos se conservan hasta el borrado definitivo).

### Comportamiento (`VaultSession`)

| API | Efecto |
|---|---|
| `movePageToTrash(id)` | Marca `trashedAt` en la pÃ¡gina **y todo su subÃ¡rbol activo** |
| `restoreFromTrash(id)` | Quita `trashedAt` del subÃ¡rbol; si el padre ya no existe o sigue en papelera, la raÃ­z vuelve a la raÃ­z de la libreta |
| `permanentlyDeleteFromTrash(id)` | Hard-delete del subÃ¡rbol (adjuntos no referenciados, revisiones, ACL, comentarios) |
| `emptyTrash()` | Hard-delete de todas las raÃ­ces en papelera |
| `purgeExpiredTrash()` | Hard-delete de entradas con mÃ¡s de 30 dÃ­as (`trashRetention`) al desbloquear / cargar la libreta |

- Siempre debe quedar **â‰¥1 pÃ¡gina activa**.
- Ãrbol del sidebar, Home, menciones, grafo, tareas e Ã­ndice de bÃºsqueda usan solo `activePages`.

### UI

- MenÃº **â‹¯** de cada pÃ¡gina/carpeta en el sidebar (`_SidebarTile`): emoji, mover, renombrar, plantilla, borrar. En escritorio nativo se revela al hover; en mÃ³vil/web queda **siempre visible** (no depende de hover).
- ConfirmaciÃ³n del menÃº del tile: Â«Mover a la papeleraÂ» (subÃ¡rbol completo para carpetas/pÃ¡ginas con hijas).
- Entrada fija **Papelera** en el pie del sidebar (`showPageTrashSheet` en `page_trash_sheet.dart`): restaurar, eliminar definitivamente, vaciar, con aviso de retenciÃ³n 30 dÃ­as.
- Badge de conteo cuando hay elementos en papelera.

---

## 45. Servidor MCP local de Folio

Folio puede exponer el mismo catÃ¡logo de acciones que usa Quill internamente (crear/editar pÃ¡ginas, gestionar libretas, buscar, etc.) a clientes MCP externos â€” Claude Desktop, Claude Code, Cursor, o cualquier otro cliente que hable el [Model Context Protocol](https://modelcontextprotocol.io) â€” para que puedan leer y gestionar tu libreta directamente, no solo el chat de Quill dentro de la app.

Es una capacidad **desactivada por defecto y solo disponible en desktop** (Windows/Mac/Linux; no aplica a web ni mÃ³vil, porque necesita abrir un socket TCP real del sistema operativo).

### CÃ³mo activarlo

1. Ajustes â†’ secciÃ³n de IA â†’ interruptor **Â«Servidor MCP local (beta)Â»**.
2. Al activarlo, Folio enruta el endpoint `/mcp` a travÃ©s del bridge de Integraciones, que ya escucha en `127.0.0.1:45831` (puerto **fijo**, siempre activo) â€” el MCP local ya no bindea su propio puerto. Se usa un **token Bearer persistente** (se genera una vez y se reutiliza entre arranques).
3. En Ajustes se muestran el endpoint y el token activos (`http://127.0.0.1:45831/mcp`), necesarios para configurar el cliente MCP externo.
4. Al desactivarlo, `/mcp` deja de enrutarse (404) â€” el bridge de Integraciones en sÃ­ sigue activo para el resto de sus endpoints. El token guardado sigue vÃ¡lido la prÃ³xima vez que se reactive el MCP.

### ConfiguraciÃ³n en Cursor (`mcp.json`)

En **Ajustes â†’ IA**, con el servidor activo:

- **Â«Copiar config de CursorÂ»** â€” JSON con `url` + `Authorization` (HTTP local; Cursor lo admite).
- **Â«Copiar JSON de Claude DesktopÂ»** â€” JSON stdio vÃ­a `npx mcp-remote` + `--allow-http` para pegar en `%APPDATA%\Claude\claude_desktop_config.json` (requiere Node.js/npx).

**Importante â€” Â«Conector personalizadoÂ» de Claude:** ese formulario (Settings â†’ Connectors â†’ Add custom connector) conecta desde **los servidores de Anthropic**, no desde tu PC. Exige una URL **HTTPS pÃºblica**; `http(s)://127.0.0.1` **no funciona** (Anthropic no puede alcanzar tu mÃ¡quina). El MCP de Folio es deliberadamente solo loopback, asÃ­ que **no se puede configurar ahÃ­**. Para Claude Desktop en el mismo equipo, usa el JSON de desarrollador (`claude_desktop_config.json`), no el conector personalizado.

PÃ©galo en `~/.cursor/mcp.json` / `%APPDATA%\Claude\claude_desktop_config.json`, fusionando con otros `mcpServers` si ya existen.

Ejemplo Cursor:

```json
{
  "mcpServers": {
    "folio": {
      "url": "http://127.0.0.1:45831/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

Ejemplo Claude Desktop (puente HTTPâ†’stdio):

```json
{
  "mcpServers": {
    "folio": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "http://127.0.0.1:45831/mcp",
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

- JSON-RPC 2.0 sobre Streamable HTTP local (endpoint Ãºnico `POST /mcp`): mÃ©todos `initialize`, `tools/list`, `tools/call`, `ping`, y notificaciones sin respuesta (`notifications/initialized`).
- Respuestas JSON (`application/json`); `GET`/`DELETE` responden `405` (sin SSE). Tras `initialize` se envÃ­a `Mcp-Session-Id`.
- Versiones de protocolo negociadas: `2024-11-05`, `2025-03-26`, `2025-06-18`, `2025-11-25` (preferida `2025-03-26`).
- Toda peticiÃ³n requiere la cabecera `Authorization: Bearer <token>`; sin ella, o con un token distinto, el servidor responde `401` y un error JSON-RPC `-32001`.
- El servidor **solo** escucha en `127.0.0.1` (loopback, vÃ­a el bridge de Integraciones que lo hospeda) â€” nunca en una interfaz de red. Valida `Origin` si viene presente (solo localhost / 127.0.0.1).

### CatÃ¡logo de acciones expuestas

El mismo `FolioToolRegistry` que usa el bucle de tool-calling interno de Quill (ver secciÃ³n 23): creaciÃ³n y ediciÃ³n de contenido (`create_page`, `append_blocks_to_page`, `replace_page_blocks`, `edit_page_blocks`, `insert_blocks_at_position`, `insert_todos`, `insert_tasks`, `translate_page_bilingual`, **`get_page_content`**) y gestiÃ³n de libretas/pÃ¡ginas (`create_folder`, `rename_page`, `move_page`, `reorder_page`, `duplicate_page`, `set_page_emoji`, `add_page_tag`/`remove_page_tag`, `trash_page`/`restore_page`/`permanently_delete_page`/`empty_trash`, `delete_folder_flatten_children`, `search_pages`, `list_children`). Un cliente MCP los descubre llamando a `tools/list`, que devuelve cada uno con su `inputSchema` (JSON Schema de argumentos).

A diferencia del chat interno de Quill, un cliente MCP no tiene "pÃ¡gina actual": debe pasar siempre un `pageId` explÃ­cito en los argumentos de cada tool que lo requiera.

### Lectura de pÃ¡ginas (`get_page_content`) y allowlist

Los clientes MCP pueden leer el contenido completo de una pÃ¡gina con `get_page_content` (metadatos + bloques con `id`, necesarios para `edit_page_blocks`). Quill interno usa el mismo tool **sin** restricciones de allowlist.

**Privacidad (allowlist por libreta, vault schema v11 `mcpReadablePageIds`):**

- Solo se devuelve el contenido de pÃ¡ginas en la allowlist (o descendientes de una **carpeta** allowlisteada).
- Si un cliente MCP pide una pÃ¡gina fuera de la allowlist, Folio muestra un diÃ¡logo: **Denegar**, **Permitir solo esta vez** (sin guardar) o **Permitir y recordar** (aÃ±ade a la allowlist).
- Las pÃ¡ginas creadas/duplicadas vÃ­a tools se aÃ±aden automÃ¡ticamente a la allowlist (el agente puede releer lo que escribiÃ³).
- `search_pages` vÃ­a MCP sigue pudiendo listar coincidencias por tÃ­tulo, pero **omite el snippet** si la pÃ¡gina no es legible (`contentReadable: false`); tambiÃ©n incluye `blockId` cuando hay coincidencia de contenido.
- MinimizaciÃ³n: no se envÃ­a `richTextDeltaJson` ni apariencia; en bloques `image`/`file`/`audio`/`video` las rutas locales se sustituyen por `[local-attachment]`.
- GestiÃ³n manual: en Ajustes â†’ IA â†’ Servidor MCP puedes **aÃ±adir** pÃ¡ginas/carpetas a la allowlist, quitarlas o vaciarla. La primera lectura vÃ­a MCP tambiÃ©n puede aÃ±adir una pÃ¡gina al aprobar el diÃ¡logo.

### Permisos: aprobaciÃ³n como con cualquier otra integraciÃ³n

El servidor MCP **no ejecuta ninguna acciÃ³n para un cliente hasta que el usuario lo aprueba explÃ­citamente** â€” mismo mecanismo de permisos que ya usan los demÃ¡s puentes locales de Folio (el bridge de Integraciones y Run2Doc):

1. Cuando un cliente MCP se conecta por primera vez (llamada `initialize`, con su `clientInfo.name`/`version`), Folio muestra un diÃ¡logo de permiso describiendo quÃ© podrÃ¡ hacer el cliente (crear/editar pÃ¡ginas, gestionar libretas, buscar, **leer pÃ¡ginas autorizadas**) y quÃ© no (el servidor nunca escucha fuera de este equipo).
2. Si el usuario deniega, la conexiÃ³n falla con un error MCP (`-32001`) y no se guarda nada.
3. Si el usuario permite, la aprobaciÃ³n se guarda igual que cualquier app aprobada (`AppSettings.approveIntegrationApp`, con el id `mcp:<nombre-del-cliente>` y `integrationVersion` = **`FolioMcpServer.capabilitiesVersion`**, hoy `"2"`) y las siguientes conexiones de ese mismo cliente no vuelven a preguntar **mientras la versiÃ³n de capacidades coincida**.
4. Si se llama a cualquier tool antes de `initialize`, o el cliente identificado no estÃ¡ aprobado, el servidor responde con un error MCP (`-32002` sin `initialize`, `-32001` sin aprobar) en vez de ejecutar la acciÃ³n.
5. **Re-aprobaciÃ³n por cambio de capacidades:** al subir `capabilitiesVersion` (p. ej. al aÃ±adir lectura de pÃ¡ginas), las aprobaciones antiguas dejan de valer. Al reconectar, Folio muestra el diÃ¡logo de actualizaciÃ³n explicando la novedad (lectura con allowlist) y pide autorizar de nuevo.

**Revocar el acceso:** como cualquier otra integraciÃ³n aprobada, los clientes MCP aprobados aparecen en **Ajustes â†’ Integraciones**, junto a Run2Doc y el resto de apps aprobadas, con un botÃ³n para revocar el acceso en cualquier momento. Revocar borra la aprobaciÃ³n guardada; la prÃ³xima vez que ese cliente se conecte, tendrÃ¡ que pedir permiso de nuevo.

### Seguridad â€” resumen

- Apagado por defecto (opt-in explÃ­cito).
- Solo loopback, nunca red.
- Comparte el puerto fijo `45831` del bridge de Integraciones (Run2Doc es un cliente identificado por `clientAppId`, no un servicio aparte); token Bearer persistente (no rota en cada arranque).
- AprobaciÃ³n explÃ­cita por cliente antes de ejecutar cualquier tool, revocable desde Ajustes â†’ Integraciones en cualquier momento.
- Lectura de contenido acotada a la allowlist MCP de la libreta (mÃ¡s confirmaciÃ³n la primera vez); escritura/gestiÃ³n siguen el catÃ¡logo completo una vez el cliente estÃ¡ aprobado.
- Revocar el cliente o vaciar la allowlist corta el acceso a contenido ya autorizado.
---

## ApÃ©ndice: configuraciÃ³n persistida (`AppSettings`)

| Clave | Tipo | DescripciÃ³n |
|---|---|---|
| `themeMode` | enum | Tema (`system` / `light` / `dark` / `oled`) |
| `accentColorMode` | enum | Modo de color de acento |
| `uiScale` | double | Factor de escala de UI |
| `uiScaleMode` | enum | Modo de escala (auto/manual) |
| `aiProvider` | enum | Proveedor IA seleccionado |
| `syncEnabled` | bool | Sync P2P activada |
| `syncRelayEnabled` | bool | Relay P2P activado |
| `syncDeviceId` | String | ID Ãºnico del dispositivo |
| `syncDeviceName` | String | Nombre del dispositivo en la red |
| `syncPendingConflicts` | List | Conflictos de sync pendientes de resoluciÃ³n |
| `syncLastSuccessMs` | int | Timestamp del Ãºltimo sync exitoso |
| `cloudDeviceSyncEnabled` | bool | Sync multi-dispositivo vÃ­a Folio Cloud |
| `cloudAppProfileSyncEnabled` | bool | Sync/backup del perfil de ajustes (app + libreta) vÃ­a Folio Cloud |
| `cloudAppProfileAckUid` / `AckFingerprint` / `AckUpdatedAtMs` | string/int | Ãšltimo perfil de cuenta ya ofrecido/aceptado (evita repetir el diÃ¡logo si no cambiÃ³) |
| `enterCreatesNewBlock` | bool | `Enter` crea nuevo bloque (vs salto de lÃ­nea) |
| `windowsNotificationsEnabled` | bool | Notificaciones de escritorio para recordatorios de tareas (Windows / macOS / Linux vÃ­a `local_notifier`) |
| `quillToolCallingEnabled` | bool | Bucle de tool-calling de Quill (default `true`; se puede desactivar en Ajustes; secciÃ³n 23) |
| `mcpServerEnabled` | bool | Servidor MCP local activado (secciÃ³n 45); desktop-only |
| `mcpServerAuthToken` | String | Token Bearer persistente del servidor MCP local (secciÃ³n 45) |

---

## ApÃ©ndice: compatibilidad y correcciones de build

### MigraciÃ³n a Flutter 3.44 / Dart 3.12

- **`flutter_quill` actualizado a `11.5.1`** (el `pubspec.lock` quedaba en `11.5.0`). La `11.5.1` implementa el nuevo mÃ©todo `TextInputClient.onFocusReceived` requerido por Flutter 3.44+. Con `11.5.0`, `QuillRawEditorState` fallaba al compilar con el error *"missing implementations for these members"*.
- **`ListView` en `settings_page.dart`**: se corrigiÃ³ un parÃ¡metro inexistente (`scrollCacheExtent: ScrollCacheExtent.pixels(480)`) por el parÃ¡metro real del framework `cacheExtent: 480`.

### Script de compilaciÃ³n y publicaciÃ³n (`builld_all.ps1`)

`builld_all.ps1` se rehÃ­zo con un **menÃº interactivo** (ademÃ¡s del modo directo por parÃ¡metros para CI). Al ejecutarlo sin argumentos (`.\builld_all.ps1`) muestra un menÃº con:

- **Publicar RELEASE / PRE-RELEASE**: compila **todas las formas de distribuciÃ³n posibles** en el host (instalador Windows `.exe`, ZIP portable Windows, MSIX Store, APK + AAB Android, ZIP Linux nativo o vÃ­a WSL, ZIP macOS solo en Mac) y las adjunta a `gh release create` (estable o `--prerelease` para el canal Beta; ver [RELEASES.md](RELEASES.md)). Antes de publicar se pueden **pegar notas Markdown** (terminar con `END`) o usar Enter para `--generate-notes`; tambiÃ©n `-ReleaseNotes` / `-ReleaseNotesFile`.
- **Publicar solo notas** (changelog) sin adjuntar artefactos (mismas opciones de Markdown).
- **Compilar TODO** o cada plataforma por separado (incluye acciÃ³n `macos`).
- **Generar solo el instalador Windows** (`.exe`).
- **Mantenimiento**: `flutter clean` y cambio de versiÃ³n en `pubspec.yaml`.

Detalles de implementaciÃ³n:

- **Compatibilidad CI intacta:** si se pasa `-SkipAndroid`, `-SkipLinux`, `-SkipMacOS`, `-SkipMicrosoftStore` o `-NonInteractive`, el script salta el menÃº y ejecuta `build-all` (comportamiento legado que usa el workflow `folio-build-all.yml`). TambiÃ©n admite `-Action <acciÃ³n>` para invocaciÃ³n directa.
- **Instalador dinÃ¡mico:** genera un `.iss` temporal con rutas absolutas al `Release` actual y `OutputDir`, evitando las rutas fijas obsoletas. Requiere `ISCC.exe` (Inno Setup); localizado por PATH o rutas por defecto.
- **PublicaciÃ³n multi-asset:** `Publish-Release` adjunta todos los artefactos de la versiÃ³n actual en `Output/` (no solo el instalador). El instalador `.exe` sigue siendo obligatorio para release/prerelease.
- **Notas Markdown:** `Resolve-ReleaseNotes` prioriza `-ReleaseNotesFile`, luego `-ReleaseNotes`, luego pegado interactivo (lÃ­nea `END`); si no hay cuerpo, usa `--generate-notes`. El Markdown se escribe a un temporal UTF-8 y se pasa a `gh release create --notes-file`.
- **Linux:** en host Linux compila nativo; en Windows intenta **WSL** (Flutter + `zip` + deps GTK en la distro). Si no hay entorno, avisa y continÃºa (best-effort en `build-all` / publish).
- **macOS:** solo en host Darwin (`flutter build macos` â†’ ZIP del `.app`). Desde Windows/Linux se omite con aviso; el workflow CI tiene job `macos-latest`.
- **PublicaciÃ³n:** usa `gh` (GitHub CLI); valida que estÃ© instalado y autenticado, y que el tag no exista antes de publicar. ParÃ¡metros: `-ReleaseTag`, `-ReleaseTarget`, `-ReleaseNotes`, `-ReleaseNotesFile`, `-PreRelease`, `-DraftRelease`, `-BumpVersion`, `-Yes`. El `target_commitish` se **autodetecta** (rama actual si existe en `origin`, o rama por defecto del remoto â†’ `main`) para evitar el error `Invalid target_commitish` cuando la rama por defecto no es `master`.
- **Robustez de cachÃ©:** opciÃ³n `-Clean` / entrada de menÃº para `flutter clean` (resuelve el error de `CMakeCache.txt` cuando el repo se mueve de carpeta).
- **CodificaciÃ³n:** el script se mantiene en ASCII para evitar fallos de parseo entre Windows PowerShell 5.1 (ANSI) y PowerShell 7 (UTF-8).
- **`installer.iss`:** se corrigieron las rutas absolutas obsoletas (`E:\Folio-1\...`) por rutas relativas al repositorio.
- **Versionado MSIX sincronizado:** `Build-WindowsStore` ejecuta `dart run msix:create --store --version <semver>.0` tomando la versiÃ³n de `pubspec.yaml`. Partner Center rechaza paquetes con el mismo *full name* (p. ej. `...Folio-PrivateWorkspace_0.4.1.0_X64_`) si el contenido difiere, asÃ­ que el `msix_version` debe subir en cada publicaciÃ³n. Antes quedaba fijo en `pubspec.yaml` (`msix_version: 0.4.1.0`) y provocaba el error *"You must upload at least one package / uniquely identified by their full names"*; ahora sigue automÃ¡ticamente a la versiÃ³n de la app (Ãºltimo segmento `0` segÃºn polÃ­ticas de la Store).

### Toolchain de Windows (MSVC 14.51 / Visual Studio 18)

- Se aÃ±adiÃ³ `-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` de forma global en `windows/CMakeLists.txt`. Los MSVC recientes convierten `<experimental/coroutine>` en error fatal (`STL1011`), lo que rompÃ­a la compilaciÃ³n de los plugins `audioplayers_windows`, `local_auth_windows` y `webview_windows` (que aÃºn usan ese header vÃ­a C++/WinRT).

### Firebase en Windows (crash de arranque)

En Windows, con el engine de Flutter 3.44 y el SDK C++ de Firebase, la app crasheaba al arrancar (antes de mostrar la ventana) por dos causas independientes:

1. **`firebase_auth` â€” `__fastfail` (`0xC0000409`).** Los `EventChannel` nativos `id-token` y `auth-state` despachan desde un hilo en segundo plano. El engine actual trata el trÃ¡fico de canales fuera del hilo de plataforma como fatal, tumbando el proceso justo tras inicializar Firebase Auth.
   - **Fix:** fork local vendorizado de `firebase_auth_platform_interface` (`vendor/firebase_auth_platform_interface`, base oficial `9.0.2`) referenciado con `dependency_overrides` (path). El parche omite el registro de **ambos** canales en Windows cuando la app activa `FirebaseAuthPlatform.disableIdTokenChannelOnWindows = true` (se hace en `main.dart`). `authStateChanges()`/`idTokenChanges()` siguen emitiendo el usuario en cachÃ© al suscribirse, asÃ­ que el estado de sesiÃ³n persistido se refleja al arrancar; lo que se pierde es la reactividad en vivo del canal (nuevos cambios de sesiÃ³n no se propagan por stream en Windows).

2. **`cloud_firestore` â€” `FirestoreInternalError` (excepciÃ³n C++ no controlada, `0xE06D7363`).** El SDK C++ de Firestore lanza un error interno fatal al inicializarse en Windows con el toolchain/engine actual (persiste incluso tras actualizar a `cloud_firestore` con Firebase C++ 13.5.0).
   - **Fix:** Firestore queda **deshabilitado en Windows** mediante el guard central `folioFirestoreSupported` (`lib/services/folio_firestore_support.dart`). Todos los accesos a Firestore comprueban ese flag: las lecturas devuelven datos vacÃ­os y las escrituras se ignoran o lanzan un error claro. Puntos protegidos: `FolioFirestoreSync` (telemetrÃ­a), `FolioCloudEntitlementsController` (doc de usuario/derechos), `folio_cloud_publish` (publicaciÃ³n web), `CommunityTemplateStore` (galerÃ­a comunitaria), `CollabSessionController` (colaboraciÃ³n en vivo), media E2E de colaboraciÃ³n en el editor de bloques y el panel de telemetrÃ­a. El resto de plataformas (Android, iOS, macOS, Linux, Web) usan Firestore con normalidad.

- Se subieron las versiones de Firebase (`firebase_core ^4.10.0`, `firebase_auth ^6.5.0`, `firebase_auth_platform_interface ^9.0.0`, `cloud_firestore ^6.5.0`, `firebase_storage ^13.4.0`, `cloud_functions ^6.3.0`).

---

## Correcciones y mejoras de robustez (julio 2026)

### Tienda de Apps

- **`setState() during build`:** `AppStoreService.fetchRegistry()` aplaza el primer `notifyListeners()` tras un microtask; `AppStoreScreen` lanza `_refreshRegistry()` en `addPostFrameCallback`.
- **Overflows UI:** nombre de app integrada con `Expanded`; fila de tags/rating en tarjetas con `Wrap`.
- **LocalizaciÃ³n:** textos de la tienda (pantalla, tarjetas, detalle, errores de registry) migrados a `lib/l10n/` (6 idiomas). El servicio expone cÃ³digos de error (`registryErrorCode`) traducidos en la UI.
- **Persistencia:** `_finalizeInstall()` hace `await _saveInstalled()` antes de notificar.

### TelemetrÃ­a (`FolioFirestoreSync`)

- Cada evento encolado guarda el `userId` de la sesiÃ³n que lo generÃ³ (no el `currentUser` del momento del flush).
- Los eventos solo se eliminan de la cola tras un `batch.commit()` exitoso; los fallidos se reinsertan al frente.
- `onUserChanged` se encadena en `_flushChain` para no solapar drains.

### Folio Cloud

- **Callables IA (mÃ³vil/macOS):** timeout de 120 s en `folio_cloud_callable.dart` con mapeo a `deadline-exceeded`.
- **Cloud-pack:** rollback de snapshot y blobs nuevos si falla `folioFinalizeCloudPack`.
- **Logging:** `AppLogger` unificado (terminal + DevTools + `folio.log`); migraciÃ³n de `debugPrint`/`print`; hitos en auth, vault unlock/key cache, sync incremental/headless, import-all, onboarding, workspace y settings.
- **IA cloud:** errores no tipados preservan el mensaje real antes de mapear a `unavailable`.
- **Entitlements:** cancelaciÃ³n serializada del listener de documento por UID (`await _docSub?.cancel()`).
- **Backup:** comprobaciÃ³n de existencia del archivo antes de `putFile`.

### LocalizaciÃ³n incremental

- **Drive:** Cancel/Delete/Rename/Mover/color de carpeta usan claves `l10n` existentes o nuevas (`driveMoveToFolderTitle`, `driveFolderColor`).
- **Kanban/Jira:** diÃ¡logos y mensajes de sync Jira migrados a claves `kanban*` y `jira*` en los 6 `.arb`.
- **Release notes** y **estado vacÃ­o del editor** (`workspaceEditorReadyHeadline`, tips `workspaceHomeTip0â€“3`).
- **Pendiente incremental:** `database_block_editor.dart` aÃºn usa helper `_t(es, en)` en parte del editor de bases de datos; conviene migrar en una tanda dedicada.

## Correcciones del sistema de notas (pÃ¡ginas y bloques) â€” julio 2026

RevisiÃ³n centrada en errores del editor de bloques, pÃ¡ginas y persistencia de notas.

### PÃ©rdida de datos (rich text WYSIWYG)

- **Clonado de bloques:** `cloneBlocksWithNewIds` y `createPageFromTemplate` ahora copian `richTextDeltaJson`, evitando perder el formato Quill al duplicar bloques, instanciar plantillas o pegar. `syncGroupId` se omite a propÃ³sito para que el clon sea independiente.
- **Flush al navegar:** `_disposeControllers()` vacÃ­a a la sesiÃ³n los cambios Quill con debounce pendiente (`_flushPendingQuill`) antes de descartar los timers, en vez de cancelarlos sin guardar.
- **Flush en blur:** al perder foco un bloque WYSIWYG se persiste con `updateBlockTextFull` (texto + Delta), no solo el Markdown.
- **Bloqueo del vault:** `VaultSession.lock()` ejecuta `flushPendingSave()` (persistencia inmediata) antes de limpiar la memoria de sesiÃ³n, evitando perder el autosave con debounce de 450 ms.

### LÃ³gica de bloques

- **Backspace:** en bloques Quill usa el estado real del documento (texto plano y selecciÃ³n), no el `TextEditingController` espejo que puede estar desfasado; el caret tras merge se posiciona con la longitud de texto plano del bloque previo (`_blockCaretLength`).
- **Caret tras primera palabra / centinela:** al insertar el bloque vacÃ­o final, el editor captura y restaura el offset desde Quill (no desde el controller sombra desfasado), hace flush del debounce antes de capturar, evita reconciliar el documento mientras hay foco/debounce pendiente y no devuelve el cursor al inicio si el bloque ya tiene texto.
- **Split (Enter) y merge:** `splitBlockAtCaret` y `mergeBlockUp` limpian `richTextDeltaJson` de los bloques afectados para que el Markdown sea la fuente de verdad y no se restaure contenido obsoleto al recargar.
- **Fuga de `FocusNode`:** el overlay de preview reutiliza un `FocusNode` cacheado por bloque (`_folioQuillPreviewFocusFor`) liberado en el teardown, en vez de crear uno nuevo en cada `build`.

### Async y concurrencia

- Comprobaciones `mounted` tras `await` en pegado de tabla, picker de emoji del callout y `catch` de subida cloud de notas de reuniÃ³n.
- TranscripciÃ³n de reuniones: los chunks de audio se procesan en serie (`_chunkChain` en el worker) para no mezclar la transcripciÃ³n fuera de orden.

### Robustez del modelo

- `FolioBlock.fromJson` / `FolioPage.fromJson`: lectura tolerante de `id` (string, numÃ©rico legacy o nulo) sin `CastError` que rompa la carga del vault; `tags` filtra no-strings; `VaultPayload.fromJson` tolera claves/valores no esperados en revisiones y ACL.
- **Toggle legacy:** `FolioToggleData.parseOrLegacy` conserva como cuerpo el texto plano antiguo en vez de vaciarlo.
- **Retroenlaces:** `backlinkPagesFor` detecta tambiÃ©n bloques `child_page` que apuntan a la pÃ¡gina objetivo.
- **IDs Ãºnicos en columnas:** `FolioColumnsData.tryParse` deduplica los IDs de bloque de todas las columnas al cargar (reasignando IDs a duplicados/vacÃ­os), evitando que un JSON corrupto/importado haga que varios bloques compartan el mismo `TextEditingController`.
- **Flush antes de bloquear:** `VaultSession` expone hooks (`addPendingFlushHook`) que `flushPendingSave()` ejecuta antes de persistir; el editor registra uno que vacÃ­a a la sesiÃ³n todos los bloques Quill con debounce pendiente, cerrando la ventana de pÃ©rdida al bloquear por inactividad o pasar a segundo plano.

### LocalizaciÃ³n

- Bloques de columnas: eliminado el helper `_t(es, en)`; etiquetas de tipo de bloque y controles de columna migrados a claves `columnBlockType*` / `columnList*` en los 6 idiomas.
- Error inline de Mermaid (`mermaidInlineLoadError`), placeholder y etiqueta de ecuaciÃ³n (`equationEmptyPlaceholder`, `equationLatexLabel`) y fallback del botÃ³n de plantilla (`templateButtonDefaultLabel`) localizados.

### Notas

- Ambos pendientes menores previos (IDs duplicados de controllers en columnas y la ventana de pÃ©rdida en bloqueo por inactividad) quedaron resueltos con la deduplicaciÃ³n de IDs al parsear columnas y los hooks de flush previos a `flushPendingSave()`.

## Workaround REST de Firestore en Windows â€” julio 2026

En Windows el SDK nativo de Cloud Firestore (C++) crashea al inicializarse, por lo que estaba deshabilitado (`folioFirestoreSupported == false`) y todas las lecturas devolvÃ­an vacÃ­o. Efecto visible: la suscripciÃ³n a Folio Cloud no aparecÃ­a en Ajustes, porque `FolioCloudEntitlementsController` no podÃ­a leer `users/{uid}`.

- **Cliente REST** (`lib/services/folio_cloud/folio_firestore_rest.dart`): lee documentos de Firestore por su [API REST](https://firebase.google.com/docs/firestore/use-rest-api) usando el ID token de Firebase Auth como Bearer (Auth sÃ­ funciona en escritorio, igual que las Cloud Functions por HTTP). Incluye un decodificador del formato `Value` de Firestore (`integerValue` como String, `mapValue`, `arrayValue`, etc.) a `Map` plano compatible con los `fromJson` de la app. Reutilizable vÃ­a `folioFirestoreRestGetDocument(path)` y el atajo `folioFirestoreRestGetUserDoc(uid)`.
- **IntegraciÃ³n:** `_fetchUserDocFromServerWithRetries` usa el fallback REST cuando el SDK nativo no estÃ¡ disponible, con los mismos reintentos por arranque en frÃ­o. Como en Windows ya se usa sondeo (`_folioFirestoreUseGetPolling`) en vez de streams, todas las rutas de derechos (carga inicial, `handleAppResumed`, refresco manual, re-sync con Stripe) funcionan ahora.
- **Alcance:** solo lecturas puntuales (`get`); no reemplaza streams en tiempo real (se aproximan con el sondeo existente) ni escrituras. El helper queda disponible para que otras lecturas (pÃ¡ginas publicadas, plantillas de comunidad, etc.) lo adopten si se requiere en Windows.

## AuditorÃ­a de seguridad y mantenimiento â€” julio 2026

Correcciones derivadas de la revisiÃ³n integral del repositorio (seguridad, datos, localizaciÃ³n e higiene).

### Seguridad y cifrado del vault

- **Ãndice de bÃºsqueda:** en libretas cifradas el Ã­ndice (`search_index.json`) ya no se persiste en disco; se mantiene solo en RAM y se borra al reconstruir. Evita tÃ­tulos y fragmentos en texto plano fuera del blob cifrado.
- **Desbloqueo rÃ¡pido:** la DEK de quick unlock migra a `flutter_secure_storage` (DPAPI/Keychain); las copias legacy en SharedPreferences se migran en la primera lectura. Al revocar passkey se desactiva tambiÃ©n el quick unlock.
- **Integraciones OAuth/API keys:** `IntegrationAuthService` persiste tokens en almacÃ©n seguro del SO con migraciÃ³n automÃ¡tica desde SharedPreferences.
- **Sync LAN entre dispositivos:** canal cifrado y autenticado con X25519 + HKDF + AES-256-GCM (`device_sync_crypto.dart`); snapshots y peticiones van sellados; peers no emparejados no pueden leer el vault.
- **Passkeys:** `FolioRpServer` valida tipo WebAuthn (`webauthn.create` / `webauthn.get`), challenge, origen y coincidencia de `credentialID` tras la respuesta del autenticador.
- **Auto-actualizador:** verificaciÃ³n SHA-256 del instalador contra el digest publicado en el asset de GitHub antes de ejecutar.

### Integridad de datos

- **Persistencia serializada:** mutex en `VaultPersistenceController`; `onAppBackgrounded` hace flush y luego lock en secuencia; flush obligatorio antes de imports y backups destructivos.
- **Escritura atÃ³mica:** `AtomicFileWriter` usa `rename` con reemplazo (sin ventana sin archivo); restore desde `.bak` tambiÃ©n para `vault.keys` y `vault.mode`.
- **WebDAV:** timeouts de conexiÃ³n/envÃ­o/recepciÃ³n en operaciones de backup remoto.

### LocalizaciÃ³n y UI

- **Drive:** menÃºs, panel de detalles, rutas raÃ­z y tipos de archivo migrados a claves `drive*` en los 6 idiomas.
- **ListTile en Home:** secciones de recientes y tareas envueltas en `Material` para evitar el error de fondo invisible con `tileColor`.
- **CÃ³digo muerto:** eliminado el catÃ¡logo duplicado en `lib/features/workspace/widgets/` (la versiÃ³n activa es `editor/block_type_catalog.dart`).

### Higiene del repositorio

- `.gitignore` ampliado: `Output/`, `lib.zip`, `build_out.txt`; artefactos de build e instaladores fuera de git.
- **`folio_local_secrets.dart`:** se versiona con placeholders vacÃ­os; copiar desde `.example` para desarrollo local (no estÃ¡ en `.gitignore`).
- **CI de localizaciÃ³n:** script `tool/check_arb_parity.ps1` para comparar claves entre `app_*.arb`.

### DocumentaciÃ³n ampliada (Ã­ndice)

- **App Store / extensiones `.folioapp`:** `lib/features/app_store/`, `lib/services/app_store/`.
- **IntegraciÃ³n YouTrack:** ajustes en `lib/features/settings/youtrack_integration_settings.dart` y `lib/services/youtrack/`.
- **Pantalla de recuperaciÃ³n:** `lib/features/vault/recovery_screen.dart` (restauraciÃ³n desde `.bak` local).
- **Dashboard de telemetrÃ­a:** `lib/features/telemetry_dashboard/telemetry_dashboard_page.dart`.

### Pendiente (deuda conocida)

- `database_block_editor.dart` migrado a `.arb` (v0.8.0); quedan clones de `_t(es,en)` en `block_editor_state.dart` y `folio_in_app_checkout_dialog.dart`, y ternarios manuales sueltos en `settings_page.dart` / `kanban_board_page.dart`.
- DivisiÃ³n de monolitos: `block_editor_state.dart` (debug API, media colaborativa/local, menÃº contextual, multi-selecciÃ³n, format toolbar + Quill Copilot ya extraÃ­dos a mixins), `kanban_board_page.dart` (sync de integraciones y persistencia ya extraÃ­dos a controllers) y `settings_page.dart` (filtro de bÃºsqueda y secciÃ³n "Acerca de" ya extraÃ­dos) parcialmente troceados en v0.8.0; el resto queda para milestones futuros.
- UnificaciÃ³n de bridges completada (v0.8.0): `run2doc_bridge` (puerto 45832) eliminado por no usarse; MCP ya no bindea su propio puerto (45833) â€” se enruta a travÃ©s de `integrations_bridge` en 45831.
- Endurecer Argon2id en nuevas libretas requiere migraciÃ³n de `vault.keys` existentes.

## Backend Spring Boot (migraciÃ³n Firebase â†’ Spring) â€” Fases 1â€“10

Directorio `backend/` (**git submodule** â†’ repo GitHub [`Minealex2001/Folio-Backend`](https://github.com/Minealex2001/Folio-Backend)): API REST `/api/v1/...` con Maven, Java 21 y Spring Boot 3.3.x que sustituye gradualmente Auth/Firestore/Functions. Tras clonar Folio: `git submodule update --init --recursive`. Despliegue cloud (p. ej. Railway) desde ese repo, no desde el monorepo de la app.

**Referencia de endpoints:** [FOLIO_BACKEND_API.md](FOLIO_BACKEND_API.md) â†’ detalle canÃ³nico en [`backend/docs/API.md`](../backend/docs/API.md) (Auth, Account, Billing, Family, Vault, Storage, Collab, Publish, Templates, AI, Integraciones, Diagnostics, Admin, STOMP).

**Infra local (Fase 1):** `docker-compose.yml` con PostgreSQL 16, MinIO y Mailpit; `GET /api/v1/health` â†’ `{"status":"ok"}`; Swagger UI en `/swagger-ui.html`.

**Self-host Docker:** el mismo compose incluye el servicio `api` (Dockerfile multi-stage Maven + JRE 21, perfil `docker`). Un `docker compose up -d --build` levanta el stack completo; el API queda en el host en **`:18080`** (`API_HOST_PORT`, evita choque con CEF en `:8080` en Windows). Secretos Stripe/OpenAI van en **`backend/.env`** (no en `functions/.env`). GuÃ­a: [FOLIO_CLOUD_SELF_HOST.md](FOLIO_CLOUD_SELF_HOST.md). CÃ³digo API y Railway: repo [Folio-Backend](https://github.com/Minealex2001/Folio-Backend) ([`backend/README.md`](../backend/README.md)).

**Postman:** colecciÃ³n v2.1 de todos los endpoints REST + nota STOMP collab en [`backend/postman/`](../backend/postman/) (`Folio_Cloud_API.postman_collection.json` + environment local). CÃ³mo importar: [backend/README.md](../backend/README.md) Â§ Postman. Carpeta **Admin (QA)** para grant Cloud/ink/staff sin Stripe. El `adminApiKey` del environment debe coincidir con `FOLIO_ADMIN_API_KEY` en `backend/.env`. Los IT que hacen fallback sin Testcontainers usan la BD `folio_it` (no `folio`) para no truncar datos locales del self-host.

### Admin / QA (sin pagar Stripe)

| MÃ©todo | Ruta | Efecto |
|---|---|---|
| POST | `/api/v1/admin/entitlements/grant-cloud` | Cloud completo (`admin_override`) sin Checkout |
| POST | `/api/v1/admin/entitlements/revoke-cloud` | Quita el grant |
| POST | `/api/v1/admin/ink/grant` | Suma tinta `purchasedBalance` |
| POST | `/api/v1/admin/staff` | Marca `folioStaff` |
| POST | `/api/v1/admin/users/lookup` | Snapshot de cuenta |

Auth: header `X-Folio-Admin-Key: $FOLIO_ADMIN_API_KEY` **o** JWT de usuario `folioStaff`. Body: `{ "email": "..." }` o `{ "uid": "..." }`.

```powershell
# En backend/.env: FOLIO_ADMIN_API_KEY=dev-admin-change-me
docker compose -f backend/docker-compose.yml up -d --build api

curl -X POST http://127.0.0.1:18080/api/v1/admin/entitlements/grant-cloud `
  -H "Content-Type: application/json" `
  -H "X-Folio-Admin-Key: dev-admin-change-me" `
  -d "{\"email\":\"tu@email.com\",\"alsoStaff\":true,\"inkDrops\":1000}"
```

**Esquema (Fases 2â€“3):** Flyway `V1__core_schema.sql` (tablas del doc Â§2.1) + `V2__auth_schema.sql` (`password_hash`, `email_verified_at`, `status`, `refresh_tokens`, `email_verification_tokens`, `password_reset_tokens`).

**Auth (Fases 4â€“9):**
- `POST /auth/register` â€” Argon2id, crea `users` + `user_folio_cloud` + `user_ink`, envÃ­a verificaciÃ³n de email.
- `POST /auth/login` â€” JWT HS256 (access 15 min) + refresh opaco (SHA-256 en BD, 30 dÃ­as).
- Filtro JWT fail-closed; pÃºblicos: health, register/login/refresh/verify-email/forgot/reset-password y Swagger.
- `POST /auth/refresh` con rotaciÃ³n; reuso de refresh revocado invalida la cadena del usuario.
- `POST /auth/logout` y `POST /auth/resend-verification` requieren Bearer.
- VerificaciÃ³n de email y forgot/reset password vÃ­a **Resend** (sin `RESEND_API_KEY` en local, se loguean). Los correos enlazan a la **app oficial** (`FOLIO_WEB_BASE_URL`: `/verify-email?token=â€¦`, `/reset-password?token=â€¦`). El HTML legacy `GET /reset-password` y `GET /api/v1/auth/verify-email` en el API quedan como fallback. Reset revoca todos los refresh tokens.

**Cuenta (Fase 10):** `GET /account/me`, `POST /account/ensure` (idempotente, puerto de `ensureUserDocExists`), `PATCH /account/display-name` (mÃ¡x. 80, colapsa espacios; propagaciÃ³n a familia en Fase 15).

## Backend Spring Boot â€” Fases 12â€“15 (billing, ink, MS Store, familia)

**Fase 12 â€” Stripe + email estudiante:** `POST /api/v1/billing/checkout-session`, `/portal-session`, `/sync` (JWT); `POST /api/v1/billing/webhook` (pÃºblico, firma Stripe + idempotencia en `stripe_webhook_events` / `stripe_processed_checkouts`). `StudentEmailChecker` / `AbusedEmailDomains` portan `student_email.ts` + `swot_abused_domains.ts` (tests 1:1). Variables `STRIPE_*` alineadas con `docs/FOLIO_CLOUD_SECRETS.md`.

**Fase 13 â€” Recarga mensual de tinta:** `@Scheduled` cron `0 0 8 1 * *` (segundos + campos Spring) zona `Europe/Madrid`; `MonthlyInkRefillJob.runRefill()` consultable en tests. Elegibilidad por query directa a `user_folio_cloud` (+ MS Store), sin Ã­ndice `folioCloudSubscribers`.

**Fase 14 â€” Microsoft Store IAP:** `POST /api/v1/billing/microsoft-store/validate` â€” Azure AD + Collections API; idempotencia en `microsoft_store_processed_purchases` / `_backup_grants`. Tests con MockWebServer.

**Fase 15 â€” Familia:** `POST /api/v1/family/invite|remove|verify-student`, `GET /api/v1/family/details`; recalcula entitlements al invitar/quitar. `PATCH /account/display-name` propaga best-effort a `family_members.display_name_snapshot`.

VerificaciÃ³n: `mvn -f backend/pom.xml test` (Testcontainers Postgres). Arranque: ver `backend/README.md`.

## Backend Spring Boot â€” Fases 19â€“21 (IA + Jira/diagnÃ³sticos + Slack/Teams/Spotify)

Flyway `V19__ai_integrations_schema.sql`: amplÃ­a `integration_user_index` / `pending_integration_command` y aÃ±ade `integration_webhook_connections`, `integration_link_codes`, `teams_webhook_endpoints`, `folio_diagnostics`, `folio_diagnostic_signatures`.

**Fase 19 â€” Proxy IA + tinta:** `GET /api/v1/ai/pricing`, `POST /api/v1/ai/complete`, `POST /api/v1/ai/transcribe` (JWT). Debita tinta antes de llamar al proveedor; reembolsa a `purchasedBalance` si falla. Cliente OpenAI inyectable (`OpenAiClient`) para tests.

**Fase 20 â€” Jira OAuth + diagnÃ³sticos (pÃºblicos):** `POST /api/v1/integrations/jira/oauth-exchange` (shape Atlassian: `access_token` / `refresh_token` / `expires_in`); `POST /api/v1/diagnostics/report` â†’ `{ok, savedToYouTrack}` y persistencia local.

**Fase 21 â€” Slack/Teams (9) + Spotify (3):** webhook connection/proxy, link-code, pending-commands, ack-command; `POST .../slack/command` y `.../teams/command` pÃºblicos con verificaciÃ³n de firma Slack HMAC / Teams outgoing HMAC; OAuth exchange Slack/Teams/Spotify (JWT); callback HTML Spotify; proxy passthrough Spotify Web API.

PÃºblicos adicionales en SecurityConfig: jira oauth-exchange, diagnostics/report, slack/teams command, spotify oauth-callback.

## Backend Spring Boot â€” Fases 11, 16â€“18, 22â€“24 (storage, vault, collab, publish, templates)

**Fase 11 â€” Storage MinIO/S3:** AWS SDK v2 `S3Client`/`S3Presigner`; `StorageService` (presign upload/download, put/get, delete, `deletePrefix`); `StoragePathAuthorizer` traduce `storage.rules` (backups, cloud-packs, device-sync, app/vault profiles, published, community-templates â‰¤1 MiB, collab-media â‰¤80 MiB); bootstrap de bucket en perfiles `dev`/`test`. Config `folio.storage.*` / env `S3_*`. Proxy autenticado para el cliente: `PUT/GET/HEAD /api/v1/storage/objects` con cabecera `X-Folio-Storage-Path` (evita URLs presignadas con hostname Docker `minio`).

**Fase 16 â€” Vault backups (14 endpoints):** `POST /api/v1/vault/backups/...` â€” finalize/latest-meta/restore-wrap/blobs-exist/usage/list/delete cloud-pack & legacy/trim(-by-bytes)/vaults/index upsert/record-meta. Cuota en `user_backup_usage` + Flyway `V111__vault_backup_fingerprint.sql`.

**Fase 17 â€” Device sync:** `POST /api/v1/vault/device-sync/meta|finalize|vaults|plain-secret/ensure` â€” v1 pack monolÃ­tico / v2 manifiesto (+ resta de cuota v1â†’v2); secreto plain get-or-create con lock. El cliente en modo Spring lee meta vÃ­a callable (no Firestore) y sube blobs/manifiesto por el proxy `/api/v1/storage/objects` con el UID Spring en las rutas `users/{uid}/...`.

**Fase 18 â€” App/vault profiles:** `POST /api/v1/vault/profiles/app|vault/...` â€” validaciÃ³n de `packStoragePath` vÃ­a `StoragePathAuthorizer` (prefijo, sin `..`, `.bin`). Respuesta vacÃ­a de `app/meta` y `vault/meta` usa `LinkedHashMap` (permite `updatedAt: null`); un `Map.of(..., null)` provocaba NPE y el cliente veÃ­a **401 vacÃ­o** por el error-dispatch de Spring Security. `POST .../app/restore-wrap` alinea con Firebase: **200** con `restoreWrapB64` vacÃ­o si aÃºn no hay wrap (antes 412 `failed_precondition`, que abortaba el primer push de ajustes).

**Fase 22 â€” Collab control-plane:** `POST/GET/PUT /api/v1/collab/rooms/**` â€” create/join/invite/remove/close, prepare/commit media (presign), update con `CollabRoomUpdateValidator` (reglas firestore legacy / e2e seal / e2e content). Sync en vivo â†’ Fase 27.

**Fase 23 â€” Published pages:** `POST/PUT/DELETE/GET /api/v1/published-pages` â€” exige feature `publishWeb`; GET por id pÃºblico; owner-only write/delete. Cliente Flutter (`folio_cloud_publish.dart`): modo Spring usa storage proxy + REST (upsert por `storagePath` vÃ­a `/mine`); modo Firebase sigue en Firestore `publishedPages`.

**Fase 24 â€” Community templates:** `POST/PUT/DELETE/GET /api/v1/community-templates` â€” `communityTemplateCreateOk` a nivel app (name/blockCount/path/url/â€¦) con 400 por campo; lÃ­mite 1 MiB en subida. Cliente Flutter (`community_template_store.dart`): en modo Spring sube el `.folio-template` por proxy de storage, indexa con `POST /api/v1/community-templates`, lista con `GET` pÃºblico, descarga por `folioSpringStorageGetData(storagePath)` y borra con `DELETE /{id}` (objeto en servidor).

## Backend Spring Boot â€” Fases 25â€“26 (ciclo de vida de cuenta / RGPD)

**Fase 25 â€” Solicitud/cancelaciÃ³n de borrado + exportaciÃ³n:**
- `POST /api/v1/account/deletion/request` â€” agenda `deletion_scheduled_for = now+30d`; si ya hay pendiente, devuelve la misma fecha.
- `POST /api/v1/account/deletion/cancel` â€” limpia columnas; rechaza si la fecha ya pasÃ³ (carrera con el job).
- `GET /api/v1/account/export` â€” JSON de metadatos (perfil, folioCloud, billing resumido, ink, familia, vaultBackups/publishedPages/communityTemplates â‰¤100, collabRooms â‰¤50). Sin contenido cifrado de libretas.

**Fase 26 â€” Cascada `purgeUserAccount` + job diario:**
- `AccountDeletionService.purgeUserAccount(uid)`: Stripe cancel/delete customer (best-effort), salir/disolver familia + recompute entitlements, borrar salas propias (BD + prefijo `collab-media-e2e/`) y membresÃ­as ajenas, `deletePrefix` de `users/{uid}/`, `published/{uid}/`, `community-templates/{uid}/`, borrar published/templates/integration index (+ filas MS Store sin CASCADE), y finalmente `users` (FK 1:1 en cascada).
- Job `@Scheduled(cron = "0 15 3 * * *", zone = Europe/Madrid)` â†’ `processScheduledAccountDeletions`.
- Sin IdP externo: no hay trigger `onUserDeleted` separado (documentado en el servicio).

**Fase 27 â€” Collab sync en vivo (STOMP/WebSocket):** endpoint `ws://â€¦/ws/collab`; JWT en frame STOMP `CONNECT` (`Authorization: Bearer` o header `token`, mismo `JwtService` que HTTP). `SEND /app/collab/{roomId}/update` con shape legacy (`title`/`blocksJson`) o E2E (`wrappedRoomKey`/`contentCipher`) + `changedKeys`; valida con `CollabRoomUpdateValidator`, persiste `content_version`, retransmite a `/topic/collab/{roomId}` solo si es vÃ¡lido. Sin CRDT (el cliente usa last-write-wins por `contentVersion`). Handshake HTTP pÃºblico; auth en CONNECT. Errores de validaciÃ³n â†’ `/user/queue/collab-errors` (sin broadcast; `CollabStompAuthInterceptor` permite SUBSCRIBE a ese destino con sesiÃ³n autenticada).

**Cliente Flutter (Fase 29):** si `FolioBackendConfig.useSpring`, `CollabSessionController` usa `CollabStompTransport` (`stomp_dart_client`) hacia `FolioBackendConfig.collabWsUrl` + snapshot REST `GET /api/v1/collab/rooms/{id}` (`collab_spring_api.dart`). Si no, sigue Firestore `collabRooms`. Chat de sala solo en Firestore (cÃ³digo `collab_chat_spring_unavailable` en modo Spring).

VerificaciÃ³n: `mvn -f backend/pom.xml test`. Arranque: ver `backend/README.md`.

## Backend Spring Boot â€” Fase 28 (telemetrÃ­a opcional)

**Fase 28 â€” TelemetrÃ­a: descartada intencionalmente.** No se porta a Spring la ingesta `telemetry_events` ni los jobs de agregaciÃ³n de `functions/src/telemetry.ts`. Motivos (evidencia en cÃ³digo/docs):

- `docs/MIGRACION_SPRINGBOOT.md` Â§6 ya enmarca `firebase_analytics` como uso ligero y no crÃ­tico: Â«Probablemente ya no dependes de Analytics para nada crÃ­tico â€” confirmar antes de decidirâ€¦Â».
- Canal dual documentado en `docs/TELEMETRY.md`: GA4 (anÃ³nimo, sin cuenta) + copia Firestore `analytics_events/{uid}/events` solo con sesiÃ³n y `AppSettings.telemetryEnabled`. El dashboard staff (`telemetry_dashboard_page.dart`) depende de Firestore/agregados; los totales de instalaciÃ³n viven en GA4 (`folio_install`), no en el pipeline propio.
- Continuidad histÃ³rica a travÃ©s del cutover no bloquea Auth, billing, vault, collab ni Cloud; la telemetrÃ­a es opt-in de producto/privacidad, no contrato de API.
- En Windows el sync a Firestore ya estÃ¡ deshabilitado (`folioFirestoreSupported` / `FolioFirestoreSync`), asÃ­ que el pipeline propio ya no es universal antes del cutover.
- Tras el cutover se puede dejar GA4 en paralelo para mÃ©tricas de producto/marketing, o reintroducir un pipeline Spring mÃ¡s adelante sin acoplarlo al go-live.

Sin cÃ³digo nuevo en esta fase (sin `mvn test` adicional).

## Backend Spring Boot â€” Fase 29 (cutover cliente Flutter)

Cutover **sin big-bang**: el cliente Flutter puede apuntar a Firebase (default) o al API Spring Boot detrÃ¡s de compile-time defines. Rollback = rebuild sin el flag Spring (modo Firebase sigue construible; no se borran paquetes Firebase â€” eso es Fase 30).

### Activar modo Spring

Prioridad: `--dart-define` > `FolioLocalSecrets.folioBackendMode` /
`folioBackendBaseUrl` (en `lib/config/folio_local_secrets.dart`).

**Railway (prod):** `https://api.folio.com.es` â€” modo Spring activo en
`FolioLocalSecrets` por defecto en desarrollo local.

```powershell
flutter run -d windows
# o explÃ­cito:
.\tool\run_folio_spring.ps1 -BaseUrl https://api.folio.com.es
```

**Local (compose en :18080):**

```powershell
flutter run -d windows --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
```
(En Windows preferir `127.0.0.1:18080`: el compose publica el API ahÃ­; `localhost:8080` choca a menudo con CEF/Cursor.)

| Define / secret | Default | Efecto |
|---|---|---|
| `FOLIO_BACKEND_MODE` | `spring` vÃ­a `FolioLocalSecrets` (o `firebase` si se vacÃ­a) | `spring` / `springboot` / `backend` â†’ API Spring |
| `FOLIO_BACKEND_BASE_URL` | `https://api.folio.com.es` vÃ­a secrets | Obligatorio en modo Spring |

CÃ³digo clave:
- `lib/config/folio_backend_config.dart` â€” flag + base URL + WS collab derivado
- `lib/services/cloud_account/folio_spring_auth_session.dart` â€” login/refresh/logout/register; tokens en `FlutterSecureStorage`
- `lib/services/cloud_account/cloud_account_controller.dart` â€” dual Firebase | Spring
- `lib/services/folio_cloud/folio_cloud_callable.dart` â€” en Spring: HTTP en **todas** las plataformas + mapa callableâ†’REST
- `lib/services/folio_cloud/folio_spring_callable_routes.dart` â€” rutas `/api/v1/...`
- `lib/services/folio_cloud/folio_cloud_identity.dart` â€” UID/Bearer unificados
- Entitlements: `GET /account/me` (mapa compatible con el shape Firestore)

Auth Spring: `POST /api/v1/auth/login` + `/refresh`; access JWT + refresh opaco, mismo almacÃ©n seguro que el resto de secretos de la app.

### Checklist go / no-go (antes de cambiar el default a Spring)

- [x] Smoke Railway: `GET /api/v1/health` â†’ ok; `POST /api/v1/auth/register` â†’ **201** (fix `/error` + mail best-effort)
- [x] Default cliente Spring: `FolioLocalSecrets` â†’ `https://api.folio.com.es`
- [x] Storage proxy Spring + UID unificado
- [x] OAuth / publish / templates / collab STOMP cableados a Spring
- [x] ETL tool: `backend/tools/firebase-import/` (Auth/Firestore/Storage â†’ Postgres+Bucket; passwords `{migrated}RESET_REQUIRED`)
- [ ] Ops: ejecutar `npm run import` con service account + vars Railway; usuarios migrados hacen forgot-password
- [ ] Ops: Stripe Dashboard webhook â†’ `https://api.folio.com.es/api/v1/billing/webhook` (dejar de apuntar a Cloud Functions)
- [ ] Smoke desktop con cuenta migrada: login/reset, `/account/me`, vault meta, storage put/get, collab

### Pendientes por plataforma / superficie

| Ãrea | Estado en Fase 29 |
|---|---|
| Callables â†’ REST (desktop + forzado HTTP en mÃ³vil/web en modo Spring) | Hecho (mapa en `folio_spring_callable_routes.dart`) |
| Auth JWT + secure storage | Hecho |
| Entitlements vÃ­a `/account/me` | Hecho |
| `folioCloudCatalogPrices` | `POST /api/v1/billing/catalog-prices` (pÃºblico) |
| Subidas/descargas blob (proxy Spring â†’ MinIO/S3) | **Hecho** |
| OAuth HTTP (Slack/Teams/Jira/Spotify) + diagnÃ³stico | **Hecho** (`apiV1Prefix` + Bearer Spring) |
| Collab live WebSocket STOMP (`/ws/collab`) | **Hecho** â€” `CollabSessionController` â†’ STOMP si `useSpring` (`collab_stomp_transport.dart` + `stomp_dart_client`); Firestore si no. CONNECT Bearer; SUBSCRIBE topic + errores; SEND update E2E. Chat sala aÃºn no en Spring. |
| Published pages + community templates | **Hecho** â€” REST Spring + storage proxy |
| Portal web (`FOLIO_WEB_PORTAL_*`) | Omite espejo en modo Spring |
| Analytics / telemetrÃ­a GA4 | Fuera de alcance (Fase 28 descartada) |
| MigraciÃ³n datos Firebase â†’ Railway | Tool `backend/tools/firebase-import/` (one-shot); ejecutar con SA antes de apagar Firebase |

## Backend Spring Boot â€” Fase 30 (decomisiÃ³n Firebase)

**Estado actual: Fase 30 ejecutada (2026-07-29).** Cliente y repo apuntan solo a Spring/Railway (`https://api.folio.com.es`). Se eliminaron deps Firebase, `functions/`, rules, `firebase_options*`, vendor fork Windows. ETL one-shot en `backend/tools/firebase-import/`. TelemetrÃ­a Firestore staff deshabilitada (UI stub). Ops pendiente: apuntar Stripe webhook a Railway y apagar proyectos GCP cuando el trÃ¡fico legacy sea cero.

**CompilaciÃ³n cliente (post-cutover):** se cerraron los `error` de `flutter analyze lib` dejados a medias tras quitar Firebase â€” storage vÃ­a `folio_storage_transport` (backup / cloud-pack / settings sync), entitlements `canUseRealtimeCollab`, identity/auth exceptions, collab firmas, proxy Spotify/Slack/Teams e integration commands por callable Spring. Meta: **0** `error -` en `flutter analyze lib` (warnings/info permitidos).

### HistÃ³rico (checklist previo a la ejecuciÃ³n)

No ejecutar esta fase en la misma sesiÃ³n en que se escribe el checklist. La decomisiÃ³n es destructiva: **el rollback deja de ser barato** (hay que restaurar deps, `functions/`, opciones de Firebase, fork Windows y, si se apagan los proyectos GCP, recuperar proyectos/billing). Solo procede **despuÃ©s de que la Fase 29 (flag dual-mode Firebase | Spring) haya corrido limpia en producciÃ³n durante al menos un ciclo de release completo**, con trÃ¡fico real en modo Spring por defecto y sin dependencia operativa del backend Firebase.

CoordinaciÃ³n: mientras Fase 29 estÃ© en curso o en canario, **no** quitar paquetes Firebase ni romper el modo Firebase del cliente.

### Prerrequisitos (obligatorios antes de tocar cÃ³digo)

1. Fase 29 fusionada y desplegada: flag dual-mode estable; default de producciÃ³n = Spring.
2. Al menos **un ciclo de release completo** en producciÃ³n con el default Spring, sin regresiones de Auth, billing, vault, collab, IA ni storage atribuibles al cutover.
3. ConfirmaciÃ³n explÃ­cita de producto/ops de que no hace falta volver a Firebase en caliente (rollback = rebuild + redeploy del cliente + posible reactivaciÃ³n de proyectos, no un flip de flag).
4. Backup / export de lo que aÃºn se necesite de Firestore/Auth/Storage (si aplica migraciÃ³n de datos residuales) y de secretos aÃºn solo en Firebase.
5. CI y builds de release apuntando ya a Spring; sin jobs que desplieguen `functions/` a producciÃ³n como camino feliz.

### QuÃ© se eliminarÃ¡ cuando se ejecute (inventario)

| Ãmbito | Elementos |
|---|---|
| **Deps `pubspec.yaml`** | `firebase_core`, `firebase_auth`, `firebase_auth_platform_interface`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_analytics`; quitar el `dependency_overrides` del path `vendor/firebase_auth_platform_interface`. |
| **Cliente / vendor** | `lib/firebase_options.dart`, `lib/firebase_options_staging.dart`, directorio `vendor/firebase_auth_platform_interface/`; cÃ³digo/imports residuales de plugins Firebase en `lib/` (tras el cutover de Fase 29 solo deberÃ­an quedar stubs o rutas muertas). |
| **Backend Firebase** | Directorio completo `functions/` (Cloud Functions, scripts de deploy npm, emuladores). |
| **Config Firebase en repo** | `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json` (y CORS/scripts solo-Firebase si ya no aplican). |
| **Docs a archivar o reescribir** | [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md) (autoridad Cloud Functions / reglas) â†’ archivar o redirigir a `backend/README.md` + este FEATURES; [FOLIO_CLOUD_STAGING.md](FOLIO_CLOUD_STAGING.md) (proyectos `folio-minealexgames` / `folio-staging-minealex`) â†’ archivar o reescribir para staging Spring. Actualizar referencias en README, `FOLIO_CLOUD_SECRETS.md`, `TELEMETRY.md`, `MIGRACION_SPRINGBOOT.md` Â§7. |
| **Proyectos Firebase/GCP** | DecomisiÃ³n operativa de **`folio-minealexgames`** (producciÃ³n) y **`folio-staging-minealex`** (staging): Functions, Auth, Firestore, Storage, facturaciÃ³n; solo tras confirmar que ningÃºn cliente en soporte sigue apuntando ahÃ­. |

### Checklist ejecutable (orden)

Ejecutar en PowerShell desde la raÃ­z del repo, en este orden. Cada casilla es un commit o PR propio si el diff es grande.

1. **Congelar prerrequisitos** â€” Verificar en release notes / mÃ©tricas que Fase 29 lleva â‰¥1 release estable en producciÃ³n con default Spring.
2. **Rama de decomisiÃ³n** â€” Crear rama; no mezclar con features de producto.
3. **Quitar deps Firebase** â€” Eliminar paquetes y override del fork Windows en `pubspec.yaml`; `flutter pub get`.
4. **Borrar artefactos Firebase del cliente** â€” `lib/firebase_options.dart`, `lib/firebase_options_staging.dart`, `vendor/firebase_auth_platform_interface/`.
5. **Limpiar cÃ³digo cliente** â€” Eliminar `main.dart` / env / telemetrÃ­a / callables que aÃºn importen plugins Firebase; dejar solo el cliente HTTP/JWT Spring (Fase 29).
6. **Borrar `functions/`** â€” Tras confirmar que no hay deploys programados ni webhooks Stripe/MS Store aÃºn apuntando a URLs de Cloud Functions.
7. **Borrar config Firebase del repo** â€” `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
8. **Docs** â€” Archivar/actualizar `FOLIO_CLOUD_BACKEND.md`, `FOLIO_CLOUD_STAGING.md` y referencias cruzadas; marcar Fase 30 como **ejecutada** en este FEATURES y en `MIGRACION_SPRINGBOOT.md` Â§7.
9. **VerificaciÃ³n local (obligatoria)**
   ```powershell
   flutter analyze
   # Cero imports de plugins Firebase en lib/ y test/ (ajustar si queda un comentario histÃ³rico):
   rg -n "package:firebase_|package:cloud_firestore|package:cloud_functions|firebase_options" lib test
   flutter test
   ```
10. **Builds de release** â€” Al menos un build por plataforma de soporte (p. ej. Windows MSIX / Android / iOS / web segÃºn el release train vigente); confirmar arranque sin `Firebase.initializeApp` y sesiÃ³n solo vÃ­a Spring.
11. **DecomisiÃ³n de proyectos GCP** (Ãºltimo, ops) â€” Apagar o borrar `folio-staging-minealex` primero; luego `folio-minealexgames` cuando el trÃ¡fico legacy sea cero. Documentar fecha y ticket de ops.

### Comandos de verificaciÃ³n (resumen)

| Comando | Criterio de Ã©xito |
|---|---|
| `flutter analyze` | Sin errores nuevos por sÃ­mbolos Firebase eliminados. |
| `rg â€¦ package:firebase_\|cloud_firestore\|cloud_functions\|firebase_options` en `lib`/`test` | Sin coincidencias de imports activos (o solo docs/comentarios explÃ­citamente permitidos). |
| `flutter test` | Suite verde. |
| Builds release | Artefactos firmados/instalables OK; smoke Auth + una callable crÃ­tica contra Spring. |

### Nota de rollback

Antes de Fase 30, el rollback tÃ­pico es **revertir el flag dual-mode (Fase 29)** y seguir sirviendo Firebase. **DespuÃ©s de Fase 30**, el rollback implica restaurar deps + vendor + `functions/` + opciones + redeploy de Functions y, si se decomisionaron los proyectos, recrear infraestructura GCP â€” coste alto y fuera de un hotfix de release. No ejecutar Fase 30 en la misma ventana que un incidente de producciÃ³n.
