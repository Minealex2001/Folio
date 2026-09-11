# Performance baseline (P0)

Parte del track continuo obligatorio de Performance & Reliability del roadmap
de 19 ideas de producto. Estos números son el punto de comparación
"antes → después" para todas las fases posteriores — no son umbrales de
aprobación/fallo, son la referencia contra la que se juzga si una fase
introdujo una regresión perceptible.

Capturado: 2026-08-09, en Windows desktop (`flutter run -d windows --profile`),
máquina de desarrollo local (no CI, no hardware de referencia estandarizado —
reproducir en la misma máquina para comparaciones válidas).

## Cómo reproducir

```bash
# Cold start
flutter run -d windows --profile --trace-startup

# Índice de búsqueda / latencia de búsqueda
flutter test test/performance/search_index_benchmark_test.dart --reporter expanded
```

## Números

| Métrica | Valor | Método |
|---|---|---|
| Cold start (time to first frame) | **78.5 ms** (raster completo: 107.3 ms; framework init: 36.5 ms) | `flutter run --profile --trace-startup`, `build/start_up_info.json` |
| Indexar vault grande (500 páginas x 40 bloques = 20.000 bloques) | **6 ms** | `test/performance/search_index_benchmark_test.dart` |
| Búsqueda sobre vault grande ya indexado (por query) | **41–60 ms** | mismo test, 4 queries distintas |
| Apertura de página | *(no medido — ver Gaps)* | — |
| Editor con muchos bloques (render) | *(no medido — ver Gaps)* | — |
| Memoria idle | *(no medido — ver Gaps)* | — |
| Canvas grande / Graph grande | *(no medido — ver Gaps)* | — |
| Sincronización | *(no medido — ver Gaps)* | — |
| Latencia de Quill | *(no medido — ver Gaps)* | — |
| Batería en móvil | *(no medido — ver Gaps)* | — |

## Lectura de los números capturados

- **Cold start (78.5ms hasta el primer frame)**: rápido en Windows desktop
  release-like (`--profile`). Nota: esta build corría sin sesión Cloud
  activa (refresh token inválido en la máquina de desarrollo) — los
  reintentos de autenticación observados en el log de arranque son
  asíncronos y no bloquean el primer frame, pero si en producción llegaran a
  bloquear el arranque en vez de degradar en segundo plano, sería una
  regresión real a vigilar en fases que toquen Cloud/sync.
- **Indexado (6ms para 20k bloques)**: rápido, no es un cuello de botella
  hoy incluso para vaults grandes.
- **Búsqueda (41–60ms por query)**: más alto de lo que parece a primera
  vista — es un escaneo lineal (`VaultSearchIndex.search`, sin índice
  invertido) sobre las 500 páginas por cada query. Con vaults aún más
  grandes esto degradaría de forma proporcional. `DriftCacheEvaluation` en
  `lib/application/vault_search_index.dart` ya señala explícitamente el
  umbral (>500 páginas o búsqueda >200ms) a partir del cual reconsiderar un
  índice FTS en disco vía Drift — este benchmark confirma que estamos cerca
  de ese umbral con vaults grandes, útil como señal temprana para la Fase 1
  del roadmap (Search & Command Center).

## Gaps — qué falta y por qué no se midió aquí

Este benchmark se acotó deliberadamente a lo medible en Dart puro sin un
harness de UI (`VaultSearchIndex` no depende de widgets). Medir con
precisión "abrir página", "editor con muchos bloques" (render real),
"Canvas grande", "Graph grande", "sincronización" y "latencia de Quill"
requiere un harness de `integration_test` que levante la app real y accione
la UI — el proyecto no tiene ese paquete ni esa infraestructura hoy
(`pubspec.yaml` no incluye `integration_test`). Construirlo es trabajo real,
no una medición de una tarde: es su propio spike dentro de la Fase 7
(Product Polish) o antes si una fase concreta lo necesita para justificar
una decisión de arquitectura.

