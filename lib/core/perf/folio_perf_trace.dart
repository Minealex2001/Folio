import '../../services/app_logger.dart';

/// Instrumentación de rendimiento **opt-in** (Fase 2 del plan de performance).
///
/// Objetivo: medir el coste real de persistencia, serialización, escritura a
/// disco, reconstrucción del índice de búsqueda y procesamiento del editor
/// **sin cambiar ningún comportamiento de producción**.
///
/// ## Coste cero en release
///
/// [enabled] es un `const bool.fromEnvironment`. Cuando vale `false` (el caso
/// por defecto y el de cualquier build de release que no pase el define), el
/// compilador AOT hace *tree-shaking* de todas las ramas guardadas por
/// `if (FolioPerfTrace.enabled)` y [begin] se pliega a `return null` sin
/// asignar ningún `Stopwatch`. No hay logging, ni acumuladores, ni closures.
///
/// ## Activación
///
/// ```
/// flutter run  --dart-define=FOLIO_PERF_TRACE=true
/// flutter test --dart-define=FOLIO_PERF_TRACE=true
/// ```
///
/// Las líneas salen por `AppLogger.debug(tag: 'perf')`, visibles en la
/// consola de `flutter run`. Formato:
///
/// ```
/// folio.perf [DEBUG] perf persistV1 | ctx={"pages":250,"blocks":7500,
///   "total_ms":"812.4","buildPayload_ms":"3.1","decomposeStore_ms":"640.2",
///   "searchIndexRebuild_ms":"165.7"}
/// ```
class FolioPerfTrace {
  const FolioPerfTrace._();

  /// Interruptor maestro. Compile-time const → coste cero cuando es `false`.
  static const bool enabled =
      bool.fromEnvironment('FOLIO_PERF_TRACE', defaultValue: false);

  /// `Stopwatch` ya arrancado si la traza está activa; `null` si no (sin
  /// asignación de objeto cuando está desactivada).
  static Stopwatch? begin() => enabled ? (Stopwatch()..start()) : null;

  /// Microsegundos transcurridos de [sw] (0 si es `null`). No detiene el
  /// cronómetro, así se puede llamar varias veces para tiempos parciales.
  static int us(Stopwatch? sw) => sw == null ? 0 : sw.elapsedMicroseconds;

  /// Formatea microsegundos como milisegundos con un decimal.
  static String ms(int micros) => (micros / 1000).toStringAsFixed(1);

  /// Emite una línea estructurada bajo el tag `perf`. No-op si está
  /// desactivada (y el `if (enabled)` de arriba ya lo habrá tree-shakeado en
  /// los llamadores).
  static void log(String op, Map<String, Object?> fields) {
    if (!enabled) return;
    AppLogger.debug('perf $op', tag: 'perf', context: fields);
  }

  /// Acumulador de desglose para el `decompose` del formato v1.
  ///
  /// `decomposeAndStoreAt` crea uno al entrar (solo si [enabled]) y lo pone
  /// aquí; las funciones internas (`_writeAtomic`, bucle de serialización de
  /// bloques) suman en él si no es `null`; al salir se lee y se limpia. Las
  /// llamadas a `decompose` están serializadas por `runExclusive` y nunca se
  /// anidan dentro del mismo isolate, así que un único slot global basta.
  static DecomposePerf? decompose;
}

/// Contadores de una sola pasada de `decomposeAndStoreAt` (formato v1).
/// Todos los tiempos en microsegundos.
class DecomposePerf {
  /// Tiempo dentro de `canonicalJson(...)` (ordenación de claves + `jsonEncode`)
  /// para meta + bloques + comentarios de todas las páginas.
  int serializeUs = 0;

  /// Tiempo dentro de `_writeAtomic` (escribir `.tmp` con flush + borrar +
  /// renombrar) sumado sobre todos los ficheros del árbol.
  int writeUs = 0;

  /// Nº de ficheros escritos por `_writeAtomic`.
  int fileCount = 0;

  /// Nº de páginas del payload.
  int pageCount = 0;
}
