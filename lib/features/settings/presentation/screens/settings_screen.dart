import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/core_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            Text('CALIBRATION', style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            )),
            const SizedBox(height: 4),
            Text('Biomarkers', style: theme.textTheme.headlineMedium),

            const SizedBox(height: 28),

            // TDEE summary card
            _SummaryCard(profile: profile),

            const SizedBox(height: 24),

            // TDEE wizard
            Text('Recalibrate', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _WizardStepper(
              currentStep: _step,
              onStep: (s) => setState(() => _step = s),
              profile: profile,
            ),

            const SizedBox(height: 24),

            // Macro target preview
            Text('Macro targets', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _MacroTargetPreview(profile: profile),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.goal.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${profile.targetKcal.round()}',
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'kcal / day',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryMetric(label: 'BMR', value: '${profile.bmr.round()}'),
              _SummaryMetric(label: 'TDEE', value: '${profile.tdee.round()}'),
              _SummaryMetric(label: 'Offset', value: '${profile.goal.kcalOffset > 0 ? '+' : ''}${profile.goal.kcalOffset.round()}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WizardStepper extends ConsumerStatefulWidget {
  const _WizardStepper({
    required this.currentStep,
    required this.onStep,
    required this.profile,
  });
  final int currentStep;
  final ValueChanged<int> onStep;
  final UserProfile profile;

  @override
  ConsumerState<_WizardStepper> createState() => _WizardStepperState();
}

class _WizardStepperState extends ConsumerState<_WizardStepper> {
  late Sex _sex;
  late int _age;
  late double _height;
  late double _weight;
  late ActivityLevel _activity;
  late Goal _goal;

  static const _steps = ['Sex', 'Age', 'Body', 'Activity', 'Goal', 'Review'];

  @override
  void initState() {
    super.initState();
    _sex = widget.profile.sex;
    _age = widget.profile.ageYears;
    _height = widget.profile.heightCm;
    _weight = widget.profile.weightKg;
    _activity = widget.profile.activity;
    _goal = widget.profile.goal;
  }

  void _apply() {
    final updated = widget.profile.copyWith(
      sex: _sex,
      ageYears: _age,
      heightCm: _height,
      weightKg: _weight,
      activity: _activity,
      goal: _goal,
    );
    ref.read(userProfileControllerProvider.notifier).update(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated — targets recalculated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = UserProfile(
      id: 'me',
      sex: _sex, ageYears: _age, heightCm: _height, weightKg: _weight,
      activity: _activity, goal: _goal,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step indicator
          Row(
            children: List.generate(_steps.length, (i) {
              final done = i < widget.currentStep;
              final active = i == widget.currentStep;
              final color = done
                  ? AppColors.success
                  : active
                      ? AppColors.brand
                      : AppColors.divider;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text(
            _steps[widget.currentStep],
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Step content
          switch (widget.currentStep) {
            0 => _StepSex(value: _sex, onChanged: (v) => setState(() => _sex = v)),
            1 => _StepAge(value: _age, onChanged: (v) => setState(() => _age = v)),
            2 => _StepBody(height: _height, weight: _weight,
                onHeight: (v) => setState(() => _height = v),
                onWeight: (v) => setState(() => _weight = v)),
            3 => _StepActivity(value: _activity, onChanged: (v) => setState(() => _activity = v)),
            4 => _StepGoal(value: _goal, onChanged: (v) => setState(() => _goal = v)),
            5 => _StepReview(preview: preview),
            _ => const SizedBox.shrink(),
          },

          const SizedBox(height: 24),

          // Nav buttons
          Row(
            children: [
              if (widget.currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onStep(widget.currentStep - 1),
                    child: const Text('Back'),
                  ),
                ),
              if (widget.currentStep > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (widget.currentStep < _steps.length - 1) {
                      widget.onStep(widget.currentStep + 1);
                    } else {
                      _apply();
                    }
                  },
                  child: Text(widget.currentStep == _steps.length - 1 ? 'Save profile' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepSex extends StatelessWidget {
  const _StepSex({required this.value, required this.onChanged});
  final Sex value;
  final ValueChanged<Sex> onChanged;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: Sex.values.map((s) {
        final selected = s == value;
        return ChoiceChip(
          label: Text(s.name),
          selected: selected,
          onSelected: (_) => onChanged(s),
          selectedColor: AppColors.brandSoft,
          labelStyle: TextStyle(
            color: selected ? AppColors.brand : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}

class _StepAge extends StatelessWidget {
  const _StepAge({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(width: 12),
        const Text('years old'),
        Expanded(
          child: Slider(
            min: 14, max: 90, divisions: 76,
            value: value.toDouble(),
            onChanged: (v) => onChanged(v.round()),
            activeColor: AppColors.brand,
          ),
        ),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.height,
    required this.weight,
    required this.onHeight,
    required this.onWeight,
  });
  final double height;
  final double weight;
  final ValueChanged<double> onHeight;
  final ValueChanged<double> onWeight;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('Height'),
            const SizedBox(width: 8),
            Text('${height.round()} cm', style: const TextStyle(fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                min: 140, max: 220, divisions: 80,
                value: height,
                onChanged: onHeight,
                activeColor: AppColors.brand,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Weight'),
            const SizedBox(width: 8),
            Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                min: 35, max: 200, divisions: 165,
                value: weight,
                onChanged: onWeight,
                activeColor: AppColors.brand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepActivity extends StatelessWidget {
  const _StepActivity({required this.value, required this.onChanged});
  final ActivityLevel value;
  final ValueChanged<ActivityLevel> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: ActivityLevel.values.map((a) {
        final selected = a == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? AppColors.brandSoft : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(a),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppColors.brand : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? AppColors.brand : AppColors.textTertiary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('×${a.multiplier.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepGoal extends StatelessWidget {
  const _StepGoal({required this.value, required this.onChanged});
  final Goal value;
  final ValueChanged<Goal> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: Goal.values.map((g) {
        final selected = g == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? AppColors.brandSoft : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(g),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppColors.brand : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.brand : AppColors.textTertiary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(g.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      '${g.kcalOffset > 0 ? '+' : ''}${g.kcalOffset.round()} kcal',
                      style: TextStyle(color: g.kcalOffset >= 0 ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepReview extends StatelessWidget {
  const _StepReview({required this.preview});
  final UserProfile preview;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macros = preview.targetMacros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(theme, 'BMR', '${preview.bmr.round()} kcal'),
        _row(theme, 'TDEE', '${preview.tdee.round()} kcal'),
        _row(theme, 'Target', '${preview.targetKcal.round()} kcal'),
        _row(theme, 'Protein', '${macros.protein.round()} g'),
        _row(theme, 'Carbs', '${macros.carbs.round()} g'),
        _row(theme, 'Fat', '${macros.fat.round()} g'),
      ],
    );
  }

  Widget _row(ThemeData t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.textTheme.bodyMedium)),
          Text(value, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MacroTargetPreview extends StatelessWidget {
  const _MacroTargetPreview({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macros = profile.targetMacros;
    final totalKcal = macros.calories;
    Widget macroBar(String label, double grams, Color color) {
      final kcal = label == 'Fat' ? grams * 9 : grams * 4;
      final pct = totalKcal == 0 ? 0 : (kcal / totalKcal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Text('${grams.round()} g · ${(pct * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          macroBar('Protein', macros.protein, AppColors.lavender),
          macroBar('Carbs', macros.carbs, AppColors.sky),
          macroBar('Fat', macros.fat, AppColors.rose),
        ],
      ),
    );
  }
}