import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
