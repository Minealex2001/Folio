import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_firestore_sync.dart';

/// Extrae `userId` de rutas `analytics_events/{userId}/...`.
String? _userIdFromAnalyticsPath(String path) {
  const prefix = 'analytics_events/';
  if (!path.startsWith(prefix)) return null;
  final rest = path.substring(prefix.length);
  final i = rest.indexOf('/');
  if (i <= 0) return null;
  return rest.substring(0, i);
}

String _shortUid(String uid) {
  if (uid.length <= 10) return uid;
  return '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';
}

DateTime? _readFirestoreTimestamp(dynamic v) {
  if (v is Timestamp) return v.toDate();
  return null;
}

String _eventSummaryLine(Map<String, dynamic> d) {
  final type = d['type']?.toString() ?? '';
  switch (type) {
    case 'featureOpened':
      return (d['featureName'] as String?)?.trim() ?? '';
    case 'contentAction':
      final a = d['action']?.toString() ?? '';
      final c = d['contentType']?.toString() ?? '';
      return '$a · $c'.trim();
    case 'navigation':
      return '${d['fromScreen'] ?? ''} → ${d['toScreen'] ?? ''}';
    case 'search':
      return '${d['queryType'] ?? ''} (${d['resultCount'] ?? ''})';
    case 'sync':
      return '${d['syncType'] ?? ''} · ok=${d['success'] ?? ''}';
    case 'performance':
      return '${d['operationName'] ?? ''} · ${d['durationMs'] ?? ''}ms';
    case 'error':
      return (d['errorMessage'] as String?)?.trim().isNotEmpty == true
          ? d['errorMessage'].toString()
          : (d['errorType']?.toString() ?? '');
    case 'usageStats':
      final m = d['stats'];
      if (m is Map) {
        return m.entries
            .take(4)
            .map((e) => '${e.key}=${e.value}')
            .join(', ');
      }
      return '';
    default:
      return '';
  }
}

/// Pantalla del Dashboard de Telemetría (solo para staff).
///
/// Usa lecturas puntuales [.get()] sin listeners en colecciones amplias, por
/// compatibilidad con el SDK de Firestore en Windows.
class TelemetryDashboardPage extends StatefulWidget {
  const TelemetryDashboardPage({super.key, required this.folioCloudSnapshot});

  final FolioCloudSnapshot folioCloudSnapshot;

  @override
  State<TelemetryDashboardPage> createState() => _TelemetryDashboardPageState();
}

class _PerUserStatRow {
  const _PerUserStatRow({
    required this.userId,
    required this.totalEvents,
    required this.errorCount,
  });

  final String userId;
  final int totalEvents;
  final int errorCount;
}

