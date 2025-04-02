import '/backend/schema/structs/index.dart';
import '/components/info_dialog_widget.dart';
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
import 'calculate_coordenates_install_component_model.dart';
export 'calculate_coordenates_install_component_model.dart';

class CalculateCoordenatesInstallComponentWidget extends StatefulWidget {
  const CalculateCoordenatesInstallComponentWidget({
    super.key,
    this.line,
    this.palm,
  });

  final int? line;
  final int? palm;

  @override
  State<CalculateCoordenatesInstallComponentWidget> createState() =>
      _CalculateCoordenatesInstallComponentWidgetState();
}

class _CalculateCoordenatesInstallComponentWidgetState
    extends State<CalculateCoordenatesInstallComponentWidget> {
  late CalculateCoordenatesInstallComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => CalculateCoordenatesInstallComponentModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        Future(() async {
          _model.pathGNSS = await actions.downloadGNSSData();
          unawaited(
            () async {
              _model.locationsList = await actions.getLocationList(
                context,
                8,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                'assets/images/Animation_-_1737672582002.gif',
                width: 120.0,
                height: 120.0,
                fit: BoxFit.cover,
              ),
            ),
            Builder(
              builder: (context) => FlutterFlowTimer(
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
                  if (((_model.locationsList != null &&
                              (_model.locationsList)!.isNotEmpty) !=
                          null) &&
                      (_model.locationsList!.length > 0)) {
                    FFAppState().addToProductsAdd(ProductsStruct(
                      idProduct: 0,
                      rfid: ' ',
                      stateProduct: 'ACTIVE',
                      descriptionProduct: ' ',
                      locationsAdd: _model.locationsList,
                      line: widget.line,
                      palm: widget.palm,
                    ));
                    _model.updatePage(() {});
                    await actions.speakText(
                      'Se registró Linea ${widget.line?.toString()}, Palma ${widget.palm?.toString()}',
                    );
                    await showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          alignment: AlignmentDirectional(0.0, 0.0)
                              .resolve(Directionality.of(context)),
                          child: Container(
                            height: MediaQuery.sizeOf(context).height * 0.9,
                            width: MediaQuery.sizeOf(context).width * 0.9,
                            child: InfoDialogWidget(
                              info: functions.listToCommaSeparatedString(
                                  _model.locationsList!.toList()),
                            ),
                          ),
                        );
                      },
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Palma registrada con éxito. Total palmas: ${FFAppState().productsAdd.length.toString()}',
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
                        duration: Duration(milliseconds: 1050),
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
            ),
          ].divide(SizedBox(height: 15.0)),
        ),
      ),
    );
  }
}
