import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../domain/food_log_entry.dart';
import '../widgets/macro_donut.dart';
import '../widgets/meal_card.dart';
import '../widgets/quick_log_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncMeals = ref.watch(todayMealsProvider);
    final asyncMacros = ref.watch(todayMacrosProvider);
    final profile = ref.watch(userProfileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: asyncMeals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (meals) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TODAY',
                              style: theme.textTheme.bodySmall?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fuel & Energy',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      _ProfilePill(profile: profile),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Center(
                    child: asyncMacros.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (macros) => MacroDonut(
                        consumed: macros.calories,
                        target: profile.targetKcal,
                        macros: macros,
                        targetMacros: profile.targetMacros,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      _MacroChip(color: AppColors.lavender, label: 'Protein', value: asyncMacros.value?.protein, target: profile.targetMacros.protein),
                      const SizedBox(width: 8),
                      _MacroChip(color: AppColors.sky, label: 'Carbs', value: asyncMacros.value?.carbs, target: profile.targetMacros.carbs),
                      const SizedBox(width: 8),
                      _MacroChip(color: AppColors.rose, label: 'Fat', value: asyncMacros.value?.fat, target: profile.targetMacros.fat),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    'Meals',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverList.builder(
                  itemCount: MealSlot.values.length,
                  itemBuilder: (context, i) {
                    final slot = MealSlot.values[i];
                    final entries = meals.where((e) => e.slot == slot).toList();
                    return MealTimelineCard(
                      slot: slot,
                      entries: entries,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: QuickLogBar(),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.color,
    required this.label,
    required this.value,
    required this.target,
  });

  final Color color;
  final String label;
  final double? value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final pct = target == 0 ? 0.0 : (v / target).clamp(0.0, 1.5);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${v.round()}g',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.profile});
  final dynamic profile;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            profile.goal.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.brand,
                ),
          ),
        ],
      ),
    );
  }
}