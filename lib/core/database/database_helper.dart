import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;

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

    return await openDatabase(dbPath, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
}
