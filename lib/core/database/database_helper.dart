import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/transaction.dart' as model;
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final defaultPath = await getDatabasesPath();
    final dbPath = join(defaultPath, 'expenses.db');

    return await openDatabase(dbPath, version: 6, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN referenceNumber TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE merchant_mappings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          raw_name TEXT NOT NULL UNIQUE,
          friendly_name TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE transactions ADD COLUMN bankName TEXT DEFAULT 'Unknown'");
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_metadata(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_mappings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          merchant_name TEXT NOT NULL UNIQUE,
          category TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        merchant TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        rawText TEXT NOT NULL,
        referenceNumber TEXT,
        bankName TEXT NOT NULL DEFAULT 'Unknown'
      )
    ''');

    await db.execute('''
      CREATE TABLE merchant_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_name TEXT NOT NULL UNIQUE,
        friendly_name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_metadata(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE category_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_name TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;

    // Check if a transaction with the same reference number exists
    if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
      final List<Map<String, dynamic>> existingByRef = await db.query(
        'transactions',
        where: 'referenceNumber = ?',
        whereArgs: [transaction.referenceNumber],
        limit: 1,
      );

      if (existingByRef.isNotEmpty) {
        return existingByRef.first['id'] as int;
      }
    }

    // Fallback: Check if a transaction with the same rawText and date already exists
    // to prevent duplicates from multiple SMS scans if no reference number was found
    final List<Map<String, dynamic>> existing = await db.query(
      'transactions',
      where: 'rawText = ? AND date = ?',
      whereArgs: [transaction.rawText, transaction.date.toIso8601String()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Return the ID of the existing transaction
      return existing.first['id'] as int;
    }

    return await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<model.Transaction>> getTransactionsForMonth(int year, int month) async {
    final db = await database;

    // Create start and end dates for the month
    final startOfMonth = DateTime(year, month, 1).toIso8601String();

    // Calculate the start of the next month
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final startOfNextMonth = DateTime(nextYear, nextMonth, 1).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfMonth, startOfNextMonth],
      orderBy: 'date DESC',
    );

    return List<model.Transaction>.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<List<String>> getUniqueRawMerchants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      columns: ['merchant'],
      distinct: true,
      orderBy: 'merchant ASC',
    );

    return maps.map((map) => map['merchant'] as String).toList();
  }

  Future<List<model.Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    return List<model.Transaction>.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<int> updateTransactionMerchant(int id, String newMerchant) async {
    final db = await database;
    return await db.update('transactions', {'merchant': newMerchant}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateAllTransactionsMerchantByRawPattern(String rawPattern, String friendlyName) async {
    final db = await database;
    // Fetch all transactions and update those whose merchant contains the raw pattern
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    int updatedCount = 0;
    for (final row in maps) {
      final merchant = row['merchant'] as String? ?? '';
      if (merchant.toUpperCase().contains(rawPattern.toUpperCase())) {
        await db.update(
          'transactions',
          {'merchant': friendlyName},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        updatedCount++;
      }
    }
    return updatedCount;
  }

  // --- Merchant Mappings CRUD ---

  Future<int> insertMerchantMapping(String rawName, String friendlyName) async {
    final db = await database;
    return await db.insert('merchant_mappings', {
      'raw_name': rawName,
      'friendly_name': friendlyName,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllMerchantMappings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('merchant_mappings');

    final Map<String, String> mappings = {};
    for (var map in maps) {
      mappings[map['raw_name'] as String] = map['friendly_name'] as String;
    }
    return mappings;
  }

  Future<int> deleteMerchantMapping(int id) async {
    final db = await database;
    return await db.delete('merchant_mappings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMerchantMappingByRawName(String rawName) async {
    final db = await database;
    return await db.delete('merchant_mappings', where: 'raw_name = ?', whereArgs: [rawName]);
  }

  Future<void> setAppMetadata(String key, String value) async {
    final db = await database;
    await db.insert('app_metadata', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getAppMetadata(String key) async {
    final db = await database;
    final results = await db.query('app_metadata', where: 'key = ?', whereArgs: [key], limit: 1);
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  Future<void> setLastUsedDateTime(DateTime value) async {
    await setAppMetadata('last_used_datetime', value.toIso8601String());
  }

  Future<DateTime?> getLastUsedDateTime() async {
    final raw = await getAppMetadata('last_used_datetime');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // --- Category Mappings CRUD & Transaction Updates ---

  Future<int> insertCategoryMapping(String merchantName, String category) async {
    final db = await database;
    return await db.insert('category_mappings', {
      'merchant_name': merchantName,
      'category': category,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllCategoryMappings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('category_mappings');

    final Map<String, String> mappings = {};
    for (var map in maps) {
      mappings[map['merchant_name'] as String] = map['category'] as String;
    }
    return mappings;
  }

  Future<int> updateTransactionCategory(int id, String newCategory) async {
    final db = await database;
    return await db.update('transactions', {'category': newCategory}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateAllTransactionsCategoryByMerchant(String merchant, String category) async {
    final db = await database;
    return await db.update('transactions', {'category': category}, where: 'merchant = ?', whereArgs: [merchant]);
  }

  // --- Custom Categories CRUD ---
  
  static const String _categoriesKey = 'custom_categories';
  static const List<String> _defaultCategories = ['Food & Dining', 'Transport', 'Utilities & Bills', 'Shopping', 'Health', 'Entertainment', 'Transfers'];

  Future<List<String>> getCategories() async {
    final raw = await getAppMetadata(_categoriesKey);
    if (raw == null) {
      return List.from(_defaultCategories);
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return List.from(_defaultCategories);
    }
  }

  Future<void> addCategory(String category) async {
    final categories = await getCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      await setAppMetadata(_categoriesKey, jsonEncode(categories));
    }
  }

  Future<void> renameCategory(String oldCategory, String newCategory) async {
    final categories = await getCategories();
    final index = categories.indexOf(oldCategory);
    if (index != -1) {
      categories[index] = newCategory;
      await setAppMetadata(_categoriesKey, jsonEncode(categories));
      
      final db = await database;
      await db.update('transactions', {'category': newCategory}, where: 'category = ?', whereArgs: [oldCategory]);
      await db.update('category_mappings', {'category': newCategory}, where: 'category = ?', whereArgs: [oldCategory]);
    }
  }

  Future<void> deleteCategory(String category) async {
    final categories = await getCategories();
    if (categories.contains(category)) {
      categories.remove(category);
      await setAppMetadata(_categoriesKey, jsonEncode(categories));
      
      final db = await database;
      await db.update('transactions', {'category': 'Uncategorized'}, where: 'category = ?', whereArgs: [category]);
      await db.update('category_mappings', {'category': 'Uncategorized'}, where: 'category = ?', whereArgs: [category]);
    }
  }

  // --- Enhanced Data Management ---

  Future<String> exportTransactionsToCsv() async {
    final transactions = await getAllTransactions();
    final buffer = StringBuffer();
    buffer.writeln('ID,Amount,Type,Merchant,Date,Category,RawText,ReferenceNumber,BankName');
    for (final tx in transactions) {
      String escape(String? val) {
        if (val == null) return '';
        final s = val.replaceAll('"', '""');
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"$s"';
        }
        return s;
      }
      buffer.writeln('${tx.id},${tx.amount},${escape(tx.type.name)},${escape(tx.merchant)},${tx.date.toIso8601String()},${escape(tx.category)},${escape(tx.rawText)},${escape(tx.referenceNumber)},${escape(tx.bankName)}');
    }
    return buffer.toString();
  }

  Future<String> getDatabasePath() async {
    final defaultPath = await getDatabasesPath();
    return join(defaultPath, 'expenses.db');
  }

  Future<bool> restoreDatabase(String backupPath) async {
    try {
      final File backupFile = File(backupPath);
      
      if (!await backupFile.exists()) return false;
      final randomAccessFile = await backupFile.open();
      final header = await randomAccessFile.read(16);
      await randomAccessFile.close();
      
      final headerString = String.fromCharCodes(header);
      if (headerString != 'SQLite format 3\u0000') {
         return false; // Not a valid SQLite database
      }

      final dbPath = await getDatabasePath();
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      await backupFile.copy(dbPath);
      _database = await _initDb();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('merchant_mappings');
    await db.delete('category_mappings');
    await db.delete('app_metadata');
  }
}
