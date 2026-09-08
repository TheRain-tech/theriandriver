import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../shared/widgets/feature_templates.dart';

const _barBlue = Color(0xFF1565C0);
const _barBlueToday = Color(0xFF0D47A1);
const _barGrey = Color(0xFFE0E0E0);

/// Earnings bar chart for the Today / This Week / This Month views. Reads a
/// pre-bucketed list of totals (hourly/daily/weekly, matching [period]) from
/// DriverEarningRepository.getEarnings and renders it with fl_chart, so the
/// same chart works correctly for all three tabs instead of only "This Week".
class EarningsBarChart extends StatelessWidget {
  const EarningsBarChart({super.key, required this.period, required this.values});

  /// One of 'Daily', 'Weekly', 'Monthly'.
  final String period;

  /// Bucket totals: 8 two-hour buckets for Daily, 7 days for Weekly, 4 weeks
  /// for Monthly - length must match [_labels] for the given period.
  final List<double> values;

  List<String> get _labels => switch (period) {
    'Daily' => const [
      '6AM',
      '8AM',
      '10AM',
      '12PM',
      '2PM',
      '4PM',
      '6PM',
      '8PM',
    ],
    'Monthly' => const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
    _ => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };

  String get _emptyMessage => switch (period) {
    'Daily' => 'No earnings yet today',
    'Monthly' => 'No earnings this month yet',
    _ => 'No earnings this week yet',
  };

  @override
  Widget build(BuildContext context) {
    final hasData = values.any((v) => v > 0);
    final maxValue = values.fold(0.0, (max, v) => v > max ? v : max);
    final maxY = hasData ? maxValue * 1.25 : 4.0;
    final todayIndex = period == 'Weekly' ? DateTime.now().weekday - 1 : -1;
    final barWidth = values.length <= 4
        ? 26.0
        : values.length <= 7
        ? 20.0
        : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: Colors.white,
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labels[i],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        '${NumberFormat.compact().format(value)} XAF',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: hasData,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => _barBlueToday,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          '${CurrencyFormatter.format(values[groupIndex])} earned',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hasData ? values[i] : maxY * 0.12,
                          color: !hasData
                              ? _barGrey
                              : (i == todayIndex ? _barBlueToday : _barBlue),
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            ),
          ),
        ),
        if (!hasData) ...[
          const SizedBox(height: 12),
          _EmptyEarningsNotice(message: _emptyMessage),
        ],
      ],
    );
  }
}

class _EmptyEarningsNotice extends StatelessWidget {
  const _EmptyEarningsNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.grey.shade400,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Go online to start earning!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
