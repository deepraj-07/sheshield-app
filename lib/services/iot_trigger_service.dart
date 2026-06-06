import '../core/utils/logger.dart';

/// IotTriggerService — modular placeholder hooks for IoT device activation.
///
/// These are stub implementations ready for native platform channel integration.
/// Each method logs the intent and can be wired to:
///   - Raspberry Pi via Firebase RTDB (already done via StealthModeService RTDB writes)
///   - ESP32/BLE via flutter_bluetooth_serial
///   - Wearable via custom BLE protocol
///
/// For power-button trigger support, add a MethodChannel here and implement
/// the corresponding Android BroadcastReceiver in MainActivity.kt.
class IotTriggerService {
  static final IotTriggerService _instance = IotTriggerService._internal();
  factory IotTriggerService() => _instance;
  IotTriggerService._internal();

  // ── Stealth mode hooks ─────────────────────────────────────────────────────

  /// Called when stealth emergency mode activates.
  /// RPi already reacts via RTDB `current_status.is_alert = true`.
  /// This method handles BLE/wearable side-channel triggers.
  Future<void> activateStealthMode({required String sessionId}) async {
    AppLogger.i(
        'IotTriggerService: activateStealthMode — sessionId=$sessionId');

    // TODO: Raspberry Pi — already handled via RTDB in StealthModeService
    await _activateRaspberryPi(sessionId: sessionId);

    // TODO: ESP32/BLE wearable trigger
    await _activateEsp32(sessionId: sessionId);

    // TODO: Wearable vibration alert
    await _alertWearable();
  }

  /// Called when stealth emergency mode deactivates.
  Future<void> deactivateStealthMode() async {
    AppLogger.i('IotTriggerService: deactivateStealthMode');
    await _deactivateRaspberryPi();
    await _deactivateEsp32();
  }

  // ── Raspberry Pi ───────────────────────────────────────────────────────────

  /// RPi activation — primary channel is RTDB (already written by StealthModeService).
  /// This placeholder is for any additional RPi-specific commands.
  Future<void> _activateRaspberryPi({required String sessionId}) async {
    // RTDB write already done in StealthModeService._writeRtdbStealthAlert()
    // Add RPi-specific HTTP endpoint call here if needed:
    // await http.post(Uri.parse('http://rpi-local-ip/stealth'), body: {'session': sessionId});
    AppLogger.d('IotTriggerService: RPi activation via RTDB — done');
  }

  Future<void> _deactivateRaspberryPi() async {
    // RTDB clear already done in StealthModeService._clearRtdbStealthAlert()
    AppLogger.d('IotTriggerService: RPi deactivation via RTDB — done');
  }

  // ── ESP32 / BLE ────────────────────────────────────────────────────────────

  /// ESP32 BLE activation placeholder.
  /// Wire to flutter_bluetooth_serial or a custom BLE plugin.
  Future<void> _activateEsp32({required String sessionId}) async {
    // TODO: Connect to ESP32 via BLE and send activation command
    // Example:
    // final bt = BluetoothService();
    // await bt.sendCommand('STEALTH_ON:$sessionId');
    AppLogger.d(
        'IotTriggerService: ESP32 activation — placeholder (not yet wired)');
  }

  Future<void> _deactivateEsp32() async {
    // TODO: Send deactivation command to ESP32
    AppLogger.d('IotTriggerService: ESP32 deactivation — placeholder');
  }

  // ── Wearable ───────────────────────────────────────────────────────────────

  /// Wearable vibration/LED alert placeholder.
  Future<void> _alertWearable() async {
    // TODO: Send vibration pattern to wearable via BLE
    // The existing BluetoothService.vibrateBracelet() can be called here
    AppLogger.d('IotTriggerService: wearable alert — placeholder');
  }

  // ── Power button trigger (future) ─────────────────────────────────────────

  /// Scaffold for power-button trigger support.
  /// To implement:
  ///   1. Add a MethodChannel in MainActivity.kt
  ///   2. Register a BroadcastReceiver for ACTION_SCREEN_OFF (5 presses = trigger)
  ///   3. Call this method from the platform channel callback
  ///
  /// This method is intentionally a no-op until native code is added.
  Future<void> onPowerButtonTrigger() async {
    AppLogger.i(
        'IotTriggerService: power button trigger received — activating stealth');
    // StealthModeService().activate(triggerSource: 'power_button');
    // ↑ Uncomment when native power-button detection is implemented
  }
}
