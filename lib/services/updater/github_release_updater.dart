import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../app/folio_distribution.dart';
import '../app_logger.dart';
import 'update_release_channel.dart';

class GitHubReleaseUpdater {
  GitHubReleaseUpdater({
    required this.owner,
    required this.repo,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String owner;
  final String repo;
  final http.Client _httpClient;

  Future<UpdateCheckResult> checkForUpdate({
    required UpdateReleaseChannel channel,
  }) async {
    if (kIsWeb) {
      return UpdateCheckResult.unsupportedPlatform();
    }
    final supportsPlatform = Platform.isWindows || Platform.isAndroid;
    if (!supportsPlatform) {
      return UpdateCheckResult.unsupportedPlatform();
    }
    if (!FolioDistribution.offersGitHubSelfUpdate) {
      final currentVersion = await _currentVersion();
      return UpdateCheckResult.noUpdate(currentVersion: currentVersion);
    }

    final currentVersion = await _currentVersion();
    _GitHubRelease? release;
    var releaseIsPrerelease = false;
    switch (channel) {
      case UpdateReleaseChannel.stable:
        release = await _fetchLatestStableRelease();
        releaseIsPrerelease = false;
        break;
      case UpdateReleaseChannel.beta:
        // Canal beta: la actualización puede ser la última estable **o** la última
        // pre-release, la que tenga semver mayor (y asset de instalador).
        final ranked = await _pickBestBetaChannelRelease(currentVersion);
        if (ranked != null) {
          release = ranked.release;
          releaseIsPrerelease = ranked.isPrerelease;
        }
        break;
    }
    if (release == null) {
      return UpdateCheckResult.noUpdate(
        currentVersion: currentVersion,
        reason: channel == UpdateReleaseChannel.beta
            ? 'No hay en GitHub una versión estable o pre-release más nueva con instalador para esta plataforma.'
            : null,
      );
    }
    final remoteVersion = release.parsedVersion;
    if (remoteVersion == null) {
      AppLogger.warn(
        'No se pudo parsear tag semver del release',
        tag: 'updater',
        context: {'tagName': release.tagName},
      );
      return UpdateCheckResult.noUpdate(currentVersion: currentVersion);
    }

    if (remoteVersion <= currentVersion) {
      return UpdateCheckResult.noUpdate(currentVersion: currentVersion);
    }

    final releaseAsset = _pickReleaseAssetForCurrentPlatform(release.assets);
    if (releaseAsset == null) {
      final missingAssetReason = Platform.isAndroid
          ? 'No se encontró asset APK instalable para Android en el release.'
          : 'No se encontró asset .exe instalador en el release.';
      return UpdateCheckResult.noUpdate(
        currentVersion: currentVersion,
        reason: missingAssetReason,
      );
    }

    return UpdateCheckResult.updateAvailable(
      currentVersion: currentVersion,
      releaseVersion: remoteVersion,
      releaseName: release.name,
      releaseNotes: release.body,
      installerAssetName: releaseAsset.name,
      installerUrl: releaseAsset.browserDownloadUrl,
      publishedAt: release.publishedAt,
      isPrerelease: releaseIsPrerelease,
    );
  }

  /// Para [UpdateReleaseChannel.beta]: elige entre última estable y última pre-release
  /// la versión semver mayor (empate → preferir estable).
  Future<_RankedRelease?> _pickBestBetaChannelRelease(
    Version currentVersion,
  ) async {
    _GitHubRelease? stable;
    try {
      stable = await _fetchLatestStableRelease();
    } catch (e, st) {
      AppLogger.warn(
        'Updater: no se pudo obtener release estable (canal beta)',
        tag: 'updater',
        context: {'error': e.toString(), 'stack': st.toString()},
      );
    }
    _GitHubRelease? pre;
    try {
      pre = await _fetchLatestPrereleaseRelease();
    } catch (e, st) {
      AppLogger.warn(
        'Updater: no se pudo listar pre-releases (canal beta)',
        tag: 'updater',
        context: {'error': e.toString(), 'stack': st.toString()},
      );
    }

    _RankedRelease? best;
    void consider(_GitHubRelease? rel, bool isPre) {
      if (rel == null) return;
      final v = rel.parsedVersion;
      if (v == null || v <= currentVersion) return;
      if (_pickReleaseAssetForCurrentPlatform(rel.assets) == null) return;
      if (best == null) {
        best = _RankedRelease(release: rel, version: v, isPrerelease: isPre);
        return;
      }
      if (v > best!.version) {
        best = _RankedRelease(release: rel, version: v, isPrerelease: isPre);
      } else if (v == best!.version && !isPre && best!.isPrerelease) {
        best = _RankedRelease(release: rel, version: v, isPrerelease: isPre);
      }
    }

    consider(stable, false);
    consider(pre, true);
    return best;
  }

  Future<ReleaseNotesResult?> fetchReleaseNotesForVersion({
    required String appVersion,
    String? buildNumber,
  }) async {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) {
        candidates.add(trimmed);
      }
    }

    final version = appVersion.trim();
    final build = (buildNumber ?? '').trim();
    addCandidate(version);
    if (build.isNotEmpty) {
      addCandidate('$version+$build');
    }
    final plusIndex = version.indexOf('+');
    if (plusIndex > 0) {
      addCandidate(version.substring(0, plusIndex));
    }

    final expandedCandidates = <String>[];
    final expandedSeen = <String>{};
    for (final candidate in candidates) {
      if (expandedSeen.add(candidate)) {
        expandedCandidates.add(candidate);
      }
      final noV = candidate.replaceFirst(RegExp(r'^v'), '');
      final withV = 'v$noV';
      if (expandedSeen.add(withV)) {
        expandedCandidates.add(withV);
      }
    }

    for (final tag in expandedCandidates) {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/releases/tags/$tag',
      );
      final response = await _httpClient.get(uri, headers: _headers());
      if (response.statusCode == 404) {
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'No se pudo consultar release por tag en GitHub: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Respuesta inválida de GitHub releases por tag.',
        );
      }
      final release = _GitHubRelease.fromJson(decoded);
      return ReleaseNotesResult(
        tagName: release.tagName,
        releaseVersion: release.parsedVersion,
        releaseName: release.name,
        releaseNotes: release.body,
        publishedAt: release.publishedAt,
      );
    }
    return null;
  }

  Future<File> downloadInstaller(UpdateCheckResult update) async {
    if (!update.hasUpdate) {
      throw StateError('No hay actualización disponible para descargar.');
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = update.installerAssetName ?? 'Folio-Setup-update.exe';
    final installerPath = p.join(tempDir.path, safeName);
    final file = File(installerPath);
    final uri = Uri.parse(update.installerUrl!);
    final response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Error al descargar instalador: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  Future<void> launchInstallerAndExit(File installerFile) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Solo soportado en Windows.');
    }
    if (!await installerFile.exists()) {
      throw FileSystemException(
        'No existe el instalador descargado.',
        installerFile.path,
      );
    }

    // Inno Setup: sin asistente ni mensajes que requieran clic (ver installer.iss).
    await Process.start(installerFile.path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NOCANCEL',
      '/SP-',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<Version> _currentVersion() async {
    final pkg = await PackageInfo.fromPlatform();
    final name = pkg.version.trim();
    final build = pkg.buildNumber.trim();
    // En Flutter, pubspec `0.0.2+3` suele exponerse como version=0.0.2 y buildNumber=3.
    if (name.contains('+')) {
      return _parseSemver(name) ?? Version.none;
    }
    if (build.isNotEmpty) {
      final combined = '$name+$build';
      return _parseSemver(combined) ?? _parseSemver(name) ?? Version.none;
    }
    return _parseSemver(name) ?? Version.none;
  }

  Future<_GitHubRelease?> _fetchLatestStableRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases/latest',
    );
    final response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo consultar releases en GitHub: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta inválida de GitHub releases.');
    }
    return _GitHubRelease.fromJson(decoded);
  }

  /// Lista de releases (más recientes primero); primer prerelease no borrador.
  Future<_GitHubRelease?> _fetchLatestPrereleaseRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases',
      const {'per_page': '30'},
    );
    final response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo listar releases en GitHub: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Respuesta inválida de GitHub releases.');
    }
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      if (item['draft'] == true) continue;
      if (item['prerelease'] != true) continue;
      return _GitHubRelease.fromJson(item);
    }
    return null;
  }

  Map<String, String> _headers() {
    return const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'folio-updater',
    };
  }

  Version? _parseSemver(String input) {
    final normalized = input.trim().replaceFirst(RegExp(r'^v'), '');
    try {
      return Version.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  _GitHubReleaseAsset? _pickWindowsInstallerAsset(List<_GitHubReleaseAsset> a) {
    for (final asset in a) {
      final lower = asset.name.toLowerCase();
      if (!lower.endsWith('.exe')) continue;
      if (lower.contains('setup') || lower.contains('installer')) return asset;
    }
    for (final asset in a) {
      if (asset.name.toLowerCase().endsWith('.exe')) return asset;
    }
    return null;
  }

  _GitHubReleaseAsset? _pickAndroidInstallerAsset(List<_GitHubReleaseAsset> a) {
    for (final asset in a) {
      final lower = asset.name.toLowerCase();
      if (!lower.endsWith('.apk')) continue;
      if (lower.contains('release') || lower.contains('arm64')) return asset;
    }
    for (final asset in a) {
      if (asset.name.toLowerCase().endsWith('.apk')) return asset;
    }
    return null;
  }

  _GitHubReleaseAsset? _pickReleaseAssetForCurrentPlatform(
    List<_GitHubReleaseAsset> assets,
  ) {
    if (Platform.isWindows) {
      return _pickWindowsInstallerAsset(assets);
    }
    if (Platform.isAndroid) {
      return _pickAndroidInstallerAsset(assets);
    }
    return null;
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    required this.supportedPlatform,
    required this.currentVersion,
    this.releaseVersion,
    this.releaseName,
    this.releaseNotes,
    this.installerAssetName,
    this.installerUrl,
    this.reason,
    this.publishedAt,
    this.isPrerelease = false,
  });

  UpdateCheckResult.unsupportedPlatform()
    : this(
        hasUpdate: false,
        supportedPlatform: false,
        currentVersion: Version.none,
      );

  factory UpdateCheckResult.noUpdate({
    required Version currentVersion,
    String? reason,
  }) {
    return UpdateCheckResult(
      hasUpdate: false,
      supportedPlatform: true,
      currentVersion: currentVersion,
      reason: reason,
    );
  }

  factory UpdateCheckResult.updateAvailable({
    required Version currentVersion,
    required Version releaseVersion,
    required String? releaseName,
    required String? releaseNotes,
    required String installerAssetName,
    required String installerUrl,
    required DateTime? publishedAt,
    bool isPrerelease = false,
  }) {
    return UpdateCheckResult(
      hasUpdate: true,
      supportedPlatform: true,
      currentVersion: currentVersion,
      releaseVersion: releaseVersion,
      releaseName: releaseName,
      releaseNotes: releaseNotes,
      installerAssetName: installerAssetName,
      installerUrl: installerUrl,
      publishedAt: publishedAt,
      isPrerelease: isPrerelease,
    );
  }

  final bool hasUpdate;
  final bool supportedPlatform;
  final Version currentVersion;
  final Version? releaseVersion;
  final String? releaseName;
  final String? releaseNotes;
  final String? installerAssetName;
  final String? installerUrl;
  final String? reason;
  final DateTime? publishedAt;
  final bool isPrerelease;
}

