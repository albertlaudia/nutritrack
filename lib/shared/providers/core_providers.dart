import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/config/secrets.dart';
import '../../core/db/db_service.dart';
import '../../core/sync/pocketbase_client.dart';
import '../../features/camera/data/off_cache.dart';
import '../../features/camera/data/off_client.dart';
import '../../features/dashboard/data/food_log_repository.dart';
import '../../features/dashboard/domain/food_log_entry.dart' as domain;
import '../../features/dashboard/domain/macro_nutrients.dart';
import '../../features/settings/domain/user_profile.dart';
import '../../features/workout/data/workout_repository.dart';

part 'core_providers.g.dart';

/// Initialize the local database at app start.
@Riverpod(keepAlive: true)
Future<DbService> dbInit(DbInitRef ref) async {
  final service = await DbService.init();
  ref.onDispose(service.close);
  return service;
}

/// AI gateway — singleton.
@Riverpod(keepAlive: true)
AIGateway aiGateway(AiGatewayRef ref) {
  return OpenRouterAIGateway(
    apiKey: Secrets.openRouterApiKey,
    primaryModel: Secrets.visionModel,
    fallbackModels: Secrets.fallbackModels,
  );
}

/// Open Food Facts barcode-lookup client. Singleton — uses an in-memory
/// session cache so repeat scans are instant.
@Riverpod(keepAlive: true)
OpenFoodFactsClient openFoodFacts(OpenFoodFactsRef ref) {
  return OpenFoodFactsClient();
}

/// PocketBase HTTP client — used for the cross-user barcode cache and
/// future cloud sync. No token: the barcode cache is configured for
/// anonymous read on the server side (public OFF data).
@Riverpod(keepAlive: true)
PocketBaseClient pocketBase(PocketBaseRef ref) {
  return PocketBaseClient(
    baseUrl: Secrets.pocketBaseUrl,
  );
}

/// Three-tier barcode cache: in-memory → PocketBase → Open Food Facts.
/// All scan paths should read from this rather than OpenFoodFactsClient
/// directly. The scanner UI does not change.
@Riverpod(keepAlive: true)
CachedOffClient cachedOff(CachedOffRef ref) {
  return CachedOffClient(
    off: ref.watch(openFoodFactsProvider),
    pb: ref.watch(pocketBaseProvider),
  );
}

/// Food log repository — depends on local db.
@Riverpod(keepAlive: true)
Future<FoodLogRepository> foodLogRepository(FoodLogRepositoryRef ref) async {
  final db = await ref.watch(dbInitProvider.future);
  return FoodLogRepository(db);
}

/// Workout repository.
@Riverpod(keepAlive: true)
Future<WorkoutRepository> workoutRepository(WorkoutRepositoryRef ref) async {
  final db = await ref.watch(dbInitProvider.future);
  return WorkoutRepository(db);
}

/// Selected date — defaults to today.
@riverpod
class SelectedDate extends _$SelectedDate {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

/// User profile controller — single record.
@Riverpod(keepAlive: true)
class UserProfileController extends _$UserProfileController {
  @override
  UserProfile build() {
    return UserProfile(
      id: 'me',
      sex: Sex.other,
      ageYears: 30,
      heightCm: 170,
      weightKg: 70,
      activity: ActivityLevel.moderate,
      goal: Goal.maintenance,
    );
  }

  void update(UserProfile profile) => state = profile;
}

/// AsyncNotifier holding today's meals as a reactive stream from Drift.
@Riverpod(keepAlive: true)
class TodayMeals extends _$TodayMeals {
  @override
  Stream<List<domain.FoodLogEntry>> build() async* {
    final repo = await ref.watch(foodLogRepositoryProvider.future);
    final date = ref.watch(selectedDateProvider);
    yield* repo.watchByDate(date);
  }

  Future<void> add(List<domain.FoodLogEntry> entries) async {
    final repo = await ref.read(foodLogRepositoryProvider.future);
    await repo.addAll(entries);
  }

  Future<void> delete(String id) async {
    final repo = await ref.read(foodLogRepositoryProvider.future);
    await repo.delete(id);
  }
}

/// Today's macros — derived from today's meals.
@riverpod
Future<MacroNutrients> todayMacros(TodayMacrosRef ref) async {
  final meals = await ref.watch(todayMealsProvider.future);
  return meals.fold<MacroNutrients>(
    MacroNutrients.empty,
    (sum, e) => sum + e.macros,
  );
}