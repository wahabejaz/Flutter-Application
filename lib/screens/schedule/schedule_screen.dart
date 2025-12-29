import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/db/sqlite_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../utils/date_time_helpers.dart';

/// Schedule Screen
/// Shows calendar view and scheduled medicines for selected date
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final SQLiteService _dbService = SQLiteService();
  final ReminderScheduler _scheduler = ReminderScheduler();
  
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _schedules = [];
  Map<DateTime, List<String>> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _loadEvents();
  }

  Future<void> _loadSchedules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final db = await _dbService.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final schedules = await db.rawQuery('''
      SELECT s.*, m.name, m.dosage, m.iconColor
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE date(s.scheduledDate) = ? AND m.uid = ?
      ORDER BY s.scheduledTime ASC
    ''', [dateStr, currentUser.uid]);

    setState(() {
      _schedules = schedules;
    });
  }

  Future<void> _loadEvents() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final db = await _dbService.database;
    final events = await db.rawQuery('''
      SELECT DISTINCT date(scheduledDate) as date
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE s.status = 'pending' AND m.uid = ?
    ''', [currentUser.uid]);

    final Map<DateTime, List<String>> map = {};
    for (var event in events) {
      final dateStr = event['date'] as String;
      final date = DateTime.parse(dateStr);
      final dateKey = DateTime(date.year, date.month, date.day);
      
      // Get medicine count for this date
      final count = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM schedules s
        INNER JOIN medicines m ON s.medicineId = m.id
        WHERE date(s.scheduledDate) = ? AND s.status = 'pending' AND m.uid = ?
      ''', [dateStr, currentUser.uid]);
      
      final countValue = count.first['count'] as int;
      if (countValue > 0) {
        map[dateKey] = List.generate(countValue, (i) => 'medicine');
      }
    }

    setState(() {
      _eventsMap = map;
    });
  }

  Future<void> _markAsTaken(int scheduleId, int medicineId) async {
    await _scheduler.markAsTaken(scheduleId, medicineId);
    await _loadSchedules();
    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine marked as taken'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Calendar Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.blueGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCalendar(),
              ],
            ),
          ),
          // Scheduled Medicines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Scheduled for ${DateFormat('MMMM d').format(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: _schedules.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 48,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No medicines scheduled for this date',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _schedules.length,
                          itemBuilder: (context, index) {
                            return _buildScheduleCard(_schedules[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday;
    final daysInMonth = lastDay.day;

    return Column(
      children: [
        // Weekday headers
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...List.generate(
          (firstDayOfWeek + daysInMonth - 1) ~/ 7 + 1,
          (week) {
            return Row(
              children: List.generate(7, (day) {
                final dayIndex = week * 7 + day - firstDayOfWeek + 1;
                if (dayIndex < 1 || dayIndex > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(_selectedDate.year, _selectedDate.month, dayIndex);
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final hasEvents = _eventsMap.containsKey(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                      _loadSchedules();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$dayIndex',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : isToday
                                      ? Colors.white
                                      : Colors.white70,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (hasEvents)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final medicineName = schedule['name'] as String;
    final dosage = schedule['dosage'] as String;
    final time = schedule['scheduledTime'] as String;
    final status = schedule['status'] as String;
    final scheduleId = schedule['id'] as int;
    final medicineId = schedule['medicineId'] as int;
    final iconColor = Color(schedule['iconColor'] as int);
    final isTaken = status == 'taken';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: isTaken ? AppColors.green : iconColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dosage,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: isTaken ? AppColors.green : AppColors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                DateTimeHelpers.formatTime12Hour(time),
                style: TextStyle(
                  fontSize: 14,
                  color: isTaken ? AppColors.green : AppColors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          if (!isTaken)
            ElevatedButton(
              onPressed: () => _markAsTaken(scheduleId, medicineId),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Take'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Taken',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
