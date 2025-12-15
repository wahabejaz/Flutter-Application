import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_routes.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen1.dart';
import '../screens/onboarding/onboarding_screen2.dart';
import '../screens/onboarding/onboarding_screen3.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/add_medicine_screen.dart';
import '../screens/home/edit_medicine_screen.dart';
import '../screens/home/medicine_detail_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Check if user is authenticated for protected routes
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final protectedRoutes = [
      AppRoutes.home,
      AppRoutes.addMedicine,
      AppRoutes.editMedicine,
      AppRoutes.medicineDetail,
      AppRoutes.schedule,
      AppRoutes.history,
      AppRoutes.profile,
    ];

    if (protectedRoutes.contains(settings.name) && !isAuthenticated) {
      // Redirect to sign in if not authenticated
      return MaterialPageRoute(builder: (_) => const SignInScreen());
    }

    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding1:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen1());
      case AppRoutes.onboarding2:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen2());
      case AppRoutes.onboarding3:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen3());

      case AppRoutes.signin:
        return MaterialPageRoute(builder: (_) => const SignInScreen());
      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case AppRoutes.addMedicine:
        return MaterialPageRoute(builder: (_) => const AddMedicineScreen());
      case AppRoutes.editMedicine:
        return MaterialPageRoute(builder: (_) => const EditMedicineScreen());
      case AppRoutes.medicineDetail:
        return MaterialPageRoute(builder: (_) => const MedicineDetailScreen());

      case AppRoutes.schedule:
        return MaterialPageRoute(builder: (_) => const ScheduleScreen());

      case AppRoutes.history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
    }

    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(
          child: Text("Route not found"),
        ),
      ),
    );
  }
}
