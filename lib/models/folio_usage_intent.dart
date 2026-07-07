import 'dart:convert';

/// Cómo el usuario planea usar Folio; guía las páginas iniciales al crear una libreta.
enum FolioUsageIntent {
  notes,
  tasks,
  projects,
  knowledge,
  journal,
  study;

  static const int maxSelection = 3;

  String get storageId => name;

  static FolioUsageIntent? tryParse(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final intent in FolioUsageIntent.values) {
      if (intent.name == key) return intent;
    }
    return null;
  }

  static List<FolioUsageIntent> parseList(
    String? raw, {
    List<FolioUsageIntent> fallback = const [FolioUsageIntent.notes],
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return List<FolioUsageIntent>.from(fallback);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return List<FolioUsageIntent>.from(fallback);
      }
      final out = <FolioUsageIntent>[];
      for (final item in decoded) {
        final intent = tryParse('$item');
        if (intent != null && !out.contains(intent)) {
          out.add(intent);
        }
        if (out.length >= maxSelection) break;
      }
      return out.isEmpty
          ? List<FolioUsageIntent>.from(fallback)
          : out;
    } catch (_) {
      return List<FolioUsageIntent>.from(fallback);
    }
  }

  static String encodeList(Iterable<FolioUsageIntent> intents) {
    final unique = <FolioUsageIntent>[];
    for (final intent in intents) {
      if (!unique.contains(intent)) {
        unique.add(intent);
      }
      if (unique.length >= maxSelection) break;
    }
    return jsonEncode(unique.map((e) => e.storageId).toList());
  }

  static List<FolioUsageIntent> sanitizeSelection(
    Iterable<FolioUsageIntent> intents, {
    List<FolioUsageIntent> fallback = const [FolioUsageIntent.notes],
  }) {
    final out = <FolioUsageIntent>[];
    for (final intent in intents) {
      if (!out.contains(intent)) {
        out.add(intent);
      }
      if (out.length >= maxSelection) break;
    }
    return out.isEmpty ? List<FolioUsageIntent>.from(fallback) : out;
  }
}
