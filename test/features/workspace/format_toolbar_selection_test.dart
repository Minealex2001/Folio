import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/editor/folio_text_format.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('format toolbar applies wrap to selected text', (tester) async {
    final controller = TextEditingController(text: 'hola mundo');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focusNode),
                FolioFormatToolbar(
                  controller: controller,
                  colorScheme: Theme.of(context).colorScheme,
                  textFocusNode: focusNode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.selection = const TextSelection(baseOffset: 5, extentOffset: 10);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pumpAndSettle();

    expect(controller.text, 'hola **mundo**');
  });

  testWidgets('format toolbar bold wraps whole block when no selection', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'hola mundo');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focusNode),
                FolioFormatToolbar(
                  controller: controller,
                  colorScheme: Theme.of(context).colorScheme,
                  textFocusNode: focusNode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pumpAndSettle();

    expect(controller.text, '**hola mundo**');
  });

  testWidgets(
    'format toolbar applies on pointerDown even if focus is lost before pointerUp',
    (tester) async {
      final controller = TextEditingController(text: 'hola mundo');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextField(controller: controller, focusNode: focusNode),
                  FolioFormatToolbar(
                    controller: controller,
                    colorScheme: Theme.of(context).colorScheme,
                    textFocusNode: focusNode,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      controller.selection = const TextSelection(baseOffset: 5, extentOffset: 10);
      await tester.pump();

      final bold = find.byIcon(Icons.format_bold_rounded);
      final g = await tester.startGesture(tester.getCenter(bold));
      await tester.pump();

      // Simula el caso desktop: el foco se pierde en pointerDown
      focusNode.unfocus();
      await tester.pump();

      await g.up();
      await tester.pumpAndSettle();

      expect(controller.text, 'hola **mundo**');
    },
  );
}

