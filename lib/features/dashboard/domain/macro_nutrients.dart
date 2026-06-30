import 'package:freezed_annotation/freezed_annotation.dart';

part 'macro_nutrients.freezed.dart';
part 'macro_nutrients.g.dart';

/// Macronutrient breakdown. kcal automatically derived: P×4 + C×4 + F×9.
@freezed
class MacroNutrients with _$MacroNutrients {
  const MacroNutrients._();

  const factory MacroNutrients({
    required double protein,
    required double carbs,
    required double fat,
    @Default(0.0) double fiber,
    @Default(0.0) double sugar,
    @Default(0.0) double sodium,
  }) = _MacroNutrients;

  factory MacroNutrients.fromJson(Map<String, dynamic> json) =>
      _$MacroNutrientsFromJson(json);

  /// Total caloric value of these macros.
  double get calories => (protein * 4) + (carbs * 4) + (fat * 9);

  /// Scale to a new portion size in grams.
  MacroNutrients perGrams(double grams, {required double originalGrams}) {
    if (originalGrams == 0) return this;
    final ratio = grams / originalGrams;
    return copyWith(
      protein: protein * ratio,
      carbs: carbs * ratio,
      fat: fat * ratio,
      fiber: fiber * ratio,
      sugar: sugar * ratio,
      sodium: sodium * ratio,
    );
  }

  static const empty = MacroNutrients(protein: 0, carbs: 0, fat: 0);
}

extension MacroMath on MacroNutrients {
  MacroNutrients operator +(MacroNutrients other) => MacroNutrients(
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        fiber: fiber + other.fiber,
        sugar: sugar + other.sugar,
        sodium: sodium + other.sodium,
      );

  MacroNutrients scale(double factor) => MacroNutrients(
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
        fiber: fiber * factor,
        sugar: sugar * factor,
        sodium: sodium * factor,
      );
}