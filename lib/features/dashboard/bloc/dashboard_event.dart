import 'package:equatable/equatable.dart';
import 'dashboard_state.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends DashboardEvent {}

class AppOpened extends DashboardEvent {}

class SortTransactions extends DashboardEvent {
  final SortOption sortOption;

  const SortTransactions(this.sortOption);

  @override
  List<Object?> get props => [sortOption];
}

class ScanHistoricalSms extends DashboardEvent {
  final int days;

  const ScanHistoricalSms({required this.days});

  @override
  List<Object?> get props => [days];
}

class ApplyTransactionFilters extends DashboardEvent {
  final String? merchant;
  final String? bank;
  final DateTime? date;
  final double? minAmount;
  final double? maxAmount;

  const ApplyTransactionFilters({this.merchant, this.bank, this.date, this.minAmount, this.maxAmount});

  @override
  List<Object?> get props => [merchant, bank, date, minAmount, maxAmount];
}

class ClearTransactionFilters extends DashboardEvent {}

class LoadDummyData extends DashboardEvent {}

class ChangeMonth extends DashboardEvent {
  final DateTime month;

  const ChangeMonth({required this.month});

  @override
  List<Object?> get props => [month];
}
