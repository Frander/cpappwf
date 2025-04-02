import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'calculate_coordenates_component_model.dart';
export 'calculate_coordenates_component_model.dart';

class CalculateCoordenatesComponentWidget extends StatefulWidget {
  const CalculateCoordenatesComponentWidget({super.key});

  @override
  State<CalculateCoordenatesComponentWidget> createState() =>
      _CalculateCoordenatesComponentWidgetState();
}

class _CalculateCoordenatesComponentWidgetState
    extends State<CalculateCoordenatesComponentWidget> {
  late CalculateCoordenatesComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalculateCoordenatesComponentModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        Future(() async {
          unawaited(
            () async {
              _model.locationsList = await actions.getLocationList(
                context,
                10,
              );
            }(),
          );
        }),
        Future(() async {
          _model.timerController.onStartTimer();
        }),
      ]);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: Image.asset(
            'assets/images/Fondoo56_Mesa-de-trabajo-1.jpg',
          ).image,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(30.0, 5.0, 30.0, 0.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/Clickpalmlogo1-removebg-preview.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Text(
                'Quedese cerca a la palma',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Text(
                'Estamos calculando la ubicación exacta del dispositivo',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              'Espere 10 segundos',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Inter',
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            FlutterFlowTimer(
              initialTime: _model.timerInitialTimeMs,
              getDisplayTime: (value) => StopWatchTimer.getDisplayTime(
                value,
                hours: false,
                minute: false,
                milliSecond: false,
              ),
              controller: _model.timerController,
              updateStateInterval: Duration(milliseconds: 1000),
              onChanged: (value, displayTime, shouldUpdate) {
                _model.timerMilliseconds = value;
                _model.timerValue = displayTime;
                if (shouldUpdate) safeSetState(() {});
              },
              onEnded: () async {
                if (_model.locationsList!.length > 0) {
                  FFAppState().addToVisitsAdd(VisitsStruct(
                    idVisit: 0,
                    idCompany: FFAppState().userSelected.idCompany,
                    idActivity: FFAppState().activitySelected.idActivity,
                    idHeadquarter: 0,
                    idProduct: 0,
                    idUser: FFAppState().userSelected.idUser,
                    idDevice: FFAppState().deviceDefault.idDevice,
                    locationsAdd: _model.locationsList,
                    locationDefault: ' ',
                    idStatus:
                        FFAppState().activityStatusSelected.idActivityStatus,
                    createdAt:
                        functions.convertToDotNetDateTime(getCurrentTimestamp),
                  ));
                  _model.updatePage(() {});
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Visita registrada con éxito. Total visitas: ${FFAppState().visitsAdd.length.toString()}',
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  fontFamily: 'Inter Tight',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                ),
                      ),
                      duration: Duration(milliseconds: 2000),
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                    ),
                  );
                  Navigator.pop(context);
                  return;
                } else {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Se está tardando más de lo normal...',
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  fontFamily: 'Inter Tight',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                ),
                      ),
                      duration: Duration(milliseconds: 2000),
                      backgroundColor: FlutterFlowTheme.of(context).alternate,
                    ),
                  );
                  _model.timerController.onResetTimer();

                  _model.timerController.onStartTimer();
                  return;
                }
              },
              textAlign: TextAlign.start,
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: 'Inter Tight',
                    fontSize: 100.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ].divide(SizedBox(height: 15.0)),
        ),
      ),
    );
  }
}
