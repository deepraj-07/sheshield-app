import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single stealth emergency session stored in Firestore.
///
/// Firestore path: /emergency_sessions/{sessionId}
/// Sub-collections:
///   /emergency_sessions/{sessionId}/locations  — live location updates
///   /emergency_sessions/{sessionId}/evidence   — audio/video upload refs
class StealthSessionModel {
  final String sessionId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'active' | 'ended' | 'cancelled'
  final double? initialLatitude;
  final double? initialLongitude;
  final bool stealthModeEnabled;
  final String triggerSource; // 'tap_pattern' | 'in_app' | 'power_button'
  final List<String> contactsNotified;

  const StealthSessionModel({
    required this.sessionId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.initialLatitude,
    this.initialLongitude,
    required this.stealthModeEnabled,
    required this.triggerSource,
    required this.contactsNotified,
  });

  Map<String, dynamic> toFirestore() => {
        'sessionId': sessionId,
        'userId': userId,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'status': status,
        'initialLatitude': initialLatitude,
        'initialLongitude': initialLongitude,
        'stealthModeEnabled': stealthModeEnabled,
        'triggerSource': triggerSource,
        'contactsNotified': contactsNotified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  StealthSessionModel copyWith({
    String? status,
    DateTime? endedAt,
    double? initialLatitude,
    double? initialLongitude,
    List<String>? contactsNotified,
  }) =>
      StealthSessionModel(
        sessionId: sessionId,
        userId: userId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        initialLatitude: initialLatitude ?? this.initialLatitude,
        initialLongitude: initialLongitude ?? this.initialLongitude,
        stealthModeEnabled: stealthModeEnabled,
        triggerSource: triggerSource,
        contactsNotified: contactsNotified ?? this.contactsNotified,
      );
}

/// A single location update within a stealth session.
class StealthLocationUpdate {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  const StealthLocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toFirestore() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(timestamp),
        'accuracy': accuracy,
        'mapsUrl': 'https://maps.google.com/?q=$latitude,$longitude',
      };
}
