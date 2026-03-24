import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_event.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/widgets/transaction_list_item.dart';
import '../../../core/models/transaction.dart';
import '../../../core/widgets/modern_app_bar.dart';
import '../../statement_import/screens/statement_import_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  void _updateFilter(DashboardLoaded state, {
    String? merchant, bool clearMerchant = false,
    String? bank, bool clearBank = false,
    DateTime? date, bool clearDate = false,
    double? minAmount, bool clearMin = false,
    double? maxAmount, bool clearMax = false,
    TransactionType? type, bool clearType = false,
    String? searchQuery, bool clearSearch = false,
  }) {
    context.read<DashboardBloc>().add(
      ApplyTransactionFilters(
        merchant: clearMerchant ? null : (merchant ?? state.selectedMerchant),
        bank: clearBank ? null : (bank ?? state.selectedBank),
        date: clearDate ? null : (date ?? state.selectedDate),
        minAmount: clearMin ? null : (minAmount ?? state.minAmount),
        maxAmount: clearMax ? null : (maxAmount ?? state.maxAmount),
        type: clearType ? null : (type ?? state.selectedType),
        searchQuery: clearSearch ? null : (searchQuery ?? state.searchQuery),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dayFormatter = DateFormat.yMMMd();
    final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹');

    return Scaffold(
      appBar: ModernAppBar(
        title: _isSearching
            ? BlocBuilder<DashboardBloc, DashboardState>(
                builder: (context, state) {
                  return TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Search merchants...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      if (state is DashboardLoaded) {
                        _updateFilter(state, searchQuery: val, clearSearch: val.isEmpty);
                      }
                    },
                  );
                },
              )
            : const Text('All Transactions'),
        leading: _isSearching
            ? BlocBuilder<DashboardBloc, DashboardState>(
                builder: (context, state) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                      });
                      if (state is DashboardLoaded) {
                        _updateFilter(state, clearSearch: true);
                      }
                    },
                  );
                },
              )
            : null,
        actions: [
          if (!_isSearching)
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                      if (state is DashboardLoaded) {
                        _searchController.text = state.searchQuery ?? '';
                      }
                    });
                  },
                );
              },
            ),
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoaded) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<SortOption>(
                      icon: Badge(
                        isLabelVisible: state.sortOption != SortOption.dateDesc,
                        child: const Icon(Icons.sort),
                      ),
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
                    IconButton(
                      icon: Badge(
                        isLabelVisible: state.selectedMerchant != null || 
                                        state.selectedBank != null || 
                                        state.selectedDate != null || 
                                        state.minAmount != null || 
                                        state.maxAmount != null,
                        child: const Icon(Icons.filter_alt_outlined),
                      ),
                      onPressed: () => _showFiltersBottomSheet(context, state),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoaded) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatementImportScreen()),
                );
              },
              icon: const Icon(Icons.file_upload),
              label: const Text('Import Statement'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          } else if (state is DashboardLoaded) {
            return Column(
              children: [
                _buildQuickFilters(context, state),
                if (state.filteredTransactions.isEmpty)
                  const Expanded(child: Center(child: Text('No transactions match the selected filters.')))
                else
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final Map<String, List<Transaction>> groupedTransactions = {};
                        final Map<String, double> dailySpends = {};

                        for (var t in state.filteredTransactions) {
                          final dateKey = dayFormatter.format(t.date);
                          if (!groupedTransactions.containsKey(dateKey)) {
                            groupedTransactions[dateKey] = [];
                            dailySpends[dateKey] = 0;
                          }
                          groupedTransactions[dateKey]!.add(t);
                          if (t.type == TransactionType.debit) {
                            dailySpends[dateKey] = dailySpends[dateKey]! + t.amount;
                          }
                        }

                        final sortedDates = groupedTransactions.keys.toList();

                        return ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, sectionIndex) {
                            final dateKey = sortedDates[sectionIndex];
                            final transactionsForDate = groupedTransactions[dateKey]!;
                            final dailySpend = dailySpends[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateKey,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.blueGrey),
                                      ),
                                      if (dailySpend > 0)
                                        Text(
                                          '- ${currencyFormat.format(dailySpend)}',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade600),
                                        ),
                                      if (dailySpend == 0)
                                        Text(
                                          currencyFormat.format(0),
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade400),
                                        ),
                                    ],
                                  ),
                                ),
                                ...transactionsForDate.map((t) {
                                  final isTopMerchantTxn = state.topMerchants.any((m) => m['merchant'] == t.merchant);
                                  return TransactionListItem(
                                    transaction: t,
                                    isMostUsedMerchantTxn: isTopMerchantTxn,
                                  );
                                }),
                              ],
                            );
                          },
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

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onSelected}) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.teal,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildQuickFilters(BuildContext context, DashboardLoaded state) {
    return Container(
      color: Colors.grey.shade50,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildChip(
              label: 'All', 
              isSelected: state.selectedType == null && state.selectedBank == null,
              onSelected: () {
                _updateFilter(state, clearType: true, clearBank: true, clearMerchant: true);
              }
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Debits', 
              isSelected: state.selectedType == TransactionType.debit,
              onSelected: () => _updateFilter(state, type: TransactionType.debit),
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Credits', 
              isSelected: state.selectedType == TransactionType.credit,
              onSelected: () => _updateFilter(state, type: TransactionType.credit),
            ),
            const SizedBox(width: 8),
            if (state.availableBanks.contains('HDFC')) ...[
              _buildChip(
                label: 'HDFC', 
                isSelected: state.selectedBank == 'HDFC',
                onSelected: () => _updateFilter(state, bank: 'HDFC'),
              ),
              const SizedBox(width: 8),
            ],
            if (state.availableBanks.contains('TMB')) ...[
              _buildChip(
                label: 'TMB', 
                isSelected: state.selectedBank == 'TMB',
                onSelected: () => _updateFilter(state, bank: 'TMB'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext parentContext, DashboardLoaded state) {
    String? selectedMerchant = state.selectedMerchant;
    String? selectedBank = state.selectedBank;
    DateTime? selectedDate = state.selectedDate;
    final minController = TextEditingController(text: state.minAmount?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: state.maxAmount?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Advanced Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMerchant,
                      decoration: const InputDecoration(labelText: 'Merchant', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Merchants')),
                        ...state.availableMerchants.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))),
                      ],
                      onChanged: (value) => setModalState(() => selectedMerchant = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Banks')),
                        ...state.availableBanks.map((b) => DropdownMenuItem<String>(value: b, child: Text(b))),
                      ],
                      onChanged: (value) => setModalState(() => selectedBank = value),
                    ),
                    const SizedBox(height: 16),
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
                        if (selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setModalState(() => selectedDate = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              parentContext.read<DashboardBloc>().add(ClearTransactionFilters());
                            },
                            child: const Text('Clear All', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              final minAmount = double.tryParse(minController.text.trim());
                              final maxAmount = double.tryParse(maxController.text.trim());

                              Navigator.of(sheetContext).pop();
                              parentContext.read<DashboardBloc>().add(
                                ApplyTransactionFilters(
                                  merchant: selectedMerchant,
                                  bank: selectedBank,
                                  date: selectedDate,
                                  minAmount: minAmount,
                                  maxAmount: maxAmount,
                                  type: state.selectedType,
                                  searchQuery: state.searchQuery,
                                ),
                              );
                            },
                            child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }
}
