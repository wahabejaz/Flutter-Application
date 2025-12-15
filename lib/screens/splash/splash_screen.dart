import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../onboarding/onboarding_controller.dart';
import '../../services/sample_data_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SampleDataService _sampleDataService = SampleDataService();

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Initialize sample data if needed (runs in background)
    _sampleDataService.hasSampleData().then((hasData) {
      if (!hasData) {
        _sampleDataService.addSampleData();
      }
    });

    await Future.delayed(const Duration(seconds: 2));   // splash duration

    if (!mounted) return;

    bool firstTime = await OnboardingController.isFirstTime();
    bool loggedIn = FirebaseAuth.instance.currentUser != null;

    if (firstTime) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding1);
      }
    } else {
      if (loggedIn) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.signin);
        }
      }
    }
  }

  /// Dev Mode: Skip to home screen (for testing)
 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication_outlined, size: 64, color: Color.fromARGB(255, 58, 183, 183)),
            const SizedBox(height: 16),
            const Text(
              "Medicine Reminder",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
