# Fase 7 del roadmap de producto — Product Polish + scoping de Marketplace/App Store

Capturado: 2026-08-09, sobre la rama `chrono-trigger-alpha`.

## 7A — Product Polish Pass

Barrido de "qué construimos que no se siente conectado" ([[feedback_connect_dont_just_build]]),
usando la checklist de Definition of Done del roadmap como criterio.

**Encontrado y corregido esta sesión:**
- `SidebarOrganizationSwitcher` (`lib/features/workspace/shell/sidebar/sidebar_organization_switcher.dart`)
  estaba completamente construido, con tests de compilación limpios, pero **nunca se instanciaba en
  ningún sitio de la app real** — quedó huérfano tras ser reemplazado por
  `SidebarContextSwitcher` (que combina cuenta + equipo en un solo chip, y ese sí está conectado
  en `SidebarFooter`). Se ha eliminado el archivo huérfano.

**Encontrado, NO corregido (fuera de alcance seguro para esta sesión):**
- `sidebar_cloud_account_switcher.dart` tiene la misma historia — su clase
  `SidebarCloudAccountSwitcher` está igual de huérfana — pero el mismo archivo también define
  `showAddFolioCloudAccountDialog()`, que sí usa `SidebarContextSwitcher`. Borrar el archivo entero
  (como se intentó por error en esta sesión y se revirtió al momento) rompería esa función. Extraer
  solo la clase muerta y mover el diálogo a su propio archivo es un cambio quirúrgico de bajo riesgo
  pero se deja como tarea aparte, para no mezclarlo con el resto de esta sesión.

**No auditado a fondo por límite de tiempo de esta sesión** (candidatos para una pasada dedicada
futura, seguir el mismo patrón: `grep -rl "<ClassName>\b" lib test` para cada widget "huérfano
sospechoso" antes de tocarlo):
- Otros widgets bajo `lib/features/workspace/shell/sidebar/` no auditados uno a uno.
- El resto del catálogo de widgets (`lib/widget_catalog/builtin/`) no se revisó buscando plugins
  registrados pero sin ningún settings/entry point real más allá del catálogo mismo.

## 7B — Visual Pack Marketplace

Sin cambios de código en esta fase — confirmado el estado real:
- La implementación base de Visual Packs (`lib/visual_packs/active_pack_controller.dart`,
  `builtin/*`) existe y funciona en `chrono-trigger-alpha`.
- El documento de arquitectura del marketplace (referenciado en memoria de sesiones previas como
  "Fase 8.5") vive en la rama de backend `feature/organizations-teams`, que el usuario decidió
  explícitamente NO mergear todavía en esta sesión (ver decisión de Fase 6). El scoping de
  Marketplace queda bloqueado en la misma decisión, no es un bloqueo nuevo.
- Acción recomendada cuando se retome: releer ese documento de arquitectura tras el merge del
  backend, antes de diseñar la UI cliente — no reinventar el diseño desde cero.

## 7C — App Store / Extensibility

Hallazgo relevante: el "spike de descubrimiento" que el roadmap pedía ya se hizo en algún momento,
solo que en un worktree separado nunca integrado:
- `docs/platform/APP_STORE_GUIDE.md` (en `chrono-trigger-alpha`, ya integrado) documenta el formato
  `.folioapp` completo: manifest, bloques personalizados en WebView, comandos de `/`,
  transformadores de IA, permisos, publicación en el registry.
- Una implementación funcional (`app_store_screen.dart`, `app_store_service.dart`, widgets) existe
  en `FolioApp/.claude/worktrees/musing-gates-0c05e2/lib/features/app_store/` — **no está en
  `chrono-trigger-alpha`**.

Esto cambia la naturaleza de la Fase 7C: no es "investigar si esto es viable", es "decidir si se
integra el trabajo que ya existe en ese worktree". Es una decisión de alcance del mismo tipo que la
de Fase 6 (qué rama/worktree se convierte en la fuente de verdad) — se deja explícitamente para que
el usuario la tome, no se ha tocado el worktree ni se ha traído nada de él a `chrono-trigger-alpha`
en esta sesión.
