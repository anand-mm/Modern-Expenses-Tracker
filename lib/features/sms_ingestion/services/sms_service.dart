import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:telephony_fix/telephony.dart';
import '../parsers/sms_parser.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/transaction.dart';

// Top-level function for background execution
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  if (message.body != null) {
    final parser = SmsParser();
    final transaction = await parser.parseSms(message.body!, sender: message.address);
    if (transaction != null) {
      debugPrint('Parsed a valid background transaction');
      final actualDate = message.date != null ? DateTime.fromMillisecondsSinceEpoch(message.date!) : transaction.date;
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: transaction.amount,
        type: transaction.type,
        merchant: transaction.merchant,
        date: actualDate,
        category: transaction.category,
        rawText: transaction.rawText,
        referenceNumber: transaction.referenceNumber,
        bankName: transaction.bankName,
      );
      await DatabaseHelper().insertTransaction(updatedTransaction);
    }
  }
}

class SmsService {
  final Telephony telephony = Telephony.instance;

  Future<void> scanSmsSinceLastUse({int fallbackDays = 7}) async {
    if (!Platform.isAndroid) return;

    final db = DatabaseHelper();
    final now = DateTime.now();
    final previousLastUsed = await db.getLastUsedDateTime();
    final fromDate = previousLastUsed ?? now.subtract(Duration(days: fallbackDays));

    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      await _scanAndPersistFrom(fromDate);
      await db.setLastUsedDateTime(now);
    }
  }

  Future<void> initSmsListener() async {
    if (!Platform.isAndroid) {
      debugPrint('SMS tracking is only supported on Android. Service disabled for this platform.');
      return;
    }

    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          // Handle foreground message
          if (message.body != null) {
            final parser = SmsParser();
            final transaction = await parser.parseSms(message.body!, sender: message.address);
            if (transaction != null) {
              debugPrint('Parsed a valid foreground transaction');
              final actualDate = message.date != null ? DateTime.fromMillisecondsSinceEpoch(message.date!) : transaction.date;
              final updatedTransaction = Transaction(
                id: transaction.id,
                amount: transaction.amount,
                type: transaction.type,
                merchant: transaction.merchant,
                date: actualDate,
                category: transaction.category,
                rawText: transaction.rawText,
                referenceNumber: transaction.referenceNumber,
                bankName: transaction.bankName,
              );
              await DatabaseHelper().insertTransaction(updatedTransaction);
            }
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    } else {
      debugPrint('SMS permissions not granted by the user.');
    }
  }

  Future<void> scanHistoricalSms({int days = 7}) async {
    if (!Platform.isAndroid) return;

    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      final fromDate = DateTime.now().subtract(Duration(days: days));
      await _scanAndPersistFrom(fromDate);
    }
  }

  Future<void> _scanAndPersistFrom(DateTime fromDate) async {
    final cutoffDate = fromDate.millisecondsSinceEpoch;
    final messages = await telephony.getInboxSms(
      columns: [SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ADDRESS],
      filter: SmsFilter.where(SmsColumn.DATE).greaterThan(cutoffDate.toString()),
    );

    for (var message in messages) {
      if (message.body == null) continue;

      final parser = SmsParser();
      final transaction = await parser.parseSms(message.body!, sender: message.address);
      if (transaction == null) continue;

      final actualDate = message.date != null ? DateTime.fromMillisecondsSinceEpoch(message.date!) : transaction.date;

      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: transaction.amount,
        type: transaction.type,
        merchant: transaction.merchant,
        date: actualDate,
        category: transaction.category,
        rawText: transaction.rawText,
        referenceNumber: transaction.referenceNumber,
        bankName: transaction.bankName,
      );

      await DatabaseHelper().insertTransaction(updatedTransaction);
    }
  }
}
