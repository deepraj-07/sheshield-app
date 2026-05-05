/// BraceletModel represents the state of the ESP32 wearable bracelet.
/// This model is NOT persisted to Firestore - it's only for real-time UI state.
/// Data comes via Bluetooth from ESP32 device.
class BraceletModel {
  final int bpm; // Heart rate (beats per minute)
  final int batteryPercentage; // Battery level 0-100
  final bool isConnected; // Bluetooth connection status
  final DateTime? lastUpdateTime; // When data was last received
  final String? deviceAddress; // MAC address of paired device
  final String? deviceName; // Name of paired device

  BraceletModel({
    required this.bpm,
    required this.batteryPercentage,
    required this.isConnected,
    this.lastUpdateTime,
    this.deviceAddress,
    this.deviceName,
  });

  /// Create initial/default state (disconnected)
  factory BraceletModel.disconnected() {
    return BraceletModel(
      bpm: 0,
      batteryPercentage: 0,
      isConnected: false,
      lastUpdateTime: null,
      deviceAddress: null,
      deviceName: null,
    );
  }

  /// Create from JSON (for local storage)
  factory BraceletModel.fromJson(Map<String, dynamic> json) {
    return BraceletModel(
      bpm: json['bpm'] ?? 0,
      batteryPercentage: json['batteryPercentage'] ?? 0,
      isConnected: json['isConnected'] ?? false,
      lastUpdateTime: json['lastUpdateTime'] != null
          ? DateTime.parse(json['lastUpdateTime'])
          : null,
      deviceAddress: json['deviceAddress'],
      deviceName: json['deviceName'],
    );
  }

  /// Convert to JSON (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'bpm': bpm,
      'batteryPercentage': batteryPercentage,
      'isConnected': isConnected,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
    };
  }

  /// Create a copy with modified fields
  BraceletModel copyWith({
    int? bpm,
    int? batteryPercentage,
    bool? isConnected,
    DateTime? lastUpdateTime,
    String? deviceAddress,
    String? deviceName,
  }) {
    return BraceletModel(
      bpm: bpm ?? this.bpm,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      isConnected: isConnected ?? this.isConnected,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  /// Check if bracelet is in critical battery state (< 20%)
  bool get isCriticalBattery => batteryPercentage < 20;

  /// Check if bracelet is in low battery state (< 40%)
  bool get isLowBattery => batteryPercentage < 40;

  /// Check if bracelet connection is stale (no update for 10+ seconds)
  bool get isConnectionStale {
    if (lastUpdateTime == null) return true;
    return DateTime.now().difference(lastUpdateTime!).inSeconds > 10;
  }

  /// Get human-readable battery status
  String getBatteryStatus() {
    if (batteryPercentage >= 80) return 'Excellent';
    if (batteryPercentage >= 60) return 'Good';
    if (batteryPercentage >= 40) return 'Fair';
    if (batteryPercentage >= 20) return 'Low';
    return 'Critical';
  }

  /// Check if BPM is in normal resting range (60-100)
  bool get isNormalHeartRate => bpm >= 60 && bpm <= 100;

  /// Check if BPM is elevated (>100)
  bool get isElevatedHeartRate => bpm > 100;

  /// Check if BPM is critical (>140)
  bool get isCriticalHeartRate => bpm > 140;

  @override
  String toString() {
    return 'BraceletModel(bpm: $bpm, battery: $batteryPercentage%, '
        'connected: $isConnected, device: $deviceName)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BraceletModel &&
          runtimeType == other.runtimeType &&
          bpm == other.bpm &&
          batteryPercentage == other.batteryPercentage &&
          isConnected == other.isConnected &&
          deviceAddress == other.deviceAddress;

  @override
  int get hashCode =>
      bpm.hashCode ^
      batteryPercentage.hashCode ^
      isConnected.hashCode ^
      deviceAddress.hashCode;
}
