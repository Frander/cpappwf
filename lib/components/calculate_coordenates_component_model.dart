import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'calculate_coordenates_component_widget.dart'
    show CalculateCoordenatesComponentWidget;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';

class CalculateCoordenatesComponentModel
    extends FlutterFlowModel<CalculateCoordenatesComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - getLocationList] action in CalculateCoordenatesComponent widget.
  List<String>? locationsList;
  // State field(s) for Timer widget.
  final timerInitialTimeMs = 5000;
  int timerMilliseconds = 5000;
  String timerValue = StopWatchTimer.getDisplayTime(
    5000,
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
