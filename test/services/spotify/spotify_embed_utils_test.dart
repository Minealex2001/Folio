import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/folio_spotify.dart';

void main() {
  group('folioSpotifyRefFromUrl', () {
    test('parsea open.spotify.com track', () {
      final ref = folioSpotifyRefFromUrl(
        'https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6',
      );
      expect(ref?.type, 'track');
      expect(ref?.id, '6rqhFgbbKwnb9MLmUQDhG6');
    });

    test('parsea spotify:playlist URI', () {
      final ref = folioSpotifyRefFromUrl('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M');
      expect(ref?.type, 'playlist');
      expect(ref?.id, '37i9dQZF1DXcBWIGoYBM5M');
    });

    test('genera embed URL', () {
      expect(
        folioSpotifyEmbedUrl('album', 'abc123'),
        'https://open.spotify.com/embed/album/abc123',
      );
    });

    test('devuelve null para URL no Spotify', () {
      expect(folioSpotifyRefFromUrl('https://example.com/foo'), isNull);
    });
  });
}
