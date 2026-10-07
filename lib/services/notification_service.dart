import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:medicine_reminder_app/models/medicine_model.dart';
import 'package:medicine_reminder_app/services/db/sqlite_service.dart';
import 'package:medicine_reminder_app/services/schedule_planner.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

const _medicineAndroidActions = <AndroidNotificationAction>[
  AndroidNotificationAction(
    'taken',
    'Taken',
    showsUserInterface: false,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    'snooze_10',
    'Snooze 10 min',
    showsUserInterface: false,
    cancelNotification: true,
  ),
];

final _medicineDarwinActions = <DarwinNotificationAction>[
  DarwinNotificationAction.plain('taken', 'Taken'),
  DarwinNotificationAction.plain('snooze_10', 'Snooze 10 min'),
];

final _medicineDarwinCategories = <DarwinNotificationCategory>[
  DarwinNotificationCategory(
    'medicine_reminder',
    actions: _medicineDarwinActions,
  ),
];

/// Notification Service
/// Handles scheduling and displaying local notifications for medicine reminders
/// Uses Android-recommended APIs for reliable notifications with battery optimization enabled
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static int lowStockNotificationIdForMedicine(int medicineId) => -medicineId;

  bool _initialized = false;
  Function(NotificationResponse)? _onNotificationTapCallback;
  NotificationResponse? _initialNotificationResponse;

  /// Set callback for notification tap handling
  void setNotificationTapCallback(Function(NotificationResponse) callback) {
    _onNotificationTapCallback = callback;
  }

  void clearNotificationTapCallback() {
    _onNotificationTapCallback = null;
  }

  NotificationResponse? getInitialNotificationResponse() {
    final response = _initialNotificationResponse;
    _initialNotificationResponse = null;
    return response;
  }

  /// Initialize notification service
  /// Must be called before scheduling any notifications
  /// Sets up timezone data and notification channels for reliable delivery
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔧 Initializing notification service...');

    // Initialize timezone data first - critical for accurate scheduling
    tz.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      debugPrint('Timezone detection failed; using Asia/Karachi: $e');
    }
    debugPrint('Timezone data initialized, local timezone: ${tz.local.name}');

    // Android initialization settings with proper icon
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings with full permissions
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: _medicineDarwinCategories,
    );

    // Initialization settings for both platforms
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          notificationResponseBackgroundHandler,
    );
    debugPrint('✅ Notification plugin initialized');

    // Check for initial notification that launched the app
    final initialNotification = await _notifications.getNotificationAppLaunchDetails();
    if (initialNotification?.didNotificationLaunchApp == true) {
      _initialNotificationResponse = initialNotification?.notificationResponse;
      debugPrint('📱 App launched by notification ID: ${_initialNotificationResponse?.id}');
    }

    // Create notification channel for Android 8+ with high importance and sound
    await _createNotificationChannel();
    debugPrint('📢 Notification channel created');

    // Request permissions if not already requested
    await requestPermission();

    _initialized = true;
    debugPrint('🎉 Notification service fully initialized');
  }

  /// Check if notification permissions are granted
  Future<bool> hasPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        return await androidPlugin.areNotificationsEnabled() ?? true;
      } catch (e) {
        return true;
      }
    }
    return true;
  }

  Future<bool> exactAlarmsGranted() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;

    try {
      return await androidPlugin.canScheduleExactNotifications() ?? true;
    } catch (e) {
      debugPrint('Could not check exact-alarm access: $e');
      return false;
    }
  }

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> requestPermission() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.requestNotificationsPermission() ??
            await hasPermission();
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request both permissions after an explicit user action.
  Future<void> requestReminderPermissions() async {
    await requestPermission();
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Could not request exact-alarm access: $e');
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return AndroidScheduleMode.exactAllowWhileIdle;

    try {
      final canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      return canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      debugPrint('Could not check exact-alarm access; using inexact mode: $e');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  String? _nextFireTime(PendingNotificationRequest notification) {
    final payload = notification.payload;
    if (payload == null) return null;

    if (payload.startsWith('daily:')) {
      final parts = payload.substring('daily:'.length).split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      return next.toString();
    }

    if (payload.startsWith('at:')) {
      return DateTime.tryParse(payload.substring('at:'.length))?.toLocal().toString();
    }
    if (payload.startsWith('reminder:')) {
      final parts = payload.split(':');
      if (parts.length < 5) return null;
        final fireEpoch = int.tryParse(parts[4]);
        final firstFire = fireEpoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fireEpoch).toLocal();
      if (firstFire == null) return null;
      final now = tz.TZDateTime.now(tz.local);
      if (parts[3] == 'Monthly') return firstFire.toLocal().toString();
      final hour = firstFire.hour;
      final minute = firstFire.minute;
      if (parts[3] == 'Daily') {
        var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
        return next.toString();
      }
      if (parts[3] == 'Weekly') {
        final weekday = firstFire.weekday;
        var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        while (next.weekday != weekday || !next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next.toString();
      }
    }
    return null;
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'medicine_reminder_channel',
      'Medicine Reminders',
      description: 'Notifications for medicine reminders',
      importance: Importance.high,
      playSound: true,
      showBadge: true,
      enableVibration: true,
      enableLights: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.actionId == 'taken' || response.actionId == 'snooze_10') {
      unawaited(_processMedicineAction(response));
      return;
    }

    // Handle notification tap - call the callback with notification ID
    if (_onNotificationTapCallback != null) {
      _onNotificationTapCallback!(response);
    }
  }

  /// Schedule a notification for a specific date and time
  ///
  /// [id] - Unique notification ID
  /// [title] - Notification title
  /// [body] - Notification body/message
  /// [scheduledDate] - Date and time when notification should appear
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Convert DateTime to TZDateTime
    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'medicine_reminder_channel',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      notificationDetails,
      androidScheduleMode: await _androidScheduleMode(),
      payload: 'at:${tzDateTime.toIso8601String()}',
    );
  }

  Future<void> scheduleMedicineReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstFireDate,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (!_initialized) await initialize();
    if (!await hasPermission()) {
      throw Exception('Notification permission is not granted');
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_reminder_channel',
        'Medicine Reminders',
        channelDescription: 'Daily notifications for medicine reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        actions: _medicineAndroidActions,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'medicine_reminder',
      ),
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      firstFireDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
  }

  static int snoozeNotificationIdFor(int reminderNotificationId) =>
      -500000000 - (reminderNotificationId % 500000000);

  Future<void> scheduleSnoozedReminder({
    required int reminderNotificationId,
    required int scheduleId,
    required int medicineId,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    final fireDate = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_reminder_channel',
        'Medicine Reminders',
        channelDescription: 'Snoozed medicine reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.zonedSchedule(
      snoozeNotificationIdFor(reminderNotificationId),
      title,
      body,
      fireDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      payload: 'snooze:$scheduleId:$medicineId',
    );
  }

  /// Schedule a daily repeating medicine reminder notification
  /// Uses Android-recommended zonedSchedule API with exactAllowWhileIdle mode
  /// This ensures notifications fire on time even with battery optimization enabled
  /// Works on Android 10+ by respecting system doze and app standby restrictions
  ///
  /// [id] - Unique notification ID (medicineId * 100 + timeIndex)
  /// [title] - Notification title
  /// [body] - Notification body/message with medicine name
  /// [time] - Time of day for the reminder (HH:mm)
  Future<void> scheduleDailyMedicineReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    debugPrint('🚀 Starting to schedule daily medicine reminder...');
    debugPrint('📋 Parameters: id=$id, title="$title", body="$body", time=${time.hour}:${time.minute.toString().padLeft(2, '0')}');

    if (!_initialized) {
      debugPrint('🔧 Notification service not initialized, initializing now...');
      await initialize();
      debugPrint('✅ Notification service initialized successfully');
    }

      final notificationsEnabled = await hasPermission();
      debugPrint('Notifications enabled: $notificationsEnabled');
      if (!notificationsEnabled) {
        throw Exception('Notification permission is not granted');
      }

      // Cancel any existing notification for this ID first
      try {
        debugPrint('🗑️ Cancelling existing notification ID $id...');
        await _notifications.cancel(id);
        debugPrint('✅ Successfully cancelled existing notification ID $id');
      } catch (e) {
        debugPrint('⚠️ Failed to cancel existing notification ID $id: $e');
        // Continue anyway, this is not critical
      }

      // Get the next occurrence of the specified time using local timezone
      // This ensures accurate scheduling regardless of device timezone settings
      final now = tz.TZDateTime.now(tz.local);
    late tz.TZDateTime scheduledDate;
    
    try {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      debugPrint('📅 Current time: $now');
      debugPrint('⏰ Requested time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      debugPrint('📅 Initial scheduled date: $scheduledDate');

      // If the time has already passed today, schedule for tomorrow
      // This prevents immediate triggering and ensures future scheduling
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        debugPrint('📅 Time already passed today, scheduling for tomorrow: $scheduledDate');
      } else {
        debugPrint('📅 Time is in the future today: $scheduledDate');
      }

      // Validate that scheduled time is not in the past
      if (scheduledDate.isBefore(now)) {
        const errorMsg = '❌ ERROR: Scheduled time is still in the past';
        debugPrint('$errorMsg: $scheduledDate (current: $now)');
        throw Exception('$errorMsg: $scheduledDate');
      }

      // Validate the time is reasonable (not more than 24 hours in the future for daily repeats)
      final timeUntilScheduled = scheduledDate.difference(now);
      debugPrint('⏱️ Time until notification: $timeUntilScheduled');

      if (timeUntilScheduled > const Duration(hours: 24)) {
        debugPrint('⚠️ WARNING: Scheduled time is more than 24 hours in the future: $timeUntilScheduled');
      }
      if (timeUntilScheduled < const Duration(minutes: 1)) {
        debugPrint('⚠️ WARNING: Scheduled time is less than 1 minute in the future: $timeUntilScheduled');
      }

      // Android notification details optimized for battery-efficient delivery
      const androidDetails = AndroidNotificationDetails(
        'medicine_reminder_channel',
        'Medicine Reminders',
        channelDescription: 'Daily notifications for medicine reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Notification details for both platforms
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduleMode = await _androidScheduleMode();

      // Schedule the daily repeating notification using zonedSchedule
      // matchDateTimeComponents: DateTimeComponents.time ensures daily repetition at the same time
      // androidScheduleMode: exactAllowWhileIdle allows delivery during doze mode
      // This is the Android-recommended approach that works with battery optimization enabled
      debugPrint('📅 Attempting to schedule notification with primary mode: $scheduleMode');
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at the same time
        payload: 'daily:${time.hour}:${time.minute}',
      );

      debugPrint('✅ Successfully scheduled daily notification ID $id for ${time.hour}:${time.minute.toString().padLeft(2, '0')} using mode: $scheduleMode');

      // Verify the notification was scheduled by checking pending notifications
      try {
        final pending = await getPendingNotifications();
        final scheduledExists = pending.any((n) => n.id == id);
        debugPrint('🔍 Verification: Notification ID $id ${scheduledExists ? 'found' : 'NOT FOUND'} in pending notifications (${pending.length} total)');
      } catch (verifyError) {
        debugPrint('⚠️ Could not verify notification scheduling: $verifyError');
      }

    } catch (primaryError) {
      debugPrint('❌ Failed to schedule notification ID $id with primary mode, trying fallback: $primaryError');

      // Try fallback scheduling mode
      try {
        debugPrint('🔄 Attempting fallback scheduling...');
        const fallbackNotificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminder_channel',
            'Medicine Reminders',
            channelDescription: 'Daily notifications for medicine reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          fallbackNotificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily:${time.hour}:${time.minute}',
        );
        debugPrint('✅ Successfully scheduled notification ID $id with fallback mode');

        // Verify fallback scheduling
        try {
          final pending = await getPendingNotifications();
          final scheduledExists = pending.any((n) => n.id == id);
          debugPrint('🔍 Fallback verification: Notification ID $id ${scheduledExists ? 'found' : 'NOT FOUND'} in pending notifications');
        } catch (verifyError) {
          debugPrint('⚠️ Could not verify fallback notification scheduling: $verifyError');
        }

      } catch (fallbackError) {
        debugPrint('❌ Failed to schedule notification ID $id even with fallback: $fallbackError');
        debugPrint('💥 TERMINAL DEBUG: Notification scheduling completely failed for ID $id');
        debugPrint('💥 TERMINAL DEBUG: Title: "$title"');
        debugPrint('💥 TERMINAL DEBUG: Body: "$body"');
        debugPrint('💥 TERMINAL DEBUG: Time: ${time.hour}:${time.minute}');
        debugPrint('💥 TERMINAL DEBUG: Current Time: ${tz.TZDateTime.now(tz.local)}');
        debugPrint('💥 TERMINAL DEBUG: Primary Error: $primaryError');
        debugPrint('💥 TERMINAL DEBUG: Fallback Error: $fallbackError');
        rethrow;
      }
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelMedicineNotifications(int medicineId) async {
    for (var index = 0; index < 100; index++) {
      try {
        await _notifications.cancel(medicineId * 100 + index);
      } catch (e) {
        debugPrint('Failed to cancel reminder notification: $e');
      }
    }
    try {
      await _notifications.cancel(lowStockNotificationIdForMedicine(medicineId));
    } catch (e) {
      debugPrint('Failed to cancel low-stock notification: $e');
    }

    try {
      final pending = await _notifications.pendingNotificationRequests();
      for (final notification in pending) {
        final payload = notification.payload?.split(':') ?? const <String>[];
        if (payload.length == 3 &&
            payload[0] == 'snooze' &&
            int.tryParse(payload[2]) == medicineId) {
          await _notifications.cancel(notification.id);
        }
      }
    } catch (e) {
      debugPrint('Failed to cancel snoozed reminder notifications: $e');
    }
  }

  /// Debug method to print all pending notifications to terminal
  Future<void> debugPrintPendingNotifications() async {
    try {
      debugPrint('🔍 DEBUG: Checking pending notifications...');
      final pending = await getPendingNotifications();
      debugPrint('📋 DEBUG: Found ${pending.length} pending notifications:');
      
      for (final notification in pending) {
        debugPrint('🔔 DEBUG: ID=${notification.id}, Title="${notification.title}", Body="${notification.body}"');
      }
      
      if (pending.isEmpty) {
        debugPrint('📋 DEBUG: No pending notifications found');
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Failed to get pending notifications: $e');
    }
  }

  /// Show an immediate notification (for testing)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'medicine_reminder_channel',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  /// Schedule a test notification in 2 minutes (for debugging scheduling)
  Future<void> scheduleTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    final testTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
    debugPrint('🧪 Scheduling test notification for: $testTime');

    const androidDetails = AndroidNotificationDetails(
      'medicine_reminder_channel',
      'Medicine Reminders',
      channelDescription: 'Test notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        999999, // Use a high ID for test notifications
        'Test Notification 🧪',
        'This is a test notification scheduled for 2 minutes from now',
        testTime,
        notificationDetails,
        androidScheduleMode: await _androidScheduleMode(),
        payload: 'at:${testTime.toIso8601String()}',
      );
      debugPrint('✅ Test notification scheduled successfully');
    } catch (e) {
      debugPrint('❌ Failed to schedule test notification: $e');
      rethrow;
    }
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Found ${pending.length} pending notifications');
      for (final notification in pending) {
        debugPrint('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }
      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// Get comprehensive notification status for debugging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    if (!_initialized) {
      await initialize();
    }

    final status = <String, dynamic>{};

    try {
      // Check permissions
      status['hasPermission'] = await hasPermission();
      debugPrint('🔐 Notification permission: ${status['hasPermission']}');

        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
        status['notificationsEnabled'] = androidPlugin == null
          ? await hasPermission()
          : await androidPlugin.areNotificationsEnabled() ?? false;
        status['exactAlarmsGranted'] = await exactAlarmsGranted();

      // Get pending notifications
      final pending = await getPendingNotifications();
      status['pendingCount'] = pending.length;
      status['pendingNotifications'] = pending.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'nextFireTime': _nextFireTime(n),
      }).toList();
      debugPrint('Notifications enabled: ${status['notificationsEnabled']}');
      debugPrint('Exact alarms granted: ${status['exactAlarmsGranted']}');
      for (final notification in status['pendingNotifications']) {
        debugPrint('Pending ${notification['id']} next fires at ${notification['nextFireTime'] ?? 'unknown'}');
      }

      // Current timezone info
      status['timezone'] = tz.local.name;
      debugPrint('Timezone: ${status['timezone']}');
      status['currentTime'] = tz.TZDateTime.now(tz.local).toString();

    } catch (e) {
      debugPrint('❌ Error getting notification status: $e');
      status['error'] = e.toString();
    }

    return status;
  }
}

