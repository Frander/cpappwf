import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'do_visits_activity_page_widget.dart' show DoVisitsActivityPageWidget;
import 'package:flutter/material.dart';

class DoVisitsActivityPageModel
    extends FlutterFlowModel<DoVisitsActivityPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for RadioButton widget.
  FormFieldController<String>? radioButtonValueController;
  // Stores action output result for [Custom Action - readQR] action in Container widget.
  String? qrRead;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  /// Additional helper methods.
  String? get radioButtonValue => radioButtonValueController?.value;
}
