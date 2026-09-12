/// Decide si un push de device-sync debe omitirse por sospecha de vaciado
/// accidental: el payload local no tiene páginas, pero hay evidencia de que
/// la libreta ya tenía contenido (fingerprint/blobs propios ya confirmados,
/// o un remoto ya poblado). Una libreta recién creada y legítimamente vacía
/// no tiene esa evidencia previa, así que su primer push no se bloquea.
bool shouldSkipEmptyDeviceSyncPush({
  required bool payloadHasPages,
  required bool hadPriorContent,
}) => !payloadHasPages && hadPriorContent;

/// Decide si un push debe omitirse porque el payload en memoria tiene muchas
/// menos páginas que el árbol en disco de la misma libreta — señal de que la
/// libreta no se cargó del todo en memoria antes de exportar (p. ej. una
/// carrera de carga) en vez de un borrado real del usuario. Mismo umbral que
/// `VaultSyncMergeEngine.looksSuspiciouslyPartial`/
/// `VaultLocalStorage.looksLikePartialOverwrite`: por debajo del 40% de lo
/// que hay en disco, con un mínimo de 4 páginas en disco.
bool shouldSkipSuspiciouslyPartialDeviceSyncPush({
  required int payloadPageCount,
  required int onDiskPageCount,
}) {
  if (onDiskPageCount < 4) return false; // libreta pequeña: sin heurística de %
  if (payloadPageCount == 0) return false; // lo cubre shouldSkipEmptyDeviceSyncPush
  return payloadPageCount <= (onDiskPageCount * 0.4).ceil();
}
