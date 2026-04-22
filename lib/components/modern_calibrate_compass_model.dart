import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'modern_calibrate_compass_widget.dart' show ModernCalibrateCompassWidget;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';

class ModernCalibrateCompassModel
    extends FlutterFlowModel<ModernCalibrateCompassWidget> {
  /// State field(s) for Timer widget.
  final timerInitialTimeMs = 20000;
  int timerMilliseconds = 20000;
  String timerValue = StopWatchTimer.getDisplayTime(
    20000,
    hours: false,
    minute: false,
    milliSecond: false,
  );
  FlutterFlowTimerController timerController =
      FlutterFlowTimerController(StopWatchTimer(mode: StopWatchMode.countDown));

  /// Stores action output result for [Custom Action - calibrateCompass] action
  bool? calibrateCompass;

  /// Stores action output result for [Custom Action - calibrateGPS] action
  bool? calibrateGPS;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    timerController.dispose();
  }
}
