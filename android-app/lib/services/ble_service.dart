import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:battery_plus/battery_plus.dart';

const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String SETTINGS_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String STATUS_CHAR_UUID = "8b11b57c-ed1a-466d-8e42-99a341f22e70";

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  final Battery _battery = Battery();
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? _settingsChar;
  BluetoothCharacteristic? _statusChar;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool isConnected = false;

  bool _savingMode = false;
  int _minThreshold = 20;
  int _maxThreshold = 80;

  void init() {
    _battery.onBatteryStateChanged.listen((_) async {
      if (isConnected) await _push();
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    await device.connect();
    connectedDevice = device;

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
        for (var char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == SETTINGS_CHAR_UUID.toLowerCase()) {
            _settingsChar = char;
          }
          if (uuid == STATUS_CHAR_UUID.toLowerCase()) {
            _statusChar = char;
            _startListening(char);
          }
        }
      }
    }
    isConnected = true;
    _connectionController.add(true);
    await _push(); // push current settings right after connecting
  }

  void _startListening(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    char.onValueReceived.listen((value) {
      String data = utf8.decode(value);
      List<String> parts = data.split(':');
      if (parts.length >= 3) {
        final Map<String, dynamic> status = {
          'battery': int.tryParse(parts[0]) ?? 0,
          'temp': double.tryParse(parts[1]) ?? 0.0,
          'current': int.tryParse(parts[2]) ?? 0,
        };
        if (parts.length >= 4) {
          status['relayOn'] = parts[3].trim() == '1';
        }
        _statusController.add(status);
      }
    });
  }

  Future<void> _push() async {
    if (_settingsChar == null || !isConnected) return;
    final level = await _battery.batteryLevel;
    final payload = "${_savingMode ? "1" : "0"}:$_minThreshold:$_maxThreshold:$level";
    await _settingsChar!.write(utf8.encode(payload));
  }

  /// Update settings and immediately push them to the ESP.
  /// Pass only the fields that changed; the rest keep their last value.
  Future<void> updateSettings({bool? savingMode, int? min, int? max}) async {
    if (savingMode != null) _savingMode = savingMode;
    if (min != null) _minThreshold = min;
    if (max != null) _maxThreshold = max;
    await _push();
  }

  Future<void> syncSettings(bool savingMode, int min, int max, int phoneBat) async {
    _savingMode = savingMode;
    _minThreshold = min;
    _maxThreshold = max;
    await _push();
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    isConnected = false;
    _connectionController.add(false);
  }
}