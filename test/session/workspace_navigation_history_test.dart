import 'package:flutter_test/flutter_test.dart';
import 'package:folio/session/workspace_navigation_history.dart';

void main() {
  group('WorkspaceNavigationHistory', () {
    test('record and goBack/goForward like a browser', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record('b');
      h.record('c');

      expect(h.canGoBack, isTrue);
      expect(h.canGoForward, isFalse);
      expect(h.current, 'c');

      expect(h.goBack(isValid: (_) => true), isTrue);
      expect(h.current, 'b');
      expect(h.canGoForward, isTrue);

      expect(h.goForward(isValid: (_) => true), isTrue);
      expect(h.current, 'c');
    });

    test('record truncates forward stack', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record('b');
      h.record('c');
      expect(h.goBack(isValid: (_) => true), isTrue);
      expect(h.current, 'b');
      h.record('d');
      expect(h.canGoForward, isFalse);
      expect(h.current, 'd');
      expect(h.goBack(isValid: (_) => true), isTrue);
      expect(h.current, 'b');
    });

    test('null entry represents home', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record(null);
      expect(h.current, isNull);
      expect(h.goBack(isValid: (_) => true), isTrue);
      expect(h.current, 'a');
    });

    test('skips invalid entries on goBack', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record('gone');
      h.record('c');
      final valid = {'a', 'c'};
      expect(
        h.goBack(isValid: (id) => id == null || valid.contains(id)),
        isTrue,
      );
      expect(h.current, 'a');
    });

    test('duplicate current record is ignored', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record('a');
      expect(h.canGoBack, isFalse);
      expect(h.current, 'a');
    });

    test('clear resets state', () {
      final h = WorkspaceNavigationHistory();
      h.seed('a');
      h.record('b');
      h.clear();
      expect(h.isEmpty, isTrue);
      expect(h.canGoBack, isFalse);
      expect(h.canGoForward, isFalse);
    });
  });
}
