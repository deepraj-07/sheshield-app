import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../core/utils/logger.dart';
import '../core/constants/app_constants.dart';

/// BluetoothService handles all Bluetooth operations with ESP32 bracelet.
/// Singleton pattern — persistent connection across entire app lifetime.
/// CRITICAL: Do NOT disconnect on navigation — only explicit user action.
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  // ========== STATE ==========
  BluetoothConnection? _connection;
  String? _deviceAddress;
  String? _deviceName;
  bool _isConnected = false;
  bool _isScanning = false;

  // ========== STREAMS ==========
  final _dataStreamController = StreamController<String>.broadcast();
  late Stream<String> _dataStream;

  final _connectionStateController = StreamController<bool>.broadcast();
  late Stream<bool> _connectionStateStream;

  // ========== BUFFERS ==========
  String _receiveBuffer = '';

  // ========== GETTERS ==========
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String? get deviceAddress => _deviceAddress;
  String? get deviceName => _deviceName;
  Stream<String> get dataStream => _dataStream;
  Stream<bool> get connectionStateStream => _connectionStateStream;

  // ========== INITIALIZATION ==========
  void _setupStreams() {
    _dataStream = _dataStreamController.stream;
    _connectionStateStream = _connectionStateController.stream;
  }

  /// Initialize Bluetooth service on app startup
  Future<bool> initialize() async {
    try {
      _setupStreams();

      // Check if Bluetooth is enabled
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        AppLogger.w('Bluetooth is disabled');
        return false;
      }

      AppLogger.serviceEvent('BluetoothService', 'Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('BluetoothService initialization error', e, stackTrace);
      return false;
    }
  }

  // ========== SCANNING & DISCOVERY ==========
  /// Scan for available Bluetooth devices
  /// Returns list of paired/discovered devices
  Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      _isScanning = true;
      AppLogger.i('Starting Bluetooth device scan...');

      // Get bonded devices
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();

      final sheShieldDevices = devices
          .where((device) =>
              device.name?.contains(AppConstants.bluetoothDeviceName) ?? false)
          .toList();

      AppLogger.i(
        'Found ${devices.length} bonded devices, '
        '${sheShieldDevices.length} SheShield devices',
      );

      _isScanning = false;
      return devices;
    } catch (e, stackTrace) {
      AppLogger.e('Error scanning Bluetooth devices', e, stackTrace);
      _isScanning = false;
      return [];
    }
  }

  // ========== CONNECTION MANAGEMENT ==========
  /// Connect to a Bluetooth device
  /// Returns true on success
  Future<bool> connectToDevice(String address, String name) async {
    try {
      // Disconnect existing connection if any
      if (_isConnected) {
        await disconnect();
      }

      AppLogger.serviceEvent('BluetoothService', 'Connecting to $name ($address)');

      _connection = await BluetoothConnection.toAddress(address);

      if (_connection == null) {
        AppLogger.e('Connection returned null');
        return false;
      }

      _isConnected = true;
      _deviceAddress = address;
      _deviceName = name;

      // Emit connection state
      _connectionStateController.add(true);

      AppLogger.serviceEvent('BluetoothService', 'Connected to $name');

      // Start listening to incoming data
      _listenToData();

      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error connecting to Bluetooth device', e, stackTrace);
      _isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
  }

  /// Disconnect from Bluetooth device
  /// ONLY call this on explicit user action (e.g., "Disconnect" button)
  Future<bool> disconnect() async {
    try {
      if (_connection != null) {
        await _connection!.finish();
        _connection = null;
      }

      _isConnected = false;
      _deviceAddress = null;
      _deviceName = null;
      _receiveBuffer = '';

      // Emit connection state
      _connectionStateController.add(false);

      AppLogger.serviceEvent('BluetoothService', 'Disconnected');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error disconnecting', e, stackTrace);
      return false;
    }
  }

  // ========== DATA COMMUNICATION ==========
  /// Listen to incoming data from ESP32
  void _listenToData() {
    if (_connection == null) return;

    _connection!.input?.listen(
      (data) {
        // Append to buffer
        _receiveBuffer += String.fromCharCodes(data);

        // Check for complete messages (newline-terminated)
        while (_receiveBuffer.contains('\n')) {
          final newlineIndex = _receiveBuffer.indexOf('\n');
          final message = _receiveBuffer.substring(0, newlineIndex).trim();
          _receiveBuffer = _receiveBuffer.substring(newlineIndex + 1);

          if (message.isNotEmpty) {
            AppLogger.d('[ESP32 RX] $message');
            _dataStreamController.add(message);
            _handleIncomingData(message);
          }
        }
      },
      onError: (error) {
        AppLogger.e('Bluetooth connection error', error);
        _isConnected = false;
        _connectionStateController.add(false);
        // Attempt auto-reconnect
        _startAutoReconnect();
      },
      onDone: () {
        AppLogger.i('Bluetooth connection closed by device');
        _isConnected = false;
        _connectionStateController.add(false);
        // Attempt auto-reconnect
        _startAutoReconnect();
      },
    );
  }

  /// Send data to ESP32
  /// Automatically appends newline
  Future<bool> sendData(String command) async {
    try {
      if (!_isConnected || _connection == null) {
        AppLogger.w('Cannot send: Bluetooth not connected');
        return false;
      }

      final commandWithNewline = command.endsWith('\n') ? command : '$command\n';
      _connection!.output.add(Uint8List.fromList(commandWithNewline.codeUnits));

      AppLogger.d('[ESP32 TX] $command');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error sending Bluetooth data', e, stackTrace);
      return false;
    }
  }

  /// Handle incoming commands from ESP32
  /// Routes commands to appropriate handlers
  void _handleIncomingData(String message) {
    final command = message.trim().toUpperCase();

    // Parse different command types
    if (command == 'SOS') {
      AppLogger.sosStep(0, 'SOS triggered from bracelet button');
      // Invoke registered callback if available
      try {
        _onSosCallback?.call();
      } catch (e, st) {
        AppLogger.e('Error invoking onSos callback', e, st);
      }
    } else if (command == 'SHAKE') {
      AppLogger.i('Shake detected from bracelet');
      // Could trigger SOS or custom action
    } else if (command.startsWith('HR_DATA:')) {
      final bpmStr = command.replaceFirst('HR_DATA:', '').trim();
      final bpm = int.tryParse(bpmStr) ?? 0;
      AppLogger.d('Heart rate received: $bpm BPM');
      // Update bracelet_provider with BPM data
    } else if (command.startsWith('BATTERY:')) {
      final batteryStr = command.replaceFirst('BATTERY:', '').trim();
      final battery = int.tryParse(batteryStr) ?? 0;
      AppLogger.d('Battery level received: $battery%');
      // Update bracelet_provider with battery data
    } else if (command == 'STEALTH') {
      AppLogger.i('Stealth mode activated from bracelet');
      // Trigger stealth mode UI
    } else {
      AppLogger.d('Unknown command from ESP32: $message');
    }
  }

  VoidCallback? _onSosCallback;

  /// Register a callback to be invoked when bracelet triggers SOS.
  void registerOnSosCallback(VoidCallback cb) {
    _onSosCallback = cb;
  }

  /// Unregister the SOS callback.
  void unregisterOnSosCallback() {
    _onSosCallback = null;
  }

  Timer? _reconnectTimer;

  void _startAutoReconnect() {
    try {
      if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
      if (_deviceAddress == null) return;

      int attempt = 0;
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        attempt += 1;
        if (_isConnected) {
          timer.cancel();
          return;
        }

        AppLogger.i('BluetoothService: Auto-reconnect attempt #$attempt to $_deviceAddress');
        final success = await connectToDevice(_deviceAddress!, _deviceName ?? 'SheShield');
        if (success) {
          AppLogger.i('BluetoothService: Auto-reconnect successful');
          timer.cancel();
        }

        // Give up after 12 attempts (~1 minute)
        if (attempt >= 12) {
          AppLogger.w('BluetoothService: Auto-reconnect giving up after $attempt attempts');
          timer.cancel();
        }
      });
    } catch (e, st) {
      AppLogger.e('BluetoothService: Auto-reconnect failed to start', e, st);
    }
  }

  // ========== COMMAND HELPERS ==========
  /// Send vibration command to bracelet
  Future<bool> vibrateBracelet() async {
    return sendData('VIBRATE_SOS');
  }

  /// Send LED on command
  Future<bool> ledOn() async {
    return sendData('LED_ON');
  }

  /// Send LED off command
  Future<bool> ledOff() async {
    return sendData('LED_OFF');
  }

  /// Send buzzer on command
  Future<bool> buzzerOn() async {
    return sendData('BUZZER_ON');
  }

  /// Send buzzer off command
  Future<bool> buzzerOff() async {
    return sendData('BUZZER_OFF');
  }

  /// Request immediate BPM data from ESP32
  Future<bool> requestHeartRateData() async {
    return sendData('GET_HR');
  }

  /// Request battery level from ESP32
  Future<bool> requestBatteryLevel() async {
    return sendData('GET_BATTERY');
  }

  // ========== CLEANUP ==========
  void dispose() {
    _dataStreamController.close();
    _connectionStateController.close();
    disconnect();
  }

  @override
  String toString() =>
      'BluetoothService(connected: $_isConnected, device: $_deviceName)';
}
