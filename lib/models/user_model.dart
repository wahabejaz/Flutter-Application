/// User Model
/// Represents user information in the app
class User {
  final int? id;
  final String? uid; // Firebase Auth UID
  final String? email;
  final String? fullName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    this.uid,
    this.email,
    this.fullName,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert User to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create User from Map (from database)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      fullName: map['fullName'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Create a copy of User with updated fields
  User copyWith({
    int? id,
    String? uid,
    String? email,
    String? fullName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

