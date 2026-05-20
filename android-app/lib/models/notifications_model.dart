import 'package:flutter/material.dart';

enum NotificationType {
  chargeComplete,
  lowBattery,
  chargingRateAnomaly,
  chargingStarted,
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

class NotificationDetector {
  // Thresholds
  static const int lowBatteryThreshold = 15; // Alert when battery < 15%
  static const double lowChargingRateThreshold = 0.2; // Alert if rate drops below 0.2%/min
  static const int chargingAnomalyCheckPoints = 10; // Check last 10 data points

  // State tracking to avoid duplicate notifications
  bool _chargeCompleteNotified = false;
  bool _lowBatteryNotified = false;
  int _lastBatteryPercent = 0;

  /// Check for charging completion
  /// Returns notification if battery reached 100%, null otherwise
  SmartNotification? checkChargingComplete(int currentBattery, bool relayOn) {
    if (currentBattery >= 100 && !_chargeCompleteNotified && relayOn) {
      _chargeCompleteNotified = true;
      return SmartNotification(
        type: NotificationType.chargeComplete,
        title: "🎉 Charging Complete!",
        message: "Battery reached 100%",
        color: Colors.green,
      );
    }

    // Reset flag when charging stops or battery drops
    if (currentBattery < 100 || !relayOn) {
      _chargeCompleteNotified = false;
    }

    return null;
  }

  /// Check for low battery warning
  /// Returns notification if battery is low and not already notified
  SmartNotification? checkLowBattery(int currentBattery, bool relayOn) {
    if (currentBattery < lowBatteryThreshold &&
        currentBattery < _lastBatteryPercent &&
        !_lowBatteryNotified &&
        !relayOn) {
      _lowBatteryNotified = true;
      return SmartNotification(
        type: NotificationType.lowBattery,
        title: "⚠️ Low Battery",
        message: "External battery at $currentBattery%. Connect charger soon!",
        color: Colors.orange,
      );
    }

    // Reset flag when battery is charged above threshold
    if (currentBattery > lowBatteryThreshold + 5) {
      _lowBatteryNotified = false;
    }

    _lastBatteryPercent = currentBattery;
    return null;
  }

  /// Check for charging rate anomalies
  /// Returns notification if charging rate is unusually low
  SmartNotification? checkChargingRateAnomaly(
    List<dynamic> dataPoints, // ChargingDataPoint list
    bool relayOn,
  ) {
    if (!relayOn || dataPoints.length < chargingAnomalyCheckPoints) {
      return null;
    }

    // Get last 10 data points
    final recentPoints = dataPoints.sublist(
      (dataPoints.length - chargingAnomalyCheckPoints)
          .clamp(0, dataPoints.length),
    );

    if (recentPoints.length < 2) return null;

    // Calculate current charging rate
    final first = recentPoints.first;
    final last = recentPoints.last;

    final timeDiffSeconds =
        last.timestamp.difference(first.timestamp).inSeconds;
    if (timeDiffSeconds == 0) return null;

    final batteryDiff = (last.batteryPercent - first.batteryPercent).toDouble();
    final timeInMinutes = timeDiffSeconds / 60;
    final currentRate = batteryDiff / timeInMinutes;

    // Alert if charging rate is unusually low (but still positive)
    if (currentRate > 0 && currentRate < lowChargingRateThreshold) {
      return SmartNotification(
        type: NotificationType.chargingRateAnomaly,
        title: "⏱️ Slow Charging Detected",
        message:
            "Charging rate: ${currentRate.toStringAsFixed(2)}%/min. Check connection!",
        color: Colors.yellow,
      );
    }

    return null;
  }

  /// Check if charging just started
  SmartNotification? checkChargingStarted(int currentBattery, bool relayOn, bool wasRelayOn) {
    if (relayOn && !wasRelayOn && currentBattery < 100) {
      return SmartNotification(
        type: NotificationType.chargingStarted,
        title: "⚡ Charging Started",
        message: "Battery: $currentBattery%",
        color: Colors.blue,
      );
    }
    return null;
  }
}
