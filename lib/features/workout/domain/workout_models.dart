import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_models.freezed.dart';
part 'workout_models.g.dart';

enum MuscleGroup {
  chest,
  back,
  shoulders,
  arms,
  legs,
  glutes,
  core,
  fullBody,
  cardio,
}

extension MuscleGroupX on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.arms:
        return 'Arms';
      case MuscleGroup.legs:
        return 'Legs';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.core:
        return 'Core';
      case MuscleGroup.fullBody:
        return 'Full Body';
      case MuscleGroup.cardio:
        return 'Cardio';
    }
  }
}

enum Equipment {
  bodyweight,
  dumbbell,
  barbell,
  kettlebell,
  machine,
  cable,
  band,
  other,
}

extension EquipmentX on Equipment {
  String get label {
    switch (this) {
      case Equipment.bodyweight:
        return 'Bodyweight';
      case Equipment.dumbbell:
        return 'Dumbbell';
      case Equipment.barbell:
        return 'Barbell';
      case Equipment.kettlebell:
        return 'Kettlebell';
      case Equipment.machine:
        return 'Machine';
      case Equipment.cable:
        return 'Cable';
      case Equipment.band:
        return 'Band';
      case Equipment.other:
        return 'Other';
    }
  }
}

enum Difficulty {
  beginner,
  intermediate,
  advanced,
}

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.beginner:
        return 'Beginner';
      case Difficulty.intermediate:
        return 'Intermediate';
      case Difficulty.advanced:
        return 'Advanced';
    }
  }
}

@freezed
class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    required MuscleGroup primaryMuscle,
    @Default(<MuscleGroup>[]) List<MuscleGroup> secondaryMuscles,
    required Equipment equipment,
    required Difficulty difficulty,
    String? instructions,
    String? videoUrl,
    String? imageUrl,
    @Default(<String>[]) List<String> tags,
    @Default(0) int caloriesPerHour,   // Rough MET-based estimate
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}

@freezed
class SetEntry with _$SetEntry {
  const factory SetEntry({
    required int reps,
    required double weightKg,
    @Default(0) int rpe,                 // Rate of Perceived Exertion 1-10
    @Default(false) bool isWarmup,
    @Default(false) bool isFailure,
    @Default(false) bool isDropSet,
    int? restSeconds,
  }) = _SetEntry;

  factory SetEntry.fromJson(Map<String, dynamic> json) =>
      _$SetEntryFromJson(json);
}

extension SetEntryX on SetEntry {
  /// Estimated 1-Rep Max using Epley formula.
  double get estimatedOneRm =>
      weightKg * (1 + reps / 30.0);

  /// Volume in kg × reps.
  double get volume => weightKg * reps;
}

@freezed
class WorkoutExercise with _$WorkoutExercise {
  const factory WorkoutExercise({
    required String exerciseId,
    required String exerciseName,
    required List<SetEntry> sets,
    String? notes,
    @Default(true) bool supersetNext,
  }) = _WorkoutExercise;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      _$WorkoutExerciseFromJson(json);
}

extension WorkoutExerciseX on WorkoutExercise {
  double get totalVolume =>
      sets.fold(0.0, (sum, s) => sum + s.volume);
  double get topWeight =>
      sets.isEmpty ? 0 : sets.map((s) => s.weightKg).reduce((a, b) => a > b ? a : b);
  int get totalReps =>
      sets.fold(0, (sum, s) => sum + s.reps);
}

@freezed
class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required DateTime startedAt,
    DateTime? endedAt,
    required String name,
    @Default(<WorkoutExercise>[]) List<WorkoutExercise> exercises,
    String? notes,
    @Default(0) int perceivedExertion,   // Overall session RPE 1-10
    @Default(0) double caloriesBurned,
  }) = _WorkoutSession;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);
}

extension WorkoutSessionX on WorkoutSession {
  double get totalVolume =>
      exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
  Duration get duration =>
      endedAt == null ? Duration.zero : endedAt!.difference(startedAt);
  bool get isActive => endedAt == null;
  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);
}