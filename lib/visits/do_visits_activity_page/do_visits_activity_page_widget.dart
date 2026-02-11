import '/backend/schema/structs/index.dart';
import '/components/read_n_f_c_component_widget.dart';
import '/flutter_flow/flutter_flow_radio_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'do_visits_activity_page_model.dart';
export 'do_visits_activity_page_model.dart';

class DoVisitsActivityPageWidget extends StatefulWidget {
  const DoVisitsActivityPageWidget({
    super.key,
    String? tittle,
  }) : tittle = tittle ?? 'Módulo ClickPalm';

  final String tittle;

  static String routeName = 'DoVisitsActivityPage';
  static String routePath = '/doVisitsActivityPage';

  @override
  State<DoVisitsActivityPageWidget> createState() =>
      _DoVisitsActivityPageWidgetState();
}

class _DoVisitsActivityPageWidgetState
    extends State<DoVisitsActivityPageWidget> {
  late DoVisitsActivityPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoVisitsActivityPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF101827),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 15.0, 0.0, 0.0),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FlutterFlowRadioButton(
                              options: ['GPS', 'NFC', 'QR'].toList(),
                              onChanged: (val) => safeSetState(() {}),
                              controller: _model.radioButtonValueController ??=
                                  FormFieldController<String>('GPS'),
                              optionHeight: 42.0,
                              textStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: TextStyle(fontFamily: 'Roboto',
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                              selectedTextStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: TextStyle(fontFamily: 'Roboto',
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).info,
                                    fontSize: 18.0,
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              buttonPosition: RadioButtonPosition.left,
                              direction: Axis.horizontal,
                              radioButtonColor:
                                  FlutterFlowTheme.of(context).primary,
                              inactiveRadioButtonColor: const Color(0xFF2E363C),
                              toggleable: false,
                              horizontalAlignment: WrapAlignment.center,
                              verticalAlignment: WrapCrossAlignment.start,
                            ),
                          ],
                        ),
                      ].divide(const SizedBox(height: 5.0)),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                          child: Builder(
                            builder: (context) {
                              final activityStatusItem = functions
                                  .sortJsonByOrder(getJsonField(
                                    FFAppState().activitySelectedJSON,
                                    r'''$.activity_status''',
                                  ))
                                  .toList();

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                scrollDirection: Axis.vertical,
                                itemCount: activityStatusItem.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 5.0),
                                itemBuilder:
                                    (context, activityStatusItemIndex) {
                                  final activityStatusItemItem =
                                      activityStatusItem[
                                          activityStatusItemIndex];
                                  return Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Builder(
                                        builder: (context) => Padding(
                                          padding: const
                                              EdgeInsetsDirectional.fromSTEB(
                                                  15.0, 0.0, 15.0, 0.0),
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              HapticFeedback.vibrate();
                                              FFAppState().stopVoice = true;
                                              FFAppState().addToVisitDetails(
                                                  VisitsDetailsStruct(
                                                idVisitDetail: 0,
                                                idVisit: 0,
                                                idActivityStatus: getJsonField(
                                                  activityStatusItemItem,
                                                  r'''$.id_activity_status''',
                                                ),
                                                statusOption: getJsonField(
                                                  activityStatusItemItem,
                                                  r'''$.status_name''',
                                                ).toString(),
                                                statusResponse: getJsonField(
                                                  activityStatusItemItem,
                                                  r'''$.status_name''',
                                                ).toString(),
                                              ));
                                              FFAppState().update(() {});
                                              await actions.speakText(
                                                'Opción seleccionada. ',
                                              );
                                              FFAppState().stopVoice = false;
                                              if (_model.radioButtonValue ==
                                                  'GPS') {
                                                if (context.mounted) {
                                                  context.pushNamed(
                                                    LoadCoordinatesPageWidget
                                                        .routeName,
                                                    extra: <String, dynamic>{
                                                      kTransitionInfoKey:
                                                          const TransitionInfo(
                                                        hasTransition: true,
                                                        transitionType:
                                                            PageTransitionType
                                                                .fade,
                                                        duration: Duration(
                                                            milliseconds: 1000),
                                                      ),
                                                    },
                                                  );
                                                }
                                                return;
                                              } else {
                                                if (_model.radioButtonValue ==
                                                    'NFC') {
                                                  if (context.mounted) {
                                                    await showDialog(
                                                      barrierDismissible: false,
                                                      context: context,
                                                      builder: (dialogContext) {
                                                        return Dialog(
                                                          elevation: 0,
                                                          insetPadding:
                                                              EdgeInsets.zero,
                                                          backgroundColor:
                                                              Colors.transparent,
                                                          alignment:
                                                              const AlignmentDirectional(
                                                                      0.0, 0.0)
                                                                  .resolve(
                                                                      Directionality.of(
                                                                          context)),
                                                          child: GestureDetector(
                                                            onTap: () {
                                                              FocusScope.of(
                                                                      dialogContext)
                                                                  .unfocus();
                                                              FocusManager
                                                                  .instance
                                                                  .primaryFocus
                                                                  ?.unfocus();
                                                            },
                                                            child: SizedBox(
                                                              height: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .height *
                                                                  0.9,
                                                              width: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .width *
                                                                  0.9,
                                                              child:
                                                                  const ReadNFCComponentWidget(),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  }
                                                  return;
                                                } else {
                                                  if (context.mounted) {
                                                    _model.qrRead =
                                                        await actions.readQR(
                                                      context,
                                                    );
                                                    safeSetState(() {});
                                                  }
                                                  return;
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: MediaQuery.sizeOf(context)
                                                      .width *
                                                  1.0,
                                              height: 70.0,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF004628),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    blurRadius: 8.0,
                                                    color: Color(0x33000000),
                                                    offset: Offset(
                                                      0.0,
                                                      2.0,
                                                    ),
                                                  )
                                                ],
                                                borderRadius:
                                                    BorderRadius.circular(22.0),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        20.0, 0.0, 20.0, 0.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        getJsonField(
                                                          activityStatusItemItem,
                                                          r'''$.status_name''',
                                                        ).toString(),
                                                        textAlign:
                                                            TextAlign.start,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      TextStyle(
                                                                    fontFamily: 'Roboto',
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .info,
                                                                  fontSize:
                                                                      22.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.navigate_next,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .info,
                                                      size: 50.0,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        height: 71.27,
                        decoration: const BoxDecoration(),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              10.0, 5.0, 10.0, 10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    FFAppState().stopVoice = true;
                                    safeSetState(() {});
                                    context.safePop();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 8.0,
                                          color: Color(0x33000000),
                                          offset: Offset(
                                            0.0,
                                            2.0,
                                          ),
                                        )
                                      ],
                                      borderRadius: BorderRadius.circular(22.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Container(
                                          width: 50.0,
                                          height: 50.0,
                                          decoration: const BoxDecoration(),
                                          child: Icon(
                                            Icons.stop_circle,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            size: 30.0,
                                          ),
                                        ),
                                        Padding(
                                          padding: const
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 10.0, 0.0),
                                          child: Text(
                                            'Terminar',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: const TextStyle(fontFamily: 'Roboto',
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  fontSize: 20.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ].divide(const SizedBox(width: 10.0)),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    context.pushNamed(
                                      MapInstallPageWidget.routeName,
                                      queryParameters: {
                                        'idHeadquarter': serializeParam(
                                          0,
                                          ParamType.int,
                                        ),
                                      }.withoutNulls,
                                      extra: <String, dynamic>{
                                        kTransitionInfoKey: const TransitionInfo(
                                          hasTransition: true,
                                          transitionType:
                                              PageTransitionType.fade,
                                          duration:
                                              Duration(milliseconds: 1000),
                                        ),
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDA6B00),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 8.0,
                                          color: Color(0x33000000),
                                          offset: Offset(
                                            0.0,
                                            2.0,
                                          ),
                                        )
                                      ],
                                      borderRadius: BorderRadius.circular(22.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Container(
                                          width: 50.0,
                                          height: 50.0,
                                          decoration: const BoxDecoration(),
                                          child: Icon(
                                            Icons.map,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            size: 30.0,
                                          ),
                                        ),
                                        Padding(
                                          padding: const
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 9.0, 0.0),
                                          child: Text(
                                            'Recorrido',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: const TextStyle(fontFamily: 'Roboto',
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  fontSize: 20.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ].divide(const SizedBox(width: 10.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ].divide(const SizedBox(width: 10.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
