import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/db/sqlite_service.dart';
import '../../services/notification_service.dart';

/// Settings Screen
/// Allows users to configure app settings like theme mode
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        final db = SQLiteService();
        final notificationService = NotificationService();

        final database = await db.database;

        // Get all medicines for current user
        final medicines = await database.query(
          'medicines',
          where: 'uid = ?',
          whereArgs: [currentUser.uid],
        );

        // Cancel notifications for pending schedules and delete all schedules/history for each medicine
        for (var medicine in medicines) {
          final medicineId = medicine['id'] as int;

          // Get pending schedules to cancel notifications
          final pendingSchedules = await database.query(
            'schedules',
            where: 'medicineId = ? AND status = ?',
            whereArgs: [medicineId, 'pending'],
          );

          // Cancel notifications for pending schedules
          for (var schedule in pendingSchedules) {
            final scheduleId = schedule['id'] as int;
            await notificationService.cancelNotification(scheduleId);
          }

          // Delete all schedules for this medicine
          await database.delete(
            'schedules',
            where: 'medicineId = ?',
            whereArgs: [medicineId],
          );

          // Delete history for this medicine
          await database.delete(
            'history',
            where: 'medicineId = ?',
            whereArgs: [medicineId],
          );
        }

        // Delete medicines
        await database.delete(
          'medicines',
          where: 'uid = ?',
          whereArgs: [currentUser.uid],
        );

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
                        leading: Icon(
                          Icons.notifications,
                          color: AppColors.primary,
                        ),
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