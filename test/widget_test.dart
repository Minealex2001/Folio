import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/folio_app.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('MaterialApp de Folio se monta', (WidgetTester tester) async {
    final session = VaultSession();
    await tester.pumpWidget(FolioApp(session: session));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
