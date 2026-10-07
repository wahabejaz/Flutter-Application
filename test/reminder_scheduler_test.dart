import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/models/schedule_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/db/medicine_dao.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';
import 'package:medicine_reminder_app/services/reminder_scheduler.dart';
import 'package:medicine_reminder_app/services/schedule_planner.dart';
import 'package:medicine_reminder_app/services/user_data_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory databaseDirectory;
  late Database database;
  late ReminderScheduler scheduler;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp('medicine_db_test_');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return databaseDirectory.path;
      }
      return null;
    });
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    database = await SQLiteService().database;
    await database.delete('history');
    await database.delete('schedules');
    await database.delete('medicines');
    await database.delete('users');
    scheduler = ReminderScheduler();
  });

  tearDownAll(() async {
    await SQLiteService().close();
    await databaseDirectory.delete(recursive: true);
  });

  test('SQLite enforces foreign keys and one history row per schedule', () async {
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);

    final medicineId = await _insertMedicine(database);
    final scheduleId = await _insertSchedule(database, medicineId);
    final schedule = await database.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    await database.insert('history', {
      'medicineId': medicineId,
      'scheduleId': scheduleId,
      'scheduledDate': schedule.single['scheduledDate'],
      'scheduledTime': schedule.single['scheduledTime'],
      'status': 'missed',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await expectLater(
      database.insert('history', {
        'medicineId': medicineId,
        'scheduleId': scheduleId,
        'scheduledDate': schedule.single['scheduledDate'],
        'scheduledTime': schedule.single['scheduledTime'],
        'status': 'missed',
        'createdAt': DateTime.now().toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('taken transition decrements stock and writes history once', () async {
    final medicineId = await _insertMedicine(database);
    final scheduleId = await _insertSchedule(database, medicineId);

    expect(await scheduler.markAsTaken(scheduleId, medicineId), isTrue);
    expect(await scheduler.markAsTaken(scheduleId, medicineId), isFalse);

    final medicine = await database.query(
      'medicines',
      columns: ['stockCount'],
      where: 'id = ?',
      whereArgs: [medicineId],
    );
    final schedule = await database.query(
      'schedules',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
    final history = await database.query(
      'history',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );

    expect(medicine.single['stockCount'], 9);
    expect(schedule.single['status'], 'taken');
    expect(history, hasLength(1));
    expect(history.single['status'], 'taken');
  });

  test('missed dose requires explicit late-dose recovery and remains idempotent', () async {
    final medicineId = await _insertMedicine(database);
    final scheduleId = await _insertSchedule(database, medicineId);

    expect(await scheduler.markAsMissed(scheduleId, medicineId), isTrue);
    expect(await scheduler.markAsMissed(scheduleId, medicineId), isFalse);
    expect(await scheduler.markAsTaken(scheduleId, medicineId), isFalse);
    expect(
      await scheduler.markAsTaken(scheduleId, medicineId, lateDose: true),
      isTrue,
    );
    expect(
      await scheduler.markAsTaken(scheduleId, medicineId, lateDose: true),
      isFalse,
    );

    final medicine = await database.query(
      'medicines',
      columns: ['stockCount'],
      where: 'id = ?',
      whereArgs: [medicineId],
    );
    final history = await database.query(
      'history',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );

    expect(medicine.single['stockCount'], 9);
    expect(history, hasLength(1));
    expect(history.single['status'], 'taken');
    expect(history.single['takenAt'], isNotNull);
  });

  test('daily occurrences do not precede start and include the end date', () {
    final medicine = _medicine(
      startDate: DateTime.utc(2025, 1, 10, 9),
      endDate: DateTime.utc(2025, 1, 12),
    );
    final occurrences = MedicineSchedulePlanner.occurrences(
      medicine: medicine,
      time: const TimeOfDay(hour: 8, minute: 30),
      now: DateTime.utc(2025, 1, 10, 8),
      through: DateTime.utc(2025, 1, 13),
    );

    expect(
      occurrences.map((date) => '${date.month}/${date.day} ${date.hour}:${date.minute}'),
      ['1/11 8:30', '1/12 8:30'],
    );
  });

  test('weekly occurrences honor the selected weekdays', () {
    final medicine = _medicine(
      frequency: 'Weekly',
      reminderWeekdays: const [1, 3],
      startDate: DateTime.utc(2025, 1, 1),
      endDate: DateTime.utc(2025, 1, 20),
    );
    final occurrences = MedicineSchedulePlanner.occurrences(
      medicine: medicine,
      time: const TimeOfDay(hour: 9, minute: 0),
      now: DateTime.utc(2025, 1, 6, 10),
      through: DateTime.utc(2025, 1, 15),
    );

    expect(occurrences.map((date) => date.weekday), [3, 1, 3]);
    expect(occurrences.map((date) => date.day), [8, 13, 15]);
  });

  test('monthly occurrences clamp to the last day of shorter months', () {
    final medicine = _medicine(
      frequency: 'Monthly',
      startDate: DateTime.utc(2025, 1, 31),
      endDate: DateTime.utc(2025, 4, 30),
    );
    final occurrences = MedicineSchedulePlanner.occurrences(
      medicine: medicine,
      time: const TimeOfDay(hour: 9, minute: 0),
      now: DateTime.utc(2025, 1, 31, 10),
      through: DateTime.utc(2025, 4, 30),
    );

    expect(occurrences.map((date) => '${date.month}/${date.day}'), [
      '2/28',
      '3/31',
      '4/30',
    ]);
    expect(
      MedicineSchedulePlanner.nextOccurrence(
        medicine: medicine,
        time: const TimeOfDay(hour: 9, minute: 0),
        now: DateTime.utc(2025, 2, 1),
      )?.day,
      28,
    );
  });

  test('as-needed medicines do not produce scheduled occurrences', () {
    final medicine = _medicine(
      frequency: 'As Needed',
      startDate: DateTime.utc(2025, 1, 1),
      endDate: DateTime.utc(2025, 1, 31),
    );

    expect(
      MedicineSchedulePlanner.occurrences(
        medicine: medicine,
        time: const TimeOfDay(hour: 9, minute: 0),
        now: DateTime.utc(2025, 1, 1),
        through: DateTime.utc(2025, 1, 31),
      ),
      isEmpty,
    );
  });

  test('deleting a medicine removes its schedules and history', () async {
    final medicineId = await _insertMedicine(database);
    final scheduleId = await _insertSchedule(database, medicineId);
    await scheduler.markAsMissed(scheduleId, medicineId);

    await MedicineDAO().deleteMedicine(medicineId);

    expect(await database.query('medicines'), isEmpty);
    expect(await database.query('schedules'), isEmpty);
    expect(await database.query('history'), isEmpty);
  });

  test('user reset cancels all notifications and preserves other users', () async {
    final targetMedicineId = await _insertMedicine(database, uid: 'target-user');
    final otherMedicineId = await _insertMedicine(database, uid: 'other-user');
    final targetScheduleId = await _insertSchedule(database, targetMedicineId);
    await scheduler.markAsMissed(targetScheduleId, targetMedicineId);
    await _insertSchedule(database, otherMedicineId);
    var notificationsCancelled = false;

    await UserDataService(
      cancelAllNotifications: () async {
        notificationsCancelled = true;
      },
    ).clearCurrentUserData('target-user');

    expect(notificationsCancelled, isTrue);
    expect(await database.query('medicines', where: 'uid = ?', whereArgs: ['target-user']), isEmpty);
    expect(await database.query('schedules'), hasLength(1));
    expect(await database.query('history'), isEmpty);
    expect(await database.query('users'), isEmpty);
    expect(
      await database.query('medicines', where: 'uid = ?', whereArgs: ['other-user']),
      hasLength(1),
    );
  });

  test('taking the last dose reaches zero and stock IDs are disjoint', () async {
    final medicineId = await _insertMedicine(database, stockCount: 1);
    final scheduleId = await _insertSchedule(database, medicineId);

    expect(await scheduler.markAsTaken(scheduleId, medicineId), isTrue);
    expect(await scheduler.markAsTaken(scheduleId, medicineId), isFalse);

    final medicine = await database.query(
      'medicines',
      columns: ['stockCount'],
      where: 'id = ?',
      whereArgs: [medicineId],
    );
    final stockNotificationId =
        ReminderScheduler.lowStockNotificationId(medicineId);

    expect(medicine.single['stockCount'], 0);
    expect(stockNotificationId, lessThan(0));
    expect(List.generate(100, (index) => medicineId * 100 + index),
        isNot(contains(stockNotificationId)));
  });

  test('snooze IDs stay outside reminder and stock ID namespaces', () {
    const reminderNotificationId = 12345;
    final snoozeId =
        NotificationService.snoozeNotificationIdFor(reminderNotificationId);

    expect(snoozeId, lessThan(0));
    expect(snoozeId, isNot(ReminderScheduler.lowStockNotificationId(12)));
    expect(snoozeId, isNot(reminderNotificationId));
  });
}

Future<int> _insertMedicine(
  Database database, {
  String uid = 'scheduler-test-user',
  int stockCount = 10,
}) async {
  final now = DateTime.now();
  final medicine = _medicine(
    startDate: now,
    endDate: now.add(const Duration(days: 10)),
  ).copyWith(uid: uid, stockCount: stockCount);
  return database.insert('medicines', medicine.toMap());
}

Medicine _medicine({
  String frequency = 'Daily',
  List<int> reminderWeekdays = const [],
  DateTime? startDate,
  DateTime? endDate,
}) {
  final createdAt = DateTime.utc(2025);
  return Medicine(
    uid: 'scheduler-test-user',
    name: 'Test medicine',
    dosage: '1 tablet',
    frequency: frequency,
    frequencyUnit: frequency == 'Weekly' ? '7' : '1',
    startDate: startDate ?? createdAt,
    endDate: endDate ?? createdAt.add(const Duration(days: 10)),
    reminderTimes: const ['09:00'],
    reminderWeekdays: reminderWeekdays,
    iconColor: 0xFF00FF00,
    stockCount: 10,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<int> _insertSchedule(Database database, int medicineId) async {
  final scheduledDate = DateTime.now().add(const Duration(hours: 1));
  return database.insert(
    'schedules',
    Schedule(
      medicineId: medicineId,
      scheduledDate: scheduledDate,
      scheduledTime: '09:00',
      createdAt: DateTime.now(),
    ).toMap(),
  );
}