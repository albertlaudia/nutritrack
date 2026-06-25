import 'package:dio/dio.dart';

import '../../../core/sync/pocketbase_client.dart';
import 'off_client.dart';

/// Three-tier barcode lookup: in-memory → PocketBase cache → Open Food Facts.
///
/// Read path (per barcode, per scan):
///   1. In-memory Map for instant repeated scans in the same session
///   2. PocketBase nt_barcode_cache for offline / cross-user cache
///   3. Open Food Facts over the network (and on hit, write back to PB
///      via a server-side sync job — not the device)
///
/// PB tier is gated by a circuit-breaker: if PB is unreachable (timeout,
/// DNS error, server down), we skip it for the next 30s instead of paying
/// the timeout cost on every scan. The OFF tier always works as fallback.
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

  // Circuit breaker for the PB tier. When the last PB call failed, we skip
  // PB until _pbOpenUntil (epoch millis). Stops wasting 8s timeouts when
  // the server is down. A successful PB call resets it to 0.
  int _pbOpenUntil = 0;
  static const _circuitBreakerMs = 30000; // 30s

  // Stats for /debug/cache and telemetry.
  int memHits = 0;
  int pbHits = 0;
  int offHits = 0;
  int pbSkippedByBreaker = 0;

  /// Look up a barcode. Returns null if not in any tier (i.e. not in OFF).
  Future<OffProduct?> lookup(String barcode) async {
    // Tier 1: in-memory (instant, zero IO).
    final memHit = _memCache[barcode];
    if (memHit != null) {
      memHits++;
      return memHit;
    }

    // Tier 2: PocketBase cache, gated by circuit breaker.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pbAvailable = nowMs >= _pbOpenUntil;
    if (pbAvailable) {
      try {
        final pbRecord = await _pb.getBarcodeCache(barcode);
        // PB worked — reset the breaker.
        _pbOpenUntil = 0;
        if (pbRecord != null) {
          final product = _recordToProduct(pbRecord);
          _memCache[barcode] = product;
          pbHits++;
          return product;
        }
      } on DioException {
        // PB failed — open the breaker so we don't keep paying for timeouts.
        _pbOpenUntil = nowMs + _circuitBreakerMs;
      }
    } else {
      pbSkippedByBreaker++;
    }

    // Tier 3: Open Food Facts over the network.
    final product = await _off.lookup(barcode);
    if (product != null) {
      _memCache[barcode] = product;
      offHits++;
    }
    return product;
  }

  /// Clear the in-memory tier only. PB cache is server-side and persists.
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
        'pb_skipped_breaker': pbSkippedByBreaker,
        'pb_available': DateTime.now().millisecondsSinceEpoch >= _pbOpenUntil ? 1 : 0,
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