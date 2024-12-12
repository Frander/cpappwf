import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'main_page_widget.dart' show MainPageWidget;
import 'package:flutter/material.dart';

class MainPageModel extends FlutterFlowModel<MainPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - SQLite (GetAllUsers)] action in Container widget.
  List<GetAllUsersRow>? allUsers;
  // Stores action output result for [Backend Call - API (/Users/filters GET)] action in Container widget.
  ApiCallResponse? apiResultGetUsers;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
