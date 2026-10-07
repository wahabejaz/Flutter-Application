import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class ProgressStrip extends StatelessWidget {
  final int taken;
  final int total;

  const ProgressStrip({super.key, required this.taken, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = TodayColors.of(context);
    final completed = taken.clamp(0, total);
    final progress = total == 0 ? 0.0 : completed / total;
    final percent = (progress * 100).round();

    return Card(
      color: colors.progressSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.progressShadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      total == 0
                          ? 'Nothing scheduled today'
                          : '$completed of $total doses today',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Semantics(
                  container: true,
                  label: 'Daily dose completion: $percent percent',
                  child: ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: value,
                              strokeWidth: 6,
                              backgroundColor: colors.progressTrack,
                              color: colors.progressRing,
                            ),
                            Text(
                              '~${(value * 100).round()}%',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
