import '../../models/histroy_model.dart';
import 'sqlite_service.dart';

/// History Data Access Object (DAO)
/// Handles all database operations for history entries
class HistoryDAO {
  final SQLiteService _dbService = SQLiteService();

  /// Get all history entries
  Future<List<History>> getAllHistory() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'history',
      orderBy: 'scheduledDate DESC, scheduledTime DESC',
    );
    return List.generate(maps.length, (i) => History.fromMap(maps[i]));
  }

  /// Get history by status (taken, missed, or all)
  Future<List<History>> getHistoryByStatus(String status) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'history',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'scheduledDate DESC, scheduledTime DESC',
    );
    return List.generate(maps.length, (i) => History.fromMap(maps[i]));
  }

  /// Get history for a specific date
  Future<List<History>> getHistoryByDate(DateTime date) async {
    final db = await _dbService.database;
    final dateStr = date.toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'history',
      where: 'date(scheduledDate) = ?',
      whereArgs: [dateStr],
      orderBy: 'scheduledTime DESC',
    );
    return List.generate(maps.length, (i) => History.fromMap(maps[i]));
  }

  /// Insert a new history entry
  Future<int> insertHistory(History history) async {
    final db = await _dbService.database;
    return await db.insert('history', history.toMap());
  }

  /// Update history entry status
  Future<int> updateHistoryStatus(int id, String status, DateTime? takenAt) async {
    final db = await _dbService.database;
    return await db.update(
      'history',
      {
        'status': status,
        'takenAt': takenAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a history entry
  Future<int> deleteHistory(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get history grouped by date
  Future<Map<String, List<History>>> getHistoryGroupedByDate() async {
    final allHistory = await getAllHistory();
    final Map<String, List<History>> grouped = {};

    for (var entry in allHistory) {
      final dateKey = entry.scheduledDate.toIso8601String().split('T')[0];
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(entry);
    }

    return grouped;
  }
}

