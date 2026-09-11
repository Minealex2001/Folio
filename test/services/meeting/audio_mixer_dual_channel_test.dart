/// Cobertura del tracking opcional de metadata de canal (Fase 1 de la
/// evolución de `meeting_note`) en `AudioMixerService`.
///
/// No es viable iniciar una grabación real (mic/system audio) en
/// `flutter test`, así que este test cubre el contrato público que sí es
/// determinista sin hardware: por defecto (sin `trackChannelMeta: true`),
/// `channelMeta` debe ser `null` — el tracking es opt-in y no debe alterar
/// el comportamiento existente para quien no lo pida explícitamente.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/audio_mixer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // El constructor de AudioMixerService instancia un AudioRecorder del
  // paquete `record`, que llama de forma fire-and-forget al canal nativo
  // para crear el recorder. En `flutter test` no hay implementación nativa
  // registrada, así que se mockea el canal para evitar una
  // MissingPluginException no manejada (no relacionada con lo que este test
  // verifica: el contrato de `channelMeta`).
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  group('AudioMixerService — channelMeta', () {
    test(
      'channelMeta es null por defecto (tracking desactivado, sin sesión activa)',
      () {
        expect(AudioMixerService.instance.channelMeta, isNull);
      },
    );

    test('AudioMixerService es un singleton estable', () {
      expect(
        identical(AudioMixerService.instance, AudioMixerService.instance),
        isTrue,
      );
    });
  });
}
