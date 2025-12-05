import '/activities/status_activity_main/status_activity_main_widget.dart';
import '/activities/steps_activity_main/steps_activity_main_widget.dart';
import '/backend/schema/structs/index.dart';
import '/components/calculate_coordenates_component_widget.dart';
import '/components/keyboard_num_component_widget.dart';
import '/components/text_field_control_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'steps_main_widget.dart' show StepsMainWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class StepsMainModel extends FlutterFlowModel<StepsMainWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for ListViewMain widget.
  ScrollController? listViewMainScrollController;
  // State field(s) for ListView widget.
  ScrollController? listViewController1;
  // State field(s) for ListView widget.
  ScrollController? listViewController2;
  // Stores action output result for [Custom Action - updateOrAddVisitDetail] action in Card widget.
  List<VisitsDetailsStruct>? visitDetail;

  @override
  void initState(BuildContext context) {
    listViewMainScrollController = ScrollController();
    listViewController1 = ScrollController();
    listViewController2 = ScrollController();
  }

  @override
  void dispose() {
    listViewMainScrollController?.dispose();
    listViewController1?.dispose();
    listViewController2?.dispose();
  }
}
