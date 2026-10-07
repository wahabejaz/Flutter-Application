import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class HealthBanner extends StatefulWidget {
  final Future<Map<String, dynamic>> status;
  final Future<void> Function() onRequestPermissions;

  const HealthBanner({
    super.key,
    required this.status,
    required this.onRequestPermissions,
  });

  @override
  State<HealthBanner> createState() => _HealthBannerState();
}

class _HealthBannerState extends State<HealthBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: widget.status,
      builder: (context, snapshot) {
        final values = snapshot.data;
        if (values == null) return const SizedBox.shrink();
        final notificationsEnabled =
            values['notificationsEnabled'] as bool? ?? true;
        final exactAlarmsGranted =
            values['exactAlarmsGranted'] as bool? ?? true;
        if (notificationsEnabled && exactAlarmsGranted) {
          return const SizedBox.shrink();
        }

        final missing = <String>[
          if (!notificationsEnabled) 'Notifications are turned off.',
          if (!exactAlarmsGranted)
            'Exact alarm access is not granted; reminders may be delayed.',
        ];
        final colors = TodayColors.of(context);

        return Card(
          color: colors.healthBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  expanded: _expanded,
                  label:
                      'Reminder permission needed. '
                      'Enable notifications to not miss doses.',
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: colors.healthIcon,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Reminder permission needed',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: colors.healthTitle,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                Text(
                                  'Enable notifications to not miss doses',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.healthSubtitle,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            color: colors.healthTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      missing.join(' '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.healthSubtitle,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Re-request reminder permissions',
                      child: FilledButton.tonal(
                        onPressed: widget.onRequestPermissions,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: colors.healthTitle,
                        ),
                        child: const Text('Enable permissions'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
