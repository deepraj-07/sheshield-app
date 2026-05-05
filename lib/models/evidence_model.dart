import 'package:cloud_firestore/cloud_firestore.dart';

/// EvidenceModel represents digital evidence from an SOS event.
/// Stored in Firestore at: /evidence/{evidenceId}
/// This model ensures tamper-proof storage with SHA-256 hashing.
class EvidenceModel {
  final String evidenceId;
  final String sosEventId;
  final String userId;
  final DateTime timestamp;
  final String? videoUrl; // Firebase Storage URL
  final String? sha256Hash; // SHA-256 hash of video file (tamper proof)
  final int videoSizeBytes; // Size of video file
  final String? pdfReportUrl; // Firebase Storage URL for evidence report
  final double latitude;
  final double longitude;
  final String? address;
  final String evidenceType; // "video", "audio", "image", "combined"
  final List<String> metadata; // Additional metadata (device, OS version, etc)
  final bool isVerified; // Marked as verified by authority
  final DateTime createdAt;

  EvidenceModel({
    required this.evidenceId,
    required this.sosEventId,
    required this.userId,
    required this.timestamp,
    this.videoUrl,
    this.sha256Hash,
    this.videoSizeBytes = 0,
    this.pdfReportUrl,
    required this.latitude,
    required this.longitude,
    this.address,
    this.evidenceType = 'video',
    this.metadata = const [],
    this.isVerified = false,
    required this.createdAt,
  });

  /// Create from Firestore DocumentSnapshot
  factory EvidenceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return EvidenceModel(
      evidenceId: doc.id,
      sosEventId: data['sosEventId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      videoUrl: data['videoUrl'],
      sha256Hash: data['sha256Hash'],
      videoSizeBytes: data['videoSizeBytes'] ?? 0,
      pdfReportUrl: data['pdfReportUrl'],
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      address: data['address'],
      evidenceType: data['evidenceType'] ?? 'video',
      metadata: List<String>.from(data['metadata'] ?? []),
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'sosEventId': sosEventId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'videoUrl': videoUrl,
      'sha256Hash': sha256Hash,
      'videoSizeBytes': videoSizeBytes,
      'pdfReportUrl': pdfReportUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'evidenceType': evidenceType,
      'metadata': metadata,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with modified fields
  EvidenceModel copyWith({
    String? evidenceId,
    String? sosEventId,
    String? userId,
    DateTime? timestamp,
    String? videoUrl,
    String? sha256Hash,
    int? videoSizeBytes,
    String? pdfReportUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? evidenceType,
    List<String>? metadata,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return EvidenceModel(
      evidenceId: evidenceId ?? this.evidenceId,
      sosEventId: sosEventId ?? this.sosEventId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      videoUrl: videoUrl ?? this.videoUrl,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      videoSizeBytes: videoSizeBytes ?? this.videoSizeBytes,
      pdfReportUrl: pdfReportUrl ?? this.pdfReportUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      evidenceType: evidenceType ?? this.evidenceType,
      metadata: metadata ?? this.metadata,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get video file size in MB (for display)
  String get videoSizeMB {
    final mb = videoSizeBytes / (1024 * 1024);
    return mb.toStringAsFixed(2);
  }

  /// Get coordinates as string for maps
  String get coordinatesString => '$latitude, $longitude';

  /// Get Google Maps URL for this evidence location
  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  /// Check if video evidence is present and valid
  bool get hasValidVideo {
    return videoUrl != null && videoUrl!.isNotEmpty && sha256Hash != null;
  }

  /// Check if evidence can be considered as valid chain of custody
  bool get hasValidChainOfCustody {
    return hasValidVideo && 
           sha256Hash != null && 
           sha256Hash!.isNotEmpty && 
           pdfReportUrl != null;
  }

  /// Check if evidence is old (> 30 days)
  bool get isOldEvidence {
    return DateTime.now().difference(createdAt).inDays > 30;
  }

  /// Verify integrity by comparing hashes (if external hash provided)
  bool verifyIntegrity(String externalHash) {
    if (sha256Hash == null) return false;
    return sha256Hash == externalHash;
  }

  @override
  String toString() {
    return 'EvidenceModel(evidenceId: $evidenceId, sosEventId: $sosEventId, '
        'type: $evidenceType, hasVideo: $hasValidVideo, isVerified: $isVerified)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceModel &&
          runtimeType == other.runtimeType &&
          evidenceId == other.evidenceId;

  @override
  int get hashCode => evidenceId.hashCode;
}
