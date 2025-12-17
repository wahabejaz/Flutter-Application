import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/services/db/medicine_dao.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/reminder_scheduler.dart';
import 'package:sqflite/sqflite.dart';

/// Sample Data Service
/// Provides comprehensive sample medicine data for testing and demonstration
/// Creates data as if the app has been in use for several weeks
class SampleDataService {
  final MedicineDAO _medicineDAO = MedicineDAO();
  final ReminderScheduler _scheduler = ReminderScheduler();
  final SQLiteService _dbService = SQLiteService();

  /// Check if sample data already exists
  Future<bool> hasSampleData() async {
    final medicines = await _medicineDAO.getAllMedicinesUnscoped();
    return medicines.isNotEmpty;
  }

  /// Add comprehensive sample data (weeks of history)
  Future<void> addSampleData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final twoWeeksAgo = today.subtract(const Duration(days: 14));

    // Sample Medicine 1: Paracetamol (started 2 weeks ago)
    final paracetamol = Medicine(
      name: 'Paracetamol',
      dosage: '500mg',
      frequency: 'Daily',
      frequencyUnit: '1',
      startDate: twoWeeksAgo,
      endDate: today.add(const Duration(days: 30)),
      reminderTimes: ['09:00'],
      notes: 'Take with food',
      iconColor: 0xFF66BB6A, // Green
      stockCount: 50,
      createdAt: twoWeeksAgo,
      updatedAt: now,
    );

    // Sample Medicine 2: Loratadine (started 1 week ago)
    final oneWeekAgo = today.subtract(const Duration(days: 7));
    final loratadine = Medicine(
      name: 'Loratadine',
      dosage: '50mg',
      frequency: 'Daily',
      frequencyUnit: '1',
      startDate: oneWeekAgo,
      endDate: today.add(const Duration(days: 30)),
      reminderTimes: ['12:30'],
      notes: 'Antihistamine',
      iconColor: 0xFF42A5F5, // Blue
      stockCount: 30,
      createdAt: oneWeekAgo,
      updatedAt: now,
    );

    // Sample Medicine 3: Multivitamin (started 3 weeks ago)
    final threeWeeksAgo = today.subtract(const Duration(days: 21));
    final multivitamin = Medicine(
      name: 'Multivitamin',
      dosage: '1 tablet',
      frequency: 'Daily',
      frequencyUnit: '1',
      startDate: threeWeeksAgo,
      endDate: today.add(const Duration(days: 60)),
      reminderTimes: ['18:00'],
      notes: 'Take after dinner',
      iconColor: 0xFFFF8A65, // Orange
      stockCount: 60,
      createdAt: threeWeeksAgo,
      updatedAt: now,
    );

    // Insert medicines
    final id1 = await _medicineDAO.insertMedicine(paracetamol);
    final id2 = await _medicineDAO.insertMedicine(loratadine);
    final id3 = await _medicineDAO.insertMedicine(multivitamin);

    final paracetamolWithId = paracetamol.copyWith(id: id1);
    final loratadineWithId = loratadine.copyWith(id: id2);
    final multivitaminWithId = multivitamin.copyWith(id: id3);

    // Schedule reminders for all medicines (this creates schedules for today and future)
    await _scheduler.scheduleMedicineReminders(paracetamolWithId);
    await _scheduler.scheduleMedicineReminders(loratadineWithId);
    await _scheduler.scheduleMedicineReminders(multivitaminWithId);

    // Create historical data (past 2 weeks) - this creates past schedules and marks them
    await _createHistoricalData(id1, id2, id3, twoWeeksAgo, today);
    
