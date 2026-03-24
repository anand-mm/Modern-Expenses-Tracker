import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../merchant_mapping/screens/merchant_mapping_screen.dart';
import '../../statement_import/screens/statement_import_screen.dart';
import '../../category_management/screens/manage_categories_screen.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_event.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/modern_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  final void Function(DateTime month)? onImportSuccess;

  const SettingsScreen({super.key, this.onImportSuccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text('General', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Manage Merchants'),
            subtitle: const Text('Map raw SMS names to clean merchant names'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const MerchantMappingScreen()),
              ).then((_) {
                if (context.mounted) {
                  context.read<DashboardBloc>().add(LoadTransactions());
                }
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add, rename, or delete tracking categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
              ).then((_) {
                if (context.mounted) {
                  context.read<DashboardBloc>().add(LoadTransactions());
                }
              });
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text('Data Management', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Statement'),
            subtitle: const Text('Import transactions from a bank statement file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatementImportScreen(
                    onImportSuccess: onImportSuccess,
                  ),
                ),
              ).then((_) {
                if (context.mounted && onImportSuccess == null) {
                  context.read<DashboardBloc>().add(LoadTransactions());
                }
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Scan SMS (Last 7 Days)'),
            subtitle: const Text('Manually trigger an SMS scan for recent transactions'),
            onTap: () {
              context.read<DashboardBloc>().add(ScanHistoricalSms(days: 7));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning last 7 days...')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('Scan SMS (Last 30 Days)'),
            subtitle: const Text('Deep scan for older transactions'),
            onTap: () {
              context.read<DashboardBloc>().add(ScanHistoricalSms(days: 30));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deep scanning last 30 days...')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data (CSV)'),
            subtitle: const Text('Download your transaction history as a CSV file'),
            onTap: () async {
              final csv = await DatabaseHelper().exportTransactionsToCsv();
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/transactions_export.csv');
              await file.writeAsString(csv);
              
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(file.path)], 
                  subject: 'Expense Tracker Export',
                  sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Database'),
            subtitle: const Text('Save your raw database file locally or to Drive'),
            onTap: () async {
               final dbPath = await DatabaseHelper().getDatabasePath();
               if (context.mounted) {
                 final box = context.findRenderObject() as RenderBox?;
                 await Share.shareXFiles(
                   [XFile(dbPath, name: 'expenses_backup.db')],
                   subject: 'Expense Tracker Database Backup',
                   sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                 );
               }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Database'),
            subtitle: const Text('Restore from a previously exported database file'),
            onTap: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                   type: FileType.any,
                );
                
                if (result != null && result.files.single.path != null) {
                   final success = await DatabaseHelper().restoreDatabase(result.files.single.path!);
                   if (context.mounted) {
                       if (success) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database restored successfully!')));
                           context.read<DashboardBloc>().add(LoadTransactions());
                       } else {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid database file. Please select a valid .db backup.')));
                       }
                   }
                }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text('Danger Zone', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Wipe all transactions and settings. This cannot be undone.', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
               showDialog(
                 context: context,
                 builder: (dialogContext) => AlertDialog(
                   title: const Text('Wipe Database?'),
                   content: const Text('Are you unconditionally sure you want to delete all your tracked expenses? This action is permanent and cannot be reversed.'),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                       onPressed: () async {
                         await DatabaseHelper().clearAllData();
                         if (context.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database completely wiped.')));
                         }
                         if (context.mounted) {
                            context.read<DashboardBloc>().add(LoadTransactions());
                         }
                       },
                       child: const Text('Nuclear Wipe', style: TextStyle(color: Colors.white)),
                     ),
                   ],
                 )
               );
            },
          ),
          if (kDebugMode) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text('Developer Options', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.red),
              title: const Text('Load Sample Data', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Populates database with mock transactions'),
              onTap: () {
                context.read<DashboardBloc>().add(LoadDummyData());
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading sample data...')));
              },
            ),
          ],
        ],
      ),
    );
  }
}
