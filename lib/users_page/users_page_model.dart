import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'users_page_widget.dart' show UsersPageWidget;
import 'package:flutter/material.dart';

class UsersPageModel extends FlutterFlowModel<UsersPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Custom Action - usersSelect] action in TextField widget.
  List<UsersStruct>? usersFilterList;
  // Stores action output result for [Custom Action - usersSelect] action in TextField widget.
  List<UsersStruct>? usersFilterNameList;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
