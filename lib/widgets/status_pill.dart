import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum DoseVisualStatus { taken, upcoming, missed }

class StatusPill extends StatelessWidget {
  final DoseVisualStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = TodayColors.of(context);
    final (label, icon, foreground, background) = switch (status) {
      DoseVisualStatus.taken => (
        'Taken',
        Icons.check_circle_outline,
        colors.takenForeground,
        colors.takenBackground,
      ),
      DoseVisualStatus.upcoming => (
        'Upcoming',
        Icons.schedule_outlined,
        colors.upcomingForeground,
        colors.upcomingBackground,
      ),
      DoseVisualStatus.missed => (
        'Missed',
        Icons.error_outline,
        colors.missedForeground,
        colors.missedBackground,
      ),
    };

    return Semantics(
      container: true,
      label: 'Dose status: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
