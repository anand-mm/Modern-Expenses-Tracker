import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../merchant_mapping/screens/merchant_mapping_screen.dart';
import '../../../../core/models/transaction.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (sortOption) {
              context.read<DashboardBloc>().add(SortTransactions(sortOption));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: SortOption.dateDesc, child: Text('Date (Newest First)')),
              PopupMenuItem(value: SortOption.dateAsc, child: Text('Date (Oldest First)')),
              PopupMenuItem(value: SortOption.amountDesc, child: Text('Amount (High to Low)')),
              PopupMenuItem(value: SortOption.amountAsc, child: Text('Amount (Low to High)')),
            ],
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 7 || action == 30) {
                context.read<DashboardBloc>().add(ScanHistoricalSms(days: action));
              } else if (action == -1 && kDebugMode) {
                context.read<DashboardBloc>().add(LoadDummyData());
              } else if (action == 100) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantMappingScreen())).then((_) {
                  if (!context.mounted) return;
                  // Reload transactions when coming back in case mappings changed
                  context.read<DashboardBloc>().add(LoadTransactions());
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Scan Last 7 Days')),
              const PopupMenuItem(value: 30, child: Text('Scan Last 30 Days')),
              if (kDebugMode) const PopupMenuItem(value: -1, child: Text('Load Sample Data (Emulator)')),
              const PopupMenuItem(value: 100, child: Text('Manage Merchants')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          } else if (state is DashboardLoaded) {
            final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹');

            return Column(
              children: [
                _buildMonthSelector(context, state.selectedMonth),
                _buildSummaryCard(
                  currencyFormat,
                  state.totalSpend,
                  state.todaySpend,
                  state.previousDaySpend,
                  state.selectedMonth,
                ),
                _buildFilterSummary(context, state),
                Expanded(
                  child: state.transactions.isEmpty
                      ? const Center(child: Text('No transactions for this month.'))
                      : ListView.builder(
                          itemCount: state.transactions.length,
                          itemBuilder: (context, index) {
                            final t = state.transactions[index];
                            final isMostUsedMerchantTxn = state.mostUsedMerchant != null && t.merchant == state.mostUsedMerchant;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMostUsedMerchantTxn ? const Color(0xFFE0F2FE) : null,
                                borderRadius: BorderRadius.circular(12),
                                border: isMostUsedMerchantTxn ? Border.all(color: const Color(0xFF38BDF8), width: 1) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: t.type == TransactionType.debit ? Colors.red.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    t.type == TransactionType.debit
                                        ? Icons.shopping_bag_outlined
                                        : Icons.account_balance_wallet_outlined,
                                    color: t.type == TransactionType.debit ? Colors.red.shade400 : Colors.green.shade400,
                                    size: 22,
                                  ),
                                ),
                                title: Text(t.merchant, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(DateFormat.yMMMd().format(t.date)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatSignedAmount(currencyFormat, t),
                                      style: TextStyle(
                                        color: t.type == TransactionType.debit ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (t.bankName != 'Unknown')
                                      Padding(padding: const EdgeInsets.only(top: 4.0), child: _buildBankLogo(t.bankName)),
                                  ],
                                ),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    builder: (context) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          top: 24,
                                          left: 24,
                                          right: 24,
                                          bottom: MediaQuery.of(context).padding.bottom + 24,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 40,
                                                height: 4,
                                                margin: const EdgeInsets.only(bottom: 24),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade400,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Transaction Details',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 16),
                                            _detailRow('Amount', _formatSignedAmount(currencyFormat, t)),
                                            _detailRow('Date', DateFormat.yMMMd().add_jm().format(t.date)),
                                            _detailRow('Merchant', t.merchant),
                                            _detailRow('Type', t.type == TransactionType.credit ? 'Credit' : 'Debit'),
                                            if (t.bankName != 'Unknown') _detailRow('Bank', t.bankName),
                                            if (t.referenceNumber != null) _detailRow('Ref No', t.referenceNumber!),
                                            const SizedBox(height: 16),
                                            const Text('Raw SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Text(
                                                t.rawText,
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBankLogo(String bankName) {
    if (bankName == 'HDFC') {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFF004C8F), borderRadius: BorderRadius.circular(4)), // Standard HDFC Blue
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.rectangle),
            ),
            const SizedBox(width: 4),
            const Text(
              'HDFC',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
      );
    } else if (bankName == 'TMB') {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF37021), borderRadius: BorderRadius.circular(4)), // Standard Orange
        child: const Text(
          'TMB',
          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    NumberFormat format,
    double totalSpend,
    double todaySpend,
    double previousDaySpend,
    DateTime selectedMonth,
  ) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final cardMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final showTodayInsights = cardMonth == currentMonth;

    final diff = todaySpend - previousDaySpend;
    final isIncrease = diff >= 0;
    final comparisonText = previousDaySpend == 0
        ? 'No expenses recorded on previous day'
        : '${isIncrease ? '↑' : '↓'} ${isIncrease ? 'Up' : 'Down'} by ${format.format(diff.abs())} vs previous day';

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF115E59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Spend',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              format.format(totalSpend),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (showTodayInsights) ...[
              const SizedBox(height: 12),
              Text(
                'Today expenses: ${format.format(todaySpend)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                comparisonText,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSignedAmount(NumberFormat format, Transaction transaction) {
    final prefix = transaction.type == TransactionType.debit ? '- ' : '+ ';
    return '$prefix${format.format(transaction.amount)}';
  }

  Widget _buildFilterSummary(BuildContext context, DashboardLoaded state) {
    final chips = <Widget>[];
    if (state.selectedMerchant != null) {
      chips.add(Chip(label: Text('Merchant: ${state.selectedMerchant}')));
    }
    if (state.selectedBank != null) {
      chips.add(Chip(label: Text('Bank: ${state.selectedBank}')));
    }
    if (state.selectedDate != null) {
      chips.add(Chip(label: Text('Date: ${DateFormat.yMMMd().format(state.selectedDate!)}')));
    }
    if (state.minAmount != null) {
      chips.add(Chip(label: Text('Min: ₹${state.minAmount!.toStringAsFixed(0)}')));
    }
    if (state.maxAmount != null) {
      chips.add(Chip(label: Text('Max: ₹${state.maxAmount!.toStringAsFixed(0)}')));
    }

    final hasFilters = chips.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showFiltersBottomSheet(context, state),
              icon: const Icon(Icons.filter_list),
              label: const Text('Filters'),
            ),
          ),
          const SizedBox(height: 8),
          if (state.mostUsedMerchant != null)
            Text(
              'Most used merchant: ${state.mostUsedMerchant} (${state.mostUsedMerchantCount} txns)',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          if (state.selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Transactions on selected date: ${state.selectedDateTransactionCount ?? 0}',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          if (hasFilters) const SizedBox(height: 8),
          if (hasFilters) Wrap(spacing: 8, runSpacing: 8, children: chips),
          if (hasFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.read<DashboardBloc>().add(ClearTransactionFilters()),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext parentContext, DashboardLoaded state) {
    String? selectedMerchant = state.selectedMerchant;
    String? selectedBank = state.selectedBank;
    DateTime? selectedDate = state.selectedDate;
    final minController = TextEditingController(text: state.minAmount?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: state.maxAmount?.toStringAsFixed(0) ?? '');
    final quickMerchants = _buildQuickMerchantList(state);
    final quickBanks = state.availableBanks.take(6).toList();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMerchant,
                      decoration: const InputDecoration(labelText: 'Merchant', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Merchants')),
                        if (state.mostUsedMerchant != null)
                          DropdownMenuItem<String>(value: '__MOST_USED__', child: Text('Most Used (${state.mostUsedMerchant})')),
                        ...state.availableMerchants.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          if (value == '__MOST_USED__') {
                            selectedMerchant = state.mostUsedMerchant;
                          } else {
                            selectedMerchant = value;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Banks')),
                        ...state.availableBanks.map((b) => DropdownMenuItem<String>(value: b, child: Text(b))),
                      ],
                      onChanged: (value) => setModalState(() => selectedBank = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(selectedDate == null ? 'Select Date' : DateFormat.yMMMd().format(selectedDate!)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => setModalState(() => selectedDate = null), child: const Text('Clear Date')),
                      ],
                    ),
                    if (quickMerchants.isNotEmpty || quickBanks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Quick Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (quickMerchants.isNotEmpty) ...[
                        const Text('Merchants', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('All'),
                                  selected: selectedMerchant == null,
                                  onSelected: (_) => setModalState(() => selectedMerchant = null),
                                ),
                              ),
                              ...quickMerchants.map(
                                (merchant) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(merchant),
                                    selected: selectedMerchant == merchant,
                                    onSelected: (selected) {
                                      setModalState(() => selectedMerchant = selected ? merchant : null);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (quickBanks.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Banks', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('All'),
                                  selected: selectedBank == null,
                                  onSelected: (_) => setModalState(() => selectedBank = null),
                                ),
                              ),
                              ...quickBanks.map(
                                (bank) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(bank),
                                    selected: selectedBank == bank,
                                    onSelected: (selected) {
                                      setModalState(() => selectedBank = selected ? bank : null);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min Amount',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max Amount',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                parentContext.read<DashboardBloc>().add(ClearTransactionFilters());
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final minAmount = double.tryParse(minController.text.trim());
                              final maxAmount = double.tryParse(maxController.text.trim());

                              Navigator.of(sheetContext).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                parentContext.read<DashboardBloc>().add(
                                  ApplyTransactionFilters(
                                    merchant: selectedMerchant,
                                    bank: selectedBank,
                                    date: selectedDate,
                                    minAmount: minAmount,
                                    maxAmount: maxAmount,
                                  ),
                                );
                              });
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      minController.dispose();
      maxController.dispose();
    });
  }

  List<String> _buildQuickMerchantList(DashboardLoaded state) {
    final result = <String>[];
    final seen = <String>{};

    if (state.mostUsedMerchant != null && state.mostUsedMerchant!.isNotEmpty) {
      seen.add(state.mostUsedMerchant!);
      result.add(state.mostUsedMerchant!);
    }

    for (final merchant in state.availableMerchants) {
      if (merchant.isEmpty || seen.contains(merchant)) continue;
      seen.add(merchant);
      result.add(merchant);
      if (result.length >= 6) break;
    }

    return result;
  }

  Widget _buildMonthSelector(BuildContext context, DateTime selectedMonth) {
    final DateFormat monthFormat = DateFormat('MMMM yyyy');
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final isCurrentMonth = selectedMonth.year == currentMonth.year && selectedMonth.month == currentMonth.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
              context.read<DashboardBloc>().add(ChangeMonth(month: newMonth));
            },
          ),
          Text(monthFormat.format(selectedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: isCurrentMonth ? Colors.grey : null,
            onPressed: isCurrentMonth
                ? null
                : () {
                    final newMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                    context.read<DashboardBloc>().add(ChangeMonth(month: newMonth));
                  },
          ),
        ],
      ),
    );
  }
}
