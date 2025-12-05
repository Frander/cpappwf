import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_tag_component_widget.dart' show NfcTagComponentWidget;
import 'package:flutter/material.dart';

class NfcTagComponentModel extends FlutterFlowModel<NfcTagComponentWidget> {
  ///  Local state fields for this component.

  String? nfcData;
  bool isScanning = false;
  bool isSuccess = false;
  bool isError = false;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
