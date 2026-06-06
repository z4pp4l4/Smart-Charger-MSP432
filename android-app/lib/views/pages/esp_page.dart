import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user_profile.dart';
import '../../models/charging_data.dart';
import '../../models/notifications_model.dart';

// Match the 128-bit UUIDs from ESP32
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String SETTINGS_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String STATUS_CHAR_UUID = "8b11b57c-ed1a-466d-8e42-99a341f22e70";

class EspPage extends StatefulWidget {
  final UserProfile profile;
  final BatteryState batteryState;
  const EspPage({super.key, required this.profile, required this.batteryState});

  @override
  State<EspPage> createState() => _EspPageState();
}

class _EspPageState extends State<EspPage> {
  final Battery _battery = Battery();
  bool isConnected = false;
  bool isScanning = false;
  List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _statusSubscription;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _connectedDeviceTimer;
  Timer? _heartbeatTimer;
  bool _isConnecting = false;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? settingsCharacteristic;
  BluetoothCharacteristic? statusCharacteristic;

  // Phone Data
  int phoneBatteryLevel = 0;
  String? lastSyncPayload;

  // ESP32 Data (Live)
  int extBatteryLevel = 0;
  double voltage = 0.0;
  double current = 0.0;
  double power = 0.0;
  bool relayOn = false;

  // Charging History & Analytics
  late ChargingHistory chargingHistory;
  Timer? _dataCollectionTimer;

  // Smart Notifications
  late NotificationDetector notificationDetector;
  bool? _previousRelayState; // Null means unknown/initial state

