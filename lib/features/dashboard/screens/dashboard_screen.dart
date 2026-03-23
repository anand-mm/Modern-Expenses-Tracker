import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../../../core/widgets/transaction_list_item.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewAll;

  const DashboardScreen({super.key, this.onViewAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(AppOpened());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          } else if (state is DashboardLoaded) {
            final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹');

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildModernHeader(context, state, currencyFormat),
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  if (state.transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No transactions for this month.')),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Transactions',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (widget.onViewAll != null)
                                TextButton(
                                  onPressed: widget.onViewAll,
                                  child: const Text('View All'),
                                ),
                            ],
                          ),
                        ),
                        ...state.transactions.take(5).map((t) {
                          final isTopMerchantTxn = state.topMerchants.any((m) => m['merchant'] == t.merchant);
                          return TransactionListItem(
                            transaction: t,
                            isMostUsedMerchantTxn: isTopMerchantTxn,
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, DashboardLoaded state) {
    if (state.totalSpend == 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricCard(title: 'Today', amount: state.todaySpend),
        const SizedBox(width: 8),
        _buildMetricCard(
          title: 'vs\nYesterday', 
          amount: state.previousDaySpend, 
          isComparison: true, 
          diff: state.todaySpend - state.previousDaySpend
        ),
        const SizedBox(width: 8),
        _buildMetricCard(title: 'This week', amount: state.currentWeekSpend),
      ],
    );
  }

  Widget _buildMetricCard({required String title, required double amount, bool isComparison = false, double diff = 0}) {
    final formatExact = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isDown = diff <= 0;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235), // Dark sleek color mapped from user image
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFF8B92A5), fontSize: 13, height: 1.3, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (isComparison)
               Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                   Icon(isDown ? Icons.arrow_downward : Icons.arrow_upward, 
                       color: isDown ? const Color(0xFFE87A76) : Colors.red, size: 14),
                   const SizedBox(width: 4),
                   Expanded(
                     child: Text(
                       formatExact.format(amount),
                       style: const TextStyle(color: Color(0xFFE87A76), fontSize: 16, fontWeight: FontWeight.bold),
                       overflow: TextOverflow.ellipsis,
                     ),
                   )
                 ],
               )
            else
              Text(
                formatExact.format(amount),
                style: const TextStyle(color: Color(0xFFE87A76), fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    DashboardLoaded state,
    NumberFormat format,
  ) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final cardMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month, 1);
    final showTodayInsights = cardMonth == currentMonth;

    final DateFormat monthFormat = DateFormat('MMMM yyyy');
    final isCurrentMonth = state.selectedMonth.year == currentMonth.year && state.selectedMonth.month == currentMonth.month;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Tracker',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () {
                  final newMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month - 1, 1);
                  context.read<DashboardBloc>().add(ChangeMonth(month: newMonth));
                },
              ),
              Text(
                monthFormat.format(state.selectedMonth),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isCurrentMonth ? Colors.white24 : Colors.white70),
                onPressed: isCurrentMonth
                    ? null
                    : () {
                        final newMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month + 1, 1);
                        context.read<DashboardBloc>().add(ChangeMonth(month: newMonth));
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Spend',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            format.format(state.totalSpend),
            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          if (showTodayInsights) ...[
            const SizedBox(height: 24),
            _buildSummaryCards(context, state),
          ],
        ],
      ),
    );
  }
}
