import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'company_selection_grid_widget.dart' show CompanySelectionGridWidget;
import 'package:flutter/material.dart';

class CompanySelectionGridModel
    extends FlutterFlowModel<CompanySelectionGridWidget> {
  ///  Local state fields for this component.

  List<dynamic> companiesList = [];
  void addToCompaniesList(dynamic value) => companiesList.add(value);
  void removeFromCompaniesList(dynamic value) => companiesList.remove(value);
  void removeAtIndexFromCompaniesList(int index) =>
      companiesList.removeAt(index);
  void insertAtIndexInCompaniesList(int index, dynamic value) =>
      companiesList.insert(index, value);
  void updateCompaniesListAtIndex(int index, Function(dynamic) updateFn) =>
      companiesList[index] = updateFn(companiesList[index]);

  List<dynamic> filteredCompaniesList = [];
  void addToFilteredCompaniesList(dynamic value) =>
      filteredCompaniesList.add(value);
  void removeFromFilteredCompaniesList(dynamic value) =>
      filteredCompaniesList.remove(value);
  void removeAtIndexFromFilteredCompaniesList(int index) =>
      filteredCompaniesList.removeAt(index);
  void insertAtIndexInFilteredCompaniesList(int index, dynamic value) =>
      filteredCompaniesList.insert(index, value);
  void updateFilteredCompaniesListAtIndex(
          int index, Function(dynamic) updateFn) =>
      filteredCompaniesList[index] = updateFn(filteredCompaniesList[index]);

  bool isLoading = false;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - API (companiesGETCall)] action in DeviceSelectionGrid widget.
  ApiCallResponse? apiResultCompanies;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }

  /// Action blocks are added here.

  /// Additional helper methods are added here.
}