@pragma('vm:entry-point')
void notificationResponseBackgroundHandler(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_processMedicineAction(response));
}

Future<void> _processMedicineAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId != 'taken' && actionId != 'snooze_10') return;

  final service = NotificationService();
  try {
    await service.initialize();
    final db = await SQLiteService().database;
    final payload = response.payload?.split(':') ?? const <String>[];
    int? medicineId;
    int? scheduleId;
    int? reminderIndex;
    String? frequency;
    Map<String, dynamic>? reminderMedicine;

    if (payload.length >= 5 && payload[0] == 'reminder') {
      medicineId = int.tryParse(payload[1]);
      reminderIndex = int.tryParse(payload[2]);
      if (medicineId == null) return;
      final medicineRows = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
        limit: 1,
      );
      if (medicineRows.isEmpty) return;
      reminderMedicine = medicineRows.first;
      frequency = payload[3];
      final reminderTimes =
          (reminderMedicine['reminderTimes'] as String? ?? '')
          .split(',')
          .map((value) => value.trim())
          .toList();
      if (reminderIndex == null ||
          reminderIndex < 0 ||
          reminderIndex >= reminderTimes.length) {
        return;
      }
      final scheduledTime = reminderTimes[reminderIndex];
      final now = DateTime.now();
      final pending = await db.query(
        'schedules',
        where: 'medicineId = ? AND scheduledTime = ? AND status = ?',
        whereArgs: [medicineId, scheduledTime, 'pending'],
      );
      for (final row in pending) {
        final scheduledDate = DateTime.parse(row['scheduledDate'] as String).toLocal();
        if (scheduledDate.year == now.year &&
            scheduledDate.month == now.month &&
            scheduledDate.day == now.day) {
          scheduleId = row['id'] as int;
          break;
        }
      }
    } else if (payload.length == 3 && payload[0] == 'snooze') {
      scheduleId = int.tryParse(payload[1]);
      medicineId = int.tryParse(payload[2]);
    }

    if (scheduleId == null || medicineId == null) return;
    final schedule = await db.query(
      'schedules',
      where: 'id = ? AND medicineId = ? AND status = ?',
      whereArgs: [scheduleId, medicineId, 'pending'],
      limit: 1,
    );
    if (schedule.isEmpty) return;
    final monthlyIndex = reminderIndex;
    final monthlyMedicine = reminderMedicine;

    if (actionId == 'snooze_10') {
      final medicine = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId],
        limit: 1,
      );
      if (medicine.isEmpty) return;
      await service.scheduleSnoozedReminder(
        reminderNotificationId: response.id ?? medicineId * 100,
        scheduleId: scheduleId,
        medicineId: medicineId,
        title: 'Medicine Reminder',
        body: 'Snoozed: it\'s time to take ${medicine.first['name']}',
      );
      if (frequency == 'Monthly' &&
          monthlyIndex != null &&
          monthlyMedicine != null) {
        await _rearmMonthlyReminder(
          service,
          db,
          medicineId,
          monthlyIndex,
          monthlyMedicine,
        );
      }
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var stockCount = 0;
    String? medicineName;
    await db.transaction((transaction) async {
      final currentSchedule = await transaction.query(
        'schedules',
        where: 'id = ? AND medicineId = ? AND status = ?',
        whereArgs: [scheduleId, medicineId, 'pending'],
        limit: 1,
      );
      if (currentSchedule.isEmpty) return;

      final updated = await transaction.update(
        'schedules',
        {'status': 'taken', 'takenAt': now.toIso8601String()},
        where: 'id = ? AND status = ?',
        whereArgs: [scheduleId, 'pending'],
      );
      if (updated != 1) return;

      final values = currentSchedule.first;
      await transaction.insert(
        'history',
        {
          'medicineId': medicineId,
          'scheduleId': scheduleId,
          'scheduledDate': values['scheduledDate'],
          'scheduledTime': values['scheduledTime'],
          'status': 'taken',
          'takenAt': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await transaction.rawUpdate(
        'UPDATE medicines SET stockCount = CASE WHEN stockCount > 0 THEN stockCount - 1 ELSE 0 END, updatedAt = ? WHERE id = ?',
        [now.toIso8601String(), medicineId],
      );
      final updatedMedicine = await transaction.query(
        'medicines',
        columns: ['name', 'stockCount'],
        where: 'id = ?',
        whereArgs: [medicineId],
        limit: 1,
      );
      if (updatedMedicine.isNotEmpty) {
        medicineName = updatedMedicine.first['name'] as String?;
        stockCount = updatedMedicine.first['stockCount'] as int? ?? 0;
      }
    });

    if (medicineName != null && stockCount <= 5) {
      await service.scheduleNotification(
        id: -medicineId,
        title: stockCount == 0 ? 'Out of Stock Alert' : 'Low Stock Alert',
        body: stockCount == 0
            ? '$medicineName is out of stock'
            : '$medicineName has only $stockCount ${stockCount == 1 ? 'tablet' : 'tablets'} remaining',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 1)),
      );
    }
    if (frequency == 'Monthly' &&
        monthlyMedicine != null &&
        monthlyIndex != null) {
      await _rearmMonthlyReminder(
        service,
        db,
        medicineId,
        monthlyIndex,
        monthlyMedicine,
      );
    }
  } catch (error) {
    debugPrint('Could not process notification action: $error');
  }
}

