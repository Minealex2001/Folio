import 'package:flutter/foundation.dart';

/// Indica si Cloud Firestore puede usarse de forma segura en esta plataforma.
///
/// En Windows el SDK C++ de Firestore lanza un `FirestoreInternalError` fatal
/// (excepción C++ no capturada, exit `0xE06D7363`) al inicializarse con el
/// toolchain/engine actual, tumbando el proceso antes de que la UI aparezca.
/// Hasta que haya arreglo upstream, deshabilitamos Firestore en Windows: las
/// lecturas devuelven datos vacíos y las escrituras se ignoran silenciosamente.
///
/// El resto de plataformas (Android, iOS, macOS, Linux, Web) siguen usando
/// Firestore con normalidad.
///
/// Ver crash `FirestoreInternalError` (firebase/flutterfire, Windows desktop).
bool get folioFirestoreSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.windows;
}
