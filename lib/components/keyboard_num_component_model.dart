import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'keyboard_num_component_widget.dart' show KeyboardNumComponentWidget;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class KeyboardNumComponentModel
    extends FlutterFlowModel<KeyboardNumComponentWidget> {
  ///  Local state fields for this component.

  String? tittle = 'Ingrese el código';

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - updateOrAddVisitDetail] action in Container widget.
  List<VisitsDetailsStruct>? visitDetails;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
