// ARCore view (optional upgrade): the native view draws the camera image and puts the arrow on a
// detected floor plane (android/.../ar/ArGuideView.kt). Used only when ARCore is installed and supported.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'guide_params.dart';

/// `initializing` / `searching` / `tracking` / `lost` / `error` / `unsupported` (see ArRenderer.kt).
class ArCoreStatus {
  const ArCoreStatus(this.state, [this.reason]);
  final String state;
  final String? reason;

  bool get tracking => state == 'tracking';
  bool get failed => state == 'error' || state == 'unsupported';
}

class ArCoreView extends StatefulWidget {
  const ArCoreView({super.key, required this.turn, required this.yawOffsetDeg, required this.onStatus});

  final Turn turn;

  /// Clockwise angle from the viewing direction to the route bearing; used when the arrow is placed.
  final double yawOffsetDeg;
  final ValueChanged<ArCoreStatus> onStatus;

  @override
  State<ArCoreView> createState() => _ArCoreViewState();
}

class _ArCoreViewState extends State<ArCoreView> {
  static const _viewType = 'tasuku_ar/arview';
  MethodChannel? _channel;

  @override
  void didUpdateWidget(ArCoreView old) {
    super.didUpdateWidget(old);
    if (old.turn != widget.turn) _channel?.invokeMethod('setTurn', widget.turn.name);
    if ((old.yawOffsetDeg - widget.yawOffsetDeg).abs() > 1) {
      _channel?.invokeMethod('setYawOffset', widget.yawOffsetDeg);
    }
  }

  Future<void> _onCreated(int id) async {
    final channel = MethodChannel('tasuku_ar/arview_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onStatus') _emit(call.arguments);
    });
    await channel.invokeMethod('setYawOffset', widget.yawOffsetDeg);
    // Status sent before the handler was set (e.g. session creation failed) is read back here.
    _emit(await channel.invokeMethod<Object?>('getStatus'));
  }

  void _emit(Object? raw) {
    if (!mounted || raw is! Map) return;
    final state = raw['state'];
    if (state is! String) return;
    widget.onStatus(ArCoreStatus(state, raw['reason'] as String?));
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hybrid composition: the native GLSurfaceView renders correctly under Flutter overlays.
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, Object?>{'turn': widget.turn.name},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_onCreated)
          ..create();
      },
    );
  }
}
