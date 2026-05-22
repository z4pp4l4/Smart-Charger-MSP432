import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';

enum NotificationType {
  chargeComplete,
  lowBattery,
  chargingRateAnomaly,
  chargingStarted,
  phoneTargetReached,
}

class SmartNotification {
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Color color;

  SmartNotification({
    required this.type,
    required this.title,
    required this.message,
    required this.color,
  }) : timestamp = DateTime.now();
}

/// Global manager for notification history
class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final List<SmartNotification> _history = [];
  List<SmartNotification> get history => List.unmodifiable(_history);

  void addNotification(SmartNotification notification) {
    _history.insert(0, notification);
    if (_history.length > 50) {
      _history.removeLast();
    }
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}

class NotificationDetector {
  static const int lowBatteryThreshold = 15;
  static const double lowChargingRateThreshold = 0.2;
  static const int chargingAnomalyCheckPoints = 10;

  bool _chargeCompleteNotified = false;
  bool _lowBatteryNotified = false;
  int _lastBatteryPercent = 0;

  /// Detects phone-specific charging events confirmed by the device hardware
  SmartNotification? checkPhoneStatus(
    BatteryState currentState,
    BatteryState? previousState,
    int phoneLevel,
    int maxThreshold,
  ) {
    if (previousState == null || currentState == previousState) return null;

    // 1. Target reached (Charging stopped near max threshold)
    if (previousState == BatteryState.charging &&
        (currentState == BatteryState.discharging || currentState == BatteryState.full) &&
        phoneLevel >= maxThreshold - 2) {
      return SmartNotification(
        type: NotificationType.phoneTargetReached,
        title: "🎯 Target Reached",
        message: "Phone reached $phoneLevel%. Charging paused to protect battery.",
        color: Colors.teal,
      );
    }

    // 2. Confirmed charging started
    if (currentState == BatteryState.charging && previousState != BatteryState.charging) {
      return SmartNotification(
        type: NotificationType.chargingStarted,
        title: "⚡ Phone Charging",
        message: "Your device is now receiving power at $phoneLevel%.",
        color: Colors.blue,
      );
    }

    // 3. Charging stopped manually or unplugged
    if (previousState == BatteryState.charging && 
        currentState == BatteryState.discharging && 
        phoneLevel < maxThreshold - 2) {
      return SmartNotification(
        type: NotificationType.lowBattery,
        title: "🔌 Charging Stopped",
        message: "The device stopped charging at $phoneLevel%.",
        color: Colors.grey,
      );
    }

    return null;
  }

  SmartNotification? checkChargingComplete(int currentBattery, bool relayOn) {
    if (currentBattery >= 100 && !_chargeCompleteNotified && relayOn) {
      _chargeCompleteNotified = true;
      return SmartNotification(
        type: NotificationType.chargeComplete,
        title: "🎉 MSP Battery Full!",
        message: "External battery reached 100%",
        color: Colors.green,
      );
    }
    if (currentBattery < 100 || !relayOn) {
      _chargeCompleteNotified = false;
    }
    return null;
  }

  SmartNotification? checkLowBattery(int currentBattery, bool relayOn) {
    if (currentBattery < lowBatteryThreshold &&
        currentBattery < _lastBatteryPercent &&
        !_lowBatteryNotified &&
        !relayOn) {
      _lowBatteryNotified = true;
      return SmartNotification(
        type: NotificationType.lowBattery,
        title: "⚠️ Low Battery (MSP)",
        message: "External battery at $currentBattery%. Connect charger soon!",
        color: Colors.orange,
      );
    }
    if (currentBattery > lowBatteryThreshold + 5) {
      _lowBatteryNotified = false;
    }
    _lastBatteryPercent = currentBattery;
    return null;
  }

  SmartNotification? checkChargingRateAnomaly(
    List<dynamic> dataPoints,
    bool relayOn,
  ) {
    if (!relayOn || dataPoints.length < chargingAnomalyCheckPoints) {
      return null;
    }
    final recentPoints = dataPoints.sublist(
      (dataPoints.length - chargingAnomalyCheckPoints).clamp(0, dataPoints.length),
    );
    if (recentPoints.length < 2) return null;
    final first = recentPoints.first;
    final last = recentPoints.last;
    final timeDiffSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (timeDiffSeconds == 0) return null;
    final batteryDiff = (last.batteryPercent - first.batteryPercent).toDouble();
    final timeInMinutes = timeDiffSeconds / 60;
    final currentRate = batteryDiff / timeInMinutes;

    if (currentRate > 0 && currentRate < lowChargingRateThreshold) {
      return SmartNotification(
        type: NotificationType.chargingRateAnomaly,
        title: "⏱️ Slow Charging Detected",
        message: "Charging rate: ${currentRate.toStringAsFixed(2)}%/min. Check connection!",
        color: Colors.yellow,
      );
    }
    return null;
  }

  /// Check if charging just started based on relay
  SmartNotification? checkChargingStarted(int currentBattery, bool relayOn, bool? wasRelayOn) {
    if (wasRelayOn != null && relayOn && !wasRelayOn && currentBattery < 100) {
      return SmartNotification(
        type: NotificationType.chargingStarted,
        title: "⚡ Relay Activated",
        message: "Smart switch engaged at $currentBattery%.",
        color: Colors.blueGrey,
      );
    }
    return null;
  }
}
