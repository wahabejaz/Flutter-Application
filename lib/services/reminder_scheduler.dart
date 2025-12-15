import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/models/schedule_model.dart';
import 'package:medicine_reminder_app/models/histroy_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';

/// Reminder Scheduler Service
/// Handles scheduling reminders for medicines and creating schedule entries
class ReminderScheduler {
  final NotificationService _notificationService = NotificationService();
  final SQLiteService _dbService = SQLiteService();

  /// Schedule reminders for a medicine
  /// Creates schedule entries and sets up notifications
  Future<void> scheduleMedicineReminders(Medicine medicine) async {
    final now = DateTime.now();
    final startDate = medicine.startDate;
    final endDate = medicine.endDate;

    // Only schedule if medicine is active (between start and end date)
    if (now.isAfter(endDate)) {
      return; // Medicine period has ended
    }

    // Get the effective start date (today if medicine already started)
    final today = DateTime(now.year, now.month, now.day);
    final effectiveStartDate = startDate.isBefore(today) ? today : startDate;

    // Create schedule entries for each reminder time
    for (var timeStr in medicine.reminderTimes) {
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final db = await _dbService.database;
      
      // Schedule for each day from effective start date to end date
      var currentDate = effectiveStartDate;
      
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        // Create schedule for this date and time
        final scheduleDateTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          hour,
          minute,
        );
        
        // Check if schedule already exists
        final dateStr = currentDate.toIso8601String().split('T')[0];
        final existing = await db.query(
          'schedules',
          where: 'medicineId = ? AND date(scheduledDate) = ? AND scheduledTime = ?',
          whereArgs: [
            medicine.id!,
            dateStr,
            timeStr,
          ],
        );

        if (existing.isEmpty) {
          // Create schedule entry
          final schedule = Schedule(
            medicineId: medicine.id!,
            scheduledDate: scheduleDateTime,
            scheduledTime: timeStr,
            status: 'pending',
            createdAt: DateTime.now(),
          );

          // Insert schedule into database
          final scheduleId = await db.insert('schedules', schedule.toMap());

          // Schedule notification (only for future dates/times)
          if (scheduleDateTime.isAfter(now)) {
            try {
              await _notificationService.scheduleNotification(
                id: scheduleId,
                title: 'Medicine Reminder',
                body: 'Time to take ${medicine.name} (${medicine.dosage})',
                scheduledDate: scheduleDateTime,
              );
            } catch (e) {
              // Notification scheduling might fail on web, continue anyway
            }
          }
        }

        // Move to next day
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
  }

  /// Cancel all reminders for a medicine
  Future<void> cancelMedicineReminders(int medicineId) async {
    final db = await _dbService.database;
    
    // Get all schedules for this medicine
    final schedules = await db.query(
      'schedules',
      where: 'medicineId = ? AND status = ?',
      whereArgs: [medicineId, 'pending'],
    );

    // Cancel notifications and delete schedules
    for (var scheduleMap in schedules) {
      final scheduleId = scheduleMap['id'] as int;
      await _notificationService.cancelNotification(scheduleId);
      await db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
    }
  }

  /// Mark a schedule as taken
  Future<void> markAsTaken(int scheduleId, int medicineId) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // Update schedule status
    await db.update(
      'schedules',
      {
        'status': 'taken',
        'takenAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    // Get schedule details
    final scheduleMaps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    if (scheduleMaps.isNotEmpty) {
      final schedule = Schedule.fromMap(scheduleMaps.first);

      // Create history entry
      final history = History(
        medicineId: medicineId,
        scheduleId: scheduleId,
        scheduledDate: schedule.scheduledDate,
        scheduledTime: schedule.scheduledTime,
        status: 'taken',
        takenAt: now,
        createdAt: now,
      );

      await db.insert('history', history.toMap());

      // Decrement stock count
      await db.rawUpdate(
        'UPDATE medicines SET stockCount = stockCount - 1 WHERE id = ? AND stockCount > 0',
        [medicineId],
      );

      // Check if stock is low and send notification
      final medicineResult = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
      );

      if (medicineResult.isNotEmpty) {
        final medicine = Medicine.fromMap(medicineResult.first);
        if (medicine.stockCount <= 5 && medicine.stockCount > 0) {
          // Send low stock notification
          try {
            await _notificationService.scheduleNotification(
              id: medicineId + 10000, // Use different ID range for stock notifications
              title: 'Low Stock Alert',
              body: '${medicine.name} has only ${medicine.stockCount} ${medicine.stockCount == 1 ? 'tablet' : 'tablets'} remaining',
              scheduledDate: DateTime.now().add(const Duration(seconds: 1)), // Show immediately
            );
          } catch (e) {
            // Notification might fail on web, continue anyway
          }
        }
      }
    }
  }

  /// Mark a schedule as missed
  Future<void> markAsMissed(int scheduleId, int medicineId) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // Update schedule status
    await db.update(
      'schedules',
      {
        'status': 'missed',
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    // Get schedule details
    final scheduleMaps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    if (scheduleMaps.isNotEmpty) {
      final schedule = Schedule.fromMap(scheduleMaps.first);

      // Create history entry
      final history = History(
        medicineId: medicineId,
        scheduleId: scheduleId,
        scheduledDate: schedule.scheduledDate,
        scheduledTime: schedule.scheduledTime,
        status: 'missed',
        createdAt: now,
      );

      await db.insert('history', history.toMap());
    }
  }
}

