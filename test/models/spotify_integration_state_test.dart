import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/spotify_integration_state.dart';

void main() {
  group('SpotifyIntegrationState', () {
    test('serializa y parsea conexión con preferencias zen', () {
      final expires = DateTime.utc(2026, 7, 20, 12);
      final conn = SpotifyConnection(
        id: 's1',
        label: 'Mi Spotify',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: expires,
        spotifyUserId: 'user123',
        displayName: 'Alejandro',
        focusPlaylistUri: 'spotify:playlist:abc',
        focusPlaylistName: 'Focus',
        zenAutoPlay: true,
        zenPauseOnExit: false,
      );
      final state = SpotifyIntegrationState(connections: [conn]);
      final parsed = SpotifyIntegrationState.fromJson(state.toJson());
      expect(parsed.connections.length, 1);
      final c = parsed.connections.first;
      expect(c.id, 's1');
      expect(c.spotifyUserId, 'user123');
      expect(c.focusPlaylistUri, 'spotify:playlist:abc');
      expect(c.zenAutoPlay, isTrue);
      expect(c.zenPauseOnExit, isFalse);
      expect(c.expiresAt.toUtc(), expires);
    });

    test('tryParse rechaza conexiones incompletas', () {
      expect(
        SpotifyConnection.tryParse(<String, dynamic>{
          'id': 'x',
          'label': 'x',
        }),
        isNull,
      );
    });
  });
}
