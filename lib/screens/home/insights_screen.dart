import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../services/db/sqlite_service.dart';
import '../history/history_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Insights'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InsightsOverview(),
            HistoryScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

class _InsightsOverview extends StatefulWidget {
  const _InsightsOverview();

  @override
  State<_InsightsOverview> createState() => _InsightsOverviewState();
}

class _InsightsOverviewState extends State<_InsightsOverview>
    with WidgetsBindingObserver {
  final SQLiteService _dbService = SQLiteService();
  List<_DayAdherence> _week = [];
  int _streak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInsights();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadInsights();
  }

  Future<void> _loadInsights() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final endKey = DateFormat('yyyy-MM-dd').format(today);
    try {
      final db = await _dbService.database;
      final rows = await db.rawQuery('''
        SELECT substr(s.scheduledDate, 1, 10) AS day, s.status
        FROM schedules s
        INNER JOIN medicines m ON m.id = s.medicineId
        WHERE m.uid = ? AND substr(s.scheduledDate, 1, 10) <= ?
        ORDER BY day DESC
      ''', [uid, endKey]);

      final byDay = <String, List<String>>{};
      for (final row in rows) {
        final day = row['day'] as String;
        (byDay[day] ??= []).add(row['status'] as String);
      }

      final week = List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final statuses = byDay[key] ?? const <String>[];
        return _DayAdherence(
          date: date,
          taken: statuses.where((status) => status == 'taken').length,
          pending: statuses.where((status) => status == 'pending').length,
          missed: statuses.where((status) => status == 'missed').length,
        );
      });

      var streak = 0;
      final todayKey = DateFormat('yyyy-MM-dd').format(today);
      final todayStatuses = byDay[todayKey];
      var streakDate = today;
      if (todayStatuses == null ||
          todayStatuses.isEmpty ||
          todayStatuses.any((status) => status != 'taken')) {
        streakDate = today.subtract(const Duration(days: 1));
      }
      while (true) {
        final key = DateFormat('yyyy-MM-dd').format(streakDate);
        final statuses = byDay[key];
        if (statuses == null ||
            statuses.isEmpty ||
            statuses.any((status) => status != 'taken')) {
          break;
        }
        streak++;
        streakDate = streakDate.subtract(const Duration(days: 1));
      }

      if (!mounted) return;
      setState(() {
        _week = week;
        _streak = streak;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load insights: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Weekly adherence', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _LegendItem(color: AppStatusColors.taken(context), label: 'Taken'),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(
                color: AppStatusColors.upcoming(context),
                label: 'Pending',
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(color: AppStatusColors.missed(context), label: 'Missed'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: _week.isEmpty || _week.every((day) => day.total == 0)
                ? Center(
                    child: Text(
                      'No dose history this week',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : BarChart(_chartData(context)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Icon(Icons.local_fire_department, color: scheme.primary),
              title: const Text('Adherence streak'),
              trailing: Text(
                '$_streak ${_streak == 1 ? 'day' : 'days'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartData _chartData(BuildContext context) {
    final takenColor = AppStatusColors.taken(context);
    final pendingColor = AppStatusColors.upcoming(context);
    final missedColor = AppStatusColors.missed(context);
    final maxTotal = _week.fold<int>(0, (max, day) => day.total > max ? day.total : max);
    return BarChartData(
      maxY: (maxTotal == 0 ? 1 : maxTotal).toDouble(),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _week.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(DateFormat('EEEEE').format(_week[index].date)),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(_week.length, (index) {
        final day = _week[index];
        final total = day.total.toDouble();
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: total,
              width: 22,
              borderRadius: BorderRadius.circular(6),
              color: total == 0
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : null,
              rodStackItems: total == 0
                  ? const []
                  : [
                      BarChartRodStackItem(0, day.taken.toDouble(), takenColor),
                      BarChartRodStackItem(
                        day.taken.toDouble(),
                        (day.taken + day.pending).toDouble(),
                        pendingColor,
                      ),
                      BarChartRodStackItem(
                        (day.taken + day.pending).toDouble(),
                        total,
                        missedColor,
                      ),
                    ],
            ),
          ],
        );
      }),
    );
  }
}

class _DayAdherence {
  final DateTime date;
  final int taken;
  final int pending;
  final int missed;

  const _DayAdherence({
    required this.date,
    required this.taken,
    required this.pending,
    required this.missed,
  });

  int get total => taken + pending + missed;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}