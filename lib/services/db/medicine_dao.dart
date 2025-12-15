import '../../models/medicine_model.dart';
import 'sqlite_service.dart';

/// Medicine Data Access Object (DAO)
/// Handles all database operations for medicines
class MedicineDAO {
  final SQLiteService _dbService = SQLiteService();

  /// Get all medicines
  Future<List<Medicine>> getAllMedicines() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('medicines');
    return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
  }

  /// Get medicine by ID
  Future<Medicine?> getMedicineById(int id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Medicine.fromMap(maps.first);
  }

  /// Insert a new medicine
  Future<int> insertMedicine(Medicine medicine) async {
    final db = await _dbService.database;
    return await db.insert('medicines', medicine.toMap());
  }

  /// Update an existing medicine
  Future<int> updateMedicine(Medicine medicine) async {
    final db = await _dbService.database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  /// Delete a medicine
  Future<int> deleteMedicine(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get medicines for today's schedule
  Future<List<Medicine>> getMedicinesForToday() async {
    final db = await _dbService.database;
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0]; // Get YYYY-MM-DD format

    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      where: 'date(startDate) <= ? AND date(endDate) >= ?',
      whereArgs: [todayStr, todayStr],
    );
    return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
  }

  /// Update medicine stock count
  Future<int> updateStockCount(int id, int stockCount) async {
    final db = await _dbService.database;
    return await db.update(
      'medicines',
      {'stockCount': stockCount, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

