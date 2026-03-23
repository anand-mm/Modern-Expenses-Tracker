import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/modern_app_bar.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await _dbHelper.getCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _dbHelper.addCategory(name);
                if (context.mounted) Navigator.pop(context);
                _loadCategories();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldCategory) {
    if (oldCategory == 'Uncategorized') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot modify system fallback category')));
       return;
    }
    final controller = TextEditingController(text: oldCategory);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != oldCategory) {
                await _dbHelper.renameCategory(oldCategory, name);
                if (context.mounted) Navigator.pop(context);
                _loadCategories();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String category) {
    if (category == 'Uncategorized') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot modify system fallback category')));
       return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$category"? All associated transactions will be marked as Uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _dbHelper.deleteCategory(category);
              if (context.mounted) Navigator.pop(context);
              _loadCategories();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: Text('Categories'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isReadOnly = category == 'Uncategorized';
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2C5364),
                    child: Icon(Icons.category, color: Colors.white, size: 20),
                  ),
                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: isReadOnly ? null : PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'rename') _showRenameDialog(category);
                      if (val == 'delete') _showDeleteDialog(category);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        backgroundColor: const Color(0xFF203A43),
      ),
    );
  }
}
