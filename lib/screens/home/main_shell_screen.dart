import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../routes/app_routes.dart';
import 'home_screen.dart';
import 'medicine_hub_screen.dart';
import 'insights_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  int _refreshVersion = 0;
  bool _showRefillsTab = false;

  Future<void> _addMedicine() async {
    try {
      final result = await Navigator.pushNamed(context, AppRoutes.addMedicine);
      if (result == true && mounted) {
        setState(() => _refreshVersion++);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Add Medicine: $error')),
        );
      }
    }
  }

  void _openRefills() {
    setState(() {
      _showRefillsTab = true;
      _selectedIndex = 2;
    });
  }

  List<Widget> get _pages => [
    HomeScreen(
      key: ValueKey('today-$_refreshVersion'),
      onOpenProfile: () => setState(() => _selectedIndex = 4),
      onOpenRefills: _openRefills,
    ),
    const ScheduleScreen(),
    MedicineHubScreen(
      key: ValueKey('medicines-$_refreshVersion-$_showRefillsTab'),
      initialRefills: _showRefillsTab,
    ),
    const InsightsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final todayColors = TodayColors.of(context);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedicine,
        tooltip: 'Add medicine',
        backgroundColor: todayColors.fabBackground,
        foregroundColor: todayColors.fabForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: todayColors.navigationForeground),
          ),
          labelTextStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: todayColors.navigationForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: todayColors.navigationBackground,
          indicatorColor: todayColors.navigationIndicator,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => setState(() {
            _selectedIndex = index;
            if (index != 2) _showRefillsTab = false;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Medicines',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
