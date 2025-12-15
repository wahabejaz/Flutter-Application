import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import 'onboarding_controller.dart';

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Track Your Progress",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "See daily stats and stay motivated on your health journey.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),

            ElevatedButton(
              onPressed: () async {
                await OnboardingController.completeOnboarding();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.signin);
                }
              },
              child: const Text("Get Started"),
            ),

            TextButton(
              onPressed: () async {
                await OnboardingController.completeOnboarding();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.signin);
                }
              },
              child: const Text("Skip"),
            )
          ],
        ),
      ),
    );
  }
}
