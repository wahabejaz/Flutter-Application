import 'package:flutter/material.dart';
import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:timezone/timezone.dart' as tz;

class MedicineSchedulePlanner {
  const MedicineSchedulePlanner._();

  static List<tz.TZDateTime> occurrences({
    required Medicine medicine,
    required TimeOfDay time,
    required DateTime now,
    required DateTime through,
  }) {
    final location = tz.local;
    final localNow = tz.TZDateTime.from(now, location);
    final start = tz.TZDateTime.from(medicine.startDate, location);
    final endDate = tz.TZDateTime.from(medicine.endDate, location);
    final end = tz.TZDateTime(
      location,
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );
    if (medicine.frequency == 'As Needed' || end.isBefore(start)) return [];

    final firstDay = _dateOnly(start);
    final lastDay = _dateOnly(end);
    final firstSearchDay = _dateOnly(localNow).isAfter(firstDay)
        ? _dateOnly(localNow)
        : firstDay;
    final requestedThrough = _dateOnly(tz.TZDateTime.from(through, location));
    final lastSearchDay = requestedThrough.isBefore(lastDay)
        ? requestedThrough
        : lastDay;
    if (lastSearchDay.isBefore(firstSearchDay)) return [];

    final weekdays = medicine.reminderWeekdays.isEmpty
        ? <int>[start.weekday]
        : medicine.reminderWeekdays;
    final result = <tz.TZDateTime>[];

    for (var day = firstSearchDay;
        !day.isAfter(lastSearchDay);
        day = day.add(const Duration(days: 1))) {
      final matches = switch (medicine.frequency) {
        'Weekly' => weekdays.contains(day.weekday),
        'Monthly' => day.day == _monthlyDay(start, day.year, day.month),
        _ => true,
      };
      if (!matches) continue;

      final occurrence = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (occurrence.isAfter(localNow) &&
          !occurrence.isBefore(start) &&
          !occurrence.isAfter(end)) {
        result.add(occurrence);
      }
    }
    return result;
  }

  static tz.TZDateTime? nextOccurrence({
    required Medicine medicine,
    required TimeOfDay time,
    required DateTime now,
  }) {
    final through = medicine.endDate;
    final endDate = tz.TZDateTime.from(through, tz.local);
    final end = tz.TZDateTime(
      tz.local,
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );
    final start = tz.TZDateTime.from(medicine.startDate, tz.local);
    if (end.isBefore(start) || medicine.frequency == 'As Needed') return null;

    final localNow = tz.TZDateTime.from(now, tz.local);
    final searchFrom = localNow.isBefore(start) ? start : localNow;
    final horizon = tz.TZDateTime(
      tz.local,
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    );
    final candidates = occurrences(
      medicine: medicine,
      time: time,
      now: searchFrom.subtract(const Duration(microseconds: 1)),
      through: horizon,
    );
    for (final candidate in candidates) {
      if (candidate.isAfter(localNow)) return candidate;
    }
    return null;
  }

  static tz.TZDateTime _dateOnly(tz.TZDateTime date) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day);

  static int _monthlyDay(DateTime anchor, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return anchor.day < lastDay ? anchor.day : lastDay;
  }
}