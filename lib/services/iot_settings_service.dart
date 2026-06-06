import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/utils/logger.dart';

/// Writes app-controlled settings to RTDB so the Raspberry Pi can read them.
///
/// RTDB path: `app_settings/`
/// {
///   "voice_trigger_enabled": true,
///   "audio_detection_enabled": false,
///   "auto_video_enabled": true,
///   "updated_at": 1234567890
/// }
///
/// The RPi polls / listens to this node and enables/disables features accordingly.
class IotSettingsService {
  static const _rtdbUrl =
      'https://sheshield-bd387-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const _path = 'app_settings';

  static DatabaseReference? _ref;

  static DatabaseReference _getRef() {
    _ref ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _rtdbUrl,
    ).ref(_path);
    return _ref!;
  }

  /// Write a single boolean setting to RTDB.
  static Future<void> writeSetting(String key, bool value) async {
    try {
      await _getRef().update({
        key: value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      AppLogger.i('IotSettings: $key = $value written to RTDB');
    } catch (e, st) {
      AppLogger.taggedError('IotSettings', 'Failed to write $key', e, st);
    }
  }

  static Future<void> setVoiceTrigger(bool enabled) =>
      writeSetting('voice_trigger_enabled', enabled);

  static Future<void> setAudioDetection(bool enabled) =>
      writeSetting('audio_detection_enabled', enabled);

  static Future<void> setAutoVideo(bool enabled) =>
      writeSetting('auto_video_enabled', enabled);

  /// Push all current settings to RTDB at once (call on app startup).
  static Future<void> syncAll({
    required bool voiceTrigger,
    required bool audioDetection,
    required bool autoVideo,
  }) async {
    try {
      await _getRef().update({
        'voice_trigger_enabled': voiceTrigger,
        'audio_detection_enabled': audioDetection,
        'auto_video_enabled': autoVideo,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      AppLogger.i('IotSettings: full sync written to RTDB');
    } catch (e, st) {
      AppLogger.taggedError('IotSettings', 'Full sync failed', e, st);
    }
  }
}
