import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/db/sqlite_service.dart';

/// History Screen
/// Shows medicine intake history with filters (Taken, Missed, All)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SQLiteService _dbService = SQLiteService();

  String _selectedFilter = 'Taken'; // 'Taken', 'Missed', 'All'
  final Map<String, List<Map<String, dynamic>>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final db = await _dbService.database;
    
    String whereClause = 'WHERE m.uid = ?';
    List<dynamic> whereArgs = [currentUser.uid];
    
    if (_selectedFilter != 'All') {
      whereClause += ' AND h.status = ?';
      whereArgs.add(_selectedFilter.toLowerCase());
    }

    final history = await db.rawQuery('''
      SELECT h.*, m.name, m.dosage, m.iconColor
      FROM history h
      INNER JOIN medicines m ON h.medicineId = m.id
      $whereClause
      ORDER BY h.scheduledDate DESC, h.scheduledTime DESC
    ''', whereArgs);

    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var entry in history) {
      final dateStr = entry['scheduledDate'] as String;
      final date = DateTime.parse(dateStr);
      final dateKey = DateFormat('d MMM yyyy').format(date);
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(entry);
    }

    setState(() {
      _groupedHistory.clear();
      _groupedHistory.addAll(grouped);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'History Log',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.orangeGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton('Taken', AppColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterButton('Missed', AppColors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterButton('All', AppColors.textPrimary),
                ),
              ],
            ),
          ),
          // History List
          Expanded(
            child: _groupedHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedHistory.length,
                    itemBuilder: (context, index) {
                      final dateKey = _groupedHistory.keys.elementAt(index);
                      final entries = _groupedHistory[dateKey]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          ...entries.map((entry) => _buildHistoryCard(entry)),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, Color activeColor) {
    final isSelected = _selectedFilter == label;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedFilter = label;
        });
        _loadHistory();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? activeColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : AppColors.pastelOrange,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final medicineName = entry['name'] as String;
    final dosage = entry['dosage'] as String;
    final time = entry['scheduledTime'] as String;
    final status = entry['status'] as String;
    final isTaken = status == 'taken';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: isTaken ? AppColors.green : AppColors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dosage,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: isTaken ? AppColors.green : AppColors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  color: isTaken ? AppColors.green : AppColors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isTaken ? AppColors.green : AppColors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isTaken ? 'Taken' : 'Missed',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
