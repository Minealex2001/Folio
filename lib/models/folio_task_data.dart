import 'dart:convert';

/// Datos de un bloque de tarea enriquecido (tipo `task`).
///
/// El contenido se almacena serializado en [FolioBlock.text] como JSON,
/// siguiendo el mismo patrón que [FolioToggleData] y [FolioTemplateButtonData].
class FolioTaskData {
  FolioTaskData({
    required this.title,
    required this.status,
    this.columnId,
    this.parentTaskId,
    this.blocked = false,
    this.blockedReason = '',
    this.priority,
    this.description = '',
    this.startDate,
    this.dueDate,
    this.recurrence,
    this.reminderEnabled = false,
    this.timeSpentMinutes,
    this.external,
    this.jira,
    List<FolioTaskSubtask>? subtasks,
    List<String>? tags,
    this.assignee,
    this.estimatedMinutes,
    this.storyPoints,
    Map<String, Object?>? customProperties,
    this.recurringRule,
    List<String>? blockedByTaskIds,
    this.aiGenerated = false,
    this.createdFromBlockId,
    this.aiContextPageId,
    this.confidenceScore,
    this.suggestedDueDate,
  })  : subtasks = List<FolioTaskSubtask>.from(subtasks ?? const []),
        tags = List<String>.unmodifiable(_normalizeTags(tags)),
        customProperties = Map<String, Object?>.unmodifiable(
          _normalizeCustomProperties(customProperties),
        ),
        blockedByTaskIds = List<String>.unmodifiable(
          _normalizeIdList(blockedByTaskIds),
        );

  static const int _kMaxCustomPropertyKeys = 32;
  static const int _kMaxTags = 64;

