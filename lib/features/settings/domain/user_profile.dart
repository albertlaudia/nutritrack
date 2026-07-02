import 'package:freezed_annotation/freezed_annotation.dart';
import '../../dashboard/domain/macro_nutrients.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

enum Sex { male, female, other }

enum ActivityLevel {
  sedentary,      // Little/no exercise
  light,          // 1-3 days/wk
  moderate,       // 3-5 days/wk
  active,         // 6-7 days/wk
  athletic,       // Physical job + training
}

extension ActivityLevelX on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.active:
        return 'Very Active';
      case ActivityLevel.athletic:
        return 'Athletic';
    }
  }

  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.athletic:
        return 1.9;
    }
  }
}

enum Goal {
  aggressiveCut,        // -500 kcal/day, ~0.5 kg/wk loss
  moderateCut,          // -250 kcal/day, ~0.25 kg/wk loss
  recomposition,        // Maintenance + high protein
  leanBulk,             // +250 kcal/day, ~0.25 kg/wk gain
  aggressiveBulk,       // +500 kcal/day, ~0.5 kg/wk gain
  maintenance;

  String get label {
    switch (this) {
      case Goal.aggressiveCut:
        return 'Aggressive Cut';
      case Goal.moderateCut:
        return 'Moderate Cut';
      case Goal.recomposition:
        return 'Recomposition';
      case Goal.leanBulk:
        return 'Lean Bulk';
      case Goal.aggressiveBulk:
        return 'Aggressive Bulk';
      case Goal.maintenance:
        return 'Maintain';
    }
  }

  /// Caloric offset per day.
  double get kcalOffset {
    switch (this) {
      case Goal.aggressiveCut:
        return -500;
      case Goal.moderateCut:
        return -250;
      case Goal.recomposition:
        return 0;
      case Goal.leanBulk:
        return 250;
      case Goal.aggressiveBulk:
        return 500;
      case Goal.maintenance:
        return 0;
    }
  }

  /// Protein target in g per kg of bodyweight.
  double get proteinPerKg {
    switch (this) {
      case Goal.aggressiveCut:
        return 2.4;
      case Goal.moderateCut:
        return 2.2;
      case Goal.recomposition:
        return 2.0;
      case Goal.leanBulk:
        return 1.8;
      case Goal.aggressiveBulk:
        return 1.6;
      case Goal.maintenance:
        return 1.6;
    }
  }

  /// Fat as % of total kcal.
  double get fatPctOfKcal {
    switch (this) {
      case Goal.aggressiveCut:
        return 0.25;
      case Goal.moderateCut:
        return 0.25;
      case Goal.recomposition:
        return 0.25;
      case Goal.leanBulk:
        return 0.25;
      case Goal.aggressiveBulk:
        return 0.20;
      case Goal.maintenance:
        return 0.30;
    }
  }
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required Sex sex,
    required int ageYears,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required Goal goal,
    @Default(false) bool useMetric,
    DateTime? birthDate,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

extension UserProfileX on UserProfile {
  /// Mifflin-St Jeor BMR (kcal/day at rest).
  double get bmr {
    final base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * ageYears;
    switch (sex) {
      case Sex.male:
        return base + 5;
      case Sex.female:
        return base - 161;
      case Sex.other:
        return base - 78; // average
    }
  }

  /// Total Daily Energy Expenditure (TDEE) — BMR × activity multiplier.
  double get tdee => bmr * activity.multiplier;

  /// Target daily caloric intake.
  double get targetKcal => (tdee + goal.kcalOffset).clamp(1200, 6000);

  /// Target macronutrient breakdown.
  MacroNutrients get targetMacros {
    final totalKcal = targetKcal;
    final proteinG = weightKg * goal.proteinPerKg;
    final fatKcal = totalKcal * goal.fatPctOfKcal;
    final fatG = fatKcal / 9;
    final proteinKcal = proteinG * 4;
    final carbsKcal = (totalKcal - proteinKcal - fatKcal).clamp(0, double.infinity);
    final carbsG = carbsKcal / 4;
    return MacroNutrients(
      protein: proteinG,
      carbs: carbsG,
      fat: fatG,
    );
  }
}