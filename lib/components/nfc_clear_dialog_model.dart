import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_clear_dialog_widget.dart' show NfcClearDialogWidget;
import 'package:flutter/material.dart';

class NfcClearDialogModel extends FlutterFlowModel<NfcClearDialogWidget> {
  /// Estado de limpieza
  bool isClearing = false;

  /// Estado de éxito
  bool isSuccess = false;

  /// Mensaje de error
  String errorMessage = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
