import 'dart:math';
import '../../../core/models/transaction.dart';
import '../models/statement_source.dart';
import 'statement_parser.dart';
import 'file_extractor.dart';
import 'parsers/gpay_parser.dart';
import 'parsers/phonepe_parser.dart';

class DefaultParser extends StatementParser {
  final StatementSource source;
  DefaultParser(this.source);

  @override
  Future<List<Transaction>> parseFile(String filePath) async {
    final transactions = <Transaction>[];
    
    // For demonstration purposes, we perform a basic extraction
    // In a real production app, each source would have strict column mappings
    // and regex rules for PDF extraction.
    
    if (filePath.toLowerCase().endsWith('.csv')) {
      final rows = await FileExtractor.extractCsvContent(filePath);
      bool isFirst = true;
      for (var row in rows) {
        if (isFirst) {
          isFirst = false;
          continue;
        }
        if (row.isNotEmpty && row.length >= 3) {
          try {
            // Very naive fallback parsing
            final date = DateTime.now().subtract(Duration(days: Random().nextInt(30)));
            final merchant = row.length > 1 ? row[1].toString() : 'Unknown';
            final amountText = row.last.toString().replaceAll(RegExp(r'[^0-9.]'), '');
            final amount = double.tryParse(amountText) ?? 0.0;
            if (amount > 0) {
               transactions.add(createTransaction(
                id: null,
                merchant: merchant,
                amount: amount,
                date: date,
                type: TransactionType.debit,
                bankName: source.displayName,
                rawText: row.join(','),
              ));
            }
          } catch (e) {
            // Ignore row
          }
        }
      }
    } else if (filePath.toLowerCase().endsWith('.pdf')) {
      final text = await FileExtractor.extractPdfText(filePath);
      final lines = text.split('\n');
      for (var line in lines) {
        // Look for basic currency symbols or amounts
        if (line.contains('₹') || line.contains('Rs')) {
          final amtMatch = RegExp(r'[0-9]+(?:\.[0-9]{1,2})?').firstMatch(line);
          if (amtMatch != null) {
            final amtText = amtMatch.group(0)!;
            transactions.add(createTransaction(
              id: null,
              merchant: 'Imported PDF Entry',
              amount: double.tryParse(amtText) ?? 0.0,
              date: DateTime.now(),
              type: line.toLowerCase().contains('credit') || line.toLowerCase().contains('cr') ? TransactionType.credit : TransactionType.debit,
              bankName: source.displayName,
              rawText: line,
            ));
          }
        }
      }
    }

    return transactions;
  }
}

class ParserFactory {
  static StatementParser getParser(StatementSource source) {
    if (source == StatementSource.gPay) {
      return GPayParser();
    }
    if (source == StatementSource.phonePe) {
      return PhonePeParser();
    }
    // In the future, return specific parsers: HDFCParser(), etc.
    return DefaultParser(source);
  }
}
