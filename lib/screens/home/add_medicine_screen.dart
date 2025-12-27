import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/medicine_model.dart';
import '../../services/db/medicine_dao.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/notification_service.dart';

/// Add Medicine Screen
/// Allows users to add a new medicine with all details
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
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

  String _frequency = 'Daily';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _reminderTimes = [];
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
    _selectedIconColor = _iconColors[0];
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
    });
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate end date is not before start date
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }

    // For "As Needed" frequency, skip reminder time validation
    if (_frequency != 'As Needed') {
      if (_reminderTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one reminder time')),
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
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();

      // Map frequency to frequencyUnit
      String frequencyUnit;
      switch (_frequency) {
        case 'Daily':
          frequencyUnit = '1';
          break;
        case 'Weekly':
          frequencyUnit = '7';
          break;
        case 'As Needed':
          frequencyUnit = '0';
          break;
        default:
          frequencyUnit = '1';
      }

      final medicine = Medicine(
        uid: FirebaseAuth.instance.currentUser?.uid,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequency,
        frequencyUnit: frequencyUnit,
        startDate: _startDate,
        endDate: _endDate,
        reminderTimes: _frequency == 'As Needed' ? [] : _reminderTimes,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        iconColor: _selectedIconColor,
        stockCount: int.parse(_stockController.text.trim()),
        createdAt: now,
        updatedAt: now,
      );

      final id = await _medicineDAO.insertMedicine(medicine);
      final medicineWithId = medicine.copyWith(id: id);

      // Schedule reminders only if not "As Needed"
      if (_frequency != 'As Needed') {
        await _scheduler.scheduleMedicineReminders(medicineWithId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine added successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding medicine: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Medication',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                items: ['Daily', 'Weekly', 'As Needed'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _frequency = value!);
                },
              ),
              const SizedBox(height: 24),
              // Start Date & End Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Start Date'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('End Date'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Reminder Times - Only show for non "As Needed" frequencies
              if (_frequency != 'As Needed') ...[
                _buildSectionTitle('Reminder Times'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: 8),
                        const Text('Add Reminder Time'),
                        const Spacer(),
                        Icon(Icons.add, color: AppColors.primary),
                      ],
                    ),
                  ),
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
                const SizedBox(height: 24),
              ],
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
                    final isSelected = _selectedIconColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconColor = color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.medication,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Medication',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
