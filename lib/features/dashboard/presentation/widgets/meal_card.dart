import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    this.onDeleteEntry,
    this.onFavoriteEntry,
  });

  final MealSlot slot;
  final List<FoodLogEntry> entries;
  final VoidCallback? onAdd;
  final ValueChanged<FoodLogEntry>? onTapEntry;
  final ValueChanged<String>? onDeleteEntry;
  final ValueChanged<FoodLogEntry>? onFavoriteEntry;

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
                  (e) => _SwipeableEntry(
                    key: ValueKey(e.value.id),
                    entry: e.value,
                    onTap: onTapEntry == null ? null : () => onTapEntry!(e.value),
                    onDelete: onDeleteEntry == null ? null : () => onDeleteEntry!(e.value.id),
                    onFavorite: onFavoriteEntry == null ? null : () => onFavoriteEntry!(e.value),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 80 * e.key),
                        duration: AppMotion.fast,
                      ).slideY(begin: 0.05, end: 0, curve: AppMotion.emphasizedDecelerate),
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

/// Swipe left to delete, swipe right to toggle favorite.
class _SwipeableEntry extends StatelessWidget {
  const _SwipeableEntry({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
    this.onFavorite,
  });

  final FoodLogEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('entry_${entry.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.45,
        DismissDirection.startToEnd: 0.45,
      },
      movementDuration: AppMotion.normal,
      resizeDuration: AppMotion.normal,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.endToStart) {
          // Swipe LEFT = delete
          await Future<void>.delayed(const Duration(milliseconds: 200));
          onDelete?.call();
          return true;
        } else {
          // Swipe RIGHT = toggle favorite
          HapticFeedback.lightImpact();
          onFavorite?.call();
          return false; // don't actually dismiss for favorite
        }
      },
      background: _SwipeBg(
        alignment: Alignment.centerLeft,
        color: AppColors.success,
        icon: entry.isFavorite ? Icons.star : Icons.star_border_rounded,
        label: entry.isFavorite ? 'Unfav' : 'Favorite',
        paddingStart: 24,
      ),
      secondaryBackground: const _SwipeBg(
        alignment: Alignment.centerRight,
        color: AppColors.error,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        paddingStart: 24,
      ),
      child: _EntryRow(entry: entry, onTap: onTap),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    required this.paddingStart,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  final double paddingStart;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.only(left: isLeft ? paddingStart : 0, right: isLeft ? 0 : paddingStart),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}