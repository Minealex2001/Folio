import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Atajos editables del workspace (persistidos en [AppSettings], no en la libreta).
enum FolioInAppShortcut {
  search,
  newPage,
  quickAddTask,
  settings,
  lock,
  pageNext,
  pagePrev,
  closePage,
}

extension FolioInAppShortcutLabels on FolioInAppShortcut {
  String get settingsLabel => switch (this) {
    FolioInAppShortcut.search => 'Buscar en la libreta',
    FolioInAppShortcut.newPage => 'Nueva página',
    FolioInAppShortcut.quickAddTask => 'Captura rápida de tarea',
    FolioInAppShortcut.settings => 'Abrir ajustes',
    FolioInAppShortcut.lock => 'Bloquear libreta',
    FolioInAppShortcut.pageNext => 'Página siguiente',
    FolioInAppShortcut.pagePrev => 'Página anterior',
    FolioInAppShortcut.closePage => 'Cerrar página actual',
  };

  SingleActivator get defaultActivator => switch (this) {
    FolioInAppShortcut.search => const SingleActivator(
      LogicalKeyboardKey.keyK,
      control: true,
    ),
    FolioInAppShortcut.newPage => const SingleActivator(
      LogicalKeyboardKey.keyN,
      control: true,
    ),
    FolioInAppShortcut.quickAddTask => const SingleActivator(
      LogicalKeyboardKey.keyT,
      control: true,
      shift: true,
    ),
    FolioInAppShortcut.settings => const SingleActivator(
      LogicalKeyboardKey.comma,
      control: true,
    ),
    FolioInAppShortcut.lock => const SingleActivator(
      LogicalKeyboardKey.keyL,
      control: true,
    ),
    FolioInAppShortcut.pageNext => const SingleActivator(
      LogicalKeyboardKey.bracketRight,
      alt: true,
    ),
    FolioInAppShortcut.pagePrev => const SingleActivator(
      LogicalKeyboardKey.bracketLeft,
      alt: true,
    ),
    FolioInAppShortcut.closePage => const SingleActivator(
      LogicalKeyboardKey.keyW,
      control: true,
    ),
  };
}

String describeActivator(SingleActivator a) {
  final parts = <String>[];
  if (a.control) parts.add('Ctrl');
  if (a.meta) parts.add('Meta');
  if (a.alt) parts.add('Alt');
  if (a.shift) parts.add('Mayús');
  final k = a.trigger;
  var keyName = k.keyLabel;
  if (keyName.isEmpty) {
    keyName = k.debugName ?? '?';
  }
  parts.add(keyName);
  return parts.join(' + ');
}

Map<String, dynamic> activatorToJson(SingleActivator a) => {
  'key': a.trigger.keyId,
  'control': a.control,
  'shift': a.shift,
  'alt': a.alt,
  'meta': a.meta,
};

SingleActivator? activatorFromJson(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final keyId = m['key'] as int?;
  if (keyId == null) return null;
  final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
  if (key == null) return null;
  return SingleActivator(
    key,
    control: m['control'] as bool? ?? false,
    shift: m['shift'] as bool? ?? false,
    alt: m['alt'] as bool? ?? false,
    meta: m['meta'] as bool? ?? false,
  );
}

String serializeShortcutOverrides(Map<FolioInAppShortcut, SingleActivator> map) {
  final out = <String, Map<String, dynamic>>{};
  for (final e in map.entries) {
    out[e.key.name] = activatorToJson(e.value);
  }
  return jsonEncode(out);
}

Map<FolioInAppShortcut, SingleActivator> parseShortcutOverrides(
  String? raw,
  Map<FolioInAppShortcut, SingleActivator> defaults,
) {
  final next = Map<FolioInAppShortcut, SingleActivator>.from(defaults);
  if (raw == null || raw.trim().isEmpty) return next;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return next;
    for (final id in FolioInAppShortcut.values) {
      final v = decoded[id.name];
      if (v == null) continue;
      final a = activatorFromJson(v);
      if (a != null) next[id] = a;
    }
  } catch (_) {}
  return next;
}

Map<FolioInAppShortcut, SingleActivator> defaultShortcutMap() => {
  for (final id in FolioInAppShortcut.values) id: id.defaultActivator,
};
