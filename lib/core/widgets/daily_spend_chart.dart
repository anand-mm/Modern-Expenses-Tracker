import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../features/dashboard/bloc/dashboard_state.dart';

class DailySpendChart extends StatelessWidget {
  final DashboardLoaded state;

  const DailySpendChart({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.dailySpends.isEmpty) return const Text('No daily trend data.');

    List<FlSpot> spots = [];
    double maxX = max(1.0, state.dailySpends.length.toDouble() - 1);
    double maxY = 0;

    for (int i = 0; i < state.dailySpends.length; i++) {
      final amount = state.dailySpends[i].value;
      if (amount > maxY) maxY = amount;
      spots.add(FlSpot(i.toDouble(), amount));
    }

    if (spots.length == 1) {
      spots.add(FlSpot(1.0, spots.first.y));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < state.dailySpends.length) {
                        final date = state.dailySpends[index].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('d MMM').format(date), style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                    interval: max(1.0, (state.dailySpends.length / 5).ceil().toDouble()),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('');
                      return Text(NumberFormat.compact().format(value), style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
