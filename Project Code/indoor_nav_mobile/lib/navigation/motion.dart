import 'dart:math' as math;

/// A reading from a 3-axis sensor, in the phone's own axes: x to the right
/// of the screen, y towards the top, z out of the screen.
typedef Vec3 = ({double x, double y, double z});

/// Finds footsteps in accelerometer readings. Walking with a phone makes the
/// total acceleration bounce above gravity once per step; each clear peak,
/// at least [minInterval] after the last, is a step.
class StepDetector {
  StepDetector({this.threshold = 1.0, this.minInterval = const Duration(milliseconds: 280)});

  /// How far above the running average (m/s²) a peak must rise.
  final double threshold;
  final Duration minInterval;

  double? _smooth;
  double _average = 9.81;
  double? _previous;
  bool _rising = false;
  Duration? _lastStep;

  /// Feeds one reading; returns true if it completes a step.
  bool add(Vec3 accel, Duration timestamp) {
    final magnitude = math.sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
    // Light smoothing removes hand jitter; a slow average tracks gravity.
    final smooth = _smooth = _smooth == null ? magnitude : _smooth! + 0.35 * (magnitude - _smooth!);
    _average += 0.02 * (smooth - _average);
    final previous = _previous;
    _previous = smooth;
    if (previous == null) return false;
    var step = false;
    if (smooth < previous && _rising && previous > _average + threshold) {
      final last = _lastStep;
      if (last == null || timestamp - last >= minInterval) {
        _lastStep = timestamp;
        step = true;
      }
    }
    _rising = smooth > previous;
    return step;
  }
}

/// Compass heading of the top of the phone, clockwise from magnetic north,
/// in radians (0..2π), from gravity ([accel]) and the magnetic field ([mag]).
/// Tilt-compensated, like Android's getRotationMatrix + getOrientation.
/// Returns null when the readings can't give a direction (phone in free fall,
/// no magnetic field, or the phone pointing straight up).
double? compassHeading(Vec3 accel, Vec3 mag) {
  // East = magnetic field × gravity; North = gravity × East.
  var hx = mag.y * accel.z - mag.z * accel.y;
  var hy = mag.z * accel.x - mag.x * accel.z;
  var hz = mag.x * accel.y - mag.y * accel.x;
  final hNorm = math.sqrt(hx * hx + hy * hy + hz * hz);
  final aNorm = math.sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
  if (hNorm < 0.1 || aNorm < 0.1) return null;
  hx /= hNorm;
  hy /= hNorm;
  hz /= hNorm;
  final ax = accel.x / aNorm, ay = accel.y / aNorm, az = accel.z / aNorm;
  final my = az * hx - ax * hz;
  return normaliseAngle(math.atan2(hy, my));
}

/// Wraps an angle into 0..2π.
double normaliseAngle(double a) {
  const tau = 2 * math.pi;
  final r = a % tau;
  return r < 0 ? r + tau : r;
}

/// The signed difference [a] - [b], wrapped into -π..π.
double angleBetween(double a, double b) {
  final d = normaliseAngle(a - b);
  return d > math.pi ? d - 2 * math.pi : d;
}

/// Smooths a stream of headings, handling the wrap at north.
class HeadingFilter {
  HeadingFilter({this.strength = 0.15});

  final double strength;
  double? _value;

  double? get value => _value;

  double add(double heading) {
    final v = _value;
    return _value = v == null ? heading : normaliseAngle(v + strength * angleBetween(heading, v));
  }
}

/// Notices a floor change from air pressure. Pressure drops about 0.12 hPa
/// per metre of height, so one storey (~3.5 m) is roughly 0.4 hPa.
class FloorChangeDetector {
  FloorChangeDetector({this.hPaPerFloor = 0.4});

  final double hPaPerFloor;
  double? _start;
  double? _smooth;

  /// Starts measuring from the current pressure (call on reaching the stairs
  /// or lift).
  void reset() => _start = _smooth;

  /// Feeds one reading (hPa); returns how many floors you have moved since
  /// [reset], positive going up, as a fraction (1.0 = one storey).
  double add(double pressure) {
    final s = _smooth = _smooth == null ? pressure : _smooth! + 0.2 * (pressure - _smooth!);
    final start = _start ??= s;
    return (start - s) / hPaPerFloor;
  }
}
