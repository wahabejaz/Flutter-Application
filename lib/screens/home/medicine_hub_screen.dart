import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/medicine_model.dart';
import '../../routes/app_routes.dart';
import '../../services/db/medicine_dao.dart';
import 'refill_tracker/refill_tracker_screen.dart';

class MedicineHubScreen extends StatelessWidget {
  final bool initialRefills;

  const MedicineHubScreen({super.key, this.initialRefills = false});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialRefills ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medicines'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My medicines'),
              Tab(text: 'Refills'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MedicineListPage(), RefillTrackerScreen(embedded: true)],
        ),
      ),
    );
  }
}

class _MedicineListPage extends StatefulWidget {
  const _MedicineListPage();

  @override
  State<_MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<_MedicineListPage> {
  final MedicineDAO _medicineDAO = MedicineDAO();
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      _medicines = await _medicineDAO.getAllMedicines(uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load medicines: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMedicine(Medicine medicine) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.medicineDetail,
      arguments: medicine.id,
    );
    if (mounted && (result == 'deleted' || result == 'edited')) {
      await _loadMedicines();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_medicines.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMedicines,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: 88),
            Icon(
              Icons.medication_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No medicines yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add a medicine to keep your treatment organized.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: FilledButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.addMedicine,
                  );
                  if (mounted && result == true) await _loadMedicines();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add medicine'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMedicines,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _medicines.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final medicine = _medicines[index];
          final isOut = medicine.stockCount == 0;
          final isLow = medicine.stockCount > 0 && medicine.stockCount <= 5;
          final stockColor = isOut
              ? AppStatusColors.missed(context)
              : isLow
              ? AppStatusColors.upcoming(context)
              : AppStatusColors.taken(context);
          return Card(
            child: ListTile(
              minTileHeight: 88,
              leading: CircleAvatar(
                backgroundColor: Color(medicine.iconColor),
                child: const Icon(Icons.medication, color: Colors.white),
              ),
              title: Text(medicine.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${medicine.dosage} · ${medicine.frequency} · '
                    '${medicine.stockCount} left',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: (medicine.stockCount / 30).clamp(0.0, 1.0),
                      minHeight: 4,
                      color: stockColor,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      semanticsLabel: 'Stock: ${medicine.stockCount} remaining',
                    ),
                  ),
                ],
              ),
              trailing: isOut || isLow
                  ? Semantics(
                      label: isOut
                          ? 'Out of stock'
                          : 'Low stock: ${medicine.stockCount} remaining, refill',
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOut
                                  ? Icons.error_outline
                                  : Icons.inventory_2_outlined,
                              size: 18,
                              color: stockColor,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              isOut ? 'Out' : 'Refill',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: stockColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _openMedicine(medicine),
            ),
          );
        },
      ),
    );
  }
}
