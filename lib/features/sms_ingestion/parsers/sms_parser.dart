import '../../../core/models/transaction.dart';
import '../../../core/database/database_helper.dart';

class SmsParser {
  // Regex extracting Amount. Matches 'Rs.', 'INR' optionally followed by spaces and a number with optional decimals.
  static final RegExp _amountRegex = RegExp(r'(?:Rs\.?|INR)\s*([\d,]+\.?\d*)', caseSensitive: false);

  // Regex extracting Type. Matches 'credited', 'cr', 'deposited', 'received' for credit and 'debited', 'dr', 'deducted', 'sent' for debit.
  static final RegExp _creditRegex = RegExp(r'\b(credited|cr|deposited|received)\b', caseSensitive: false);
  static final RegExp _debitRegex = RegExp(r'\b(debited|dr|deducted|sent)\b', caseSensitive: false);

  // Regex extracting Date. Matches common patterns like DD-MM-YY, DD/MM/YYYY, or DD-MMM-YY.
  static final RegExp _dateRegex = RegExp(
    r'\b(\d{2}[-/]\d{2}[-/]\d{2,4}|\d{2}-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-\d{2,4})\b',
    caseSensitive: false,
  );

  // Regex extracting Merchant for debits. Looks for text between 'to ', 'info: ', or 'on ' and the next structural keyword ('.', 'Ref').
  static final RegExp _merchantToRegex = RegExp(
    r'(?:to|info:|on)\s+(?:VPA\s+)?([A-Za-z0-9@\s]+?)(?:\.|\s+(?:Ref|UPI|On))',
    caseSensitive: false,
  );

  // Regex extracting Sender for credits. Looks for text between 'from ' and the next structural keyword.
  static final RegExp _merchantFromRegex = RegExp(r'from\s+([A-Za-z0-9\s]+?)(?:\.|\s+Ref)', caseSensitive: false);

  // Regex extracting Reference Number (Ref No, UTR, Txn ID, etc.)
  static final RegExp _refNumberRegex = RegExp(
    r'(?:Ref[\s\.No]*|UTR|Txn|ID|UPI Ref)[^\w]*([A-Za-z0-9]{6,20})\b',
    caseSensitive: false,
  );
  // New regex for multiline debit format "Sent Rs.XXX\nFrom...\nTo [Merchant]\nOn [Date]\nRef [Ref]"
  static final RegExp _multilineSentRegex = RegExp(
    r'^Sent(?: Rs\.?| INR)\s*([\d,]+\.?\d*)',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _multilineToRegex = RegExp(r'^To\s+(.+)$', caseSensitive: false, multiLine: true);

  DatabaseHelper? _dbHelper;

  SmsParser({DatabaseHelper? dbHelper}) {
    _dbHelper = dbHelper ?? DatabaseHelper();
  }

  Future<String> _getFriendlyMerchantName(String rawMerchant) async {
    String normalizedRaw = rawMerchant.trim().toUpperCase();

    try {
      final mappings = await _dbHelper!.getAllMerchantMappings();
      for (var entry in mappings.entries) {
        if (normalizedRaw.contains(entry.key.toUpperCase())) {
          return entry.value;
        }
      }
    } catch (e) {
      // ignore
    }

    return rawMerchant.trim();
  }

  Future<Transaction?> parseSms(String rawSms, {String? sender}) async {
    try {
      // 1. Determine Type & Amount together if it matches multiline format
      TransactionType type;
      double amount = 0.0;

      final multiLineMatch = _multilineSentRegex.firstMatch(rawSms);
      if (multiLineMatch != null) {
        type = TransactionType.debit;
        final amountStr = multiLineMatch.group(1)?.replaceAll(',', '') ?? '0.0';
        amount = double.parse(amountStr);
      } else if (_debitRegex.hasMatch(rawSms)) {
        type = TransactionType.debit;
      } else if (_creditRegex.hasMatch(rawSms)) {
        type = TransactionType.credit;
      } else {
        return null; // Ignore non-transactional messages
      }

      // 2. Extract Amount (if not already extracted by multiline)
      if (multiLineMatch == null) {
        final amountMatch = _amountRegex.firstMatch(rawSms);
        if (amountMatch == null) return null; // Transaction must have an amount
        final amountStr = amountMatch.group(1)?.replaceAll(',', '') ?? '0.0';
        amount = double.parse(amountStr);
      }

      // 3. Extract Date
      DateTime date = DateTime.now(); // Fallback to current time
      final dateMatch = _dateRegex.firstMatch(rawSms);
      if (dateMatch != null) {
        // Real parsing of India-specific date formats (DD-MM-YYYY, etc.) can be complex,
        // so we'll grab it, but in a real app we'd format it strictly with intl's DateFormat.
        // For this scaffold, we stick with DateTime.now() since raw text parse to DateTime natively is fragile.
      }

      // 4. Extract Merchant
      String merchant = 'Unknown';
      if (_multilineToRegex.hasMatch(rawSms)) {
        final toMatch = _multilineToRegex.firstMatch(rawSms);
        if (toMatch != null) merchant = toMatch.group(1)?.trim() ?? 'Unknown';
      } else if (type == TransactionType.debit) {
        final merchantMatch = _merchantToRegex.firstMatch(rawSms);
        if (merchantMatch != null) merchant = merchantMatch.group(1)?.trim() ?? 'Unknown';
      } else {
        final fromMatch = _merchantFromRegex.firstMatch(rawSms);
        if (fromMatch != null) merchant = fromMatch.group(1)?.trim() ?? 'Unknown';
      }

      merchant = await _getFriendlyMerchantName(merchant);

      // 5. Extract Reference Number
      String? referenceNumber;
      final refMatch = _refNumberRegex.firstMatch(rawSms);
      if (refMatch != null) {
        referenceNumber = refMatch.group(1)?.trim();
      }

      // 6. Extract Bank Name
      String bankName = 'Unknown';
      if (sender != null) {
        final uSender = sender.toUpperCase();
        if (uSender.contains('HDFC')) {
          bankName = 'HDFC';
        } else if (uSender.contains('TMB') || uSender.contains('TAMILNAD')) {
          bankName = 'TMB';
        }
      }

      if (bankName == 'Unknown') {
        final uRawSms = rawSms.toUpperCase();
        if (uRawSms.contains('HDFC')) {
          bankName = 'HDFC';
        } else if (uRawSms.contains('TMB') || uRawSms.contains('TAMILNAD')) {
          bankName = 'TMB';
        }
      }

      return Transaction(
        amount: amount,
        type: type,
        merchant: merchant,
        date: date,
        category: 'Uncategorized',
        rawText: rawSms,
        referenceNumber: referenceNumber,
        bankName: bankName,
      );
    } catch (e) {
      return null;
    }
  }
}
