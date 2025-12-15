import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// SQLite Database Service
/// Handles database initialization and provides database instance
class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  static Database? _database;

  factory SQLiteService() {
    return _instance;
  }

  SQLiteService._internal();

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  /// Creates database file and tables if they don't exist
  Future<Database> _initDatabase() async {
    // Get the directory path for storing the database
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'medicine_reminder.db');

    // Open/create the database
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  /// Called when database is first created
  Future<void> _onCreate(Database db, int version) async {
    // Medicines table
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        frequencyUnit TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        reminderTimes TEXT NOT NULL,
        notes TEXT,
        iconColor INTEGER NOT NULL,
        stockCount INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Schedules table
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineId INTEGER NOT NULL,
        scheduledDate TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        takenAt TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (medicineId) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // History table
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineId INTEGER NOT NULL,
        scheduleId INTEGER NOT NULL,
        scheduledDate TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        status TEXT NOT NULL,
        takenAt TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (medicineId) REFERENCES medicines (id) ON DELETE CASCADE,
        FOREIGN KEY (scheduleId) REFERENCES schedules (id) ON DELETE CASCADE
      )
    ''');

    // Users table (for local user data)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        email TEXT,
        fullName TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  /// Handle database upgrades
  /// Called when database version changes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future database migrations here
    // For now, we'll just recreate tables if needed
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

