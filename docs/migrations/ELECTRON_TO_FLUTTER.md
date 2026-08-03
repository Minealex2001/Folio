# Migración de Folio (Flutter) a Electron (guía para que lo ejecute una IA)

> Objetivo: que **una IA (Cursor/Agente)** pueda ejecutar la migración de esta app (Folio) desde Flutter/Dart a **Electron**, reduciendo riesgos y manteniendo paridad funcional por fases.
>
> Este documento está pensado como **runbook**: arquitectura objetivo, mapeos, decisiones, checklist, prompts sugeridos y criterios de aceptación.
>
> Contexto del repo (según `pubspec.yaml`, `README.md` y `docs/FEATURES.md`):
> - App **desktop-first** (Windows/Linux/macOS) con editor complejo de bloques, canvas, Kanban, tray, hotkeys globales, etc.
> - **Local-first** (vault en disco, cifrado, IA local).
> - **Folio Cloud opcional**: Firebase Auth/Firestore/Storage/Functions + Stripe/Microsoft Store en backend.

---

## Índice

- [1. Principios y estrategia](#1-principios-y-estrategia)
- [2. Requisitos no negociables](#2-requisitos-no-negociables)
- [3. Arquitectura objetivo en Electron](#3-arquitectura-objetivo-en-electron)
- [4. Mapeo Flutter → Electron (por área)](#4-mapeo-flutter--electron-por-área)
- [5. Plan de migración por fases (ejecutable por IA)](#5-plan-de-migración-por-fases-ejecutable-por-ia)
- [6. Inventario de “hard parts” (riesgos + mitigación)](#6-inventario-de-hard-parts-riesgos--mitigación)
- [7. Diseño de datos: Vault, páginas, bloques, historial](#7-diseño-de-datos-vault-páginas-bloques-historial)
- [8. Editor: estrategia de port](#8-editor-estrategia-de-port)
- [9. IA local y IA Cloud](#9-ia-local-y-ia-cloud)
- [10. Sync P2P y colaboración](#10-sync-p2p-y-colaboración)
- [11. Localización (i18n) y “no hardcodear”](#11-localización-i18n-y-no-hardcodear)
- [12. Distribución, auto-update e instaladores](#12-distribución-auto-update-e-instaladores)
- [13. Estrategia de pruebas y verificación](#13-estrategia-de-pruebas-y-verificación)
- [14. Prompts y plantillas para agentes](#14-prompts-y-plantillas-para-agentes)
- [15. Definición de “Done” (por fase)](#15-definición-de-done-por-fase)

---

## 1. Principios y estrategia

### Qué significa “migrar” aquí

No es “re-hacer pantallas”: Folio es un producto con **lógica compleja** (editor, modelos, sync, crypto, AI, cloud opcional). La migración real consiste en:

- Mantener el **modelo mental** y los **datos** (vault, páginas, bloques) compatibles.
- Preservar el enfoque **local-first** y **privacy-first**.
- Conservar *feature parity* por fases sin bloquear el desarrollo.

### Estrategia recomendada (para IA)

- **Fase 0**: preparar un *Electron skeleton* con arquitectura limpia (main/renderer/preload) y pipeline de build.
- **Fase 1**: portar **core data + vault** (sin UI compleja) y abrir/editar una página simple.
- **Fase 2**: portar el **editor** de forma incremental (bloques básicos → advanced).
- **Fase 3**: portar features periféricas (tray, hotkeys, notificaciones, PDF/media, etc.).
- **Fase 4**: integrar Folio Cloud (si se quiere conservar en desktop).

La IA debe priorizar lo “core” para evitar quedar atrapada en UI sin tener base de datos, persistencia o modelo estable.

---

## 2. Requisitos no negociables

### 2.1. Local-first y seguridad

- El vault debe seguir siendo **local por defecto**.
- Si existe cifrado, debe mantenerse el estándar (p. ej., AES-GCM + derivación de clave robusta) y el modelo de amenaza debe estar documentado.
- Todo acceso a disco debe pasar por APIs controladas (evitar fugas, evitar escribir en ubicaciones inseguras).

### 2.2. No hardcodear texto

Regla del workspace: **no se puede hardcodear texto**; hay que usar y actualizar ficheros de localización.

En Electron esto implica:

- Elegir un sistema i18n (por ejemplo: `i18next`, `react-intl`, `lingui`, etc.).
- Centralizar claves, pluralización y formato de fechas.
- Evitar strings directos en componentes UI.

### 2.3. Documentación

Regla del workspace: después de cambios sustanciales, documentar en `docs/FEATURES.md` (o el lugar equivalente que use el repo).

---

## 3. Arquitectura objetivo en Electron

### 3.1. Propuesta de stack (recomendado)

- **Electron** (main process): ventanas, tray, menús, atajos globales, actualizaciones, file dialogs, IPC seguro.
- **Renderer** (UI):
  - Preferible **React + TypeScript** (por escalabilidad y tooling).
  - Alternativas: Svelte/Vue si el equipo lo prefiere, pero React suele ser el camino “menos sorpresas” para IA + ecosistema.
- **Estado**:
  - `zustand`/`redux`/`jotai`/`mobx` según preferencia; para IA conviene algo simple y explícito.
- **Persistencia**:
  - Opción A: **SQLite** (p. ej. `better-sqlite3` o `sqlite` + migraciones).
  - Opción B: **archivos JSON + índices** (solo si el modelo es simple; aquí probablemente NO lo es).
  - Opción C: **LevelDB** (`level`) para KV + índices manuales.
  - Recomendación: **SQLite** por búsquedas y consistencia.
- **Crypto**:
  - Node `crypto` + libs auditadas.
  - Evitar inventarse formatos; documentar KDF y parámetros.
- **Editor**:
  - Bloques: React + layout virtualizado (listas grandes).
  - Texto rico: ProseMirror/Tiptap/Lexical/Slate (elegir una).
  - Markdown + AST: `remark`/`mdast` si se conserva Markdown como storage.

### 3.2. Separación por procesos

- **Main**:
  - Control de ventana (maximize/minimize), tray, global shortcuts, actualizaciones.
  - Acceso a FS si se decide no exponer directamente al renderer.
- **Preload**:
  - API mínima expuesta al renderer (contextBridge).
  - Validación/serialización de mensajes IPC.
- **Renderer**:
  - UI, editor, lógica de interacción.
  - Nunca acceso “libre” a Node si se habilita `contextIsolation`.

### 3.3. Seguridad Electron (mínimos)

- `contextIsolation: true`
- `nodeIntegration: false` (en renderer)
- IPC “allowlist”: no exponer `fs` genérico; exponer funciones específicas.
- Sanitizar contenido HTML (publicación web / embeds).

---

## 4. Mapeo Flutter → Electron (por área)

Esta sección es la “tabla mental” para que la IA sepa dónde traducir cada concepto.

### 4.1. UI general (Material/Widgets → Web UI)

- Flutter widgets → componentes React (o framework elegido).
- Tema (claro/oscuro/OLED) → CSS variables + tokens (similar a `ui_tokens.dart`).
- Escala UI (`uiScale`) → `rem` base + scaling global, o zoom controlado.

### 4.2. Bandeja del sistema (tray)

Flutter: `tray_manager`

Electron: `Tray`, `Menu`, `nativeImage`.

Checklist:

- icono tray (Windows) + menú “Abrir / Buscar / Bloquear / Cerrar”.
- “Minimizar a bandeja” configurable (persistencia de setting).

### 4.3. Hotkeys globales

Flutter: `hotkey_manager`

Electron: `globalShortcut` + atajos por ventana (`Menu` o listeners en renderer).

Nota: globalShortcut requiere gestión cuidadosa de conflictos con el SO.

### 4.4. Notificaciones de escritorio

Flutter: `local_notifier`

Electron: `new Notification()` (o `node-notifier` / notificaciones nativas según OS).

### 4.5. File picker / drag & drop

Flutter: `file_picker`, `desktop_drop`

Electron:

- `dialog.showOpenDialog`
- Drag & drop HTML5 + `ipcRenderer` para “importar”

### 4.6. PDF viewer

Flutter: Syncfusion PDF Viewer.

Electron:

- Opción A: `pdf.js` en renderer.
- Opción B: abrir PDF en ventana/OS.
- Opción C: embed webview (menos control).

### 4.7. Web embeds / webview

Flutter: `webview_flutter`, `webview_windows`

Electron:

- `<webview>` (con cautela, permisos, sandbox).
- `BrowserView`/`WebContentsView` en main.
- Preferir iframes “sanitizados” cuando aplique.

### 4.8. Audio/video

Flutter: `video_player`, `audioplayers`, `record`

Electron:

- Playback: `<audio>`/`<video>` HTML + MediaSource si hace falta.
- Grabación: `navigator.mediaDevices.getUserMedia` + MediaRecorder.
- Sistema audio capture: complejo (depende OS) → fase tardía o usar librerías nativas.

### 4.9. Firebase y backend Folio Cloud (opcional)

Flutter usa Firebase en desktop con limitaciones (por ejemplo, `cloud_functions` no fiable en Windows/Linux y fallback HTTP).

Electron opciones:

- Usar **Firebase Web SDK** en renderer (Auth/Firestore/Storage).
- Para callables y endpoints, usar fetch HTTP con ID token (similar al fallback existente).
- Para seguridad: seguir “cliente no confiable”: reglas + Functions (Admin SDK) mantienen autoridad.

### 4.10. Microsoft Store / Stripe

En Flutter hay integración específica MS Store en Windows + backend que valida entitlements.

En Electron:

- Stripe: más directo (web checkout + webhooks server).
- Microsoft Store: puede requerir integración WinRT/bridge nativo; probablemente fase avanzada.

---

## 5. Plan de migración por fases (ejecutable por IA)

### Fase 0 — Preparación del proyecto Electron

**Objetivo**: repositorio con `apps/electron` (o carpeta raíz `electron/`) listo para compilar, con una app mínima.

Entregables:

- `package.json` (workspace si conviene) + scripts `dev`, `build`.
- `electron/main.ts`, `electron/preload.ts`, `renderer/` con UI mínima.
- Infra de lint/format.
- Ruta de datos de usuario: `app.getPath('userData')`.

Criterios de aceptación:

- `npm run dev` abre ventana.
- Hot reload o rebuild rápido.
- No hay `nodeIntegration` en renderer.

### Fase 1 — Persistencia base y “Vault mínimo”

**Objetivo**: poder crear/abrir un vault, listar páginas y abrir una página con bloques *simples*.

Entregables:

- Modelo de datos: `Vault`, `Page`, `Block`.
- Persistencia: SQLite (o decisión final) + migraciones.
- API IPC: `vault.create/open/lock/unlock`, `pages.list/open/save`.

Criterios de aceptación:

- Crear vault → reiniciar app → el vault sigue.
- Crear página con 3 bloques simples → reabrir → se mantiene.

### Fase 2 — Editor incremental (bloques básicos)

Orden sugerido:

1. `paragraph` (texto plano) + `h1/h2/h3`
2. `bullet`, `numbered`, `todo`
3. `quote`, `divider`, `callout`, `toggle`
4. Pegado markdown multilínea → parse a bloques

Criterios:

- Undo/redo por página (aunque sea básico al inicio).
- Navegación con teclado para crear bloques.
- Persistencia estable.

### Fase 3 — Bloques avanzados y vistas dedicadas

Orden sugerido:

- `code` con highlight
- `table` y `database` (beta)
- `kanban` (vista dedicada)
- `canvas` (vista dedicada)
- `bookmark`, `embed`
- `file`, `image`, `video`, `audio`, `pdf`

### Fase 4 — Features de escritorio

- Tray
- Hotkeys globales remapeables
- Notificaciones
- Auto-update (según canal)

### Fase 5 — Folio Cloud (si aplica)

- Firebase Auth + perfil `users/{uid}`
- Entitlements + gating en UI
- Cloud backup (Storage + list)
- IA Cloud (callables/HTTP)
- Publish web
- Collab realtime (si se mantiene)

---

## 6. Inventario de “hard parts” (riesgos + mitigación)

### 6.1. Editor (lo más caro)

Riesgo: reimplementar editor tipo Notion con buen UX consume meses.

Mitigación:

- Port incremental por bloques.
- Elegir un motor de texto rico y no reinventar selección/IME.
- Virtualización de lista para páginas grandes.

### 6.2. Canvas

Riesgo: motor de canvas (pan/zoom, nodos, conectores, trazos) es un proyecto en sí.

Mitigación:

- Usar un engine existente (Konva/Fabric/Pixi) y encapsular.
- Mantener formato de datos separado.

### 6.3. Sync P2P

Riesgo: multicast + TCP + conflictos implica networking “de verdad”.

Mitigación:

- Migrarlo “tal cual” como servicio Node en main (UDP/TCP).
- Aislarlo detrás de una interfaz.
- Empezar con export/import snapshot antes de sync realtime.

### 6.4. Firebase en desktop

Riesgo: diferencias entre Web SDK y Flutter SDK (y reglas / IAM).

Mitigación:

- Usar Web SDK (es el camino “first-class” en desktop-web tech).
- Reusar endpoints HTTP con ID token donde haga falta.

---

## 7. Diseño de datos: Vault, páginas, bloques, historial

### 7.1. Principio

Antes de UI compleja, fijar:

- Identificadores estables (`uuid`).
- Formato de persistencia.
- Migraciones.
- Versionado del esquema.

### 7.2. Recomendación de modelo en Electron

- `vaults` (tabla): metadata, estado cifrado, configuración.
- `pages` (tabla): id, parentId, title, icon, timestamps.
- `blocks` (tabla): pageId, blockId, type, text, props JSON, orderIndex.
- `page_revisions` (tabla): snapshot/patch con timestamps (según estrategia).

### 7.3. Historial + undo/redo

Separar:

- **Historial de versiones** (persistente, auditable).
- **Undo/redo** (ephemeral por sesión, pero puede persistirse para resiliencia).

---

## 8. Editor: estrategia de port

### 8.1. “Bloques como lista”

El editor de Folio es un “stack de bloques” con múltiples tipos.

En React:

- Lista virtualizada (p. ej. `react-virtual`).
- Cada bloque es un componente con contrato: `render`, `serialize`, `handleKeyDown`, `onChange`.

### 8.2. Texto rico y Markdown

En Flutter hay persistencia dual Markdown + Delta JSON (Quill).

Opciones en Electron:

- Mantener Markdown como verdad + un editor WYSIWYG que compile a Markdown.
- Mantener un formato tipo Delta (Quill) + export a Markdown.
- Elegir uno como “source of truth” para evitar drift.

Recomendación para minimizar sorpresas:

- Empezar con **Markdown como truth** para bloques textuales.
- Cuando haya paridad, evaluar dual persistence si hace falta (compatibilidad o performance).

---

## 9. IA local y IA Cloud

### 9.1. IA local (Ollama / LM Studio)

En Electron: son endpoints HTTP locales, por lo que es directo:

- Renderer hace fetch a `http://127.0.0.1:11434` / `http://127.0.0.1:1234` (con controles y timeouts).
- Política de seguridad centralizada (validar URL, bloquear hosts no locales si el usuario lo quiere).

### 9.2. IA Cloud (Folio Cloud)

Mantener el principio: **cliente no confiable**.

- El renderer obtiene ID token (Firebase Auth).
- Las llamadas a functions se hacen por HTTP con `Authorization: Bearer`.
- El servidor decide entitlements, tinta, etc.

---

## 10. Sync P2P y colaboración

### 10.1. Sync P2P

En Node (main process) es viable:

- UDP multicast discovery (similar a Flutter).
- TCP data transfer.
- Conflictos: mantener fingerprint y baseline.

### 10.2. Colaboración (Firestore)

Se puede mantener usando Firestore Web SDK:

- rooms en `collabRooms/{roomId}` + mensajes cifrados E2E.
- Upload media cifrado a Storage.

---

## 11. Localización (i18n) y “no hardcodear”

### 11.1. Requisito

No introducir texto hardcodeado en UI Electron.

### 11.2. Propuesta

- `locales/en.json`, `locales/es.json` (o formato ICU si la librería lo requiere).
- Helper `t('key')` + `Trans`/componentes.
- Fechas: `Intl.DateTimeFormat` con locale activo.

### 11.3. Checklist anti-hardcode

- Todo label/button/placeholder en UI debe venir de `t()`.
- Los mensajes de error también (al menos los user-facing).
- Las “strings técnicas” deben mapearse a un mensaje localizado.

---

## 12. Distribución, auto-update e instaladores

### 12.1. Canales

- Windows: instalador (NSIS/MSIX), o distribuir con auto-update según política.
- macOS: DMG + firma/notarización (si aplica).
- Linux: AppImage/deb/rpm (según target).

### 12.2. Herramientas

- `electron-builder` o `electron-forge`.
- Auto-update: `electron-updater` o equivalente.

---

## 13. Estrategia de pruebas y verificación

### 13.1. Tests recomendados

- Unit tests: modelo de datos, parser de markdown, crypto.
- Integration: persistencia SQLite, migraciones.
- E2E: flujos “crear vault → crear página → editar → reiniciar”.

### 13.2. Verificación de paridad

Usar `docs/FEATURES.md` como “lista maestra”:

- Marcar cada feature como: **No portado / Parcial / Portado / Portado+verificado**.

---

## 14. Prompts y plantillas para agentes

> Nota: estos prompts asumen un agente con acceso al repo y capacidad de editar archivos.

### 14.1. Prompt base (arquitectura)

“Explora el repo Flutter y propone una arquitectura Electron segura con main/preload/renderer. No hardcodees strings; usa i18n desde el inicio. Crea estructura mínima compiland o. Devuelve un plan por commits.”

### 14.2. Prompt (modelo de datos)

“Implementa el modelo Vault/Page/Block en TypeScript con SQLite y migraciones. Añade APIs IPC mínimas para crear/abrir vault y listar/guardar páginas. Incluye tests de persistencia.”

### 14.3. Prompt (editor incremental)

“Implementa editor de bloques con React: lista virtualizada, bloques paragraph/h1/h2/h3 + persistencia. Añade undo/redo por página. No hardcodees strings.”

---

## 15. Definición de “Done” (por fase)

### Done Fase 1

- Vault persistente, páginas y bloques básicos persistentes.
- UI mínima con navegación y edición simple.
- i18n operativo y sin strings hardcodeadas.

### Done Fase 2

- Editor usable con bloques básicos y comportamiento de teclado razonable.
- Import/export markdown básico.

### Done final (migración completa)

- Paridad funcional con el inventario de `docs/FEATURES.md` (o aceptación explícita de recortes).
- Seguridad Electron validada (contextIsolation, IPC mínimo).
- Build + instaladores funcionando.

