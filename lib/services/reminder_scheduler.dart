import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/models/schedule_model.dart';
import 'package:medicine_reminder_app/models/histroy_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';
import 'package:medicine_reminder_app/services/schedule_planner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

/// Reminder Scheduler Service
/// Handles scheduling reminders for medicines and creating schedule entries
class ReminderScheduler {
  final NotificationService _notificationService;
  final SQLiteService _dbService = SQLiteService();

  ReminderScheduler({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  /// Schedule notifications and local schedule rows for an active medicine.
  Future<void> scheduleMedicineReminders(Medicine medicine) async {
    final medicineId = medicine.id;
    if (medicineId == null) throw ArgumentError('Medicine must have an ID');

    await cancelMedicineReminders(medicineId);
    if (medicine.frequency == 'As Needed' || medicine.reminderTimes.isEmpty) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final scheduleThrough = today.add(const Duration(days: 7));
    final db = await _dbService.database;

    for (var index = 0; index < medicine.reminderTimes.length; index++) {
      final timeStr = medicine.reminderTimes[index].trim();
      final timeParts = timeStr.split(':');
      if (timeParts.length != 2) {
        throw FormatException('Invalid reminder time: $timeStr');
      }
      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw FormatException('Invalid reminder time: $timeStr');
      }
      final time = TimeOfDay(hour: hour, minute: minute);
      final occurrences = MedicineSchedulePlanner.occurrences(
        medicine: medicine,
        time: time,
        now: now,
        through: scheduleThrough,
      );

      for (final occurrence in occurrences) {
        final dateStr = occurrence.toIso8601String().split('T').first;
        final existing = await db.query(
          'schedules',
          where: 'medicineId = ? AND date(scheduledDate) = ? AND scheduledTime = ?',
          whereArgs: [medicineId, dateStr, timeStr],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert(
            'schedules',
            Schedule(
              medicineId: medicineId,
              scheduledDate: occurrence,
              scheduledTime: timeStr,
              status: 'pending',
              createdAt: now,
            ).toMap(),
          );
        }
      }

      final scheduleMode = _recurrenceFor(medicine.frequency);
      final weekdays = medicine.frequency == 'Weekly'
          ? (medicine.reminderWeekdays.isEmpty
              ? [tz.TZDateTime.from(medicine.startDate, tz.local).weekday]
              : medicine.reminderWeekdays)
          : const <int>[];
      final reminderDays = weekdays.isEmpty ? [0] : weekdays;
      for (final weekday in reminderDays) {
        final recurringMedicine = medicine.frequency == 'Weekly'
            ? medicine.copyWith(reminderWeekdays: [weekday])
            : medicine;
        final firstFire = MedicineSchedulePlanner.nextOccurrence(
          medicine: recurringMedicine,
          time: time,
          now: now,
        );
        if (firstFire == null) continue;

        final idOffset = medicine.frequency == 'Weekly'
            ? index * 7 + weekday - 1
            : index;
        if (idOffset >= 100) {
          throw StateError('Medicine has too many reminder times for notification IDs');
        }
        await _notificationService.scheduleMedicineReminder(
          id: medicineId * 100 + idOffset,
          title: 'Medicine Reminder',
          body: 'It\'s time to take ${medicine.name}',
          firstFireDate: firstFire,
          matchDateTimeComponents: scheduleMode,
          payload: 'reminder:$medicineId:$index:${medicine.frequency}',
        );
      }
    }
  }

  DateTimeComponents? _recurrenceFor(String frequency) => switch (frequency) {
        'Daily' => DateTimeComponents.time,
        'Weekly' => DateTimeComponents.dayOfWeekAndTime,
        'Monthly' => null,
        _ => null,
      };

  /// Cancel all reminders for a medicine
  Future<void> cancelMedicineReminders(int medicineId) async {
    // IDs 0 through 99 are reserved for this medicine's reminder notifications.
    for (int i = 0; i < 100; i++) {
      final notificationId = medicineId * 100 + i;
      try {
        await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        // Continue canceling others
      }
    }

    final db = await _dbService.database;
    final pendingSchedules = await db.query(
      'schedules',
      columns: ['id', 'scheduledDate'],
      where: 'medicineId = ? AND status = ?',
      whereArgs: [medicineId, 'pending'],
    );
    final now = DateTime.now();
    final futureIds = pendingSchedules.where((schedule) {
      return DateTime.parse(schedule['scheduledDate'] as String).isAfter(now);
    }).map((schedule) => schedule['id'] as int);

    await db.transaction((transaction) async {
      for (final scheduleId in futureIds) {
        await transaction.delete(
          'schedules',
          where: 'id = ? AND status = ?',
          whereArgs: [scheduleId, 'pending'],
        );
      }
    });
  }

  /// Check and cancel reminders for expired medicines
  Future<void> cancelExpiredReminders() async {
    final db = await _dbService.database;
    final now = tz.TZDateTime.now(tz.local);

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
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final futureDate = today.add(const Duration(days: 7));

    // Get all active medicines
    final activeMedicines = await db.query(
      'medicines',
      where: 'endDate >= ?',
      whereArgs: [now.toIso8601String()],
    );

    for (var medicineMap in activeMedicines) {
      final medicine = Medicine.fromMap(medicineMap);
      if (medicine.frequency == 'As Needed') continue;

      for (final rawTime in medicine.reminderTimes) {
        final timeStr = rawTime.trim();
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
          continue;
        }

        final occurrences = MedicineSchedulePlanner.occurrences(
          medicine: medicine,
          time: TimeOfDay(hour: hour, minute: minute),
          now: now,
          through: futureDate,
        );
        for (final occurrence in occurrences) {
          final dateStr = occurrence.toIso8601String().split('T').first;
          final existing = await db.query(
            'schedules',
            where: 'medicineId = ? AND date(scheduledDate) = ? AND scheduledTime = ?',
            whereArgs: [medicine.id!, dateStr, timeStr],
            limit: 1,
          );
          if (existing.isEmpty) {
            await db.insert(
              'schedules',
              Schedule(
                medicineId: medicine.id!,
                scheduledDate: occurrence,
                scheduledTime: timeStr,
                status: 'pending',
                createdAt: now,
              ).toMap(),
            );
          }
        }
      }
    }
  }

