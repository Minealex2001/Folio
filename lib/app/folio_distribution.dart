/// Canal de distribución en tiempo de compilación.
///
/// `flutter build ... --dart-define=FOLIO_DISTRIBUTION=github`
///
/// Valores reconocidos: [isGitHub], [isMicrosoftStore], [isPlayStore]. Cadena
/// vacía u otro valor = legado (p. ej. Windows puede ofrecer Microsoft Store
/// además de Stripe cuando el runtime lo permita).
abstract final class FolioDistribution {
  static const String raw = String.fromEnvironment(
    'FOLIO_DISTRIBUTION',
    defaultValue: '',
  );

  static String get _normalized => raw.trim().toLowerCase();

  /// Instalador u origen GitHub (sin integración Microsoft Store en la app).
  static bool get isGitHub => _normalized == 'github';

  /// MSIX / Partner Center.
  static bool get isMicrosoftStore => _normalized == 'microsoft_store';

  /// Build pensado para distribución en Google Play (Android).
  static bool get isPlayStore => _normalized == 'play_store';

  /// Comprobar versiones nuevas y descargar instalador/APK desde GitHub Releases.
  ///
  /// Falso en [isMicrosoftStore] e [isPlayStore]: las tiendas distribuyen actualizaciones.
  /// Las **notas de versión** del release en GitHub pueden seguir mostrándose en esos builds
  /// (solo lectura); ver [GitHubReleaseUpdater.fetchReleaseNotesForVersion].
  ///
  /// Verdadero en [isGitHub] y en modo legado (cadena vacía u otro valor).
  static bool get offersGitHubSelfUpdate {
    if (isMicrosoftStore) return false;
    if (isPlayStore) return false;
    return true;
  }

  /// IAP y sincronización con Microsoft Store en Windows.
  ///
  /// Falso en [isGitHub] y [isPlayStore]. Verdadero en [isMicrosoftStore],
  /// cadena vacía y valores no reconocidos (comportamiento anterior).
  static bool get showMicrosoftStoreIntegration {
    if (isGitHub) return false;
    if (isPlayStore) return false;
    return true;
  }
}
