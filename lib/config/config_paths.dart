/// Categorías conceptuales de configuración de personalización, mapeadas a
/// `Folio/<categoría>/<id>.json` en nativo (dentro del directorio sandbox de
/// la app) o a un object store de IndexedDB por categoría en web.
///
/// Puramente Dart (sin dart:io/dart:html) para que ambos backends
/// (`config_store_backend_io.dart`, `config_store_backend_web.dart`) puedan
/// importarlo sin necesitar su propio gateway condicional.
enum ConfigCategory { themes, layouts, dashboards, widgets, packs }

extension ConfigCategoryFolder on ConfigCategory {
  /// Nombre de carpeta (nativo) / object store (web) para esta categoría.
  String get folderName {
    switch (this) {
      case ConfigCategory.themes:
        return 'themes';
      case ConfigCategory.layouts:
        return 'layouts';
      case ConfigCategory.dashboards:
        return 'dashboards';
      case ConfigCategory.widgets:
        return 'widgets';
      case ConfigCategory.packs:
        return 'packs';
    }
  }
}

/// Carpeta contenedora bajo el directorio sandbox de la app (mismo nivel que
/// `folio_vaults`, ver `vault_storage_io.dart`).
const String kFolioConfigContainer = 'folio_config';
