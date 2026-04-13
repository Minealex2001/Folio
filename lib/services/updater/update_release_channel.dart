/// Canal de actualización respecto a GitHub Releases.
enum UpdateReleaseChannel {
  /// Ultima release estable (excluye prereleases): API `releases/latest`.
  stable,

  /// Betas y estables: versión más nueva entre última estable y última pre-release
  /// en GitHub (con instalador para la plataforma).
  beta,
}
