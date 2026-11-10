// Camera tilt samples for "device raised -> AR" (F36), behind an interface so tests need no sensors.
import 'package:flutter/services.dart';

abstract class TiltSource {
  /// Camera angle below the horizon in degrees (0 = phone upright, 90 = phone flat, screen up).
  /// Listening starts the sensor; cancelling the subscription stops it.
  Stream<double> pitch();
}

/// Android: `tasuku_ar/tilt` (TiltStream.kt, gravity / accelerometer). A device without an accelerometer
/// sends no samples, so deviceRaised is left to the demo controls.
class NativeTiltSource implements TiltSource {
  const NativeTiltSource();

  static const _channel = EventChannel('tasuku_ar/tilt');

  @override
  Stream<double> pitch() => _channel
      .receiveBroadcastStream()
      .map((e) => (e as Map).cast<Object?, Object?>())
      .where((m) => m['available'] == true && m['pitch'] is num)
      .map((m) => (m['pitch'] as num).toDouble());
}
