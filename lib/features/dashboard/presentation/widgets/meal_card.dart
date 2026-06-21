import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/food_log_entry.dart';
import '../../domain/macro_nutrients.dart';

/// Per-meal section in the timeline. Header + sparkline of macros + item list.
class MealTimelineCard extends StatelessWidget {
  const MealTimelineCard({
    super.key,
    required this.slot,
    required this.entries,
    this.onAdd,
    this.onTapEntry,
  });

  final MealSlot slot;
  final List<FoodLogEntry> entries;
  final VoidCallback? onAdd;
  final ValueChanged<FoodLogEntry>? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCals = entries.fold<double>(0, (s, e) => s + e.macros.calories);
    final totalMacros = entries.fold<MacroNutrients>(
      MacroNutrients.empty,
      (s, e) => s + e.macros,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Text(slot.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.label, style: theme.textTheme.titleMedium),
                      Text(
                        entries.isEmpty
                            ? 'Tap + to log'
                            : '${entries.length} item${entries.length == 1 ? '' : 's'} · ${totalCals.round()} kcal',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (entries.isNotEmpty)
                  _MealMacroBars(macros: totalMacros)
                      .animate()
                      .fadeIn(duration: AppMotion.normal)
                      .slideX(begin: 0.1, end: 0),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: AppColors.brand),
                  tooltip: 'Add to ${slot.label}',
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty)
            ...entries.asMap().entries.map(
                  (e) => _EntryRow(
                    entry: e.value,
                    onTap: onTapEntry == null ? null : () => onTapEntry!(e.value),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 80 * e.key),
                        duration: AppMotion.fast,
                      ),
                ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, this.onTap});
  final FoodLogEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (entry.imagePath != null && File(entry.imagePath!).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(entry.imagePath!),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🍽️', style: TextStyle(fontSize: 18)),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.grams.round()}g · '
                      'P${entry.macros.protein.round()} '
                      'C${entry.macros.carbs.round()} '
                      'F${entry.macros.fat.round()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.macros.calories.round().toString(),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text('kcal', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealMacroBars extends StatelessWidget {
  const _MealMacroBars({required this.macros});
  final MacroNutrients macros;

  @override
  Widget build(BuildContext context) {
    final total = (macros.protein * 4 + macros.carbs * 4 + macros.fat * 9).clamp(1, double.infinity);
    return SizedBox(
      width: 80,
      height: 28,
      child: Row(
        children: [
          Expanded(
            flex: (macros.protein * 4 / total * 1000).round().clamp(1, 10000),
            child: Container(color: AppColors.lavender),
          ),
          Expanded(
            flex: (macros.carbs * 4 / total * 1000).round().clamp(1, 10000),
            child: Container(color: AppColors.sky),
          ),
          Expanded(
            flex: (macros.fat * 9 / total * 1000).round().clamp(1, 10000),
            child: Container(color: AppColors.rose),
          ),
        ],
      ),
    );
  }
}