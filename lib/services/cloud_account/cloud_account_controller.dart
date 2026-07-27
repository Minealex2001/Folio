import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_identity_rest_verify.dart';
import '../folio_firestore_sync.dart';
import 'folio_spring_auth_session.dart';

/// Optional cloud account (Firebase Auth **o** Spring JWT según [FolioBackendConfig]).
///
/// Si Firebase no está inicializado y el modo es Firebase, [isAvailable] es false.
/// En modo Spring, [isAvailable] es true aunque Firebase no arranque.
class CloudAccountController extends ChangeNotifier {
  static const Duration _authNetworkTimeout = Duration(seconds: 15);

  CloudAccountController({FolioSpringAuthSession? springSession})
      : _spring = springSession ?? FolioSpringAuthSession.instance {
    if (FolioBackendConfig.useSpring) {
      _spring.addListener(_onSpringChanged);
      // restore() se invoca desde main; aquí solo reaccionamos a cambios.
    } else if (Firebase.apps.isNotEmpty) {
      _auth = FirebaseAuth.instance;
      _authStateSub = _auth!.authStateChanges().listen((_) => notifyListeners());
    }
  }

  final FolioSpringAuthSession _spring;
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authStateSub;

  void _onSpringChanged() => notifyListeners();

  /// Sesión Spring lista (tras [FolioSpringAuthSession.restore] en main).
  Future<void> ensureSpringSessionRestored() async {
    if (!FolioBackendConfig.useSpring) return;
    await _spring.restore();
  }

  bool get isAvailable =>
      FolioBackendConfig.useSpring || Firebase.apps.isNotEmpty;

  /// Usuario Firebase (solo modo Firebase). En modo Spring es siempre null;
  /// usa [uid] / [email] / [displayName].
  User? get user => FolioBackendConfig.useSpring ? null : _auth?.currentUser;

  String? get uid => FolioBackendConfig.useSpring
      ? _spring.uid
      : _auth?.currentUser?.uid;

  String? get email => FolioBackendConfig.useSpring
      ? _spring.email
      : _auth?.currentUser?.email;

  String? get displayName => FolioBackendConfig.useSpring
      ? _spring.displayName
      : _auth?.currentUser?.displayName;

  bool get emailVerified => FolioBackendConfig.useSpring
      ? _spring.emailVerified
      : (_auth?.currentUser?.emailVerified ?? false);

  bool get isSignedIn => FolioBackendConfig.useSpring
      ? _spring.isSignedIn
      : user != null;

  /// Cuenta con enlace email/contraseña (reautenticación con [reauthenticateWithEmailAndPassword]).
  bool get canReauthenticateWithPassword {
    if (FolioBackendConfig.useSpring) {
      return isSignedIn;
    }
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
    if (FolioBackendConfig.useSpring) {
      await _spring.verifyPassword(email: email, password: password);
      return;
    }
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
    if (FolioBackendConfig.useSpring) return false;
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
    if (FolioBackendConfig.useSpring) {
      await _spring.verifyPassword(email: email, password: password);
      return;
    }
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
    if (FolioBackendConfig.useSpring) {
      AppLogger.info(
        'signIn start (spring)',
        tag: 'auth',
        context: {'emailLen': email.trim().length},
      );
      try {
        await _spring
            .login(email: email, password: password)
            .timeout(_authNetworkTimeout);
        AppLogger.info(
          'signIn ok (spring)',
          tag: 'auth',
          context: {'uid': _spring.uid},
        );
      } on TimeoutException catch (e, st) {
        AppLogger.error(
          'signIn timeout',
          tag: 'auth',
          error: e,
          stackTrace: st,
        );
        throw FirebaseAuthException(code: 'network-request-failed');
      } on FolioSpringAuthException catch (e, st) {
        AppLogger.error(
          'signIn failed',
          tag: 'auth',
          error: e,
          stackTrace: st,
          context: {'code': e.code},
        );
        throw FirebaseAuthException(code: e.code, message: e.message);
      }
      return;
    }

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
    if (FolioBackendConfig.useSpring) {
      AppLogger.info(
        'createUser start (spring)',
        tag: 'auth',
        context: {'emailLen': email.trim().length},
      );
      try {
        await _spring
            .register(email: email, password: password)
            .timeout(_authNetworkTimeout);
        AppLogger.info(
          'createUser ok (spring)',
          tag: 'auth',
          context: {'uid': _spring.uid},
        );
      } on TimeoutException catch (e, st) {
        AppLogger.error(
          'createUser timeout',
          tag: 'auth',
          error: e,
          stackTrace: st,
        );
        throw FirebaseAuthException(code: 'network-request-failed');
      } on FolioSpringAuthException catch (e, st) {
        AppLogger.error(
          'createUser failed',
          tag: 'auth',
          error: e,
          stackTrace: st,
          context: {'code': e.code},
        );
        final code = e.statusCode == 409 ? 'email-already-in-use' : e.code;
        throw FirebaseAuthException(code: code, message: e.message);
      }
      return;
    }

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
    if (FolioBackendConfig.useSpring) {
      try {
        await _spring
            .forgotPassword(email)
            .timeout(_authNetworkTimeout);
        AppLogger.info('passwordReset sent (spring)', tag: 'auth');
      } on TimeoutException catch (e, st) {
        AppLogger.error(
          'passwordReset timeout',
          tag: 'auth',
          error: e,
          stackTrace: st,
        );
        throw FirebaseAuthException(code: 'network-request-failed');
      } on FolioSpringAuthException catch (e) {
        throw FirebaseAuthException(code: e.code, message: e.message);
      }
      return;
    }

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
    if (FolioBackendConfig.useSpring) {
      AppLogger.info(
        'signOut (spring)',
        tag: 'auth',
        context: {'uid': _spring.uid},
      );
      await _spring.logout();
      return;
    }
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
    if (FolioBackendConfig.useSpring) {
      // Spring no tiene reload de perfil Auth; el perfil se refresca vía /account/me.
      notifyListeners();
      return;
    }
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
    if (FolioBackendConfig.useSpring) {
      try {
        await _spring.resendVerification();
      } on FolioSpringAuthException catch (e) {
        throw FirebaseAuthException(code: e.code, message: e.message);
      }
      return;
    }
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
    if (FolioBackendConfig.useSpring) {
      _spring.removeListener(_onSpringChanged);
    }
    final sub = _authStateSub;
    _authStateSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
