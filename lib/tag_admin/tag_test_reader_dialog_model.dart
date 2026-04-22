import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class TagTestReaderDialogModel extends FlutterFlowModel {
  bool isReading = false;
  bool isSuccess = false;
  String? errorMessage;
  String rawContent = '';
  List<Map<String, dynamic>> parsedRecords = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
