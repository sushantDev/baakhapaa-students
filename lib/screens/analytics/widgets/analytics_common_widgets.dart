import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GraphMetric {
  final String name;
  final double current;
  final double change;
  final Color color;

  GraphMetric(this.name, this.current, this.change, this.color);
}

class AnalyticsMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String percentage;
  final bool isPositive;
  final Color bgColor;
  final Color graphColor;

  const AnalyticsMetricCard({
    Key? key,
    required this.label,
    required this.value,
    required this.percentage,
    required this.isPositive,
    required this.bgColor,
    required this.graphColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    percentage,
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Simple mini graph placeholder
          SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(10, (index) {
                final height = 5.0 + (index * 2.0 % 20.0);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: height,
                    decoration: BoxDecoration(
                      color: graphColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsTabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final bool enabled;

  const AnalyticsTabChip({
    Key? key,
    required this.label,
    required this.isActive,
    this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: isActive
            ? BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? (isActive ? Colors.amber : Colors.grey)
                : Colors.grey[700],
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class ComparisonGraph extends StatelessWidget {
  final String title;
  final List<GraphMetric> metrics;
  final bool isLifetime;

  const ComparisonGraph({
    Key? key,
    required this.title,
    required this.metrics,
    this.isLifetime = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double maxVal = 0;
    for (var m in metrics) {
      double prev = isLifetime ? 0 : m.current / (1 + m.change / 100);
      if (prev.isInfinite || prev.isNaN) prev = 0;
      maxVal = math.max(maxVal, math.max(m.current, prev));
    }
    if (maxVal == 0) maxVal = 10;

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 20),
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final metric = metrics[groupIndex];
                      final labelText = isLifetime
                          ? 'Total'
                          : (rodIndex == 0 ? 'Current' : 'Previous');
                      return BarTooltipItem(
                        '${metric.name}\n$labelText: ${formatNumber(rod.toY.toInt())}',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= metrics.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            metrics[value.toInt()].name,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          formatNumber(value.toInt()),
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 9),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(metrics.length, (index) {
                  final m = metrics[index];
                  double prev =
                      isLifetime ? 0 : m.current / (1 + m.change / 100);
                  if (prev.isInfinite || prev.isNaN) prev = 0;

                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: m.current,
                        color: m.color,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.2,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      if (!isLifetime)
                        BarChartRodData(
                          toY: prev,
                          color: m.color.withOpacity(0.3),
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (!isLifetime)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildComparisonLegend('This Period', Colors.white),
                  const SizedBox(width: 20),
                  _buildComparisonLegend('Previous', Colors.white30),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonLegend(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class AnalyticsLegend extends StatelessWidget {
  final List<LegendItem> items;

  const AnalyticsLegend({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items
          .map((item) => Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class LegendItem {
  final Color color;
  final String label;
  LegendItem(this.color, this.label);
}

String formatNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toString();
}

int safeToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed ?? 0;
  }
  if (value is num) return value.toInt();
  return 0;
}
