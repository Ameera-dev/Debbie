import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../providers/weekly_budget_provider.dart';
import '../../../shared/widgets/tide.dart';

/// Line chart of weekly budget-plan performance % over the last 12 weeks.
/// Performance = (planned - actual) / planned * 100 — higher is better.
class PerformanceHistoryCard extends ConsumerWidget {
  const PerformanceHistoryCard({super.key, this.weeks = 12});

  final int weeks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(weeklyPerformanceHistoryProvider(weeks));

    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.show_chart_rounded,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly score over the last $weeks weeks. '
                      'Higher means you spent less than planned.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          pointsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Could not load history.\n$e',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.expense,
                      height: 1.4,
                    ),
              ),
            ),
            data: (points) => points.length < 2
                ? _EmptyState(weeks: weeks, hasOne: points.length == 1)
                : _PerformanceLineChart(points: points),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.weeks, required this.hasOne});

  final int weeks;
  final bool hasOne;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        hasOne
            ? 'Just one week so far. Actualize at least one more week to draw a trend.'
            : 'Actualize a few days each week and your trend will appear here.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
      ),
    );
  }
}

class _PerformanceLineChart extends StatelessWidget {
  const _PerformanceLineChart({required this.points});

  final List<WeeklyPerformancePoint> points;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final p in points) (p.performancePercent ?? 0).toDouble(),
    ];
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    // Always include 0 in the visible range so the user can see "broke even".
    final minY = math.min(rawMin, 0).floorToDouble() - 5;
    final maxY = math.max(rawMax, 0).ceilToDouble() + 5;

    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];

    final latest = points.last;
    final latestValue = latest.performancePercent ?? 0;
    final average =
        values.fold<double>(0, (s, v) => s + v) / values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Latest week',
                value: _formatPct(latestValue),
                helper: DateFormat('d MMM').format(latest.weekStart),
                color: _colorFor(latestValue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Average',
                value: _formatPct(average),
                helper: '${points.length} weeks tracked',
                color: AppColors.secondaryDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _niceInterval(maxY - minY),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: value == 0
                      ? AppColors.textSecondary.withValues(alpha: 0.4)
                      : AppColors.divider,
                  strokeWidth: value == 0 ? 1 : 0.6,
                  dashArray: value == 0 ? null : const [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: _niceInterval(maxY - minY),
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max || value == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${value.toInt()}%',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      // Show label on first, last, and every ~3rd in between
                      final isEdge = i == 0 || i == points.length - 1;
                      final stride = (points.length / 4).ceil();
                      if (!isEdge && i % stride != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d/M').format(points[i].weekStart),
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.textPrimary.withValues(alpha: 0.92),
                  getTooltipItems: (touched) => touched.map((spot) {
                    final p = points[spot.x.toInt()];
                    return LineTooltipItem(
                      '${_formatPct(spot.y)}\n',
                      GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: DateFormat('d MMM').format(p.weekStart),
                          style: GoogleFonts.nunito(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 3.5,
                      color: _colorFor(spot.y),
                      strokeColor: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap a point for details. Dashed lines mark percent intervals; the solid line is the break-even (0%) baseline.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
        ),
      ],
    );
  }

  static String _formatPct(double v) {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}%';
  }

  static Color _colorFor(double v) {
    if (v > 0) return AppColors.primary;
    if (v < 0) return AppColors.expense;
    return AppColors.textSoft;
  }

  static double _niceInterval(double range) {
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 50;
    return 100;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
