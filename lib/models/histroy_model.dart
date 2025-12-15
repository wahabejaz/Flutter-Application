/// History Model
/// Represents a history entry for medicine intake tracking
/// Note: File name has typo "histroy" but keeping it to match existing structure
class History {
  final int? id;
  final int medicineId; // Foreign key to Medicine
  final int scheduleId; // Foreign key to Schedule
  final DateTime scheduledDate;
  final String scheduledTime; // HH:mm format
  final String status; // 'taken' or 'missed'
  final DateTime? takenAt; // When the medicine was marked as taken
  final DateTime createdAt;

  History({
    this.id,
    required this.medicineId,
    required this.scheduleId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.takenAt,
    required this.createdAt,
  });

  /// Convert History to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'scheduleId': scheduleId,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime,
      'status': status,
      'takenAt': takenAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create History from Map (from database)
  factory History.fromMap(Map<String, dynamic> map) {
    return History(
      id: map['id'] as int?,
      medicineId: map['medicineId'] as int,
      scheduleId: map['scheduleId'] as int,
      scheduledDate: DateTime.parse(map['scheduledDate'] as String),
      scheduledTime: map['scheduledTime'] as String,
      status: map['status'] as String,
      takenAt: map['takenAt'] != null
          ? DateTime.parse(map['takenAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Create a copy of History with updated fields
  History copyWith({
    int? id,
    int? medicineId,
    int? scheduleId,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? status,
    DateTime? takenAt,
    DateTime? createdAt,
  }) {
    return History(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

