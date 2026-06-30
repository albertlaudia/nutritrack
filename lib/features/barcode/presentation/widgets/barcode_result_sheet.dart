import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../camera/data/off_client.dart';
import '../../../dashboard/domain/food_log_entry.dart';

/// Bottom-sheet editor for a barcode-scanned product. Shows:
///   • Product name + brand + image (if available)
///   • Nutri-Score badge if present
///   • Allergen warnings if present
///   • Grams stepper (defaults to product's serving size)
///   • P / C / F / kcal for the chosen portion
///   • Meal slot picker
///   • Save button
class BarcodeResultSheet extends StatefulWidget {
  const BarcodeResultSheet({
    super.key,
    required this.product,
    required this.onSave,
    required this.onScanAnother,
    required this.scrollController,
  });

  final OffProduct product;
  final Future<void> Function({
    required OffProduct product,
    required double grams,
    required MealSlot slot,
  }) onSave;
  final VoidCallback onScanAnother;
  final ScrollController scrollController;

  @override
  State<BarcodeResultSheet> createState() => _BarcodeResultSheetState();
}

class _BarcodeResultSheetState extends State<BarcodeResultSheet> {
  late double _grams;
  late MealSlot _slot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.product.servingGrams ?? 100;
    _slot = _inferSlot();
  }

  MealSlot _inferSlot() {
    final h = DateTime.now().hour;
    if (h < 11) return MealSlot.breakfast;
    if (h < 15) return MealSlot.lunch;
    if (h < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  double get _ratio => _grams / 100.0;
  double get _protein => widget.product.per100g.protein * _ratio;
  double get _carbs => widget.product.per100g.carbs * _ratio;
  double get _fat => widget.product.per100g.fat * _ratio;
  double get _kcal => widget.product.per100g.calories * _ratio;

  void _bump(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _grams = (_grams + delta).clamp(1, 5000).toDouble());
  }

  void _commitText(String s) {
    final v = double.tryParse(s);
    if (v != null && v > 0) {
      setState(() => _grams = v);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        product: widget.product,
        grams: _grams,
        slot: _slot,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          _handle(),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                _productHeader(theme),
                if (widget.product.allergens.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _allergens(),
                ],
                const SizedBox(height: 20),
                _gramsSection(),
                const SizedBox(height: 20),
                _macroGrid(theme),
                const SizedBox(height: 20),
                _slotSection(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _saveButton(),
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

  Widget _productHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image (or placeholder)
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.product.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 200, // downsample — display is 80px @ 2.5x DPR
                    placeholder: (_, __) => const Center(
                      child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textTertiary, size: 28),
                    ),
                  )
                : const Center(
                    child: Text('\ud83e\udd57', style: TextStyle(fontSize: 36)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.product.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.product.brand!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (widget.product.nutriscore != null)
                      _NutriScoreBadge(grade: widget.product.nutriscore!),
                    if (widget.product.nutriscore != null)
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product.barcode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allergens() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
            size: 18, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contains: ${widget.product.allergens.take(4).join(", ")}'
              '${widget.product.allergens.length > 4 ? ", …" : ""}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gramsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Text('Portion',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          _stepBtn(Icons.remove_rounded, () => _bump(-10)),
          SizedBox(
            width: 96,
            child: TextFormField(
              key: ValueKey(_grams), // re-init when external bump happens
              initialValue: _grams.toStringAsFixed(0),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                suffixText: 'g',
                suffixStyle: TextStyle(
                  color: AppColors.textTertiary, fontWeight: FontWeight.w600,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16,
              ),
              onFieldSubmitted: _commitText,
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          _stepBtn(Icons.add_rounded, () => _bump(10)),
          if (widget.product.servingGrams != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _grams = widget.product.servingGrams!);
              },
              child: Text(
                '1 serving',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36, height: 36,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _macroGrid(ThemeData theme) {
    return Row(
      children: [
        _macroBox('P', _protein.toStringAsFixed(0), 'g', AppColors.lavender),
        const SizedBox(width: 8),
        _macroBox('C', _carbs.toStringAsFixed(0), 'g', AppColors.sky),
        const SizedBox(width: 8),
        _macroBox('F', _fat.toStringAsFixed(0), 'g', AppColors.rose),
        const SizedBox(width: 8),
        _macroBox('kcal', _kcal.round().toString(), '', AppColors.brand, big: true),
      ],
    );
  }

  Widget _macroBox(String label, String value, String unit, Color color,
      {bool big = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              '$value$unit',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: big ? 18 : 16,
                color: color,
              ),
            ),
            Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add to', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(
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
        ),
      ],
    );
  }

  Widget _saveButton() {
    final canSave = !_saving;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canSave ? widget.onScanAnother : null,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan another'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Log ${_kcal.round()} kcal'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                disabledBackgroundColor: AppColors.divider,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriScoreBadge extends StatelessWidget {
  const _NutriScoreBadge({required this.grade});
  final String grade;

  @override
  Widget build(BuildContext context) {
    final upper = grade.toUpperCase();
    final color = switch (upper) {
      'A' => const Color(0xFF038141),
      'B' => const Color(0xFF85BB2F),
      'C' => const Color(0xFFFECB02),
      'D' => const Color(0xFFEE8100),
      _ => const Color(0xFFE63E11),
    };
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        upper,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}