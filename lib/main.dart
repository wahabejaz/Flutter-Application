import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:medicine_reminder_app/firebase_options.dart';
import 'package:medicine_reminder_app/routes/app_routes.dart';
import 'package:medicine_reminder_app/routes/route_generator.dart';
import 'package:medicine_reminder_app/services/notification_service.dart';
import 'package:medicine_reminder_app/config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Reminder',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: RouteGenerator.generateRoute,
      theme: AppTheme.lightTheme,
    );
  }
}
