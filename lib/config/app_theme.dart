import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadii {
  static const double card = 16;
  static const double panel = 24;
}

abstract final class AppStatusColors {
  static Color taken(BuildContext context) =>
      _color(context, const Color(0xFF1B5E20), const Color(0xFF81C784));

  static Color upcoming(BuildContext context) =>
      _color(context, const Color(0xFF7A4D00), const Color(0xFFFFD180));

  static Color missed(BuildContext context) =>
      _color(context, const Color(0xFFB3261E), const Color(0xFFEF9A9A));

  static Color _color(BuildContext context, Color light, Color dark) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class TodayColors extends ThemeExtension<TodayColors> {
  final Color background;
  final Color primaryText;
  final Color secondaryText;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color healthBackground;
  final Color healthIcon;
  final Color healthTitle;
  final Color healthSubtitle;
  final Color heroStart;
  final Color heroEnd;
  final Color heroLabel;
  final Color capsuleLight;
  final Color capsuleDark;
  final Color capsuleOutline;
  final Color markTakenBackground;
  final Color markTakenForeground;
  final Color progressSurface;
  final Color progressShadow;
  final Color progressRing;
  final Color progressTrack;
  final Color timelineDot;
  final Color timelineConnector;
  final Color doseSurface;
  final Color takenBackground;
  final Color takenForeground;
  final Color takenIconBackground;
  final Color upcomingBackground;
  final Color upcomingForeground;
  final Color upcomingIconBackground;
  final Color missedBackground;
  final Color missedForeground;
  final Color missedIconBackground;
  final Color stockFill;
  final Color stockTrack;
  final Color stockText;
  final Color fabBackground;
  final Color fabForeground;
  final Color navigationBackground;
  final Color navigationIndicator;
  final Color navigationForeground;

  const TodayColors({
    required this.background,
    required this.primaryText,
    required this.secondaryText,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.healthBackground,
    required this.healthIcon,
    required this.healthTitle,
    required this.healthSubtitle,
    required this.heroStart,
    required this.heroEnd,
    required this.heroLabel,
    required this.capsuleLight,
    required this.capsuleDark,
    required this.capsuleOutline,
    required this.markTakenBackground,
    required this.markTakenForeground,
    required this.progressSurface,
    required this.progressShadow,
    required this.progressRing,
    required this.progressTrack,
    required this.timelineDot,
    required this.timelineConnector,
    required this.doseSurface,
    required this.takenBackground,
    required this.takenForeground,
    required this.takenIconBackground,
    required this.upcomingBackground,
    required this.upcomingForeground,
    required this.upcomingIconBackground,
    required this.missedBackground,
    required this.missedForeground,
    required this.missedIconBackground,
    required this.stockFill,
    required this.stockTrack,
    required this.stockText,
    required this.fabBackground,
    required this.fabForeground,
    required this.navigationBackground,
    required this.navigationIndicator,
    required this.navigationForeground,
  });

  static const light = TodayColors(
    background: Color(0xFFF6F7FB),
    primaryText: Color(0xFF0F2F2C),
    secondaryText: Color(0xFF5B6B69),
    avatarBackground: Color(0xFFCDE9E4),
    avatarForeground: Color(0xFF0F2F2C),
    healthBackground: Color(0xFFFDDCD3),
    healthIcon: Color(0xFFE5533D),
    healthTitle: Color(0xFF5A2A1E),
    healthSubtitle: Color(0xFF7A4A3E),
    heroStart: Color(0xFF1F847B),
    heroEnd: Color(0xFF0D5C56),
    heroLabel: Color(0xFFBFE5DF),
    capsuleLight: Color(0xFFCDE9E4),
    capsuleDark: Color(0xFF2A8F86),
    capsuleOutline: Color(0xFF0F4F4A),
    markTakenBackground: Color(0xFFCDE9E4),
    markTakenForeground: Color(0xFF0B3D3A),
    progressSurface: Colors.white,
    progressShadow: Color(0x14000000),
    progressRing: Color(0xFF19C39A),
    progressTrack: Color(0xFFD5F0EA),
    timelineDot: Color(0xFFBFE0DA),
    timelineConnector: Color(0xFFCFE6E2),
    doseSurface: Colors.white,
    takenBackground: Color(0xFFCDEFD3),
    takenForeground: Color(0xFF1F6B35),
    takenIconBackground: Color(0xFFCDE9E4),
    upcomingBackground: Color(0xFFFFD98A),
    upcomingForeground: Color(0xFF7A4B00),
    upcomingIconBackground: Color(0xFFFBE3B5),
    missedBackground: Color(0xFFFAD4D4),
    missedForeground: Color(0xFFB3261E),
    missedIconBackground: Color(0xFFFAD4D4),
    stockFill: Color(0xFFC98A1B),
    stockTrack: Color(0xFFE8E2D4),
    stockText: Color(0xFF8A5A00),
    fabBackground: Color(0xFF12897F),
    fabForeground: Colors.white,
    navigationBackground: Color(0xFFE3F3F0),
    navigationIndicator: Color(0xFFBFE6E0),
    navigationForeground: Color(0xFF0F2F2C),
  );

  static const dark = TodayColors(
    background: Color(0xFF101B1A),
    primaryText: Color(0xFFE1F2EF),
    secondaryText: Color(0xFFAAC0BC),
    avatarBackground: Color(0xFF28534D),
    avatarForeground: Color(0xFFE1F2EF),
    healthBackground: Color(0xFF4B2823),
    healthIcon: Color(0xFFFF8A72),
    healthTitle: Color(0xFFFFD4C9),
    healthSubtitle: Color(0xFFE8B4A7),
    heroStart: Color(0xFF176D66),
    heroEnd: Color(0xFF0A4743),
    heroLabel: Color(0xFFC3E9E3),
    capsuleLight: Color(0xFF9CCFC6),
    capsuleDark: Color(0xFF247F77),
    capsuleOutline: Color(0xFF092F2C),
    markTakenBackground: Color(0xFFB9DED6),
    markTakenForeground: Color(0xFF0B3D3A),
    progressSurface: Color(0xFF1B2927),
    progressShadow: Color(0x55000000),
    progressRing: Color(0xFF42D9B1),
    progressTrack: Color(0xFF34514B),
    timelineDot: Color(0xFF47766E),
    timelineConnector: Color(0xFF34514B),
    doseSurface: Color(0xFF1B2927),
    takenBackground: Color(0xFF244D32),
    takenForeground: Color(0xFFB0E6B9),
    takenIconBackground: Color(0xFF28534D),
    upcomingBackground: Color(0xFF5A431F),
    upcomingForeground: Color(0xFFFFD98A),
    upcomingIconBackground: Color(0xFF594323),
    missedBackground: Color(0xFF542D30),
    missedForeground: Color(0xFFFFB5B2),
    missedIconBackground: Color(0xFF542D30),
    stockFill: Color(0xFFE4AD4B),
    stockTrack: Color(0xFF514A3C),
    stockText: Color(0xFFFFD98A),
    fabBackground: Color(0xFF27A99C),
    fabForeground: Color(0xFF062D29),
    navigationBackground: Color(0xFF192A28),
    navigationIndicator: Color(0xFF28534D),
    navigationForeground: Color(0xFFE1F2EF),
  );

  static TodayColors of(BuildContext context) =>
      Theme.of(context).extension<TodayColors>() ??
      (Theme.of(context).brightness == Brightness.light ? light : dark);

  @override
  TodayColors copyWith({
    Color? background,
    Color? primaryText,
    Color? secondaryText,
    Color? avatarBackground,
    Color? avatarForeground,
    Color? healthBackground,
    Color? healthIcon,
    Color? healthTitle,
    Color? healthSubtitle,
    Color? heroStart,
    Color? heroEnd,
    Color? heroLabel,
    Color? capsuleLight,
    Color? capsuleDark,
    Color? capsuleOutline,
    Color? markTakenBackground,
    Color? markTakenForeground,
    Color? progressSurface,
    Color? progressShadow,
    Color? progressRing,
    Color? progressTrack,
    Color? timelineDot,
    Color? timelineConnector,
    Color? doseSurface,
    Color? takenBackground,
    Color? takenForeground,
    Color? takenIconBackground,
    Color? upcomingBackground,
    Color? upcomingForeground,
    Color? upcomingIconBackground,
    Color? missedBackground,
    Color? missedForeground,
    Color? missedIconBackground,
    Color? stockFill,
    Color? stockTrack,
    Color? stockText,
    Color? fabBackground,
    Color? fabForeground,
    Color? navigationBackground,
    Color? navigationIndicator,
    Color? navigationForeground,
  }) => TodayColors(
    background: background ?? this.background,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    avatarBackground: avatarBackground ?? this.avatarBackground,
    avatarForeground: avatarForeground ?? this.avatarForeground,
    healthBackground: healthBackground ?? this.healthBackground,
    healthIcon: healthIcon ?? this.healthIcon,
    healthTitle: healthTitle ?? this.healthTitle,
    healthSubtitle: healthSubtitle ?? this.healthSubtitle,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
    heroLabel: heroLabel ?? this.heroLabel,
    capsuleLight: capsuleLight ?? this.capsuleLight,
    capsuleDark: capsuleDark ?? this.capsuleDark,
    capsuleOutline: capsuleOutline ?? this.capsuleOutline,
    markTakenBackground: markTakenBackground ?? this.markTakenBackground,
    markTakenForeground: markTakenForeground ?? this.markTakenForeground,
    progressSurface: progressSurface ?? this.progressSurface,
    progressShadow: progressShadow ?? this.progressShadow,
    progressRing: progressRing ?? this.progressRing,
    progressTrack: progressTrack ?? this.progressTrack,
    timelineDot: timelineDot ?? this.timelineDot,
    timelineConnector: timelineConnector ?? this.timelineConnector,
    doseSurface: doseSurface ?? this.doseSurface,
    takenBackground: takenBackground ?? this.takenBackground,
    takenForeground: takenForeground ?? this.takenForeground,
    takenIconBackground: takenIconBackground ?? this.takenIconBackground,
    upcomingBackground: upcomingBackground ?? this.upcomingBackground,
    upcomingForeground: upcomingForeground ?? this.upcomingForeground,
    upcomingIconBackground:
        upcomingIconBackground ?? this.upcomingIconBackground,
    missedBackground: missedBackground ?? this.missedBackground,
    missedForeground: missedForeground ?? this.missedForeground,
    missedIconBackground: missedIconBackground ?? this.missedIconBackground,
    stockFill: stockFill ?? this.stockFill,
    stockTrack: stockTrack ?? this.stockTrack,
    stockText: stockText ?? this.stockText,
    fabBackground: fabBackground ?? this.fabBackground,
    fabForeground: fabForeground ?? this.fabForeground,
    navigationBackground: navigationBackground ?? this.navigationBackground,
    navigationIndicator: navigationIndicator ?? this.navigationIndicator,
    navigationForeground: navigationForeground ?? this.navigationForeground,
  );

  @override
  TodayColors lerp(covariant TodayColors? other, double t) {
    if (other == null) return this;
    return TodayColors(
      background: Color.lerp(background, other.background, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      avatarBackground: Color.lerp(
        avatarBackground,
        other.avatarBackground,
        t,
      )!,
      avatarForeground: Color.lerp(
        avatarForeground,
        other.avatarForeground,
        t,
      )!,
      healthBackground: Color.lerp(
        healthBackground,
        other.healthBackground,
        t,
      )!,
      healthIcon: Color.lerp(healthIcon, other.healthIcon, t)!,
      healthTitle: Color.lerp(healthTitle, other.healthTitle, t)!,
      healthSubtitle: Color.lerp(healthSubtitle, other.healthSubtitle, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroLabel: Color.lerp(heroLabel, other.heroLabel, t)!,
      capsuleLight: Color.lerp(capsuleLight, other.capsuleLight, t)!,
      capsuleDark: Color.lerp(capsuleDark, other.capsuleDark, t)!,
      capsuleOutline: Color.lerp(capsuleOutline, other.capsuleOutline, t)!,
      markTakenBackground: Color.lerp(
        markTakenBackground,
        other.markTakenBackground,
        t,
      )!,
      markTakenForeground: Color.lerp(
        markTakenForeground,
        other.markTakenForeground,
        t,
      )!,
      progressSurface: Color.lerp(progressSurface, other.progressSurface, t)!,
      progressShadow: Color.lerp(progressShadow, other.progressShadow, t)!,
      progressRing: Color.lerp(progressRing, other.progressRing, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      timelineDot: Color.lerp(timelineDot, other.timelineDot, t)!,
      timelineConnector: Color.lerp(
        timelineConnector,
        other.timelineConnector,
        t,
      )!,
      doseSurface: Color.lerp(doseSurface, other.doseSurface, t)!,
      takenBackground: Color.lerp(takenBackground, other.takenBackground, t)!,
      takenForeground: Color.lerp(takenForeground, other.takenForeground, t)!,
      takenIconBackground: Color.lerp(
        takenIconBackground,
        other.takenIconBackground,
        t,
      )!,
      upcomingBackground: Color.lerp(
        upcomingBackground,
        other.upcomingBackground,
        t,
      )!,
      upcomingForeground: Color.lerp(
        upcomingForeground,
        other.upcomingForeground,
        t,
      )!,
      upcomingIconBackground: Color.lerp(
        upcomingIconBackground,
        other.upcomingIconBackground,
        t,
      )!,
      missedBackground: Color.lerp(
        missedBackground,
        other.missedBackground,
        t,
      )!,
      missedForeground: Color.lerp(
        missedForeground,
        other.missedForeground,
        t,
      )!,
      missedIconBackground: Color.lerp(
        missedIconBackground,
        other.missedIconBackground,
        t,
      )!,
      stockFill: Color.lerp(stockFill, other.stockFill, t)!,
      stockTrack: Color.lerp(stockTrack, other.stockTrack, t)!,
      stockText: Color.lerp(stockText, other.stockText, t)!,
      fabBackground: Color.lerp(fabBackground, other.fabBackground, t)!,
      fabForeground: Color.lerp(fabForeground, other.fabForeground, t)!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      navigationIndicator: Color.lerp(
        navigationIndicator,
        other.navigationIndicator,
        t,
      )!,
      navigationForeground: Color.lerp(
        navigationForeground,
        other.navigationForeground,
        t,
      )!,
    );
  }
}

class AppTheme {
  static final ThemeData lightTheme = _theme(Brightness.light);
  static final ThemeData darkTheme = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    );
    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
            textStyle: baseTextTheme.displayLarge,
            fontWeight: FontWeight.w700,
          ),
          displayMedium: GoogleFonts.spaceGrotesk(
            textStyle: baseTextTheme.displayMedium,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: GoogleFonts.spaceGrotesk(
            textStyle: baseTextTheme.headlineLarge,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            textStyle: baseTextTheme.headlineMedium,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [
        brightness == Brightness.light ? TodayColors.light : TodayColors.dark,
      ],
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
