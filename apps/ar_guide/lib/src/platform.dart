// Channels to the Android side (android/app/src/main/kotlin/jp/tasuku/ar_guide/).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

enum CameraPermission { granted, denied, blocked }

class PrepareResult {
  const PrepareResult(this.camera, this.arcore);
  final CameraPermission camera;

  /// ARCore is supported and installed (optional upgrade: plane finding).
  final bool arcore;
}

class Orientation3 {
  const Orientation3({required this.available, this.heading = 0, this.pitch = 0, this.accuracy = -1});

  /// false = no magnetometer.
  final bool available;

  /// Compass heading of where the phone points (deg, 0 = north, clockwise).
  final double heading;

  /// Camera angle below the horizon (deg): 0 = level, 90 = pointing at the floor.
  final double pitch;

  /// Magnetometer accuracy (Android SensorManager): 0 unreliable, 1 low, 2 medium, 3 high, -1 unknown.
  final int accuracy;

  /// SENSOR_STATUS_UNRELIABLE. The screen asks for a figure-8 calibration only when this lasts
  /// [GuideScreen]'s hold time (1 s), so a brief drop does not hide the arrow (F3B).
  bool get unreliable => accuracy == 0;

  /// SENSOR_STATUS_ACCURACY_LOW: some phones stay here; the arrow is kept with a small note.
  bool get lowAccuracy => accuracy == 1;
}

class NativeBridge {
  static const _link = MethodChannel('tasuku_ar/link');
  static const _ar = MethodChannel('tasuku_ar/ar');
  static const _orientation = EventChannel('tasuku_ar/orientation');

  static Future<String?> initialLink() => _link.invokeMethod<String>('getInitialLink');

  /// Later deep links while the app is open (singleTop activity).
  static void onLink(void Function(String link) handler) {
    _link.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) handler(call.arguments as String);
    });
  }

  static Future<PrepareResult> prepare({required bool requestPermission}) async {
    final r = await _ar.invokeMapMethod<String, Object?>('prepare', {'requestPermission': requestPermission});
    final camera = switch (r?['camera']) {
      'granted' => CameraPermission.granted,
      'blocked' => CameraPermission.blocked,
      _ => CameraPermission.denied,
    };
    return PrepareResult(camera, r?['arcore'] == true);
  }

  static Future<void> openAppSettings() => _ar.invokeMethod('openAppSettings');

  static Stream<Orientation3> orientation() => _orientation.receiveBroadcastStream().map((e) {
        final m = (e as Map).cast<Object?, Object?>();
        if (m['available'] != true) return const Orientation3(available: false);
        return Orientation3(
          available: true,
          heading: (m['heading'] as num?)?.toDouble() ?? 0,
          pitch: (m['pitch'] as num?)?.toDouble() ?? 0,
          accuracy: (m['accuracy'] as num?)?.toInt() ?? -1,
        );
      });
}

/// Smallest signed difference a - b in degrees, in (-180, 180].
double angleDiff(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Clockwise angle of the camera arrow from straight ahead: bearing - heading.
double arrowAngle({required double bearing, required double heading}) => angleDiff(bearing, heading);

/// Rotation of the marker on the schematic map, whose "up" is the next leg of the route (bearing):
/// heading - bearing. When the camera arrow points straight ahead, the marker points along the route.
double mapMarkerAngle({required double bearing, required double heading}) => angleDiff(heading, bearing);

/// "Turn around" state with hysteresis (same thresholds as the mock's S11), so the display does not
/// flicker around the limit: on above [enterDeg], off below [exitDeg], kept in between.
class TurnAroundLatch {
  static const enterDeg = 120.0;
  static const exitDeg = 110.0;
  bool _on = false;

  /// [deltaDeg] = arrow angle; null (no usable compass) clears the state.
  bool update(double? deltaDeg) {
    if (deltaDeg == null) {
      _on = false;
    } else if (deltaDeg.abs() > enterDeg) {
      _on = true;
    } else if (deltaDeg.abs() < exitDeg) {
      _on = false;
    }
    return _on;
  }
}

/// Low-pass filter for compass angles (handles the 359 -> 0 wrap).
class AngleSmoother {
  AngleSmoother({this.factor = 0.18});
  final double factor;
  double? _value;

  double add(double deg) {
    final v = _value;
    if (v == null) return _value = deg;
    final next = (v + angleDiff(deg, v) * factor) % 360;
    return _value = next < 0 ? next + 360 : next;
  }

  void reset() => _value = null;
}

double degToRad(double d) => d * math.pi / 180;
