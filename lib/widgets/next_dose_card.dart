import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum NextDoseCardState { pending, allTaken, onlyMissed, noDoses }

class NextDoseCard extends StatelessWidget {
  final NextDoseCardState state;
  final String medicineName;
  final String dosage;
  final DateTime? scheduledAt;
  final DateTime now;
  final int missedCount;
  final VoidCallback? onTaken;
  final VoidCallback? onSnooze;
  final VoidCallback? onLogLateDose;
  final VoidCallback? onAddMedicine;

  const NextDoseCard({
    super.key,
    this.state = NextDoseCardState.pending,
    this.medicineName = '',
    this.dosage = 'dose',
    this.scheduledAt,
    required this.now,
    this.missedCount = 0,
    this.onTaken,
    this.onSnooze,
    this.onLogLateDose,
    this.onAddMedicine,
  });

  String _countdown() {
    final date = scheduledAt;
    if (date == null) return '';
    final minutes = date.difference(now).inMinutes;
    if (minutes < 0) return '${minutes.abs()} MIN OVERDUE';
    if (minutes == 0) return 'DUE NOW';
    return 'NEXT DOSE IN $minutes MIN';
  }

  @override
  Widget build(BuildContext context) {
    final colors = TodayColors.of(context);
    const foreground = Colors.white;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.heroStart, colors.heroEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (state) {
            NextDoseCardState.pending => _pending(context, foreground),
            NextDoseCardState.allTaken => _message(
              context,
              foreground,
              'All done for today',
            ),
            NextDoseCardState.onlyMissed => _missed(context, foreground),
            NextDoseCardState.noDoses => _noDoses(context, foreground),
          },
        ),
      ),
    );
  }

  Widget _pending(BuildContext context, Color foreground) {
    final colors = TodayColors.of(context);
    final scheduledTime = scheduledAt == null
        ? ''
        : TimeOfDay.fromDateTime(scheduledAt!).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _countdown(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.heroLabel,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    displayDosage(dosage),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (scheduledTime.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      scheduledTime,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: foreground),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ExcludeSemantics(
              child: CustomPaint(
                size: const Size(56, 88),
                painter: _CapsulePainter(
                  highlight: colors.capsuleLight,
                  light: colors.capsuleLight,
                  dark: colors.capsuleDark,
                  outline: colors.capsuleOutline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Mark $medicineName as taken',
                child: FilledButton.icon(
                  onPressed: onTaken,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: colors.markTakenBackground,
                    foregroundColor: colors.markTakenForeground,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark Taken'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Snooze $medicineName for 10 minutes',
                child: OutlinedButton.icon(
                  onPressed: onSnooze,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: foreground,
                    side: BorderSide(color: foreground, width: 1.5),
                    backgroundColor: Colors.transparent,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.snooze),
                  label: const Text('Snooze 10m'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _missed(BuildContext context, Color foreground) {
    final count = missedCount;
    final colors = TodayColors.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: foreground, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count ${count == 1 ? 'dose' : 'doses'} missed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                container: true,
                button: true,
                label: 'Log late dose of $medicineName as taken',
                onTap: onLogLateDose,
                child: ExcludeSemantics(
                  child: FilledButton(
                    onPressed: onLogLateDose,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: colors.markTakenBackground,
                      foregroundColor: colors.markTakenForeground,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Log late dose'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message(BuildContext context, Color foreground, String message) {
    return Row(
      children: [
        Icon(
          state == NextDoseCardState.allTaken
              ? Icons.check_circle_outline
              : Icons.event_available_outlined,
          color: foreground,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _noDoses(BuildContext context, Color foreground) {
    final colors = TodayColors.of(context);
    return Row(
      children: [
        Icon(Icons.event_available_outlined, color: foreground, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing scheduled',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                button: true,
                label: 'Add medicine',
                child: FilledButton(
                  onPressed: onAddMedicine,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: colors.markTakenBackground,
                    foregroundColor: colors.markTakenForeground,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Add medicine'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String displayDosage(String? dosage) {
  final value = dosage?.trim() ?? '';
  return value.isEmpty ? 'dose' : value;
}

class _CapsulePainter extends CustomPainter {
  final Color highlight;
  final Color light;
  final Color dark;
  final Color outline;

  const _CapsulePainter({
    required this.highlight,
    required this.light,
    required this.dark,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .48,
      height: size.height * .86,
    );
    final capsule = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width / 2),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.78);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRRect(
      capsule,
      Paint()
        ..shader = LinearGradient(
          colors: [light, dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      Paint()
        ..color = highlight
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CapsulePainter oldDelegate) =>
      oldDelegate.highlight != highlight ||
      oldDelegate.light != light ||
      oldDelegate.dark != dark ||
      oldDelegate.outline != outline;
}
