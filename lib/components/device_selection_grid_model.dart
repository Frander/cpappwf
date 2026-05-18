import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'device_selection_grid_widget.dart' show DeviceSelectionGridWidget;
import 'package:flutter/material.dart';

class DeviceSelectionGridModel
    extends FlutterFlowModel<DeviceSelectionGridWidget> {
  ///  Local state fields for this component.

  List<dynamic> devicesList = [];
  List<dynamic> filteredDevicesList = [];
  bool isLoading = true;
  String searchQuery = '';
  int? selectingDeviceId; // ID del dispositivo que se está seleccionando

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  // Stores action output result for [Backend Call - API] action
  ApiCallResponse? apiResultDevices;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }

  void filterDevices(String query) {
    searchQuery = query.toLowerCase();
    if (searchQuery.isEmpty) {
      filteredDevicesList = List.from(devicesList);
    } else {
      filteredDevicesList = devicesList.where((device) {
        final deviceName = (device['device_name'] ?? '').toString().toLowerCase();
        final serial = (device['serial_id'] ?? '').toString().toLowerCase();
        final imei1 = (device['imeI1'] ?? '').toString().toLowerCase();
        final model = (device['model'] ?? '').toString().toLowerCase();

        return deviceName.contains(searchQuery) ||
            serial.contains(searchQuery) ||
            imei1.contains(searchQuery) ||
            model.contains(searchQuery);
      }).toList();
    }
  }
}
