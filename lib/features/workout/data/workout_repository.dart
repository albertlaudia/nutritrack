import 'dart:async';
import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/isar_collections.dart';
import '../../../core/db/isar_service.dart';
import '../domain/workout_models.dart';

/// Workout repository — sessions, exercise DB search.
class WorkoutRepository {
  WorkoutRepository(this._service);
  final IsarService _service;
  final _uuid = const Uuid();

  Isar get _isar => _service.isar;

  // ── Sessions ──────────────────────────────────────────────────
  Stream<List<WorkoutSession>> watchAllSessions() {
    return _isar.workoutSessionEntitys
        .where()
        .sortByStartedAtDesc()
        .build()
        .watch(fireImmediately: true)
        .map((rows) => rows.map(_fromSessionEntity).toList());
  }

  List<WorkoutSession> recentSessions({int limit = 20}) {
    return _isar.workoutSessionEntitys
        .where()
        .sortByStartedAtDesc()
        .limit(limit)
        .findAllSync()
        .map(_fromSessionEntity)
        .toList();
  }

  Future<void> startSession(String name) async {
    await _isar.writeTxn(() async {
      await _isar.workoutSessionEntitys.put(
        WorkoutSessionEntity()
          ..id = _uuid.v4()
          ..startedAt = DateTime.now()
          ..name = name,
      );
    });
  }

  Future<void> endSession(String id, List<WorkoutExercise> exercises, {int rpe = 0, double caloriesBurned = 0}) async {
    final existing = await _isar.workoutSessionEntitys
        .filter()
        .idEqualTo(id)
        .findFirst();
    if (existing == null) return;

    await _isar.writeTxn(() async {
      existing
        ..endedAt = DateTime.now()
        ..exercisesJson = jsonEncode(exercises.map((e) => e.toJson()).toList())
        ..perceivedExertion = rpe
        ..caloriesBurned = caloriesBurned;
      await _isar.workoutSessionEntitys.put(existing);
    });
  }

  // ── Exercise DB search ────────────────────────────────────────
  Future<List<Exercise>> searchExercises({
    String? query,
    MuscleGroup? primaryMuscle,
    Equipment? equipment,
    Difficulty? difficulty,
    int limit = 50,
  }) async {
    var q = _isar.exerciseEntitys.filter();

    if (query != null && query.isNotEmpty) {
      q = q.nameContains(query, caseSensitive: false);
    }
    if (primaryMuscle != null) {
      q = q.primaryMuscleEqualTo(primaryMuscle.name);
    }
    if (equipment != null) {
      q = q.equipmentEqualTo(equipment.name);
    }
    if (difficulty != null) {
      q = q.difficultyEqualTo(difficulty.name);
    }

    final rows = await q.limit(limit).findAll();
    return rows.map(_fromExerciseEntity).toList();
  }

  Future<void> seedExercisesIfEmpty(List<Exercise> seed) async {
    final count = await _isar.exerciseEntitys.count();
    if (count > 0) return;
    await _isar.writeTxn(() async {
      await _isar.exerciseEntitys.putAll(seed.map(_toExerciseEntity).toList());
    });
  }

  // ── Mappers ───────────────────────────────────────────────────
  WorkoutSession _fromSessionEntity(WorkoutSessionEntity e) {
    List<WorkoutExercise> exercises = [];
    try {
      final list = (jsonDecode(e.exercisesJson) as List).cast<Map<String, dynamic>>();
      exercises = list.map(WorkoutExercise.fromJson).toList();
    } catch (_) {}
    return WorkoutSession(
      id: e.id,
      startedAt: e.startedAt,
      endedAt: e.endedAt,
      name: e.name,
      exercises: exercises,
      perceivedExertion: e.perceivedExertion,
      caloriesBurned: e.caloriesBurned,
    );
  }

  Exercise _fromExerciseEntity(ExerciseEntity e) {
    return Exercise(
      id: e.id,
      name: e.name,
      primaryMuscle: MuscleGroup.values.firstWhere(
        (m) => m.name == e.primaryMuscle,
        orElse: () => MuscleGroup.fullBody,
      ),
      secondaryMuscles: e.secondaryMuscles
          .map((s) => MuscleGroup.values.firstWhere(
                (m) => m.name == s,
                orElse: () => MuscleGroup.fullBody,
              ))
          .toList(),
      equipment: Equipment.values.firstWhere(
        (eq) => eq.name == e.equipment,
        orElse: () => Equipment.other,
      ),
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == e.difficulty,
        orElse: () => Difficulty.beginner,
      ),
      instructions: e.instructions,
      videoUrl: e.videoUrl,
      imageUrl: e.imageUrl,
      tags: e.tags,
      caloriesPerHour: e.caloriesPerHour,
    );
  }

  ExerciseEntity _toExerciseEntity(Exercise e) {
    return ExerciseEntity()
      ..id = e.id
      ..name = e.name
      ..primaryMuscle = e.primaryMuscle.name
      ..secondaryMuscles = e.secondaryMuscles.map((m) => m.name).toList()
      ..equipment = e.equipment.name
      ..difficulty = e.difficulty.name
      ..instructions = e.instructions
      ..videoUrl = e.videoUrl
      ..imageUrl = e.imageUrl
      ..tags = e.tags
      ..caloriesPerHour = e.caloriesPerHour;
  }

  String newId() => _uuid.v4();
}