import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

/// Notification Service
/// Handles scheduling and displaying local notifications for medicine reminders
/// Uses Android-recommended APIs for reliable notifications with battery optimization enabled
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(int)? _onNotificationTapCallback;
  int? _initialNotificationId;

  /// Set callback for notification tap handling
  void setNotificationTapCallback(Function(int) callback) {
    _onNotificationTapCallback = callback;
  }

  /// Get the notification ID that launched the app (if any)
  int? getInitialNotificationId() {
    final id = _initialNotificationId;
    _initialNotificationId = null; // Clear after reading
    return id;
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
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings for both platforms
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    debugPrint('✅ Notification plugin initialized');

    // Check for initial notification that launched the app
    final initialNotification = await _notifications.getNotificationAppLaunchDetails();
    if (initialNotification?.didNotificationLaunchApp == true) {
      _initialNotificationId = initialNotification?.notificationResponse?.id;
      debugPrint('📱 App launched by notification ID: $_initialNotificationId');
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
    // Handle notification tap - call the callback with notification ID
    final notificationId = response.id;
    if (notificationId != null && _onNotificationTapCallback != null) {
      _onNotificationTapCallback!(notificationId);
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
      firstFireDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
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