    // Ensure today's schedules exist (in case they weren't created)
    await _ensureTodaySchedules(id1, id2, id3, today);
  }

  /// Create historical data for the past weeks
  Future<void> _createHistoricalData(
    int paracetamolId,
    int loratadineId,
    int multivitaminId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbService.database;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Generate history for each day from start date to today
    for (var date = startDate; date.isBefore(todayStart); date = date.add(const Duration(days: 1))) {
      // Paracetamol at 09:00 (started 2 weeks ago)
      final paracetamolSchedule = await _getOrCreateSchedule(
        db,
        paracetamolId,
        date,
        '09:00',
      );
      if (paracetamolSchedule != null) {
        // Mark as taken (80% of the time) or missed (20%)
        final dayOffset = date.difference(startDate).inDays;
        final isTaken = dayOffset % 5 != 0;
        if (isTaken) {
          await _scheduler.markAsTaken(paracetamolSchedule, paracetamolId);
        } else {
          await _scheduler.markAsMissed(paracetamolSchedule, paracetamolId);
        }
      }

      // Loratadine at 12:30 (started 1 week ago, so only after 7 days from startDate)
      final oneWeekAgo = startDate.add(const Duration(days: 7));
      if (date.isAfter(oneWeekAgo) || date.isAtSameMomentAs(oneWeekAgo)) {
        final loratadineSchedule = await _getOrCreateSchedule(
          db,
          loratadineId,
          date,
          '12:30',
        );
        if (loratadineSchedule != null) {
          final dayOffset = date.difference(oneWeekAgo).inDays;
          final isTaken = dayOffset % 4 != 0;
          if (isTaken) {
            await _scheduler.markAsTaken(loratadineSchedule, loratadineId);
          } else {
            await _scheduler.markAsMissed(loratadineSchedule, loratadineId);
          }
        }
      }

      // Multivitamin at 18:00 (started 3 weeks ago, but we're only going back 2 weeks from startDate)
      // So multivitamin appears in the last week
      final twoWeeksAgo = startDate.add(const Duration(days: 14));
      if (date.isAfter(twoWeeksAgo) || date.isAtSameMomentAs(twoWeeksAgo)) {
        final multivitaminSchedule = await _getOrCreateSchedule(
          db,
          multivitaminId,
          date,
          '18:00',
        );
        if (multivitaminSchedule != null) {
          final dayOffset = date.difference(twoWeeksAgo).inDays;
          final isTaken = dayOffset % 3 != 0;
          if (isTaken) {
            await _scheduler.markAsTaken(multivitaminSchedule, multivitaminId);
          } else {
            await _scheduler.markAsMissed(multivitaminSchedule, multivitaminId);
          }
        }
      }
    }
  }

  /// Get or create a schedule entry
  Future<int?> _getOrCreateSchedule(
    Database db,
    int medicineId,
    DateTime date,
    String time,
  ) async {
    final dateStr = date.toIso8601String().split('T')[0];
    
    // Check if schedule exists
    final existing = await db.query(
      'schedules',
      where: 'medicineId = ? AND date(scheduledDate) = ? AND scheduledTime = ?',
      whereArgs: [medicineId, dateStr, time],
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    // Create new schedule
    final scheduleId = await db.insert('schedules', {
      'medicineId': medicineId,
      'scheduledDate': date.toIso8601String(),
      'scheduledTime': time,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

    return scheduleId;
  }

  /// Ensure today's schedules exist
  Future<void> _ensureTodaySchedules(
    int paracetamolId,
    int loratadineId,
    int multivitaminId,
    DateTime today,
  ) async {
    final db = await _dbService.database;
    
    // Ensure Paracetamol schedule for today at 09:00
    await _getOrCreateSchedule(db, paracetamolId, today, '09:00');
    
    // Ensure Loratadine schedule for today at 12:30
    await _getOrCreateSchedule(db, loratadineId, today, '12:30');
    
    // Ensure Multivitamin schedule for today at 18:00
    await _getOrCreateSchedule(db, multivitaminId, today, '18:00');
  }

  /// Clear all data (medicines, schedules, history)
  Future<void> clearAllData() async {
    final db = await _dbService.database;
    
    // Delete all data
    await db.delete('history');
    await db.delete('schedules');
    
    // Cancel all notifications and delete medicines
    final medicines = await _medicineDAO.getAllMedicinesUnscoped();
    for (var medicine in medicines) {
      if (medicine.id != null) {
        await _scheduler.cancelMedicineReminders(medicine.id!);
        await _medicineDAO.deleteMedicine(medicine.id!);
      }
    }
  }
}
