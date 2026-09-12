import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canal nativo Android: abre https/http con Intent ACTION_VIEW.
///
/// Fallback cuando el plugin `url_launcher` no tiene el host Pigeon conectado
/// (`PlatformException(channel-error, ... UrlLauncherApi.launchUrl)`).
const MethodChannel _androidBrowserChannel =
    MethodChannel('com.minealexgames.folio/browser');

/// Abre una URL de autorización OAuth probando varios [LaunchMode].
///
/// En Android, `externalApplication` a veces falla por package visibility o
/// por el navegador por defecto; Custom Tabs (`inAppBrowserView`) suele
/// funcionar. Si el canal Pigeon de `url_launcher` no está disponible
/// (`channel-error`), se usa un Intent nativo vía MethodChannel.
Future<bool> launchOAuthAuthorizeUrl(Uri authUri) async {
  if (await _tryLaunch(authUri, LaunchMode.externalApplication)) {
    return true;
  }
  if (await _tryLaunch(authUri, LaunchMode.inAppBrowserView)) {
    return true;
  }
  if (await _tryLaunch(authUri, LaunchMode.platformDefault)) {
    return true;
  }
  return _openViaAndroidIntent(authUri);
}

Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } on PlatformException {
    // p.ej. channel-error / ACTIVITY_NOT_FOUND / NO_ACTIVITY
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> _openViaAndroidIntent(Uri uri) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    final opened = await _androidBrowserChannel.invokeMethod<bool>(
      'openUrl',
      <String, dynamic>{'url': uri.toString()},
    );
    return opened == true;
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }
}
