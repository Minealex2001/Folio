// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
//
// Replace with your project: run `flutterfire configure` from the repo root.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJ4VGvDqiLYJRIhkcta4OTa-wrN6KiOL8',
    appId: '1:681177615508:web:cec096dfd599c4a9f9b881',
    messagingSenderId: '681177615508',
    projectId: 'folio-minealexgames',
    authDomain: 'folio-minealexgames.firebaseapp.com',
    storageBucket: 'folio-minealexgames.firebasestorage.app',
    measurementId: 'G-CDTQZZJG97',
  );

  /// Misma app Firebase que Windows/desktop (`folio-minealexgames`).

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA8FCHMGWXZVONQnnRPMLlwL2TqNng3wAc',
    appId: '1:681177615508:android:54bb3b642bd3ab54f9b881',
    messagingSenderId: '681177615508',
    projectId: 'folio-minealexgames',
    storageBucket: 'folio-minealexgames.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC9oovXeBhasuXhLnWBYgd_366G9DuXIgc',
    appId: '1:681177615508:ios:1541c69edde7fd82f9b881',
    messagingSenderId: '681177615508',
    projectId: 'folio-minealexgames',
    storageBucket: 'folio-minealexgames.firebasestorage.app',
    iosClientId: '681177615508-b4bp4kn9dbdqasdg2ubuf3gm3kn68v0i.apps.googleusercontent.com',
    iosBundleId: 'com.minealexgames.folio',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC9oovXeBhasuXhLnWBYgd_366G9DuXIgc',
    appId: '1:681177615508:ios:64dac66f2165689ef9b881',
    messagingSenderId: '681177615508',
    projectId: 'folio-minealexgames',
    storageBucket: 'folio-minealexgames.firebasestorage.app',
    iosClientId: '681177615508-8qe5e941bn39pbqg95k1i2d36maabc60.apps.googleusercontent.com',
    iosBundleId: 'com.minealexgames.folio.macos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCJ4VGvDqiLYJRIhkcta4OTa-wrN6KiOL8',
    appId: '1:681177615508:web:cec096dfd599c4a9f9b881',
    messagingSenderId: '681177615508',
    projectId: 'folio-minealexgames',
    authDomain: 'folio-minealexgames.firebaseapp.com',
    storageBucket: 'folio-minealexgames.firebasestorage.app',
    measurementId: 'G-CDTQZZJG97',
  );

}