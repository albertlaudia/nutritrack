import 'drift_database.dart';

/// Thin wrapper that owns the [AppDatabase] singleton.
///
/// Replaces the old IsarService — all repositories receive this and call
/// [db] directly to access Drift DAOs / query builders.
class DbService {
  DbService._(this.db);

  final AppDatabase db;

  static DbService? _instance;
  static DbService get instance {
    final i = _instance;
    if (i == null) throw StateError('DbService not initialized. Call init() first.');
    return i;
  }

  static Future<DbService> init() async {
    if (_instance != null) return _instance!;
    _instance = DbService._(AppDatabase());
    return _instance!;
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
