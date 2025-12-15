import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Organize Your Medicines",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Add, track, and update your medication schedule easily.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.onboarding3);
              },
              child: const Text("Next"),
            ),

            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.signin);
              },
              child: const Text("Skip"),
            )
          ],
        ),
      ),
    );
  }
}
