import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../models/user_profile.dart';

class PhonePage extends StatefulWidget {
  final String username;
  final UserProfile profile;
  final Function(UserProfile) onUpdateProfile;

  const PhonePage({
    super.key,
    required this.username,
    required this.profile,
    required this.onUpdateProfile,
  });

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage>
    with SingleTickerProviderStateMixin {
  final Battery _battery = Battery();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  String _deviceName = 'Loading...';
  String _deviceModel = 'Loading...';
  String _deviceType = 'Loading...';

  // State synced with widget.profile
  late bool _savingMode;
  late int _minThreshold;
  late int _maxThreshold;

  late AnimationController _animController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _savingMode = widget.profile.savingMode;
    _minThreshold = widget.profile.minThreshold;
    _maxThreshold = widget.profile.maxThreshold;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fillAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _initBattery();
    _getDeviceInfo();

    _battery.onBatteryStateChanged.listen((state) {
      if (mounted) setState(() => _batteryState = state);
    });
  }

  @override
  void didUpdateWidget(PhonePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      setState(() {
        _savingMode = widget.profile.savingMode;
        _minThreshold = widget.profile.minThreshold;
        _maxThreshold = widget.profile.maxThreshold;
      });
    }
  }

  void _syncProfile() {
    final updatedProfile = UserProfile(
      name: widget.profile.name,
      surname: widget.profile.surname,
      email: widget.profile.email,
      phone: widget.profile.phone,
      savingMode: _savingMode,
      minThreshold: _minThreshold,
      maxThreshold: _maxThreshold,
    );
    widget.onUpdateProfile(updatedProfile);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _batteryState = state;
        });
        _fillAnimation = Tween<double>(
          begin: _fillAnimation.value,
          end: level / 100,
        ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
        _animController
          ..reset()
          ..forward();
      }
    } catch (e) {
      debugPrint("Battery error: $e");
    }
  }

  Future<void> _getDeviceInfo() async {
    String name = 'Unknown', model = 'Unknown', type = 'Unknown';
    try {
      if (kIsWeb) {
        final w = await _deviceInfoPlugin.webBrowserInfo;
        name = w.browserName.toString();
        model = w.userAgent ?? 'Web';
        type = 'Web';
      } else if (Platform.isAndroid) {
        final a = await _deviceInfoPlugin.androidInfo;
        name = a.brand;
        model = a.model;
        type = 'Android';
      } else if (Platform.isIOS) {
        final i = await _deviceInfoPlugin.iosInfo;
        name = i.name;
        model = i.model;
        type = 'iOS';
      } else if (Platform.isWindows) {
        final win = await _deviceInfoPlugin.windowsInfo;
        name = win.computerName;
        model = 'Windows PC';
        type = 'PC';
      } else if (Platform.isMacOS) {
        final mac = await _deviceInfoPlugin.macOsInfo;
        name = mac.computerName;
        model = mac.model;
        type = 'macOS';
      } else if (Platform.isLinux) {
        final lx = await _deviceInfoPlugin.linuxInfo;
        name = lx.name;
        model = 'Linux PC';
        type = 'PC';
      }
    } catch (e) {
      debugPrint("Device info error: $e");
    }
    if (mounted) {
      setState(() {
        _deviceName = name;
        _deviceModel = model;
        _deviceType = type;
      });
    }
  }

  Color _batteryColor(int level) {
    if (level >= 60) return const Color(0xFF00C897);
    if (level >= 40) return const Color(0xFF3DA9FF);
    if (level >= 20) return const Color(0xFFFF9A3C);
    return const Color(0xFFFF4C4C);
  }

  String _chargingLabel() {
    switch (_batteryState) {
      case BatteryState.charging: return 'Charging';
      case BatteryState.discharging: return 'Discharging';
      case BatteryState.full: return 'Full';
      default: return 'Unknown';
    }
  }

  IconData _chargingIcon() {
    switch (_batteryState) {
      case BatteryState.charging: return Icons.bolt;
      case BatteryState.full: return Icons.battery_full;
      default: return Icons.battery_std;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _batteryColor(_batteryLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDeviceCard(),
          const SizedBox(height: 20),
          _buildBatteryCard(color),
          const SizedBox(height: 20),
          _buildChargingStatus(color),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () { _initBattery(); _getDeviceInfo(); },
            icon: const Icon(Icons.refresh, color: Colors.teal),
            label: const Text('Refresh', style: TextStyle(color: Colors.teal)),
          ),
          const SizedBox(height: 20),
          _buildSavingModeCard(),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.phone_android, color: Colors.teal, size: 32),
          ),
          const SizedBox(width: 16),
          const Text('Device Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _miniInfoRow('Type', _deviceType),
                _miniInfoRow('Brand', _deviceName),
                _miniInfoRow('Model', _deviceModel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(120, 200),
                painter: _BatteryPainter(
                  fillPercent: _fillAnimation.value,
                  color: color,
                  isCharging: _batteryState == BatteryState.charging,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              final displayLevel = (_fillAnimation.value * 100).round();
              return Text('$displayLevel%', style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: color, letterSpacing: -2));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChargingStatus(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(_chargingIcon(), color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_chargingLabel(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingModeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _savingMode ? Colors.teal.withOpacity(0.6) : Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.energy_savings_leaf, color: _savingMode ? Colors.teal : Colors.white38, size: 24),
                  const SizedBox(width: 12),
                  Text('Saving Mode', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _savingMode ? Colors.teal : Colors.white70)),
                ],
              ),
              Switch(
                value: _savingMode,
                onChanged: (v) {
                  setState(() => _savingMode = v);
                  _syncProfile();
                },
                activeColor: Colors.teal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _savingMode ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_savingMode,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Charge Thresholds', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  const Text('Set the min/max battery levels for the charger', style: TextStyle(fontSize: 12, color: Colors.white38)),
                  const SizedBox(height: 24),
                  _buildThresholdSlider(
                    label: 'Min Threshold',
                    value: _minThreshold,
                    color: const Color(0xFFFF4C4C),
                    icon: Icons.battery_1_bar,
                    onChanged: (v) {
                      if (v < _maxThreshold) {
                        setState(() => _minThreshold = v);
                        _syncProfile();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildThresholdSlider(
                    label: 'Max Threshold',
                    value: _maxThreshold,
                    color: const Color(0xFF00C897),
                    icon: Icons.battery_full,
                    onChanged: (v) {
                      if (v > _minThreshold) {
                        setState(() => _maxThreshold = v);
                        _syncProfile();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdSlider({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double fillPercent;
  final Color color;
  final bool isCharging;

  _BatteryPainter({required this.fillPercent, required this.color, required this.isCharging});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, r = 12.0, tipH = 12.0, tipW = w * 0.35, bodyTop = tipH, bodyH = h - tipH;
    final borderPaint = Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 3;
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final bgPaint = Paint()..color = color.withOpacity(0.08)..style = PaintingStyle.fill;
    final tipLeft = (w - tipW) / 2;
    final tipRect = RRect.fromRectAndRadius(Rect.fromLTWH(tipLeft, 0, tipW, tipH + r), const Radius.circular(4));
    canvas.drawRRect(tipRect, borderPaint);
    final bodyRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, bodyTop, w, bodyH), Radius.circular(r));
    canvas.drawRRect(bodyRect, bgPaint);
    canvas.drawRRect(bodyRect, borderPaint);
    final fillH = (bodyH - 6) * fillPercent;
    final fillTop = bodyTop + (bodyH - 6) - fillH + 3;
    final fillRect = RRect.fromRectAndCorners(Rect.fromLTWH(3, fillTop, w - 6, fillH), bottomLeft: Radius.circular(r - 2), bottomRight: Radius.circular(r - 2), topLeft: fillPercent >= 0.99 ? Radius.circular(r - 2) : Radius.zero, topRight: fillPercent >= 0.99 ? Radius.circular(r - 2) : Radius.zero);
    canvas.drawRRect(fillRect, fillPaint);
    final glowPaint = Paint()..color = color.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(fillRect, glowPaint);
    if (isCharging) {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(text: String.fromCharCode(Icons.bolt.codePoint), style: TextStyle(fontSize: 40, fontFamily: Icons.bolt.fontFamily, color: Colors.white.withOpacity(0.9)));
      textPainter.layout();
      textPainter.paint(canvas, Offset((w - textPainter.width) / 2, bodyTop + (bodyH - textPainter.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.fillPercent != fillPercent || old.color != color || old.isCharging != isCharging;
}
