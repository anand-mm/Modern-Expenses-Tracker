import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/models/transaction.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
import '../../sms_ingestion/services/sms_service.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  SortOption _currentSortOption = SortOption.dateDesc;
  String? _selectedMerchant;
  String? _selectedBank;
  DateTime? _selectedDate;
  double? _minAmount;
  double? _maxAmount;

  DashboardBloc() : super(DashboardInitial()) {
    on<AppOpened>(_onAppOpened);
    on<LoadTransactions>(_onLoadTransactions);
    on<SortTransactions>(_onSortTransactions);
    on<ScanHistoricalSms>(_onScanHistoricalSms);
    on<ApplyTransactionFilters>(_onApplyTransactionFilters);
    on<ClearTransactionFilters>(_onClearTransactionFilters);
    on<ChangeMonth>(_onChangeMonth);
    on<LoadDummyData>(_onLoadDummyData);
  }

  Future<void> _onAppOpened(AppOpened event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final smsService = SmsService();
      await smsService.scanSmsSinceLastUse();
    } catch (_) {
      // Do not block dashboard if SMS sync fails.
    }
    add(LoadTransactions());
  }

  Future<void> _onLoadTransactions(LoadTransactions event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final allMonthTransactions = await _databaseHelper.getTransactionsForMonth(_selectedMonth.year, _selectedMonth.month);
      final debitMonthTransactions = allMonthTransactions.where((t) => t.type == TransactionType.debit).toList();
      final transactions = _applyFilters(debitMonthTransactions);

      final availableMerchants = debitMonthTransactions.map((t) => t.merchant).toSet().where((m) => m.isNotEmpty).toList()
        ..sort();
      final availableBanks =
          debitMonthTransactions.map((t) => t.bankName).toSet().where((b) => b.isNotEmpty && b != 'Unknown').toList()..sort();

      final merchantCounts = <String, int>{};
      for (final tx in debitMonthTransactions) {
        if (tx.merchant.isEmpty) continue;
        merchantCounts[tx.merchant] = (merchantCounts[tx.merchant] ?? 0) + 1;
      }
      String? mostUsedMerchant;
      int mostUsedMerchantCount = 0;
      merchantCounts.forEach((merchant, count) {
        if (count > mostUsedMerchantCount) {
          mostUsedMerchantCount = count;
          mostUsedMerchant = merchant;
        }
      });

      const int mostUsedMerchantThreshold = 3;
      if (mostUsedMerchantCount < mostUsedMerchantThreshold) {
        mostUsedMerchant = null;
        mostUsedMerchantCount = 0;
      }

      int? selectedDateTransactionCount;
      if (_selectedDate != null) {
        selectedDateTransactionCount = transactions.length;
      }

      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final previousDayDateOnly = todayDateOnly.subtract(const Duration(days: 1));

      double todaySpend = 0;
      double previousDaySpend = 0;
      for (final tx in debitMonthTransactions) {
        final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
        if (txDateOnly == todayDateOnly) {
          todaySpend += tx.amount;
        } else if (txDateOnly == previousDayDateOnly) {
          previousDaySpend += tx.amount;
        }
      }

      double spend = 0;
      Map<String, double> categorySpends = {};
      Map<DateTime, double> dailySpendsMap = {};
      double currentWeekendSpend = 0;
      double previousWeekendSpend = 0;

      final now = DateTime.now();
      DateTime lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      DateTime referenceDate = (lastDayOfMonth.isAfter(now)) ? now : lastDayOfMonth;

      DateTime lastSunday = referenceDate.subtract(Duration(days: referenceDate.weekday % 7));
      DateTime lastSaturday = lastSunday.subtract(const Duration(days: 1));

      DateTime previousSunday = lastSunday.subtract(const Duration(days: 7));
      DateTime previousSaturday = lastSaturday.subtract(const Duration(days: 7));

      bool isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

      for (var t in transactions) {
        if (t.type == TransactionType.debit) {
          spend += t.amount;
          categorySpends[t.category] = (categorySpends[t.category] ?? 0) + t.amount;

          DateTime dateOnly = DateTime(t.date.year, t.date.month, t.date.day);
          dailySpendsMap[dateOnly] = (dailySpendsMap[dateOnly] ?? 0) + t.amount;

          if (isSameDay(t.date, lastSaturday) || isSameDay(t.date, lastSunday)) {
            currentWeekendSpend += t.amount;
          } else if (isSameDay(t.date, previousSaturday) || isSameDay(t.date, previousSunday)) {
            previousWeekendSpend += t.amount;
          }
        }
      }

      var dailySpends = dailySpendsMap.entries.toList();
      dailySpends.sort((a, b) => a.key.compareTo(b.key));

      if (_currentSortOption == SortOption.dateDesc) {
        transactions.sort((a, b) => b.date.compareTo(a.date));
      } else if (_currentSortOption == SortOption.dateAsc) {
        transactions.sort((a, b) => a.date.compareTo(b.date));
      } else if (_currentSortOption == SortOption.amountDesc) {
        transactions.sort((a, b) => b.amount.compareTo(a.amount));
      } else if (_currentSortOption == SortOption.amountAsc) {
        transactions.sort((a, b) => a.amount.compareTo(b.amount));
      }

      emit(
        DashboardLoaded(
          transactions: transactions,
          totalSpend: spend,
          todaySpend: todaySpend,
          previousDaySpend: previousDaySpend,
          selectedMonth: _selectedMonth,
          sortOption: _currentSortOption,
          selectedMerchant: _selectedMerchant,
          selectedBank: _selectedBank,
          selectedDate: _selectedDate,
          minAmount: _minAmount,
          maxAmount: _maxAmount,
          availableMerchants: availableMerchants,
          availableBanks: availableBanks,
          mostUsedMerchant: mostUsedMerchant,
          mostUsedMerchantCount: mostUsedMerchantCount,
          selectedDateTransactionCount: selectedDateTransactionCount,
          categorySpends: categorySpends,
          dailySpends: dailySpends,
          currentWeekendSpend: currentWeekendSpend,
          previousWeekendSpend: previousWeekendSpend,
        ),
      );
    } catch (e) {
      emit(DashboardError('Failed to load transactions: \$e'));
    }
  }

  void _onSortTransactions(SortTransactions event, Emitter<DashboardState> emit) {
    _currentSortOption = event.sortOption;
    add(LoadTransactions());
  }

  Future<void> _onScanHistoricalSms(ScanHistoricalSms event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final smsService = SmsService();
      await smsService.scanHistoricalSms(days: event.days);
      add(LoadTransactions()); // Reload transactions after scan
    } catch (e) {
      emit(DashboardError('Failed to scan historical SMS: \$e'));
    }
  }

  void _onApplyTransactionFilters(ApplyTransactionFilters event, Emitter<DashboardState> emit) {
    _selectedMerchant = event.merchant;
    _selectedBank = event.bank;
    _selectedDate = event.date;
    _minAmount = event.minAmount;
    _maxAmount = event.maxAmount;
    add(LoadTransactions());
  }

  void _onClearTransactionFilters(ClearTransactionFilters event, Emitter<DashboardState> emit) {
    _selectedMerchant = null;
    _selectedBank = null;
    _selectedDate = null;
    _minAmount = null;
    _maxAmount = null;
    add(LoadTransactions());
  }

  void _onChangeMonth(ChangeMonth event, Emitter<DashboardState> emit) {
    _selectedMonth = event.month;
    add(LoadTransactions());
  }

  Future<void> _onLoadDummyData(LoadDummyData event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final dummyTransactions = _buildReusableDummyTransactions();

      for (var t in dummyTransactions) {
        await _databaseHelper.insertTransaction(t);
      }

      // Ensure users can immediately see seeded data in the active month view.
      final now = DateTime.now();
      _selectedMonth = DateTime(now.year, now.month, 1);
      add(LoadTransactions());
    } catch (e) {
      emit(DashboardError('Failed to load dummy data: \$e'));
    }
  }

  List<Transaction> _buildReusableDummyTransactions() {
    final now = DateTime.now();

    final sampleRows =
        <
          ({
            int daysAgo,
            int minutesAgo,
            double amount,
            TransactionType type,
            String merchant,
            String category,
            String bank,
            String ref,
          })
        >[
          (
            daysAgo: 0,
            minutesAgo: 35,
            amount: 250.0,
            type: TransactionType.debit,
            merchant: 'Swiggy',
            category: 'Food',
            bank: 'HDFC',
            ref: 'SAMPLE-0001',
          ),
          (
            daysAgo: 0,
            minutesAgo: 90,
            amount: 120.0,
            type: TransactionType.debit,
            merchant: 'Aavin',
            category: 'Groceries',
            bank: 'TMB',
            ref: 'SAMPLE-0002',
          ),
          (
            daysAgo: 1,
            minutesAgo: 10,
            amount: 1540.0,
            type: TransactionType.debit,
            merchant: 'Amazon',
            category: 'Shopping',
            bank: 'TMB',
            ref: 'SAMPLE-0003',
          ),
          (
            daysAgo: 1,
            minutesAgo: 180,
            amount: 320.0,
            type: TransactionType.debit,
            merchant: 'Uber',
            category: 'Transport',
            bank: 'HDFC',
            ref: 'SAMPLE-0004',
          ),
          (
            daysAgo: 2,
            minutesAgo: 15,
            amount: 50000.0,
            type: TransactionType.credit,
            merchant: 'Employer',
            category: 'Salary',
            bank: 'HDFC',
            ref: 'SAMPLE-0005',
          ),
          (
            daysAgo: 3,
            minutesAgo: 50,
            amount: 80.0,
            type: TransactionType.debit,
            merchant: 'Starbucks',
            category: 'Food',
            bank: 'TMB',
            ref: 'SAMPLE-0006',
          ),
          (
            daysAgo: 4,
            minutesAgo: 40,
            amount: 460.0,
            type: TransactionType.debit,
            merchant: 'BigBasket',
            category: 'Groceries',
            bank: 'HDFC',
            ref: 'SAMPLE-0007',
          ),
          (
            daysAgo: 5,
            minutesAgo: 20,
            amount: 1299.0,
            type: TransactionType.debit,
            merchant: 'Myntra',
            category: 'Shopping',
            bank: 'TMB',
            ref: 'SAMPLE-0008',
          ),
          (
            daysAgo: 6,
            minutesAgo: 60,
            amount: 210.0,
            type: TransactionType.debit,
            merchant: 'Zomato',
            category: 'Food',
            bank: 'HDFC',
            ref: 'SAMPLE-0009',
          ),
          (
            daysAgo: 7,
            minutesAgo: 35,
            amount: 799.0,
            type: TransactionType.debit,
            merchant: 'Jio',
            category: 'Bills',
            bank: 'TMB',
            ref: 'SAMPLE-0010',
          ),
          (
            daysAgo: 8,
            minutesAgo: 25,
            amount: 1450.0,
            type: TransactionType.debit,
            merchant: 'Apollo Pharmacy',
            category: 'Health',
            bank: 'HDFC',
            ref: 'SAMPLE-0011',
          ),
          (
            daysAgo: 9,
            minutesAgo: 90,
            amount: 350.0,
            type: TransactionType.debit,
            merchant: 'Petrol Bunk',
            category: 'Transport',
            bank: 'TMB',
            ref: 'SAMPLE-0012',
          ),
          (
            daysAgo: 11,
            minutesAgo: 75,
            amount: 2200.0,
            type: TransactionType.debit,
            merchant: 'IKEA',
            category: 'Home',
            bank: 'HDFC',
            ref: 'SAMPLE-0013',
          ),
          (
            daysAgo: 13,
            minutesAgo: 55,
            amount: 6000.0,
            type: TransactionType.credit,
            merchant: 'Friend',
            category: 'Transfer',
            bank: 'TMB',
            ref: 'SAMPLE-0014',
          ),
          (
            daysAgo: 15,
            minutesAgo: 30,
            amount: 95.0,
            type: TransactionType.debit,
            merchant: 'Tea Shop',
            category: 'Food',
            bank: 'HDFC',
            ref: 'SAMPLE-0015',
          ),
          (
            daysAgo: 17,
            minutesAgo: 20,
            amount: 1800.0,
            type: TransactionType.debit,
            merchant: 'Decathlon',
            category: 'Shopping',
            bank: 'TMB',
            ref: 'SAMPLE-0016',
          ),
          (
            daysAgo: 20,
            minutesAgo: 80,
            amount: 420.0,
            type: TransactionType.debit,
            merchant: 'Book Store',
            category: 'Education',
            bank: 'HDFC',
            ref: 'SAMPLE-0017',
          ),
          (
            daysAgo: 23,
            minutesAgo: 30,
            amount: 999.0,
            type: TransactionType.debit,
            merchant: 'Prime Video',
            category: 'Entertainment',
            bank: 'TMB',
            ref: 'SAMPLE-0018',
          ),
          (
            daysAgo: 26,
            minutesAgo: 100,
            amount: 300.0,
            type: TransactionType.debit,
            merchant: 'Bus Pass',
            category: 'Transport',
            bank: 'HDFC',
            ref: 'SAMPLE-0019',
          ),
          (
            daysAgo: 28,
            minutesAgo: 5,
            amount: 145.0,
            type: TransactionType.debit,
            merchant: 'Bakery',
            category: 'Food',
            bank: 'TMB',
            ref: 'SAMPLE-0020',
          ),
          (
            daysAgo: 28,
            minutesAgo: 5,
            amount: 145.0,
            type: TransactionType.debit,
            merchant: 'Bakery',
            category: 'Food',
            bank: 'TMB',
            ref: 'SAMPLE-0021',
          ),
          (
            daysAgo: 28,
            minutesAgo: 5,
            amount: 145.0,
            type: TransactionType.debit,
            merchant: 'Bakery',
            category: 'Food',
            bank: 'TMB',
            ref: 'SAMPLE-0022',
          ),
        ];

    return sampleRows.map((row) {
      final timestamp = now.subtract(Duration(days: row.daysAgo, minutes: row.minutesAgo));
      final action = row.type == TransactionType.credit ? 'credited' : 'debited';
      return Transaction(
        amount: row.amount,
        type: row.type,
        merchant: row.merchant,
        date: timestamp,
        category: row.category,
        rawText: 'Rs ${row.amount} $action from a/c XXXXXX on ${row.merchant}. Ref ${row.ref}',
        referenceNumber: row.ref,
        bankName: row.bank,
      );
    }).toList();
  }

  List<Transaction> _applyFilters(List<Transaction> source) {
    return source.where((t) {
      if (_selectedMerchant != null && _selectedMerchant!.isNotEmpty && t.merchant != _selectedMerchant) {
        return false;
      }

      if (_selectedBank != null && _selectedBank!.isNotEmpty && t.bankName != _selectedBank) {
        return false;
      }

      if (_selectedDate != null) {
        final d = _selectedDate!;
        if (t.date.year != d.year || t.date.month != d.month || t.date.day != d.day) {
          return false;
        }
      }

      if (_minAmount != null && t.amount < _minAmount!) {
        return false;
      }

      if (_maxAmount != null && t.amount > _maxAmount!) {
        return false;
      }

      return true;
    }).toList();
  }
}
