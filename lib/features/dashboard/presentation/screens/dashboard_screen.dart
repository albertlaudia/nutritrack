import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../domain/food_log_entry.dart';
import '../../domain/macro_nutrients.dart';
import '../../../settings/domain/user_profile.dart';
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
    // Profile is async (loads from Drift). While loading, fall back to a sane
    // default so target rings still render with placeholder values.
    final profile = ref.watch(userProfileControllerProvider).valueOrNull ?? _defaultProfile();

    Future<void> deleteEntry(String id) async {
      HapticFeedback.mediumImpact();
      await ref.read(todayMealsProvider.notifier).delete(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                // The delete already removed it; in a fuller app we'd restore
                // via a PendingOp. For now this is a no-op but shows the affordance.
              },
            ),
          ),
        );
      }
    }

    Future<void> toggleFavorite(FoodLogEntry entry) async {
      HapticFeedback.lightImpact();
      final repo = await ref.read(foodLogRepositoryProvider.future);
      await repo.markFavorite(entry.id, !entry.isFavorite);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(entry.isFavorite ? 'Removed from favorites' : '★ Favorited'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: asyncMeals.when(
          loading: () => const _LoadingState(),
          error: (e, st) => _ErrorState(
            message: 'Could not load your meals.',
            error: e,
            onRetry: () {
              ref.invalidate(todayMealsProvider);
              ref.invalidate(todayMacrosProvider);
            },
          ),
          data: (meals) => RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              ref.invalidate(todayMealsProvider);
              ref.invalidate(todayMacrosProvider);
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                    child: Row(
                      children: [
                        Text(
                          'Meals',
                          style: theme.textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          '${meals.length} ${meals.length == 1 ? 'item' : 'items'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
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
                        onAdd: () => _showAddSheet(context, ref, slot),
                        onDeleteEntry: deleteEntry,
                        onFavoriteEntry: toggleFavorite,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: QuickLogBar(),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, MealSlot slot) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMealSheet(slot: slot, ref: ref),
    );
  }
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet({required this.slot, required this.ref});
  final MealSlot slot;
  final WidgetRef ref;

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _nameCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final grams = double.tryParse(_gramsCtrl.text);
    if (name.isEmpty || grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and grams')),
      );
      return;
    }
    final p = double.tryParse(_proteinCtrl.text) ?? 0;
    final c = double.tryParse(_carbsCtrl.text) ?? 0;
    final f = double.tryParse(_fatCtrl.text) ?? 0;

    setState(() => _saving = true);
    final entry = FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.toLowerCase(),
      grams: grams,
      macros: MacroNutrients(protein: p, carbs: c, fat: f),
      loggedAt: DateTime.now(),
      slot: widget.slot,
      source: LogSource.custom,
    );
    await widget.ref.read(todayMealsProvider.notifier).add([entry]);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(widget.slot.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  'Add to ${widget.slot.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Food name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gramsCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Grams',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _macroField(_proteinCtrl, 'Protein (g)')),
                const SizedBox(width: 8),
                Expanded(child: _macroField(_carbsCtrl, 'Carbs (g)')),
                const SizedBox(width: 8),
                Expanded(child: _macroField(_fatCtrl, 'Fat (g)')),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save entry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
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
/// Skeleton loader while data is hydrating. Shown instead of a centered spinner
/// so the screen layout doesn't shift when content arrives.
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: const [
        _SkeletonBlock(width: 80, height: 12),
        SizedBox(height: 8),
        _SkeletonBlock(width: 200, height: 28),
        SizedBox(height: 24),
        _SkeletonBlock(width: double.infinity, height: 280, radius: 140),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _SkeletonBlock(width: double.infinity, height: 60)),
            SizedBox(width: 8),
            Expanded(child: _SkeletonBlock(width: double.infinity, height: 60)),
            SizedBox(width: 8),
            Expanded(child: _SkeletonBlock(width: double.infinity, height: 60)),
          ],
        ),
        SizedBox(height: 28),
        _SkeletonBlock(width: 80, height: 20),
        SizedBox(height: 12),
        _SkeletonBlock(width: double.infinity, height: 90),
        SizedBox(height: 8),
        _SkeletonBlock(width: double.infinity, height: 90),
      ],
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 14,
  });
  final double width;
  final double height;
  final double radius;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.surfaceMuted, AppColors.divider, _ctrl.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.error,
    required this.onRetry,
  });
  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(message, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

UserProfile _defaultProfile() => UserProfile(
      id: 'me',
      sex: Sex.other,
      ageYears: 30,
      heightCm: 170,
      weightKg: 70,
      activity: ActivityLevel.moderate,
      goal: Goal.maintenance,
      useMetric: true,
    );
