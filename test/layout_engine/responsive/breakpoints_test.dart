import 'package:flutter_test/flutter_test.dart';
import 'package:folio/layout_engine/responsive/breakpoints.dart';

void main() {
  group('Breakpoints.resolve', () {
    test('below tablet is mobile', () {
      expect(Breakpoints.resolve(0), Breakpoint.mobile);
      expect(Breakpoints.resolve(699), Breakpoint.mobile);
    });

    test('boundary at tablet is inclusive (>= counts as tablet)', () {
      expect(Breakpoints.resolve(700), Breakpoint.tablet);
      expect(Breakpoints.resolve(899), Breakpoint.tablet);
    });

    test('boundary at desktop is inclusive', () {
      expect(Breakpoints.resolve(900), Breakpoint.desktop);
      expect(Breakpoints.resolve(1599), Breakpoint.desktop);
    });

    test('boundary at ultrawide is inclusive', () {
      expect(Breakpoints.resolve(1600), Breakpoint.ultrawide);
      expect(Breakpoints.resolve(3000), Breakpoint.ultrawide);
    });
  });
}
