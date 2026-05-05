import '../core/utils/logger.dart';
import '../models/contact_model.dart';
import '../services/bluetooth_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';

/// Small debug harness for verifying critical SOS building blocks.
///
/// These helpers are intentionally lightweight and can be wired to a debug
/// screen, command, or developer menu.
class SosTestHarness {
  static Future<void> testGpsFetch() async {
    AppLogger.step('GPS', 'TEST', 'Starting GPS fetch test');
    try {
      final position = await LocationService().getCurrentLocationWithFallback();
      if (position == null) {
        AppLogger.w('GPS test failed: no location available');
        return;
      }
      AppLogger.step('GPS', 'TEST', 'GPS test success: ${position.latitude}, ${position.longitude}');
    } catch (e, st) {
      AppLogger.taggedError('GPS', 'GPS test failed', e, st);
    }
  }

  static Future<void> testSmsSending(List<ContactModel> contacts, double lat, double lng) async {
    AppLogger.step('SMS', 'TEST', 'Starting SMS test');
    try {
      await SmsService().sendEmergencySMS(contacts, lat, lng);
      AppLogger.step('SMS', 'TEST', 'SMS test completed');
    } catch (e, st) {
      AppLogger.taggedError('SMS', 'SMS test failed', e, st);
    }
  }

  static Future<void> testBluetoothTrigger() async {
    AppLogger.step('BT', 'TEST', 'Starting Bluetooth trigger test');
    try {
      final service = BluetoothService();
      final connected = service.isConnected;
      AppLogger.step('BT', 'TEST', 'Bluetooth connected: $connected');
      if (connected) {
        await service.sendData('PING');
      }
    } catch (e, st) {
      AppLogger.taggedError('BT', 'Bluetooth test failed', e, st);
    }
  }
}
