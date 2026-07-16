import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../models/folio_app_package.dart';

/// Resultado de cargar un paquete .folioapp.
sealed class FolioAppLoadResult {}

class FolioAppLoadSuccess extends FolioAppLoadResult {
  FolioAppLoadSuccess({required this.package, required this.extractedPath});

  final FolioAppPackage package;

  /// Directorio local donde se extrajeron los archivos del paquete.
  final String extractedPath;
}

class FolioAppLoadError extends FolioAppLoadResult {
  FolioAppLoadError(this.message);
  final String message;
}

/// Carga, valida y extrae paquetes .folioapp (archivos ZIP renombrados).
class FolioAppPackageLoader {
  const FolioAppPackageLoader();

  static const _manifestFileName = 'manifest.json';

  /// Carga un paquete desde un archivo local [filePath] (.folioapp).
  /// Extrae el contenido en [destinationDir] / [packageId] y devuelve el resultado.
  Future<FolioAppLoadResult> loadFromFile(
    String filePath, {
    required String destinationDir,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return FolioAppLoadError('Archivo no encontrado: $filePath');
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      return FolioAppLoadError('No se pudo leer el archivo: $e');
    }

    return _loadFromBytes(bytes, destinationDir: destinationDir);
  }

  /// Carga un paquete descargado desde [bytes].
  Future<FolioAppLoadResult> loadFromBytes(
    Uint8List bytes, {
    required String destinationDir,
  }) {
    return _loadFromBytes(bytes, destinationDir: destinationDir);
  }

  Future<FolioAppLoadResult> _loadFromBytes(
    Uint8List bytes, {
    required String destinationDir,
  }) async {
    // 1. Descomprimir ZIP
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return FolioAppLoadError('El archivo no es un ZIP válido: $e');
    }

    // 2. Leer manifest.json
    final manifestFile = archive.findFile(_manifestFileName);
    if (manifestFile == null) {
      return FolioAppLoadError('Falta $_manifestFileName en el paquete.');
    }

    final FolioAppPackage package;
    try {
      final json = utf8.decode(manifestFile.content as List<int>);
      package = FolioAppPackage.fromJsonString(json);
    } catch (e) {
      return FolioAppLoadError('manifest.json inválido: $e');
    }

    // 3. Validar ID
    if (package.id.isEmpty || !FolioAppPackage.isValidId(package.id)) {
      return FolioAppLoadError(
        'ID de app inválido: "${package.id}". Usa formato reverse-domain (p. ej. com.empresa.app).',
      );
    }

    // 4. Extraer al directorio de destino
    final extractedPath = p.join(destinationDir, package.id);
    try {
      await _extractArchive(archive, extractedPath);
    } catch (e) {
      return FolioAppLoadError('Error extrayendo archivos: $e');
    }

    return FolioAppLoadSuccess(package: package, extractedPath: extractedPath);
  }

  Future<void> _extractArchive(Archive archive, String dest) async {
    final destDir = Directory(dest);
    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }
    await destDir.create(recursive: true);

    for (final entry in archive) {
      // Sanitize: evitar path traversal
      final entryPath = entry.name.replaceAll(RegExp(r'\.\.[\\/]'), '');
      final outPath = p.join(dest, entryPath);

      if (entry.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  /// Elimina los archivos de una app del directorio de instalación.
  Future<void> uninstall(String extractedPath) async {
    final dir = Directory(extractedPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
