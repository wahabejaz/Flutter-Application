import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/models/schedule_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/reminder_scheduler.dart';
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
}

Future<int> _insertMedicine(Database database) async {
  final now = DateTime.now();
  return database.insert(
    'medicines',
    Medicine(
      uid: 'scheduler-test-user',
      name: 'Test medicine',
      dosage: '1 tablet',
      frequency: 'Daily',
      frequencyUnit: '1',
      startDate: now,
      endDate: now.add(const Duration(days: 10)),
      reminderTimes: const ['09:00'],
      iconColor: 0xFF00FF00,
      stockCount: 10,
      createdAt: now,
      updatedAt: now,
    ).toMap(),
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