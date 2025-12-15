/// Schedule Model
/// Represents a scheduled medicine reminder for a specific date and time
class Schedule {
  final int? id;
  final int medicineId; // Foreign key to Medicine
  final DateTime scheduledDate;
  final String scheduledTime; // HH:mm format
  final String status; // 'pending', 'taken', 'missed'
  final DateTime? takenAt; // When the medicine was marked as taken
  final DateTime createdAt;

  Schedule({
    this.id,
    required this.medicineId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.status = 'pending',
    this.takenAt,
    required this.createdAt,
  });

  /// Convert Schedule to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime,
      'status': status,
      'takenAt': takenAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create Schedule from Map (from database)
  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as int?,
      medicineId: map['medicineId'] as int,
      scheduledDate: DateTime.parse(map['scheduledDate'] as String),
      scheduledTime: map['scheduledTime'] as String,
      status: map['status'] as String? ?? 'pending',
      takenAt: map['takenAt'] != null
          ? DateTime.parse(map['takenAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Create a copy of Schedule with updated fields
  Schedule copyWith({
    int? id,
    int? medicineId,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? status,
    DateTime? takenAt,
    DateTime? createdAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

