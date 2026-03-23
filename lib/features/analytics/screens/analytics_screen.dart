import 'package:expense_tracker/core/widgets/modern_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/widgets/daily_spend_chart.dart';

import '../../dashboard/bloc/dashboard_event.dart';

class AnalyticsScreen extends StatelessWidget {
  final VoidCallback? onViewTransactions;

  const AnalyticsScreen({super.key, this.onViewTransactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: const Text('Insights')),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          } else if (state is DashboardLoaded) {
            if (state.totalSpend == 0 && state.transactions.isEmpty) {
              return const Center(child: Text('No data available for insights.'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthOverMonthChart(context, state),
                  const SizedBox(height: 24),
                  _buildTopMerchantsCard(context, state, isByAmount: true),
                  const SizedBox(height: 24),
                  _buildTopMerchantsCard(context, state, isByAmount: false),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Spend by Category'),
                  const SizedBox(height: 16),
                  _buildCategoryCharts(context, state),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Daily Spend Trend'),
                  const SizedBox(height: 16),
                  DailySpendChart(state: state),
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

  Widget _buildTopMerchantsCard(BuildContext context, DashboardLoaded state, {bool isByAmount = true}) {
    final merchants = isByAmount ? state.topMerchants : state.topMerchantsByCount;
    if (merchants.isEmpty) {
      return const SizedBox.shrink();
    }

    final format = NumberFormat.currency(symbol: '₹');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isByAmount ? 'Top Merchants (Highest Spend)' : 'Most Visited Merchants',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...merchants.map((merchantData) {
              final merchantName = merchantData['merchant'] as String;
              final count = merchantData['count'] as int;
              final amount = merchantData['amount'] as double;

              return InkWell(
                onTap: () {
                  if (onViewTransactions != null) {
                    context.read<DashboardBloc>().add(ApplyTransactionFilters(merchant: merchantName));
                    onViewTransactions!();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.storefront, color: Colors.blue.shade600, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              merchantName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count transactions',
                              style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        format.format(amount),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              );
            }),
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

  Widget _buildMonthOverMonthChart(BuildContext context, DashboardLoaded state) {
    if (state.totalSpend == 0 && state.previousMonthSpend == 0) {
      return const SizedBox.shrink();
    }

    final format = NumberFormat.currency(symbol: '₹');
    final double diff = state.totalSpend - state.previousMonthSpend;
    final bool isIncrease = diff > 0;

    // Compute month names for axis (this month vs last month)
    final prevMonthDate = DateTime(state.selectedMonth.year, state.selectedMonth.month - 1, 1);
    final String prevMonthName = DateFormat('MMM').format(prevMonthDate);
    final String currMonthName = DateFormat('MMM').format(state.selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Budget Comparison'),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isIncrease ? Colors.red.shade50 : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncrease ? Icons.trending_up : Icons.trending_down,
                        color: isIncrease ? Colors.red.shade400 : Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isIncrease
                            ? 'You have spent ${format.format(diff.abs())} more this month compared to the same time last month'
                            : (diff == 0
                                  ? 'Your spending is exactly matching last month.'
                                  : 'Great job! You spent ${format.format(diff.abs())} less than this time last month'),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (state.totalSpend > state.previousMonthSpend ? state.totalSpend : state.previousMonthSpend) * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const style = TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 13);
                              final text = value.toInt() == 0 ? prevMonthName : currMonthName;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(text, style: style),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: state.previousMonthSpend,
                              color: Colors.blueGrey.shade200,
                              width: 32,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: state.totalSpend,
                              color: Colors.blue.shade400,
                              width: 32,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
