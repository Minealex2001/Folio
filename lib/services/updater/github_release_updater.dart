import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../core/errors/folio_exception.dart';
import '../../app/folio_distribution.dart';
import '../app_logger.dart';
import 'update_release_channel.dart';

class GitHubReleaseUpdater {
  GitHubReleaseUpdater({
    required this.owner,
    required this.repo,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Timeout para llamadas a la API de GitHub.
  static const Duration _apiTimeout = Duration(seconds: 30);

  /// Timeout para la descarga del instalador (archivos grandes).
  static const Duration _downloadTimeout = Duration(minutes: 10);

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
    final ranked = await _pickBestReleaseForChannel(
      channel: channel,
      currentVersion: currentVersion,
    );
    if (ranked == null) {
      return UpdateCheckResult.noUpdate(
        currentVersion: currentVersion,
        reason: channel == UpdateReleaseChannel.beta
            ? 'No hay en GitHub una versión estable o pre-release más nueva con instalador para esta plataforma.'
            : 'No hay en GitHub una versión estable más nueva con instalador para esta plataforma.',
      );
    }

    final release = ranked.release;
    final remoteVersion = ranked.version;
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
      installerSha256: releaseAsset.sha256Digest,
      publishedAt: release.publishedAt,
      isPrerelease: ranked.isPrerelease,
    );
  }

  /// Elige la mejor release elegible para el canal y la plataforma actual.
  Future<_RankedRelease?> _pickBestReleaseForChannel({
    required UpdateReleaseChannel channel,
    required Version currentVersion,
  }) async {
    final releases = await _listReleases(perPage: 40);
    _RankedRelease? best;
    for (final release in releases) {
      if (release.draft) continue;
      if (channel == UpdateReleaseChannel.stable && release.prerelease) {
        continue;
      }
      if (!_tagMatchesCurrentPlatform(release.tagName)) continue;
      final version = release.parsedVersion;
      if (version == null || version <= currentVersion) continue;
      if (_pickReleaseAssetForCurrentPlatform(release.assets) == null) continue;

      final isPre = release.prerelease;
      final isGlobal = _isGlobalReleaseTag(release.tagName);
      if (best == null) {
        best = _RankedRelease(
          release: release,
          version: version,
          isPrerelease: isPre,
          isGlobalTag: isGlobal,
        );
        continue;
      }
      if (version > best.version) {
        best = _RankedRelease(
          release: release,
          version: version,
          isPrerelease: isPre,
          isGlobalTag: isGlobal,
        );
      } else if (version == best.version) {
        // Empate semver: preferir estable sobre pre; luego tag global.
        if (!isPre && best.isPrerelease) {
          best = _RankedRelease(
            release: release,
            version: version,
            isPrerelease: isPre,
            isGlobalTag: isGlobal,
          );
        } else if (isPre == best.isPrerelease && isGlobal && !best.isGlobalTag) {
          best = _RankedRelease(
            release: release,
            version: version,
            isPrerelease: isPre,
            isGlobalTag: isGlobal,
          );
        }
      }
    }
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
      // Tags por plataforma (v1.4.0-android, …).
      for (final suffix in const ['android', 'windows', 'linux', 'macos']) {
        final platformTag = 'v$noV-$suffix';
        if (expandedSeen.add(platformTag)) {
          expandedCandidates.add(platformTag);
        }
      }
    }

    for (final tag in expandedCandidates) {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/releases/tags/$tag',
      );
      final response = await _httpClient
          .get(uri, headers: _headers())
          .timeout(_apiTimeout);
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

