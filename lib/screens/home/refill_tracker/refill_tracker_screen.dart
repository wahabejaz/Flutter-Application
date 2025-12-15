import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/medicine_model.dart';
import '../../../services/db/medicine_dao.dart';

/// Refill Tracker Screen
/// Shows medicines that are running low on stock and need to be refilled
class RefillTrackerScreen extends StatefulWidget {
  const RefillTrackerScreen({super.key});

  @override
  State<RefillTrackerScreen> createState() => _RefillTrackerScreenState();
}

class _RefillTrackerScreenState extends State<RefillTrackerScreen> {
  final MedicineDAO _medicineDAO = MedicineDAO();
  List<Medicine> _lowStockMedicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLowStockMedicines();
  }

  Future<void> _loadLowStockMedicines() async {
    setState(() => _isLoading = true);
    try {
      final allMedicines = await _medicineDAO.getAllMedicines();
      // Filter medicines with low stock (less than 10)
      _lowStockMedicines = allMedicines.where((medicine) =>
        medicine.stockCount < 10 && medicine.stockCount > 0
      ).toList();

      // Sort by stock count (lowest first)
      _lowStockMedicines.sort((a, b) => a.stockCount.compareTo(b.stockCount));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medicines: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStockCount(Medicine medicine, int newCount) async {
    try {
      await _medicineDAO.updateStockCount(medicine.id!, newCount);
      await _loadLowStockMedicines(); // Refresh the list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock count updated successfully'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stock: $e')),
        );
      }
    }
  }

  Future<void> _showUpdateStockDialog(Medicine medicine) async {
    final controller = TextEditingController(text: medicine.stockCount.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock for ${medicine.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New stock count',
            hintText: 'Enter number of tablets/pills',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              if (count != null && count >= 0) {
                Navigator.of(context).pop(count);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateStockCount(medicine, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refill Tracker'),
        backgroundColor: AppColors.pastelOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLowStockMedicines,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lowStockMedicines.isEmpty
              ? _buildEmptyState()
              : _buildMedicinesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'All medicines are well stocked!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No refills needed at this time.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lowStockMedicines.length,
      itemBuilder: (context, index) {
        final medicine = _lowStockMedicines[index];
        final stockLevel = _getStockLevel(medicine.stockCount);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(medicine.iconColor),
              child: const Icon(
                Icons.local_pharmacy,
                color: Colors.white,
              ),
            ),
            title: Text(
              medicine.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${medicine.dosage} • ${medicine.stockCount} remaining'),
                const SizedBox(height: 4),
                _buildStockIndicator(stockLevel),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showUpdateStockDialog(medicine),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refill'),
            ),
          ),
        );
      },
    );
  }

  StockLevel _getStockLevel(int stockCount) {
    if (stockCount <= 2) return StockLevel.critical;
    if (stockCount <= 5) return StockLevel.low;
    return StockLevel.warning;
  }

  Widget _buildStockIndicator(StockLevel level) {
    final color = switch (level) {
      StockLevel.critical => Colors.red,
      StockLevel.low => Colors.orange,
      StockLevel.warning => Colors.yellow[700],
    };

    final text = switch (level) {
      StockLevel.critical => 'Critical - Refill immediately!',
      StockLevel.low => 'Low stock - Refill soon',
      StockLevel.warning => 'Running low',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? Colors.grey),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

enum StockLevel {
  critical,
  low,
  warning,
}