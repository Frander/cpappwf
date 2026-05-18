import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'calibrate_compass_component_widget.dart'
    show CalibrateCompassComponentWidget;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';

class CalibrateCompassComponentModel
    extends FlutterFlowModel<CalibrateCompassComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - calibrateCompass] action in Container widget.
  bool? calibrateCompass;
  // Stores action output result for [Custom Action - calibrateGPS] action in Container widget.
  bool? calibrateGPS;
  // State field(s) for Timer widget.
  final timerInitialTimeMs = 40000;
  int timerMilliseconds = 40000;
  String timerValue = StopWatchTimer.getDisplayTime(
    40000,
    hours: false,
    minute: false,
    milliSecond: false,
  );
  FlutterFlowTimerController timerController =
      FlutterFlowTimerController(StopWatchTimer(mode: StopWatchMode.countDown));

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    timerController.dispose();
  }
}
