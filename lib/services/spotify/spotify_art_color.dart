import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Extrae el color dominante de una URL de imagen de carátula Spotify.
///
/// El resultado se devuelve como [Color] con alpha 1. Si falla (URL vacía,
/// error de red, etc.) devuelve `null`.
Future<Color?> extractSpotifyArtColor(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  try {
    final completer = Completer<ui.Image>();
    final stream = NetworkImage(url.trim()).resolve(
      ImageConfiguration.empty,
    );
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );
    stream.addListener(listener);
    final image = await completer.future.timeout(const Duration(seconds: 8));
    stream.removeListener(listener);

    // Renderizar a una miniatura 8×8 para promediar píxeles rápido.
    const size = 8;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(size, size);
    final byteData =
        await thumb.toByteData(format: ui.ImageByteFormat.rawRgba);
    thumb.dispose();
    picture.dispose();
    image.dispose();

    if (byteData == null) return null;
    return await compute(_dominantColor, byteData.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

/// Corre en un Isolate separado: calcula el color más vívido/saturado del
/// buffer RGBA (8×8 = 256 bytes mínimo).
Color? _dominantColor(Uint8List rgba) {
  if (rgba.length < 4) return null;
  final pixels = rgba.length ~/ 4;

  // Calculamos la media ponderada por saturación HSL para preferir
  // colores vívidos sobre el gris de fondos negros.
  double sumR = 0, sumG = 0, sumB = 0, totalW = 0;
  for (var i = 0; i < pixels; i++) {
    final r = rgba[i * 4] / 255.0;
    final g = rgba[i * 4 + 1] / 255.0;
    final b = rgba[i * 4 + 2] / 255.0;
    // Saturación HSL como peso: pixeles grises contribuyen poco.
    final mx = math.max(r, math.max(g, b));
    final mn = math.min(r, math.min(g, b));
    final l = (mx + mn) / 2;
    final sat = (mx == mn)
        ? 0.0
        : (l > 0.5 ? (mx - mn) / (2 - mx - mn) : (mx - mn) / (mx + mn));
    // Evitar fondos muy oscuros (l < 0.1) y muy claros (l > 0.92).
    if (l < 0.08 || l > 0.92) continue;
    final w = 0.2 + sat * 0.8; // mínimo 0.2 para no ignorar del todo grises
    sumR += r * w;
    sumG += g * w;
    sumB += b * w;
    totalW += w;
  }
  if (totalW == 0) return null;

  final r = (sumR / totalW).clamp(0.0, 1.0);
  final g = (sumG / totalW).clamp(0.0, 1.0);
  final b = (sumB / totalW).clamp(0.0, 1.0);

  // Boost de saturación: amplificar desviación respecto a la media.
  final avg = (r + g + b) / 3;
  const sat = 1.45; // factor de saturación
  final br = ((r - avg) * sat + avg).clamp(0.0, 1.0);
  final bg = ((g - avg) * sat + avg).clamp(0.0, 1.0);
  final bb = ((b - avg) * sat + avg).clamp(0.0, 1.0);

  return Color.fromARGB(255, (br * 255).round(), (bg * 255).round(), (bb * 255).round());
}

/// Oscurece un color para usarlo como fondo de texto (legibilidad garantizada).
Color spotifyArtColorBackground(Color dominant, {double darkness = 0.55}) {
  final hsl = HSLColor.fromColor(dominant);
  return hsl
      .withLightness((hsl.lightness * (1 - darkness)).clamp(0.05, 0.4))
      .withSaturation(hsl.saturation.clamp(0.3, 1.0))
      .toColor();
}

/// Color de texto que contraste con [bg] (blanco u oscuro).
Color spotifyArtColorForeground(Color bg) {
  final l = (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b);
  return l > 0.4 ? Colors.black87 : Colors.white;
}
