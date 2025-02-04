import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'calculate_location_page_widget.dart' show CalculateLocationPageWidget;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';

class CalculateLocationPageModel
    extends FlutterFlowModel<CalculateLocationPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - getLocationList] action in CalculateLocationPage widget.
  List<String>? locationsList;
  // State field(s) for Timer widget.
  final timerInitialTimeMs = 10000;
  int timerMilliseconds = 10000;
  String timerValue = StopWatchTimer.getDisplayTime(
    10000,
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
