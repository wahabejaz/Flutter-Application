import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/medicine_model.dart';
import '../../services/db/medicine_dao.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/notification_service.dart';

/// Edit Medicine Screen
/// Allows users to edit an existing medicine with all details pre-filled
class EditMedicineScreen extends StatefulWidget {
  final Medicine medicine;

  const EditMedicineScreen({super.key, required this.medicine});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _stockController = TextEditingController();
  final _notesController = TextEditingController();
  final _nameFocus = FocusNode();
  final _dosageFocus = FocusNode();
  final _stockFocus = FocusNode();
  final _notesFocus = FocusNode();
  final MedicineDAO _medicineDAO = MedicineDAO();

  late String _frequency;
  late String _frequencyUnit;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  late List<String> _reminderTimes;
  late int _selectedIconColor;
  bool _isLoading = false;

  final List<int> _iconColors = [
    0xFF66BB6A, // green
    0xFF42A5F5, // blue
    0xFFEF5350, // red
    0xFFFF8A65, // orange
    0xFF4ECDC4, // primary
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill all fields with existing medicine data
    _nameController.text = widget.medicine.name;
    _dosageController.text = widget.medicine.dosage;
    _stockController.text = widget.medicine.stockCount.toString();
    _notesController.text = widget.medicine.notes ?? '';
    _frequency = widget.medicine.frequency;
    _frequencyUnit = widget.medicine.frequencyUnit;
    _startDate = widget.medicine.startDate;
    _endDate = widget.medicine.endDate;
    _reminderTimes = List.from(widget.medicine.reminderTimes);
    _selectedIconColor = widget.medicine.iconColor;
  }

  ReminderScheduler get _scheduler {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    return ReminderScheduler(notificationService: notificationService);
  }

  /// Helper method to compare only date parts (year, month, day) of DateTime objects
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  /// Check if a reminder time is in the future for today
  bool _isReminderTimeValidForToday(String timeStr) {
    final now = DateTime.now();
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final reminderDateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return reminderDateTime.isAfter(now);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _stockController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    _dosageFocus.dispose();
    _stockFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      // Check for duplicate times
      if (_reminderTimes.contains(timeStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This reminder time is already added')),
        );
        return;
      }

      // Check if time is valid for today
      if (_isSameDate(_startDate, DateTime.now()) && !_isReminderTimeValidForToday(timeStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected time has already passed. Please choose a future time.')),
        );
        return;
      }

      setState(() {
        _selectedTime = picked;
        _reminderTimes.add(timeStr);
        _reminderTimes.sort();
      });
      // Unfocus all fields after time selection
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _removeTime(String time) {
    setState(() {
      _reminderTimes.remove(time);
      // Ensure list remains sorted after removal
      _reminderTimes.sort();
    });
  }

  Future<void> _updateMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one reminder time')),
      );
      return;
    }

    // Validate end date is not before start date
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }

    // Validate date and time for same-day medicines
    final now = DateTime.now();
    if (_isSameDate(_startDate, now) && _isSameDate(_endDate, now)) {
      // For same-day medicines, check if any reminder time has already passed
      for (final timeStr in _reminderTimes) {
        if (!_isReminderTimeValidForToday(timeStr)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected time has already passed. Please choose a future time.')),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Map frequency to frequencyUnit
      String frequencyUnit;
      switch (_frequency) {
        case 'Daily':
          frequencyUnit = '1';
          break;
        case 'Weekly':
          frequencyUnit = '7';
          break;
        case 'Monthly':
          frequencyUnit = '30';
          break;
        default:
          frequencyUnit = '1';
      }

      // Create updated medicine object
      final updatedMedicine = Medicine(
        id: widget.medicine.id,
        uid: currentUser.uid,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequency,
        frequencyUnit: frequencyUnit,
        startDate: _startDate,
        endDate: _endDate,
        reminderTimes: _reminderTimes,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        iconColor: _selectedIconColor,
        stockCount: int.tryParse(_stockController.text.trim()) ?? 0,
        createdAt: widget.medicine.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update medicine in database
      await _medicineDAO.updateMedicine(updatedMedicine);

      // Cancel existing notifications and schedule new ones
      await _scheduler.cancelMedicineReminders(widget.medicine.id!);
      await _scheduler.scheduleMedicineReminders(updatedMedicine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine updated successfully')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update medicine: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Medicine',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateMedicine,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication Name
                    _buildSectionTitle('Medication Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      decoration: InputDecoration(
                        hintText: 'Enter medication name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter medication name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Dosage
                    _buildSectionTitle('Dosage'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dosageController,
                      focusNode: _dosageFocus,
                      decoration: InputDecoration(
                        hintText: 'e.g., 500mg, 1 tablet',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter dosage';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Stock Count
                    _buildSectionTitle('Initial Stock Count'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _stockController,
                      focusNode: _stockFocus,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter initial stock count';
                        }
                        final count = int.tryParse(value);
                        if (count == null || count < 0) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Frequency
                    _buildSectionTitle('Frequency'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: ['Daily', 'Weekly', 'Monthly']
                          .map((freq) => DropdownMenuItem(
                                value: freq,
                                child: Text(freq),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _frequency = value;
                            // Update frequencyUnit based on selected frequency
                            switch (value) {
                              case 'Daily':
                                _frequencyUnit = '1';
                                break;
                              case 'Weekly':
                                _frequencyUnit = '7';
                                break;
                              case 'Monthly':
                                _frequencyUnit = '30';
                                break;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Date Range
                    _buildSectionTitle('Date Range'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_startDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_endDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Reminder Times
                    _buildSectionTitle('Reminder Times'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Add reminder times',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _selectTime(context),
                                icon: const Icon(Icons.add),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_reminderTimes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _reminderTimes.map((time) {
                                return Chip(
                                  label: Text(time),
                                  onDeleted: () => _removeTime(time),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Notes
                    _buildSectionTitle('Notes'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      focusNode: _notesFocus,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add any additional notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Select Icon
                    _buildSectionTitle('Select Icon'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _iconColors.map((color) {
                          final isSelected = color == _selectedIconColor;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedIconColor = color);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(color),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: AppColors.primary, width: 3)
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

