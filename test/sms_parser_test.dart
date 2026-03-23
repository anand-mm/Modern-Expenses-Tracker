import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/features/sms_ingestion/parsers/sms_parser.dart';
import 'package:expense_tracker/core/models/transaction.dart';

void main() {
  group('SmsParser', () {
    test('parses debit SMS correctly', () async {
      final sms = 'Rs.500.00 has been debited from A/c no. XXXXX3451 on 01-Jan-22 to VPA alice@upi. Ref no. 23456.';
      final parser = SmsParser();
      final transaction = await parser.parseSms(sms);

      expect(transaction, isNotNull);
      expect(transaction!.amount, 500.0);
      expect(transaction.type, TransactionType.debit);
      expect(transaction.merchant, 'alice@upi');
      expect(transaction.bankName, 'Unknown');
    });

    test('parses credit SMS correctly', () async {
      final sms = 'Dear Customer, Acct XX123 is credited with INR 5,000.00 on 10/05/2021 from employer. Ref 1234';
      final parser = SmsParser();
      final transaction = await parser.parseSms(sms);

      expect(transaction, isNotNull);
      expect(transaction!.amount, 5000.0);
      expect(transaction.type, TransactionType.credit);
      expect(transaction.merchant, 'employer');
      expect(transaction.bankName, 'Unknown');
    });

    test('ignores non-transactional SMS', () async {
      final sms = 'Your OTP for login is 123456. Do not share with anyone.';
      final parser = SmsParser();
      final transaction = await parser.parseSms(sms);

      expect(transaction, isNull);
    });

    test('parses HDFC bank name correctly', () async {
      final sms = 'Update! INR 1,200.00 is debited from your HDFC Bank A/c...';
      final parser = SmsParser();
      final transaction = await parser.parseSms(sms, sender: 'VM-HDFCBank');

      expect(transaction, isNotNull);
      expect(transaction!.bankName, 'HDFC');
    });

    test('parses TMB bank name correctly', () async {
      final sms = 'Your a/c is credited with Rs.1000 by ABC on 01-01-22.';
      final parser = SmsParser();
      final transaction = await parser.parseSms(sms, sender: 'VM-TMBank');

      expect(transaction, isNotNull);
      expect(transaction!.bankName, 'TMB');
    });
  });
}
