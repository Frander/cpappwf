import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_transfer_dialog_widget.dart' show NfcTransferDialogWidget;
import 'package:flutter/material.dart';

class NfcTransferDialogModel
    extends FlutterFlowModel<NfcTransferDialogWidget> {
  ///  Local state fields for this component.

  // Estados del proceso
  int currentStep = 1; // 1 = Leer origen, 2 = Escribir destino
  bool isReading = false;
  bool isClearingAndWriting = false;
  bool isSuccess = false;
  String? errorMessage;

  // Datos del tag de origen
  String sourceTagContent = '';
  Map<int, Map<String, dynamic>> parsedData = {};

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
