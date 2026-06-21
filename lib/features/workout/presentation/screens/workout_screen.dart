import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncRepo = ref.watch(workoutRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
              onChanged: (q) => setState(() => _query = q),
              value: _query,
            )),
            SliverToBoxAdapter(child: _FilterRow(
              muscle: _muscle,
              equipment: _equipment,
              onMuscle: (m) => setState(() => _muscle = m),
              onEquipment: (e) => setState(() => _equipment = e),
            )),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Exercises', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ),
            ),
            FutureBuilder<List<Exercise>>(
              future: asyncRepo.then((r) => r.searchExercises(
                query: _query.isEmpty ? null : _query,
                primaryMuscle: _muscle,
                equipment: _equipment,
                limit: 50,
              )),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                final exercises = snap.data ?? [];
                if (exercises.isEmpty) {
                  return const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No exercises match your filters')),
                  ));
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ExerciseTile(exercise: exercises[i]),
                  ),
                );
              },
            ),
          ],
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
  const _SearchBar({required this.onChanged, required this.value});
  final ValueChanged<String> onChanged;
  final String value;
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
                controller: TextEditingController(text: value),
                decoration: const InputDecoration(
                  hintText: 'Search exercises…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
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
  const _ExerciseTile({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
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
              Icon(Icons.add, color: AppColors.brand, size: 20),
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
}