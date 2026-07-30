import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_logger.dart';
import '../folio_cloud/folio_cloud_exception.dart';
import '../folio_cloud/folio_spring_account_me.dart';
import 'folio_spring_auth_session.dart';

/// Cuenta Folio Cloud (JWT Spring). Tras Fase 30 no hay Firebase Auth.
class CloudAccountController extends ChangeNotifier {
  static const Duration _authNetworkTimeout = Duration(seconds: 15);

  CloudAccountController({FolioSpringAuthSession? springSession})
      : _spring = springSession ?? FolioSpringAuthSession.instance {
    _spring.addListener(_onSpringChanged);
  }

  final FolioSpringAuthSession _spring;

  void _onSpringChanged() => notifyListeners();

  /// Sesión Spring lista (tras [FolioSpringAuthSession.restore] en main).
  Future<void> ensureSpringSessionRestored() async {
    await _spring.restore();
  }

  bool get isAvailable => true;

  /// Compat: ya no hay [User] de Firebase.
  Object? get user => null;

  String? get uid => _spring.uid;

  String? get email => _spring.email;

  String? get displayName => _spring.displayName;

  bool get emailVerified => _spring.emailVerified;

  bool get isSignedIn => _spring.isSignedIn;

  /// Cuenta con enlace email/contraseña.
  bool get canReauthenticateWithPassword => isSignedIn;

  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _spring.verifyPassword(email: email, password: password);
  }

  Future<void> verifyPasswordForSensitiveCloudAction({
    required String email,
    required String password,
  }) async {
    await _spring.verifyPassword(email: email, password: password);
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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
      throw FolioAuthException(code: 'network-request-failed');
    } on FolioSpringAuthException catch (e, st) {
      AppLogger.error(
        'signIn failed',
        tag: 'auth',
        error: e,
        stackTrace: st,
        context: {'code': e.code},
      );
      throw FolioAuthException(code: e.code, message: e.message);
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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
      throw FolioAuthException(code: 'network-request-failed');
    } on FolioSpringAuthException catch (e, st) {
      AppLogger.error(
        'createUser failed',
        tag: 'auth',
        error: e,
        stackTrace: st,
        context: {'code': e.code},
      );
      final code = e.statusCode == 409 ? 'email-already-in-use' : e.code;
      throw FolioAuthException(code: code, message: e.message);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _spring.forgotPassword(email).timeout(_authNetworkTimeout);
      AppLogger.info('passwordReset sent (spring)', tag: 'auth');
    } on TimeoutException catch (e, st) {
      AppLogger.error(
        'passwordReset timeout',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
      throw FolioAuthException(code: 'network-request-failed');
    } on FolioSpringAuthException catch (e) {
      throw FolioAuthException(code: e.code, message: e.message);
    }
  }

  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _spring
          .resetPassword(token: token, newPassword: newPassword)
          .timeout(_authNetworkTimeout);
      AppLogger.info('passwordReset completed (spring)', tag: 'auth');
    } on TimeoutException catch (e, st) {
      AppLogger.error(
        'passwordReset complete timeout',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
      throw FolioAuthException(code: 'network-request-failed');
    } on FolioSpringAuthException catch (e) {
      throw FolioAuthException(code: e.code, message: e.message);
    }
  }

  Future<void> signOut() async {
    AppLogger.info(
      'signOut (spring)',
      tag: 'auth',
      context: {'uid': _spring.uid},
    );
    await _spring.logout();
  }

  Future<void> reloadCurrentUser() async {
    try {
      final me = await folioSpringFetchAccountMeAsUserDoc();
      if (me != null) {
        final verified = me['emailVerifiedAt'] != null;
        final dn = me['displayName']?.toString();
        await _spring.updateLocalProfile(
          displayName: (dn != null && dn.trim().isNotEmpty) ? dn.trim() : null,
          emailVerified: verified,
        );
      }
    } catch (e, st) {
      AppLogger.warn(
        'reloadCurrentUser failed',
        tag: 'auth',
        context: {'error': '$e', 'stack': '$st'},
      );
    }
    notifyListeners();
  }

  Future<void> sendEmailVerification() async {
    try {
      await _spring.resendVerification();
    } on FolioSpringAuthException catch (e) {
      if (e.code == 'already-verified') {
        await _spring.updateLocalProfile(emailVerified: true);
        return;
      }
      throw FolioAuthException(code: e.code, message: e.message);
    }
  }

  @override
  void dispose() {
    _spring.removeListener(_onSpringChanged);
    super.dispose();
  }
}
