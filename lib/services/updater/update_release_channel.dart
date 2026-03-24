/// Canal de actualización respecto a GitHub Releases.
enum UpdateReleaseChannel {
  /// Última release estable (excluye prereleases): API `releases/latest`.
  stable,

  /// Última release marcada como prerelease en GitHub (betas).
  beta,
}
