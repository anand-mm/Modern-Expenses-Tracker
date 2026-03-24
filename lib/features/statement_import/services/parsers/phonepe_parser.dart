import 'package:intl/intl.dart';
import '../../../../core/models/transaction.dart';
import '../../models/statement_source.dart';
import '../statement_parser.dart';
import '../file_extractor.dart';

class PhonePeParser extends StatementParser {
  @override
  Future<List<Transaction>> parseFile(String filePath) async {
    final transactions = <Transaction>[];

    if (!filePath.toLowerCase().endsWith('.pdf')) {
      await FileExtractor.extractCsvContent(filePath);
      return transactions;
    }

    // 1. Extract All Text
    String fullText = await FileExtractor.extractPdfText(filePath);

    // Clean up invisible characters
    fullText = fullText.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '');

    // Flatten the text into a single line spaced by single spaces
    // as PDFs often split text randomly with newlines
    fullText = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove all PhonePe specific boilerplate
    fullText = fullText.replaceAll(RegExp(r'Page\s+\d+\s+of\s+\d+', caseSensitive: false), ' ');
    fullText = fullText.replaceAll(RegExp(r'This is a system generated statement.*?support\.phonepe\.com/statement\.?', caseSensitive: false), ' ');
    fullText = fullText.replaceAll(RegExp(r'Date\s+Transaction\s+Details\s+Type\s+Amount', caseSensitive: false), ' ');
    fullText = fullText.replaceAll(RegExp(r'Transaction\s+Statement\s+for\s+\d+', caseSensitive: false), ' ');
    fullText = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. The Date Anchor Regex for PhonePe (e.g. "Mar 18, 2024")
    // Notice that GPay had "02 Jul, 2025" while PhonePe has "Mar 18, 2024".
    final dateRegExp = RegExp(r'[A-Za-z]{3}\s+\d{1,2},?\s*\d{4}');

    // Find all occurrences of the date pattern
    final Iterable<Match> dateMatches = dateRegExp.allMatches(fullText);

    if (dateMatches.isEmpty) {
      return transactions;
    }

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
      // e.g. "Mar 18, 2024"
      final dateRegExp = RegExp(r'[A-Za-z]{3}\s+\d{1,2},?\s*\d{4}');
      // Use user-provided regex for time: \d{2}.\d{2}\s*[aApP][mM]
      // Adding capturing groups for hour, minute, am/pm
      final timeRegExp = RegExp(r'(\d{2}).(\d{2})\s*([aApP][mM])');

      // Specifically target ₹ to avoid misinterpreting "0718" as an amount when missing symbols
      final amountRegExp = RegExp(r'(?:₹|Rs\.?|INR|\?)\s*([0-9,]+(?:\.[0-9]*)?)');
      // e.g "DEBIT" or "CREDIT"
      final typeRegExp = RegExp(r'\b(DEBIT|CREDIT)\b', caseSensitive: false);
      // e.g. "Paid to SHREE LAUNDRY", stops at "Transaction ID" or "₹"
      final merchantRegExp = RegExp(
        r'(?:Paid to|Received from|Mobile recharged|Sent to)\s+(.*?)(?=\s+DEBIT|\s+CREDIT|\s+Transaction ID|\s+₹)',
        caseSensitive: false,
      );

      final dateMatch = dateRegExp.firstMatch(chunk);
      final timeMatch = timeRegExp.firstMatch(chunk);
      final amountMatch = amountRegExp.firstMatch(chunk);
      final merchantMatch = merchantRegExp.firstMatch(chunk);
      final typeMatch = typeRegExp.firstMatch(chunk);
      final bankRegExp = RegExp(
        r'(?:Paid by|Deposited to|Credited to)\s+(.*?)(?=\s*X{2,}\d+|\s+\d{4}|\s*₹|\s*$)',
        caseSensitive: false,
      );
      final bankMatch = bankRegExp.firstMatch(chunk);

      if (dateMatch == null || amountMatch == null) {
        return null;
      }

      String dateStr = dateMatch.group(0)!;
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      final amount = double.tryParse(amountStr) ?? 0.0;

      final isDebit =
          typeMatch?.group(1)?.toUpperCase() == 'DEBIT' ||
          chunk.toLowerCase().contains('paid to') ||
          chunk.toLowerCase().contains('recharged');
      final isCredit = typeMatch?.group(1)?.toUpperCase() == 'CREDIT' || chunk.toLowerCase().contains('received from');

      if (!isDebit && !isCredit) {
        return null; // Cannot determine transaction direction
      }

      final type = isCredit ? TransactionType.credit : TransactionType.debit;

      String merchant = 'Unknown Merchant';
      if (merchantMatch != null && merchantMatch.groupCount >= 1) {
        merchant = merchantMatch.group(1)!.trim();
      } else if (chunk.toLowerCase().contains('mobile recharged')) {
        final rechargeMatch = RegExp(r'Mobile recharged\s+([0-9]+)', caseSensitive: false).firstMatch(chunk);
        if (rechargeMatch != null) merchant = 'Mobile Recharge ${rechargeMatch.group(1)}';
      }

      DateTime date;
      try {
        String cleanDate = dateStr.replaceAll(',', '').replaceAll(RegExp(r'\s+'), ' ').trim();
        String formatString = cleanDate.split(' ')[0].length > 3 ? 'MMMM d yyyy' : 'MMM d yyyy';
        DateTime dateOnly = DateFormat(formatString).parse(cleanDate);

        if (timeMatch != null) {
          int hour = int.parse(timeMatch.group(1)!);
          int minute = int.parse(timeMatch.group(2)!);
          String ampm = timeMatch.group(3)!.toLowerCase();

          if (ampm == 'pm' && hour < 12) hour += 12;
          if (ampm == 'am' && hour == 12) hour = 0;

          date = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, hour, minute);
        } else {
          date = dateOnly;
        }
      } catch (e) {
        date = DateTime.now();
      }

      String bankName = StatementSource.phonePe.displayName;
      if (bankMatch != null && bankMatch.groupCount >= 1) {
        String rawBank = bankMatch.group(1)!.trim().toLowerCase();
        if (rawBank.contains('hdfc'))
          bankName = 'HDFC';
        else if (rawBank.contains('state bank') || rawBank.contains('sbi'))
          bankName = 'SBI';
        else if (rawBank.contains('icici'))
          bankName = 'ICICI';
        else if (rawBank.contains('axis'))
          bankName = 'Axis';
        else if (rawBank.contains('kotak'))
          bankName = 'Kotak';
        else if (rawBank.contains('baroda') || rawBank.contains('bob'))
          bankName = 'BOB';
        else if (rawBank.contains('tmb') || rawBank.contains('tamilnad'))
          bankName = 'TMB';
        else if (rawBank.contains('punjab') || rawBank.contains('pnb'))
          bankName = 'PNB';
        else if (rawBank.isNotEmpty) {
          bankName = bankMatch.group(1)!.trim();
        }
      }

      return createTransaction(
        id: null,
        merchant: merchant,
        amount: amount,
        date: date,
        type: type,
        bankName: bankName,
        rawText: chunk.replaceAll('\n', ' ').trim(),
      );
    } catch (e) {
      return null;
    }
  }
}
