import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'folio_cloud_callable.dart';

/// Importes de catálogo Stripe (`folioCloudCatalogPrices`) para la UI.
class FolioCloudCatalogPrice {
  const FolioCloudCatalogPrice({
    required this.unitAmount,
    required this.currency,
  });

  /// Importe en la unidad mínima de la divisa (céntimos para EUR/USD).
  final int unitAmount;
  final String currency;

  String format(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final code = currency.trim().toUpperCase();
    if (code.isEmpty) {
      return NumberFormat.decimalPattern(locale).format(unitAmount / 100);
    }
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: code,
    ).format(unitAmount / 100.0);
  }
}

class FolioCloudCatalogPricesSnapshot {
  const FolioCloudCatalogPricesSnapshot({
    required this.prices,
    required this.fromServer,
  });

  final Map<String, FolioCloudCatalogPrice> prices;
  final bool fromServer;

  FolioCloudCatalogPrice? operator [](String key) => prices[key];

  String? format(BuildContext context, String key) {
    final p = prices[key];
    if (p == null) return null;
    return p.format(context);
  }

  static FolioCloudCatalogPricesSnapshot empty() {
    return const FolioCloudCatalogPricesSnapshot(
      prices: <String, FolioCloudCatalogPrice>{},
      fromServer: false,
    );
  }
}

class FolioCloudCatalogPricesService {
  static FolioCloudCatalogPricesSnapshot? _cache;
  static DateTime? _cacheAt;
  static const Duration _cacheTtl = Duration(minutes: 10);

  static Future<FolioCloudCatalogPricesSnapshot> getPricing({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null && _cacheAt != null) {
      final age = DateTime.now().difference(_cacheAt!);
      if (age <= _cacheTtl) return _cache!;
    }

    try {
      final raw = await callFolioHttpsCallable(
        'folioCloudCatalogPrices',
        <String, dynamic>{'debug': kDebugMode},
      );
      final parsed = _parseSnapshot(raw);
      _cache = parsed;
      _cacheAt = DateTime.now();
      return parsed;
    } on FirebaseFunctionsException {
      return _cache ?? FolioCloudCatalogPricesSnapshot.empty();
    } catch (_) {
      return _cache ?? FolioCloudCatalogPricesSnapshot.empty();
    }
  }

  static FolioCloudCatalogPricesSnapshot _parseSnapshot(dynamic raw) {
    if (raw is! Map) return FolioCloudCatalogPricesSnapshot.empty();
    final map = Map<String, dynamic>.from(raw);
    final pricesRaw = map['prices'];
    final parsed = <String, FolioCloudCatalogPrice>{};
    if (pricesRaw is Map) {
      for (final e in pricesRaw.entries) {
        final key = '${e.key}'.trim();
        if (key.isEmpty || e.value is! Map) continue;
        final entry = Map<String, dynamic>.from(e.value as Map);
        final amount = _parseInt(entry['unitAmount']);
        final currency = '${entry['currency'] ?? ''}'.trim().toLowerCase();
        if (amount == null || amount < 0 || currency.isEmpty) continue;
        parsed[key] = FolioCloudCatalogPrice(
          unitAmount: amount,
          currency: currency,
        );
      }
    }
    return FolioCloudCatalogPricesSnapshot(
      prices: Map<String, FolioCloudCatalogPrice>.unmodifiable(parsed),
      fromServer: parsed.isNotEmpty,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
