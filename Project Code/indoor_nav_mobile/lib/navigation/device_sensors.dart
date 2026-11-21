import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'live_walk.dart';
import 'motion.dart';

/// The phone's real accelerometer, magnetometer and barometer.
class DeviceMotionSensors implements MotionSensors {
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Stream<(Vec3, Duration)> get accelerometer => accelerometerEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).map((e) => ((x: e.x, y: e.y, z: e.z), _clock.elapsed));

  @override
  Stream<Vec3> get magnetometer =>
      magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) => (x: e.x, y: e.y, z: e.z));

  @override
  Stream<double>? get barometer =>
      barometerEventStream(samplingPeriod: SensorInterval.uiInterval).map((e) => e.pressure);
}

/// Spoken directions through the phone's text-to-speech.
class DeviceSpeaker implements Speaker {
  DeviceSpeaker() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  @override
  Future<void> say(String text) async {
    if (!_ready) {
      _ready = true;
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