class _RecentEventRow {
  _RecentEventRow({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  DateTime? get timestamp => _readFirestoreTimestamp(data['timestamp']);

  String get type => data['type']?.toString() ?? '';

  String summary() => _eventSummaryLine(data);
}

class _TelemetryDashboardPageState extends State<TelemetryDashboardPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isFlushing = false;

  int _refreshKey = 0;

  String get _dateStr =>
      DateFormat('yyyy-MM-dd', 'en_US').format(_selectedDate);

  Future<_DashboardData> _loadData() async {
    final db = FirebaseFirestore.instance;
    const getOpts = GetOptions(source: Source.server);

    late final DocumentSnapshot<Map<String, dynamic>> globalDoc;
    try {
      globalDoc = await db
          .collection('telemetryGlobalStats')
          .doc(_dateStr)
          .get(getOpts)
          .catchError(
            (_) => db.collection('telemetryGlobalStats').doc(_dateStr).get(),
          );
    } catch (_) {
      globalDoc =
          await db.collection('telemetryGlobalStats').doc(_dateStr).get();
    }

    final perUser = <_PerUserStatRow>[];
    try {
      final snap = await db
          .collectionGroup('stats')
          .where('date', isEqualTo: _dateStr)
          .limit(200)
          .get();
      for (final d in snap.docs) {
        final uid = _userIdFromAnalyticsPath(d.reference.path);
        if (uid == null || uid.isEmpty) continue;
        final m = d.data();
        perUser.add(
          _PerUserStatRow(
            userId: uid,
            totalEvents: (m['totalEvents'] as num?)?.toInt() ?? 0,
            errorCount: (m['errorCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      perUser.sort((a, b) => b.totalEvents.compareTo(a.totalEvents));
    } catch (_) {
      // Índice COLLECTION_GROUP stats/date o permisos; la UI sigue sin esta sección.
    }

    final recent = <_RecentEventRow>[];
    try {
      final snap = await db
          .collectionGroup('events')
          .orderBy('timestamp', descending: true)
          .limit(80)
          .get();
      for (final d in snap.docs) {
        final uid = _userIdFromAnalyticsPath(d.reference.path) ?? '';
        recent.add(_RecentEventRow(userId: uid, data: d.data()));
      }
    } catch (_) {
      // Índice COLLECTION_GROUP events/timestamp o permisos.
    }

    return _DashboardData(
      globalStats: globalDoc.exists ? globalDoc.data() : null,
      perUserStats: perUser,
      recentEvents: recent,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  Future<void> _flushAndRefresh() async {
    if (!mounted) return;
    setState(() => _isFlushing = true);
    try {
      await FolioFirestoreSync.flush();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) {
        setState(() {
          _isFlushing = false;
          _refreshKey++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!widget.folioCloudSnapshot.folioStaff) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.telemetryDashboardTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(l10n.telemetryDashboardAccessDenied),
              const SizedBox(height: 8),
              Text(l10n.telemetryDashboardStaffOnlyBody),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.telemetryDashboardTitle),
        elevation: 0,
        actions: [
          if (_isFlushing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: l10n.telemetryDashboardFlushTooltip,
              onPressed: _flushAndRefresh,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.appStoreTooltipRefresh,
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<_DashboardData>(
              key: ValueKey('$_refreshKey-$_dateStr'),
              future: _loadData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.telemetryDashboardErrorLoading,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.telemetryDashboardErrorDetail(
                              snapshot.error.toString(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                return _buildContent(context, data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _eventsByTypeFromGlobalStats(
    Map<String, dynamic> stats,
  ) {
    Object? raw = stats['eventsByType'];
    if (raw is! Map || raw.isEmpty) {
      raw = stats['globalEventsByType'];
    }
    if (raw is! Map) return {};
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              _refreshKey++;
            }),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _selectedDate = picked;
                    _refreshKey++;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(_selectedDate),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = _selectedDate.add(const Duration(days: 1));
              if (!next.isAfter(DateTime.now())) {
                setState(() {
                  _selectedDate = next;
                  _refreshKey++;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, _DashboardData data) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final hasGlobal = data.globalStats != null;
    final hasPerUser = data.perUserStats.isNotEmpty;
    final hasRecent = data.recentEvents.isNotEmpty;

    if (!hasGlobal && !hasPerUser && !hasRecent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.telemetryDashboardNoDataForDate(
                  DateFormat.yMMMd(localeName).format(_selectedDate),
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.telemetryDashboardEmptyAll,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.telemetryDashboardNoDataHint,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _flushAndRefresh,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(l10n.telemetryDashboardFlushRefresh),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!hasGlobal)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.telemetryDashboardGlobalMissingHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!hasGlobal) const SizedBox(height: 12),
        if (hasGlobal) ...[
          _buildSectionHeader(
            context,
            l10n.telemetryDashboardSectionGlobalTitle,
            Icons.public_outlined,
            Colors.green,
            subtitle: l10n.telemetryDashboardSectionGlobalSubtitle,
          ),
          const SizedBox(height: 12),
          _buildGlobalSummaryCards(context, data.globalStats!),
          const SizedBox(height: 8),
          _buildEventBreakdown(
            context,
            data.globalStats!,
            totalKey: 'totalEvents',
          ),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader(
          context,
          l10n.telemetryDashboardPerUserDayTitle,
          Icons.people_outline,
          Colors.blue,
          subtitle: l10n.telemetryDashboardPerUserDaySubtitle(_dateStr),
        ),
        const SizedBox(height: 8),
        _buildPerUserSection(context, data.perUserStats),
        const SizedBox(height: 24),
        _buildSectionHeader(
          context,
          l10n.telemetryDashboardRecentEventsTitle,
          Icons.receipt_long_outlined,
          Colors.deepPurple,
          subtitle: l10n.telemetryDashboardRecentEventsSubtitle,
        ),
        const SizedBox(height: 8),
        _buildRecentEventsSection(context, data.recentEvents, localeName),
      ],
    );
  }

  Widget _buildPerUserSection(
    BuildContext context,
    List<_PerUserStatRow> rows,
  ) {
    final l10n = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Text(
        l10n.telemetryDashboardNoPerUserStats,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      );
    }
    return Column(
      children: rows.map((r) {
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text(
              _shortUid(r.userId),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            subtitle: Text(r.userId, style: const TextStyle(fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: l10n.telemetryDashboardColEvents,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('${r.totalEvents}'),
                  ),
                ),
                Tooltip(
                  message: l10n.telemetryDashboardColErrors,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${r.errorCount}',
                      style: TextStyle(
                        color: r.errorCount > 0 ? Colors.red : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentEventsSection(
    BuildContext context,
    List<_RecentEventRow> rows,
    String localeName,
  ) {
    final l10n = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Text(
        l10n.telemetryDashboardNoRecentEvents,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      );
    }
    final fmt = DateFormat.yMMMd(localeName).add_Hms();
    return Column(
      children: rows.map((r) {
        final ts = r.timestamp;
        final timeStr = ts != null ? fmt.format(ts.toLocal()) : '—';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text(
              '${_formatEventType(context, r.type)} · ${_shortUid(r.userId)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              '$timeStr · ${r.summary()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  'uid: ${r.userId}\n$timeStr\ntype: ${r.type}\n${r.summary()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalSummaryCards(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final l10n = AppLocalizations.of(context);
    final users = (stats['totalUsersWithEvents'] as num?)?.toInt() ?? 0;
    final totalEvents = (stats['totalEvents'] as num?)?.toInt() ?? 0;
    final errors = (stats['totalErrors'] as num?)?.toInt() ?? 0;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            l10n.telemetryDashboardMetricUsers,
            users.toString(),
            Icons.people_outline,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            l10n.telemetryDashboardMetricEvents,
            totalEvents.toString(),
            Icons.analytics_outlined,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            l10n.telemetryDashboardMetricErrors,
            errors.toString(),
            Icons.error_outline,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBreakdown(
    BuildContext context,
    Map<String, dynamic> stats, {
    required String totalKey,
  }) {
    final l10n = AppLocalizations.of(context);
    final eventsByType = _eventsByTypeFromGlobalStats(stats);
    if (eventsByType.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.telemetryDashboardNoEventBreakdown,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
        ),
      );
    }
    final total = (stats[totalKey] as num?)?.toInt() ?? 1;
    final sorted = eventsByType.entries.toList()
      ..sort((a, b) {
        final aCount = (a.value as num?)?.toInt() ?? 0;
        final bCount = (b.value as num?)?.toInt() ?? 0;
        return bCount.compareTo(aCount);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.telemetryDashboardByType,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        ...sorted.map((e) {
          final count = (e.value as num?)?.toInt() ?? 0;
          final fraction = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getTypeIcon(e.key),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_formatEventType(context, e.key)),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: fraction,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _getTypeIcon(String type) {
    switch (type) {
      case 'featureOpened':
        return const Icon(Icons.apps_outlined, color: Colors.blue, size: 20);
      case 'contentAction':
        return const Icon(Icons.edit_outlined, color: Colors.orange, size: 20);
      case 'navigation':
        return const Icon(
          Icons.directions_outlined,
          color: Colors.purple,
          size: 20,
        );
      case 'search':
        return const Icon(Icons.search_outlined, color: Colors.green, size: 20);
      case 'sync':
        return const Icon(Icons.sync_outlined, color: Colors.cyan, size: 20);
      case 'performance':
        return const Icon(Icons.speed_outlined, color: Colors.amber, size: 20);
      case 'error':
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
      case 'usageStats':
        return const Icon(
          Icons.trending_up_outlined,
          color: Colors.teal,
          size: 20,
        );
      default:
        return const Icon(Icons.circle_outlined, color: Colors.grey, size: 20);
    }
  }

  String _formatEventType(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);
    if (type.isEmpty) return l10n.telemetryDashboardEventTypeUnknown;
    return type
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _DashboardData {
  const _DashboardData({
    required this.globalStats,
    required this.perUserStats,
    required this.recentEvents,
  });

  final Map<String, dynamic>? globalStats;
  final List<_PerUserStatRow> perUserStats;
  final List<_RecentEventRow> recentEvents;
}
