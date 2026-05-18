// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<bool> removeVisitDetailByActivityStatus(
  BuildContext context,
  int activityStatusId,
) async {
  bool removed = false;

  FFAppState().update(() {
    // Copiamos la lista para trabajar sobre un objeto mutable.
    final list = FFAppState().visitDetails.toList();

    final beforeLen = list.length;
    list.removeWhere((v) => v.idActivityStatus == activityStatusId);
    removed = beforeLen != list.length;

    // Guardamos la lita depurada nuevamente en AppState.
    FFAppState().visitDetails = list;
  });

  return removed;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
