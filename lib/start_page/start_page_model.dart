import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/components/info_dialog_widget.dart';
import '/components/keyboard_num_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'start_page_widget.dart' show StartPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class StartPageModel extends FlutterFlowModel<StartPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Sync progress tracking
  int currentStep = 0;
  int totalSteps = 5;
  String stepMessage = 'Iniciando sincronización...';

  // Stores action output result for [Custom Action - getPersistentId] action in StartPage widget.
  String? identifierCTR;
  // Stores action output result for [Custom Action - validateDbSqlite] action in StartPage widget.
  String? pathDBSQLite1;
  // Stores action output result for [Custom Action - checkInternetQuality] action in StartPage widget.
  dynamic? connectionJSON;
  // Stores action output result for [Backend Call - API (/Devices/filters GET)] action in StartPage widget.
  ApiCallResponse? apiResultDevices;
  // Stores action output result for [Backend Call - API (/Users/Login POST)] action in StartPage widget.
  ApiCallResponse? apiResultLoginDirect;
  // Stores action output result for [Custom Action - validateDbSqlite] action in StartPage widget.
  String? pathDBSQLite;
  // Stores action output result for [Custom Action - syncLogin] action in StartPage widget.
  bool? customSyncLoginResult;
  // Stores action output result for [Backend Call - API (/Users/Login POST)] action in StartPage widget.
  ApiCallResponse? apiResultLoginRegister;
  // Stores action output result for [Custom Action - validateDbSqlite] action in StartPage widget.
  String? pathDBSQLiteRegister;
  // Stores action output result for [Custom Action - syncLogin] action in StartPage widget.
  bool? customSyncLoginResult1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
