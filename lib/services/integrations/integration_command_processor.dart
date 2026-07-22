import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../app/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/folio_task_data.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_firestore_support.dart';
import 'integration_command_parser.dart';

/// Procesa el buzón `pendingIntegrationCommands` al tener vault desbloqueado.
class IntegrationCommandProcessor {
  IntegrationCommandProcessor({
    required VaultSession session,
    required AppSettings appSettings,
  })  : _session = session,
        _appSettings = appSettings;

  final VaultSession _session;
  final AppSettings _appSettings;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _pollTimer;
  bool _processing = false;

  void bind() {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  void dispose() {
    _session.removeListener(_onSessionChanged);
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _onSessionChanged() {
    if (_session.state != VaultFlowState.unlocked ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _ensureListening();
    unawaited(_processPending());
  }

  void _ensureListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // En Windows el SDK C++ de Firestore puede tumbar el proceso; usamos solo
    // polling vía callable (Admin SDK), no list REST.
    if (!folioFirestoreSupported) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 45),
        (_) => unawaited(_processPending()),
      );
      return;
    }

    if (_subscription != null) return;

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pendingIntegrationCommands')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((_) => unawaited(_processPending()), onError: (Object e, StackTrace st) {
      AppLogger.warn(
        'integration commands listener failed',
        tag: 'integrations',
        context: {'error': '$e'},
      );
    });

    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_processPending()),
    );
  }

  AppLocalizations get _l10n =>
      lookupAppLocalizations(_session.titleLocale ?? const Locale('es'));

  Future<void> _processPending() async {
    if (_processing) return;
    if (_session.state != VaultFlowState.unlocked) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final vaultId = _session.activeVaultId?.trim();
    if (uid == null || vaultId == null || vaultId.isEmpty) return;

    _processing = true;
    try {
      if (folioFirestoreSupported) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('pendingIntegrationCommands')
            .where('status', isEqualTo: 'pending')
            .where('vaultId', isEqualTo: vaultId)
            .limit(20)
            .get();

        for (final doc in snap.docs) {
          await _applyCommand(doc.id, doc.data());
        }
      } else {
        // En Windows/Linux el listado REST de Firestore suele devolver 403
        // (PERMISSION_DENIED) aunque las reglas permitan list; usamos callable
        // con Admin SDK (mismo patrón que el resto de Folio Cloud en desktop).
        final pending = await _fetchPendingViaCallable(vaultId);
        for (final item in pending) {
          await _applyCommand(item.id, item.data);
        }
      }
    } catch (e, st) {
      AppLogger.warn(
        'integration commands processing failed',
        tag: 'integrations',
        context: {'error': '$e', 'stack': '$st'},
      );
    } finally {
      _processing = false;
    }
  }

  Future<List<({String id, Map<String, dynamic> data})>> _fetchPendingViaCallable(
    String vaultId,
  ) async {
    final raw = await callFolioHttpsCallable('folioListPendingIntegrationCommands', {
      'vaultId': vaultId,
      'limit': 20,
    });
    if (raw is! Map) return const [];
    final commands = raw['commands'];
    if (commands is! List) return const [];
    final out = <({String id, Map<String, dynamic> data})>[];
    for (final item in commands) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final id = (m['id'] as String? ?? '').trim();
      if (id.isEmpty) continue;
      out.add((id: id, data: m));
    }
    return out;
  }

  Future<void> _applyCommand(String commandId, Map<String, dynamic> data) async {
    final command = (data['command'] as String? ?? '').trim();
    switch (command) {
      case 'create_task':
        await _applyCreateTask(commandId, data);
      case 'list_tasks':
        await _applyListTasks(commandId);
      case 'complete_task':
        await _applyCompleteTask(commandId, data);
      default:
        await _ack(
          commandId: commandId,
          success: false,
          errorMessage: 'unsupported_command',
        );
    }
  }

  Future<void> _applyCreateTask(String commandId, Map<String, dynamic> data) async {
    final title = (data['title'] as String? ?? '').trim();
    if (title.isEmpty || title.length > IntegrationCommandParser.maxTaskTitleLength) {
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: 'invalid_title',
      );
      return;
    }

    try {
      final pageId = await _resolveTaskInboxPageId();
      final task = FolioTaskData.defaults().copyWith(title: title);
      final blockId = _session.appendTaskBlockReturningId(pageId: pageId, task: task);
      if (blockId.isEmpty) {
        await _ack(
          commandId: commandId,
          success: false,
          errorMessage: 'create_failed',
        );
        return;
      }
      await _ack(
        commandId: commandId,
        success: true,
        taskTitle: title,
        responseMessage: 'Created task "$title".',
      );
    } catch (e, st) {
      AppLogger.error(
        'integration command apply failed',
        tag: 'integrations',
        error: e,
        stackTrace: st,
      );
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _applyListTasks(String commandId) async {
    try {
      final entries = _session
          .collectTaskBlocks(includeSimpleTodos: false)
          .where((e) => !e.isDone)
          .take(10)
          .toList(growable: false);
      if (entries.isEmpty) {
        await _ack(
          commandId: commandId,
          success: true,
          responseMessage: 'No open tasks.',
        );
        return;
      }
      final lines = <String>[];
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final due = (e.dueDate ?? '').trim();
        final dueSuffix = due.isEmpty ? '' : ' (due $due)';
        lines.add('${i + 1}. ${e.displayTitle}$dueSuffix');
      }
      await _ack(
        commandId: commandId,
        success: true,
        responseMessage: 'Open tasks:\n${lines.join('\n')}',
      );
    } catch (e, st) {
      AppLogger.error(
        'integration list_tasks failed',
        tag: 'integrations',
        error: e,
        stackTrace: st,
      );
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _applyCompleteTask(
    String commandId,
    Map<String, dynamic> data,
  ) async {
    final title = (data['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: 'invalid_title',
      );
      return;
    }
    try {
      final needle = title.toLowerCase();
      final match = _session.collectTaskBlocks(includeSimpleTodos: false).where((e) {
        if (e.isDone) return false;
        return e.displayTitle.toLowerCase() == needle;
      }).firstOrNull;
      if (match == null || match.task == null) {
        await _ack(
          commandId: commandId,
          success: false,
          errorMessage: 'task_not_found',
          responseMessage: 'No open task titled "$title".',
        );
        return;
      }
      final updated = match.task!.copyWith(status: 'done');
      _session.updateBlockText(match.pageId, match.blockId, updated.encode());
      await _ack(
        commandId: commandId,
        success: true,
        taskTitle: title,
        responseMessage: 'Completed task "$title".',
      );
    } catch (e, st) {
      AppLogger.error(
        'integration complete_task failed',
        tag: 'integrations',
        error: e,
        stackTrace: st,
      );
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: '$e',
      );
    }
  }

  Future<String> _resolveTaskInboxPageId() async {
    final vaultId = _session.activeVaultId?.trim();
    if (vaultId == null || vaultId.isEmpty) {
      throw StateError('no_active_vault');
    }
    final existing = (await _appSettings.getTaskInboxPageId(vaultId))?.trim();
    if (existing != null &&
        existing.isNotEmpty &&
        _session.pages.any((p) => p.id == existing)) {
      return existing;
    }
    final pageId = _session.createTaskInboxPage(title: _l10n.taskInboxDefaultTitle);
    await _appSettings.setTaskInboxPageId(vaultId, pageId);
    return pageId;
  }

  Future<void> _ack({
    required String commandId,
    required bool success,
    String? taskTitle,
    String? errorMessage,
    String? responseMessage,
  }) async {
    try {
      await callFolioHttpsCallable('folioAckIntegrationCommand', {
        'commandId': commandId,
        'success': success,
        if (taskTitle != null) 'taskTitle': taskTitle,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (responseMessage != null) 'responseMessage': responseMessage,
      });
    } catch (e) {
      AppLogger.warn(
        'integration command ack failed',
        tag: 'integrations',
        context: {'commandId': commandId, 'error': '$e'},
      );
    }
  }
}
