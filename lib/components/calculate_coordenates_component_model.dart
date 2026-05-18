import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'calculate_coordenates_component_widget.dart'
    show CalculateCoordenatesComponentWidget;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';

class CalculateCoordenatesComponentModel
    extends FlutterFlowModel<CalculateCoordenatesComponentWidget> {
  ///  State fields for stateful widgets in this component.

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

  // Stores action output result for [Custom Action - createVisit] action in Timer widget.
  VisitsStruct? visitCreated;
  // Stores action output result for [Custom Action - getVisitsCount] action in Timer widget.
  int? countVisits;
  // Stores action output result for [Custom Action - createVisit] action in Timer widget.
  VisitsStruct? visitCreated2;
  // Stores action output result for [Custom Action - getVisitsCount] action in Timer widget.
  int? countVisits1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    timerController.dispose();
  }
}
