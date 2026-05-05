import 'package:cloud_firestore/cloud_firestore.dart';

/// MedicalInfoModel stores user's medical information
class MedicalInfoModel {
  final String userId;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> medicalConditions;
  final String doctorContact;
  final String doctorName;
  final DateTime? lastUpdatedAt;

  MedicalInfoModel({
    required this.userId,
    this.bloodGroup = 'O+',
    this.allergies = const [],
    this.medicalConditions = const [],
    this.doctorContact = '',
    this.doctorName = '',
    this.lastUpdatedAt,
  });

  /// Create from Firestore DocumentSnapshot
  factory MedicalInfoModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MedicalInfoModel(
      userId: doc.id,
      bloodGroup: data['bloodGroup'] ?? 'O+',
      allergies: List<String>.from(data['allergies'] ?? []),
      medicalConditions:
          List<String>.from(data['medicalConditions'] ?? []),
      doctorContact: data['doctorContact'] ?? '',
      doctorName: data['doctorName'] ?? '',
      lastUpdatedAt: data['lastUpdatedAt'] != null
          ? (data['lastUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'doctorContact': doctorContact,
      'doctorName': doctorName,
      'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Create a copy with modified fields
  MedicalInfoModel copyWith({
    String? userId,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? medicalConditions,
    String? doctorContact,
    String? doctorName,
    DateTime? lastUpdatedAt,
  }) {
    return MedicalInfoModel(
      userId: userId ?? this.userId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      doctorContact: doctorContact ?? this.doctorContact,
      doctorName: doctorName ?? this.doctorName,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() {
    return 'MedicalInfoModel(bloodGroup: $bloodGroup, allergies: $allergies)';
  }
}
