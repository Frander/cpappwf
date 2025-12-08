import '/activities/status_activity_main/status_activity_main_widget.dart';
import '/activities/steps_activity_main/steps_activity_main_widget.dart';
import '/backend/schema/structs/index.dart';
import '/components/calculate_coordenates_component_widget.dart';
import '/components/keyboard_num_component_widget.dart';
import '/components/text_field_control_component_widget.dart';
import '/components/photo_capture_component_widget.dart';
import '/components/date_picker_component_widget.dart';
import '/components/time_picker_component_widget.dart';
import '/components/nfc_tag_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'steps_main_model.dart';
export 'steps_main_model.dart';

class StepsMainWidget extends StatefulWidget {
  const StepsMainWidget({
    super.key,
    required this.activityMain,
  });

  final dynamic activityMain;

  @override
  State<StepsMainWidget> createState() => _StepsMainWidgetState();
}

class _StepsMainWidgetState extends State<StepsMainWidget> {
  late StepsMainModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StepsMainModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).newBg,
              boxShadow: [
                BoxShadow(
                  blurRadius: 4.0,
                  color: Color(0x33000000),
                  offset: Offset(
                    0.0,
                    2.0,
                  ),
                )
              ],
              borderRadius: BorderRadius.circular(0.0),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(5.0, 8.0, 5.0, 8.0),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                scrollDirection: Axis.vertical,
                children: [
                  if (functions.checkIfFieldIsList(
                      getJsonField(
                        widget!.activityMain,
                        r'''$''',
                      ),
                      'activity_steps'))
                    Builder(
                      builder: (context) {
                        final activityStepItem = getJsonField(
                          FFAppState().currentActivity,
                          r'''$.activity_steps''',
                        ).toList();

                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          primary: false,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          itemCount: activityStepItem.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10.0),
                          itemBuilder: (context, activityStepItemIndex) {
                            final activityStepItemItem =
                                activityStepItem[activityStepItemIndex];
                            return Builder(
                              builder: (context) => Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    5.0, 0.0, 5.0, 0.0),
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    if (functions.checkIfFieldIsList(
                                        getJsonField(
                                          activityStepItemItem,
                                          r'''$''',
                                        ),
                                        'activities_status')) {
                                      await showDialog(
                                        context: context,
                                        builder: (dialogContext) {
                                          return Dialog(
                                            elevation: 0,
                                            insetPadding: EdgeInsets.zero,
                                            backgroundColor: Colors.transparent,
                                            alignment: AlignmentDirectional(
                                                    0.0, 0.0)
                                                .resolve(
                                                    Directionality.of(context)),
                                            child: Container(
                                              height: MediaQuery.sizeOf(context)
                                                      .height *
                                                  0.95,
                                              width: MediaQuery.sizeOf(context)
                                                      .width *
                                                  0.95,
                                              child: StepsActivityMainWidget(
                                                stepsActivityMain: getJsonField(
                                                  activityStepItemItem,
                                                  r'''$''',
                                                ),
                                                idStepParent: functions
                                                    .dynamicToInt(getJsonField(
                                                  activityStepItemItem,
                                                  r'''$.id_activity_step''',
                                                )),
                                              ),
                                            ),
                                          );
                                        },
                                      );

                                      return;
                                    } else {
                                      return;
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: functions.searchInVisitsDetails(
                                              FFAppState()
                                                  .visitDetails
                                                  .toList(),
                                              functions
                                                  .dynamicToInt(getJsonField(
                                                activityStepItemItem,
                                                r'''$.id_activity_step''',
                                              )),
                                              'STEP')
                                          ? Color(0xFF8EBDA2)
                                          : FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 4.0,
                                          color: Color(0x33000000),
                                          offset: Offset(
                                            0.0,
                                            2.0,
                                          ),
                                        )
                                      ],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 2.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        if (functions.showCurrentStatus(
                                                FFAppState()
                                                    .visitDetails
                                                    .toList(),
                                                getJsonField(
                                                  activityStepItemItem,
                                                  r'''$.id_activity_step''',
                                                )) !=
                                            'N/A')
                                          Align(
                                            alignment: AlignmentDirectional(
                                                -1.0, -1.0),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(5.0, 2.0, 0.0, 0.0),
                                              child: Text(
                                                '${getJsonField(
                                                  activityStepItemItem,
                                                  r'''$.name_step''',
                                                ).toString()}',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              TextStyle(fontFamily: 'Roboto',
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  10.0, 5.0, 10.0, 5.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${functions.showCurrentStatus(FFAppState().visitDetails.toList(), getJsonField(
                                                        activityStepItemItem,
                                                        r'''$.id_activity_step''',
                                                      )) == 'N/A' ? getJsonField(
                                                      activityStepItemItem,
                                                      r'''$.name_step''',
                                                    ).toString() : '${functions.showCurrentStatus(FFAppState().visitDetails.toList(), getJsonField(
                                                        activityStepItemItem,
                                                        r'''$.id_activity_step''',
                                                      ))}'}',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .headlineSmall
                                                      .override(
                                                        font: TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .headlineSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .headlineSmall
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 25.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .headlineSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .headlineSmall
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                              if (functions
                                                      .searchInVisitsDetails(
                                                          FFAppState()
                                                              .visitDetails
                                                              .toList(),
                                                          functions
                                                              .dynamicToInt(
                                                                  getJsonField(
                                                            activityStepItemItem,
                                                            r'''$.id_activity_step''',
                                                          )),
                                                          'STEP') ==
                                                  true)
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                  child: Image.asset(
                                                    'assets/images/check-mark-button-svgrepo-com.png',
                                                    width: 30.0,
                                                    height: 30.0,
                                                    fit: BoxFit.cover,
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
                          },
                          controller: _model.listViewController1,
                        );
                      },
                    ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 10.0),
                    child: Builder(
                      builder: (context) {
                        final statusItem = getJsonField(
                          widget!.activityMain,
                          r'''$.activity_status''',
                        ).toList();

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          primary: false,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          itemCount: statusItem.length,
                          itemBuilder: (context, statusItemIndex) {
                            final statusItemItem = statusItem[statusItemIndex];
                            return Builder(
                              builder: (context) {
                                if (functions.jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'unique-option') {
                                  return Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 5.0, 16.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 12.0, 8.0, 12.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 18.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFF7C8791),
                                              size: 24.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'number') {
                                  return Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        5.0, 12.0, 5.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: functions.searchInVisitsDetails(
                                                FFAppState()
                                                    .visitDetails
                                                    .toList(),
                                                functions
                                                    .dynamicToInt(getJsonField(
                                                  statusItemItem,
                                                  r'''$.id_activity_status''',
                                                )),
                                                'STATUS')
                                            ? Color(0xFF8EBDA2)
                                            : FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    15.0, 5.0, 0.0, 0.0),
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(),
                                              child: Text(
                                                getJsonField(
                                                  statusItemItem,
                                                  r'''$.status_name''',
                                                ).toString(),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              TextStyle(fontFamily: 'Roboto',
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                          fontSize: 18.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 5.0, 8.0, 5.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                5.0, 0.0),
                                                    child: Text(
                                                      '${functions.statusResponseByActivityStatusAlternative(functions.dynamicToInt(getJsonField(
                                                            statusItemItem,
                                                            r'''$.id_activity_status''',
                                                          )), FFAppState().visitDetails.toList(), 0) == '' ? '0' : functions.statusResponseByActivityStatusAlternative(functions.dynamicToInt(getJsonField(
                                                            statusItemItem,
                                                            r'''$.id_activity_status''',
                                                          )), FFAppState().visitDetails.toList(), 0)}',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyLarge
                                                          .override(
                                                            font: TextStyle(
                                                              fontFamily: 'Roboto',
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                            ),
                                                            fontSize: 20.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                if (functions
                                                        .searchInVisitsDetails(
                                                            FFAppState()
                                                                .visitDetails
                                                                .toList(),
                                                            functions
                                                                .dynamicToInt(
                                                                    getJsonField(
                                                              statusItemItem,
                                                              r'''$.id_activity_status''',
                                                            )),
                                                            'STATUS') ==
                                                    true)
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    child: Image.asset(
                                                      'assets/images/check-mark-button-svgrepo-com.png',
                                                      width: 30.0,
                                                      height: 30.0,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              final number = FFAppConstants
                                                  .numOptions
                                                  .toList();

                                              return Flex(
                                                direction: Axis.horizontal,
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: List.generate(
                                                        number.length,
                                                        (numberIndex) {
                                                  final numberItem =
                                                      number[numberIndex];
                                                  return InkWell(
                                                    splashColor:
                                                        Colors.transparent,
                                                    focusColor:
                                                        Colors.transparent,
                                                    hoverColor:
                                                        Colors.transparent,
                                                    highlightColor:
                                                        Colors.transparent,
                                                    onTap: () async {
                                                      FFAppState().codeKeyboard = functions
                                                          .statusResponseByActivityStatusAlternative(
                                                              functions
                                                                  .dynamicToInt(
                                                                      getJsonField(
                                                                statusItemItem,
                                                                r'''$.id_activity_status''',
                                                              )),
                                                              FFAppState()
                                                                  .visitDetails
                                                                  .toList(),
                                                              0);
                                                      FFAppState()
                                                          .update(() {});
                                                      _model.visitDetail =
                                                          await actions
                                                              .updateOrAddVisitDetail(
                                                        FFAppState()
                                                            .visitDetails
                                                            .toList(),
                                                        getJsonField(
                                                          statusItemItem,
                                                          r'''$.id_activity_status''',
                                                        ),
                                                        0,
                                                        getJsonField(
                                                          statusItemItem,
                                                          r'''$.status_name''',
                                                        ).toString(),
                                                        numberItem.toString(),
                                                        getJsonField(
                                                          statusItemItem,
                                                          r'''$.remember_status''',
                                                        ),
                                                        getJsonField(
                                                          statusItemItem,
                                                          r'''$.default_status''',
                                                        ).toString(),
                                                        0,
                                                      );
                                                      FFAppState()
                                                              .visitDetails =
                                                          _model.visitDetail!
                                                              .toList()
                                                              .cast<
                                                                  VisitsDetailsStruct>();

                                                      safeSetState(() {});
                                                    },
                                                    child: Card(
                                                      clipBehavior: Clip
                                                          .antiAliasWithSaveLayer,
                                                      color: functions
                                                                  .statusResponseByActivityStatusAlternative(
                                                                      getJsonField(
                                                                        statusItemItem,
                                                                        r'''$.id_activity_status''',
                                                                      ),
                                                                      FFAppState()
                                                                          .visitDetails
                                                                          .toList(),
                                                                      0) ==
                                                              '${numberItem.toString()}'
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .orange
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      elevation: 0.0,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(
                                                            20.0),
                                                        child: Text(
                                                          numberItem.toString(),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    TextStyle(
                                                                  fontFamily: 'Roboto',
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .info,
                                                                fontSize: 40.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                })
                                                    .divide(true
                                                        ? SizedBox(width: 10.0)
                                                        : SizedBox(
                                                            height: 10.0))
                                                    .addToStart(true
                                                        ? SizedBox(width: 10.0)
                                                        : SizedBox(
                                                            height: 10.0)),
                                              );
                                            },
                                          ),
                                          Builder(
                                            builder: (context) => Padding(
                                              padding: EdgeInsets.all(5.0),
                                              child: FFButtonWidget(
                                                onPressed: () async {
                                                  FFAppState().codeKeyboard = functions
                                                      .statusResponseByActivityStatusAlternative(
                                                          functions
                                                              .dynamicToInt(
                                                                  getJsonField(
                                                            statusItemItem,
                                                            r'''$.id_activity_status''',
                                                          )),
                                                          FFAppState()
                                                              .visitDetails
                                                              .toList(),
                                                          0);
                                                  await showDialog(
                                                    context: context,
                                                    builder: (dialogContext) {
                                                      return Dialog(
                                                        elevation: 0,
                                                        insetPadding:
                                                            EdgeInsets.zero,
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        alignment:
                                                            AlignmentDirectional(
                                                                    0.0, 0.0)
                                                                .resolve(
                                                                    Directionality.of(
                                                                        context)),
                                                        child: Container(
                                                          height:
                                                              MediaQuery.sizeOf(
                                                                          context)
                                                                      .height *
                                                                  0.9,
                                                          width:
                                                              MediaQuery.sizeOf(
                                                                          context)
                                                                      .width *
                                                                  0.9,
                                                          child:
                                                              KeyboardNumComponentWidget(
                                                            tittle:
                                                                'Digite ${getJsonField(
                                                              statusItemItem,
                                                              r'''$.status_name''',
                                                            ).toString()}',
                                                            isBackButton: true,
                                                            idStatus:
                                                                getJsonField(
                                                              statusItemItem,
                                                              r'''$.id_activity_status''',
                                                            ),
                                                            statusName:
                                                                getJsonField(
                                                              statusItemItem,
                                                              r'''$.status_name''',
                                                            ).toString(),
                                                            statusJSON:
                                                                getJsonField(
                                                              statusItemItem,
                                                              r'''$''',
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                                text: 'Otro Valor',
                                                options: FFButtonOptions(
                                                  width:
                                                      MediaQuery.sizeOf(context)
                                                              .width *
                                                          0.9,
                                                  height: 50.0,
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          16.0, 0.0, 16.0, 0.0),
                                                  iconPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(0.0, 0.0,
                                                              0.0, 0.0),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .orange,
                                                  textStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .titleSmall
                                                      .override(
                                                        font: TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                        color: Colors.white,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                  elevation: 0.0,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'text') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          if (functions.isFieldList(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$''',
                                                  ),
                                                  'activities_steps_childs') ==
                                              true) {
                                            FFAppState().addToVisitDetails(
                                                VisitsDetailsStruct(
                                              idVisitDetail: 0,
                                              idVisit: 0,
                                              idActivityStatus: getJsonField(
                                                statusItemItem,
                                                r'''$.id_activity_status''',
                                              ),
                                              statusOption: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                              statusResponse: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                            ));
                                            safeSetState(() {});
                                            await showDialog(
                                              barrierDismissible: false,
                                              context: context,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  elevation: 0,
                                                  insetPadding: EdgeInsets.zero,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  alignment:
                                                      AlignmentDirectional(
                                                              0.0, 0.0)
                                                          .resolve(
                                                              Directionality.of(
                                                                  context)),
                                                  child: Container(
                                                    height: MediaQuery.sizeOf(
                                                                context)
                                                            .height *
                                                        0.95,
                                                    width: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.95,
                                                    child:
                                                        StepsActivityMainWidget(
                                                      stepsActivityMain:
                                                          getJsonField(
                                                        statusItemItem,
                                                        r'''$.activities_steps_childs''',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );

                                            return;
                                          } else {
                                            FFAppState().addToVisitDetails(
                                                VisitsDetailsStruct(
                                              idVisitDetail: 0,
                                              idVisit: 0,
                                              idActivityStatus: getJsonField(
                                                statusItemItem,
                                                r'''$.id_activity_status''',
                                              ),
                                              statusOption: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                              statusResponse: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                            ));
                                            safeSetState(() {});
                                            await showDialog(
                                              barrierDismissible: false,
                                              context: context,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  elevation: 0,
                                                  insetPadding: EdgeInsets.zero,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  alignment:
                                                      AlignmentDirectional(
                                                              0.0, 0.0)
                                                          .resolve(
                                                              Directionality.of(
                                                                  context)),
                                                  child: Container(
                                                    height: MediaQuery.sizeOf(
                                                                context)
                                                            .height *
                                                        0.9,
                                                    width: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.9,
                                                    child:
                                                        CalculateCoordenatesComponentWidget(),
                                                  ),
                                                );
                                              },
                                            );

                                            Navigator.pop(context);
                                            return;
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child:
                                                      TextFieldControlComponentWidget(
                                                    key: Key(
                                                        'Keyqlx_${statusItemIndex}_of_${statusItem.length}'),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'date') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          await showDialog(
                                            barrierDismissible: false,
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                insetPadding: EdgeInsets.zero,
                                                backgroundColor:
                                                    Colors.transparent,
                                                alignment:
                                                    AlignmentDirectional(0.0, 0.0)
                                                        .resolve(
                                                            Directionality.of(
                                                                context)),
                                                child: Container(
                                                  height: MediaQuery.sizeOf(
                                                              context)
                                                          .height *
                                                      0.9,
                                                  width: MediaQuery.sizeOf(context)
                                                          .width *
                                                      0.9,
                                                  child:
                                                      DatePickerComponentWidget(
                                                    tittle: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    idStatus: functions
                                                        .dynamicToInt(getJsonField(
                                                      statusItemItem,
                                                      r'''$.id_activity_status''',
                                                    )),
                                                    statusName: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    statusJSON: getJsonField(
                                                      statusItemItem,
                                                      r'''$''',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'time') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          await showDialog(
                                            barrierDismissible: false,
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                insetPadding: EdgeInsets.zero,
                                                backgroundColor:
                                                    Colors.transparent,
                                                alignment:
                                                    AlignmentDirectional(0.0, 0.0)
                                                        .resolve(
                                                            Directionality.of(
                                                                context)),
                                                child: Container(
                                                  height: MediaQuery.sizeOf(
                                                              context)
                                                          .height *
                                                      0.9,
                                                  width: MediaQuery.sizeOf(context)
                                                          .width *
                                                      0.9,
                                                  child:
                                                      TimePickerComponentWidget(
                                                    tittle: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    idStatus: functions
                                                        .dynamicToInt(getJsonField(
                                                      statusItemItem,
                                                      r'''$.id_activity_status''',
                                                    )),
                                                    statusName: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    statusJSON: getJsonField(
                                                      statusItemItem,
                                                      r'''$''',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'photo') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          await showDialog(
                                            barrierDismissible: false,
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                insetPadding: EdgeInsets.zero,
                                                backgroundColor:
                                                    Colors.transparent,
                                                alignment:
                                                    AlignmentDirectional(0.0, 0.0)
                                                        .resolve(
                                                            Directionality.of(
                                                                context)),
                                                child: Container(
                                                  height: MediaQuery.sizeOf(
                                                              context)
                                                          .height *
                                                      0.9,
                                                  width: MediaQuery.sizeOf(context)
                                                          .width *
                                                      0.9,
                                                  child:
                                                      PhotoCaptureComponentWidget(
                                                    tittle: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    idStatus: functions
                                                        .dynamicToInt(getJsonField(
                                                      statusItemItem,
                                                      r'''$.id_activity_status''',
                                                    )),
                                                    statusName: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    statusJSON: getJsonField(
                                                      statusItemItem,
                                                      r'''$''',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'tag-reader') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          await showDialog(
                                            barrierDismissible: false,
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                insetPadding: EdgeInsets.zero,
                                                backgroundColor:
                                                    Colors.transparent,
                                                alignment:
                                                    AlignmentDirectional(0.0, 0.0)
                                                        .resolve(
                                                            Directionality.of(
                                                                context)),
                                                child: Container(
                                                  height: MediaQuery.sizeOf(
                                                              context)
                                                          .height *
                                                      0.9,
                                                  width: MediaQuery.sizeOf(context)
                                                          .width *
                                                      0.9,
                                                  child: NfcTagComponentWidget(
                                                    tittle: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    idStatus: functions
                                                        .dynamicToInt(getJsonField(
                                                      statusItemItem,
                                                      r'''$.id_activity_status''',
                                                    )),
                                                    statusName: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    statusJSON: getJsonField(
                                                      statusItemItem,
                                                      r'''$''',
                                                    ),
                                                    isWriter: false,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (functions
                                        .jsonDynamicToString(getJsonField(
                                      statusItemItem,
                                      r'''$.type_status''',
                                    )) ==
                                    'tag-writer') {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          await showDialog(
                                            barrierDismissible: false,
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                insetPadding: EdgeInsets.zero,
                                                backgroundColor:
                                                    Colors.transparent,
                                                alignment:
                                                    AlignmentDirectional(0.0, 0.0)
                                                        .resolve(
                                                            Directionality.of(
                                                                context)),
                                                child: Container(
                                                  height: MediaQuery.sizeOf(
                                                              context)
                                                          .height *
                                                      0.9,
                                                  width: MediaQuery.sizeOf(context)
                                                          .width *
                                                      0.9,
                                                  child: NfcTagComponentWidget(
                                                    tittle: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    idStatus: functions
                                                        .dynamicToInt(getJsonField(
                                                      statusItemItem,
                                                      r'''$.id_activity_status''',
                                                    )),
                                                    statusName: getJsonField(
                                                      statusItemItem,
                                                      r'''$.status_name''',
                                                    ).toString(),
                                                    statusJSON: getJsonField(
                                                      statusItemItem,
                                                      r'''$''',
                                                    ),
                                                    isWriter: true,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Builder(
                                    builder: (context) => Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 12.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          HapticFeedback.vibrate();
                                          if (functions.isFieldList(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$''',
                                                  ),
                                                  'activities_steps_childs') ==
                                              true) {
                                            FFAppState().addToVisitDetails(
                                                VisitsDetailsStruct(
                                              idVisitDetail: 0,
                                              idVisit: 0,
                                              idActivityStatus: getJsonField(
                                                statusItemItem,
                                                r'''$.id_activity_status''',
                                              ),
                                              statusOption: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                              statusResponse: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                            ));
                                            safeSetState(() {});
                                            await showDialog(
                                              barrierDismissible: false,
                                              context: context,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  elevation: 0,
                                                  insetPadding: EdgeInsets.zero,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  alignment:
                                                      AlignmentDirectional(
                                                              0.0, 0.0)
                                                          .resolve(
                                                              Directionality.of(
                                                                  context)),
                                                  child: Container(
                                                    height: MediaQuery.sizeOf(
                                                                context)
                                                            .height *
                                                        0.95,
                                                    width: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.95,
                                                    child:
                                                        StatusActivityMainWidget(
                                                      statusActivityMain:
                                                          getJsonField(
                                                        statusItemItem,
                                                        r'''$''',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );

                                            return;
                                          } else {
                                            FFAppState().addToVisitDetails(
                                                VisitsDetailsStruct(
                                              idVisitDetail: 0,
                                              idVisit: 0,
                                              idActivityStatus: getJsonField(
                                                statusItemItem,
                                                r'''$.id_activity_status''',
                                              ),
                                              statusOption: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                              statusResponse: getJsonField(
                                                statusItemItem,
                                                r'''$.status_name''',
                                              ).toString(),
                                            ));
                                            safeSetState(() {});
                                            Navigator.pop(context);
                                            return;
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 8.0, 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  getJsonField(
                                                    statusItemItem,
                                                    r'''$.status_name''',
                                                  ).toString(),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: TextStyle(fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: Color(0xFF7C8791),
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          controller: _model.listViewController2,
                        );
                      },
                    ),
                  ),
                ],
                controller: _model.listViewMainScrollController,
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional(1.0, 1.0),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 20.0),
            child: FloatingActionButton(
              onPressed: () async {
                unawaited(
                  () async {
                    await _model.listViewMainScrollController?.animateTo(
                      _model.listViewMainScrollController!.position
                          .maxScrollExtent,
                      duration: Duration(milliseconds: 100),
                      curve: Curves.ease,
                    );
                  }(),
                );
              },
              backgroundColor: FlutterFlowTheme.of(context).orange,
              elevation: 8.0,
              child: Icon(
                Icons.arrow_downward,
                color: FlutterFlowTheme.of(context).info,
                size: 24.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
