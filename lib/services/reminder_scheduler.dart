import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/models/schedule_model.dart';
import 'package:medicine_reminder_app/models/histroy_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';
import 'package:flutter/material.dart';

/// Reminder Scheduler Service
/// Handles scheduling reminders for medicines and creating schedule entries
class ReminderScheduler {
  final NotificationService _notificationService;
  final SQLiteService _dbService = SQLiteService();

  ReminderScheduler({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  /// Schedule reminders for a medicine
  /// Creates daily repeating notifications and schedule entries for upcoming days
  Future<void> scheduleMedicineReminders(Medicine medicine) async {
    // Cancel any existing notifications for this medicine first
    await cancelMedicineReminders(medicine.id!);

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

    // Schedule daily repeating notifications for each reminder time
    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final timeStr = medicine.reminderTimes[i];
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final timeOfDay = TimeOfDay(hour: hour, minute: minute);

      // Generate unique notification ID for this medicine and time
      final notificationId = medicine.id! * 100 + i;

      try {
        await _notificationService.scheduleDailyMedicineReminder(
          id: notificationId,
          title: 'Medicine Reminder 💊',
          body: 'It\'s time to take ${medicine.name}',
          time: timeOfDay,
        );
      } catch (e) {
        // Log the error but continue with other reminders
        // This prevents one failed reminder from blocking others
        debugPrint('Failed to schedule reminder for ${medicine.name} at ${timeStr}: $e');
      }
    }

    // Create schedule entries for the next 7 days (to allow marking as taken/missed)
    final db = await _dbService.database;
    for (var timeStr in medicine.reminderTimes) {
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      var currentDate = effectiveStartDate;
      final endScheduleDate = endDate.isBefore(today.add(const Duration(days: 7)))
          ? endDate
          : today.add(const Duration(days: 7));

      while (currentDate.isBefore(endScheduleDate) ||
             currentDate.isAtSameMomentAs(endScheduleDate)) {
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
          whereArgs: [medicine.id!, dateStr, timeStr],
        );

        if (existing.isEmpty) {
          // Create schedule entry
          final schedule = Schedule(
            medicineId: medicine.id!,
            scheduledDate: scheduleDateTime,
            scheduledTime: timeStr,
            status: scheduleDateTime.isBefore(now) ? 'missed' : 'pending',
            createdAt: DateTime.now(),
          );

          // Insert schedule into database
          await db.insert('schedules', schedule.toMap());
        }

        // Move to next day
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
  }

  /// Cancel all reminders for a medicine
  Future<void> cancelMedicineReminders(int medicineId) async {
    // Cancel daily repeating notifications
    // Assuming up to 10 reminder times per medicine
    for (int i = 0; i < 10; i++) {
      final notificationId = medicineId * 100 + i;
      try {
        await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        // Continue canceling others
      }
    }

    // Delete schedule entries
    final db = await _dbService.database;
    await db.delete('schedules', where: 'medicineId = ?', whereArgs: [medicineId]);
  }

  /// Check and cancel reminders for expired medicines
  Future<void> cancelExpiredReminders() async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // Get all medicines that have ended
    final expiredMedicines = await db.query(
      'medicines',
      where: 'endDate < ?',
      whereArgs: [now.toIso8601String()],
    );

    for (var medicineMap in expiredMedicines) {
      final medicineId = medicineMap['id'] as int;
      await cancelMedicineReminders(medicineId);
    }
  }

  /// Refresh schedule entries for upcoming days
  Future<void> refreshUpcomingSchedules() async {
    final db = await _dbService.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureDate = today.add(const Duration(days: 7));

    // Get all active medicines
    final activeMedicines = await db.query(
      'medicines',
      where: 'endDate >= ?',
      whereArgs: [now.toIso8601String()],
    );

    for (var medicineMap in activeMedicines) {
      final medicine = Medicine.fromMap(medicineMap);

      for (var timeStr in medicine.reminderTimes) {
        final timeParts = timeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        var currentDate = today;
        while (currentDate.isBefore(futureDate)) {
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
            whereArgs: [medicine.id!, dateStr, timeStr],
          );

          if (existing.isEmpty) {
            // Create schedule entry
            final schedule = Schedule(
              medicineId: medicine.id!,
              scheduledDate: scheduleDateTime,
              scheduledTime: timeStr,
              status: scheduleDateTime.isBefore(now) ? 'missed' : 'pending',
              createdAt: DateTime.now(),
            );

            // Insert schedule into database
            await db.insert('schedules', schedule.toMap());
          }

          // Move to next day
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }
  }

  /// Reschedule all notifications for active medicines
  /// This should be called when the app starts to ensure notifications are active
  Future<void> rescheduleAllNotifications() async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // Get all active medicines (not expired)
    final activeMedicines = await db.query(
      'medicines',
      where: 'endDate >= ?',
      whereArgs: [now.toIso8601String()],
    );

    for (var medicineMap in activeMedicines) {
      final medicine = Medicine.fromMap(medicineMap);
      await scheduleMedicineReminders(medicine);
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

  /// Mark all overdue pending schedules as missed
  /// This should be called when the app starts to ensure missed doses are properly recorded
  Future<void> markOverdueSchedulesAsMissed() async {
    final db = await _dbService.database;
    final now = DateTime.now();
    const gracePeriod = Duration(minutes: 30);

    // Get all pending schedules that are overdue (past grace period)
    // Use Dart DateTime logic instead of SQLite datetime functions for timezone safety
    final pendingSchedules = await db.rawQuery('''
      SELECT s.*, m.uid
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE s.status = 'pending'
    ''');

    for (final scheduleMap in pendingSchedules) {
      final scheduledDateStr = scheduleMap['scheduledDate'] as String;
      final scheduledTimeStr = scheduleMap['scheduledTime'] as String;
      
      // Parse the stored ISO date string
      final scheduledDate = DateTime.parse(scheduledDateStr);
      
      // Construct the full scheduled DateTime using the stored date and time
      final timeParts = scheduledTimeStr.split(':');
      final scheduledHour = int.parse(timeParts[0]);
      final scheduledMinute = int.parse(timeParts[1]);
      
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledHour,
        scheduledMinute,
      );

      // Mark as missed only if now is after scheduled time + grace period
      if (now.isAfter(scheduledDateTime.add(gracePeriod))) {
        final scheduleId = scheduleMap['id'] as int;
        final medicineId = scheduleMap['medicineId'] as int;
        await markAsMissed(scheduleId, medicineId);
      }
    }
  }
}

