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

  static const int maxDataPoints = 120;
  static const int _minPoints = 5;
  static const int _minSpanSeconds = 60;

  // Smoothed charging rate (%/min) so the ETA doesn't jump around.
  double _smoothedRate = 0;
  static const double _smoothing = 0.2; // lower = smoother/slower to react

  void addDataPoint(double voltage, double current, double power, int batteryPercent) {
    dataPoints.add(ChargingDataPoint(
      timestamp: DateTime.now(),
      voltage: voltage,
      current: current,
      power: power,
      batteryPercent: batteryPercent,
    ));
    if (dataPoints.length > maxDataPoints) {
      dataPoints.removeAt(0);
    }
    _updateRate();
  }

  void clear() {
    dataPoints.clear();
    _smoothedRate = 0;
  }

  // Recomputed each time a point is added (~5s), then exponentially smoothed.
  void _updateRate() {
    final valid = dataPoints.where((p) => p.batteryPercent > 0).toList();
    if (valid.length < 2) return;

    final cutoff = valid.last.timestamp.subtract(const Duration(minutes: 5));
    final window = valid.where((p) => p.timestamp.isAfter(cutoff)).toList();
    if (window.length < 2) return;

    final first = window.first;
    final last = window.last;
    final seconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (seconds <= 0) return;

    final raw = (last.batteryPercent - first.batteryPercent).toDouble() / (seconds / 60.0);
    if (raw <= 0) return; // % hasn't moved -> keep the last good rate, don't inflate

    _smoothedRate =
    _smoothedRate == 0 ? raw : (_smoothedRate * (1 - _smoothing) + raw * _smoothing);
  }

  double getAverageChargingRate() => _smoothedRate;

  double calculateEstimatedTimeToCharge(int currentBattery, {int targetBattery = 100}) {
    if (currentBattery >= targetBattery) return 0;
    if (dataPoints.length < _minPoints) return -1;

    final spanSeconds =
        dataPoints.last.timestamp.difference(dataPoints.first.timestamp).inSeconds;
    if (spanSeconds < _minSpanSeconds) return -1;

    final rate = getAverageChargingRate();
    if (rate <= 0) return -1;

    final remainingPercent = targetBattery - currentBattery;
    return remainingPercent / rate;
  }
}