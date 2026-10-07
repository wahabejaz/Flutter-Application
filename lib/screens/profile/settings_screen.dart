import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_data_service.dart';

/// Settings Screen
/// Allows users to configure app settings like theme mode
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _notificationStatus;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  void _refreshNotificationStatus() {
    _notificationStatus = NotificationService().getNotificationStatus();
  }

  Future<void> _requestReminderPermissions() async {
    try {
      await NotificationService().requestReminderPermissions();
      if (!mounted) return;
      setState(_refreshNotificationStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission status refreshed')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request permissions: $e')),
        );
      }
    }
  }

  Future<void> _testNotification(BuildContext context) async {
    try {
      final notificationService = NotificationService();
      await notificationService.showNotification(
        id: 999999, // Use a high ID to avoid conflicts
        title: 'Test Notification',
        body: 'This is a test notification to verify notifications are working.',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetUserData(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Data'),
        content: const Text(
          'This will permanently delete all your medicines, schedules, and history. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserDataService().clearCurrentUserData(currentUser.uid);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data has been reset'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting data: $e'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.iconTheme?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Settings Menu
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Consumer<ThemeService>(
                builder: (context, themeService, child) {
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          themeService.themeMode == ThemeMode.light
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: AppColors.primary,
                        ),
                        title: const Text('Theme Mode'),
                        subtitle: Text(
                          themeService.themeMode == ThemeMode.light
                              ? 'Light Mode'
                              : 'Dark Mode',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeSelector(context, themeService),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.notifications, color: AppColors.primary),
                        title: const Text('Re-request Notification Permissions'),
                        subtitle: const Text('Request notification and exact-alarm access'),
                        trailing: const Icon(Icons.refresh),
                        onTap: _requestReminderPermissions,
                      ),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _notificationStatus,
                        builder: (context, snapshot) {
                          final status = snapshot.data;
                          if (status == null) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Checking notification status...'),
                            );
                          }
                          final pending =
                              status['pendingNotifications'] as List<dynamic>? ?? [];
                          final nextFireTimes = pending
                              .map((item) => item['nextFireTime'])
                              .whereType<String>()
                              .take(3)
                              .map((time) => 'Next fire: $time')
                              .join('\n');
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                            child: Text([
                              'Timezone: ${status['timezone']}',
                              'Notifications enabled: ${status['notificationsEnabled']}',
                              'Exact alarms granted: ${status['exactAlarmsGranted']}',
                              'Pending notifications: ${status['pendingCount']}',
                              if (nextFireTimes.isNotEmpty) nextFireTimes,
                            ].join('\n')),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.notifications_active, color: AppColors.primary),
                        title: const Text('Test Notification'),
                        subtitle: const Text('Send a test notification now'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _testNotification(context),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: AppColors.red,
                        ),
                        title: const Text('Reset Data'),
                        subtitle: const Text('Delete all medicines and history'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _resetUserData(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, ThemeService themeService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Theme',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(
                  Icons.light_mode,
                  color: themeService.themeMode == ThemeMode.light
                      ? AppColors.primary
                      : Colors.grey,
                ),
                title: const Text('Light Mode'),
                trailing: themeService.themeMode == ThemeMode.light
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  themeService.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.dark_mode,
                  color: themeService.themeMode == ThemeMode.dark
                      ? AppColors.primary
                      : Colors.grey,
                ),
                title: const Text('Dark Mode'),
                trailing: themeService.themeMode == ThemeMode.dark
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  themeService.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}