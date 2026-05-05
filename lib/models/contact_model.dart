import 'package:cloud_firestore/cloud_firestore.dart';

/// ContactModel represents an emergency contact.
/// Stored locally in SharedPreferences as JSON array.
/// Also synced to Firestore at: /contacts/{contactId}
class ContactModel {
  final String contactId;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final int priority; // 1 = highest, 5 = lowest
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? lastTestedAt; // When SMS was last tested

  ContactModel({
    required this.contactId,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.priority = 1,
    this.isPinned = false,
    required this.createdAt,
    this.lastTestedAt,
  });

  /// Create from JSON (for SharedPreferences)
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      contactId: json['contactId'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      relationship: json['relationship'],
      priority: json['priority'] ?? 1,
      isPinned: json['isPinned'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastTestedAt: json['lastTestedAt'] != null
          ? DateTime.parse(json['lastTestedAt'])
          : null,
    );
  }

  /// Convert to JSON (for SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'contactId': contactId,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'priority': priority,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'lastTestedAt': lastTestedAt?.toIso8601String(),
    };
  }

  /// Create from Firestore DocumentSnapshot
  factory ContactModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ContactModel(
      contactId: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      relationship: data['relationship'],
      priority: data['priority'] ?? 1,
      isPinned: data['isPinned'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastTestedAt: data['lastTestedAt'] != null
          ? (data['lastTestedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'priority': priority,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastTestedAt': lastTestedAt != null ? Timestamp.fromDate(lastTestedAt!) : null,
    };
  }

  /// Create a copy with modified fields
  ContactModel copyWith({
    String? contactId,
    String? userId,
    String? name,
    String? phoneNumber,
    String? relationship,
    int? priority,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? lastTestedAt,
  }) {
    return ContactModel(
      contactId: contactId ?? this.contactId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
    );
  }

  /// Get clean phone number (digits only)
  String get cleanPhoneNumber => phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

  /// Format phone number for display
  String get formattedPhoneNumber {
    final clean = cleanPhoneNumber;
    if (clean.length == 10) {
      return '(${clean.substring(0, 3)}) ${clean.substring(3, 6)}-${clean.substring(6)}';
    }
    return phoneNumber;
  }

  @override
  String toString() {
    return 'ContactModel(name: $name, phoneNumber: $phoneNumber, priority: $priority, isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModel &&
          runtimeType == other.runtimeType &&
          contactId == other.contactId;

  @override
  int get hashCode => contactId.hashCode;
}
