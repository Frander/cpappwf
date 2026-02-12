import '/components/info_dialog_widget.dart';
import '/components/nfc_write_dialog_widget.dart';
import '/components/nfc_read_dialog_widget.dart';
import '/components/advanced_sync_dialog_widget.dart';
import '/components/gps_stabilization_monitor_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/visits/validation_sync_route/validation_sync_route_widget.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/backend/schema/structs/index.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'do_activities_page_model.dart';
export 'do_activities_page_model.dart';

class DoActivitiesPageWidget extends StatefulWidget {
  const DoActivitiesPageWidget({
    super.key,
    String? tittle,
  }) : this.tittle = tittle ?? 'Módulo ClickPalm';

  final String tittle;

  static String routeName = 'DoActivitiesPage';
  static String routePath = '/doActivitiesPage';

  @override
  State<DoActivitiesPageWidget> createState() => _DoActivitiesPageWidgetState();
}

class _DoActivitiesPageWidgetState extends State<DoActivitiesPageWidget>
    with SingleTickerProviderStateMixin {
  late DoActivitiesPageModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoActivitiesPageModel());

    // Inicializar animación de pulso para indicador GPS
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // DESACTIVADO: getLocationList - ahora solo usa background_location_service
      // unawaited(
      //   () async {
      //     await actions.getLocationList(
      //       context,
      //     );
      //   }(),
      // );
      if (FFAppState().isStabilized) {
        return;
      }

      return;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observar FFAppState para que el widget se reconstruya cuando isStabilized cambie
    // Esto permite que el botón "Realizar visitas" se habilite cuando el GPS se estabiliza
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
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF003420),
                  Color(0xFF002415),
                  Color(0xFF00150A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header moderno
                Container(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF00a86b).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Botón Back
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(
                                HomePageWidget.routeName,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.fade,
                                    duration: Duration(milliseconds: 500),
                                  ),
                                },
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFF00a86b).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF00ff9f),
                                size: 28,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Logo
                          Container(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.asset(
                                'assets/images/logo2_(1).png',
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Spacer(),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Título del módulo con efecto brillante
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF00ff9f),
                              Color(0xFF00a86b),
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          widget.tittle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xFF00a86b).withOpacity(0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                // Contenido scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 16.0),
                    child: Column(
                      children: [
                        // 1. Seleccionar Operador
                        _buildStepCard(
                          context,
                          stepNumber: '1',
                          icon: 'assets/images/usersv2.png',
                          title: (FFAppState().userSelected != null) &&
                                  (FFAppState().userSelected.nameUser != null &&
                                      FFAppState().userSelected.nameUser != '')
                              ? FFAppState().userSelected.nameUser
                              : 'Seleccione un operador',
                          isCompleted: (FFAppState().userSelected.nameUser !=
                                      null &&
                                  FFAppState().userSelected.nameUser != '') &&
                              (FFAppState().userSelected.nameUser != null &&
                                  FFAppState().userSelected.nameUser != ''),
                          onTap: () async {
                            HapticFeedback.vibrate();
                            context.pushNamed(
                              UsersPageWidget.routeName,
                              extra: <String, dynamic>{
                                kTransitionInfoKey: TransitionInfo(
                                  hasTransition: true,
                                  transitionType: PageTransitionType.fade,
                                  duration: Duration(milliseconds: 1000),
                                ),
                              },
                            );
                          },
                        ),

                        SizedBox(height: 12),

                        // 2. Seleccionar Actividad
                        _buildStepCard(
                          context,
                          stepNumber: '2',
                          icon: 'assets/images/activities2.png',
                          title: FFAppState().activitySelected.hasNameActivity()
                              ? FFAppState().activitySelected.nameActivity
                              : 'Seleccione una actividad',
                          isCompleted:
                              FFAppState().activitySelected.hasNameActivity(),
                          onTap: () async {
                            HapticFeedback.vibrate();
                            context.pushNamed(
                              ActivitiesPageWidget.routeName,
                              extra: <String, dynamic>{
                                kTransitionInfoKey: TransitionInfo(
                                  hasTransition: true,
                                  transitionType: PageTransitionType.fade,
                                  duration: Duration(milliseconds: 1000),
                                ),
                              },
                            );
                          },
                        ),

                        SizedBox(height: 12),

                        // 3. Seleccionar Lotes (solo si tracking_headquarter es true)
                        if (() {
                          // Verificar si la actividad requiere tracking de lotes
                          if (FFAppState().activitySelected.hasNameActivity()) {
                            // Si tracking_headquarter es true, mostrar el botón
                            // Si es false explícitamente, ocultarlo
                            return FFAppState().activitySelected.trackingHeadquarter;
                          }
                          // Si no hay actividad seleccionada, mostrar el botón por defecto
                          return true;
                        }())
                          _buildStepCard(
                            context,
                            stepNumber: '3',
                            icon: 'assets/images/HugeiconsGrid_2.png',
                            title: () {
                              if (FFAppState().headquartersSelectedList.length !=
                                  0) {
                                return functions.concatHeadquartersNames(
                                    FFAppState()
                                        .headquartersSelectedList
                                        .toList());
                              } else if (FFAppState()
                                  .headquartersSelectedList
                                  .isNotEmpty) {
                                return functions.concatHeadquartersNames(
                                    FFAppState()
                                        .headquartersSelectedList
                                        .toList());
                              } else {
                                return 'Seleccione los lotes a trabajar';
                              }
                            }(),
                            isCompleted:
                                FFAppState().headquartersSelectedList.isNotEmpty,
                            onTap: () async {
                              HapticFeedback.vibrate();
                              context.pushNamed(
                                HeadquartersPageWidget.routeName,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.fade,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                          ),

                        SizedBox(height: 20),

                        // Botón grande: Realizar Visitas
                        Builder(
                          builder: (context) => GestureDetector(
                            onTap: () async {
                              HapticFeedback.vibrate();

                              // Validaciones
                              if (!FFAppState().isStabilized) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Espere a que el sistema GPS se estabilice',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              if (FFAppState().userSelected == null ||
                                  FFAppState().userSelected.nameUser == null ||
                                  FFAppState().userSelected.nameUser == '') {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar un operador',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              if (!FFAppState().activitySelected.hasNameActivity()) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar una actividad a realizar',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              // Solo validar lotes si tracking_headquarter es true
                              final requiresHeadquarters = FFAppState().activitySelected.hasNameActivity() &&
                                  FFAppState().activitySelected.trackingHeadquarter;

                              if (requiresHeadquarters &&
                                  FFAppState().headquartersSelectedList.isEmpty) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar al menos un lote para trabajar',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              final bool? shouldPerformAdvancedSync;

                              // 🔍 Verificar si la sincronización es obligatoria (usando is_sync_full)
                              final isSyncMandatory = FFAppState().activitySelected.hasNameActivity() &&
                                  FFAppState().activitySelected.isSyncFull;

                              // Si es obligatorio, SIEMPRE mostrar el diálogo (ignorar preferencia guardada)
                              // Si NO es obligatorio, verificar si hay preferencia guardada
                              if (!isSyncMandatory && FFAppState().shouldGenerateOptimalRoute != null) {
                                // Usar la preferencia guardada sin mostrar el diálogo (solo si NO es obligatorio)
                                shouldPerformAdvancedSync =
                                    FFAppState().shouldGenerateOptimalRoute;
                              } else {
                                // Mostrar el diálogo (si es obligatorio o no hay preferencia guardada)
                                shouldPerformAdvancedSync = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  barrierColor: Colors.black.withOpacity(0.8),
                                  builder: (dialogContext) {
                                    return AdvancedSyncDialogWidget(
                                      onSyncNow: () async {
                                        debugPrint('🔄 Iniciando sincronización completa...');

                                        // Obtener el token de autenticación
                                        final String? authToken = getJsonField(
                                          FFAppState().loginResponse,
                                          r'''$.token''',
                                        )?.toString();

                                        if (authToken == null || authToken.isEmpty) {
                                          debugPrint('❌ No se encontró token de autenticación');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: No se encontró token de autenticación'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // Sincronizar cada lote seleccionado
                                        bool allSynced = true;
                                        int syncedCount = 0;

                                        for (final headquarter in FFAppState().headquartersSelectedList) {
                                          final int? headquarterId = headquarter.idHeadquarter;

                                          if (headquarterId == null) {
                                            debugPrint('⚠️ Lote sin ID, omitiendo...');
                                            continue;
                                          }

                                          debugPrint('📥 Sincronizando lote ID: $headquarterId');

                                          final bool syncResult = await actions.syncInstallModule(
                                            context,
                                            headquarterId,
                                            authToken,
                                          );

                                          if (syncResult) {
                                            syncedCount++;
                                            debugPrint('✅ Lote $headquarterId sincronizado exitosamente');
                                          } else {
                                            allSynced = false;
                                            debugPrint('❌ Error sincronizando lote $headquarterId');
                                          }
                                        }

                                        // Cargar TODOS los productos desde SQLite al AppState
                                        debugPrint('📦 Cargando productos desde SQLite al AppState...');
                                        try {
                                          // Usar la misma ruta de base de datos que sync_install_module
                                          final Directory? externalDir = await getExternalStorageDirectory();
                                          if (externalDir == null) {
                                            throw Exception('No se pudo acceder al almacenamiento externo');
                                          }
                                          final String basePath = '${externalDir.path}/ClickPalmData';
                                          final String dbPath = path.join(basePath, 'clickpalm_database.db');

                                          final db = await openDatabase(dbPath);
                                          debugPrint('🔗 Conexión abierta para cargar productos: ${db.hashCode}');

                                          final List<Map<String, dynamic>> productsRaw = await db.query('Products');

                                          final List<ProductsStruct> loadedProducts = productsRaw
                                              .map((map) => ProductsStruct.fromMap(map))
                                              .toList();

                                          FFAppState().productsList = loadedProducts;
                                          debugPrint('✅ ${loadedProducts.length} productos cargados en AppState');

                                          // Mostrar resumen por lote
                                          final Map<int, int> productsByHeadquarter = {};
                                          for (var product in loadedProducts) {
                                            productsByHeadquarter[product.idHeadquarter] =
                                                (productsByHeadquarter[product.idHeadquarter] ?? 0) + 1;
                                          }
                                          debugPrint('📊 Productos por lote:');
                                          productsByHeadquarter.forEach((heId, count) {
                                            debugPrint('   - Lote $heId: $count productos');
                                          });

                                          // Cerrar la conexión
                                          await db.close();
                                          debugPrint('🔗 Conexión cerrada después de cargar productos');
                                        } catch (e) {
                                          debugPrint('❌ Error cargando productos: $e');
                                        }

                                        // Mostrar resultado
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                allSynced
                                                    ? '✓ Sincronización completa exitosa ($syncedCount lotes)'
                                                    : '⚠ Sincronización parcial ($syncedCount/${FFAppState().headquartersSelectedList.length} lotes)',
                                              ),
                                              backgroundColor: allSynced ? Color(0xFF00a86b) : Colors.orange,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }

                                        debugPrint('🎉 Sincronización completa finalizada');
                                      },
                                      onSkip: () {
                                        debugPrint('⏭️ Usuario omitió la sincronización completa');
                                      },
                                    );
                                  },
                                );

                                // Guardar la preferencia para futuras interacciones en esta sesión (solo si NO es obligatorio)
                                if (!isSyncMandatory && shouldPerformAdvancedSync != null) {
                                  FFAppState().shouldGenerateOptimalRoute =
                                      shouldPerformAdvancedSync;
                                }
                              }

                              // 🚨 VALIDAR: Si la sincronización es OBLIGATORIA y el usuario NO sincronizó, detener aquí
                              if (isSyncMandatory && shouldPerformAdvancedSync != true) {
                                debugPrint('🚫 Sincronización obligatoria no completada. Deteniendo navegación.');
                                return; // NO continuar si es obligatorio y no sincronizó
                              }

                              FFAppState().stopVoice = false;

                              // ⚠️ CRÍTICO: Limpiar visitDetails antes de entrar al formulario
                              // Esto asegura que no haya opciones preseleccionadas de visitas anteriores
                              FFAppState().visitDetails = [];
                              FFAppState().update(() {});

                              final bool isMapEnabled =
                                  shouldPerformAdvancedSync == true;

                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => VisitsWithMapPageWidget(
                                    isMapEnabled: isMapEnabled,
                                  ),
                                ),
                              );
                            },
                            onLongPress: () async {
                              // 🔄 LONG PRESS (2 segundos): Forzar mostrar el diálogo nuevamente
                              HapticFeedback.heavyImpact();

                              debugPrint('🔄 Long press detectado - Mostrando diálogo de sincronización nuevamente');

                              // Validaciones previas
                              if (!FFAppState().isStabilized) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Espere a que el sistema GPS se estabilice',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              if (FFAppState().userSelected == null ||
                                  FFAppState().userSelected.nameUser == null ||
                                  FFAppState().userSelected.nameUser == '') {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar un operador',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              if (!FFAppState().activitySelected.hasNameActivity()) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar una actividad a realizar',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              // Solo validar lotes si tracking_headquarter es true (onLongPress)
                              final requiresHeadquartersLongPress = FFAppState().activitySelected.hasNameActivity() &&
                                  FFAppState().activitySelected.trackingHeadquarter;

                              if (requiresHeadquartersLongPress &&
                                  FFAppState().headquartersSelectedList.isEmpty) {
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
                                          FocusScope.of(dialogContext)
                                              .unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Container(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.4,
                                          width:
                                              MediaQuery.sizeOf(context).width *
                                                  0.9,
                                          child: InfoDialogWidget(
                                            info:
                                                'Debe seleccionar al menos un lote para trabajar',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                return;
                              }

                              // 🔄 FORZAR mostrar el diálogo de sincronización (ignorar preferencia guardada)
                              final bool? shouldPerformAdvancedSyncLongPress = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                barrierColor: Colors.black.withOpacity(0.8),
                                builder: (dialogContext) {
                                  return AdvancedSyncDialogWidget(
                                    onSyncNow: () async {
                                      debugPrint('🔄 Iniciando sincronización completa (long press)...');

                                      // Obtener el token de autenticación
                                      final String? authToken = getJsonField(
                                        FFAppState().loginResponse,
                                        r'''$.token''',
                                      )?.toString();

                                      if (authToken == null || authToken.isEmpty) {
                                        debugPrint('❌ No se encontró token de autenticación');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: No se encontró token de autenticación'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      // Sincronizar cada lote seleccionado
                                      bool allSynced = true;
                                      int syncedCount = 0;

                                      for (final headquarter in FFAppState().headquartersSelectedList) {
                                        final int? headquarterId = headquarter.idHeadquarter;

                                        if (headquarterId == null) {
                                          debugPrint('⚠️ Lote sin ID, omitiendo...');
                                          continue;
                                        }

                                        debugPrint('📥 Sincronizando lote ID: $headquarterId');

                                        final bool syncResult = await actions.syncInstallModule(
                                          context,
                                          headquarterId,
                                          authToken,
                                        );

                                        if (syncResult) {
                                          syncedCount++;
                                          debugPrint('✅ Lote $headquarterId sincronizado exitosamente');
                                        } else {
                                          allSynced = false;
                                          debugPrint('❌ Error sincronizando lote $headquarterId');
                                        }
                                      }

                                      // Mostrar resultado
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              allSynced
                                                  ? '✓ Sincronización completa exitosa ($syncedCount lotes)'
                                                  : '⚠ Sincronización parcial ($syncedCount/${FFAppState().headquartersSelectedList.length} lotes)',
                                            ),
                                            backgroundColor: allSynced ? Color(0xFF00a86b) : Colors.orange,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }

                                      debugPrint('🎉 Sincronización completa finalizada (long press)');
                                    },
                                    onSkip: () {
                                      debugPrint('⏭️ Usuario omitió la sincronización completa (long press)');
                                    },
                                  );
                                },
                              );

                              // 🔍 Verificar si la sincronización es obligatoria (usando is_sync_full)
                              final isSyncMandatoryLongPress = FFAppState().activitySelected.hasNameActivity() &&
                                  FFAppState().activitySelected.isSyncFull;

                              // Actualizar la preferencia guardada con la nueva elección (solo si NO es obligatorio)
                              if (!isSyncMandatoryLongPress && shouldPerformAdvancedSyncLongPress != null) {
                                FFAppState().shouldGenerateOptimalRoute = shouldPerformAdvancedSyncLongPress;
                                debugPrint('✅ Preferencia actualizada: $shouldPerformAdvancedSyncLongPress');
                              }

                              if (isSyncMandatoryLongPress && shouldPerformAdvancedSyncLongPress != true) {
                                debugPrint('🚫 Sincronización obligatoria no completada (long press). Deteniendo navegación.');
                                return; // NO continuar si es obligatorio y no sincronizó
                              }

                              // Continuar con el flujo normal
                              FFAppState().stopVoice = false;
                              FFAppState().visitDetails = [];
                              FFAppState().update(() {});

                              final bool isMapEnabled = shouldPerformAdvancedSyncLongPress == true;

                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => VisitsWithMapPageWidget(
                                    isMapEnabled: isMapEnabled,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: FFAppState().isStabilized
                                      ? [
                                          Color(0xFF003420),
                                          Color(0xFF00a86b),
                                        ]
                                      : [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFFFB3B3),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 20,
                                    color: (FFAppState().isStabilized
                                            ? Color(0xFF00a86b)
                                            : Color(0xFFFF6B6B))
                                        .withOpacity(0.4),
                                    offset: Offset(0, 10),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    'Realizar visitas',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 8),

                        // Indicador de estado GPS en tiempo real (tappable → abre monitor)
                        GestureDetector(
                          onTap: () => GPSStabilizationMonitor.show(context),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final isStabilized = FFAppState().isStabilized;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                margin: EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: isStabilized
                                      ? Color(0xFF00a86b).withOpacity(0.15)
                                      : Color(0xFFFF6B6B).withOpacity(0.15 * _pulseAnimation.value),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isStabilized
                                        ? Color(0xFF00a86b).withOpacity(0.4)
                                        : Color(0xFFFF6B6B).withOpacity(0.4 * _pulseAnimation.value),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Icono animado de GPS
                                    Transform.scale(
                                      scale: isStabilized ? 1.0 : _pulseAnimation.value,
                                      child: Icon(
                                        isStabilized
                                            ? Icons.gps_fixed_rounded
                                            : Icons.gps_not_fixed_rounded,
                                        color: isStabilized
                                            ? Color(0xFF00ff9f)
                                            : Color(0xFFFF6B6B),
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Texto del estado
                                    Text(
                                      isStabilized
                                          ? 'GPS estabilizado'
                                          : 'Estabilizando GPS...',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isStabilized
                                            ? Color(0xFF00ff9f)
                                            : Color(0xFFFF6B6B),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    // Indicador de carga cuando no está estabilizado
                                    if (!isStabilized) ...[
                                      SizedBox(width: 10),
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFFFF6B6B).withOpacity(_pulseAnimation.value),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        SizedBox(height: 8),

                        // Hint para long press
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: Color(0xFF00ff9f).withOpacity(0.6),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Mantén presionado para opciones avanzadas',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Información y sincronización
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            context.pushNamed(
                              InformationPageWidget.routeName,
                              extra: <String, dynamic>{
                                kTransitionInfoKey: TransitionInfo(
                                  hasTransition: true,
                                  transitionType:
                                      PageTransitionType.bottomToTop,
                                  duration: Duration(milliseconds: 1000),
                                ),
                              },
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 16.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: (FFAppState().visitsAdd.length > 0) ||
                                        (FFAppState().productsAdd.length > 0) ||
                                        (FFAppState().newsSelected.length > 0)
                                    ? [
                                        FlutterFlowTheme.of(context).orange,
                                        FlutterFlowTheme.of(context)
                                            .orange
                                            .withOpacity(0.7),
                                      ]
                                    : [
                                        FlutterFlowTheme.of(context).primary,
                                        FlutterFlowTheme.of(context)
                                            .primary
                                            .withOpacity(0.7),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 20,
                                  color: ((FFAppState().visitsAdd.length > 0) ||
                                              (FFAppState().productsAdd.length >
                                                  0) ||
                                              (FFAppState()
                                                      .newsSelected
                                                      .length >
                                                  0)
                                          ? FlutterFlowTheme.of(context).orange
                                          : FlutterFlowTheme.of(context)
                                              .primary)
                                      .withOpacity(0.4),
                                  offset: Offset(0, 8),
                                  spreadRadius: 2,
                                )
                              ],
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sync_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Información y sincronización',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: TextStyle(fontFamily: 'Roboto',
                                                fontWeight: FontWeight.bold,
                                              ),
                                              color: Colors.white,
                                              fontSize: 15,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        (FFAppState().visitsAdd.length > 0) ||
                                                (FFAppState()
                                                        .productsAdd
                                                        .length >
                                                    0)
                                            ? 'Hay información pendiente por sincronizar'
                                            : 'Sin información pendiente por sincronizar',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: TextStyle(fontFamily: 'Roboto',
                                                fontWeight: FontWeight.w500,
                                              ),
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              letterSpacing: 0.3,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStepCard(
    BuildContext context, {
    required String stepNumber,
    required String icon,
    required String title,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 14.0, 16.0, 14.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).primary.withOpacity(0.7),
                  ]
                : [
                    FlutterFlowTheme.of(context).orange,
                    FlutterFlowTheme.of(context).orange.withOpacity(0.7),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              color: (isCompleted
                      ? FlutterFlowTheme.of(context).primary
                      : FlutterFlowTheme.of(context).orange)
                  .withOpacity(0.3),
              offset: Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Número del paso
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Icono
            Container(
              width: 40,
              height: 40,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                icon,
                fit: BoxFit.contain,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            // Título
            Expanded(
              child: Text(
                title,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: TextStyle(fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
