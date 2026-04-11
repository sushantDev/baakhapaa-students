import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PointLogTab extends StatefulWidget {
  final List<Map<String, dynamic>> pointLogs;
  final int currentBalance;

  const PointLogTab({
    Key? key,
    required this.pointLogs,
    required this.currentBalance,
  }) : super(key: key);

  @override
  State<PointLogTab> createState() => _PointLogTabState();
}

class _PointLogTabState extends State<PointLogTab> {
  final Set<int> _expandedItems = {};

  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showMonthlyDetails(String month, List<Map<String, dynamic>> logs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final monthLogs = logs.where((t) {
          try {
            final date = DateTime.parse(t['date'] ?? t['created_at'] ?? "");
            final transMonth = DateFormat('MMM\n\'yy').format(date);
            return transMonth == month;
          } catch (_) {
            return false;
          }
        }).toList();

        double totalEarned = monthLogs
            .where(
                (t) => (t['isPositive'] ?? t['status'] == 'credited') == true)
            .fold(0,
                (sum, t) => sum + (t['points'] ?? t['coin'] ?? 0).toDouble());
        double totalUsed = monthLogs
            .where(
                (t) => (t['isPositive'] ?? t['status'] == 'credited') == false)
            .fold(
                0,
                (sum, t) =>
                    sum + ((t['points'] ?? t['coin'] ?? 0).abs()).toDouble());

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Container(
            color: Colors.black, // Match theme
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Summary for ${month.replaceAll('\n', ' ')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                          'Earned', totalEarned, Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard('Used', totalUsed, Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Transactions (${monthLogs.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: monthLogs.length,
                    itemBuilder: (context, idx) {
                      final t = monthLogs[idx];
                      final bool isPositive = t.containsKey('isPositive')
                          ? t['isPositive']
                          : (t['status'] == 'credited');
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 0),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPositive
                                      ? Icons.add_circle
                                      : Icons.remove_circle,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['title'] ??
                                          t['remarks'] ??
                                          'Point Activity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(
                                          t['date'] ?? t['created_at'] ?? ""),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if ((t['notes'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          t['notes'],
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                (isPositive ? "+" : "-") +
                                    ((t['points'] ?? t['coin'] ?? 0)
                                        .abs()
                                        .toString()),
                                style: TextStyle(
                                  color: isPositive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.21)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineGraph(List<Map<String, dynamic>> logs) {
    Map<String, Map<String, double>> dailyTotals = {};
    for (var t in logs) {
      try {
        final date = DateTime.parse(t['date'] ?? t['created_at'] ?? "");
        final isPositive = t.containsKey('isPositive')
            ? t['isPositive']
            : (t['status'] == 'credited');
        final amount = (t['points'] ?? t['coin'] ?? 0).toDouble().abs();
        final dateLabel = DateFormat('MMM\n\'yy').format(date);

        dailyTotals[dateLabel] ??= {'credited': 0, 'debited': 0};

        if (isPositive) {
          dailyTotals[dateLabel]!['credited'] =
              (dailyTotals[dateLabel]!['credited'] ?? 0) + amount;
        } else {
          dailyTotals[dateLabel]!['debited'] =
              (dailyTotals[dateLabel]!['debited'] ?? 0) + amount;
        }
      } catch (_) {}
    }

    if (dailyTotals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
            child: Text("No activity to graph",
                style: TextStyle(color: Colors.grey))),
      );
    }

    double maxAmount = 0;
    for (var day in dailyTotals.values) {
      maxAmount =
          math.max(maxAmount, math.max(day['credited']!, day['debited']!));
    }
    if (maxAmount == 0) maxAmount = 10;

    return Container(
      height: 256,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text(
            'Monthly Coin Activity',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmount * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String type = rodIndex == 0 ? 'Earned' : 'Used';
                      return BarTooltipItem(
                        '$type: ${rod.toY.toStringAsFixed(1)} points',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final month = dailyTotals.keys
                          .elementAt(response!.spot!.touchedBarGroupIndex);
                      _showMonthlyDetails(month, widget.pointLogs);
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= dailyTotals.keys.length) {
                          return const SizedBox.shrink();
                        }
                        return Transform.rotate(
                          angle: -0.5,
                          child: SizedBox(
                            width: 54,
                            child: Text(
                              dailyTotals.keys.elementAt(value.toInt()),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[400]),
                              textAlign: TextAlign.center,
                            ),
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
                          value.toInt().toString(),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxAmount / 5,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey[800], strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[800]!),
                ),
                barGroups: List.generate(
                  dailyTotals.length,
                  (index) {
                    final date = dailyTotals.keys.elementAt(index);
                    final data = dailyTotals[date]!;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data['credited']!,
                          color: Colors.green,
                          width: 12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: data['debited']!,
                          color: Colors.red,
                          width: 12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Earned', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Used', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPointItem(Map<String, dynamic> log, int index) {
    final String title = log['title'] ?? 'Point Activity';
    final String dateStr = log['date'] ?? log['created_at'] ?? '';
    final int points = log['points'] ?? log['coin'] ?? 0;
    final bool isPositive = log.containsKey('isPositive')
        ? log['isPositive'] as bool
        : ((log['status'] == 'credited' || points >= 0));
    final bool isExpanded = _expandedItems.contains(index);
    final String transactionId = log['transactionId'] != null &&
            log['transactionId'].toString().isNotEmpty
        ? '#${log['transactionId']}'
        : 'N/A';
    final String remark = log['remarks'] ?? '';

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedItems.remove(index);
            } else {
              _expandedItems.add(index);
            }
          });
        },
        child: AnimatedSize(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPositive ? Icons.add_circle : Icons.remove_circle,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            maxLines: isExpanded ? null : 1,
                            overflow: isExpanded ? null : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(dateStr),
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isPositive ? "+" : "-"}${points.abs()}",
                          style: TextStyle(
                            color: isPositive
                                ? Colors.lightGreenAccent
                                : Colors.redAccent,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Bal: ${_calculateBalanceAtIndex(index)}",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const Divider(height: 17, color: Colors.white10),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDetailRow("Transaction ID", transactionId),
                        if (remark.isNotEmpty) _buildDetailRow("Title", remark),
                        _buildDetailRow("Created at", _formatDate(dateStr)),
                        _buildDetailRow("Status", title),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pointLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36.0),
          child: Text(
            "No point log found.",
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ),
      );
    }

    List<Map<String, dynamic>> logs = widget.pointLogs;

    return Column(
      children: [
        _buildLineGraph(logs),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) =>
                _buildPointItem(logs[index], index),
          ),
        ),
      ],
    );
  }

  int _calculateBalanceAtIndex(int index) {
    int balance = widget.currentBalance;
    for (int i = 0; i < index; i++) {
      final log = widget.pointLogs[i];
      final dynamic pointValue = log['points'] ?? log['coin'] ?? 0;
      final int p = pointValue is num
          ? pointValue.toInt()
          : (int.tryParse(pointValue.toString()) ?? 0);
      final isPos = log.containsKey('isPositive')
          ? log['isPositive'] as bool
          : ((log['status'] == 'credited' || p >= 0));

      if (isPos) {
        balance -= p.abs();
      } else {
        balance += p.abs();
      }
    }
    return balance;
  }
}
