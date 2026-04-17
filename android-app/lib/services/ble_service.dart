import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:battery_plus/battery_plus.dart';

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

  void init() {
    _battery.onBatteryStateChanged.listen((_) async {
      final level = await _battery.batteryLevel;
      if (isConnected) syncSettings(false, 20, 80, level);
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    await device.connect();
    connectedDevice = device;
    
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().contains("1234")) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().contains("5678")) _settingsChar = char;
          if (char.uuid.toString().contains("9ABC")) {
            _statusChar = char;
            _startListening(char);
          }
        }
      }
    }
    isConnected = true;
    _connectionController.add(true);
  }

  void _startListening(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    char.onValueReceived.listen((value) {
      String data = utf8.decode(value);
      List<String> parts = data.split(':');
      if (parts.length == 3) {
        _statusController.add({
          'battery': int.tryParse(parts[0]) ?? 0,
          'temp': double.tryParse(parts[1]) ?? 0.0,
          'current': int.tryParse(parts[2]) ?? 0,
        });
      }
    });
  }

  Future<void> syncSettings(bool manual, int min, int max, int phoneBat) async {
    if (_settingsChar != null) {
      String payload = "${manual ? "1" : "0"}:$min:$max:$phoneBat";
      await _settingsChar!.write(utf8.encode(payload));
    }
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    isConnected = false;
    _connectionController.add(false);
  }
}