  @override
  void initState() {
    super.initState();
    chargingHistory = ChargingHistory();
    notificationDetector = NotificationDetector();
    _initBattery();

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted && state != BluetoothAdapterState.on) {
        _cleanupConnection();
      }
    });

    _connectedDeviceTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!isConnected) _checkAlreadyConnectedDevices();
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (isConnected) _sendDataToESP32(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant EspPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batteryState != widget.batteryState) {
      if (isConnected) {
        _checkNotifications(relayOn);
      }
    }

    if (isConnected &&
        (oldWidget.profile.savingMode != widget.profile.savingMode ||
            oldWidget.profile.minThreshold != widget.profile.minThreshold ||
            oldWidget.profile.maxThreshold != widget.profile.maxThreshold)) {
      _sendDataToESP32(force: true);
    }
  }

  Future<void> _initBattery() async {
    final level = await _battery.batteryLevel;
    if (mounted) setState(() => phoneBatteryLevel = level);

    _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => phoneBatteryLevel = level);
        if (isConnected) _sendDataToESP32();
      }
    });
  }

  void _cleanupConnection() {
    if (!mounted) return;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;
    setState(() {
      isConnected = false;
      _isConnecting = false;
      connectedDevice = null;
      settingsCharacteristic = null;
      statusCharacteristic = null;
      relayOn = false;
      _previousRelayState = null;
    });
    chargingHistory.clear();
    lastSyncPayload = null;
  }

  Future<void> _checkAlreadyConnectedDevices() async {
    try {
      List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
      if (connected.isNotEmpty && mounted && !isConnected && !_isConnecting) {
        _connectToDevice(connected.first);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    _batterySubscription?.cancel();
    _connectedDeviceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _dataCollectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendDataToESP32({bool force = false}) async {
    if (settingsCharacteristic == null || !isConnected) return;
    try {
      // onBatteryStateChanged only fires on state transitions, not per-percent,
      // so re-read the live level here or the ESP acts on a stale %.
      final level = await _battery.batteryLevel;
      phoneBatteryLevel = level;

      final payload =
          "${widget.profile.savingMode ? "1" : "0"}:${widget.profile.minThreshold}:${widget.profile.maxThreshold}:$level";
      if (!force && payload == lastSyncPayload) return;

      await settingsCharacteristic!.write(utf8.encode(payload), withoutResponse: false);
      if (!mounted) return;
      setState(() => lastSyncPayload = payload);
      debugPrint("Sent Sync: $payload");
    } catch (e) {
      debugPrint("Send Error: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;
    try {
      await FlutterBluePlus.stopScan();
      final connectionState = await device.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        await device.connect(autoConnect: false, mtu: null);
      }
      if (!mounted) return;

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) _cleanupConnection();
      });

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            SERVICE_UUID.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() ==
                SETTINGS_CHAR_UUID.toLowerCase()) {
              settingsCharacteristic = char;
            }

            if (char.uuid.toString().toLowerCase() ==
                STATUS_CHAR_UUID.toLowerCase()) {
              statusCharacteristic = char;
              _listenToESP(char);
            }
          }
        }
      }

      if (settingsCharacteristic == null) {
        debugPrint("ERROR: settingsCharacteristic not found");
      }

      if (!mounted) return;
      setState(() {
        isConnected = true;
        _isConnecting = false;
        connectedDevice = device;
      });

      // Start collecting data for charts
      _dataCollectionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && isConnected && relayOn) {
          setState(() {
            chargingHistory.addDataPoint(
              voltage,
              current,
              power,
              extBatteryLevel,
            );
          });
        }
      });

      _sendDataToESP32(force: true);
    } catch (e) {
      _isConnecting = false;
      debugPrint("Conn Error: $e");
    }
  }

  void _listenToESP(BluetoothCharacteristic char) async {
    await _statusSubscription?.cancel();
    await char.setNotifyValue(true);
    _statusSubscription = char.onValueReceived.listen((value) {
      if (!mounted || value.isEmpty) return;

      try {
        String data = utf8.decode(value, allowMalformed: true).trim();
        List<String> parts = data.split(':');

        if (parts.length >= 5) {
          final newExtBatteryLevel = int.tryParse(parts[0]) ?? extBatteryLevel;
          final newVoltage = double.tryParse(parts[1]) ?? voltage;
          final newCurrent = double.tryParse(parts[2]) ?? current;
          final newPower = double.tryParse(parts[3]) ?? power;
          final newRelayState = parts[4].trim() == '1';

          setState(() {
            extBatteryLevel = newExtBatteryLevel;
            voltage = newVoltage;
            current = newCurrent;
            power = newPower;
            relayOn = newRelayState;
          });

          _checkNotifications(newRelayState);
        } else {
          debugPrint("Invalid ESP status packet: $data");
        }
      } catch (e) {
        debugPrint("Status Parse Error: $e");
      }
    });
  }

  void _checkNotifications(bool isCharging) {
    // Check charging completion
    final chargeCompleteNotif =
        notificationDetector.checkChargingComplete(extBatteryLevel, isCharging);
    if (chargeCompleteNotif != null) {
      _addNotification(chargeCompleteNotif);
    }

    // Check low battery
    final lowBatteryNotif =
        notificationDetector.checkLowBattery(extBatteryLevel, isCharging);
    if (lowBatteryNotif != null) {
      _addNotification(lowBatteryNotif);
    }

    // Check charging rate anomaly
    final anomalyNotif = notificationDetector.checkChargingRateAnomaly(
        chargingHistory.dataPoints, isCharging);
    if (anomalyNotif != null) {
      _addNotification(anomalyNotif);
    }

    // Check if charging just started
    final startedNotif = notificationDetector.checkChargingStarted(
        extBatteryLevel, isCharging, _previousRelayState);
    if (startedNotif != null) {
      _addNotification(startedNotif);
    }

    _previousRelayState = isCharging;
  }

  void _addNotification(SmartNotification notification) {
    NotificationManager().addNotification(notification);
    _showNotificationSnackbar(notification);
  }

  void _showNotificationSnackbar(SmartNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: notification.color.withOpacity(0.8),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleConnectPressed() async {
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth and Location permissions are required.")),
      );
      return;
    }
    _showScanDialog();
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  void _showScanDialog() {
  _startScan();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text("Search for BLE Devices", style: TextStyle(color: Colors.teal)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Bluetooth Status Banner (High Visibility - First Ground)
            StreamBuilder<BluetoothAdapterState>(
              stream: FlutterBluePlus.adapterState,
              initialData: BluetoothAdapterState.unknown,
              builder: (c, snapshot) {
                if (snapshot.data != BluetoothAdapterState.on) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.bluetooth_disabled, color: Colors.white, size: 24),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "Bluetooth is OFF. Please turn it on to scan.",
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 14, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            StreamBuilder<bool>(
              stream: FlutterBluePlus.isScanning,
              initialData: false,
              builder: (c, snapshot) {
                if (snapshot.data == true) {
                  return const LinearProgressIndicator(color: Colors.teal);
                } else {
                  return const SizedBox(height: 4);
                }
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.teal),
              title: const Text("Don't see your device?",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text("Open Bluetooth Settings",
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              onTap: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                initialData: const [],
                builder: (c, snapshot) {
                  final results = (snapshot.data ?? [])
                      .where((r) {
                        final name = (r.device.platformName +
                                r.advertisementData.localName)
                            .toLowerCase();
                        return name.contains("esp");
                      })
                      .toList()
                    ..sort((a, b) => b.rssi.compareTo(a.rssi));

                  if (results.isEmpty) {
                    return const Center(
                      child: Text("Searching for ESP devices…",
                          style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (c, i) {
                      final result = results[i];
                      final name = result.device.platformName.isEmpty
                          ? (result.advertisementData.localName.isEmpty
                              ? "Unknown Device"
                              : result.advertisementData.localName)
                          : result.device.platformName;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth, color: Colors.teal),
                        title: Text(name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(result.device.remoteId.toString(),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                        onTap: () {
                          _connectToDevice(result.device);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FlutterBluePlus.stopScan();
            Navigator.pop(context);
          },
          child: const Text("Close"),
        ),
        StreamBuilder<bool>(
          stream: FlutterBluePlus.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data == false) {
              return TextButton(
                onPressed: _startScan,
                child: const Text("Rescan", style: TextStyle(color: Colors.teal)),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ],
    ),
  );
}

Future<void> _startScan() async {
  final adapterState = await FlutterBluePlus.adapterState.first;
  if (adapterState != BluetoothAdapterState.on) {
    // Bluetooth check is now handled visually in the dialog banner
    return;
  }

  setState(() => scanResults.clear());
  try {
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          scanResults = results
              .where((r) {
                final name = (r.device.platformName +
                        r.advertisementData.localName)
                    .toLowerCase();
                return name.contains("esp");
              })
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }
    });

    if (await FlutterBluePlus.isScanning.first) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: true,
    );
  } catch (e) {
    debugPrint("Scan Error: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationManager(),
      builder: (context, _) {
        final history = NotificationManager().history;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (history.isNotEmpty) ...[
                _buildNotificationHistory(history),
                const SizedBox(height: 20),
              ],
              _buildCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("ESP32 Connection", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(
                            isConnected ? (connectedDevice?.platformName.isNotEmpty == true
                                ? connectedDevice!.platformName
                                : "ESP32 Device") : "Disconnected",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isConnected ? () => connectedDevice?.disconnect() : _handleConnectPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? Colors.red.withOpacity(0.2) : Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isConnected ? "Disconnect" : "Connect"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // --- App -> ESP32 Data ---
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync, color: Colors.teal, size: 20),
                        SizedBox(width: 8),
                        Text("Phone -> ESP32 Sync", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _syncItem("Saving Mode", widget.profile.savingMode ? "ON" : "OFF", widget.profile.savingMode ? Colors.orange : Colors.white54),
                        _syncItem("Phone Battery", "$phoneBatteryLevel%", Colors.green),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _syncItem("Min Threshold", widget.profile.savingMode ? "${widget.profile.minThreshold}%" : "0%", Colors.white),
                        _syncItem("Max Threshold", widget.profile.savingMode ? "${widget.profile.maxThreshold}%" : "100%", Colors.white),
                      ],
                    ),
                    if (lastSyncPayload != null) ...[
                      const Divider(color: Colors.white10, height: 20),
                      Text("Last Payload: $lastSyncPayload", style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !isConnected,
                  child: Column(
                    children: [
                      /*
                      _buildCard(
                        child: Column(
                          children: [
                            const Text("ESP32 External Battery", style: TextStyle(color: Colors.white54)),
                            const SizedBox(height: 10),
                            Text("$extBatteryLevel%", style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.teal)),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: extBatteryLevel / 100,
                              backgroundColor: Colors.white12,
                              color: Colors.teal,
                            )
                          ],
                        ),
                      ), */
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _infoCard(Icons.flash_on, "Current","${current.toStringAsFixed(1)} mA", Colors.blue)),
                          const SizedBox(width: 12),
                          Expanded(child: _infoCard(Icons.bolt, "Voltage", "${voltage.toStringAsFixed(2)} V", Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.electric_bolt,
                              "Power",
                              "${power.toStringAsFixed(1)} mW",
                              Colors.purple,
                            ),
                          ),
                          /*
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              relayOn ? Icons.power : Icons.power_off,
                              relayOn ? "Relay ON" : "Relay OFF",
                              relayOn ? "Charging" : "Stopped",
                              relayOn ? Colors.green : Colors.red,
                            ),
                          ),
                          */
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildEstimatedTimeCard(),
                      const SizedBox(height: 20),
                      _buildCard(child: _buildPowerChart()),
                      const SizedBox(height: 20),
                      _buildCard(child: _buildCurrentChart()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _syncItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: child,
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPowerChart() {
    if (chargingHistory.dataPoints.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No data collected yet", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final dataPoints = chargingHistory.dataPoints;
    final maxPower = dataPoints.fold(0.0, (max, p) => p.power > max ? p.power : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Power Over Time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxPower > 0 ? maxPower / 4 : 1,
              ),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    dataPoints.length,
                    (i) => FlSpot(i.toDouble(), dataPoints[i].power),
                  ),
                  isCurved: true,
                  color: Colors.purple,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                )
              ],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentChart() {
    if (chargingHistory.dataPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final dataPoints = chargingHistory.dataPoints;
    final maxCurrent = dataPoints.fold(0.0, (max, p) => p.current > max ? p.current : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Current Over Time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxCurrent > 0 ? maxCurrent / 4 : 1,
              ),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    dataPoints.length,
                    (i) => FlSpot(i.toDouble(), dataPoints[i].current),
                  ),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                )
              ],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    if (!minutes.isFinite || minutes.isNaN) return "N/A";
    if (minutes < 0) return "Calculating…";   // -1 from the estimator
    final m = minutes.round();
    final hours = m ~/ 60, mins = m % 60;
    return hours > 0 ? "$hours h ${mins}m" : "${mins}m";
  }

  Widget _buildEstimatedTimeCard() {
    final target = widget.profile.savingMode ? widget.profile.maxThreshold : 100;

    if (!relayOn || extBatteryLevel >= target) {
      return _buildCard(
        child: Column(
          children: [
            const Icon(Icons.timer, color: Colors.grey, size: 32),
            const SizedBox(height: 12),
            const Text("Not Charging", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            Text(
              extBatteryLevel >= target
                  ? (target >= 100 ? "Battery Full" : "Target Reached")
                  : "Battery Not Charging",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      );
    }

    final estimatedMinutes = chargingHistory.calculateEstimatedTimeToCharge(
      extBatteryLevel,
      targetBattery: target,        // ← the key fix
    );
    final timeString = _formatDuration(estimatedMinutes);

    return _buildCard(
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.orange, size: 32),
          const SizedBox(height: 12),
          Text(
            target >= 100 ? "Estimated Time to Full Charge" : "Estimated Time to Target",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            timeString,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          if (estimatedMinutes > 0) ...[
            const SizedBox(height: 8),
            Text(
              "From ${extBatteryLevel}% → $target%",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildNotificationHistory(List<SmartNotification> history) {
    // Show only the 3 most recent notifications in the small card
    final recentHistory = history.take(3).toList();

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              const Text(
                "Recent Alerts",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => NotificationManager().clearHistory(),
                child: const Text("Clear", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentHistory.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final notif = recentHistory[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(
                        color: notif.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.title,
                            style: TextStyle(
                              color: notif.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notif.message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(notif.timestamp),
                      style: const TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return "now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${diff.inDays}d ago";
    }
  }
}
