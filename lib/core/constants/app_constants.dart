/// Application-level constants: timeouts, thresholds, API keys, limits.
class AppConstants {
  // ========== SOS FLOW ==========
  /// Time to hold SOS button before trigger (milliseconds)
  static const int sosHoldDurationMs = 3000;

  /// Video recording duration on SOS (seconds)
  static const int sosVideoRecordDurationSec = 30;

  /// SOS button countdown update interval (milliseconds)
  static const int sosCountdownIntervalMs = 100;

  // ========== BLUETOOTH ==========
  /// Bluetooth device name to scan for
  static const String bluetoothDeviceName = 'SheShield';

  /// BT data poll interval (milliseconds)
  static const int bluetoothPollIntervalMs = 2000;

  /// BT connection timeout (seconds)
  static const int bluetoothConnectionTimeoutSec = 30;

  // ========== LOCATION ==========
  /// Location update interval (milliseconds)
  static const int locationUpdateIntervalMs = 5000;

  /// Accuracy desired (meters)
  static const double locationAccuracyM = 20.0;

  /// Distance filter for location updates (meters)
  static const double locationDistanceFilterM = 50.0;

  // ========== AUDIO TRIGGER ==========
  /// Microphone amplitude threshold for scream detection (0.0 - 1.0)
  /// Calibrate based on real environment testing
  static const double audioTriggerThreshold = 0.75;

  /// Audio sampling buffer duration (milliseconds)
  static const int audioSamplingDurationMs = 1000;

  // ========== JOURNEY MODE ==========
  /// Geofence radius around destination (meters)
  static const double journeyGeofenceRadiusM = 100.0;

  /// Route deviation threshold (meters)
  static const double journeyDeviationThresholdM = 500.0;

  /// Journey mode timeout before auto-SOS (minutes)
  static const int journeyTimeoutMinutes = 120;

  // ========== CONTACTS MANAGER ==========
  /// Maximum emergency contacts allowed
  static const int maxEmergencyContacts = 5;

  /// Recommended emergency contacts for optimal use
  static const int recommendedContacts = 3;

  // ========== FORM VALIDATION ==========
  /// Minimum password length
  static const int minPasswordLength = 6;

  /// Maximum contact name length
  static const int maxContactNameLength = 50;

  // ========== API & NETWORK ==========
  /// HTTP request timeout (seconds)
  static const int httpTimeoutSec = 30;

  /// OpenStreetMap Overpass API timeout (seconds)
  static const int osmApiTimeoutSec = 15;

  /// Retry attempts for failed API calls
  static const int apiRetryAttempts = 3;

  // ========== NEARBY PLACES ==========
  /// Search radius for nearby police stations (meters)
  static const double policeSearchRadiusM = 5000.0;

  /// Maximum police stations to fetch
  static const int maxPoliceStationsToFetch = 20;

  // ========== VIDEO & EVIDENCE ==========
  /// Maximum video file size (MB)
  static const double maxVideoSizeMB = 100.0;

  /// Firebase Storage path prefix for evidence
  static const String firebaseEvidencePath = 'evidence';

  /// PDF report filename pattern: evidence_[timestamp].pdf
  static const String pdfReportPattern = 'evidence_[timestamp].pdf';

  // ========== STEALTH MODE ==========
  /// Stealth mode unlock code suffix (press this to unlock)
  static const String stealthModeUnlockSuffix = '=';
  // stealthModeSecretCode is now read from AppEnv.stealthModeCode at runtime.

  // ========== SHARED PREFERENCES KEYS ==========
  static const String spKeyUserEmail = 'user_email';
  static const String spKeyUserId = 'user_id';
  static const String spKeyDisplayName = 'display_name';
  static const String spKeyEmergencyContacts = 'emergency_contacts';
  static const String spKeyVoiceTriggerEnabled = 'voice_trigger_enabled';
  static const String spKeyAudioTriggerEnabled = 'audio_trigger_enabled';
  static const String spKeyStealthModeEnabled = 'stealth_mode_enabled';
  static const String spKeyJourneyModeAutoArm = 'journey_mode_auto_arm';
  static const String spKeyLastKnownLocation = 'last_known_location';
  static const String spKeyBluetoothDeviceAddress = 'bt_device_address';
  static const String spKeyAppFirstLaunch = 'app_first_launch';

  // ========== FIRESTORE COLLECTIONS ==========
  static const String firestoreUsersCollection = 'users';
  static const String firestoreSosEventsCollection = 'sos_events';
  static const String firestoreContactsCollection = 'contacts';
  static const String firestoreSettingsCollection = 'settings';

  // ========== ANIMATION DURATIONS ==========
  /// SOS button pulse animation (milliseconds)
  static const int sosButtonPulseMs = 1500;

  /// Card transition animation (milliseconds)
  static const int cardTransitionMs = 300;

  /// Status change animation (milliseconds)
  static const int statusChangeMs = 500;

  /// Modal transition animation (milliseconds)
  static const int modalTransitionMs = 400;

  // ========== HAPTIC FEEDBACK ==========
  /// Light haptic feedback (milliseconds)
  static const int hapticLightMs = 10;

  /// Medium haptic feedback (milliseconds)
  static const int hapticMediumMs = 20;

  /// Heavy haptic feedback (milliseconds)
  static const int hapticHeavyMs = 50;

  // ========== LOGGING ==========
  /// Enable detailed logging in debug mode
  static const bool enableDetailedLogging = true;

  /// Maximum log history to keep (lines)
  static const int maxLogHistoryLines = 1000;

  // ========== SECURITY ==========
  /// Enable APK obfuscation on release build
  static const bool enableObfuscationRelease = true;

  /// SSL pinning enabled for API calls (optional)
  static const bool enableSslPinning = false;

  // ========== NOTIFICATIONS ==========
  /// FCM notification request timeout (seconds)
  static const int fcmTimeoutSec = 10;

  /// Local notification sound ID
  static const String notificationSoundId = 'default';

  // ========== ENVIRONMENT (sourced from .env via AppEnv) ==========
  // Access actual runtime values via AppEnv — e.g. AppEnv.googleMapsApiKey
  // These constants are kept only as documentation references.

  /// OSM Overpass API default endpoint (override in .env with OSM_OVERPASS_API_URL)
  static const String osmOverpassApiUrlDefault =
      'https://overpass-api.de/api/interpreter';
}
