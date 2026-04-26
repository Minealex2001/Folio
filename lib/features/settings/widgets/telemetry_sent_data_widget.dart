import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/folio_telemetry.dart';

/// Widget que muestra ejemplos de eventos de telemetría
class TelemetrySentDataWidget extends StatefulWidget {
  const TelemetrySentDataWidget({super.key});

  @override
  State<TelemetrySentDataWidget> createState() =>
      _TelemetrySentDataWidgetState();
}

class _TelemetrySentDataWidgetState extends State<TelemetrySentDataWidget> {
  bool _showDetails = false;
  Map<String, dynamic>? _lastEvent;

  @override
  void initState() {
    super.initState();
    _loadLastEvent();
  }

  Future<void> _loadLastEvent() async {
    final event = await FolioTelemetry.getLastEventSnapshot();
    if (mounted) {
      setState(() {
        _lastEvent = event;
      });
    }
  }

  String _formatDetails(Map<String, dynamic>? m) {
    if (m == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(m);
    } catch (_) {
      return m.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                l10n.telemetrySentDataCategoriesTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _buildExampleItem(
                context,
                '📖',
                l10n.telemetrySentDataFeatureUsageTitle,
                l10n.telemetrySentDataFeatureUsageBody,
              ),
              _buildExampleItem(
                context,
                '✏️',
                l10n.telemetrySentDataContentActionsTitle,
                l10n.telemetrySentDataContentActionsBody,
              ),
              _buildExampleItem(
                context,
                '🔍',
                l10n.telemetrySentDataSearchesTitle,
                l10n.telemetrySentDataSearchesBody,
              ),
              _buildExampleItem(
                context,
                '🔄',
                l10n.telemetrySentDataSyncTitle,
                l10n.telemetrySentDataSyncBody,
              ),
              _buildExampleItem(
                context,
                '⚡',
                l10n.telemetrySentDataPerformanceTitle,
                l10n.telemetrySentDataPerformanceBody,
              ),
              _buildExampleItem(
                context,
                '❌',
                l10n.telemetrySentDataErrorsTitle,
                l10n.telemetrySentDataErrorsBody,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.telemetrySentDataPrivacyNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.telemetrySentDataChannelsNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showDetails
                          ? l10n.telemetrySentDataHideTechnicalDetails
                          : l10n.telemetrySentDataViewTechnicalDetails,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _buildEventDetails(context, l10n),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildExampleItem(
    BuildContext context,
    String emoji,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetails(BuildContext context, AppLocalizations l10n) {
    if (_lastEvent == null) {
      return Text(
        l10n.telemetrySentDataNoEventsYet,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        _formatDetails(_lastEvent),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
      ),
    );
  }
}
