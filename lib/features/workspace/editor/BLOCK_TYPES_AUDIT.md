# Auditoría de tipos de bloque (workspace editor)

Fuente de verdad de tipos en el selector `/`: `block_type_catalog.dart` (`blockTypeTemplates`).

## Matriz por tipo

| type | Fuente de datos persistida | UI interactiva embebida (riesgo taps/foco) | Slash/toolbar | Render principal |
|---|---|---|---|---|
| `paragraph` | `FolioBlock.text` (markdown inline) | links/mentions/toolbar inline | Sí | `block_editor/editable_markdown_block_row.dart` |
| `h1`/`h2`/`h3` | `text` (markdown inline) | links/toolbar inline | Sí | `block_editor/editable_markdown_block_row.dart` |
| `bullet`/`numbered`/`todo` | `text` + `checked` (todo) | checkbox marcador + links/toolbar | Sí | `editable_markdown_block_row.dart` + `block_row_marker.dart` |
| `quote` | `text` | links/toolbar | Sí | `editable_markdown_block_row.dart` |
| `callout` | `text` + `icon` + `appearance` | picker emoji + popup | Sí | `editable_markdown_block_row.dart` |
| `divider` | estructural (sin texto) | — | No | `block_editor/block_row_dispatch_divider.dart` |
| `toggle` | `text` (payload `FolioToggleData.encode()`) + `expanded` | TextFields + botón expand | Parcial (catálogo lo incluye) | `block_row_dispatch_toggle.dart` → `folio_special_block_widgets.dart` |
| `task` | `text` (payload `FolioTaskData.encode()`) | chips, menús, TextFields | No | `block_row_dispatch_task.dart` → `folio_special_block_widgets.dart` |
| `template_button` | `text` (payload `FolioTemplateButtonData.encode()`) | botón inserta plantilla | No | `block_row_dispatch_template_button.dart` → `folio_special_block_widgets.dart` |
| `column_list` | `text` (payload `FolioColumnsData.encode()`) | múltiples TextFields/checkbox dentro | No | `block_row_dispatch_column_list.dart` → `folio_special_block_widgets.dart` |
| `toc` | `text` (si aplica) | lista de saltos (scrollToBlock) | No | `block_row_dispatch_toc.dart` → `folio_special_block_widgets.dart` |
| `breadcrumb` | `text` (si aplica) | navegación/acciones | No | `block_row_dispatch_breadcrumb.dart` → `folio_special_block_widgets.dart` |
| `child_page` | `text` (pageId) | navegación a página hija | No | `block_row_dispatch_child_page.dart` |
| `image` | `url` + `imageWidth` | botones resize/replace | No | `block_row_dispatch_image.dart` |
| `bookmark` | `url` + `text` (título) | botones abrir/editar URL | No | `block_row_dispatch_bookmark.dart` |
| `embed` | `url` | webview embebido | No | `block_row_dispatch_embed.dart` |
| `video` | `url` (YouTube o file) | preview card + botones | No | `block_row_dispatch_video.dart` |
| `audio` | `url` (file) | reproductor + slider | No | `block_row_dispatch_audio.dart` → `folio_special_block_widgets.dart` |
| `meeting_note` | `url` (audio) + flags | grabación/transcripción/controles | No | `block_row_dispatch_meeting_note.dart` → `meeting_note_block_widget.dart` |
| `file` | `url` (file) | preview + botones | No | `block_row_dispatch_file.dart` |
| `code` | `text` + `codeLanguage` | CodeField + selector lenguaje | No | `block_row_dispatch_code.dart` |
| `equation` | `text` (latex) | CodeField + preview | No | `block_row_dispatch_equation.dart` |
| `mermaid` | `text` (source) | preview expand + editor fuente | No | `block_row_dispatch_mermaid.dart` + `folio_mermaid_preview.dart` |
| `table` | `text` (payload `FolioTableData.encode()`) | tabla editable | No | `block_row_dispatch_table.dart` → `table_block_editor.dart` |
| `database` | `text` (payload `FolioDatabaseData.encode()`) | grid + filtros + config | No | `block_row_dispatch_database.dart` → `database_block_editor.dart` |

## Hotspots detectados (para refactor)

- **Política de interacción row**: selección/foco se decide en `block_editor/block_list_row.dart` usando hit-testing con `MetaData` tags (`folio.link` / `folio.interactive`). Cualquier control interno no marcado puede provocar “click → entrar en edición/seleccionar” antes de que el widget reciba el evento.
- **Tipos con payload serializado en `text`**: `toggle`, `task`, `column_list`, `template_button`, `table`, `database`. Riesgo de **desincronización** si existe `TextEditingController` asociado pero el flujo de update viene desde widgets internos (no desde el controller).
- **Duplicación de “row chrome”**: casi todos los `block_row_dispatch_*.dart` repiten padding+row+slots; propenso a divergencias de UX y bugs sutiles.

