import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/biometric_entry.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sample data — in production this comes from WeightRepository
    final samples = _generateSampleWeights();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INSIGHTS', style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      )),
                      const SizedBox(height: 4),
                      Text('AI & Forecast', style: theme.textTheme.headlineMedium),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Log weight',
                  onPressed: () => _showLogWeightSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight progression card
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weight progression', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              '30-day moving average smooths daily noise',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${samples.last.weightKg.toStringAsFixed(1)} kg',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _WeightChart(samples: samples),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Adherence insights
            ..._sampleInsights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InsightCard(insight: i),
            )),
          ],
        ),
      ),
    );
  }

  List<WeightEntry> _generateSampleWeights() {
    final now = DateTime.now();
    final rng = math.Random(42);
    final base = 78.0;
    return List.generate(30, (i) {
      final day = now.subtract(Duration(days: 29 - i));
      // Trend down with daily noise
      final noise = (rng.nextDouble() - 0.5) * 0.6;
      final trend = -0.04 * i;
      return WeightEntry(
        id: '$i',
        recordedAt: day,
        weightKg: base + trend + noise,
      );
    });
  }

  List<AdherenceInsight> get _sampleInsights => [
    AdherenceInsight(
      id: '1',
      title: 'Protein timing pattern detected',
      body: 'When your protein intake before noon falls below 20% of your daily target, '
            'your reported evening cravings increase by 40%. Consider a protein-forward breakfast.',
      severity: InsightSeverity.warning,
      generatedAt: DateTime.now(),
      tags: ['protein', 'meal-timing'],
    ),
    AdherenceInsight(
      id: '2',
      title: 'You\'re crushing your fiber goal 🎉',
      body: 'Hit 30g+ fiber 5 days this week. This correlates with better sleep scores '
            'and steadier energy in the afternoon.',
      severity: InsightSeverity.positive,
      generatedAt: DateTime.now(),
      tags: ['fiber', 'energy'],
    ),
    AdherenceInsight(
      id: '3',
      title: 'Weekly deficit looks right',
      body: 'You\'re trending toward a -0.3 kg/wk loss — perfect for a moderate cut. '
            'To stay there, target ~1850 kcal/day average.',
      severity: InsightSeverity.info,
      generatedAt: DateTime.now(),
      tags: ['deficit', 'progress'],
    ),
  ];

  void _showLogWeightSheet(BuildContext context) {
    final weightCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
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
                Text('Log weight',
                  style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Adds to your 30-day moving average.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: wire to WeightRepository + nt_weight_entries.
                    // For now, close the sheet and confirm visually.
                    final w = double.tryParse(weightCtrl.text);
                    if (w == null || w <= 0 || w > 500) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a weight between 0 and 500 kg'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logged ${w.toStringAsFixed(1)} kg'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.samples});
  final List<WeightEntry> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < samples.length; i++) {
      spots.add(FlSpot(i.toDouble(), samples[i].weightKg));
    }

    // Moving average (7-day)
    final maSpots = <FlSpot>[];
    for (int i = 0; i < samples.length; i++) {
      final window = samples.sublist(
        math.max(0, i - 6),
        i + 1,
      );
      final avg = window.map((e) => e.weightKg).reduce((a, b) => a + b) / window.length;
      maSpots.add(FlSpot(i.toDouble(), avg));
    }

    return LineChart(
      LineChartData(
        minY: samples.map((e) => e.weightKg).reduce(math.min) - 1,
        maxY: samples.map((e) => e.weightKg).reduce(math.max) + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.divider,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final daysAgo = samples.length - 1 - value.toInt();
                if (daysAgo % 7 == 0) {
                  return Text(
                    '-${daysAgo}d',
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Daily weight (faint)
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.brand.withOpacity(0.25),
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          // Moving average (bold)
          LineChartBarData(
            spots: maSpots,
            isCurved: true,
            curveSmoothness: 0.4,
            color: AppColors.brand,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.brand.withOpacity(0.15),
                  AppColors.brand.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final AdherenceInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = _resolveStyle(insight.severity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.severity.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(insight.title, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight.body, style: theme.textTheme.bodyMedium),
          if (insight.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: insight.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#$t', style: theme.textTheme.bodySmall),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _resolveStyle(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.info:
        return (AppColors.sky, Icons.info_outline);
      case InsightSeverity.positive:
        return (AppColors.mint, Icons.check_circle_outline);
      case InsightSeverity.warning:
        return (AppColors.amber, Icons.warning_amber_outlined);
      case InsightSeverity.critical:
        return (AppColors.error, Icons.error_outline);
    }
  }
}