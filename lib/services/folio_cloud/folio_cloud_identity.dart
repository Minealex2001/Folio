import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../config/folio_backend_config.dart';
import '../cloud_account/folio_spring_auth_session.dart';

/// UID de la sesión Folio Cloud activa (Firebase o Spring según el flag).
String? folioCloudCurrentUid() {
  if (FolioBackendConfig.useSpring) {
    return FolioSpringAuthSession.instance.uid;
  }
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.uid;
}

/// Email de la sesión activa (o null).
String? folioCloudCurrentEmail() {
  if (FolioBackendConfig.useSpring) {
    return FolioSpringAuthSession.instance.email;
  }
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.email;
}

/// Bearer para HTTP (JWT Spring o ID token Firebase).
Future<String?> folioCloudBearerToken({bool forceRefresh = false}) async {
  if (FolioBackendConfig.useSpring) {
    return FolioSpringAuthSession.instance.getAccessToken(
      forceRefresh: forceRefresh,
    );
  }
  if (Firebase.apps.isEmpty) return null;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return user.getIdToken(forceRefresh);
}

/// Hay sesión Cloud usable para callables / REST.
bool folioCloudHasSession() {
  if (FolioBackendConfig.useSpring) {
    return FolioSpringAuthSession.instance.isSignedIn;
  }
  if (Firebase.apps.isEmpty) return false;
  return FirebaseAuth.instance.currentUser != null;
}
