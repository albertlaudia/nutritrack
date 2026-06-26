import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'drift_database.g.dart';

// ─── Tables ──────────────────────────────────────────────────────────────────

class FoodLogEntries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get grams => real()();
  RealColumn get calories => real()();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  RealColumn get fiber => real().withDefault(const Constant(0))();
  RealColumn get sugar => real().withDefault(const Constant(0))();
  RealColumn get sodium => real().withDefault(const Constant(0))();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get slot => text()();
  TextColumn get source => text()();
  RealColumn get confidence => real().withDefault(const Constant(1))();
  TextColumn get brand => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get externalId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get syncedToCloud => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseEntries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  TextColumn get secondaryMusclesJson => text().withDefault(const Constant('[]'))();
  TextColumn get equipment => text()();
  TextColumn get difficulty => text()();
  TextColumn get instructions => text().nullable()();
  TextColumn get videoUrl => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get caloriesPerHour => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get name => text()();
  IntColumn get perceivedExertion => integer().withDefault(const Constant(0))();
  RealColumn get caloriesBurned => real().withDefault(const Constant(0))();
  TextColumn get exercisesJson => text().withDefault(const Constant('[]'))();
  TextColumn get notesText => text().nullable()();
  BoolColumn get syncedToCloud => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class WeightEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get weightKg => real()();
  RealColumn get bodyFatPct => real().withDefault(const Constant(0))();
  RealColumn get muscleKg => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get syncedToCloud => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get sex => text()();
  IntColumn get ageYears => integer()();
  RealColumn get heightCm => real()();
  RealColumn get weightKg => real()();
  TextColumn get activity => text()();
  TextColumn get goal => text()();
  BoolColumn get useMetric => boolean().withDefault(const Constant(true))();
  DateTimeColumn get birthDate => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ImageHashCache extends Table {
  TextColumn get hash => text()();
  TextColumn get itemsJson => text()();
  IntColumn get useCount => integer()();
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {hash};
}

class PendingSyncEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get retries => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  FoodLogEntries,
  ExerciseEntries,
  WorkoutSessions,
  WeightEntries,
  UserProfiles,
  ImageHashCache,
  PendingSyncEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'nutritrack');
  }
}
