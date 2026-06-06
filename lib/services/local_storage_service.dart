import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists contacts and settings to SharedPreferences.
/// All methods are static for easy access without DI.
class LocalStorageService {
  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kContacts = 'emergency_contacts_v1';
  static const _kSettingVoice = 'setting_sos_voice';
  static const _kSettingAudio = 'setting_ai_audio';
  static const _kSettingVideo = 'setting_auto_video';
  static const _kSettingJourney = 'setting_journey_alerts';
  static const _kSettingStealth = 'setting_stealth_mode';
  static const _kSettingBiometric = 'setting_biometric_login';
  static const _kThemeMode = 'setting_theme_mode'; // 'light' | 'dark'

  // ── Medical info keys ─────────────────────────────────────────────────────
  static const _kMedicalBloodGroup = 'medical_blood_group';
  static const _kMedicalAllergies = 'medical_allergies';
  static const _kMedicalConditions = 'medical_conditions';
  static const _kMedicalDoctorName = 'medical_doctor_name';
  static const _kMedicalDoctorPhone = 'medical_doctor_phone';

  // ── Profile keys ──────────────────────────────────────────────────────────
  static const _kProfileDisplayName = 'profile_display_name';

  // ── Stealth mode ──────────────────────────────────────────────────────────
  static const _kStealthTapCount = 'stealth_tap_count';

  // ── Contacts ──────────────────────────────────────────────────────────────

  /// Save the full contacts list as a JSON array.
  static Future<void> saveContacts(List<StoredContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_kContacts, encoded);
  }

  /// Load contacts. Returns empty list if nothing saved yet.
  static Future<List<StoredContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kContacts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StoredContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<void> saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      sosVoiceCommands: prefs.getBool(_kSettingVoice) ?? false,
      aiAudioDetection: prefs.getBool(_kSettingAudio) ?? false,
      autoVideoRecord: prefs.getBool(_kSettingVideo) ?? false,
      journeyModeAlerts: prefs.getBool(_kSettingJourney) ?? false,
      stealthMode: prefs.getBool(_kSettingStealth) ?? false,
      biometricLogin: prefs.getBool(_kSettingBiometric) ?? false,
      isDarkMode: prefs.getString(_kThemeMode) == 'dark',
    );
  }

  static Future<void> saveVoiceCommands(bool v) =>
      saveSetting(_kSettingVoice, v);
  static Future<void> saveAiAudio(bool v) => saveSetting(_kSettingAudio, v);
  static Future<void> saveAutoVideo(bool v) => saveSetting(_kSettingVideo, v);
  static Future<void> saveJourneyAlerts(bool v) =>
      saveSetting(_kSettingJourney, v);
  static Future<void> saveStealthMode(bool v) =>
      saveSetting(_kSettingStealth, v);
  static Future<void> saveBiometricLogin(bool v) =>
      saveSetting(_kSettingBiometric, v);

  static Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, isDark ? 'dark' : 'light');
  }

  // ── Medical info ──────────────────────────────────────────────────────────

  static Future<void> saveMedicalInfo({
    required String bloodGroup,
    required List<String> allergies,
    required List<String> conditions,
    required String doctorName,
    required String doctorPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMedicalBloodGroup, bloodGroup);
    await prefs.setString(_kMedicalAllergies, allergies.join(','));
    await prefs.setString(_kMedicalConditions, conditions.join(','));
    await prefs.setString(_kMedicalDoctorName, doctorName);
    await prefs.setString(_kMedicalDoctorPhone, doctorPhone);
  }

  static Future<Map<String, dynamic>> loadMedicalInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final allergiesRaw = prefs.getString(_kMedicalAllergies) ?? '';
    final conditionsRaw = prefs.getString(_kMedicalConditions) ?? '';
    return {
      'bloodGroup': prefs.getString(_kMedicalBloodGroup) ?? '',
      'allergies': allergiesRaw.isEmpty
          ? <String>[]
          : allergiesRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      'conditions': conditionsRaw.isEmpty
          ? <String>[]
          : conditionsRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      'doctorName': prefs.getString(_kMedicalDoctorName) ?? '',
      'doctorPhone': prefs.getString(_kMedicalDoctorPhone) ?? '',
    };
  }

  // ── Profile name ──────────────────────────────────────────────────────────

  static Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileDisplayName, name);
  }

  static Future<String?> loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kProfileDisplayName);
  }

  // ── Stealth tap count ─────────────────────────────────────────────────────

  static Future<void> saveStealthTapCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStealthTapCount, count);
  }

  static Future<int> loadStealthTapCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStealthTapCount) ?? 3;
  }
}

// ── Simple contact model for local storage ────────────────────────────────────

class StoredContact {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final String email; // Optional — used for email alerts
  final int colorValue; // Color.value int

  StoredContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    this.email = '',
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'phone': phone,
        'email': email,
        'colorValue': colorValue,
      };

  factory StoredContact.fromJson(Map<String, dynamic> j) => StoredContact(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        relation: j['relation'] as String? ?? 'Contact',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        colorValue: j['colorValue'] as int? ?? 0xFF7C3AED,
      );
}

// ── Settings snapshot ─────────────────────────────────────────────────────────

class AppSettings {
  final bool sosVoiceCommands;
  final bool aiAudioDetection;
  final bool autoVideoRecord;
  final bool journeyModeAlerts;
  final bool stealthMode;
  final bool biometricLogin;
  final bool isDarkMode;

  const AppSettings({
    required this.sosVoiceCommands,
    required this.aiAudioDetection,
    required this.autoVideoRecord,
    required this.journeyModeAlerts,
    required this.stealthMode,
    required this.biometricLogin,
    required this.isDarkMode,
  });
}
