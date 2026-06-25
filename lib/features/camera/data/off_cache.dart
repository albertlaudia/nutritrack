import 'package:dio/dio.dart';

import '../../../core/sync/pocketbase_client.dart';
import '../../../shared/providers/core_providers.dart';
import 'off_client.dart';

/// Three-tier barcode lookup: in-memory → PocketBase cache → Open Food Facts.
///
/// Read path (per barcode, per scan):
///   1. In-memory Map for instant repeated scans in the same session
///   2. PocketBase nt_barcode_cache for offline / cross-user cache
///   3. Open Food Facts over the network (and on hit, write back to PB
///      via a server-side sync job — not the device)
///
/// Once any user anywhere scans a barcode, every future scan anywhere —
/// even offline — returns the cached product.
class CachedOffClient {
  CachedOffClient({
    required OpenFoodFactsClient off,
    required PocketBaseClient pb,
  })  : _off = off,
        _pb = pb;

  final OpenFoodFactsClient _off;
  final PocketBaseClient _pb;

  // Session-local cache: faster than PB on the second scan within a session.
  final Map<String, OffProduct> _memCache = {};

  // Stats for /debug/cache and telemetry.
  int memHits = 0;
  int pbHits = 0;
  int offHits = 0;

  /// Look up a barcode. Returns null if not in any tier (i.e. not in OFF).
  Future<OffProduct?> lookup(String barcode) async {
    // Tier 1: in-memory (instant).
    final memHit = _memCache[barcode];
    if (memHit != null) {
      memHits++;
      return memHit;
    }

    // Tier 2: PocketBase cache. Failures are silent — fall through to OFF.
    try {
      final pbRecord = await _pb.getBarcodeCache(barcode);
      if (pbRecord != null) {
        final product = _recordToProduct(pbRecord);
        _memCache[barcode] = product;
        pbHits++;
        return product;
      }
    } on DioException {
      // Network blip — proceed to OFF, the user will see at most a slight
      // delay. Don't surface this as an error.
    }

    // Tier 3: Open Food Facts. Client has its own in-memory cache so even
    // repeat OFF lookups in a session are instant.
    final product = await _off.lookup(barcode);
    if (product != null) {
      _memCache[barcode] = product;
      offHits++;
    }
    return product;
  }

  /// Clear all in-memory tiers (e.g. on sign-out or "Clear cache" button).
  void clearSession() {
    _memCache.clear();
  }

  /// Server-side only. Pushes a fresh OFF result into PocketBase so future
  /// scans from any user benefit. Requires the admin token.
  Future<bool> pushToCache({
    required OffProduct product,
    required String adminToken,
  }) async {
    return _pb.upsertBarcodeCache(
      product: product,
      source: 'openfoodfacts',
      adminToken: adminToken,
    );
  }

  /// Snapshot of cache stats — useful for a debug overlay or analytics.
  Map<String, int> get stats => {
        'mem_hits': memHits,
        'pb_hits': pbHits,
        'off_hits': offHits,
        'mem_size': _memCache.length,
      };

  OffProduct _recordToProduct(Map<String, dynamic> r) {
    final per100g = MacroNutrients(
      protein: (r['protein_100g'] as num?)?.toDouble() ?? 0,
      carbs: (r['carbs_100g'] as num?)?.toDouble() ?? 0,
      fat: (r['fat_100g'] as num?)?.toDouble() ?? 0,
      fiber: (r['fiber_100g'] as num?)?.toDouble() ?? 0,
      sugar: (r['sugar_100g'] as num?)?.toDouble() ?? 0,
      sodium: (r['sodium_100g'] as num?)?.toDouble() ?? 0,
    );
    return OffProduct(
      barcode: r['barcode'] as String? ?? '',
      name: r['name'] as String? ?? 'Unknown product',
      brand: r['brand'] as String?,
      imageUrl: r['image_url'] as String?,
      servingGrams: (r['serving_grams'] as num?)?.toDouble(),
      per100g: per100g,
      categories: ((r['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      allergens: ((r['allergens'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      nutriscore: r['nutriscore'] as String?,
    );
  }
}