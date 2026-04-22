import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_view_raw_dialog_widget.dart' show NfcViewRawDialogWidget;
import 'package:flutter/material.dart';

class NfcViewRawDialogModel extends FlutterFlowModel<NfcViewRawDialogWidget> {
  /// Estado de la lectura NFC
  bool isReading = false;

  /// Contenido crudo del TAG
  String rawContent = '';

  /// Mensaje de error
  String errorMessage = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
