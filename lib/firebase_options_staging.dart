// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
//
// Firebase options for the Folio **staging** project (`folio-staging-minealex`).
// Use with: `--dart-define=FOLIO_FIREBASE_ENV=staging`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] for the non-production Folio Cloud backend.
class StagingFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // iOS/macOS apps not registered yet on staging; fall back to web config
        // so desktop-style tooling can still target the staging projectId.
        return web;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return windows;
      default:
        throw UnsupportedError(
          'StagingFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCs6zu-fzbH--_yFRHeSkBuHRONkxeVtsM',
    appId: '1:219633797530:web:63d5c602a982f356bf1223',
    messagingSenderId: '219633797530',
    projectId: 'folio-staging-minealex',
    authDomain: 'folio-staging-minealex.firebaseapp.com',
    storageBucket: 'folio-staging-minealex.firebasestorage.app',
  );

  /// Package `com.minealexgames.folio.staging` (separate from production APK).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZbk7N-c_oalA0genJdXyr7St-M33m9wA',
    appId: '1:219633797530:android:fb3c6e25bd5eb68ebf1223',
    messagingSenderId: '219633797530',
    projectId: 'folio-staging-minealex',
    storageBucket: 'folio-staging-minealex.firebasestorage.app',
  );

  /// Same Web app as production desktop pattern.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCs6zu-fzbH--_yFRHeSkBuHRONkxeVtsM',
    appId: '1:219633797530:web:63d5c602a982f356bf1223',
    messagingSenderId: '219633797530',
    projectId: 'folio-staging-minealex',
    authDomain: 'folio-staging-minealex.firebaseapp.com',
    storageBucket: 'folio-staging-minealex.firebasestorage.app',
  );
}
