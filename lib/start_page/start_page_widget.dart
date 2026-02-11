import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/components/info_dialog_widget.dart';
import '/components/device_selection_grid_widget.dart';
import '/components/sync_loading_widget.dart';
import '/components/device_registration_loading_widget.dart';
import '/components/device_registration_form_widget.dart';
import '/components/supervisor_code_keyboard_widget.dart';
import '/components/connection_retry_dialog_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
      // Paso 1: Obteniendo ID del dispositivo
      _updateProgress(1, 'Identificando dispositivo...');
      await Future.delayed(Duration(milliseconds: 500));

      _model.identifierCTR = await actions.getPersistentId(
        context,
      );
      _model.pathDBSQLite1 = await actions.validateDbSqlite(
        context,
      );
      FFAppState().pathDatabase = _model.pathDBSQLite1!;

      // Debug: Verificar estado actual (deviceDefault está persistido en AppState)
      debugPrint('🔍 DEBUG StartPage - Estado actual:');
      debugPrint('   isSync: ${FFAppState().isSync}');
      debugPrint('   deviceDefault.idDevice: ${FFAppState().deviceDefault.idDevice}');
      debugPrint('   deviceDefault.imeI1: ${FFAppState().deviceDefault.imeI1}');
      debugPrint('   deviceDefault.deviceName: ${FFAppState().deviceDefault.deviceName}');
      debugPrint('   UUID del dispositivo: ${_model.identifierCTR}');

      if (FFAppState().isSync == true) {
        // El servicio de geolocalización se iniciará en HomePage al cargar por primera vez
        // debugPrint('🚀 Iniciando servicio de geolocalización en segundo plano...');
        // await actions.startBackgroundLocationService();

        if (Navigator.of(context).canPop()) {
          context.pop();
        }
        context.pushNamed(
          LoginPageWidget.routeName,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 1000),
            ),
          },
        );

        return;
      } else if (FFAppState().isSync == false &&
                 (FFAppState().deviceDefault.idDevice > 0 ||
                  (_model.identifierCTR != null && _model.identifierCTR!.isNotEmpty))) {
        // Si isSync es false Y (deviceDefault existe O tenemos UUID válido),
        // hacer login directo sin mostrar selección de empresa/CTR
        if (FFAppState().deviceDefault.idDevice > 0) {
          debugPrint('🔵 Device default ya existe (ID: ${FFAppState().deviceDefault.idDevice}), haciendo login directo...');
        } else {
          debugPrint('🔵 No hay device default pero existe UUID (${_model.identifierCTR}), haciendo login directo...');
        }

        // Paso 2: Verificando conexión a internet con reintentos
        _updateProgress(2, 'Verificando conexión a internet...');
        await Future.delayed(Duration(milliseconds: 400));

        // Verificar conexión con reintentos automáticos durante 5 minutos
        final hasConnection = await _checkConnectionWithRetry();
        if (hasConnection) {
          // Paso 3: Iniciando sesión
          _updateProgress(3, 'Iniciando sesión de forma segura...');
          await Future.delayed(Duration(milliseconds: 400));

          // Usar el IMEI/identificador del deviceDefault para login
          String loginIdentifier = FFAppState().deviceDefault.imeI1.isNotEmpty
              ? FFAppState().deviceDefault.imeI1
              : _model.identifierCTR!;

          debugPrint('🔵 Realizando login con IMEI: $loginIdentifier');
          _model.apiResultLoginDirect =
              await APIClickPalmGroup.usersLoginPOSTCall.call(
            typeLogin: 'IMEI',
            username: loginIdentifier,
          );

          debugPrint('🔍 API Login Response:');
          debugPrint('   succeeded: ${_model.apiResultLoginDirect?.succeeded}');
          debugPrint('   statusCode: ${_model.apiResultLoginDirect?.statusCode}');
          debugPrint('   jsonBody: ${_model.apiResultLoginDirect?.jsonBody}');

          if ((_model.apiResultLoginDirect?.succeeded ?? true)) {
            // Paso 4: Sincronizando datos
            _updateProgress(4, 'Sincronizando información del usuario...');
            await Future.delayed(Duration(milliseconds: 400));

            try {
              _model.pathDBSQLite = await actions.validateDbSqlite(
                context,
              );
              debugPrint('✅ Database validated: ${_model.pathDBSQLite}');

              debugPrint('🔄 Iniciando syncLogin...');
              _model.customSyncLoginResult = await actions.syncLogin(
                context,
                loginIdentifier,
                loginIdentifier,
                getJsonField(
                  (_model.apiResultLoginDirect?.jsonBody ?? ''),
                  r'''$''',
                ),
              );
              debugPrint('✅ syncLogin completado: ${_model.customSyncLoginResult}');
            } catch (e, stackTrace) {
              debugPrint('❌ ERROR CRÍTICO en syncLogin: $e');
              debugPrint('Stack trace: $stackTrace');
              rethrow; // Re-lanzar para que se maneje arriba
            }
            FFAppState().pathDatabase = _model.pathDBSQLite!;
            FFAppState().androidID = loginIdentifier;
            FFAppState().loginResponse = getJsonField(
              (_model.apiResultLoginDirect?.jsonBody ?? ''),
              r'''$''',
            );
            FFAppState().userSelected =
                UsersStruct.maybeFromMap(getJsonField(
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
                    .map<HeadquartersStruct?>(
                        HeadquartersStruct.maybeFromMap)
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
            FFAppState().usersList = (getJsonField(
              (_model.apiResultLoginDirect?.jsonBody ?? ''),
              r'''$.users''',
              true,
            )!
                    .toList()
                    .map<UsersStruct?>(UsersStruct.maybeFromMap)
                    .toList() as Iterable<UsersStruct?>)
                .withoutNulls
                .toList()
                .cast<UsersStruct>();
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
            FFAppState().isStabilized = false;
            FFAppState().visitDetails = [];

            debugPrint('✅ Login directo completado, navegando a HomePage');

            // El servicio de geolocalización se iniciará en HomePage al cargar por primera vez
            // debugPrint('🚀 Iniciando servicio de geolocalización en segundo plano...');
            // await actions.startBackgroundLocationService();

            if (Navigator.of(context).canPop()) {
              context.pop();
            }
            context.pushNamed(
              LoginPageWidget.routeName,
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
            // El IMEI no existe en la base de datos, validar supervisor primero
            debugPrint('⚠️ IMEI no registrado, solicitando código de supervisor');

            // Cerrar el diálogo de progreso
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            }

            // PASO 1: Validar código de supervisor (reemplaza selección de empresa)
            CompaniesStruct? selectedCompany;
            bool supervisorValidated = false;

            while (!supervisorValidated) {
              // Mostrar teclado de supervisor
              String? enteredCode = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  return PopScope(
                    canPop: false,
                    child: Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        child: SupervisorCodeKeyboardWidget(
                          onCodeEntered: (String code) async {
                            Navigator.pop(dialogContext, code);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );

              if (enteredCode == null || enteredCode.isEmpty) {
                continue;
              }

              // Mostrar loading mientras valida
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: DeviceRegistrationLoadingWidget(
                      message: 'Validando código de supervisor...',
                    ),
                  );
                },
              );

              try {
                // Llamar nuevo API para validar supervisor
                ApiCallResponse? supervisorResponse =
                    await APIClickPalmGroup.validateSupervisorGETCall.call(
                  code: enteredCode,
                );

                // Cerrar loading
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }

                if (supervisorResponse.succeeded &&
                    supervisorResponse.jsonBody != null) {
                  var supervisorData = supervisorResponse.jsonBody;

                  // El endpoint ya valida que sea supervisor, solo extraemos la empresa
                  selectedCompany = CompaniesStruct.maybeFromMap(getJsonField(
                    supervisorData,
                    r'''$.company''',
                  ));

                  if (selectedCompany != null) {
                    debugPrint('✅ Supervisor validado. Empresa: ${selectedCompany.nameCompany}');
                    supervisorValidated = true;
                  } else {
                    await showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            height: MediaQuery.sizeOf(context).height * 0.6,
                            width: MediaQuery.sizeOf(context).width * 0.8,
                            child: InfoDialogWidget(
                              info: 'Error al obtener información de la empresa. Intente nuevamente.',
                            ),
                          ),
                        );
                      },
                    );
                    continue;
                  }
                } else {
                  // Error 404 o cualquier otro error
                  await showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return Dialog(
                        elevation: 0,
                        insetPadding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          width: MediaQuery.sizeOf(context).width * 0.8,
                          child: InfoDialogWidget(
                            info: 'El código ingresado no corresponde a un supervisor válido. Intente nuevamente.',
                          ),
                        ),
                      );
                    },
                  );
                  continue;
                }
              } catch (e) {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }

                await showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: Container(
                        height: MediaQuery.sizeOf(context).height * 0.6,
                        width: MediaQuery.sizeOf(context).width * 0.8,
                        child: InfoDialogWidget(
                          info: 'Error al validar supervisor: ${e.toString()}. Intente nuevamente.',
                        ),
                      ),
                    );
                  },
                );
                continue;
              }
            }

            // PASO 2: Mostrar lista de dispositivos CTR de la empresa (ahora obtenida del supervisor)
            bool? shouldRegisterNewDevice = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) {
                return PopScope(
                  canPop: false,
                  child: Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: Container(
                      width: MediaQuery.sizeOf(context).width,
                      height: MediaQuery.sizeOf(context).height,
                      child: DeviceSelectionGridWidget(
                        idCompany: selectedCompany!.idCompany,
                        onDeviceSelected: (DevicesStruct device) async {
                          // Hacer login con el dispositivo seleccionado
                          try {
                            // Capturar el navigator antes de operaciones async
                            final navigator = Navigator.of(dialogContext);

                            // Mostrar diálogo de progreso
                            showDialog(
                              context: dialogContext,
                              barrierDismissible: false,
                              builder: (loadingContext) {
                                return Dialog(
                                  elevation: 0,
                                  insetPadding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width,
                                    height: MediaQuery.sizeOf(context).height,
                                    child: SyncLoadingWidget(
                                      stepMessage: 'Iniciando sesión...',
                                      currentStep: 1,
                                      totalSteps: 1,
                                    ),
                                  ),
                                );
                              },
                            );

                            // Realizar login con el dispositivo seleccionado
                            final loginResult = await APIClickPalmGroup.usersLoginPOSTCall.call(
                              typeLogin: 'IMEI',
                              username: device.imeI1,
                            );

                            if (loginResult.succeeded ?? false) {
                              // Sincronizar datos
                              final pathDB = await actions.validateDbSqlite(context);
                              await actions.syncLogin(
                                context,
                                device.imeI1!,
                                device.imeI1!,
                                getJsonField(loginResult.jsonBody ?? '', r'''$'''),
                              );

                              // Actualizar FFAppState
                              FFAppState().pathDatabase = pathDB!;
                              FFAppState().androidID = device.imeI1!;
                              FFAppState().loginResponse = getJsonField(loginResult.jsonBody ?? '', r'''$''');
                              FFAppState().userSelected = UsersStruct.maybeFromMap(
                                getJsonField(loginResult.jsonBody ?? '', r'''$.user_default'''))!;
                              FFAppState().companyDefault = CompaniesStruct.maybeFromMap(
                                getJsonField(loginResult.jsonBody ?? '', r'''$.company'''))!;
                              FFAppState().deviceDefault = DevicesStruct.maybeFromMap(
                                getJsonField(loginResult.jsonBody ?? '', r'''$.device_default'''))!;
                              FFAppState().headquartersList = (getJsonField(
                                loginResult.jsonBody ?? '', r'''$.headquarters''', true)!
                                .toList()
                                .map<HeadquartersStruct?>(HeadquartersStruct.maybeFromMap)
                                .toList() as Iterable<HeadquartersStruct?>)
                                .withoutNulls.toList().cast<HeadquartersStruct>();
                              FFAppState().zonesList = (getJsonField(
                                loginResult.jsonBody ?? '', r'''$.zones''', true)!
                                .toList()
                                .map<ZonesStruct?>(ZonesStruct.maybeFromMap)
                                .toList() as Iterable<ZonesStruct?>)
                                .withoutNulls.toList().cast<ZonesStruct>();
                              FFAppState().lastSync = getCurrentTimestamp;
                              FFAppState().isSync = true;
                              FFAppState().usersList = (getJsonField(
                                loginResult.jsonBody ?? '', r'''$.users''', true)!
                                .toList()
                                .map<UsersStruct?>(UsersStruct.maybeFromMap)
                                .toList() as Iterable<UsersStruct?>)
                                .withoutNulls.toList().cast<UsersStruct>();
                              FFAppState().headquarterSelected = HeadquartersStruct();
                              FFAppState().zoneSelected = ZonesStruct();
                              FFAppState().activitiesJSON = getJsonField(
                                loginResult.jsonBody ?? '', r'''$.activities''');
                              FFAppState().headquartersSelectedList = [];
                              FFAppState().newsList = (getJsonField(
                                loginResult.jsonBody ?? '', r'''$.news''', true)!
                                .toList()
                                .map<NewsStruct?>(NewsStruct.maybeFromMap)
                                .toList() as Iterable<NewsStruct?>)
                                .withoutNulls.toList().cast<NewsStruct>();
                              FFAppState().isStabilized = false;
                              FFAppState().visitDetails = [];

                              // Cerrar diálogos y navegar
                              if (navigator.canPop()) {
                                navigator.pop(); // Cerrar loading
                              }
                              if (navigator.canPop()) {
                                navigator.pop(); // Cerrar DeviceSelection
                              }
                              if (Navigator.of(context).canPop()) {
                                context.pop();
                              }

                              debugPrint('✅ Login completado, navegando a HomePage');
                              context.pushNamed(
                                LoginPageWidget.routeName,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.fade,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            } else {
                              // Error en el login
                              if (navigator.canPop()) {
                                navigator.pop(); // Cerrar loading
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al iniciar sesión con el dispositivo seleccionado'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e, stackTrace) {
                            debugPrint('❌ Error en onDeviceSelected: $e');
                            debugPrint('Stack trace: $stackTrace');
                            // Intentar cerrar el loading si está abierto
                            try {
                              if (Navigator.of(dialogContext).canPop()) {
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        onAddNewDevice: () async {
                          // Usuario quiere agregar un nuevo dispositivo
                          Navigator.pop(dialogContext, true);
                        },
                      ),
                    ),
                  ),
                );
              },
            );

            if (shouldRegisterNewDevice == true) {
              // Usuario quiere registrar un nuevo dispositivo
              debugPrint('📱 Usuario solicitó agregar nuevo dispositivo');
              // Supervisor ya fue validado al inicio, continuar con el registro
              // Obtener información del dispositivo
              String deviceModel = await actions.getDeviceModel();
              String deviceSerialId = await actions.getAndroidSerialId();
              String deviceImei = _model.identifierCTR ?? '';

              // Mostrar formulario de registro
              Map<String, String>? deviceFormData =
                  await showDialog<Map<String, String>>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  return PopScope(
                    canPop: false,
                    child: Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: DeviceRegistrationFormWidget(
                        deviceImei: deviceImei,
                        deviceModel: deviceModel,
                        deviceSerialId: deviceSerialId,
                        supervisorCompanyId: selectedCompany!.idCompany,
                        onSubmit: (String deviceName, String? cellPhone) async {
                          Navigator.pop(dialogContext, {
                            'deviceName': deviceName,
                            'cellPhone': cellPhone ?? '',
                          });
                        },
                      ),
                    ),
                  );
                },
              );

              if (deviceFormData != null) {
                // Mostrar loading durante registro
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) {
                    return Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: DeviceRegistrationLoadingWidget(
                        message: 'Registrando dispositivo CTR...',
                      ),
                    );
                  },
                );

                try {
                  // Crear dispositivo con POST /Devices
                  ApiCallResponse? createDeviceResponse =
                      await APIClickPalmGroup.devicesPOSTCall.call(
                    idDevice: 0,
                    idCompany: selectedCompany!.idCompany,
                    deviceName: deviceFormData['deviceName']!,
                    cellPhone: deviceFormData['cellPhone'],
                    serialId: deviceSerialId,
                    imeI1: deviceImei,
                    imeI2: deviceImei,
                    model: deviceModel,
                    state: 'A',
                  );

                  // Cerrar loading
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }

                  if (createDeviceResponse?.succeeded ?? false) {
                    // Guardar el IMEI persistentemente
                    await actions.savePersistentId(
                      context,
                      deviceImei,
                    );

                    // Mostrar loading para login
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: DeviceRegistrationLoadingWidget(
                            message: 'Iniciando sesión...',
                          ),
                        );
                      },
                    );

                    // Hacer login con el nuevo dispositivo
                    _model.apiResultLoginRegister =
                        await APIClickPalmGroup.usersLoginPOSTCall.call(
                      typeLogin: 'IMEI',
                      username: deviceImei,
                    );

                    if ((_model.apiResultLoginRegister?.succeeded ?? true)) {
                      // Sincronizar datos
                      _model.pathDBSQLiteRegister = await actions.validateDbSqlite(
                        context,
                      );
                      _model.customSyncLoginResult1 = await actions.syncLogin(
                        context,
                        deviceImei,
                        deviceImei,
                        getJsonField(
                          (_model.apiResultLoginRegister?.jsonBody ?? ''),
                          r'''$''',
                        ),
                      );

                      // Actualizar FFAppState
                      FFAppState().loginResponse = getJsonField(
                        (_model.apiResultLoginRegister?.jsonBody ?? ''),
                        r'''$''',
                      );
                      FFAppState().userSelected =
                          UsersStruct.maybeFromMap(getJsonField(
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
                              .map<HeadquartersStruct?>(
                                  HeadquartersStruct.maybeFromMap)
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
                      FFAppState().zonesList = (getJsonField(
                        (_model.apiResultLoginRegister?.jsonBody ?? ''),
                        r'''$.zones''',
                        true,
                      )!
                              .toList()
                              .map<ZonesStruct?>(ZonesStruct.maybeFromMap)
                              .toList() as Iterable<ZonesStruct?>)
                          .withoutNulls
                          .toList()
                          .cast<ZonesStruct>();
                      FFAppState().newsList = (getJsonField(
                        (_model.apiResultLoginRegister?.jsonBody ?? ''),
                        r'''$.news''',
                        true,
                      )!
                              .toList()
                              .map<NewsStruct?>(NewsStruct.maybeFromMap)
                              .toList() as Iterable<NewsStruct?>)
                          .withoutNulls
                          .toList()
                          .cast<NewsStruct>();
                      FFAppState().pathDatabase = _model.pathDBSQLiteRegister!;
                      FFAppState().androidID = deviceImei;
                      FFAppState().isSync = true;
                      FFAppState().lastSync = getCurrentTimestamp;
                      FFAppState().headquarterSelected = HeadquartersStruct();
                      FFAppState().zoneSelected = ZonesStruct();
                      FFAppState().headquartersSelectedList = [];
                      FFAppState().isStabilized = false;
                      FFAppState().visitDetails = [];

                      // Cerrar loading y navegar
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }

                      debugPrint('✅ Registro completado, navegando a HomePage');
                      context.pushNamed(
                        LoginPageWidget.routeName,
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
                      // Error en login
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }
                      await showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return Dialog(
                            elevation: 0,
                            insetPadding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            child: Container(
                              height: MediaQuery.sizeOf(context).height * 0.4,
                              width: MediaQuery.sizeOf(context).width * 0.8,
                              child: InfoDialogWidget(
                                info: 'Error al iniciar sesión con el nuevo dispositivo.',
                              ),
                            ),
                          );
                        },
                      );
                    }
                  } else {
                    // Error al crear dispositivo
                    await showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            height: MediaQuery.sizeOf(context).height * 0.4,
                            width: MediaQuery.sizeOf(context).width * 0.8,
                            child: InfoDialogWidget(
                              info: 'Error al registrar el dispositivo. Intente nuevamente.',
                            ),
                          ),
                        );
                      },
                    );
                  }
                } catch (e) {
                  // Cerrar loading si está abierto
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }

                  await showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return Dialog(
                        elevation: 0,
                        insetPadding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          width: MediaQuery.sizeOf(context).width * 0.8,
                          child: InfoDialogWidget(
                            info: 'Error durante el registro: ${e.toString()}',
                          ),
                        ),
                      );
                    },
                  );
                }
              }
            }

            return;
          }
        } else {
          // Sin conexión a internet - NO PUEDE CONTINUAR
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return PopScope(
                canPop: false,
                child: Dialog(
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
                            '⚠️ CONEXIÓN REQUERIDA\n\nNo se detectó conexión a internet y es necesaria para sincronizar.\n\nPor favor:\n1. Active WiFi o datos móviles\n2. Verifique que tenga una buena señal\n3. Cierre y vuelva a abrir la aplicación',
                      ),
                    ),
                  ),
                ),
              );
            },
          );

          return;
        }
      } else {
        // Paso 2: Verificando conexión a internet
        _updateProgress(2, 'Verificando conexión a internet...');
        await Future.delayed(Duration(milliseconds: 400));

        _model.connectionJSON = await actions.checkInternetQuality();
        if (functions.jsonDynamicToBool(getJsonField(
              _model.connectionJSON,
              r'''$.hasInternet''',
            )) ==
            true) {
          // Paso 3: Buscando dispositivo en el sistema
          _updateProgress(3, 'Buscando dispositivo en el sistema...');
          await Future.delayed(Duration(milliseconds: 400));

          _model.apiResultDevices =
              await APIClickPalmGroup.devicesFiltersGETCall.call(
            typeSearch: 'IMEI GENERAL',
            textSearch1: _model.identifierCTR,
            idCompany: 0,
            textSearch2: _model.identifierCTR,
            daysToProcess: 0,
          );

          if ((_model.apiResultDevices?.statusCode ?? 200) == 200) {
            // Paso 4: Realizando login
            _updateProgress(4, 'Iniciando sesión de forma segura...');
            await Future.delayed(Duration(milliseconds: 400));

            _model.apiResultLoginDirect =
                await APIClickPalmGroup.usersLoginPOSTCall.call(
              typeLogin: 'IMEI',
              username: _model.identifierCTR,
            );

            if ((_model.apiResultLoginDirect?.succeeded ?? true)) {
              // Paso 5: Sincronizando datos
              _updateProgress(5, 'Sincronizando información del usuario...');
              await Future.delayed(Duration(milliseconds: 400));

              _model.pathDBSQLite = await actions.validateDbSqlite(
                context,
              );
              _model.customSyncLoginResult = await actions.syncLogin(
                context,
                _model.identifierCTR!,
                _model.identifierCTR!,
                getJsonField(
                  (_model.apiResultLoginDirect?.jsonBody ?? ''),
                  r'''$''',
                ),
              );
              FFAppState().pathDatabase = _model.pathDBSQLite!;
              FFAppState().androidID = _model.identifierCTR!;
              FFAppState().loginResponse = getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$''',
              );
              FFAppState().userSelected =
                  UsersStruct.maybeFromMap(getJsonField(
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
                      .map<HeadquartersStruct?>(
                          HeadquartersStruct.maybeFromMap)
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
              FFAppState().usersList = (getJsonField(
                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                r'''$.users''',
                true,
              )!
                      .toList()
                      .map<UsersStruct?>(UsersStruct.maybeFromMap)
                      .toList() as Iterable<UsersStruct?>)
                  .withoutNulls
                  .toList()
                  .cast<UsersStruct>();
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
              FFAppState().isStabilized = false;
              FFAppState().visitDetails = [];
              if (Navigator.of(context).canPop()) {
                context.pop();
              }
              context.pushNamed(
                LoginPageWidget.routeName,
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
            // PASO 1: Validar código de supervisor
            Map<String, dynamic>? supervisorData = await _showSupervisorCodeDialog();

            if (supervisorData == null) {
              debugPrint('⚠️ No se validó código de supervisor');
              return;
            }

            int supervisorCompanyId = supervisorData['id_company'] ?? 0;
            debugPrint('✅ Supervisor validado (Empresa: $supervisorCompanyId)');

            // Crear estructura de empresa del supervisor
            CompaniesStruct selectedCompany = CompaniesStruct(
              idCompany: supervisorCompanyId,
            );

            // PASO 2: Continuar con selección de dispositivo CTR
            if (true) {
              // PASO 2: Mostrar lista de dispositivos CTR de la empresa seleccionada (sin opción de retroceder)
              bool? shouldRegisterNewDevice = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  return PopScope(
                    canPop: false,
                    child: Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        child: DeviceSelectionGridWidget(
                          idCompany: selectedCompany.idCompany,
                          onDeviceSelected: (DevicesStruct selectedDevice) async {
                            try {
                              debugPrint('🔵 Dispositivo seleccionado: ${selectedDevice.deviceName} (ID: ${selectedDevice.idDevice})');

                              // Paso 3: Configurando dispositivo seleccionado
                              _updateProgress(3, 'Configurando dispositivo seleccionado...');
                              await Future.delayed(Duration(milliseconds: 400));

                              // Guardar el dispositivo seleccionado en AppState
                              FFAppState().deviceDefault = selectedDevice;

                              // Paso 4: Iniciando sesión
                              _updateProgress(4, 'Iniciando sesión de forma segura...');
                              await Future.delayed(Duration(milliseconds: 400));

                              // Usar el IMEI real para login, no el ID del dispositivo
                              String loginIdentifier = selectedDevice.imeI1.isNotEmpty
                                  ? selectedDevice.imeI1
                                  : selectedDevice.idDevice.toString();

                              // Persistir el identificador en archivo (IMEI o idDevice como fallback)
                              await actions.savePersistentId(
                                context,
                                loginIdentifier,
                              );
                              debugPrint('✅ ID persistido correctamente: $loginIdentifier');

                              debugPrint('🔵 Realizando login con IMEI: $loginIdentifier');
                              // Hacer login con el dispositivo seleccionado
                              _model.apiResultLoginDirect =
                                  await APIClickPalmGroup.usersLoginPOSTCall.call(
                                typeLogin: 'IMEI',
                                username: loginIdentifier,
                              );

                              debugPrint('🔵 Resultado login: ${_model.apiResultLoginDirect?.succeeded}');

                              if ((_model.apiResultLoginDirect?.succeeded ?? false)) {
                              // Paso 5: Sincronizando información
                              _updateProgress(5, 'Sincronizando información del usuario...');
                              await Future.delayed(Duration(milliseconds: 400));

                              _model.pathDBSQLite = await actions.validateDbSqlite(
                                context,
                              );
                              _model.customSyncLoginResult = await actions.syncLogin(
                                context,
                                loginIdentifier,
                                loginIdentifier,
                                getJsonField(
                                  (_model.apiResultLoginDirect?.jsonBody ?? ''),
                                  r'''$''',
                                ),
                              );
                              FFAppState().pathDatabase = _model.pathDBSQLite!;
                              FFAppState().androidID = loginIdentifier;
                              FFAppState().loginResponse = getJsonField(
                                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                                r'''$''',
                              );
                              FFAppState().userSelected =
                                  UsersStruct.maybeFromMap(getJsonField(
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
                                      .map<HeadquartersStruct?>(
                                          HeadquartersStruct.maybeFromMap)
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
                              FFAppState().usersList = (getJsonField(
                                (_model.apiResultLoginDirect?.jsonBody ?? ''),
                                r'''$.users''',
                                true,
                              )!
                                      .toList()
                                      .map<UsersStruct?>(UsersStruct.maybeFromMap)
                                      .toList() as Iterable<UsersStruct?>)
                                  .withoutNulls
                                  .toList()
                                  .cast<UsersStruct>();
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
                              FFAppState().isStabilized = false;
                              FFAppState().visitDetails = [];

                              // Cerrar el diálogo
                              Navigator.pop(dialogContext, false);

                              // Ir a HomePage
                              if (Navigator.of(context).canPop()) {
                                context.pop();
                              }
                              debugPrint('✅ Navegando a HomePage');
                              context.pushNamed(
                                LoginPageWidget.routeName,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.fade,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            } else {
                              // Error en el login
                              debugPrint('❌ Error en login - succeeded: false');
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al iniciar sesión con el dispositivo seleccionado'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            } catch (e, stackTrace) {
                              debugPrint('❌ Error en onDeviceSelected: $e');
                              debugPrint('Stack trace: $stackTrace');
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                          onAddNewDevice: () async {
                            // Usuario quiere agregar un nuevo dispositivo
                            Navigator.pop(dialogContext, true);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );

                // Si el usuario presionó "Agregar nuevo dispositivo"
                if (shouldRegisterNewDevice == true) {
                  // LOOP: Validar código de supervisor - no avanza hasta que sea correcto
                  bool supervisorValidated = false;
                  int supervisorCompanyId = 0;

                  while (!supervisorValidated) {
                    // Mostrar teclado nuevo de supervisor (sin opción de retroceder)
                    String? enteredCode = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) {
                        return PopScope(
                          canPop: false,
                          child: Dialog(
                            elevation: 0,
                            insetPadding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            child: Container(
                              width: MediaQuery.sizeOf(context).width,
                              height: MediaQuery.sizeOf(context).height,
                              child: SupervisorCodeKeyboardWidget(
                                onCodeEntered: (String code) async {
                                  Navigator.pop(dialogContext, code);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    if (enteredCode == null || enteredCode.isEmpty) {
                      // Usuario canceló o no ingresó código
                      continue;
                    }

                    // Mostrar loading mientras valida
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: DeviceRegistrationLoadingWidget(
                            message: 'Validando código de supervisor...',
                          ),
                        );
                      },
                    );

                    try {
                      // Llamar API para validar supervisor por operID
                      ApiCallResponse? supervisorResponse =
                          await APIClickPalmGroup.usersbyoperidGETCall.call(
                        operID: enteredCode,
                      );

                      // Cerrar loading
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }

                      if (supervisorResponse.succeeded &&
                          supervisorResponse.jsonBody != null) {
                        // Verificar si el usuario es supervisor
                        var supervisorData = supervisorResponse.jsonBody;

                        // Verificar permisos del usuario
                        List<dynamic> permissions = getJsonField(
                          supervisorData,
                          r'''$.users_permissions''',
                          true,
                        ) ?? [];

                        bool isSupervisor = false;
                        for (var permission in permissions) {
                          String? permissionName = getJsonField(
                            permission,
                            r'''$.name_permission''',
                          )?.toString();

                          if (permissionName?.toUpperCase() == 'SUPERVISOR') {
                            isSupervisor = true;
                            break;
                          }
                        }

                        if (!isSupervisor) {
                          // No es supervisor - mostrar error y reintentar
                          await showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.6,
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: InfoDialogWidget(
                                    info:
                                        'El código ingresado no corresponde a un supervisor. Intente nuevamente.',
                                  ),
                                ),
                              );
                            },
                          );
                          continue; // Volver a mostrar el teclado
                        }

                        // Obtener id_company del supervisor
                        supervisorCompanyId = getJsonField(
                              supervisorData,
                              r'''$.id_company''',
                            ) ??
                            0;

                        if (supervisorCompanyId == 0) {
                          await showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.6,
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: InfoDialogWidget(
                                    info:
                                        'Error: El supervisor no tiene una compañía asignada. Intente con otro código.',
                                  ),
                                ),
                              );
                            },
                          );
                          continue; // Volver a mostrar el teclado
                        }

                        // TODO CORRECTO - salir del loop
                        supervisorValidated = true;
                      } else {
                        // Error en la respuesta del API
                        await showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return Dialog(
                              elevation: 0,
                              insetPadding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              child: Container(
                                height: MediaQuery.sizeOf(context).height * 0.6,
                                width: MediaQuery.sizeOf(context).width * 0.8,
                                child: InfoDialogWidget(
                                  info:
                                      'No se encontró un usuario con ese código. Intente nuevamente.',
                                ),
                              ),
                            );
                          },
                        );
                        continue; // Volver a mostrar el teclado
                      }
                    } catch (e) {
                      // Cerrar loading si está abierto
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }

                      await showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return Dialog(
                            elevation: 0,
                            insetPadding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            child: Container(
                              height: MediaQuery.sizeOf(context).height * 0.6,
                              width: MediaQuery.sizeOf(context).width * 0.8,
                              child: InfoDialogWidget(
                                info:
                                    'Error al validar supervisor: ${e.toString()}. Intente nuevamente.',
                              ),
                            ),
                          );
                        },
                      );
                      continue; // Volver a mostrar el teclado
                    }
                  }

                  // Supervisor validado correctamente, continuar con el registro

                  // Obtener información del dispositivo
                  String deviceModel = await actions.getDeviceModel();
                  String deviceSerialId =
                      await actions.getAndroidSerialId();
                  String deviceImei = _model.identifierCTR ?? '';

                  // Mostrar formulario de registro (sin opción de retroceder)
                  Map<String, String>? deviceFormData =
                      await showDialog<Map<String, String>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      return PopScope(
                        canPop: false,
                        child: Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: DeviceRegistrationFormWidget(
                            deviceImei: deviceImei,
                            deviceModel: deviceModel,
                            deviceSerialId: deviceSerialId,
                            supervisorCompanyId: supervisorCompanyId,
                            onSubmit: (String deviceName,
                                String? cellPhone) async {
                              Navigator.pop(dialogContext, {
                                'deviceName': deviceName,
                                'cellPhone': cellPhone ?? '',
                              });
                            },
                          ),
                        ),
                      );
                    },
                  );

                  if (deviceFormData != null) {
                          // Mostrar loading durante registro
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (loadingContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                child: DeviceRegistrationLoadingWidget(
                                  message: 'Registrando dispositivo CTR...',
                                ),
                              );
                            },
                          );

                          try {
                            // Crear dispositivo con POST /Devices
                            ApiCallResponse? createDeviceResponse =
                                await APIClickPalmGroup.devicesPOSTCall.call(
                              idDevice: 0,
                              idCompany: supervisorCompanyId,
                              deviceName: deviceFormData['deviceName']!,
                              cellPhone: deviceFormData['cellPhone'],
                              serialId: deviceSerialId,
                              imeI1: deviceImei,
                              imeI2: deviceImei,
                              model: deviceModel,
                              state: 'A',
                            );

                            // Cerrar loading
                            if (Navigator.of(context).canPop()) {
                              Navigator.pop(context);
                            }

                            if (createDeviceResponse?.succeeded ?? false) {
                              // Guardar el IMEI persistentemente
                              await actions.savePersistentId(
                                context,
                                deviceImei,
                              );

                              // Paso 4: Registrando dispositivo
                              _updateProgress(4, 'Iniciando sesión...');
                              await Future.delayed(Duration(milliseconds: 400));

                              // Hacer login con el nuevo dispositivo
                              _model.apiResultLoginRegister =
                                  await APIClickPalmGroup.usersLoginPOSTCall
                                      .call(
                                typeLogin: 'IMEI',
                                username: deviceImei,
                              );

                              if ((_model.apiResultLoginRegister?.succeeded ??
                                  true)) {
                                // Paso 5: Sincronizando nuevo dispositivo
                                _updateProgress(
                                    5, 'Sincronizando información...');
                                await Future.delayed(
                                    Duration(milliseconds: 400));

                                _model.pathDBSQLiteRegister =
                                    await actions.validateDbSqlite(
                                  context,
                                );
                                _model.customSyncLoginResult1 =
                                    await actions.syncLogin(
                                  context,
                                  deviceImei,
                                  deviceImei,
                                  getJsonField(
                                    (_model.apiResultLoginRegister?.jsonBody ??
                                        ''),
                                    r'''$''',
                                  ),
                                );
                                FFAppState().loginResponse = getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$''',
                                );
                                FFAppState().userSelected =
                                    UsersStruct.maybeFromMap(getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.user_default''',
                                ))!;
                                FFAppState().companyDefault =
                                    CompaniesStruct.maybeFromMap(getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.company''',
                                ))!;
                                FFAppState().deviceDefault =
                                    DevicesStruct.maybeFromMap(getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.device_default''',
                                ))!;
                                FFAppState().headquartersList = (getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.headquarters''',
                                  true,
                                )!
                                        .toList()
                                        .map<HeadquartersStruct?>(
                                            HeadquartersStruct.maybeFromMap)
                                        .toList() as Iterable<HeadquartersStruct?>)
                                    .withoutNulls
                                    .toList()
                                    .cast<HeadquartersStruct>();
                                FFAppState().usersList = (getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.users''',
                                  true,
                                )!
                                        .toList()
                                        .map<UsersStruct?>(
                                            UsersStruct.maybeFromMap)
                                        .toList() as Iterable<UsersStruct?>)
                                    .withoutNulls
                                    .toList()
                                    .cast<UsersStruct>();
                                FFAppState().activitiesJSON = getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.activities''',
                                );
                                FFAppState().zonesList = (getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.zones''',
                                  true,
                                )!
                                        .toList()
                                        .map<ZonesStruct?>(
                                            ZonesStruct.maybeFromMap)
                                        .toList() as Iterable<ZonesStruct?>)
                                    .withoutNulls
                                    .toList()
                                    .cast<ZonesStruct>();
                                FFAppState().newsList = (getJsonField(
                                  (_model.apiResultLoginRegister?.jsonBody ??
                                      ''),
                                  r'''$.news''',
                                  true,
                                )!
                                        .toList()
                                        .map<NewsStruct?>(NewsStruct.maybeFromMap)
                                        .toList() as Iterable<NewsStruct?>)
                                    .withoutNulls
                                    .toList()
                                    .cast<NewsStruct>();
                                FFAppState().pathDatabase =
                                    _model.pathDBSQLiteRegister!;
                                FFAppState().androidID = deviceImei;
                                FFAppState().isSync = true;
                                FFAppState().lastSync = getCurrentTimestamp;
                                FFAppState().headquarterSelected =
                                    HeadquartersStruct();
                                FFAppState().zoneSelected = ZonesStruct();
                                FFAppState().headquartersSelectedList = [];
                                FFAppState().isStabilized = false;
                                FFAppState().visitDetails = [];

                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                }
                                context.pushNamed(
                                  LoginPageWidget.routeName,
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
                                      child: Container(
                                        height: MediaQuery.sizeOf(context)
                                                .height *
                                            0.6,
                                        width:
                                            MediaQuery.sizeOf(context).width *
                                                0.8,
                                        child: InfoDialogWidget(
                                          info:
                                              'Error al iniciar sesión con el nuevo dispositivo',
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
                                    child: Container(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                              0.6,
                                      width: MediaQuery.sizeOf(context).width *
                                          0.8,
                                      child: InfoDialogWidget(
                                        info:
                                            'Error al registrar el dispositivo. Intente nuevamente.',
                                      ),
                                    ),
                                  );
                                },
                              );
                              return;
                            }
                          } catch (e) {
                            // Cerrar loading si está abierto
                            if (Navigator.of(context).canPop()) {
                              Navigator.pop(context);
                            }

                            await showDialog(
                              context: context,
                              builder: (dialogContext) {
                                return Dialog(
                                  elevation: 0,
                                  insetPadding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  child: Container(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.6,
                                    width:
                                        MediaQuery.sizeOf(context).width * 0.8,
                                    child: InfoDialogWidget(
                                      info: 'Error: ${e.toString()}',
                                    ),
                                  ),
                                );
                              },
                            );
                            return;
                          }
                        } else {
                          // Usuario canceló el formulario
                          return;
                        }
                }
              }
            }
        } else {
          // Sin conexión a internet - NO PUEDE CONTINUAR
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return PopScope(
                canPop: false,
                child: Dialog(
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
                            '⚠️ CONEXIÓN REQUERIDA\n\nNo se detectó conexión a internet y es necesaria para inicializar el dispositivo por primera vez.\n\nPor favor:\n1. Active WiFi o datos móviles\n2. Verifique que tenga una buena señal\n3. Cierre y vuelva a abrir la aplicación\n\nNO PUEDE CONTINUAR sin conexión a internet.',
                      ),
                    ),
                  ),
                ),
              );
            },
          );

          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  // Helper method to update progress
  void _updateProgress(int step, String message) {
    if (mounted) {
      setState(() {
        _model.currentStep = step;
        _model.stepMessage = message;
      });
    }
  }

  /// Muestra el diálogo de código de supervisor y valida el código ingresado
  /// Retorna los datos del supervisor validado o null si se cancela
  Future<Map<String, dynamic>?> _showSupervisorCodeDialog() async {
    bool supervisorValidated = false;
    Map<String, dynamic>? supervisorResult;

    while (!supervisorValidated) {
      // Mostrar teclado de código de supervisor
      String? enteredCode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: SupervisorCodeKeyboardWidget(
                  onCodeEntered: (String code) async {
                    Navigator.pop(dialogContext, code);
                  },
                ),
              ),
            ),
          );
        },
      );

      // Si no se ingresó código (cancelado), retornar null
      if (enteredCode == null || enteredCode.isEmpty) {
        debugPrint('⚠️ Usuario canceló ingreso de código de supervisor');
        return null;
      }

      debugPrint('🔐 Validando código de supervisor: $enteredCode');

      // Mostrar loading mientras se valida
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: DeviceRegistrationLoadingWidget(
              message: 'Validando código de supervisor...',
            ),
          );
        },
      );

      try {
        // Llamar API para validar supervisor por operID
        ApiCallResponse? supervisorResponse =
            await APIClickPalmGroup.usersbyoperidGETCall.call(
          operID: enteredCode,
        );

        // Cerrar loading
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        if (supervisorResponse.succeeded && supervisorResponse.jsonBody != null) {
          var supervisorData = supervisorResponse.jsonBody;

          // Verificar permisos del usuario
          List<dynamic> permissions = getJsonField(
            supervisorData,
            r'''$.users_permissions''',
            true,
          ) ?? [];

          bool isSupervisor = false;
          for (var permission in permissions) {
            String? permissionName = getJsonField(
              permission,
              r'''$.name_permission''',
            )?.toString();

            if (permissionName?.toUpperCase() == 'SUPERVISOR') {
              isSupervisor = true;
              break;
            }
          }

          if (!isSupervisor) {
            debugPrint('❌ Código no corresponde a un supervisor');
            await showDialog(
              context: context,
              builder: (dialogContext) {
                return Dialog(
                  elevation: 0,
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    width: MediaQuery.sizeOf(context).width * 0.8,
                    child: InfoDialogWidget(
                      info: 'El código ingresado no corresponde a un supervisor. Intente nuevamente.',
                    ),
                  ),
                );
              },
            );
            continue; // Volver a solicitar código
          }

          // Extraer información del supervisor
          int idCompany = getJsonField(supervisorData, r'''$.id_company''') ?? 0;

          if (idCompany == 0) {
            debugPrint('❌ Supervisor sin empresa asignada');
            await showDialog(
              context: context,
              builder: (dialogContext) {
                return Dialog(
                  elevation: 0,
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    width: MediaQuery.sizeOf(context).width * 0.8,
                    child: InfoDialogWidget(
                      info: 'El supervisor no tiene una empresa asignada. Intente con otro código.',
                    ),
                  ),
                );
              },
            );
            continue; // Volver a solicitar código
          }

          supervisorResult = {
            'id_company': idCompany,
            'operID': enteredCode,
            'name': getJsonField(supervisorData, r'''$.name''') ?? 'Supervisor',
            'full_data': supervisorData,
          };

          debugPrint('✅ Supervisor validado: ${supervisorResult['name']} (Empresa: $idCompany)');
          supervisorValidated = true;

        } else {
          debugPrint('❌ No se encontró usuario con código: $enteredCode');
          await showDialog(
            context: context,
            builder: (dialogContext) {
              return Dialog(
                elevation: 0,
                insetPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  width: MediaQuery.sizeOf(context).width * 0.8,
                  child: InfoDialogWidget(
                    info: 'No se encontró un usuario con ese código. Intente nuevamente.',
                  ),
                ),
              );
            },
          );
          continue; // Volver a solicitar código
        }

      } catch (e) {
        // Cerrar loading si está abierto
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        debugPrint('❌ Error al validar supervisor: $e');
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.6,
                width: MediaQuery.sizeOf(context).width * 0.8,
                child: InfoDialogWidget(
                  info: 'Error al validar supervisor: ${e.toString()}. Intente nuevamente.',
                ),
              ),
            );
          },
        );
        continue; // Volver a solicitar código
      }
    }

    return supervisorResult;
  }

  /// Verifica la conexión a internet con reintentos automáticos durante 5 minutos.
  /// Retorna true si se logró conectar, false si el usuario decidió cerrar la app.
  Future<bool> _checkConnectionWithRetry() async {
    final completer = Completer<bool>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: ConnectionRetryDialogWidget(
              maxRetryDuration: const Duration(minutes: 5),
              retryInterval: const Duration(seconds: 10),
              checkConnectionCallback: () async {
                try {
                  final connectionResult = await actions.checkInternetQuality();
                  final hasInternet = functions.jsonDynamicToBool(
                    getJsonField(connectionResult, r'''$.hasInternet'''),
                  );
                  return hasInternet == true;
                } catch (e) {
                  debugPrint('❌ Error verificando conexión: $e');
                  return false;
                }
              },
              onConnectionSuccess: () {
                Navigator.of(dialogContext).pop();
                completer.complete(true);
              },
            ),
          ),
        );
      },
    );

    // Si el completer no se completó, significa que el usuario cerró la app
    if (!completer.isCompleted) {
      completer.complete(false);
    }

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return PopScope(
      canPop: false, // Previene navegación hacia atrás
      onPopInvokedWithResult: (didPop, result) {
        // No permite retroceder durante el proceso de inicialización
        if (didPop) {
          return;
        }
      },
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            body: SyncLoadingWidget(
              currentStep: _model.currentStep,
              totalSteps: _model.totalSteps,
              stepMessage: _model.stepMessage,
            ),
          ),
        ),
      ),
    );
  }
}
