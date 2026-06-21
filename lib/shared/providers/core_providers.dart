import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/config/secrets.dart';
import '../../core/db/isar_service.dart';
import '../../features/dashboard/data/food_log_repository.dart';
import '../../features/dashboard/domain/food_log_entry.dart';
import '../../features/dashboard/domain/macro_nutrients.dart';
import '../../features/settings/domain/user_profile.dart';
import '../../features/workout/data/workout_repository.dart';

part 'core_providers.g.dart';

/// Initialize Isar at app start.
@Riverpod(keepAlive: true)
Future<IsarService> isarInit(IsarInitRef ref) async {
  final service = await IsarService.init();
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

/// Food log repository — depends on isar.
@Riverpod(keepAlive: true)
Future<FoodLogRepository> foodLogRepository(FoodLogRepositoryRef ref) async {
  final isar = await ref.watch(isarInitProvider.future);
  return FoodLogRepository(isar);
}

/// Workout repository.
@Riverpod(keepAlive: true)
Future<WorkoutRepository> workoutRepository(WorkoutRepositoryRef ref) async {
  final isar = await ref.watch(isarInitProvider.future);
  return WorkoutRepository(isar);
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

/// AsyncNotifier holding today's meals as a reactive stream from Isar.
@Riverpod(keepAlive: true)
class TodayMeals extends _$TodayMeals {
  @override
  Stream<List<FoodLogEntry>> build() async* {
    final repoAsync = ref.watch(foodLogRepositoryProvider);
    final repo = await repoAsync;
    final date = ref.watch(selectedDateProvider);
    yield* repo.watchByDate(date);
  }

  Future<void> add(List<FoodLogEntry> entries) async {
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