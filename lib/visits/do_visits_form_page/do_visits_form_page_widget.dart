import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/components/nfc_read_dialog_widget.dart';
import '/components/nfc_write_dialog_widget.dart';
import '/components/nfc_transfer_dialog_widget.dart';
import '/components/nfc_transfer_write_dialog_widget.dart';
import '/components/photo_capture_component_widget.dart';
import '/components/date_picker_component_widget.dart';
import '/components/time_picker_component_widget.dart';
import '/components/text_input_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/services.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'do_visits_form_page_model.dart';
export 'do_visits_form_page_model.dart';

class DoVisitsFormPageWidget extends StatefulWidget {
  const DoVisitsFormPageWidget({
    super.key,
    String? tittle,
  }) : tittle = tittle ?? 'Módulo ClickPalm';

  final String tittle;

  static String routeName = 'DoVisitsFormPage';
  static String routePath = '/doVisitsFormPage';

  @override
  State<DoVisitsFormPageWidget> createState() => _DoVisitsFormPageWidgetState();
}

class _DoVisitsFormPageWidgetState extends State<DoVisitsFormPageWidget>
    with SingleTickerProviderStateMixin {
  late DoVisitsFormPageModel _model;
  late TabController _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Map para controlar el estado de expansión de cada step
  final Map<int, bool> _stepExpansionState = {};

  // Map para controlar el estado de expansión de cada status hijo
  final Map<String, bool> _statusExpansionState = {};

  // Map para queries de búsqueda por step
  final Map<int, String> _searchQueries = {};

  // Map para TextEditingControllers de búsqueda
  final Map<int, TextEditingController> _searchControllers = {};

  // Map para controlar el estado de expansión del search box
  final Map<int, bool> _searchBoxExpansionState = {};

  // Map para controlar el estado de expansión de los status del nivel raíz
  final Map<int, bool> _rootStatusExpansionState = {};

  // Map para rastrear si un número fue modificado usando up/down (vs cajones predeterminados)
  final Map<int, bool> _numberUsedUpDown = {};

  // Map para almacenar datos de tags NFC leídos por status_id
  final Map<int, List<Map<String, dynamic>>> _tagReaderData = {};

  // Map para controlar el estado de expansión del tree view de tag-reader (por lote)
  final Map<String, bool> _tagReaderExpansionState = {};

  // Map para almacenar geolocalizaciones capturadas al leer tags NFC por status_id
  final Map<int, ReadGeoStruct> _tagReaderGeolocations = {};

  // Map para almacenar datos de tags NFC escritos por status_id
  // La estructura es: statusId -> (headquarterId -> {totalVisits, totalResults, records})
  final Map<int, Map<int, Map<String, dynamic>>> _tagWriterData = {};

  // Map para controlar el estado de expansión del tree view de tag-writer (por lote)
  final Map<String, bool> _tagWriterExpansionState = {};

  // Map para almacenar datos de tags NFC transferidos por status_id
  // La estructura es: statusId -> (headquarterId -> {totalVisits, totalResults, records})
  final Map<int, Map<int, Map<String, dynamic>>> _tagTransferData = {};

  // Map para controlar el estado de expansión del tree view de tag-transfer (por lote)
  final Map<String, bool> _tagTransferExpansionState = {};

  // Map para rastrear si una transferencia fue completada exitosamente por statusId
  final Map<int, bool> _tagTransferCompleted = {};

  // Map para rastrear valores numéricos de status por nombre (para numbers-operation)
  // statusName -> valor numérico
  final Map<String, double> _statusValuesByName = {};

  // Map para almacenar valores calculados de numbers-operation por statusId
  final Map<int, double> _calculatedValues = {};

  // Map para rastrear si una operación fue calculada al menos una vez por statusId
  final Map<int, bool> _numbersOperationCalculated = {};

  // Map para controlar si se muestra la fórmula de una operación por statusId
  final Map<int, bool> _showFormulaForOperation = {};

  // Map para almacenar weights de headquarters por headquarterId
  // headquarterId -> weight
  final Map<int, double> _headquarterWeights = {};

  // Lista de lotes que NO tienen peso promedio configurado
  // Contiene: {headquarterId, headquarterName}
  final List<Map<String, dynamic>> _headquartersWithoutWeight = [];

  // Map para almacenar distancias calculadas por statusId (OPCIÓN 1: desde TAG)
  final Map<int, double> _calculatedDistances = {};

  // Map para almacenar distancias desde producto (OPCIÓN 2: lista por cada lote)
  // statusId -> List<{headquarterId, headquarterName, distance}>
  final Map<int, List<Map<String, dynamic>>> _calculatedDistancesFromProduct =
      {};

  // Map para rastrear si una distancia fue calculada al menos una vez por statusId
  final Map<int, bool> _distanceExtractorCalculated = {};

  // Map para almacenar la última coordenada del tag-reader
  ReadGeoStruct? _lastTagReaderLocation;

  // Set para rastrear qué status ya se loguearon (para evitar spam en logs)
  final Set<int> _loggedStatusIds = {};

  // ============================================================================
  // CACHÉ DE RENDIMIENTO - LOTE 1
  // ============================================================================

  // Caché de activity steps y status ordenados (evita parseo y sorting en cada rebuild)
  List<dynamic> _cachedActivitySteps = [];
  List<dynamic> _cachedActivityStatus = [];
  bool _isDataCacheInitialized = false;

  // Caché de búsquedas en visitDetails (evita O(n) en cada rebuild)
  final Map<String, bool> _visitDetailsSearchCache = {};
  int _lastVisitDetailsLength = 0;

  // Getter para obtener el texto de Unity o "Resultados" por defecto
  String get _unityLabel {
    final unityValue = getJsonField(
          FFAppState().currentActivity,
          r'''$.Unity''',
        )?.toString() ??
        '';

    return unityValue.isNotEmpty ? unityValue : 'Resultados';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoVisitsFormPageModel());
    _tabController = TabController(length: 2, vsync: this);
    _initializeDataCache(); // LOTE 1: Inicializar caché de datos
    _initializeExpansionStates();

    // Restaurar caché del formulario si existe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreFormCache();
      _initializeDateTimeDefaults();
    });
  }

  // ============================================================================
  // LOTE 1: INICIALIZACIÓN DE CACHÉ DE DATOS
  // ============================================================================

  /// Inicializa el caché de activity steps y status ordenados
  /// Se ejecuta una sola vez en initState, evitando parseo y sorting en cada rebuild
  void _initializeDataCache() {
    final activityStepsRawData = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );

    final activityStatusRawData = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_status''',
    );

    // Cachear y ordenar activity steps
    if (activityStepsRawData != null) {
      _cachedActivitySteps = List.from(activityStepsRawData.toList());
      _cachedActivitySteps.sort((a, b) {
        final orderA = getJsonField(a, r'''$.order_step''') ?? 999;
        final orderB = getJsonField(b, r'''$.order_step''') ?? 999;
        return orderA.compareTo(orderB);
      });
    }

    // Cachear y ordenar activity status
    if (activityStatusRawData != null) {
      _cachedActivityStatus = List.from(activityStatusRawData.toList());
      _cachedActivityStatus.sort((a, b) {
        final orderA = getJsonField(a, r'''$.order_status''') ?? 999;
        final orderB = getJsonField(b, r'''$.order_status''') ?? 999;
        return orderA.compareTo(orderB);
      });
    }

    _isDataCacheInitialized = true;
  }

  /// Invalida el caché de búsquedas cuando cambia visitDetails
  void _invalidateSearchCacheIfNeeded() {
    final currentLength = FFAppState().visitDetails.length;
    if (currentLength != _lastVisitDetailsLength) {
      _visitDetailsSearchCache.clear();
      _lastVisitDetailsLength = currentLength;
    }
  }

  /// Búsqueda cacheada en visitDetails (evita O(n) repetido)
  bool _cachedSearchInVisitDetails(int id, String type) {
    final cacheKey = '${type}_$id';
    if (!_visitDetailsSearchCache.containsKey(cacheKey)) {
      _visitDetailsSearchCache[cacheKey] = functions.searchInVisitsDetails(
        FFAppState().visitDetails.toList(),
        id,
        type,
      );
    }
    return _visitDetailsSearchCache[cacheKey]!;
  }

  @override
  void dispose() {
    // Guardar caché del formulario antes de salir
    _saveFormCache();
    _tabController.dispose();
    _model.dispose();
    // Disponer controllers de búsqueda
    _searchControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _initializeExpansionStates() {
    final activityStepsRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );

    // Si no hay activity_steps, retornar sin hacer nada
    if (activityStepsRaw == null) return;

    final activitySteps = activityStepsRaw.toList();

    for (var i = 0; i < activitySteps.length; i++) {
      final step = activitySteps[i];
      final isRequired = getJsonField(step, r'''$.is_required''') == true;
      final stepId = getJsonField(step, r'''$.id_activity_step''');

      // Si es requerido, empieza expandido; si no, colapsado
      _stepExpansionState[stepId] = isRequired;
    }
  }

  /// Genera una clave única para el caché basada en la actividad
  String _getCacheKey() {
    final activityId =
        getJsonField(FFAppState().currentActivity, r'''$.id_activity''');
    return 'form_cache_activity_$activityId';
  }

  /// Guarda el estado actual del formulario en caché
  void _saveFormCache() {
    try {
      debugPrint('');
      debugPrint('💾 ===== GUARDANDO CACHÉ DEL FORMULARIO =====');

      final cacheKey = _getCacheKey();
      debugPrint('🔑 Clave de caché: $cacheKey');

      // Crear un mapa con todo el estado del formulario
      final cacheData = <String, dynamic>{
        'visitDetails':
            FFAppState().visitDetails.map((v) => v.toMap()).toList(),
        'statusValuesByName': _statusValuesByName,
        'calculatedValues': _calculatedValues,
        'numbersOperationCalculated': _numbersOperationCalculated,
        'tagReaderData': _tagReaderData,
        'tagTransferData': _tagTransferData,
        'tagTransferCompleted': _tagTransferCompleted,
        'tagWriterData': _tagWriterData,
        'calculatedDistances': _calculatedDistances,
        'distanceExtractorCalculated': _distanceExtractorCalculated,
        'headquarterWeights': _headquarterWeights,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Guardar en FFAppState usando un Map temporal
      if (!FFAppState().formCacheMap.containsKey(cacheKey)) {
        FFAppState().formCacheMap[cacheKey] = {};
      }
      FFAppState().formCacheMap[cacheKey] = cacheData;

      debugPrint('✅ Caché guardado exitosamente');
      debugPrint(
          '   - visitDetails: ${FFAppState().visitDetails.length} items');
      debugPrint(
          '   - statusValuesByName: ${_statusValuesByName.length} valores');
      debugPrint('   - tagReaderData: ${_tagReaderData.length} tags');
      debugPrint('💾 ===== FIN GUARDADO DE CACHÉ =====');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error guardando caché: $e');
    }
  }

  /// Restaura el estado del formulario desde caché si existe
  void _restoreFormCache() {
    try {
      debugPrint('');
      debugPrint('📥 ===== RESTAURANDO CACHÉ DEL FORMULARIO =====');

      final cacheKey = _getCacheKey();
      debugPrint('🔑 Clave de caché: $cacheKey');

      // Verificar si existe caché para esta actividad
      if (!FFAppState().formCacheMap.containsKey(cacheKey)) {
        debugPrint('ℹ️ No se encontró caché para esta actividad');
        debugPrint('📥 ===== FIN RESTAURACIÓN (SIN CACHÉ) =====');
        debugPrint('');
        return;
      }

      final cacheData = FFAppState().formCacheMap[cacheKey];
      if (cacheData == null || cacheData.isEmpty) {
        debugPrint('ℹ️ Caché vacío');
        debugPrint('📥 ===== FIN RESTAURACIÓN (CACHÉ VACÍO) =====');
        debugPrint('');
        return;
      }

      debugPrint('✅ Caché encontrado');
      final timestamp = cacheData['timestamp'] as String?;
      if (timestamp != null) {
        final cacheDate = DateTime.parse(timestamp);
        final age = DateTime.now().difference(cacheDate);
        debugPrint('   Antigüedad del caché: ${age.inMinutes} minutos');
      }

      // Restaurar visitDetails
      if (cacheData['visitDetails'] != null) {
        final visitDetailsList = (cacheData['visitDetails'] as List)
            .map((item) =>
                VisitsDetailsStruct.fromMap(item as Map<String, dynamic>))
            .toList();
        FFAppState().visitDetails = visitDetailsList;
        debugPrint('   ✓ Restaurados ${visitDetailsList.length} visitDetails');
      }

      // Restaurar valores numéricos
      if (cacheData['statusValuesByName'] != null) {
        _statusValuesByName.clear();
        _statusValuesByName.addAll(
          Map<String, double>.from(cacheData['statusValuesByName'] as Map),
        );
        debugPrint(
            '   ✓ Restaurados ${_statusValuesByName.length} valores numéricos');
      }

      // Restaurar valores calculados
      if (cacheData['calculatedValues'] != null) {
        _calculatedValues.clear();
        _calculatedValues.addAll(
          Map<int, double>.from(cacheData['calculatedValues'] as Map),
        );
        debugPrint(
            '   ✓ Restaurados ${_calculatedValues.length} valores calculados');
      }

      // Restaurar flags de cálculo
      if (cacheData['numbersOperationCalculated'] != null) {
        _numbersOperationCalculated.clear();
        _numbersOperationCalculated.addAll(
          Map<int, bool>.from(cacheData['numbersOperationCalculated'] as Map),
        );
      }

      // Restaurar tag reader data
      if (cacheData['tagReaderData'] != null) {
        _tagReaderData.clear();
        _tagReaderData.addAll(
          Map<int, List<Map<String, dynamic>>>.from(
              cacheData['tagReaderData'] as Map),
        );
        debugPrint('   ✓ Restaurados ${_tagReaderData.length} tag readers');
      }

      // Restaurar tag transfer data
      if (cacheData['tagTransferData'] != null) {
        _tagTransferData.clear();
        _tagTransferData.addAll(
          Map<int, Map<int, Map<String, dynamic>>>.from(
              cacheData['tagTransferData'] as Map),
        );
        debugPrint('   ✓ Restaurados ${_tagTransferData.length} tag transfers');
      }

      // Restaurar tag transfer completed
      if (cacheData['tagTransferCompleted'] != null) {
        _tagTransferCompleted.clear();
        _tagTransferCompleted.addAll(
          Map<int, bool>.from(cacheData['tagTransferCompleted'] as Map),
        );
      }

      // Restaurar tag writer data
      if (cacheData['tagWriterData'] != null) {
        _tagWriterData.clear();
        _tagWriterData.addAll(
          Map<int, Map<int, Map<String, dynamic>>>.from(
              cacheData['tagWriterData'] as Map),
        );
        debugPrint('   ✓ Restaurados ${_tagWriterData.length} tag writers');
      }

      // Restaurar distancias calculadas
      if (cacheData['calculatedDistances'] != null) {
        _calculatedDistances.clear();
        _calculatedDistances.addAll(
          Map<int, double>.from(cacheData['calculatedDistances'] as Map),
        );
        debugPrint(
            '   ✓ Restauradas ${_calculatedDistances.length} distancias');
      }

      // Restaurar flags de distancia
      if (cacheData['distanceExtractorCalculated'] != null) {
        _distanceExtractorCalculated.clear();
        _distanceExtractorCalculated.addAll(
          Map<int, bool>.from(cacheData['distanceExtractorCalculated'] as Map),
        );
      }

      // Restaurar weights de headquarters
      if (cacheData['headquarterWeights'] != null) {
        _headquarterWeights.clear();
        _headquarterWeights.addAll(
          Map<int, double>.from(cacheData['headquarterWeights'] as Map),
        );
        debugPrint('   ✓ Restaurados ${_headquarterWeights.length} weights');
      }

      debugPrint('✅ Caché restaurado exitosamente');
      debugPrint('📥 ===== FIN RESTAURACIÓN DE CACHÉ =====');
      debugPrint('');

      // Forzar actualización de la UI
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error restaurando caché: $e');
    }
  }

  /// Inicializa automáticamente campos de fecha/hora con comandos =DATENOW o =TIMENOW
  void _initializeDateTimeDefaults() {
    debugPrint('');
    debugPrint('📅 ===== INICIALIZANDO DEFAULTS DE FECHA/HORA =====');

    final activitySteps = getJsonField(
          FFAppState().currentActivity,
          r'''$.activity_steps''',
        )?.toList() ??
        [];

    int initialized = 0;

    // Función recursiva para procesar status
    void processStatus(dynamic status, int parentStepId) {
      final typeStatus =
          getJsonField(status, r'''$.type_status''')?.toString() ?? '';
      final statusId = getJsonField(status, r'''$.id_activity_status''');
      final statusName =
          getJsonField(status, r'''$.status_name''')?.toString() ?? '';
      final defaultStatus = getJsonField(status, r'''$.default_status''')
              ?.toString()
              .toUpperCase() ??
          '';
      final rememberStatus =
          getJsonField(status, r'''$.remember_status''') == true;

      debugPrint(
          '   🔎 Procesando: "$statusName" tipo=$typeStatus default="$defaultStatus"');

      // Verificar si es tipo date o time y tiene comando
      if (typeStatus.toLowerCase() == 'date' && defaultStatus == '=DATENOW') {
        // Verificar si ya existe en visitDetails
        final existingValue =
            functions.statusResponseByActivityStatusAlternative(
          statusId,
          FFAppState().visitDetails.toList(),
          parentStepId,
        );

        if (existingValue.isEmpty) {
          // Guardar fecha actual
          final now = DateTime.now();
          final dateString = now.toIso8601String();

          debugPrint('📅 Inicializando DATE con =DATENOW:');
          debugPrint('   Status: $statusName (ID: $statusId)');
          debugPrint('   Fecha: $dateString');

          FFAppState().addToVisitDetails(
            VisitsDetailsStruct(
              idVisitDetail: 0,
              idVisit: 0,
              idActivityStatus: statusId,
              statusOption: statusName,
              statusResponse: dateString,
              idStepParent: parentStepId,
              rememberStatus: rememberStatus,
              defaultStatus: defaultStatus,
              typeStatus: typeStatus,
              auxStep: parentStepId,
            ),
          );

          initialized++;
          debugPrint('   ✅ Guardado en visitDetails');
        } else {
          debugPrint('📅 DATE ya tiene valor, saltando: $statusName');
        }
      } else if (typeStatus.toLowerCase() == 'time' &&
          (defaultStatus == '=TIMENOW' || defaultStatus == '=HOURNOW')) {
        // Verificar si ya existe en visitDetails
        final existingValue =
            functions.statusResponseByActivityStatusAlternative(
          statusId,
          FFAppState().visitDetails.toList(),
          parentStepId,
        );

        if (existingValue.isEmpty) {
          // Guardar hora actual
          final now = TimeOfDay.now();
          final timeString = 'TimeOfDay(${now.hour}:${now.minute})';

          debugPrint('⏰ Inicializando TIME con =TIMENOW:');
          debugPrint('   Status: $statusName (ID: $statusId)');
          debugPrint('   Hora: $timeString');

          FFAppState().addToVisitDetails(
            VisitsDetailsStruct(
              idVisitDetail: 0,
              idVisit: 0,
              idActivityStatus: statusId,
              statusOption: statusName,
              statusResponse: timeString,
              idStepParent: parentStepId,
              rememberStatus: rememberStatus,
              defaultStatus: defaultStatus,
              typeStatus: typeStatus,
              auxStep: parentStepId,
            ),
          );

          initialized++;
          debugPrint('   ✅ Guardado en visitDetails');
        } else {
          debugPrint('⏰ TIME ya tiene valor, saltando: $statusName');
        }
      }

      // Buscar recursivamente en steps_childs
      final stepsChilds =
          getJsonField(status, r'''$.steps_childs''')?.toList() ?? [];
      for (var childStep in stepsChilds) {
        final childStepId = getJsonField(childStep, r'''$.id_activity_step''');
        final childStatusList =
            getJsonField(childStep, r'''$.activity_status''')?.toList() ?? [];
        for (var childStatus in childStatusList) {
          processStatus(childStatus, childStepId);
        }
      }

      // Buscar recursivamente en status_childs
      final statusChilds =
          getJsonField(status, r'''$.status_childs''')?.toList() ?? [];
      for (var childStatus in statusChilds) {
        processStatus(childStatus, parentStepId);
      }
    }

    // 1. Recorrer status raíz (activity_status)
    final activitiesStatus = getJsonField(
          FFAppState().currentActivity,
          r'''$.activity_status''',
        )?.toList() ??
        [];

    debugPrint('🔍 Buscando en ${activitiesStatus.length} status raíz...');
    for (var status in activitiesStatus) {
      processStatus(status, 0); // parentStepId = 0 para status raíz
    }

    // 2. Recorrer todos los steps y sus status
    debugPrint('🔍 Buscando en ${activitySteps.length} steps...');
    for (var step in activitySteps) {
      final stepId = getJsonField(step, r'''$.id_activity_step''');
      final statusList =
          getJsonField(step, r'''$.activity_status''')?.toList() ?? [];
      for (var status in statusList) {
        processStatus(status, stepId);
      }
    }

    if (initialized > 0) {
      setState(() {});
      debugPrint('');
      debugPrint('📈 Total campos inicializados: $initialized');
    }

    debugPrint('📅 ===== FIN INICIALIZACIÓN DEFAULTS =====');
    debugPrint('');
  }

  // ==========================================================================
  // VALIDACIÓN DE CAMPOS OBLIGATORIOS
  // ==========================================================================

  /// Valida recursivamente todos los steps requeridos en la jerarquía
  /// Retorna un mapa con los steps faltantes y su ruta para expansión
  Map<String, dynamic>? _validateRequiredStepsRecursive() {
    final activityStepsRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );
    if (activityStepsRaw == null) return null;
    final activitySteps = activityStepsRaw.toList();

    final visitDetails = FFAppState().visitDetails;

    // Función recursiva para validar steps y sus hijos
    Map<String, dynamic>? checkStep(dynamic step, List<int> parentPath) {
      final stepId = getJsonField(step, r'''$.id_activity_step''');
      final stepName = getJsonField(step, r'''$.name_step''').toString();
      final isRequired = getJsonField(step, r'''$.is_required''') == true;
      final activitiesStatusRaw =
          getJsonField(step, r'''$.activities_status''');
      final activitiesStatus = activitiesStatusRaw != null
          ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
          : [];

      // Si no es requerido, no validar
      if (!isRequired) {
        return null;
      }

      // Si tiene opciones de status y es requerido, verificar que al menos una esté seleccionada
      if (activitiesStatus.isNotEmpty) {
        // Buscar si hay algún visitDetail con idStepParent igual a este stepId
        final hasSelection =
            visitDetails.any((detail) => detail.idStepParent == stepId);

        if (!hasSelection) {
          // Este step requerido no tiene ninguna opción seleccionada
          return {
            'stepId': stepId,
            'stepName': stepName,
            'path': [...parentPath, stepId],
            'message': 'Debe seleccionar una opción en "$stepName"',
          };
        }

        // Si tiene selección, verificar los steps hijos de las opciones seleccionadas
        for (var detail in visitDetails) {
          if (detail.idStepParent == stepId) {
            // Encontrar el status seleccionado
            final selectedStatus = activitiesStatus.firstWhere(
              (status) =>
                  getJsonField(status, r'''$.id_activity_status''') ==
                  detail.idActivityStatus,
              orElse: () => null,
            );

            if (selectedStatus != null) {
              // Verificar steps hijos de este status
              final stepsChilds =
                  getJsonField(selectedStatus, r'''$.activities_steps_childs''')
                      .toList();

              for (var childStep in stepsChilds) {
                final childResult =
                    checkStep(childStep, [...parentPath, stepId]);
                if (childResult != null) {
                  return childResult; // Retornar el primer error encontrado
                }
              }
            }
          }
        }
      }

      return null;
    }

    // Validar todos los steps de nivel raíz
    for (var step in activitySteps) {
      final result = checkStep(step, []);
      if (result != null) {
        return result; // Retornar el primer step faltante
      }
    }

    return null; // Todo válido
  }

  /// Expande el árbol hasta el step especificado por la ruta
  void _expandTreeToStep(List<int> path) {
    for (var stepId in path) {
      setState(() {
        _stepExpansionState[stepId] = true;
      });
    }

    // Hacer scroll al elemento (pequeño delay para que el árbol se expanda)
    Future.delayed(const Duration(milliseconds: 300), () {
      // Aquí podrías agregar lógica de scroll si tienes una GlobalKey para el step
      debugPrint('Árbol expandido hasta stepId: ${path.last}');
    });
  }

  @override
  Widget build(BuildContext context) {
    // LOTE 1: Usar Selector para escuchar solo cambios en visitDetails
    // en lugar de context.watch<FFAppState>() que escucha TODOS los cambios
    // ignore: unused_local_variable
    final _ = context.select<FFAppState, int>(
      (state) => state.visitDetails.length,
    );

    // Invalidar caché de búsquedas si cambió visitDetails
    _invalidateSearchCacheIfNeeded();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Column(
        children: [
          // Contenido del formulario
          Expanded(
            child: _buildFormContent(),
          ),

          // Botones de navegación
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    // LOTE 1: Usar datos cacheados en lugar de parsear y ordenar en cada rebuild
    if (!_isDataCacheInitialized) {
      return const SizedBox.shrink();
    }

    // Usar los datos ya ordenados del caché
    final activitySteps = _cachedActivitySteps;
    final activityStatus = _cachedActivityStatus;

    if (activitySteps.isEmpty && activityStatus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay pasos configurados',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: activitySteps.length + activityStatus.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < activitySteps.length) {
          return _buildStepCard(activitySteps[index], level: 0);
        } else {
          // Renderizar status del nivel raíz
          final statusIndex = index - activitySteps.length;
          return _buildRootStatusCard(
            activityStatus[statusIndex],
            allActivityStatus: activityStatus,
            level: 0,
          );
        }
      },
    );
  }

  Widget _buildStepCard(dynamic step, {required int level}) {
    final stepId = getJsonField(step, r'''$.id_activity_step''');
    final stepName = getJsonField(step, r'''$.name_step''').toString();
    final typeStep = getJsonField(step, r'''$.type_step''').toString();
    final isRequired = getJsonField(step, r'''$.is_required''') == true;
    final activitiesStatusRaw = getJsonField(step, r'''$.activities_status''');
    final activitiesStatus = activitiesStatusRaw != null
        ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
        : [];

    // Log de renderizado
    debugPrint('📋 RENDERIZANDO STEP: nombre="$stepName" tipo="$typeStep" ID=$stepId nivel=$level requerido=$isRequired activitiesStatus=${activitiesStatus.length}');

    // Obtener estado de expansión (funciona para todos los tipos de steps)
    final isExpanded = _stepExpansionState[stepId] ?? false;
    // LOTE 1: Usar búsqueda cacheada en lugar de O(n) repetido
    final hasValue = _cachedSearchInVisitDetails(stepId, 'STEP');

    // Calcular cuántos status son requeridos o cuántos steps hijos existen
    int totalRequired = 0;
    int totalCompleted = 0;

    for (var status in activitiesStatus) {
      final stepsChildsRaw =
          getJsonField(status, r'''$.activities_steps_childs''');
      final stepsChilds = stepsChildsRaw != null
          ? (stepsChildsRaw is List ? stepsChildsRaw : [])
          : [];

      // Si este status tiene steps hijos, contar los requeridos
      for (var childStep in stepsChilds) {
        final childRequired =
            getJsonField(childStep, r'''$.is_required''') == true;
        if (childRequired) {
          totalRequired++;
          final childStepId =
              getJsonField(childStep, r'''$.id_activity_step''');
          // LOTE 1: Usar búsqueda cacheada
          final childCompleted =
              _cachedSearchInVisitDetails(childStepId, 'STEP');
          if (childCompleted) {
            totalCompleted++;
          }
        }
      }
    }

    return Column(
      children: [
        // Header del step
        InkWell(
          onTap: () {
            setState(() {
              _stepExpansionState[stepId] = !isExpanded;
              // Si se está colapsando el step, cerrar también el search box
              if (isExpanded) {
                _searchBoxExpansionState[stepId] = false;
              }
            });
          },
          child: Container(
            margin: EdgeInsets.only(left: level * 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // INVERTIDO: Verde cuando completado, Naranja cuando NO completado
                colors: hasValue
                    ? [
                        const Color(0xFF00a86b),
                        const Color(0xFF00d980),
                      ]
                    : [
                        const Color(0xFFF1F8F4),
                        const Color(0xFFFAFDFB),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: hasValue
                      ? const Color(0xFF00a86b).withValues(alpha: 0.4)
                      : const Color(0xFFE8F5E9).withValues(alpha: 0.4),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  children: [
                    // Indicador de nivel
                    if (level > 0)
                      Container(
                        width: 3,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF00ff9f),
                              Color(0xFF00a86b),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    // Icono de expansión
                    if (activitiesStatus.isNotEmpty)
                      Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        color:
                            hasValue ? Colors.white : const Color(0xFF00a86b),
                        size: 36,
                        weight: 700,
                      ),
                    const SizedBox(width: 8),
                    // Nombre del step
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stepName,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: hasValue
                                  ? Colors.white
                                  : const Color(0xFF00a86b),
                              letterSpacing: 0.3,
                            ),
                          ),
                          // Breadcrumb de selecciones
                          _buildSelectionBreadcrumb(stepId, step),
                        ],
                      ),
                    ),
                    // Badge de progreso (si hay steps hijos requeridos)
                    if (totalRequired > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          // INVERTIDO: Verde cuando completado, Warning cuando incompleto
                          color: totalCompleted == totalRequired
                              ? const Color(0xFF00a86b).withValues(alpha: 0.3)
                              : FlutterFlowTheme.of(context)
                                  .warning
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: totalCompleted == totalRequired
                                ? const Color(0xFF00a86b)
                                : FlutterFlowTheme.of(context).warning,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$totalCompleted/$totalRequired',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: totalCompleted == totalRequired
                                ? const Color(0xFF00a86b)
                                : FlutterFlowTheme.of(context).warning,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    // Badge de requerido (solo mostrar cuando NO tiene valor)
                    if (isRequired && !hasValue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).error,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '*',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context).error,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    // Botón de búsqueda compacto (para unique-list y reference-list)
                    // Solo visible cuando el step está expandido
                    if ((typeStep == 'unique-list' ||
                            typeStep == 'reference-list') &&
                        activitiesStatus.isNotEmpty &&
                        isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCompactSearchButton(stepId),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cuadro de búsqueda expandido (solo cuando está activo)
        if ((typeStep == 'unique-list' || typeStep == 'reference-list') &&
            (_searchBoxExpansionState[stepId] ?? false))
          _buildExpandedSearchBox(stepId),

        // Lista de opciones (cuando está expandido)
        if (isExpanded && activitiesStatus.isNotEmpty)
          Builder(
            builder: (context) {
              debugPrint('   ✅ MOSTRANDO OPCIONES: paso la condición isExpanded=$isExpanded && activitiesStatus.isNotEmpty=${activitiesStatus.isNotEmpty}');
              final filteredList = _filterStatusList(stepId, activitiesStatus);
              debugPrint('   📋 Lista filtrada: ${filteredList.length} opciones de ${activitiesStatus.length}');
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(left: level * 8.0 + 8, top: 8),
                child: Column(
                  children: [
                    // Lista filtrada de status
                    ...(_filterStatusList(stepId, activitiesStatus))
                        .map<Widget>((status) {
                      return _buildStatusOption(step, status, level: level + 1);
                    }),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatusOption(dynamic parentStep, dynamic status,
      {required int level}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();

    // Log de renderizado (comentado para evitar spam en consola)
    // debugPrint('  🔹 RENDERIZANDO STATUS: nombre="$statusName" tipo="$typeStatus" ID=$statusId nivel=$level');
    final statusColor =
        getJsonField(status, r'''$.color''')?.toString() ?? '#00ff9f';
    final stepsChildsRaw =
        getJsonField(status, r'''$.activities_steps_childs''');
    final stepsChilds = stepsChildsRaw != null
        ? (stepsChildsRaw is List ? stepsChildsRaw : [])
        : [];
    final statusChildsRaw =
        getJsonField(status, r'''$.activities_status_childs''');
    final statusChilds = statusChildsRaw != null
        ? (statusChildsRaw is List ? statusChildsRaw : [])
        : [];
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');

    // LOTE 1: Usar búsqueda cacheada
    final isSelected = _cachedSearchInVisitDetails(statusId, 'STATUS');

    final expansionKey = '${parentStepId}_$statusId';
    final isExpanded = _statusExpansionState[expansionKey] ?? false;

    // Verificar si tiene algún tipo de hijos
    final hasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;

    // Para status de tipo "number", "tag-writer", "tag-reader", "tag-transfer", "numbers-operation", "headquarter-weight", "label-info", "distance-extractor" y "dynamic-printing", NO abrir diálogo, mostrar control inline
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isTagWriterType = typeStatus.toLowerCase() == 'tag-writer';
    final isTagReaderType = typeStatus.toLowerCase() == 'tag-reader';
    final isTagTransferType = typeStatus.toLowerCase() == 'tag-transfer';
    final isNumbersOperationType =
        typeStatus.toLowerCase() == 'numbers-operation';
    final isHeadquarterWeightType =
        typeStatus.toLowerCase() == 'headquarter-weight';
    final isLabelInfoType = typeStatus.toLowerCase() == 'label-info';
    final isDistanceExtractorType =
        typeStatus.toLowerCase() == 'distance-extractor';
    final isDynamicPrintingType =
        typeStatus.toLowerCase() == 'dynamic-printing';

    // Convertir color hex a Color
    Color parseColor(String hexColor) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return const Color(0xFF00ff9f); // Color por defecto
      }
    }

    final color = parseColor(statusColor);

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            debugPrint('');
            debugPrint('═════════════════════════════════════════');
            debugPrint('🔘 🔘 🔘 STATUS TAP DETECTADO 🔘 🔘 🔘');
            debugPrint('   Nombre: $statusName');
            debugPrint('   Tipo: $typeStatus');
            debugPrint('   ID: $statusId');
            debugPrint('═════════════════════════════════════════');
            debugPrint('');

            // Si es tipo number, seleccionar automáticamente y mostrar control inline
            if (isNumberType) {
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo tag-writer, abrir el diálogo de escritura NFC
            if (isTagWriterType) {
              final result = await showDialog<bool>(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcWriteDialogWidget(),
                  );
                },
              );

              // Si la escritura fue exitosa, cargar los datos del tag desde el contenido escrito
              if (result == true) {
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  // Parsear el contenido del tag y agrupar por headquarterId
                  final parsedData =
                      _parseNfcTagContentByHeadquarter(nfcContent);
                  setState(() {
                    _tagWriterData[statusId] = parsedData;
                  });
                }
              }
              return;
            }

            // Si es tipo tag-reader, abrir el componente de lectura NFC
            if (isTagReaderType) {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(autoStart: true),
                  );
                },
              );

              // Obtener el contenido del tag desde FFAppState
              final nfcContent = FFAppState().nfcRead;
              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Esperar por una geolocalización válida antes de mostrar el resumen
                if (!mounted) return;
                final geolocation = await _waitForValidGeolocation(context);

                if (geolocation != null) {
                  // Parsear el contenido del tag
                  final parsedData = _parseNfcTagContent(nfcContent);
                  setState(() {
                    _tagReaderData[statusId] = parsedData;
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                  });

                  // VALIDACIÓN DE PESO PROMEDIO: Extraer headquarterIds del tag y verificar pesos
                  final List<int> tagHeadquarterIds = [];
                  for (var record in parsedData) {
                    final hqId = record['headquarterId'] as int? ?? 0;
                    if (hqId > 0 && !tagHeadquarterIds.contains(hqId)) {
                      tagHeadquarterIds.add(hqId);
                    }
                  }

                  // Verificar si los lotes tienen peso promedio configurado
                  if (tagHeadquarterIds.isNotEmpty) {
                    debugPrint(
                        '🔍 TAG-READER: Verificando peso promedio para ${tagHeadquarterIds.length} lote(s)...');
                    await _loadHeadquarterWeights(tagHeadquarterIds);

                    // Si hay lotes sin peso, mostrar advertencia
                    if (_headquartersWithoutWeight.isNotEmpty) {
                      debugPrint(
                          '⚠️ TAG-READER: ${_headquartersWithoutWeight.length} lote(s) sin peso promedio');
                      if (mounted) {
                        _showWeightWarningDialog();
                      }
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, leer SOLO el tag de origen
            if (isTagTransferType) {
              // Resetear estado de transferencia completada al seleccionar nuevamente
              setState(() {
                _tagTransferCompleted[statusId] = false;
              });

              debugPrint('');
              debugPrint('🔄 TAG-TRANSFER: Iniciando lectura de tag de ORIGEN');

              // Abrir diálogo de lectura NFC (solo leer, no transferir aún)
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(autoStart: true),
                  );
                },
              );

              // Procesar el contenido del tag de origen desde FFAppState
              final nfcContent = FFAppState().nfcRead;
              debugPrint(
                  '📄 TAG-TRANSFER: Contenido del tag de origen leído: ${nfcContent.length} caracteres');

              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Parsear el contenido del tag y agrupar por headquarterId
                final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
                debugPrint(
                    '📊 TAG-TRANSFER: Datos parseados: ${parsedData.length} lotes');

                // Guardar los datos del tag de origen
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                });

                debugPrint(
                    '✅ TAG-TRANSFER: Tag de origen guardado correctamente');
                debugPrint(
                    '💡 TAG-TRANSFER: Ahora el usuario puede presionar "Transferir ahora"');

                // Seleccionar el status
                await _onStatusSelected(parentStep, status);
              } else {
                debugPrint('❌ TAG-TRANSFER: Error al leer tag de origen');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Error al leer el tag de origen'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }

              setState(() {});
              return;
            }

            // Si es tipo numbers-operation, calcular el valor automáticamente
            if (isNumbersOperationType) {
              final formula =
                  getJsonField(status, r'''$.default_status''')?.toString() ??
                      '';
              if (formula.isNotEmpty) {
                final result = _evaluateFormula(formula);
                if (result != null) {
                  setState(() {
                    _calculatedValues[statusId] = result;
                    // Marcar que esta operación fue calculada al menos una vez
                    _numbersOperationCalculated[statusId] = true;
                  });
                  debugPrint('🧮 Operación calculada: $formula = $result');
                }
              }
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo headquarter-weight, cargar weights desde SQLite
            if (isHeadquarterWeightType) {
              // Buscar el tag-reader previo en el árbol de steps
              // Obtener todos los headquarterIds del tag-reader más reciente
              final List<int> headquarterIds = [];

              // Buscar en _tagReaderData el status anterior
              for (var entry in _tagReaderData.entries) {
                final tagData = entry.value;
                for (var record in tagData) {
                  final hqId = record['headquarterId'] as int? ?? 0;
                  if (hqId > 0 && !headquarterIds.contains(hqId)) {
                    headquarterIds.add(hqId);
                  }
                }
              }

              // Cargar weights desde SQLite
              if (headquarterIds.isNotEmpty) {
                await _loadHeadquarterWeights(headquarterIds);
              }

              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo label-info, seleccionar automáticamente (solo muestra el nombre)
            if (isLabelInfoType) {
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo distance-extractor, calcular distancia automáticamente
            if (isDistanceExtractorType) {
              await _calculateDistance(statusId, status, parentStep);
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo dynamic-printing, seleccionar automáticamente (se maneja con botón inline)
            if (isDynamicPrintingType) {
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo photo, abrir el componente de captura de fotos
            if (typeStatus.toLowerCase() == 'photo') {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: PhotoCaptureComponentWidget(
                      idStatus: statusId,
                      statusName: statusName,
                      statusJSON: status,
                      idStepParent: parentStepId,
                    ),
                  );
                },
              );
              return;
            }

            // Si es tipo date, abrir el componente selector de fechas
            if (typeStatus.toLowerCase() == 'date') {
              debugPrint(
                  '✅ ✅ ✅ Condición date cumplida, abriendo dialog en pantalla completa...');
              try {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    debugPrint('🏗️ Construyendo DatePickerComponentWidget...');
                    return DatePickerComponentWidget(
                      idStatus: statusId,
                      statusName: statusName,
                      statusJSON: status,
                      idStepParent: parentStepId,
                    );
                  },
                );
                debugPrint('✅ Dialog cerrado correctamente');
              } catch (e) {
                debugPrint('❌ ERROR al abrir dialog: $e');
              }
              setState(() {});
              return;
            }
            debugPrint('❌ Condición date NO cumplida, continuando...');

            // Si es tipo time, abrir el componente selector de horas
            if (typeStatus.toLowerCase() == 'time') {
              debugPrint(
                  '⏰ Condición time cumplida, abriendo dialog en pantalla completa...');
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return TimePickerComponentWidget(
                    idStatus: statusId,
                    statusName: statusName,
                    statusJSON: status,
                    idStepParent: parentStepId,
                  );
                },
              );
              setState(() {});
              return;
            }

            // Si es tipo text, abrir el componente de entrada de texto
            if (typeStatus.toLowerCase() == 'text') {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: TextInputComponentWidget(
                      idStatus: statusId,
                      statusName: statusName,
                      statusJSON: status,
                      idStepParent: parentStepId,
                    ),
                  );
                },
              );
              return;
            }

            // Al seleccionar un status, guardar
            await _onStatusSelected(parentStep, status);

            setState(() {
              if (hasChildren) {
                // ✅ Si el status tiene hijos (activities_status_childs o activities_steps_childs):
                // - ALTERNAR (toggle) el estado de expansión del status
                final currentExpansion =
                    _statusExpansionState[expansionKey] ?? false;

                // COLAPSAR todos los status hermanos (del mismo step padre) antes de expandir
                if (!currentExpansion) {
                  // Obtener todos los status del step padre
                  final parentStepStatuses =
                      getJsonField(parentStep, r'''$.activities_status''')
                          .toList();

                  // Colapsar todos los status hermanos
                  for (var siblingStatus in parentStepStatuses) {
                    final siblingStatusId = getJsonField(
                        siblingStatus, r'''$.id_activity_status''');
                    final siblingExpansionKey =
                        '${parentStepId}_$siblingStatusId';
                    _statusExpansionState[siblingExpansionKey] = false;
                  }
                }

                _statusExpansionState[expansionKey] = !currentExpansion;

                // Si estamos expandiendo (no colapsando), mantener step padre expandido
                if (!currentExpansion) {
                  _stepExpansionState[parentStepId] = true;

                  // Expandir los steps hijos si son requeridos
                  for (var childStep in stepsChilds) {
                    final childStepId =
                        getJsonField(childStep, r'''$.id_activity_step''');
                    final isChildRequired =
                        getJsonField(childStep, r'''$.is_required''') == true;
                    if (isChildRequired) {
                      _stepExpansionState[childStepId] = true;
                    }
                  }
                }
              } else {
                // ✅ Si el status NO tiene hijos (ÚLTIMA ANIDACIÓN):
                // - COLAPSAR solo el step padre del status seleccionado
                _stepExpansionState[parentStepId] = false;

                // También colapsar todos los status hermanos del mismo step
                final parentStepStatuses =
                    getJsonField(parentStep, r'''$.activities_status''')
                        .toList();
                for (var siblingStatus in parentStepStatuses) {
                  final siblingStatusId =
                      getJsonField(siblingStatus, r'''$.id_activity_status''');
                  final siblingExpansionKey =
                      '${parentStepId}_$siblingStatusId';
                  _statusExpansionState[siblingExpansionKey] = false;
                }
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // INVERTIDO: Verde oscuro si está seleccionado (y no es number, tag-writer, tag-reader ni distance-extractor)
                colors: (isSelected &&
                        !isNumberType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType)
                    ? [
                        const Color(0xFF00a86b),
                        const Color(0xFF00d980),
                      ]
                    : [
                        const Color(0xFFF1F8F4),
                        const Color(0xFFFAFDFB),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // INVERTIDO: Verde oscuro si está seleccionado (y no es number, tag-writer, tag-reader ni distance-extractor)
                color: (isSelected &&
                        !isNumberType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType)
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Radio button visual
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isSelected &&
                                  !isNumberType &&
                                  !isTagWriterType &&
                                  !isTagReaderType)
                              ? Colors.white
                              : const Color(0xFF00a86b),
                          width: 3,
                        ),
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00a86b),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Icono específico para date y time, indicador de color para otros tipos
                    if (!isTagReaderType && !isTagWriterType)
                      Container(
                        width: 32,
                        height: 40,
                        decoration: BoxDecoration(
                          color: typeStatus.toLowerCase() == 'date' ||
                                  typeStatus.toLowerCase() == 'time'
                              ? color.withValues(alpha: 0.2)
                              : color,
                          borderRadius: BorderRadius.circular(6),
                          border: typeStatus.toLowerCase() == 'date' ||
                                  typeStatus.toLowerCase() == 'time'
                              ? Border.all(
                                  color: color,
                                  width: 2,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: typeStatus.toLowerCase() == 'date'
                            ? Icon(
                                Icons.calendar_today_rounded,
                                color: color,
                                size: 18,
                              )
                            : typeStatus.toLowerCase() == 'time'
                                ? Icon(
                                    Icons.access_time_rounded,
                                    color: color,
                                    size: 20,
                                  )
                                : null,
                      ),
                    if (!isTagReaderType && !isTagWriterType)
                      const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila superior: nombre + control numérico compacto + valores de fecha/hora
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        statusName,
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: (isDistanceExtractorType &&
                                                  (_distanceExtractorCalculated[
                                                          statusId] ??
                                                      false))
                                              ? const Color(
                                                  0xFF00695C) // Verde oscuro para distance-extractor calculado
                                              : (isSelected &&
                                                      !isNumberType &&
                                                      !isTagWriterType &&
                                                      !isTagReaderType &&
                                                      !isDistanceExtractorType)
                                                  ? Colors.white
                                                  : const Color(0xFF00a86b),
                                          letterSpacing: 0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    // Mostrar fecha seleccionada para tipo date (con IgnorePointer para que no bloquee taps)
                                    if (typeStatus.toLowerCase() == 'date')
                                      IgnorePointer(
                                        child: _buildDateValueDisplay(
                                            statusId, parentStepId),
                                      ),
                                    // Mostrar hora seleccionada para tipo time (con IgnorePointer para que no bloquee taps)
                                    if (typeStatus.toLowerCase() == 'time')
                                      IgnorePointer(
                                        child: _buildTimeValueDisplay(
                                            statusId, parentStepId),
                                      ),
                                  ],
                                ),
                              ),
                              // Control numérico compacto inline (- [número] +) al lado del nombre
                              if (typeStatus.toLowerCase() == 'number')
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child:
                                      _buildCompactInlineNumberControlForStatus(
                                    parentStep: parentStep,
                                    status: status,
                                  ),
                                ),
                            ],
                          ),
                          // Resumen del tag-reader (solo para tipo tag-reader) - DEBAJO
                          if (isTagReaderType &&
                              _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagReaderSummary(statusId: statusId),
                            ),
                          // Resumen del tag-writer (solo para tipo tag-writer) - DEBAJO
                          if (isTagWriterType &&
                              _tagWriterData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagWriterSummary(statusId: statusId),
                            ),
                          // Resumen del tag-transfer (solo para tipo tag-transfer) - DEBAJO
                          if (isTagTransferType &&
                              _tagTransferData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child:
                                  _buildTagTransferSummary(statusId: statusId),
                            ),
                          // Valor calculado de numbers-operation - DEBAJO
                          if (isNumbersOperationType &&
                              _calculatedValues.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildNumbersOperationDisplay(
                                statusId: statusId,
                                status: status,
                              ),
                            ),
                          // Display para label-info - DEBAJO
                          if (isLabelInfoType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildLabelInfoDisplay(
                                statusName: statusName,
                                statusId: statusId,
                                status: status,
                              ),
                            ),
                          // Display para distance-extractor - DEBAJO
                          if (isDistanceExtractorType &&
                              _calculatedDistances.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDistanceExtractorDisplay(
                                statusId: statusId,
                              ),
                            ),
                          // Resumen de weights de headquarters - DEBAJO
                          if (isHeadquarterWeightType &&
                              _headquarterWeights.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildHeadquarterWeightsDisplay(),
                            ),
                          // Cajones numéricos del 1 al 5 (solo para tipo number) - DEBAJO
                          if (typeStatus.toLowerCase() == 'number')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildNumberBoxesForStatus(
                                parentStep: parentStep,
                                status: status,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasChildren)
                      Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 32,
                        weight: 700,
                        color: const Color(0xFF00a86b),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Hijos expandidos (status o steps childs)
        if (isExpanded && hasChildren)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: [
                // ✅ PRIMERO: Mostrar status childs (opciones inmediatas del mismo nivel)
                ...statusChilds.map<Widget>((childStatus) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStatusOption(status, childStatus,
                        level: level + 1),
                  );
                }),

                // ✅ SEGUNDO: Mostrar steps childs (pasos adicionales más profundos)
                ...stepsChilds.map<Widget>((childStep) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStepCard(childStep, level: level + 1),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRootStatusCard(
    dynamic status, {
    required List<dynamic> allActivityStatus,
    required int level,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus =
        getJsonField(status, r'''$.default_status''')?.toString() ?? '';
    final stepsChildsRaw =
        getJsonField(status, r'''$.activities_steps_childs''');
    final stepsChilds = stepsChildsRaw != null
        ? (stepsChildsRaw is List ? stepsChildsRaw : [])
        : [];
    final statusChildsRaw =
        getJsonField(status, r'''$.activities_status_childs''');
    final statusChilds = statusChildsRaw != null
        ? (statusChildsRaw is List ? statusChildsRaw : [])
        : [];

    // Log de renderizado (solo la primera vez para cada status)
    if (!_loggedStatusIds.contains(statusId)) {
      _loggedStatusIds.add(statusId);
      debugPrint(
          '🎯 RENDERIZANDO ROOT STATUS: nombre="$statusName" tipo="$typeStatus" ID=$statusId nivel=$level default_status="$defaultStatus"');
    }

    final isExpanded = _rootStatusExpansionState[statusId] ?? false;
    // LOTE 1: Usar búsqueda cacheada
    final hasValue = _cachedSearchInVisitDetails(statusId, 'STATUS');

    final hasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;

    // Para status de tipo "number", "tag-writer", "tag-reader", "tag-transfer", "numbers-operation", "headquarter-weight", "label-info", "distance-extractor" y "dynamic-printing", NO abrir diálogo, mostrar control inline
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isTagWriterType = typeStatus.toLowerCase() == 'tag-writer';
    final isTagReaderType = typeStatus.toLowerCase() == 'tag-reader';
    final isTagTransferType = typeStatus.toLowerCase() == 'tag-transfer';
    final isNumbersOperationType =
        typeStatus.toLowerCase() == 'numbers-operation';
    final isHeadquarterWeightType =
        typeStatus.toLowerCase() == 'headquarter-weight';
    final isLabelInfoType = typeStatus.toLowerCase() == 'label-info';
    final isDistanceExtractorType =
        typeStatus.toLowerCase() == 'distance-extractor';
    final isDynamicPrintingType =
        typeStatus.toLowerCase() == 'dynamic-printing';

    // Calcular progreso de steps hijos requeridos
    int totalRequired = 0;
    int totalCompleted = 0;

    for (var childStep in stepsChilds) {
      final childRequired =
          getJsonField(childStep, r'''$.is_required''') == true;
      if (childRequired) {
        totalRequired++;
        final childStepId = getJsonField(childStep, r'''$.id_activity_step''');
        // LOTE 1: Usar búsqueda cacheada
        final childCompleted = _cachedSearchInVisitDetails(childStepId, 'STEP');
        if (childCompleted) {
          totalCompleted++;
        }
      }
    }

    return Column(
      children: [
        // Header del status raíz
        InkWell(
          onTap: () async {
            // Si es tipo number, NO hacer nada - el usuario interactúa con el control inline
            if (isNumberType) {
              return;
            }

            // Si es tipo tag-writer, abrir el diálogo de escritura NFC
            if (isTagWriterType) {
              final result = await showDialog<bool>(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcWriteDialogWidget(),
                  );
                },
              );

              // Si la escritura fue exitosa, cargar los datos del tag desde el contenido escrito
              if (result == true) {
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  // Parsear el contenido del tag y agrupar por headquarterId
                  final parsedData =
                      _parseNfcTagContentByHeadquarter(nfcContent);
                  setState(() {
                    _tagWriterData[statusId] = parsedData;
                  });
                }
              }
              return;
            }

            // Si es tipo tag-reader, abrir el componente de lectura NFC
            if (isTagReaderType) {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(autoStart: true),
                  );
                },
              );

              // Obtener el contenido del tag desde FFAppState
              final nfcContent = FFAppState().nfcRead;
              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Esperar por una geolocalización válida antes de mostrar el resumen
                if (!mounted) return;
                final geolocation = await _waitForValidGeolocation(context);

                if (geolocation != null) {
                  // Parsear el contenido del tag
                  final parsedData = _parseNfcTagContent(nfcContent);
                  setState(() {
                    _tagReaderData[statusId] = parsedData;
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                  });

                  // VALIDACIÓN DE PESO PROMEDIO: Extraer headquarterIds del tag y verificar pesos
                  final List<int> tagHeadquarterIds = [];
                  for (var record in parsedData) {
                    final hqId = record['headquarterId'] as int? ?? 0;
                    if (hqId > 0 && !tagHeadquarterIds.contains(hqId)) {
                      tagHeadquarterIds.add(hqId);
                    }
                  }

                  // Verificar si los lotes tienen peso promedio configurado
                  if (tagHeadquarterIds.isNotEmpty) {
                    debugPrint(
                        '🔍 TAG-READER: Verificando peso promedio para ${tagHeadquarterIds.length} lote(s)...');
                    await _loadHeadquarterWeights(tagHeadquarterIds);

                    // Si hay lotes sin peso, mostrar advertencia
                    if (_headquartersWithoutWeight.isNotEmpty) {
                      debugPrint(
                          '⚠️ TAG-READER: ${_headquartersWithoutWeight.length} lote(s) sin peso promedio');
                      if (mounted) {
                        _showWeightWarningDialog();
                      }
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, abrir el componente de transferencia NFC
            if (isTagTransferType) {
              await showDialog<bool>(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcTransferDialogWidget(),
                  );
                },
              );

              // readNFC cierra el diálogo automáticamente después de leer
              // Procesar el contenido del tag desde FFAppState
              debugPrint(
                  '✅ TAG-TRANSFER: Diálogo cerrado, procesando contenido');
              final nfcContent = FFAppState().nfcRead;
              debugPrint(
                  '📄 TAG-TRANSFER: Contenido desde FFAppState: $nfcContent');

              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Parsear el contenido del tag y agrupar por headquarterId
                final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
                debugPrint(
                    '📊 TAG-TRANSFER: Datos parseados: ${parsedData.length} lotes');
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                  debugPrint(
                      '✅ TAG-TRANSFER: Guardado en _tagTransferData[$statusId]');
                });
              } else {
                debugPrint(
                    '❌ TAG-TRANSFER: Contenido vacío o con error: $nfcContent');
              }
              return;
            }

            // Si es tipo dynamic-printing, el botón maneja su propia lógica
            if (isDynamicPrintingType) {
              debugPrint(
                  '🖨️ DYNAMIC-PRINTING: Tipo detectado, ignorando tap del contenedor');
              return;
            }

            if (hasChildren) {
              setState(() {
                // COLAPSAR todos los status hermanos antes de alternar este
                if (!isExpanded) {
                  // Colapsar todos los status raíz hermanos
                  for (var siblingStatus in allActivityStatus) {
                    final siblingStatusId = getJsonField(
                        siblingStatus, r'''$.id_activity_status''');
                    _rootStatusExpansionState[siblingStatusId] = false;
                  }
                }

                // Alternar el estado de expansión de este status
                _rootStatusExpansionState[statusId] = !isExpanded;
              });
            } else {
              // Si no tiene hijos, es un status simple que se puede seleccionar
              await _onRootStatusSelected(status);
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: level * 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // INVERTIDO: Verde oscuro si tiene valor (y no es number ni tag-writer), Naranja si NO tiene valor
                colors: (hasValue && !isNumberType && !isTagWriterType)
                    ? [
                        const Color(0xFF00a86b),
                        const Color(0xFF00d980),
                      ]
                    : [
                        const Color(0xFFF1F8F4),
                        const Color(0xFFFAFDFB),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                // INVERTIDO: Verde oscuro si tiene valor (y no es number ni tag-writer), Naranja si NO tiene valor
                color: (hasValue && !isNumberType && !isTagWriterType)
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  // INVERTIDO: Verde oscuro si tiene valor (y no es number, tag-writer ni tag-reader), Naranja si NO tiene valor
                  color: (hasValue &&
                          !isNumberType &&
                          !isTagWriterType &&
                          !isTagReaderType)
                      ? const Color(0xFF00a86b).withValues(alpha: 0.4)
                      : const Color(0xFFE8F5E9).withValues(alpha: 0.4),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  children: [
                    // Icono de expansión o tipo
                    if (hasChildren)
                      Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        color: (hasValue && !isNumberType && !isTagWriterType)
                            ? Colors.white
                            : const Color(0xFF00a86b),
                        size: 36,
                        weight: 700,
                      ),
                    if (!hasChildren &&
                        typeStatus != 'tag-writer' &&
                        typeStatus != 'tag-reader')
                      Icon(
                        typeStatus == 'number'
                            ? Icons.numbers_rounded
                            : typeStatus == 'text'
                                ? Icons.text_fields_rounded
                                : typeStatus == 'date'
                                    ? Icons.calendar_today_rounded
                                    : typeStatus == 'time'
                                        ? Icons.access_time_rounded
                                        : Icons.check_circle_outline_rounded,
                        color: (hasValue && !isNumberType && !isTagWriterType)
                            ? Colors.white
                            : const Color(0xFF00a86b),
                        size: 28,
                      ),
                    const SizedBox(width: 8),
                    // Nombre del status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila superior: nombre + control numérico compacto
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        statusName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: (isDistanceExtractorType &&
                                                  (_distanceExtractorCalculated[
                                                          statusId] ??
                                                      false))
                                              ? const Color(
                                                  0xFF00695C) // Verde oscuro para distance-extractor calculado
                                              : (hasValue &&
                                                      !isNumberType &&
                                                      !isTagWriterType &&
                                                      !isDistanceExtractorType)
                                                  ? Colors.white
                                                  : const Color(0xFF00a86b),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Mostrar valor de hora (inline)
                              if (typeStatus.toLowerCase() == 'time')
                                _buildTimeValueDisplay(statusId, 0,
                                    hasValue: hasValue),
                              // Control numérico compacto inline (- [número] +) al lado del nombre
                              if (isNumberType)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildCompactInlineNumberControl(
                                      status: status),
                                ),
                              // Botón de limpieza inline para tag-writer (antes del botón de lectura)
                              if (isTagWriterType &&
                                  _tagWriterData.containsKey(statusId))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagWriterCleanupButton(
                                    statusId: statusId,
                                  ),
                                ),
                              // Botón inline para tag-writer (NFC)
                              if (isTagWriterType)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagWriterButton(
                                    context: context,
                                    statusName: statusName,
                                    statusId: statusId,
                                  ),
                                ),
                              // Botón de limpieza inline para tag-reader (antes del botón de lectura)
                              if (isTagReaderType &&
                                  _tagReaderData.containsKey(statusId))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagReaderCleanupButton(
                                    statusId: statusId,
                                  ),
                                ),
                              // Botón inline para tag-reader (NFC)
                              if (isTagReaderType)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagReaderButton(
                                    context: context,
                                    statusName: statusName,
                                  ),
                                ),
                              // Botón de limpieza inline para tag-transfer (antes del botón de lectura)
                              if (isTagTransferType &&
                                  _tagTransferData.containsKey(statusId))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagTransferCleanupButton(
                                    statusId: statusId,
                                  ),
                                ),
                              // Botón inline para tag-transfer (NFC)
                              if (isTagTransferType)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildTagTransferButton(
                                    context: context,
                                    statusName: statusName,
                                  ),
                                ),
                              // Botón inline para dynamic-printing
                              if (isDynamicPrintingType)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildDynamicPrintingButton(
                                    context: context,
                                    statusName: statusName,
                                    status: status,
                                  ),
                                ),
                            ],
                          ),
                          // Mostrar valor de fecha en fila separada DEBAJO del nombre
                          if (typeStatus.toLowerCase() == 'date')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDateValueDisplay(statusId, 0,
                                  hasValue: hasValue),
                            ),
                          // Resumen del tag-reader (solo para tipo tag-reader) - DEBAJO
                          if (isTagReaderType &&
                              _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagReaderSummary(statusId: statusId),
                            ),
                          // Resumen del tag-writer (solo para tipo tag-writer) - DEBAJO
                          if (isTagWriterType &&
                              _tagWriterData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagWriterSummary(statusId: statusId),
                            ),
                          // Resumen del tag-transfer (solo para tipo tag-transfer) - DEBAJO
                          if (isTagTransferType &&
                              _tagTransferData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child:
                                  _buildTagTransferSummary(statusId: statusId),
                            ),
                          // Valor calculado de numbers-operation - DEBAJO
                          if (isNumbersOperationType &&
                              _calculatedValues.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildNumbersOperationDisplay(
                                statusId: statusId,
                                status: status,
                              ),
                            ),
                          // Display para label-info - DEBAJO
                          if (isLabelInfoType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildLabelInfoDisplay(
                                statusName: statusName,
                                statusId: statusId,
                                status: status,
                              ),
                            ),
                          // Display para distance-extractor - DEBAJO
                          if (isDistanceExtractorType &&
                              _calculatedDistances.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDistanceExtractorDisplay(
                                statusId: statusId,
                              ),
                            ),
                          // Resumen de weights de headquarters - DEBAJO
                          if (isHeadquarterWeightType &&
                              _headquarterWeights.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildHeadquarterWeightsDisplay(),
                            ),
                          // Cajones numéricos del 1 al 5 (solo para tipo number) - DEBAJO
                          if (isNumberType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildNumberBoxes(status: status),
                            ),
                          if (!isNumberType &&
                              !isTagWriterType &&
                              !isTagReaderType &&
                              functions.showCurrentStatus(
                                      FFAppState().visitDetails.toList(),
                                      statusId) !=
                                  'N/A')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                functions.showCurrentStatus(
                                      FFAppState().visitDetails.toList(),
                                      statusId,
                                    ) ??
                                    '',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Badge de progreso (si hay steps hijos requeridos)
                    if (totalRequired > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          // INVERTIDO: Verde cuando completado, Warning cuando incompleto
                          color: totalCompleted == totalRequired
                              ? const Color(0xFF00a86b).withValues(alpha: 0.3)
                              : FlutterFlowTheme.of(context)
                                  .warning
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: totalCompleted == totalRequired
                                ? const Color(0xFF00a86b)
                                : FlutterFlowTheme.of(context).warning,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$totalCompleted/$totalRequired',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: totalCompleted == totalRequired
                                ? const Color(0xFF00a86b)
                                : FlutterFlowTheme.of(context).warning,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Hijos expandidos (steps o status childs)
        if (isExpanded && hasChildren)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(left: level * 8.0 + 8, top: 8),
            child: Column(
              children: [
                // Mostrar status childs primero
                ...statusChilds.map<Widget>((childStatus) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRootStatusChildOption(status, childStatus,
                        level: level + 1),
                  );
                }),

                // Mostrar steps childs
                ...stepsChilds.map<Widget>((childStep) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStepCard(childStep, level: level + 1),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRootStatusChildOption(dynamic parentStatus, dynamic childStatus,
      {required int level}) {
    final statusId = getJsonField(childStatus, r'''$.id_activity_status''');
    final statusName =
        getJsonField(childStatus, r'''$.status_name''').toString();
    final typeStatus =
        getJsonField(childStatus, r'''$.type_status''').toString();
    final statusColor =
        getJsonField(childStatus, r'''$.color''')?.toString() ?? '#00ff9f';
    final parentStatusId =
        getJsonField(parentStatus, r'''$.id_activity_status''');
    final stepsChildsRaw =
        getJsonField(childStatus, r'''$.activities_steps_childs''');
    final stepsChilds = stepsChildsRaw != null
        ? (stepsChildsRaw is List ? stepsChildsRaw : [])
        : [];
    final statusChildsRaw =
        getJsonField(childStatus, r'''$.activities_status_childs''');
    final statusChilds = statusChildsRaw != null
        ? (statusChildsRaw is List ? statusChildsRaw : [])
        : [];

    // Log de renderizado (solo la primera vez para cada status)
    if (!_loggedStatusIds.contains(statusId)) {
      _loggedStatusIds.add(statusId);
      debugPrint(
          '🔸 RENDERIZANDO ROOT STATUS CHILD: nombre="$statusName" tipo="$typeStatus" ID=$statusId parentID=$parentStatusId nivel=$level');
    }

    // LOTE 1: Usar búsqueda cacheada
    final isSelected = _cachedSearchInVisitDetails(statusId, 'STATUS');

    final expansionKey = 'root_${parentStatusId}_$statusId';
    final isExpanded = _statusExpansionState[expansionKey] ?? false;
    final hasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;

    // Para status de tipo "number", "tag-writer", "tag-reader", "tag-transfer" y "distance-extractor", NO cambiar color de la tarjeta
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isTagWriterType = typeStatus.toLowerCase() == 'tag-writer';
    final isTagReaderType = typeStatus.toLowerCase() == 'tag-reader';
    final isTagTransferType = typeStatus.toLowerCase() == 'tag-transfer';
    final isDistanceExtractorType =
        typeStatus.toLowerCase() == 'distance-extractor';

    // Convertir color hex a Color
    Color parseColor(String hexColor) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return const Color(0xFF00ff9f); // Color por defecto
      }
    }

    final color = parseColor(statusColor);

    return Column(
      children: [
        InkWell(
          onTap: () async {
            // Si es tipo tag-writer, abrir el diálogo de escritura NFC
            if (isTagWriterType) {
              final result = await showDialog<bool>(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcWriteDialogWidget(),
                  );
                },
              );

              // Si la escritura fue exitosa, cargar los datos del tag desde el contenido escrito
              if (result == true) {
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  // Parsear el contenido del tag y agrupar por headquarterId
                  final parsedData =
                      _parseNfcTagContentByHeadquarter(nfcContent);
                  setState(() {
                    _tagWriterData[statusId] = parsedData;
                  });
                }
              }
              return;
            }

            // Si es tipo tag-reader, abrir el componente de lectura NFC
            if (isTagReaderType) {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(autoStart: true),
                  );
                },
              );

              // Obtener el contenido del tag desde FFAppState
              final nfcContent = FFAppState().nfcRead;
              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Esperar por una geolocalización válida antes de mostrar el resumen
                if (!mounted) return;
                final geolocation = await _waitForValidGeolocation(context);

                if (geolocation != null) {
                  // Parsear el contenido del tag
                  final parsedData = _parseNfcTagContent(nfcContent);
                  setState(() {
                    _tagReaderData[statusId] = parsedData;
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                  });

                  // VALIDACIÓN DE PESO PROMEDIO: Extraer headquarterIds del tag y verificar pesos
                  final List<int> tagHeadquarterIds = [];
                  for (var record in parsedData) {
                    final hqId = record['headquarterId'] as int? ?? 0;
                    if (hqId > 0 && !tagHeadquarterIds.contains(hqId)) {
                      tagHeadquarterIds.add(hqId);
                    }
                  }

                  // Verificar si los lotes tienen peso promedio configurado
                  if (tagHeadquarterIds.isNotEmpty) {
                    debugPrint(
                        '🔍 TAG-READER: Verificando peso promedio para ${tagHeadquarterIds.length} lote(s)...');
                    await _loadHeadquarterWeights(tagHeadquarterIds);

                    // Si hay lotes sin peso, mostrar advertencia
                    if (_headquartersWithoutWeight.isNotEmpty) {
                      debugPrint(
                          '⚠️ TAG-READER: ${_headquartersWithoutWeight.length} lote(s) sin peso promedio');
                      if (mounted) {
                        _showWeightWarningDialog();
                      }
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, abrir el componente de transferencia NFC
            if (isTagTransferType) {
              await showDialog<bool>(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcTransferDialogWidget(),
                  );
                },
              );

              // readNFC cierra el diálogo automáticamente después de leer
              // Procesar el contenido del tag desde FFAppState
              debugPrint(
                  '✅ TAG-TRANSFER: Diálogo cerrado, procesando contenido');
              final nfcContent = FFAppState().nfcRead;
              debugPrint(
                  '📄 TAG-TRANSFER: Contenido desde FFAppState: $nfcContent');

              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Parsear el contenido del tag y agrupar por headquarterId
                final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
                debugPrint(
                    '📊 TAG-TRANSFER: Datos parseados: ${parsedData.length} lotes');
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                  debugPrint(
                      '✅ TAG-TRANSFER: Guardado en _tagTransferData[$statusId]');
                });
              } else {
                debugPrint(
                    '❌ TAG-TRANSFER: Contenido vacío o con error: $nfcContent');
              }
              return;
            }

            await _onRootStatusSelected(childStatus);

            setState(() {
              if (hasChildren) {
                // ✅ ALTERNAR (toggle) el estado de expansión del status
                final currentExpansion =
                    _statusExpansionState[expansionKey] ?? false;

                // COLAPSAR todos los status hermanos (del mismo parent status) antes de expandir
                if (!currentExpansion) {
                  // Obtener todos los status childs del parent status
                  final parentStatusChilds = getJsonField(
                          parentStatus, r'''$.activities_status_childs''')
                      .toList();

                  // Colapsar todos los status hermanos
                  for (var siblingStatus in parentStatusChilds) {
                    final siblingStatusId = getJsonField(
                        siblingStatus, r'''$.id_activity_status''');
                    final siblingExpansionKey =
                        'root_${parentStatusId}_$siblingStatusId';
                    _statusExpansionState[siblingExpansionKey] = false;
                  }
                }

                _statusExpansionState[expansionKey] = !currentExpansion;

                // Si estamos expandiendo (no colapsando), mantener root status expandido
                if (!currentExpansion) {
                  _rootStatusExpansionState[parentStatusId] = true;

                  // Auto-expand required child steps
                  for (var childStep in stepsChilds) {
                    final childStepId =
                        getJsonField(childStep, r'''$.id_activity_step''');
                    final isChildRequired =
                        getJsonField(childStep, r'''$.is_required''') == true;
                    if (isChildRequired) {
                      _stepExpansionState[childStepId] = true;
                    }
                  }
                }
              } else {
                // ✅ Si el status NO tiene hijos (ÚLTIMA ANIDACIÓN):
                // - COLAPSAR solo el status raíz padre
                _rootStatusExpansionState[parentStatusId] = false;

                // También colapsar todos los status hermanos (hijos del mismo padre)
                final parentStatusChilds = getJsonField(
                        parentStatus, r'''$.activities_status_childs''')
                    .toList();
                for (var siblingStatus in parentStatusChilds) {
                  final siblingStatusId =
                      getJsonField(siblingStatus, r'''$.id_activity_status''');
                  final siblingExpansionKey =
                      'root_${parentStatusId}_$siblingStatusId';
                  _statusExpansionState[siblingExpansionKey] = false;
                }
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // INVERTIDO: Verde oscuro si está seleccionado (y no es number, tag-writer, tag-reader ni distance-extractor)
                colors: (isSelected &&
                        !isNumberType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType)
                    ? [
                        const Color(0xFF00a86b),
                        const Color(0xFF00d980),
                      ]
                    : [
                        const Color(0xFFF1F8F4),
                        const Color(0xFFFAFDFB),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // INVERTIDO: Verde oscuro si está seleccionado (y no es number, tag-writer, tag-reader ni distance-extractor)
                color: (isSelected &&
                        !isNumberType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType)
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Radio button visual
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isSelected &&
                              !isNumberType &&
                              !isTagWriterType &&
                              !isTagReaderType)
                          ? Colors.white
                          : const Color(0xFF00a86b),
                      width: 3,
                    ),
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00a86b),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Indicador de color
                Container(
                  width: 32,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    statusName,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: (isDistanceExtractorType &&
                              (_distanceExtractorCalculated[statusId] ?? false))
                          ? const Color(
                              0xFF00695C) // Verde oscuro para distance-extractor calculado
                          : (isSelected &&
                                  !isNumberType &&
                                  !isTagWriterType &&
                                  !isTagReaderType &&
                                  !isDistanceExtractorType)
                              ? Colors.white
                              : const Color(0xFF00a86b),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (hasChildren)
                  Icon(
                    isExpanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 32,
                    weight: 700,
                    color: const Color(0xFF00a86b),
                  ),
              ],
            ),
          ),
        ),

        // Hijos expandidos (status o steps childs)
        if (isExpanded && hasChildren)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: [
                // ✅ PRIMERO: Mostrar status childs (opciones inmediatas del mismo nivel)
                ...statusChilds.map<Widget>((nestedStatus) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRootStatusChildOption(
                        childStatus, nestedStatus,
                        level: level + 1),
                  );
                }),

                // ✅ SEGUNDO: Mostrar steps childs (pasos adicionales más profundos)
                ...stepsChilds.map<Widget>((childStep) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStepCard(childStep, level: level + 1),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _onRootStatusSelected(dynamic status) async {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    final rememberStatus =
        getJsonField(status, r'''$.remember_status''') == true;

    // ⚠️ Si es tipo "number", "tag-writer" o "tag-reader", NO hacer nada (el control inline ya está visible)
    // El usuario interactúa directamente con los botones +/- del control inline (number)
    // o con el botón NFC (tag-writer/tag-reader)
    if (typeStatus.toLowerCase() == 'number' ||
        typeStatus.toLowerCase() == 'tag-writer' ||
        typeStatus.toLowerCase() == 'tag-reader') {
      return;
    }

    // Para otros tipos, guardar valor por defecto
    _saveRootStatusValue(
      statusId: statusId,
      statusName: statusName,
      statusResponse: defaultStatus,
      typeStatus: typeStatus,
      defaultStatus: defaultStatus,
      rememberStatus: rememberStatus,
    );
  }

  int _getCurrentNumberValue(int statusId, String defaultStatus) {
    for (var detail in FFAppState().visitDetails) {
      if (detail.idActivityStatus == statusId) {
        return int.tryParse(detail.statusResponse) ?? 0;
      }
    }
    return int.tryParse(defaultStatus) ?? 0;
  }

  void _saveRootStatusValue({
    required int statusId,
    required String statusName,
    required String statusResponse,
    required String typeStatus,
    required String defaultStatus,
    required bool rememberStatus,
  }) {
    // Buscar si ya existe un registro con este statusId
    int existingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
        existingIndex = i;
        break;
      }
    }

    if (existingIndex >= 0) {
      // Si ya existe, actualizar el registro
      FFAppState().updateVisitDetailsAtIndex(
        existingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: statusResponse,
          idStepParent: 0,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: 0,
        ),
      );
    } else {
      // Si no existe, agregarlo
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: statusResponse,
          idStepParent: 0,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: 0,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _onStatusSelected(dynamic parentStep, dynamic status) async {
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    final rememberStatus =
        getJsonField(status, r'''$.remember_status''') == true;
    final stepName = getJsonField(parentStep, r'''$.name_step''').toString();
    final typeStep = getJsonField(parentStep, r'''$.type_step''').toString();

    // LÓGICA CLAVE: Por cada id_step_parent solo puede haber UN id_activity_status activo
    // Si selecciono otro status en el mismo step, ELIMINAR el anterior y AGREGAR el nuevo

    // 1. Eliminar TODOS los status previos (idActivityStatus != 0) con el mismo id_step_parent
    List<int> indicesToRemove = [];
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
          FFAppState().visitDetails[i].idActivityStatus != 0) {
        indicesToRemove.add(i);
      }
    }

    // Remover en orden inverso para no alterar los índices
    for (int i = indicesToRemove.length - 1; i >= 0; i--) {
      FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
    }

    // 2. Agregar el nuevo status seleccionado
    // Aplicar la lógica correcta según el tipo del step padre
    String finalStatusOption = statusName;
    String finalStatusResponse = defaultStatus;

    // Si el step padre es de tipo "reference-list", invertir los valores
    if (typeStep.toLowerCase() == 'reference-list') {
      finalStatusOption = stepName; // Nombre del step padre
      finalStatusResponse = statusName; // Nombre del status seleccionado
    }

    FFAppState().addToVisitDetails(
      VisitsDetailsStruct(
        idVisitDetail: 0,
        idVisit: 0,
        idActivityStatus: statusId,
        statusOption: finalStatusOption,
        statusResponse: finalStatusResponse,
        idStepParent: parentStepId,
        rememberStatus: rememberStatus,
        defaultStatus: defaultStatus,
        typeStatus: typeStatus,
        auxStep: parentStepId,
      ),
    );

    // 3. Marcar el step padre como completado
    // Buscar si ya existe un registro del step (idActivityStatus == 0)
    int stepExistingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
          FFAppState().visitDetails[i].idActivityStatus == 0) {
        stepExistingIndex = i;
        break;
      }
    }

    if (stepExistingIndex >= 0) {
      // Actualizar el registro del step con el nombre del status seleccionado
      FFAppState().updateVisitDetailsAtIndex(
        stepExistingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: 0,
          statusOption: stepName,
          statusResponse: statusName,
          idStepParent: parentStepId,
          rememberStatus: false,
          defaultStatus: '',
          typeStatus: 'STEP',
          auxStep: parentStepId,
        ),
      );
    } else {
      // Crear el registro del step
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: 0,
          statusOption: stepName,
          statusResponse: statusName,
          idStepParent: parentStepId,
          rememberStatus: false,
          defaultStatus: '',
          typeStatus: 'STEP',
          auxStep: parentStepId,
        ),
      );
    }

    setState(() {});
  }

  Widget _buildNavigationButtons() {
    // Verificar si is_sync es true para mostrar el botón Guardar
    final currentActivity = FFAppState().currentActivity;
    final isSync = getJsonField(currentActivity, r'''$.is_sync''') == true;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                context.pushNamed(
                  DoActivitiesPageWidget.routeName,
                  extra: <String, dynamic>{
                    kTransitionInfoKey: const TransitionInfo(
                      hasTransition: true,
                      transitionType: PageTransitionType.fade,
                      duration: Duration(milliseconds: 500),
                    ),
                  },
                );
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FlutterFlowTheme.of(context).error,
                      FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      color: FlutterFlowTheme.of(context)
                          .error
                          .withValues(alpha: 0.4),
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Solo mostrar el separador y el botón Guardar si is_sync es true
          if (isSync) ...[
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  // Validar steps requeridos antes de guardar
                  final validationResult = _validateRequiredStepsRecursive();

                  if (validationResult != null) {
                    // Hay un step requerido sin completar
                    final message = validationResult['message'] as String;
                    final path = validationResult['path'] as List<int>;

                    // Expandir el árbol hasta el step faltante
                    _expandTreeToStep(path);

                    // Mostrar mensaje de error específico
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Campo Requerido',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 4000),
                        backgroundColor: FlutterFlowTheme.of(context).error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }

                  // Si la validación pasó, mostrar diálogo con LoadCoordinatesVisit
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    barrierColor: Colors.black.withValues(alpha: 0.85),
                    builder: (dialogContext) {
                      return Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        insetPadding: EdgeInsets.zero,
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.75,
                          width: MediaQuery.sizeOf(context).width * 0.95,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: custom_widgets.LoadCoordinatesVisit(
                              width: MediaQuery.sizeOf(context).width * 0.95,
                              height: MediaQuery.sizeOf(context).height * 0.75,
                            ),
                          ),
                        ),
                      );
                    },
                  );

                  // NUEVO: Limpiar los datos de tags que NO deben ser recordados después de crear la visita
                  _cleanupTagDatasByRememberFlag();

                  // El widget LoadCoordinatesVisit se cierra automáticamente
                  // El formulario permanece abierto para permitir crear más visitas
                  // visitDetails ya fue limpiado automáticamente (solo quedaron los con remember_status = true)
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FlutterFlowTheme.of(context).primary,
                        FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.4),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Guardar',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateNumberValue(
      dynamic parentStep, dynamic status, int newValue) async {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    final rememberStatus =
        getJsonField(status, r'''$.remember_status''') == true;
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');

    // Actualizar el valor en el Map para fórmulas (numbers-operation)
    _statusValuesByName[statusName] = newValue.toDouble();
    debugPrint('');
    debugPrint('🔢 ===== ACTUALIZACIÓN DE VALOR (STEP STATUS) =====');
    debugPrint('📝 Campo actualizado: "$statusName"');
    debugPrint('🔢 Valor nuevo: $newValue');
    debugPrint('📊 ID Status: $statusId');
    debugPrint('🗂️  ID Step Parent: $parentStepId');

    // Guardar el valor actualizado
    await _onStatusSelected(parentStep, status);

    // Actualizar el valor numérico en visitDetails
    int existingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
        existingIndex = i;
        break;
      }
    }

    if (existingIndex >= 0) {
      FFAppState().updateVisitDetailsAtIndex(
        existingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: newValue.toString(),
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    } else {
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: newValue.toString(),
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    }

    debugPrint('🔄 Llamando _recalculateOperations()...');
    // Recalcular todas las operaciones que dependen de este valor
    _recalculateOperations();
    debugPrint('✅ ===== FIN ACTUALIZACIÓN DE VALOR (STEP STATUS) =====');
    debugPrint('');
  }

  // ==========================================================================
  // LÓGICA DE FILTRADO
  // ==========================================================================

  List<dynamic> _filterStatusList(int stepId, List<dynamic> statusList) {
    final query = _searchQueries[stepId] ?? '';

    // Si no hay query, devolver toda la lista
    if (query.isEmpty) {
      return statusList;
    }

    // Filtrar por nombre de status
    return statusList.where((status) {
      final statusName =
          getJsonField(status, r'''$.status_name''').toString().toLowerCase();
      return statusName.contains(query);
    }).toList();
  }

  // ==========================================================================
  // CUADRO DE BÚSQUEDA ELEGANTE
  // ==========================================================================

  // Botón compacto en el header del step
  Widget _buildCompactSearchButton(int stepId) {
    final isExpanded = _searchBoxExpansionState[stepId] ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          _searchBoxExpansionState[stepId] = !isExpanded;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          // INVERTIDO: Verde cuando expandido
          color: isExpanded
              ? const Color(0xFF00a86b).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExpanded
                ? const Color(0xFF00a86b).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.search_rounded,
          size: 16,
          color: Color(0xFF00a86b),
        ),
      ),
    );
  }

  // Cuadro de búsqueda expandido
  Widget _buildExpandedSearchBox(int stepId) {
    // Obtener o crear controller
    if (!_searchControllers.containsKey(stepId)) {
      _searchControllers[stepId] = TextEditingController();
    }

    final controller = _searchControllers[stepId]!;
    final hasText = (_searchQueries[stepId] ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasText
                ? FlutterFlowTheme.of(context).primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icono de búsqueda
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: hasText
                    ? FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.8)
                    : const Color(0xFF00a86b),
              ),
            ),

            // Campo de texto
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQueries[stepId] = value.toLowerCase();
                  });
                },
              ),
            ),

            // Botón cerrar
            InkWell(
              onTap: () {
                controller.clear();
                setState(() {
                  _searchQueries[stepId] = '';
                  _searchBoxExpansionState[stepId] = false;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12, left: 8),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BREADCRUMB DE SELECCIONES
  // ==========================================================================

  Widget _buildSelectionBreadcrumb(int stepId, dynamic step) {
    final visitDetails = FFAppState().visitDetails.toList();
    final breadcrumbItems = <String>[];

    // Función recursiva para construir el breadcrumb
    void buildBreadcrumbRecursive(int currentStepId, dynamic currentStep) {
      // Buscar SOLO visitas de tipo STATUS (no STEP) para este step
      final stepVisits = visitDetails
          .where((visit) =>
                  visit.idStepParent == currentStepId &&
                  visit.statusOption.isNotEmpty &&
                  visit.statusOption != 'N/A' &&
                  visit.typeStatus !=
                      'STEP' // ✅ Excluir entradas de tipo STEP (son metadata interna)
              )
          .toList();

      if (stepVisits.isEmpty) return;

      // Tomar la última (más reciente) que tenga datos válidos
      final selectedVisit = stepVisits.last;
      final statusOption = selectedVisit.statusOption;
      final statusId = selectedVisit.idActivityStatus;

      // Agregar el nombre del status seleccionado
      breadcrumbItems.add(statusOption);

      // Buscar el status completo en el JSON para ver si tiene hijos
      final activitiesStatusRaw =
          getJsonField(currentStep, r'''$.activities_status''');
      final activitiesStatus = activitiesStatusRaw != null
          ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
          : [];

      for (var status in activitiesStatus) {
        final currentStatusId =
            getJsonField(status, r'''$.id_activity_status''');

        // Buscar por ID en lugar de nombre
        if (currentStatusId == statusId) {
          // Verificar si tiene steps_childs
          final stepsChildsRaw =
              getJsonField(status, r'''$.activities_steps_childs''');
          final stepsChilds = stepsChildsRaw != null
              ? (stepsChildsRaw is List ? stepsChildsRaw : [])
              : [];

          // Procesar cada step_child recursivamente
          for (var childStep in stepsChilds) {
            final childStepId =
                getJsonField(childStep, r'''$.id_activity_step''');

            // Verificar si este step_child tiene selección de STATUS (no STEP)
            final hasChildSelection = visitDetails.any((visit) =>
                visit.idStepParent == childStepId &&
                visit.typeStatus != 'STEP');

            if (hasChildSelection) {
              buildBreadcrumbRecursive(childStepId, childStep);
            }
          }

          // Verificar si tiene status_childs
          final statusChildsRaw =
              getJsonField(status, r'''$.activities_status_childs''');
          final statusChilds = statusChildsRaw?.toList() ?? [];

          for (var childStatus in statusChilds) {
            final childStatusId =
                getJsonField(childStatus, r'''$.id_activity_status''');

            // Verificar si este status_child está seleccionado (solo STATUS, no STEP)
            final isChildSelected = visitDetails.any((visit) =>
                visit.idActivityStatus == childStatusId &&
                visit.typeStatus != 'STEP');

            if (isChildSelected) {
              final childStatusName =
                  getJsonField(childStatus, r'''$.status_name''').toString();
              breadcrumbItems.add(childStatusName);

              // Si este status_child tiene steps_childs, procesarlos también
              final childStepsChilds =
                  getJsonField(childStatus, r'''$.activities_steps_childs''')
                      .toList();
              for (var nestedStep in childStepsChilds) {
                final nestedStepId =
                    getJsonField(nestedStep, r'''$.id_activity_step''');
                final hasNestedSelection = visitDetails.any((visit) =>
                    visit.idStepParent == nestedStepId &&
                    visit.typeStatus != 'STEP');

                if (hasNestedSelection) {
                  buildBreadcrumbRecursive(nestedStepId, nestedStep);
                }
              }
            }
          }

          break;
        }
      }
    }

    // Iniciar construcción del breadcrumb
    buildBreadcrumbRecursive(stepId, step);

    // Si no hay selecciones, no mostrar nada
    if (breadcrumbItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Construir el widget del breadcrumb
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (int i = 0; i < breadcrumbItems.length; i++) ...[
            // Texto del item
            Text(
              breadcrumbItems[i],
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),

            // Separador (excepto para el último item)
            if (i < breadcrumbItems.length - 1)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }

  // ===== MÉTODOS PARA ROOT NUMBER CONTROL =====

  void _updateRootNumberValue(dynamic status, int newValue) async {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    final rememberStatus =
        getJsonField(status, r'''$.remember_status''') == true;

    // Actualizar el valor en el Map para fórmulas (numbers-operation)
    _statusValuesByName[statusName] = newValue.toDouble();
    debugPrint('');
    debugPrint('🔢 ===== ACTUALIZACIÓN DE VALOR (ROOT STATUS) =====');
    debugPrint('📝 Campo actualizado: "$statusName"');
    debugPrint('🔢 Valor nuevo: $newValue');
    debugPrint('📊 ID Status: $statusId');

    // Guardar el valor actualizado usando el método específico para root status
    _saveRootStatusValue(
      statusId: statusId,
      statusName: statusName,
      statusResponse: newValue.toString(),
      typeStatus: typeStatus,
      defaultStatus: defaultStatus,
      rememberStatus: rememberStatus,
    );

    debugPrint('🔄 Llamando _recalculateOperations()...');
    // Recalcular todas las operaciones que dependen de este valor
    _recalculateOperations();
    debugPrint('✅ ===== FIN ACTUALIZACIÓN DE VALOR (ROOT STATUS) =====');
    debugPrint('');
  }

  // ===== CAJONES NUMÉRICOS DEL 1 AL 5 =====

  // Control numérico compacto para root status
  Widget _buildCompactInlineNumberControl({required dynamic status}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    return Container(
      decoration: BoxDecoration(
        // INVERTIDO: Verde oscuro si usado (up/down), Naranja si NO usado
        gradient: usedUpDown
            ? const LinearGradient(
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)], // Verde oscuro
              )
            : const LinearGradient(
                colors: [Color(0xFFF1F8F4), Color(0xFFFAFDFB)],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usedUpDown ? const Color(0xFF1B4332) : const Color(0xFFE8F5E9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: usedUpDown
                ? const Color(0xFF1B4332).withValues(alpha: 0.4)
                : const Color(0xFFE8F5E9).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón -
          InkWell(
            onTap: () {
              if (currentValue > 0) {
                setState(() {
                  _numberUsedUpDown[statusId] =
                      true; // Marcar como usado con up/down
                  _updateRootNumberValue(status, currentValue - 1);
                });
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
              child: Icon(
                Icons.remove_rounded,
                color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                size: 20,
              ),
            ),
          ),

          // Display del número
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            constraints: const BoxConstraints(minWidth: 50),
            child: Center(
              child: Text(
                _formatColombianNumber(currentValue),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Botón +
          InkWell(
            onTap: () {
              setState(() {
                _numberUsedUpDown[statusId] =
                    true; // Marcar como usado con up/down
                _updateRootNumberValue(status, currentValue + 1);
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(9),
                  bottomRight: Radius.circular(9),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cajones para root status
  Widget _buildNumberBoxes({required dynamic status}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(5, (index) {
            final number = index + 1;
            // Solo poner naranja si está seleccionado Y NO se usó up/down
            final isSelected = currentValue == number && !usedUpDown;

            return InkWell(
              onTap: () {
                setState(() {
                  _numberUsedUpDown[statusId] =
                      false; // Marcar como NO usado con up/down
                  _updateRootNumberValue(status, number);
                });
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  // INVERTIDO: Verde si está seleccionado, Naranja si NO está seleccionado
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            const Color(0xFF00a86b),
                            const Color(0xFF00d980),
                          ]
                        : [
                            const Color(0xFFF1F8F4),
                            const Color(0xFFFAFDFB),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00a86b)
                        : const Color(0xFFE8F5E9),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFF00a86b).withValues(alpha: 0.5)
                          : const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? Colors.white : const Color(0xFF00a86b),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Botón INGRESAR OTRO NUMERO
        InkWell(
          onTap: () async {
            final result = await _showFullScreenNumericKeyboard(currentValue);
            if (result != null) {
              setState(() {
                _numberUsedUpDown[statusId] =
                    true; // Marcar como usado con teclado custom
                _updateRootNumberValue(status, result);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)], // Verde oscuro
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B4332).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.dialpad_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'INGRESAR OTRO NÚMERO',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Control numérico compacto para status childs (dentro de steps)
  Widget _buildCompactInlineNumberControlForStatus({
    required dynamic parentStep,
    required dynamic status,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    return Container(
      decoration: BoxDecoration(
        // INVERTIDO: Verde oscuro si usado (up/down), Naranja si NO usado
        gradient: usedUpDown
            ? const LinearGradient(
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)], // Verde oscuro
              )
            : const LinearGradient(
                colors: [Color(0xFFF1F8F4), Color(0xFFFAFDFB)],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usedUpDown ? const Color(0xFF1B4332) : const Color(0xFFE8F5E9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: usedUpDown
                ? const Color(0xFF1B4332).withValues(alpha: 0.4)
                : const Color(0xFFE8F5E9).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón -
          InkWell(
            onTap: () {
              if (currentValue > 0) {
                setState(() {
                  _numberUsedUpDown[statusId] =
                      true; // Marcar como usado con up/down
                  _updateNumberValue(parentStep, status, currentValue - 1);
                });
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
              child: Icon(
                Icons.remove_rounded,
                color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                size: 20,
              ),
            ),
          ),

          // Display del número
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            constraints: const BoxConstraints(minWidth: 50),
            child: Center(
              child: Text(
                _formatColombianNumber(currentValue),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Botón +
          InkWell(
            onTap: () {
              setState(() {
                _numberUsedUpDown[statusId] =
                    true; // Marcar como usado con up/down
                _updateNumberValue(parentStep, status, currentValue + 1);
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(9),
                  bottomRight: Radius.circular(9),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: usedUpDown ? Colors.white : const Color(0xFF00a86b),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cajones para status childs (dentro de steps)
  Widget _buildNumberBoxesForStatus({
    required dynamic parentStep,
    required dynamic status,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(5, (index) {
            final number = index + 1;
            // Solo poner naranja si está seleccionado Y NO se usó up/down
            final isSelected = currentValue == number && !usedUpDown;

            return InkWell(
              onTap: () {
                setState(() {
                  _numberUsedUpDown[statusId] =
                      false; // Marcar como NO usado con up/down
                  _updateNumberValue(parentStep, status, number);
                });
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  // INVERTIDO: Verde si está seleccionado, Naranja si NO está seleccionado
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            const Color(0xFF00a86b),
                            const Color(0xFF00d980),
                          ]
                        : [
                            const Color(0xFFF1F8F4),
                            const Color(0xFFFAFDFB),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00a86b)
                        : const Color(0xFFE8F5E9),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFF00a86b).withValues(alpha: 0.5)
                          : const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? Colors.white : const Color(0xFF00a86b),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Botón INGRESAR OTRO NUMERO
        InkWell(
          onTap: () async {
            final result = await _showFullScreenNumericKeyboard(currentValue);
            if (result != null) {
              setState(() {
                _numberUsedUpDown[statusId] =
                    true; // Marcar como usado con teclado custom
                _updateNumberValue(parentStep, status, result);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)], // Verde oscuro
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B4332).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.dialpad_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'INGRESAR OTRO NÚMERO',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== BOTÓN TAG WRITER (NFC) =====

  Widget _buildTagWriterButton({
    required BuildContext context,
    required String statusName,
    required int statusId,
  }) {
    return InkWell(
      onTap: () async {
        final result = await showDialog<bool>(
          barrierDismissible: false,
          context: context,
          builder: (dialogContext) {
            return const Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: NfcWriteDialogWidget(),
            );
          },
        );

        // Si la escritura fue exitosa, cargar los datos del tag desde el contenido escrito
        if (result == true) {
          final nfcContent = FFAppState().nfcRead;
          if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
            // Parsear el contenido del tag y agrupar por headquarterId
            final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
            setState(() {
              _tagWriterData[statusId] = parsedData;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.nfc_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDynamicPrintingButton({
    required BuildContext context,
    required String statusName,
    required dynamic status,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        debugPrint('🖨️ ===== BOTÓN DYNAMIC-PRINTING PRESIONADO =====');
        debugPrint('   Status: $statusName');

        HapticFeedback.mediumImpact();

        try {
          // Obtener el HTML template desde default_status
          var htmlTemplate =
              getJsonField(status, r'''$.default_status''')?.toString() ?? '';
          debugPrint(
              '📄 HTML template obtenido: ${htmlTemplate.length} caracteres');

          if (htmlTemplate.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ No hay plantilla HTML configurada'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Decodificar HTML entities (por si vienen escapadas del JSON)
          htmlTemplate = _decodeHtmlEntities(htmlTemplate);
          debugPrint(
              '📄 HTML decodificado (primeros 500 chars): ${htmlTemplate.substring(0, htmlTemplate.length > 500 ? 500 : htmlTemplate.length)}...');

          // Procesar placeholders con acceso completo al estado del formulario
          debugPrint('');
          debugPrint('🔄 ===== INICIANDO PROCESAMIENTO DE PLACEHOLDERS =====');
          final processedHTML = _processHTMLPlaceholders(htmlTemplate);
          debugPrint('✅ ===== FIN PROCESAMIENTO DE PLACEHOLDERS =====');
          debugPrint('');
          debugPrint(
              '📄 HTML procesado (primeros 500 chars): ${processedHTML.substring(0, processedHTML.length > 500 ? 500 : processedHTML.length)}...');

          // Abrir el previsualizador HTML con opción de imprimir
          await actions.previewAndPrintHTML(
            context,
            processedHTML,
            statusName,
          );

          debugPrint('✅ Vista previa cerrada');
        } catch (e) {
          debugPrint('❌ Error generando PDF: $e');
          // Cerrar loading si está abierto
          if (!mounted) return;
          if (Navigator.canPop(this.context)) {
            Navigator.of(this.context).pop();
          }
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al generar PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.print_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              'PDF',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parsea el contenido del tag NFC y lo agrupa por lote (headquarterId)
  /// Retorna un Map donde la clave es el headquarterId y el valor es un Map con la data agregada
  Map<int, Map<String, dynamic>> _parseNfcTagContentByHeadquarter(
      String nfcContent) {
    final Map<int, Map<String, dynamic>> groupedByHeadquarter = {};

    // El contenido puede tener múltiples registros separados por comas
    // Ejemplo: {DH:2025_11_06_13:20:00;OP:4214;OP2:5432;VISITS:50;RESULTS:25;HE:204},{DH:...}

    // Extraer todos los registros entre {}
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(nfcContent);

    for (var match in matches) {
      final recordContent = match.group(1);
      if (recordContent == null) continue;

      // Parsear cada campo dentro del registro
      final Map<String, dynamic> record = {
        'operatorId': '',
        'operator2Id': '',
        'visits': 0,
        'results': 0,
        'headquarterId': 0,
        'dateTime': DateTime.now(),
      };
      final fields = recordContent.split(';');

      for (var field in fields) {
        final parts = field.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          switch (key) {
            case 'DH':
              // Parsear fecha: 2025_11_06_13:20:00
              try {
                final dateStr = value.replaceAll('_', '-');
                final dateParts = dateStr.split('-');
                if (dateParts.length >= 4) {
                  final year = int.parse(dateParts[0]);
                  final month = int.parse(dateParts[1]);
                  final day = int.parse(dateParts[2]);
                  final timeParts = dateParts[3].split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  final second = int.parse(timeParts[2]);
                  record['dateTime'] =
                      DateTime(year, month, day, hour, minute, second);
                }
              } catch (e) {
                record['dateTime'] = DateTime.now();
              }
              break;
            case 'OP':
              record['operatorId'] = value;
              break;
            case 'OP2':
              // Si OP2 es "false" (string literal), dejarlo como vacío
              record['operator2Id'] = (value == 'false') ? '' : value;
              break;
            case 'VISITS':
              record['visits'] = int.tryParse(value) ?? 0;
              break;
            case 'RESULTS':
              record['results'] = int.tryParse(value) ?? 0;
              break;
            case 'HE':
              record['headquarterId'] = int.tryParse(value) ?? 0;
              break;
          }
        }
      }

      if (record['headquarterId'] != 0) {
        final heId = record['headquarterId'] as int;

        // Si el lote no existe en el map, crearlo
        if (!groupedByHeadquarter.containsKey(heId)) {
          groupedByHeadquarter[heId] = {
            'totalVisits': 0,
            'totalResults': 0,
            'records': <Map<String, dynamic>>[],
          };
        }

        // Agregar el registro al lote
        groupedByHeadquarter[heId]!['totalVisits'] =
            (groupedByHeadquarter[heId]!['totalVisits'] as int) +
                (record['visits'] as int? ?? 0);
        groupedByHeadquarter[heId]!['totalResults'] =
            (groupedByHeadquarter[heId]!['totalResults'] as int) +
                (record['results'] as int? ?? 0);
        (groupedByHeadquarter[heId]!['records'] as List<Map<String, dynamic>>)
            .add(record);
      }
    }

    return groupedByHeadquarter;
  }

  // ===== BOTÓN TAG READER (NFC) =====

  Widget _buildTagReaderButton({
    required BuildContext context,
    required String statusName,
  }) {
    return InkWell(
      onTap: () {}, // El tap se maneja en el InkWell padre
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.nfc_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTagTransferButton({
    required BuildContext context,
    required String statusName,
  }) {
    return InkWell(
      onTap: () {}, // El tap se maneja en el InkWell padre
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFA500), Color(0xFFFFB74D)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA500).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.nfc_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Botón de limpieza inline para tag-reader
  Widget _buildTagReaderCleanupButton({
    required int statusId,
  }) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Limpiar Tag Reader'),
              content: const Text(
                  '¿Estás seguro de que deseas limpiar los datos del tag reader? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tagReaderData.remove(statusId);
                      _tagReaderGeolocations.remove(statusId);
                      _headquartersWithoutWeight.clear();
                      _headquarterWeights.clear();
                    });
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Datos de tag reader limpiados')),
                    );
                  },
                  child: const Text('Limpiar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE57373), Color(0xFFEF9A9A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE57373).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Botón de limpieza inline para tag-writer
  Widget _buildTagWriterCleanupButton({
    required int statusId,
  }) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Limpiar Tag Writer'),
              content: const Text(
                  '¿Estás seguro de que deseas limpiar los datos del tag writer? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tagWriterData.remove(statusId);
                    });
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Datos de tag writer limpiados')),
                    );
                  },
                  child: const Text('Limpiar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE57373), Color(0xFFEF9A9A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE57373).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Botón de limpieza inline para tag-transfer
  Widget _buildTagTransferCleanupButton({
    required int statusId,
  }) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Limpiar Tag Transfer'),
              content: const Text(
                  '¿Estás seguro de que deseas limpiar los datos del tag transfer? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tagTransferData.remove(statusId);
                    });
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Datos de tag transfer limpiados')),
                    );
                  },
                  child: const Text('Limpiar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE57373), Color(0xFFEF9A9A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE57373).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // ===== PARSEO DEL CONTENIDO DEL TAG NFC =====

  List<Map<String, dynamic>> _parseNfcTagContent(String nfcContent) {
    final List<Map<String, dynamic>> parsedData = [];

    // El contenido puede tener múltiples registros separados por comas
    // Ejemplo: {DH:2025_11_06_13:20:00;OP:4214;OP2:5432;VISITS:50;RESULTS:25;HE:204},{DH:...}

    // Extraer todos los registros entre {}
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(nfcContent);

    for (var match in matches) {
      final recordContent = match.group(1);
      if (recordContent == null) continue;

      // Parsear cada campo dentro del registro
      final Map<String, dynamic> record = {
        'operatorId': '',
        'operator2Id': '',
        'visits': 0,
        'results': 0,
        'headquarterId': 0,
        'dateTime': DateTime.now(),
      };
      final fields = recordContent.split(';');

      for (var field in fields) {
        final parts = field.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value =
              parts.sublist(1).join(':').trim(); // Para manejar campos con ':'

          switch (key) {
            case 'DH':
              // Parsear fecha: 2025_11_06_13:20:00
              try {
                final dateStr = value.replaceAll('_', '-');
                final dateParts = dateStr.split('-');
                if (dateParts.length >= 4) {
                  final year = int.parse(dateParts[0]);
                  final month = int.parse(dateParts[1]);
                  final day = int.parse(dateParts[2]);
                  final timeParts = dateParts[3].split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  final second = int.parse(timeParts[2]);
                  record['dateTime'] =
                      DateTime(year, month, day, hour, minute, second);
                }
              } catch (e) {
                record['dateTime'] = DateTime.now();
              }
              break;
            case 'OP':
              record['operatorId'] = value;
              break;
            case 'OP2':
              // Si OP2 es "false" (string literal), dejarlo como vacío
              record['operator2Id'] = (value == 'false') ? '' : value;
              break;
            case 'VISITS':
              record['visits'] = int.tryParse(value) ?? 0;
              break;
            case 'RESULTS':
              record['results'] = int.tryParse(value) ?? 0;
              break;
            case 'HE':
              record['headquarterId'] = int.tryParse(value) ?? 0;
              break;
          }
        }
      }

      if (record['operatorId'].toString().isNotEmpty) {
        parsedData.add(record);
      }
    }

    return parsedData;
  }

  // ===== EVALUADOR DE FÓRMULAS MATEMÁTICAS =====

  /// Evalúa una fórmula matemática reemplazando nombres de status por sus valores
  /// Ejemplo: "=Tare+Destare" -> 10+5 = 15
  double? _evaluateFormula(String formula) {
    try {
      debugPrint('');
      debugPrint('🔢 ===== INICIO EVALUACIÓN DE FÓRMULA =====');
      debugPrint('📋 Fórmula original: "$formula"');
      debugPrint('📊 Valores disponibles en _statusValuesByName:');
      if (_statusValuesByName.isEmpty) {
        debugPrint(
            '   ⚠️  El map está VACÍO - no hay valores numéricos guardados');
      } else {
        for (var entry in _statusValuesByName.entries) {
          debugPrint('   ✓ ${entry.key} = ${entry.value}');
        }
      }

      // Remover el prefijo "=" si existe
      String expression = formula.trim();
      if (expression.startsWith('=')) {
        expression = expression.substring(1);
      }
      debugPrint('📝 Expresión después de remover "=": "$expression"');

      // Reemplazar nombres de status por sus valores (case-insensitive)
      int replacementCount = 0;
      for (var entry in _statusValuesByName.entries) {
        final statusName = entry.key;
        final statusValue = entry.value;
        // Usar regex para reemplazar solo palabras completas (case-insensitive)
        final regex = RegExp('\\b$statusName\\b', caseSensitive: false);
        if (regex.hasMatch(expression)) {
          expression = expression.replaceAll(regex, statusValue.toString());
          replacementCount++;
          debugPrint('   🔄 Reemplazo: "$statusName" -> $statusValue');
        }
      }

      if (replacementCount == 0) {
        debugPrint(
            '   ⚠️  NO se hicieron reemplazos - posiblemente los nombres en la fórmula no coinciden');
      } else {
        debugPrint('   ✅ Total de reemplazos: $replacementCount');
      }

      debugPrint('🧮 Expresión final a evaluar: "$expression"');

      // Evaluar la expresión matemática
      final result = _evaluateMathExpression(expression);

      if (result != null) {
        debugPrint('✅ Resultado: $result');
      } else {
        debugPrint('❌ Error: resultado null');
      }
      debugPrint('🔢 ===== FIN EVALUACIÓN DE FÓRMULA =====');
      debugPrint('');

      return result;
    } catch (e) {
      debugPrint('❌ ERROR CRÍTICO evaluando fórmula "$formula": $e');
      debugPrint('🔢 ===== FIN EVALUACIÓN DE FÓRMULA (CON ERROR) =====');
      debugPrint('');
      return null;
    }
  }

  /// Evalúa una expresión matemática simple (+, -, *, /)
  double? _evaluateMathExpression(String expression) {
    try {
      // Remover espacios
      expression = expression.replaceAll(' ', '');

      // Parsear y evaluar usando un enfoque simple
      // Soporta +, -, *, /
      // Orden de operaciones: primero * y /, luego + y -

      // Primero manejar multiplicación y división
      expression = _processOperators(expression, ['*', '/']);

      // Luego manejar suma y resta
      expression = _processOperators(expression, ['+', '-']);

      return double.tryParse(expression);
    } catch (e) {
      debugPrint('❌ Error evaluando expresión matemática "$expression": $e');
      return null;
    }
  }

  /// Procesa operadores matemáticos en orden
  String _processOperators(String expression, List<String> operators) {
    for (var operator in operators) {
      while (expression.contains(operator)) {
        // Encontrar el primer operador
        final opIndex = expression.indexOf(operator);
        if (opIndex == -1 || opIndex == 0) break;

        // Extraer el número a la izquierda
        int leftStart = opIndex - 1;
        while (leftStart > 0 && _isNumberChar(expression[leftStart - 1])) {
          leftStart--;
        }
        final leftNum = double.parse(expression.substring(leftStart, opIndex));

        // Extraer el número a la derecha
        int rightEnd = opIndex + 1;
        while (rightEnd < expression.length &&
            _isNumberChar(expression[rightEnd])) {
          rightEnd++;
        }
        final rightNum =
            double.parse(expression.substring(opIndex + 1, rightEnd));

        // Calcular el resultado
        double result;
        switch (operator) {
          case '+':
            result = leftNum + rightNum;
            break;
          case '-':
            result = leftNum - rightNum;
            break;
          case '*':
            result = leftNum * rightNum;
            break;
          case '/':
            result = rightNum != 0 ? leftNum / rightNum : 0;
            break;
          default:
            result = 0;
        }

        // Reemplazar la sub-expresión con el resultado
        expression = expression.substring(0, leftStart) +
            result.toString() +
            expression.substring(rightEnd);
      }
    }
    return expression;
  }

  /// Formatea un número en formato colombiano
  /// Sin decimales, punto como separador de miles, comilla simple como separador de millones
  /// Ejemplo: 1234567 -> 1'234.567
  String _formatColombianNumber(num value) {
    // Redondear a entero (sin decimales)
    final int intValue = value.round();

    // Manejar números negativos
    final bool isNegative = intValue < 0;
    final String absValue = intValue.abs().toString();

    // Simplificar: usar punto para miles, comilla para millones
    final regex = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    String result =
        absValue.replaceAllMapped(regex, (match) => '${match.group(1)}.');

    // Cambiar el primer punto por comilla simple si hay más de 6 dígitos (millones)
    if (absValue.length > 6) {
      final parts = result.split('.');
      result = "${parts[0]}'${parts.sublist(1).join('.')}";
    }

    return isNegative ? '-$result' : result;
  }

  /// Verifica si un carácter es parte de un número (dígito, punto decimal, o signo negativo al inicio)
  bool _isNumberChar(String char) {
    return char == '.' ||
        char == '-' ||
        (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57);
  }

  /// Recalcula todas las operaciones numbers-operation que dependen de valores cambiados
  void _recalculateOperations() {
    debugPrint('');
    debugPrint('🔄 ===== RECALCULANDO TODAS LAS OPERACIONES =====');

    final activityStepsRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );
    if (activityStepsRaw == null) return;
    final activitySteps = activityStepsRaw.toList();

    int operationsFound = 0;
    int operationsCalculated = 0;

    // Función helper para procesar un status y encontrar operations
    void processStatus(dynamic status, String location) {
      final typeStatus =
          getJsonField(status, r'''$.type_status''')?.toString() ?? '';
      if (typeStatus.toLowerCase() == 'numbers-operation') {
        operationsFound++;
        final statusId = getJsonField(status, r'''$.id_activity_status''');
        final statusName =
            getJsonField(status, r'''$.status_name''')?.toString() ?? '';
        final formula =
            getJsonField(status, r'''$.default_status''')?.toString() ?? '';

        debugPrint('📊 Operación #$operationsFound encontrada en $location:');
        debugPrint('   ID: $statusId');
        debugPrint('   Nombre: "$statusName"');
        debugPrint('   Fórmula: "$formula"');

        if (formula.isNotEmpty) {
          final result = _evaluateFormula(formula);
          if (result != null) {
            setState(() {
              _calculatedValues[statusId] = result;
              // Marcar que esta operación fue calculada al menos una vez
              _numbersOperationCalculated[statusId] = true;
            });
            operationsCalculated++;
            debugPrint('   ✅ Calculado y guardado: $result');

            // También guardar en visitDetails
            _saveOperationResult(status, result);
          } else {
            debugPrint('   ❌ Error al calcular (resultado null)');
          }
        } else {
          debugPrint('   ⚠️  Fórmula vacía - no se puede calcular');
        }
      }

      // Buscar recursivamente en steps_childs
      final stepsChilds =
          getJsonField(status, r'''$.steps_childs''')?.toList() ?? [];
      for (var childStep in stepsChilds) {
        final childStatusList =
            getJsonField(childStep, r'''$.activity_status''')?.toList() ?? [];
        for (var childStatus in childStatusList) {
          processStatus(childStatus, 'steps_childs');
        }
      }

      // Buscar recursivamente en status_childs
      final statusChilds =
          getJsonField(status, r'''$.status_childs''')?.toList() ?? [];
      for (var childStatus in statusChilds) {
        processStatus(childStatus, 'status_childs');
      }
    }

    // 1. Buscar en ROOT STATUS (activity_status directos de la actividad)
    final rootStatusList = getJsonField(
          FFAppState().currentActivity,
          r'''$.activity_status''',
        )?.toList() ??
        [];

    debugPrint('🔍 Buscando en ${rootStatusList.length} root status...');
    for (var status in rootStatusList) {
      processStatus(status, 'root status');
    }

    // 2. Recorrer todos los steps y sus status
    debugPrint('🔍 Buscando en ${activitySteps.length} activity steps...');
    for (var step in activitySteps) {
      final statusList =
          getJsonField(step, r'''$.activity_status''')?.toList() ?? [];
      for (var status in statusList) {
        processStatus(status, 'step status');
      }
    }

    debugPrint('');
    debugPrint('📈 Resumen:');
    debugPrint('   Total operaciones encontradas: $operationsFound');
    debugPrint('   Total operaciones calculadas: $operationsCalculated');
    debugPrint('🔄 ===== FIN RECALCULACIÓN =====');
    debugPrint('');
  }

  /// Guarda el resultado de una operación en visitDetails
  void _saveOperationResult(dynamic status, double result) async {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName =
        getJsonField(status, r'''$.status_name''')?.toString() ?? '';

    debugPrint('💾 Guardando resultado de operación en visitDetails:');
    debugPrint('   Status: $statusName (ID: $statusId)');
    debugPrint('   Resultado: $result');

    // Buscar si ya existe en visitDetails
    int existingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
        existingIndex = i;
        break;
      }
    }

    // Obtener el step parent del status
    int parentStepId = 0;
    try {
      final activityStepsRaw =
          getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');
      if (activityStepsRaw != null) {
        final activitySteps = activityStepsRaw.toList();
        for (var step in activitySteps) {
          final stepId = getJsonField(step, r'''$.id_activity_step''');
          final statusListRaw = getJsonField(step, r'''$.activity_status''');
          if (statusListRaw == null) continue;
          final statusList = statusListRaw.toList();

          // Buscar en el nivel principal
          for (var s in statusList) {
            final sId = getJsonField(s, r'''$.id_activity_status''');
            if (sId == statusId) {
              parentStepId = stepId;
              break;
            }
          }
          if (parentStepId != 0) break;
        }
      }
    } catch (e) {
      debugPrint('   ⚠️  No se pudo encontrar el step parent: $e');
    }

    if (existingIndex >= 0) {
      // Actualizar existente
      FFAppState().updateVisitDetailsAtIndex(
        existingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: result.toString(),
          idStepParent: parentStepId,
          rememberStatus: detail.rememberStatus,
          defaultStatus: detail.defaultStatus,
          typeStatus: 'numbers-operation',
          auxStep: parentStepId,
        ),
      );
      debugPrint('   ✅ Actualizado en visitDetails[index=$existingIndex]');
    } else {
      // Agregar nuevo
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: result.toString(),
          idStepParent: parentStepId,
          rememberStatus: false,
          defaultStatus: '',
          typeStatus: 'numbers-operation',
          auxStep: parentStepId,
        ),
      );
      debugPrint('   ✅ Agregado a visitDetails');
    }
  }

  // ===== CARGAR WEIGHTS DE HEADQUARTERS DESDE SQLITE =====

  /// Carga los weights de headquarters desde SQLite para el mes/año actual
  /// También identifica los lotes que NO tienen peso promedio configurado
  Future<void> _loadHeadquarterWeights(List<int> headquarterIds) async {
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      debugPrint(
          '📊 Cargando weights para ${headquarterIds.length} lotes (año: $currentYear, mes: $currentMonth)');

      // Limpiar lista de lotes sin peso antes de cargar
      _headquartersWithoutWeight.clear();

      for (var headquarterId in headquarterIds) {
        // Buscar nombre del lote en AppState
        String headquarterName = 'Lote $headquarterId';
        try {
          final headquarters = FFAppState().headquartersSelectedList;
          final hq = headquarters.firstWhere(
            (h) => h.idHeadquarter == headquarterId,
            orElse: () => HeadquartersStruct(),
          );
          if (hq.nameHeadquarter.isNotEmpty) {
            headquarterName = hq.nameHeadquarter;
          }
        } catch (e) {
          // Usar nombre por defecto
        }

        // Consultar SQLite
        final results = await SQLiteManager.instance.getHeadquarterWeights(
          headquarterId: headquarterId,
          year: currentYear,
          month: currentMonth,
        );

        if (results.isNotEmpty) {
          final weight = results.first.weight;
          setState(() {
            _headquarterWeights[headquarterId] = weight;
          });
          debugPrint(
              '   ✅ Lote $headquarterId ($headquarterName): weight = $weight');
        } else {
          // Agregar a la lista de lotes sin peso
          _headquartersWithoutWeight.add({
            'headquarterId': headquarterId,
            'headquarterName': headquarterName,
          });
          debugPrint(
              '   ⚠️ Lote $headquarterId ($headquarterName): SIN peso promedio configurado');
        }
      }

      // Log resumen
      if (_headquartersWithoutWeight.isNotEmpty) {
        debugPrint('');
        debugPrint(
            '⚠️ ADVERTENCIA: ${_headquartersWithoutWeight.length} lote(s) sin peso promedio:');
        for (var hq in _headquartersWithoutWeight) {
          debugPrint(
              '   - ${hq['headquarterName']} (ID: ${hq['headquarterId']})');
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando weights: $e');
    }
  }

  /// Muestra un diálogo de advertencia cuando hay lotes sin peso promedio configurado
  void _showWeightWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de advertencia
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFCA5A5),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  '⚠️ Peso Promedio No Configurado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Los siguientes lotes no tienen peso promedio configurado para el mes actual:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de lotes sin peso
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _headquartersWithoutWeight.map((hq) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFFCA5A5),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${hq['headquarterName']}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                'ID: ${hq['headquarterId']}',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Advertencia
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFB020).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFFFB020),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El cálculo de peso NO se realizará para estos lotes.',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFFB020),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón cerrar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Calcula la distancia desde el origen hasta la extractora
  /// Opción 1: Usar coordenadas del TAG_READER especificado en default_status
  /// Opción 2: Si distancia > 200km, usar coordenadas de Products (línea y palma menor del lote)
  Future<void> _calculateDistance(
      int statusId, dynamic status, dynamic parentStep) async {
    try {
      debugPrint('');
      debugPrint('📏 ===== INICIO CÁLCULO DE DISTANCIA =====');

      final defaultStatus =
          getJsonField(status, r'''$.default_status''')?.toString() ?? '';
      debugPrint('🔍 default_status: "$defaultStatus"');

      // Variables para las coordenadas de origen
      double? originLat;
      double? originLng;

      // OPCIÓN 1: Buscar coordenadas del TAG_READER especificado
      if (defaultStatus.startsWith('=TAG_READER:')) {
        final tagReaderName =
            defaultStatus.substring(12).trim(); // Quitar "=TAG_READER:"
        debugPrint('📍 Buscando TAG_READER con nombre: "$tagReaderName"');
        debugPrint(
            '📋 Total TAG_READER en _tagReaderGeolocations: ${_tagReaderGeolocations.length}');

        // Buscar directamente por nombre comparando con los status name guardados
        // Primero obtener todos los status de la actividad
        final activityStepsRaw = getJsonField(
          FFAppState().currentActivity,
          r'''$.activity_steps''',
        );
        final activitySteps = activityStepsRaw?.toList() ?? [];

        final activityStatusRaw = getJsonField(
          FFAppState().currentActivity,
          r'''$.activity_status''',
        );
        final activityStatus = activityStatusRaw?.toList() ?? [];

        // Buscar el statusId del tag-reader por nombre
        int? targetTagReaderId;

        // Buscar en root status
        for (var status in activityStatus) {
          final statusName =
              getJsonField(status, r'''$.status_name''')?.toString() ?? '';
          final typeStatus =
              getJsonField(status, r'''$.type_status''')?.toString() ?? '';
          if (typeStatus.toLowerCase() == 'tag-reader' &&
              statusName.toLowerCase() == tagReaderName.toLowerCase()) {
            targetTagReaderId =
                getJsonField(status, r'''$.id_activity_status''');
            debugPrint(
                '   ✅ Encontrado en root status: "$statusName" (ID: $targetTagReaderId)');
            break;
          }
        }

        // Si no se encontró en root, buscar en steps
        if (targetTagReaderId == null) {
          for (var step in activitySteps) {
            final statusListRaw = getJsonField(step, r'''$.activity_status''');
            final statusList = statusListRaw?.toList() ?? [];
            for (var status in statusList) {
              final statusName =
                  getJsonField(status, r'''$.status_name''')?.toString() ?? '';
              final typeStatus =
                  getJsonField(status, r'''$.type_status''')?.toString() ?? '';
              if (typeStatus.toLowerCase() == 'tag-reader' &&
                  statusName.toLowerCase() == tagReaderName.toLowerCase()) {
                targetTagReaderId =
                    getJsonField(status, r'''$.id_activity_status''');
                debugPrint(
                    '   ✅ Encontrado en step: "$statusName" (ID: $targetTagReaderId)');
                break;
              }
            }
            if (targetTagReaderId != null) break;
          }
        }

        if (targetTagReaderId == null) {
          debugPrint(
              '⚠️ No se encontró status TAG_READER con nombre "$tagReaderName"');
          return;
        }

        // Ahora buscar las coordenadas en _tagReaderGeolocations usando el ID
        if (_tagReaderGeolocations.containsKey(targetTagReaderId)) {
          final geolocation = _tagReaderGeolocations[targetTagReaderId]!;
          originLat = geolocation.latitude;
          originLng = geolocation.longitude;
          debugPrint('✅ Coordenadas encontradas: ($originLat, $originLng)');
        } else {
          debugPrint(
              '⚠️ TAG_READER "$tagReaderName" (ID: $targetTagReaderId) no tiene coordenadas en _tagReaderGeolocations');
          debugPrint(
              '   IDs disponibles: ${_tagReaderGeolocations.keys.toList()}');
          return;
        }
      } else if (_lastTagReaderLocation != null) {
        // Usar última ubicación de tag-reader como fallback
        originLat = _lastTagReaderLocation!.latitude;
        originLng = _lastTagReaderLocation!.longitude;
        debugPrint(
            '📍 Usando última ubicación TAG_READER: ($originLat, $originLng)');
      } else {
        debugPrint('⚠️ No hay ubicación de tag-reader disponible');
        return;
      }

      // Obtener coordenadas de la extractora (Companies)
      final company = FFAppState().companyDefault;

      // Usar los campos latitude_extractor y longitude_extractor
      final extractoraLat = company.latitudeExtractor;
      final extractoraLng = company.longitudeExtractor;

      debugPrint('🏭 Extractora: ${company.nameCompany}');
      debugPrint('   Coordenadas: ($extractoraLat, $extractoraLng)');
      debugPrint('   📊 Company completo: ${company.toMap()}');

      if (extractoraLat == 0.0 || extractoraLng == 0.0) {
        debugPrint(
            '⚠️ ⚠️ ⚠️ ERROR: Coordenadas de extractora no configuradas o inválidas ⚠️ ⚠️ ⚠️');
        debugPrint(
            '   Las coordenadas de la extractora deben venir del API de Login');
        debugPrint(
            '   Verifica que el API devuelva latitude_extractor y longitude_extractor');

        // Mostrar un diálogo de error al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ No se encontraron coordenadas de la extractora.\nConfigure las coordenadas en el sistema.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Calcular distancia OPCIÓN 1 (desde TAG) usando fórmula de Haversine
      double distanceFromTag = _calculateHaversineDistance(
          originLat, originLng, extractoraLat, extractoraLng);

      debugPrint(
          '📐 Distancia calculada (OPCIÓN 1 - desde TAG): ${distanceFromTag.toStringAsFixed(2)} metros (${(distanceFromTag / 1000).toStringAsFixed(2)} km)');

      // OPCIÓN 2: SIEMPRE calcular distancia desde Products para CADA lote SELECCIONADO
      debugPrint('');
      debugPrint(
          '📦 ===== CALCULANDO OPCIÓN 2 (desde Producto por cada lote) =====');

      // Obtener lotes SELECCIONADOS de FFAppState().headquartersSelectedList
      final selectedHeadquarters = FFAppState().headquartersSelectedList;
      debugPrint(
          '📋 Lotes seleccionados en headquartersSelectedList: ${selectedHeadquarters.length}');
      for (var hq in selectedHeadquarters) {
        debugPrint('   - Lote ${hq.idHeadquarter}: ${hq.nameHeadquarter}');
      }

      // Lista para almacenar las distancias de cada lote
      final List<Map<String, dynamic>> distancesFromProducts = [];

      if (selectedHeadquarters.isEmpty) {
        debugPrint('⚠️ No hay lotes seleccionados en headquartersSelectedList');
        debugPrint('   No se puede calcular OPCIÓN 2');
      } else {
        // Leer productos desde SQLite usando la MISMA ruta que sync_install_module
        try {
          // Obtener la ruta de la base de datos (misma que usa sync_install_module)
          final Directory? externalDir = await getExternalStorageDirectory();
          if (externalDir == null) {
            throw Exception('No se pudo acceder al almacenamiento externo');
          }
          final String basePath = '${externalDir.path}/ClickPalmData';
          final String dbPath = path.join(basePath, 'clickpalm_database.db');

          debugPrint('📂 Ruta de SQLite: $dbPath');

          // Abrir la base de datos
          final db = await openDatabase(dbPath);

          // Calcular distancia para CADA lote seleccionado
          for (final selectedHq in selectedHeadquarters) {
            final loteHeadquarterId = selectedHq.idHeadquarter;
            final loteName = selectedHq.nameHeadquarter.isNotEmpty
                ? selectedHq.nameHeadquarter
                : 'Lote #$loteHeadquarterId';

            debugPrint('');
            debugPrint(
                '🏢 ===== PROCESANDO LOTE $loteHeadquarterId ($loteName) =====');

            // Consultar productos del lote específico desde SQLite
            // Ordenar por Line ASC, Palm ASC para obtener la línea menor primero, y dentro de esa línea la palma menor
            final List<Map<String, dynamic>> productsRaw = await db.query(
              'Products',
              where: 'Id_headquarter = ? AND Line > 0 AND Palm > 0',
              whereArgs: [loteHeadquarterId],
              orderBy: 'Line ASC, Palm ASC',
              limit:
                  1, // Solo necesitamos el producto con línea y palma menores
            );

            debugPrint(
                '📊 Productos encontrados en SQLite para lote $loteHeadquarterId: ${productsRaw.length}');

            if (productsRaw.isEmpty) {
              debugPrint(
                  '❌ No se encontró ningún producto en lote $loteHeadquarterId');
              continue;
            }

            // El primer resultado es el de línea menor y palma menor (por el ORDER BY)
            final productMap = productsRaw.first;
            final productId = productMap['Id_product'] as int?;
            final line = productMap['Line'] as int?;
            final palm = productMap['Palm'] as int?;
            final locationRaw = productMap['Location_raw'] as String?;

            debugPrint('✅ Producto con palma menor:');
            debugPrint('   - ID Product: $productId');
            debugPrint('   - Línea: $line');
            debugPrint('   - Palma: $palm');
            debugPrint('   - Location_raw: $locationRaw');

            if (locationRaw != null && locationRaw.isNotEmpty) {
              // Parsear location_raw (formato: "LAT:X;LON:Y;ALT:Z;ERH:W")
              double? productLat;
              double? productLng;

              final parts = locationRaw.split(';');
              for (final part in parts) {
                if (part.startsWith('LAT:')) {
                  productLat = double.tryParse(part.substring(4));
                } else if (part.startsWith('LON:')) {
                  productLng = double.tryParse(part.substring(4));
                }
              }

              if (productLat != null && productLng != null) {
                debugPrint(
                    '   - Coordenadas parseadas: ($productLat, $productLng)');

                // Calcular distancia desde producto
                final distanceFromProduct = _calculateHaversineDistance(
                    productLat, productLng, extractoraLat, extractoraLng);

                final distanceKm = distanceFromProduct / 1000;
                debugPrint(
                    '📐 Distancia desde producto (OPCIÓN 2): ${distanceFromProduct.toStringAsFixed(2)} metros (${distanceKm.toStringAsFixed(2)} km)');

                // Agregar a la lista de distancias
                distancesFromProducts.add({
                  'headquarterId': loteHeadquarterId,
                  'headquarterName': loteName,
                  'distance': distanceFromProduct,
                  'line': line ?? 0,
                  'palm': palm ?? 0,
                });
              } else {
                debugPrint(
                    '⚠️ Error parseando coordenadas del location_raw: "$locationRaw"');
              }
            } else {
              debugPrint(
                  '❌ Producto encontrado pero sin coordenadas (Location_raw vacío o null)');
            }
          } // fin del for de lotes seleccionados

          // Cerrar la base de datos
          await db.close();
          debugPrint('✅ Base de datos cerrada');
        } catch (e) {
          debugPrint('❌ Error consultando SQLite: $e');
        }
      }

      // Guardar TODAS las distancias
      setState(() {
        _calculatedDistances[statusId] = distanceFromTag; // OPCIÓN 1
        if (distancesFromProducts.isNotEmpty) {
          _calculatedDistancesFromProduct[statusId] =
              distancesFromProducts; // OPCIÓN 2 (lista)
        }
        _distanceExtractorCalculated[statusId] = true;
      });

      debugPrint(
          '✅ Distancia desde TAG (OPCIÓN 1): ${distanceFromTag.toStringAsFixed(2)} metros');
      if (distancesFromProducts.isNotEmpty) {
        debugPrint(
            '✅ Distancias desde Productos (OPCIÓN 2): ${distancesFromProducts.length} lotes');
        for (var item in distancesFromProducts) {
          debugPrint(
              '   - ${item['headquarterName']}: ${item['distance'].toStringAsFixed(2)} m (Línea: ${item['line']}, Palma: ${item['palm']})');
        }
      }
      debugPrint('📏 ===== FIN CÁLCULO DE DISTANCIA =====');
      debugPrint('');

      // Mostrar mensaje de éxito al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Distancia calculada: ${(distanceFromTag / 1000).toStringAsFixed(2)} km'),
            backgroundColor: const Color(0xFF00a86b),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error calculando distancia: $e');
      debugPrint('📏 ===== FIN CÁLCULO DE DISTANCIA (CON ERROR) =====');
      debugPrint('');

      // Mostrar mensaje de error al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error calculando distancia: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Calcula la distancia entre dos puntos usando la fórmula de Haversine
  double _calculateHaversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final lat1Rad = lat1 * (math.pi / 180);
    final lat2Rad = lat2 * (math.pi / 180);
    final dLat = lat2Rad - lat1Rad;
    final dLng = (lng2 - lng1) * (math.pi / 180);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    const earthRadius = 6371000; // Radio de la Tierra en metros
    return earthRadius * c;
  }

  /// Busca y calcula automáticamente las distancias de todos los distance-extractor
  /// que referencian al tag-reader especificado
  Future<void> _autoCalculateRelatedDistances(
      int tagReaderStatusId, String tagReaderName) async {
    try {
      debugPrint('');
      debugPrint(
          '🔍 Buscando distance-extractor que referencien TAG_READER "$tagReaderName" (ID: $tagReaderStatusId)');

      // Obtener steps y status con manejo de nulos
      final activityStepsRaw = getJsonField(
        FFAppState().currentActivity,
        r'''$.activity_steps''',
      );
      final activitySteps = activityStepsRaw != null
          ? (activityStepsRaw is List ? activityStepsRaw : [])
          : [];

      final activityStatusRaw = getJsonField(
        FFAppState().currentActivity,
        r'''$.activity_status''',
      );
      final activityStatus = activityStatusRaw != null
          ? (activityStatusRaw is List ? activityStatusRaw : [])
          : [];

      debugPrint('📊 Activity steps encontrados: ${activitySteps.length}');
      debugPrint('📊 Activity status encontrados: ${activityStatus.length}');

      int foundCount = 0;
      int totalDistanceExtractors = 0;

      // Función helper para procesar un status y buscar distance-extractor
      Future<void> processStatus(dynamic status, dynamic parentStep) async {
        final typeStatus =
            getJsonField(status, r'''$.type_status''')?.toString() ?? '';

        if (typeStatus.toLowerCase() == 'distance-extractor') {
          totalDistanceExtractors++;
          final statusId = getJsonField(status, r'''$.id_activity_status''');
          final statusName =
              getJsonField(status, r'''$.status_name''')?.toString() ?? '';
          final defaultStatus =
              getJsonField(status, r'''$.default_status''')?.toString() ?? '';

          debugPrint(
              '   📋 distance-extractor #$totalDistanceExtractors: "$statusName" (ID: $statusId)');
          debugPrint('      default_status: "$defaultStatus"');
          debugPrint(
              '      Comparando con: "=tag_reader:${tagReaderName.toLowerCase()}"');

          // Verificar si este distance-extractor referencia al tag-reader actual
          final normalizedDefault =
              defaultStatus.trim().toLowerCase().replaceAll(' ', '');
          final expectedPattern1 =
              '=tag_reader:${tagReaderName.toLowerCase()}'.replaceAll(' ', '');
          final expectedPattern2 =
              '=tag_reader:${tagReaderName.toLowerCase()}'.replaceAll(' ', '');

          if (normalizedDefault == expectedPattern1 ||
              normalizedDefault == expectedPattern2 ||
              defaultStatus
                  .toLowerCase()
                  .contains(tagReaderName.toLowerCase())) {
            foundCount++;
            debugPrint('      ✅ COINCIDE! Calculando distancia...');

            // Calcular la distancia
            await _calculateDistance(statusId, status, parentStep);
          } else {
            debugPrint('      ❌ No coincide');
          }
        }

        // Buscar recursivamente en steps_childs
        final stepsChildsRaw = getJsonField(status, r'''$.steps_childs''');
        final stepsChilds = stepsChildsRaw != null
            ? (stepsChildsRaw is List ? stepsChildsRaw : [])
            : [];
        for (var childStep in stepsChilds) {
          final childStatusListRaw =
              getJsonField(childStep, r'''$.activity_status''');
          final childStatusList = childStatusListRaw != null
              ? (childStatusListRaw is List ? childStatusListRaw : [])
              : [];
          for (var childStatus in childStatusList) {
            await processStatus(childStatus, childStep);
          }
        }

        // Buscar recursivamente en status_childs
        final statusChildsRaw = getJsonField(status, r'''$.status_childs''');
        final statusChilds = statusChildsRaw != null
            ? (statusChildsRaw is List ? statusChildsRaw : [])
            : [];
        for (var childStatus in statusChilds) {
          await processStatus(childStatus, parentStep);
        }
      }

      // Buscar en steps
      for (var step in activitySteps) {
        final statusListRaw = getJsonField(step, r'''$.activity_status''');
        final statusList = statusListRaw != null
            ? (statusListRaw is List ? statusListRaw : [])
            : [];
        for (var status in statusList) {
          await processStatus(status, step);
        }
      }

      // Buscar en status raíz
      for (var status in activityStatus) {
        await processStatus(status, null);
      }

      debugPrint('');
      debugPrint('📊 Resumen búsqueda:');
      debugPrint(
          '   Total distance-extractor encontrados: $totalDistanceExtractors');
      debugPrint('   Que referencian "$tagReaderName": $foundCount');

      if (foundCount == 0) {
        debugPrint('   ⚠️  No se encontraron coincidencias');
      } else {
        debugPrint('   ✅ Total calculados: $foundCount');
      }
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error en _autoCalculateRelatedDistances: $e');
      debugPrint('');
    }
  }

  /// Espera hasta obtener una geolocalización válida de FFAppState().geoLocationsList
  /// Retorna la última geolocalización válida o null si se cancela la espera
  Future<ReadGeoStruct?> _waitForValidGeolocation(BuildContext context) async {
    // Verificar si ya hay una geolocalización válida
    ReadGeoStruct? getLatestValidGeolocation() {
      final geoList = FFAppState().geoLocationsList;
      if (geoList.isEmpty) return null;

      // Obtener la última geolocalización
      final latest = geoList.last;

      // Verificar que tenga valores válidos (no 0, 0)
      if (latest.latitude != 0.0 && latest.longitude != 0.0) {
        return latest;
      }

      return null;
    }

    // Intentar obtener inmediatamente
    final immediate = getLatestValidGeolocation();
    if (immediate != null) {
      debugPrint(
          '📍 Geolocalización disponible: ${immediate.latitude}, ${immediate.longitude}');
      return immediate;
    }

    // Si no hay geolocalización válida, mostrar diálogo de espera
    debugPrint('⏳ Esperando geolocalización válida...');

    ReadGeoStruct? result;
    bool cancelled = false;

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Verificar periódicamente si hay geolocalización válida
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!cancelled && dialogContext.mounted) {
                final geo = getLatestValidGeolocation();
                if (geo != null) {
                  result = geo;
                  Navigator.of(dialogContext).pop();
                } else {
                  setState(() {}); // Refrescar el diálogo
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.black87,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Esperando ubicación GPS...',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Por favor espere mientras se obtiene una ubicación válida',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        cancelled = true;
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      debugPrint(
          '✅ Geolocalización obtenida: ${result!.latitude}, ${result!.longitude}');
    } else {
      debugPrint('❌ Espera de geolocalización cancelada');
    }

    return result;
  }

  /// Busca el nombre de un usuario por su operID de forma robusta
  /// Garantiza que siempre retorna algo, nunca un string vacío
  String _getUserName(String operID) {
    if (operID.isEmpty) {
      debugPrint('👤 _getUserName: operID vacío, retornando vacío');
      return '';
    }

    debugPrint('👤 _getUserName: Buscando operID="$operID"');
    debugPrint(
        '👤 Total usuarios en usersList: ${FFAppState().usersList.length}');

    // Buscar en usersList por operID
    final user = FFAppState().usersList.firstWhere(
          (u) => u.operID == operID,
          orElse: () => UsersStruct(),
        );

    if (user.nameUser.isNotEmpty) {
      debugPrint('✅ _getUserName: Encontrado por operID: "${user.nameUser}"');
      return user.nameUser;
    }

    debugPrint('❌ _getUserName: No encontrado por operID');

    // Si no se encuentra en usersList, intentar buscar como número
    // (podría ser que el ID sea un número directo y no un operID)
    try {
      final userId = int.tryParse(operID);
      if (userId != null) {
        debugPrint('👤 _getUserName: Intentando buscar por idUser: $userId');
        final userById = FFAppState().usersList.firstWhere(
              (u) => u.idUser == userId,
              orElse: () => UsersStruct(),
            );
        if (userById.nameUser.isNotEmpty) {
          debugPrint(
              '✅ _getUserName: Encontrado por idUser: "${userById.nameUser}"');
          return userById.nameUser;
        }
      }
    } catch (e) {
      debugPrint('❌ Error buscando usuario por ID: $e');
    }

    debugPrint(
        '❌ _getUserName: Usuario no encontrado, retornando operID original: "$operID"');
    return operID;
  }

  /// Obtiene el nombre del cortero desde Activities_status usando su IdActivityStatus
  /// El parámetro idActivityStatus es el OP2 que viene del NFC tag
  String _getCorterName(String idActivityStatus) {
    if (idActivityStatus.isEmpty) {
      debugPrint('🔄 _getCorterName: idActivityStatus vacío, retornando vacío');
      return '';
    }

    debugPrint('🔄 _getCorterName: Buscando idActivityStatus="$idActivityStatus"');

    // Intentar parsear como número
    final id = int.tryParse(idActivityStatus);
    if (id == null) {
      debugPrint('❌ _getCorterName: idActivityStatus no es un número válido');
      return '';
    }

    // Aquí idealmente se consultaría la base de datos o un cache
    // Por ahora, intentamos obtenerlo de visitDetails si está disponible
    try {
      for (var detail in FFAppState().visitDetails) {
        if (detail.idActivityStatus == id && detail.statusResponse.isNotEmpty) {
          debugPrint('✅ _getCorterName: Encontrado en visitDetails: "${detail.statusResponse}"');
          return detail.statusResponse;
        }
      }
    } catch (e) {
      debugPrint('❌ Error buscando en visitDetails: $e');
    }

    debugPrint('❌ _getCorterName: No encontrado el cortero para idActivityStatus=$idActivityStatus');
    return '';
  }

  /// Limpia los datos de tags (tag-reader, tag-writer, tag-transfer) que NO deben ser recordados
  /// Se ejecuta después de crear la visita para no mostrar contenido INLINE de tags que ya fueron guardados
  void _cleanupTagDatasByRememberFlag() {
    debugPrint('🧹 LIMPIEZA DE DATOS DE TAGS VISUALES');

    // NOTA: Los visitDetails ya fueron limpiados por removeVisits() en LoadCoordinatesVisit
    // Por lo tanto, los tags con rememberStatus=false ya NO están en FFAppState().visitDetails
    // Debemos buscar en los Maps locales y eliminar los que NO estén en visitDetails (ya fueron eliminados)

    final remainingVisitDetailsIds = FFAppState()
        .visitDetails
        .map((d) => d.idActivityStatus)
        .toSet();

    int cleanedCount = 0;

    // Limpiar tag-reader data: eliminar los que ya no están en visitDetails
    final tagReaderIdsToRemove = _tagReaderData.keys
        .where((id) => !remainingVisitDetailsIds.contains(id))
        .toList();
    for (final statusId in tagReaderIdsToRemove) {
      _tagReaderData.remove(statusId);
      debugPrint('   ❌ Limpiado _tagReaderData[$statusId]');
      cleanedCount++;
    }

    // Limpiar tag-reader geolocations
    final tagReaderGeoIdsToRemove = _tagReaderGeolocations.keys
        .where((id) => !remainingVisitDetailsIds.contains(id))
        .toList();
    for (final statusId in tagReaderGeoIdsToRemove) {
      _tagReaderGeolocations.remove(statusId);
      debugPrint('   ❌ Limpiado _tagReaderGeolocations[$statusId]');
    }

    // Limpiar tag-writer data
    final tagWriterIdsToRemove = _tagWriterData.keys
        .where((id) => !remainingVisitDetailsIds.contains(id))
        .toList();
    for (final statusId in tagWriterIdsToRemove) {
      _tagWriterData.remove(statusId);
      debugPrint('   ❌ Limpiado _tagWriterData[$statusId]');
      cleanedCount++;
    }

    // Limpiar tag-transfer data
    final tagTransferIdsToRemove = _tagTransferData.keys
        .where((id) => !remainingVisitDetailsIds.contains(id))
        .toList();
    for (final statusId in tagTransferIdsToRemove) {
      _tagTransferData.remove(statusId);
      debugPrint('   ❌ Limpiado _tagTransferData[$statusId]');
      cleanedCount++;
    }

    // Limpiar tag-transfer completed flag
    final tagTransferCompletedIdsToRemove = _tagTransferCompleted.keys
        .where((id) => !remainingVisitDetailsIds.contains(id))
        .toList();
    for (final statusId in tagTransferCompletedIdsToRemove) {
      _tagTransferCompleted.remove(statusId);
      debugPrint('   ❌ Limpiado _tagTransferCompleted[$statusId]');
    }

    if (cleanedCount == 0) {
      debugPrint('   ℹ️ No hay tags para limpiar (todos tienen rememberStatus=true)');
    } else {
      // Forzar rebuild para que desaparezca el contenido visual
      setState(() {});
      debugPrint('✅ Limpieza de tags completada: $cleanedCount tags limpiados');
    }
  }

  // ===== PROCESAR PLACEHOLDERS HTML PARA DYNAMIC-PRINTING =====

  String _processHTMLPlaceholders(String htmlTemplate) {
    String result = htmlTemplate;

    // Buscar todos los placeholders en formato {NombreCampo}
    // Solo capturar nombres válidos: letras, números, espacios, guiones y guiones bajos
    final placeholderPattern = RegExp(r'\{([a-zA-Z0-9\sáéíóúÁÉÍÓÚñÑ_-]+)\}');
    final matches = placeholderPattern.allMatches(htmlTemplate).toList();

    debugPrint('📋 Encontrados ${matches.length} placeholders en HTML:');
    for (final match in matches) {
      debugPrint('   - ${match.group(0)}');
    }
    debugPrint('');

    int replacedCount = 0;
    for (final match in matches) {
      final placeholder = match.group(0)!; // {NombreCampo}
      final fieldName = match.group(1)!; // NombreCampo

      debugPrint(
          '🔍 [${replacedCount + 1}/${matches.length}] Procesando placeholder: "$placeholder" (campo: "$fieldName")');

      // Buscar el campo en currentStepStatuses
      String replacementValue = _getPlaceholderValue(fieldName);

      // Reemplazar el placeholder
      result = result.replaceAll(placeholder, replacementValue);

      final preview = replacementValue.length > 100
          ? '${replacementValue.substring(0, 100)}...'
          : replacementValue;
      debugPrint('   ✅ Reemplazado con: "$preview"');
      debugPrint('');

      replacedCount++;
    }

    debugPrint('📊 Total reemplazados: $replacedCount de ${matches.length}');
    return result;
  }

  String _getPlaceholderValue(String fieldName) {
    debugPrint('🔍 Buscando placeholder: "$fieldName"');

    // Buscar el status por nombre en activity_steps y root status
    dynamic targetStatus;
    int? targetStatusId;
    String? targetStatusType;

    // Buscar en activity_steps
    final activityStepsRaw =
        getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');
    debugPrint(
        '   Activity steps raw: ${activityStepsRaw != null ? "existe" : "null"}');

    if (activityStepsRaw != null) {
      final activitySteps =
          (activityStepsRaw is List) ? activityStepsRaw : [activityStepsRaw];
      debugPrint('   Buscando en ${activitySteps.length} steps');

      for (var step in activitySteps) {
        final statusListRaw = getJsonField(step, r'''$.activity_status''');
        if (statusListRaw != null) {
          final statusList =
              (statusListRaw is List) ? statusListRaw : [statusListRaw];
          debugPrint('     Revisando ${statusList.length} status en step');

          for (var status in statusList) {
            final statusNameField =
                getJsonField(status, r'''$.name_status''')?.toString() ?? '';
            debugPrint('       - Status: "$statusNameField"');

            if (statusNameField.toLowerCase() == fieldName.toLowerCase()) {
              targetStatus = status;
              targetStatusId =
                  getJsonField(status, r'''$.id_activity_status''')?.toInt();
              targetStatusType = getJsonField(status, r'''$.type_status''')
                  ?.toString()
                  .toLowerCase();
              debugPrint(
                  '       ✅ MATCH! id: $targetStatusId, tipo: $targetStatusType');
              break;
            }
          }
          if (targetStatus != null) break;
        }
      }
    }

    // Si no se encuentra en steps, buscar en root status (activity_status)
    if (targetStatus == null) {
      final rootStatusListRaw =
          getJsonField(FFAppState().currentActivity, r'''$.activity_status''');
      debugPrint(
          '   Buscando en activity_status: ${rootStatusListRaw != null ? "existe" : "null"}');

      if (rootStatusListRaw != null) {
        final rootStatusList = (rootStatusListRaw is List)
            ? rootStatusListRaw
            : [rootStatusListRaw];
        debugPrint('   Buscando en ${rootStatusList.length} root status');

        for (var status in rootStatusList) {
          final statusNameField =
              getJsonField(status, r'''$.name_status''')?.toString() ?? '';
          debugPrint('     - Root status: "$statusNameField"');

          if (statusNameField.toLowerCase() == fieldName.toLowerCase()) {
            targetStatus = status;
            targetStatusId =
                getJsonField(status, r'''$.id_activity_status''')?.toInt();
            targetStatusType = getJsonField(status, r'''$.type_status''')
                ?.toString()
                .toLowerCase();
            debugPrint(
                '     ✅ MATCH! id: $targetStatusId, tipo: $targetStatusType');
            break;
          }
        }
      }
    }

    if (targetStatus == null ||
        targetStatusId == null ||
        targetStatusType == null) {
      debugPrint('⚠️ Campo "$fieldName" NO encontrado en activity');
      return '[$fieldName]';
    }

    debugPrint(
        '📌 Campo encontrado: $fieldName (id: $targetStatusId, tipo: $targetStatusType)');

    // Según el tipo de status, obtener el valor apropiado
    switch (targetStatusType) {
      case 'date':
        return _getDateValue(targetStatusId);

      case 'time':
        return _getTimeValue(targetStatusId);

      case 'tag-reader':
        return _getTagReaderPlainText(targetStatusId);

      case 'distance-extractor':
        return _getDistanceExtractorValue(targetStatusId);

      case 'number':
        return _getNumberValue(targetStatusId);

      case 'numbers-operation':
        return _getNumbersOperationValue(targetStatusId);

      case 'label-info':
        // Para label-info, retornar el contenido de default_status
        final defaultStatus =
            getJsonField(targetStatus, r'''$.default_status''')?.toString() ??
                '';
        return defaultStatus.isNotEmpty ? defaultStatus : '[Sin información]';

      case 'text':
        // Para text, obtener de visitDetails
        final detail = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == targetStatusId,
              orElse: () => VisitsDetailsStruct(),
            );
        return detail.statusResponse.isNotEmpty
            ? detail.statusResponse
            : '[$fieldName]';

      case 'unique-list':
      case 'reference-list':
        // Para listas, obtener la opción seleccionada desde statusResponse
        final detail = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == targetStatusId,
              orElse: () => VisitsDetailsStruct(),
            );
        // Para reference-list, statusResponse contiene el nombre seleccionado (e.g., "WISTON HERNAN QUIÑONES ORTIZ")
        return detail.statusResponse.isNotEmpty
            ? detail.statusResponse
            : '[$fieldName]';

      default:
        // Para otros tipos, obtener de visitDetails
        final detail = FFAppState().visitDetails.firstWhere(
              (d) => d.statusOption.toLowerCase() == fieldName.toLowerCase(),
              orElse: () => VisitsDetailsStruct(),
            );
        return detail.statusResponse.isNotEmpty
            ? detail.statusResponse
            : '[$fieldName]';
    }
  }

  String _getDateValue(int statusId) {
    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );

    if (detail.statusResponse.isEmpty ||
        detail.statusResponse.startsWith('=')) {
      return '[Sin fecha]';
    }

    // Formatear la fecha
    try {
      final date = DateTime.parse(detail.statusResponse);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return detail.statusResponse;
    }
  }

  String _getTimeValue(int statusId) {
    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );

    if (detail.statusResponse.isEmpty ||
        detail.statusResponse.startsWith('=')) {
      return '[Sin hora]';
    }

    return detail.statusResponse;
  }

  /// Genera texto plano del tag-reader para usar en placeholders de dynamic-printing
  String _getTagReaderPlainText(int statusId) {
    final tagData = _tagReaderData[statusId] ?? [];
    if (tagData.isEmpty) {
      return 'Sin datos de TAG';
    }

    // Agrupar por lote (headquarterId)
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in tagData) {
      final heId = record['headquarterId'] as int? ?? 0;
      if (!groupedByHeadquarter.containsKey(heId)) {
        groupedByHeadquarter[heId] = [];
      }
      groupedByHeadquarter[heId]!.add(record);
    }

    // Generar texto plano con saltos de línea e indentación
    StringBuffer text = StringBuffer();

    for (var entry in groupedByHeadquarter.entries) {
      final headquarterId = entry.key;
      final records = entry.value;

      // Obtener nombre del lote
      String loteName = 'Lote #$headquarterId';
      final headquarters = FFAppState().headquartersList.firstWhere(
            (h) => h.idHeadquarter == headquarterId,
            orElse: () => HeadquartersStruct(),
          );

      if (headquarters.nameHeadquarter.isNotEmpty) {
        loteName = headquarters.nameHeadquarter;
      }

      // Agrupar por operador
      final Map<String, Map<String, dynamic>> operatorGroups = {};
      for (var record in records) {
        final operatorId = record['operatorId'] as String? ?? 'N/A';

        if (!operatorGroups.containsKey(operatorId)) {
          String operatorName = _getUserName(operatorId);

          operatorGroups[operatorId] = {
            'operatorName': operatorName,
            'totalVisits': 0,
            'totalResults': 0,
          };
        }

        final visits = (record['visits'] as int?) ?? 0;
        final results = (record['results'] as int?) ?? 0;

        operatorGroups[operatorId]!['totalVisits'] =
            (operatorGroups[operatorId]!['totalVisits'] as int) + visits;
        operatorGroups[operatorId]!['totalResults'] =
            (operatorGroups[operatorId]!['totalResults'] as int) + results;
      }

      // Calcular totales del lote
      int totalVisits = 0;
      int totalResults = 0;
      for (var operatorGroup in operatorGroups.values) {
        totalVisits += (operatorGroup['totalVisits'] as int?) ?? 0;
        totalResults += (operatorGroup['totalResults'] as int?) ?? 0;
      }

      // Texto del lote
      text.writeln(loteName);
      text.writeln(
          '$totalVisits visitas - $totalResults ${_unityLabel.toLowerCase()}');

      // Operadores con indentación
      for (var operatorGroup in operatorGroups.values) {
        final operatorName = operatorGroup['operatorName'];
        final opVisits = operatorGroup['totalVisits'];
        final opResults = operatorGroup['totalResults'];

        text.writeln(
            '  $operatorName: $opVisits visitas, $opResults ${_unityLabel.toLowerCase()}');
      }

      text.writeln(''); // Línea en blanco entre lotes
    }

    return text.toString().trim();
  }

  String _getDistanceExtractorValue(int statusId) {
    if (!_distanceExtractorCalculated.containsKey(statusId)) {
      return '[Sin calcular]';
    }

    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );

    if (detail.statusResponse.isEmpty) {
      return '[Sin distancia]';
    }

    // Extraer solo el número de km
    try {
      final distanceKm = double.parse(detail.statusResponse);
      return '${distanceKm.toStringAsFixed(2)} km';
    } catch (e) {
      return detail.statusResponse;
    }
  }

  String _getNumberValue(int statusId) {
    // Buscar el nombre del status para obtener el valor
    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );

    if (detail.statusOption.isEmpty) {
      return '0';
    }

    final currentValue = _statusValuesByName[detail.statusOption] ?? 0.0;
    return _formatColombianNumber(currentValue);
  }

  String _getNumbersOperationValue(int statusId) {
    final calculatedValue = _calculatedValues[statusId];
    if (calculatedValue == null) {
      return '[Sin calcular]';
    }

    return _formatColombianNumber(calculatedValue);
  }

  // ===== RESUMEN DEL TAG READER AGRUPADO POR LOTE =====

  Widget _buildTagReaderSummary({required int statusId}) {
    final tagData = _tagReaderData[statusId] ?? [];
    if (tagData.isEmpty) return const SizedBox.shrink();

    // Agrupar por lote (headquarterId)
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in tagData) {
      final heId = record['headquarterId'] as int? ?? 0;
      if (!groupedByHeadquarter.containsKey(heId)) {
        groupedByHeadquarter[heId] = [];
      }
      groupedByHeadquarter[heId]!.add(record);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332), // Verde oscuro
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Resumen del TAG',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // Mostrar geolocalización de forma sutil si está disponible
              if (_tagReaderGeolocations.containsKey(statusId)) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_tagReaderGeolocations[statusId]!.latitude.toStringAsFixed(5)}, ${_tagReaderGeolocations[statusId]!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...groupedByHeadquarter.entries.map((entry) {
            final headquarterId = entry.key;
            final records = entry.value;
            return _buildHeadquarterGroup(headquarterId, records);
          }),
        ],
      ),
    );
  }

  Widget _buildHeadquarterGroup(
      int headquarterId, List<Map<String, dynamic>> records) {
    // Buscar el nombre del lote
    String loteName = 'Lote #$headquarterId';
    final headquarters = FFAppState().headquartersList.firstWhere(
          (h) => h.idHeadquarter == headquarterId,
          orElse: () => HeadquartersStruct(),
        );

    if (headquarters.nameHeadquarter.isNotEmpty) {
      loteName = headquarters.nameHeadquarter;
    }

    final expansionKey = 'HE_$headquarterId';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    // Agrupar por par de operadores (OP + OP2)
    final Map<String, Map<String, dynamic>> operatorGroups = {};
    for (var record in records) {
      final operatorId = record['operatorId'] as String? ?? 'N/A';
      final operator2Id = record['operator2Id'] as String? ?? ''; // OP2 = IdActivityStatus

      debugPrint(
          '🔍 TAG-READER buildHeadquarterGroup: operatorId="$operatorId", operator2Id="$operator2Id"');

      // Crear clave compuesta por OP y OP2
      final operatorPairKey =
          operator2Id.isNotEmpty ? '${operatorId}_$operator2Id' : operatorId;

      if (!operatorGroups.containsKey(operatorPairKey)) {
        // Buscar nombre del operador principal en usersList
        String operatorName = _getUserName(operatorId);

        // Buscar nombre del cortero en Activities_status usando IdActivityStatus (OP2)
        String operator2Name = '';
        if (operator2Id.isNotEmpty) {
          debugPrint('🔍 TAG-READER: Buscando cortero con IdActivityStatus="$operator2Id"');
          // Aquí se buscará el nombre desde Activities_status usando OP2 como IdActivityStatus
          // Por ahora usamos una búsqueda simple; idealmente esto vendría de la DB
          operator2Name = _getCorterName(operator2Id);
          debugPrint('🔍 TAG-READER: Cortero Name resultado="$operator2Name"');
        } else {
          debugPrint('🔍 TAG-READER: operator2Id está VACÍO');
        }

        operatorGroups[operatorPairKey] = {
          'operatorId': operatorId,
          'operator2Id': operator2Id,
          'operatorName': operatorName,
          'operator2Name': operator2Name,
          'totalVisits': 0,
          'totalResults': 0,
          'records': <Map<String, dynamic>>[],
        };
      }

      final visits = (record['visits'] as int?) ?? 0;
      // Usar el valor de resultados que viene del tag NFC
      final results = (record['results'] as int?) ?? 0;

      operatorGroups[operatorPairKey]!['totalVisits'] =
          (operatorGroups[operatorPairKey]!['totalVisits'] as int) + visits;
      operatorGroups[operatorPairKey]!['totalResults'] =
          (operatorGroups[operatorPairKey]!['totalResults'] as int) + results;
      (operatorGroups[operatorPairKey]!['records']
              as List<Map<String, dynamic>>)
          .add(record);
    }

    // Calcular totales del lote
    int totalVisits = 0;
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
      totalVisits += (operatorGroup['totalVisits'] as int?) ?? 0;
      totalResults += (operatorGroup['totalResults'] as int?) ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F)
            .withValues(alpha: 0.3), // Verde medio con transparencia
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagReaderExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.white,
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loteName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${operatorGroups.length}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: operatorGroups.entries.map((entry) {
                  final operatorPairKey = entry.key;
                  final operatorData = entry.value;
                  return _buildTagReaderOperatorGroup(
                      headquarterId, operatorPairKey, operatorData);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagReaderOperatorGroup(int headquarterId, String operatorPairKey,
      Map<String, dynamic> operatorData) {
    final operator2Id = operatorData['operator2Id'] as String? ?? '';
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final operator2Name = operatorData['operator2Name'] as String? ?? '';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;
    final records =
        operatorData['records'] as List<Map<String, dynamic>>? ?? [];

    // Verificar si hay operador cortero (OP2)
    final hasOperator2 = operator2Id.isNotEmpty;

    final expansionKey = 'TR_OP_${headquarterId}_$operatorPairKey';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagReaderExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFF74C69D),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  // Mostrar icono de dos personas si hay cortero
                  if (hasOperator2)
                    const Icon(
                      Icons.people_outline_rounded,
                      color: Color(0xFF74C69D),
                      size: 18,
                    )
                  else
                    const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF74C69D),
                      size: 18,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP)
                        Text(
                          operatorName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        // Nombre del operador cortero (OP2) en línea separada
                        if (hasOperator2) ...[
                          const SizedBox(height: 2),
                          Text(
                            operator2Name.isNotEmpty
                                ? operator2Name
                                : operator2Id,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF74C69D),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 5),
              child: Column(
                children: records
                    .map((record) => _buildTagReaderVisitRecord(record))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagReaderVisitRecord(Map<String, dynamic> record) {
    final visits = record['visits'] as int? ?? 0;
    final results = record['results'] as int? ?? 0;
    final dateTime = record['dateTime'] as DateTime? ?? DateTime.now();

    // Formato de fecha: "Mié, 14 de Feb 2025"
    final dateFormatter = DateFormat('EEE, d \'de\' MMM yyyy HH:mm', 'es_ES');
    final formattedDate = dateFormatter.format(dateTime);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF081C15)
            .withValues(alpha: 0.5), // Verde muy oscuro con transparencia
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMetricChip('Visitas', visits.toString(), Colors.white),
              const SizedBox(width: 8),
              _buildMetricChip(_unityLabel, results.toString(), Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===== RESUMEN DEL TAG WRITER AGRUPADO POR LOTE =====

  Widget _buildTagWriterSummary({required int statusId}) {
    final headquarterData = _tagWriterData[statusId];
    if (headquarterData == null || headquarterData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular totales generales
    int grandTotalVisits = 0;
    for (var entry in headquarterData.values) {
      grandTotalVisits += (entry['totalVisits'] as int?) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(
            0xFF1B3A4B), // Azul oscuro para diferenciarlo del lector
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF64B5F6),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Registros escritos en TAG',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$grandTotalVisits visitas',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...headquarterData.entries.map((entry) {
            final headquarterId = entry.key;
            final data = entry.value;
            return _buildTagWriterHeadquarterGroup(headquarterId, data);
          }),
        ],
      ),
    );
  }

  Widget _buildTagWriterHeadquarterGroup(
      int headquarterId, Map<String, dynamic> data) {
    // Buscar el nombre del lote en headquartersList (igual que tag-reader)
    String loteName = 'Lote #$headquarterId';

    final headquarters = FFAppState().headquartersList.firstWhere(
          (h) => h.idHeadquarter == headquarterId,
          orElse: () => HeadquartersStruct(),
        );

    if (headquarters.nameHeadquarter.isNotEmpty) {
      loteName = headquarters.nameHeadquarter;
    }

    final expansionKey = 'TW_HE_$headquarterId';
    final isExpanded = _tagWriterExpansionState[expansionKey] ?? false;

    // Obtener los registros desde el data
    final records = (data['records'] as List<Map<String, dynamic>>?) ?? [];

    // Agrupar por par de operadores (OP + OP2)
    final Map<String, Map<String, dynamic>> operatorGroups = {};
    for (var record in records) {
      final operatorId = record['operatorId'] as String? ?? 'N/A';
      final operator2Id = record['operator2Id'] as String? ?? ''; // OP2 = IdActivityStatus

      debugPrint(
          '🔍 TAG-WRITER buildHeadquarterGroup: operatorId="$operatorId", operator2Id="$operator2Id"');

      // Crear clave compuesta por OP y OP2
      final operatorPairKey =
          operator2Id.isNotEmpty ? '${operatorId}_$operator2Id' : operatorId;

      if (!operatorGroups.containsKey(operatorPairKey)) {
        // Buscar nombre del operador principal en usersList
        String operatorName = _getUserName(operatorId);

        // Buscar nombre del cortero en Activities_status usando IdActivityStatus (OP2)
        String operator2Name = '';
        if (operator2Id.isNotEmpty) {
          debugPrint('🔍 TAG-WRITER: Buscando cortero con IdActivityStatus="$operator2Id"');
          operator2Name = _getCorterName(operator2Id);
          debugPrint('🔍 TAG-WRITER: Cortero Name resultado="$operator2Name"');
        } else {
          debugPrint('🔍 TAG-WRITER: operator2Id está VACÍO');
        }

        operatorGroups[operatorPairKey] = {
          'operatorId': operatorId,
          'operator2Id': operator2Id,
          'operatorName': operatorName,
          'operator2Name': operator2Name,
          'totalVisits': 0,
          'totalResults': 0,
          'records': <Map<String, dynamic>>[],
        };
      }

      final visits = (record['visits'] as int?) ?? 0;
      final results = (record['results'] as int?) ?? 0;

      operatorGroups[operatorPairKey]!['totalVisits'] =
          (operatorGroups[operatorPairKey]!['totalVisits'] as int) + visits;
      operatorGroups[operatorPairKey]!['totalResults'] =
          (operatorGroups[operatorPairKey]!['totalResults'] as int) + results;
      (operatorGroups[operatorPairKey]!['records']
              as List<Map<String, dynamic>>)
          .add(record);
    }

    // Calcular totales del lote
    int totalVisits = 0;
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
      totalVisits += (operatorGroup['totalVisits'] as int?) ?? 0;
      totalResults += (operatorGroup['totalResults'] as int?) ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagWriterExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFF64B5F6),
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loteName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${operatorGroups.length}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: operatorGroups.entries.map((entry) {
                  final operatorPairKey = entry.key;
                  final operatorData = entry.value;
                  return _buildTagWriterOperatorGroup(
                      headquarterId, operatorPairKey, operatorData);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagWriterOperatorGroup(int headquarterId, String operatorPairKey,
      Map<String, dynamic> operatorData) {
    final operator2Id = operatorData['operator2Id'] as String? ?? '';
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final operator2Name = operatorData['operator2Name'] as String? ?? '';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;
    final records =
        operatorData['records'] as List<Map<String, dynamic>>? ?? [];

    final expansionKey = 'TW_OP_${headquarterId}_$operatorPairKey';
    final isExpanded = _tagWriterExpansionState[expansionKey] ?? false;

    // Verificar si hay operador cortero (OP2)
    final hasOperator2 = operator2Id.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF64B5F6).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagWriterExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFF64B5F6),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  // Mostrar dos iconos si hay cortero
                  if (hasOperator2) ...[
                    const Icon(
                      Icons.people_outline_rounded,
                      color: Color(0xFF64B5F6),
                      size: 18,
                    ),
                  ] else ...[
                    const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF64B5F6),
                      size: 18,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP)
                        Text(
                          operatorName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        // Nombre del operador cortero (OP2) en línea separada
                        if (hasOperator2) ...[
                          const SizedBox(height: 2),
                          Text(
                            operator2Name.isNotEmpty
                                ? operator2Name
                                : operator2Id,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64B5F6),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 5),
              child: Column(
                children: records
                    .map((record) => _buildTagWriterVisitRecord(record))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagWriterVisitRecord(Map<String, dynamic> record) {
    final visits = record['visits'] as int? ?? 0;
    final results = record['results'] as int? ?? 0;
    final dateTime = record['dateTime'] as DateTime? ?? DateTime.now();

    // Formato de fecha: "Mié, 14 de Feb 2025 HH:mm"
    final dateFormatter = DateFormat('EEE, d \'de\' MMM yyyy HH:mm', 'es_ES');
    final formattedDate = dateFormatter.format(dateTime);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMetricChip(
                  'Visitas', visits.toString(), const Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              _buildMetricChip(
                  _unityLabel, results.toString(), const Color(0xFF64B5F6)),
            ],
          ),
        ],
      ),
    );
  }

  // ===== RESUMEN DEL TAG TRANSFER AGRUPADO POR LOTE =====

  Widget _buildTagTransferSummary({required int statusId}) {
    final headquarterData = _tagTransferData[statusId];
    if (headquarterData == null || headquarterData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular totales generales
    int grandTotalVisits = 0;
    for (var entry in headquarterData.values) {
      grandTotalVisits += (entry['totalVisits'] as int?) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A4B), // Azul oscuro igual que tag-writer
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF64B5F6),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Tag de origen leído',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$grandTotalVisits visitas',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...headquarterData.entries.map((entry) {
            final headquarterId = entry.key;
            final data = entry.value;
            return _buildTagTransferHeadquarterGroup(headquarterId, data);
          }),
          // Botón TRANSFERIR AHORA o mensaje de éxito
          const SizedBox(height: 16),
          _tagTransferCompleted[statusId] == true
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00a86b), Color(0xFF008c5a)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00a86b).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'TRANSFERENCIA EXITOSA',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                )
              : InkWell(
                  onTap: () async {
                    // Obtener el contenido del tag de origen desde FFAppState
                    final sourceTagContent = FFAppState().nfcRead;
                    if (sourceTagContent.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No hay contenido de origen disponible',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Abrir diálogo de escritura en tag de destino
                    final result = await showDialog<bool>(
                      barrierDismissible: false,
                      context: context,
                      builder: (dialogContext) {
                        return Dialog(
                          elevation: 0,
                          insetPadding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          child: NfcTransferWriteDialogWidget(
                            sourceTagContent: sourceTagContent,
                          ),
                        );
                      },
                    );

                    // Si la transferencia fue exitosa, mostrar mensaje y marcar como completada
                    if (result == true && mounted) {
                      setState(() {
                        _tagTransferCompleted[statusId] = true;
                      });
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Transferencia completada exitosamente',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Color(0xFF00a86b),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'TRANSFERIR AHORA',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTagTransferHeadquarterGroup(
      int headquarterId, Map<String, dynamic> data) {
    // Buscar el nombre del lote en headquartersList
    String loteName = 'Lote #$headquarterId';

    final headquarters = FFAppState().headquartersList.firstWhere(
          (h) => h.idHeadquarter == headquarterId,
          orElse: () => HeadquartersStruct(),
        );

    if (headquarters.nameHeadquarter.isNotEmpty) {
      loteName = headquarters.nameHeadquarter;
    }

    final expansionKey = 'TT_HE_$headquarterId';
    final isExpanded = _tagTransferExpansionState[expansionKey] ?? false;

    final totalVisits = (data['totalVisits'] as int?) ?? 0;
    final totalResults = (data['totalResults'] as int?) ?? 0;
    final records = (data['records'] as List<Map<String, dynamic>>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagTransferExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFF64B5F6),
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loteName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${records.length}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: records.map((record) {
                  return _buildTagTransferRecord(record);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagTransferRecord(Map<String, dynamic> record) {
    final operatorId = record['operatorId'] as String? ?? 'N/A';
    final operator2Id = record['operator2Id'] as String? ?? '';
    final visits = record['visits'] as int? ?? 0;
    final results = record['results'] as int? ?? 0;
    final dateTime = record['dateTime'] as DateTime? ?? DateTime.now();

    debugPrint(
        '🔍 TAG-TRANSFER Record: operatorId="$operatorId", operator2Id="$operator2Id"');

    // Buscar el nombre del operador principal
    String operatorName = _getUserName(operatorId);

    // operator2Id ahora contiene el IdActivityStatus (ID único de Activities_status)
    // Buscamos el nombre del cortero para display
    String operator2Name = '';
    if (operator2Id.isNotEmpty) {
      debugPrint('🔍 TAG-TRANSFER: Buscando cortero con IdActivityStatus="$operator2Id"');
      operator2Name = _getCorterName(operator2Id);
      debugPrint('🔍 TAG-TRANSFER: Cortero nombre="$operator2Name"');
    } else {
      debugPrint('🔍 TAG-TRANSFER: operator2Id está VACÍO');
    }

    // Construir textos de display
    final hasOperator2 = operator2Id.isNotEmpty;
    final displayName =
        hasOperator2 ? '$operatorName / $operator2Name' : operatorName;
    final displayIds = hasOperator2
        ? 'Op: $operatorId | Cortero ID: $operator2Id'
        : 'Op: $operatorId';

    // Formato de fecha: "Mié, 14 de Feb 2025"
    final dateFormatter = DateFormat('EEE, d \'de\' MMM yyyy HH:mm', 'es_ES');
    final formattedDate = dateFormatter.format(dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasOperator2
                    ? Icons.people_outline_rounded
                    : Icons.person_outline_rounded,
                color: const Color(0xFF64B5F6),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  displayIds,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMetricChip(
                  'Visitas', visits.toString(), const Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              _buildMetricChip(
                  _unityLabel, results.toString(), const Color(0xFF64B5F6)),
            ],
          ),
        ],
      ),
    );
  }

  // ===== VISUALIZACIÓN DE NUMBERS-OPERATION =====

  Widget _buildNumbersOperationDisplay({
    required int statusId,
    required dynamic status,
  }) {
    final calculatedValue = _calculatedValues[statusId] ?? 0.0;
    final formula =
        getJsonField(status, r'''$.default_status''')?.toString() ?? '';
    final hasBeenCalculated = _numbersOperationCalculated[statusId] ?? false;

    // Colores: Verde si ya fue calculado, Blanco si aún no
    final backgroundColor = hasBeenCalculated
        ? [const Color(0xFF1B4332), const Color(0xFF2D6A4F)] // Verde oscuro
        : [
            const Color(0xFFF5F5F5),
            const Color(0xFFFFFFFF)
          ]; // Blanco/Gris claro

    final borderColor = hasBeenCalculated
        ? const Color(0xFF40916C).withValues(alpha: 0.5)
        : const Color(0xFFBDBDBD).withValues(alpha: 0.5);

    final iconColor =
        hasBeenCalculated ? const Color(0xFF52B788) : const Color(0xFF9E9E9E);

    final textColor = hasBeenCalculated
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF424242);

    final valueColor =
        hasBeenCalculated ? const Color(0xFF95D5B2) : const Color(0xFF757575);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundColor,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_rounded,
                color: iconColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Resultado Calculado',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onLongPress: () {
              setState(() {
                _showFormulaForOperation[statusId] =
                    !(_showFormulaForOperation[statusId] ?? false);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasBeenCalculated
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Valor calculado (siempre visible)
                  Center(
                    child: Text(
                      _formatColombianNumber(calculatedValue),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
                  ),
                  // Fórmula (solo visible si se hace long press)
                  if (_showFormulaForOperation[statusId] == true) ...[
                    const SizedBox(height: 8),
                    Divider(
                      color: hasBeenCalculated
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.3),
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fórmula: $formula',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: hasBeenCalculated
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF757575),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelInfoDisplay({
    required String statusName,
    required int statusId,
    required dynamic status,
  }) {
    // Obtener el valor de default_status
    final defaultStatus =
        getJsonField(status, r'''$.default_status''')?.toString() ?? '';
    final displayValue =
        defaultStatus.isNotEmpty ? defaultStatus : 'Sin información';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF66BB6A),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceExtractorDisplay({required int statusId}) {
    final distanceFromTag = _calculatedDistances[statusId] ?? 0.0;
    final distancesFromProducts = _calculatedDistancesFromProduct[statusId];

    final distanceFromTagKm = distanceFromTag / 1000;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332), // Verde oscuro (mismo que tag-reader)
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.straighten_rounded,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Distancia a Extractora',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // OPCIÓN 1: Desde TAG
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desde TAG',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${distanceFromTagKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // OPCIÓN 2: Desde Productos (una fila por cada lote)
          if (distancesFromProducts != null &&
              distancesFromProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Título de la sección
            Text(
              'Desde Productos:',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Lista de distancias por lote
            ...distancesFromProducts.map((item) {
              final loteName = item['headquarterName'] as String;
              final distance = item['distance'] as double;
              final line = item['line'] as int?;
              final palm = item['palm'] as int?;
              final distanceKm = distance / 1000;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loteName,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (line != null && palm != null)
                              Text(
                                'L:$line P:$palm',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${distanceKm.toStringAsFixed(2)} km',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ===== TECLADO NUMÉRICO DE PANTALLA COMPLETA =====

  Future<int?> _showFullScreenNumericKeyboard(int initialValue) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _FullScreenNumericKeyboardDialog(initialValue: initialValue);
      },
    );
  }

  // ===== VISUALIZACIÓN DE HEADQUARTER WEIGHTS =====

  Widget _buildHeadquarterWeightsDisplay() {
    // Si hay lotes sin peso, mostrar SOLO advertencia
    if (_headquartersWithoutWeight.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFCA5A5),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Peso promedio no configurado',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Los siguientes lotes no tienen peso promedio configurado para el mes actual. No se puede realizar el cálculo.',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Lista de lotes sin peso
            ..._headquartersWithoutWeight.map((hq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFFCA5A5),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hq['headquarterName'],
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${hq['headquarterId']}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Sin peso',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFFCA5A5),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure el peso promedio en el sistema antes de continuar.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Si todos los lotes tienen peso, mostrar display normal
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF40916C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                color: Color(0xFF52B788),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Pesos de Lotes',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mostrar cada headquarter weight
          ..._headquarterWeights.entries.map((entry) {
            final headquarterId = entry.key;
            final weight = entry.value;

            // Buscar el nombre del lote en FFAppState().headquartersSelectedList
            String headquarterName = 'Lote $headquarterId';
            try {
              final headquarters = FFAppState().headquartersSelectedList;
              final hq = headquarters.firstWhere(
                (h) => h.idHeadquarter == headquarterId,
                orElse: () => HeadquartersStruct(),
              );
              if (hq.nameHeadquarter.isNotEmpty) {
                headquarterName = hq.nameHeadquarter;
              }
            } catch (e) {
              // Usar nombre por defecto
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF52B788).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headquarterName,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: $headquarterId',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF52B788), Color(0xFF40916C)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${weight.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===== VISUALIZACIÓN DE FECHA Y HORA EN STATUS =====

  /// Muestra el valor de fecha seleccionado al lado del nombre del status
  Widget _buildDateValueDisplay(int statusId, int parentStepId,
      {bool hasValue = false}) {
    // Buscar el valor en visitDetails
    String dateValue = functions.statusResponseByActivityStatusAlternative(
      statusId,
      FFAppState().visitDetails.toList(),
      parentStepId,
    );

    if (dateValue.isEmpty || dateValue == '[Fecha]') {
      return const SizedBox.shrink();
    }

    // Si es una fórmula (=DATENOW, =TIMENOW, etc.), no mostrar nada
    if (dateValue.startsWith('=')) {
      return const SizedBox.shrink();
    }

    // Formatear la fecha
    try {
      final date = DateTime.parse(dateValue);
      // Formato: "Miércoles 15 de Junio 2025"
      final dayName = DateFormat('EEEE', 'es_ES').format(date);
      final day = date.day;
      final monthName = DateFormat('MMMM', 'es_ES').format(date);
      final year = date.year;

      // Capitalizar primera letra
      final capitalizedDay = dayName[0].toUpperCase() + dayName.substring(1);
      final capitalizedMonth =
          monthName[0].toUpperCase() + monthName.substring(1);

      final formattedDate = '$capitalizedDay $day de $capitalizedMonth $year';

      // Colores según si está seleccionado
      final textColor = hasValue ? Colors.white : const Color(0xFF00a86b);
      final bgColor = hasValue
          ? Colors.white.withValues(alpha: 0.2)
          : const Color(0xFF00a86b).withValues(alpha: 0.15);
      final borderColor = hasValue
          ? Colors.white.withValues(alpha: 0.5)
          : const Color(0xFF00a86b).withValues(alpha: 0.3);

      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  formattedDate,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error formateando fecha: $e');
      return const SizedBox.shrink();
    }
  }

  /// Muestra el valor de hora seleccionado al lado del nombre del status
  Widget _buildTimeValueDisplay(int statusId, int parentStepId,
      {bool hasValue = false}) {
    // Buscar el valor en visitDetails
    String timeValue = functions.statusResponseByActivityStatusAlternative(
      statusId,
      FFAppState().visitDetails.toList(),
      parentStepId,
    );

    if (timeValue.isEmpty || timeValue == '[Hora]') {
      return const SizedBox.shrink();
    }

    // Si es una fórmula (=TIMENOW, etc.), no mostrar nada
    if (timeValue.startsWith('=')) {
      return const SizedBox.shrink();
    }

    // El valor viene en formato TimeOfDay serializado, extraer horas y minutos
    try {
      // El formato puede ser "HH:mm" o un TimeOfDay serializado
      String formattedTime = timeValue;
      int hour24 = 0;
      int minute = 0;

      // Si es un TimeOfDay serializado como "TimeOfDay(HH:MM)"
      if (timeValue.contains('TimeOfDay')) {
        final match = RegExp(r'TimeOfDay\((\d+):(\d+)\)').firstMatch(timeValue);
        if (match != null) {
          hour24 = int.parse(match.group(1)!);
          minute = int.parse(match.group(2)!);
        }
      } else {
        // Si es formato HH:mm directo
        final parts = timeValue.split(':');
        if (parts.length == 2) {
          hour24 = int.parse(parts[0]);
          minute = int.parse(parts[1]);
        }
      }

      // Convertir a formato 12 horas con am/pm
      String period = hour24 >= 12 ? 'pm' : 'am';
      int hour12 = hour24 % 12;
      if (hour12 == 0) hour12 = 12;

      formattedTime =
          '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';

      // Colores según si está seleccionado
      final textColor = hasValue ? Colors.white : const Color(0xFF00a86b);
      final bgColor = hasValue
          ? Colors.white.withValues(alpha: 0.2)
          : const Color(0xFF00a86b).withValues(alpha: 0.15);
      final borderColor = hasValue
          ? Colors.white.withValues(alpha: 0.5)
          : const Color(0xFF00a86b).withValues(alpha: 0.3);

      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Text(
                formattedTime,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error formateando hora: $e');
      return const SizedBox.shrink();
    }
  }

  // ===== DECODIFICAR HTML ENTITIES =====

  /// Decodifica HTML entities comunes que pueden venir escapadas del JSON
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x3D;', '=')
        .replaceAll('&nbsp;', ' ');
  }
}

// ===== DIÁLOGO DE TECLADO NUMÉRICO DE PANTALLA COMPLETA =====

class _FullScreenNumericKeyboardDialog extends StatefulWidget {
  final int initialValue;

  const _FullScreenNumericKeyboardDialog({
    required this.initialValue,
  });

  @override
  State<_FullScreenNumericKeyboardDialog> createState() =>
      _FullScreenNumericKeyboardDialogState();
}

class _FullScreenNumericKeyboardDialogState
    extends State<_FullScreenNumericKeyboardDialog> {
  late String _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue =
        widget.initialValue > 0 ? widget.initialValue.toString() : '';
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_currentValue.length < 6) {
        _currentValue += number;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_currentValue.isNotEmpty) {
        _currentValue = _currentValue.substring(0, _currentValue.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _currentValue = '';
    });
  }

  void _onConfirm() {
    if (_currentValue.isNotEmpty) {
      final value = int.tryParse(_currentValue);
      if (value != null && value > 0) {
        Navigator.of(context).pop(value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF003420),
              Color(0xFF002415),
              Color(0xFF00150A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header con botón cerrar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ingresar Número',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00ff9f),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Display del número
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1B4332).withValues(alpha: 0.6),
                          const Color(0xFF2D6A4F).withValues(alpha: 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF52B788).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _currentValue.isEmpty ? '0' : _currentValue,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF52B788),
                        letterSpacing: 4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Teclado numérico
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Fila 1: 1, 2, 3
                      Expanded(
                        child: Row(
                          children: [
                            _buildKeyButton('1'),
                            const SizedBox(width: 12),
                            _buildKeyButton('2'),
                            const SizedBox(width: 12),
                            _buildKeyButton('3'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Fila 2: 4, 5, 6
                      Expanded(
                        child: Row(
                          children: [
                            _buildKeyButton('4'),
                            const SizedBox(width: 12),
                            _buildKeyButton('5'),
                            const SizedBox(width: 12),
                            _buildKeyButton('6'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Fila 3: 7, 8, 9
                      Expanded(
                        child: Row(
                          children: [
                            _buildKeyButton('7'),
                            const SizedBox(width: 12),
                            _buildKeyButton('8'),
                            const SizedBox(width: 12),
                            _buildKeyButton('9'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Fila 4: C, 0, ⌫
                      Expanded(
                        child: Row(
                          children: [
                            _buildActionButton(
                              'C',
                              Icons.clear_rounded,
                              _onClear,
                              const Color(0xFFFF5252),
                            ),
                            const SizedBox(width: 12),
                            _buildKeyButton('0'),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              '⌫',
                              Icons.backspace_rounded,
                              _onBackspace,
                              const Color(0xFFFFA726),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Botón CONFIRMAR
                      InkWell(
                        onTap: _onConfirm,
                        child: Container(
                          width: double.infinity,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00a86b), Color(0xFF00d980)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00a86b)
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'CONFIRMAR',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildKeyButton(String number) {
    return Expanded(
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2D6A4F),
                Color(0xFF40916C),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D6A4F).withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
