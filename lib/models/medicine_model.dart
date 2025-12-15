/// Medicine Model
/// Represents a medicine/medication entry in the app
class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String frequency; // e.g., "Daily", "Weekly", "Unit"
  final String frequencyUnit; // e.g., "1", "2", "3"
  final DateTime startDate;
  final DateTime endDate;
  final List<String> reminderTimes; // List of times in HH:mm format
  final String? notes;
  final int iconColor; // Color value for the medicine icon
  final int stockCount; // Number of tablets/pills remaining
  final DateTime createdAt;
  final DateTime updatedAt;

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.frequencyUnit,
    required this.startDate,
    required this.endDate,
    required this.reminderTimes,
    this.notes,
    required this.iconColor,
    this.stockCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert Medicine to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'frequencyUnit': frequencyUnit,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reminderTimes': reminderTimes.join(','), // Store as comma-separated string
      'notes': notes,
      'iconColor': iconColor,
      'stockCount': stockCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create Medicine from Map (from database)
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      frequency: map['frequency'] as String,
      frequencyUnit: map['frequencyUnit'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      reminderTimes: (map['reminderTimes'] as String).split(','),
      notes: map['notes'] as String?,
      iconColor: map['iconColor'] as int,
      stockCount: map['stockCount'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Create a copy of Medicine with updated fields
  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    String? frequency,
    String? frequencyUnit,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? reminderTimes,
    String? notes,
    int? iconColor,
    int? stockCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      frequencyUnit: frequencyUnit ?? this.frequencyUnit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      notes: notes ?? this.notes,
      iconColor: iconColor ?? this.iconColor,
      stockCount: stockCount ?? this.stockCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

