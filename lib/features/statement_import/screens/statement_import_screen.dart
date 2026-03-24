import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/statement_source.dart';
import '../services/parser_factory.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_event.dart';
import '../../../core/database/database_helper.dart';

class StatementImportScreen extends StatefulWidget {
  final void Function(DateTime month)? onImportSuccess;

  const StatementImportScreen({super.key, this.onImportSuccess});

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  StatementSource? _selectedSource;
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _pickAndParseFile() async {
    if (_selectedSource == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Parsing statement...';
      });

      try {
        final parser = ParserFactory.getParser(_selectedSource!);
        final transactions = await parser.parseFile(result.files.single.path!);

        if (transactions.isNotEmpty) {
          // Import them into the database
          final db = DatabaseHelper();
          for (var t in transactions) {
            await db.insertTransaction(t);
          }
          if (mounted) {
            transactions.sort((a, b) => b.date.compareTo(a.date));
            final recentDate = transactions.first.date;
            final importedMonth = DateTime(recentDate.year, recentDate.month, 1);
            context.read<DashboardBloc>().add(ChangeMonth(month: importedMonth));

            // Redirect to Dashboard filtered to the imported month
            if (widget.onImportSuccess != null) {
              Navigator.of(context).pop();
              widget.onImportSuccess!(importedMonth);
            } else {
              setState(() {
                _statusMessage = 'Successfully imported ${transactions.length} transactions.';
                _isProcessing = false;
              });
            }
          }
        } else {
          setState(() {
             _statusMessage = 'No transactions found in this file.';
             _isProcessing = false;
          });
        }
      } catch (e) {
        setState(() {
           _statusMessage = 'Failed to parse file: $e';
           _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Statement'),
        backgroundColor: const Color(0xFF0F2027),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where is this statement from?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the source to help us parse the file correctly.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: StatementSource.values.length,
                itemBuilder: (context, index) {
                  final source = StatementSource.values[index];
                  final isSelected = _selectedSource == source;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSource = source;
                        _statusMessage = null; // reset
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? source.brandColor.withOpacity(0.1) : Colors.white,
                        border: Border.all(
                          color: isSelected ? source.brandColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance, size: 40, color: source.brandColor), // Assuming icon
                          const SizedBox(height: 12),
                          Text(
                            source.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? source.brandColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_statusMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: _statusMessage!.contains('Successfully') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedSource == null || _isProcessing ? null : _pickAndParseFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedSource?.brandColor ?? Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _statusMessage != null && _statusMessage!.contains('Successfully') 
                          ? 'Import Another File' 
                          : 'Pick CSV/PDF File', 
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
