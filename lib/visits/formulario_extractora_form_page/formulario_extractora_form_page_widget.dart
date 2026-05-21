import '/backend/schema/structs/index.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/components/nfc_read_dialog_widget.dart';
import '/components/nfc_write_dialog_widget.dart';
import '/components/nfc_transfer_write_dialog_widget.dart';
import '/components/qr_scanner_dialog_widget.dart';
import '/components/photo_capture_component_widget.dart';
import '/components/video_capture_component_widget.dart';
import '/components/date_picker_component_widget.dart';
import '/components/time_picker_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/services.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:io';
import '/custom_code/platform_utils.dart';
import '/custom_code/actions/adb_nfc_bridge_service.dart';
import '/custom_code/actions/adb_nfc_client_service.dart';
import 'dart:math' as math;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'formulario_extractora_form_page_model.dart';
export 'formulario_extractora_form_page_model.dart';

class FormularioExtractorPageWidget extends StatefulWidget {
  const FormularioExtractorPageWidget({
    super.key,
    String? tittle,
  }) : tittle = tittle ?? 'Módulo ClickPalm';

  final String tittle;

  static String routeName = 'FormularioExtractorPage';
  static String routePath = '/formularioExtractorPage';

  @override
  State<FormularioExtractorPageWidget> createState() => _FormularioExtractorPageWidgetState();
}

class _FormularioExtractorPageWidgetState extends State<FormularioExtractorPageWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late FormularioExtractorPageModel _model;

  // Mantener vivo el estado cuando se cambia de tab
  @override
  bool get wantKeepAlive => true;

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

  // Map para acumulación de tags en modo NO_REMOVE (statusId → lista de raw JSON strings)
  final Map<int, List<String>> _tagReaderRawJsons = {};

  // Map para controlar el estado de expansión del tree view de tag-reader (por lote)
  final Map<String, bool> _tagReaderExpansionState = {};

  // Map para almacenar geolocalizaciones capturadas al leer tags NFC por status_id
  final Map<int, ReadGeoStruct> _tagReaderGeolocations = {};

  // Maps para almacenar nombres de producto por status_id (de la tabla Products de SQLite)
  final Map<int, String> _tagReaderProductName = {};
  final Map<int, String> _tagWriterProductName = {};
  final Map<int, String> _tagTransferSourceProductName = {};
  final Map<int, String> _tagTransferDestProductName = {};

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

  // Checkboxes para tags ADB acumulados (statusId → Set de índices marcados)
  final Map<int, Set<int>> _adbTagChecked = {};

  // Código de supervisor requerido para confirmar la eliminación de una visita
  // pendiente desde el botón ELIMINAR del bottom bar.
  // TODO: mover a configuración remota / FFAppState cuando se defina el flujo
  //       de gestión de códigos de supervisor.
  static const String _kSupervisorDeleteCode = '9229';

  // ── Persistencia incremental de Visits_details en SQLite ─────────────────
  // _activeVisitId: Id_visit de la última visita creada por _autoSaveVisitFromAdbTag.
  // Los UPDATEs incrementales (number, date, time, etc.) apuntan a esta visita.
  // Null antes del primer tag ADB.
  int? _activeVisitId;
  // _formLocked: true mientras no haya tag ADB leído. Bloquea inputs vía IgnorePointer.
  bool _formLocked = true;
  // _processingTag: true desde que llega el JSON del tag hasta que
  // _autoSaveVisitFromAdbTag termina (incluyendo cálculos). Hace que el overlay
  // muestre un spinner en lugar del mensaje "Lea un tag para empezar".
  bool _processingTag = false;
  // _voiceEnabled: controla si se anuncia la visita por voz al guardar el tag.
  // Por defecto OFF; se alterna con el botón del header.
  bool _voiceEnabled = false;
  // Map índice de tarjeta del panel ADB → Id_visit en SQLite.
  // Se llena al recibir un tag (insert) y al cargar pendientes en initState.
  // Permite que el toque en una tarjeta dispare la rehidratación de la visita.
  final Map<int, int> _pendingTagIndexToVisitId = {};
  // Índice de la tarjeta que está animando su salida (Status=0 → Status=1).
  // Mientras es != null, esa tarjeta se renderiza con AnimatedSlide+AnimatedOpacity.
  int? _animatingOutTagIndex;

  // ── ADB NFC Bridge (tag-transfer-adb-server / tag-transfer-adb-from) ──────
  AdbBridgeStatus _adbServerStatus = AdbBridgeStatus.serverDown;
  bool _isRestartingAdb = false;
  StreamSubscription<AdbBridgeStatus>? _adbStatusSub;
  StreamSubscription<Map<String, dynamic>>? _adbTagSub;
  final Map<int, Map<String, dynamic>> _adbReceivedTagData = {};
  bool _adbClientConnected = false;
  StreamSubscription<bool>? _adbClientConnSub;
  StreamSubscription<Map<String, dynamic>>? _adbServerCommandSub;
  // Panel superior ADB
  bool _hasAdbServerField = false;
  int? _adbServerStatusId;
  int _selectedAdbTagIndex = 0;
  final List<DateTime> _adbTagTimestamps = [];
  // Una entrada por tarjeta leída (índice = número de tarjeta)
  final Map<int, List<List<Map<String, dynamic>>>> _adbServerCardsData = {};
  final Map<int, List<String>> _adbServerCardsProductName = {};
  final Map<int, List<String>> _adbServerCardsRawJson = {};  // raw JSON completo por tarjeta
  // Caché de productos para lookup inline adb-server
  final Map<int, String> _productByIdCache = {};      // Id_product -> Name_product
  final Map<String, String> _productByRfidCache = {}; // Rfid -> Name_product

  // Caché de nombres de corteros desde SQLite (id_activity_status -> status_name)
  final Map<int, String> _corteroNamesCache = {};

  // Caché de nombres de usuarios desde SQLite (id_user -> name_user)
  final Map<int, String> _userNamesCache = {};

  // Caché de identificación de usuarios desde SQLite (id_user -> Identificacion
  // o, si está vacía, Oper_id). Se llena de forma asíncrona vía
  // _loadUserIdentificacionFromSQLite.
  final Map<int, String> _userIdentificacionCache = {};
  final Set<int> _userIdentificacionLoading = {};

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

  // Map para almacenar resultados calculados de peso por headquarter
  // headquarterId -> {weight, totalResults, calculatedWeight}
  final Map<int, Map<String, dynamic>> _calculatedHeadquarterWeights = {};

  // Resultados de distribución proporcional de peso (=CALCULATION_DISTRIBUTION)
  // statusId -> {pesoNeto, factor, grandTotal, lotes, error, ...}
  final Map<int, Map<String, dynamic>> _calculatedDistributions = {};

  // Estado de expansión del árbol de distribución: 'DIST_{statusId}_{hqId}' → bool
  final Map<String, bool> _distributionExpansionState = {};

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

  // Map para controladores de texto (tipo text)
  final Map<int, TextEditingController> _textControllers = {};

  // Map para rastrear qué unique-option hijo está seleccionado bajo cada padre multiple-option
  // Clave: idActivityStatus del padre multiple-option
  // Valor: idActivityStatus del hijo unique-option seleccionado
  final Map<int, int> _selectedUniqueOptionByParent = {};

  // Map para FocusNodes de texto (tipo text)
  final Map<int, FocusNode> _textFocusNodes = {};

  // Map para controladores de búsqueda de usuarios (tipo users-list)
  final Map<int, TextEditingController> _usersSearchControllers = {};

  // Map para FocusNodes de búsqueda de usuarios (tipo users-list)
  final Map<int, FocusNode> _usersSearchFocusNodes = {};

  // Map para almacenar resultados de búsqueda de usuarios (tipo users-list)
  final Map<int, List<UsersStruct>> _usersSearchResults = {};

  // Set para rastrear qué status ya se loguearon (para evitar spam en logs)
  final Set<int> _loggedStatusIds = {};


  // ============================================================================
  // CACHÉ DE RENDIMIENTO - LOTE 1
  // ============================================================================

  // Caché de activity steps y status ordenados (evita parseo y sorting en cada rebuild)
  List<dynamic> _cachedActivitySteps = [];
  List<dynamic> _cachedActivityStatus = [];
  bool _isDataCacheInitialized = false;

  // TabController para steps de tipo tab-container
  TabController? _tabController;

  // Caché de hijos de reference-list cargados desde activitiesJSON por default_status
  // statusId → List<dynamic> de statuses de la actividad referenciada
  final Map<int, List<dynamic>> _referenceListChilds = {};

  // Caché de búsquedas en visitDetails (evita O(n) en cada rebuild)
  final Map<String, bool> _visitDetailsSearchCache = {};
  int _lastVisitDetailsLength = 0;

  // Getter para obtener el texto de Unity o "Resultados" por defecto
  String get _unityLabel {
    final unity = FFAppState().activitySelected.unity;
    return unity.isNotEmpty ? unity : 'Resultados';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormularioExtractorPageModel());
    _initializeDataCache(); // LOTE 1: Inicializar caché de datos
    _migrateHtmlToCheckmark(); // Migrar HTML antiguo a checkmark
    _initializeExpansionStates();

    // Restaurar caché del formulario si existe
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _restoreFormCache();
      await _restoreTagTransferFromPrefs();
      _initializeDateTimeDefaults();
      _preloadUserNamesFromSQLite(); // Pre-cargar nombres de usuarios para el árbol de tags
      _initAdbBridge(); // Inicializar bridge ADB si corresponde
      // Hidratar visitas pendientes (Status=0) del Id_activity actual: las
      // muestra en el panel izquierdo y rehidrata el formulario con la más
      // reciente. Se ejecuta DESPUÉS de _initAdbBridge para que
      // _adbServerStatusId ya esté seteado.
      await _loadPendingVisitsFromSQLite();
    });
  }

  void _initAdbBridge() {
    final statuses = _cachedActivityStatus;

    // Incluir también los statuses dentro de steps (tag-transfer-adb-server puede estar en un step)
    final List<dynamic> allStatuses = [...statuses];
    for (final step in _cachedActivitySteps) {
      final stepStatuses = getJsonField(step, r'''$.activities_status''');
      if (stepStatuses is List) allStatuses.addAll(stepStatuses);
    }

    final hasServerField = allStatuses.any((s) =>
        (getJsonField(s, r'''$.type_status''')?.toString() ?? '')
                .toLowerCase() ==
            'tag-transfer-adb-server');
    final hasFromField = allStatuses.any((s) =>
        (getJsonField(s, r'''$.type_status''')?.toString() ?? '')
                .toLowerCase() ==
            'tag-transfer-adb-from');

    if (hasServerField && Platforms.isDesktop) {
      // Guardar flag y statusId del primer campo adb-server detectado
      _hasAdbServerField = true;
      final firstServer = allStatuses.firstWhere(
        (s) => (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase() == 'tag-transfer-adb-server',
        orElse: () => null,
      );
      _adbServerStatusId = firstServer != null
          ? getJsonField(firstServer, r'''$.id_activity_status''') as int?
          : null;

      _adbStatusSub = AdbNfcBridgeService.instance.onStatusChanged.listen((status) {
        if (mounted) setState(() => _adbServerStatus = status);
      });
      _adbTagSub = AdbNfcBridgeService.instance.onTagReceived.listen((payload) {
        if (!mounted) {
          debugPrint('🟡 ADB-TAG listener: widget NO mounted, ignorando tag');
          return;
        }
        debugPrint(
            '🟢 ADB-TAG listener: tag recibido — payload keys=${payload.keys.toList()}');

        // Lista de (statusId, statusName) para los que hay que recalcular
        final List<({int id, String name})> toRecalc = [];

        // Sets recolectados durante el setState para warm-up de cachés
        // (nombres de cargueros, pesos de lotes, identificaciones).
        final Set<int> heIdsToWarm = {};
        final Set<int> usIdsToWarm = {};
        final Set<String> opIdsToWarm = {};

        setState(() {
          final serverStatuses = allStatuses.where((s) =>
              (getJsonField(s, r'''$.type_status''')?.toString() ?? '')
                      .toLowerCase() ==
                  'tag-transfer-adb-server');
          for (final s in serverStatuses) {
            final id = getJsonField(s, r'''$.id_activity_status''') as int?;
            if (id == null) continue;
            _adbReceivedTagData[id] = payload;
            final tagContent = payload['tagContent'] as String? ?? '';
            final productName = payload['productName'] as String? ?? '';
            if (tagContent.isEmpty) continue;

            // Cada tag es una tarjeta independiente — sin acumulación ni reemplazo
            final parsed = _parseNfcTagContent(tagContent);
            _adbServerCardsData[id] ??= [];
            _adbServerCardsData[id]!.add(parsed);
            _adbServerCardsProductName[id] ??= [];
            _adbServerCardsProductName[id]!.add(productName);
            _adbServerCardsRawJson[id] ??= [];
            _adbServerCardsRawJson[id]!.add(tagContent);

            // Registrar timestamp y seleccionar la nueva tarjeta
            _adbTagTimestamps.add(DateTime.now());
            final newIndex = _adbTagTimestamps.length - 1;
            _selectedAdbTagIndex = newIndex;

            // Mostrar en el árbol inline los datos de la tarjeta recién recibida
            _tagReaderData[id] = parsed;
            _tagReaderProductName[id] = productName;
            _tagReaderRawJsons.remove(id);
            debugPrint(
                '🟢 ADB-TAG: actualizando caches para statusId=$id — '
                'parsed.length=${parsed.length} '
                'rawJsons.length=${_adbServerCardsRawJson[id]?.length ?? 0}');

            // Recolectar IDs para warm-up de cachés (US, OP, HE).
            try {
              final decoded = jsonDecode(tagContent) as Map<String, dynamic>;
              final us = (decoded['Read_info'] as Map?)?['US'];
              if (us is int) usIdsToWarm.add(us);
            } catch (_) {}
            for (final r in parsed) {
              final op = (r['operatorId'] as String?) ?? '';
              if (op.isNotEmpty) opIdsToWarm.add(op);
              final he = (r['headquarterId'] as int?) ?? 0;
              if (he > 0) heIdsToWarm.add(he);
            }

            // Registrar para recalcular headquarter-weight después del setState
            final sName = getJsonField(s, r'''$.status_name''')?.toString() ?? '';
            toRecalc.add((id: id, name: sName));
          }
        });

        // Warm-up de cachés que la UI del card ADB necesita. Cada lookup
        // dispara una carga async desde SQLite + setState al completar; la
        // siguiente rebuild mostrará nombres/pesos resueltos en lugar del
        // fallback (ej. "Carguero #293").
        for (final usId in usIdsToWarm) {
          _getUserName(usId.toString());
          _getUserIdentificacion(usId);
        }
        for (final opId in opIdsToWarm) {
          _getUserName(opId);
          final asInt = int.tryParse(opId);
          if (asInt != null) _getUserIdentificacion(asInt);
        }
        if (heIdsToWarm.isNotEmpty) {
          unawaited(_loadHeadquarterWeights(heIdsToWarm.toList()));
        }

        // Disparar cálculos fuera del setState (son async)
        for (final entry in toRecalc) {
          _autoCalculateRelatedDistances(entry.id, entry.name);
          _autoCalculateRelatedHeadquarterWeights(entry.id, entry.name);
        }

        // Auto-guardar visita en SQLite al recibir cada tag
        final tagContent = payload['tagContent'] as String? ?? '';
        if (tagContent.isNotEmpty) {
          // Mostrar spinner inmediatamente — la guarda y los cálculos demoran
          // unos segundos, durante los cuales el overlay sigue visible.
          if (mounted) setState(() => _processingTag = true);

          final allServerStatuses = allStatuses.where((s) =>
              (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase() ==
              'tag-transfer-adb-server');
          for (final s in allServerStatuses) {
            final id = getJsonField(s, r'''$.id_activity_status''') as int?;
            if (id == null) continue;
            unawaited(_autoSaveVisitFromAdbTag(id, tagContent));
          }
        }
      });
      AdbNfcBridgeService.instance.start().then((_) {
        if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
      });
    }

    if (hasFromField && Platforms.isMobile) {
      _adbClientConnSub = AdbNfcClientService.instance.onConnectionChanged.listen((connected) {
        if (mounted) setState(() => _adbClientConnected = connected);
      });
      AdbNfcClientService.instance.connect().then((connected) {
        if (mounted) setState(() => _adbClientConnected = connected);
      });
      // Responder solicitudes de geolocalización del servidor Windows
      _adbServerCommandSub = AdbNfcClientService.instance.onServerCommand.listen((cmd) {
        if (cmd['type'] == 'request_geo_location') {
          final geoList = FFAppState().geoLocationsList;
          if (geoList.isEmpty) return;
          final latest = geoList.reduce((a, b) =>
              (a.dateHourRead?.isAfter(b.dateHourRead ?? DateTime(0)) ?? false) ? a : b);
          AdbNfcClientService.instance.sendGeoLocation(
            latitude: latest.latitude,
            longitude: latest.longitude,
            altitude: latest.altitude,
            errorHorizontal: latest.errorHorizontal,
          );
        }
      });
    }
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

    // Cachear y ordenar activity status (solo los de la actividad actual)
    if (activityStatusRawData != null) {
      final currentActivityId = getJsonField(FFAppState().currentActivity, r'''$.id_activity''');
      _cachedActivityStatus = List.from(activityStatusRawData.toList());
      if (currentActivityId != null) {
        _cachedActivityStatus = _cachedActivityStatus.where((s) {
          final sActivityId = getJsonField(s, r'''$.id_activity''');
          return sActivityId == currentActivityId;
        }).toList();
      }
      _cachedActivityStatus.sort((a, b) {
        final orderA = getJsonField(a, r'''$.order_status''') ?? 999;
        final orderB = getJsonField(b, r'''$.order_status''') ?? 999;
        return orderA.compareTo(orderB);
      });
    }

    // Cargar hijos de reference-list (type_status) desde activitiesJSON
    // Los hijos viven en otra actividad referenciada por el campo default_status del status
    _referenceListChilds.clear();
    final activitiesJson = FFAppState().activitiesJSON;
    if (activitiesJson is List) {
      // Indexar actividades por id para búsqueda rápida
      final Map<int, dynamic> activityById = {};
      for (var act in activitiesJson) {
        final actId = getJsonField(act, r'''$.id_activity''');
        if (actId is int) activityById[actId] = act;
      }

      for (var step in _cachedActivitySteps) {
        final statusesRaw = getJsonField(step, r'''$.activities_status''');
        if (statusesRaw is! List) continue;
        for (var status in statusesRaw) {
          final typeStatus = getJsonField(status, r'''$.type_status''')?.toString() ?? '';
          if (typeStatus != 'reference-list') continue;
          final statusId = getJsonField(status, r'''$.id_activity_status''');
          if (statusId == null) continue;
          final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
          final refActivityId = int.tryParse(defaultStatus);
          if (refActivityId == null) continue;
          final refActivity = activityById[refActivityId];
          if (refActivity == null) {
            debugPrint('⚠️ reference-list status $statusId: actividad referenciada $refActivityId no encontrada');
            continue;
          }
          // Obtener statuses raíz de la actividad referenciada
          final refStatuses = getJsonField(refActivity, r'''$.activity_status''');
          if (refStatuses is List && refStatuses.isNotEmpty) {
            _referenceListChilds[statusId as int] = refStatuses;
            debugPrint('✅ reference-list status $statusId: ${refStatuses.length} hijos desde actividad $refActivityId');
          } else {
            debugPrint('⚠️ reference-list status $statusId: actividad $refActivityId sin statuses raíz');
          }
        }
      }
    }

    _isDataCacheInitialized = true;

    // Inicializar TabController si todos los steps raíz son tab-container
    final allTabContainer = _cachedActivitySteps.isNotEmpty &&
        _cachedActivitySteps.every((s) =>
            getJsonField(s, r'''$.type_step''').toString() == 'tab-container');
    if (allTabContainer) {
      _tabController?.dispose();
      _tabController = TabController(
        length: _cachedActivitySteps.length,
        vsync: this,
      )..addListener(() {
        if (mounted) setState(() {});
      });

      // Auto-expandir reference-list dentro de tab-container (siempre visibles)
      for (var step in _cachedActivitySteps) {
        final stepId = getJsonField(step, r'''$.id_activity_step''');
        final statusesRaw = getJsonField(step, r'''$.activities_status''');
        if (statusesRaw is! List) continue;
        for (var status in statusesRaw) {
          final typeStatus = getJsonField(status, r'''$.type_status''').toString();
          final statusId = getJsonField(status, r'''$.id_activity_status''');
          final childsRaw = getJsonField(status, r'''$.activities_status_childs''');
          final hasRefChilds = typeStatus == 'reference-list' &&
              ((statusId is int && _referenceListChilds.containsKey(statusId)) ||
               (childsRaw is List && childsRaw.isNotEmpty));
          if (hasRefChilds) {
            _statusExpansionState['${stepId}_$statusId'] = true;
          }
        }
      }
    }
  }

  /// Migra datos antiguos con HTML en status_response a checkmark simple
  /// Se ejecuta una vez en initState para limpiar datos legacy de SQLite
  void _migrateHtmlToCheckmark() {
    debugPrint('🔄 Migrando HTML antiguo a checkmark...');

    bool hasChanges = false;

    // Recorrer todos los registros de visitDetails
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      final detail = FFAppState().visitDetails[i];

      // Si el statusResponse contiene HTML (empieza con "<div" o "<")
      if (detail.statusResponse.trim().startsWith('<')) {
        debugPrint('   🔧 Migrando registro $i: "${detail.statusResponse.substring(0, 20)}..." → "✓"');

        // Actualizar el registro reemplazando HTML por checkmark
        FFAppState().updateVisitDetailsAtIndex(
          i,
          (d) => VisitsDetailsStruct(
            idVisitDetail: d.idVisitDetail,
            idVisit: d.idVisit,
            idActivityStatus: d.idActivityStatus,
            statusOption: d.statusOption,
            statusResponse: '✓', // Reemplazar HTML por checkmark
            idStepParent: d.idStepParent,
            rememberStatus: d.rememberStatus,
            defaultStatus: d.defaultStatus,
            typeStatus: d.typeStatus,
            auxStep: d.auxStep,
          ),
        );

        hasChanges = true;
      }
    }

    if (hasChanges) {
      debugPrint('✅ Migración completada. Se actualizaron registros con HTML.');
      // Actualizar FFAppState para persistir los cambios
      FFAppState().update(() {});
    } else {
      debugPrint('ℹ️ No se encontraron registros con HTML para migrar.');
    }
  }

  /// Verifica si la actividad actual tiene algún status de tipo 'headquarters-weights'
  bool _hasHeadquartersWeightsStatus() {
    // Buscar en activity_status raíz
    for (var status in _cachedActivityStatus) {
      final typeStatus = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase() ?? '';
      if (typeStatus == 'headquarters-weights') {
        return true;
      }
    }

    // Buscar en activity_steps -> activity_status
    for (var step in _cachedActivitySteps) {
      final statusList = getJsonField(step, r'''$.activity_status''')?.toList() ?? [];
      for (var status in statusList) {
        final typeStatus = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase() ?? '';
        if (typeStatus == 'headquarters-weights') {
          return true;
        }
      }
    }

    return false;
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
    _model.dispose();
    // Disponer controllers de búsqueda
    _searchControllers.forEach((_, controller) => controller.dispose());
    _tabController?.dispose();
    // Limpiar ADB bridge
    _adbStatusSub?.cancel();
    _adbTagSub?.cancel();
    _adbClientConnSub?.cancel();
    _adbServerCommandSub?.cancel();
    if (Platforms.isDesktop) {
      AdbNfcBridgeService.instance.stop();
    } else {
      AdbNfcClientService.instance.disconnect();
    }
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

  /// Persiste el raw nfcContent del tag de origen en SharedPreferences.
  /// Clave: tt_<cacheKey>_<statusId>
  Future<void> _persistTagTransferToPrefs(int statusId, String nfcContent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tt_${_getCacheKey()}_$statusId', nfcContent);
      debugPrint('💾 [TAG-TRANSFER] Persistido en SharedPreferences: statusId=$statusId');
    } catch (e) {
      debugPrint('⚠️ [TAG-TRANSFER] Error persistiendo en SharedPreferences: $e');
    }
  }

  /// Restaura tag transfer data desde SharedPreferences para statusIds que
  /// no estén ya en _tagTransferData (fallback al iniciar una nueva sesión).
  Future<void> _restoreTagTransferFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'tt_${_getCacheKey()}_';
      final matchingKeys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      if (matchingKeys.isEmpty) return;

      int restored = 0;
      for (final key in matchingKeys) {
        final statusIdStr = key.substring(prefix.length);
        final statusId = int.tryParse(statusIdStr);
        if (statusId == null) continue;
        if (_tagTransferData.containsKey(statusId)) continue;

        final nfcContent = prefs.getString(key) ?? '';
        if (nfcContent.isEmpty) continue;

        final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
        if (parsedData.isNotEmpty) {
          setState(() { _tagTransferData[statusId] = parsedData; });
          restored++;
          debugPrint('♻️ [TAG-TRANSFER] Restaurado desde SharedPreferences: statusId=$statusId');
        }
      }
      if (restored > 0) {
        debugPrint('✅ [TAG-TRANSFER] $restored tag(s) restaurados desde SharedPreferences');
      }
    } catch (e) {
      debugPrint('⚠️ [TAG-TRANSFER] Error restaurando desde SharedPreferences: $e');
    }
  }

  /// Limpia el nfcContent persistido de un tag transfer en SharedPreferences.
  Future<void> _clearTagTransferFromPrefs(int statusId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tt_${_getCacheKey()}_$statusId');
      debugPrint('🗑️ [TAG-TRANSFER] Eliminado de SharedPreferences: statusId=$statusId');
    } catch (e) {
      debugPrint('⚠️ [TAG-TRANSFER] Error limpiando SharedPreferences: $e');
    }
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
        'tagReaderProductName': _tagReaderProductName,
        'tagWriterProductName': _tagWriterProductName,
        'tagTransferSourceProductName': _tagTransferSourceProductName,
        'tagTransferDestProductName': _tagTransferDestProductName,
        'tagTransferData': _tagTransferData,
        'tagTransferCompleted': _tagTransferCompleted,
        'tagWriterData': _tagWriterData,
        'calculatedDistances': _calculatedDistances,
        'distanceExtractorCalculated': _distanceExtractorCalculated,
        'headquarterWeights': _headquarterWeights,
        'adbServerCardsRawJson': _adbServerCardsRawJson
            .map((k, v) => MapEntry(k.toString(), v)),
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

      if (cacheData['tagReaderProductName'] != null) {
        _tagReaderProductName.clear();
        _tagReaderProductName.addAll(Map<int, String>.from(cacheData['tagReaderProductName'] as Map));
      }

      if (cacheData['tagWriterProductName'] != null) {
        _tagWriterProductName.clear();
        _tagWriterProductName.addAll(Map<int, String>.from(cacheData['tagWriterProductName'] as Map));
      }

      if (cacheData['tagTransferSourceProductName'] != null) {
        _tagTransferSourceProductName.clear();
        _tagTransferSourceProductName.addAll(Map<int, String>.from(cacheData['tagTransferSourceProductName'] as Map));
      }

      if (cacheData['tagTransferDestProductName'] != null) {
        _tagTransferDestProductName.clear();
        _tagTransferDestProductName.addAll(Map<int, String>.from(cacheData['tagTransferDestProductName'] as Map));
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

      // Restaurar ADB server cards raw JSON
      if (cacheData['adbServerCardsRawJson'] != null) {
        _adbServerCardsRawJson.clear();
        final rawMap = cacheData['adbServerCardsRawJson'] as Map;
        rawMap.forEach((k, v) {
          final id = int.tryParse(k.toString());
          if (id != null && v is List) {
            _adbServerCardsRawJson[id] = List<String>.from(v);
          }
        });
        debugPrint('   ✓ Restaurados ${_adbServerCardsRawJson.length} ADB card entries');
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
      } else if (typeStatus.toLowerCase() == 'number' &&
          defaultStatus.contains('=RANDOM:')) {
        final regexRandom = RegExp(r'=RANDOM:MIN=(\d+)_MAX=(\d+)');
        final matchRandom = regexRandom.firstMatch(defaultStatus);
        if (matchRandom != null) {
          final existingValue =
              functions.statusResponseByActivityStatusAlternative(
            statusId,
            FFAppState().visitDetails.toList(),
            parentStepId,
          );
          if (existingValue.isEmpty) {
            final minVal = int.parse(matchRandom.group(1)!);
            final maxVal = int.parse(matchRandom.group(2)!);
            final randomValue =
                minVal + math.Random().nextInt(maxVal - minVal + 1);
            debugPrint(
                '🎲 Inicializando NUMBER con =RANDOM: min=$minVal max=$maxVal → $randomValue');
            FFAppState().addToVisitDetails(
              VisitsDetailsStruct(
                idVisitDetail: 0,
                idVisit: 0,
                idActivityStatus: statusId,
                statusOption: statusName,
                statusResponse: randomValue.toString(),
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
            debugPrint(
                '🎲 NUMBER =RANDOM ya tiene valor, saltando: $statusName');
          }
        }
      }

      // Buscar recursivamente en steps_childs
      final stepsChilds =
          getJsonField(status, r'''$.steps_childs''')?.toList() ?? [];
      for (var childStep in stepsChilds) {
        final childStepId = getJsonField(childStep, r'''$.id_activity_step''');
        final childStatusList =
            getJsonField(childStep, r'''$.activities_status''')?.toList() ?? [];
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
          getJsonField(step, r'''$.activities_status''')?.toList() ?? [];
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

  /// Verifica si existe algún status de tipo tag-writer, tag-reader o tag-transfer
  /// en la actividad actual (busca recursivamente en todos los niveles)
  bool _hasTagTypeStatus() {
    final activityStepsRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );
    if (activityStepsRaw == null) return false;
    final activitySteps = activityStepsRaw.toList();

    // También revisar activity_status raíz
    final activityStatusRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_status''',
    );
    final activityStatus = activityStatusRaw?.toList() ?? [];

    // Declarar las funciones como late para permitir referencias mutuas
    late bool Function(List<dynamic>) checkStatusList;
    late bool Function(List<dynamic>) checkStepsList;

    checkStatusList = (List<dynamic> statusList) {
      for (var status in statusList) {
        final typeStatus = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase() ?? '';
        if (typeStatus == 'tag-writer' || typeStatus == 'tag-reader' || typeStatus == 'tag-transfer') {
          return true;
        }
        // Revisar status hijos
        final statusChilds = getJsonField(status, r'''$.activities_status_childs''')?.toList() ?? [];
        if (checkStatusList(statusChilds)) return true;

        // Revisar steps hijos de este status
        final stepsChilds = getJsonField(status, r'''$.activities_steps_childs''')?.toList() ?? [];
        if (checkStepsList(stepsChilds)) return true;
      }
      return false;
    };

    checkStepsList = (List<dynamic> stepsList) {
      for (var step in stepsList) {
        final activitiesStatusRaw = getJsonField(step, r'''$.activities_status''');
        final activitiesStatus = activitiesStatusRaw != null
            ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
            : [];
        if (checkStatusList(activitiesStatus)) return true;
      }
      return false;
    };

    // Revisar status raíz
    if (checkStatusList(activityStatus)) return true;

    // Revisar steps
    if (checkStepsList(activitySteps)) return true;

    return false;
  }

  /// Valida recursivamente todos los steps requeridos en la jerarquía
  /// Retorna un mapa con los steps faltantes y su ruta para expansión
  Map<String, dynamic>? _validateRequiredStepsRecursive() {
    // Si existe algún status de tipo tag-writer, tag-reader o tag-transfer,
    // omitir la validación de is_required
    if (_hasTagTypeStatus()) {
      return null;
    }

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
                      ?.toList() ?? [];

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
    // Requerido por AutomaticKeepAliveClientMixin
    super.build(context);

    // LOTE 1: Usar Selector para escuchar solo cambios en visitDetails
    // en lugar de context.watch<FFAppState>() que escucha TODOS los cambios
    // ignore: unused_local_variable
    final _ = context.select<FFAppState, int>(
      (state) => state.visitDetails.length,
    );

    // Invalidar caché de búsquedas si cambió visitDetails
    _invalidateSearchCacheIfNeeded();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF003420), Color(0xFF002415), Color(0xFF00150A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Column(
              children: [
                // Header de la página (título + botón atrás)
                _buildPageHeader(),

                // Contenido del formulario (bloqueado hasta el primer tag ADB)
                Expanded(
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: _formLocked,
                        child: _buildFormContent(),
                      ),
                      if (_formLocked)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.55),
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: _processingTag
                                    ? const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFFB45309)),
                                            ),
                                          ),
                                          SizedBox(height: 20),
                                          Text(
                                            'Leyendo tag...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Procesando la información, espere un momento...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontFamily: 'Roboto',
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.nfc_rounded,
                                              color: Color(0xFFB45309),
                                              size: 64),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Lea un tag para empezar',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'El formulario se desbloqueará cuando se reciba la lectura del tag ADB.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontFamily: 'Roboto',
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          _buildOverlaySolicitarButton(),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Botones de navegación
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón SOLICITAR que se muestra dentro del overlay de bloqueo cuando el
  /// formulario está esperando el primer tag ADB. Replica el comportamiento
  /// del botón homónimo del panel ADB ([widget:9501]) — solo está activo si
  /// hay un cliente Android conectado y dispara `sendRequestRead()`.
  Widget _buildOverlaySolicitarButton() {
    final isConnected = _adbServerStatus == AdbBridgeStatus.clientConnected;
    return GestureDetector(
      onTap: isConnected
          ? () {
              final sent = AdbNfcBridgeService.instance.sendRequestRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sent
                        ? '📲 Solicitud enviada al Android'
                        : '⚠️ No hay dispositivo Android conectado'),
                    backgroundColor: sent
                        ? const Color(0xFFB45309)
                        : const Color(0xFFE53935),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isConnected
              ? const Color(0xFF1565C0)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isConnected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                    blurRadius: 10,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nfc_rounded,
              color: isConnected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'SOLICITAR',
              style: TextStyle(
                color: isConnected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header de la página standalone (equivalente al _buildModernHeader de VisitsWithMapPage)
  Widget _buildPageHeader() {
    final activityName = FFAppState().activitySelected.nameActivity.isNotEmpty
        ? FFAppState().activitySelected.nameActivity
        : 'Formulario Extractora';

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFB45309).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Botón atrás
            GestureDetector(
              onTap: () => context.pushNamed(
                DoActivitiesPageWidget.routeName,
                extra: <String, dynamic>{
                  kTransitionInfoKey: const TransitionInfo(
                    hasTransition: true,
                    transitionType: PageTransitionType.fade,
                    duration: Duration(milliseconds: 400),
                  ),
                },
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB45309), Color(0xFF451A03)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFB45309).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Título de la actividad
            Expanded(
              child: Text(
                activityName,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // Toggle de voz: activa/desactiva announceVisitVoice() al guardar
            // un tag. OFF por defecto.
            GestureDetector(
              onTap: () {
                setState(() => _voiceEnabled = !_voiceEnabled);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_voiceEnabled
                          ? '🔊 Voz activada'
                          : '🔇 Voz desactivada'),
                      backgroundColor: _voiceEnabled
                          ? const Color(0xFF00a86b)
                          : const Color(0xFF616161),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _voiceEnabled
                        ? const [Color(0xFF00a86b), Color(0xFF007552)]
                        : const [Color(0xFF424242), Color(0xFF212121)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_voiceEnabled
                            ? const Color(0xFF00a86b)
                            : Colors.white)
                        .withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _voiceEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
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

    // Si todos los steps raíz son tab-container → renderizar como Tabs
    final allTabContainer = activitySteps.isNotEmpty &&
        activitySteps.every((s) =>
            getJsonField(s, r'''$.type_step''').toString() == 'tab-container');

    final Widget formBody = allTabContainer
        ? _buildSimultaneousPanelLayout(activitySteps, activityStatus)
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: activitySteps.length + activityStatus.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index < activitySteps.length) {
                return _buildStepCard(activitySteps[index], level: 0);
              } else {
                final statusIndex = index - activitySteps.length;
                return _buildRootStatusCard(
                  activityStatus[statusIndex],
                  allActivityStatus: activityStatus,
                  level: 0,
                );
              }
            },
          );

    // Si hay campo adb-server en Windows → panel vertical izquierdo + formulario a la derecha
    if (_hasAdbServerField && Platforms.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAdbSidePanel(),
          Expanded(child: formBody),
        ],
      );
    }

    return formBody;
  }

  // ============================================================
  // LAYOUT SIMULTÁNEO DE PANELES (reemplaza TabBarView)
  // ============================================================

  /// Renderiza todos los steps tab-container en paralelo: panel izquierdo (primer step)
  /// y panel derecho (steps restantes fusionados en grid 2 columnas).
  Widget _buildSimultaneousPanelLayout(
      List<dynamic> activitySteps, List<dynamic> activityStatus) {
    if (activitySteps.isEmpty) return const SizedBox.shrink();

    final firstStep = activitySteps.first;
    final remainingSteps = activitySteps.skip(1).toList();

    // El primer step ensancha el panel izquierdo cuando contiene un
    // tag-transfer-adb-server, para acomodar el layout en dos columnas
    // (controles a la izquierda, info + tabla del ADB a la derecha).
    final firstStepStatuses = getJsonField(firstStep, r'''$.activities_status''');
    final firstStepHasAdb = firstStepStatuses is List &&
        firstStepStatuses.any((s) =>
            (getJsonField(s, r'''$.type_status''')?.toString() ?? '')
                .toLowerCase() ==
            'tag-transfer-adb-server');

    if (firstStepHasAdb) {
      // Cuando el primer step contiene un tag-transfer-adb-server,
      // DATOS PRINCIPALES ocupa la fila 1 a todo ancho (con dos columnas
      // internas) y los demás steps fusionados ocupan la fila 2 abajo.
      // Como la altura ya no está limitada por un Row con stretch, los
      // hijos se renderizan con altura intrínseca y el scroll lo lleva
      // un SingleChildScrollView envolvente.
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPanelForStep(firstStep, unboundedHeight: true),
            const SizedBox(height: 10),
            _buildMergedPanel(remainingSteps, unboundedHeight: true),
          ],
        ),
      );
    }

    // Layout clásico: dos paneles lado a lado (izq 340px, der expanded).
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: _buildPanelForStep(firstStep),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildMergedPanel(remainingSteps)),
        ],
      ),
    );
  }

  /// Panel izquierdo: statuses normales en grid 2 columnas; tag-transfer-adb-server en full-width.
  /// Cuando [unboundedHeight] es true, el panel renderiza su contenido con altura
  /// intrínseca (sin `Expanded` ni `SingleChildScrollView` interno), apropiado
  /// para apilarse dentro de otro scroll vertical.
  Widget _buildPanelForStep(dynamic step, {bool unboundedHeight = false}) {
    final stepName = getJsonField(step, r'''$.unity''')?.toString() ??
        getJsonField(step, r'''$.name_step''')?.toString() ?? '';
    final statusesRaw = getJsonField(step, r'''$.activities_status''');
    final List<dynamic> statuses = statusesRaw is List ? statusesRaw : [];

    // Separar por tipo: date primero, time segundo, adb full-width, el resto en grid
    final dateStatuses = statuses.where((s) =>
        (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase() == 'date').toList();
    final timeStatuses = statuses.where((s) =>
        (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase() == 'time').toList();
    final adbStatuses = statuses.where((s) =>
        (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase() ==
        'tag-transfer-adb-server').toList();
    final randomNumStatuses = statuses.where(_isRandomNumberStatus).toList();
    final normalStatuses = statuses.where((s) {
      final t = (getJsonField(s, r'''$.type_status''')?.toString() ?? '').toLowerCase();
      if (t == 'date' || t == 'time' || t == 'tag-transfer-adb-server') return false;
      if (_isRandomNumberStatus(s)) return false;
      return true;
    }).toList();

    final Widget contentBody = LayoutBuilder(builder: (context, constraints) {
      // Cuando el panel tiene un status ADB, el layout pasa a DOS FILAS:
      //   Fila 1: controles (date / time / random / normales) en una sola
      //           Row horizontal de igual ancho.
      //   Fila 2: card ADB en modo tabla, a todo el ancho del panel.
      // Esto le da al control de tabla todo el ancho útil que necesita.
      final hasAdb = adbStatuses.isNotEmpty;

      Widget adbStack({required AdbCardDisplayMode mode}) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final adbStatus in adbStatuses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildStatusOption(
                  step,
                  adbStatus,
                  level: 0,
                  adbDisplayModeOverride: mode,
                ),
              ),
          ],
        );
      }

      if (hasAdb) {
        // Concatenar todos los controles que no son ADB, preservando el orden
        // original (date → time → random → normales).
        final topControls = <dynamic>[
          ...dateStatuses,
          ...timeStatuses,
          ...randomNumStatuses,
          ...normalStatuses,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topControls.isNotEmpty)
              // Sin IntrinsicHeight: el control number tiene un Stack interno
              // que no soporta intrinsic dimensions y causa el error
              // "RenderBox was not laid out: hasSize". Las celdas toman
              // altura natural y se alinean al tope.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < topControls.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatusOption(step, topControls[i],
                          level: 0),
                    ),
                  ],
                ],
              ),
            if (topControls.isNotEmpty) const SizedBox(height: 10),
            adbStack(mode: AdbCardDisplayMode.table),
          ],
        );
      }

      // Sin ADB → layout legacy: date / time / random a full width, normales
      // en grid de 2 columnas.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in dateStatuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStatusOption(step, s, level: 0),
            ),
          for (final s in timeStatuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStatusOption(step, s, level: 0),
            ),
          for (final s in randomNumStatuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStatusOption(step, s, level: 0),
            ),
          if (normalStatuses.isNotEmpty)
            Column(
              children: List.generate(
                (normalStatuses.length / 2).ceil(),
                (rowIndex) {
                  final leftIndex = rowIndex * 2;
                  final rightIndex = leftIndex + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildStatusOption(
                                step, normalStatuses[leftIndex],
                                level: 0),
                          ),
                          const SizedBox(width: 10),
                          if (rightIndex < normalStatuses.length)
                            Expanded(
                              child: _buildStatusOption(
                                  step, normalStatuses[rightIndex],
                                  level: 0),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D5A2D).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del panel
          if (stepName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                stepName.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          // Contenido — flujo natural si se apila dentro de otro scroll,
          // o scroll interno cuando el panel tiene altura acotada.
          if (unboundedHeight)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: contentBody,
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: contentBody,
              ),
            ),
        ],
      ),
    );
  }

  /// Busca el step al que pertenece un status dado (por id_activity_step_parent).
  dynamic _findStepForStatus(List<dynamic> steps, dynamic status) {
    final parentId = getJsonField(status, r'''$.id_activity_step_parent''');
    if (parentId == null) return steps.isNotEmpty ? steps.first : null;
    for (final step in steps) {
      final stepId = getJsonField(step, r'''$.id_activity_step''');
      if (stepId == parentId) return step;
    }
    return steps.isNotEmpty ? steps.first : null;
  }

  /// Panel derecho: fusiona statuses de todos los steps restantes en grid de 2 columnas.
  /// Cuando [unboundedHeight] es true, el panel renderiza su contenido con altura
  /// intrínseca (sin `Expanded` ni `SingleChildScrollView` interno), apropiado
  /// para apilarse dentro de otro scroll vertical.
  Widget _buildMergedPanel(List<dynamic> steps,
      {bool unboundedHeight = false}) {
    if (steps.isEmpty) return const SizedBox.shrink();

    // Recopilar todos los statuses y ordenar por order_status
    final List<dynamic> allStatuses = [];
    for (final step in steps) {
      final raw = getJsonField(step, r'''$.activities_status''');
      if (raw is List) allStatuses.addAll(raw);
    }

    if (allStatuses.isEmpty) return const SizedBox.shrink();

    allStatuses.sort((a, b) {
      final orderA = getJsonField(a, r'''$.order_status''');
      final orderB = getJsonField(b, r'''$.order_status''');
      final numA = orderA is num ? orderA.toInt() : int.tryParse(orderA?.toString() ?? '') ?? 0;
      final numB = orderB is num ? orderB.toInt() : int.tryParse(orderB?.toString() ?? '') ?? 0;
      return numA.compareTo(numB);
    });

    final randomNumStatuses = allStatuses.where(_isRandomNumberStatus).toList();
    final gridStatuses = allStatuses.where((s) => !_isRandomNumberStatus(s)).toList();

    // Nombre del panel = nombres de los steps fusionados
    final panelName = steps.map((s) =>
        getJsonField(s, r'''$.unity''')?.toString() ??
        getJsonField(s, r'''$.name_step''')?.toString() ?? '').join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D5A2D).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (panelName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                panelName.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          // Contenido — scroll interno cuando hay altura acotada, flujo
          // natural cuando se apila dentro de otro scroll.
          if (unboundedHeight)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _mergedPanelBody(
                  steps, randomNumStatuses, gridStatuses),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: _mergedPanelBody(
                    steps, randomNumStatuses, gridStatuses),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mergedPanelBody(List<dynamic> steps,
      List<dynamic> randomNumStatuses, List<dynamic> gridStatuses) {
    return Column(
      children: [
        // RANDOM number — fila individual (full-width)
        for (final s in randomNumStatuses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildStatusOption(
                _findStepForStatus(steps, s), s, level: 0),
          ),
        // Resto en grid 2 columnas
        ...List.generate(
          (gridStatuses.length / 2).ceil(),
          (rowIndex) {
            final leftIndex = rowIndex * 2;
            final rightIndex = leftIndex + 1;
            final leftStep =
                _findStepForStatus(steps, gridStatuses[leftIndex]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildStatusOption(
                        leftStep, gridStatuses[leftIndex], level: 0),
                  ),
                  const SizedBox(width: 10),
                  if (rightIndex < gridStatuses.length)
                    Expanded(
                      child: _buildStatusOption(
                          _findStepForStatus(
                              steps, gridStatuses[rightIndex]),
                          gridStatuses[rightIndex],
                          level: 0),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepCard(dynamic step, {required int level}) {
    final stepId = getJsonField(step, r'''$.id_activity_step''');
    final stepName = getJsonField(step, r'''$.name_step''').toString();
    final typeStep = getJsonField(step, r'''$.type_step''').toString();
    final isRequired = getJsonField(step, r'''$.is_required''') == true;
    final activitiesStatusRaw = getJsonField(step, r'''$.activities_status''');
    List activitiesStatus = activitiesStatusRaw != null
        ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
        : [];

    // reference-list es ahora un type_status, no type_step
    // Sus activities_status se cargan desde el JSON embebido

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
              // Reemplazado gradiente por color sólido para mejor rendimiento
              color: hasValue
                  ? const Color(0xFFB45309)
                  : const Color(0xFF0D2B1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? const Color(0xFFB45309)
                    : const Color(0xFF1A4A2E),
                width: 2,
              ),
              // BoxShadow removido para mejor rendimiento en scroll
            ),
            child: Row(
              children: [
                // Indicador de nivel
                if (level > 0)
                  Container(
                    width: 3,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309),
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
                        hasValue ? Colors.white : const Color(0xFFB45309),
                    size: 36,
                  ),
                const SizedBox(width: 8),
                // Nombre del step
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stepName,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: hasValue
                                    ? Colors.white
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                          // Indicador sutil cuando está completado y es requerido
                          if (isRequired && hasValue)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Req.',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
                      color: totalCompleted == totalRequired
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCompleted/$totalRequired',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Badge de requerido (solo mostrar cuando NO tiene valor)
                if (isRequired && !hasValue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFEE5A6F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Requerido',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Botón de búsqueda compacto (para unique-list)
                // Solo visible cuando el step está expandido
                // NOTA: container-list NO tiene búsqueda, solo renderiza sus hijos
                // NOTA: reference-list es ahora type_status, no type_step
                if (typeStep == 'unique-list' &&
                    activitiesStatus.isNotEmpty &&
                    isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCompactSearchButton(stepId, hasValue: hasValue),
                  ),
              ],
            ),
          ),
        ),

        // Cuadro de búsqueda expandido (solo cuando está activo)
        // NOTA: container-list NO tiene búsqueda
        // NOTA: reference-list es ahora type_status, no type_step
        if (typeStep == 'unique-list' &&
            (_searchBoxExpansionState[stepId] ?? false))
          _buildExpandedSearchBox(stepId),

        // Lista de opciones (cuando está expandido)
        if (isExpanded && activitiesStatus.isNotEmpty)
          Builder(
            builder: (context) {
              debugPrint('   ✅ MOSTRANDO OPCIONES: paso la condición isExpanded=$isExpanded && activitiesStatus.isNotEmpty=${activitiesStatus.isNotEmpty}');

              // Para container-list, mostrar todos los status sin filtro
              // Para unique-list, aplicar filtro de búsqueda
              // reference-list es ahora type_status, no type_step
              final displayList = typeStep == 'container-list'
                  ? activitiesStatus
                  : _filterStatusList(stepId, activitiesStatus);

              debugPrint('   📋 Lista a mostrar: ${displayList.length} opciones de ${activitiesStatus.length} (tipo: $typeStep)');

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(left: level * 8.0 + 8, top: 8),
                child: Column(
                  children: [
                    // Lista de status (filtrada o completa según el tipo)
                    ...displayList.map<Widget>((status) {
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
      {required int level,
      int? parentMultipleOptionId,
      AdbCardDisplayMode? adbDisplayModeOverride}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();

    // Log de renderizado (comentado para evitar spam en consola)
    // debugPrint('  🔹 RENDERIZANDO STATUS: nombre="$statusName" tipo="$typeStatus" ID=$statusId nivel=$level');
    final stepsChildsRaw =
        getJsonField(status, r'''$.activities_steps_childs''');
    final stepsChilds = stepsChildsRaw != null
        ? (stepsChildsRaw is List ? stepsChildsRaw : [])
        : [];
    final statusChildsRaw =
        getJsonField(status, r'''$.activities_status_childs''');
    // Para reference-list (type_status), los hijos viven en otra actividad cargada via default_status
    // Se usa _referenceListChilds[statusId] si está disponible, si no, fallback a la lista embebida
    final refListChildsFromCache = (typeStatus.toLowerCase() == 'reference-list' && statusId is int)
        ? (_referenceListChilds[statusId] ?? [])
        : <dynamic>[];
    final statusChilds = refListChildsFromCache.isNotEmpty
        ? refListChildsFromCache
        : (statusChildsRaw != null
            ? (statusChildsRaw is List ? statusChildsRaw : [])
            : []);
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');

    // LOTE 1: Usar búsqueda cacheada
    final isSelected = _cachedSearchInVisitDetails(statusId, 'STATUS');

    final expansionKey = '${parentStepId}_$statusId';
    final typeStatusLower = typeStatus.toLowerCase();
    // distance-extractor: siempre expandido (el árbol interno siempre visible)
    final isExpanded = typeStatusLower == 'distance-extractor'
        ? true
        : (_statusExpansionState[expansionKey] ?? false);

    // Verificar si tiene algún tipo de hijos
    final hasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;

    // Para status de tipo "number", "text", "tag-writer", "tag-reader", "tag-transfer", "numbers-operation", "headquarter-weight", "label-info", "distance-extractor", "dynamic-printing", "users-list" y "video", NO abrir diálogo, mostrar control inline
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isTextType = typeStatus.toLowerCase() == 'text';
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
    final isDynamicPrintingAdbType =
        typeStatus.toLowerCase() == 'dynamic-printing-adb';
    final isPhotoType = typeStatus.toLowerCase() == 'photo';
    final isVideoType = typeStatus.toLowerCase() == 'video';
    final isDateType = typeStatus.toLowerCase() == 'date';
    final isTimeType = typeStatus.toLowerCase() == 'time';
    final isUsersListType = typeStatus.toLowerCase() == 'users-list';
    final isReferenceListType = typeStatus.toLowerCase() == 'reference-list';
    final isTagTransferAdbServerType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-server';
    final isTagTransferAdbFromType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-from';

    // Para reference-list: determinar si algún hijo está seleccionado y cuál es su nombre
    // (el hijo seleccionado se almacena con auxStep == statusId del padre reference-list)
    final int statusIdInt = statusId is int ? statusId : (statusId as num).toInt();
    String? referenceListSelectedName;
    if (isReferenceListType) {
      for (final d in FFAppState().visitDetails) {
        if (d.auxStep == statusIdInt) {
          referenceListSelectedName = d.statusOption;
          break;
        }
      }
    }
    final bool hasSelectedRefChild = isReferenceListType && referenceListSelectedName != null;

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

            // Si es tipo reference-list, solo hacer toggle de expansión (los hijos son quienes se seleccionan)
            if (isReferenceListType) {
              setState(() {
                _statusExpansionState[expansionKey] = !(_statusExpansionState[expansionKey] ?? false);
              });
              return;
            }

            // Si es tipo number, solo mostrar el control inline
            // NO llamar a _onStatusSelected para evitar agregar registros duplicados al breadcrumb
            // El valor se guardará cuando el usuario cambie el número con los controles +/- o teclado
            if (isNumberType) {
              return;
            }

            // Si es tipo text, NO seleccionar automáticamente al hacer tap
            // Solo se seleccionará cuando tenga mínimo 10 caracteres escritos
            if (isTextType) {
              return;
            }

            // Si es tipo users-list, NO seleccionar automáticamente al hacer tap
            // El usuario interactúa con el control de búsqueda inline
            if (isUsersListType) {
              return;
            }

            // Tipos que no deben reaccionar al tap del contenedor principal
            // (date y time tienen sus propios handlers más abajo con return)
            // distance-extractor tiene su propio handler más abajo que sí calcula
            if (isTagTransferAdbServerType ||
                isDateType ||
                isTimeType ||
                isLabelInfoType) {
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
                    _tagWriterProductName[statusId] = FFAppState().nfcLastProductName;
                  });

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
                  int existingIndex = -1;
                  for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                    if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
                      existingIndex = i;
                      break;
                    }
                  }

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();

                  if (existingIndex >= 0) {
                    FFAppState().updateVisitDetailsAtIndex(
                      existingIndex,
                      (detail) => VisitsDetailsStruct(
                        idVisitDetail: detail.idVisitDetail,
                        idVisit: detail.idVisit,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-WRITER: Contenido guardado en status_response (en memoria)');
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
                  final productName = await _fetchProductNameFromRfid(nfcContent);

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();
                  final isNoRemove = defaultStatus.contains('=ACTIONS:NO_REMOVE');

                  setState(() {
                    if (isNoRemove) {
                      // Modo acumulativo: agregar al array de raw JSONs
                      if (!_tagReaderRawJsons.containsKey(statusId)) {
                        _tagReaderRawJsons[statusId] = [];
                      }
                      _tagReaderRawJsons[statusId]!.add(nfcContent);
                      // Aplanar todos los records acumulados para _tagReaderData
                      final allRecords = <Map<String, dynamic>>[];
                      for (final raw in _tagReaderRawJsons[statusId]!) {
                        allRecords.addAll(_parseNfcTagContent(raw));
                      }
                      _tagReaderData[statusId] = allRecords;
                    } else {
                      // Modo normal: reemplazar
                      _tagReaderRawJsons.remove(statusId);
                      _tagReaderData[statusId] = parsedData;
                    }
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                    _tagReaderProductName[statusId] = productName;
                  });

                  // Determinar el statusResponse a guardar
                  final statusResponseToSave = isNoRemove
                      ? jsonEncode(_tagReaderRawJsons[statusId])
                      : nfcContent;

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
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
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-READER: Contenido guardado en status_response (en memoria)${isNoRemove ? " [NO_REMOVE: ${_tagReaderRawJsons[statusId]!.length} tags acumulados]" : ""}');

                  // VALIDACIÓN DE PESO PROMEDIO: Solo validar si hay status de tipo 'headquarters-weights'
                  if (_hasHeadquartersWeightsStatus()) {
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

                      // Calcular peso total: resultados x weight por cada headquarter
                      _calculateHeadquarterWeightResults(statusId, statusName);
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);

                  // Calcular automáticamente los headquarter-weight que referencien este tag-reader
                  debugPrint('🎯 TAG-READER: Llamando a _autoCalculateRelatedHeadquarterWeights() con statusName="$statusName"');
                  await _autoCalculateRelatedHeadquarterWeights(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, leer SOLO el tag de origen
            if (isTagTransferType) {
              // Si ya se leyó el tag origen, bloquear tap — solo debe usarse TRANSFERIR AHORA
              if (_tagTransferData.containsKey(statusId) && _tagTransferData[statusId]!.isNotEmpty) {
                debugPrint('🚫 TAG-TRANSFER: Tag origen ya leído, tap bloqueado — usar TRANSFERIR AHORA');
                return;
              }

              // Si la transferencia ya está completada, NO procesar el tap
              if (_tagTransferCompleted[statusId] == true) {
                debugPrint('🚫 TAG-TRANSFER: Transferencia ya completada, tap ignorado');
                return;
              }

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
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: true,
                    ),
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
                final sourceProductName = await _fetchProductNameFromRfid(nfcContent);
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                  _tagTransferSourceProductName[statusId] = sourceProductName;
                });
                _persistTagTransferToPrefs(statusId, nfcContent).ignore();

                debugPrint(
                    '✅ TAG-TRANSFER: Tag de origen guardado y limpiado correctamente');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.cleaning_services, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tag de origen leído y limpiado correctamente',
                              style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Color(0xFFB45309),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }

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

            // tag-transfer-adb-server: tap deshabilitado (ya cortocircuitado
            // por el early return de arriba; bloque conservado en otros
            // builders sólo para los demás tipos que sí siguen activos).

            // tag-transfer-adb-from: tap conecta y lee NFC (solo móvil)
            if (isTagTransferAdbFromType) {
              if (Platforms.isMobile) {
                if (!AdbNfcClientService.instance.isConnected) {
                  final connected = await AdbNfcClientService.instance.connect();
                  if (!mounted) return;
                  setState(() => _adbClientConnected = connected);
                  if (!connected) return;
                }
                if (!mounted) return;
                bool tagSentSuccessfully = false;
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                      onTagReadCallback: (tagContent) async {
                        final sent = await AdbNfcClientService.instance
                            .sendTagData(tagContent: tagContent);
                        if (sent) tagSentSuccessfully = true;
                        return sent;
                      },
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (tagSentSuccessfully &&
                    nfcContent.isNotEmpty &&
                    !nfcContent.startsWith('ERROR')) {
                  // Mostrar resumen inline en el dispositivo Android también
                  setState(() {
                    _tagReaderData[statusId] = _parseNfcTagContent(nfcContent);
                    _tagReaderProductName[statusId] = '';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop y borrado'),
                    backgroundColor: Color(0xFFB45309),
                    duration: Duration(seconds: 3),
                  ));
                }
              }
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
                    _numbersOperationCalculated[statusId] = true;
                  });
                  debugPrint('🧮 Operación calculada: $formula = $result');
                }
              }
              // No llamar _onStatusSelected — no debe marcarse visualmente como seleccionado
              setState(() {});
              return;
            }

            // Si es tipo headquarter-weight, NO hacer nada en el tap del usuario.
            // El cálculo se dispara desde el tag-reader / webhook ADB
            // (_autoCalculateRelatedHeadquarterWeights), no desde aquí.
            if (isHeadquarterWeightType) {
              return;
            }

            // Si es tipo label-info, seleccionar automáticamente (solo muestra el nombre)
            if (isLabelInfoType) {
              await _onStatusSelected(parentStep, status);
              setState(() {});
              return;
            }

            // Si es tipo distance-extractor, calcular distancia automáticamente
            // No llamar _onStatusSelected — no debe marcarse visualmente como seleccionado
            if (isDistanceExtractorType) {
              await _calculateDistance(statusId, status, parentStep);
              setState(() {});
              return;
            }

            // Si es tipo dynamic-printing / dynamic-printing-adb, seleccionar automáticamente (se maneja con botón inline)
            if (isDynamicPrintingType || isDynamicPrintingAdbType) {
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

            // Si es tipo video, abrir el componente de captura de video
            if (typeStatus.toLowerCase() == 'video') {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: VideoCaptureComponentWidget(
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
              // Persistir incremento en SQLite con el valor recién seleccionado.
              if (_activeVisitId != null && statusId is int) {
                final detail = FFAppState()
                    .visitDetails
                    .where((d) => d.idActivityStatus == statusId)
                    .firstOrNull;
                if (detail != null) {
                  unawaited(actions.updateVisitDetailInSQLite(
                    _activeVisitId!,
                    statusId,
                    statusName,
                    detail.statusResponse,
                  ));
                }
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
              // Persistir incremento en SQLite con la hora recién seleccionada.
              if (_activeVisitId != null && statusId is int) {
                final detail = FFAppState()
                    .visitDetails
                    .where((d) => d.idActivityStatus == statusId)
                    .firstOrNull;
                if (detail != null) {
                  unawaited(actions.updateVisitDetailInSQLite(
                    _activeVisitId!,
                    statusId,
                    statusName,
                    detail.statusResponse,
                  ));
                }
              }
              setState(() {});
              return;
            }

            // NOTA: text ahora se maneja inline, ya no abre diálogo (ver línea ~1217)

            // TOGGLE para unique-option: Si ya está seleccionado, deseleccionar
            // Si no está seleccionado, seleccionar
            if (isSelected) {
              // Ya está seleccionado, DESELECCIONAR
              debugPrint('🔄 Status ya seleccionado, DESELECCIONANDO...');

              // Recopilar IDs de hijos para también eliminarlos
              final childStatusIds = statusChilds
                  .map((c) =>
                      getJsonField(c, r'''$.id_activity_status'''))
                  .toSet();

              // Eliminar de visitDetails (el status actual Y sus hijos)
              List<int> indicesToRemove = [];
              for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                final detail = FFAppState().visitDetails[i];
                if (detail.idStepParent == parentStepId &&
                    (detail.idActivityStatus == statusId ||
                        childStatusIds.contains(detail.idActivityStatus))) {
                  indicesToRemove.add(i);
                }
              }

              for (int i = indicesToRemove.length - 1; i >= 0; i--) {
                FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
              }

              // Limpiar registro de unique-option:
              // Si es un padre multiple-option, limpiar sus hijos del mapa
              _selectedUniqueOptionByParent.remove(statusId);
              // Si es un unique-option hijo, limpiar del registro del padre
              if (parentMultipleOptionId != null &&
                  typeStatus.toLowerCase() == 'unique-option') {
                _selectedUniqueOptionByParent.remove(parentMultipleOptionId);
              }
              _visitDetailsSearchCache.clear();

              debugPrint('✅ Status deseleccionado correctamente (incluyendo ${childStatusIds.length} hijos)');

              // Solo hacer setState si DESELECCIONAMOS
              // (cuando seleccionamos, _onStatusSelected ya hace setState)
              setState(() {
                if (hasChildren) {
                  // ✅ Si el status tiene hijos (activities_status_childs o activities_steps_childs):
                  // - ALTERNAR (toggle) el estado de expansión del status
                  final currentExpansion =
                      _statusExpansionState[expansionKey] ?? false;

                  // COLAPSAR todos los status hermanos (solo en non-tab-container)
                  // En tab-container cada status es independiente y no debe colapsar hermanos
                  final parentTypeStep = getJsonField(parentStep, r'''$.type_step''')?.toString() ?? '';
                  if (!currentExpansion && parentTypeStep.toLowerCase() != 'tab-container') {
                    final parentStepStatuses =
                        getJsonField(parentStep, r'''$.activities_status''')
                            .toList();
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
            } else {
              // No está seleccionado, SELECCIONAR
              debugPrint('✅ Seleccionando status...');

              // Si es un unique-option hijo de un multiple-option,
              // manejar exclusividad: deseleccionar hermano previamente seleccionado
              if (parentMultipleOptionId != null &&
                  typeStatus.toLowerCase() == 'unique-option') {
                debugPrint(
                    '🎯 UNIQUE-OPTION HIJO (step-level): statusId=$statusId, parentMultipleOptionId=$parentMultipleOptionId');
                final previouslySelectedId =
                    _selectedUniqueOptionByParent[parentMultipleOptionId];
                if (previouslySelectedId != null &&
                    previouslySelectedId != statusId) {
                  // Deseleccionar el unique-option anterior del mismo padre
                  List<int> siblingIndicesToRemove = [];
                  for (int i = 0;
                      i < FFAppState().visitDetails.length;
                      i++) {
                    if (FFAppState().visitDetails[i].idActivityStatus ==
                            previouslySelectedId &&
                        FFAppState().visitDetails[i].idStepParent ==
                            parentStepId) {
                      siblingIndicesToRemove.add(i);
                      debugPrint(
                          '   ❌ Deseleccionando hermano anterior: ID=$previouslySelectedId');
                    }
                  }
                  for (int i = siblingIndicesToRemove.length - 1;
                      i >= 0;
                      i--) {
                    FFAppState().removeAtIndexFromVisitDetails(
                        siblingIndicesToRemove[i]);
                  }
                  _visitDetailsSearchCache.clear();
                }
                // Registrar el nuevo unique-option seleccionado bajo este padre
                _selectedUniqueOptionByParent[parentMultipleOptionId] =
                    statusId;
                debugPrint(
                    '   ✅ Registrado nuevo unique-option: statusId=$statusId bajo padre=$parentMultipleOptionId');
              }

              // Auto-expandir si el status tiene hijos (ej: multiple-option con unique-option hijos)
              if (hasChildren) {
                _statusExpansionState[expansionKey] = true;
                // Auto-expandir los steps hijos requeridos para que sean visibles
                for (var childStep in stepsChilds) {
                  final childStepId = getJsonField(childStep, r'''$.id_activity_step''');
                  if (childStepId != null) {
                    _stepExpansionState[childStepId] =
                        getJsonField(childStep, r'''$.is_required''') == true;
                  }
                }
              }

              await _onStatusSelected(parentStep, status, parentMultipleOptionId: parentMultipleOptionId);

              // Auto-colapsar el reference-list padre al seleccionar un hijo
              if (parentMultipleOptionId != null) {
                setState(() {
                  _statusExpansionState['${parentStepId}_$parentMultipleOptionId'] = false;
                });
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: (isTagTransferAdbFromType && Platforms.isMobile)
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                : (isDateType || isTimeType)
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: ((isReferenceListType ? hasSelectedRefChild : isSelected) &&
                        !isNumberType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType &&
                        !isHeadquarterWeightType &&
                        !isNumbersOperationType &&
                        !isDateType &&
                        !isTimeType)
                    ? [
                        const Color(0xFFB45309),
                        const Color(0xFF92400E),
                      ]
                    : [
                        const Color(0xFF0D2B1A),
                        const Color(0xFF0A1F12),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ((isReferenceListType ? hasSelectedRefChild : isSelected) &&
                        !isNumberType &&
                        !isTextType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType &&
                        !isHeadquarterWeightType &&
                        !isNumbersOperationType &&
                        !isDateType &&
                        !isTimeType)
                    ? const Color(0xFFB45309)
                    : const Color(0xFF1A4A2E),
                width: 2,
              ),
            ),
            child: Builder(builder: (context) {
              // Icono representativo del tipo de status
              final bool active = (isReferenceListType ? hasSelectedRefChild : isSelected);
              final bool alwaysWhiteIcon = isTagTransferType ||
                  isTagTransferAdbServerType ||
                  typeStatus.toLowerCase() == 'tag-transfer-adb-from' ||
                  isDistanceExtractorType ||
                  isLabelInfoType ||
                  isDynamicPrintingAdbType;
              final Color iconColor = (active || alwaysWhiteIcon) ? Colors.white : const Color(0xFFB45309);
              IconData iconData;
              if (isDateType) {
                iconData = Icons.calendar_today_rounded;
              } else if (isTimeType) {
                iconData = Icons.access_time_rounded;
              } else if (isNumberType) {
                iconData = Icons.pin_rounded;
              } else if (isTextType) {
                iconData = Icons.text_fields_rounded;
              } else if (isTagReaderType) {
                iconData = Icons.nfc_rounded;
              } else if (isTagWriterType) {
                iconData = Icons.edit_note_rounded;
              } else if (isTagTransferType) {
                iconData = Icons.swap_horiz_rounded;
              } else if (isTagTransferAdbServerType) {
                iconData = Icons.wifi_tethering_rounded;
              } else if (typeStatus.toLowerCase() == 'tag-transfer-adb-from') {
                iconData = Icons.wifi_tethering_rounded;
              } else if (isPhotoType) {
                iconData = Icons.photo_camera_rounded;
              } else if (isVideoType) {
                iconData = Icons.videocam_rounded;
              } else if (isReferenceListType) {
                iconData = Icons.list_alt_rounded;
              } else if (isLabelInfoType) {
                iconData = Icons.info_outline_rounded;
              } else if (isDistanceExtractorType) {
                iconData = Icons.social_distance_rounded;
              } else if (isHeadquarterWeightType) {
                iconData = Icons.scale_rounded;
              } else if (isNumbersOperationType) {
                iconData = Icons.calculate_rounded;
              } else if (isUsersListType) {
                iconData = Icons.people_rounded;
              } else {
                iconData = Icons.radio_button_unchecked_rounded;
              }

              final Widget iconBadge = Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (active || alwaysWhiteIcon)
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFB45309).withValues(alpha: 0.12),
                  border: Border.all(
                    color: (active || alwaysWhiteIcon)
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFFB45309).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(iconData, size: 15, color: iconColor),
              );

              final bool isAnyTagTransfer = isTagTransferType ||
                  isTagTransferAdbServerType ||
                  typeStatus.toLowerCase() == 'tag-transfer-adb-from';

              // Para campos RANDOM: chip full-width con nombre, número y botón copiar
              if (isNumberType) {
                final ds = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                if (ds.toUpperCase().contains('=RANDOM:')) {
                  final numId = getJsonField(status, r'''$.id_activity_status''') as int? ?? 0;
                  return _buildRandomNumberChip(
                    statusId: numId,
                    statusName: statusName,
                    defaultStatus: ds,
                    fullWidth: true,
                  );
                }
              }

              // Bloque de contenido del status (sin el icono de tipo para tag-transfer)
              Widget bodyContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    if (!isAnyTagTransfer) ...[
                      iconBadge,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila superior: nombre + control numérico compacto + valores de fecha/hora
                          if (isNumberType)
                            // Layout especial para number: título izquierda, número centrado absoluto, botones derecha
                            Builder(builder: (context) {
                              final numStatusId = getJsonField(status, r'''$.id_activity_status''');
                              final defaultStatus = getJsonField(status, r'''$.default_status''').toString();
                              final currentValue = _getCurrentNumberValue(numStatusId, defaultStatus);
                              final usedUpDown = _numberUsedUpDown[numStatusId] ?? false;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Fila extremos: título izquierda, botones derecha
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          statusName,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      _buildCompactInlineNumberControlForStatus(
                                        parentStep: parentStep,
                                        status: status,
                                        showValue: false,
                                      ),
                                    ],
                                  ),
                                  // Número superpuesto en el centro real del contenedor
                                  IgnorePointer(
                                    child: Text(
                                      _formatColombianNumber(currentValue),
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: usedUpDown ? Colors.white : const Color(0xFFB45309),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            })
                          else
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusName,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: (typeStatus.toLowerCase() == 'date' || typeStatus.toLowerCase() == 'time') ? 13 : 19,
                                        fontWeight: FontWeight.w800,
                                        color: (isTagTransferType || isTagTransferAdbServerType || typeStatus.toLowerCase() == 'tag-transfer-adb-from' || isDistanceExtractorType || isLabelInfoType || isDynamicPrintingAdbType)
                                                ? Colors.white
                                                : ((isReferenceListType ? hasSelectedRefChild : isSelected) &&
                                                            !isTagWriterType &&
                                                            !isTagReaderType)
                                                        ? Colors.white
                                                        : const Color(0xFFB45309),
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    // Mostrar fecha seleccionada para tipo date (línea separada)
                                    if (typeStatus.toLowerCase() == 'date')
                                      IgnorePointer(
                                        child: _buildDateValueDisplay(
                                            statusId, parentStepId),
                                      ),
                                    // Mostrar hora seleccionada para tipo time (línea separada)
                                    if (typeStatus.toLowerCase() == 'time')
                                      IgnorePointer(
                                        child: _buildTimeValueDisplay(
                                            statusId, parentStepId),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Opción seleccionada para reference-list - DEBAJO del título
                          if (isReferenceListType && referenceListSelectedName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      referenceListSelectedName,
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Resumen del tag-reader (solo para tipo tag-reader) - DEBAJO
                          if (isTagReaderType &&
                              _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagReaderSummary(statusId: statusId),
                            ),
                          // Resumen ADB server en Windows (compact view)
                          if (isTagTransferAdbServerType && _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildAdbServerTagInlineSummary(
                                statusId: statusId,
                                displayMode: adbDisplayModeOverride ??
                                    AdbCardDisplayMode.tree,
                              ),
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
                          // TextField inline para tipo text - DEBAJO
                          if (isTextType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTextInputControl(
                                parentStep: parentStep,
                                status: status,
                              ),
                            ),
                          // Widget inline para tipo users-list - DEBAJO
                          if (isUsersListType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildUsersListControl(
                                parentStep: parentStep,
                                status: status,
                              ),
                            ),
                          // Display inline para tipo photo - DEBAJO
                          if (isPhotoType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildPhotoDisplay(
                                statusId: statusId,
                                parentStepId: parentStepId,
                              ),
                            ),
                          // Display inline para tipo video - DEBAJO
                          if (isVideoType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildVideoDisplay(
                                statusId: statusId,
                                parentStepId: parentStepId,
                                parentStep: parentStep,
                                status: status,
                              ),
                            ),
                          // Display para distance-extractor - siempre visible
                          if (isDistanceExtractorType)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDistanceExtractorDisplay(
                                statusId: statusId,
                              ),
                            ),
                          // Resumen de weights of headquarters - DEBAJO
                          if (isHeadquarterWeightType &&
                              (_calculatedHeadquarterWeights.containsKey(statusId is int ? statusId : (statusId as num).toInt()) ||
                                  _headquartersWithoutWeight.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildHeadquarterWeightsDisplay(statusId is int ? statusId : (statusId as num).toInt()),
                            ),
                          // Distribución proporcional de peso - DEBAJO
                          if (isHeadquarterWeightType &&
                              _isDistributionCalculation(
                                  getJsonField(status, r'''$.default_status''')?.toString() ?? ''))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDistributionDisplay(statusId),
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
                          // Botón PREVISUALIZAR para dynamic-printing-adb (dentro del card)
                          if (isDynamicPrintingAdbType)
                            _buildDynamicPrintingAdbButton(
                              context: context,
                              statusName: statusName,
                              status: status,
                              statusId: statusId,
                            ),
                        ],
                      ),
                    ),
                    // Botón de búsqueda inline para reference-list
                    if (isReferenceListType)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchBoxExpansionState[statusId] =
                                !(_searchBoxExpansionState[statusId] ?? false);
                            // Si abrimos la búsqueda, asegurar que la lista esté expandida
                            if (_searchBoxExpansionState[statusId] == true) {
                              _statusExpansionState[expansionKey] = true;
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: (_searchBoxExpansionState[statusId] ?? false)
                                ? const Color(0xFFB45309).withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: Colors.white,
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
                        color: const Color(0xFFB45309),
                      ),
                  ],
                );

              // Para tag-transfer: icono badge en esquina superior derecha
              if (isAnyTagTransfer) {
                return Stack(
                  children: [
                    bodyContent,
                    Positioned(
                      top: 0,
                      right: 0,
                      child: iconBadge,
                    ),
                  ],
                );
              }
              return bodyContent;
            }),
          ),
        ),

        // ╔════════════════════════════════════════════════════════════════╗
        // ║ RENDERIZACIÓN ESPECIAL PARA reference-list (type_status)      ║
        // ╚════════════════════════════════════════════════════════════════╝
        if (isReferenceListType && statusChilds.isNotEmpty && isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: [
                // Cuadro de búsqueda expandido (solo cuando está activo)
                if ((_searchBoxExpansionState[statusId] ?? false))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildExpandedSearchBox(statusId),
                  ),

                // Renderizar statusChilds de reference-list filtrando por búsqueda
                Builder(
                  builder: (context) {
                    final displayList = _filterStatusList(statusId, statusChilds);
                    if (displayList.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: displayList
                          .map<Widget>((childStatus) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildStatusOption(parentStep, childStatus,
                                    level: level + 1,
                                    parentMultipleOptionId: statusId),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),

        // Hijos expandidos (status o steps childs)
        if (isExpanded && hasChildren && !isReferenceListType)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: [
                // ✅ PRIMERO: Mostrar status childs (opciones inmediatas del mismo nivel)
                // IMPORTANTE: Pasar parentStep (el step real), NO el status actual
                // y pasar statusId como parentMultipleOptionId para exclusividad unique-option
                ...statusChilds.map<Widget>((childStatus) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStatusOption(parentStep, childStatus,
                        level: level + 1,
                        parentMultipleOptionId: statusId),
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

    // Extraer color del status para unique-option y unique_choice
    final statusColor = getJsonField(status, r'''$.color''')?.toString() ?? '#00ff9f';

    // Función para parsear color hex a Color
    Color parseColor(String hexColor) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return const Color(0xFF92400E); // Color por defecto
      }
    }

    final statusColorParsed = parseColor(statusColor);

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
    final isDynamicPrintingAdbType =
        typeStatus.toLowerCase() == 'dynamic-printing-adb';
    final isTagTransferAdbServerType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-server';
    final isTagTransferAdbFromType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-from';

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
                    _tagWriterProductName[statusId] = FFAppState().nfcLastProductName;
                  });

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
                  int existingIndex = -1;
                  for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                    if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
                      existingIndex = i;
                      break;
                    }
                  }

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();

                  if (existingIndex >= 0) {
                    FFAppState().updateVisitDetailsAtIndex(
                      existingIndex,
                      (detail) => VisitsDetailsStruct(
                        idVisitDetail: detail.idVisitDetail,
                        idVisit: detail.idVisit,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-WRITER: Contenido guardado en status_response (en memoria)');
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
                  final productName = await _fetchProductNameFromRfid(nfcContent);

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();
                  final isNoRemove = defaultStatus.contains('=ACTIONS:NO_REMOVE');

                  setState(() {
                    if (isNoRemove) {
                      // Modo acumulativo: agregar al array de raw JSONs
                      if (!_tagReaderRawJsons.containsKey(statusId)) {
                        _tagReaderRawJsons[statusId] = [];
                      }
                      _tagReaderRawJsons[statusId]!.add(nfcContent);
                      // Aplanar todos los records acumulados para _tagReaderData
                      final allRecords = <Map<String, dynamic>>[];
                      for (final raw in _tagReaderRawJsons[statusId]!) {
                        allRecords.addAll(_parseNfcTagContent(raw));
                      }
                      _tagReaderData[statusId] = allRecords;
                    } else {
                      // Modo normal: reemplazar
                      _tagReaderRawJsons.remove(statusId);
                      _tagReaderData[statusId] = parsedData;
                    }
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                    _tagReaderProductName[statusId] = productName;
                  });

                  // Determinar el statusResponse a guardar
                  final statusResponseToSave = isNoRemove
                      ? jsonEncode(_tagReaderRawJsons[statusId])
                      : nfcContent;

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
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
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-READER: Contenido guardado en status_response (en memoria)${isNoRemove ? " [NO_REMOVE: ${_tagReaderRawJsons[statusId]!.length} tags acumulados]" : ""}');

                  // VALIDACIÓN DE PESO PROMEDIO: Solo validar si hay status de tipo 'headquarters-weights'
                  if (_hasHeadquartersWeightsStatus()) {
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

                      // Calcular peso total: resultados x weight por cada headquarter
                      _calculateHeadquarterWeightResults(statusId, statusName);
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);

                  // Calcular automáticamente los headquarter-weight que referencien este tag-reader
                  debugPrint('🎯 TAG-READER: Llamando a _autoCalculateRelatedHeadquarterWeights() con statusName="$statusName"');
                  await _autoCalculateRelatedHeadquarterWeights(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, leer SOLO el tag de origen (NO transferir aún)
            if (isTagTransferType) {
              // Si ya se leyó el tag origen, bloquear tap — solo debe usarse TRANSFERIR AHORA
              if (_tagTransferData.containsKey(statusId) && _tagTransferData[statusId]!.isNotEmpty) {
                debugPrint('🚫 TAG-TRANSFER (ROOT): Tag origen ya leído, tap bloqueado — usar TRANSFERIR AHORA');
                return;
              }

              // Si la transferencia ya está completada, NO procesar el tap
              if (_tagTransferCompleted[statusId] == true) {
                debugPrint('🚫 TAG-TRANSFER (ROOT): Transferencia ya completada, tap ignorado');
                return;
              }

              // Resetear estado de transferencia completada al seleccionar nuevamente
              setState(() {
                _tagTransferCompleted[statusId] = false;
              });

              debugPrint('');
              debugPrint('🔄 TAG-TRANSFER (ROOT): Iniciando lectura de tag de ORIGEN');

              // Parsear TYPE_PRODUCT_START y TYPE_PRODUCT_FINISH desde default_status
              String? typeProductStart;
              String? typeProductFinish;
              // Captura todo hasta ; o } (permitiendo espacios en el nombre)
              final regexTypeStart = RegExp(r'=TYPE_PRODUCT_START:([^;}]+)');
              final regexTypeFinish = RegExp(r'TYPE_PRODUCT_FINISH:([^;}]+)');
              final matchStart = regexTypeStart.firstMatch(defaultStatus);
              final matchFinish = regexTypeFinish.firstMatch(defaultStatus);

              if (matchStart != null) {
                typeProductStart = matchStart.group(1)!.trim();
                debugPrint('📦 TAG-TRANSFER: TYPE_PRODUCT_START detectado: $typeProductStart');
              }
              if (matchFinish != null) {
                typeProductFinish = matchFinish.group(1)!.trim();
                debugPrint('📦 TAG-TRANSFER: TYPE_PRODUCT_FINISH detectado: $typeProductFinish');
              }

              // Obtener rememberStatus del JSON
              final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;

              // Crear título dinámico para el diálogo
              String dialogTitle = 'LEER TAG DE ORIGEN';
              if (typeProductStart != null && typeProductStart.isNotEmpty) {
                dialogTitle = 'Leer $typeProductStart de origen';
              }

              // Abrir diálogo de lectura NFC (solo leer, no transferir aún)
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (dialogContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: true,
                      tagTransferTitle: dialogTitle,
                    ),
                  );
                },
              );

              // Procesar el contenido del tag de origen desde FFAppState
              final nfcContent = FFAppState().nfcRead;
              debugPrint(
                  '📄 TAG-TRANSFER (ROOT): Contenido del tag de origen leído: ${nfcContent.length} caracteres');

              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // La validación de RFID ya se hizo en readNFC si TYPE_PRODUCT_START está presente
                // Si llegamos aquí, la validación pasó exitosamente

                // Parsear el contenido del tag y agrupar por headquarterId
                final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
                debugPrint(
                    '📊 TAG-TRANSFER (ROOT): Datos parseados: ${parsedData.length} lotes');

                // Guardar los datos del tag de origen
                final sourceProductName = await _fetchProductNameFromRfid(nfcContent);
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                  _tagTransferSourceProductName[statusId] = sourceProductName;
                });
                _persistTagTransferToPrefs(statusId, nfcContent).ignore();

                debugPrint(
                    '✅ TAG-TRANSFER (ROOT): Tag de origen guardado correctamente');

                // Guardar el contenido en status_response del visit detail (en memoria)
                // Buscar el índice existente o agregar nuevo
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
                      statusResponse: nfcContent,
                      idStepParent: 0,
                      rememberStatus: rememberStatus,
                      defaultStatus: defaultStatus,
                      typeStatus: typeStatus,
                      auxStep: 0,
                    ),
                  );
                } else {
                  FFAppState().addToVisitDetails(
                    VisitsDetailsStruct(
                      idVisitDetail: 0,
                      idVisit: 0,
                      idActivityStatus: statusId,
                      statusOption: statusName,
                      statusResponse: nfcContent,
                      idStepParent: 0,
                      rememberStatus: rememberStatus,
                      defaultStatus: defaultStatus,
                      typeStatus: typeStatus,
                      auxStep: 0,
                    ),
                  );
                }
                debugPrint('💾 TAG-TRANSFER: Contenido guardado en status_response (en memoria)');

                // Limpiar el tag de origen después de leer exitosamente
                debugPrint('🧹 TAG-TRANSFER (ROOT): Limpiando tag de origen...');
                if (!mounted) return;
                final clearSuccess = await actions.clearNFCTag(context);
                if (clearSuccess) {
                  debugPrint('✅ TAG-TRANSFER (ROOT): Tag de origen limpiado exitosamente');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.cleaning_services, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tag de origen leído y limpiado correctamente',
                                style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Color(0xFFB45309),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  debugPrint('⚠️ TAG-TRANSFER (ROOT): No se pudo limpiar el tag de origen');
                  // Continuar de todos modos, no es crítico
                }

                debugPrint(
                    '💡 TAG-TRANSFER (ROOT): Ahora el usuario puede presionar "Transferir ahora"');
              } else {
                debugPrint('❌ TAG-TRANSFER (ROOT): Error al leer tag de origen');
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

            // Si es tipo dynamic-printing / dynamic-printing-adb, el botón maneja su propia lógica
            if (isDynamicPrintingType || isDynamicPrintingAdbType) {
              debugPrint(
                  '🖨️ DYNAMIC-PRINTING: Tipo detectado, ignorando tap del contenedor');
              return;
            }

            // tag-transfer-adb-server: tap deshabilitado.
            // El socket arranca automáticamente desde _initAdbBridge() en
            // initState para desktop; no se debe levantar desde el tap.
            if (isTagTransferAdbServerType) {
              return;
            }

            // tag-transfer-adb-from: tap conecta y lee NFC (solo móvil)
            if (isTagTransferAdbFromType) {
              if (Platforms.isMobile) {
                if (!AdbNfcClientService.instance.isConnected) {
                  final connected = await AdbNfcClientService.instance.connect();
                  if (!mounted) return;
                  setState(() => _adbClientConnected = connected);
                  if (!connected) return;
                }
                if (!mounted) return;
                bool tagSentSuccessfully = false;
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                      onTagReadCallback: (tagContent) async {
                        final sent = await AdbNfcClientService.instance
                            .sendTagData(tagContent: tagContent);
                        if (sent) tagSentSuccessfully = true;
                        return sent;
                      },
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (tagSentSuccessfully &&
                    nfcContent.isNotEmpty &&
                    !nfcContent.startsWith('ERROR')) {
                  // Mostrar resumen inline en el dispositivo Android también
                  setState(() {
                    _tagReaderData[statusId] = _parseNfcTagContent(nfcContent);
                    _tagReaderProductName[statusId] = '';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop y borrado'),
                    backgroundColor: Color(0xFFB45309),
                    duration: Duration(seconds: 3),
                  ));
                }
              }
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
              await _onRootStatusSelected(status, allRootStatus: allActivityStatus);
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: level * 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Reemplazado gradiente por color sólido para mejor rendimiento
              color: (hasValue && !isNumberType && !isTagWriterType)
                  ? const Color(0xFFB45309)
                  : const Color(0xFF0D2B1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (hasValue && !isNumberType && !isTagWriterType)
                    ? const Color(0xFFB45309)
                    : const Color(0xFF1A4A2E),
                width: 2,
              ),
              // BoxShadow removido para mejor rendimiento
            ),
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
                        : const Color(0xFFB45309),
                    size: 36,
                  ),
                if (!hasChildren &&
                    typeStatus != 'tag-writer' &&
                    typeStatus != 'tag-reader' &&
                    typeStatus != 'tag-transfer' &&
                    typeStatus != 'tag-transfer-adb-server')
                  // Mostrar indicador de color para unique-option y unique_choice
                  (typeStatus.toLowerCase() == 'unique-option' || typeStatus.toLowerCase() == 'unique_choice')
                      ? Container(
                          width: 32,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColorParsed,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: statusColorParsed.withValues(alpha: 0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        )
                      : Icon(
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
                              : const Color(0xFFB45309),
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
                            child: Text(
                              statusName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: (isDistanceExtractorType &&
                                        (_distanceExtractorCalculated[statusId] ?? false))
                                    ? const Color(0xFF00695C)
                                    : (hasValue && !isNumberType && !isTagWriterType && !isDistanceExtractorType)
                                        ? Colors.white
                                        : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                          // Mostrar valor de hora (inline)
                          if (typeStatus.toLowerCase() == 'time')
                            _buildTimeValueDisplay(statusId, 0, hasValue: hasValue),
                          // Control numérico compacto inline
                          if (isNumberType)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: defaultStatus.toUpperCase().contains('=RANDOM:')
                                  ? _buildRandomNumberChip(
                                      statusId: statusId is int ? statusId : (statusId as num).toInt(),
                                      statusName: statusName,
                                      defaultStatus: defaultStatus,
                                      fullWidth: false,
                                    )
                                  : _buildCompactInlineNumberControl(status: status),
                            ),
                          // Botón de limpieza inline para tag-writer
                          if (isTagWriterType && _tagWriterData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildTagWriterCleanupButton(statusId: statusId),
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
                          // Botón de limpieza inline para tag-reader
                          if (isTagReaderType && _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildTagReaderCleanupButton(statusId: statusId),
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
                          // Botón de limpieza inline para tag-transfer
                          if (isTagTransferType && _tagTransferData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildTagTransferCleanupButton(statusId: statusId),
                            ),
                          // Botón inline para tag-transfer (NFC)
                          if (isTagTransferType)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildTagTransferButton(
                                context: context,
                                statusName: statusName,
                                statusId: statusId,
                                parentStep: null,
                                status: status,
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
                          // Badge inline para tag-transfer-adb-server (desktop)
                          if (isTagTransferAdbServerType)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildAdbServerBadge(statusId: statusId),
                            ),
                          // Badge compacto adb-from solo en desktop (móvil usa card completa debajo)
                          if (isTagTransferAdbFromType && Platforms.isDesktop)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildAdbFromBadge(statusId: statusId),
                            ),
                        ],
                      ),
                      // Mostrar valor de fecha
                      if (typeStatus.toLowerCase() == 'date')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildDateValueDisplay(statusId, 0, hasValue: hasValue),
                        ),
                      // Resumen del tag-reader
                      if (isTagReaderType && _tagReaderData.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildTagReaderSummary(statusId: statusId),
                        ),
                      // Tarjeta grande adb-from (solo móvil)
                      if (isTagTransferAdbFromType && Platforms.isMobile)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildAdbFromCard(statusId: statusId, context: context, status: status),
                        ),
                      // Resumen ADB server en Windows
                      if (isTagTransferAdbServerType && _tagReaderData.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildAdbServerTagInlineSummary(statusId: statusId),
                        ),
                      // Resumen del tag-writer
                      if (isTagWriterType && _tagWriterData.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildTagWriterSummary(statusId: statusId),
                        ),
                      // Resumen del tag-transfer
                      if (isTagTransferType && _tagTransferData.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildTagTransferSummary(statusId: statusId),
                        ),
                      // Valor calculado de numbers-operation
                      if (isNumbersOperationType && _calculatedValues.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildNumbersOperationDisplay(statusId: statusId, status: status),
                        ),
                      // Display para label-info
                      if (isLabelInfoType)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildLabelInfoDisplay(
                            statusName: statusName,
                            statusId: statusId,
                            status: status,
                          ),
                        ),
                      // Display para distance-extractor - siempre visible
                      if (isDistanceExtractorType)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildDistanceExtractorDisplay(statusId: statusId),
                        ),
                      // Resumen de weights de headquarters
                      if (isHeadquarterWeightType &&
                          (_calculatedHeadquarterWeights.containsKey(statusId is int ? statusId : (statusId as num).toInt()) || _headquartersWithoutWeight.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildHeadquarterWeightsDisplay(statusId is int ? statusId : (statusId as num).toInt()),
                        ),
                      // Distribución proporcional de peso - DEBAJO
                      if (isHeadquarterWeightType &&
                          _isDistributionCalculation(
                              getJsonField(status, r'''$.default_status''')?.toString() ?? ''))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildDistributionDisplay(statusId),
                        ),
                      // Cajones numéricos del 1 al 5
                      if (isNumberType &&
                          !defaultStatus.toUpperCase().contains('=RANDOM:'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildNumberBoxes(status: status),
                        ),
                      if (!isNumberType && !isTagWriterType && !isTagReaderType &&
                          functions.showCurrentStatus(FFAppState().visitDetails.toList(), statusId) != 'N/A')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            functions.showCurrentStatus(FFAppState().visitDetails.toList(), statusId) ?? '',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      // Botón PREVISUALIZAR para dynamic-printing-adb (dentro del card)
                      if (isDynamicPrintingAdbType)
                        _buildDynamicPrintingAdbButton(
                          context: context,
                          statusName: statusName,
                          status: status,
                          statusId: statusId,
                        ),
                    ],
                  ),
                ),
                // Badge de progreso (si hay steps hijos requeridos)
                if (totalRequired > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: totalCompleted == totalRequired
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCompleted/$totalRequired',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
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

                // Mostrar steps childs (level: 0 para alinear visualmente con los status childs)
                ...stepsChilds.map<Widget>((childStep) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildStepCard(childStep, level: 0),
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
    // Alias childStatus como status para compatibilidad con el código interno
    final status = childStatus;
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

    // Para status de tipo "number", "text", "tag-writer", "tag-reader", "tag-transfer" y "distance-extractor", NO cambiar color de la tarjeta
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isTextType = typeStatus.toLowerCase() == 'text';
    final isTagWriterType = typeStatus.toLowerCase() == 'tag-writer';
    final isTagReaderType = typeStatus.toLowerCase() == 'tag-reader';
    final isTagTransferType = typeStatus.toLowerCase() == 'tag-transfer';
    final isDistanceExtractorType =
        typeStatus.toLowerCase() == 'distance-extractor';
    final isPhotoType = typeStatus.toLowerCase() == 'photo';
    final isDateType = typeStatus.toLowerCase() == 'date';
    final isTimeType = typeStatus.toLowerCase() == 'time';
    final isUsersListType = typeStatus.toLowerCase() == 'users-list';
    final isTagTransferAdbServerType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-server';
    final isTagTransferAdbFromType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-from';

    // Convertir color hex a Color
    Color parseColor(String hexColor) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return const Color(0xFF92400E); // Color por defecto
      }
    }

    final color = parseColor(statusColor);

    return Column(
      children: [
        InkWell(
          onTap: () async {
            // Si es tipo users-list, no hacer nada: el control inline maneja la interacción
            if (isUsersListType) return;

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
                    _tagWriterProductName[statusId] = FFAppState().nfcLastProductName;
                  });

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
                  int existingIndex = -1;
                  for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                    if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
                      existingIndex = i;
                      break;
                    }
                  }

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();

                  if (existingIndex >= 0) {
                    FFAppState().updateVisitDetailsAtIndex(
                      existingIndex,
                      (detail) => VisitsDetailsStruct(
                        idVisitDetail: detail.idVisitDetail,
                        idVisit: detail.idVisit,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: nfcContent,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-WRITER: Contenido guardado en status_response (en memoria)');
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
                  final productName = await _fetchProductNameFromRfid(nfcContent);

                  // Extraer valores necesarios del status
                  final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;
                  final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
                  final typeStatus = getJsonField(status, r'''$.type_status''').toString();
                  final isNoRemove = defaultStatus.contains('=ACTIONS:NO_REMOVE');

                  setState(() {
                    if (isNoRemove) {
                      // Modo acumulativo: agregar al array de raw JSONs
                      if (!_tagReaderRawJsons.containsKey(statusId)) {
                        _tagReaderRawJsons[statusId] = [];
                      }
                      _tagReaderRawJsons[statusId]!.add(nfcContent);
                      // Aplanar todos los records acumulados para _tagReaderData
                      final allRecords = <Map<String, dynamic>>[];
                      for (final raw in _tagReaderRawJsons[statusId]!) {
                        allRecords.addAll(_parseNfcTagContent(raw));
                      }
                      _tagReaderData[statusId] = allRecords;
                    } else {
                      // Modo normal: reemplazar
                      _tagReaderRawJsons.remove(statusId);
                      _tagReaderData[statusId] = parsedData;
                    }
                    _tagReaderGeolocations[statusId] = geolocation;
                    _lastTagReaderLocation =
                        geolocation; // Guardar para distance-extractor
                    _tagReaderProductName[statusId] = productName;
                  });

                  // Determinar el statusResponse a guardar
                  final statusResponseToSave = isNoRemove
                      ? jsonEncode(_tagReaderRawJsons[statusId])
                      : nfcContent;

                  // Guardar el contenido en status_response del visit detail (en memoria)
                  // Buscar el índice existente o agregar nuevo
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
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: statusName,
                        statusResponse: statusResponseToSave,
                        idStepParent: 0,
                        rememberStatus: rememberStatus,
                        defaultStatus: defaultStatus,
                        typeStatus: typeStatus,
                        auxStep: 0,
                      ),
                    );
                  }
                  debugPrint('💾 TAG-READER: Contenido guardado en status_response (en memoria)${isNoRemove ? " [NO_REMOVE: ${_tagReaderRawJsons[statusId]!.length} tags acumulados]" : ""}');

                  // VALIDACIÓN DE PESO PROMEDIO: Solo validar si hay status de tipo 'headquarters-weights'
                  if (_hasHeadquartersWeightsStatus()) {
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

                      // Calcular peso total: resultados x weight por cada headquarter
                      _calculateHeadquarterWeightResults(statusId, statusName);
                    }
                  }

                  // Calcular automáticamente las distancias de los distance-extractor que referencien este tag-reader
                  await _autoCalculateRelatedDistances(statusId, statusName);

                  // Calcular automáticamente los headquarter-weight que referencien este tag-reader
                  debugPrint('🎯 TAG-READER: Llamando a _autoCalculateRelatedHeadquarterWeights() con statusName="$statusName"');
                  await _autoCalculateRelatedHeadquarterWeights(statusId, statusName);
                }
              }
              return;
            }

            // Si es tipo tag-transfer, leer SOLO el tag de origen (NO transferir aún)
            if (isTagTransferType) {
              // Si ya se leyó el tag origen, bloquear tap — solo debe usarse TRANSFERIR AHORA
              if (_tagTransferData.containsKey(statusId) && _tagTransferData[statusId]!.isNotEmpty) {
                debugPrint('🚫 TAG-TRANSFER (CHILD): Tag origen ya leído, tap bloqueado — usar TRANSFERIR AHORA');
                return;
              }

              // Si la transferencia ya está completada, NO procesar el tap
              if (_tagTransferCompleted[statusId] == true) {
                debugPrint('🚫 TAG-TRANSFER (CHILD): Transferencia ya completada, tap ignorado');
                return;
              }

              // Resetear estado de transferencia completada al seleccionar nuevamente
              setState(() {
                _tagTransferCompleted[statusId] = false;
              });

              debugPrint('');
              debugPrint('🔄 TAG-TRANSFER (CHILD): Iniciando lectura de tag de ORIGEN');

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
                  '📄 TAG-TRANSFER (CHILD): Contenido del tag de origen leído: ${nfcContent.length} caracteres');

              if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                // Parsear el contenido del tag y agrupar por headquarterId
                final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
                debugPrint(
                    '📊 TAG-TRANSFER (CHILD): Datos parseados: ${parsedData.length} lotes');

                // Guardar los datos del tag de origen
                final sourceProductName = await _fetchProductNameFromRfid(nfcContent);
                setState(() {
                  _tagTransferData[statusId] = parsedData;
                  _tagTransferSourceProductName[statusId] = sourceProductName;
                });
                _persistTagTransferToPrefs(statusId, nfcContent).ignore();

                debugPrint(
                    '✅ TAG-TRANSFER (CHILD): Tag de origen guardado correctamente');
                debugPrint(
                    '💡 TAG-TRANSFER (CHILD): Ahora el usuario puede presionar "Transferir ahora"');
              } else {
                debugPrint('❌ TAG-TRANSFER (CHILD): Error al leer tag de origen');
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

            // tag-transfer-adb-server: tap deshabilitado.
            // El socket arranca automáticamente desde _initAdbBridge() en
            // initState para desktop; no se debe levantar desde el tap.
            if (isTagTransferAdbServerType) {
              return;
            }

            // tag-transfer-adb-from: tap conecta y lee NFC (solo móvil)
            if (isTagTransferAdbFromType) {
              if (Platforms.isMobile) {
                if (!AdbNfcClientService.instance.isConnected) {
                  final connected = await AdbNfcClientService.instance.connect();
                  if (!mounted) return;
                  setState(() => _adbClientConnected = connected);
                  if (!connected) return;
                }
                if (!mounted) return;
                bool tagSentSuccessfully = false;
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                      onTagReadCallback: (tagContent) async {
                        final sent = await AdbNfcClientService.instance
                            .sendTagData(tagContent: tagContent);
                        if (sent) tagSentSuccessfully = true;
                        return sent;
                      },
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (tagSentSuccessfully &&
                    nfcContent.isNotEmpty &&
                    !nfcContent.startsWith('ERROR')) {
                  // Mostrar resumen inline en el dispositivo Android también
                  setState(() {
                    _tagReaderData[statusId] = _parseNfcTagContent(nfcContent);
                    _tagReaderProductName[statusId] = '';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop y borrado'),
                    backgroundColor: Color(0xFFB45309),
                    duration: Duration(seconds: 3),
                  ));
                }
              }
              return;
            }

            // Obtener todos los status childs del parent status para manejar unique_choice
            final parentStatusChildsRaw = getJsonField(parentStatus, r'''$.activities_status_childs''');
            final parentStatusChildsList = parentStatusChildsRaw != null
                ? (parentStatusChildsRaw is List ? parentStatusChildsRaw : [])
                : [];

            // TOGGLE para unique-option: Si ya está seleccionado, deseleccionar
            if (isSelected) {
              // Ya está seleccionado, DESELECCIONAR
              debugPrint('🔄 Root Status Child ya seleccionado, DESELECCIONANDO...');

              // Eliminar de visitDetails
              List<int> indicesToRemove = [];
              for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
                  indicesToRemove.add(i);
                }
              }

              for (int i = indicesToRemove.length - 1; i >= 0; i--) {
                FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
              }

              // Si es un unique-option hijo, limpiar del registro de selección por padre
              if (typeStatus.toLowerCase() == 'unique-option') {
                _selectedUniqueOptionByParent.remove(parentStatusId);
                debugPrint(
                    '   ✅ Limpiado registro de unique-option para padre=$parentStatusId');
              }

              debugPrint('✅ Root Status Child deseleccionado correctamente');

              // Solo hacer setState si DESELECCIONAMOS
              // (cuando seleccionamos, _onRootStatusSelected ya hace setState)
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
            } else {
              // No está seleccionado, SELECCIONAR
              debugPrint('✅ Seleccionando Root Status Child...');
              // Si tiene hijos, expandir en la misma pulsación (sin esperar 2 taps)
              if (hasChildren) {
                for (var sibling in parentStatusChildsList) {
                  final sibId = getJsonField(sibling, r'''$.id_activity_status''');
                  if (sibId != statusId) {
                    _statusExpansionState['root_${parentStatusId}_$sibId'] = false;
                  }
                }
                _statusExpansionState[expansionKey] = true;
                _rootStatusExpansionState[parentStatusId] = true;
              }
              await _onRootStatusSelected(
                childStatus,
                allRootStatus: parentStatusChildsList,
                parentStatusId: parentStatusId,
              );
            }
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
                        const Color(0xFFB45309),
                        const Color(0xFF92400E),
                      ]
                    : [
                        const Color(0xFF0D2B1A),
                        const Color(0xFF0A1F12),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // INVERTIDO: Verde oscuro si está seleccionado (y no es number, tag-writer, tag-reader ni distance-extractor)
                color: (isSelected &&
                        !isNumberType &&
                        !isTextType &&
                        !isTagWriterType &&
                        !isTagReaderType &&
                        !isDistanceExtractorType)
                    ? const Color(0xFFB45309)
                    : const Color(0xFF1A4A2E),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Radio button visual (no mostrar para tag-transfer, text, photo)
                if (!isTagTransferType && !isTextType && !isPhotoType)
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
                            : const Color(0xFFB45309),
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
                                color: Color(0xFFB45309),
                              ),
                            ),
                          )
                        : null,
                  ),
                if (!isTagTransferType && !isTextType && !isPhotoType) const SizedBox(width: 12),
                // Icono específico para date, time, text y photo, indicador de color para otros tipos
                if (!isTagTransferType)
                  // Para text y photo: solo mostrar icono sin contenedor de fondo cuando no está seleccionado
                  (isTextType || isPhotoType) && !isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            isTextType
                                ? Icons.text_fields_rounded
                                : Icons.photo_camera_rounded,
                            color: color,
                            size: 24,
                          ),
                        )
                      : Container(
                          width: 32,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isDateType || isTimeType || isTextType || isPhotoType)
                                ? (isSelected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : color.withValues(alpha: 0.2))
                                : color,
                            borderRadius: BorderRadius.circular(6),
                            border: (isDateType || isTimeType || isTextType || isPhotoType)
                                ? Border.all(
                                    color: isSelected ? Colors.white : color,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected ? Colors.white : color).withValues(alpha: 0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isDateType
                              ? Icon(
                                  Icons.calendar_today_rounded,
                                  color: isSelected ? Colors.white : color,
                                  size: 18,
                                )
                              : isTimeType
                                  ? Icon(
                                      Icons.access_time_rounded,
                                      color: isSelected ? Colors.white : color,
                                      size: 20,
                                    )
                                  : isTextType
                                      ? Icon(
                                          Icons.text_fields_rounded,
                                          color: isSelected ? Colors.white : color,
                                          size: 20,
                                        )
                                      : isPhotoType
                                          ? Icon(
                                              Icons.photo_camera_rounded,
                                              color: isSelected ? Colors.white : color,
                                              size: 20,
                                            )
                                          : null,
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
                              : const Color(0xFFB45309),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Badge inline para tag-transfer-adb-server
                if (isTagTransferAdbServerType)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildAdbServerBadge(statusId: statusId),
                  ),
                // Badge compacto adb-from solo en desktop
                if (isTagTransferAdbFromType && Platforms.isDesktop)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildAdbFromBadge(statusId: statusId),
                  ),
                if (hasChildren)
                  Icon(
                    isExpanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 32,
                    weight: 700,
                    color: const Color(0xFFB45309),
                  ),
              ],
            ),
          ),
        ),

        // Control inline para tipo users-list (fuera del InkWell para interacción independiente)
        if (isUsersListType)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: _buildUsersListControl(
              parentStep: null,
              status: status,
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

  Future<void> _onRootStatusSelected(
    dynamic status, {
    List<dynamic>? allRootStatus,
    int? parentStatusId,
  }) async {
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

    // CASO 1: UNIQUE-OPTION HIJO dentro de un MULTIPLE-OPTION PADRE
    // Deseleccionar solo hermanos del MISMO padre
    if (typeStatus.toLowerCase() == 'unique-option' &&
        parentStatusId != null &&
        allRootStatus != null) {
      debugPrint(
          '🎯 UNIQUE-OPTION HIJO: statusId=$statusId, parentId=$parentStatusId');

      // Obtener el unique-option previamente seleccionado bajo este padre
      final previouslySelectedId = _selectedUniqueOptionByParent[parentStatusId];

      if (previouslySelectedId != null && previouslySelectedId != statusId) {
        // Deseleccionar el anterior
        List<int> indicesToRemove = [];
        for (int i = 0; i < FFAppState().visitDetails.length; i++) {
          if (FFAppState().visitDetails[i].idActivityStatus ==
              previouslySelectedId) {
            indicesToRemove.add(i);
            debugPrint(
                '   ❌ Deseleccionando anterior: ID=$previouslySelectedId');
          }
        }
        for (int i = indicesToRemove.length - 1; i >= 0; i--) {
          FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
        }
        _visitDetailsSearchCache.clear();
      }

      // Registrar el nuevo unique-option seleccionado
      _selectedUniqueOptionByParent[parentStatusId] = statusId;
      debugPrint('   ✅ Registrado nuevo unique-option: statusId=$statusId');
    }
    // CASO 2: UNIQUE-CHOICE/UNIQUE-OPTION A NIVEL RAÍZ
    else if ((typeStatus.toLowerCase() == 'unique_choice' ||
            typeStatus.toLowerCase() == 'unique-option') &&
        allRootStatus != null) {
      // Obtener todos los IDs de status raíz que son unique_choice o unique-option (excepto el actual)
      final List<int> siblingStatusIds = [];
      for (var sibling in allRootStatus) {
        final siblingId = getJsonField(sibling, r'''$.id_activity_status''');
        final siblingType =
            getJsonField(sibling, r'''$.type_status''')?.toString().toLowerCase() ?? '';
        if (siblingId != statusId &&
            (siblingType == 'unique_choice' || siblingType == 'unique-option')) {
          siblingStatusIds.add(siblingId);
        }
      }

      // Eliminar de visitDetails todos los status hermanos (unique_choice) que estén seleccionados
      if (siblingStatusIds.isNotEmpty) {
        List<int> indicesToRemove = [];
        for (int i = 0; i < FFAppState().visitDetails.length; i++) {
          if (siblingStatusIds
              .contains(FFAppState().visitDetails[i].idActivityStatus)) {
            indicesToRemove.add(i);
          }
        }
        // Remover en orden inverso para no alterar los índices
        for (int i = indicesToRemove.length - 1; i >= 0; i--) {
          FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
        }
        // Limpiar cache de búsqueda porque cambiaron los visitDetails
        _visitDetailsSearchCache.clear();
        debugPrint(
            '🔘 UNIQUE_CHOICE/UNIQUE-OPTION: Eliminados ${indicesToRemove.length} status hermanos');
      }
    }

    // Determinar el statusResponse según el tipo
    String finalStatusResponse = defaultStatus;
    if (typeStatus.toLowerCase() == 'unique_choice' ||
        typeStatus.toLowerCase() == 'unique-option') {
      // Para unique_choice y unique-option, guardar "Seleccionado"
      finalStatusResponse = 'Seleccionado';
    }

    // Para otros tipos, guardar valor correspondiente
    _saveRootStatusValue(
      statusId: statusId,
      statusName: statusName,
      statusResponse: finalStatusResponse,
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

    // Limpiar cache de búsqueda porque cambiaron los visitDetails
    _visitDetailsSearchCache.clear();
    setState(() {});
  }

  Future<void> _onStatusSelected(dynamic parentStep, dynamic status, {int? parentMultipleOptionId}) async {
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

    // LÓGICA CLAVE DE SELECCIÓN SEGÚN TIPO DE STEP:
    // - reference-list: SOLO se puede seleccionar UN elemento
    // - unique-list: SOLO se puede seleccionar UN elemento
    // - container-list: Se pueden seleccionar MÚLTIPLES elementos (es solo un contenedor)
    // - multiple-list: Se pueden seleccionar MÚLTIPLES elementos

    final isMultiSelectList = typeStep.toLowerCase() == 'container-list' ||
        typeStep.toLowerCase() == 'multiple-list';

    if (isMultiSelectList) {
      debugPrint('📋 Tipo de step: $typeStep - Permite MÚLTIPLES selecciones');
    } else {
      debugPrint('📋 Tipo de step: $typeStep - Solo se permite UNA selección');
    }

    // 1. Lógica de eliminación de selecciones previas según tipo de step
    List<int> indicesToRemove = [];

    if (!isMultiSelectList) {
      if (typeStep.toLowerCase() == 'tab-container') {
        // Para tab-container: cada status es independiente, NO borrar hermanos del tab.
        // Pero los hijos de un reference-list deben ser excluyentes entre sí,
        // identificados por auxStep == parentMultipleOptionId.
        if (parentMultipleOptionId != null) {
          // Es hijo de un reference-list: eliminar selección previa del mismo grupo
          for (int i = 0; i < FFAppState().visitDetails.length; i++) {
            final d = FFAppState().visitDetails[i];
            if (d.auxStep == parentMultipleOptionId && d.idActivityStatus != 0) {
              indicesToRemove.add(i);
              debugPrint('   ⚠️ Eliminando selección previa de reference-list: ${d.statusOption}');
            }
          }
        } else {
          // Status independiente del tab: solo eliminar la entrada anterior del mismo statusId
          for (int i = 0; i < FFAppState().visitDetails.length; i++) {
            final d = FFAppState().visitDetails[i];
            if (d.idStepParent == parentStepId && d.idActivityStatus == statusId) {
              indicesToRemove.add(i);
              debugPrint('   ⚠️ Eliminando entrada previa del mismo status: ${d.statusOption}');
            }
          }
        }
      } else {
        // Comportamiento original para non-tab-container: eliminar todos los status del step
        for (int i = 0; i < FFAppState().visitDetails.length; i++) {
          if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
              FFAppState().visitDetails[i].idActivityStatus != 0) {
            indicesToRemove.add(i);
            debugPrint('   ⚠️ Eliminando selección previa: ${FFAppState().visitDetails[i].statusOption}');
          }
        }
      }

      if (indicesToRemove.isNotEmpty) {
        debugPrint('   🗑️ Eliminando ${indicesToRemove.length} selección(es) previa(s)');
      }

      // Remover en orden inverso para no alterar los índices
      for (int i = indicesToRemove.length - 1; i >= 0; i--) {
        FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
      }
    } else {
      debugPrint('   ✅ multi-select: No se eliminan selecciones previas');
    }

    // 2. Agregar el nuevo status seleccionado
    // Aplicar la lógica correcta según el tipo del step padre
    String finalStatusOption = statusName;
    String finalStatusResponse = defaultStatus;

    // Para tipo number, obtener el valor actual si ya existe en visitDetails
    if (typeStatus.toLowerCase() == 'number') {
      for (var detail in FFAppState().visitDetails) {
        if (detail.idActivityStatus == statusId && detail.idStepParent == parentStepId) {
          finalStatusResponse = detail.statusResponse;
          break;
        }
      }
    }

    // Si el step padre es de tipo "unique-list", guardar checkmark
    if (typeStep.toLowerCase() == 'unique-list') {
      finalStatusResponse = '✓';
    }

    // Si el status es de tipo "reference-list", invertir los valores
    // statusOption = nombre del step padre (actividad padre)
    // statusResponse = nombre del status seleccionado (hijo seleccionado)
    if (typeStatus.toLowerCase() == 'reference-list') {
      finalStatusOption = stepName; // Nombre del step padre
      finalStatusResponse = statusName; // Nombre del status seleccionado
      debugPrint('📋 reference-list (type_status): Inversión de valores');
      debugPrint('   statusOption = "$finalStatusOption" (step padre)');
      debugPrint('   statusResponse = "$finalStatusResponse" (status seleccionado)');
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
        // Para hijos de reference-list: auxStep = ID del reference-list padre
        // Permite identificar hermanos para exclusividad en tab-container
        auxStep: parentMultipleOptionId ?? parentStepId,
      ),
    );

    // 3. Marcar el step padre como completado
    // Para container-list: actualizar con lista de todos los status seleccionados
    // Para unique-list/reference-list: actualizar con el único status seleccionado

    // Buscar si ya existe un registro del step (idActivityStatus == 0)
    int stepExistingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
          FFAppState().visitDetails[i].idActivityStatus == 0) {
        stepExistingIndex = i;
        break;
      }
    }

    // Para container-list, obtener todos los status seleccionados de este step
    String stepStatusResponse = statusName;
    if (isMultiSelectList) {
      List<String> selectedStatusNames = [];
      for (var detail in FFAppState().visitDetails) {
        if (detail.idStepParent == parentStepId && detail.idActivityStatus != 0) {
          selectedStatusNames.add(detail.statusOption);
        }
      }
      stepStatusResponse = selectedStatusNames.join(', ');
      debugPrint('   📝 container-list: statusResponse del step = "$stepStatusResponse"');
    }

    if (stepExistingIndex >= 0) {
      // Actualizar el registro del step
      FFAppState().updateVisitDetailsAtIndex(
        stepExistingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: 0,
          statusOption: stepName,
          statusResponse: stepStatusResponse,
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
          statusResponse: stepStatusResponse,
          idStepParent: parentStepId,
          rememberStatus: false,
          defaultStatus: '',
          typeStatus: 'STEP',
          auxStep: parentStepId,
        ),
      );
    }

    // Forzar limpieza del caché para que se actualice el color verde de las opciones
    // Esto es especialmente importante para unique-list y reference-list donde
    // eliminamos 1 y agregamos 1 (la longitud no cambia, pero los IDs sí)
    _visitDetailsSearchCache.clear();

    // Para unique-list y reference-list: COLAPSAR automáticamente el step después de seleccionar
    // Esto evita que el usuario tenga que tocar manualmente el header para cerrar la lista
    if (!isMultiSelectList) {
      // Para reference-list: si el status seleccionado tiene steps hijos, mantener
      // el step padre expandido para que los child steps sean visibles directamente.
      final stepsChildsRaw = getJsonField(status, r'''$.activities_steps_childs''');
      final stepsChilds = stepsChildsRaw != null
          ? (stepsChildsRaw is List ? stepsChildsRaw : [])
          : [];
      final statusChildsRaw = getJsonField(status, r'''$.activities_status_childs''');
      final statusChilds = statusChildsRaw != null
          ? (statusChildsRaw is List ? statusChildsRaw : [])
          : [];
      final selectedStatusHasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;

      if (typeStep.toLowerCase() == 'tab-container') {
        // Las tabs nunca colapsan: el auto-collapse no aplica
        debugPrint('🔽 tab-container: no auto-colapsar');
      } else if (typeStatus.toLowerCase() == 'reference-list' && selectedStatusHasChildren) {
        // No colapsar: mantener visible la lista con el status seleccionado y sus hijos
        debugPrint('🔽 reference-list (type_status): status seleccionado tiene hijos → NO colapsar estado expandido');
      } else {
        debugPrint('🔽 Auto-colapsando step "$stepName" (tipo: $typeStep)');
        _stepExpansionState[parentStepId] = false;
        _searchBoxExpansionState[parentStepId] = false;
      }
    }

    setState(() {});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOTONERA INFERIOR (Cancelar / Historial / Guardar).
  // GUARDAR ya no crea visita — la visita se crea al recibir un tag ADB.
  // GUARDAR solo cambia Status=1 (terminado) de _activeVisitId, anima la
  // salida de la tarjeta del panel izquierdo y auto-selecciona la siguiente
  // pendiente más reciente (o vuelve a bloquear el form si no quedan).
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildNavigationButtons() {
    final canSave = _activeVisitId != null;
    final canDelete = _activeVisitId != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // ── ELIMINAR ───────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: canDelete ? _confirmAndDeletePendingVisit : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canDelete
                        ? [
                            FlutterFlowTheme.of(context).error,
                            FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                          ]
                        : const [Color(0xFF616161), Color(0xFF424242)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canDelete
                      ? [
                          BoxShadow(
                            blurRadius: 12,
                            color: FlutterFlowTheme.of(context).error.withValues(alpha: 0.4),
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Eliminar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── HISTORIAL ──────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () {
                final idActivity = getJsonField(
                    FFAppState().currentActivity, r'$.id_activity') as int?;
                if (idActivity == null) return;
                context.pushNamed(
                  'HistorialExtractoraPage',
                  queryParameters: {'idActivity': idActivity.toString()},
                );
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Historial',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── GUARDAR ────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: canSave ? _onSavePendingVisit : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canSave
                        ? const [Color(0xFF00a86b), Color(0xFF007552)]
                        : const [Color(0xFF616161), Color(0xFF424242)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canSave
                      ? [
                          BoxShadow(
                            blurRadius: 12,
                            color: const Color(0xFF00a86b).withValues(alpha: 0.45),
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Guardar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Marca la visita activa como terminada (Status=1), anima la salida de
  /// la tarjeta correspondiente del panel izquierdo, reindexa el map de
  /// pendientes y auto-selecciona la siguiente más reciente (o bloquea el
  /// formulario si no quedan más).
  Future<void> _onSavePendingVisit() async {
    if (_activeVisitId == null) return;
    final closedVisitId = _activeVisitId!;

    try {
      final db = await GlobalDbSingleton().database;
      await db.update(
        'Visits',
        {'Status': 1},
        where: 'Id_visit = ?',
        whereArgs: [closedVisitId],
      );
    } catch (e) {
      debugPrint('❌ _onSavePendingVisit UPDATE error: $e');
      return;
    }

    // Localizar índice de la tarjeta correspondiente (puede ser -1 si por
    // alguna razón no estaba mapeada — en ese caso skip animation).
    int closedIdx = -1;
    _pendingTagIndexToVisitId.forEach((k, v) {
      if (v == closedVisitId) closedIdx = k;
    });

    if (closedIdx >= 0) {
      setState(() => _animatingOutTagIndex = closedIdx);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _removeTagCardAt(closedIdx);
        _pendingTagIndexToVisitId.remove(closedIdx);
        _reindexPendingTagMap(closedIdx);
        _animatingOutTagIndex = null;
      });
    }

    // Auto-seleccionar la siguiente pendiente (la primera del map).
    if (_pendingTagIndexToVisitId.isNotEmpty) {
      final nextIdx = _pendingTagIndexToVisitId.keys.reduce(
          (a, b) => a < b ? a : b);
      final nextVisitId = _pendingTagIndexToVisitId[nextIdx]!;
      setState(() => _selectedAdbTagIndex = nextIdx);
      _clearFormState();
      await _hydrateVisitInForm(nextVisitId);
    } else {
      _clearFormState();
      if (mounted) {
        setState(() {
          _activeVisitId = null;
          _formLocked = true;
        });
      }
    }
  }

  /// Muestra un diálogo modal pidiendo el código de supervisor para confirmar
  /// la eliminación de la visita activa. Si el código es correcto, dispara
  /// [_deletePendingVisit]; de lo contrario reintenta sin cerrar el diálogo.
  Future<void> _confirmAndDeletePendingVisit() async {
    if (_activeVisitId == null) return;

    final codeController = TextEditingController();
    final focusNode = FocusNode();
    String? errorText;
    bool confirmed = false;

    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validateAndClose() {
              final entered = codeController.text.trim();
              if (entered == _kSupervisorDeleteCode) {
                confirmed = true;
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(() {
                  errorText = 'Código incorrecto';
                  codeController.clear();
                });
                focusNode.requestFocus();
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFEF4444), size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Eliminar visita',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Esta acción borrará permanentemente la visita seleccionada '
                      'y todos sus detalles y ubicaciones asociadas.\n\n'
                      'Digita el código de supervisor para continuar:',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeController,
                      focusNode: focusNode,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (_) => validateAndClose(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          letterSpacing: 6,
                          fontSize: 16,
                        ),
                        errorText: errorText,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: validateAndClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    codeController.dispose();
    focusNode.dispose();

    if (!confirmed || !mounted) return;
    await _deletePendingVisit();
  }

  /// Borra de SQLite la visita activa (Visits + Visits_details + Visits_locations),
  /// anima la salida de la tarjeta del panel izquierdo, reindexa
  /// [_pendingTagIndexToVisitId] y auto-selecciona la siguiente pendiente.
  /// Imita la mecánica de [_onSavePendingVisit] sustituyendo el UPDATE por DELETE.
  Future<void> _deletePendingVisit() async {
    if (_activeVisitId == null) return;
    final deletedVisitId = _activeVisitId!;

    try {
      final db = await GlobalDbSingleton().database;
      // Orden importante: hijos primero, padre al final.
      await db.rawDelete(
        'DELETE FROM Visits_locations WHERE Id_visit = ?',
        [deletedVisitId],
      );
      await db.rawDelete(
        'DELETE FROM Visits_details WHERE Id_visit = ?',
        [deletedVisitId],
      );
      final deletedRows = await db.delete(
        'Visits',
        where: 'Id_visit = ?',
        whereArgs: [deletedVisitId],
      );
      debugPrint(
          '🗑️ _deletePendingVisit: borradas $deletedRows fila(s) de Visits para Id_visit=$deletedVisitId');
    } catch (e) {
      debugPrint('❌ _deletePendingVisit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la visita. Inténtalo de nuevo.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    int closedIdx = -1;
    _pendingTagIndexToVisitId.forEach((k, v) {
      if (v == deletedVisitId) closedIdx = k;
    });

    if (closedIdx >= 0) {
      setState(() => _animatingOutTagIndex = closedIdx);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _removeTagCardAt(closedIdx);
        _pendingTagIndexToVisitId.remove(closedIdx);
        _reindexPendingTagMap(closedIdx);
        _animatingOutTagIndex = null;
      });
    }

    if (_pendingTagIndexToVisitId.isNotEmpty) {
      final nextIdx = _pendingTagIndexToVisitId.keys.reduce(
          (a, b) => a < b ? a : b);
      final nextVisitId = _pendingTagIndexToVisitId[nextIdx]!;
      setState(() => _selectedAdbTagIndex = nextIdx);
      _clearFormState();
      await _hydrateVisitInForm(nextVisitId);
    } else {
      // No quedan visitas pendientes: devolver el formulario al estado de
      // "primer ingreso" (overlay "Lea un tag para empezar"). Limpiamos también
      // los maps de tarjetas ADB para que el siguiente tag arranque en frío,
      // sin restos de la visita recién eliminada.
      _clearFormState();
      if (mounted) {
        setState(() {
          _activeVisitId = null;
          _formLocked = true;
          _animatingOutTagIndex = null;
          _selectedAdbTagIndex = 0;
          _pendingTagIndexToVisitId.clear();
          _adbTagTimestamps.clear();
          _adbServerCardsRawJson.clear();
          _adbServerCardsData.clear();
          _adbServerCardsProductName.clear();
          _tagReaderData.clear();
          _tagReaderRawJsons.clear();
          _tagReaderProductName.clear();
        });
      }
    }
  }

  /// Crea una visita directamente usando el TAG NFC leído y las últimas 3 geolocalizaciones del AppState
  Future<bool> _createVisitWithNfc(String nfcTagId) async {
    try {
      debugPrint('📱 ===== CREANDO VISITA CON NFC =====');
      debugPrint('🏷️  TAG ID: $nfcTagId');

      // Obtener datos necesarios
      final currentActivity = FFAppState().currentActivity;
      final idActivity = getJsonField(currentActivity, r'''$.id_activity''');
      final userSelected = FFAppState().userSelected;
      final deviceDefault = FFAppState().deviceDefault;

      // === VALIDACIÓN DE TIPO DE PRODUCTO PARA TAG-READER ===
      // Verificar si algún status es tag-reader con validación de tipo de producto
      final activityStatusList = getJsonField(currentActivity, r'''$.activity_status''') as List?;
      if (activityStatusList != null) {
        for (var statusItem in activityStatusList) {
          final typeStatus = getJsonField(statusItem, r'''$.type_status''')?.toString() ?? '';
          final defaultStatus = getJsonField(statusItem, r'''$.default_status''')?.toString() ?? '';

          if (typeStatus == 'tag-reader' && defaultStatus.contains('=TYPE_PRODUCT_DEFAULT:')) {
            debugPrint('🔍 Validando tipo de producto para tag-reader');

            // Extraer el tipo de producto requerido
            final regex = RegExp(r'=TYPE_PRODUCT_DEFAULT:([^;}\s]+)');
            final match = regex.firstMatch(defaultStatus);

            if (match != null && match.groupCount >= 1) {
              final requiredProductType = match.group(1)!.trim();
              debugPrint('✅ Tipo de producto requerido: $requiredProductType');

              // Buscar el producto en SQLite por RFID
              // Usa GlobalDbSingleton.executeOperation: conexión compartida +
              // retry automático en locked/busy/database_closed (3 intentos).
              final productResults = await globalDb.executeOperation(
                (db) => db.rawQuery(
                  'SELECT Type_product FROM Products WHERE Rfid = ? LIMIT 1',
                  [nfcTagId],
                ),
              );

              if (productResults.isEmpty) {
                debugPrint('❌ RFID no encontrado en Products: $nfcTagId');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El tag no corresponde a un $requiredProductType',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
                return false;
              }

              final productType = productResults.first['Type_product'] as String?;

              if (productType != requiredProductType) {
                // Tipo de producto no coincide
                debugPrint('❌ Tipo de producto no coincide. Esperado: $requiredProductType, Encontrado: $productType');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El tag no corresponde a un $requiredProductType',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
                return false;
              }

              debugPrint('✅ Validación de tipo de producto exitosa: $productType');
            }
          }
        }
      }

      // Obtener el Id_headquarter del lote actual
      int idHeadquarter = 0;
      final headquartersList = FFAppState().headquartersSelectedList;
      if (headquartersList.isNotEmpty) {
        idHeadquarter = headquartersList.first.idHeadquarter;
        debugPrint('✅ Usando lote: ${headquartersList.first.nameHeadquarter} (ID: $idHeadquarter)');
      } else {
        debugPrint('⚠️ No hay lotes seleccionados, Id_headquarter será 0');
      }

      // Obtener geolocalizaciones de los últimos 5 segundos desde geoLocationsList
      final allGeoLocations = FFAppState().geoLocationsList;
      if (allGeoLocations.isEmpty) {
        debugPrint('⚠️ No hay geolocalizaciones disponibles');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No hay ubicación GPS disponible. Espere a que se obtenga la ubicación.',
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return false;
      }

      // Filtrar ubicaciones de los últimos 5 segundos
      final now = DateTime.now();
      final fiveSecondsAgo = now.subtract(const Duration(seconds: 5));

      final recentGeoLocations = allGeoLocations.where((loc) {
        if (loc.dateHourRead == null) return false;
        return loc.dateHourRead!.isAfter(fiveSecondsAgo) && loc.dateHourRead!.isBefore(now);
      }).toList();

      // Si no hay ubicaciones de los últimos 5 segundos, usar la más reciente
      final locationsToSave = recentGeoLocations.isNotEmpty
          ? recentGeoLocations
          : [allGeoLocations.last];

      // Usar la ubicación más reciente como la principal de la visita
      final mainLocation = locationsToSave.last;
      debugPrint('📍 Ubicación principal: lat=${mainLocation.latitude}, lon=${mainLocation.longitude}');
      debugPrint('📍 Total geolocalizaciones de los últimos 5 segundos: ${locationsToSave.length}');

      // Obtener visitDetails filtrados
      final visitDetails = FFAppState().visitDetails;
      final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();

      // Insertar Visita + detalles + geolocalizaciones en una transacción.
      // Usa GlobalDbSingleton.executeOperation: conexión compartida +
      // retry automático en locked/busy/database_closed (3 intentos).
      int visitId = 0;
      await globalDb.executeOperation((db) async {
        await db.transaction((txn) async {
          // Insertar la visita con el RFID
          visitId = await txn.rawInsert('''
            INSERT INTO Visits (
              Id_company, Id_activity, Id_headquarter, Id_product, Id_bulk,
              Id_user, Id_device, Id_status, Created_at, Battery,
              Latitude, Longitude, Altitude, Error_horizontal, Id_virtual_point, Status, Rfid
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            userSelected.idCompany,
            idActivity,
            idHeadquarter,
            0, // Id_product
            0, // Id_bulk
            userSelected.idUser,
            deviceDefault.idDevice,
            0, // Id_status
            DateTime.now().toIso8601String(),
            100, // Battery (valor por defecto)
            mainLocation.latitude,
            mainLocation.longitude,
            mainLocation.altitude,
            mainLocation.errorHorizontal,
            null, // Id_virtual_point
            0, // Status
            nfcTagId, // RFID del TAG
          ]);

          debugPrint('✅ Visita NFC creada con ID: $visitId');

          // Insertar detalles de la visita
          int insertedCount = 0;
          for (var detail in detailsToInsert) {
            final idActivityStatus = detail.idActivityStatus;

            final statusCheck = await txn.rawQuery('''
              SELECT Id_activity_status FROM Activities_status WHERE Id_activity_status = ?
            ''', [idActivityStatus]);

            if (statusCheck.isEmpty) continue;

            await txn.rawInsert('''
              INSERT INTO Visits_details (Id_visit, Id_activity_status, Status_option, Status_response)
              VALUES (?, ?, ?, ?)
            ''', [visitId, idActivityStatus, detail.statusOption, detail.statusResponse]);

            insertedCount++;
          }

          debugPrint('✅ $insertedCount detalles de visita insertados');

          // Insertar las geolocalizaciones
          for (var geoPoint in locationsToSave) {
            await txn.rawInsert('''
              INSERT INTO Visits_locations (Id_visit, Latitude, Longitude, Altitude, HorizontalError, CreatedAt)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              visitId,
              geoPoint.latitude,
              geoPoint.longitude,
              geoPoint.altitude,
              geoPoint.errorHorizontal,
              geoPoint.dateHourRead?.toIso8601String() ?? DateTime.now().toIso8601String(),
            ]);
          }

          debugPrint('✅ ${locationsToSave.length} ubicaciones GPS insertadas');
        });
      });

      // Actualizar el contador de visitas y limpiar visitDetails completamente
      FFAppState().update(() {
        FFAppState().visitCount = FFAppState().visitCount + 1;
        FFAppState().visitDetails = [];
      });

      debugPrint('🧹 visitDetails limpiado completamente después de guardar visita NFC');
      debugPrint('✅ Visita NFC completada exitosamente. ID: $visitId');
      unawaited(actions.announceVisitVoice());
      return true;
    } catch (e) {
      debugPrint('❌ Error creando visita NFC: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al guardar la visita: $e',
                    style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return false;
    }
  }

  /// Muestra el diálogo moderno para escanear un código QR
  /// Retorna el código QR escaneado o null si el usuario cancela
  Future<String?> _showQrScannerDialog() async {
    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) {
        return const Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: QrScannerDialogWidget(
            title: 'Escanear QR',
            subtitle: 'Alinee el código QR dentro del marco para registrar la visita',
          ),
        );
      },
    );
  }

  /// Crea una visita directamente usando el código QR escaneado y las últimas 3 geolocalizaciones del AppState
  Future<bool> _createVisitWithQr(String qrCode) async {
    try {
      debugPrint('📱 ===== CREANDO VISITA CON QR =====');
      debugPrint('📷 QR Code: $qrCode');

      // Obtener datos necesarios
      final currentActivity = FFAppState().currentActivity;
      final idActivity = getJsonField(currentActivity, r'''$.id_activity''');
      final userSelected = FFAppState().userSelected;
      final deviceDefault = FFAppState().deviceDefault;

      // Obtener el Id_headquarter del lote actual
      int idHeadquarter = 0;
      final headquartersList = FFAppState().headquartersSelectedList;
      if (headquartersList.isNotEmpty) {
        idHeadquarter = headquartersList.first.idHeadquarter;
        debugPrint('✅ Usando lote: ${headquartersList.first.nameHeadquarter} (ID: $idHeadquarter)');
      } else {
        debugPrint('⚠️ No hay lotes seleccionados, Id_headquarter será 0');
      }

      // Obtener geolocalizaciones de los últimos 5 segundos desde geoLocationsList
      final allGeoLocations = FFAppState().geoLocationsList;
      if (allGeoLocations.isEmpty) {
        debugPrint('⚠️ No hay geolocalizaciones disponibles');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No hay ubicación GPS disponible. Espere a que se obtenga la ubicación.',
                      style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return false;
      }

      // Filtrar ubicaciones de los últimos 5 segundos
      final now = DateTime.now();
      final fiveSecondsAgo = now.subtract(const Duration(seconds: 5));

      final recentGeoLocations = allGeoLocations.where((loc) {
        if (loc.dateHourRead == null) return false;
        return loc.dateHourRead!.isAfter(fiveSecondsAgo) && loc.dateHourRead!.isBefore(now);
      }).toList();

      // Si no hay ubicaciones de los últimos 5 segundos, usar la más reciente
      final locationsToSave = recentGeoLocations.isNotEmpty
          ? recentGeoLocations
          : [allGeoLocations.last];

      // Usar la ubicación más reciente como la principal de la visita
      final mainLocation = locationsToSave.last;
      debugPrint('📍 Ubicación principal: lat=${mainLocation.latitude}, lon=${mainLocation.longitude}');
      debugPrint('📍 Total geolocalizaciones de los últimos 5 segundos: ${locationsToSave.length}');

      // Obtener visitDetails filtrados
      final visitDetails = FFAppState().visitDetails;
      final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();

      // Insertar Visita + detalles + geolocalizaciones en una transacción.
      // Usa GlobalDbSingleton.executeOperation: conexión compartida +
      // retry automático en locked/busy/database_closed (3 intentos).
      int visitId = 0;
      await globalDb.executeOperation((db) async {
        await db.transaction((txn) async {
          // Insertar la visita con el código QR en el campo Rfid
          visitId = await txn.rawInsert('''
            INSERT INTO Visits (
              Id_company, Id_activity, Id_headquarter, Id_product, Id_bulk,
              Id_user, Id_device, Id_status, Created_at, Battery,
              Latitude, Longitude, Altitude, Error_horizontal, Id_virtual_point, Status, Rfid
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            userSelected.idCompany,
            idActivity,
            idHeadquarter,
            0, // Id_product
            0, // Id_bulk
            userSelected.idUser,
            deviceDefault.idDevice,
            0, // Id_status
            DateTime.now().toIso8601String(),
            100, // Battery (valor por defecto)
            mainLocation.latitude,
            mainLocation.longitude,
            mainLocation.altitude,
            mainLocation.errorHorizontal,
            null, // Id_virtual_point
            0, // Status
            qrCode, // Código QR en el campo Rfid
          ]);

          debugPrint('✅ Visita QR creada con ID: $visitId');

          // Insertar detalles de la visita
          int insertedCount = 0;
          for (var detail in detailsToInsert) {
            final idActivityStatus = detail.idActivityStatus;

            final statusCheck = await txn.rawQuery('''
              SELECT Id_activity_status FROM Activities_status WHERE Id_activity_status = ?
            ''', [idActivityStatus]);

            if (statusCheck.isEmpty) continue;

            await txn.rawInsert('''
              INSERT INTO Visits_details (Id_visit, Id_activity_status, Status_option, Status_response)
              VALUES (?, ?, ?, ?)
            ''', [visitId, idActivityStatus, detail.statusOption, detail.statusResponse]);

            insertedCount++;
          }

          debugPrint('✅ $insertedCount detalles de visita insertados');

          // Insertar las geolocalizaciones
          for (var geoPoint in locationsToSave) {
            await txn.rawInsert('''
              INSERT INTO Visits_locations (Id_visit, Latitude, Longitude, Altitude, HorizontalError, CreatedAt)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              visitId,
              geoPoint.latitude,
              geoPoint.longitude,
              geoPoint.altitude,
              geoPoint.errorHorizontal,
              geoPoint.dateHourRead?.toIso8601String() ?? DateTime.now().toIso8601String(),
            ]);
          }

          debugPrint('✅ ${locationsToSave.length} ubicaciones GPS insertadas');
        });
      });

      // Actualizar el contador de visitas y limpiar visitDetails completamente
      FFAppState().update(() {
        FFAppState().visitCount = FFAppState().visitCount + 1;
        FFAppState().visitDetails = [];
      });

      debugPrint('🧹 visitDetails limpiado completamente después de guardar visita QR');
      debugPrint('✅ Visita QR completada exitosamente. ID: $visitId');
      unawaited(actions.announceVisitVoice());
      return true;
    } catch (e) {
      debugPrint('❌ Error creando visita QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al guardar la visita: $e',
                    style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return false;
    }
  }

  // ============================================================================
  // AUTO-GUARDADO AL RECIBIR TAG ADB (tag-transfer-adb-server)
  // ============================================================================

  /// Guarda automáticamente una visita en SQLite cada vez que se recibe un tag
  /// desde Android vía el puente ADB. No limpia visitDetails (el usuario puede
  /// seguir usando el formulario y generar más visitas).
  Future<void> _autoSaveVisitFromAdbTag(int adbStatusId, String rawTagJson) async {
    try {
      debugPrint('💾 ===== AUTO-GUARDANDO VISITA DESDE ADB TAG (statusId=$adbStatusId) =====');
      final currentActivity = FFAppState().currentActivity;
      final idActivity = getJsonField(currentActivity, r'$.id_activity');
      final userSelected = FFAppState().userSelected;
      final deviceDefault = FFAppState().deviceDefault;

      // 1. GPS: solicitar a Android vía ADB (Windows) o usar FFAppState (Android)
      Map<String, dynamic>? geoData;
      if (Platforms.isDesktop) {
        geoData = await AdbNfcBridgeService.instance.requestAndWaitGeoLocation();
      }
      if (geoData == null) {
        final geoList = FFAppState().geoLocationsList;
        if (geoList.isNotEmpty) {
          final latest = geoList.reduce((a, b) =>
              (a.dateHourRead?.isAfter(b.dateHourRead ?? DateTime(0)) ?? false) ? a : b);
          geoData = {
            'latitude': latest.latitude,
            'longitude': latest.longitude,
            'altitude': latest.altitude,
            'errorHorizontal': latest.errorHorizontal,
          };
        }
      }
      final lat = (geoData?['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (geoData?['longitude'] as num?)?.toDouble() ?? 0.0;
      final alt = (geoData?['altitude'] as num?)?.toDouble() ?? 0.0;
      final errH = (geoData?['errorHorizontal'] as num?)?.toDouble() ?? 0.0;
      debugPrint('📍 GPS obtenido: lat=$lat, lon=$lon');

      // 2. Parsear rawTagJson → RFID del tag destino (tag_from en Read_info)
      String tagFromRfid = '';
      try {
        final decoded = jsonDecode(rawTagJson) as Map<String, dynamic>;
        tagFromRfid = ((decoded['Read_info'] as Map?)?['tag_from'] as String? ?? '').trim();
      } catch (_) {}
      debugPrint('🏷️  Tag destino RFID: "$tagFromRfid"');

      // 3-5. Lookups (Id_product, coordenadas, virtual_point) en una sola
      // executeOperation: conexión compartida del singleton + retry automático
      // en locked/busy/database_closed.
      int idProduct = 0;
      double refLat = lat, refLon = lon;
      int idVirtualPoint = 0;
      double minVpDist = double.infinity;
      await globalDb.executeOperation((db) async {
        // 3. Id_product desde Products WHERE Rfid = tag_from
        if (tagFromRfid.isNotEmpty) {
          final rows = await db.rawQuery(
              'SELECT Id_product FROM Products WHERE Rfid = ? LIMIT 1', [tagFromRfid]);
          if (rows.isNotEmpty) idProduct = (rows.first['Id_product'] as int?) ?? 0;
        }

        // 4. Coordenadas de referencia para VP
        if (idProduct > 0) {
          final coordRows = await db.rawQuery(
              'SELECT Latitude, Longitude FROM Products_coordinates WHERE Id_product = ? LIMIT 1',
              [idProduct]);
          if (coordRows.isNotEmpty) {
            refLat = (coordRows.first['Latitude'] as num?)?.toDouble() ?? lat;
            refLon = (coordRows.first['Longitude'] as num?)?.toDouble() ?? lon;
          }
        }

        // 5. Id_virtual_point: punto virtual más cercano a las coordenadas de referencia
        final vpRows = await db.rawQuery(
            'SELECT Id_virtual_point, Latitude, Longitude FROM Virtual_points '
            'WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL');
        for (final vp in vpRows) {
          final vpLat = (vp['Latitude'] as num?)?.toDouble() ?? 0.0;
          final vpLon = (vp['Longitude'] as num?)?.toDouble() ?? 0.0;
          if (vpLat == 0.0 && vpLon == 0.0) continue;
          final d = _calcHaversineAdb(refLat, refLon, vpLat, vpLon);
          if (d < minVpDist) {
            minVpDist = d;
            idVirtualPoint = (vp['Id_virtual_point'] as int?) ?? 0;
          }
        }
      });
      debugPrint('📦 Id_product: $idProduct');
      debugPrint('📌 Id_virtual_point: $idVirtualPoint (dist: ${minVpDist.toStringAsFixed(0)} m)');

      // 6. Id_headquarter por verificación de polígono
      int idHeadquarter = 0;
      final hqList = FFAppState().headquartersSelectedList;
      if (hqList.isNotEmpty) {
        if (lat != 0.0 || lon != 0.0) {
          final check = await actions.checkLocationInPolygons(lat, lon, hqList);
          idHeadquarter = check.insideHeadquarter?.idHeadquarter
              ?? (check.nearestList.isNotEmpty
                  ? check.nearestList.first.headquarter.idHeadquarter
                  : hqList.first.idHeadquarter);
        } else {
          idHeadquarter = hqList.first.idHeadquarter;
        }
      }
      debugPrint('🏢 Id_headquarter: $idHeadquarter');

      // 7. Construir lista de Visits_details desde el estado actual del formulario
      final detailsToInsert = _buildAllVisitDetails(adbStatusId, rawTagJson);

      // 8. Insertar Visits + Visits_details en una transacción.
      // Usa GlobalDbSingleton.executeOperation: conexión compartida +
      // retry automático en locked/busy/database_closed.
      int visitId = 0;
      await globalDb.executeOperation((db) async {
        await db.transaction((txn) async {
          visitId = await txn.rawInsert('''
            INSERT INTO Visits (
              Id_company, Id_activity, Id_headquarter, Id_product, Id_bulk,
              Id_user, Id_device, Id_status, Created_at, Battery,
              Latitude, Longitude, Altitude, Error_horizontal, Id_virtual_point, Status, Rfid
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
          ''', [
            userSelected.idCompany,
            idActivity,
            idHeadquarter,
            idProduct,
            0,
            userSelected.idUser,
            deviceDefault.idDevice,
            0,
            DateTime.now().toIso8601String(),
            100,
            lat,
            lon,
            alt,
            errH,
            idVirtualPoint > 0 ? idVirtualPoint : null,
            0,
            tagFromRfid.isNotEmpty ? tagFromRfid : null,
          ]);

          debugPrint('✅ Visita ADB creada con ID: $visitId');

          int insertedDetails = 0;
          for (final d in detailsToInsert) {
            final statusCheck = await txn.rawQuery(
                'SELECT Id_activity_status FROM Activities_status WHERE Id_activity_status = ?',
                [d['id_activity_status']]);
            if (statusCheck.isEmpty) continue;
            await txn.rawInsert(
                'INSERT INTO Visits_details (Id_visit, Id_activity_status, Status_option, Status_response) '
                'VALUES (?,?,?,?)',
                [visitId, d['id_activity_status'], d['status_option'], d['status_response']]);
            insertedDetails++;
          }
          debugPrint('✅ $insertedDetails detalles de visita insertados');
        });
      });

      FFAppState().update(() => FFAppState().visitCount = FFAppState().visitCount + 1);

      // Marcar esta visita como activa para los UPDATEs incrementales que
      // dispare el usuario al editar campos del formulario, y desbloquear
      // los inputs (que estaban inactivos hasta el primer tag).
      if (mounted && visitId > 0) {
        setState(() {
          _activeVisitId = visitId;
          _formLocked = false;
          _processingTag = false;
          // Asociar la tarjeta recién insertada (última en _adbTagTimestamps)
          // con el Id_visit en SQLite, para que el botón GUARDAR sepa cuál
          // visita marcar como Status=1 al cerrarla.
          final lastTagIndex = _adbTagTimestamps.length - 1;
          if (lastTagIndex >= 0) {
            _pendingTagIndexToVisitId[lastTagIndex] = visitId;
          }
        });
      } else if (mounted) {
        setState(() => _processingTag = false);
      }

      debugPrint('✅ Auto-visita ADB guardada exitosamente. ID: $visitId');
      if (_voiceEnabled) {
        unawaited(actions.announceVisitVoice());
      }
    } catch (e) {
      debugPrint('❌ _autoSaveVisitFromAdbTag error: $e');
      if (mounted) setState(() => _processingTag = false);
    }
  }

  /// Construye la lista de detalles a insertar en Visits_details recopilando
  /// los valores actuales de todos los status del formulario.
  List<Map<String, dynamic>> _buildAllVisitDetails(int adbStatusId, String rawTagJson) {
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    // Recolectar todos los statuses: raíz + dentro de cada step
    final List<dynamic> allStatuses = [..._cachedActivityStatus];
    for (final step in _cachedActivitySteps) {
      final stepStatuses = getJsonField(step, r'$.activities_status');
      if (stepStatuses is List) allStatuses.addAll(stepStatuses);
    }

    for (final s in allStatuses) {
      final typeStatus =
          (getJsonField(s, r'$.type_status')?.toString() ?? '').toLowerCase();
      final statusId = getJsonField(s, r'$.id_activity_status') as int?;
      final statusName = getJsonField(s, r'$.status_name')?.toString() ?? '';
      final defaultStatus =
          getJsonField(s, r'$.default_status')?.toString() ?? '';
      if (statusId == null) continue;

      final statusResponse = _buildStatusResponse(
        typeStatus: typeStatus,
        statusId: statusId,
        statusName: statusName,
        defaultStatus: defaultStatus,
        adbStatusId: adbStatusId,
        rawTagJson: rawTagJson,
        now: now,
      );

      // INSERT incondicional: incluir TODOS los statuses con un valor por defecto
      // (cadena vacía si _buildStatusResponse retorna null) para que los UPDATEs
      // incrementales posteriores tengan siempre una fila que actualizar.
      results.add({
        'id_activity_status': statusId,
        'status_option': statusName,
        'status_response': statusResponse ?? '',
      });
    }
    return results;
  }

  /// Genera el status_response apropiado para cada tipo de campo del formulario.
  /// Retorna null si el tipo no tiene valor disponible aún (se omite ese detalle).
  String? _buildStatusResponse({
    required String typeStatus,
    required int statusId,
    required String statusName,
    required String defaultStatus,
    required int adbStatusId,
    required String rawTagJson,
    required DateTime now,
  }) {
    String pad2(int v) => v.toString().padLeft(2, '0');

    switch (typeStatus) {
      case 'date':
        return '${pad2(now.day)}/${pad2(now.month)}/${now.year}';

      case 'time':
        return '${pad2(now.hour)}:${pad2(now.minute)}:${pad2(now.second)}';

      case 'tag-transfer-adb-server':
        final cards = _adbServerCardsRawJson[statusId];
        if (cards != null && cards.isNotEmpty) return cards.last;
        if (statusId == adbStatusId) return rawTagJson;
        return null;

      case 'number':
        final detail = FFAppState()
            .visitDetails
            .where((d) => d.idActivityStatus == statusId)
            .firstOrNull;
        if (detail != null && detail.statusResponse.isNotEmpty) {
          return detail.statusResponse;
        }
        final text = _textControllers[statusId]?.text ?? '';
        return text.isNotEmpty ? text : null;

      case 'numbers-operation':
        return _calculatedValues[statusId]?.toStringAsFixed(2);

      case 'label-info':
        final text = defaultStatus.startsWith('=')
            ? defaultStatus.substring(1)
            : defaultStatus;
        return text.isNotEmpty ? text : (statusName.isNotEmpty ? statusName : null);

      case 'distance-extractor':
        if (!(_distanceExtractorCalculated[statusId] ?? false)) return null;
        return jsonEncode({
          'distanceFromTag': _calculatedDistances[statusId] ?? 0.0,
          'distancesFromProducts': _calculatedDistancesFromProduct[statusId] ?? [],
        });

      case 'headquarter-weight':
        // Preferir el JSON ya serializado en visitDetails (lo guarda
        // _saveHqWeightToVisitDetails con claves String). _calculatedHeadquarterWeights
        // contiene Map<int, ...> que jsonEncode no soporta.
        final detail = FFAppState()
            .visitDetails
            .where((d) => d.idActivityStatus == statusId)
            .firstOrNull;
        if (detail != null && detail.statusResponse.isNotEmpty) {
          return detail.statusResponse;
        }
        return null;

      case 'dynamic-printing-adb':
        // Default inicial: "NO" (no impreso). El UPDATE pasará a "SI"
        // cuando el usuario oprima IMPRIMIR en el dialog de previsualización.
        return 'NO';

      default:
        // Para tipos no listados buscar en visitDetails
        final detail = FFAppState()
            .visitDetails
            .where((d) => d.idActivityStatus == statusId)
            .firstOrNull;
        if (detail != null && detail.statusResponse.isNotEmpty) {
          return detail.statusResponse;
        }
        return null;
    }
  }

  // ============================================================================
  // HIDRATACIÓN: cargar visitas pendientes (Status=0) al entrar a la página
  // y rehidratar el formulario cuando se selecciona una tarjeta.
  // ============================================================================

  /// Carga del SQLite todas las visitas pendientes (Status=0) del Id_activity
  /// actual, las inserta como tarjetas en el panel ADB izquierdo y auto-
  /// selecciona la más reciente, hidratando el formulario.
  Future<void> _loadPendingVisitsFromSQLite() async {
    try {
      final currentActivity = FFAppState().currentActivity;
      final idActivity = getJsonField(currentActivity, r'$.id_activity') as int?;
      if (idActivity == null) return;

      final db = await GlobalDbSingleton().database;

      // 1. Visitas pendientes ordenadas por más reciente primero.
      final visitRows = await db.rawQuery('''
        SELECT v.Id_visit, v.Created_at, v.Id_product, p.Name_product
        FROM Visits v
        LEFT JOIN Products p ON v.Id_product = p.Id_product
        WHERE v.Status = 0 AND v.Id_activity = ?
        ORDER BY v.Created_at DESC
      ''', [idActivity]);

      if (visitRows.isEmpty) return;

      final serverStatusId = _adbServerStatusId;
      // Para cada visita pendiente: tomar el Status_response del detalle de
      // tipo tag-transfer-adb-server y rellenar las estructuras del panel.
      for (final v in visitRows) {
        final visitId = v['Id_visit'] as int;
        final createdAtStr = v['Created_at'] as String?;
        final productName = (v['Name_product'] as String?) ?? '';
        DateTime? createdAt;
        if (createdAtStr != null) {
          createdAt = DateTime.tryParse(createdAtStr);
        }

        // Obtener el rawTagJson asociado a esta visita.
        String rawTagJson = '';
        if (serverStatusId != null) {
          final detailRows = await db.rawQuery('''
            SELECT vd.Status_response
            FROM Visits_details vd
            INNER JOIN Activities_status a
              ON a.Id_activity_status = vd.Id_activity_status
            WHERE vd.Id_visit = ?
              AND LOWER(a.Type_status) = 'tag-transfer-adb-server'
            LIMIT 1
          ''', [visitId]);
          if (detailRows.isNotEmpty) {
            rawTagJson = (detailRows.first['Status_response'] as String?) ?? '';
          }
        }

        if (!mounted) return;
        setState(() {
          _adbTagTimestamps.add(createdAt ?? DateTime.now());
          final idx = _adbTagTimestamps.length - 1;
          _pendingTagIndexToVisitId[idx] = visitId;

          if (serverStatusId != null) {
            _adbServerCardsRawJson[serverStatusId] ??= [];
            _adbServerCardsProductName[serverStatusId] ??= [];
            _adbServerCardsData[serverStatusId] ??= [];
            _adbServerCardsRawJson[serverStatusId]!.add(rawTagJson);
            _adbServerCardsProductName[serverStatusId]!.add(productName);
            if (rawTagJson.isNotEmpty) {
              try {
                _adbServerCardsData[serverStatusId]!
                    .add(_parseNfcTagContent(rawTagJson));
              } catch (_) {
                _adbServerCardsData[serverStatusId]!.add([]);
              }
            } else {
              _adbServerCardsData[serverStatusId]!.add([]);
            }
          }
        });
      }

      // 2. Auto-seleccionar la más reciente (índice 0 fue la primera insertada
      // arriba, ordenadas DESC). Rehidratar el formulario con sus detalles.
      if (_pendingTagIndexToVisitId.isNotEmpty) {
        final firstIdx = _pendingTagIndexToVisitId.keys.first;
        final firstVisitId = _pendingTagIndexToVisitId[firstIdx]!;
        if (mounted) {
          setState(() {
            _selectedAdbTagIndex = firstIdx;
            // Reflejar en el árbol inline el contenido del primer tag.
            if (serverStatusId != null) {
              final cards = _adbServerCardsData[serverStatusId];
              if (cards != null && firstIdx < cards.length) {
                _tagReaderData[serverStatusId] = cards[firstIdx];
                _tagReaderProductName[serverStatusId] =
                    _adbServerCardsProductName[serverStatusId]?[firstIdx] ?? '';
              }
            }
          });
        }
        await _hydrateVisitInForm(firstVisitId);
      }
    } catch (e) {
      debugPrint('❌ _loadPendingVisitsFromSQLite error: $e');
    }
  }

  /// Rellena los controllers/maps del formulario con los Visits_details de
  /// la visita indicada. Hace UN solo SELECT con JOIN a Activities_status para
  /// obtener Type_status. Luego despacha por tipo.
  Future<void> _hydrateVisitInForm(int visitId) async {
    try {
      final db = await GlobalDbSingleton().database;

      final rows = await db.rawQuery('''
        SELECT vd.Id_activity_status, vd.Status_option, vd.Status_response,
               a.Type_status, a.Status_name, a.Default_status,
               a.Remember_status, a.Id_activity_step_parent
        FROM Visits_details vd
        LEFT JOIN Activities_status a
          ON a.Id_activity_status = vd.Id_activity_status
        WHERE vd.Id_visit = ?
        ORDER BY vd.Id_visit_detail
      ''', [visitId]);

      final newDetails = <VisitsDetailsStruct>[];

      for (final r in rows) {
        final idStatus = (r['Id_activity_status'] as int?) ?? 0;
        if (idStatus == 0) continue;
        final statusOption = (r['Status_option'] as String?) ?? '';
        final statusResponse = (r['Status_response'] as String?) ?? '';
        final typeStatus =
            ((r['Type_status'] as String?) ?? '').toLowerCase();
        final statusName = (r['Status_name'] as String?) ?? statusOption;
        final defaultStatus = (r['Default_status'] as String?) ?? '';
        final rememberStatus = (r['Remember_status'] as int?) == 1;
        final idStepParent = (r['Id_activity_step_parent'] as int?) ?? 0;

        // Rellenar la estructura visual según el tipo
        switch (typeStatus) {
          case 'number':
            if (statusResponse.isNotEmpty) {
              _textControllers[idStatus] ??= TextEditingController();
              _textControllers[idStatus]!.text = statusResponse;
              final parsed = double.tryParse(statusResponse);
              if (parsed != null) _statusValuesByName[statusName] = parsed;
            }
            break;
          case 'numbers-operation':
            final parsed = double.tryParse(statusResponse);
            if (parsed != null) {
              _calculatedValues[idStatus] = parsed;
              _numbersOperationCalculated[idStatus] = true;
            }
            break;
          case 'distance-extractor':
            if (statusResponse.isNotEmpty) {
              try {
                final m = jsonDecode(statusResponse) as Map<String, dynamic>;
                final dist = (m['distanceFromTag'] as num?)?.toDouble();
                if (dist != null) _calculatedDistances[idStatus] = dist;
                final list = m['distancesFromProducts'];
                if (list is List) {
                  _calculatedDistancesFromProduct[idStatus] =
                      list.cast<Map<String, dynamic>>();
                }
                _distanceExtractorCalculated[idStatus] = true;
              } catch (_) {}
            }
            break;
          case 'headquarter-weight':
            if (statusResponse.isNotEmpty) {
              try {
                final m = jsonDecode(statusResponse) as Map<String, dynamic>;
                _calculatedHeadquarterWeights[idStatus] = m;
              } catch (_) {}
            }
            break;
          case 'tag-transfer-adb-server':
          case 'label-info':
            // tag-transfer-adb-server ya se cargó en _loadPendingVisitsFromSQLite.
            // label-info es estático (default_status); no necesita rehidratar.
            break;
          default:
            break;
        }

        newDetails.add(VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: idStatus,
          statusOption: statusOption,
          statusResponse: statusResponse,
          idStepParent: idStepParent,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: idStepParent,
        ));
      }

      if (!mounted) return;
      setState(() {
        FFAppState().visitDetails = newDetails;
        _activeVisitId = visitId;
        _formLocked = false;
      });

      // Recalcular fórmulas TAG_READER (mismo patrón que el listener del tag
      // ADB en línea ~372): los campos `headquarter-weight` y
      // `distance-extractor` cuyo default_status apunta a TAG_READER:<name>
      // dependen de `_tagReaderData`, que ya quedó poblado por
      // _loadPendingVisitsFromSQLite o por el onTap de _buildAdbTagCard ANTES
      // de invocar _hydrateVisitInForm. Sin estas dos llamadas los campos
      // quedan inertes al rehidratar.
      final List<dynamic> allStatuses = [..._cachedActivityStatus];
      for (final step in _cachedActivitySteps) {
        final stepStatuses = getJsonField(step, r'$.activities_status');
        if (stepStatuses is List) allStatuses.addAll(stepStatuses);
      }
      for (final s in allStatuses) {
        final type = (getJsonField(s, r'$.type_status')?.toString() ?? '')
            .toLowerCase();
        if (type != 'tag-transfer-adb-server') continue;
        final id = getJsonField(s, r'$.id_activity_status') as int?;
        final name = getJsonField(s, r'$.status_name')?.toString() ?? '';
        if (id == null) continue;
        // Fire-and-forget — si fallan tienen su propio try/catch.
        _autoCalculateRelatedDistances(id, name);
        _autoCalculateRelatedHeadquarterWeights(id, name);
      }
    } catch (e) {
      debugPrint('❌ _hydrateVisitInForm error: $e');
    }
  }

  /// Limpia los controllers/maps que renderizan los valores del formulario,
  /// para evitar mezcla al pasar de una visita a otra.
  void _clearFormState() {
    setState(() {
      for (final c in _textControllers.values) {
        c.clear();
      }
      _statusValuesByName.clear();
      _calculatedValues.clear();
      _numbersOperationCalculated.clear();
      _calculatedDistances.clear();
      _calculatedDistancesFromProduct.clear();
      _distanceExtractorCalculated.clear();
      _calculatedHeadquarterWeights.clear();
      FFAppState().visitDetails = [];
    });
  }

  /// Elimina la tarjeta del panel ADB en el índice indicado, ajustando todas
  /// las estructuras que dependen del orden de inserción.
  void _removeTagCardAt(int idx) {
    if (idx < 0 || idx >= _adbTagTimestamps.length) return;
    _adbTagTimestamps.removeAt(idx);
    final sid = _adbServerStatusId;
    if (sid != null) {
      if (_adbServerCardsRawJson[sid] != null &&
          idx < _adbServerCardsRawJson[sid]!.length) {
        _adbServerCardsRawJson[sid]!.removeAt(idx);
      }
      if (_adbServerCardsProductName[sid] != null &&
          idx < _adbServerCardsProductName[sid]!.length) {
        _adbServerCardsProductName[sid]!.removeAt(idx);
      }
      if (_adbServerCardsData[sid] != null &&
          idx < _adbServerCardsData[sid]!.length) {
        _adbServerCardsData[sid]!.removeAt(idx);
      }
    }
  }

  /// Reindexa _pendingTagIndexToVisitId después de eliminar una tarjeta:
  /// las claves > closedIdx se decrementan en 1 para alinearse con las listas
  /// que ya hicieron removeAt.
  void _reindexPendingTagMap(int closedIdx) {
    final entries = _pendingTagIndexToVisitId.entries
        .where((e) => e.key > closedIdx)
        .toList();
    for (final e in entries) {
      _pendingTagIndexToVisitId.remove(e.key);
      _pendingTagIndexToVisitId[e.key - 1] = e.value;
    }
  }

  /// Fórmula de Haversine para uso interno del auto-guardado ADB.
  double _calcHaversineAdb(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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

    // Actualizar el valor numérico en visitDetails directamente
    // NO llamar a _onStatusSelected para evitar duplicados en el breadcrumb
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

    // Actualizar el registro del step padre (idActivityStatus == 0)
    final stepName = getJsonField(parentStep, r'''$.name_step''').toString();
    int stepExistingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
          FFAppState().visitDetails[i].idActivityStatus == 0) {
        stepExistingIndex = i;
        break;
      }
    }

    if (stepExistingIndex >= 0) {
      // Actualizar el registro del step existente
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
      // Crear el registro del step si no existe
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

    // Persistir incrementalmente en SQLite sobre la visita activa (último tag ADB).
    if (_activeVisitId != null && statusId is int) {
      unawaited(actions.updateVisitDetailInSQLite(
        _activeVisitId!,
        statusId,
        statusName,
        newValue.toString(),
      ));
    }

    debugPrint('🔄 Llamando _recalculateOperations()...');
    // Recalcular todas las operaciones que dependen de este valor
    _recalculateOperations();

    // Recalcular fórmulas de headquarter-weight que dependan de este campo
    debugPrint('🔄 Verificando si este campo es usado en fórmulas...');
    await _recalculateHeadquarterWeightFormulas(statusName);

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
  Widget _buildCompactSearchButton(int stepId, {required bool hasValue}) {
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
              ? const Color(0xFFB45309).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExpanded
                ? const Color(0xFFB45309).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.search_rounded,
          size: 16,
          // Blanco cuando el step tiene valor (fondo verde), verde en caso contrario
          color: hasValue ? Colors.white : const Color(0xFFB45309),
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
                    : const Color(0xFFB45309),
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

  // Helper para obtener el tipo de status desde el JSON de la actividad
  String _getStatusTypeById(int statusId) {
    final activityStepsRaw = getJsonField(
      FFAppState().currentActivity,
      r'''$.activity_steps''',
    );

    if (activityStepsRaw == null) return '';

    final activitySteps = activityStepsRaw is List ? activityStepsRaw : [];

    // Buscar recursivamente en todos los steps y sus status
    String searchInSteps(List steps) {
      for (var step in steps) {
        // Buscar en activities_status del step
        final activitiesStatusRaw = getJsonField(step, r'''$.activities_status''');
        final activitiesStatus = activitiesStatusRaw != null
            ? (activitiesStatusRaw is List ? activitiesStatusRaw : [])
            : [];

        for (var status in activitiesStatus) {
          final currentStatusId = getJsonField(status, r'''$.id_activity_status''');
          if (currentStatusId == statusId) {
            return getJsonField(status, r'''$.type_status''')?.toString() ?? '';
          }

          // Buscar en activities_status_childs
          final statusChildsRaw = getJsonField(status, r'''$.activities_status_childs''');
          final statusChilds = statusChildsRaw != null
              ? (statusChildsRaw is List ? statusChildsRaw : [])
              : [];

          for (var childStatus in statusChilds) {
            final childStatusId = getJsonField(childStatus, r'''$.id_activity_status''');
            if (childStatusId == statusId) {
              return getJsonField(childStatus, r'''$.type_status''')?.toString() ?? '';
            }
          }

          // Buscar en activities_steps_childs
          final stepsChildsRaw = getJsonField(status, r'''$.activities_steps_childs''');
          final stepsChilds = stepsChildsRaw != null
              ? (stepsChildsRaw is List ? stepsChildsRaw : [])
              : [];

          if (stepsChilds.isNotEmpty) {
            final result = searchInSteps(stepsChilds);
            if (result.isNotEmpty) return result;
          }
        }
      }
      return '';
    }

    return searchInSteps(activitySteps);
  }

  Widget _buildSelectionBreadcrumb(int stepId, dynamic step) {
    final visitDetails = FFAppState().visitDetails.toList();
    final breadcrumbItems = <Map<String, String>>[];

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

      // Obtener el tipo de step
      final typeStep = getJsonField(currentStep, r'''$.type_step''')?.toString() ?? '';

      // Para container-list, mostrar TODOS los status seleccionados con sus valores
      // Para unique-list y reference-list, mostrar solo el último seleccionado
      if (typeStep.toLowerCase() == 'container-list') {
        // Agregar todos los status con sus respuestas
        for (var visit in stepVisits) {
          // Obtener el tipo de status desde el JSON de la actividad
          final typeStatus = _getStatusTypeById(visit.idActivityStatus).toLowerCase();

          // Determinar el valor a mostrar según el tipo de status
          String displayValue;
          if (typeStatus == 'unique_choice' || typeStatus == 'unique-option') {
            // Para unique_choice y unique-option, NO mostrar el HTML
            displayValue = '';
          } else if (typeStatus == 'photo' ||
              typeStatus == 'video' ||
              typeStatus == 'tag-writer' ||
              typeStatus == 'tag-reader' ||
              typeStatus == 'tag-transfer') {
            displayValue = visit.statusResponse.isNotEmpty ? '1' : '-';
          } else {
            displayValue = visit.statusResponse.isNotEmpty ? visit.statusResponse : '-';
          }

          breadcrumbItems.add({
            'label': visit.statusOption,
            'value': displayValue,
          });
        }

        // Para container-list, no continuar recursivamente (solo mostrar los status de primer nivel)
        return;
      } else {
        // Para unique-list y reference-list, tomar el último seleccionado
        final selectedVisit = stepVisits.last;
        final statusId = selectedVisit.idActivityStatus;

        // Obtener el tipo de status desde el JSON de la actividad
        final typeStatus = _getStatusTypeById(selectedVisit.idActivityStatus).toLowerCase();

        // Para reference-list, el nombre real está en statusResponse, no en statusOption
        final displayName = typeStatus.toLowerCase() == 'reference-list'
            ? selectedVisit.statusResponse
            : selectedVisit.statusOption;

        // Determinar el valor a mostrar según el tipo de step y status
        String displayValue;

        if (typeStep.toLowerCase() == 'unique-list' ||
            typeStatus == 'unique_choice' ||
            typeStatus == 'unique-option') {
          // Para unique-list, unique_choice y unique-option, mostrar el checkmark
          displayValue = selectedVisit.statusResponse.isNotEmpty ? selectedVisit.statusResponse : '';
        } else if (typeStatus == 'photo' ||
            typeStatus == 'video' ||
            typeStatus == 'tag-writer' ||
            typeStatus == 'tag-reader' ||
            typeStatus == 'tag-transfer') {
          // Para photo, video, tag-writer, tag-reader y tag-transfer, mostrar contador simple
          displayValue = selectedVisit.statusResponse.isNotEmpty ? '1' : displayName;
        } else {
          // Para otros casos (reference-list, etc.), mostrar el statusResponse
          displayValue = selectedVisit.statusResponse.isNotEmpty ? selectedVisit.statusResponse : displayName;
        }

        // Agregar el nombre del status seleccionado con su respuesta
        breadcrumbItems.add({
          'label': selectedVisit.statusOption,
          'value': displayValue,
        });

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

                // Buscar la respuesta del child status
                final childVisit = visitDetails.firstWhere(
                  (visit) => visit.idActivityStatus == childStatusId && visit.typeStatus != 'STEP',
                  orElse: () => VisitsDetailsStruct(
                    idVisitDetail: 0,
                    idVisit: 0,
                    idActivityStatus: 0,
                    statusOption: '',
                    statusResponse: '',
                    idStepParent: 0,
                    rememberStatus: false,
                    defaultStatus: '',
                    typeStatus: '',
                    auxStep: 0,
                  ),
                );

                // Obtener el tipo de status desde el JSON de la actividad
                final childTypeStatus = _getStatusTypeById(childVisit.idActivityStatus).toLowerCase();

                // Determinar el valor a mostrar según el tipo de status
                String childDisplayValue;
                if (childTypeStatus == 'unique_choice' || childTypeStatus == 'unique-option') {
                  // Para unique_choice y unique-option, NO mostrar el HTML
                  childDisplayValue = '';
                } else if (childTypeStatus == 'photo' ||
                    childTypeStatus == 'video' ||
                    childTypeStatus == 'tag-writer' ||
                    childTypeStatus == 'tag-reader' ||
                    childTypeStatus == 'tag-transfer') {
                  childDisplayValue = childVisit.statusResponse.isNotEmpty ? '1' : childStatusName;
                } else {
                  childDisplayValue = childVisit.statusResponse.isNotEmpty ? childVisit.statusResponse : childStatusName;
                }

                breadcrumbItems.add({
                  'label': childStatusName,
                  'value': childDisplayValue,
                });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: breadcrumbItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Viñeta (bullet point)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Texto del item con label y value
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${item['label']}: ',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.2,
                          ),
                        ),
                        TextSpan(
                          text: item['value'],
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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

    // Recalcular fórmulas de headquarter-weight que dependan de este campo
    debugPrint('🔄 Verificando si este campo es usado en fórmulas...');
    await _recalculateHeadquarterWeightFormulas(statusName);

    debugPrint('✅ ===== FIN ACTUALIZACIÓN DE VALOR (ROOT STATUS) =====');
    debugPrint('');
  }

  // ===== RANDOM NUMBER CHIP =====

  bool _isRandomNumberStatus(dynamic status) {
    final t = (getJsonField(status, r'''$.type_status''')?.toString() ?? '').toLowerCase();
    if (t != 'number') return false;
    final ds = (getJsonField(status, r'''$.default_status''')?.toString() ?? '').toUpperCase();
    return ds.contains('=RANDOM:');
  }

  Widget _buildRandomNumberChip({
    required int statusId,
    required String statusName,
    required String defaultStatus,
    bool fullWidth = false,
  }) {
    final value = _getCurrentNumberValue(statusId, defaultStatus);
    final formatted = _formatColombianNumber(value);
    final rawString = value.toString();

    final copyBtn = _CopyValueButton(
      value: rawString,
      semanticLabel: 'Copiar número aleatorio',
    );

    if (fullWidth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0D2B1A), Color(0xFF1B4332)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.tag_rounded,
                size: 13, color: Colors.white.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusName,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                formatted,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            copyBtn,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatted,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 7),
          copyBtn,
        ],
      ),
    );
  }

  // ===== CAJONES NUMÉRICOS DEL 1 AL 4 =====

  // Control numérico compacto para root status
  Widget _buildCompactInlineNumberControl({required dynamic status}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();

    if (defaultStatus.toUpperCase().contains('=RANDOM:')) {
      final sName = getJsonField(status, r'''$.status_name''')?.toString() ?? '';
      return _buildRandomNumberChip(
        statusId: statusId is int ? statusId : (statusId as num).toInt(),
        statusName: sName,
        defaultStatus: defaultStatus,
        fullWidth: false,
      );
    }

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
                colors: [Color(0xFF0D2B1A), Color(0xFF0A1F12)],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usedUpDown ? const Color(0xFF1B4332) : const Color(0xFF1A4A2E),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: usedUpDown
                ? const Color(0xFF1B4332).withValues(alpha: 0.4)
                : const Color(0xFF1A4A2E).withValues(alpha: 0.4),
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
                color: usedUpDown ? Colors.white : const Color(0xFFB45309),
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
                  color: usedUpDown ? Colors.white : const Color(0xFFB45309),
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
                color: usedUpDown ? Colors.white : const Color(0xFFB45309),
                size: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _CopyValueButton(
              value: currentValue.toString(),
              semanticLabel: 'Copiar valor numérico',
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

    if (defaultStatus.toUpperCase().contains('=RANDOM:')) return const SizedBox.shrink();

    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    // Verificar si es estilo compacto
    final isCompactStyle = defaultStatus == '=STYLE:COMPACT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solo mostrar los números rápidos si NO es estilo compacto
        if (!isCompactStyle) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (index) {
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
                              const Color(0xFFB45309),
                              const Color(0xFF92400E),
                            ]
                          : [
                              const Color(0xFF0D2B1A),
                              const Color(0xFF0A1F12),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFB45309)
                          : const Color(0xFF1A4A2E),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFFB45309).withValues(alpha: 0.5)
                            : const Color(0xFF1A4A2E).withValues(alpha: 0.5),
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
                            isSelected ? Colors.white : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
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
                Flexible(
                  child: Text(
                    'INGRESAR OTRO NÚMERO',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
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
    bool showValue = true,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();
    if (defaultStatus.toUpperCase().contains('=RANDOM:')) return const SizedBox.shrink();
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
                colors: [Color(0xFF0D2B1A), Color(0xFF0A1F12)],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usedUpDown ? const Color(0xFF1B4332) : const Color(0xFF1A4A2E),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: usedUpDown
                ? const Color(0xFF1B4332).withValues(alpha: 0.4)
                : const Color(0xFF1A4A2E).withValues(alpha: 0.4),
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
                color: usedUpDown ? Colors.white : const Color(0xFFB45309),
                size: 20,
              ),
            ),
          ),

          // Display del número (solo si showValue es true)
          if (showValue)
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
                    color: usedUpDown ? Colors.white : const Color(0xFFB45309),
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
                color: usedUpDown ? Colors.white : const Color(0xFFB45309),
                size: 20,
              ),
            ),
          ),
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _CopyValueButton(
                value: currentValue.toString(),
                semanticLabel: 'Copiar valor numérico',
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
    if (defaultStatus.toUpperCase().contains('=RANDOM:')) return const SizedBox.shrink();
    int currentValue = _getCurrentNumberValue(statusId, defaultStatus);
    bool usedUpDown = _numberUsedUpDown[statusId] ?? false;

    // Verificar si es estilo compacto
    final isCompactStyle = defaultStatus == '=STYLE:COMPACT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solo mostrar los números rápidos si NO es estilo compacto
        if (!isCompactStyle) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (index) {
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
                              const Color(0xFFB45309),
                              const Color(0xFF92400E),
                            ]
                          : [
                              const Color(0xFF0D2B1A),
                              const Color(0xFF0A1F12),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFB45309)
                          : const Color(0xFF1A4A2E),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFFB45309).withValues(alpha: 0.5)
                            : const Color(0xFF1A4A2E).withValues(alpha: 0.5),
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
                            isSelected ? Colors.white : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
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
                Flexible(
                  child: Text(
                    'INGRESAR OTRO NÚMERO',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
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
              _tagWriterProductName[statusId] = FFAppState().nfcLastProductName;
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
          final processedHTML = await _processHTMLPlaceholders(htmlTemplate);
          debugPrint('✅ ===== FIN PROCESAMIENTO DE PLACEHOLDERS =====');
          debugPrint('');
          debugPrint(
              '📄 HTML procesado (primeros 500 chars): ${processedHTML.substring(0, processedHTML.length > 500 ? 500 : processedHTML.length)}...');

          // Construir nombre del PDF: {NumeroRegistro}_{Fecha}_{Hora}_{Producto}
          final pdfRegistro = () {
            final d = FFAppState().visitDetails.firstWhere(
              (x) => x.defaultStatus.toUpperCase().contains('=RANDOM:'),
              orElse: () => VisitsDetailsStruct(),
            );
            return d.statusResponse.isNotEmpty
                ? d.statusResponse
                : DateTime.now().millisecondsSinceEpoch.toString();
          }();
          final pdfNow = DateTime.now();
          final pdfFecha =
              '${pdfNow.day.toString().padLeft(2, '0')}${pdfNow.month.toString().padLeft(2, '0')}${pdfNow.year}';
          final pdfHora =
              '${pdfNow.hour.toString().padLeft(2, '0')}${pdfNow.minute.toString().padLeft(2, '0')}';
          String pdfProducto = '';
          for (final cards in _adbServerCardsRawJson.values) {
            if (cards.isNotEmpty) {
              final j = actions.parseNfcJson(cards.last);
              if (j != null) {
                pdfProducto =
                    ((j['Read_info'] as Map?)?['Name_product'] as String? ?? '')
                        .trim();
                if (pdfProducto.isNotEmpty) break;
              }
            }
          }
          if (pdfProducto.isEmpty) pdfProducto = statusName;
          final pdfFilename =
              '${pdfRegistro}_${pdfFecha}_${pdfHora}_$pdfProducto';

          // Abrir el previsualizador HTML con opción de imprimir y guardar PDF
          if (!mounted) return;
          await actions.previewAndPrintHTML(
            this.context,
            processedHTML,
            statusName,
            pdfFilename: pdfFilename,
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

  Widget _buildDynamicPrintingAdbButton({
    required BuildContext context,
    required String statusName,
    required dynamic status,
    required int statusId,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.mediumImpact();
          try {
            var htmlTemplate =
                getJsonField(status, r'''$.default_status''')?.toString() ?? '';
            if (htmlTemplate.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ No hay plantilla HTML configurada'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }

            htmlTemplate = _decodeHtmlEntities(htmlTemplate);
            final processedHTML = await _processHTMLPlaceholders(htmlTemplate);
            if (!mounted) return;

            // Construir pdfFilename igual que en dynamic-printing normal
            final adbPdfRegistro = () {
              final d = FFAppState().visitDetails.firstWhere(
                (x) => x.defaultStatus.toUpperCase().contains('=RANDOM:'),
                orElse: () => VisitsDetailsStruct(),
              );
              return d.statusResponse.isNotEmpty
                  ? d.statusResponse
                  : DateTime.now().millisecondsSinceEpoch.toString();
            }();
            final adbPdfNow = DateTime.now();
            final adbPdfFilename = '${adbPdfRegistro}_'
                '${adbPdfNow.day.toString().padLeft(2, '0')}${adbPdfNow.month.toString().padLeft(2, '0')}${adbPdfNow.year}_'
                '${adbPdfNow.hour.toString().padLeft(2, '0')}${adbPdfNow.minute.toString().padLeft(2, '0')}_'
                '$statusName';

            if (!mounted) return;
            showDialog(
              context: this.context,
              barrierDismissible: true,
              builder: (dialogContext) => _AdbPrintPreviewDialog(
                html: processedHTML,
                title: statusName,
                pdfFilename: adbPdfFilename,
                onPrinted: () {
                  // Persistir en SQLite: el usuario confirmó IMPRIMIR.
                  if (_activeVisitId != null) {
                    unawaited(actions.updateVisitDetailInSQLite(
                      _activeVisitId!,
                      statusId,
                      statusName,
                      'SI',
                    ));
                  }
                },
              ),
            );
          } catch (e) {
            debugPrint('❌ Error en dynamic-printing-adb preview: $e');
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('❌ Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'PREVISUALIZAR',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Parsea el contenido del tag NFC y lo agrupa por lote (headquarterId)
  /// Retorna un Map donde la clave es el headquarterId y el valor es un Map con la data agregada
  Map<int, Map<String, dynamic>> _parseNfcTagContentByHeadquarter(
      String nfcContent) {
    final Map<int, Map<String, dynamic>> groupedByHeadquarter = {};

    // Verificar si es el nuevo formato JSON
    if (actions.isNewJsonFormat(nfcContent)) {
      debugPrint('✅ TAG-WRITER: Formato JSON detectado');
      final nfcJson = actions.parseNfcJson(nfcContent);

      if (nfcJson != null) {
        // Extraer visitas del JSON usando el helper
        final visits = actions.extractVisitsFromJson(nfcJson);
        debugPrint('📋 TAG-WRITER: ${visits.length} visitas extraídas del JSON');

        // Agrupar por headquarterId usando el helper
        return actions.groupVisitsByHeadquarter(visits);
      }

      return groupedByHeadquarter;
    }

    // Formato antiguo: El contenido puede tener múltiples registros separados por comas
    // Ejemplo: {DH:2025_11_06_13:20:00;OP:4214;OP2:5432;VISITS:50;RESULTS:25;HE:204},{DH:...}
    debugPrint('⚠️ TAG-WRITER: Formato antiguo detectado');

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
            colors: [Color(0xFFB45309), Color(0xFF81C784)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB45309).withValues(alpha: 0.4),
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
    required int statusId,
    required dynamic parentStep,
    required dynamic status,
  }) {
    // Siempre mostrar el icono NFC naranja para leer tag de origen
    // El botón "TRANSFERIR AHORA" y "TRANSFERENCIA EXITOSA" se muestran en el resumen inline
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA500), Color(0xFFD97706)],
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
                      _tagReaderRawJsons.remove(statusId);
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
                    _clearTagTransferFromPrefs(statusId).ignore();
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

  // ===== ADB SERVER INLINE SUMMARY (enriquecido con SQLite) =====

  Widget _buildAdbServerTagInlineSummary({
    required int statusId,
    AdbCardDisplayMode displayMode = AdbCardDisplayMode.tree,
  }) {
    final rawJsons = _adbServerCardsRawJson[statusId];
    debugPrint(
        '🔵 _buildAdbServerTagInlineSummary: statusId=$statusId '
        'displayMode=$displayMode '
        'rawJsons.length=${rawJsons?.length ?? 0}');
    if (rawJsons == null || rawJsons.isEmpty) return const SizedBox.shrink();

    final selectedIndex = _selectedAdbTagIndex.clamp(0, rawJsons.length - 1);
    final rawJson = rawJsons[selectedIndex];

    // Parsear Read_info y Visits del JSON
    Map<String, dynamic>? readInfo;
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      readInfo = decoded['Read_info'] as Map<String, dynamic>?;
    } catch (_) {}

    final idProduct = readInfo?['Id_product'] as int?;
    final tagFrom = (readInfo?['tag_from'] as String? ?? '').trim();
    final idUser = readInfo?['US'] as int?;
    final nameProductDirect = readInfo?['Name_product'] as String? ?? '';

    // Lookup origen (Id_product → Products)
    final String originName;
    if (idProduct != null && _productByIdCache.containsKey(idProduct)) {
      originName = _productByIdCache[idProduct]!.isNotEmpty
          ? _productByIdCache[idProduct]!
          : nameProductDirect;
    } else {
      originName = nameProductDirect;
      if (idProduct != null) _loadProductById(idProduct);
    }

    // Lookup destino (tag_from RFID → Products)
    final String destName;
    if (tagFrom.isNotEmpty && _productByRfidCache.containsKey(tagFrom)) {
      destName = _productByRfidCache[tagFrom]!;
    } else {
      destName = '';
      if (tagFrom.isNotEmpty) _loadProductByRfid(tagFrom);
    }

    // Lookup conductor (US id_user → Users, usa caché existente)
    // Conductor: solo el nombre. La identificación se muestra en su propia
    // fila (IDENTIFICACION = columna Users.Identificacion, fallback Oper_id).
    String driverName = '—';
    String driverIdentificacion = '';
    if (idUser != null) {
      // _getUserName intenta primero usersList, luego caché y finalmente
      // dispara una carga async desde SQLite que llamará setState al
      // completar — la próxima rebuild mostrará el nombre real. Mientras
      // tanto, usamos un fallback descriptivo en vez del id desnudo.
      final resolvedName = _getUserName(idUser.toString());
      final isResolved =
          resolvedName.isNotEmpty && resolvedName != idUser.toString();
      driverName = isResolved ? resolvedName : 'Carguero #$idUser';
      driverIdentificacion = _getUserIdentificacion(idUser);
      if (driverIdentificacion.isEmpty) {
        driverIdentificacion = '$idUser';
      }
    }

    // Parsear visitas para el árbol
    final visitData = _parseNfcTagContent(rawJson);

    // Parsear visits_details inyectado por WRITER_STATUS (status.visits_details)
    List<Map<String, dynamic>> formStatusDetails = const [];
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final statusBlock = decoded['status'] as Map<String, dynamic>?;
      final details = statusBlock?['visits_details'] as List<dynamic>?;
      if (details != null) {
        formStatusDetails =
            details.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    return _buildAdbServerTagCard(
      statusId: statusId,
      originName: originName,
      destName: destName.isNotEmpty ? destName : (tagFrom.isNotEmpty ? tagFrom : '—'),
      driverName: driverName.isNotEmpty ? driverName : '—',
      driverIdentificacion:
          driverIdentificacion.isNotEmpty ? driverIdentificacion : '—',
      visitData: visitData,
      formStatusDetails: formStatusDetails,
      displayMode: displayMode,
    );
  }

  Widget _buildAdbServerTagCard({
    required int statusId,
    required String originName,
    required String destName,
    required String driverName,
    required String driverIdentificacion,
    required List<Map<String, dynamic>> visitData,
    List<Map<String, dynamic>> formStatusDetails = const [],
    AdbCardDisplayMode displayMode = AdbCardDisplayMode.tree,
  }) {
    // Agrupar visitas por lote (mismo que árbol existente)
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (final record in visitData) {
      final heId = record['headquarterId'] as int? ?? 0;
      groupedByHeadquarter.putIfAbsent(heId, () => []).add(record);
    }

    Widget infoRow(
      IconData icon,
      String label,
      String value,
      Color iconColor, {
      String? copyValue,
      String? copySemanticLabel,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            if (copyValue != null && copyValue.isNotEmpty && copyValue != '—') ...[
              const SizedBox(width: 6),
              _CopyValueButton(
                value: copyValue,
                semanticLabel: copySemanticLabel,
                iconSize: 12,
              ),
            ],
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header con Origen / Destino / Conductor / Identificación + visits_details
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Builder(builder: (_) {
              final List<Widget> allInfoRows = [
                infoRow(
                  Icons.inventory_2_outlined,
                  'ORIGEN',
                  originName,
                  const Color(0xFFB45309),
                  copyValue: originName,
                  copySemanticLabel: 'Copiar origen',
                ),
                infoRow(
                  Icons.move_to_inbox_outlined,
                  'DESTINO',
                  destName,
                  const Color(0xFFB45309),
                  copyValue: destName,
                  copySemanticLabel: 'Copiar destino',
                ),
                infoRow(
                  Icons.person_outline_rounded,
                  'CONDUCTOR',
                  driverName,
                  const Color(0xFF42A5F5),
                  copyValue: driverName,
                  copySemanticLabel: 'Copiar conductor',
                ),
                infoRow(
                  Icons.badge_outlined,
                  'IDENTIFICACIÓN',
                  driverIdentificacion,
                  const Color(0xFF42A5F5),
                  copyValue: driverIdentificacion,
                  copySemanticLabel: 'Copiar identificación',
                ),
                ...formStatusDetails.map((d) {
                  final option =
                      (d['status_option'] ?? '').toString().toUpperCase();
                  final response = (d['status_response'] ?? '').toString();
                  return infoRow(
                    Icons.checklist_rounded,
                    option,
                    response.isNotEmpty ? response : '—',
                    const Color(0xFF66BB6A),
                    copyValue: response,
                    copySemanticLabel: option.isNotEmpty
                        ? 'Copiar $option'
                        : 'Copiar valor',
                  );
                }),
              ];

              // En modo tabla (panel DATOS PRINCIPALES) los items se distribuyen
              // en DOS FILAS horizontales con anchos uniformes. En el modo árbol
              // clásico se conserva el apilado vertical legacy.
              if (displayMode != AdbCardDisplayMode.table) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: allInfoRows,
                );
              }

              final perRow = ((allInfoRows.length + 1) / 2).ceil();
              final row1 = allInfoRows.take(perRow).toList();
              final row2 = allInfoRows.skip(perRow).toList();

              Widget hRow(List<Widget> items) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < perRow; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: i < items.length
                            ? items[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  hRow(row1),
                  hRow(row2),
                ],
              );
            }),
          ),
          // ── Separador ─────────────────────────────────────────
          if (groupedByHeadquarter.isNotEmpty)
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          // ── Árbol o tabla de visitas por lote ─────────────────
          if (groupedByHeadquarter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: displayMode == AdbCardDisplayMode.table
                  ? _buildTagOperatorLotesTable(visitData)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: groupedByHeadquarter.entries.map((entry) {
                        return _buildHeadquarterGroup(entry.key, entry.value);
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  // ===== ADB SERVER TOP PANEL =====

  /// Panel lateral izquierdo ADB — reemplaza el antiguo panel horizontal superior.
  /// Muestra el estado de conexión, el botón SOLICITAR LECTURA y las tarjetas
  /// leídas en lista vertical con scroll.
  Widget _buildAdbSidePanel() {
    final sid = _adbServerStatusId;
    final tagCount = sid != null ? (_adbServerCardsData[sid]?.length ?? 0) : 0;

    final isConnected = _adbServerStatus == AdbBridgeStatus.clientConnected;
    final badgeColor = isConnected ? const Color(0xFF92400E) : const Color(0xFFE53935);
    final badgeIcon = isConnected ? Icons.usb_rounded : Icons.usb_off_rounded;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Badge USB/ADB ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
            child: GestureDetector(
              onTap: () async {
                if (_isRestartingAdb) return;
                if (mounted) setState(() => _isRestartingAdb = true);
                if (AdbNfcBridgeService.instance.isServerRunning) {
                  final ok = await AdbNfcBridgeService.instance.retryAdbReverse();
                  if (mounted) {
                    setState(() => _isRestartingAdb = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? '🔗 adb reverse ejecutado — conecta el Android'
                          : '❌ ${AdbNfcBridgeService.instance.adbError ?? 'Error desconocido'}'),
                      backgroundColor: ok ? const Color(0xFF1565C0) : const Color(0xFFE53935),
                      duration: const Duration(seconds: 3),
                    ));
                  }
                } else {
                  await AdbNfcBridgeService.instance.restart();
                  if (mounted) {
                    final ok = AdbNfcBridgeService.instance.adbError == null;
                    setState(() {
                      _adbServerStatus = AdbNfcBridgeService.instance.currentStatus;
                      _isRestartingAdb = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? '🟢 Servidor reiniciado — conecta el Android'
                          : '❌ ${AdbNfcBridgeService.instance.adbError ?? 'Error al reiniciar'}'),
                      backgroundColor: ok ? const Color(0xFF2D6A4F) : const Color(0xFFE53935),
                      duration: const Duration(seconds: 3),
                    ));
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _isRestartingAdb ? const Color(0xFF1565C0) : badgeColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: 0.5), blurRadius: 10)],
                ),
                child: _isRestartingAdb
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'RECONECTANDO...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(badgeIcon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'USB CONECTADO' : 'ADB ESPERANDO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // ── Botón SOLICITAR LECTURA ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: GestureDetector(
              onTap: isConnected
                  ? () {
                      final sent = AdbNfcBridgeService.instance.sendRequestRead();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sent
                                ? '📲 Solicitud enviada al Android'
                                : '⚠️ No hay dispositivo Android conectado'),
                            backgroundColor:
                                sent ? const Color(0xFFB45309) : const Color(0xFFE53935),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF1565C0)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isConnected
                      ? [BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                          blurRadius: 8,
                        )]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nfc_rounded,
                      color: isConnected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SOLICITAR',
                      style: TextStyle(
                        color: isConnected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Separador con label ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'TAGS LEÍDOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
              ],
            ),
          ),

          // ── Lista vertical de tarjetas ───────────────────────────────────
          Expanded(
            child: tagCount == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Esperando\nlectura NFC...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    itemCount: tagCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildAdbTagCard(index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdbTagCard(int index) {
    final isSelected = _selectedAdbTagIndex == index;
    final ts = index < _adbTagTimestamps.length ? _adbTagTimestamps[index] : null;
    String timeStr = '--';
    if (ts != null) {
      final hour12 = ts.hour % 12 == 0 ? 12 : ts.hour % 12;
      final period = ts.hour < 12 ? 'am' : 'pm';
      timeStr =
          '${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year} '
          '${hour12.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')} $period';
    }

    // Obtener el nombre del producto desde el JSON de la tarjeta
    String cardTitle = 'Tarjeta leída ${index + 1}';
    final sid = _adbServerStatusId;
    if (sid != null) {
      // Intentar obtener Name_product del raw JSON
      final rawJsons = _adbServerCardsRawJson[sid];
      if (rawJsons != null && index < rawJsons.length) {
        try {
          final decoded = jsonDecode(rawJsons[index]) as Map<String, dynamic>;
          final readInfo = decoded['Read_info'] as Map<String, dynamic>?;
          final nameFromJson = readInfo?['Name_product'] as String? ?? '';
          if (nameFromJson.isNotEmpty) {
            cardTitle = nameFromJson;
          } else {
            // Fallback al productName del payload
            final pn = _adbServerCardsProductName[sid]?[index] ?? '';
            if (pn.isNotEmpty) cardTitle = pn;
          }
        } catch (_) {
          final pn = _adbServerCardsProductName[sid]?[index] ?? '';
          if (pn.isNotEmpty) cardTitle = pn;
        }
      }
    }

    final isAnimatingOut = _animatingOutTagIndex == index;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInBack,
      offset: isAnimatingOut ? const Offset(-1.4, 0) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: isAnimatingOut ? 0 : 1,
        child: GestureDetector(
          onTap: () async {
            setState(() {
              _selectedAdbTagIndex = index;
              // Actualizar árbol inline con los datos de la tarjeta seleccionada
              final sid = _adbServerStatusId;
              if (sid != null) {
                final cards = _adbServerCardsData[sid];
                if (cards != null && index < cards.length) {
                  _tagReaderData[sid] = cards[index];
                  _tagReaderProductName[sid] =
                      _adbServerCardsProductName[sid]?[index] ?? '';
                  _tagReaderRawJsons.remove(sid);
                }
              }
            });

            // Rehidratar el formulario con la visita asociada a esta tarjeta
            // (si proviene de una pendiente cargada de SQLite o de un tag ya
            // insertado en esta sesión).
            final visitId = _pendingTagIndexToVisitId[index];
            if (visitId != null && visitId != _activeVisitId) {
              _clearFormState();
              await _hydrateVisitInForm(visitId);
            }
          },
          child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFB45309)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFB45309).withValues(alpha: 0.5), blurRadius: 10)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cardTitle,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            Text(
              timeStr,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  // ===== ADB NFC BRIDGE BADGES =====

  Widget _buildAdbServerBadge({required int statusId}) {
    Color bgColor;
    IconData icon;
    String label;
    switch (_adbServerStatus) {
      case AdbBridgeStatus.clientConnected:
        bgColor = const Color(0xFFB45309);
        icon = Icons.usb_rounded;
        label = 'Conectado';
        break;
      case AdbBridgeStatus.waitingForClient:
        bgColor = const Color(0xFFB45309);
        icon = Icons.usb_off_rounded;
        label = 'Esperando';
        break;
      case AdbBridgeStatus.serverDown:
        bgColor = const Color(0xFFE53935);
        icon = Icons.usb_rounded;
        label = 'Inactivo';
        break;
    }
    return GestureDetector(
      onTap: () async {
        if (AdbNfcBridgeService.instance.isServerRunning) {
          await AdbNfcBridgeService.instance.retryAdbReverse();
        } else {
          await AdbNfcBridgeService.instance.start();
        }
        if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: bgColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }

  Widget _buildAdbFromBadge({required int statusId}) {
    final connected = _adbClientConnected;
    final bgColor = connected ? const Color(0xFFB45309) : const Color(0xFFE53935);
    final icon = connected ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded;
    final label = connected ? 'Conectado' : 'Sin conexión';
    return GestureDetector(
      onTap: () async {
        if (!AdbNfcClientService.instance.isConnected) {
          final ok = await AdbNfcClientService.instance.connect();
          if (mounted) setState(() => _adbClientConnected = ok);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: bgColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }

  /// Tarjeta grande para tag-transfer-adb-from — estado de conexión + animación + botón re-lectura.
  Widget _buildAdbFromCard({required int statusId, required BuildContext context, required dynamic status}) {
    final connected = _adbClientConnected;
    final hasData = _tagReaderData.containsKey(statusId);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? [const Color(0xFF0D1B2A), const Color(0xFF1A2F45)]
              : [const Color(0xFF1A0A0A), const Color(0xFF2A1010)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFFE53935).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: connected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : const Color(0xFFE53935).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: iconos animados + estado ──
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  onEnd: () => setState(() {}),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: const Icon(Icons.nfc_rounded, color: Color(0xFF00E5FF), size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (_, t, __) => Opacity(
                    opacity: (t < 0.5 ? t * 2 : (1.0 - t) * 2).clamp(0.3, 1.0),
                    child: Icon(Icons.sync_alt_rounded,
                        color: connected ? const Color(0xFF00E5FF) : const Color(0xFFE53935), size: 28),
                  ),
                  onEnd: () => setState(() {}),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transferencia NFC',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: connected ? const Color(0xFFF59E0B) : const Color(0xFFE53935),
                              boxShadow: [BoxShadow(color: (connected ? const Color(0xFFF59E0B) : const Color(0xFFE53935)).withValues(alpha: 0.6), blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            connected ? 'Servidor conectado' : 'Sin conexión al servidor',
                            style: TextStyle(color: connected ? const Color(0xFFF59E0B) : const Color(0xFFE53935), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!connected)
                  GestureDetector(
                    onTap: () async {
                      final ok = await AdbNfcClientService.instance.connect();
                      if (mounted) setState(() => _adbClientConnected = ok);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.5)),
                      ),
                      child: const Text('Reintentar', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            if (!hasData) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected ? 'Toca para leer un tag NFC y transferirlo' : 'Conecta al servidor para habilitar la lectura',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasData) ...[
              const SizedBox(height: 12),
              _buildTagReaderSummary(statusId: statusId),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: connected ? () async {
                  if (!AdbNfcClientService.instance.isConnected) {
                    final ok = await AdbNfcClientService.instance.connect();
                    if (!mounted) return;
                    setState(() => _adbClientConnected = ok);
                    if (!ok) return;
                  }
                  if (!mounted) return;
                  await showDialog(
                    barrierDismissible: false,
                    context: this.context,
                    builder: (_) => const Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: NfcReadDialogWidget(autoStart: true, isTagTransferMode: false),
                    ),
                  );
                  if (!mounted) return;
                  final nfcContent = FFAppState().nfcRead;
                  if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                    await AdbNfcClientService.instance.sendTagData(tagContent: nfcContent);
                    if (!mounted) return;
                    setState(() {
                      _tagReaderData[statusId] = _parseNfcTagContent(nfcContent);
                      _tagReaderProductName[statusId] = '';
                    });
                  }
                } : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: connected ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF075985)]) : null,
                    color: connected ? null : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: connected ? [const BoxShadow(color: Color(0x440284C7), blurRadius: 12, offset: Offset(0, 4))] : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nfc_rounded, color: connected ? Colors.white : Colors.white38, size: 18),
                      const SizedBox(width: 8),
                      Text('Leer otro tag',
                          style: TextStyle(color: connected ? Colors.white : Colors.white38, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== PARSEO DEL CONTENIDO DEL TAG NFC =====

  List<Map<String, dynamic>> _parseNfcTagContent(String nfcContent) {
    final List<Map<String, dynamic>> parsedData = [];

    // Verificar si es el nuevo formato JSON
    if (actions.isNewJsonFormat(nfcContent)) {
      debugPrint('✅ TAG-READER: Formato JSON detectado');
      final nfcJson = actions.parseNfcJson(nfcContent);

      if (nfcJson != null) {
        // Extraer visitas del JSON usando el helper
        parsedData.addAll(actions.extractVisitsFromJson(nfcJson));
        debugPrint('📋 TAG-READER: ${parsedData.length} visitas extraídas del JSON');
      }

      return parsedData;
    }

    // Formato antiguo: El contenido puede tener múltiples registros separados por comas
    // Ejemplo: {DH:2025_11_06_13:20:00;OP:4214;OP2:5432;VISITS:50;RESULTS:25;HE:204},{DH:...}
    debugPrint('⚠️ TAG-READER: Formato antiguo detectado');

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

  /// Parsea los parámetros de una fórmula que vienen después del &
  /// Ejemplo: "=TARE-DESTARE&Sufijo=Kg" retorna {"Sufijo": "Kg"}
  Map<String, String> _parseFormulaParameters(String formula) {
    final params = <String, String>{};

    // Buscar si hay parámetros después del &
    final ampersandIndex = formula.indexOf('&');
    if (ampersandIndex == -1) return params;

    // Obtener la parte de parámetros
    final paramsString = formula.substring(ampersandIndex + 1);

    // Parsear cada parámetro (formato: Param1=Value1&Param2=Value2)
    final paramPairs = paramsString.split('&');
    for (final pair in paramPairs) {
      final keyValue = pair.split('=');
      if (keyValue.length == 2) {
        params[keyValue[0].trim()] = keyValue[1].trim();
      }
    }

    debugPrint('📋 Parámetros parseados de fórmula: $params');
    return params;
  }

  /// Extrae solo la parte de la fórmula (antes del &)
  /// Ejemplo: "=TARE-DESTARE&Sufijo=Kg" retorna "=TARE-DESTARE"
  String _extractFormulaOnly(String formula) {
    final ampersandIndex = formula.indexOf('&');
    if (ampersandIndex == -1) return formula;
    return formula.substring(0, ampersandIndex);
  }

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

      // Extraer solo la fórmula (sin parámetros después del &)
      String expression = _extractFormulaOnly(formula).trim();

      // Remover el prefijo "=" si existe
      if (expression.startsWith('=')) {
        expression = expression.substring(1);
      }
      debugPrint('📝 Expresión después de remover "=" y parámetros: "$expression"');

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

    // Persistir incrementalmente en SQLite sobre la visita activa.
    if (_activeVisitId != null && statusId is int) {
      unawaited(actions.updateVisitDetailInSQLite(
        _activeVisitId!,
        statusId,
        statusName,
        result.toString(),
      ));
    }
  }

  // ===== PERSISTENCIA DE RESULTADOS DE headquarter-weight =====

  /// Persiste el resultado de un campo headquarter-weight en FFAppState().visitDetails.
  /// Se llama desde los tres tipos de cálculo (traditional, formula, distribution)
  /// justo después de que el resultado es almacenado en el mapa en memoria.
  ///
  /// [statusId]   ID del activity_status del campo headquarter-weight.
  /// [statusName] Nombre del campo (statusOption).
  /// [resultJson] Mapa ya serializable con los datos del cálculo.
  void _saveHqWeightToVisitDetails(
    int statusId,
    String statusName,
    Map<String, dynamic> resultJson,
  ) {
    try {
      final String jsonString = jsonEncode(resultJson);

      // Buscar parentStepId desde la definición de la actividad
      int parentStepId = 0;
      try {
        final activityStepsRaw =
            getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');
        if (activityStepsRaw != null) {
          final activitySteps = activityStepsRaw.toList();
          outer:
          for (var step in activitySteps) {
            final stepId = getJsonField(step, r'''$.id_activity_step''');
            final statusListRaw = getJsonField(step, r'''$.activity_status''');
            if (statusListRaw == null) continue;
            for (var s in statusListRaw.toList()) {
              if (getJsonField(s, r'''$.id_activity_status''') == statusId) {
                parentStepId = stepId;
                break outer;
              }
            }
          }
        }
      } catch (_) {}

      // Buscar si ya existe una entrada para este statusId
      final int existingIndex = FFAppState()
          .visitDetails
          .indexWhere((d) => d.idActivityStatus == statusId);

      if (existingIndex >= 0) {
        final detail = FFAppState().visitDetails[existingIndex];
        FFAppState().updateVisitDetailsAtIndex(
          existingIndex,
          (_) => VisitsDetailsStruct(
            idVisitDetail: detail.idVisitDetail,
            idVisit: detail.idVisit,
            idActivityStatus: statusId,
            statusOption: statusName,
            statusResponse: jsonString,
            idStepParent: parentStepId,
            rememberStatus: detail.rememberStatus,
            defaultStatus: detail.defaultStatus,
            typeStatus: 'headquarter-weight',
            auxStep: parentStepId,
          ),
        );
        debugPrint('   ✅ HQ-Weight persistido en visitDetails[index=$existingIndex]');
      } else {
        FFAppState().addToVisitDetails(
          VisitsDetailsStruct(
            idVisitDetail: 0,
            idVisit: 0,
            idActivityStatus: statusId,
            statusOption: statusName,
            statusResponse: jsonString,
            idStepParent: parentStepId,
            rememberStatus: false,
            defaultStatus: '',
            typeStatus: 'headquarter-weight',
            auxStep: parentStepId,
          ),
        );
        debugPrint('   ✅ HQ-Weight añadido a visitDetails');
      }

      // Persistir incrementalmente en SQLite sobre la visita activa.
      if (_activeVisitId != null) {
        unawaited(actions.updateVisitDetailInSQLite(
          _activeVisitId!,
          statusId,
          statusName,
          jsonString,
        ));
      }
    } catch (e) {
      debugPrint('⚠️ Error persistiendo HQ-Weight en visitDetails: $e');
    }
  }

  // ===== CARGAR WEIGHTS DE HEADQUARTERS DESDE SQLITE =====

  /// Carga los weights de headquarters desde SQLite para el mes/año actual
  /// También identifica los lotes que NO tienen peso promedio configurado
  /// Usa la base de datos principal (pathDatabase) con conexión directa
  Future<void> _loadHeadquarterWeights(List<int> headquarterIds) async {
    try {
      final now = DateTime.now();

      // Calcular mes anterior (manejar rollover de año)
      int previousYear = now.year;
      int previousMonth = now.month - 1;

      if (previousMonth == 0) {
        // Si el mes actual es enero (1), el mes anterior es diciembre (12) del año pasado
        previousMonth = 12;
        previousYear = now.year - 1;
      }

      debugPrint(
          '📊 Cargando weights DEL MES ANTERIOR para ${headquarterIds.length} lotes (año: $previousYear, mes: $previousMonth)');
      debugPrint('   📅 Fecha actual: ${now.year}-${now.month} → Buscando: $previousYear-$previousMonth');

      // Limpiar lista de lotes sin peso antes de cargar
      _headquartersWithoutWeight.clear();

      // Usar la conexión compartida del singleton (NO se cierra después,
      // el singleton es dueño del ciclo de vida y otras consultas concurrentes
      // podrían fallar con database_closed si cerramos aquí).
      final db = await GlobalDbSingleton().database;

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

        // Consultar SQLite directamente con el mes ANTERIOR
        final results = await db.rawQuery('''
          SELECT * FROM Headquarters_weights
          WHERE Id_headquarter = ?
            AND Date_year = ?
            AND Date_month = ?
          LIMIT 1
        ''', [headquarterId, previousYear, previousMonth]);

        if (results.isNotEmpty) {
          final weightData = results.first['Weight'];
          final weight = (weightData is num) ? weightData.toDouble() : 0.0;
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

  /// Calcula el peso total por headquarter: totalResults * weight
  /// Se llama después de leer el tag y cargar los weights
  /// Si se proporciona targetStatusId, solo calcula para ese status
  void _calculateHeadquarterWeightResults(
      int tagReaderStatusId, String tagReaderStatusName,
      {int? targetStatusId, String? targetStatusName}) {
    debugPrint('');
    debugPrint('⚖️ ===== CÁLCULO DE PESO POR HEADQUARTER =====');
    debugPrint('📍 Tag Reader: "$tagReaderStatusName" (ID: $tagReaderStatusId)');
    if (targetStatusId != null) {
      debugPrint('🎯 Calculando solo para statusId: $targetStatusId');
    }
    debugPrint('📋 _tagReaderData tiene ${_tagReaderData.length} entradas');
    debugPrint('📋 _headquarterWeights tiene ${_headquarterWeights.length} pesos');

    // Obtener los datos del tag leído - buscar en TODAS las entradas de _tagReaderData
    List<Map<String, dynamic>> allTagData = [];
    for (var entry in _tagReaderData.entries) {
      debugPrint('   📍 Tag Reader ID: ${entry.key} con ${entry.value.length} registros');
      allTagData.addAll(entry.value);
    }

    if (allTagData.isEmpty) {
      debugPrint('   ❌ No hay datos del tag para calcular');
      return;
    }

    debugPrint('📊 Total de registros encontrados: ${allTagData.length}');

    // Si se especificó targetStatusId, limpiar solo ese cálculo
    // De lo contrario, limpiar todos
    if (targetStatusId != null) {
      _calculatedHeadquarterWeights.remove(targetStatusId);
    } else {
      _calculatedHeadquarterWeights.clear();
    }

    // Agrupar resultados por headquarterId
    final Map<int, int> resultsByHeadquarter = {};
    for (var record in allTagData) {
      final headquarterId = record['headquarterId'] as int? ?? 0;
      final results = record['results'] as int? ?? 0;
      if (headquarterId > 0) {
        resultsByHeadquarter[headquarterId] =
            (resultsByHeadquarter[headquarterId] ?? 0) + results;
      }
    }

    debugPrint('📊 Resultados agrupados por lote:');
    for (var entry in resultsByHeadquarter.entries) {
      debugPrint('   - Lote ${entry.key}: ${entry.value} resultados');
    }

    // Calcular peso para cada headquarter
    final Map<int, Map<String, dynamic>> resultsForThisStatus = {};
    for (var entry in resultsByHeadquarter.entries) {
      final headquarterId = entry.key;
      final totalResults = entry.value;
      final weight = _headquarterWeights[headquarterId];

      if (weight != null) {
        final calculatedWeight = totalResults * weight;

        // Buscar nombre del lote
        String headquarterName = 'Lote $headquarterId';
        try {
          final headquarters = FFAppState().headquartersList.firstWhere(
                (h) => h.idHeadquarter == headquarterId,
                orElse: () => HeadquartersStruct(),
              );
          if (headquarters.nameHeadquarter.isNotEmpty) {
            headquarterName = headquarters.nameHeadquarter;
          }
        } catch (e) {
          // Usar nombre por defecto
        }

        resultsForThisStatus[headquarterId] = {
          'headquarterName': headquarterName,
          'weight': weight,
          'totalResults': totalResults,
          'calculatedWeight': calculatedWeight,
        };

        debugPrint(
            '   ✅ $headquarterName: $totalResults resultados × ${weight.toStringAsFixed(2)} kg = ${calculatedWeight.toStringAsFixed(2)} kg');
      } else {
        debugPrint(
            '   ⚠️ Lote $headquarterId: Sin peso configurado, no se puede calcular');
      }
    }

    // Calcular total general
    double grandTotal = 0;
    for (var data in resultsForThisStatus.values) {
      grandTotal += (data['calculatedWeight'] as double? ?? 0);
    }
    debugPrint('');
    debugPrint('📦 PESO TOTAL CALCULADO: ${grandTotal.toStringAsFixed(2)} kg');

    // Construir fórmula evaluada para mostrar INLINE
    String evaluatedFormula = '';
    if (resultsForThisStatus.length == 1) {
      // Si solo hay un lote, mostrar fórmula simple: "4 × 250 = 1.000,00"
      final data = resultsForThisStatus.values.first;
      final totalResults = data['totalResults'] as int;
      final weight = data['weight'] as double;
      final formattedWeight = _formatNumberForFormula(weight);
      final formattedTotal = _formatDecimal(grandTotal);
      evaluatedFormula = '$totalResults × $formattedWeight = $formattedTotal';
    } else {
      // Si hay múltiples lotes, mostrar suma: "(4×250) + (3×200) = 1.600,00"
      final List<String> parts = [];
      for (var data in resultsForThisStatus.values) {
        final totalResults = data['totalResults'] as int;
        final weight = data['weight'] as double;
        final formattedWeight = _formatNumberForFormula(weight);
        parts.add('($totalResults×$formattedWeight)');
      }
      final formattedTotal = _formatDecimal(grandTotal);
      evaluatedFormula = '${parts.join(' + ')} = $formattedTotal';
    }

    // Guardar resultados usando el statusId como clave
    final statusIdForStorage = targetStatusId ?? tagReaderStatusId;
    _calculatedHeadquarterWeights[statusIdForStorage] = {
      'isFormulaResult': false,
      'resultsByHeadquarter': resultsForThisStatus,
      'grandTotal': grandTotal,
      'evaluatedFormula': evaluatedFormula, // Fórmula para mostrar INLINE
    };

    // Persistir en visitDetails como JSON
    final String statusNameForStorage = targetStatusName ?? tagReaderStatusName;
    final List<Map<String, dynamic>> lotesJson = resultsForThisStatus.entries
        .map((e) => {
              'headquarterId': e.key,
              'headquarterName': e.value['headquarterName'],
              'totalResults': e.value['totalResults'],
              'weight': e.value['weight'],
              'calculatedWeight': e.value['calculatedWeight'],
            })
        .toList();
    _saveHqWeightToVisitDetails(statusIdForStorage, statusNameForStorage, {
      'calculationType': 'traditional',
      'grandTotal': grandTotal,
      'evaluatedFormula': evaluatedFormula,
      'lotes': lotesJson,
    });

    debugPrint('⚖️ ===== FIN CÁLCULO DE PESO =====');
    debugPrint('');
    if (mounted) setState(() {});
  }

  // ===== DISTRIBUCIÓN PROPORCIONAL DE PESO (=CALCULATION_DISTRIBUTION) =====

  /// Calcula la distribución proporcional del peso neto (TARE - DESTARE) entre
  /// los lotes y operadores del TAG leído, usando el peso promedio por racimo
  /// de cada lote como línea base para la proporción.
  Future<void> _calculateDistributionWeights(int statusId, {String statusName = ''}) async {
    debugPrint('');
    debugPrint('📊 ===== INICIO CÁLCULO DE DISTRIBUCIÓN =====');
    debugPrint('📋 StatusId: $statusId');

    // 1. Extraer TARE (búsqueda exacta, luego fallback contains)
    var tareDetail = FFAppState().visitDetails.firstWhere(
          (d) => d.statusOption.toUpperCase() == 'TARE',
          orElse: () => VisitsDetailsStruct(),
        );
    if (tareDetail.statusResponse.isEmpty) {
      tareDetail = FFAppState().visitDetails.firstWhere(
            (d) =>
                d.statusOption.toUpperCase().contains('TARE') &&
                !d.statusOption.toUpperCase().contains('DESTARE'),
            orElse: () => VisitsDetailsStruct(),
          );
    }

    // 2. Extraer DESTARE (búsqueda exacta, luego fallback contains)
    var destareDetail = FFAppState().visitDetails.firstWhere(
          (d) => d.statusOption.toUpperCase() == 'DESTARE',
          orElse: () => VisitsDetailsStruct(),
        );
    if (destareDetail.statusResponse.isEmpty) {
      destareDetail = FFAppState().visitDetails.firstWhere(
            (d) => d.statusOption.toUpperCase().contains('DESTARE'),
            orElse: () => VisitsDetailsStruct(),
          );
    }

    final tare = double.tryParse(tareDetail.statusResponse);
    final destare = double.tryParse(destareDetail.statusResponse);

    if (tare == null || destare == null) {
      debugPrint('   ⚠️ TARE o DESTARE no configurados o no son numéricos');
      setState(() {
        _calculatedDistributions[statusId] = {
          'error': true,
          'errorMessage': 'Configure TARE y DESTARE antes de calcular la distribución',
          'pesoNeto': 0.0,
          'grandTotal': 0.0,
        };
      });
      debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (ERROR) =====');
      debugPrint('');
      return;
    }

    final pesoNeto = tare - destare;
    debugPrint('   💰 TARE: $tare  |  DESTARE: $destare  |  Peso neto: $pesoNeto');

    if (pesoNeto <= 0) {
      debugPrint('   ⚠️ Peso neto ≤ 0: no se puede distribuir');
      setState(() {
        _calculatedDistributions[statusId] = {
          'error': true,
          'errorMessage': 'El peso neto (TARE − DESTARE) debe ser mayor a cero',
          'pesoNeto': pesoNeto,
          'grandTotal': 0.0,
        };
      });
      debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (ERROR) =====');
      debugPrint('');
      return;
    }

    // 3. Recolectar todos los registros del TAG
    final List<Map<String, dynamic>> allTagData = [];
    for (var entry in _tagReaderData.entries) {
      allTagData.addAll(entry.value);
    }

    if (allTagData.isEmpty) {
      debugPrint('   ⚠️ No hay datos de TAG leídos todavía');
      debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (SIN TAG) =====');
      debugPrint('');
      return;
    }

    debugPrint('   📋 Total registros del TAG: ${allTagData.length}');

    // 4. Agrupar resultados por lote (headquarterId)
    final Map<int, int> resultsByLote = {};
    for (var record in allTagData) {
      final hqId = record['headquarterId'] as int? ?? 0;
      final results = record['results'] as int? ?? 0;
      if (hqId > 0) {
        resultsByLote[hqId] = (resultsByLote[hqId] ?? 0) + results;
      }
    }

    debugPrint('   📦 Lotes encontrados: ${resultsByLote.length}');
    for (var e in resultsByLote.entries) {
      debugPrint('      Lote ${e.key}: ${e.value} racimos');
    }

    // 5. Cargar pesos promedio para los lotes si no están cargados
    final loteIds = resultsByLote.keys.toList();
    await _loadHeadquarterWeights(loteIds);

    // Verificar que todos los lotes tienen peso configurado
    final List<Map<String, dynamic>> missingWeights = [];
    for (final hqId in loteIds) {
      if (!_headquarterWeights.containsKey(hqId)) {
        String hqName = 'Lote $hqId';
        try {
          final hq = FFAppState().headquartersList.firstWhere(
                (h) => h.idHeadquarter == hqId,
                orElse: () => HeadquartersStruct(),
              );
          if (hq.nameHeadquarter.isNotEmpty) hqName = hq.nameHeadquarter;
        } catch (_) {}
        missingWeights.add({'headquarterId': hqId, 'headquarterName': hqName});
      }
    }

    if (missingWeights.isNotEmpty) {
      debugPrint('   ⚠️ ${missingWeights.length} lote(s) sin peso promedio configurado');
      setState(() {
        _calculatedDistributions[statusId] = {
          'error': true,
          'errorMessage': 'Hay lotes sin peso promedio configurado',
          'missingWeights': missingWeights,
          'pesoNeto': pesoNeto,
          'grandTotal': 0.0,
        };
      });
      debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (ERROR) =====');
      debugPrint('');
      return;
    }

    // 6–8. Calcular pesos esperados y factor de ajuste
    double pesoEsperadoTotal = 0.0;
    final Map<int, double> pesoEsperadoPorLote = {};
    for (var entry in resultsByLote.entries) {
      final hqId = entry.key;
      final racimos = entry.value;
      final avgWeight = _headquarterWeights[hqId]!;
      final pe = racimos * avgWeight;
      pesoEsperadoPorLote[hqId] = pe;
      pesoEsperadoTotal += pe;
    }

    if (pesoEsperadoTotal == 0) {
      debugPrint('   ⚠️ Peso esperado total es cero: no se puede calcular factor');
      setState(() {
        _calculatedDistributions[statusId] = {
          'error': true,
          'errorMessage': 'El total esperado es cero (sin racimos o sin pesos configurados)',
          'pesoNeto': pesoNeto,
          'grandTotal': 0.0,
        };
      });
      debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (ERROR) =====');
      debugPrint('');
      return;
    }

    final factor = pesoNeto / pesoEsperadoTotal;
    debugPrint('   🔢 Peso esperado total: $pesoEsperadoTotal  |  Factor: $factor');

    // 9. Peso asignado por lote
    final Map<int, double> pesoAsignadoPorLote = {};
    for (var entry in pesoEsperadoPorLote.entries) {
      pesoAsignadoPorLote[entry.key] = entry.value * factor;
    }

    // 10. Construir árbol por lote con detalle de operadores
    double grandTotal = 0.0;
    final Map<int, Map<String, dynamic>> lotesData = {};

    for (final hqId in loteIds) {
      final racimosLote = resultsByLote[hqId]!;
      final avgWeight = _headquarterWeights[hqId]!;
      final pesoEsperado = pesoEsperadoPorLote[hqId]!;
      final pesoAsignado = pesoAsignadoPorLote[hqId]!;
      grandTotal += pesoAsignado;

      String hqName = 'Lote $hqId';
      try {
        final hq = FFAppState().headquartersList.firstWhere(
              (h) => h.idHeadquarter == hqId,
              orElse: () => HeadquartersStruct(),
            );
        if (hq.nameHeadquarter.isNotEmpty) hqName = hq.nameHeadquarter;
      } catch (_) {}

      debugPrint('   🏢 $hqName: $racimosLote rac. × $avgWeight = $pesoEsperado → asignado: $pesoAsignado kg');

      // Agrupar operadores dentro de este lote
      final Map<String, Map<String, dynamic>> opGroups = {};
      for (var record in allTagData) {
        if ((record['headquarterId'] as int? ?? 0) != hqId) continue;
        final opId = record['operatorId'] as String? ?? '';
        final op2Id = record['operator2Id'] as String? ?? '';
        final results = record['results'] as int? ?? 0;
        final opKey = op2Id.isNotEmpty ? '${opId}_$op2Id' : opId;

        if (!opGroups.containsKey(opKey)) {
          opGroups[opKey] = {
            'operatorId': opId,
            'operator2Id': op2Id,
            'operatorName': _getUserName(opId),
            'operator2Name': op2Id.isNotEmpty ? _getCorterName(op2Id) : '',
            'results': 0,
            'pesoOp': 0.0,
          };
        }
        opGroups[opKey]!['results'] = (opGroups[opKey]!['results'] as int) + results;
      }

      // Calcular peso por operador proporcionalmente
      for (var opEntry in opGroups.entries) {
        final opResults = opEntry.value['results'] as int;
        final pesoOp = racimosLote > 0 ? (opResults / racimosLote) * pesoAsignado : 0.0;
        opGroups[opEntry.key]!['pesoOp'] = pesoOp;
        debugPrint('      👤 ${opEntry.value['operatorName']}: $opResults rac. → $pesoOp kg');
      }

      lotesData[hqId] = {
        'headquarterName': hqName,
        'totalResults': racimosLote,
        'avgWeight': avgWeight,
        'pesoEsperado': pesoEsperado,
        'pesoAsignado': pesoAsignado,
        'operators': opGroups.values.toList(),
      };
    }

    debugPrint('   ✅ Total distribuido: $grandTotal kg (peso neto: $pesoNeto kg)');

    setState(() {
      _calculatedDistributions[statusId] = {
        'error': false,
        'pesoNeto': pesoNeto,
        'factor': factor,
        'pesoEsperadoTotal': pesoEsperadoTotal,
        'grandTotal': grandTotal,
        'lotes': lotesData,
      };
    });

    final List<Map<String, dynamic>> lotesJson = lotesData.entries.map((e) {
      final ops = (e.value['operators'] as List?)
              ?.map((op) => Map<String, dynamic>.from(op as Map))
              .toList() ??
          [];
      return {
        'headquarterId': e.key,
        'headquarterName': e.value['headquarterName'],
        'totalResults': e.value['totalResults'],
        'avgWeight': e.value['avgWeight'],
        'pesoEsperado': e.value['pesoEsperado'],
        'pesoAsignado': e.value['pesoAsignado'],
        'operators': ops,
      };
    }).toList();

    _saveHqWeightToVisitDetails(statusId, statusName, {
      'calculationType': 'distribution',
      'pesoNeto': pesoNeto,
      'factor': factor,
      'grandTotal': grandTotal,
      'lotes': lotesJson,
    });

    debugPrint('📊 ===== FIN CÁLCULO DE DISTRIBUCIÓN (ÉXITO) =====');
    debugPrint('');
  }

  /// Busca automáticamente los campos headquarter-weight que referencien el TAG_READER actual
  /// y los calcula automáticamente (ya sea formula o cálculo tradicional)
  Future<void> _autoCalculateRelatedHeadquarterWeights(
      int tagReaderStatusId, String tagReaderName) async {
    try {
      debugPrint('');
      debugPrint(
          '🔍 Buscando headquarter-weight que referencien TAG_READER "$tagReaderName" (ID: $tagReaderStatusId)');

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
      int totalHeadquarterWeights = 0;

      // Función helper para procesar un status y buscar headquarter-weight
      Future<void> processStatus(dynamic status, dynamic parentStep) async {
        final typeStatus =
            getJsonField(status, r'''$.type_status''')?.toString() ?? '';

        if (typeStatus.toLowerCase() == 'headquarter-weight') {
          totalHeadquarterWeights++;
          final statusIdRaw = getJsonField(status, r'''$.id_activity_status''');
          final statusId = statusIdRaw is int ? statusIdRaw : (statusIdRaw as num).toInt();
          final statusName =
              getJsonField(status, r'''$.status_name''')?.toString() ?? '';
          final defaultStatus =
              getJsonField(status, r'''$.default_status''')?.toString() ?? '';

          debugPrint(
              '   📋 headquarter-weight #$totalHeadquarterWeights: "$statusName" (ID: $statusId)');
          debugPrint('      default_status: "$defaultStatus"');
          debugPrint(
              '      Comparando con: "=tag_reader:${tagReaderName.toLowerCase()}"');

          // DISTRIBUCIÓN PROPORCIONAL: no necesita coincidir con ningún TAG_READER
          if (_isDistributionCalculation(defaultStatus)) {
            foundCount++;
            debugPrint('      📊 Detectado como DISTRIBUCIÓN PROPORCIONAL, calculando...');
            final List<int> headquarterIds = [];
            for (var entry in _tagReaderData.entries) {
              for (var record in entry.value) {
                final hqId = record['headquarterId'] as int? ?? 0;
                if (hqId > 0 && !headquarterIds.contains(hqId)) {
                  headquarterIds.add(hqId);
                }
              }
            }
            if (headquarterIds.isNotEmpty) {
              await _loadHeadquarterWeights(headquarterIds);
            }
            await _calculateDistributionWeights(statusId, statusName: statusName);
            return; // no caer en el bloque tagReaderPattern
          }

          // Verificar si este headquarter-weight referencia al tag-reader actual
          final normalizedDefault =
              defaultStatus.trim().toLowerCase().replaceAll(' ', '');
          final tagReaderPattern =
              '=tag_reader:${tagReaderName.toLowerCase()}'.replaceAll(' ', '');

          // Verificar si contiene referencia al TAG_READER
          if (normalizedDefault.contains(tagReaderPattern) ||
              defaultStatus
                  .toLowerCase()
                  .contains('tag_reader:${tagReaderName.toLowerCase()}')) {
            foundCount++;
            debugPrint('      ✅ COINCIDE! Calculando peso...');

            // Verificar si es una fórmula (contiene operadores + variables de formulario)
            final isFormula = _isHeadquarterWeightFormula(defaultStatus);

            if (isFormula) {
              debugPrint('      🧮 Detectado como FÓRMULA, evaluando...');
              await _evaluateHeadquarterWeightFormula(
                statusId,
                defaultStatus,
                tagReaderName,
                statusName: statusName,
              );
            } else {
              debugPrint(
                  '      📊 Detectado como CÁLCULO TRADICIONAL (TAG_READER simple)');

              // IMPORTANTE: Primero cargar los weights desde SQLite
              // Obtener los headquarterIds del tag
              final List<int> headquarterIds = [];
              for (var entry in _tagReaderData.entries) {
                for (var record in entry.value) {
                  final hqId = record['headquarterId'] as int? ?? 0;
                  if (hqId > 0 && !headquarterIds.contains(hqId)) {
                    headquarterIds.add(hqId);
                  }
                }
              }

              if (headquarterIds.isNotEmpty) {
                debugPrint('      📦 Cargando weights para ${headquarterIds.length} lote(s)...');
                await _loadHeadquarterWeights(headquarterIds);
              }

              // Calcular usando el método tradicional, pero especificando el statusId
              _calculateHeadquarterWeightResults(
                tagReaderStatusId,
                tagReaderName,
                targetStatusId: statusId,
                targetStatusName: statusName,
              );
            }
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
          '   Total headquarter-weight encontrados: $totalHeadquarterWeights');
      debugPrint('   Que referencian "$tagReaderName": $foundCount');

      if (foundCount == 0) {
        debugPrint('   ⚠️  No se encontraron coincidencias');
      } else {
        debugPrint('   ✅ Total calculados: $foundCount');
      }
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error en _autoCalculateRelatedHeadquarterWeights: $e');
      debugPrint('');
    }
  }

  /// Formatea un número decimal con formato europeo/latinoamericano
  /// Punto (.) para miles, coma (,) para decimales
  /// Ejemplo: 1234.56 → "1.234,56"
  String _formatDecimal(double value, {int decimals = 2}) {
    final str = value.toStringAsFixed(decimals);
    final parts = str.split('.');
    final integerPart = int.parse(parts[0]);
    final decimalPart = parts[1];

    // Formatear parte entera con puntos como separador de miles
    final intStr = integerPart.toString();
    final reversed = intStr.split('').reversed.toList();
    final List<String> formattedParts = [];

    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formattedParts.add('.');
      }
      formattedParts.add(reversed[i]);
    }

    final formattedInteger = formattedParts.reversed.join('');
    return '$formattedInteger,$decimalPart';
  }

  /// Formatea un número para mostrar en fórmulas con separador de miles
  /// - Enteros: sin decimales, con separador de miles (ej: 20.000)
  /// - Decimales: 2 decimales, con separador de miles (ej: 1.234,56)
  /// Usa formato europeo/latinoamericano: punto para miles, coma para decimales
  String _formatNumberForFormula(double value) {
    // Si es un número entero (sin decimales), formatear sin parte decimal
    if (value == value.toInt()) {
      // Convertir a entero y agregar separador de miles
      final intValue = value.toInt();
      final str = intValue.toString();

      // Agregar puntos como separador de miles
      final reversed = str.split('').reversed.toList();
      final List<String> parts = [];

      for (int i = 0; i < reversed.length; i++) {
        if (i > 0 && i % 3 == 0) {
          parts.add('.');
        }
        parts.add(reversed[i]);
      }

      return parts.reversed.join('');
    } else {
      // Si tiene decimales, formatear con 2 decimales y separador de miles
      final decimalPart = value.toStringAsFixed(2).split('.')[1];
      final integerPart = value.toInt();

      // Formatear parte entera con separador de miles (puntos)
      final str = integerPart.toString();
      final reversed = str.split('').reversed.toList();
      final List<String> parts = [];

      for (int i = 0; i < reversed.length; i++) {
        if (i > 0 && i % 3 == 0) {
          parts.add('.');
        }
        parts.add(reversed[i]);
      }

      final formattedInteger = parts.reversed.join('');
      // Usar coma como separador decimal
      return '$formattedInteger,$decimalPart';
    }
  }

  /// Verifica si el default_status es una fórmula (tiene operadores y variables)
  bool _isHeadquarterWeightFormula(String defaultStatus) {
    // Es fórmula si contiene operadores matemáticos (+, -, *, /) y variables del formulario
    // Las variables pueden ser: TARE, DESTARE, u otros campos del form
    final hasOperators = defaultStatus.contains('+') ||
        defaultStatus.contains('-') ||
        defaultStatus.contains('*') ||
        defaultStatus.contains('/');

    final hasFormVariables = defaultStatus.toUpperCase().contains('TARE') ||
        defaultStatus.toUpperCase().contains('DESTARE');

    return hasOperators && hasFormVariables;
  }

  /// Detecta si el default_status es el modo de distribución proporcional de peso
  bool _isDistributionCalculation(String defaultStatus) {
    return defaultStatus.trim().toUpperCase() == '=CALCULATION_DISTRIBUTION';
  }

  /// Evalúa una fórmula de headquarter-weight
  /// Evalúa una fórmula de tipo headquarter-weight que contiene TAG_READER.
  /// Si la fórmula es exactamente "=(TARE-DESTARE)/TAG_READER:<nombre>", calcula
  /// por lote (un resultado por HE). Para cualquier otra fórmula usa el cálculo
  /// global original (un único resultado).
  Future<void> _evaluateHeadquarterWeightFormula(
    int statusId,
    String formula,
    String tagReaderName, {
    String statusName = '',
  }) async {
    try {
      debugPrint('');
      debugPrint('🧮 ===== EVALUANDO FÓRMULA =====');
      debugPrint('📋 StatusId: $statusId');
      debugPrint('📝 Fórmula original: "$formula"');

      // ── Detectar si es la fórmula por-lote: =(TARE-DESTARE)/TAG_READER:<nombre> ──
      final isPerLoteFormula = RegExp(
        r'^\s*=\s*\(\s*TARE\s*-\s*DESTARE\s*\)\s*/\s*TAG_READER:',
        caseSensitive: false,
      ).hasMatch(formula);

      debugPrint('📊 Modo per-lote: $isPerLoteFormula');

      if (isPerLoteFormula) {
        await _evaluateHeadquarterWeightFormulaPerLote(
          statusId, formula, tagReaderName, statusName: statusName);
      } else {
        await _evaluateHeadquarterWeightFormulaGlobal(
          statusId, formula, tagReaderName, statusName: statusName);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error evaluando fórmula: $e\n$stackTrace');
      debugPrint('🧮 ===== FIN EVALUACIÓN (ERROR) =====');
    }
  }

  /// Cálculo global original: un único resultado para toda la lectura.
  Future<void> _evaluateHeadquarterWeightFormulaGlobal(
    int statusId,
    String formula,
    String tagReaderName, {
    String statusName = '',
  }) async {
    debugPrint('📊 Modo global (un único resultado)');

    // 1. Total de RESULTS
    int tagReaderValue = 0;
    for (final entry in _tagReaderData.entries) {
      for (final record in entry.value) {
        tagReaderValue += record['results'] as int? ?? 0;
      }
    }
    debugPrint('📊 TAG_READER total results: $tagReaderValue');

    if (tagReaderValue == 0) {
      debugPrint('⚠️ TAG_READER es 0, no se puede calcular');
      return;
    }

    // 2. Variables del formulario
    final formVariables = _collectFormVariables();
    if (formVariables.isEmpty) {
      debugPrint('❌ No se encontraron variables (TARE, DESTARE)');
      return;
    }

    // 3. Procesar fórmula
    final tagReaderPattern = RegExp(
      r'TAG_READER:[^\s\)]+(?:\s+[^\s\)]+)*',
      caseSensitive: false,
    );
    String processedFormula = formula.startsWith('=') ? formula.substring(1) : formula;
    processedFormula = processedFormula.replaceAll(tagReaderPattern, tagReaderValue.toString());
    String displayFormula = processedFormula;

    for (final e in formVariables.entries) {
      final pattern = RegExp('\\b${e.key}\\b', caseSensitive: false);
      processedFormula = processedFormula.replaceAllMapped(pattern, (_) => e.value.toString());
      displayFormula = displayFormula.replaceAllMapped(pattern, (_) => _formatNumberForFormula(e.value));
    }

    debugPrint('   Fórmula para cálculo: "$processedFormula"');
    final result = _evaluateMathExpressionWithParentheses(
      processedFormula,
      variables: formVariables,
    );
    debugPrint('✅ Resultado: $result kg');

    _calculatedHeadquarterWeights[statusId] = {
      'isFormulaResult': true,
      'grandTotal': result,
      'formula': formula,
      'evaluatedFormula': displayFormula,
    };
    _saveHqWeightToVisitDetails(statusId, statusName, {
      'calculationType': 'formula',
      'grandTotal': result,
      'formula': formula,
      'evaluatedFormula': displayFormula,
    });

    debugPrint('🧮 ===== FIN EVALUACIÓN (ÉXITO - GLOBAL) =====');
    setState(() {});
  }

  /// Cálculo por lote: =(TARE-DESTARE)/TAG_READER:<nombre>
  /// Sustituye TAG_READER por los racimos de cada HE y produce un resultado por lote.
  Future<void> _evaluateHeadquarterWeightFormulaPerLote(
    int statusId,
    String formula,
    String tagReaderName, {
    String statusName = '',
  }) async {
    debugPrint('🏢 Modo per-lote');

    // 1. Agrupar RESULTS por HE desde _tagReaderData.
    //    _tagReaderData ya contiene los datos de los tags ADB y físicos parseados.
    //    NO usar _adbServerCardsRawJson porque produciría doble conteo.
    final Map<int, int> racimosPorLote = {};

    for (final entry in _tagReaderData.entries) {
      for (final record in entry.value) {
        final heId = record['headquarterId'] as int? ?? 0;
        if (heId == 0) continue;
        racimosPorLote[heId] = (racimosPorLote[heId] ?? 0) + (record['results'] as int? ?? 0);
      }
    }

    debugPrint('📊 Racimos por lote: $racimosPorLote');
    if (racimosPorLote.isEmpty) {
      debugPrint('⚠️ Sin datos de racimos por lote');
      return;
    }

    // 2. Variables del formulario
    final formVariables = _collectFormVariables();

    // 3. Nombres de lote — misma fuente que _buildHeadquarterGroup: headquartersList
    final Map<int, String> loteNames = {};
    for (final hq in FFAppState().headquartersList) {
      if (hq.nameHeadquarter.isNotEmpty) loteNames[hq.idHeadquarter] = hq.nameHeadquarter;
    }
    for (final hq in FFAppState().headquartersSelectedList) {
      if (hq.nameHeadquarter.isNotEmpty) loteNames[hq.idHeadquarter] ??= hq.nameHeadquarter;
    }

    final tagReaderPattern = RegExp(
      r'TAG_READER:[^\s\)]+(?:\s+[^\s\)]+)*',
      caseSensitive: false,
    );

    // 4. Calcular por lote
    final List<Map<String, dynamic>> lotesResult = [];
    double grandTotal = 0.0;

    for (final loteEntry in racimosPorLote.entries) {
      final heId = loteEntry.key;
      final racimos = loteEntry.value;
      if (racimos == 0) continue;

      final loteName = loteNames[heId] ?? 'Lote #$heId';
      String calcF = formula.startsWith('=') ? formula.substring(1) : formula;
      calcF = calcF.replaceAll(tagReaderPattern, racimos.toString());
      String dispF = calcF;

      for (final varEntry in formVariables.entries) {
        final pat = RegExp('\\b${varEntry.key}\\b', caseSensitive: false);
        calcF = calcF.replaceAllMapped(pat, (_) => varEntry.value.toString());
        dispF = dispF.replaceAllMapped(pat, (_) => _formatNumberForFormula(varEntry.value));
      }

      debugPrint('   🏢 $loteName: racimos=$racimos, fórmula=$calcF');
      final result = _evaluateMathExpressionWithParentheses(
        calcF,
        variables: formVariables,
      );
      debugPrint('   ✅ $result kg');

      lotesResult.add({
        'headquarterId': heId,
        'headquarterName': loteName,
        'totalRacimos': racimos,
        'weight': result,
        'evaluatedFormula': '$dispF = ${_formatDecimal(result)} kg',
      });
      grandTotal += result;
    }

    if (lotesResult.isEmpty) {
      debugPrint('⚠️ Sin resultados por lote');
      return;
    }

    final summaryDisplay = lotesResult.length == 1
        ? lotesResult.first['evaluatedFormula'] as String
        : lotesResult.map((l) => '${l['headquarterName']}: ${_formatDecimal(l['weight'] as double)} kg').join(' | ');

    _calculatedHeadquarterWeights[statusId] = {
      'isFormulaResult': true,
      'calculationType': 'formula_per_lote',
      'grandTotal': grandTotal,
      'formula': formula,
      'evaluatedFormula': summaryDisplay,
      'lotes': lotesResult,
    };
    _saveHqWeightToVisitDetails(statusId, statusName, {
      'calculationType': 'formula',
      'grandTotal': grandTotal,
      'formula': formula,
      'evaluatedFormula': summaryDisplay,
      'lotes': lotesResult,
    });

    debugPrint('✅ grandTotal: $grandTotal kg | ${lotesResult.length} lote(s)');
    debugPrint('🧮 ===== FIN EVALUACIÓN (ÉXITO - PER LOTE) =====');
    setState(() {});
  }

  /// Extrae TARE y DESTARE de visitDetails como Map<String, double>.
  Map<String, double> _collectFormVariables() {
    final Map<String, double> vars = {};

    // Recopilar todos los campos del formulario con respuesta numérica
    for (final d in FFAppState().visitDetails) {
      if (d.statusResponse.isNotEmpty && d.statusOption.isNotEmpty) {
        final val = double.tryParse(d.statusResponse);
        if (val != null) {
          vars[d.statusOption.toUpperCase()] = val;
        }
      }
    }

    // Alias TARE para campos cuyo nombre contenga "TARE" (pero no "DESTARE"),
    // por compatibilidad con formularios que no llamen al campo exactamente "TARE"
    if (!vars.containsKey('TARE')) {
      for (final d in FFAppState().visitDetails) {
        if (d.statusOption.toUpperCase().contains('TARE') &&
            !d.statusOption.toUpperCase().contains('DESTARE') &&
            d.statusResponse.isNotEmpty) {
          final val = double.tryParse(d.statusResponse);
          if (val != null) {
            vars['TARE'] = val;
            break;
          }
        }
      }
    }

    return vars;
  }

  /// Obtiene el total de RESULTS de todos los registros del TAG_READER
  /// Evalúa una expresión matemática simple con paréntesis
  /// Soporta: +, -, *, /, ()
  /// Si [variables] se provee, los tokens no-numéricos se resuelven contra el
  /// mapa usando claves normalizadas (uppercase + sin espacios/guiones bajos),
  /// para que p.ej. el token "PESOBRUTO" (resultado de quitar espacios a la
  /// fórmula original "PESO BRUTO") matchee con la variable "Peso bruto".
  double _evaluateMathExpressionWithParentheses(
    String expression, {
    Map<String, double>? variables,
  }) {
    try {
      debugPrint('   🔢 Evaluando: "$expression"');

      // Remover espacios
      expression = expression.replaceAll(' ', '');

      final Map<String, double>? normalizedVars = variables == null
          ? null
          : {
              for (final e in variables.entries)
                e.key.toUpperCase().replaceAll(RegExp(r'[\s_]'), ''): e.value,
            };

      // Evaluar paréntesis recursivamente
      int iterations = 0;
      while (expression.contains('(')) {
        iterations++;
        if (iterations > 100) {
          throw Exception('Demasiadas iteraciones, posible loop infinito');
        }

        final openIndex = expression.lastIndexOf('(');
        final closeIndex = expression.indexOf(')', openIndex);

        if (closeIndex == -1) {
          throw Exception('Paréntesis no balanceados');
        }

        final subExpr = expression.substring(openIndex + 1, closeIndex);
        debugPrint('   📐 Evaluando sub-expresión: "$subExpr"');
        final subResult = _evaluateSimpleMathExpression(subExpr, variables: normalizedVars);
        debugPrint('   📐 Resultado: $subResult');

        expression = expression.substring(0, openIndex) +
            subResult.toString() +
            expression.substring(closeIndex + 1);

        debugPrint('   🔄 Expresión actualizada: "$expression"');
      }

      // Evaluar expresión sin paréntesis
      debugPrint('   📊 Evaluando expresión final: "$expression"');
      final result = _evaluateSimpleMathExpression(expression, variables: normalizedVars);
      debugPrint('   ✅ Resultado final: $result');
      return result;
    } catch (e) {
      debugPrint('   ❌ Error evaluando expresión "$expression": $e');
      return 0.0;
    }
  }

  /// Recalcula todas las fórmulas de headquarter-weight que usen el campo modificado
  Future<void> _recalculateHeadquarterWeightFormulas(String modifiedFieldName) async {
    try {
      debugPrint('🔍 Buscando fórmulas que usen el campo "$modifiedFieldName"...');

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

      int recalculatedCount = 0;

      // Función helper para procesar un status
      Future<void> processStatus(dynamic status) async {
        final typeStatus =
            getJsonField(status, r'''$.type_status''')?.toString() ?? '';

        if (typeStatus.toLowerCase() == 'headquarter-weight') {
          final statusIdRaw = getJsonField(status, r'''$.id_activity_status''');
          final statusId = statusIdRaw is int ? statusIdRaw : (statusIdRaw as num).toInt();
          final statusName =
              getJsonField(status, r'''$.status_name''')?.toString() ?? '';
          final defaultStatus =
              getJsonField(status, r'''$.default_status''')?.toString() ?? '';

          // DISTRIBUCIÓN PROPORCIONAL: se recalcula ante cualquier cambio de TARE/DESTARE
          if (_isDistributionCalculation(defaultStatus)) {
            debugPrint('   📊 Recalculando distribución para "$statusName" (ID: $statusId)');
            await _calculateDistributionWeights(statusId, statusName: statusName);
            recalculatedCount++;
            return;
          }

          // Verificar si la fórmula contiene el campo modificado
          final normalizedFormula = defaultStatus.toUpperCase();
          final normalizedFieldName = modifiedFieldName.toUpperCase();

          if (normalizedFormula.contains(normalizedFieldName)) {
            debugPrint('   ✅ Fórmula encontrada en "$statusName" (ID: $statusId)');
            debugPrint('      Fórmula: "$defaultStatus"');

            // Verificar si es una fórmula (contiene operadores y variables)
            final isFormula = _isHeadquarterWeightFormula(defaultStatus);

            if (isFormula) {
              debugPrint('      🧮 Recalculando fórmula...');

              // Obtener el nombre del TAG_READER referenciado
              final tagReaderPattern = RegExp(
                r'TAG_READER:([^\s\)]+(?:\s+[^\s\)]+)*)',
                caseSensitive: false,
              );
              final match = tagReaderPattern.firstMatch(defaultStatus);
              String tagReaderName = '';
              if (match != null && match.groupCount >= 1) {
                tagReaderName = match.group(1) ?? '';
              }

              if (tagReaderName.isNotEmpty) {
                await _evaluateHeadquarterWeightFormula(
                  statusId,
                  defaultStatus,
                  tagReaderName,
                  statusName: statusName,
                );
                recalculatedCount++;
              } else {
                debugPrint('      ⚠️ No se encontró TAG_READER en la fórmula');
              }
            }
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
            await processStatus(childStatus);
          }
        }

        // Buscar recursivamente en status_childs
        final statusChildsRaw = getJsonField(status, r'''$.status_childs''');
        final statusChilds = statusChildsRaw != null
            ? (statusChildsRaw is List ? statusChildsRaw : [])
            : [];
        for (var childStatus in statusChilds) {
          await processStatus(childStatus);
        }
      }

      // Buscar en steps
      for (var step in activitySteps) {
        final statusListRaw = getJsonField(step, r'''$.activity_status''');
        final statusList = statusListRaw != null
            ? (statusListRaw is List ? statusListRaw : [])
            : [];
        for (var status in statusList) {
          await processStatus(status);
        }
      }

      // Buscar en status raíz
      for (var status in activityStatus) {
        await processStatus(status);
      }

      if (recalculatedCount > 0) {
        debugPrint('✅ $recalculatedCount fórmula(s) recalculada(s)');
        setState(() {});
      } else {
        debugPrint('   ℹ️ No se encontraron fórmulas que usen "$modifiedFieldName"');
      }
    } catch (e) {
      debugPrint('❌ Error en _recalculateHeadquarterWeightFormulas: $e');
    }
  }

  /// Evalúa una expresión matemática simple sin paréntesis
  /// Respeta precedencia de operadores: *, / antes que +, -
  /// [variables] se asume YA normalizado: claves uppercase + sin espacios ni
  /// guiones bajos. Llamado desde [_evaluateMathExpressionWithParentheses]
  /// que se encarga de la normalización.
  double _evaluateSimpleMathExpression(
    String expression, {
    Map<String, double>? variables,
  }) {
    try {
      // Remover espacios
      expression = expression.replaceAll(' ', '');

      if (expression.isEmpty) {
        debugPrint('   ⚠️ Expresión vacía');
        return 0.0;
      }

      // Separar en tokens
      final List<String> tokens = [];
      final buffer = StringBuffer();

      for (int i = 0; i < expression.length; i++) {
        final char = expression[i];
        // Considerar - como negativo si está al inicio o después de operador
        final isNegativeSign = char == '-' &&
            (i == 0 || '+-*/'.contains(expression[i - 1]));

        if ('+-*/'.contains(char) && !isNegativeSign) {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
          tokens.add(char);
        } else {
          buffer.write(char);
        }
      }
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
      }

      debugPrint('      Tokens: $tokens');

      if (tokens.isEmpty) {
        return 0.0;
      }

      // Convertir números (con fallback a variables si no es numérico)
      final List<dynamic> processed = [];
      for (var token in tokens) {
        if ('+-*/'.contains(token)) {
          processed.add(token);
          continue;
        }
        final num = double.tryParse(token);
        if (num != null) {
          processed.add(num);
          continue;
        }
        // Fallback: token no numérico → buscar en variables con clave
        // normalizada (uppercase + sin espacios/guiones bajos). Esto permite
        // que fórmulas con espacios ("PESO BRUTO") sigan funcionando aunque
        // la limpieza previa de espacios haya pegado las palabras
        // ("PESOBRUTO"), o que variantes como "peso_bruto" matcheen también.
        if (variables != null) {
          final key = token.toUpperCase().replaceAll(RegExp(r'[\s_]'), '');
          final v = variables[key];
          if (v != null) {
            debugPrint('      🔁 Variable resuelta: "$token" → $v');
            processed.add(v);
            continue;
          }
        }
        debugPrint('      ⚠️ No se pudo parsear: "$token"');
        return 0.0;
      }

      debugPrint('      Procesados: $processed');

      // Si solo hay un número, retornarlo
      if (processed.length == 1) {
        return processed[0] as double;
      }

      // Procesar * y / primero
      int i = 1;
      while (i < processed.length) {
        if (i >= processed.length - 1) break;

        if (processed[i] == '*') {
          final result = (processed[i - 1] as double) * (processed[i + 1] as double);
          debugPrint('      ${processed[i - 1]} * ${processed[i + 1]} = $result');
          processed.removeRange(i - 1, i + 2);
          processed.insert(i - 1, result);
        } else if (processed[i] == '/') {
          final divisor = processed[i + 1] as double;
          if (divisor == 0) {
            debugPrint('      ⚠️ División por cero');
            return 0.0;
          }
          final result = (processed[i - 1] as double) / divisor;
          debugPrint('      ${processed[i - 1]} / ${processed[i + 1]} = $result');
          processed.removeRange(i - 1, i + 2);
          processed.insert(i - 1, result);
        } else {
          i += 2;
        }
      }

      debugPrint('      Después de */ : $processed');

      // Procesar + y -
      i = 1;
      while (i < processed.length) {
        if (i >= processed.length - 1) break;

        if (processed[i] == '+') {
          final result = (processed[i - 1] as double) + (processed[i + 1] as double);
          debugPrint('      ${processed[i - 1]} + ${processed[i + 1]} = $result');
          processed.removeRange(i - 1, i + 2);
          processed.insert(i - 1, result);
        } else if (processed[i] == '-') {
          final result = (processed[i - 1] as double) - (processed[i + 1] as double);
          debugPrint('      ${processed[i - 1]} - ${processed[i + 1]} = $result');
          processed.removeRange(i - 1, i + 2);
          processed.insert(i - 1, result);
        } else {
          i += 2;
        }
      }

      debugPrint('      Resultado final: ${processed[0]}');
      return processed[0] as double;
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error en _evaluateSimpleMathExpression: $e');
      debugPrint('   Stack: $stackTrace');
      return 0.0;
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

      // ID del tag-reader/ADB asociado (cuando aplica). Se usa también en la
      // OPCIÓN 2 para localizar el JSON del tag (matriz de Visitas) y derivar
      // la lista de lotes con la misma fuente que renderiza el árbol del card.
      int? targetTagReaderId;

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

        // Buscar el statusId del tag-reader (o tag-transfer-adb-server/from) por nombre
        // Tipos de status que actúan como origen de tag
        const tagOriginTypes = {
          'tag-reader',
          'tag-transfer-adb-server',
          'tag-transfer-adb-from',
          'tag-writer',
        };

        // Buscar en root status
        for (var status in activityStatus) {
          final statusName =
              getJsonField(status, r'''$.status_name''')?.toString() ?? '';
          final typeStatus =
              getJsonField(status, r'''$.type_status''')?.toString() ?? '';
          if (tagOriginTypes.contains(typeStatus.toLowerCase()) &&
              statusName.toLowerCase() == tagReaderName.toLowerCase()) {
            targetTagReaderId =
                getJsonField(status, r'''$.id_activity_status''');
            final rawId = targetTagReaderId;
            targetTagReaderId = rawId is int ? rawId : (rawId as num?)?.toInt();
            debugPrint(
                '   ✅ Encontrado en root status: "$statusName" tipo=$typeStatus (ID: $targetTagReaderId)');
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
              if (tagOriginTypes.contains(typeStatus.toLowerCase()) &&
                  statusName.toLowerCase() == tagReaderName.toLowerCase()) {
                final rawId = getJsonField(status, r'''$.id_activity_status''');
                targetTagReaderId = rawId is int ? rawId : (rawId as num?)?.toInt();
                debugPrint(
                    '   ✅ Encontrado en step: "$statusName" tipo=$typeStatus (ID: $targetTagReaderId)');
                break;
              }
            }
            if (targetTagReaderId != null) break;
          }
        }

        if (targetTagReaderId == null) {
          debugPrint(
              '⚠️ No se encontró status TAG_READER/ADB con nombre "$tagReaderName" — procediendo sin coordenadas de origen');
          // No retornar: la Opción 2 (desde producto) aún puede calcularse
        }

        // Ahora buscar las coordenadas en _tagReaderGeolocations usando el ID
        if (targetTagReaderId != null &&
            _tagReaderGeolocations.containsKey(targetTagReaderId)) {
          final geolocation = _tagReaderGeolocations[targetTagReaderId]!;
          originLat = geolocation.latitude;
          originLng = geolocation.longitude;
          debugPrint('✅ Coordenadas encontradas: ($originLat, $originLng)');
        } else {
          debugPrint(
              '⚠️ No hay coordenadas en _tagReaderGeolocations para ID $targetTagReaderId — solo se calculará Opción 2 (desde producto)');
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
      // Solo si se tienen coordenadas de origen (puede ser null para ADB sin geolocalización)
      double distanceFromTag = 0.0;
      if (originLat != null && originLng != null) {
        distanceFromTag = _calculateHaversineDistance(
            originLat, originLng, extractoraLat, extractoraLng);
        debugPrint(
            '📐 Distancia calculada (OPCIÓN 1 - desde TAG): ${distanceFromTag.toStringAsFixed(2)} metros (${(distanceFromTag / 1000).toStringAsFixed(2)} km)');
      } else {
        debugPrint('ℹ️ Sin coordenadas de origen — Opción 1 omitida, solo Opción 2');
      }

      // OPCIÓN 2: calcular distancia desde el punto virtual más bajo (Línea 1, Palma 1) de cada lote
      debugPrint('');
      debugPrint(
          '📦 ===== CALCULANDO OPCIÓN 2 (desde Producto por cada lote) =====');

      // Fuente PRIMARIA: HE únicos del JSON del tag (matriz de Visitas) que está
      // asociado al TAG_READER/ADB que disparó este cálculo. Es la misma fuente
      // que renderiza el árbol _buildAdbServerTagCard → _buildHeadquarterGroup.
      final List<({int id, String name})> lotesToProcess = [];
      final Set<int> uniqueHeIds = {};

      // 1) Records ya parseados del tag-reader/ADB target (poblados al recibir el tag)
      if (targetTagReaderId != null && _tagReaderData[targetTagReaderId] != null) {
        for (final record in _tagReaderData[targetTagReaderId]!) {
          final heId = record['headquarterId'] as int? ?? 0;
          if (heId > 0) uniqueHeIds.add(heId);
        }
        debugPrint(
            '📋 Lotes desde JSON tag (matriz de visitas) tag-reader $targetTagReaderId: ${uniqueHeIds.length}');
      }

      // 2) Si por alguna razón no hay records parseados, leer rawJsons del mismo
      //    statusId y parsear Visits[].HE manualmente (fallback robusto).
      if (uniqueHeIds.isEmpty && targetTagReaderId != null) {
        final rawList = _adbServerCardsRawJson[targetTagReaderId];
        if (rawList != null) {
          for (final rawJson in rawList) {
            try {
              final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
              final visits = decoded['Visits'] as List<dynamic>?;
              if (visits != null) {
                for (final visit in visits) {
                  final he = visit['HE'];
                  if (he != null) {
                    final heId = he is int ? he : (he as num).toInt();
                    if (heId > 0) uniqueHeIds.add(heId);
                  }
                }
              }
            } catch (_) {}
          }
          debugPrint(
              '📋 Lotes desde rawJson de tag-reader $targetTagReaderId: ${uniqueHeIds.length}');
        }
      }

      for (final heId in uniqueHeIds) {
        lotesToProcess.add((id: heId, name: '')); // nombre se resuelve más abajo via SQLite
      }

      // 3) Último recurso: si no hay tag JSON disponible, usar headquartersSelectedList
      //    (caso típico: cálculo manual previo a leer un tag).
      if (lotesToProcess.isEmpty) {
        final selectedHeadquarters = FFAppState().headquartersSelectedList;
        debugPrint(
            '⚠️ Sin JSON tag para tag-reader $targetTagReaderId — fallback a headquartersSelectedList: ${selectedHeadquarters.length}');
        for (final hq in selectedHeadquarters) {
          lotesToProcess.add((
            id: hq.idHeadquarter,
            name: hq.nameHeadquarter.isNotEmpty
                ? hq.nameHeadquarter
                : 'Lote #${hq.idHeadquarter}',
          ));
        }
      }

      // Lista para almacenar las distancias de cada lote
      final List<Map<String, dynamic>> distancesFromProducts = [];

      if (lotesToProcess.isEmpty) {
        debugPrint('⚠️ No hay lotes para calcular — Opción 2 omitida');
      } else {
        // Leer productos desde SQLite (usando el singleton para evitar
        // cerrar la conexión compartida y romper consultas concurrentes)
        try {
          final db = await GlobalDbSingleton().database;

          // Calcular distancia para CADA lote
          for (final loteEntry in lotesToProcess) {
            final loteHeadquarterId = loteEntry.id;
            // Si no tenemos el nombre, consultarlo de la tabla Headquarters
            String loteName = loteEntry.name;
            if (loteName.isEmpty) {
              try {
                final hqRows = await db.query(
                  'Headquarters',
                  columns: ['Name_headquarter'],
                  where: 'Id_headquarter = ?',
                  whereArgs: [loteHeadquarterId],
                  limit: 1,
                );
                if (hqRows.isNotEmpty) {
                  loteName = hqRows.first['Name_headquarter'] as String? ?? 'Lote #$loteHeadquarterId';
                } else {
                  loteName = 'Lote #$loteHeadquarterId';
                }
              } catch (_) {
                loteName = 'Lote #$loteHeadquarterId';
              }
            }

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
          } // fin del for de lotes

          // NO cerrar: la conexión es propiedad de GlobalDbSingleton.
          // Otras consultas concurrentes (p.ej. _loadHeadquarterWeights)
          // fallarían con DatabaseException(database_closed) si cerramos aquí.
        } catch (e) {
          debugPrint('❌ Error consultando SQLite: $e');
        }
      } // fin del bloque de cálculo

      // Guardar TODAS las distancias
      setState(() {
        _calculatedDistances[statusId] = distanceFromTag; // OPCIÓN 1
        if (distancesFromProducts.isNotEmpty) {
          _calculatedDistancesFromProduct[statusId] =
              distancesFromProducts; // OPCIÓN 2 (lista)
        }
        _distanceExtractorCalculated[statusId] = true;
      });

      // Persistir incrementalmente en SQLite sobre la visita activa.
      if (_activeVisitId != null) {
        final statusName =
            getJsonField(status, r'''$.status_name''')?.toString() ?? '';
        final responseJson = jsonEncode({
          'distanceFromTag': distanceFromTag,
          'distancesFromProducts': distancesFromProducts,
        });
        unawaited(actions.updateVisitDetailInSQLite(
          _activeVisitId!,
          statusId,
          statusName,
          responseJson,
        ));
      }

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
            backgroundColor: const Color(0xFFB45309),
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
  /// Si no hay en AppState, busca en SQLite como fallback
  /// Retorna la última geolocalización válida o null si se cancela la espera
  Future<ReadGeoStruct?> _waitForValidGeolocation(BuildContext context) async {
    // Verificar si ya hay una geolocalización válida en AppState
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

    // Siempre mostrar el diálogo para que el usuario pueda elegir entre
    // GPS automático o entrada manual de coordenadas
    debugPrint('⏳ Mostrando diálogo de geolocalización...');

    ReadGeoStruct? result;
    bool cancelled = false;

    // Controladores para entrada manual (creados fuera del builder para no recrearlos)
    final latController = TextEditingController();
    final lonController = TextEditingController();
    // Estado del modo manual (fuera del builder para persistir entre rebuilds)
    bool showManualInput = false;
    String? manualError;

    if (!context.mounted) return null;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {

            // Función local para confirmar entrada manual
            void confirmManual() {
              final lat = double.tryParse(latController.text.trim().replaceAll(',', '.'));
              final lon = double.tryParse(lonController.text.trim().replaceAll(',', '.'));
              if (lat == null || lon == null ||
                  lat < -90 || lat > 90 ||
                  lon < -180 || lon > 180) {
                setState(() {
                  manualError = 'Ingresa coordenadas válidas (lat ±90, lon ±180)';
                });
                return;
              }
              result = ReadGeoStruct(
                latitude: lat,
                longitude: lon,
                altitude: 0.0,
                errorHorizontal: 0.0,
                dateHourRead: DateTime.now(),
              );
              cancelled = false;
              Navigator.of(dialogContext).pop();
            }

            // Verificar periódicamente si hay geolocalización válida (solo si no está en modo manual)
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!cancelled && dialogContext.mounted && !showManualInput) {
                final geo = getLatestValidGeolocation();
                if (geo != null) {
                  result = geo;
                  Navigator.of(dialogContext).pop();
                } else {
                  setState(() {});
                }
              }
            });

            return Dialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!showManualInput) ...[
                      // ── Vista de espera ──
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
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
                      const SizedBox(height: 20),
                      // Botón sutil Visita Manual
                      GestureDetector(
                        onTap: () => setState(() { showManualInput = true; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_location_alt_outlined,
                                  color: Color(0xFF94A3B8), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'VISITA MANUAL',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                    ] else ...[
                      // ── Vista de entrada manual ──
                      Row(
                        children: [
                          const Icon(Icons.edit_location_alt_outlined,
                              color: Color(0xFF60A5FA), size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Ubicación manual',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              showManualInput = false;
                              manualError = null;
                            }),
                            child: const Icon(Icons.close,
                                color: Color(0xFF94A3B8), size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ingresa las coordenadas para registrar la visita',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Latitud
                      TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Latitud',
                          labelStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                          hintText: 'Ej: 5.07285',
                          hintStyle: const TextStyle(
                              color: Color(0xFF475569), fontSize: 13),
                          prefixIcon: const Icon(Icons.north_outlined,
                              color: Color(0xFF60A5FA), size: 18),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF60A5FA)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Campo Longitud
                      TextField(
                        controller: lonController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Longitud',
                          labelStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                          hintText: 'Ej: -75.53112',
                          hintStyle: const TextStyle(
                              color: Color(0xFF475569), fontSize: 13),
                          prefixIcon: const Icon(Icons.east_outlined,
                              color: Color(0xFF60A5FA), size: 18),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF60A5FA)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => confirmManual(),
                      ),
                      if (manualError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          manualError!,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: confirmManual,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB45309),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Confirmar ubicación',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () {
                          cancelled = true;
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    latController.dispose();
    lonController.dispose();

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
    final userId = int.tryParse(operID);
    if (userId != null) {
      // 1. Revisar caché de SQLite
      if (_userNamesCache.containsKey(userId)) {
        final cached = _userNamesCache[userId]!;
        debugPrint('✅ _getUserName: Encontrado en caché SQLite: "$cached"');
        return cached;
      }

      // 2. Buscar en usersList por idUser
      try {
        debugPrint('👤 _getUserName: Intentando buscar por idUser: $userId');
        final userById = FFAppState().usersList.firstWhere(
          (u) => u.idUser == userId,
          orElse: () => UsersStruct(),
        );
        if (userById.nameUser.isNotEmpty) {
          debugPrint('✅ _getUserName: Encontrado por idUser: "${userById.nameUser}"');
          return userById.nameUser;
        }
      } catch (e) {
        debugPrint('❌ Error buscando usuario por idUser en AppState: $e');
      }

      // 3. Fallback: cargar desde SQLite de forma asíncrona
      _loadUserNameFromSQLite(userId);
      debugPrint('⏳ _getUserName: Cargando desde SQLite para idUser=$userId');
    }

    debugPrint('❌ _getUserName: Usuario no encontrado, retornando operID original: "$operID"');
    return operID;
  }

  /// Obtiene el nombre del cortero desde Activities_status usando su IdActivityStatus
  /// El parámetro idActivityStatus es el OP2 que viene del NFC tag
  /// Busca primero en visitDetails (tag-writer), luego en caché, y si no está,
  /// dispara una carga asíncrona desde SQLite
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

    // 1. Primero buscar en visitDetails (funciona para tag-writer)
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

    // 2. Buscar en caché de SQLite
    if (_corteroNamesCache.containsKey(id)) {
      final cachedName = _corteroNamesCache[id]!;
      debugPrint('✅ _getCorterName: Encontrado en caché: "$cachedName"');
      return cachedName;
    }

    // 3. Si no está en caché, disparar carga asíncrona desde SQLite
    _loadCorteroNameFromSQLite(id);

    debugPrint('⏳ _getCorterName: Cargando desde SQLite para idActivityStatus=$id');
    return ''; // Retornará vacío mientras carga, el rebuild lo actualizará
  }

  /// Carga el nombre del cortero desde SQLite y lo guarda en caché
  Future<void> _loadCorteroNameFromSQLite(int idActivityStatus) async {
    try {
      final db = await GlobalDbSingleton().database;
      final result = await db.query(
        'Activities_status',
        columns: ['Status_name'],
        where: 'Id_activity_status = ?',
        whereArgs: [idActivityStatus],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final statusName = result.first['Status_name'] as String? ?? '';
        if (statusName.isNotEmpty) {
          debugPrint('✅ _loadCorteroNameFromSQLite: Encontrado "$statusName" para id=$idActivityStatus');
          _corteroNamesCache[idActivityStatus] = statusName;
          // Forzar rebuild para actualizar la UI
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        debugPrint('❌ _loadCorteroNameFromSQLite: No encontrado en SQLite para id=$idActivityStatus');
      }
    } catch (e) {
      debugPrint('❌ _loadCorteroNameFromSQLite: Error: $e');
    }
  }

  /// Carga el nombre del usuario desde SQLite y lo guarda en caché
  Future<void> _loadUserNameFromSQLite(int idUser) async {
    try {
      final db = await GlobalDbSingleton().database;
      final result = await db.query(
        'Users',
        columns: ['Name_user'],
        where: 'Id_user = ?',
        whereArgs: [idUser],
        limit: 1,
      );
      if (result.isNotEmpty) {
        final name = result.first['Name_user'] as String? ?? '';
        if (name.isNotEmpty) {
          _userNamesCache[idUser] = name;
          if (mounted) setState(() {});
        }
      } else {
        debugPrint('⚠️ _loadUserNameFromSQLite: No encontrado Id_user=$idUser en SQLite');
      }
    } catch (e) {
      debugPrint('❌ _loadUserNameFromSQLite: Error: $e');
    }
  }

  /// Devuelve la identificación visible del conductor (columna `Identificacion`
  /// de la tabla SQLite `Users`). Si está vacía, devuelve el `Oper_id`.
  /// Mientras la consulta a SQLite carga, intenta resolver de inmediato con
  /// `operID` desde `FFAppState().usersList`.
  String _getUserIdentificacion(int idUser) {
    if (_userIdentificacionCache.containsKey(idUser)) {
      return _userIdentificacionCache[idUser]!;
    }
    _loadUserIdentificacionFromSQLite(idUser);
    final user = FFAppState().usersList.firstWhere(
          (u) => u.idUser == idUser,
          orElse: () => UsersStruct(),
        );
    return user.operID;
  }

  Future<void> _loadUserIdentificacionFromSQLite(int idUser) async {
    if (_userIdentificacionLoading.contains(idUser)) return;
    _userIdentificacionLoading.add(idUser);
    try {
      final db = await GlobalDbSingleton().database;
      final result = await db.query(
        'Users',
        columns: ['Identificacion', 'Oper_id'],
        where: 'Id_user = ?',
        whereArgs: [idUser],
        limit: 1,
      );
      String value = '';
      if (result.isNotEmpty) {
        final ident = (result.first['Identificacion'] as String?) ?? '';
        final operId = (result.first['Oper_id'] as String?) ?? '';
        value = ident.isNotEmpty ? ident : operId;
      }
      _userIdentificacionCache[idUser] = value;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ _loadUserIdentificacionFromSQLite: Error: $e');
    } finally {
      _userIdentificacionLoading.remove(idUser);
    }
  }

  /// Carga el nombre del producto desde SQLite por Id_product
  Future<void> _loadProductById(int productId) async {
    if (_productByIdCache.containsKey(productId)) return;
    try {
      final db = await GlobalDbSingleton().database;
      final rows = await db.query(
        'Products',
        columns: ['Name_product'],
        where: 'Id_product = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final name = rows.first['Name_product'] as String? ?? '';
        if (mounted) setState(() => _productByIdCache[productId] = name);
      } else {
        if (mounted) setState(() => _productByIdCache[productId] = '');
      }
    } catch (e) {
      debugPrint('❌ _loadProductById: Error: $e');
    }
  }

  /// Carga el nombre del producto desde SQLite por RFID (columna Rfid)
  Future<void> _loadProductByRfid(String rfid) async {
    if (_productByRfidCache.containsKey(rfid)) return;
    try {
      final db = await GlobalDbSingleton().database;
      final rows = await db.query(
        'Products',
        columns: ['Name_product'],
        where: 'Rfid = ?',
        whereArgs: [rfid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final name = rows.first['Name_product'] as String? ?? '';
        if (mounted) setState(() => _productByRfidCache[rfid] = name);
      } else {
        if (mounted) setState(() => _productByRfidCache[rfid] = '');
      }
    } catch (e) {
      debugPrint('❌ _loadProductByRfid: Error: $e');
    }
  }

  /// Pre-carga TODOS los nombres de usuarios desde SQLite al caché en un solo query.
  /// Se ejecuta en initState para que el árbol de tags tenga nombres listos al expandir.
  Future<void> _preloadUserNamesFromSQLite() async {
    try {
      // Primero intentar poblar desde FFAppState().usersList si ya está cargado
      final appUsers = FFAppState().usersList;
      if (appUsers.isNotEmpty) {
        for (final u in appUsers) {
          if (u.idUser > 0 && u.nameUser.isNotEmpty) {
            _userNamesCache[u.idUser] = u.nameUser;
          }
        }
        debugPrint('✅ _preloadUserNames: ${_userNamesCache.length} usuarios desde AppState');
        if (mounted) setState(() {});
        return;
      }

      // Si AppState vacío, cargar directamente desde SQLite
      final db = await GlobalDbSingleton().database;
      final rows = await db.query('Users', columns: ['Id_user', 'Name_user']);
      int count = 0;
      for (final row in rows) {
        final id = row['Id_user'] as int?;
        final name = row['Name_user'] as String?;
        if (id != null && name != null && name.isNotEmpty) {
          _userNamesCache[id] = name;
          count++;
        }
      }
      debugPrint('✅ _preloadUserNames: $count usuarios cargados desde SQLite');
      if (mounted && count > 0) setState(() {});
    } catch (e) {
      debugPrint('❌ _preloadUserNamesFromSQLite: Error: $e');
    }
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
      _tagReaderRawJsons.remove(statusId);
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

  Future<String> _processHTMLPlaceholders(String htmlTemplate) async {
    String result = htmlTemplate;

    // Buscar todos los placeholders en formato {NombreCampo} o {Campo.subpath}
    // Permite letras, números, espacios, guiones, guiones bajos y puntos
    final placeholderPattern = RegExp(r'\{([a-zA-Z0-9\sáéíóúÁÉÍÓÚñÑ_.-]+)\}');
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
      String replacementValue = await _getPlaceholderValue(fieldName);

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

  Future<String> _getPlaceholderValue(String fieldName) async {
    debugPrint('🔍 Buscando placeholder: "$fieldName"');

    // Notación de punto: {NombreCampo.subpath} → extrae sub-campo del JSON NFC
    if (fieldName.contains('.')) {
      final dotIdx = fieldName.indexOf('.');
      final baseField = fieldName.substring(0, dotIdx).trim();
      final subPath = fieldName.substring(dotIdx + 1).trim();
      return _getNfcJsonSubfieldValue(baseField, subPath);
    }

    // Búsqueda recursiva: cubre steps_childs y status_childs en cualquier nivel
    dynamic targetStatus;
    int? targetStatusId;
    String? targetStatusType;

    void searchInStatus(dynamic status) {
      if (targetStatus != null) return;
      // JSON usa "status_name" (no "name_status")
      final name = getJsonField(status, r'''$.status_name''')?.toString() ?? '';
      if (name.toLowerCase() == fieldName.toLowerCase()) {
        targetStatus = status;
        targetStatusId = getJsonField(status, r'''$.id_activity_status''')?.toInt();
        targetStatusType = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase();
        debugPrint('       ✅ MATCH! id: $targetStatusId, tipo: $targetStatusType');
        return;
      }
      // Recursivo: status hijos (activities_status_childs)
      final statusChilds = getJsonField(status, r'''$.activities_status_childs''')?.toList() ?? [];
      for (var cs in statusChilds) {
        if (targetStatus != null) return;
        searchInStatus(cs);
      }
      // Recursivo: steps hijos → cada step tiene activities_status
      final stepsChilds = getJsonField(status, r'''$.activities_steps_childs''')?.toList() ?? [];
      for (var childStep in stepsChilds) {
        if (targetStatus != null) return;
        final childList = getJsonField(childStep, r'''$.activities_status''')?.toList() ?? [];
        for (var cs in childList) {
          searchInStatus(cs);
        }
      }
    }

    // Buscar en activity_steps → statuses via $.activities_status
    final activityStepsRaw =
        getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');

    if (activityStepsRaw != null) {
      final activitySteps =
          (activityStepsRaw is List) ? activityStepsRaw : [activityStepsRaw];

      for (var step in activitySteps) {
        if (targetStatus != null) break;
        final statusListRaw = getJsonField(step, r'''$.activities_status''');
        if (statusListRaw != null) {
          final statusList =
              (statusListRaw is List) ? statusListRaw : [statusListRaw];
          for (var status in statusList) {
            searchInStatus(status);
            if (targetStatus != null) break;
          }
        }
      }
    }

    // Buscar en root activity_status (singular — es la clave correcta en raíz)
    if (targetStatus == null) {
      final rootStatusListRaw =
          getJsonField(FFAppState().currentActivity, r'''$.activity_status''');
      if (rootStatusListRaw != null) {
        final rootStatusList = (rootStatusListRaw is List)
            ? rootStatusListRaw
            : [rootStatusListRaw];
        for (var status in rootStatusList) {
          if (targetStatus != null) break;
          searchInStatus(status);
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
    // Nota: se usa targetStatusId! porque ya se verificó != null arriba.
    // Dart pierde el type promotion cuando la variable es capturada por un closure.
    final sid = targetStatusId!;

    switch (targetStatusType) {
      case 'date':
        return _getDateValue(sid);

      case 'time':
        return _getTimeValue(sid);

      case 'tag-reader':
        return _getTagReaderPlainText(sid);

      case 'tag-transfer-adb-server':
        return _getAdbServerDestinationValue(sid);

      case 'distance-extractor':
        return _getDistanceExtractorValue(sid);

      case 'number':
        return _getNumberValue(sid);

      case 'numbers-operation':
        return _getNumbersOperationValue(sid);

      case 'label-info':
        final defaultStatus =
            getJsonField(targetStatus, r'''$.default_status''')?.toString() ?? '';
        return defaultStatus.isNotEmpty ? defaultStatus : '[Sin información]';

      case 'text':
        final detailText = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == sid,
              orElse: () => VisitsDetailsStruct(),
            );
        return detailText.statusResponse.isNotEmpty
            ? detailText.statusResponse
            : '[$fieldName]';

      case 'unique-list':
      case 'reference-list':
        final detailList = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == sid,
              orElse: () => VisitsDetailsStruct(),
            );
        return detailList.statusResponse.isNotEmpty
            ? detailList.statusResponse
            : '[$fieldName]';

      default:
        // Para cualquier otro tipo buscar por idActivityStatus
        final detailDefault = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == sid,
              orElse: () => VisitsDetailsStruct(),
            );
        return detailDefault.statusResponse.isNotEmpty
            ? detailDefault.statusResponse
            : '[$fieldName]';
    }
  }

  /// Extrae un sub-campo del JSON NFC de un status tag-reader/tag-writer/tag-transfer.
  /// Uso: {NombreCampo.subPath} en el HTML template.
  Future<String> _getNfcJsonSubfieldValue(String baseField, String subPath) async {
    debugPrint('🔎 NFC subfield: "$baseField.$subPath"');

    // Búsqueda recursiva por name_status == baseField
    int? targetStatusId;
    String? targetStatusType;

    void searchNfcStatus(dynamic status) {
      if (targetStatusId != null) return;
      // JSON usa "status_name" (no "name_status")
      final name = getJsonField(status, r'''$.status_name''')?.toString() ?? '';
      if (name.toLowerCase() == baseField.toLowerCase()) {
        targetStatusId = getJsonField(status, r'''$.id_activity_status''')?.toInt();
        targetStatusType = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase();
        return;
      }
      // Recursivo: status hijos
      final statusChilds = getJsonField(status, r'''$.activities_status_childs''')?.toList() ?? [];
      for (var cs in statusChilds) {
        if (targetStatusId != null) return;
        searchNfcStatus(cs);
      }
      // Recursivo: steps hijos
      final stepsChilds = getJsonField(status, r'''$.activities_steps_childs''')?.toList() ?? [];
      for (var childStep in stepsChilds) {
        if (targetStatusId != null) return;
        final childList = getJsonField(childStep, r'''$.activities_status''')?.toList() ?? [];
        for (var cs in childList) { searchNfcStatus(cs); }
      }
    }

    final stepsRaw = getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');
    if (stepsRaw != null) {
      final steps = stepsRaw is List ? stepsRaw : [stepsRaw];
      for (var step in steps) {
        if (targetStatusId != null) break;
        final sl = getJsonField(step, r'''$.activities_status''');
        if (sl != null) {
          for (var s in (sl is List ? sl : [sl])) {
            searchNfcStatus(s);
          }
        }
      }
    }
    if (targetStatusId == null) {
      final rootRaw = getJsonField(FFAppState().currentActivity, r'''$.activity_status''');
      if (rootRaw != null) {
        for (var s in (rootRaw is List ? rootRaw : [rootRaw])) {
          searchNfcStatus(s);
        }
      }
    }

    if (targetStatusId == null || targetStatusType == null) {
      debugPrint('⚠️ NFC subfield: campo "$baseField" no encontrado');
      return '[$baseField.$subPath]';
    }

    const nfcTypes = {
      'tag-reader', 'tag-writer', 'tag-transfer',
      'tag-transfer-adb-server', 'tag-transfer-adb-from',
    };
    if (!nfcTypes.contains(targetStatusType)) {
      debugPrint('⚠️ NFC subfield: tipo "$targetStatusType" no soportado');
      return '[$baseField.$subPath]';
    }

    // Obtener raw JSON: primero visitDetails, luego fallback a _adbServerCardsRawJson
    // (tag-transfer-adb-server guarda el JSON en estado local, no en visitDetails)
    String rawJson = FFAppState().visitDetails
        .where((d) => d.idActivityStatus == targetStatusId)
        .firstOrNull
        ?.statusResponse ?? '';

    debugPrint('🔎 NFC subfield: statusId=$targetStatusId type=$targetStatusType rawJson.len=${rawJson.length}');

    if (rawJson.isEmpty) {
      final sid = targetStatusId!;
      final cards = _adbServerCardsRawJson[sid];
      debugPrint('🔎 NFC fallback ADB: adbServerCards[$sid]=${cards?.length ?? "null"} entries');
      if (cards != null && cards.isNotEmpty) {
        final idx = _selectedAdbTagIndex.clamp(0, cards.length - 1);
        rawJson = cards[idx];
        debugPrint('🔎 NFC fallback ADB: usando card[$idx], len=${rawJson.length}');
      }
    }

    if (rawJson.isEmpty) {
      debugPrint('⚠️ NFC subfield: statusResponse vacío para "$baseField" (statusId=$targetStatusId)');
      return '[$baseField.$subPath]';
    }

    final nfcJson = actions.parseNfcJson(rawJson);
    if (nfcJson == null) {
      debugPrint('⚠️ NFC subfield: JSON inválido para "$baseField"');
      return '[$baseField.$subPath]';
    }

    final readInfo = nfcJson['Read_info'] as Map<String, dynamic>?;

    switch (subPath.toLowerCase()) {
      case 'us':
        final usId = readInfo?['US'];
        if (usId == null) return '[Sin operador]';
        try {
          final usRows = await globalDb.executeOperation((db) async {
            return await db.query(
              'Users',
              columns: ['Name_user'],
              where: 'Id_user = ?',
              whereArgs: [usId],
              limit: 1,
            );
          });
          if (usRows.isNotEmpty) {
            final name = usRows.first['Name_user'] as String?;
            if (name != null && name.isNotEmpty) return name;
          }
        } catch (_) {}
        return 'ID $usId';

      case 'tag_from':
        return (readInfo?['tag_from'] as String? ?? '').isNotEmpty
            ? (readInfo!['tag_from'] as String)
            : '[Sin tag origen]';

      case 'tag_to':
        final rawTagTo = (readInfo?['tag_to'] as String? ?? '').trim();
        if (rawTagTo.isEmpty) return '[Sin tag destino]';
        final cachedName = _productByRfidCache[rawTagTo];
        if (cachedName == null) {
          unawaited(_loadProductByRfid(rawTagTo));
          return rawTagTo;
        }
        return cachedName.isNotEmpty ? '$cachedName ($rawTagTo)' : rawTagTo;

      case 'date_created':
        final raw = readInfo?['Date_created'] as String?;
        if (raw == null || raw.isEmpty) return '[Sin fecha]';
        try {
          final dt = DateTime.parse(raw);
          return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
              '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
        } catch (_) {
          return raw;
        }

      case 'name_product':
        return readInfo?['Name_product'] as String? ?? '[Sin producto]';

      case 'rfid':
        return readInfo?['RFID'] as String? ?? '[Sin RFID]';

      case 'visits':
        final visitsList = nfcJson['Visits'] as List?;
        if (visitsList == null || visitsList.isEmpty) {
          return '<div>[Sin visitas]</div>';
        }

        // Pre-cargar nombres de cargueros desde SQLite (un query por ID único)
        final uniqueOpIds = visitsList
            .whereType<Map<String, dynamic>>()
            .map((v) => v['OP'])
            .where((id) => id != null)
            .map((id) => (id as num).toInt())
            .toSet();
        final opNames = <int, String>{};
        for (final opId in uniqueOpIds) {
          try {
            final rows = await globalDb.executeOperation((db) async {
              return await db.query(
                'Users',
                columns: ['Name_user'],
                where: 'Id_user = ?',
                whereArgs: [opId],
                limit: 1,
              );
            });
            if (rows.isNotEmpty) {
              final name = rows.first['Name_user'] as String?;
              if (name != null && name.isNotEmpty) opNames[opId] = name;
            }
          } catch (_) {}
        }

        final buffer = StringBuffer();
        for (final v in visitsList) {
          if (v is! Map<String, dynamic>) continue;

          String dhFormatted = '';
          try {
            final dh = DateTime.parse(v['DH'] as String? ?? '');
            dhFormatted = '${dh.day.toString().padLeft(2,'0')}/${dh.month.toString().padLeft(2,'0')}/${dh.year} '
                '${dh.hour.toString().padLeft(2,'0')}:${dh.minute.toString().padLeft(2,'0')}';
          } catch (_) {
            dhFormatted = v['DH']?.toString() ?? '';
          }

          final opId = v['OP'] != null ? (v['OP'] as num).toInt() : null;
          final opName = opId != null ? (opNames[opId] ?? 'ID $opId') : '';

          final heId = v['HE'] != null ? (v['HE'] as num).toInt() : 0;
          String loteName = 'Lote #$heId';
          if (heId > 0) {
            try {
              final hqRows = await globalDb.executeOperation((db) async {
                return await db.query(
                  'Headquarters',
                  columns: ['Name_headquarter'],
                  where: 'Id_headquarter = ?',
                  whereArgs: [heId],
                  limit: 1,
                );
              });
              if (hqRows.isNotEmpty) {
                final name = hqRows.first['Name_headquarter'] as String?;
                if (name != null && name.isNotEmpty) loteName = name;
              }
            } catch (_) {}
          }

          final visits = v['VISITS'] ?? 0;
          final results = v['RESULTS'] ?? 0;

          buffer.write(
            '<div style="border-bottom:1px dashed #ccc;padding:3px 0;">'
            '<div>Fecha: $dhFormatted</div>'
            '<div>Carguero: $opName</div>'
            '<div>Visitas: $visits&nbsp;&nbsp;Racimos: $results</div>'
            '<div>Lote: $loteName</div>'
            '</div>',
          );
        }
        return buffer.toString();

      default:
        debugPrint('⚠️ NFC subfield: subPath "$subPath" no reconocido');
        return '[$baseField.$subPath]';
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
      DateTime date;
      try {
        date = DateFormat('dd/MM/yyyy').parse(detail.statusResponse);
      } catch (_) {
        date = DateTime.parse(detail.statusResponse);
      }
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

    // Parsear formato Flutter TimeOfDay(HH:MM) → "HH:MM"
    final todMatch =
        RegExp(r'TimeOfDay\((\d{1,2}:\d{2})\)').firstMatch(detail.statusResponse);
    if (todMatch != null) return todMatch.group(1)!;

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

  /// Renderiza el placeholder {NombreCampo} de un status tag-transfer-adb-server:
  /// RFID destino (con fallback a RFID origen) + lista HTML de visits_details inyectados.
  String _getAdbServerDestinationValue(int statusId) {
    final cards = _adbServerCardsRawJson[statusId];
    if (cards == null || cards.isEmpty) {
      return '[Sin tag de destino]';
    }

    final selectedIndex = _selectedAdbTagIndex.clamp(0, cards.length - 1);
    final rawJson = cards[selectedIndex];

    String destRfid = '';
    List<Map<String, dynamic>> formStatusDetails = const [];
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final readInfo = decoded['Read_info'] as Map<String, dynamic>?;
      final tagTo = (readInfo?['tag_to'] as String? ?? '').trim();
      final rfid = (readInfo?['RFID'] as String? ?? '').trim();
      destRfid = tagTo.isNotEmpty ? tagTo : rfid;

      final statusBlock = decoded['status'] as Map<String, dynamic>?;
      final details = statusBlock?['visits_details'] as List<dynamic>?;
      if (details != null) {
        formStatusDetails =
            details.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.write(destRfid.isNotEmpty ? destRfid : '[Sin tag de destino]');

    for (final d in formStatusDetails) {
      final option = (d['status_option'] ?? '').toString();
      final response = (d['status_response'] ?? '').toString();
      if (option.isEmpty && response.isEmpty) continue;
      buffer.write('<div>$option: $response</div>');
    }

    return buffer.toString();
  }

  String _getDistanceExtractorValue(int statusId) {
    // Fuente principal: valor numérico en memoria (metros).
    final meters = _calculatedDistances[statusId];
    if (meters != null && meters > 0) {
      return '${(meters / 1000.0).toStringAsFixed(2)} km';
    }

    // Fallback: extraer distanceFromTag del JSON serializado en visitDetails
    // (el auto-save guarda {distanceFromTag, distancesFromProducts} como JSON).
    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );
    if (detail.statusResponse.isNotEmpty) {
      try {
        final decoded = jsonDecode(detail.statusResponse);
        if (decoded is Map && decoded['distanceFromTag'] != null) {
          final m = (decoded['distanceFromTag'] as num).toDouble();
          if (m > 0) return '${(m / 1000.0).toStringAsFixed(2)} km';
        }
      } catch (_) {}
    }

    return '[Sin calcular]';
  }

  String _getNumberValue(int statusId) {
    final detail = FFAppState().visitDetails.firstWhere(
          (d) => d.idActivityStatus == statusId,
          orElse: () => VisitsDetailsStruct(),
        );

    if (detail.statusOption.isEmpty) return '0';

    // Campos RANDOM: valor guardado en statusResponse (no pasa por text controller)
    if (detail.defaultStatus.toUpperCase().contains('=RANDOM:') &&
        detail.statusResponse.isNotEmpty) {
      final parsed = double.tryParse(detail.statusResponse);
      if (parsed != null) return _formatColombianNumber(parsed);
      return detail.statusResponse;
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

  /// Obtiene el nombre del producto consultando SQLite por el hardware RFID del chip NFC.
  /// Fallback: Name_product del JSON del tag → nfcLastProductName.
  Future<String> _fetchProductNameFromRfid(String nfcContent) async {
    try {
      // Usar el hardware tag ID (chip NFC) guardado durante la lectura
      final hardwareRfid = FFAppState().nfcHardwareTagId;
      if (hardwareRfid.isNotEmpty) {
        final rows = await globalDb.executeOperation((db) async {
          return await db.rawQuery(
            'SELECT Name_product FROM Products WHERE Rfid = ? LIMIT 1',
            [hardwareRfid],
          );
        });
        if (rows.isNotEmpty) {
          final name = rows.first['Name_product'] as String?;
          if (name != null && name.isNotEmpty) return name;
        }
      }
      // Fallback: nombre almacenado en el JSON del tag
      final json = jsonDecode(nfcContent) as Map<String, dynamic>?;
      final readInfo = json?['Read_info'] as Map<String, dynamic>?;
      final name = readInfo?['Name_product'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return FFAppState().nfcLastProductName;
  }

  // ===== RESUMEN DEL TAG READER AGRUPADO POR LOTE =====

  String _extractTagProductName(String rawJson) {
    try {
      final parsed = actions.parseNfcJson(rawJson);
      return (parsed?['Read_info']?['Name_product'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  Widget _buildTagReaderSummary({required int statusId, bool isAdbServer = false}) {
    final rawJsons = _tagReaderRawJsons[statusId];
    final isMulti = rawJsons != null && rawJsons.length > 1;

    List<Map<String, dynamic>> parseVisitsDetails(String raw) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final status = decoded['status'] as Map<String, dynamic>?;
        final details = status?['visits_details'] as List<dynamic>?;
        if (details != null) {
          return details.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
      return [];
    }

    if (isMulti) {
      // Modo NO_REMOVE: una sección por cada tag leído
      return Column(
        children: rawJsons.asMap().entries.map((entry) {
          final index = entry.key;
          final raw = entry.value;
          final sectionData = _parseNfcTagContent(raw);
          final sectionProductName = _extractTagProductName(raw);
          return _buildTagReaderSummarySection(
            sectionData: sectionData,
            productName: sectionProductName,
            tagIndex: index + 1,
            statusId: statusId,
            isAdbServer: isAdbServer,
            visitsDetails: parseVisitsDetails(raw),
          );
        }).toList(),
      );
    }

    // Modo normal (un solo tag): comportamiento original
    final tagData = _tagReaderData[statusId] ?? [];
    if (tagData.isEmpty) return const SizedBox.shrink();
    final singleRaw = rawJsons?.isNotEmpty == true ? rawJsons!.first : '';
    return _buildTagReaderSummarySection(
      sectionData: tagData,
      productName: _tagReaderProductName[statusId] ?? '',
      tagIndex: 0,
      statusId: statusId,
      isAdbServer: isAdbServer,
      visitsDetails: singleRaw.isNotEmpty ? parseVisitsDetails(singleRaw) : [],
    );
  }

  Widget _buildTagReaderSummarySection({
    required List<Map<String, dynamic>> sectionData,
    required String productName,
    required int tagIndex,
    required int statusId,
    bool isAdbServer = false,
    List<Map<String, dynamic>> visitsDetails = const [],
  }) {
    if (sectionData.isEmpty) return const SizedBox.shrink();

    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in sectionData) {
      final heId = record['headquarterId'] as int? ?? 0;
      groupedByHeadquarter.putIfAbsent(heId, () => []).add(record);
    }

    final checkKey = tagIndex;
    final isChecked = isAdbServer && (_adbTagChecked[statusId]?.contains(checkKey) ?? false);

    final treeContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tagIndex > 0) ...[
          Row(
            children: [
              Icon(Icons.nfc, color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 4),
              Text('Tag #$tagIndex', style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.24), height: 1)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Icon(Icons.summarize_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(productName.isNotEmpty ? productName : 'Resumen del TAG',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            if (tagIndex <= 1 && _tagReaderGeolocations.containsKey(statusId)) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withValues(alpha: 0.7), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '${_tagReaderGeolocations[statusId]!.latitude.toStringAsFixed(5)}, ${_tagReaderGeolocations[statusId]!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...groupedByHeadquarter.entries.map((entry) => _buildHeadquarterGroup(entry.key, entry.value)),
        if (visitsDetails.isNotEmpty) ...[
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          ...visitsDetails.map((detail) {
            final option = detail['status_option']?.toString() ?? '';
            final response = detail['status_response']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.label_outline_rounded, size: 13, color: Color(0xFF42A5F5)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$option: ',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      response,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );

    return Container(
      margin: tagIndex > 0 ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: isAdbServer
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: treeContent),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _adbTagChecked[statusId] ??= {};
                      if (isChecked) {
                        _adbTagChecked[statusId]!.remove(checkKey);
                      } else {
                        _adbTagChecked[statusId]!.add(checkKey);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isChecked
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF59E0B), Color(0xFF92400E)],
                            )
                          : null,
                      color: isChecked ? null : Colors.transparent,
                      border: Border.all(
                        color: isChecked ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: isChecked
                          ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)]
                          : [],
                    ),
                    child: isChecked ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                  ),
                ),
              ],
            )
          : treeContent,
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Lote: ',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                    TextSpan(
                                      text: loteName,
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _CopyValueButton(
                              value: loteName,
                              semanticLabel: 'Copiar nombre del lote',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Vis: ',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Text(
                                      '$totalVisits',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$_unityLabel: ',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$totalResults',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _CopyValueButton(
                                      value: '$totalResults',
                                      semanticLabel:
                                          'Copiar racimos del lote',
                                      iconSize: 11,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP) con prefijo Carguero
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Carguero: ',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                    TextSpan(
                                      text: operatorName.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _CopyValueButton(
                              value: operatorName.toUpperCase(),
                              semanticLabel: 'Copiar carguero',
                            ),
                          ],
                        ),
                        // Cortero eliminado del resumen
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visitas: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalVisits',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _CopyValueButton(
                                    value: '$totalResults',
                                    semanticLabel:
                                        'Copiar racimos del carguero',
                                    iconSize: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===== TABLA PLANA POR (CARGUERO × LOTE) — usada por el panel DATOS PRINCIPALES =====

  String _resolveLoteName(int headquarterId) {
    final hq = FFAppState().headquartersList.firstWhere(
          (h) => h.idHeadquarter == headquarterId,
          orElse: () => HeadquartersStruct(),
        );
    return hq.nameHeadquarter.isNotEmpty
        ? hq.nameHeadquarter
        : 'Lote #$headquarterId';
  }

  /// Formatea un double como peso en formato es-ES: "12,50 kg".
  String _formatKg(double v) {
    final fixed = v.toStringAsFixed(2);
    final withComma = fixed.replaceAll('.', ',');
    return '$withComma kg';
  }

  Widget _buildTagOperatorLotesTable(List<Map<String, dynamic>> visitData) {
    debugPrint(
        '🟣 _buildTagOperatorLotesTable: visitData.length=${visitData.length} '
        '_headquarterWeights.length=${_headquarterWeights.length}');
    if (visitData.isEmpty) return const SizedBox.shrink();

    // 1 fila por record de Visits[]. Orden descendente por dateTime.
    final records = List<Map<String, dynamic>>.from(visitData)
      ..sort((a, b) {
        final ta = a['dateTime'] as DateTime?;
        final tb = b['dateTime'] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    int totalRacimos = 0;
    double totalPesoAprox = 0;
    final List<_TiqueteRow> rows = [];
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final opId = (r['operatorId'] as String?) ?? '';
      final opIdInt = int.tryParse(opId) ?? 0;
      final heId = (r['headquarterId'] as int?) ?? 0;
      final results = (r['results'] as int?) ?? 0;
      final dt = r['dateTime'] as DateTime?;
      final pesoProm = _headquarterWeights[heId];
      final pesoAprox = pesoProm != null ? results * pesoProm : 0.0;

      totalRacimos += results;
      totalPesoAprox += pesoAprox;

      final cargueroResolved = _getUserName(opId);
      final cargueroDisplay =
          (cargueroResolved.isNotEmpty && cargueroResolved != opId)
              ? cargueroResolved.toUpperCase()
              : (opIdInt > 0 ? 'Carguero #$opIdInt' : '—');

      final identResolved = _getUserIdentificacion(opIdInt);
      final identDisplay = identResolved.isNotEmpty ? identResolved : '—';

      rows.add(_TiqueteRow(
        tiquete: i + 1,
        fechaCorte: dt,
        loteName: _resolveLoteName(heId),
        racimos: results,
        pesoPromedio: pesoProm,
        pesoAproximado: pesoAprox,
        cargueroNombre: cargueroDisplay,
        cargueroIdentificacion: identDisplay,
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTiqueteTableHeader(),
                  for (int i = 0; i < rows.length; i++)
                    _buildTiqueteTableRow(rows[i], i.isOdd),
                  _buildTiqueteTableFooter(totalRacimos, totalPesoAprox),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTiqueteTableHeader() {
    Widget cell(String text, int flex,
        {TextAlign align = TextAlign.center, double padR = 0}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: EdgeInsets.only(right: padR),
          child: Text(
            text,
            textAlign: align,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFBBF24),
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          cell('TIQUETE', 1),
          const SizedBox(width: 6),
          cell('FECHA CORTE', 2),
          const SizedBox(width: 6),
          cell('LOTE', 3),
          const SizedBox(width: 6),
          cell('RACIMOS', 1),
          const SizedBox(width: 6),
          cell('PESO PROMEDIO', 2),
          const SizedBox(width: 6),
          cell('PESO APROXIMADO', 2),
          const SizedBox(width: 6),
          cell('NOMBRE CARGUERO', 3),
          const SizedBox(width: 6),
          cell('IDENTIFICACIÓN', 2),
        ],
      ),
    );
  }

  /// Render de UNA celda de tabla — texto + botón copiar a la derecha del texto.
  /// Si [leading] está definido (chip de lote), se renderiza en lugar del texto.
  Widget _tiqueteCell({
    required int flex,
    required String text,
    required String copyValue,
    required String copyLabel,
    TextAlign align = TextAlign.center,
    Color textColor = Colors.white,
    bool bold = true,
    bool numeric = false,
    Widget? leading,
  }) {
    final canCopy = copyValue.isNotEmpty && copyValue != '—';
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisAlignment: align == TextAlign.right
            ? MainAxisAlignment.end
            : (align == TextAlign.center
                ? MainAxisAlignment.center
                : MainAxisAlignment.start),
        children: [
          if (leading != null)
            Flexible(child: leading)
          else
            Flexible(
              child: Text(
                text,
                textAlign: align,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                  fontFeatures: numeric
                      ? const [FontFeature.tabularFigures()]
                      : null,
                ),
              ),
            ),
          if (canCopy) ...[
            const SizedBox(width: 4),
            _CopyValueButton(
              value: copyValue,
              semanticLabel: copyLabel,
              iconSize: 10,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTiqueteTableRow(_TiqueteRow row, bool zebra) {
    final bgColor =
        zebra ? Colors.white.withValues(alpha: 0.03) : Colors.transparent;

    final String fechaText = row.fechaCorte == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(row.fechaCorte!);

    final String pesoPromText =
        row.pesoPromedio == null ? 'Sin peso' : _formatKg(row.pesoPromedio!);
    final String pesoAproxText =
        row.pesoPromedio == null ? '0' : _formatKg(row.pesoAproximado);

    final Widget loteChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        row.loteName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _tiqueteCell(
            flex: 1,
            text: '${row.tiquete}',
            copyValue: '${row.tiquete}',
            copyLabel: 'Copiar tiquete',
            numeric: true,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 2,
            text: fechaText,
            copyValue: fechaText,
            copyLabel: 'Copiar fecha de corte',
            numeric: true,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 3,
            text: row.loteName,
            copyValue: row.loteName,
            copyLabel: 'Copiar lote',
            leading: loteChip,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 1,
            text: '${row.racimos}',
            copyValue: '${row.racimos}',
            copyLabel: 'Copiar racimos',
            numeric: true,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 2,
            text: pesoPromText,
            copyValue: pesoPromText,
            copyLabel: 'Copiar peso promedio',
            numeric: true,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 2,
            text: pesoAproxText,
            copyValue: pesoAproxText,
            copyLabel: 'Copiar peso aproximado',
            numeric: true,
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 3,
            text: row.cargueroNombre,
            copyValue: row.cargueroNombre,
            copyLabel: 'Copiar nombre carguero',
          ),
          const SizedBox(width: 6),
          _tiqueteCell(
            flex: 2,
            text: row.cargueroIdentificacion,
            copyValue: row.cargueroIdentificacion,
            copyLabel: 'Copiar identificación carguero',
          ),
        ],
      ),
    );
  }

  Widget _buildTiqueteTableFooter(int totalRacimos, double totalPesoAprox) {
    final String totalPesoText =
        totalPesoAprox == 0 ? '0' : _formatKg(totalPesoAprox);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332).withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // 1 + 6 + 2 + 6 + 3 + 6 = label TOTALES ocupa los tres primeros bloques
          Expanded(
            flex: 6, // tiquete + fecha + lote (1+2+3)
            child: Text(
              'TOTALES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 24), // los SizedBoxes entre columnas: 18 (3*6)
          Expanded(
            flex: 1, // racimos
            child: Text(
              '$totalRacimos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // peso promedio (sin suma — n/a a nivel global)
          const Expanded(flex: 2, child: SizedBox.shrink()),
          const SizedBox(width: 6),
          Expanded(
            flex: 2, // peso aproximado total
            child: Text(
              totalPesoText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(flex: 3, child: SizedBox.shrink()), // carguero
          const SizedBox(width: 6),
          const Expanded(flex: 2, child: SizedBox.shrink()), // identificación
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
              Text(
                (_tagWriterProductName[statusId]?.isNotEmpty == true)
                    ? _tagWriterProductName[statusId]!
                    : 'Registros escritos en TAG',
                style: const TextStyle(
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
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Lote: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              TextSpan(
                                text: loteName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visitas: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalVisits',
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
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
                          ],
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
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;

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
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP) con prefijo Carguero
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Carguero: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64B5F6),
                                ),
                              ),
                              TextSpan(
                                text: operatorName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Cortero eliminado del resumen
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visitas: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalVisits',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _getUnresolvedStatuses({required int skipStatusId}) {
    const skipTypes = {
      'step',
      'tag-transfer',
      'tag-transfer-adb-server',
      'tag-transfer-adb-from',
      'dynamic-printing',
      'dynamic-printing-adb',
    };
    final unresolved = <String>[];

    void checkStatus(dynamic status) {
      final type = getJsonField(status, r'''$.type_status''')
              ?.toString()
              .toLowerCase() ??
          '';
      final id =
          getJsonField(status, r'''$.id_activity_status''') as int? ?? 0;
      final name =
          getJsonField(status, r'''$.status_name''')?.toString() ?? '';
      if (!skipTypes.contains(type) && id != skipStatusId && id != 0) {
        final hasValue = FFAppState()
            .visitDetails
            .any((d) => d.idActivityStatus == id && d.statusResponse.isNotEmpty);
        if (!hasValue) unresolved.add(name.isNotEmpty ? name : 'ID $id');
      }
      for (var step
          in (getJsonField(status, r'''$.steps_childs''')?.toList() ?? [])) {
        for (var s
            in (getJsonField(step, r'''$.activity_status''')?.toList() ?? [])) {
          checkStatus(s);
        }
      }
      for (var s
          in (getJsonField(status, r'''$.status_childs''')?.toList() ?? [])) {
        checkStatus(s);
      }
    }

    final activity = FFAppState().currentActivity;
    for (var s
        in (getJsonField(activity, r'''$.activity_status''')?.toList() ?? [])) {
      checkStatus(s);
    }
    for (var step
        in (getJsonField(activity, r'''$.activity_steps''')?.toList() ?? [])) {
      for (var s
          in (getJsonField(step, r'''$.activity_status''')?.toList() ?? [])) {
        checkStatus(s);
      }
    }
    return unresolved;
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

    // Obtener el default_status del visit detail para extraer TYPE_PRODUCT_START
    String titleText = 'Tag de origen leído';
    for (var detail in FFAppState().visitDetails) {
      if (detail.idActivityStatus == statusId) {
        final defaultStatus = detail.defaultStatus;
        // Captura todo hasta ; o } (permitiendo espacios en el nombre)
        final regexTypeStart = RegExp(r'=TYPE_PRODUCT_START:([^;}]+)');
        final matchStart = regexTypeStart.firstMatch(defaultStatus);
        if (matchStart != null) {
          final typeProductStart = matchStart.group(1)!.trim();
          titleText = '$typeProductStart de origen';
          debugPrint('📦 TAG-TRANSFER Summary: Título dinámico: $titleText');
        }
        break;
      }
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_tagTransferSourceProductName[statusId]?.isNotEmpty == true)
                          ? _tagTransferSourceProductName[statusId]!
                          : titleText,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_tagTransferDestProductName[statusId]?.isNotEmpty == true)
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward, color: Color(0xFF64B5F6), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _tagTransferDestProductName[statusId]!,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              color: Color(0xFF64B5F6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
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
          // Botón TRANSFERIR AHORA o TRANSFERENCIA EXITOSA
          const SizedBox(height: 16),
          if (_tagTransferCompleted[statusId] == true)
            // TRANSFERENCIA EXITOSA - No clickeable
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFF008c5a)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB45309).withValues(alpha: 0.4),
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
          else
            // TRANSFERIR AHORA - Clickeable
            InkWell(
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

                // Extraer TYPE_PRODUCT_FINISH y WRITER_STATUS para título dinámico y validación
                String? destinationTitle;
                bool writerStatus = false;
                for (var detail in FFAppState().visitDetails) {
                  if (detail.idActivityStatus == statusId) {
                    final defaultStatus = detail.defaultStatus;
                    // Captura todo hasta ; o } (permitiendo espacios en el nombre)
                    final regexTypeFinish = RegExp(r'TYPE_PRODUCT_FINISH:([^;}]+)');
                    final matchFinish = regexTypeFinish.firstMatch(defaultStatus);
                    if (matchFinish != null) {
                      final typeProductFinish = matchFinish.group(1)!.trim();
                      destinationTitle = 'Escribir $typeProductFinish de destino';
                      debugPrint('📦 TAG-TRANSFER: Título dinámico destino: $destinationTitle');
                    }
                    if (RegExp(r'WRITER_STATUS\s*=\s*TRUE')
                        .hasMatch(defaultStatus.toUpperCase())) {
                      writerStatus = true;
                      debugPrint('📋 TAG-TRANSFER: WRITER_STATUS=true detectado');
                    }
                    break;
                  }
                }

                // Si WRITER_STATUS=true, validar que todos los campos del formulario estén resueltos
                if (writerStatus) {
                  final unresolved =
                      _getUnresolvedStatuses(skipStatusId: statusId);
                  if (unresolved.isNotEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          'Completa estos campos antes de transferir:\n• ${unresolved.join('\n• ')}',
                          style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ));
                    }
                    return;
                  }
                }

                // Si WRITER_STATUS=true, inyectar los status del formulario en el JSON del tag
                String contentToTransfer = sourceTagContent;
                if (writerStatus) {
                  final srcJson = actions.parseNfcJson(sourceTagContent);
                  if (srcJson != null) {
                    final visitDetailsForForm = FFAppState()
                        .visitDetails
                        .where((d) => d.idActivityStatus != statusId)
                        .map((d) => {
                              'id_activity_status': d.idActivityStatus,
                              'status_option': d.statusOption,
                              'status_response': d.statusResponse,
                            })
                        .toList();
                    srcJson['status'] = {'visits_details': visitDetailsForForm};
                    contentToTransfer = jsonEncode(srcJson);
                    debugPrint(
                        '📋 WRITER_STATUS: ${visitDetailsForForm.length} status inyectados en JSON');
                  }
                }

                // Abrir diálogo de escritura en tag de destino
                final result = await showDialog<String?>(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) {
                    return Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: NfcTransferWriteDialogWidget(
                        sourceTagContent: contentToTransfer,
                        destinationTitle: destinationTitle,
                      ),
                    );
                  },
                );

                // Si la transferencia fue exitosa, obtener el contenido escrito y actualizar visitDetails
                if (result != null && result.isNotEmpty && mounted) {
                  final destinationTagContent = result;
                  
                  // Actualizar el statusResponse en visitDetails con el JSON del tag de destino
                  int existingIndex = -1;
                  for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                    if (FFAppState().visitDetails[i].idActivityStatus == statusId) {
                      existingIndex = i;
                      break;
                    }
                  }

                  if (existingIndex >= 0) {
                    final existingDetail = FFAppState().visitDetails[existingIndex];
                    FFAppState().updateVisitDetailsAtIndex(
                      existingIndex,
                      (detail) => VisitsDetailsStruct(
                        idVisitDetail: detail.idVisitDetail,
                        idVisit: detail.idVisit,
                        idActivityStatus: statusId,
                        statusOption: existingDetail.statusOption,
                        statusResponse: destinationTagContent,
                        idStepParent: existingDetail.idStepParent,
                        rememberStatus: existingDetail.rememberStatus,
                        defaultStatus: existingDetail.defaultStatus,
                        typeStatus: 'tag-transfer',
                        auxStep: existingDetail.auxStep,
                      ),
                    );
                    debugPrint('💾 TAG-TRANSFER: statusResponse actualizado con JSON del tag de destino en visitDetails[$existingIndex]');
                  } else {
                    FFAppState().addToVisitDetails(
                      VisitsDetailsStruct(
                        idVisitDetail: 0,
                        idVisit: 0,
                        idActivityStatus: statusId,
                        statusOption: 'Tag Transfer',
                        statusResponse: destinationTagContent,
                        idStepParent: 0,
                        rememberStatus: false,
                        defaultStatus: '',
                        typeStatus: 'tag-transfer',
                        auxStep: 0,
                      ),
                    );
                    debugPrint('💾 TAG-TRANSFER: Nuevo registro agregado a visitDetails con JSON del tag de destino');
                  }

                  setState(() {
                    _tagTransferCompleted[statusId] = true;
                    _tagTransferDestProductName[statusId] = FFAppState().nfcLastProductName;
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
                      backgroundColor: Color(0xFFB45309),
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

    // Agrupar por par de operadores (OP + OP2) - igual que tag-reader
    final Map<String, Map<String, dynamic>> operatorGroups = {};
    for (var record in records) {
      final operatorId = record['operatorId'] as String? ?? 'N/A';
      final operator2Id = record['operator2Id'] as String? ?? '';

      // Crear una clave única para la pareja de operadores
      final operatorPairKey =
          operator2Id.isNotEmpty ? '${operatorId}_$operator2Id' : operatorId;

      if (!operatorGroups.containsKey(operatorPairKey)) {
        // Buscar nombre del operador principal en usersList
        String operatorName = _getUserName(operatorId);

        // Buscar nombre del cortero si existe
        String operator2Name = '';
        if (operator2Id.isNotEmpty) {
          operator2Name = _getCorterName(operator2Id);
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
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Lote: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              TextSpan(
                                text: loteName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visitas: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalVisits',
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
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
                          ],
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
                  return _buildTagTransferOperatorGroup(
                      headquarterId, operatorPairKey, operatorData);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagTransferOperatorGroup(int headquarterId, String operatorPairKey,
      Map<String, dynamic> operatorData) {
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP) con prefijo Carguero
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Carguero: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64B5F6),
                                ),
                              ),
                              TextSpan(
                                text: operatorName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Cortero eliminado del resumen
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visitas: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalVisits',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

    // Parsear parámetros de la fórmula (ej: Sufijo=Kg)
    final params = _parseFormulaParameters(formula);
    final suffix = params['Sufijo'] ?? '';

    // Colores: Verde si ya fue calculado, Blanco si aún no
    final backgroundColor = hasBeenCalculated
        ? [const Color(0xFF1B4332), const Color(0xFF2D6A4F)] // Verde oscuro
        : [
            const Color(0xFFF5F5F5),
            const Color(0xFFFFFFFF)
          ]; // Blanco/Gris claro

    final borderColor = hasBeenCalculated
        ? const Color(0xFF451A03).withValues(alpha: 0.5)
        : const Color(0xFFBDBDBD).withValues(alpha: 0.5);

    final iconColor =
        hasBeenCalculated ? const Color(0xFFD97706) : const Color(0xFF9E9E9E);

    final textColor = hasBeenCalculated
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF424242);

    final valueColor =
        hasBeenCalculated ? const Color(0xFF95D5B2) : const Color(0xFF757575);

    // Construir el texto del valor con sufijo si existe
    final displayValue = suffix.isNotEmpty
        ? '${_formatColombianNumber(calculatedValue)} $suffix'
        : _formatColombianNumber(calculatedValue);

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
                  // Valor calculado con sufijo (siempre visible)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayValue,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: valueColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CopyValueButton(
                        value: _formatColombianNumber(calculatedValue),
                        semanticLabel: 'Copiar resultado calculado',
                        iconSize: 14,
                      ),
                    ],
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B1A), Color(0xFF0A1F12)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A4A2E),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.white,
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
          if (defaultStatus.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CopyValueButton(
              value: defaultStatus,
              semanticLabel: 'Copiar información',
              iconSize: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInputControl({
    required dynamic parentStep,
    required dynamic status,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');

    // Obtener o crear el controlador y FocusNode para este status
    if (!_textControllers.containsKey(statusId)) {
      // Obtener el valor actual del texto desde visitDetails
      String currentValue = '';
      final existingDetail = FFAppState().visitDetails.firstWhere(
        (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
        orElse: () => VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: 0,
          statusOption: '',
          statusResponse: '',
          idStepParent: 0,
          rememberStatus: false,
          defaultStatus: '',
          typeStatus: '',
          auxStep: 0,
        ),
      );
      currentValue = existingDetail.statusResponse;

      _textControllers[statusId] = TextEditingController(text: currentValue);
      _textFocusNodes[statusId] = FocusNode();

      // Listener para detectar cuando pierde el foco
      _textFocusNodes[statusId]!.addListener(() {
        if (!_textFocusNodes[statusId]!.hasFocus) {
          // Perdió el foco, guardar el valor
          _saveTextValue(parentStep, status, _textControllers[statusId]!.text);
        }
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB45309).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _textControllers[statusId],
        focusNode: _textFocusNodes[statusId],
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          color: Color(0xFFB45309),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Escribe aquí...',
          hintStyle: TextStyle(
            color: const Color(0xFFB45309).withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: (value) {
          // Validar y guardar con cada letra que se escribe
          _saveTextValue(parentStep, status, value);
        },
        onSubmitted: (value) {
          // Al presionar Enter/Done, guardar
          _saveTextValue(parentStep, status, value);
        },
      ),
    );
  }

  // Widget inline para búsqueda de usuarios (tipo users-list)
  Widget _buildUsersListControl({
    dynamic parentStep,
    required dynamic status,
  }) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final parentStepId = parentStep != null
        ? (getJsonField(parentStep, r'''$.id_activity_step''') ?? 0)
        : 0;

    // Obtener o crear el controlador y FocusNode para este status
    if (!_usersSearchControllers.containsKey(statusId)) {
      _usersSearchControllers[statusId] = TextEditingController();
      _usersSearchFocusNodes[statusId] = FocusNode();
      _usersSearchResults[statusId] = [];
    }

    // Obtener el usuario seleccionado desde visitDetails
    String selectedUserName = '';
    final existingDetail = FFAppState().visitDetails.firstWhere(
      (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
      orElse: () => VisitsDetailsStruct(
        idVisitDetail: 0,
        idVisit: 0,
        idActivityStatus: 0,
        statusOption: '',
        statusResponse: '',
        idStepParent: 0,
        rememberStatus: false,
        defaultStatus: '',
        typeStatus: '',
        auxStep: 0,
      ),
    );
    selectedUserName = existingDetail.statusResponse;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D2B1A),
            Color(0xFF0A1F12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB45309).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usuario seleccionado (si existe)
          if (selectedUserName.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB45309),
                    Color(0xFF92400E),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB45309).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getUserInitials(selectedUserName),
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedUserName,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      // Limpiar la selección
                      _removeUserSelection(parentStep, status);
                    },
                  ),
                ],
              ),
            ),

          // Barra de búsqueda
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFB45309).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _usersSearchControllers[statusId],
                    focusNode: _usersSearchFocusNodes[statusId],
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      hintStyle: TextStyle(
                        color: const Color(0xFFB45309).withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFB45309),
                        size: 22,
                      ),
                      suffixIcon: _usersSearchControllers[statusId]!.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: const Color(0xFFB45309).withValues(alpha: 0.6),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _usersSearchControllers[statusId]?.clear();
                                  _usersSearchResults[statusId] = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onChanged: (value) async {
                      // Búsqueda en tiempo real
                      await _searchUsers(statusId, value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón para abrir diálogo de pantalla completa
              InkWell(
                onTap: () async {
                  await _openFullScreenUserSearch(parentStep, status);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB45309),
                        Color(0xFF92400E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB45309).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          // Mini lista de resultados (primeras 2 coincidencias)
          if (_usersSearchResults[statusId]!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _usersSearchResults[statusId]!.length > 2
                    ? 2
                    : _usersSearchResults[statusId]!.length,
                itemBuilder: (context, index) {
                  final user = _usersSearchResults[statusId]![index];
                  return _buildUserListItem(
                    user: user,
                    onTap: () {
                      _selectUser(parentStep, status, user);
                    },
                  );
                },
              ),
            ),

          // Indicador de más resultados
          if (_usersSearchResults[statusId]!.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '+${_usersSearchResults[statusId]!.length - 2} usuarios más...',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309).withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget para mostrar un usuario en la lista
  Widget _buildUserListItem({
    required UsersStruct user,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFB45309).withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB45309).withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB45309),
                    Color(0xFF92400E),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getUserInitials(user.nameUser),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nameUser,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Código: ${user.operID}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB45309).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFFB45309).withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Obtener iniciales del nombre de usuario
  String _getUserInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Buscar usuarios en SQLite
  Future<void> _searchUsers(int statusId, String searchText) async {
    if (searchText.trim().isEmpty) {
      setState(() {
        _usersSearchResults[statusId] = [];
      });
      return;
    }

    try {
      final results = await actions.searchUsersSqlite(searchText);
      setState(() {
        _usersSearchResults[statusId] = results;
      });
    } catch (e) {
      debugPrint('❌ Error buscando usuarios: $e');
      setState(() {
        _usersSearchResults[statusId] = [];
      });
    }
  }

  // Seleccionar un usuario
  void _selectUser(dynamic parentStep, dynamic status, UsersStruct user) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final parentStepId = parentStep != null
        ? (getJsonField(parentStep, r'''$.id_activity_step''') ?? 0)
        : 0;
    final rememberStatus = getJsonField(status, r'''$.remember_status''') ?? false;
    final defaultStatus = getJsonField(status, r'''$.default_status''')?.toString() ?? '';
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();

    // Buscar si ya existe un registro para este status
    final existingIndex = FFAppState().visitDetails.indexWhere(
      (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
    );

    if (existingIndex != -1) {
      // Actualizar el registro existente
      FFAppState().updateVisitDetailsAtIndex(
        existingIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: user.nameUser,
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    } else {
      // Crear un nuevo registro
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: user.nameUser,
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    }

    // Limpiar la búsqueda
    setState(() {
      _usersSearchControllers[statusId]?.clear();
      _usersSearchResults[statusId] = [];
    });

    debugPrint('✅ Usuario seleccionado: ${user.nameUser}');
  }

  // Remover selección de usuario
  void _removeUserSelection(dynamic parentStep, dynamic status) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final parentStepId = parentStep != null
        ? (getJsonField(parentStep, r'''$.id_activity_step''') ?? 0)
        : 0;

    // Buscar y eliminar el registro
    final existingIndex = FFAppState().visitDetails.indexWhere(
      (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
    );

    if (existingIndex != -1) {
      FFAppState().removeAtIndexFromVisitDetails(existingIndex);
      setState(() {});
      debugPrint('✅ Usuario deseleccionado');
    }
  }

  // Abrir diálogo de búsqueda de pantalla completa
  Future<void> _openFullScreenUserSearch(dynamic parentStep, dynamic status) async {
    final selectedUser = await showDialog<UsersStruct>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return const _FullScreenUserSearchDialog();
      },
    );

    if (selectedUser != null) {
      _selectUser(parentStep, status, selectedUser);
    }
  }

  // Generar nombre de foto usando fecha, hora y nombre de la actividad
  String _generatePhotoName() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // Obtener nombre de la actividad desde FFAppState
    final activityName = getJsonField(
      FFAppState().currentActivity,
      r'''$.name_activity''',
    )?.toString() ?? 'Actividad';

    // Limpiar el nombre de la actividad (quitar espacios y caracteres especiales)
    final cleanActivityName = activityName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .toLowerCase();

    return '${cleanActivityName}_${dateStr}_$timeStr.jpg';
  }

  // Display inline para foto capturada (tipo photo)
  Widget _buildPhotoDisplay({
    required int statusId,
    required int parentStepId,
  }) {
    // Buscar el registro en visitDetails
    final photoDetail = FFAppState().visitDetails.firstWhere(
      (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
      orElse: () => VisitsDetailsStruct(
        idVisitDetail: 0,
        idVisit: 0,
        idActivityStatus: 0,
        statusOption: '',
        statusResponse: '',
        idStepParent: 0,
        rememberStatus: false,
        defaultStatus: '',
        typeStatus: '',
        auxStep: 0,
      ),
    );

    // Si no hay foto, no mostrar nada
    if (photoDetail.statusResponse.isEmpty) {
      return const SizedBox.shrink();
    }

    final photoPath = photoDetail.statusResponse;

    // Verificar que el archivo existe
    final photoFile = File(photoPath);
    if (!photoFile.existsSync()) {
      debugPrint('⚠️ Archivo de foto no existe: $photoPath');
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB45309).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Miniatura de la foto con bordes redondeados
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFB45309).withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.file(
                photoFile,
                fit: BoxFit.cover,
                cacheWidth: 120, // Cachear a 120px (2x el tamaño de display para buena calidad)
                cacheHeight: 120,
                gaplessPlayback: true, // Evitar parpadeo durante rebuilds
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nombre de la foto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFB45309),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Foto capturada',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _generatePhotoName(),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Display inline para video capturado (tipo video)
  Widget _buildVideoDisplay({
    required int statusId,
    required int parentStepId,
    required dynamic parentStep,
    required dynamic status,
  }) {
    // Buscar el registro en visitDetails
    final videoDetail = FFAppState().visitDetails.firstWhere(
      (d) => d.idActivityStatus == statusId && d.idStepParent == parentStepId,
      orElse: () => VisitsDetailsStruct(
        idVisitDetail: 0,
        idVisit: 0,
        idActivityStatus: 0,
        statusOption: '',
        statusResponse: '',
        idStepParent: 0,
        rememberStatus: false,
        defaultStatus: '',
        typeStatus: '',
        auxStep: 0,
      ),
    );

    // Si no hay video, no mostrar nada
    if (videoDetail.statusResponse.isEmpty) {
      return const SizedBox.shrink();
    }

    final videoPath = videoDetail.statusResponse;
    final statusName = getJsonField(status, r'''$.status_name''').toString();

    return GestureDetector(
      onTap: () async {
        debugPrint('🎬 Abriendo diálogo de captura de video con video existente');

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: VideoCaptureComponentWidget(
                idStatus: statusId,
                statusName: statusName,
                statusJSON: status,
                idStepParent: parentStepId,
              ),
            );
          },
        );

        // Actualizar la UI después de cerrar el diálogo
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFB45309).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
        children: [
          // Miniatura del video usando VideoPlayer
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFB45309).withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Thumbnail del video
                  _VideoThumbnail(videoPath: videoPath),
                  // Overlay de play icon
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Información del video
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFB45309),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Video capturado',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _generateVideoName(),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // Generar nombre de video usando fecha, hora y nombre de la actividad
  String _generateVideoName() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // Obtener nombre de la actividad desde FFAppState
    final activityName = getJsonField(
      FFAppState().currentActivity,
      r'''$.name_activity''',
    )?.toString() ?? 'Actividad';

    // Limpiar el nombre de la actividad (quitar espacios y caracteres especiales)
    final cleanActivityName = activityName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .toLowerCase();

    return '${cleanActivityName}_${dateStr}_$timeStr.mp4';
  }

  // Guardar el valor de texto en visitDetails
  Future<void> _saveTextValue(
      dynamic parentStep, dynamic status, String value) async {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final statusName = getJsonField(status, r'''$.status_name''').toString();
    final parentStepId = getJsonField(parentStep, r'''$.id_activity_step''');
    final typeStatus = getJsonField(status, r'''$.type_status''').toString();
    final defaultStatus = getJsonField(status, r'''$.default_status''').toString();
    final rememberStatus = getJsonField(status, r'''$.remember_status''') == true;

    debugPrint('📝 Guardando texto para "$statusName": "$value" (${value.length} caracteres)');

    final trimmedValue = value.trim();

    // Si el texto está vacío, eliminar de visitDetails
    if (trimmedValue.isEmpty) {
      debugPrint('⚠️ Texto vacío. Eliminando de visitDetails...');

      List<int> indicesToRemove = [];
      for (int i = 0; i < FFAppState().visitDetails.length; i++) {
        if (FFAppState().visitDetails[i].idActivityStatus == statusId &&
            FFAppState().visitDetails[i].idStepParent == parentStepId) {
          indicesToRemove.add(i);
        }
      }

      for (int i = indicesToRemove.length - 1; i >= 0; i--) {
        FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
      }

      // Limpiar caché para que el estado se actualice correctamente
      _visitDetailsSearchCache.clear();

      setState(() {});
      return;
    }

    // Buscar si ya existe el detalle
    int existingIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == statusId &&
          FFAppState().visitDetails[i].idStepParent == parentStepId) {
        existingIndex = i;
        break;
      }
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
          statusResponse: trimmedValue,
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    } else {
      // Crear nuevo DIRECTAMENTE (sin llamar a _onStatusSelected)
      // Esto hace que text se comporte como number
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: statusId,
          statusOption: statusName,
          statusResponse: trimmedValue,
          idStepParent: parentStepId,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus,
          typeStatus: typeStatus,
          auxStep: parentStepId,
        ),
      );
    }

    // Limpiar caché para que el estado se actualice correctamente
    _visitDetailsSearchCache.clear();

    setState(() {});
  }

  Widget _buildDistanceExtractorDisplay({required int statusId}) {
    final hasData = _calculatedDistances.containsKey(statusId);
    final distanceFromTag = _calculatedDistances[statusId] ?? 0.0;
    final distancesFromProducts = _calculatedDistancesFromProduct[statusId];
    final distanceFromTagKm = distanceFromTag / 1000;

    // Sin datos: mostrar placeholder hasta que se reciba un tag
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4332),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.social_distance_rounded, size: 16, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Esperando lectura de TAG para calcular distancia...',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
          // NIVEL 1: Desde TAG
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Desde TAG',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
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
                const SizedBox(width: 8),
                _CopyValueButton(
                  value: distanceFromTagKm.toStringAsFixed(2),
                  semanticLabel: 'Copiar distancia desde TAG',
                ),
              ],
            ),
          ),
          // NIVEL 2: Desde Productos (siempre visible — árbol expandido por defecto)
          const SizedBox(height: 8),
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
          if (distancesFromProducts == null || distancesFromProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: Text(
                'Sin distancias calculadas por producto',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...distancesFromProducts.map((item) {
              final loteName = item['headquarterName'] as String;
              final distance = item['distance'] as double;
              final line = item['line'] as int?;
              final palm = item['palm'] as int?;
              final distanceKm = distance / 1000;

              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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
                      const SizedBox(width: 8),
                      _CopyValueButton(
                        value: distanceKm.toStringAsFixed(2),
                        semanticLabel: 'Copiar distancia a $loteName',
                        iconSize: 12,
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

  Widget _buildHeadquarterWeightsDisplay(int statusId) {
    // Si no hay datos del tag, mostrar mensaje para leer primero
    if (_tagReaderData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2A4A6F)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFF64B5F6),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Primero lea el TAG en el status "Lectura en TAG" para calcular el peso',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Si no hay resultado para este statusId específico, no mostrar nada
    if (!_calculatedHeadquarterWeights.containsKey(statusId)) {
      return const SizedBox.shrink();
    }

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

    // Obtener el dato para este statusId específico
    final data = _calculatedHeadquarterWeights[statusId]!;
    final isFormulaResult = data['isFormulaResult'] as bool? ?? false;
    final grandTotal = data['grandTotal'] as double? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF451A03).withValues(alpha: 0.3),
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
                color: Color(0xFFD97706),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFormulaResult ? 'Peso Calculado por racimo' : 'Peso Calculado por Lote',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Si es resultado de fórmula, mostrar de forma simple
          if (isFormulaResult) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resultado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFF451A03)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_formatDecimal(grandTotal)} kg',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CopyValueButton(
                        value: _formatDecimal(grandTotal),
                        semanticLabel: 'Copiar peso calculado',
                        iconSize: 13,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]
          // Si es cálculo tradicional, mostrar desglose por lote
          else ...[
            if (data['resultsByHeadquarter'] != null)
              ...((data['resultsByHeadquarter'] as Map<int, Map<String, dynamic>>)
                  .entries
                  .map((hqEntry) {
                final headquarterId = hqEntry.key;
                final hqData = hqEntry.value;
                final headquarterName =
                    hqData['headquarterName'] as String? ?? 'Lote $headquarterId';
                final weight = hqData['weight'] as double? ?? 0;
                final totalResults = hqData['totalResults'] as int? ?? 0;
                final calculatedWeight = hqData['calculatedWeight'] as double? ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD97706).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del lote
                        Text(
                          headquarterName,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Fórmula: resultados x peso = total
                        Row(
                          children: [
                            // Resultados
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$totalResults',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '×',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            // Peso unitario
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA500)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_formatDecimal(weight)} kg',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '=',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            // Peso calculado
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD97706), Color(0xFF451A03)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_formatDecimal(calculatedWeight)} kg',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CopyValueButton(
                              value: _formatDecimal(calculatedWeight),
                              semanticLabel: 'Copiar peso calculado del lote',
                              iconSize: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              })),
            // Mostrar total general
            if (grandTotal > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFF451A03)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL GENERAL:',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_formatDecimal(grandTotal)} kg',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ===== DISTRIBUCIÓN PROPORCIONAL DE PESO — ÁRBOL INLINE =====

  /// Muestra el árbol de distribución proporcional de peso (=CALCULATION_DISTRIBUTION)
  /// Jerarquía: Lote → Operadores, con racimos y kg asignados en cada nivel.
  Widget _buildDistributionDisplay(int statusId) {
    // Guard 1: sin datos de TAG todavía
    if (_tagReaderData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Primero lea el TAG para calcular la distribución de peso',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Guard 2: cálculo aún no ejecutado
    if (!_calculatedDistributions.containsKey(statusId)) {
      return const SizedBox.shrink();
    }

    final data = _calculatedDistributions[statusId]!;
    final hasError = data['error'] == true;

    // Guard 3: error con lotes sin peso
    if (hasError && data['missingWeights'] != null) {
      final missing = data['missingWeights'] as List<Map<String, dynamic>>;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB71C1C).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB71C1C), size: 18),
                SizedBox(width: 8),
                Text(
                  'Lotes sin peso promedio configurado',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...missing.map((m) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    '• ${m['headquarterName']}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                )),
          ],
        ),
      );
    }

    // Guard 4: error genérico
    if (hasError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF57F17).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF57F17).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['errorMessage'] as String? ?? 'Error en el cálculo de distribución',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Color(0xFFF57F17),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- Renderizado del árbol ---
    final pesoNeto = data['pesoNeto'] as double;
    final factor = data['factor'] as double;
    final grandTotal = data['grandTotal'] as double;
    final lotes = data['lotes'] as Map<int, Map<String, dynamic>>;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF451A03).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Distribución de Peso',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildDistBadge(
                      label: 'Peso neto',
                      value: '${_formatDecimal(pesoNeto)} kg',
                      color: const Color(0xFFD97706),
                    ),
                    _buildDistBadge(
                      label: 'Factor',
                      value: factor.toStringAsFixed(4),
                      color: const Color(0xFF451A03),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF451A03), height: 1, thickness: 0.5),

          // Lotes (expandibles)
          ...lotes.entries.map((loteEntry) {
            final hqId = loteEntry.key;
            final lote = loteEntry.value;
            final hqName = lote['headquarterName'] as String;
            final totalResults = lote['totalResults'] as int;
            final pesoAsignado = lote['pesoAsignado'] as double;
            final operators = lote['operators'] as List<Map<String, dynamic>>;
            final expansionKey = 'DIST_${statusId}_$hqId';
            final isExpanded = _distributionExpansionState[expansionKey] ?? false;

            return Column(
              children: [
                // Fila de lote (header expandible)
                InkWell(
                  onTap: () => setState(() {
                    _distributionExpansionState[expansionKey] = !isExpanded;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          color: const Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hqName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildDistBadge(
                                label: '',
                                value: '$totalResults rac.',
                                color: const Color(0xFF2196F3).withValues(alpha: 0.7),
                                compact: true,
                              ),
                              _buildDistBadge(
                                label: '',
                                value: '${_formatDecimal(pesoAsignado)} kg',
                                color: const Color(0xFFD97706).withValues(alpha: 0.7),
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Filas de operadores (visibles cuando expandido)
                if (isExpanded)
                  ...operators.map((op) {
                    final opName = op['operatorName'] as String? ?? op['operatorId'] as String? ?? '—';
                    final op2Name = op['operator2Name'] as String? ?? '';
                    final opResults = op['results'] as int;
                    final pesoOp = op['pesoOp'] as double;
                    final displayName = opName.isNotEmpty ? opName.toUpperCase() : (op['operatorId'] as String? ?? '—');
                    return Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, color: Color(0xFFFBBF24), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD8F3DC),
                                    ),
                                  ),
                                  if (op2Name.isNotEmpty)
                                    Text(
                                      'Cortero: $op2Name',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 11,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildDistBadge(
                                    label: '',
                                    value: '$opResults rac.',
                                    color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                                    compact: true,
                                  ),
                                  _buildDistBadge(
                                    label: '',
                                    value: '${_formatDecimal(pesoOp)} kg',
                                    color: const Color(0xFFD97706).withValues(alpha: 0.5),
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const Divider(color: Color(0xFF451A03), height: 1, thickness: 0.3),
              ],
            );
          }),

          // Footer total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                const Text(
                  'TOTAL DISTRIBUIDO:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFBBF24),
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_formatDecimal(grandTotal)} kg',
                    style: const TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  /// Badge compacto reutilizable para el árbol de distribución
  Widget _buildDistBadge({
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: label.isEmpty
          ? Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
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

    debugPrint(
        '📅 _buildDateValueDisplay: statusId=$statusId parentStepId=$parentStepId raw="$dateValue"');

    // Vacío o placeholder → resolver a la fecha actual para no dejar el campo
    // sin valor visible. Lo mismo aplica si todavía contiene la fórmula sin
    // resolver (=DATENOW) porque la auto-inicialización aún no corrió o la
    // entrada en visitDetails se persistió literalmente.
    if (dateValue.isEmpty ||
        dateValue == '[Fecha]' ||
        dateValue.startsWith('=')) {
      dateValue = DateTime.now().toIso8601String();
    }

    // Formatear la fecha
    try {
      DateTime date;
      try {
        date = DateFormat('dd/MM/yyyy').parse(dateValue);
      } catch (_) {
        date = DateTime.parse(dateValue);
      }
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

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  formattedDate,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CopyValueButton(
                value: formattedDate,
                semanticLabel: 'Copiar fecha',
                iconSize: 10,
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

    debugPrint(
        '⏰ _buildTimeValueDisplay: statusId=$statusId parentStepId=$parentStepId raw="$timeValue"');

    // Vacío, placeholder o fórmula no resuelta → caer a la hora actual para
    // mantener el campo siempre visible.
    if (timeValue.isEmpty ||
        timeValue == '[Hora]' ||
        timeValue.startsWith('=')) {
      final now = TimeOfDay.now();
      timeValue =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              _CopyValueButton(
                value: formattedTime,
                semanticLabel: 'Copiar hora',
                iconSize: 10,
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
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentValue =
        widget.initialValue > 0 ? widget.initialValue.toString() : '';
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final digitKeys = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    if (digitKeys.containsKey(key)) {
      _onNumberPressed(digitKeys[key]!);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _onConfirm();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _onClear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Material(
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
                        color: Colors.white,
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
                        color: const Color(0xFF40916C).withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _currentValue.isEmpty ? '0' : _currentValue,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF74C69D),
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
                              const Color(0xFF40916C),
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
                              colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2D6A4F)
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
                Color(0xFF40916C),
                Color(0xFF1B4332),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B4332).withValues(alpha: 0.5),
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

// Diálogo de búsqueda de usuarios de pantalla completa
class _FullScreenUserSearchDialog extends StatefulWidget {
  const _FullScreenUserSearchDialog();

  @override
  State<_FullScreenUserSearchDialog> createState() =>
      _FullScreenUserSearchDialogState();
}

class _FullScreenUserSearchDialogState
    extends State<_FullScreenUserSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UsersStruct> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String searchText) async {
    if (searchText.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await actions.searchUsersSqlite(searchText);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('❌ Error buscando usuarios: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Fila de título y botón cerrar
                    Row(
                      children: [
                        // Botón volver
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Título
                        const Expanded(
                          child: Text(
                            'Buscar Usuario',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Barra de búsqueda
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o código...',
                          hintStyle: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 24,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchResults = [];
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onChanged: (value) async {
                          await _performSearch(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de resultados
              Expanded(
                child: _isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFB45309)
                                            .withValues(alpha: 0.2),
                                        const Color(0xFF92400E)
                                            .withValues(alpha: 0.2),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_search,
                                    size: 60,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Escribe para buscar'
                                      : 'No se encontraron usuarios',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Busca por nombre o código de usuario'
                                      : 'Intenta con otro término de búsqueda',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserCard(user);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UsersStruct user) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(user);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Row(
              children: [
                // Avatar con iniciales
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFB45309),
                        Color(0xFF92400E),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFB45309),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getUserInitials(user.nameUser),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información del usuario
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nameUser,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFB45309).withValues(alpha: 0.3),
                              const Color(0xFF92400E).withValues(alpha: 0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFB45309)
                                .withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tag,
                              size: 14,
                              color: Color(0xFF92400E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Código: ${user.operID}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Icono de navegación
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFB45309),
                        Color(0xFF92400E),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUserInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

// Widget para mostrar la miniatura del video (primer frame)
class _VideoThumbnail extends StatefulWidget {
  final String videoPath;

  const _VideoThumbnail({required this.videoPath});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('🎬 Inicializando thumbnail para video: ${widget.videoPath}');

      final file = File(widget.videoPath);
      if (!await file.exists()) {
        debugPrint('❌ Video no existe: ${widget.videoPath}');
        setState(() {
          _hasError = true;
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      // Pausar en el primer frame
      await _controller!.seekTo(Duration.zero);
      await _controller!.pause();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      debugPrint('✅ Thumbnail inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error al inicializar thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Mostrar ícono de error si hubo problema
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[300],
        child: const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 40,
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      // Mostrar indicador de carga
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
          ),
        ),
      );
    }

    // Mostrar el primer frame del video
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Control de Pasos moderno para formularios EXTRACTORA
// ─────────────────────────────────────────────────────────────────────────────
class _ModernTabBar extends StatefulWidget {
  final TabController controller;
  final List<dynamic> steps;
  final bool Function(int id, String type) getCachedValue;
  final dynamic Function(dynamic json, String path) getJsonField;

  const _ModernTabBar({
    required this.controller,
    required this.steps,
    required this.getCachedValue,
    required this.getJsonField,
  });

  @override
  State<_ModernTabBar> createState() => _ModernTabBarState();
}

class _ModernTabBarState extends State<_ModernTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Iconos por índice de paso (se repite si hay más de 8 pasos)
  static const List<IconData> _stepIcons = [
    Icons.description_outlined,
    Icons.local_shipping_outlined,
    Icons.warehouse_outlined,
    Icons.analytics_outlined,
    Icons.verified_outlined,
    Icons.rule_outlined,
    Icons.science_outlined,
    Icons.star_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!widget.controller.indexIsChanging) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final currentIndex = widget.controller.index;
    final count = steps.length;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(count * 2 - 1, (rawIndex) {
            // Indices pares = pasos, impares = conectores
            if (rawIndex.isOdd) {
              final leftIndex = rawIndex ~/ 2;
              final leftCompleted = () {
                final s = steps[leftIndex];
                final id = widget.getJsonField(s, r'''$.id_activity_step''') as int?;
                return id != null && widget.getCachedValue(id, 'STEP');
              }();
              // ── Línea conectora ──────────────────────────────────────
              return SizedBox(
                width: 36,
                child: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: leftCompleted
                          ? const LinearGradient(
                              colors: [Color(0xFF92400E), Color(0xFFB45309)],
                            )
                          : null,
                      color: leftCompleted ? null : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              );
            }

            final i = rawIndex ~/ 2;
            final step = steps[i];
            final stepName = widget.getJsonField(step, r'''$.name_step''').toString();
            final stepId = widget.getJsonField(step, r'''$.id_activity_step''') as int?;
            final isCompleted = stepId != null && widget.getCachedValue(stepId, 'STEP');
            final isSelected = i == currentIndex;
            final icon = _stepIcons[i % _stepIcons.length];

            return GestureDetector(
              onTap: () => widget.controller.animateTo(i),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Círculo del paso ──────────────────────────────
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        final scale = isSelected && !isCompleted ? _pulseAnim.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isCompleted
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFF59E0B), Color(0xFF92400E)],
                                )
                              : isSelected
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFF8C00), Color(0xFFB45309)],
                                    )
                                  : null,
                          color: isCompleted || isSelected
                              ? null
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFFF59E0B)
                                : isSelected
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white.withValues(alpha: 0.25),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: isCompleted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF92400E).withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFB45309).withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: Colors.transparent,
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    key: ValueKey('check'),
                                    color: Colors.white,
                                    size: 22,
                                  )
                                : Icon(
                                    icon,
                                    key: ValueKey('icon_$i'),
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.45),
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // ── Nombre del paso ───────────────────────────────
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isCompleted
                            ? const Color(0xFFF59E0B)
                            : isSelected
                                ? const Color(0xFFF59E0B)
                                : Colors.white.withValues(alpha: 0.45),
                        letterSpacing: 0.2,
                        height: 1.3,
                      ),
                      child: Text(
                        stepName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AdbPrintPreviewDialog extends StatefulWidget {
  final String html;
  final String title;
  final String pdfFilename;
  // Callback que el padre conecta al UPDATE de Visits_details
  // (Status_response = "SI") cuando el usuario confirma la impresión.
  final VoidCallback? onPrinted;

  const _AdbPrintPreviewDialog({
    required this.html,
    required this.title,
    this.pdfFilename = 'ticket',
    this.onPrinted,
  });

  @override
  State<_AdbPrintPreviewDialog> createState() => _AdbPrintPreviewDialogState();
}

class _AdbPrintPreviewDialogState extends State<_AdbPrintPreviewDialog> {
  bool _savingPdf = false;

  @override
  Widget build(BuildContext context) {
    final isConnected = AdbNfcBridgeService.instance.isClientConnected;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1B5E20),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
            // Contenido HTML scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: HtmlWidget(
                  widget.html,
                  textStyle: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  onTapUrl: (_) => true,
                ),
              ),
            ),
            // Botones GUARDAR PDF + IMPRIMIR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _savingPdf
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      children: [
                        // GUARDAR PDF
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              setState(() => _savingPdf = true);
                              try {
                                await actions.savePdfToFile(
                                  context,
                                  widget.html,
                                  widget.pdfFilename,
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Error al guardar PDF: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _savingPdf = false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'GUARDAR PDF',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // IMPRIMIR
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              final sent =
                                  AdbNfcBridgeService.instance.sendPrintRequest(
                                htmlContent: widget.html,
                                title: widget.title,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(sent
                                      ? '📲 Solicitud de impresión enviada al Android'
                                      : '⚠️ No hay dispositivo Android conectado'),
                                  backgroundColor: sent
                                      ? const Color(0xFF00a86b)
                                      : const Color(0xFFE53935),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              if (sent) {
                                widget.onPrinted?.call();
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isConnected
                                      ? const [
                                          Color(0xFF00a86b),
                                          Color(0xFF007552)
                                        ]
                                      : const [
                                          Color(0xFF616161),
                                          Color(0xFF424242)
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.print_rounded,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    isConnected
                                        ? 'IMPRIMIR'
                                        : 'IMPRIMIR',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}

// Modo de render del card del tag ADB: el árbol (jerárquico Lote → Carguero)
// para el flujo clásico, o la tabla plana (1 fila por par CARGUERO × LOTE)
// para el panel DATOS PRINCIPALES.
enum AdbCardDisplayMode { tree, table }

// Fila de la tabla de tiquete del panel DATOS PRINCIPALES — una por record de
// Visits[] del tag ADB. Sin agregación.
class _TiqueteRow {
  final int tiquete;
  final DateTime? fechaCorte;
  final String loteName;
  final int racimos;
  final double? pesoPromedio;
  final double pesoAproximado;
  final String cargueroNombre;
  final String cargueroIdentificacion;
  _TiqueteRow({
    required this.tiquete,
    required this.fechaCorte,
    required this.loteName,
    required this.racimos,
    required this.pesoPromedio,
    required this.pesoAproximado,
    required this.cargueroNombre,
    required this.cargueroIdentificacion,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón inline de "copiar al portapapeles" usado en el árbol del control
// tag-transfer-adb-server (niveles Lote / Racimos lote / Carguero / Racimos
// carguero). Muestra feedback elegante en el propio botón: el icono cambia a
// un check verde y aparece una pequeña burbuja flotante "¡Copiado!" durante
// ~1.2s. Detiene la propagación del tap para no disparar el InkWell padre.
// ─────────────────────────────────────────────────────────────────────────────
class _CopyValueButton extends StatefulWidget {
  final String value;
  final String? semanticLabel;
  final double iconSize;

  const _CopyValueButton({
    required this.value,
    this.semanticLabel,
    this.iconSize = 13,
  });

  @override
  State<_CopyValueButton> createState() => _CopyValueButtonState();
}

class _CopyValueButtonState extends State<_CopyValueButton> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    Clipboard.setData(ClipboardData(text: widget.value));
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.iconSize <= 11 ? 4.0 : 5.0;
    final pillColor = _copied
        ? const Color(0xFF4ADE80).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.12);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Semantics(
          label: widget.semanticLabel ?? 'Copiar valor',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _copied
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('copied'),
                        size: widget.iconSize + 1,
                        color: const Color(0xFF4ADE80),
                      )
                    : Icon(
                        Icons.copy_rounded,
                        key: const ValueKey('copy'),
                        size: widget.iconSize,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: widget.iconSize + padding * 2 + 4,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              offset: _copied ? Offset.zero : const Offset(0, 0.35),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _copied ? 1.0 : 0.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B4332),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.45),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '¡Copiado!',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
