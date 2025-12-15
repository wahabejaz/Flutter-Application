import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Never Miss a Dose",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Get timely reminders that keep you healthy and consistent.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.onboarding2);
              },
              child: const Text("Next"),
            ),

            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.signin);
              },
              child: const Text("Skip"),
            ),
            const SizedBox(height: 16)
          ],
        ),
      ),
    );
  }
}
