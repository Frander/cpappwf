import '/backend/schema/structs/index.dart';
import '/components/info_dialog_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'validation_sync_component_model.dart';
export 'validation_sync_component_model.dart';

class ValidationSyncComponentWidget extends StatefulWidget {
  const ValidationSyncComponentWidget({
    super.key,
    String? title,
    this.info,
  }) : this.title = title ?? 'Información';

  final String title;
  final String? info;

  @override
  State<ValidationSyncComponentWidget> createState() =>
      _ValidationSyncComponentWidgetState();
}

class _ValidationSyncComponentWidgetState
    extends State<ValidationSyncComponentWidget> {
  late ValidationSyncComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ValidationSyncComponentModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Align(
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 530.0,
          ),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 3.0,
                color: Color(0x33000000),
                offset: Offset(
                  0.0,
                  1.0,
                ),
              )
            ],
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: FlutterFlowTheme.of(context).primaryBackground,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 16.0),
                            child: Icon(
                              Icons.phone_iphone_outlined,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 44.0,
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Text(
                            '¿Está seguro que desea realizar la sincronización?',
                            textAlign: TextAlign.center,
                            style: FlutterFlowTheme.of(context)
                                .headlineMedium
                                .override(
                                  font: TextStyle(fontFamily: 'Roboto',
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).primary,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional(-1.0, -1.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 12.0, 0.0, 0.0),
                              child: Text(
                                'Si continúa con la sincronización se validará que tenga una conexión estable a internet esto puede tardar hasta 10 segundos.',
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: TextStyle(fontFamily: 'Roboto',
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                          text: 'Cancelar',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).error,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: TextStyle(fontFamily: 'Roboto',
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0.0,
                            borderSide: BorderSide(
                              color: Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(40.0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Builder(
                          builder: (context) => FFButtonWidget(
                            onPressed: () async {
                              var _shouldSetState = false;
                              _model.checkInternetConnectionJSON =
                                  await actions.checkInternetQuality();
                              _shouldSetState = true;
                              if (functions.jsonDynamicToBool(getJsonField(
                                    _model.checkInternetConnectionJSON,
                                    r'''$.isGoodConnection''',
                                  )) ==
                                  true) {
                                if ((FFAppState().visitsAdd.length > 0) ||
                                    (FFAppState().newsAdd.length > 0)) {
                                  _model.syncAddResult =
                                      await actions.syncVisitsv2(
                                    context,
                                    FFAppState().newsAdd.toList(),
                                    FFAppState().companyDefault.idCompany,
                                    functions.concatenateHeadquarterIds(
                                        FFAppState()
                                            .headquartersSelectedList
                                            .toList()),
                                    FFAppState().androidID,
                                    getJsonField(
                                      FFAppState().loginResponse,
                                      r'''$.token''',
                                    ).toString(),
                                  );
                                  _shouldSetState = true;
                                  FFAppState().loginResponse = null;
                                  FFAppState().userSelected = UsersStruct();
                                  FFAppState().companyDefault =
                                      CompaniesStruct();
                                  FFAppState().headquartersList = [];
                                  FFAppState().zonesList = [];
                                  FFAppState().productsList = [];
                                  FFAppState().lastSync =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          1743526800000);
                                  FFAppState().isSync = false;
                                  FFAppState().usersList = [];
                                  FFAppState().headquarterSelected =
                                      HeadquartersStruct();
                                  FFAppState().zoneSelected = ZonesStruct();
                                  FFAppState().visitsAdd = [];
                                  FFAppState().productsAdd = [];
                                  FFAppState().activitySelectedJSON = null;
                                  FFAppState().activityStatusSelectedJSON =
                                      null;
                                  FFAppState().activitiesJSON = null;
                                  FFAppState().newsAdd = [];
                                  FFAppState().newsList = [];
                                  FFAppState().newsSelected = [];

                                  context.pushNamed(
                                    StartPageWidget.routeName,
                                    extra: <String, dynamic>{
                                      kTransitionInfoKey: TransitionInfo(
                                        hasTransition: true,
                                        transitionType: PageTransitionType.fade,
                                        duration: Duration(milliseconds: 1000),
                                      ),
                                    },
                                  );

                                  if (_shouldSetState) safeSetState(() {});
                                  return;
                                } else {
                                  FFAppState().loginResponse = null;
                                  FFAppState().userSelected = UsersStruct();
                                  FFAppState().companyDefault =
                                      CompaniesStruct();
                                  FFAppState().headquartersList = [];
                                  FFAppState().zonesList = [];
                                  FFAppState().productsList = [];
                                  FFAppState().lastSync =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          1743526800000);
                                  FFAppState().isSync = false;
                                  FFAppState().usersList = [];
                                  FFAppState().headquarterSelected =
                                      HeadquartersStruct();
                                  FFAppState().zoneSelected = ZonesStruct();
                                  FFAppState().visitsAdd = [];
                                  FFAppState().productsAdd = [];
                                  FFAppState().activitySelectedJSON = null;
                                  FFAppState().activityStatusSelectedJSON =
                                      null;
                                  FFAppState().activitiesJSON = null;
                                  FFAppState().newsAdd = [];
                                  FFAppState().newsList = [];
                                  FFAppState().newsSelected = [];

                                  context.pushNamed(
                                    StartPageWidget.routeName,
                                    extra: <String, dynamic>{
                                      kTransitionInfoKey: TransitionInfo(
                                        hasTransition: true,
                                        transitionType: PageTransitionType.fade,
                                        duration: Duration(milliseconds: 1000),
                                      ),
                                    },
                                  );

                                  if (_shouldSetState) safeSetState(() {});
                                  return;
                                }
                              } else {
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
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                                0.5,
                                        width:
                                            MediaQuery.sizeOf(context).width *
                                                0.9,
                                        child: InfoDialogWidget(
                                          info: 'La señal es ${getJsonField(
                                            _model.checkInternetConnectionJSON,
                                            r'''$.message''',
                                          ).toString()}',
                                        ),
                                      ),
                                    );
                                  },
                                );

                                if (_shouldSetState) safeSetState(() {});
                                return;
                              }

                              if (_shouldSetState) safeSetState(() {});
                            },
                            text: 'Sincronizar ahora',
                            options: FFButtonOptions(
                              height: 40.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  20.0, 0.0, 20.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: TextStyle(fontFamily: 'Roboto',
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(40.0),
                            ),
                          ),
                        ),
                      ),
                    ].divide(SizedBox(width: 5.0)),
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
