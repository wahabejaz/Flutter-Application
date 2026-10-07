import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'next_dose_card.dart';
import 'status_pill.dart';

class DoseTile extends StatelessWidget {
  final String name;
  final String dosage;
  final TimeOfDay time;
  final DoseVisualStatus status;
  final int stockCount;
  final VoidCallback? onTaken;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRefillTap;

  const DoseTile({
    super.key,
    required this.name,
    required this.dosage,
    required this.time,
    required this.status,
    required this.stockCount,
    this.onTaken,
    this.onTap,
    this.onLongPress,
    this.onRefillTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TodayColors.of(context);
    final (statusColor, iconBackground) = switch (status) {
      DoseVisualStatus.taken => (
        colors.takenForeground,
        colors.takenIconBackground,
      ),
      DoseVisualStatus.upcoming => (
        colors.upcomingForeground,
        colors.upcomingIconBackground,
      ),
      DoseVisualStatus.missed => (
        colors.missedForeground,
        colors.missedIconBackground,
      ),
    };
    final lowStock = stockCount <= 5;
    final tile = Card(
      color: colors.doseSurface,
      elevation: 3,
      shadowColor: colors.progressShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: status == DoseVisualStatus.missed ? onLongPress : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: iconBackground,
                    foregroundColor: statusColor,
                    child: const Icon(Icons.medication_outlined, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          displayDosage(dosage),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill(status: status),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        time.format(context),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.secondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (status == DoseVisualStatus.upcoming) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: (stockCount / 30).clamp(0.0, 1.0),
                    minHeight: 4,
                    color: colors.stockFill,
                    backgroundColor: colors.stockTrack,
                    semanticsLabel: 'Stock: $stockCount remaining',
                  ),
                ),
                if (lowStock)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Semantics(
                        button: true,
                        label: stockCount == 0
                            ? 'Out of stock, open refill tracker'
                            : '$stockCount left, open refill tracker',
                        child: InkWell(
                          onTap: onRefillTap,
                          borderRadius: BorderRadius.circular(100),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 48,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ExcludeSemantics(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.upcomingBackground,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    stockCount == 0
                                        ? '0 left - Refill'
                                        : '$stockCount left - Refill',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.stockText,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (status != DoseVisualStatus.upcoming || onTaken == null) return tile;
    return Dismissible(
      key: key ?? ValueKey('$name-${time.hour}-${time.minute}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        color: AppStatusColors.taken(context),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onTaken!();
        return false;
      },
      child: tile,
    );
  }
}
