import 'package:equatable/equatable.dart';
import '../../../../core/models/transaction.dart';

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Transaction> transactions;
  final List<Transaction> filteredTransactions;
  final double totalSpend;
  final double previousMonthSpend;
  final double todaySpend;
  final double previousDaySpend;
  final double currentWeekSpend;
  final DateTime selectedMonth;
  final SortOption sortOption;
  final String? selectedMerchant;
  final String? selectedBank;
  final DateTime? selectedDate;
  final double? minAmount;
  final double? maxAmount;
  final TransactionType? selectedType;
  final String? searchQuery;
  final List<String> availableMerchants;
  final List<String> availableBanks;
  final List<Map<String, dynamic>> topMerchants;
  final List<Map<String, dynamic>> topMerchantsByCount;
  final int? selectedDateTransactionCount;
  final Map<String, double> categorySpends;
  final List<MapEntry<DateTime, double>> dailySpends;
  final double currentWeekendSpend;
  final double previousWeekendSpend;

  const DashboardLoaded({
    required this.transactions,
    required this.filteredTransactions,
    required this.totalSpend,
    this.previousMonthSpend = 0.0,
    this.todaySpend = 0.0,
    this.previousDaySpend = 0.0,
    this.currentWeekSpend = 0.0,
    required this.selectedMonth,
    this.sortOption = SortOption.dateDesc,
    this.selectedMerchant,
    this.selectedBank,
    this.selectedDate,
    this.minAmount,
    this.maxAmount,
    this.selectedType,
    this.searchQuery,
    required this.availableMerchants,
    required this.availableBanks,
    required this.topMerchants,
    required this.topMerchantsByCount,
    this.selectedDateTransactionCount,
    this.categorySpends = const {},
    this.dailySpends = const [],
    this.currentWeekendSpend = 0.0,
    this.previousWeekendSpend = 0.0,
  });

  @override
  List<Object?> get props => [
    transactions,
    filteredTransactions,
    totalSpend,
    previousMonthSpend,
    todaySpend,
    previousDaySpend,
    currentWeekSpend,
    selectedMonth,
    sortOption,
    selectedMerchant,
    selectedBank,
    selectedDate,
    minAmount,
    maxAmount,
    selectedType,
    searchQuery,
    availableMerchants,
    availableBanks,
    topMerchants,
    topMerchantsByCount,
    selectedDateTransactionCount,
    categorySpends,
    dailySpends,
    currentWeekendSpend,
    previousWeekendSpend,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
