import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/custom_icons/custom_icon_blob_store.dart';
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
      return _buildFileIcon(customIcon.filePath, customIcon.isSvg);
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

  Widget _buildFileIcon(String storageKey, bool isSvg) {
    return FutureBuilder<Uint8List?>(
      future: CustomIconBlobStore.instance.read(storageKey),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null || data.isEmpty) return _fallback();
        if (isSvg) {
          return SvgPicture.memory(
            data,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _fallback(),
          );
        }
        return Image.memory(
          data,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallback(),
        );
      },
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
