import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_settings.dart';

class FolioIconTokenView extends StatelessWidget {
  const FolioIconTokenView({
    super.key,
    required this.appSettings,
    required this.token,
    required this.fallbackText,
    this.size = 20,
  });

  final AppSettings appSettings;
  final String? token;
  final String fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = token?.trim();
    final customIcon = appSettings.customIconForToken(raw);
    if (customIcon != null) {
      if (customIcon.isSvg) {
        return SvgPicture.file(
          File(customIcon.filePath),
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _fallback(),
        );
      }
      return Image.file(
        File(customIcon.filePath),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    final text = (raw == null || raw.isEmpty) ? fallbackText : raw;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(text, style: TextStyle(fontSize: size * 0.82)),
      ),
    );
  }

  Widget _fallback() {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(fallbackText, style: TextStyle(fontSize: size * 0.82)),
      ),
    );
  }
}
