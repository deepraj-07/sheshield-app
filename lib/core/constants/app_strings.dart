/// All UI strings used in SheShield app.
/// NO hardcoded strings in UI — use these constants exclusively.
/// Enables easy localization and consistent messaging.
class AppStrings {
  // ========== NAVIGATION & TABS ==========
  static const String tabHome = 'Home';
  static const String tabLocation = 'Location';
  static const String tabContacts = 'Contacts';
  static const String tabBluetooth = 'Bracelet';
  static const String tabProfile = 'Profile';

  // ========== HOME SCREEN ==========
  static const String safeStatus = 'You are safe';
  static const String sosActive = 'SOS Active';
  static const String holdForSos = 'Hold 1 second for SOS';
  static const String sofBraceletBpm = 'BPM';
  static const String braceletBattery = 'Battery';
  static const String connected = 'Connected';
  static const String disconnected = 'Disconnected';

  // ========== ACTION GRID ==========
  static const String shareLocation = 'Share Location';
  static const String nearbyPolice = 'Nearby Police';
  static const String emergencyContacts = 'Contacts';
  static const String journeyMode = 'Journey Mode';

  // ========== LOCATION SCREEN ==========
  static const String currentLocation = 'Current Location';
  static const String shareVia = 'Share via';
  static const String copyLink = 'Copy Link';
  static const String shareWhatsapp = 'WhatsApp';
  static const String shareSms = 'SMS';
  static const String shareClipboard = 'Clipboard';
  static const String locationCopied = 'Location link copied!';
  static const String noLocation = 'Unable to fetch location';

  // ========== CONTACTS SCREEN ==========
  static const String addContact = 'Add Contact';
  static const String emergencyContacts_title = 'Emergency Contacts';
  static const String contactName = 'Name';
  static const String contactPhone = 'Phone Number';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String testSms = 'Test SMS';
  static const String noContacts = 'No emergency contacts added';
  static const String addEmergencyContact = 'Add an emergency contact';
  static const String maxContacts = 'Maximum 5 contacts allowed';

  // ========== NEARBY POLICE ==========
  static const String nearbyPoliceStations = 'Nearby Police Stations';
  static const String getDirections = 'Get Directions';
  static const String distance = 'Distance';
  static const String noPoliceNearby = 'No police stations found nearby';
  static const String fetchingNearby = 'Fetching nearby stations...';

  // ========== BLUETOOTH / BRACELET ==========
  static const String braceletSettings = 'Bracelet Settings';
  static const String scanDevices = 'Scan Devices';
  static const String scanning = 'Scanning...';
  static const String selectDevice = 'Select Device';
  static const String noDevicesFound = 'No devices found';
  static const String deviceName = 'SheShield';
  static const String pair = 'Pair';
  static const String disconnect = 'Disconnect';
  static const String connected_status = 'Connected';
  static const String disconnected_status = 'Disconnected';
  static const String pairingFailed = 'Pairing failed';

  // ========== PROFILE SCREEN ==========
  static const String profile = 'Profile';
  static const String email = 'Email';
  static const String displayName = 'Display Name';
  static const String settings = 'Settings';
  static const String voiceTrigger = 'Voice Trigger';
  static const String audioTrigger = 'Audio Trigger (Scream Detection)';
  static const String stealthMode = 'Stealth Mode';
  static const String journeyModeAutoArm = 'Auto-arm Journey Mode';
  static const String logout = 'Logout';
  static const String confirmLogout = 'Are you sure you want to logout?';

  // ========== AUTHENTICATION ==========
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String email_hint = 'Enter your email';
  static const String password = 'Password';
  static const String password_hint = 'Enter your password';
  static const String confirmPassword = 'Confirm Password';
  static const String confirmPassword_hint = 'Re-enter your password';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String loginError = 'Login failed. Please try again.';
  static const String signupError = 'Signup failed. Please try again.';
  static const String passwordMismatch = 'Passwords do not match';
  static const String invalidEmail = 'Please enter a valid email';
  static const String passwordTooShort =
      'Password must be at least 6 characters';

  // ========== SOS & EMERGENCY ==========
  static const String sosTriggered = 'SOS Triggered!';
  static const String sosMessageSent = 'Emergency contacts notified';
  static const String videoRecording = 'Recording video...';
  static const String sosCountdown = 'SOS in';
  static const String cancel = 'Cancel';
  static const String sosAlert = 'Emergency Alert';
  static const String contactsNotified = 'Contacts have been notified';

  // ========== JOURNEY MODE ==========
  static const String journeyModeTitle = 'Journey Mode';
  static const String setDestination = 'Set Destination';
  static const String startJourney = 'Start Journey';
  static const String endJourney = 'End Journey';
  static const String journeyActive = 'Journey Active';
  static const String arrivedSafely = 'Arrived Safely';
  static const String deviceDeviatedFromRoute =
      'You have deviated from the planned route';
  static const String estimatedArrival = 'Estimated Arrival';

  // ========== PAST EMERGENCIES ==========
  static const String pastEmergencies = 'Past Emergencies';
  static const String noEmergencies = 'No emergency events recorded';
  static const String viewDetails = 'View Details';
  static const String downloadPdf = 'Download Report';
  static const String viewVideo = 'Watch Video';
  static const String coordinates = 'Coordinates';
  static const String timestamp = 'Timestamp';
  static const String evidenceHash = 'Evidence Hash';

  // ========== STEALTH MODE ==========
  static const String calculator = 'Calculator';
  static const String enterSecretCode = 'Enter secret code and press =';
  static const String invalidCode = 'Invalid code';
  static const String stealthModeActive = 'Stealth Mode Active';

  // ========== GENERAL ==========
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String confirm = 'Confirm';
  static const String retry = 'Retry';
  static const String back = 'Back';
  static const String close = 'Close';
  static const String permissionDenied = 'Permission denied';
  static const String enablePermission = 'Please enable permission in settings';
  static const String networkError = 'Network error. Please try again.';
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';

  // ========== TOAST MESSAGES ==========
  static const String helpReceived = 'Help request received!';
  static const String emergencyAlertSent = 'Emergency alert sent to contacts';
  static const String videoUploadFailed = 'Video upload failed. Retrying...';
  static const String pdfGenerationFailed = 'Failed to generate PDF report';
  static const String permissionGranted = 'Permission granted';
}
