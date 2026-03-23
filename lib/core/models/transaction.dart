enum TransactionType { credit, debit }

class Transaction {
  final int? id;
  final double amount;
  final TransactionType type;
  final String merchant;
  final DateTime date;
  final String category;
  final String rawText;
  final String? referenceNumber;
  final String bankName;

  Transaction({
    this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.date,
    required this.category,
    required this.rawText,
    this.referenceNumber,
    this.bankName = 'Unknown',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type == TransactionType.credit ? 'credit' : 'debit',
      'merchant': merchant,
      'date': date.toIso8601String(),
      'category': category,
      'rawText': rawText,
      'referenceNumber': referenceNumber,
      'bankName': bankName,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      type: map['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
      merchant: map['merchant'] as String,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      rawText: map['rawText'] as String,
      referenceNumber: map['referenceNumber'] as String?,
      bankName: map['bankName'] as String? ?? 'Unknown',
    );
  }
}
