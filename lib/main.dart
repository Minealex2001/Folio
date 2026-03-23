import 'package:flutter/material.dart';

import 'app/folio_app.dart';
import 'session/vault_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = VaultSession();
  runApp(FolioApp(session: session));
}
