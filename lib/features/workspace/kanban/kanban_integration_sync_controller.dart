import 'package:flutter/foundation.dart';

/// Tracks in-flight external-integration sync operations for the Kanban
/// board (Jira, YouTrack, Trello, GitHub, GitLab), deduplicating the
/// busy-flag bookkeeping that used to be repeated once per provider in
/// `_KanbanBoardPageState`.
///
/// Each provider's pull/push sequencing, messaging and error formatting
/// stay call-site-specific (they genuinely differ), so this controller
/// only owns what was truly identical across all five: the "already
/// running? skip" guard and the busy-state notification around [action].
class KanbanIntegrationSyncController {
  final Map<String, bool> _busy = {};

  bool isBusy(String key) => _busy[key] ?? false;

  Future<void> run(
    String key,
    Future<void> Function() action, {
    required VoidCallback onStateChanged,
  }) async {
    if (isBusy(key)) return;
    _busy[key] = true;
    onStateChanged();
    try {
      await action();
    } finally {
      _busy[key] = false;
      onStateChanged();
    }
  }
}
