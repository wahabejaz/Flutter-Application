import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController {
  static const String _key = "isFirstTime";

  /// Check if user is opening the app for the first time
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;   // default is true (first time)
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}
