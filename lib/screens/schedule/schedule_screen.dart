import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
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

    final schedules = await db.rawQuery(
      '''
      SELECT s.*, m.name, m.dosage, m.iconColor
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE substr(s.scheduledDate, 1, 10) = ? AND m.uid = ?
      ORDER BY s.scheduledTime ASC
    ''',
      [dateStr, currentUser.uid],
    );

    setState(() {
      _schedules = schedules;
    });
  }

  Future<void> _loadEvents() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final db = await _dbService.database;
    final events = await db.rawQuery(
      '''
      SELECT substr(s.scheduledDate, 1, 10) as date, s.status
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE m.uid = ?
      ORDER BY date
    ''',
      [currentUser.uid],
    );

    final Map<DateTime, List<String>> map = {};
    for (var event in events) {
      final dateStr = event['date'] as String;
      final date = DateTime.parse(dateStr);
      final dateKey = DateTime(date.year, date.month, date.day);
      (map[dateKey] ??= []).add(event['status'] as String);
    }

    setState(() {
      _eventsMap = map;
    });
  }

  Future<void> _markAsTaken(
    int scheduleId,
    int medicineId, {
    bool lateDose = false,
  }) async {
    final transitioned = await _scheduler.markAsTaken(
      scheduleId,
      medicineId,
      lateDose: lateDose,
    );
    await _loadSchedules();
    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transitioned
                ? 'Medicine marked as taken'
                : 'This dose was already updated',
          ),
          backgroundColor: transitioned ? AppColors.green : AppColors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Schedule'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Calendar Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                    style: Theme.of(context).textTheme.titleLarge,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No medicines scheduled for this date',
                                style: Theme.of(context).textTheme.bodyMedium,
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
    final scheme = Theme.of(context).colorScheme;
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
        ...List.generate((firstDayOfWeek + daysInMonth - 1) ~/ 7 + 1, (week) {
          return Row(
            children: List.generate(7, (day) {
              final dayIndex = week * 7 + day - firstDayOfWeek + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final date = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                dayIndex,
              );
              final isSelected =
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              final isToday =
                  date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final statuses = _eventsMap[date];
              final markerColor = _markerColor(context, statuses);
              final dayStatus = statuses == null
                  ? ''
                  : statuses.contains('missed')
                  ? ', contains missed doses'
                  : statuses.contains('pending')
                  ? ', has pending doses'
                  : ', all doses taken';

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label:
                      DateFormat('EEEE, MMMM d').format(date) +
                      (statuses == null
                          ? ''
                          : ', ${statuses.length} scheduled doses$dayStatus'),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _loadSchedules();
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.surface : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$dayIndex',
                            style: TextStyle(
                              color: isSelected
                                  ? scheme.onSurface
                                  : isToday
                                  ? scheme.onPrimary
                                  : scheme.onPrimary.withValues(alpha: .75),
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (markerColor != null)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
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
    final isTaken = status == 'taken';
    final isMissed = status == 'missed';
    final isPending = status == 'pending';

    final scheme = Theme.of(context).colorScheme;
    final statusColor = isTaken
        ? AppStatusColors.taken(context)
        : isMissed
        ? AppStatusColors.missed(context)
        : AppStatusColors.upcoming(context);
    final statusLabel = isTaken
        ? 'Taken'
        : isMissed
        ? 'Missed'
        : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dosage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 18, color: statusColor),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        DateTimeHelpers.formatTime12Hour(time),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending)
                Semantics(
                  button: true,
                  label: 'Mark $medicineName as taken',
                  child: ElevatedButton(
                    onPressed: () => _markAsTaken(scheduleId, medicineId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: scheme.onPrimary,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Take'),
                  ),
                )
              else if (isMissed)
                Semantics(
                  button: true,
                  label: 'Log late dose of $medicineName as taken',
                  child: OutlinedButton(
                    onPressed: () =>
                        _markAsTaken(scheduleId, medicineId, lateDose: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Log late dose'),
                  ),
                )
              else
                Semantics(
                  label: 'Dose status: $statusLabel',
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color? _markerColor(BuildContext context, List<String>? statuses) {
    if (statuses == null || statuses.isEmpty) return null;
    if (statuses.contains('missed')) return AppStatusColors.missed(context);
    if (statuses.contains('pending')) return AppStatusColors.upcoming(context);
    if (statuses.every((status) => status == 'taken')) {
      return AppStatusColors.taken(context);
    }
    return null;
  }
}
