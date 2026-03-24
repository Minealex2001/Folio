import 'package:flutter_test/flutter_test.dart';
import 'package:folio/app/app_settings.dart';
import 'package:folio/services/ai/ai_safety_policy.dart';

void main() {
  group('AiSafetyPolicy', () {
    test('acepta localhost en modo localhostOnly', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'http://127.0.0.1:11434',
        mode: AiEndpointMode.localhostOnly,
        remoteConfirmed: false,
      );
      expect(err, isNull);
    });

    test('bloquea remoto sin confirmación en allowRemote', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'https://api.example.com/v1',
        mode: AiEndpointMode.allowRemote,
        remoteConfirmed: false,
      );
      expect(err, isNotNull);
    });

    test('permite remoto confirmado en allowRemote', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'https://api.example.com/v1',
        mode: AiEndpointMode.allowRemote,
        remoteConfirmed: true,
      );
      expect(err, isNull);
    });
  });
}
