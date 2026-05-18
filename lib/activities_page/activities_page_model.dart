import '/flutter_flow/flutter_flow_util.dart';
import 'activities_page_widget.dart' show ActivitiesPageWidget;
import 'package:flutter/material.dart';

class ActivitiesPageModel extends FlutterFlowModel<ActivitiesPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
