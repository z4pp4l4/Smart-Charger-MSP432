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

  // Keep ~10 minutes of history at 5s intervals.
  static const int maxDataPoints = 120;

  // Don't estimate until we have enough data for a stable result.
  static const int _minPoints = 5;
  static const int _minSpanSeconds = 60;

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

    if (dataPoints.length > maxDataPoints) {
      dataPoints.removeAt(0);
    }
  }

  void clear() {
    dataPoints.clear();
  }

  /// Average charging rate in percent-per-minute, taken from the phone's
  /// reported battery level over the recorded window.
  /// Positive while charging, negative while discharging, 0 if unknown.
  double getAverageChargingRate() {
    if (dataPoints.length < 2) return 0;

    final first = dataPoints.first;
    final last = dataPoints.last;

    final seconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (seconds <= 0) return 0;

    final percentDiff = (last.batteryPercent - first.batteryPercent).toDouble();
    final minutes = seconds / 60.0;

    return percentDiff / minutes; // % per minute
  }

  /// Estimated minutes until the battery reaches [targetBattery].
  /// In saving mode, pass the max threshold as [targetBattery]; otherwise 100.
  ///
  /// Returns:
  ///    0  -> already at or past the target
  ///   -1  -> can't estimate yet (not enough data, or not charging)
  ///   >0  -> estimated minutes remaining
  double calculateEstimatedTimeToCharge(int currentBattery, {int targetBattery = 100}) {
    if (currentBattery >= targetBattery) return 0;

    if (dataPoints.length < _minPoints) return -1;

    final spanSeconds = dataPoints.last.timestamp
        .difference(dataPoints.first.timestamp)
        .inSeconds;
    if (spanSeconds < _minSpanSeconds) return -1;

    final rate = getAverageChargingRate(); // % per minute
    if (rate <= 0) return -1;              // not charging, or % hasn't moved yet

    final remainingPercent = targetBattery - currentBattery;
    return remainingPercent / rate;        // minutes
  }
}