import 'package:cloud_functions/cloud_functions.dart';

import 'folio_cloud_callable.dart';

const Map<String, int> kFolioCloudInkCostFallback = <String, int>{
  'rewrite_block': 1,
  'summarize_selection': 1,
  'extract_tasks': 2,
  'summarize_page': 3,
  'generate_insert': 5,
  'generate_page': 8,
  'chat_turn': 3,
  'agent_main': 10,
  'agent_followup': 4,
  'edit_page_panel': 4,
  'default': 3,
};

class FolioCloudAiPricingSnapshot {
  const FolioCloudAiPricingSnapshot({
    required this.costByOperation,
    required this.inkMaxPerRequest,
    required this.promptLengthSurchargeThreshold,
    required this.extraForLongPrompt,
    required this.tokensPerSurchargeUnit,
    required this.maxTokenSurcharge,
    required this.fromServer,
  });

  final Map<String, int> costByOperation;
  final int inkMaxPerRequest;
  final int promptLengthSurchargeThreshold;
  final int extraForLongPrompt;
  final int tokensPerSurchargeUnit;
  final int maxTokenSurcharge;
  final bool fromServer;

  int costForOperation(String operationKind) {
    final fallbackDefault = kFolioCloudInkCostFallback['default'] ?? 3;
    return costByOperation[operationKind] ??
        costByOperation['default'] ??
        fallbackDefault;
  }

  static FolioCloudAiPricingSnapshot fallback() {
    return const FolioCloudAiPricingSnapshot(
      costByOperation: kFolioCloudInkCostFallback,
      inkMaxPerRequest: 16,
      promptLengthSurchargeThreshold: 32000,
      extraForLongPrompt: 2,
      tokensPerSurchargeUnit: 6000,
      maxTokenSurcharge: 10,
      fromServer: false,
    );
  }
}

class FolioCloudAiPricingService {
  static FolioCloudAiPricingSnapshot? _cache;
  static DateTime? _cacheAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  static Future<FolioCloudAiPricingSnapshot> getPricing({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null && _cacheAt != null) {
      final age = DateTime.now().difference(_cacheAt!);
      if (age <= _cacheTtl) return _cache!;
    }

    try {
      final raw = await callFolioHttpsCallable(
        'folioCloudAiPricing',
        const <String, dynamic>{},
      );
      final parsed = _parseSnapshot(raw);
      _cache = parsed;
      _cacheAt = DateTime.now();
      return parsed;
    } on FirebaseFunctionsException {
      return _cache ?? FolioCloudAiPricingSnapshot.fallback();
    } catch (_) {
      return _cache ?? FolioCloudAiPricingSnapshot.fallback();
    }
  }

  static FolioCloudAiPricingSnapshot _parseSnapshot(dynamic raw) {
    if (raw is! Map) return FolioCloudAiPricingSnapshot.fallback();
    final map = Map<String, dynamic>.from(raw);
    final costMapRaw = map['costByOperation'];
    final parsedCosts = <String, int>{};
    if (costMapRaw is Map) {
      for (final e in costMapRaw.entries) {
        final key = '${e.key}'.trim();
        if (key.isEmpty) continue;
        final value = _parseInt(e.value);
        if (value == null || value < 0) continue;
        parsedCosts[key] = value;
      }
    }

    if (parsedCosts.isEmpty) {
      parsedCosts.addAll(kFolioCloudInkCostFallback);
    } else if (!parsedCosts.containsKey('default')) {
      parsedCosts['default'] = kFolioCloudInkCostFallback['default'] ?? 3;
    }

    return FolioCloudAiPricingSnapshot(
      costByOperation: Map<String, int>.unmodifiable(parsedCosts),
      inkMaxPerRequest: _parseInt(map['inkMaxPerRequest']) ?? 16,
      promptLengthSurchargeThreshold:
          _parseInt(map['promptLengthSurchargeThreshold']) ?? 32000,
      extraForLongPrompt: _parseInt(map['extraForLongPrompt']) ?? 2,
      tokensPerSurchargeUnit: _parseInt(map['tokensPerSurchargeUnit']) ?? 6000,
      maxTokenSurcharge: _parseInt(map['maxTokenSurcharge']) ?? 10,
      fromServer: true,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v.trim());
      return n;
    }
    return null;
  }
}
