import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../models/bracelet_model.dart';
import '../core/utils/logger.dart';

/// Enum for SOS state
enum SosState {
  idle,      // No SOS active
  countdown, // Countdown to SOS trigger
  active,    // SOS is active/triggered
  resolved,  // SOS has been resolved
}

/// Central application state management.
/// All major app state is held here and notified to listeners.
/// This is the single source of truth for app-wide state.
class AppState extends ChangeNotifier {
  // ========== USER STATE ==========
  UserModel? _currentUser;

  // ========== CONTACTS STATE ==========
  List<ContactModel> _emergencyContacts = [];

  // ========== SOS STATE ==========
  SosState _sosState = SosState.idle;
  DateTime? _sosTriggeredAt;

  // ========== BRACELET STATE ==========
  BraceletModel _braceletData = BraceletModel.disconnected();

  // ========== LOCATION STATE ==========
  double? _currentLatitude;
  double? _currentLongitude;
  String? _currentAddress;

  // ========== SETTINGS STATE ==========
  bool _isStealthModeActive = false;
  bool _isJourneyModeActive = false;
  bool _isVoiceTriggerEnabled = false;
  bool _isAudioTriggerEnabled = false;
  ThemeMode _themeMode = ThemeMode.light;

  // ========== GETTERS ==========
  UserModel? get currentUser => _currentUser;
  List<ContactModel> get emergencyContacts => _emergencyContacts;
  SosState get sosState => _sosState;
  DateTime? get sosTriggeredAt => _sosTriggeredAt;
  BraceletModel get braceletData => _braceletData;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  String? get currentAddress => _currentAddress;
  bool get isStealthModeActive => _isStealthModeActive;
  bool get isJourneyModeActive => _isJourneyModeActive;
  bool get isVoiceTriggerEnabled => _isVoiceTriggerEnabled;
  bool get isAudioTriggerEnabled => _isAudioTriggerEnabled;
  ThemeMode get themeMode => _themeMode;

  /// Check if user is safe (no active SOS)
  bool get isSafe => _sosState == SosState.idle;

  // ========== USER MANAGEMENT ==========
  void setCurrentUser(UserModel? user) {
    _currentUser = user;
    if (user != null) {
      _isStealthModeActive = user.isStealthModeEnabled;
      _isJourneyModeActive = user.isJourneyModeAutoArm;
      _isVoiceTriggerEnabled = user.isVoiceTriggerEnabled;
      _isAudioTriggerEnabled = user.isAudioTriggerEnabled;
      AppLogger.providerStateChange('AppState', 'User set: ${user.email}');
    }
    notifyListeners();
  }

  void clearCurrentUser() {
    _currentUser = null;
    _emergencyContacts = [];
    _sosState = SosState.idle;
    AppLogger.providerStateChange('AppState', 'User cleared');
    notifyListeners();
  }

  // ========== CONTACTS MANAGEMENT ==========
  void setEmergencyContacts(List<ContactModel> contacts) {
    _emergencyContacts = contacts;
    AppLogger.providerStateChange('AppState', 'Contacts updated: ${contacts.length}');
    notifyListeners();
  }

  void addEmergencyContact(ContactModel contact) {
    if (_emergencyContacts.length < 5) {
      _emergencyContacts.add(contact);
      AppLogger.providerStateChange('AppState', 'Contact added: ${contact.name}');
      notifyListeners();
    } else {
      AppLogger.w('Cannot add more than 5 emergency contacts');
    }
  }

  void removeEmergencyContact(String contactId) {
    _emergencyContacts.removeWhere((contact) => contact.contactId == contactId);
    AppLogger.providerStateChange('AppState', 'Contact removed: $contactId');
    notifyListeners();
  }

  void updateEmergencyContact(ContactModel contact) {
    final index =
        _emergencyContacts.indexWhere((c) => c.contactId == contact.contactId);
    if (index >= 0) {
      _emergencyContacts[index] = contact;
      AppLogger.providerStateChange('AppState', 'Contact updated: ${contact.name}');
      notifyListeners();
    }
  }

  // ========== SOS STATE MANAGEMENT ==========
  void setSosState(SosState state) {
    _sosState = state;
    if (state == SosState.active) {
      _sosTriggeredAt = DateTime.now();
      AppLogger.sosStep(0, 'SOS State set to ACTIVE');
    } else if (state == SosState.idle) {
      _sosTriggeredAt = null;
    }
    AppLogger.providerStateChange('AppState', 'SOS State: $state');
    notifyListeners();
  }

  bool get isSosActive => _sosState == SosState.active;

  // ========== BRACELET STATE MANAGEMENT ==========
  void updateBraceletData(BraceletModel data) {
    _braceletData = data;
    AppLogger.providerStateChange(
      'AppState',
      'Bracelet updated: BPM=${data.bpm}, Battery=${data.batteryPercentage}%, Connected=${data.isConnected}',
    );
    notifyListeners();
  }

  void setBraceletConnected(bool isConnected) {
    _braceletData = _braceletData.copyWith(isConnected: isConnected);
    AppLogger.providerStateChange(
      'AppState',
      'Bracelet connection: $isConnected',
    );
    notifyListeners();
  }

  // ========== LOCATION STATE MANAGEMENT ==========
  void updateLocation(double latitude, double longitude, {String? address}) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _currentAddress = address;
    AppLogger.providerStateChange(
      'AppState',
      'Location updated: $latitude, $longitude, address: $address',
    );
    notifyListeners();
  }

  void clearLocation() {
    _currentLatitude = null;
    _currentLongitude = null;
    _currentAddress = null;
    notifyListeners();
  }

  // ========== SETTINGS MANAGEMENT ==========
  void setStealthModeActive(bool active) {
    _isStealthModeActive = active;
    AppLogger.providerStateChange('AppState', 'Stealth mode: $active');
    notifyListeners();
  }

  void setJourneyModeActive(bool active) {
    _isJourneyModeActive = active;
    AppLogger.providerStateChange('AppState', 'Journey mode: $active');
    notifyListeners();
  }

  void setVoiceTriggerEnabled(bool enabled) {
    _isVoiceTriggerEnabled = enabled;
    AppLogger.providerStateChange('AppState', 'Voice trigger: $enabled');
    notifyListeners();
  }

  void setAudioTriggerEnabled(bool enabled) {
    _isAudioTriggerEnabled = enabled;
    AppLogger.providerStateChange('AppState', 'Audio trigger: $enabled');
    notifyListeners();
  }

  void toggleThemeMode() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    AppLogger.providerStateChange('AppState', 'Theme mode: $_themeMode');
    notifyListeners();
  }

  // ========== RESET STATE ==========
  void reset() {
    _currentUser = null;
    _emergencyContacts = [];
    _sosState = SosState.idle;
    _sosTriggeredAt = null;
    _braceletData = BraceletModel.disconnected();
    _currentLatitude = null;
    _currentLongitude = null;
    _currentAddress = null;
    _isStealthModeActive = false;
    _isJourneyModeActive = false;
    _isVoiceTriggerEnabled = false;
    _isAudioTriggerEnabled = false;
    AppLogger.providerStateChange('AppState', 'All state reset');
    notifyListeners();
  }

  @override
  String toString() {
    return 'AppState(user: ${_currentUser?.email}, sosState: $_sosState, '
        'contacts: ${_emergencyContacts.length}, bracelet: ${_braceletData.isConnected})';
  }
}
