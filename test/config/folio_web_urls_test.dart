import 'package:folio/config/folio_web_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FolioWebUrls hosts', () {
    test('reconoce prod y beta', () {
      expect(FolioWebUrls.isOfficialFolioWebHost('folio.minealexgames.com'), isTrue);
      expect(
        FolioWebUrls.isOfficialFolioWebHost('foliobeta.minealexgames.com'),
        isTrue,
      );
      expect(FolioWebUrls.isBetaWebHost('foliobeta.minealexgames.com'), isTrue);
      expect(FolioWebUrls.isProductionWebHost('folio.minealexgames.com'), isTrue);
      expect(FolioWebUrls.isBetaWebHost('folio.minealexgames.com'), isFalse);
      expect(FolioWebUrls.isOfficialFolioWebHost('evil.com'), isFalse);
    });

    test('resolveWebBaseUrl en beta usa origen actual', () {
      final base = FolioWebUrls.resolveWebBaseUrl(
        isWeb: true,
        currentUri: Uri.parse('https://foliobeta.minealexgames.com/workspace'),
      );
      expect(base, 'https://foliobeta.minealexgames.com');
    });

    test('resolveWebBaseUrl en prod usa origen actual', () {
      final base = FolioWebUrls.resolveWebBaseUrl(
        isWeb: true,
        currentUri: Uri.parse('https://folio.minealexgames.com/'),
      );
      expect(base, 'https://folio.minealexgames.com');
    });

    test('defineOverride gana sobre host', () {
      final base = FolioWebUrls.resolveWebBaseUrl(
        isWeb: true,
        currentUri: Uri.parse('https://folio.minealexgames.com/'),
        defineOverride: 'https://foliobeta.minealexgames.com',
      );
      expect(base, 'https://foliobeta.minealexgames.com');
    });

    test('fuera de web cae en producción', () {
      final base = FolioWebUrls.resolveWebBaseUrl(isWeb: false);
      expect(base, FolioWebUrls.productionBaseUrl);
    });
  });

  group('FolioWebUrls share URLs', () {
    test('vaultPublicShareUrl usa host de producción fuera de web beta', () {
      expect(
        FolioWebUrls.vaultPublicShareUrl('tok_abc'),
        'https://folio.minealexgames.com/s/tok_abc',
      );
    });

    test('resolveVaultPublicShareUrl reescribe viewer legacy del API', () {
      final url = FolioWebUrls.resolveVaultPublicShareUrl(
        publicUrlFromApi:
            'https://api.folio.com.es/api/v1/vault-shares/public/tok99/view',
      );
      expect(url, 'https://folio.minealexgames.com/s/tok99');
    });

    test('resolveVaultPublicShareUrl prioriza token', () {
      final url = FolioWebUrls.resolveVaultPublicShareUrl(
        token: 'local',
        publicUrlFromApi: 'https://folio.minealexgames.com/s/other',
      );
      expect(url, 'https://folio.minealexgames.com/s/local');
    });

    test('resetPasswordUrl y verifyEmailUrl incluyen query token', () {
      expect(
        FolioWebUrls.resetPasswordUrl('r1'),
        'https://folio.minealexgames.com/reset-password?token=r1',
      );
      expect(
        FolioWebUrls.verifyEmailUrl('v1'),
        'https://folio.minealexgames.com/verify-email?token=v1',
      );
      expect(
        FolioWebUrls.verifyStudentEmailUrl('s1'),
        'https://folio.minealexgames.com/verify-student-email?token=s1',
      );
    });
  });

  group('FolioWebPublicRoute.match', () {
    test('parsea /s/{token} en prod y beta', () {
      for (final host in [
        'https://folio.minealexgames.com',
        'https://foliobeta.minealexgames.com',
      ]) {
        final r = FolioWebPublicRoute.match(Uri.parse('$host/s/abc123'));
        expect(r, isA<FolioWebPublicShareRoute>());
        expect((r as FolioWebPublicShareRoute).token, 'abc123');
      }
    });

    test('parsea reset-password y verify-email en foliobeta', () {
      final reset = FolioWebPublicRoute.match(
        Uri.parse(
          'https://foliobeta.minealexgames.com/reset-password?token=rt',
        ),
      );
      expect(reset, isA<FolioWebResetPasswordRoute>());
      expect((reset as FolioWebResetPasswordRoute).token, 'rt');

      final verify = FolioWebPublicRoute.match(
        Uri.parse(
          'https://foliobeta.minealexgames.com/verify-email?token=vt',
        ),
      );
      expect(verify, isA<FolioWebVerifyEmailRoute>());
      expect((verify as FolioWebVerifyEmailRoute).token, 'vt');

      final student = FolioWebPublicRoute.match(
        Uri.parse(
          'https://foliobeta.minealexgames.com/verify-student-email?token=st',
        ),
      );
      expect(student, isA<FolioWebVerifyStudentEmailRoute>());
      expect((student as FolioWebVerifyStudentEmailRoute).token, 'st');
    });

    test('otras rutas no matchean', () {
      expect(
        FolioWebPublicRoute.match(Uri.parse('https://foliobeta.minealexgames.com/')),
        isNull,
      );
    });
  });
}
