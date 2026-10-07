import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../models/medicine_model.dart';
import '../../routes/app_routes.dart';
import '../../services/db/sqlite_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../models/user_model.dart' as local_user;
import '../../widgets/today_widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenRefills;

  const HomeScreen({
    super.key,
    this.onOpenProfile,
    this.onOpenRefills,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const String _pending = 'pending';
  static const String _taken = 'taken';
  static const String _missed = 'missed';

  final SQLiteService _dbService = SQLiteService();
  final ReminderScheduler _scheduler = ReminderScheduler();
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _todaySchedules = [];
  local_user.User? _localUser;
  int _totalDoses = 0;
  int _takenDoses = 0;
  int _medicineCount = 0;
  DateTime _now = DateTime.now();
  late Future<Map<String, dynamic>> _notificationStatus;
  Timer? _clockTimer;
  Timer? _dataTimer;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationStatus = Future.value(const <String, dynamic>{});
    _notificationService.setNotificationTapCallback(_handleNotificationTap);
    _initializeData();
    final initialResponse = _notificationService
        .getInitialNotificationResponse();
    if (initialResponse != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _handleNotificationTap(initialResponse);
      });
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _dataTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadTodayData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _dataTimer?.cancel();
    _notificationService.clearNotificationTapCallback();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _rescheduleNotifications();
    _loadTodayData();
    _refreshNotificationStatus();
    if (mounted) setState(() => _now = DateTime.now());
  }

  Future<void> _rescheduleNotifications() async {
    try {
      await _scheduler.cancelExpiredReminders();
      await _scheduler.rescheduleAllNotifications();
    } catch (error) {
      debugPrint('Failed to refresh medicine reminders: $error');
    }
  }

  Future<void> _initializeData() async {
    await _loadTodayData();
    await _refreshNotificationStatus();
  }

  Future<void> _refreshNotificationStatus() async {
    try {
      final status = await _notificationService.getNotificationStatus();
      final statusError = status['error'];
      if (statusError is String) throw StateError(statusError);
      if (mounted) {
        setState(() {
          _notificationStatus = Future.value(status);
        });
      }
    } catch (error) {
      if (mounted) _showError('Could not check reminder permissions', error);
    }
  }

  Future<void> _loadTodayData() async {
    if (_loadingData) return;
    _loadingData = true;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _todaySchedules = [];
          _localUser = null;
          _totalDoses = 0;
          _takenDoses = 0;
          _medicineCount = 0;
          _now = DateTime.now();
        });
        return;
      }

      final db = await _dbService.database;
      await _scheduler.markOverdueSchedulesAsMissed();
      final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final schedules = await db.rawQuery(
        '''
        SELECT s.*, m.name, m.dosage, m.iconColor, m.stockCount
        FROM schedules s
        INNER JOIN medicines m ON s.medicineId = m.id
        WHERE substr(s.scheduledDate, 1, 10) = ? AND m.uid = ?
        ORDER BY s.scheduledTime ASC
      ''',
        [todayString, currentUser.uid],
      );
      final medicines = await db.query(
        'medicines',
        columns: ['id'],
        where: 'uid = ?',
        whereArgs: [currentUser.uid],
      );
      final users = await db.query(
        'users',
        where: 'uid = ?',
        whereArgs: [currentUser.uid],
        limit: 1,
      );
      final localUser = users.isEmpty
          ? null
          : local_user.User.fromMap(users.first);

      if (!mounted) return;
      setState(() {
        _todaySchedules = schedules;
        _localUser = localUser;
        _totalDoses = schedules.length;
        _takenDoses = schedules.where((row) => row['status'] == _taken).length;
        _medicineCount = medicines.length;
        _now = DateTime.now();
      });
    } catch (error) {
      if (mounted) _showError('Could not refresh today’s schedule', error);
    } finally {
      _loadingData = false;
    }
  }

  Future<void> _refreshToday() async {
    await Future.wait([_loadTodayData(), _refreshNotificationStatus()]);
  }

  void _showError(String message, Object error) {
    debugPrint('$message: $error');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAsTaken(
    int scheduleId,
    int medicineId, {
    bool lateDose = false,
  }) async {
    try {
      final transitioned = await _scheduler.markAsTaken(
        scheduleId,
        medicineId,
        lateDose: lateDose,
      );
      await _loadTodayData();
      if (!mounted) return;
      if (transitioned) unawaited(_performTakenHaptic());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transitioned
                ? 'Dose marked as taken'
                : 'This dose was already updated',
          ),
          backgroundColor: transitioned ? AppColors.green : AppColors.orange,
        ),
      );
    } catch (error) {
      if (mounted) _showError('Could not mark dose as taken', error);
    }
  }

  Future<void> _performTakenHaptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (error) {
      debugPrint('Could not play dose confirmation haptic: $error');
    }
  }

  Future<void> _snooze(int scheduleId, int medicineId) async {
    try {
      final snoozed = await _scheduler.snoozeSchedule(scheduleId, medicineId);
      await _loadTodayData();
      if (!mounted) return;
      final until = DateFormat(
        'h:mm a',
      ).format(DateTime.now().add(const Duration(minutes: 10)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snoozed ? 'Snoozed until $until' : 'Dose is no longer pending',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError('Could not snooze reminder', error);
    }
  }

  Future<void> _markAsMissed(int scheduleId, int medicineId) async {
    try {
      await _scheduler.markAsMissed(scheduleId, medicineId);
      await _loadTodayData();
    } catch (error) {
      if (mounted) _showError('Could not update dose status', error);
    }
  }

  Future<void> _requestReminderPermissions() async {
    try {
      await _notificationService.requestReminderPermissions();
      await _refreshNotificationStatus();
    } catch (error) {
      if (mounted) _showError('Could not request reminder permissions', error);
    }
  }

  Future<void> _handleNotificationTap(NotificationResponse response) async {
    try {
      await _processNotificationTap(response);
    } catch (error) {
      if (mounted) _showError('Could not open medicine reminder', error);
    }
  }

  Future<void> _processNotificationTap(NotificationResponse response) async {
    if (response.actionId == 'taken' || response.actionId == 'snooze_10') {
      return;
    }
    final notificationId = response.id;
    final payload = response.payload;
    if (notificationId == null ||
        notificationId < 100 ||
        payload == null ||
        !payload.startsWith('reminder:')) {
      return;
    }
    final parts = payload.split(':');
    if (parts.length < 5) return;
    final medicineId = int.tryParse(parts[1]);
    final reminderIndex = int.tryParse(parts[2]);
    if (medicineId == null ||
        reminderIndex == null ||
        notificationId ~/ 100 != medicineId) {
      return;
    }

    final db = await _dbService.database;
    final medicineRows = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
      limit: 1,
    );
    if (medicineRows.isEmpty) return;
    final medicine = medicineRows.first;
    final reminderTimes = (medicine['reminderTimes'] as String? ?? '')
        .split(',')
        .map((value) => value.trim())
        .toList();
    if (reminderIndex < 0 || reminderIndex >= reminderTimes.length) return;

    if (parts[3] == 'Monthly') {
      try {
        await _scheduler.scheduleMedicineReminders(Medicine.fromMap(medicine));
      } catch (error) {
        debugPrint('Failed to re-arm monthly reminder: $error');
      }
    }

    final reminderTime = reminderTimes[reminderIndex];
    final today = DateTime.now();
    final pending = await db.query(
      'schedules',
      where: 'medicineId = ? AND scheduledTime = ? AND status = ?',
      whereArgs: [medicineId, reminderTime, _pending],
    );
    Map<String, dynamic>? todaySchedule;
    for (final row in pending) {
      final date = DateTime.parse(row['scheduledDate'] as String).toLocal();
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        todaySchedule = row;
        break;
      }
    }
    if (todaySchedule == null || !mounted) return;

    final scheduleId = todaySchedule['id'] as int;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Medicine reminder'),
        content: Text(
          'Time to take ${medicine['name']} '
          '(${displayDosage(medicine['dosage'] as String?)})',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _markAsMissed(scheduleId, medicineId);
            },
            child: const Text('Missed'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _markAsTaken(scheduleId, medicineId);
            },
            child: const Text('Taken'),
          ),
        ],
      ),
    );
  }

  String _firstName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }
    final localName = _localUser?.fullName?.trim();
    if (localName != null && localName.isNotEmpty) {
      return localName.split(RegExp(r'\s+')).first;
    }
    return user?.email?.split('@').first ?? 'there';
  }

  String _dayPart() {
    if (_now.hour < 12) return 'Good morning';
    if (_now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Map<String, dynamic>? get _nextPendingDose {
    for (final schedule in _todaySchedules) {
      if (schedule['status'] == _pending) return schedule;
    }
    return null;
  }

  Map<String, dynamic>? get _firstMissedDose {
    for (final schedule in _todaySchedules) {
      if (schedule['status'] == _missed) return schedule;
    }
    return null;
  }

  String _timeGroup(Map<String, dynamic> schedule) {
    final hour = int.parse(
      (schedule['scheduledTime'] as String).split(':').first,
    );
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  DateTime _scheduledAt(Map<String, dynamic> schedule) {
    final parts = (schedule['scheduledDate'] as String)
        .substring(0, 10)
        .split('-')
        .map(int.parse)
        .toList();
    final time = (schedule['scheduledTime'] as String)
        .split(':')
        .map(int.parse)
        .toList();
    return DateTime(parts[0], parts[1], parts[2], time[0], time[1]);
  }

  Future<void> _openDetails(int medicineId) async {
    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.medicineDetail,
        arguments: medicineId,
      );
      if (mounted) await _loadTodayData();
    } catch (error) {
      if (mounted) _showError('Could not open medicine details', error);
    }
  }

  Future<void> _addFirstMedicine() async {
    try {
      final result = await Navigator.pushNamed(context, AppRoutes.addMedicine);
      if (mounted && result == true) await _loadTodayData();
    } catch (error) {
      if (mounted) _showError('Could not open Add Medicine', error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nextDose = _nextPendingDose;
    final firstMissedDose = _firstMissedDose;
    final groups = const ['Morning', 'Afternoon', 'Evening', 'Night'];
    final todayColors = TodayColors.of(context);

    return Scaffold(
      backgroundColor: todayColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshToday,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              AppSpacing.md,
              20,
              128,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dayPart()},',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: todayColors.primaryText),
                        ),
                        Text(
                          '${_firstName(user)}!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: todayColors.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          DateFormat('EEEE, MMM d').format(_now),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: todayColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Open profile',
                    child: InkWell(
                      onTap: widget.onOpenProfile,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: todayColors.avatarBackground,
                            foregroundColor: todayColors.avatarForeground,
                            child: user?.photoURL == null
                                ? _avatarInitial(context, user)
                                : ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          _avatarInitial(context, user),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              HealthBanner(
                status: _notificationStatus,
                onRequestPermissions: _requestReminderPermissions,
              ),
              NextDoseCard(
                state: nextDose != null
                    ? NextDoseCardState.pending
                    : _totalDoses == 0
                    ? NextDoseCardState.noDoses
                    : _takenDoses > 0
                    ? NextDoseCardState.allTaken
                    : NextDoseCardState.onlyMissed,
                missedCount: _todaySchedules
                    .where((row) => row['status'] == _missed)
                    .length,
                medicineName:
                    nextDose?['name'] as String? ??
                    firstMissedDose?['name'] as String? ??
                    '',
                dosage:
                    nextDose?['dosage'] as String? ??
                    firstMissedDose?['dosage'] as String? ??
                    'dose',
                scheduledAt: nextDose == null ? null : _scheduledAt(nextDose),
                now: _now,
                onTaken: nextDose == null
                    ? null
                    : () => _markAsTaken(
                        nextDose['id'] as int,
                        nextDose['medicineId'] as int,
                      ),
                onSnooze: nextDose == null
                    ? null
                    : () => _snooze(
                        nextDose['id'] as int,
                        nextDose['medicineId'] as int,
                      ),
                onLogLateDose: firstMissedDose == null
                    ? null
                    : () => _markAsTaken(
                        firstMissedDose['id'] as int,
                        firstMissedDose['medicineId'] as int,
                        lateDose: true,
                      ),
                onAddMedicine: _addFirstMedicine,
              ),
              const SizedBox(height: AppSpacing.md),
              ProgressStrip(taken: _takenDoses, total: _totalDoses),
              const SizedBox(height: AppSpacing.md),
              if (_medicineCount == 0)
                EmptyState(
                  title: 'Start with your first medicine',
                  message: 'Add a medicine to build today’s schedule.',
                  onAdd: _addFirstMedicine,
                )
              else if (_todaySchedules.isNotEmpty) ...[
                Text(
                  "Today's timeline",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: todayColors.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._buildTimelineSections(groups),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  DoseVisualStatus _status(String status) => switch (status) {
    _taken => DoseVisualStatus.taken,
    _missed => DoseVisualStatus.missed,
    _ => DoseVisualStatus.upcoming,
  };

  Widget _avatarInitial(BuildContext context, User? user) => Text(
        _firstName(user).isNotEmpty
            ? _firstName(user)[0].toUpperCase()
            : '?',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      );

  List<Widget> _buildTimelineSections(List<String> groups) {
    final sections = <Widget>[];
    for (final group in groups) {
      final schedules = _todaySchedules
          .where((schedule) => _timeGroup(schedule) == group)
          .toList();
      if (schedules.isEmpty) continue;

      sections.add(
        TimelineSection(
          title: group,
          children: [
            for (final schedule in schedules)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DoseTile(
                  key: ValueKey(schedule['id']),
                  name: schedule['name'] as String,
                  dosage: schedule['dosage'] as String? ?? '',
                  time: _parseTime(schedule['scheduledTime'] as String),
                  status: _status(schedule['status'] as String),
                  stockCount: schedule['stockCount'] as int? ?? 0,
                  onTaken: schedule['status'] == _pending
                      ? () => _markAsTaken(
                          schedule['id'] as int,
                          schedule['medicineId'] as int,
                        )
                      : null,
                  onLongPress: schedule['status'] == _missed
                      ? () => _markAsTaken(
                          schedule['id'] as int,
                          schedule['medicineId'] as int,
                          lateDose: true,
                        )
                      : null,
                  onRefillTap: widget.onOpenRefills,
                  onTap: () => _openDetails(schedule['medicineId'] as int),
                ),
              ),
          ],
        ),
      );
    }
    return sections;
  }
}
