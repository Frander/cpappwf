import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_read_dialog_widget.dart' show NfcReadDialogWidget, NfcRecord;
import 'package:flutter/material.dart';

class NfcReadDialogModel extends FlutterFlowModel<NfcReadDialogWidget> {
  ///  Local state fields for this component.
  bool isReading = false;
  bool isSuccess = false;
  String? errorMessage;
  String rawContent = '';
  List<NfcRecord> parsedRecords = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
