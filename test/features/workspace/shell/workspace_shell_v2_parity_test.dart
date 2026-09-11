import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/shell/workspace_shell.dart';
import 'package:folio/features/workspace/shell/workspace_shell_v2.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

/// V2 (Fase 24) reemplaza los tres handles de resize hechos a mano (sidebar/
/// IA/colaboración) de v1 por `PanelResizeHandle`, el widget compartido con
/// el motor de layout. Esa sustitución NO debe cambiar la API pública ni el
/// signo del delta que reciben los callbacks del caller — este test arrastra
/// cada handle en v1 y en v2 y compara el delta recibido, en vez de confiar
/// solo en la inspección manual del código.
void main() {
  final scheme = ThemeData.light().colorScheme;

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: 1000, height: 700, child: child),
    ),
  );

  group('sidebar resize handle', () {
    testWidgets('v1 and v2 report the same delta sign for the same drag', (
      tester,
    ) async {
      double? v1Delta;
      double? v2Delta;

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShell(
            compact: false,
            sidePanelWidth: 280,
            sidePanel: const ColoredBox(color: Colors.blue),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            showSidebarResizeHandle: true,
            onResizeSidebarDelta: (d) => v1Delta = d,
          ),
        ),
      );
      final v1Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v1Handle.first, const Offset(30, 0));

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 280,
            sidePanel: const ColoredBox(color: Colors.blue),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            showSidebarResizeHandle: true,
            onResizeSidebarDelta: (d) => v2Delta = d,
          ),
        ),
      );
      final v2Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v2Handle.first, const Offset(30, 0));

      expect(v1Delta, isNotNull);
      expect(v2Delta, isNotNull);
      expect(v1Delta!.sign, v2Delta!.sign);
      expect(v2Delta, v1Delta);
    });
  });

  group('AI panel resize handles', () {
    testWidgets('width handle: v1 and v2 report the same delta for the '
        'same horizontal drag', (tester) async {
      double? v1Delta;
      double? v2Delta;

      Widget buildAiHost(ValueChanged<double> onWidth) => WorkspaceBodyShell(
        compact: false,
        sidePanelWidth: 0,
        sidePanel: const SizedBox.shrink(),
        editorContent: const SizedBox.expand(),
        scheme: scheme,
        aiFloatingPanel: const ColoredBox(color: Colors.green),
        aiFloatingShowResizeHandles: true,
        onResizeAiPanelWidth: onWidth,
      );

      await tester.pumpWidget(wrap(buildAiHost((d) => v1Delta = d)));
      final v1Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v1Handle.first, const Offset(20, 0));

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            aiFloatingPanel: const ColoredBox(color: Colors.green),
            aiFloatingShowResizeHandles: true,
            onResizeAiPanelWidth: (d) => v2Delta = d,
          ),
        ),
      );
      final v2Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v2Handle.first, const Offset(20, 0));

      expect(v1Delta, isNotNull);
      expect(v2Delta, isNotNull);
      expect(v2Delta, v1Delta);
    });

    testWidgets('height handle: v1 and v2 report the same delta for the '
        'same vertical drag', (tester) async {
      double? v1Delta;
      double? v2Delta;

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShell(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            aiFloatingPanel: const ColoredBox(color: Colors.green),
            aiFloatingShowResizeHandles: true,
            onResizeAiPanelHeight: (d) => v1Delta = d,
          ),
        ),
      );
      final v1Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeUpDown,
      );
      await tester.drag(v1Handle.first, const Offset(0, 15));

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            aiFloatingPanel: const ColoredBox(color: Colors.green),
            aiFloatingShowResizeHandles: true,
            onResizeAiPanelHeight: (d) => v2Delta = d,
          ),
        ),
      );
      final v2Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeUpDown,
      );
      await tester.drag(v2Handle.first, const Offset(0, 15));

      expect(v1Delta, isNotNull);
      expect(v2Delta, isNotNull);
      expect(v2Delta, v1Delta);
    });
  });

  group('collab panel resize handles', () {
    testWidgets('width handle: v1 and v2 report the same delta for the '
        'same horizontal drag', (tester) async {
      double? v1Delta;
      double? v2Delta;

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShell(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            collabFloatingPanel: const ColoredBox(color: Colors.orange),
            collabFloatingShowResizeHandles: true,
            onResizeCollabPanelWidth: (d) => v1Delta = d,
          ),
        ),
      );
      final v1Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v1Handle.first, const Offset(18, 0));

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            collabFloatingPanel: const ColoredBox(color: Colors.orange),
            collabFloatingShowResizeHandles: true,
            onResizeCollabPanelWidth: (d) => v2Delta = d,
          ),
        ),
      );
      final v2Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      await tester.drag(v2Handle.first, const Offset(18, 0));

      expect(v1Delta, isNotNull);
      expect(v2Delta, isNotNull);
      expect(v2Delta, v1Delta);
    });

    testWidgets('height handle: v1 and v2 report the same delta for the '
        'same vertical drag', (tester) async {
      double? v1Delta;
      double? v2Delta;

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShell(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            collabFloatingPanel: const ColoredBox(color: Colors.orange),
            collabFloatingShowResizeHandles: true,
            onResizeCollabPanelHeight: (d) => v1Delta = d,
          ),
        ),
      );
      final v1Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeUpDown,
      );
      await tester.drag(v1Handle.first, const Offset(0, 12));

      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            collabFloatingPanel: const ColoredBox(color: Colors.orange),
            collabFloatingShowResizeHandles: true,
            onResizeCollabPanelHeight: (d) => v2Delta = d,
          ),
        ),
      );
      final v2Handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeUpDown,
      );
      await tester.drag(v2Handle.first, const Offset(0, 12));

      expect(v1Delta, isNotNull);
      expect(v2Delta, isNotNull);
      expect(v2Delta, v1Delta);
    });
  });

  group('structural parity', () {
    testWidgets('v2 renders sidePanel, editorContent, betaBanner and '
        'overlay exactly like v1', (tester) async {
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 280,
            sidePanel: const Text('sidebar-content'),
            editorContent: const Text('editor-content'),
            scheme: scheme,
            betaBanner: const Text('beta-banner'),
            overlay: const Text('overlay-content'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sidebar-content'), findsOneWidget);
      expect(find.text('editor-content'), findsOneWidget);
      expect(find.text('beta-banner'), findsOneWidget);
      expect(find.text('overlay-content'), findsOneWidget);
    });

    testWidgets('with no topBand/bottomBand, v2 has the exact same number '
        'of Column/Stack ancestors as v1 — no extra wrapper added', (
      tester,
    ) async {
      Widget buildV1() => WorkspaceBodyShell(
        compact: false,
        sidePanelWidth: 280,
        sidePanel: const SizedBox.shrink(),
        editorContent: const SizedBox.expand(),
        scheme: scheme,
      );
      Widget buildV2() => WorkspaceBodyShellV2(
        compact: false,
        sidePanelWidth: 280,
        sidePanel: const SizedBox.shrink(),
        editorContent: const SizedBox.expand(),
        scheme: scheme,
      );

      await tester.pumpWidget(wrap(buildV1()));
      final v1Columns = find.byType(Column).evaluate().length;
      final v1Stacks = find.byType(Stack).evaluate().length;

      await tester.pumpWidget(wrap(buildV2()));
      final v2Columns = find.byType(Column).evaluate().length;
      final v2Stacks = find.byType(Stack).evaluate().length;

      expect(v2Columns, v1Columns);
      expect(v2Stacks, v1Stacks);
    });

    testWidgets('a configured topBand renders above editorContent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 0,
            sidePanel: const SizedBox.shrink(),
            editorContent: const Text('editor-content'),
            scheme: scheme,
            topBand: const Text('toolbar-band'),
          ),
        ),
      );

      expect(find.text('toolbar-band'), findsOneWidget);
      expect(find.text('editor-content'), findsOneWidget);
      final bandY = tester.getTopLeft(find.text('toolbar-band')).dy;
      final editorY = tester.getTopLeft(find.text('editor-content')).dy;
      expect(bandY, lessThan(editorY));
    });
  });

  group('sidebarPosition (Fase 25)', () {
    testWidgets('default ("left") renders the sidebar to the left of the '
        'editor, matching v1 exactly', (tester) async {
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 200,
            sidePanel: const Text('sidebar'),
            editorContent: const Text('editor'),
            scheme: scheme,
          ),
        ),
      );

      final sidebarX = tester.getTopLeft(find.text('sidebar')).dx;
      final editorX = tester.getTopLeft(find.text('editor')).dx;
      expect(sidebarX, lessThan(editorX));
    });

    testWidgets('"right" renders the sidebar to the right of the editor', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 200,
            sidePanel: const Text('sidebar'),
            editorContent: const Text('editor'),
            scheme: scheme,
            sidebarPosition: 'right',
          ),
        ),
      );

      final sidebarX = tester.getTopLeft(find.text('sidebar')).dx;
      final editorX = tester.getTopLeft(find.text('editor')).dx;
      expect(sidebarX, greaterThan(editorX));
    });

    testWidgets('"right" still resizes the sidebar in the correct '
        'direction (drag towards the editor grows it)', (tester) async {
      double? delta;
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 200,
            sidePanel: const ColoredBox(color: Colors.blue),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            showSidebarResizeHandle: true,
            sidebarPosition: 'right',
            onResizeSidebarDelta: (d) => delta = d,
          ),
        ),
      );

      final handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      // Arrastrar hacia la izquierda (hacia el editor) debe crecer un
      // sidebar anclado a la derecha.
      await tester.drag(handle.first, const Offset(-20, 0));

      expect(delta, isNotNull);
      expect(delta, greaterThan(0));
    });
  });

  group('sidebarShowDivider (Fase 26)', () {
    testWidgets('default (true) paints the resize handle with the usual '
        'outlineVariant color (parity)', (tester) async {
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 200,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            showSidebarResizeHandle: true,
          ),
        ),
      );

      final handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      final container = tester.widget<Container>(
        find.descendant(of: handle, matching: find.byType(Container)).first,
      );
      expect(container.color, isNot(Colors.transparent));
      expect(container.color, isNotNull);
    });

    testWidgets('false paints the resize handle transparent while it '
        'still functions as a drag target', (tester) async {
      double? delta;
      await tester.pumpWidget(
        wrap(
          WorkspaceBodyShellV2(
            compact: false,
            sidePanelWidth: 200,
            sidePanel: const SizedBox.shrink(),
            editorContent: const SizedBox.expand(),
            scheme: scheme,
            showSidebarResizeHandle: true,
            sidebarShowDivider: false,
            onResizeSidebarDelta: (d) => delta = d,
          ),
        ),
      );

      final handle = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      final container = tester.widget<Container>(
        find.descendant(of: handle, matching: find.byType(Container)).first,
      );
      expect(container.color, Colors.transparent);

      await tester.drag(handle.first, const Offset(15, 0));
      expect(delta, isNotNull);
    });
  });
}
