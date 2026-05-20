class ChargingDataPoint {
  final DateTime timestamp;
  final double voltage;
  final double current;
  final double power;
  final int batteryPercent;

  ChargingDataPoint({
    required this.timestamp,
    required this.voltage,
    required this.current,
    required this.power,
    required this.batteryPercent,
  });
}

class ChargingHistory {
  final List<ChargingDataPoint> dataPoints = [];
  static const int maxDataPoints = 120; // Keep last 120 readings (~10 mins at 5s intervals)

  void addDataPoint(double voltage, double current, double power, int batteryPercent) {
    dataPoints.add(
      ChargingDataPoint(
        timestamp: DateTime.now(),
        voltage: voltage,
        current: current,
        power: power,
        batteryPercent: batteryPercent,
      ),
    );

    // Keep only the last maxDataPoints
    if (dataPoints.length > maxDataPoints) {
      dataPoints.removeAt(0);
    }
  }

  void clear() {
    dataPoints.clear();
  }

  /// Calculate estimated time to full charge in minutes
  /// Returns -1 if unable to calculate
  double calculateEstimatedTimeToCharge(int currentBattery, {int targetBattery = 100}) {
    if (dataPoints.length < 5) return -1; // Need at least 5 data points

    // Calculate average power in last few readings (mW)
    final recentPoints = dataPoints.sublist(
      (dataPoints.length - 5).clamp(0, dataPoints.length),
    );

    double avgPower = recentPoints.fold(0.0, (sum, p) => sum + p.power) / recentPoints.length;
    double remainingEnergy = (targetBattery - currentBattery) * 50; // ~50 mWh per 1%
    double timeToCharge = remainingEnergy / avgPower;

    return timeToCharge; // in minutes
  }

  /// Get average charging rate in percentage per minute
  double getAverageChargingRate() {
    if (dataPoints.isEmpty) return 0;

    if (dataPoints.length < 2) return 0;

    final first = dataPoints.first;
    final last = dataPoints.last;

    final timeDiffSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (timeDiffSeconds == 0) return 0;

    final batteryDiff = (last.batteryPercent - first.batteryPercent).toDouble();
    final timeInMinutes = timeDiffSeconds / 60;

    return batteryDiff / timeInMinutes; // % per minute
  }
}
