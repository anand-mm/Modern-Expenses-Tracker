import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import 'dart:math';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spend Insights')),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          } else if (state is DashboardLoaded) {
            final currencyFormat = NumberFormat.currency(symbol: '₹');

            if (state.totalSpend == 0 && state.transactions.isEmpty) {
              return const Center(child: Text('No data available for insights.'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeekendComparisonCard(context, state, currencyFormat),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Spend by Category'),
                  const SizedBox(height: 16),
                  _buildCategoryCharts(context, state),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Daily Spend Trend'),
                  const SizedBox(height: 16),
                  _buildDailySpendChart(context, state),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildWeekendComparisonCard(BuildContext context, DashboardLoaded state, NumberFormat format) {
    double diff = state.currentWeekendSpend - state.previousWeekendSpend;
    double percentage = state.previousWeekendSpend == 0
        ? (state.currentWeekendSpend > 0 ? 100.0 : 0.0)
        : (diff / state.previousWeekendSpend) * 100;

    IconData icon = Icons.trending_flat;
    Color color = Colors.grey;
    String diffText = 'Same as previous weekend';

    if (diff > 0) {
      icon = Icons.trending_up;
      color = Colors.red;
      diffText = '+${percentage.toStringAsFixed(1)}% up from last weekend';
    } else if (diff < 0) {
      icon = Icons.trending_down;
      color = Colors.green;
      diffText = '${percentage.abs().toStringAsFixed(1)}% down from last weekend';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekend Spend',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(format.format(state.currentWeekendSpend), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diffText,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCharts(BuildContext context, DashboardLoaded state) {
    if (state.categorySpends.isEmpty) return const Text('No category data.');

    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.red, Colors.teal, Colors.amber];

    int colorIndex = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];

    state.categorySpends.forEach((category, amount) {
      final color = colors[colorIndex % colors.length];
      final percentage = (amount / state.totalSpend) * 100;

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(category, style: const TextStyle(fontSize: 14))),
              Text(
                NumberFormat.currency(symbol: '₹').format(amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      colorIndex++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(sections: sections, centerSpaceRadius: 50, sectionsSpace: 2)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        NumberFormat.compactCurrency(symbol: '₹').format(state.totalSpend),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...legendItems,
          ],
        ),
      ),
    );
  }

  Widget _buildDailySpendChart(BuildContext context, DashboardLoaded state) {
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