"Memoria idle" y "batería en móvil" requieren perfilado de proceso en vivo
(Task Manager / Instruments / Android Profiler) sobre una sesión real de
uso, no solo el arranque — se deja pendiente de una pasada manual con la
app en uso normal, no un número de un solo proceso recién lanzado.

## Próxima actualización

Cuando exista el harness de `integration_test` (Fase 7C o antes), añadir
aquí: tiempo de apertura de página, render de documento de 1k/10k/50k
bloques, Canvas grande, Graph grande, latencia end-to-end de un turno de
Quill, y memoria en uso normal (no solo en frío).

---

## Fase 2 (2026-09-07) — Baseline de PERSISTENCIA

Investigación "por qué Folio se congela en hardware limitado". Máquina de
desarrollo (SSD rápido) — en el portátil corporativo objetivo (disco cifrado
+ antivirus escaneando cada fichero) el componente de I/O será varias veces
mayor.

### Cómo reproducir

```bash
flutter test test/performance/persistence_benchmark_test.dart --reporter expanded
# Instrumentación en vivo (app real):
flutter run -d windows --profile --dart-define=FOLIO_PERF_TRACE=true
#   → líneas `folio.perf [DEBUG] perf <op> | ctx={...}` en consola
```

### Números: `decomposeAndStoreAt` (guardado v1 completo)

Es lo que dispara el debounce de 450 ms del editor tras cada pausa de
escritura, **en el UI isolate**. Reescribe `meta.json` + `blocks.jsonl` de
**todas las páginas** de la libreta, más borrado recursivo de `repo.tmp` y
doble rename de directorio.

| Libreta (30 bloques/página) | serialización pura (CPU) | `decomposeAndStoreAt` total | `rebuildSearchIndex` |
|---|---|---|---|
| 25 páginas (750 bloques)   | 2.9 / 4.0 / 5.3 ms   | **139.7 / 148.9 / 158.5 ms**   | 0.1 ms |
| 50 páginas (1.5k bloques)  | 4.5 / 5.0 / 5.8 ms   | **258.6 / 264.1 / 267.8 ms**   | 0.1 ms |
| 100 páginas (3k bloques)   | 8.8 / 9.3 / 9.6 ms   | **509.4 / 525.8 / 554.5 ms**   | 0.2 ms |
| 250 páginas (7.5k bloques) | 23.5 / 24.3 / 25.1 ms | **1242.9 / 1301.3 / 1468.3 ms** | 0.3 ms |
| 500 páginas (15k bloques)  | 46.9 / 48.9 / 50.6 ms | **2442.0 / 2579.2 / 2667.1 ms** | 0.6 ms |

(min / avg / max sobre 5 iteraciones + 1 de calentamiento descartada.)

### Desglose interno (instrumentación `FOLIO_PERF_TRACE`, ~59 páginas)

`work ≈ 335 ms` = `writeAtomic ≈ 285 ms` (**~85 %**) + `other ≈ 48 ms`
(borrado recursivo `repo.tmp` + `create` + doble `rename`, **~14 %**) +
`serialize ≈ 6 ms` (**~2 %**).

### Lectura

- **El coste es I/O secuencial, no CPU.** `_writeAtomic` (escribe `.tmp` con
  `flush: true` → fsync, borra el viejo, renombra) se ejecuta **2 veces por
  página, para todas las páginas, con `await` en serie** en cada guardado.
  ~5 ms/página, ~lineal.
- **La serialización (`canonicalJson`) es barata** (~2 %). Mover a un isolate
  solo la serialización no arreglaría nada.
- **`rebuildFromPages` no es un cuello de botella** en estado estacionario
  (sub-ms; los 6–7 ms del baseline de Fase 0 eran warm-up de la primera
  llamada). Revisa a la baja la hipótesis S2.
- **Umbral problemático:** a partir de ~25–50 páginas el guardado ya supera
  varios frames (>16 ms × N). A ~100 páginas (~525 ms aquí, probablemente
  >1 s en el portátil objetivo) cada pausa de escritura produce una
  congelación perceptible. La libreta del usuario está casi con certeza por
  encima de ese punto.

### Instrumentación añadida (opt-in, coste cero en release)

