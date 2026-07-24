/// Decide si un push de device-sync debe omitirse por sospecha de vaciado
/// accidental: el payload local no tiene páginas, pero hay evidencia de que
/// la libreta ya tenía contenido (fingerprint/blobs propios ya confirmados,
/// o un remoto ya poblado). Una libreta recién creada y legítimamente vacía
/// no tiene esa evidencia previa, así que su primer push no se bloquea.
bool shouldSkipEmptyDeviceSyncPush({
  required bool payloadHasPages,
  required bool hadPriorContent,
}) => !payloadHasPages && hadPriorContent;
