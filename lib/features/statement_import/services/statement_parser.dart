import '../../../core/models/transaction.dart';

abstract class StatementParser {
  /// Parses the given file (either CSV content string or extracted PDF text or bytes) 
  /// and returns a list of Transactions.
  Future<List<Transaction>> parseFile(String filePath);
  
  /// Helper method to create a transaction safely
  Transaction createTransaction({
    int? id,
    required String merchant,
    required double amount,
    required DateTime date,
    required TransactionType type,
    String? bankName,
    String? rawText,
    String? referenceNumber,
  }) {
    return Transaction(
      id: id,
      amount: amount,
      date: date,
      type: type,
      category: 'Uncategorized', // Default
      merchant: merchant,
      bankName: bankName ?? 'Unknown',
      rawText: rawText ?? 'Imported Statement Transaction',
      referenceNumber: referenceNumber,
    );
  }
}
