import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'start_page_widget.dart' show StartPageWidget;
import 'package:flutter/material.dart';

class StartPageModel extends FlutterFlowModel<StartPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - checkConnection] action in StartPage widget.
  bool? isConnection;
  // Stores action output result for [Custom Action - getAndroidID] action in StartPage widget.
  String? androidID;
  // Stores action output result for [Backend Call - API (/Devices/filters GET)] action in StartPage widget.
  ApiCallResponse? apiResultDevices;
  // Stores action output result for [Backend Call - API (/Users/Login POST)] action in StartPage widget.
  ApiCallResponse? apiResultLoginDirect;
  // Stores action output result for [Custom Action - getDatabase] action in StartPage widget.
  String? pathDatabase;
  // Stores action output result for [Custom Action - usersSelect] action in StartPage widget.
  List<UsersStruct>? usersSelectList;
  // Stores action output result for [Backend Call - API (/Users/Login POST)] action in StartPage widget.
  ApiCallResponse? apiResultLoginRegister;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
