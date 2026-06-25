import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../dashboard/domain/food_log_entry.dart';
import '../../../dashboard/domain/macro_nutrients.dart';

/// Bottom-sheet editor shown after AI recognition. User can:
///   • Edit each item's grams
///   • Remove an item
///   • Pick the meal slot
///   • Re-take the photo
///   • Confirm and save
///
/// Stays editable until Confirm is tapped — nothing is written to storage
/// during review.
class CameraReviewSheet extends StatefulWidget {
  const CameraReviewSheet({
    super.key,
    required this.entries,
    required this.saving,
    required this.onConfirm,
    required this.onRetake,
    required this.scrollController,
  });

  final List<FoodLogEntry> entries;
  final bool saving;
  final ValueChanged<List<FoodLogEntry>> onConfirm;
  final VoidCallback onRetake;
  final ScrollController scrollController;

  @override
  State<CameraReviewSheet> createState() => _CameraReviewSheetState();
}

class _CameraReviewSheetState extends State<CameraReviewSheet> {
  late List<_EditableEntry> _items;
  late MealSlot _slot;

  @override
  void initState() {
    super.initState();
    _items = widget.entries.map(_EditableEntry.from).toList();
    _slot = _inferSlot();
  }

  MealSlot _inferSlot() {
    final h = DateTime.now().hour;
    if (h < 11) return MealSlot.breakfast;
    if (h < 15) return MealSlot.lunch;
    if (h < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  MacroNutrients get _totalMacros => _items.fold<MacroNutrients>(
        MacroNutrients.empty,
        (s, e) => s + e.entry.macros,
      );

  int get _totalCalories => _totalMacros.calories.round();

  void _updateGrams(int index, double grams) {
    setState(() {
      _items[index].updateGrams(grams);
    });
  }

  void _remove(int index) {
    HapticFeedback.lightImpact();
    setState(() => _items.removeAt(index));
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    final entries = _items
        .map((e) => e.entry.copyWith(
              slot: _slot,
              source: LogSource.cameraAI,
            ))
        .toList();
    widget.onConfirm(entries);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == _items.length) {
                  return const SizedBox(height: 80);
                }
                return _ReviewItemCard(
                  item: _items[i],
                  onGramsChanged: (g) => _updateGrams(i, g),
                  onRemove: () => _remove(i),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 80 * i),
                      duration: AppMotion.fast,
                    )
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      curve: AppMotion.emphasizedDecelerate,
                    );
              },
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _handle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                      size: 14, color: AppColors.mint),
                    const SizedBox(width: 4),
                    Text(
                      '${_items.length} detected',
                      style: const TextStyle(
                        color: AppColors.mint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.saving ? null : widget.onRetake,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-take'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_totalCalories',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'kcal total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _slotPicker(),
        ],
      ),
    );
  }

  Widget _slotPicker() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MealSlot.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = MealSlot.values[i];
          final selected = s == _slot;
          return Material(
            color: selected ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _slot = s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.brand : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  Widget _footer() {
    final canSave = _items.isNotEmpty && !widget.saving;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: canSave ? _confirm : null,
          icon: widget.saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: Text(widget.saving ? 'Saving…' : 'Save to $_totalCalories kcal'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            disabledBackgroundColor: AppColors.divider,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper that holds the original entry + a working copy of grams.
class _EditableEntry {
  _EditableEntry({required this.entry, required this.grams});
  factory _EditableEntry.from(FoodLogEntry e) =>
      _EditableEntry(entry: e, grams: e.grams);

  FoodLogEntry entry;
  double grams;

  /// Recompute macros proportionally when grams change. The recognition
  /// result stores macros-per-the-given-grams, so we scale linearly.
  void updateGrams(double newGrams) {
    final ratio = grams == 0 ? 1.0 : newGrams / grams;
    grams = newGrams;
    entry = entry.copyWith(
      grams: newGrams,
      macros: entry.macros.scale(ratio),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.onGramsChanged,
    required this.onRemove,
  });

  final _EditableEntry item;
  final ValueChanged<double> onGramsChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowConfidence = item.entry.confidence < 0.6;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lowConfidence
              ? AppColors.amber.withOpacity(0.5)
              : AppColors.divider,
          width: lowConfidence ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.entry.displayTitle,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lowConfidence) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.psychology_alt_outlined,
                              size: 12, color: AppColors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'Low confidence \u2014 please verify',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textTertiary),
                  onPressed: onRemove,
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // Grams stepper
                _GramsStepper(
                  value: item.grams.round(),
                  onChanged: onGramsChanged,
                ),
                const SizedBox(width: 16),
                // Macros breakdown
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroColumn('P',
                        '${item.entry.macros.protein.round()}',
                        AppColors.lavender),
                      _macroColumn('C',
                        '${item.entry.macros.carbs.round()}',
                        AppColors.sky),
                      _macroColumn('F',
                        '${item.entry.macros.fat.round()}',
                        AppColors.rose),
                      _macroColumn('kcal',
                        '${item.entry.macros.calories.round()}',
                        AppColors.textPrimary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// +/- stepper for grams, with tap-to-edit.
class _GramsStepper extends StatefulWidget {
  const _GramsStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<double> onChanged;

  @override
  State<_GramsStepper> createState() => _GramsStepperState();
}

class _GramsStepperState extends State<_GramsStepper> {
  late TextEditingController _ctrl;
  bool _editing = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant _GramsStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.value != oldWidget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String s) {
    final v = double.tryParse(s);
    if (v != null && v > 0) {
      widget.onChanged(v);
    } else {
      _ctrl.text = '${widget.value}';
    }
  }

  void _bump(int delta) {
    final next = (widget.value + delta).clamp(1, 5000);
    widget.onChanged(next.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(
            icon: Icons.remove_rounded,
            onTap: () => _bump(-10),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _editing = true);
              _focus.requestFocus();
              _ctrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _ctrl.text.length,
              );
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        suffixText: 'g',
                        suffixStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onSubmitted: (s) {
                        setState(() => _editing = false);
                        _commit(s);
                      },
                      onTapOutside: (_) {
                        setState(() => _editing = false);
                        _commit(_ctrl.text);
                      },
                    )
                  : Text(
                      '${widget.value}g',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          _step(
            icon: Icons.add_rounded,
            onTap: () => _bump(10),
          ),
        ],
      ),
    );
  }

  Widget _step({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}