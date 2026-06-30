import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../domain/workout_models.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  String _query = '';
  MuscleGroup? _muscle;
  Equipment? _equipment;
  final _searchCtrl = TextEditingController();
  late Future<List<Exercise>> _exercisesFuture;

  @override
  void initState() {
    super.initState();
    _exercisesFuture = _loadExercises();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Exercise>> _loadExercises() async {
    final repo = await ref.read(workoutRepositoryProvider.future);
    return repo.searchExercises(
      query: _query.isEmpty ? null : _query,
      primaryMuscle: _muscle,
      equipment: _equipment,
      limit: 50,
    );
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    setState(() => _exercisesFuture = _loadExercises());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            _refresh();
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WORKOUT', style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      )),
                      const SizedBox(height: 4),
                      Text('Smart Builder', style: theme.textTheme.headlineMedium),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _SearchBar(
                controller: _searchCtrl,
                onChanged: (q) {
                  setState(() => _query = q);
                  _refresh();
                },
              )),
              SliverToBoxAdapter(child: _FilterRow(
                muscle: _muscle,
                equipment: _equipment,
                onMuscle: (m) {
                  setState(() => _muscle = m);
                  _refresh();
                },
                onEquipment: (e) {
                  setState(() => _equipment = e);
                  _refresh();
                },
              )),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Exercises', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ),
              ),
              FutureBuilder<List<Exercise>>(
                future: _exercisesFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const _WorkoutListSkeleton();
                  }
                  final exercises = snap.data ?? [];
                  if (exercises.isEmpty) {
                    return SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded,
                              size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text('No exercises match your filters',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList.separated(
                      itemCount: exercises.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ExerciseTile(
                        key: ValueKey(exercises[i].id),
                        exercise: exercises[i],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startSession(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start session'),
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    final ctrl = TextEditingController(text: 'Push Day');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start workout'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Session name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'Workout' : ctrl.text.trim()),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (name == null) return;
    final repo = await ref.read(workoutRepositoryProvider.future);
    await repo.startSession(name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Started "$name"')));
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                controller: controller,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search exercises…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            // Subscribe to controller so the X button appears/disappears as
            // the user types. Reading controller.text directly in build() is
            // a stale-value bug — this rebuilds whenever the text changes.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: Icon(Icons.close,
                        color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.muscle,
    required this.equipment,
    required this.onMuscle,
    required this.onEquipment,
  });

  final MuscleGroup? muscle;
  final Equipment? equipment;
  final ValueChanged<MuscleGroup?> onMuscle;
  final ValueChanged<Equipment?> onEquipment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterChip(
            label: 'All',
            selected: muscle == null,
            onTap: () => onMuscle(null),
          ),
          ...MuscleGroup.values.map((m) => _FilterChip(
            label: m.label,
            selected: muscle == m,
            onTap: () => onMuscle(m == muscle ? null : m),
          )),
          const SizedBox(width: 12),
          Container(width: 1, color: AppColors.divider, margin: const EdgeInsets.symmetric(vertical: 12)),
          const SizedBox(width: 12),
          ...Equipment.values.map((e) => _FilterChip(
            label: e.label,
            selected: equipment == e,
            onTap: () => onEquipment(e == equipment ? null : e),
          )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.brand : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.brand : AppColors.divider),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _muscleEmoji(exercise.primaryMuscle),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.primaryMuscle.label} · ${exercise.equipment.label} · ${exercise.difficulty.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: AppColors.brand, size: 28),
                tooltip: 'Add to workout',
                onPressed: onAdd ?? () => _showDetail(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _muscleEmoji(MuscleGroup m) {
    switch (m) {
      case MuscleGroup.chest: return '💪';
      case MuscleGroup.back: return '🏋️';
      case MuscleGroup.shoulders: return '🤸';
      case MuscleGroup.arms: return '💪';
      case MuscleGroup.legs: return '🦵';
      case MuscleGroup.glutes: return '🍑';
      case MuscleGroup.core: return '🧘';
      case MuscleGroup.cardio: return '🏃';
      case MuscleGroup.fullBody: return '🏋️';
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseDetailSheet(exercise: exercise),
    );
  }
}

/// Detail sheet for an exercise — instructions, sets/reps suggestion,
/// quick-add to today's workout session.
class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(_muscleEmojiFor(exercise.primaryMuscle),
                    style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _metaChip(exercise.primaryMuscle.label),
                            _metaChip(exercise.equipment.label),
                            _metaChip(exercise.difficulty.label),
                            if (exercise.caloriesPerHour > 0)
                              _metaChip('~${exercise.caloriesPerHour} kcal/hr'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (exercise.secondaryMuscles.isNotEmpty) ...[
                Text('Secondary muscles',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: exercise.secondaryMuscles
                      .map((m) => _metaChip(m.label))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
              Text('Instructions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
              const SizedBox(height: 8),
              Text(
                exercise.instructions?.isNotEmpty == true
                    ? exercise.instructions!
                    : 'No instructions yet. Tap "Add to workout" to start logging sets.',
                style: theme.textTheme.bodyMedium,
              ),
              if (exercise.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  children: exercise.tags.map((t) => Chip(
                    label: Text('#$t', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: wire to active workout session once
                        // workout logging UI exists (Tier 2 work).
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${exercise.name} queued for your next session'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Add to workout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFF6B35),
      )),
    );
  }

  String _muscleEmojiFor(MuscleGroup m) {
    switch (m) {
      case MuscleGroup.chest: return '💪';
      case MuscleGroup.back: return '🏋️';
      case MuscleGroup.shoulders: return '🤸';
      case MuscleGroup.arms: return '💪';
      case MuscleGroup.legs: return '🦵';
      case MuscleGroup.glutes: return '🍑';
      case MuscleGroup.core: return '🧘';
      case MuscleGroup.cardio: return '🏃';
      case MuscleGroup.fullBody: return '🏋️';
    }
  }
}
/// Skeleton loader for the exercise list. Same shape as a real tile
/// (icon + 2-line text + trailing action) so the layout doesn't jump when
/// results arrive.
class _WorkoutListSkeleton extends StatefulWidget {
  const _WorkoutListSkeleton();
  @override
  State<_WorkoutListSkeleton> createState() => _WorkoutListSkeletonState();
}

class _WorkoutListSkeletonState extends State<_WorkoutListSkeleton>
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
    final base = AppColors.surfaceMuted;
    final high = AppColors.divider;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList.builder(
        itemCount: 6,
        itemBuilder: (_, i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Color.lerp(base, high, _ctrl.value),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color.lerp(base, high, _ctrl.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 180,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color.lerp(base, high, _ctrl.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Color.lerp(base, high, _ctrl.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
