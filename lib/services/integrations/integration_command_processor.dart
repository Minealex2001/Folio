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
    // En Windows el SDK C++ de Firestore crashea el proceso (0xE06D7363) y
    // la API REST no permite listar subcolecciones sin regla `list` explícita.
    // Los comandos entrantes de Slack/Teams no son funcionales en Windows de
    // todas formas; simplemente no hacemos polling.
    if (!folioFirestoreSupported) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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
    if (!folioFirestoreSupported) return;
    if (_processing) return;
    if (_session.state != VaultFlowState.unlocked) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final vaultId = _session.activeVaultId?.trim();
    if (uid == null || vaultId == null || vaultId.isEmpty) return;

    _processing = true;
    try {
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
    } catch (e, st) {
      AppLogger.error(
        'integration commands processing failed',
        tag: 'integrations',
        error: e,
        stackTrace: st,
      );
    } finally {
      _processing = false;
    }
  }

  Future<void> _applyCommand(String commandId, Map<String, dynamic> data) async {
    final command = (data['command'] as String? ?? '').trim();
    if (command != 'create_task') {
      await _ack(
        commandId: commandId,
        success: false,
        errorMessage: 'unsupported_command',
      );
      return;
    }
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
      await _ack(commandId: commandId, success: true, taskTitle: title);
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
  }) async {
    try {
      await callFolioHttpsCallable('folioAckIntegrationCommand', {
        'commandId': commandId,
        'success': success,
        if (taskTitle != null) 'taskTitle': taskTitle,
        if (errorMessage != null) 'errorMessage': errorMessage,
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
