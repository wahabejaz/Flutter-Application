import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder_app/firebase_options.dart';
import 'package:medicine_reminder_app/routes/app_routes.dart';
import 'package:medicine_reminder_app/routes/route_generator.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';
import 'package:medicine_reminder_app/services/reminder_scheduler.dart';
import 'package:medicine_reminder_app/services/theme_service.dart';
import 'package:medicine_reminder_app/config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (with error handling)
  try {
    await dotenv.load();
  } catch (e) {
    // If .env file doesn't exist or can't be loaded, continue without it
    // AI features will be disabled gracefully
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize reminder scheduler and reschedule all notifications
  final reminderScheduler = ReminderScheduler(notificationService: notificationService);

  // Run initialization in background to prevent blocking app startup
  Future.microtask(() async {
    try {
      await reminderScheduler.rescheduleAllNotifications();
      await reminderScheduler.cancelExpiredReminders();
      await reminderScheduler.refreshUpcomingSchedules();
      await reminderScheduler.markOverdueSchedulesAsMissed();
    } catch (e) {
      debugPrint('⚠️ Error during background initialization: $e');
    }
  });

  // Initialize theme service
  final themeService = ThemeService();
  await themeService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<ThemeService>(
          create: (_) => themeService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Medicine Reminder',
          debugShowCheckedModeBanner: false,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: RouteGenerator.generateRoute,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
        );
      },
    );
  }
}