  static List<String> _normalizeTags(List<String>? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      final t = e.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(t);
      if (out.length >= _kMaxTags) break;
    }
    return out;
  }

  static List<String> _normalizeIdList(List<String>? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      final t = e.trim();
      if (t.isEmpty) continue;
      if (seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
      if (out.length >= 32) break;
    }
    return out;
  }

  static Map<String, Object?> _normalizeCustomProperties(
    Map<String, Object?>? raw,
  ) {
    if (raw == null || raw.isEmpty) return const {};
    final out = <String, Object?>{};
    for (final e in raw.entries) {
      final k = e.key.trim();
      if (k.isEmpty) continue;
      if (out.length >= _kMaxCustomPropertyKeys) break;
      final v = e.value;
      if (v == null ||
          v is String ||
          v is num ||
          v is bool ||
          v is List ||
          v is Map) {
        out[k] = v;
      }
    }
    return out;
  }

  /// Texto descriptivo de la tarea.
  final String title;

  /// Estado de la tarea: `'todo'`, `'in_progress'` o `'done'`.
  final String status;

  /// Columna Kanban (configurable por página). Si es null/vacío, la UI puede
  /// derivarla de [status] (compatibilidad).
  final String? columnId;

  /// Si no es null, esta tarea se considera subtarea de la tarea cuyo bloque id
  /// coincide con este valor (subtareas como tareas anidadas).
  final String? parentTaskId;

  /// Si true, la tarea está bloqueada.
  final bool blocked;

  /// Motivo de bloqueo (opcional).
  final String blockedReason;

  /// Prioridad opcional.
  ///
  /// Compatible con Jira por defecto: `'lowest'`, `'low'`, `'medium'`, `'high'`, `'highest'`.
  final String? priority;

  /// Descripción de la tarea (texto libre).
  final String description;

  /// Fecha de inicio opcional (ISO-8601 `'YYYY-MM-DD'`). Útil para Timeline.
  final String? startDate;

  /// Fecha límite opcional en formato ISO-8601 (`'YYYY-MM-DD'`).
  final String? dueDate;

  /// Recurrencia opcional: `'daily'`, `'weekly'`, `'monthly'` o `'yearly'`.
  final String? recurrence;

  /// Si true, el usuario quiere que la app le recuerde esta tarea cuando llegue [dueDate].
  final bool reminderEnabled;

  /// Tiempo invertido (acumulado) en minutos.
  final int? timeSpentMinutes;

  /// Enlace opcional a un proveedor externo (p. ej. Jira).
  final FolioExternalTaskLink? external;

  /// Snapshot opcional de campos Jira para UI rica sin refetch constante.
  final FolioJiraIssueSnapshot? jira;

  /// Subtareas opcionales asociadas a la tarea principal.
  final List<FolioTaskSubtask> subtasks;

  /// Etiquetas locales (no confundir con labels Jira en [jira]).
  final List<String> tags;

  /// Responsable u mención libre (texto).
  final String? assignee;

  /// Estimación de esfuerzo en minutos (p. ej. pomodoros × 25).
  final int? estimatedMinutes;

  /// Story points opcionales (p. ej. integración con tableros).
  final double? storyPoints;

  /// Propiedades flexibles serializables (tamaño acotado al guardar).
  final Map<String, Object?> customProperties;

  /// Regla RRULE opcional (iCalendar). Si está vacía, puede usarse [recurrence] legacy.
  final String? recurringRule;

  /// Ids de bloques `task` que bloquean esta tarea (dependencias).
  final List<String> blockedByTaskIds;

  /// Tarea generada o asistida por IA.
  final bool aiGenerated;

  /// Bloque de origen si la tarea se creó desde otro bloque.
  final String? createdFromBlockId;

  /// Página de contexto usada por la IA al crear la tarea.
  final String? aiContextPageId;

  /// Confianza del modelo al sugerir metadatos (0–1), opcional.
  final double? confidenceScore;

  /// Fecha sugerida por la IA (`YYYY-MM-DD` o ISO con tiempo).
  final String? suggestedDueDate;

  static const _validStatuses = {'todo', 'in_progress', 'done'};
  static const _validPriorities = {
    'lowest',
    'low',
    'medium',
    'high',
    'highest',
  };

  static const _validRecurrences = {'daily', 'weekly', 'monthly', 'yearly'};

  static FolioTaskData defaults() => FolioTaskData(
    title: '',
    status: 'todo',
    columnId: null,
    parentTaskId: null,
    blocked: false,
    blockedReason: '',
    priority: null,
    description: '',
    startDate: null,
    dueDate: null,
    recurrence: null,
    reminderEnabled: false,
    timeSpentMinutes: null,
    external: null,
    jira: null,
    subtasks: const [],
    tags: const [],
    assignee: null,
    estimatedMinutes: null,
    storyPoints: null,
    customProperties: const {},
    recurringRule: null,
    blockedByTaskIds: const [],
    aiGenerated: false,
    createdFromBlockId: null,
    aiContextPageId: null,
    confidenceScore: null,
    suggestedDueDate: null,
  );

  FolioTaskData copyWith({
    String? title,
    String? status,
    Object? columnId = _sentinel,
    Object? parentTaskId = _sentinel,
    bool? blocked,
    Object? blockedReason = _sentinel,
    Object? priority = _sentinel,
    Object? description = _sentinel,
    Object? startDate = _sentinel,
    Object? dueDate = _sentinel,
    Object? recurrence = _sentinel,
    bool? reminderEnabled,
    Object? timeSpentMinutes = _sentinel,
    Object? external = _sentinel,
    Object? jira = _sentinel,
    Object? subtasks = _sentinel,
    Object? tags = _sentinel,
    Object? assignee = _sentinel,
    Object? estimatedMinutes = _sentinel,
    Object? storyPoints = _sentinel,
    Object? customProperties = _sentinel,
    Object? recurringRule = _sentinel,
    Object? blockedByTaskIds = _sentinel,
    bool? aiGenerated,
    Object? createdFromBlockId = _sentinel,
    Object? aiContextPageId = _sentinel,
    Object? confidenceScore = _sentinel,
    Object? suggestedDueDate = _sentinel,
  }) {
    return FolioTaskData(
      title: title ?? this.title,
      status: status ?? this.status,
      columnId: columnId == _sentinel ? this.columnId : columnId as String?,
      parentTaskId: parentTaskId == _sentinel
          ? this.parentTaskId
          : parentTaskId as String?,
      blocked: blocked ?? this.blocked,
      blockedReason: blockedReason == _sentinel
          ? this.blockedReason
          : (blockedReason as String),
      priority: priority == _sentinel ? this.priority : priority as String?,
      description: description == _sentinel
          ? this.description
          : (description as String),
      startDate: startDate == _sentinel ? this.startDate : startDate as String?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as String?,
      recurrence: recurrence == _sentinel
          ? this.recurrence
          : recurrence as String?,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      timeSpentMinutes: timeSpentMinutes == _sentinel
          ? this.timeSpentMinutes
          : timeSpentMinutes as int?,
      external: external == _sentinel
          ? this.external
          : external as FolioExternalTaskLink?,
      jira: jira == _sentinel ? this.jira : jira as FolioJiraIssueSnapshot?,
      subtasks: subtasks == _sentinel
          ? this.subtasks
          : (subtasks as List<FolioTaskSubtask>),
      tags: tags == _sentinel
          ? this.tags
          : _normalizeTags(
              tags is List<String>
                  ? tags
                  : (tags as List).map((e) => '$e').toList(growable: false),
            ),
      assignee: assignee == _sentinel
          ? this.assignee
          : assignee as String?,
      estimatedMinutes: estimatedMinutes == _sentinel
          ? this.estimatedMinutes
          : estimatedMinutes as int?,
      storyPoints: storyPoints == _sentinel
          ? this.storyPoints
          : (storyPoints as num?)?.toDouble(),
      customProperties: customProperties == _sentinel
          ? this.customProperties
          : _normalizeCustomProperties(
              customProperties as Map<String, Object?>?,
            ),
      recurringRule: recurringRule == _sentinel
          ? this.recurringRule
          : recurringRule as String?,
      blockedByTaskIds: blockedByTaskIds == _sentinel
          ? this.blockedByTaskIds
          : _normalizeIdList(
              switch (blockedByTaskIds) {
                final List l => List<String>.from(l.map((e) => '$e')),
                _ => null,
              },
            ),
      aiGenerated: aiGenerated ?? this.aiGenerated,
      createdFromBlockId: createdFromBlockId == _sentinel
          ? this.createdFromBlockId
          : createdFromBlockId as String?,
      aiContextPageId: aiContextPageId == _sentinel
          ? this.aiContextPageId
          : aiContextPageId as String?,
      confidenceScore: confidenceScore == _sentinel
          ? this.confidenceScore
          : confidenceScore as double?,
      suggestedDueDate: suggestedDueDate == _sentinel
          ? this.suggestedDueDate
          : suggestedDueDate as String?,
    );
  }

  static const Object _sentinel = Object();

  /// Columna efectiva para la UI Kanban.
  String effectiveColumnId({Set<String>? allowedColumnIds}) {
    final cid = (columnId ?? '').trim();
    if (cid.isNotEmpty &&
        (allowedColumnIds == null || allowedColumnIds.contains(cid))) {
      return cid;
    }
    if (status == 'in_progress') return 'in_progress';
    if (status == 'done') return 'done';
    return 'todo';
  }

  String encode() => jsonEncode({
    'v': 4,
    'title': title,
    'status': status,
    if ((columnId ?? '').trim().isNotEmpty) 'columnId': columnId,
    if ((parentTaskId ?? '').trim().isNotEmpty) 'parentTaskId': parentTaskId,
    if (blocked) 'blocked': true,
    if (blockedReason.trim().isNotEmpty) 'blockedReason': blockedReason,
    if (priority != null) 'priority': priority,
    if (description.trim().isNotEmpty) 'description': description,
    if (startDate != null) 'startDate': startDate,
    if (dueDate != null) 'dueDate': dueDate,
    if (recurrence != null) 'recurrence': recurrence,
    if (reminderEnabled) 'reminderEnabled': true,
    if (timeSpentMinutes != null) 'timeSpentMinutes': timeSpentMinutes,
    if (external != null) 'external': external!.toJson(),
    if (jira != null) 'jira': jira!.toJson(),
    if (subtasks.isNotEmpty)
      'subtasks': subtasks.map((s) => s.toJson()).toList(growable: false),
    if (tags.isNotEmpty) 'tags': tags.toList(growable: false),
    if ((assignee ?? '').trim().isNotEmpty) 'assignee': assignee!.trim(),
    if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
    if (storyPoints != null) 'storyPoints': storyPoints,
    if (customProperties.isNotEmpty) 'customProperties': Map<String, Object?>.from(customProperties),
    if ((recurringRule ?? '').trim().isNotEmpty) 'recurringRule': recurringRule!.trim(),
    if (blockedByTaskIds.isNotEmpty)
      'blockedByTaskIds': blockedByTaskIds.toList(growable: false),
    if (aiGenerated) 'aiGenerated': true,
    if ((createdFromBlockId ?? '').trim().isNotEmpty)
      'createdFromBlockId': createdFromBlockId!.trim(),
    if ((aiContextPageId ?? '').trim().isNotEmpty)
      'aiContextPageId': aiContextPageId!.trim(),
    if (confidenceScore != null) 'confidenceScore': confidenceScore,
    if ((suggestedDueDate ?? '').trim().isNotEmpty)
      'suggestedDueDate': suggestedDueDate!.trim(),
  });

  static FolioTaskData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioTaskData.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final rawStatus = m['status'] as String? ?? 'todo';
      final rawPriority = m['priority'] as String?;
      final rawColumnId = (m['columnId'] as String?)?.trim();
      final rawParent = (m['parentTaskId'] as String?)?.trim();
      final rawBlocked = m['blocked'] == true;
      final rawBlockedReason = (m['blockedReason'] as String?) ?? '';
      final rawDescription = (m['description'] as String?) ?? '';
      final rawStartDate = (m['startDate'] as String?)?.trim();
      final rawRecurrence = (m['recurrence'] as String?)?.trim();
      final rawReminderEnabled = m['reminderEnabled'] == true;
      final rawTimeSpent = m['timeSpentMinutes'];
      final rawSubtasks = m['subtasks'];
      final rawExternal = m['external'];
      final rawJira = m['jira'];
      final subtasks = <FolioTaskSubtask>[];
      if (rawSubtasks is List) {
        for (final s in rawSubtasks) {
          if (s is Map) {
            final parsed = FolioTaskSubtask.tryParse(
              Map<String, dynamic>.from(s),
            );
            if (parsed != null) subtasks.add(parsed);
          }
        }
      }
      FolioExternalTaskLink? external;
      if (rawExternal is Map) {
        external = FolioExternalTaskLink.tryParse(
          Map<String, dynamic>.from(rawExternal),
        );
      }
      FolioJiraIssueSnapshot? jira;
      if (rawJira is Map) {
        jira = FolioJiraIssueSnapshot.tryParse(
          Map<String, dynamic>.from(rawJira),
        );
      }
      final rawTags = m['tags'];
      final tagList = <String>[];
      if (rawTags is List) {
        for (final e in rawTags) {
          final s = '$e'.trim();
          if (s.isNotEmpty) tagList.add(s);
        }
      }
      final assigneeRaw = (m['assignee'] as String?)?.trim();
      final est = m['estimatedMinutes'];
      final sp = m['storyPoints'];
      final rawCp = m['customProperties'];
      Map<String, Object?>? cp;
      if (rawCp is Map) {
        cp = Map<String, Object?>.from(
          rawCp.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      final recurringRuleRaw = (m['recurringRule'] as String?)?.trim();
      final rawBlockedBy = m['blockedByTaskIds'];
      final blockedBy = <String>[];
      if (rawBlockedBy is List) {
        for (final e in rawBlockedBy) {
          final s = '$e'.trim();
          if (s.isNotEmpty) blockedBy.add(s);
        }
      }
      final aiGen = m['aiGenerated'] == true;
      final fromBlock = (m['createdFromBlockId'] as String?)?.trim();
      final aiCtx = (m['aiContextPageId'] as String?)?.trim();
      final conf = m['confidenceScore'];
      double? confScore;
      if (conf is num) {
        confScore = conf.toDouble();
        if (confScore < 0) confScore = 0;
        if (confScore > 1) confScore = 1;
      }
      final suggestedDue = (m['suggestedDueDate'] as String?)?.trim();

      return FolioTaskData(
        title: (m['title'] as String?) ?? '',
        status: _validStatuses.contains(rawStatus) ? rawStatus : 'todo',
        priority: (_validPriorities.contains(rawPriority)) ? rawPriority : null,
        columnId: (rawColumnId?.isEmpty ?? true) ? null : rawColumnId,
        parentTaskId: (rawParent?.isEmpty ?? true) ? null : rawParent,
        blocked: rawBlocked,
        blockedReason: rawBlockedReason,
        description: rawDescription,
        startDate: (rawStartDate?.isEmpty ?? true) ? null : rawStartDate,
        dueDate: (m['dueDate'] as String?),
        recurrence: (_validRecurrences.contains(rawRecurrence))
            ? rawRecurrence
            : null,
        reminderEnabled: rawReminderEnabled,
        timeSpentMinutes: rawTimeSpent is num ? rawTimeSpent.toInt() : null,
        external: external,
        jira: jira,
        subtasks: subtasks,
        tags: tagList,
        assignee: (assigneeRaw?.isEmpty ?? true) ? null : assigneeRaw,
        estimatedMinutes: est is num ? est.toInt() : null,
        storyPoints: sp is num ? sp.toDouble() : null,
        customProperties: cp,
        recurringRule: (recurringRuleRaw?.isEmpty ?? true)
            ? null
            : recurringRuleRaw,
        blockedByTaskIds: blockedBy,
        aiGenerated: aiGen,
        createdFromBlockId: (fromBlock?.isEmpty ?? true) ? null : fromBlock,
        aiContextPageId: (aiCtx?.isEmpty ?? true) ? null : aiCtx,
        confidenceScore: confScore,
        suggestedDueDate: (suggestedDue?.isEmpty ?? true) ? null : suggestedDue,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Referencia estable a una tarea remota (issue) en un proveedor externo.
///
/// Hoy se usa para Jira, pero está pensado para extenderse a otros.
class FolioExternalTaskLink {
  const FolioExternalTaskLink({
    required this.provider,
    required this.issueId,
    this.issueKey,
    this.deployment,
    this.baseUrl,
    this.cloudId,
    this.lastSyncedAtMs,
    this.remoteUpdatedAtMs,
    this.etag,
    this.remoteVersion,
    this.syncState,
  });

  /// Identificador del proveedor, p. ej. `jira`.
  final String provider;

  /// Identificador estable del issue en el proveedor.
  final String issueId;

  /// Identificador humano opcional, p. ej. `ABC-123`.
  final String? issueKey;

  /// `cloud` | `server` (opcional).
  final String? deployment;

  /// Para Server/DC: `https://jira.ejemplo.com` (opcional).
  final String? baseUrl;

  /// Para Cloud: `cloudId` del sitio Atlassian (opcional).
  final String? cloudId;

  /// Epoch ms local de la última sincronización.
  final int? lastSyncedAtMs;

  /// Epoch ms (según proveedor) de la última modificación remota observada.
  final int? remoteUpdatedAtMs;

  /// ETag / version string del proveedor para detección de conflictos.
  final String? etag;

  /// Version/contador remoto (si está disponible) para conflictos.
  final String? remoteVersion;

  /// `ok` | `needsPull` | `needsPush` | `conflict` (opcional).
  final String? syncState;

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider,
    'issueId': issueId,
    if ((issueKey ?? '').trim().isNotEmpty) 'issueKey': issueKey,
    if ((deployment ?? '').trim().isNotEmpty) 'deployment': deployment,
    if ((baseUrl ?? '').trim().isNotEmpty) 'baseUrl': baseUrl,
    if ((cloudId ?? '').trim().isNotEmpty) 'cloudId': cloudId,
    if (lastSyncedAtMs != null) 'lastSyncedAtMs': lastSyncedAtMs,
    if (remoteUpdatedAtMs != null) 'remoteUpdatedAtMs': remoteUpdatedAtMs,
    if ((etag ?? '').trim().isNotEmpty) 'etag': etag,
    if ((remoteVersion ?? '').trim().isNotEmpty) 'remoteVersion': remoteVersion,
    if ((syncState ?? '').trim().isNotEmpty) 'syncState': syncState,
  };

  FolioExternalTaskLink copyWith({
    String? provider,
    String? issueId,
    Object? issueKey = FolioTaskData._sentinel,
    Object? deployment = FolioTaskData._sentinel,
    Object? baseUrl = FolioTaskData._sentinel,
    Object? cloudId = FolioTaskData._sentinel,
    Object? lastSyncedAtMs = FolioTaskData._sentinel,
    Object? remoteUpdatedAtMs = FolioTaskData._sentinel,
    Object? etag = FolioTaskData._sentinel,
    Object? remoteVersion = FolioTaskData._sentinel,
    Object? syncState = FolioTaskData._sentinel,
  }) {
    return FolioExternalTaskLink(
      provider: provider ?? this.provider,
      issueId: issueId ?? this.issueId,
      issueKey: issueKey == FolioTaskData._sentinel
          ? this.issueKey
          : issueKey as String?,
      deployment: deployment == FolioTaskData._sentinel
          ? this.deployment
          : deployment as String?,
      baseUrl: baseUrl == FolioTaskData._sentinel
          ? this.baseUrl
          : baseUrl as String?,
      cloudId: cloudId == FolioTaskData._sentinel
          ? this.cloudId
          : cloudId as String?,
      lastSyncedAtMs: lastSyncedAtMs == FolioTaskData._sentinel
          ? this.lastSyncedAtMs
          : lastSyncedAtMs as int?,
      remoteUpdatedAtMs: remoteUpdatedAtMs == FolioTaskData._sentinel
          ? this.remoteUpdatedAtMs
          : remoteUpdatedAtMs as int?,
      etag: etag == FolioTaskData._sentinel ? this.etag : etag as String?,
      remoteVersion: remoteVersion == FolioTaskData._sentinel
          ? this.remoteVersion
          : remoteVersion as String?,
      syncState: syncState == FolioTaskData._sentinel
          ? this.syncState
          : syncState as String?,
    );
  }

  static FolioExternalTaskLink? tryParse(Map<String, dynamic> map) {
    final provider = (map['provider'] as String? ?? '').trim();
    final issueId = (map['issueId'] as String? ?? '').trim();
    if (provider.isEmpty || issueId.isEmpty) return null;
    final issueKey = (map['issueKey'] as String?)?.trim();
    final deployment = (map['deployment'] as String?)?.trim();
    final baseUrl = (map['baseUrl'] as String?)?.trim();
    final cloudId = (map['cloudId'] as String?)?.trim();
    final lastSyncedAtMs = map['lastSyncedAtMs'] is num
        ? (map['lastSyncedAtMs'] as num).toInt()
        : null;
    final remoteUpdatedAtMs = map['remoteUpdatedAtMs'] is num
        ? (map['remoteUpdatedAtMs'] as num).toInt()
        : null;
    final etag = (map['etag'] as String?)?.trim();
    final remoteVersion = (map['remoteVersion'] as String?)?.trim();
    final syncState = (map['syncState'] as String?)?.trim();
    return FolioExternalTaskLink(
      provider: provider,
      issueId: issueId,
      issueKey: (issueKey?.isEmpty ?? true) ? null : issueKey,
      deployment: (deployment?.isEmpty ?? true) ? null : deployment,
      baseUrl: (baseUrl?.isEmpty ?? true) ? null : baseUrl,
      cloudId: (cloudId?.isEmpty ?? true) ? null : cloudId,
      lastSyncedAtMs: lastSyncedAtMs,
      remoteUpdatedAtMs: remoteUpdatedAtMs,
      etag: (etag?.isEmpty ?? true) ? null : etag,
      remoteVersion: (remoteVersion?.isEmpty ?? true) ? null : remoteVersion,
      syncState: (syncState?.isEmpty ?? true) ? null : syncState,
    );
  }
}

class FolioJiraIssueSnapshot {
  const FolioJiraIssueSnapshot({
    this.projectKey,
    this.issueType,
    this.statusId,
    this.statusName,
    this.assigneeAccountId,
    this.assigneeDisplayName,
    this.reporterAccountId,
    this.reporterDisplayName,
    this.labels = const [],
    this.components = const [],
    this.sprintId,
    this.sprintName,
    this.boardId,
    this.customFields = const {},
    this.originalEstimateMinutes,
    this.remainingEstimateMinutes,
    this.timeSpentMinutes,
    this.worklogCount,
    this.commentCount,
    this.attachmentCount,
  });

  final String? projectKey;
  final String? issueType;
  final String? statusId;
  final String? statusName;

  final String? assigneeAccountId;
  final String? assigneeDisplayName;
  final String? reporterAccountId;
  final String? reporterDisplayName;

  final List<String> labels;
  final List<String> components;

  final String? sprintId;
  final String? sprintName;
  final String? boardId;

  /// fieldId -> value (JSON-friendly). Solo incluye el set configurado.
  final Map<String, Object?> customFields;

  final int? originalEstimateMinutes;
  final int? remainingEstimateMinutes;
  final int? timeSpentMinutes;
  final int? worklogCount;
  final int? commentCount;
  final int? attachmentCount;

  Map<String, Object?> toJson() => <String, Object?>{
    if ((projectKey ?? '').trim().isNotEmpty) 'projectKey': projectKey,
    if ((issueType ?? '').trim().isNotEmpty) 'issueType': issueType,
    if ((statusId ?? '').trim().isNotEmpty) 'statusId': statusId,
    if ((statusName ?? '').trim().isNotEmpty) 'statusName': statusName,
    if ((assigneeAccountId ?? '').trim().isNotEmpty)
      'assigneeAccountId': assigneeAccountId,
    if ((assigneeDisplayName ?? '').trim().isNotEmpty)
      'assigneeDisplayName': assigneeDisplayName,
    if ((reporterAccountId ?? '').trim().isNotEmpty)
      'reporterAccountId': reporterAccountId,
    if ((reporterDisplayName ?? '').trim().isNotEmpty)
      'reporterDisplayName': reporterDisplayName,
    if (labels.isNotEmpty) 'labels': labels,
    if (components.isNotEmpty) 'components': components,
    if ((sprintId ?? '').trim().isNotEmpty) 'sprintId': sprintId,
    if ((sprintName ?? '').trim().isNotEmpty) 'sprintName': sprintName,
    if ((boardId ?? '').trim().isNotEmpty) 'boardId': boardId,
    if (customFields.isNotEmpty) 'customFields': customFields,
    if (originalEstimateMinutes != null)
      'originalEstimateMinutes': originalEstimateMinutes,
    if (remainingEstimateMinutes != null)
      'remainingEstimateMinutes': remainingEstimateMinutes,
    if (timeSpentMinutes != null) 'timeSpentMinutes': timeSpentMinutes,
    if (worklogCount != null) 'worklogCount': worklogCount,
    if (commentCount != null) 'commentCount': commentCount,
    if (attachmentCount != null) 'attachmentCount': attachmentCount,
  };

  static FolioJiraIssueSnapshot? tryParse(Map<String, dynamic> map) {
    final projectKey = (map['projectKey'] as String?)?.trim();
    final issueType = (map['issueType'] as String?)?.trim();
    final statusId = (map['statusId'] as String?)?.trim();
    final statusName = (map['statusName'] as String?)?.trim();
    final assigneeAccountId = (map['assigneeAccountId'] as String?)?.trim();
    final assigneeDisplayName = (map['assigneeDisplayName'] as String?)?.trim();
    final reporterAccountId = (map['reporterAccountId'] as String?)?.trim();
    final reporterDisplayName = (map['reporterDisplayName'] as String?)?.trim();
    final labels = <String>[];
    final rawLabels = map['labels'];
    if (rawLabels is List) {
      labels.addAll(
        rawLabels.map((e) => '$e').where((e) => e.trim().isNotEmpty),
      );
    }
    final components = <String>[];
    final rawComponents = map['components'];
    if (rawComponents is List) {
      components.addAll(
        rawComponents.map((e) => '$e').where((e) => e.trim().isNotEmpty),
      );
    }
    final sprintId = (map['sprintId'] as String?)?.trim();
    final sprintName = (map['sprintName'] as String?)?.trim();
    final boardId = (map['boardId'] as String?)?.trim();
    final customFieldsRaw = map['customFields'];
    final customFields = customFieldsRaw is Map
        ? Map<String, Object?>.from(customFieldsRaw)
        : const <String, Object?>{};
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return FolioJiraIssueSnapshot(
      projectKey: (projectKey?.isEmpty ?? true) ? null : projectKey,
      issueType: (issueType?.isEmpty ?? true) ? null : issueType,
      statusId: (statusId?.isEmpty ?? true) ? null : statusId,
      statusName: (statusName?.isEmpty ?? true) ? null : statusName,
      assigneeAccountId: (assigneeAccountId?.isEmpty ?? true)
          ? null
          : assigneeAccountId,
      assigneeDisplayName: (assigneeDisplayName?.isEmpty ?? true)
          ? null
          : assigneeDisplayName,
      reporterAccountId: (reporterAccountId?.isEmpty ?? true)
          ? null
          : reporterAccountId,
      reporterDisplayName: (reporterDisplayName?.isEmpty ?? true)
          ? null
          : reporterDisplayName,
      labels: List.unmodifiable(labels),
      components: List.unmodifiable(components),
      sprintId: (sprintId?.isEmpty ?? true) ? null : sprintId,
      sprintName: (sprintName?.isEmpty ?? true) ? null : sprintName,
      boardId: (boardId?.isEmpty ?? true) ? null : boardId,
      customFields: Map.unmodifiable(customFields),
      originalEstimateMinutes: asInt(map['originalEstimateMinutes']),
      remainingEstimateMinutes: asInt(map['remainingEstimateMinutes']),
      timeSpentMinutes: asInt(map['timeSpentMinutes']),
      worklogCount: asInt(map['worklogCount']),
      commentCount: asInt(map['commentCount']),
      attachmentCount: asInt(map['attachmentCount']),
    );
  }
}

class FolioTaskSubtask {
  const FolioTaskSubtask({
    required this.id,
    required this.title,
    required this.status,
    this.columnId,
    this.priority,
    this.description = '',
    this.startDate,
    this.dueDate,
    this.timeSpentMinutes,
  });

  final String id;
  final String title;
  final String status;
  final String? columnId;
  final String? priority;
  final String description;
  final String? startDate;
  final String? dueDate;
  final int? timeSpentMinutes;

  FolioTaskSubtask copyWith({
    String? id,
    String? title,
    String? status,
    Object? columnId = FolioTaskData._sentinel,
    Object? priority = FolioTaskData._sentinel,
    Object? description = FolioTaskData._sentinel,
    Object? startDate = FolioTaskData._sentinel,
    Object? dueDate = FolioTaskData._sentinel,
    Object? timeSpentMinutes = FolioTaskData._sentinel,
  }) {
    return FolioTaskSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      columnId: columnId == FolioTaskData._sentinel
          ? this.columnId
          : columnId as String?,
      priority: priority == FolioTaskData._sentinel
          ? this.priority
          : priority as String?,
      description: description == FolioTaskData._sentinel
          ? this.description
          : (description as String),
      startDate: startDate == FolioTaskData._sentinel
          ? this.startDate
          : startDate as String?,
      dueDate: dueDate == FolioTaskData._sentinel
          ? this.dueDate
          : dueDate as String?,
      timeSpentMinutes: timeSpentMinutes == FolioTaskData._sentinel
          ? this.timeSpentMinutes
          : timeSpentMinutes as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    if ((columnId ?? '').trim().isNotEmpty) 'columnId': columnId,
    if (priority != null) 'priority': priority,
    if (description.trim().isNotEmpty) 'description': description,
    if (startDate != null) 'startDate': startDate,
    if (dueDate != null) 'dueDate': dueDate,
    if (timeSpentMinutes != null) 'timeSpentMinutes': timeSpentMinutes,
  };

  static FolioTaskSubtask? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final title = (map['title'] as String? ?? '').trim();
    if (id.isEmpty && title.isEmpty) return null;
    final rawStatus =
        (map['status'] as String?) ??
        ((map['done'] == true) ? 'done' : 'todo'); // compat v1
    final status = FolioTaskData._validStatuses.contains(rawStatus)
        ? rawStatus
        : 'todo';
    final rawPriority = map['priority'] as String?;
    final priority = FolioTaskData._validPriorities.contains(rawPriority)
        ? rawPriority
        : null;
    return FolioTaskSubtask(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title,
      status: status,
      columnId: (map['columnId'] as String?)?.trim().isNotEmpty == true
          ? (map['columnId'] as String).trim()
          : null,
      priority: priority,
      description: (map['description'] as String?) ?? '',
      startDate: (map['startDate'] as String?)?.trim(),
      dueDate: (map['dueDate'] as String?)?.trim(),
      timeSpentMinutes: map['timeSpentMinutes'] is num
          ? (map['timeSpentMinutes'] as num).toInt()
          : null,
    );
  }
}
