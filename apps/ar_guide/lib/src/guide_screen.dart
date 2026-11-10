// S11 AR guidance (with S12 "AR paused" as the fallback state).
//
// Two ways to put the arrow on the floor:
//  - compass (default, works without ARCore, e.g. AQUOS wish4): `camera` plugin preview + an arrow drawn
//    in perspective from the phone tilt, rotated by (route bearing - compass heading).
//  - ARCore (optional upgrade): when ARCore is installed and supported, the native view anchors the arrow
//    on a detected floor plane. If ARCore fails, the screen falls back to the compass mode.
//
// The arrow is hidden and "AR paused" is shown when: camera permission denied (F3C), no camera, no
// compass sensor, compass needs calibration (F3B), or ARCore lost tracking / found no floor yet (F3B).
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcore_view.dart';
import 'floor_arrow.dart';
import 'guide_params.dart';
import 'platform.dart';
import 'strings.dart';
import 'widgets.dart';

enum _Mode { checking, compass, arcore }

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.params, this.onBack});
  final GuideParams params;

  /// The back button. null = leave the app (opened by the deep link).
  final VoidCallback? onBack;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> with WidgetsBindingObserver {
  _Mode _mode = _Mode.checking;
  CameraPermission? _permission;
  bool _arcoreAvailable = false;
  bool _arcoreFailed = false;
  bool _preparing = false;
  ArCoreStatus _arStatus = const ArCoreStatus('initializing');

  CameraController? _camera;
  bool _cameraError = false;
  bool _cameraStarting = false;

  StreamSubscription<Orientation3>? _orientationSub;
  Orientation3? _orientation;
  final _heading = AngleSmoother();
  double _smoothedHeading = 0;
  double _pitch = 60;

  /// Current height of the MAP sheet (px); updated by the sheet.
  final _sheetHeight = ValueNotifier<double>(96);

  /// The route is behind the user: U-turn arrow instead of the band (compass mode).
  final _turnAroundLatch = TurnAroundLatch();
  bool _turnAround = false;

  /// When the magnetometer became UNRELIABLE (null = it is not).
  DateTime? _unreliableSince;
  static const _calibrationHold = Duration(seconds: 1);

  /// UNRELIABLE for at least [_calibrationHold]: hide the arrow and ask for a figure 8 (F3B).
  bool get _needsCalibration {
    final since = _unreliableSince;
    return since != null && DateTime.now().difference(since) >= _calibrationHold;
  }

  /// Route bearing in use: the link's `bearing`, or the heading at the first compass reading.
  double? _bearing;

  GuideParams get p => widget.params;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bearing = p.bearingDeg;
    _listenOrientation();
    _prepare(requestPermission: true);
  }

  @override
  void didUpdateWidget(GuideScreen old) {
    super.didUpdateWidget(old);
    if (old.params != widget.params) {
      // New deep link: new route direction; without a bearing, re-take the current heading.
      _bearing = p.bearingDeg ?? (_orientation?.available == true ? _smoothedHeading : null);
      final wantCompass = p.mode == ArMode.compass;
      if ((_mode == _Mode.arcore && wantCompass) || (_mode == _Mode.compass && p.mode == ArMode.arcore)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyMode();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orientationSub?.cancel();
    _sheetHeight.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _stopCamera();
      case AppLifecycleState.resumed:
        if (_permission != CameraPermission.granted) {
          // Back from Settings (or the permission dialog): check again without prompting.
          _prepare(requestPermission: false);
        } else if (_mode == _Mode.compass) {
          _startCamera();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  // ---------------------------------------------------------------------------------------------

  Future<void> _prepare({required bool requestPermission}) async {
    if (_preparing) return;
    _preparing = true;
    try {
      final r = await NativeBridge.prepare(requestPermission: requestPermission);
      if (!mounted) return;
      setState(() {
        _permission = r.camera;
        _arcoreAvailable = r.arcore;
      });
      if (r.camera == CameraPermission.granted) _applyMode();
    } on PlatformException {
      // "busy": a permission dialog is already showing; its result will arrive through that call.
    } finally {
      _preparing = false;
    }
  }

  void _applyMode() {
    final useArcore = _arcoreAvailable && !_arcoreFailed && p.mode != ArMode.compass;
    if (useArcore) {
      _stopCamera();
      setState(() {
        _mode = _Mode.arcore;
        _arStatus = const ArCoreStatus('initializing');
      });
    } else {
      setState(() => _mode = _Mode.compass);
      _startCamera();
    }
  }

  void _onArStatus(ArCoreStatus s) {
    if (s.failed) {
      // ARCore could not run after all: switch to the compass mode automatically.
      _arcoreFailed = true;
      _applyMode();
      return;
    }
    setState(() => _arStatus = s);
  }

  Future<void> _startCamera() async {
    if (_camera != null || _cameraStarting || _permission != CameraPermission.granted) return;
    _cameraStarting = true;
    try {
      final cameras = await availableCameras();
      final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back);
      if (back.isEmpty) throw CameraException('noBackCamera', null);
      final controller = CameraController(back.first, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      // The app may have gone to the background while the camera was opening: the lifecycle handler
      // found no controller to stop then, so drop this one now; resumed will start a fresh one.
      final inForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!mounted || _mode != _Mode.compass || !inForeground) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraError = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        if (e.code == 'CameraAccessDenied') _permission = CameraPermission.denied;
      });
    } finally {
      _cameraStarting = false;
    }
  }

  void _stopCamera() {
    final c = _camera;
    if (c == null) return;
    _camera = null;
    if (mounted) setState(() {});
    c.dispose();
  }

  void _listenOrientation() {
    _orientationSub = NativeBridge.orientation().listen((o) {
      if (!mounted) return;
      setState(() {
        _orientation = o;
        if (!o.available) return;
        // Events arrive ~30 times a second, so the hold time is re-checked on every rebuild.
        _unreliableSince = o.unreliable ? (_unreliableSince ?? DateTime.now()) : null;
        _smoothedHeading = _heading.add(o.heading);
        _pitch += (o.pitch - _pitch) * 0.2;
        _bearing ??= _smoothedHeading;
        _turnAround = _turnAroundLatch.update(_needsCalibration ? null : _delta);
      });
    });
  }

  void _back() => widget.onBack != null ? widget.onBack!() : SystemNavigator.pop();

  // ---------------------------------------------------------------------------------------------

  /// Clockwise angle from where the phone points to the route bearing.
  double get _delta {
    final b = _bearing;
    if (b == null || _orientation?.available != true) return 0;
    return arrowAngle(bearing: b, heading: _smoothedHeading);
  }

  /// Marker rotation on the route-up map; null (no direction shown) without a usable compass or while
  /// calibrating. Without a link `bearing`, [_bearing] is the first heading, so the same formula applies.
  double? get _markerAngle {
    final b = _bearing;
    if (b == null || _orientation?.available != true || _needsCalibration) return null;
    return mapMarkerAngle(bearing: b, heading: _smoothedHeading);
  }

  /// Why the arrow is hidden, or null when it is shown.
  _Pause? _pauseReason(S s) {
    final perm = _permission;
    if (perm == null || _mode == _Mode.checking) return _Pause(s.checkLocation, s.starting);
    if (perm == CameraPermission.blocked) {
      return _Pause(s.checkLocation, s.cameraOff, action: s.openSettings, onAction: NativeBridge.openAppSettings);
    }
    if (perm == CameraPermission.denied) {
      return _Pause(s.checkLocation, s.cameraOff,
          action: s.allowCamera, onAction: () => _prepare(requestPermission: true));
    }
    final o = _orientation;
    final compassNeeded = _mode == _Mode.compass || p.bearingDeg != null;
    if (_mode == _Mode.compass) {
      if (_cameraError) return _Pause(s.checkLocation, s.cameraError);
      if (_camera == null) return _Pause(s.checkLocation, s.starting);
      if (o == null) return _Pause(s.checkLocation, s.starting);
      if (!o.available) return _Pause(s.checkLocation, s.noCompass);
    }
    if (compassNeeded && o != null && o.available && _needsCalibration) {
      return _Pause(s.calibrateCompass, s.figure8, figure8: true);
    }
    if (_mode == _Mode.arcore && !_arStatus.tracking) {
      return switch (_arStatus.state) {
        'searching' || 'initializing' => _Pause(s.checkLocation, s.pointAtFloor),
        _ => _Pause(s.checkLocation, switch (_arStatus.reason) {
            'INSUFFICIENT_LIGHT' => s.tooDark,
            'EXCESSIVE_MOTION' => s.tooFast,
            'INSUFFICIENT_FEATURES' => s.noFeatures,
            _ => s.uncertain,
          }),
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(p.lang);
    final pause = _pauseReason(s);
    final showArrow = pause == null;
    final showTurnAround = _mode == _Mode.compass && showArrow && _turnAround;
    // Cards sit on the side opposite the turn (physical left for Right / Straight), as in the mock.
    final cardsOnLeft = p.turn != Turn.left;

    return Directionality(
      textDirection: p.lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Tk.bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Full-screen camera (edge-to-edge); overlays below stay inside the safe area.
              _background(showArrow),
              if (showTurnAround)
                CustomPaint(painter: UTurnArrowPainter(sheetHeight: _sheetHeight))
              else if (_mode == _Mode.compass && showArrow)
                CustomPaint(
                  painter: FloorArrowPainter(
                    turn: p.turn,
                    deltaDeg: _delta,
                    pitchDeg: _pitch,
                    sheetHeight: _sheetHeight,
                  ),
                ),
              Column(
                children: [
                  TkHeader(
                    title: s.title,
                    demoLabel: s.demo,
                    modeLabel: switch (_mode) {
                      _Mode.compass => s.modeCompass,
                      _Mode.arcore => s.modeArcore,
                      _Mode.checking => null,
                    },
                    onBack: _back,
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SafeArea(
                          top: false,
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
                            child: Align(
                              alignment: cardsOnLeft ? Alignment.topLeft : Alignment.topRight,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: cardsOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  TkBadge(label: s.tsunamiWarning),
                                  if (showArrow) ...[
                                    const SizedBox(height: 10),
                                    TurnCard(direction: s.turn(p.turn), distance: s.distance(p.distanceM)),
                                    if (showTurnAround) ...[
                                      const SizedBox(height: 8),
                                      Semantics(
                                        liveRegion: true,
                                        child: LowAccuracyChip(label: s.turnAround, icon: Icons.u_turn_left),
                                      ),
                                    ],
                                    if (_orientation?.lowAccuracy == true || _orientation?.unreliable == true) ...[
                                      const SizedBox(height: 8),
                                      LowAccuracyChip(label: s.lowAccuracy),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (pause == null) MapSheet(s: s, params: p, headingDeg: _markerAngle, sheetHeight: _sheetHeight),
                      ],
                    ),
                  ),
                  if (pause != null)
                    PausedSheet(
                      s: s,
                      title: pause.title,
                      message: pause.message,
                      actionLabel: pause.action,
                      onAction: pause.onAction,
                      showFigure8: pause.figure8,
                      onBack: _back,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _background(bool showArrow) {
    if (_mode == _Mode.arcore) {
      return ArCoreView(turn: p.turn, yawOffsetDeg: _delta, onStatus: _onArStatus);
    }
    final c = _camera;
    if (_mode == _Mode.compass && c != null && c.value.isInitialized) {
      final size = c.value.previewSize; // landscape (width > height)
      if (size == null) return CameraPreview(c);
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: size.height, height: size.width, child: CameraPreview(c)),
        ),
      );
    }
    return const ColoredBox(color: Tk.bgDark);
  }
}

class _Pause {
  _Pause(this.title, this.message, {this.action, this.onAction, this.figure8 = false});
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool figure8;
}
