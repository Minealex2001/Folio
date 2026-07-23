import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import '../firebase_options.dart';
import '../firebase_options_staging.dart';

/// Selects production vs staging Firebase backend via compile-time define.
///
/// ```bash
/// flutter run --dart-define=FOLIO_FIREBASE_ENV=staging
/// ```
///
/// Default (unset or any other value) is **production** (`folio-minealexgames`).
class FolioFirebaseEnv {
  FolioFirebaseEnv._();

  static const String _env = String.fromEnvironment(
    'FOLIO_FIREBASE_ENV',
    defaultValue: 'production',
  );

  /// True when the app was built against `folio-staging-minealex`.
  static bool get isStaging => _env.toLowerCase() == 'staging';

  static String get label => isStaging ? 'staging' : 'production';

  static FirebaseOptions get options => isStaging
      ? StagingFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;
}
