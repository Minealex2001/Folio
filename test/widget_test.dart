import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/app.dart';

void main() {
  testWidgets('Muestra Folio y la primera página mock', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Folio'), findsWidgets);
    expect(find.text('Bienvenida'), findsNWidgets(2));
    expect(
      find.textContaining('Esta es Folio'),
      findsOneWidget,
    );
  });
}
