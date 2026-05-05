import 'package:cloud_firestore/cloud_firestore.dart';

/// SosEventModel represents a single SOS emergency event.
/// Stored in Firestore at: /sos_events/{eventId}
/// Each event is immutable after creation for evidence preservation.
class SosEventModel {
  final String eventId;
  final String userId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? address;
  final String? videoUrl; // Firebase Storage URL
  final String? sha256Hash; // Video evidence hash
  final String? pdfReportUrl; // Firebase Storage URL for PDF report
  final int? bpmAtTrigger; // Heart rate when SOS was triggered
  final String? triggerSource; // "button", "bluetooth", "voice", "audio", "journey"
  final List<String> contactsNotified; // List of contact phone numbers notified
  final bool isResolved;
  final DateTime? resolvedAt;
  final String? notes; // User notes about the incident

  SosEventModel({
    required this.eventId,
    required this.userId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.address,
    this.videoUrl,
    this.sha256Hash,
    this.pdfReportUrl,
    this.bpmAtTrigger,
    this.triggerSource,
    this.contactsNotified = const [],
    this.isResolved = false,
    this.resolvedAt,
    this.notes,
  });

  /// Create from Firestore DocumentSnapshot
  factory SosEventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SosEventModel(
      eventId: doc.id,
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      address: data['address'],
      videoUrl: data['videoUrl'],
      sha256Hash: data['sha256Hash'],
      pdfReportUrl: data['pdfReportUrl'],
      bpmAtTrigger: data['bpmAtTrigger'],
      triggerSource: data['triggerSource'],
      contactsNotified: List<String>.from(data['contactsNotified'] ?? []),
      isResolved: data['isResolved'] ?? false,
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'videoUrl': videoUrl,
      'sha256Hash': sha256Hash,
      'pdfReportUrl': pdfReportUrl,
      'bpmAtTrigger': bpmAtTrigger,
      'triggerType': triggerSource,
      'triggerSource': triggerSource,
      'contactsNotified': contactsNotified,
      'isResolved': isResolved,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'notes': notes,
    };
  }

  /// Create a copy with modified fields
  SosEventModel copyWith({
    String? eventId,
    String? userId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? address,
    String? videoUrl,
    String? sha256Hash,
    String? pdfReportUrl,
    int? bpmAtTrigger,
    String? triggerSource,
    List<String>? contactsNotified,
    bool? isResolved,
    DateTime? resolvedAt,
    String? notes,
  }) {
    return SosEventModel(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      videoUrl: videoUrl ?? this.videoUrl,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      pdfReportUrl: pdfReportUrl ?? this.pdfReportUrl,
      bpmAtTrigger: bpmAtTrigger ?? this.bpmAtTrigger,
      triggerSource: triggerSource ?? this.triggerSource,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Get coordinates as LatLng string for maps
  String get coordinatesString => '$latitude, $longitude';

  /// Get Google Maps URL for this event location
  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  /// Check if event has video evidence
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Check if event has PDF report
  bool get hasPdfReport => pdfReportUrl != null && pdfReportUrl!.isNotEmpty;

  /// Check if event is recent (less than 24 hours old)
  bool get isRecent {
    final now = DateTime.now();
    return now.difference(timestamp).inHours < 24;
  }

  /// Time elapsed since SOS was triggered
  Duration get timeSinceEvent {
    return DateTime.now().difference(timestamp);
  }

  @override
  String toString() {
    return 'SosEventModel(eventId: $eventId, userId: $userId, timestamp: $timestamp, '
        'address: $address, hasVideo: $hasVideo, isResolved: $isResolved)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SosEventModel &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId;

  @override
  int get hashCode => eventId.hashCode;
}
