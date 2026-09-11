/// Versión de esquema actual para todos los documentos JSON persistidos por
/// [ConfigStore] (LayoutConfig, ThemeConfig, DashboardConfig, manifest de pack).
const int kFolioConfigSchemaVersion = 1;

/// Registro real de migraciones enhebrado en [ConfigStore]. Vacío hoy porque
/// todo lo añadido hasta ahora sigue la política aditivo-nullable-con-default
/// (no requiere reescribir documentos guardados) — pero a diferencia de antes
/// de la Fase 12, [ConfigStore._decode] SÍ pasa este registro a
/// [runMigrations], así que una migración real registrada aquí se ejecutaría
/// de verdad en producción. Añadir una entrada aquí es lo único que hace
/// falta el día que una fase futura necesite un renombre/reestructuración
/// genuino en vez de un campo aditivo.
const List<ConfigMigration> kFolioConfigMigrations = [];

/// Una migración lineal de un documento JSON de [fromVersion] a [fromVersion] + 1.
class ConfigMigration {
  const ConfigMigration({required this.fromVersion, required this.migrate});

  final int fromVersion;
  final Map<String, dynamic> Function(Map<String, dynamic> json) migrate;
}

/// Aplica migraciones registradas en [registry] de forma secuencial hasta
/// alcanzar [targetVersion]. Si el documento ya está en (o por encima de)
/// [targetVersion], lo devuelve sin cambios. Si falta una migración para
/// avanzar (p. ej. un documento viene de una versión futura desconocida),
/// devuelve el documento tal cual en vez de lanzar — degradar es más seguro
/// que corromper datos del usuario.
Map<String, dynamic> runMigrations(
  Map<String, dynamic> json,
  int targetVersion, {
  List<ConfigMigration> registry = const [],
}) {
  var current = Map<String, dynamic>.from(json);
  var version = (current['schemaVersion'] as num?)?.toInt() ?? 0;

  while (version < targetVersion) {
    ConfigMigration? next;
    for (final migration in registry) {
      if (migration.fromVersion == version) {
        next = migration;
        break;
      }
    }
    if (next == null) {
      // No hay migración registrada para este salto: no podemos avanzar de
      // forma segura, devolvemos lo que tenemos en vez de intentar adivinar.
      break;
    }
    current = next.migrate(current);
    current['schemaVersion'] = version + 1;
    version += 1;
  }

  return current;
}