  /// Descarga el instalador con progreso opcional [onProgress] (0.0–1.0).
  /// Si la respuesta no incluye Content-Length, no se llama a [onProgress]
  /// hasta completar (la UI puede mostrar barra indeterminada).
  Future<File> downloadInstaller(
    UpdateCheckResult update, {
    void Function(double progress)? onProgress,
  }) async {
    if (!update.hasUpdate) {
      throw StateError('No hay actualización disponible para descargar.');
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = update.installerAssetName ?? 'Folio-Setup-update.exe';
    final installerPath = p.join(tempDir.path, safeName);
    final file = File(installerPath);
    final uri = Uri.parse(update.installerUrl!);

    final request = http.Request('GET', uri);
    request.headers.addAll(_headers());
    final streamed = await _httpClient
        .send(request)
        .timeout(_downloadTimeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException(
        'Error al descargar instalador: HTTP ${streamed.statusCode}',
        uri: uri,
      );
    }

    final total = streamed.contentLength ?? 0;
    var received = 0;
    IOSink? sink;
    try {
      if (await file.exists()) {
        await file.delete();
      }
      sink = file.openWrite();
      await for (final chunk in streamed.stream.timeout(_downloadTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } catch (_) {
      await sink?.close();
      sink = null;
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      await sink?.close();
    }
    onProgress?.call(1.0);

    // Integridad: verificar SHA-256 del fichero antes de ejecutarlo.
    final expected = (update.installerSha256 ?? '').trim().toLowerCase();
    if (expected.isNotEmpty) {
      final bytes = await file.readAsBytes();
      final hash = await Sha256().hash(bytes);
      final actual = hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (actual != expected) {
        try {
          await file.delete();
        } catch (_) {}
        throw UpdateIntegrityException(
          'El instalador descargado no coincide con el checksum SHA-256 '
          'publicado (esperado $expected, obtenido $actual). '
          'Descarga cancelada por seguridad.',
        );
      }
    } else {
      AppLogger.warn(
        'Release sin digest SHA-256; no se pudo verificar integridad',
        tag: 'updater',
        context: {'asset': safeName},
      );
    }
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

  Future<List<_GitHubRelease>> _listReleases({int perPage = 40}) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases',
      {'per_page': '$perPage'},
    );
    final response = await _httpClient
        .get(uri, headers: _headers())
        .timeout(_apiTimeout);
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
    final out = <_GitHubRelease>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      out.add(_GitHubRelease.fromJson(item));
    }
    return out;
  }

  Map<String, String> _headers() {
    return const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'folio-updater',
    };
  }

  /// Sufijos de tag por plataforma: `v1.4.0-android`, `v1.4.0-windows`, …
  static final RegExp _platformTagSuffix = RegExp(
    r'-(android|windows|linux|macos)$',
    caseSensitive: false,
  );

  static String _stripPlatformTagSuffix(String tagOrVersion) {
    final noV = tagOrVersion.trim().replaceFirst(RegExp(r'^v'), '');
    return noV.replaceFirst(_platformTagSuffix, '');
  }

  static bool _isGlobalReleaseTag(String tagName) {
    final noV = tagName.trim().replaceFirst(RegExp(r'^v'), '');
    return !_platformTagSuffix.hasMatch(noV);
  }

  /// Tag global o de la plataforma actual (Windows/Android).
  bool _tagMatchesCurrentPlatform(String tagName) {
    final noV = tagName.trim().replaceFirst(RegExp(r'^v'), '');
    final match = _platformTagSuffix.firstMatch(noV);
    if (match == null) return true; // global
    final platform = match.group(1)!.toLowerCase();
    if (Platform.isAndroid) return platform == 'android';
    if (Platform.isWindows) return platform == 'windows';
    if (Platform.isLinux) return platform == 'linux';
    if (Platform.isMacOS) return platform == 'macos';
    return false;
  }

  Version? _parseSemver(String input) {
    final normalized = _stripPlatformTagSuffix(input);
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
    this.installerSha256,
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
    String? installerSha256,
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
      installerSha256: installerSha256,
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

  /// SHA-256 (hex) esperado del instalador, según el digest del asset.
  final String? installerSha256;
  final String? reason;
  final DateTime? publishedAt;
  final bool isPrerelease;
}

/// El archivo descargado no supera la verificación de integridad.
class UpdateIntegrityException extends FolioException {
  const UpdateIntegrityException(super.message);
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
    this.isGlobalTag = true,
  });

  final _GitHubRelease release;
  final Version version;
  final bool isPrerelease;
  final bool isGlobalTag;
}

class _GitHubRelease {
  _GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    required this.publishedAt,
    this.draft = false,
    this.prerelease = false,
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
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
    );
  }

  final String tagName;
  final String? name;
  final String? body;
  final List<_GitHubReleaseAsset> assets;
  final DateTime? publishedAt;
  final bool draft;
  final bool prerelease;

  Version? get parsedVersion {
    // Quitar sufijo de plataforma antes de parsear (v1.4.0-android → 1.4.0).
    final stripped = GitHubReleaseUpdater._stripPlatformTagSuffix(tagName);
    try {
      return Version.parse(stripped);
    } catch (_) {
      return null;
    }
  }
}

class _GitHubReleaseAsset {
  _GitHubReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.digest,
  });

  factory _GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return _GitHubReleaseAsset(
      name: (json['name'] as String? ?? '').trim(),
      browserDownloadUrl: (json['browser_download_url'] as String? ?? '')
          .trim(),
      digest: (json['digest'] as String?)?.trim(),
    );
  }

  final String name;
  final String browserDownloadUrl;

  /// Digest del asset según la API de GitHub, formato `sha256:<hex>`.
  final String? digest;

  /// SHA-256 en hex minúsculas, o `null` si GitHub no publicó digest.
  String? get sha256Digest {
    final d = (digest ?? '').trim().toLowerCase();
    if (!d.startsWith('sha256:')) return null;
    final hex = d.substring('sha256:'.length);
    return hex.length == 64 ? hex : null;
  }
}
