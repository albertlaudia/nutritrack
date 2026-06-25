import 'dart:async';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/isar_collections.dart';
import '../../../core/db/isar_service.dart';
import '../domain/food_log_entry.dart';
import '../domain/macro_nutrients.dart';

/// Food log repository — offline-first. All reads are reactive (Isar watch).
class FoodLogRepository {
  FoodLogRepository(this._service);

  final IsarService _service;
  final _uuid = const Uuid();

  Isar get _isar => _service.isar;

  /// Watch meals for a given date. Emits a new list whenever the underlying
  /// Isar collection changes — UI uses Riverpod `StreamProvider`.
  Stream<List<FoodLogEntry>> watchByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final query = _isar.foodLogEntitys
        .filter()
        .loggedAtBetween(start, end)
        .sortByLoggedAt()
        .build();

    return query
        .watch(fireImmediately: true)
        .map(_mapEntities);
  }

  List<FoodLogEntry> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = _isar.foodLogEntitys
        .filter()
        .loggedAtBetween(start, end)
        .sortByLoggedAt()
        .findAllSync();
    return _mapEntities(rows);
  }

  Future<void> addAll(List<FoodLogEntry> entries) async {
    await _isar.writeTxn(() async {
      final entities = entries.map(_toEntity).toList();
      await _isar.foodLogEntitys.putAllById(entities);
    });
  }

  Future<void> add(FoodLogEntry entry) async {
    await addAll([entry]);
  }

  Future<void> update(FoodLogEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.foodLogEntitys.put(_toEntity(entry));
    });
  }

  Future<void> delete(String id) async {
    await _isar.writeTxn(() async {
      // Find first by string id, then delete by Isar's internal numeric id.
      final entity = await _isar.foodLogEntitys
          .filter()
          .idEqualTo(id)
          .findFirst();
      if (entity != null) {
        await _isar.foodLogEntitys.delete(entity.isarId);
      }
    });
  }

  /// Toggle favorite state for an entry. No-op if id is unknown.
  Future<void> markFavorite(String id, bool value) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.foodLogEntitys
          .filter()
          .idEqualTo(id)
          .findFirst();
      if (entity != null) {
        entity.isFavorite = value;
        await _isar.foodLogEntitys.put(entity);
      }
    });
  }

  /// Aggregate macros for a date — sums all entries.
  Future<MacroNutrients> aggregateForDate(DateTime date) async {
    final entries = getByDate(date);
    return entries.fold<MacroNutrients>(
      MacroNutrients.empty,
      (sum, e) => sum + e.macros,
    );
  }

  // ── Mapping ───────────────────────────────────────────────────
  List<FoodLogEntry> _mapEntities(List<FoodLogEntity> rows) {
    return rows.map(_fromEntity).toList();
  }

  FoodLogEntry _fromEntity(FoodLogEntity e) {
    final m = e.macros;
    return FoodLogEntry(
      id: e.id,
      name: e.name,
      grams: e.grams,
      macros: MacroNutrients(
        protein: m.protein,
        carbs: m.carbs,
        fat: m.fat,
        fiber: m.fiber,
        sugar: m.sugar,
        sodium: m.sodium,
      ),
      loggedAt: e.loggedAt,
      slot: MealSlot.values.firstWhere(
        (s) => s.name == e.slot,
        orElse: () => MealSlot.snack,
      ),
      source: LogSource.values.firstWhere(
        (s) => s.name == e.source,
        orElse: () => LogSource.custom,
      ),
      confidence: e.confidence,
      brand: e.brand,
      imagePath: e.imagePath,
      notes: e.notes,
      externalId: e.externalId,
      isFavorite: e.isFavorite,
    );
  }

  FoodLogEntity _toEntity(FoodLogEntry e) {
    final entity = FoodLogEntity()
      ..id = e.id
      ..name = e.name
      ..grams = e.grams
      ..loggedAt = e.loggedAt
      ..slot = e.slot.name
      ..source = e.source.name
      ..confidence = e.confidence
      ..brand = e.brand
      ..imagePath = e.imagePath
      ..notes = e.notes
      ..externalId = e.externalId
      ..isFavorite = e.isFavorite
      ..calories = e.macros.calories;
    entity.macros
      ..protein = e.macros.protein
      ..carbs = e.macros.carbs
      ..fat = e.macros.fat
      ..fiber = e.macros.fiber
      ..sugar = e.macros.sugar
      ..sodium = e.macros.sodium;
    return entity;
  }

  String newId() => _uuid.v4();
}