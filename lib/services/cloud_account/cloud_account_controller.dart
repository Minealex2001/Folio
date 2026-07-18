import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../app_logger.dart';
import '../folio_cloud/folio_cloud_identity_rest_verify.dart';
import '../folio_firestore_sync.dart';

/// Optional Firebase Authentication for future paid cloud sync.
/// If [Firebase] was not initialized, [isAvailable] is false and methods throw.
class CloudAccountController extends ChangeNotifier {
  static const Duration _authNetworkTimeout = Duration(seconds: 15);

  CloudAccountController() {
    if (Firebase.apps.isNotEmpty) {
      _auth = FirebaseAuth.instance;
      _authStateSub = _auth!.authStateChanges().listen((_) => notifyListeners());
    }
  }

  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authStateSub;

  bool get isAvailable => Firebase.apps.isNotEmpty;

  User? get user => _auth?.currentUser;

  bool get isSignedIn => user != null;

  /// Cuenta con enlace email/contraseña (reautenticación con [reauthenticateWithEmailAndPassword]).
  bool get canReauthenticateWithPassword {
    final u = user;
    if (u == null) return false;
    return u.providerData.any(
      (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  /// Comprueba de nuevo la contraseña de la cuenta (p. ej. antes de listar copias en la nube).
  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    final current = auth.currentUser;
    if (current == null) {
      throw StateError('No hay sesión en Folio Cloud');
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await current.reauthenticateWithCredential(credential);
  }

  bool get _useIdentityToolkitPasswordVerify {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  /// Misma intención que [reauthenticateWithEmailAndPassword], pero en Windows/Linux
  /// usa la API REST para evitar fallos del plugin nativo (`id-token` en hilo incorrecto).
  Future<void> verifyPasswordForSensitiveCloudAction({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    final current = auth.currentUser;
    if (current == null) {
      throw StateError('No hay sesión en Folio Cloud');
    }
    final trimmed = email.trim();
    final sessionEmail = current.email?.trim().toLowerCase();
    if (sessionEmail != null &&
        sessionEmail.isNotEmpty &&
        trimmed.toLowerCase() != sessionEmail) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'El correo no coincide con la sesión actual.',
      );
    }
    if (_useIdentityToolkitPasswordVerify) {
      await verifyFolioCloudPasswordViaIdentityToolkit(
        email: trimmed,
        password: password,
        expectedLocalId: current.uid,
      );
      return;
    }
    await reauthenticateWithEmailAndPassword(
      email: trimmed,
      password: password,
    );
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    AppLogger.info(
      'signIn start',
      tag: 'auth',
      context: {'emailLen': email.trim().length},
    );
    if (auth.currentUser != null) {
      await FolioFirestoreSync.flush();
    }
    try {
      await auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authNetworkTimeout);
      AppLogger.info(
        'signIn ok',
        tag: 'auth',
        context: {'uid': auth.currentUser?.uid},
      );
    } on TimeoutException catch (e, st) {
      AppLogger.error(
        'signIn timeout',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
      throw FirebaseAuthException(code: 'network-request-failed');
    } on FirebaseAuthException catch (e, st) {
      AppLogger.error(
        'signIn failed',
        tag: 'auth',
        error: e,
        stackTrace: st,
        context: {'code': e.code},
      );
      rethrow;
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    AppLogger.info(
      'createUser start',
      tag: 'auth',
      context: {'emailLen': email.trim().length},
    );
    try {
      await auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authNetworkTimeout);
      AppLogger.info(
        'createUser ok',
        tag: 'auth',
        context: {'uid': auth.currentUser?.uid},
      );
    } on TimeoutException catch (e, st) {
      AppLogger.error(
        'createUser timeout',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
      throw FirebaseAuthException(code: 'network-request-failed');
    } on FirebaseAuthException catch (e, st) {
      AppLogger.error(
        'createUser failed',
        tag: 'auth',
        error: e,
        stackTrace: st,
        context: {'code': e.code},
      );
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    try {
      await auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(_authNetworkTimeout);
      AppLogger.info('passwordReset sent', tag: 'auth');
    } on TimeoutException catch (e, st) {
      AppLogger.error(
        'passwordReset timeout',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
      throw FirebaseAuthException(code: 'network-request-failed');
    }
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    AppLogger.info(
      'signOut',
      tag: 'auth',
      context: {'uid': auth.currentUser?.uid},
    );
    await FolioFirestoreSync.flush();
    await auth.signOut();
  }

  /// Refresca el perfil del usuario (p. ej. tras abrir el enlace de verificación de correo).
  /// Notifica a los oyentes porque [authStateChanges] no siempre emite tras [User.reload].
  Future<void> reloadCurrentUser() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    final current = auth.currentUser;
    if (current == null) {
      throw StateError('No hay sesión en Folio Cloud');
    }
    await current.reload();
    notifyListeners();
  }

  /// Envía el correo de verificación de la dirección actual (cuenta email/contraseña).
  Future<void> sendEmailVerification() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    final current = auth.currentUser;
    if (current == null) {
      throw StateError('No hay sesión en Folio Cloud');
    }
    await current.sendEmailVerification();
  }

  @override
  void dispose() {
    final sub = _authStateSub;
    _authStateSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
