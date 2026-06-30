import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/db_service.dart';
import '../../../core/db/drift_database.dart';
import '../domain/workout_models.dart' as domain;

/// Workout repository — sessions, exercise DB search.
class WorkoutRepository {
  WorkoutRepository(this._service);
  final DbService _service;
  final _uuid = const Uuid();

  AppDatabase get _db => _service.db;

  // ── Sessions ──────────────────────────────────────────────────
  Stream<List<domain.WorkoutSession>> watchAllSessions() {
    return (_db.select(_db.workoutSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch()
        .map((rows) => rows.map(_fromSessionRow).toList());
  }

  Future<List<domain.WorkoutSession>> recentSessions({int limit = 20}) async {
    final rows = await (_db.select(_db.workoutSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .get();
    return rows.map(_fromSessionRow).toList();
  }

  Future<void> startSession(String name) async {
    await _db.into(_db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: _uuid.v4(),
            startedAt: DateTime.now(),
            name: name,
          ),
        );
  }

  Future<void> endSession(String id, List<domain.WorkoutExercise> exercises, {int rpe = 0, double caloriesBurned = 0}) async {
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(id)))
        .write(WorkoutSessionsCompanion(
      endedAt: Value(DateTime.now()),
      exercisesJson: Value(jsonEncode(exercises.map((e) => e.toJson()).toList())),
      perceivedExertion: Value(rpe),
      caloriesBurned: Value(caloriesBurned),
    ));
  }

  // ── Exercise DB search ────────────────────────────────────────
  Future<List<domain.Exercise>> searchExercises({
    String? query,
    domain.MuscleGroup? primaryMuscle,
    domain.Equipment? equipment,
    domain.Difficulty? difficulty,
    int limit = 50,
  }) async {
    final stmt = _db.select(_db.exerciseEntries);
    stmt.where((t) {
      Expression<bool> cond = const Constant(true);
      if (query != null && query.isNotEmpty) {
        cond = cond & t.name.lower().contains(query.toLowerCase());
      }
      if (primaryMuscle != null) {
        cond = cond & t.primaryMuscle.equals(primaryMuscle.name);
      }
      if (equipment != null) {
        cond = cond & t.equipment.equals(equipment.name);
      }
      if (difficulty != null) {
        cond = cond & t.difficulty.equals(difficulty.name);
      }
      return cond;
    });
    stmt.limit(limit);
    final rows = await stmt.get();
    return rows.map(_fromExerciseRow).cast<domain.Exercise>().toList();
  }

  Future<void> seedExercisesIfEmpty(List<domain.Exercise> seed) async {
    final count = await _db.exerciseEntries.count().getSingle();
    if (count > 0) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.exerciseEntries,
        seed.map(_toExerciseCompanion).toList(),
      );
    });
  }

  // ── Mappers ───────────────────────────────────────────────────
  domain.WorkoutSession _fromSessionRow(WorkoutSessionRow e) {
    List<domain.WorkoutExercise> exercises = [];
    try {
      final list = (jsonDecode(e.exercisesJson) as List).cast<Map<String, dynamic>>();
      exercises = list.map(domain.WorkoutExercise.fromJson).toList();
    } catch (_) {}
    return domain.WorkoutSession(
      id: e.id,
      startedAt: e.startedAt,
      endedAt: e.endedAt,
      name: e.name,
      exercises: exercises,
      perceivedExertion: e.perceivedExertion,
      caloriesBurned: e.caloriesBurned,
    );
  }

  domain.Exercise _fromExerciseRow(ExerciseEntryRow e) {
    final secondaryMuscles = (jsonDecode(e.secondaryMusclesJson) as List)
        .cast<String>()
        .map((s) => domain.MuscleGroup.values.firstWhere(
              (m) => m.name == s,
              orElse: () => domain.MuscleGroup.fullBody,
            ))
        .toList();
    final tags = (jsonDecode(e.tagsJson) as List).cast<String>();
    return domain.Exercise(
      id: e.id,
      name: e.name,
      primaryMuscle: domain.MuscleGroup.values.firstWhere(
        (m) => m.name == e.primaryMuscle,
        orElse: () => domain.MuscleGroup.fullBody,
      ),
      secondaryMuscles: secondaryMuscles,
      equipment: domain.Equipment.values.firstWhere(
        (eq) => eq.name == e.equipment,
        orElse: () => domain.Equipment.other,
      ),
      difficulty: domain.Difficulty.values.firstWhere(
        (d) => d.name == e.difficulty,
        orElse: () => domain.Difficulty.beginner,
      ),
      instructions: e.instructions,
      videoUrl: e.videoUrl,
      imageUrl: e.imageUrl,
      tags: tags,
      caloriesPerHour: e.caloriesPerHour,
    );
  }

  ExerciseEntriesCompanion _toExerciseCompanion(domain.Exercise e) {
    return ExerciseEntriesCompanion.insert(
      id: e.id,
      name: e.name,
      primaryMuscle: e.primaryMuscle.name,
      secondaryMusclesJson: Value(jsonEncode(e.secondaryMuscles.map((m) => m.name).toList())),
      equipment: e.equipment.name,
      difficulty: e.difficulty.name,
      instructions: Value(e.instructions),
      videoUrl: Value(e.videoUrl),
      imageUrl: Value(e.imageUrl),
      tagsJson: Value(jsonEncode(e.tags)),
      caloriesPerHour: Value(e.caloriesPerHour),
    );
  }

  String newId() => _uuid.v4();
}