`lib/core/perf/folio_perf_trace.dart` — flag `bool.fromEnvironment('FOLIO_PERF_TRACE')`.
Puntos: `_doPersistV1`, `decomposeAndStoreAt` / `_writeAtomic` / bucle de
serialización, `_rebuildSearchIndex`, editor `_onSession`, flush de Quill
(`documentToMarkdown` + `jsonEncode(toDelta)` + `updateBlockTextFull`).
Los tres últimos solo se ven ejecutando la app real con el define.

---

## Fase 3 (2026-09-07) — Persistencia incremental v1 (fix S1)

Una edición de contenido de una página existente ahora persiste solo esa
página (`VaultLocalStorage.storePageAt`) en vez de reescribir todo `repo/`.
Condiciones y salvaguardas: ver el informe de Fase 3 y los doc-comments de
`_tryIncrementalPersistV1` / `scheduleSave` en `vault_session.dart`.

### Coste de persistir una edición de contenido (misma máquina)

`flutter test test/performance/persistence_benchmark_test.dart`

| Vault (30 b/pág) | ANTES `decomposeAndStore` (full) | DESPUÉS `storePageAt` ×1 | DESPUÉS ×5 |
|---|---|---|---|
| 25 páginas  | 142.8 ms | **5.5 ms** (26×)  | 26.0 ms |
| 50 páginas  | 269.5 ms | **5.0 ms** (54×)  | 26.5 ms |
| 100 páginas | 579.0 ms | **5.0 ms** (116×) | 25.8 ms |
| 250 páginas | 1409 ms  | **5.6 ms** (250×) | 31.6 ms |
| 500 páginas | 2703 ms  | **5.6 ms** (480×) | 26.9 ms |

Propiedad clave: `storePageAt ×1` es **plano ~5 ms** de 25 a 500 páginas — el
coste de una edición dejó de escalar con el tamaño de la vault. `×N` (todas
las páginas por la vía incremental, peor caso) ≈ coste del guardado completo,
como se espera.

### Contadores de diagnóstico

`VaultSession.debugFullPersistV1Count` / `debugIncrementalPersistV1Count`
(`@visibleForTesting`) y modo `mode: incremental|full|incremental+reconcile`
en la línea `folio.perf perf doPersistV1` con `FOLIO_PERF_TRACE=true`.

---

## Fase 4 (2026-09-07) — Investigación Settings + Cloud (diagnóstico, sin optimizar)

### `directoryTotalFileBytes` (Ajustes › Vault/Backup)

`flutter test test/performance/settings_disk_usage_benchmark_test.dart`
(dev, SSD rápido):

| Árbol de libreta | ~ficheros | `directoryTotalFileBytes` (min/avg/max) |
|---|---|---|
| 50 pág, 0 snapshots     | 100  | 9.4 / 10.1 / 10.9 ms |
| 50 pág, 100 snapshots   | 300  | 22.5 / 26.7 / 31.9 ms |
| 250 pág, 0 snapshots    | 500  | 35.5 / 39.3 / 44.5 ms |
| 250 pág, 500 snapshots  | 1500 | 119.7 / 133.3 / 145.2 ms |
| 250 pág, 2000 snapshots | 4500 | 310.8 / **373.3** / 452.7 ms |

~0.08 ms/fichero. `versions/` (historial de snapshots) domina. Se ejecuta como
`future:` **creado dentro de `build()`** → se relanza en cada rebuild de la
sección Vault/Backup mientras está visible. En el portátil objetivo (SSD
empresarial + BitLocker + antivirus escaneando cada `stat`) ×3–10.

### Instrumentación añadida (opt-in, `FOLIO_PERF_TRACE`, coste cero en release)

- `VaultPaths.directoryTotalFileBytes` → `folio.perf perf vaultDirTotalFileBytes` (files, bytes, ms).
- `SettingsPage`: `_perfTracedLoad` envuelve las 5 cargas diferidas →
  `folio.perf perf settings.deferredLoad {load, total_ms}`; contadores
  `builds` / `cloudFolioNotifies` / `open_ms` → `folio.perf perf settings.lifetime` en `dispose`.

