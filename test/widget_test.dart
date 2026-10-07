import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder_app/widgets/empty_state.dart';
import 'package:medicine_reminder_app/widgets/health_banner.dart';
import 'package:medicine_reminder_app/widgets/next_dose_card.dart';
import 'package:medicine_reminder_app/widgets/progress_strip.dart';
import 'package:medicine_reminder_app/widgets/status_pill.dart';

void main() {
  final now = DateTime(2026, 10, 7, 8);

  Widget testApp(Widget child, {double textScale = 1}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );

  testWidgets('EmptyState shows copy and invokes its add action', (
    tester,
  ) async {
    var addPressed = false;
    await tester.pumpWidget(
      testApp(
        EmptyState(
          title: 'No medicines',
          message: 'Add a medicine to get started.',
          onAdd: () => addPressed = true,
        ),
      ),
    );

    expect(find.text('No medicines'), findsOneWidget);
    expect(find.text('Add a medicine to get started.'), findsOneWidget);
    await tester.tap(find.text('Add your first medicine'));
    expect(addPressed, isTrue);
  });

  testWidgets(
    'NextDoseCard pending state shows countdown, dosage and actions',
    (tester) async {
      var taken = false;
      var snoozed = false;
      await tester.pumpWidget(
        testApp(
          NextDoseCard(
            state: NextDoseCardState.pending,
            medicineName: 'Medicine A',
            dosage: '10mg',
            scheduledAt: now.add(const Duration(minutes: 25)),
            now: now,
            onTaken: () => taken = true,
            onSnooze: () => snoozed = true,
          ),
          textScale: 1.5,
        ),
      );

      expect(find.text('NEXT DOSE IN 25 MIN'), findsOneWidget);
      expect(find.text('10mg'), findsOneWidget);
      expect(find.bySemanticsLabel('Mark Medicine A as taken'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Snooze Medicine A for 10 minutes'),
        findsOneWidget,
      );
      final allButtons = find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
      );
      expect(
        tester
            .getSize(
              find.ancestor(of: find.text('Mark Taken'), matching: allButtons),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(
              find.ancestor(of: find.text('Snooze 10m'), matching: allButtons),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Mark Taken'));
      await tester.tap(find.text('Snooze 10m'));
      expect(taken, isTrue);
      expect(snoozed, isTrue);
    },
  );

  testWidgets('NextDoseCard all-taken state does not expose missed action', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(NextDoseCard(state: NextDoseCardState.allTaken, now: now)),
    );

    expect(find.text('All done for today'), findsOneWidget);
    expect(find.textContaining('missed'), findsNothing);
    expect(find.text('Log late dose'), findsNothing);
  });

  testWidgets('NextDoseCard labels due and overdue pending doses', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        NextDoseCard(
          state: NextDoseCardState.pending,
          medicineName: 'Medicine C',
          scheduledAt: now,
          now: now,
        ),
      ),
    );
    expect(find.text('DUE NOW'), findsOneWidget);

    await tester.pumpWidget(
      testApp(
        NextDoseCard(
          state: NextDoseCardState.pending,
          medicineName: 'Medicine C',
          scheduledAt: now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
      ),
    );
    expect(find.text('3 MIN OVERDUE'), findsOneWidget);
    expect(displayDosage(null), 'dose');
  });

  testWidgets('NextDoseCard only-missed state offers late-dose recovery', (
    tester,
  ) async {
    var recovered = false;
    await tester.pumpWidget(
      testApp(
        NextDoseCard(
          state: NextDoseCardState.onlyMissed,
          medicineName: 'Medicine B',
          missedCount: 3,
          now: now,
          onLogLateDose: () => recovered = true,
        ),
      ),
    );

    expect(find.text('3 doses missed'), findsOneWidget);
    expect(find.text('All done for today'), findsNothing);
    expect(
      find.bySemanticsLabel('Log late dose of Medicine B as taken'),
      findsOneWidget,
    );
    await tester.tap(find.text('Log late dose'));
    expect(recovered, isTrue);
  });

  testWidgets('NextDoseCard no-dose state offers Add Medicine', (tester) async {
    var addPressed = false;
    await tester.pumpWidget(
      testApp(
        NextDoseCard(
          state: NextDoseCardState.noDoses,
          now: now,
          onAddMedicine: () => addPressed = true,
        ),
      ),
    );

    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(find.bySemanticsLabel('Add medicine'), findsOneWidget);
    await tester.tap(find.text('Add medicine'));
    expect(addPressed, isTrue);
  });

  testWidgets('ProgressStrip handles zero and normal dose counts', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const ProgressStrip(taken: 0, total: 0)));
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Nothing scheduled today'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(testApp(const ProgressStrip(taken: 2, total: 4)));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 doses today'), findsOneWidget);
    expect(find.text('~50%'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Daily dose completion: 50 percent'),
      findsOneWidget,
    );
  });

  testWidgets('StatusChip announces status in light and dark themes', (
    tester,
  ) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Wrap(
              children: [
                StatusPill(status: DoseVisualStatus.taken),
                StatusPill(status: DoseVisualStatus.upcoming),
                StatusPill(status: DoseVisualStatus.missed),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Dose status: Taken'), findsOneWidget);
      expect(find.bySemanticsLabel('Dose status: Upcoming'), findsOneWidget);
      expect(find.bySemanticsLabel('Dose status: Missed'), findsOneWidget);
    }
  });

  testWidgets('HealthBanner expands to explain missing permission', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      testApp(
        HealthBanner(
          status: Future.value({
            'notificationsEnabled': true,
            'exactAlarmsGranted': false,
          }),
          onRequestPermissions: () async => requested = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reminder permission needed'), findsOneWidget);
    expect(
      find.textContaining('Exact alarm access is not granted'),
      findsNothing,
    );
    await tester.tap(find.text('Reminder permission needed'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Exact alarm access is not granted'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enable permissions'));
    await tester.pumpAndSettle();
    expect(requested, isTrue);
  });

  testWidgets('HealthBanner stays hidden when permissions are enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        HealthBanner(
          status: Future.value({
            'notificationsEnabled': true,
            'exactAlarmsGranted': true,
          }),
          onRequestPermissions: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reminder permission needed'), findsNothing);
  });
}
