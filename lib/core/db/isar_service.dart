import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_collections.dart';

/// Isar service — opens the singleton instance and exposes typed accessors.
///
/// We use a single Isar instance per app; all repositories share it.
class IsarService {
  IsarService._(this.isar);

  final Isar isar;

  static IsarService? _instance;
  static IsarService get instance {
    final i = _instance;
    if (i == null) throw StateError('IsarService not initialized. Call init() first.');
    return i;
  }

  static Future<IsarService> init() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        FoodLogEntitySchema,
        ExerciseEntitySchema,
        WorkoutSessionEntitySchema,
        WeightEntitySchema,
        UserProfileEntitySchema,
        ImageHashCacheEntitySchema,
        PendingSyncEntitySchema,
      ],
      directory: dir.path,
      name: 'nutritrack',
      inspector: false,   // Disable in release for performance
    );
    _instance = IsarService._(isar);
    return _instance!;
  }

  Future<void> close() async {
    await isar.close();
    _instance = null;
  }
}