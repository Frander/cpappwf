import '/flutter_flow/flutter_flow_util.dart';
import 'text_field_control_component_widget.dart'
    show TextFieldControlComponentWidget;
import 'package:flutter/material.dart';

class TextFieldControlComponentModel
    extends FlutterFlowModel<TextFieldControlComponentWidget> {
  ///  State fields for stateful widgets in this component.

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
