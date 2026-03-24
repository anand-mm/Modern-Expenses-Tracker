import 'package:intl/intl.dart';
import '../../../../core/models/transaction.dart';
import '../../models/statement_source.dart';
import '../statement_parser.dart';
import '../file_extractor.dart';

class GPayParser extends StatementParser {
  @override
  Future<List<Transaction>> parseFile(String filePath) async {
    final transactions = <Transaction>[];

    if (!filePath.toLowerCase().endsWith('.pdf')) {
      // Fallback for CSV if any
      await FileExtractor.extractCsvContent(filePath);
      // Basic CSV reading (skipped fully functional CSV handling for now to focus on PDF)
      return transactions;
    }

    // 1. Extract All Text
    String fullText = await FileExtractor.extractPdfText(filePath);
    
    // Clean up invisible characters that PDF extractors sometimes insert
    fullText = fullText.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '');
    
    // CRITICAL FIX: The PDF extractor outputs a NEWLINE after almost every single word.
    // Replace all spacing formats (newlines, tabs, double spaces) into single spaces!
    fullText = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove PDF Footers like "Page 1 of 13"
    fullText = fullText.replaceAll(RegExp(r'Page\s+\d+\s+of\s+\d+', caseSensitive: false), ' ');
    fullText = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. The Date Anchor Regex (relaxed: 02 Jul, 2025 or 02 July 2025)
    final dateRegExp = RegExp(r'\d{2}\s+[A-Za-z]{3,},?\s*\d{4}');
    
    // Find all occurrences of the date pattern
    final Iterable<Match> dateMatches = dateRegExp.allMatches(fullText);
    
    if (dateMatches.isEmpty) {
      return transactions;
    }

    // Convert matches to a list of start indices
    final List<int> startIndices = dateMatches.map((m) => m.start).toList();
    
    // 3. Split the text into discrete transaction chunks
    for (int i = 0; i < startIndices.length; i++) {
      final int start = startIndices[i];
      final int end = (i + 1 < startIndices.length) ? startIndices[i + 1] : fullText.length;
      
      final String chunk = fullText.substring(start, end);
      
      // 4. Parse the isolated chunk
      final txn = _parseChunk(chunk);
      if (txn != null) {
        transactions.add(txn);
      }
    }

    return transactions;
  }

  Transaction? _parseChunk(String chunk) {
    try {
      final dateRegExp = RegExp(r'\d{2}\s+[A-Za-z]{3,},?\s*\d{4}');
      // Match ₹, Rs, INR, or a non-ascii symbol that usually replaces ₹
      final amountRegExp = RegExp(r'(?:₹|Rs\.?|INR|\?|[^a-zA-Z0-9\s.,:])\s*([0-9,]+(?:\.[0-9]*)?)');
      final merchantRegExp = RegExp(r'(?:Paid to|Received from)\s+(.*?)(?=UPI|Paid by|₹|Rs)', caseSensitive: false);

      final dateMatch = dateRegExp.firstMatch(chunk);
      final amountMatch = amountRegExp.firstMatch(chunk);
      final merchantMatch = merchantRegExp.firstMatch(chunk);
      final bankRegExp = RegExp(r'(?:Paid by|Deposited to|Credited to)\s+(.*?)(?=\s+\d{4}|\s*₹|\s*Rs|$)', caseSensitive: false);
      final bankMatch = bankRegExp.firstMatch(chunk);

      // We need at least a date and an amount for a valid transaction chunk
      if (dateMatch == null || amountMatch == null) {
        return null;
      }

      String dateStr = dateMatch.group(0)!;
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      final amount = double.tryParse(amountStr) ?? 0.0;
      
      final isDebit = chunk.contains('Paid to');
      final isCredit = chunk.contains('Received from');
      
      if (!isDebit && !isCredit) {
        return null; // Cannot determine transaction direction
      }

      final type = isCredit ? TransactionType.credit : TransactionType.debit;
      
      String merchant = 'Unknown Merchant';
      if (merchantMatch != null && merchantMatch.groupCount >= 1) {
        merchant = merchantMatch.group(1)!.trim();
      }

      DateTime date;
      try {
        String cleanDate = dateStr.replaceAll(',', '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleanDate.split(' ')[1].length > 3) {
          date = DateFormat('dd MMMM yyyy').parse(cleanDate);
        } else {
          date = DateFormat('dd MMM yyyy').parse(cleanDate);
        }
      } catch (e) {
        date = DateTime.now();
      }

      String bankName = StatementSource.gPay.displayName;
      if (bankMatch != null && bankMatch.groupCount >= 1) {
        String rawBank = bankMatch.group(1)!.trim().toLowerCase();
        if (rawBank.contains('hdfc')) bankName = 'HDFC';
        else if (rawBank.contains('state bank') || rawBank.contains('sbi')) bankName = 'SBI';
        else if (rawBank.contains('icici')) bankName = 'ICICI';
        else if (rawBank.contains('axis')) bankName = 'Axis';
        else if (rawBank.contains('kotak')) bankName = 'Kotak';
        else if (rawBank.contains('baroda') || rawBank.contains('bob')) bankName = 'BOB';
        else if (rawBank.contains('tmb') || rawBank.contains('tamilnad')) bankName = 'TMB';
        else if (rawBank.contains('punjab') || rawBank.contains('pnb')) bankName = 'PNB';
        else bankName = bankMatch.group(1)!.trim(); // Use original text if not recognized
      }

      return createTransaction(
        id: null,
        merchant: merchant,
        amount: amount,
        date: date,
        type: type,
        bankName: bankName,
        rawText: chunk.replaceAll('\n', ' ').trim(), // Flattened raw text 
      );

    } catch (e) {
      return null;
    }
  }
}
