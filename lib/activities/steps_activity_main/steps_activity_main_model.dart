import '/activities/steps_activity_main/steps_activity_main_widget.dart';
import '/backend/schema/structs/index.dart';
import '/components/calculate_coordenates_component_widget.dart';
import '/components/keyboard_num_component_widget.dart';
import '/components/text_field_control_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'steps_activity_main_widget.dart' show StepsActivityMainWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class StepsActivityMainModel extends FlutterFlowModel<StepsActivityMainWidget> {
  ///  Local state fields for this component.

  dynamic stepsActivityMainFilter;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Custom Action - updateOrAddVisitDetail] action in Container widget.
  List<VisitsDetailsStruct>? visitDetailsCopy;
  // Stores action output result for [Custom Action - updateOrAddVisitDetail] action in Container widget.
  List<VisitsDetailsStruct>? visitDetails;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
