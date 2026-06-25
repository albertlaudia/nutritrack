import 'package:dio/dio.dart';

import '../../features/camera/data/off_client.dart';

/// Thin HTTP client for PocketBase REST API.
///
/// The barcode cache (`nt_barcode_cache`) is configured for anonymous read —
/// no auth required. The device only ever reads from this client; writes
/// happen exclusively via the server-side `off_to_pb_sync.js` cron job
/// using admin credentials that never ship in the app.
///
/// This is intentionally NOT the official `pocketbase` package — that's a
/// heavy dependency for what is effectively two HTTP endpoints.
class PocketBaseClient {
  PocketBaseClient({
    required String baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'Content-Type': 'application/json'},
            ));

  final String _baseUrl;
  final Dio _dio;

  String get baseUrl => _baseUrl;

  /// Fetch a barcode cache record by exact barcode match.
  /// Returns null if not cached (PB returns empty `items`) or on network
  /// failure. Network failures are swallowed — the OFF lookup will pick up
  /// the slack, so transient PB outages don't break the scanner.
  Future<Map<String, dynamic>?> getBarcodeCache(String barcode) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/collections/nt_barcode_cache/records',
        queryParameters: {
          'filter': 'barcode="$barcode"',
          'perPage': 1,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final items = res.data?['items'] as List?;
      if (items == null || items.isEmpty) return null;
      return (items.first as Map).cast<String, dynamic>();
    } on DioException {
      return null;
    }
  }

  /// Health check — used by `CachedOffClient` to skip the PB tier when the
  /// server is unreachable so we don't pay the timeout on every scan.
  Future<bool> ping() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/collections/nt_barcode_cache/records',
        queryParameters: {'perPage': 1},
        options: Options(
          receiveTimeout: const Duration(seconds: 3),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  /// Server-side upsert. Not called from the device — included for the
  /// sync cron to share the same request shape as the device's read.
  Future<bool> upsertBarcodeCache({
    required OffProduct product,
    required String source,
    required String adminToken,
  }) async {
    try {
      final body = {
        'barcode': product.barcode,
        'name': product.name,
        if (product.brand != null) 'brand': product.brand,
        if (product.imageUrl != null) 'image_url': product.imageUrl,
        if (product.servingGrams != null) 'serving_grams': product.servingGrams,
        'protein_100g': product.per100g.protein,
        'carbs_100g': product.per100g.carbs,
        'fat_100g': product.per100g.fat,
        'fiber_100g': product.per100g.fiber,
        'sugar_100g': product.per100g.sugar,
        'sodium_100g': product.per100g.sodium,
        'energy_kcal_100g': product.per100g.calories,
        'categories': product.categories,
        'allergens': product.allergens,
        if (product.nutriscore != null) 'nutriscore': product.nutriscore,
        'source': source,
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
        'hit_count': 1,
      };
      // Try update first (cheap idempotent upsert keyed on barcode).
      final existing = await _dio.get<Map<String, dynamic>>(
        '/api/collections/nt_barcode_cache/records',
        queryParameters: {
          'filter': 'barcode="${product.barcode}"',
          'perPage': 1,
        },
        options: Options(headers: {'Authorization': adminToken}),
      );
      final existingItems = existing.data?['items'] as List?;
      if (existingItems != null && existingItems.isNotEmpty) {
        final id = (existingItems.first as Map)['id'];
        await _dio.patch<Map<String, dynamic>>(
          '/api/collections/nt_barcode_cache/records/$id',
          data: body,
          options: Options(headers: {'Authorization': adminToken}),
        );
      } else {
        await _dio.post<Map<String, dynamic>>(
          '/api/collections/nt_barcode_cache/records',
          data: body,
          options: Options(headers: {'Authorization': adminToken}),
        );
      }
      return true;
    } on DioException {
      return false;
    }
  }
}