import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onAdd;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: 'Add your first medicine',
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add your first medicine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
