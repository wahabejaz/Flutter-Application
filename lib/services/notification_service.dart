import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
    debugPrint('🌍 Timezone data initialized, local timezone: ${tz.local}');

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
    if (!_permissionsRequested) {
      await requestPermission();
    }

    _initialized = true;
    debugPrint('🎉 Notification service fully initialized');
  }

  bool _permissionsRequested = false;

  /// Check if notification permissions are granted
  Future<bool> hasPermission() async {
    // For Android 13+, check runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        // Check basic notification permission
        final notificationsEnabled = await androidPlugin.areNotificationsEnabled() ?? true;
        
        // For Android 12+, check exact alarm permission
        // For Android 9-11, exact alarms are allowed by default
        bool exactAlarmGranted = true;
        try {
          exactAlarmGranted = await androidPlugin.canScheduleExactNotifications() ?? true;
        } catch (e) {
          // canScheduleExactNotifications() not available on Android < 12, assume allowed
          exactAlarmGranted = true;
        }
        
        return notificationsEnabled && exactAlarmGranted;
      } catch (e) {
        // For older Android versions or if plugin fails, assume enabled
        return true;
      }
    }
    // For iOS, permissions are requested during initialization
    return true;
  }

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> requestPermission() async {
    if (_permissionsRequested) return await hasPermission();

    try {
      // Android 13+ permissions
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request basic notification permission
        final notificationsGranted = await androidPlugin.requestNotificationsPermission() ?? false;
        
        // Request exact alarm permission (Android 12+ only)
        bool exactAlarmGranted = true;
        try {
          exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission() ?? true;
        } catch (e) {
          // requestExactAlarmsPermission() not available on Android < 12, assume allowed
          exactAlarmGranted = true;
        }
        
        _permissionsRequested = true;
        return notificationsGranted && exactAlarmGranted;
      }

      // For iOS, permissions are handled in initialization settings
      _permissionsRequested = true;
      return true;
    } catch (e) {
      _permissionsRequested = true;
      return false;
    }
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

      // Check permissions before scheduling - critical for Android
      debugPrint('🔐 Checking notification permissions...');
      final hasPermission = await this.hasPermission();
      debugPrint('🔐 Permission status: $hasPermission');

      if (!hasPermission) {
        const errorMsg = '❌ Notification permissions not granted - cannot schedule reminders';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
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

      // Try exact scheduling first, fall back to exactAllowWhileIdle if it fails
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      try {
        debugPrint('🔧 Determining optimal scheduling mode...');
        // Check if we can use exact scheduling
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final canScheduleExact = await androidPlugin.canScheduleExactNotifications() ?? false;
          debugPrint('🔧 Can schedule exact notifications: $canScheduleExact');
          if (canScheduleExact) {
            scheduleMode = AndroidScheduleMode.exact;
            debugPrint('🎯 Using exact scheduling mode for better reliability');
          } else {
            debugPrint('⚡ Using exactAllowWhileIdle scheduling mode');
          }
        } else {
          debugPrint('⚠️ Android plugin not available, using exactAllowWhileIdle');
        }
      } catch (e) {
        debugPrint('⚠️ Could not determine scheduling mode, using exactAllowWhileIdle: $e');
      }

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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

      // Get pending notifications
      final pending = await getPendingNotifications();
      status['pendingCount'] = pending.length;
      status['pendingNotifications'] = pending.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
      }).toList();

      // Check if notifications are enabled
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          status['notificationsEnabled'] = await androidPlugin.areNotificationsEnabled() ?? false;
          status['exactAlarmsGranted'] = await androidPlugin.canScheduleExactNotifications() ?? false;
          debugPrint('📱 Android notifications enabled: ${status['notificationsEnabled']}');
          debugPrint('⏰ Exact alarms granted: ${status['exactAlarmsGranted']}');
        } catch (e) {
          debugPrint('⚠️ Could not check Android notification status: $e');
        }
      }

      // Current timezone info
      status['timezone'] = tz.local.name;
      status['currentTime'] = tz.TZDateTime.now(tz.local).toString();

    } catch (e) {
      debugPrint('❌ Error getting notification status: $e');
      status['error'] = e.toString();
    }

    return status;
  }
}

