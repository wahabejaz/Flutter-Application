import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../config/app_colors.dart';
import '../../services/db/sqlite_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/notification_service.dart';
import '../../widgets/progress_circle.dart';
import 'refill_tracker/refill_tracker_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/date_time_helpers.dart';
import 'dart:async';

/// Home Screen
/// Main screen showing daily progress, quick actions, and today's schedule
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Constants for schedule statuses
  static const String _statusPending = 'pending';
  static const String _statusTaken = 'taken';
  static const String _statusMissed = 'missed';
  final SQLiteService _dbService = SQLiteService();
  final ReminderScheduler _scheduler = ReminderScheduler();
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _todaySchedules = [];
  int _totalDoses = 0;
  int _takenDoses = 0;
  Timer? _autoUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationCallback();
    _initializeData();
    
    // Set up automatic UI updates every 60 seconds
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _loadTodayData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reschedule notifications and reload data when app comes back to foreground
      _rescheduleNotifications();
      _loadTodayData();
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      await _scheduler.rescheduleAllNotifications();
    } catch (e) {
      // Silently handle errors to avoid disrupting the user experience
      debugPrint('Failed to reschedule notifications: $e');
    }
  }

  Future<void> _initializeData() async {
    // Load today's data
    await _loadTodayData();
  }

  void _setupNotificationCallback() {
    _notificationService.setNotificationTapCallback(_handleNotificationTap);
    
    // Check if app was launched by a notification
    final initialNotificationId = _notificationService.getInitialNotificationId();
    if (initialNotificationId != null) {
      // Handle the initial notification after a short delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialNotificationId);
      });
    }
  }

  Future<void> _handleNotificationTap(int notificationId) async {
    debugPrint('🔔 Notification tapped with ID: $notificationId');

    try {
      // Decode notification ID: medicineId * 100 + reminderIndex
      final medicineId = notificationId ~/ 100;
      final reminderIndex = notificationId % 100;

      debugPrint('🔍 Decoded: medicineId=$medicineId, reminderIndex=$reminderIndex');

      // Find the medicine
      final db = await _dbService.database;
      final medicineResult = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
      );

      if (medicineResult.isEmpty) {
        debugPrint('❌ Medicine not found for ID: $medicineId');
        return;
      }

      final medicine = medicineResult.first;
      final reminderTimes = (medicine['reminderTimes'] as String?)?.split(',') ?? [];

      if (reminderIndex >= reminderTimes.length) {
        debugPrint('❌ Reminder index $reminderIndex out of range for medicine $medicineId');
        return;
      }

      final reminderTime = reminderTimes[reminderIndex].trim();
      debugPrint('✅ Found reminder time: $reminderTime for medicine: ${medicine['name']}');

      // Find today's schedule for this medicine and time
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final scheduleResult = await db.query(
        'schedules',
        where: 'medicineId = ? AND date(scheduledDate) = ? AND scheduledTime = ?',
        whereArgs: [medicineId, todayStr, reminderTime],
      );

      if (scheduleResult.isEmpty) {
        debugPrint('❌ No schedule found for medicine $medicineId at $reminderTime today');
        return;
      }

      final schedule = scheduleResult.first;
      final scheduleId = schedule['id'] as int?;
      final status = schedule['status'] as String?;

      if (scheduleId == null || status == null) {
        debugPrint('❌ Invalid schedule data');
        return;
      }

      debugPrint('📋 Schedule status: $status for schedule ID: $scheduleId');

      // Only show notification dialog if schedule is still pending
      if (status == _statusPending && mounted) {
        final medicineName = medicine['name'] as String? ?? 'Unknown Medicine';
        final dosage = medicine['dosage'] as String? ?? '';

        debugPrint('💊 Showing reminder dialog for $medicineName');

        // Show dialog to mark as taken or missed
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Medicine Reminder'),
            content: Text('Time to take your $medicineName ($dosage)'),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint('🚫 User tapped "Missed" for schedule $scheduleId');
                  Navigator.of(context).pop();
                  _markAsMissed(scheduleId, medicineId);
                },
                child: const Text('Missed'),
              ),
              ElevatedButton(
                onPressed: () {
                  debugPrint('✅ User tapped "Taken" for schedule $scheduleId');
                  Navigator.of(context).pop();
                  _markAsTaken(scheduleId, medicineId);
                },
                child: const Text('Taken'),
              ),
            ],
          ),
        );
      } else {
        debugPrint('⚠️ Notification tapped but schedule status is "$status" (not pending), dialog not shown');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing notification: $e'),
            backgroundColor: AppColors.red,
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
    // No need for additional setState since _loadTodaySchedules already calls it
  }

  Future<void> _loadTodaySchedules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return; // No user logged in

    final db = await _dbService.database;
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Check for overdue schedules and mark them as missed
    try {
      await _scheduler.markOverdueSchedulesAsMissed();
      debugPrint('✅ Checked for overdue schedules');
    } catch (e) {
      debugPrint('⚠️ Failed to check overdue schedules: $e');
    }

    // Get all schedules for today with medicine details, filtered by current user's uid
    final schedules = await db.rawQuery('''
      SELECT s.*, m.name, m.dosage, m.iconColor
      FROM schedules s
      INNER JOIN medicines m ON s.medicineId = m.id
      WHERE date(s.scheduledDate) = ? AND m.uid = ?
      ORDER BY s.scheduledTime ASC
    ''', [todayStr, currentUser.uid]);

    // Note: Overdue checking is handled by markOverdueSchedulesAsMissed() in main.dart on app start
    // No need to check for overdue schedules here to avoid duplicate processing

    setState(() {
      _todaySchedules = schedules;
      _totalDoses = schedules.length;
      _takenDoses = schedules.where((s) => s['status'] == _statusTaken).length;
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
      if (status == _statusPending) {
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
      } else if (status == _statusMissed) {
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
    debugPrint('🚫 Marking schedule $scheduleId as missed for medicine $medicineId');
    await _scheduler.markAsMissed(scheduleId, medicineId);
    await _loadTodayData();
    debugPrint('✅ Successfully marked schedule as missed and refreshed UI');
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

    final isTaken = status == _statusTaken;
    final isMissed = status == _statusMissed;
    final isPending = status == _statusPending;

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
      timeIconColor = AppColors.grey;
      timeTextColor = AppColors.grey;
      buttonBackgroundColor = AppColors.grey;
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

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, AppRoutes.medicineDetail, arguments: medicineId);
        if (result == 'deleted' && mounted) {
          // Refresh the medicine list after deletion
          await _loadTodayData();
        }
      },
      child: Container(
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
                  DateTimeHelpers.formatTime12Hour(time),
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
      ),
    );
  }
}
