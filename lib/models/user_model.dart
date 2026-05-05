import 'package:cloud_firestore/cloud_firestore.dart';

/// UserModel represents an authenticated user in SheShield app.
/// Stored in Firestore at: /users/{userId}
class UserModel {
  final String userId;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool isStealthModeEnabled;
  final bool isVoiceTriggerEnabled;
  final bool isAudioTriggerEnabled;
  final bool isJourneyModeAutoArm;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  UserModel({
    required this.userId,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.isStealthModeEnabled = false,
    this.isVoiceTriggerEnabled = false,
    this.isAudioTriggerEnabled = false,
    this.isJourneyModeAutoArm = false,
    required this.createdAt,
    this.lastUpdatedAt,
  });

  /// Create from Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      userId: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      avatarUrl: data['avatarUrl'],
      isStealthModeEnabled: data['isStealthModeEnabled'] ?? false,
      isVoiceTriggerEnabled: data['isVoiceTriggerEnabled'] ?? false,
      isAudioTriggerEnabled: data['isAudioTriggerEnabled'] ?? false,
      isJourneyModeAutoArm: data['isJourneyModeAutoArm'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdatedAt: data['lastUpdatedAt'] != null
          ? (data['lastUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isStealthModeEnabled': isStealthModeEnabled,
      'isVoiceTriggerEnabled': isVoiceTriggerEnabled,
      'isAudioTriggerEnabled': isAudioTriggerEnabled,
      'isJourneyModeAutoArm': isJourneyModeAutoArm,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Create a copy with modified fields
  UserModel copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isStealthModeEnabled,
    bool? isVoiceTriggerEnabled,
    bool? isAudioTriggerEnabled,
    bool? isJourneyModeAutoArm,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isStealthModeEnabled: isStealthModeEnabled ?? this.isStealthModeEnabled,
      isVoiceTriggerEnabled: isVoiceTriggerEnabled ?? this.isVoiceTriggerEnabled,
      isAudioTriggerEnabled: isAudioTriggerEnabled ?? this.isAudioTriggerEnabled,
      isJourneyModeAutoArm: isJourneyModeAutoArm ?? this.isJourneyModeAutoArm,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, email: $email, displayName: $displayName, '
        'isStealthModeEnabled: $isStealthModeEnabled, isVoiceTriggerEnabled: $isVoiceTriggerEnabled)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
