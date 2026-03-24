import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/dashboard/bloc/dashboard_event.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isMostUsedMerchantTxn;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.isMostUsedMerchantTxn = false,
  });

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isMostUsedMerchantTxn ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMostUsedMerchantTxn ? const Color(0xFF7DD3FC) : Colors.grey.shade100,
          width: isMostUsedMerchantTxn ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTransactionDetails(context, transaction, currencyFormat),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: transaction.type == TransactionType.debit ? Colors.red.shade50 : Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    transaction.type == TransactionType.debit ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                    color: transaction.type == TransactionType.debit ? Colors.red.shade400 : Colors.green.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchant,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            DateFormat('MMM d, h:mm a').format(transaction.date),
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (transaction.category == 'Uncategorized')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Add Category', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          if (transaction.bankName != 'Unknown')
                            _buildBankLogo(transaction.bankName),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatSignedAmount(currencyFormat, transaction),
                      style: TextStyle(
                        color: transaction.type == TransactionType.debit ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSignedAmount(NumberFormat format, Transaction t) {
    final prefix = t.type == TransactionType.debit ? '- ' : '+ ';
    return '$prefix${format.format(t.amount)}';
  }

  Widget _buildBankLogo(String bankName) {
    final Map<String, Color> bankColors = {
      'HDFC': const Color(0xFF004C8F),
      'SBI': const Color(0xFF008CC4),
      'ICICI': const Color(0xFFB02A30),
      'Axis': const Color(0xFFAF2047),
      'Kotak': const Color(0xFFED1C24),
      'BOB': const Color(0xFFF1592A),
      'TMB': const Color(0xFFF37021),
      'PNB': const Color(0xFFA32020),
    };

    final color = bankColors[bankName] ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(
        bankName.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction t, NumberFormat currencyFormat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Transaction Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _detailRow('Amount', _formatSignedAmount(currencyFormat, t)),
              _detailRow('Date', DateFormat.yMMMd().add_jm().format(t.date)),
              _detailRow('Merchant', t.merchant),
              _detailRow('Type', t.type == TransactionType.credit ? 'Credit' : 'Debit'),
              _detailRowWithEdit(context, 'Category', t.category, () => _showCategoryPicker(context, t)),
              if (t.bankName != 'Unknown') _detailRow('Bank', t.bankName),
              if (t.referenceNumber != null) _detailRow('Ref No', t.referenceNumber!),
              const SizedBox(height: 16),
              const Text('Raw SMS', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(t.rawText, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _detailRowWithEdit(BuildContext context, String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit, size: 18, color: Colors.teal),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, Transaction t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        final categories = ['Food & Dining', 'Transport', 'Utilities & Groceries', 'Shopping', 'Health', 'Income', 'Transfer', 'Entertainment', 'Housing', 'Travel', 'Uncategorized'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (listContext, index) {
                    return ListTile(
                      title: Text(categories[index]),
                      trailing: t.category == categories[index] ? const Icon(Icons.check, color: Colors.teal) : null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _confirmCategoryChange(context, t, categories[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmCategoryChange(BuildContext context, Transaction t, String newCategory) {
    if (t.category == newCategory) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Category'),
          content: Text('Do you want to categorize all future and past transactions from "${t.merchant}" as $newCategory?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close details sheet
                context.read<DashboardBloc>().add(
                  UpdateTransactionCategory(
                    transactionId: t.id!,
                    merchant: t.merchant,
                    newCategory: newCategory,
                    applyToAll: false,
                  )
                );
              },
              child: const Text('Only This One'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close details sheet
                context.read<DashboardBloc>().add(
                  UpdateTransactionCategory(
                    transactionId: t.id!,
                    merchant: t.merchant,
                    newCategory: newCategory,
                    applyToAll: true,
                  )
                );
              },
              child: const Text('Yes, Update All'),
            ),
          ],
        );
      },
    );
  }
}