---

## Fase 4 · Paso 1 (2026-09-07) — Cambio 1 + Cambio 2 (implementados)

**Cambio 1** — `SettingsPage.build()` ya NO va envuelto en
`ListenableBuilder(listenable: _s)` (eliminado) y el `AnimatedBuilder(_app)`
se movió de envolver `PopScope/Scaffold/AppBar/rail` a envolver solo `body`.
Reactividad de `_s` reacotada a 3 sitios (banner de overview, sección Vault,
—la sección Sync no leía `_s` en build—).

**Cambio 2** — el uso de disco se cachea en `_diskUsageFuture` (campo del
State), calculado 1 vez al abrir + al cambiar `activeVaultId` +
`_refreshDiskUsage()` explícito. Antes: `future:` creado dentro de `build()`.

### Medido (widget test `settings_page_perf_decoupling_test.dart`, `FOLIO_PERF_TRACE=true`)

| Señal | Antes | Después |
|---|---|---|
| `_SettingsPageState.build()` por `VaultSession.notifyListeners()` | 1 rebuild del contenido completo (ListView + 9 secciones) por notify | **0** (`debugBuildCount` no cambia tras 5 notifies) |
| `_SettingsPageState.build()` por `AppSettings.notifyListeners()` | 1 rebuild de todo (chrome incluido) | **0 re-ejecuciones de `build()`**; solo el contenido (`AnimatedBuilder`) — appbar/rail intactos |
| `directoryTotalFileBytes` en entrada + 3 rebuilds normales | 1 (entrada) + 1 por rebuild de la sección Vault visible | **1** (identidad del `Future` estable entre rebuilds) |
| `directoryTotalFileBytes` al cambiar de libreta | recalcula | recalcula (1×) ✅ |
| `directoryTotalFileBytes` en refresh explícito | recalcula | recalcula (1×) ✅ |
| `settings.deferredLoad` (test env) | — | cloudBackupCount 0.3–4 ms · taskCapturePrefs/vaultBackupPrefs 0.6–5 ms · openDiagnosticReports 0.5–5 ms |

En el portátil objetivo, cada rebuild de la sección Vault ahorra el walk de
`repo/` + `versions/` (133–373 ms en dev SSD → ×3–10 con BitLocker+AV), y
cada `VaultSession.notifyListeners()` (typing coalesced, save-status, sync)
deja de reconstruir el árbol de ~5.000 líneas de Settings.

### Contadores/hooks de diagnóstico añadidos (`@visibleForTesting`)

`SettingsPage.debugBuildCount`, `VaultPaths.debugDirectoryTotalFileBytesCalls`,
`_SettingsPageState.debugDiskUsageFutureRef` / `debugRefreshDiskUsage()`.

### NO incluido en este paso (pendiente)

Cambio 3 (coalescing de cargas diferidas), Cambio 4 (construcción perezosa de
secciones), scoping por-widget de `_app`, cambios en `_refreshOpenDiagnosticReports`,
polling Cloud. El `AnimatedBuilder(_app)` sigue repintando el **contenido**
(no el chrome) en cada notify de `AppSettings` — se abordará con Cambio 4.

---

## Fase 4 · Paso 2 (2026-09-07) — Cambio 3 + Cambio 4 (implementados)

### Cambio 3 — coalescencia de las cargas diferidas

`_runDeferredInitIfNeeded()` disparaba ~8 cargas, cada una terminando en su
propio `_rebuild()` (`setState`). En el dispositivo, las que resuelven en
frames distintos producían un rebuild de `_SettingsPageState` cada una.

