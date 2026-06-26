import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/db_service.dart';
import '../../../core/db/drift_database.dart';
import '../domain/food_log_entry.dart';
import '../domain/macro_nutrients.dart';

/// Food log repository — offline-first. All reads are reactive (Drift watch).
class FoodLogRepository {
  FoodLogRepository(this._service);

  final DbService _service;
  final _uuid = const Uuid();

  AppDatabase get _db => _service.db;

  /// Watch meals for a given date. Emits a new list whenever the underlying
  /// table changes — UI uses Riverpod `StreamProvider`.
  Stream<List<FoodLogEntry>> watchByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return (_db.select(_db.foodLogEntries)
          ..where((t) => t.loggedAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<FoodLogEntry>> getByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.foodLogEntries)
          ..where((t) => t.loggedAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> addAll(List<FoodLogEntry> entries) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.foodLogEntries,
        entries.map(_toCompanion).toList(),
      );
    });
  }

  Future<void> add(FoodLogEntry entry) => addAll([entry]);

  Future<void> update(FoodLogEntry entry) async {
    await (_db.update(_db.foodLogEntries)
          ..where((t) => t.id.equals(entry.id)))
        .write(_toCompanion(entry));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.foodLogEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markFavorite(String id, bool value) async {
    await (_db.update(_db.foodLogEntries)..where((t) => t.id.equals(id)))
        .write(FoodLogEntriesCompanion(isFavorite: Value(value)));
  }

  Future<MacroNutrients> aggregateForDate(DateTime date) async {
    final entries = await getByDate(date);
    return entries.fold<MacroNutrients>(
      MacroNutrients.empty,
      (sum, e) => sum + e.macros,
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  FoodLogEntry _fromRow(FoodLogEntry Function(FoodLogEntriesData) mapper) {
    throw UnimplementedError('use _fromData instead');
  }

  FoodLogEntry _fromData(FoodLogEntriesData e) {
    return FoodLogEntry(
      id: e.id,
      name: e.name,
      grams: e.grams,
      macros: MacroNutrients(
        protein: e.protein,
        carbs: e.carbs,
        fat: e.fat,
        fiber: e.fiber,
        sugar: e.sugar,
        sodium: e.sodium,
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

  FoodLogEntriesCompanion _toCompanion(FoodLogEntry e) {
    return FoodLogEntriesCompanion.insert(
      id: e.id,
      name: e.name,
      grams: e.grams,
      calories: e.macros.calories,
      protein: Value(e.macros.protein),
      carbs: Value(e.macros.carbs),
      fat: Value(e.macros.fat),
      fiber: Value(e.macros.fiber),
      sugar: Value(e.macros.sugar),
      sodium: Value(e.macros.sodium),
      loggedAt: e.loggedAt,
      slot: e.slot.name,
      source: e.source.name,
      confidence: Value(e.confidence),
      brand: Value(e.brand),
      imagePath: Value(e.imagePath),
      notes: Value(e.notes),
      externalId: Value(e.externalId),
      isFavorite: Value(e.isFavorite),
    );
  }

  String newId() => _uuid.v4();
}
