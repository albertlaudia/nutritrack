import 'dart:convert';

import 'package:dio/dio.dart';

import '../../features/camera/data/off_client.dart';

/// Thin HTTP client for PocketBase REST API. Used by the barcode cache layer
/// to push/pull OFF lookups. Lazy-auth — no admin credentials on the device;
/// we use the existing PocketBase auth (PocketBase Flutter SDK handles this,
/// but for a focused barcode cache we just need a Dio with the right base URL
/// and the user's bearer token).
///
/// The Flutter `pocketbase` package would be a heavy dependency for what is
/// essentially `GET /api/collections/nt_barcode_cache/records?filter=barcode=X`.
/// Until we add full PocketBase sync we keep this minimal.
class PocketBaseClient {
  PocketBaseClient({
    required String baseUrl,
    String? token,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _token = token,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'Content-Type': 'application/json'},
            ));

  String _baseUrl;
  String? _token;
  final Dio _dio;

  /// Set / update the auth token. Called by the auth provider when the user
  /// signs in. Pass null on sign-out.
  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers() {
    final h = <String, String>{};
    if (_token != null) h['Authorization'] = _token!;
    return h;
  }

  /// Fetch a barcode cache record by exact barcode match.
  /// Returns null if not cached (PB returns 404) or on network failure.
  Future<Map<String, dynamic>?> getBarcodeCache(String barcode) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/collections/nt_barcode_cache/records',
        queryParameters: {
          'filter': 'barcode="$barcode"',
          'perPage': 1,
        },
        options: Options(headers: _headers(), validateStatus: (s) => s != null && s < 500),
      );
      final items = res.data?['items'] as List?;
      if (items == null || items.isEmpty) return null;
      return (items.first as Map).cast<String, dynamic>();
    } on DioException {
      return null;
    }
  }

  /// Upsert a barcode cache record. Requires superuser auth (only the server
  /// sync job calls this). The client-facing app uses [getBarcodeCache] only.
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