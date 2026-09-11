/// Proveedor de música “cuenta conectada” activo en Folio (exclusividad mutua).
enum ActiveMusicProvider {
  none,
  spotify,
  youtubeMusic,
}

extension ActiveMusicProviderCodec on ActiveMusicProvider {
  String get storageValue => switch (this) {
        ActiveMusicProvider.none => 'none',
        ActiveMusicProvider.spotify => 'spotify',
        ActiveMusicProvider.youtubeMusic => 'youtubeMusic',
      };

  static ActiveMusicProvider fromStorage(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'spotify':
        return ActiveMusicProvider.spotify;
      case 'youtubeMusic':
        return ActiveMusicProvider.youtubeMusic;
      default:
        return ActiveMusicProvider.none;
    }
  }
}
