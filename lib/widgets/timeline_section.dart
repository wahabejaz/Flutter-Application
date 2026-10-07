import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class TimelineSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const TimelineSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TodayColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            bottom: 0,
            child: Container(width: 2, color: colors.timelineConnector),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...children,
              ],
            ),
          ),
          Positioned(
            left: 3,
            top: 3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.timelineDot,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
