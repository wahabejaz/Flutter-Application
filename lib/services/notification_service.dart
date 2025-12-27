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

    // Initialize timezone data first - critical for accurate scheduling
    tz.initializeTimeZones();

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

    // Check for initial notification that launched the app
    final initialNotification = await _notifications.getNotificationAppLaunchDetails();
    if (initialNotification?.didNotificationLaunchApp == true) {
      _initialNotificationId = initialNotification?.notificationResponse?.id;
    }

    // Create notification channel for Android 8+ with high importance and sound
    await _createNotificationChannel();

    // Request permissions if not already requested
    if (!_permissionsRequested) {
      await requestPermission();
    }

    _initialized = true;
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
    if (!_initialized) {
      await initialize();
    }

    // Check permissions before scheduling - critical for Android
    if (!await hasPermission()) {
      debugPrint('❌ Notification permissions not granted - cannot schedule reminders');
      throw Exception('Notification permissions not granted - cannot schedule reminders');
    }

    // Cancel any existing notification for this ID first
    try {
      await _notifications.cancel(id);
    } catch (e) {
      // Continue if cancel fails
    }

    // Get the next occurrence of the specified time using local timezone
    // This ensures accurate scheduling regardless of device timezone settings
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    // This prevents immediate triggering and ensures future scheduling
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('📅 Scheduling notification ID $id for ${scheduledDate.toString()}');

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

    // Schedule the daily repeating notification using zonedSchedule
    // matchDateTimeComponents: DateTimeComponents.time ensures daily repetition at the same time
    // androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle allows delivery during doze mode
    // This is the Android-recommended approach that works with battery optimization enabled
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at the same time
    );

    debugPrint('✅ Successfully scheduled daily notification ID $id for ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
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
}

