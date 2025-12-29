import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (Teal/Turquoise)
  static const Color primary = Color(0xFF4ECDC4); // Teal
  static const Color primaryDark = Color(0xFF3BA99F);
  static const Color primaryLight = Color(0xFF7EDDD6);

  // Accent colors - More vibrant and attractive
  static const Color orange = Color(0xFFFF8A65);
  static const Color orangeLight = Color(0xFFFFB299);
  static const Color green = Color(0xFF66BB6A);
  static const Color greenLight = Color(0xFF81C784);
  static const Color blue = Color(0xFF42A5F5);
  static const Color blueLight = Color(0xFF64B5F6);
  static const Color red = Color(0xFFEF5350);
  static const Color redLight = Color(0xFFE57373);
  static const Color grey = Color(0xFF757575);
  
  // Pastel colors for Quick Actions - More vibrant
  static const Color pastelGreen = Color(0xFFC5E1A5);
  static const Color pastelBlue = Color(0xFFB3E5FC);
  static const Color pastelPink = Color(0xFFF8BBD9);
  static const Color pastelOrange = Color(0xFFFFCC80);
  
  // Gradient colors for Daily Progress - More vibrant
  static const Color progressGreen = Color(0xFFA5D6A7);
  static const Color progressBlue = Color(0xFF90CAF9);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFAFA);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFF9E9E9E);

  // Status colors
  static const Color taken = green;
  static const Color missed = orange;
  static const Color pending = Color(0xFFFFB74D);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pastelPinkGradient = LinearGradient(
    colors: [Color(0xFFF8BBD9), Color(0xFFF48FB1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Daily Progress Gradient (light green to light blue)
  static const LinearGradient dailyProgressGradient = LinearGradient(
    colors: [Color.fromARGB(255, 159, 216, 160), Color.fromARGB(255, 132, 197, 250)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF8A65), Color(0xFFFFB299)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

