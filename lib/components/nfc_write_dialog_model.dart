import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_write_dialog_widget.dart' show NfcWriteDialogWidget;
import 'package:flutter/material.dart';

class NfcWriteDialogModel extends FlutterFlowModel<NfcWriteDialogWidget> {
  ///  Local state fields for this component.
  bool isCalculating = false;
  bool isWriting = false;
  bool isSuccess = false;
  String? errorMessage;

  int totalVisits = 0;
  int totalResults = 0;
  String operatorId = '';
  int headquarterId = 0;
  String headquarterName = '';
  DateTime? dateHour;
  String dataToWrite = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
