import 'package:url_launcher/url_launcher.dart';

/// Abre una URL de autorización OAuth probando varios [LaunchMode].
///
/// En Android, `externalApplication` a veces falla por package visibility o
/// por el navegador por defecto; Custom Tabs (`inAppBrowserView`) suele funcionar.
Future<bool> launchOAuthAuthorizeUrl(Uri authUri) async {
  if (await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
    return true;
  }
  if (await launchUrl(authUri, mode: LaunchMode.inAppBrowserView)) {
    return true;
  }
  return launchUrl(authUri, mode: LaunchMode.platformDefault);
}
