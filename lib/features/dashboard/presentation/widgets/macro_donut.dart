import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/macro_nutrients.dart';

/// Multi-layer nutrition donut.
///
/// Three concentric rings:
///   • Outer — Calories (filled by consumed/target)
///   • Middle — Macros (protein | carbs | fat arcs)
///   • Inner — Center display (kcal + remaining)
class MacroDonut extends StatefulWidget {
  const MacroDonut({
    super.key,
    required this.consumed,
    required this.target,
    required this.macros,
    required this.targetMacros,
    this.size = 280,
  });

  final double consumed;
  final double target;
  final MacroNutrients macros;
  final MacroNutrients targetMacros;
  final double size;

  @override
  State<MacroDonut> createState() => _MacroDonutState();
}

class _MacroDonutState extends State<MacroDonut> with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _progress;
  double _prevConsumed = 0;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: AppMotion.slower);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _progress = Tween<double>(
      begin: 0,
      end: widget.target == 0 ? 0 : widget.consumed / widget.target,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: AppMotion.emphasized));
    _progressCtrl.forward();
  }

  @override
  void didUpdateWidget(MacroDonut old) {
    super.didUpdateWidget(old);
    if (old.consumed != widget.consumed) {
      _prevConsumed = _progress.value;
      _progress = Tween<double>(
        begin: _prevConsumed,
        end: widget.target == 0 ? 0 : (widget.consumed / widget.target).clamp(0, 1.5),
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: AppMotion.emphasized));
      _progressCtrl.reset()..forward();
      if (widget.consumed > widget.target && old.consumed <= widget.target) {
        _pulseCtrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_progress, _pulseCtrl]),
        builder: (context, _) {
          final p = _progress.value.clamp(0.0, 1.0);
          final overshoot = _progress.value > 1.0;
          final pulse = overshoot ? 1.0 + math.sin(_pulseCtrl.value * math.pi * 2) * 0.025 : 1.0;

          return Transform.scale(
            scale: pulse,
            child: CustomPaint(
              painter: _DonutPainter(
                progress: p,
                macros: widget.macros,
                targetMacros: widget.targetMacros,
                overshoot: overshoot,
              ),
              child: Center(
                child: _CenterReadout(
                  consumed: widget.consumed,
                  target: widget.target,
                  overshoot: overshoot,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.macros,
    required this.targetMacros,
    required this.overshoot,
  });

  final double progress;
  final MacroNutrients macros;
  final MacroNutrients targetMacros;
  final bool overshoot;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    final middleR = outerR - 22;
    final innerR = middleR - 22;

    // ── Outer ring — calories ──────────────────────────────────
    final trackOuter = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerR, trackOuter);

    final fillOuter = Paint()
      ..shader = AppColors.brandGradient.createShader(Rect.fromCircle(center: center, radius: outerR))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillOuter,
    );

    // ── Middle ring — macros (3 arcs) ──────────────────────────
    final totalTargetMacros = targetMacros.protein + targetMacros.carbs + targetMacros.fat;
    if (totalTargetMacros == 0) return;

    final consumedProtein = (macros.protein / targetMacros.protein).clamp(0.0, 1.0);
    final consumedCarbs = (macros.carbs / targetMacros.carbs).clamp(0.0, 1.0);
    final consumedFat = (macros.fat / targetMacros.fat).clamp(0.0, 1.0);

    final proteinSpan = 2 * math.pi * (targetMacros.protein / totalTargetMacros);
    final carbsSpan = 2 * math.pi * (targetMacros.carbs / totalTargetMacros);
    final fatSpan = 2 * math.pi * (targetMacros.fat / totalTargetMacros);

    double cursor = -math.pi / 2;

    _paintMacroArc(canvas, center, middleR, cursor, proteinSpan, consumedProtein, AppColors.lavender);
    cursor += proteinSpan;
    _paintMacroArc(canvas, center, middleR, cursor, carbsSpan, consumedCarbs, AppColors.sky);
    cursor += carbsSpan;
    _paintMacroArc(canvas, center, middleR, cursor, fatSpan, consumedFat, AppColors.rose);

    // ── Inner ring — subtle band ───────────────────────────────
    final innerPaint = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerR, innerPaint);
  }

  void _paintMacroArc(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double maxSpan,
    double fillRatio,
    Color color,
  ) {
    final track = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      maxSpan,
      false,
      track,
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      maxSpan * fillRatio,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.macros.protein != macros.protein ||
      old.macros.carbs != macros.carbs ||
      old.macros.fat != macros.fat;
}

class _CenterReadout extends StatelessWidget {
  const _CenterReadout({
    required this.consumed,
    required this.target,
    required this.overshoot,
  });
  final double consumed;
  final double target;
  final bool overshoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (target - consumed).clamp(0, target).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'REMAINING',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          remaining.round().toString(),
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: overshoot ? AppColors.warning : AppColors.textPrimary,
          ),
        ),
        Text(
          overshoot ? 'over goal' : 'kcal',
          style: theme.textTheme.bodySmall?.copyWith(
            color: overshoot ? AppColors.warning : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${consumed.round()} / ${target.round()}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}