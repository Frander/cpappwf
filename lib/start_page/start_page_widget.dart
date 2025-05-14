import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/components/info_dialog_widget.dart';
import '/components/keyboard_num_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'start_page_model.dart';
export 'start_page_model.dart';

class StartPageWidget extends StatefulWidget {
  const StartPageWidget({
    super.key,
    this.visitsAdd,
  });

  final List<VisitsStruct>? visitsAdd;

  static String routeName = 'StartPage';
  static String routePath = '/startPage';

  @override
  State<StartPageWidget> createState() => _StartPageWidgetState();
}

class _StartPageWidgetState extends State<StartPageWidget> {
  late StartPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StartPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.identifierCTR = await actions.getPersistentId(
        context,
      );
      _model.isConnection = await actions.checkConnection();
      if (_model.isConnection == true) {
        if ((FFAppState().lastSync == null) ||
            (functions.hasMoreThanAnHourPassed(
                    FFAppState().lastSync!, getCurrentTimestamp) ==
                true)) {
          _model.apiResultDevices =
              await APIClickPalmGroup.devicesFiltersGETCall.call(
            typeSearch: 'IMEI GENERAL',
            textSearch1: _model.identifierCTR,
            idCompany: 0,
            textSearch2: _model.identifierCTR,
          );

          if ((_model.apiResultDevices?.statusCode ?? 200) == 200) {
            _model.apiResultLoginDirect =
                await APIClickPalmGroup.usersLoginPOSTCall.call(
              typeLogin: 'IMEI',
              username: _model.identifierCTR,
            );

            if ((_model.apiResultLoginDirect?.succeeded ?? true)) {
              _model.urlRinexNavFile = await actions.getRinexNavFile(
                context,
              );
              _model.pathDatabase = await actions.getDatabase();
              FFAppState().pathDatabase = _model.pathDatabase!;
              FFAppState().androidID = _model.identifierCTR!;
              FFAppState().rinexNavFile = _model.urlRinexNavFile!;
              await actions.usersInserData(
                _model.pathDatabase!,
                'Users',
                (getJsonField(
                  (_model.apiResultLoginDirect?.jsonBody ?? ''),
                  r'''$.users''',
                  true,
                )!
                        .toList()
                        .map<UsersStruct?>(UsersStruct.maybeFromMap)
                        .toList() as Iterable<UsersStruct?>)
                    .withoutNulls
                    .toList(),
              );
              _model.usersSelectList = await actions.usersSelect(
                _model.pathDatabase!,
                'ALL',
                'ALL',
                'ALL',
              );
              FFAppState().loginResponse = getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$''',
              );
              FFAppState().userSelected = UsersStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.user_default''',
              ))!;
              FFAppState().companyDefault =
                  CompaniesStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.company''',
              ))!;
              FFAppState().deviceDefault =
                  DevicesStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.device_default''',
              ))!;
              FFAppState().headquartersList = (getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.headquarters''',
                true,
              )!
                      .toList()
                      .map<HeadquartersStruct?>(HeadquartersStruct.maybeFromMap)
                      .toList() as Iterable<HeadquartersStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<HeadquartersStruct>();
              FFAppState().zonesList = (getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.zones''',
                true,
              )!
                      .toList()
                      .map<ZonesStruct?>(ZonesStruct.maybeFromMap)
                      .toList() as Iterable<ZonesStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<ZonesStruct>();
              FFAppState().lastSync = getCurrentTimestamp;
              FFAppState().isSync = true;
              FFAppState().usersList =
                  _model.usersSelectList!.toList().cast<UsersStruct>();
              FFAppState().headquarterSelected = HeadquartersStruct();
              FFAppState().zoneSelected = ZonesStruct();
              FFAppState().activitiesJSON = getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.activities''',
              );
              FFAppState().headquartersSelectedList = [];
              FFAppState().newsList = (getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.news''',
                true,
              )!
                      .toList()
                      .map<NewsStruct?>(NewsStruct.maybeFromMap)
                      .toList() as Iterable<NewsStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<NewsStruct>();
              if (Navigator.of(context).canPop()) {
                context.pop();
              }
              context.pushNamed(
                ModulesPageWidget.routeName,
                extra: <String, dynamic>{
                  kTransitionInfoKey: TransitionInfo(
                    hasTransition: true,
                    transitionType: PageTransitionType.fade,
                    duration: Duration(milliseconds: 1000),
                  ),
                },
              );

              return;
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
                    child: GestureDetector(
                      onTap: () {
                        FocusScope.of(dialogContext).unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Container(
                        height: MediaQuery.sizeOf(context).height * 0.6,
                        width: MediaQuery.sizeOf(context).width * 0.6,
                        child: InfoDialogWidget(
                          info:
                              'Error encontrando los datos intentalo de nuevo cuando tengas internet!',
                        ),
                      ),
                    ),
                  );
                },
              );

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
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(dialogContext).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: Container(
                      height: MediaQuery.sizeOf(context).height * 0.6,
                      width: MediaQuery.sizeOf(context).width * 0.8,
                      child: InfoDialogWidget(
                        info:
                            'El dispositivo CTR con IMEI ${_model.identifierCTR} no se encuentra en nuestro sistema a continuación, deberá registrar el CTR utilizando el código de un supervisor',
                      ),
                    ),
                  ),
                );
              },
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
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(dialogContext).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: Container(
                      height: MediaQuery.sizeOf(context).height * 0.95,
                      width: MediaQuery.sizeOf(context).width * 0.95,
                      child: KeyboardNumComponentWidget(
                        tittle: 'Ingrese el código del supervisor',
                      ),
                    ),
                  ),
                );
              },
            );

            _model.apiResultLoginRegister =
                await APIClickPalmGroup.usersLoginPOSTCall.call(
              typeLogin: 'IMEI',
              username: _model.identifierCTR,
              password: FFAppState().codeKeyboard,
            );

            if ((_model.apiResultLoginRegister?.succeeded ?? true)) {
              FFAppState().loginResponse = getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$''',
              );
              FFAppState().userSelected = UsersStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.user_default''',
              ))!;
              FFAppState().companyDefault =
                  CompaniesStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.company''',
              ))!;
              FFAppState().deviceDefault =
                  DevicesStruct.maybeFromMap(getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.device_default''',
              ))!;
              FFAppState().headquartersList = (getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.headquarters''',
                true,
              )!
                      .toList()
                      .map<HeadquartersStruct?>(HeadquartersStruct.maybeFromMap)
                      .toList() as Iterable<HeadquartersStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<HeadquartersStruct>();
              FFAppState().usersList = (getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.users''',
                true,
              )!
                      .toList()
                      .map<UsersStruct?>(UsersStruct.maybeFromMap)
                      .toList() as Iterable<UsersStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<UsersStruct>();
              FFAppState().activitiesJSON = getJsonField(
                (_model.apiResultLoginRegister?.jsonBody ?? ''),
                r'''$.activities''',
              );
              if (Navigator.of(context).canPop()) {
                context.pop();
              }
              context.pushNamed(
                ModulesPageWidget.routeName,
                extra: <String, dynamic>{
                  kTransitionInfoKey: TransitionInfo(
                    hasTransition: true,
                    transitionType: PageTransitionType.fade,
                    duration: Duration(milliseconds: 1000),
                  ),
                },
              );

              return;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Verifique la conexión a internet',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                  ),
                  duration: Duration(milliseconds: 3750),
                  backgroundColor: FlutterFlowTheme.of(context).error,
                ),
              );
              return;
            }
          }
        } else {
          if (Navigator.of(context).canPop()) {
            context.pop();
          }
          context.pushNamed(
            ModulesPageWidget.routeName,
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.fade,
                duration: Duration(milliseconds: 1000),
              ),
            },
          );

          return;
        }
      } else {
        if (FFAppState().isSync == true) {
          if (Navigator.of(context).canPop()) {
            context.pop();
          }
          context.pushNamed(
            ModulesPageWidget.routeName,
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.fade,
                duration: Duration(milliseconds: 1000),
              ),
            },
          );
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
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(dialogContext).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    child: InfoDialogWidget(
                      info:
                          'No tiene conexión a internet y es la primera vez que se inicia el dispositivo, debe conectar el teléfono y proceder a iniciar de nuevo la aplicación',
                    ),
                  ),
                ),
              );
            },
          );

          return;
        }

        return;
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: Image.asset(
                  'assets/images/Fondoo56_Mesa-de-trabajo-1.jpg',
                ).image,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: 122.0,
                    decoration: BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            width: 210.0,
                            height: double.infinity,
                            decoration: BoxDecoration(),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 5.0, 0.0, 0.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  'assets/images/Clickpalmlogo1-removebg-preview.png',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 0.0, 20.0, 0.0),
                                  child: Text(
                                    'Estamos cargando todos los recursos necesarios',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: 22.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                                Text(
                                  'Espera un momento',
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        fontSize: 18.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ].divide(SizedBox(height: 20.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(),
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              height: 100.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    10.0, 5.0, 5.0, 5.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.asset(
                                          'assets/images/Animation_-_1737696401114.gif',
                                          width: 91.47,
                                          height: 171.0,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ].divide(SizedBox(height: 15.0)),
                        ),
                      ),
                    ),
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
