import 'package:dio/dio.dart';

import '../../dashboard/domain/macro_nutrients.dart';

/// Client for the Open Food Facts v2 API.
///
/// Open Food Facts is a free, open-source database of food products worldwide.
/// Barcode lookup → per-100g nutrition facts. No API key needed, no rate limit
/// beyond the implicit "be polite" guideline.
///
/// Docs: https://openfoodfacts.github.io/openfoodfacts-server/api/
class OpenFoodFactsClient {
  OpenFoodFactsClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://world.openfoodfacts.org',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: {
                'User-Agent':
                    'NutriTrack/0.1 (https://nutritrack.app; hello@nutritrack.app)',
              },
            ));

  final Dio _dio;

  /// In-memory cache for the session so repeated scans of the same product
  /// don't hit the network. Map keyed by barcode string.
  final Map<String, OffProduct?> _cache = {};

  /// Look up a product by EAN-8, EAN-13, UPC-A, UPC-E, or any other supported
  /// barcode. Returns null if the product is not in the database — callers
  /// should treat null as "unknown product" rather than an error.
  Future<OffProduct?> lookup(String barcode) async {
    if (_cache.containsKey(barcode)) return _cache[barcode];
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v2/product/$barcode.json',
        options: Options(
          // OFF uses status: 0 when product not found; that's a 200 response,
          // not an error.
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final data = res.data;
      if (data == null) {
        _cache[barcode] = null;
        return null;
      }
      final status = data['status'];
      final statusInt = status is int ? status : (status is String ? int.tryParse(status) ?? 0 : 0);
      if (statusInt != 1) {
        _cache[barcode] = null;
        return null;
      }
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) {
        _cache[barcode] = null;
        return null;
      }
      final parsed = _parse(barcode, product);
      _cache[barcode] = parsed;
      return parsed;
    } on DioException {
      _cache[barcode] = null;
      return null;
    }
  }

  OffProduct _parse(String barcode, Map<String, dynamic> product) {
    final nutriments = (product['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    final n = _NutrimentReader(nutriments);

    // OFF stores both per-100g and per-serving values; prefer per-100g for
    // total calorie accuracy and use the product's serving size as a default
    // portion suggestion.
    final servingSize = product['serving_size'] as String?;
    final servingGrams = _parseServingGrams(servingSize);

    final productName = _firstNonEmpty([
      product['product_name'],
      product['product_name_en'],
      product['generic_name'],
      product['generic_name_en'],
    ]);

    final brand = _firstNonEmpty([
      product['brands'],
      product['brands_tags'] is List && (product['brands_tags'] as List).isNotEmpty
          ? (product['brands_tags'] as List).first.toString()
          : null,
    ]);

    final imageUrl = _firstNonEmpty([
      product['image_front_url'],
      product['image_url'],
      product['image_front_small_url'],
    ]);

    final categories = (product['categories'] as String?)
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final allergens = (product['allergens'] as String?)
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final nutriscore = product['nutriscore_grade'] as String?;

    return OffProduct(
      barcode: barcode,
      name: productName ?? 'Unknown product',
      brand: brand,
      imageUrl: imageUrl,
      servingGrams: servingGrams,
      per100g: MacroNutrients(
        protein: n.read('proteins'),
        carbs: n.read('carbohydrates'),
        fat: n.read('fat'),
        fiber: n.read('fiber'),
        sugar: n.read('sugars'),
        sodium: n.readSodium(), // OFF stores sodium in grams
      ),
      categories: categories,
      allergens: allergens,
      nutriscore: nutriscore,
    );
  }

  /// OFF serving_size can be "30 g", "1 cup (240ml)", etc. We extract the
  /// first numeric token and assume grams when no unit is specified.
  double? _parseServingGrams(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
    if (match == null) return null;
    final n = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (n == null || n <= 0) return null;
    // If the unit is ml or a non-mass unit, treat as grams (rough — better
    // than nothing). The user can edit grams before saving.
    final lower = raw.toLowerCase();
    if (lower.contains('ml') || lower.contains('l')) return n;
    return n;
  }

  String? _firstNonEmpty(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }
}

/// A single product's nutrition info, normalized to per-100g.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    required this.per100g,
    this.brand,
    this.imageUrl,
    this.servingGrams,
    this.categories = const [],
    this.allergens = const [],
    this.nutriscore,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? servingGrams;
  final MacroNutrients per100g;
  final List<String> categories;
  final List<String> allergens;
  final String? nutriscore;

  /// Build a FoodLogEntry for this product at the given portion weight.
  /// The resulting entry uses the barcode as its external_id for caching
  /// future scans, and marks confidence=1.0 since OFF data is authoritative.
  Map<String, dynamic> toJsonForPortion(double grams) {
    final ratio = grams / 100.0;
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'image_url': imageUrl,
      'grams': grams,
      'protein': per100g.protein * ratio,
      'carbs': per100g.carbs * ratio,
      'fat': per100g.fat * ratio,
      'fiber': per100g.fiber * ratio,
      'sugar': per100g.sugar * ratio,
      'sodium': per100g.sodium * ratio,
      'categories': categories,
      'allergens': allergens,
      'nutriscore': nutriscore,
    };
  }
}

/// Helper for reading nutriments with two field-name conventions.
///
/// OFF has historically used both `proteins_100g` and `proteins` (and many
/// other variants). We prefer the per-100g value when present, falling back
/// to the value-as-given. This makes the parser resilient to schema drift.
class _NutrimentReader {
  _NutrimentReader(this.n);
  final Map<String, dynamic> n;

  double read(String base) {
    // Prefer _100g variant, then _value, then _serving, then plain.
    for (final suffix in ['_100g', '_value', '_serving', '']) {
      final v = n['$base$suffix'];
      final parsed = _toDouble(v);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  /// Sodium is stored either as grams (preferred) or as salt-grams with
  /// the suffix `salt`. Convert salt → sodium using 1g salt = 0.4g sodium.
  double readSodium() {
    final direct = read('sodium');
    if (direct > 0) return direct;
    final salt = read('salt');
    if (salt > 0) return salt * 0.4;
    return 0;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(',', '.').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }
}