import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../folio_cloud/folio_cloud_identity_rest_verify.dart';

/// Optional Firebase Authentication for future paid cloud sync.
/// If [Firebase] was not initialized, [isAvailable] is false and methods throw.
class CloudAccountController extends ChangeNotifier {
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
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase not initialized');
    }
    await auth.signOut();
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
