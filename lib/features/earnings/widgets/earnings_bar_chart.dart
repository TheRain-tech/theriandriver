import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/driver_copy.dart';
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

  List<String> _labelsFor(DriverCopy copy) => switch (period) {
    'Daily' => copy.isFrench
        ? const ['6h', '8h', '10h', '12h', '14h', '16h', '18h', '20h']
        : const ['6AM', '8AM', '10AM', '12PM', '2PM', '4PM', '6PM', '8PM'],
    'Monthly' => copy.isFrench
        ? const ['Semaine 1', 'Semaine 2', 'Semaine 3', 'Semaine 4']
        : const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
    _ => copy.isFrench
        ? const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };

  String _emptyMessageFor(DriverCopy copy) => switch (period) {
    'Daily' => copy.t('No earnings yet today', "Pas encore de revenus aujourd'hui"),
    'Monthly' => copy.t(
      'No earnings this month yet',
      'Pas encore de revenus ce mois-ci',
    ),
    _ => copy.t(
      'No earnings this week yet',
      'Pas encore de revenus cette semaine',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final labels = _labelsFor(copy);
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
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
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
                          copy.t(
                            '${CurrencyFormatter.format(values[groupIndex])} earned',
                            '${CurrencyFormatter.format(values[groupIndex])} gagnés',
                          ),
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
          _EmptyEarningsNotice(message: _emptyMessageFor(copy)),
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
    final copy = DriverCopy.of(context);
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
            copy.t(
              'Go online to start earning!',
              "Passez en ligne pour commencer à gagner de l'argent !",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
