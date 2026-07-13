import 'package:drift/drift.dart';
import '../../../../core/db/drift_database.dart';
import '../domain/user_profile.dart';

/// Repository for persisting the single-user UserProfile to local Drift.
///
/// The local UserProfiles table has a 1-row contract: the "me" record.
/// On first launch, no record exists; we return a default. After the
/// user saves in Settings, the record persists across app restarts.
class UserProfileRepository {
  UserProfileRepository(this._db);

  final AppDatabase _db;

  static const String _selfId = 'me';

  /// Read the persisted profile, or a sane default if none exists.
  Future<UserProfile> get() async {
    final query = _db.select(_db.userProfiles)
      ..where((t) => t.id.equals(_selfId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) {
      return _defaultProfile();
    }
    return _rowToProfile(row);
  }

  /// Watch the persisted profile. Emits a fresh UserProfile whenever
  /// the row changes (e.g., from Settings).
  Stream<UserProfile> watch() {
    final query = _db.select(_db.userProfiles)
      ..where((t) => t.id.equals(_selfId))
      ..limit(1);
    return query.watchSingleOrNull().map(
          (row) => row == null ? _defaultProfile() : _rowToProfile(row),
        );
  }

  /// Upsert: create the "me" row if absent, otherwise update.
  Future<void> save(UserProfile profile) async {
    final row = _profileToRow(profile);
    await _db.into(_db.userProfiles).insertOnConflictUpdate(row);
  }

  // ── Mapping ──────────────────────────────────────────────────────────

  UserProfile _rowToProfile(UserProfileRow row) {
    return UserProfile(
      id: row.id,
      sex: _parseSex(row.sex),
      ageYears: row.ageYears,
      heightCm: row.heightCm,
      weightKg: row.weightKg,
      activity: _parseActivity(row.activity),
      goal: _parseGoal(row.goal),
      useMetric: row.useMetric,
      birthDate: row.birthDate,
    );
  }

  UserProfilesCompanion _profileToRow(UserProfile p) {
    return UserProfilesCompanion.insert(
      id: p.id,
      sex: p.sex.name,
      ageYears: p.ageYears,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
      activity: p.activity.name,
      goal: p.goal.name,
      useMetric: Value(p.useMetric),
      birthDate: Value(p.birthDate),
      updatedAt: Value(DateTime.now()),
    );
  }

  UserProfile _defaultProfile() => UserProfile(
        id: _selfId,
        sex: Sex.other,
        ageYears: 30,
        heightCm: 170,
        weightKg: 70,
        activity: ActivityLevel.moderate,
        goal: Goal.maintenance,
        useMetric: true,
      );

  Sex _parseSex(String raw) {
    for (final s in Sex.values) {
      if (s.name == raw) return s;
    }
    return Sex.other;
  }

  ActivityLevel _parseActivity(String raw) {
    for (final a in ActivityLevel.values) {
      if (a.name == raw) return a;
    }
    return ActivityLevel.moderate;
  }

  Goal _parseGoal(String raw) {
    for (final g in Goal.values) {
      if (g.name == raw) return g;
    }
    return Goal.maintenance;
  }
}
