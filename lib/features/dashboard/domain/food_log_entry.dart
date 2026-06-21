import 'package:freezed_annotation/freezed_annotation.dart';
import 'macro_nutrients.dart';

part 'food_log_entry.freezed.dart';
part 'food_log_entry.g.dart';

enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack,
}

extension MealSlotX on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Breakfast';
      case MealSlot.lunch:
        return 'Lunch';
      case MealSlot.dinner:
        return 'Dinner';
      case MealSlot.snack:
        return 'Snack';
    }
  }

  String get emoji {
    switch (this) {
      case MealSlot.breakfast:
        return '🌅';
      case MealSlot.lunch:
        return '☀️';
      case MealSlot.dinner:
        return '🌙';
      case MealSlot.snack:
        return '🍿';
    }
  }
}

enum LogSource {
  cameraAI,    // Photo → M3 vision
  voiceAI,     // Whisper transcription → parse
  barcode,     // Open Food Facts barcode
  search,      // Manual search
  recipe,      // From saved recipe
  custom,      // User-typed entry
}

extension LogSourceX on LogSource {
  String get label {
    switch (this) {
      case LogSource.cameraAI:
        return 'AI Snap';
      case LogSource.voiceAI:
        return 'Voice';
      case LogSource.barcode:
        return 'Barcode';
      case LogSource.search:
        return 'Search';
      case LogSource.recipe:
        return 'Recipe';
      case LogSource.custom:
        return 'Custom';
    }
  }
}

/// A single food item logged by the user.
@freezed
class FoodLogEntry with _$FoodLogEntry {
  const factory FoodLogEntry({
    required String id,
    required String name,
    required double grams,
    required MacroNutrients macros,
    required DateTime loggedAt,
    required MealSlot slot,
    required LogSource source,
    String? brand,
    String? imagePath,
    String? notes,
    @Default(1.0) double confidence,   // 0..1 — AI certainty
    String? externalId,                // Barcode, OFF id, etc.
    @Default(false) bool isFavorite,
  }) = _FoodLogEntry;

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) =>
      _$FoodLogEntryFromJson(json);
}

extension FoodLogEntryX on FoodLogEntry {
  double get calories => macros.calories;
  bool get isLowConfidence => source == LogSource.cameraAI && confidence < 0.6;

  String get displayTitle {
    if (brand != null && brand!.isNotEmpty) return '$brand · $name';
    return name
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}