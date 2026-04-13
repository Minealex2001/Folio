import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

import 'package:folio/app/app_settings.dart';
import 'package:folio/services/ai/ai_safety_policy.dart';

void main() {
  group('AiSafetyPolicy', () {
    test('parsea URL http/https válida', () {
      final uri = AiSafetyPolicy.parseAndNormalizeUrl(
        ' https://api.example.com/v1 ',
      );

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'api.example.com');
    });

    test('rechaza URL sin esquema', () {
      final uri = AiSafetyPolicy.parseAndNormalizeUrl('api.example.com/v1');

      expect(uri, isNull);
    });

    test('isLocalhostHost detecta aliases de loopback', () {
      expect(AiSafetyPolicy.isLocalhostHost('localhost'), isTrue);
      expect(AiSafetyPolicy.isLocalhostHost('127.0.0.1'), isTrue);
      expect(AiSafetyPolicy.isLocalhostHost('::1'), isTrue);
      expect(AiSafetyPolicy.isLocalhostHost('api.example.com'), isFalse);
    });

    test('acepta localhost en modo localhostOnly', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'http://127.0.0.1:11434',
        mode: AiEndpointMode.localhostOnly,
        remoteConfirmed: false,
      );
      expect(err, isNull);
    });

    test('bloquea remoto en localhostOnly aunque esté confirmado', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'https://api.example.com/v1',
        mode: AiEndpointMode.localhostOnly,
        remoteConfirmed: true,
      );

      expect(err, isNotNull);
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

    test('rechaza URL inválida con mensaje de error', () {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: 'not-a-url',
        mode: AiEndpointMode.allowRemote,
        remoteConfirmed: true,
      );

      expect(err, isNotNull);
      expect(err, contains('URL inválida'));
    });

    test('detectMimeType mapea extensiones comunes y fallback', () {
      expect(AiSafetyPolicy.detectMimeType('archivo.PNG'), 'image/png');
      expect(AiSafetyPolicy.detectMimeType('foto.jpeg'), 'image/jpeg');
      expect(AiSafetyPolicy.detectMimeType('scan.PDF'), 'application/pdf');
      expect(AiSafetyPolicy.detectMimeType('nota.markdown'), 'text/markdown');
      expect(
        AiSafetyPolicy.detectMimeType('data.bin'),
        'application/octet-stream',
      );
    });

    test('isImageMimeType detecta prefijo image/', () {
      expect(AiSafetyPolicy.isImageMimeType('image/webp'), isTrue);
      expect(AiSafetyPolicy.isImageMimeType('application/json'), isFalse);
    });

    test('isEndpointAllowed aplica regla por modo y confirmación', () {
      final localhost = Uri.parse('http://localhost:11434');
      final remote = Uri.parse('https://api.example.com/v1');

      expect(
        AiSafetyPolicy.isEndpointAllowed(
          uri: localhost,
          mode: AiEndpointMode.localhostOnly,
          remoteConfirmed: false,
        ),
        isTrue,
      );
      expect(
        AiSafetyPolicy.isEndpointAllowed(
          uri: remote,
          mode: AiEndpointMode.localhostOnly,
          remoteConfirmed: true,
        ),
        isFalse,
      );
      expect(
        AiSafetyPolicy.isEndpointAllowed(
          uri: remote,
          mode: AiEndpointMode.allowRemote,
          remoteConfirmed: false,
        ),
        isFalse,
      );
      expect(
        AiSafetyPolicy.isEndpointAllowed(
          uri: remote,
          mode: AiEndpointMode.allowRemote,
          remoteConfirmed: true,
        ),
        isTrue,
      );
    });

    test('readImageAsBase64 retorna null para archivo vacío', () async {
      final dir = await Directory.systemTemp.createTemp('folio_ai_safety_');
      try {
        final file = File('${dir.path}\\empty.img');
        await file.writeAsBytes(const []);

        final result = await AiSafetyPolicy.readImageAsBase64(file);
        expect(result, isNull);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('readImageAsBase64 codifica bytes válidos', () async {
      final dir = await Directory.systemTemp.createTemp('folio_ai_safety_');
      try {
        final file = File('${dir.path}\\img.bin');
        const bytes = [1, 2, 3, 4];
        await file.writeAsBytes(bytes);

        final result = await AiSafetyPolicy.readImageAsBase64(file);
        expect(result, base64Encode(bytes));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test(
      'readAttachmentAsContext retorna texto para archivos textuales',
      () async {
        final dir = await Directory.systemTemp.createTemp('folio_ai_safety_');
        try {
          final file = File('${dir.path}\\note.txt');
          await file.writeAsString('hola mundo');

          final result = await AiSafetyPolicy.readAttachmentAsContext(file);
          expect(result, 'hola mundo');
        } finally {
          await dir.delete(recursive: true);
        }
      },
    );

    test('readAttachmentAsContext retorna metadatos para binarios', () async {
      final dir = await Directory.systemTemp.createTemp('folio_ai_safety_');
      try {
        final file = File('${dir.path}\\blob.bin');
        await file.writeAsBytes(List<int>.generate(10, (i) => i));

        final result = await AiSafetyPolicy.readAttachmentAsContext(file);
        expect(result, isNotNull);
        expect(result, contains('Adjunto binario no textual.'));
        expect(result, contains('Nombre: blob.bin'));
        expect(result, contains('Tamaño(bytes): 10'));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
