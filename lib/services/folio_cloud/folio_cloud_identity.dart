import '../cloud_account/folio_spring_auth_session.dart';

/// UID de la sesión Folio Cloud activa (Spring JWT).
String? folioCloudCurrentUid() => FolioSpringAuthSession.instance.uid;

/// Email de la sesión activa (o null).
String? folioCloudCurrentEmail() => FolioSpringAuthSession.instance.email;

/// Bearer JWT Spring para HTTP.
Future<String?> folioCloudBearerToken({bool forceRefresh = false}) {
  return FolioSpringAuthSession.instance.getAccessToken(
    forceRefresh: forceRefresh,
  );
}

/// Hay sesión Cloud usable para callables / REST.
bool folioCloudHasSession() => FolioSpringAuthSession.instance.isSignedIn;
