import 'package:isar/isar.dart';

part 'isar_collections.g.dart';

// ─── Embedded macros (per 100g) ─────────────────────────────────
@embedded
class MacrosEmbedded {
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  double fiber = 0;
  double sugar = 0;
  double sodium = 0;
}

// ─── Food log entry collection ─────────────────────────────────
@collection
class FoodLogEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String name;

  @Index()
  late DateTime loggedAt;

  @Enumerated(EnumType.name)
  late String slot;

  @Enumerated(EnumType.name)
  late String source;

  late double grams;

  @Index()
  late double calories;

  late double confidence;

  String? brand;
  String? imagePath;
  String? notes;
  String? externalId;
  bool isFavorite = false;

  // Embedded macros
  MacrosEmbedded macros = MacrosEmbedded();

  // Sync state
  bool syncedToCloud = false;
  DateTime? updatedAt;
}

// ─── Exercise collection (seeded once) ────────────────────────
@collection
class ExerciseEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index(caseSensitive: false)
  late String name;

  @Enumerated(EnumType.name)
  late String primaryMuscle;

  List<String> secondaryMuscles = [];

  @Enumerated(EnumType.name)
  late String equipment;

  @Enumerated(EnumType.name)
  late String difficulty;

  String? instructions;
  String? videoUrl;
  String? imageUrl;
  List<String> tags = [];
  int caloriesPerHour = 0;
}

// ─── Workout session collection ────────────────────────────────
@collection
class WorkoutSessionEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late DateTime startedAt;

  DateTime? endedAt;
  late String name;
  int perceivedExertion = 0;
  double caloriesBurned = 0;

  /// JSON-encoded list of WorkoutExercise
  String exercisesJson = '[]';

  String? notes;
  bool syncedToCloud = false;
}

// ─── Weight / biometric collection ────────────────────────────
@collection
class WeightEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late DateTime recordedAt;

  late double weightKg;
  double bodyFatPct = 0;
  double muscleKg = 0;
  String? notes;
  bool syncedToCloud = false;
}

// ─── User profile singleton ───────────────────────────────────
@collection
class UserProfileEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;                  // Always 'me'

  @Enumerated(EnumType.name)
  late String sex;

  late int ageYears;
  late double heightCm;
  late double weightKg;

  @Enumerated(EnumType.name)
  late String activity;

  @Enumerated(EnumType.name)
  late String goal;

  bool useMetric = true;
  DateTime? birthDate;
  DateTime? updatedAt;
}

// ─── Image hash → recognized foods cache ──────────────────────
@collection
class ImageHashCacheEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String hash;

  /// JSON-encoded List<FoodLogEntry>
  late String itemsJson;
  late int useCount;
  late DateTime lastUsedAt;
}

// ─── Sync queue (offline → cloud) ─────────────────────────────
@collection
class PendingSyncEntity {
  Id isarId = Isar.autoIncrement;

  @Index()
  late String entityType;          // 'food_log' | 'workout' | 'weight'

  late String entityId;
  @Enumerated(EnumType.name)
  late String operation;           // 'create' | 'update' | 'delete'
  late DateTime queuedAt;
  int retries = 0;
  String? lastError;
}