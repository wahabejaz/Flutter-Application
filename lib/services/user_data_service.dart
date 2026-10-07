import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';

class UserDataService {
  final SQLiteService _dbService;
  final Future<void> Function() _cancelAllNotifications;

  UserDataService({
    SQLiteService? dbService,
    Future<void> Function()? cancelAllNotifications,
  })  : _dbService = dbService ?? SQLiteService(),
        _cancelAllNotifications = cancelAllNotifications ??
            NotificationService().cancelAllNotifications;

  Future<void> clearCurrentUserData(String uid) async {
    await _cancelAllNotifications();
    final db = await _dbService.database;

    await db.transaction((transaction) async {
      final medicines = await transaction.query(
        'medicines',
        columns: ['id'],
        where: 'uid = ?',
        whereArgs: [uid],
      );
      final medicineIds = medicines.map((row) => row['id'] as int).toList();

      for (final medicineId in medicineIds) {
        await transaction.delete(
          'history',
          where: 'medicineId = ?',
          whereArgs: [medicineId],
        );
        await transaction.delete(
          'schedules',
          where: 'medicineId = ?',
          whereArgs: [medicineId],
        );
      }

      await transaction.delete(
        'medicines',
        where: 'uid = ?',
        whereArgs: [uid],
      );
      await transaction.delete(
        'users',
        where: 'uid = ?',
        whereArgs: [uid],
      );
    });
  }
}