**Después:** las 5 cargas **locales rápidas** (`_refreshSecurityFlags`,
`_loadInstalledVersionInfo`, `_refreshReleaseReadiness`, `_loadTaskCapturePrefs`,
`_loadVaultBackupPrefs`) aplican su estado **sin repintar** (`_coalesceRebuilds`)
y hay **un único `setState` consolidado** cuando el grupo resuelve
(`Future.wait`, sub-10 ms — sin timers). *Failsafe* sin timers: un
`addPostFrameCallback` cierra la ventana en el primer frame pase lo que pase
(si una carga de plataforma se colgara, el resto repinta con normalidad).
Las cargas lentas/independientes (`_loadMeetingNoteDevices` — enum de audio,
`_refreshCloudBackupCount` — red, `_refreshOnDeviceAiInfo`) mantienen su
repaint propio. `_refreshOpenDiagnosticReports` **sin tocar**: usa `_rebuildNow`
(repaint inmediato, inmune a la coalescencia).

- **Metodología:** widget test `settings_page_perf_decoupling_test.dart`
  (tests 8-9) + `FOLIO_PERF_TRACE=true`. Estados finales verificados idénticos
  (`debugInstalledVersionLabel`, prefs de backup, flags de seguridad).
- **Medido (test env):** `settings.lifetime` `builds` = 3-4 (antes 2-3). En el
  harness las cargas ya se agrupaban en ~1 frame, así que el número no baja
  ahí; la ganancia real es en el portátil, donde las cargas locales que caían
  en frames separados (hasta 5 `setState` independientes) colapsan a 1.
- **Coste/riesgo:** el *failsafe* cierra la ventana a ~1 frame; si en el
  dispositivo alguna carga local tardara >1 frame, repinta por su cuenta
  (1 rebuild) — nunca más rebuilds que antes, a veces menos. Ninguna carga
  bloquea: `Future.wait` va con `catchError` por carga.

### Cambio 4 — construcción perezosa de las 9 secciones

**Antes:** `ListView(children: [ 9× Visibility(visible: activeSection == X,
maintainState: false, child: <subárbol de sección>) ])`. `Visibility` **no**
evita instanciar el `child`: los objetos Widget de las 8 secciones no activas
(cientos–1000+ cada una) se crean y se descartan en **cada `build()`**.

**Después:** `Visibility(...) → if (activeSection == X) KeyedSubtree(key: ...,
child: <subárbol>)`. La expresión del subárbol solo se evalúa si es la sección
activa. Mismas keys, misma navegación (`AnimatedSwitcher` + `ListView` keyeado
por sección), mismo contenido. Aplicado a las 6 secciones inline + las 3 de
método (`_buildAboutSection` / `_buildOrganizationSection` /
`_buildPersonalizationSection`, que ya recibían `activeSection`).

- **Metodología:** tests 10-11 — con Cloud activa, `find.byIcon` de la sección
  Vault (`Icons.menu_book_outlined`) → `findsNothing`; al seleccionar Vault en
  el rail, su subárbol aparece y el de Cloud desaparece.
- **Antes → después:** subárboles de sección instanciados por `build()` de
  Settings: **9 → 1**. Elimina la asignación + GC de ~8 subárboles por cada
  rebuild del contenido (que aún ocurre en cada notify de `AppSettings`).
  Esta es la mayor de las dos ganancias en el portátil objetivo.
- **Coste/riesgo:** ninguno de comportamiento. `Visibility(maintainState:false)`
  ya descartaba el estado al ocultar, así que `if` es equivalente. Riesgo
  residual: si algún código externo asumía que un `KeyedSubtree` de sección
  oculta seguía en el árbol de widgets (no de elementos) — no se encontró
  ningún caso; el `AnimatedSwitcher`/`ListView` keyeado ya hacía el swap real.

### Hooks de diagnóstico añadidos (`@visibleForTesting`)

`_SettingsPageState.debugCoalescingRebuilds`, `debugInstalledVersionLabel`.
`FOLIO_PERF_TRACE` intacto (`settings.deferredLoad`, `settings.lifetime`).

### Regresión

`flutter analyze` sin avisos nuevos. `settings_page_perf_decoupling_test`
11/11. `settings_page_smoke_test` 2/2. `test/session` + `test/data` +
`test/git` + `test/performance` → +245, 0 fallos.
`settings_page_personalization_section_test` → +2 −5 (los 5 son fallos
**preexistentes** por red HTTP 400 en el entorno de test; idéntico con y sin
Cambio 3+4, verificado aislando el fichero).
