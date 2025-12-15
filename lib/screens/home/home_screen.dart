import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../config/app_colors.dart';
import '../../services/db/sqlite_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/notification_service.dart';
import '../../widgets/progress_circle.dart';
import 'refill_tracker/refill_tracker_screen.dart';
import 'package:intl/intl.dart';

/// Home Screen
/// Main screen showing daily progress, quick actions, and today's schedule
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SQLiteService _dbService = SQLiteService();
  final ReminderScheduler _scheduler = ReminderScheduler();
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _todaySchedules = [];
  int _totalDoses = 0;
  int _takenDoses = 0;

  @override
  void initState() {
    super.initState();
    _setupNotificationCallback();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load today's data
    await _loadTodayData();
  }

  void _setupNotificationCallback() {
    _notificationService.setNotificationTapCallback(_handleNotificationTap);
  }

  Future<void> _handleNotificationTap(int notificationId) async {
    // Find the schedule for this notification ID
    final db = await _dbService.database;
    final scheduleResult = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [notificationId],
    );

    if (scheduleResult.isNotEmpty) {
      final schedule = scheduleResult.first;
      final medicineId = schedule['medicineId'] as int;
      final scheduleId = schedule['id'] as int;

      // Get medicine details
      final medicineResult = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
      );

      if (medicineResult.isNotEmpty && mounted) {
        final medicine = medicineResult.first;
        final medicineName = medicine['name'] as String;
        final dosage = medicine['dosage'] as String;

        // Show dialog to mark as taken or missed
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Medicine Reminder'),
            content: Text('Did you take your $medicineName ($dosage)?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _markAsMissed(scheduleId, medicineId);
                },
                child: const Text('Missed'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _markAsTaken(scheduleId, medicineId);
                },
                child: const Text('Taken'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning from other screens
    final result = ModalRoute.of(context)?.settings.arguments;
    if (result == true) {
      _loadTodayData();
    }
  }

  Future<void> _loadTodayData() async {
    await _loadTodaySchedules();
    setState(() {});
  }

  Future<void> _loadTodaySchedules() async {
    final db = await _dbService.database;
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Get all schedules for today with medicine details
    final schedules = await db.rawQuery('''
      SELECT s.*, m.name, m.dosage, m.iconColor
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE date(s.scheduledDate) = ?
      ORDER BY s.scheduledTime ASC
    ''', [todayStr]);

    // Check for missed doses and mark them automatically (after grace period)
    final now = DateTime.now();
    const gracePeriod = Duration(minutes: 30);
    
    for (final schedule in schedules) {
      final status = schedule['status'] as String;
      if (status == 'pending') {
        final scheduledTimeStr = schedule['scheduledTime'] as String;
        final scheduledTimeParts = scheduledTimeStr.split(':');
        final scheduledHour = int.parse(scheduledTimeParts[0]);
        final scheduledMinute = int.parse(scheduledTimeParts[1]);

        final scheduledDateTime = DateTime(
          today.year,
          today.month,
          today.day,
          scheduledHour,
          scheduledMinute,
        );

        // Mark as missed only after grace period expires
        if (now.isAfter(scheduledDateTime.add(gracePeriod))) {
          final scheduleId = schedule['id'] as int;
          final medicineId = schedule['medicineId'] as int;
          await _scheduler.markAsMissed(scheduleId, medicineId);
        }
      }
    }

    // Reload schedules after marking missed ones
    final updatedSchedules = await db.rawQuery('''
      SELECT s.*, m.name, m.dosage, m.iconColor
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE date(s.scheduledDate) = ?
      ORDER BY s.scheduledTime ASC
    ''', [todayStr]);

    setState(() {
      _todaySchedules = updatedSchedules;
      _totalDoses = updatedSchedules.length;
      _takenDoses = updatedSchedules.where((s) => s['status'] == 'taken').length;
    });
  }

  Future<void> _markAsTaken(int scheduleId, int medicineId) async {
    // Check if the schedule is still pending (not missed)
    final db = await _dbService.database;
    final scheduleResult = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    if (scheduleResult.isNotEmpty) {
      final status = scheduleResult.first['status'] as String;
      if (status == 'pending') {
        await _scheduler.markAsTaken(scheduleId, medicineId);
        await _loadTodayData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine marked as taken'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } else if (status == 'missed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot mark a missed dose as taken'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsMissed(int scheduleId, int medicineId) async {
    await _scheduler.markAsMissed(scheduleId, medicineId);
    await _loadTodayData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine marked as missed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDoses > 0 ? (_takenDoses / _totalDoses) : 0.0;
    final progressPercent = (progress * 100).toInt();

    List<Widget> scheduleWidgets;
    if (_todaySchedules.isEmpty) {
      scheduleWidgets = [
        Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.medication_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 16),
              Text(
                'No medicines scheduled for today',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
      ];
    } else {
      scheduleWidgets = _todaySchedules.map((schedule) => _buildScheduleCard(schedule)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Medicine Reminder',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Progress Card - Full Rectangle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: AppColors.dailyProgressGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Daily Progress',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ProgressCircle(
                      progress: progress,
                      size: 140,
                      strokeWidth: 14,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      progressColor: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_takenDoses of $_totalDoses doses',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildQuickActionButton(
                    icon: Icons.add_circle_outline,
                    label: 'Add Medication',
                    color: AppColors.pastelGreen,
                    iconColor: AppColors.green,
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.addMedicine,
                      );
                      if (result == true) {
                        _loadTodayData();
                      }
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.calendar_today,
                    label: 'Calendar View',
                    color: AppColors.pastelBlue,
                    iconColor: AppColors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.schedule);
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.history,
                    label: 'History Log',
                    color: AppColors.pastelPink,
                    iconColor: AppColors.red,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.history);
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.local_pharmacy,
                    label: 'Refill Tracker',
                    color: AppColors.pastelOrange,
                    iconColor: AppColors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RefillTrackerScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Today's Schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.schedule);
                    },
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Schedule List
              ...scheduleWidgets,
            ],
          ),
        ),
    ));
  }
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    final isMissed = status == 'missed';
    final isPending = status == 'pending';

    // Check if pending dose is overdue (past scheduled time but within grace period)
    bool isOverdue = false;
    if (isPending) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduledTimeParts = time.split(':');
      final scheduledHour = int.parse(scheduledTimeParts[0]);
      final scheduledMinute = int.parse(scheduledTimeParts[1]);
      final scheduledDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        scheduledHour,
        scheduledMinute,
      );
      const gracePeriod = Duration(minutes: 30);
      
      isOverdue = now.isAfter(scheduledDateTime) && now.isBefore(scheduledDateTime.add(gracePeriod));
    }

    // Determine colors based on status
    Color timeIconColor = AppColors.textSecondary;
    Color timeTextColor = AppColors.textPrimary;
    Color buttonColor = iconColor;
    String buttonText = 'Take';
    Color buttonBackgroundColor = buttonColor;

    if (isTaken) {
      timeIconColor = AppColors.green;
      timeTextColor = AppColors.green;
      buttonBackgroundColor = AppColors.green;
      buttonText = 'Taken';
    } else if (isMissed) {
      timeIconColor = AppColors.red;
      timeTextColor = AppColors.red;
      buttonBackgroundColor = AppColors.red;
      buttonText = 'Missed';
    } else if (isOverdue) {
      timeIconColor = AppColors.orange;
      timeTextColor = AppColors.orange;
      buttonBackgroundColor = AppColors.orange;
      buttonText = 'Take';
    }

    Widget actionWidget = SizedBox.shrink();
    if (isPending || isOverdue) {
      actionWidget = ElevatedButton(
        onPressed: () => _markAsTaken(scheduleId, medicineId),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    } else if (isTaken) {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Taken',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    } else if (isMissed) {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Missed',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
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
                color: timeIconColor,
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(
                  fontSize: 15,
                  color: timeTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          actionWidget,
        ],
      ),
    );
  }
}
