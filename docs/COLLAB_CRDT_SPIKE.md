# Spike: CRDT para edición concurrente en salas de colaboración

Decisión de librería para la Fase 4 del plan de mejoras de colaboración (ver
`services/collab/`). Este documento reemplaza el prototipo completo de dos semanas
descrito originalmente por una verificación de viabilidad en pub.dev — antes de
invertir en el prototipo real hay que confirmar que ambos candidatos existen y
qué tan maduros/costosos son.

## Candidatos verificados (pub.dev, 2026-07-30)

| | `y_crdt` | `crdt_lf` |
|---|---|---|
| Versión | 0.2.0 (recién publicada) | 3.4.2+1 |
| Naturaleza | Puerto Dart de Yjs, motor Rust vía WASM | Puro Dart |
| Dependencias | `wasm_run` + `wasm_wit_component` (runtime WASM por plataforma) | Ninguna dependencia nativa |
| Texto | Yjs `Y.Text` (maduro, probado en producción vía Yjs JS) | `CRDTFugueTextHandler` (algoritmo Fugue, minimiza interleaving) |
| Orden causal | Yjs interno | Hybrid Logical Clock (HLC) |
| Otros tipos | Map/Array/etc. de Yjs | List, Map, Set, Register — variantes Fugue/OR |

## Recomendación: `crdt_lf`, no `y_crdt`

Razones:

1. **Sin bundling WASM.** Folio ya tiene un pipeline de build multiplataforma
   complejo (Windows MSIX, macOS, Linux, Android, iOS, Web — ver
   `builld_all.ps1`, `installer.iss`, `msix_config` en `pubspec.yaml`).
   `y_crdt` añadiría runtime WASM compilado en Rust por plataforma; `crdt_lf`
   no añade nada nativo.
2. **`y_crdt` es demasiado inmaduro para este uso.** Versión 0.2.0 recién
   publicada — alto riesgo de bugs/breaking changes para algo tan crítico
   como la integridad del contenido de las páginas.
3. **`crdt_lf` ya trae un handler de texto pensado para esto.**
   `CRDTFugueTextHandler` usa el algoritmo Fugue específicamente para
   minimizar el interleaving en ediciones concurrentes de texto — es el
   caso de uso central de la Fase 4, no un ajuste genérico.

## Lo que `crdt_lf` NO resuelve por sí solo

`CRDTFugueTextHandler` mergea la *secuencia de caracteres*, no los atributos
de formato de Quill (negrita, cursiva, links) que vive en
`FolioBlock.richTextDeltaJson`. Sigue haciendo falta la capa propia descrita
en el plan: preservar spans de formato con una estrategia simple
(last-write-wins por span), y tests reales de ediciones concurrentes con
formato antes de confiar en el merge.

## Qué falta antes de integrar en el cliente (no incluido en este spike)

- Prototipo real con `flutter_quill` + `crdt_lf`: dos ediciones concurrentes
  sobre el mismo bloque → merge → reconversión a Quill Delta con formato
  intacto.
- Medir tamaño de un update binario típico cifrado (mismo `_seal` de
  `collab_e2e_crypto.dart`) sobre el canal STOMP.
- Diseño de la capa de diff (`diff_match_patch`, ya usado en
  `sync_block_text_merge.dart`) que traduce el snapshot debounced actual en
  operaciones insert/delete que `crdt_lf` pueda consumir — ver la sección
  "Por qué no es un simple cambiar de librería" en el plan de colaboración.

Groundwork de protocolo (migración, relay ciego backend) para esta fase está
implementado ya en `FolioBackend` — ver `V115__collab_room_crdt.sql` y
`CollabCrdtWebSocketController`. El servidor no depende de qué librería CRDT
elija el cliente: solo almacena/retransmite blobs cifrados opacos.
