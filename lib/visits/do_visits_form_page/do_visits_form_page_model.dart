import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'do_visits_form_page_widget.dart' show DoVisitsFormPageWidget;
import 'package:flutter/material.dart';

class DoVisitsFormPageModel extends FlutterFlowModel<DoVisitsFormPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for RadioButton widget.
  FormFieldController<String>? radioButtonValueController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  /// Additional helper methods.
  String? get radioButtonValue => radioButtonValueController?.value;
}
