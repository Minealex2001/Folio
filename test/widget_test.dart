import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/app/folio_app.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('MaterialApp de Folio se monta', (WidgetTester tester) async {
    final session = VaultSession();
    final appSettings = AppSettings();
    final cloudAccountController = CloudAccountController();
    await tester.pumpWidget(
      FolioApp(
        session: session,
        appSettings: appSettings,
        cloudAccountController: cloudAccountController,
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
