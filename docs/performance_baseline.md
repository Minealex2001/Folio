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