Future<void> _rearmMonthlyReminder(
  NotificationService service,
  Database db,
  int medicineId,
  int reminderIndex,
  Map<String, dynamic> medicineRow,
) async {
  final medicine = Medicine.fromMap(medicineRow);
  if (reminderIndex >= medicine.reminderTimes.length) return;
  final timeParts = medicine.reminderTimes[reminderIndex].split(':');
  if (timeParts.length != 2) return;
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  if (hour == null || minute == null) return;

  final time = TimeOfDay(hour: hour, minute: minute);
  final next = MedicineSchedulePlanner.nextOccurrence(
    medicine: medicine,
    time: time,
    now: tz.TZDateTime.now(tz.local),
  );
  if (next == null) return;

  final scheduledTime = medicine.reminderTimes[reminderIndex];
  final dateStr = next.toIso8601String().split('T').first;
  final existing = await db.query(
    'schedules',
    where: 'medicineId = ? AND substr(scheduledDate, 1, 10) = ? AND scheduledTime = ?',
    whereArgs: [medicineId, dateStr, scheduledTime],
    limit: 1,
  );
  if (existing.isEmpty) {
    await db.insert('schedules', {
      'medicineId': medicineId,
      'scheduledDate': next.toIso8601String(),
      'scheduledTime': scheduledTime,
      'status': 'pending',
      'createdAt': tz.TZDateTime.now(tz.local).toIso8601String(),
    });
  }

  await service.scheduleMedicineReminder(
    id: medicineId * 100 + reminderIndex,
    title: 'Medicine Reminder',
    body: 'It\'s time to take ${medicine.name}',
    firstFireDate: next,
    payload: 'reminder:$medicineId:$reminderIndex:Monthly:${next.millisecondsSinceEpoch}',
  );
}