class ReleaseNotesResult {
  const ReleaseNotesResult({
    required this.tagName,
    required this.releaseVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.publishedAt,
  });

  final String tagName;
  final Version? releaseVersion;
  final String? releaseName;
  final String? releaseNotes;
  final DateTime? publishedAt;
}

class _RankedRelease {
  _RankedRelease({
    required this.release,
    required this.version,
    required this.isPrerelease,
  });

  final _GitHubRelease release;
  final Version version;
  final bool isPrerelease;
}

class _GitHubRelease {
  _GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    required this.publishedAt,
  });

  factory _GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_GitHubReleaseAsset.fromJson)
        .toList();
    return _GitHubRelease(
      tagName: (json['tag_name'] as String? ?? '').trim(),
      name: (json['name'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      assets: assets,
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
    );
  }

  final String tagName;
  final String? name;
  final String? body;
  final List<_GitHubReleaseAsset> assets;
  final DateTime? publishedAt;

  Version? get parsedVersion {
    final normalized = tagName.replaceFirst(RegExp(r'^v'), '');
    try {
      return Version.parse(normalized);
    } catch (_) {
      return null;
    }
  }
}

class _GitHubReleaseAsset {
  _GitHubReleaseAsset({required this.name, required this.browserDownloadUrl});

  factory _GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return _GitHubReleaseAsset(
      name: (json['name'] as String? ?? '').trim(),
      browserDownloadUrl: (json['browser_download_url'] as String? ?? '')
          .trim(),
    );
  }

  final String name;
  final String browserDownloadUrl;
}
