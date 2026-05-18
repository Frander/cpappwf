import '/flutter_flow/flutter_flow_util.dart';
import 'nfc_write_dialog_widget.dart' show NfcWriteDialogWidget;
import 'package:flutter/material.dart';

/// Estructura para almacenar datos de visitas por lote
class HeadquarterVisitData {
  final int headquarterId;
  final String headquarterName;
  final int visits;
  final int results;

  HeadquarterVisitData({
    required this.headquarterId,
    required this.headquarterName,
    required this.visits,
    required this.results,
  });
}

class NfcWriteDialogModel extends FlutterFlowModel<NfcWriteDialogWidget> {
  ///  Local state fields for this component.
  bool isCalculating = false;
  bool isWriting = false;
  bool isSuccess = false;
  String? errorMessage;

  int totalVisits = 0;
  int totalResults = 0;
  String operatorId = '';
  String operatorName = ''; // Nombre del operador principal
  String operator2Id = ''; // Operador Cortero (OP2)
  String operator2Name = ''; // Nombre del operador cortero
  int headquarterId = 0;
  String headquarterName = '';
  DateTime? dateHour;
  String dataToWrite = '';

  /// Lista de datos de visitas agrupados por lote
  List<HeadquarterVisitData> visitsByHeadquarter = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