  /// Reschedule all notifications for active medicines
  /// This should be called when the app starts to ensure notifications are active
  Future<void> rescheduleAllNotifications() async {
    debugPrint('🔄 Rescheduling all notifications...');

    final db = await _dbService.database;
    final now = tz.TZDateTime.now(tz.local);

    // Get all active medicines (not expired)
    final activeMedicines = await db.query(
      'medicines',
      where: 'endDate >= ?',
      whereArgs: [now.toIso8601String()],
    );

    debugPrint('📋 Found ${activeMedicines.length} active medicines to reschedule');

    for (var medicineMap in activeMedicines) {
      final medicine = Medicine.fromMap(medicineMap);
      debugPrint('🔄 Rescheduling for medicine: ${medicine.name}');
      await scheduleMedicineReminders(medicine);
    }

    // Log pending notifications for debugging
    try {
      final pendingNotifications = await _notificationService.getPendingNotifications();
      debugPrint('📋 Total pending notifications after rescheduling: ${pendingNotifications.length}');
      
      // Debug print all pending notifications
      await _notificationService.debugPrintPendingNotifications();
    } catch (e) {
      debugPrint('⚠️ Could not check pending notifications: $e');
    }

    debugPrint('✅ Finished rescheduling all notifications');
  }

  /// Mark a pending dose as taken. A missed dose can only be changed via [lateDose].
  Future<bool> markAsTaken(
    int scheduleId,
    int medicineId, {
    bool lateDose = false,
  }) async {
    final db = await _dbService.database;
    final now = tz.TZDateTime.now(tz.local);
    var transitioned = false;

    await db.transaction((transaction) async {
      final scheduleMaps = await transaction.query(
        'schedules',
        where: 'id = ? AND medicineId = ?',
        whereArgs: [scheduleId, medicineId],
      );
      if (scheduleMaps.isEmpty) return;

      final schedule = Schedule.fromMap(scheduleMaps.first);
      if (schedule.status != 'pending' &&
          !(lateDose && schedule.status == 'missed')) {
        return;
      }

      final updated = await transaction.update(
        'schedules',
        {'status': 'taken', 'takenAt': now.toIso8601String()},
        where: 'id = ? AND status = ?',
        whereArgs: [scheduleId, schedule.status],
      );
      if (updated != 1) return;

      final history = History(
        medicineId: medicineId,
        scheduleId: scheduleId,
        scheduledDate: schedule.scheduledDate,
        scheduledTime: schedule.scheduledTime,
        status: 'taken',
        takenAt: now,
        createdAt: now,
      );
      await transaction.insert(
        'history',
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.rawUpdate(
        'UPDATE medicines SET stockCount = CASE WHEN stockCount > 0 THEN stockCount - 1 ELSE 0 END, updatedAt = ? WHERE id = ?',
        [now.toIso8601String(), medicineId],
      );
      transitioned = true;
    });

    if (transitioned) {
      final medicineResult = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
      );
      if (medicineResult.isNotEmpty) {
        final medicine = Medicine.fromMap(medicineResult.first);
        if (medicine.stockCount <= 5) {
          try {
            await _notificationService.scheduleNotification(
              id: medicineId + 10000,
              title: 'Low Stock Alert',
              body: '${medicine.name} has only ${medicine.stockCount} ${medicine.stockCount == 1 ? 'tablet' : 'tablets'} remaining',
              scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 1)),
            );
          } catch (e) {
            debugPrint('Could not schedule low-stock notification: $e');
          }
        }
      }
    }

    return transitioned;
  }

  /// Mark a schedule as missed
  Future<bool> markAsMissed(int scheduleId, int medicineId) async {
    final db = await _dbService.database;
    final now = tz.TZDateTime.now(tz.local);
    var transitioned = false;

    await db.transaction((transaction) async {
      final scheduleMaps = await transaction.query(
        'schedules',
        where: 'id = ? AND medicineId = ? AND status = ?',
        whereArgs: [scheduleId, medicineId, 'pending'],
      );
      if (scheduleMaps.isEmpty) return;

      final schedule = Schedule.fromMap(scheduleMaps.first);
      final updated = await transaction.update(
        'schedules',
        {'status': 'missed'},
        where: 'id = ? AND status = ?',
        whereArgs: [scheduleId, 'pending'],
      );
      if (updated != 1) return;

      final history = History(
        medicineId: medicineId,
        scheduleId: scheduleId,
        scheduledDate: schedule.scheduledDate,
        scheduledTime: schedule.scheduledTime,
        status: 'missed',
        createdAt: now,
      );
      await transaction.insert(
        'history',
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      transitioned = true;
    });

    return transitioned;
  }

  /// Mark all overdue pending schedules as missed
  /// This should be called when the app starts to ensure missed doses are properly recorded
  Future<void> markOverdueSchedulesAsMissed() async {
    final db = await _dbService.database;
    final now = tz.TZDateTime.now(tz.local);
    const gracePeriod = Duration(minutes: 30);

    debugPrint('🔍 Checking for overdue schedules at $now');

    // Get all pending schedules that are overdue (past grace period)
    // Use Dart DateTime logic instead of SQLite datetime functions for timezone safety
    final pendingSchedules = await db.rawQuery('''
      SELECT s.*, m.uid
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE s.status = 'pending'
    ''');

    debugPrint('📋 Found ${pendingSchedules.length} pending schedules');

    for (final scheduleMap in pendingSchedules) {
      final scheduleId = scheduleMap['id'] as int;
      final status = scheduleMap['status'] as String;
      final scheduledDateStr = scheduleMap['scheduledDate'] as String;
      final scheduledTimeStr = scheduleMap['scheduledTime'] as String;

      debugPrint('⏰ Checking schedule $scheduleId: status=$status, time=$scheduledTimeStr');

      // Parse the stored ISO date string and construct TZDateTime
      final scheduledDateTime = tz.TZDateTime.from(DateTime.parse(scheduledDateStr), tz.local);

      debugPrint('📅 Scheduled datetime: $scheduledDateTime, Now: $now');

      // Mark as missed only if now is after scheduled time + grace period
      if (now.isAfter(scheduledDateTime.add(gracePeriod))) {
        debugPrint('❌ Marking schedule $scheduleId as missed (overdue)');
        final medicineId = scheduleMap['medicineId'] as int;
        await markAsMissed(scheduleId, medicineId);
      } else {
        debugPrint('✅ Schedule $scheduleId is still within grace period');
      }
    }
  }
}

