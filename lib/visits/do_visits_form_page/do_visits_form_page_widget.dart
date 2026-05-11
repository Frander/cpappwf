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
import 'package:nfc_manager/nfc_manager.dart';
import '/custom_code/actions/adb_nfc_bridge_service.dart';
import '/custom_code/actions/adb_nfc_client_service.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
    with AutomaticKeepAliveClientMixin {
  late DoVisitsFormPageModel _model;

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
  final Map<int, String> _tagTransferSourceContent = {}; // raw NFC JSON por statusId

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

  // ── ADB NFC Bridge (tag-transfer-adb-server / tag-transfer-adb-from) ──────
  AdbBridgeStatus _adbServerStatus = AdbBridgeStatus.serverDown;
  StreamSubscription<AdbBridgeStatus>? _adbStatusSub;
  StreamSubscription<Map<String, dynamic>>? _adbTagSub;
  // statusId -> received tag payload from mobile
  final Map<int, Map<String, dynamic>> _adbReceivedTagData = {};
  // mobile client connection state (for tag-transfer-adb-from)
  bool _adbClientConnected = false;
  StreamSubscription<bool>? _adbClientConnSub;
  StreamSubscription<Map<String, dynamic>>? _adbServerCommandSub;
  Timer? _adbRetryTimer; // reintento automático si no conecta al iniciar

  // Caché de nombres de corteros desde SQLite (id_activity_status -> status_name)
  final Map<int, String> _corteroNamesCache = {};

  // Caché de nombres de usuarios desde SQLite (id_user -> name_user)
  final Map<int, String> _userNamesCache = {};

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

  // Caché de hijos de reference-list cargados desde activitiesJSON por default_status
  // statusId → List<dynamic> de statuses de la actividad referenciada
  final Map<int, List<dynamic>> _referenceListChilds = {};

  // Caché del status padre reference-list (para poder guardar su fila en
  // visitDetails cuando se selecciona un hijo). statusId → status JSON.
  final Map<int, dynamic> _referenceListParents = {};

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
    _model = createModel(context, () => DoVisitsFormPageModel());
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
    });
  }

  // Inicia el servidor ADB (desktop) o el cliente ADB (mobile) según los campos renderizados
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
      _adbStatusSub = AdbNfcBridgeService.instance.onStatusChanged.listen((status) {
        if (mounted) setState(() => _adbServerStatus = status);
      });
      _adbTagSub = AdbNfcBridgeService.instance.onTagReceived.listen((payload) {
        if (!mounted) return;

        // Recopilar los statuses procesados ANTES del setState para poder
        // disparar los cálculos de pesos async después (setState es síncrono).
        final List<({int id, String name, List<Map<String, dynamic>> parsedData})>
            processedStatuses = [];

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

            final defaultStatus =
                getJsonField(s, r'''$.default_status''')?.toString() ?? '';
            final isNoRemove = defaultStatus.contains('=ACTIONS:NO_REMOVE');

            if (isNoRemove) {
              // Modo acumulativo: agregar al array y aplanar todos
              _tagReaderRawJsons[id] ??= [];
              _tagReaderRawJsons[id]!.add(tagContent);
              final allRecords = <Map<String, dynamic>>[];
              for (final raw in _tagReaderRawJsons[id]!) {
                allRecords.addAll(_parseNfcTagContent(raw));
              }
              _tagReaderData[id] = allRecords;
            } else {
              // Modo normal: reemplazar
              _tagReaderRawJsons.remove(id);
              _tagReaderData[id] = _parseNfcTagContent(tagContent);
            }
            _tagReaderProductName[id] = productName;

            // Registrar para post-setState cálculos de peso
            final statusName =
                getJsonField(s, r'''$.name_status''')?.toString() ?? '';
            processedStatuses.add((
              id: id,
              name: statusName,
              parsedData: List<Map<String, dynamic>>.from(_tagReaderData[id]!),
            ));
          }
        });

        // Cálculos de pesos async — misma lógica que tag-reader tras leer un tag
        if (processedStatuses.isNotEmpty) {
          Future(() async {
            for (final entry in processedStatuses) {
              if (!mounted) return;
              debugPrint(
                  '⚡ ADB-TAG: Disparando cálculos de pesos para statusId=${entry.id} name="${entry.name}"');

              // 1. Validar / calcular pesos por lote (igual que tag-reader)
              if (_hasHeadquartersWeightsStatus()) {
                final List<int> tagHeadquarterIds = [];
                for (var record in entry.parsedData) {
                  final hqId = record['headquarterId'] as int? ?? 0;
                  if (hqId > 0 && !tagHeadquarterIds.contains(hqId)) {
                    tagHeadquarterIds.add(hqId);
                  }
                }

                if (tagHeadquarterIds.isNotEmpty) {
                  await _loadHeadquarterWeights(tagHeadquarterIds);

                  if (_headquartersWithoutWeight.isNotEmpty && mounted) {
                    _showWeightWarningDialog();
                  }

                  _calculateHeadquarterWeightResults(entry.id, entry.name);
                }
              }

              // 2. Calcular distancias relacionadas
              await _autoCalculateRelatedDistances(entry.id, entry.name);

              // 3. Calcular campos headquarter-weight que referencien este tag
              debugPrint(
                  '🎯 ADB-TAG: _autoCalculateRelatedHeadquarterWeights() statusName="${entry.name}"');
              await _autoCalculateRelatedHeadquarterWeights(
                  entry.id, entry.name);
            }
          });
        }
      });
      AdbNfcBridgeService.instance.start().then((_) {
        if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
      });
    }

    if (hasFromField && Platforms.isMobile) {
      _adbClientConnSub = AdbNfcClientService.instance.onConnectionChanged.listen((connected) {
        if (mounted) {
          setState(() => _adbClientConnected = connected);
          if (!connected) _scheduleAdbRetry(); // reconectar si se cae
        }
      });
      _tryAdbConnect();

      // Escuchar comandos enviados desde Windows → Android
      _adbServerCommandSub = AdbNfcClientService.instance.onServerCommand.listen(
        (msg) => _handleAdbServerCommand(msg),
      );
    }
  }

  /// Procesa comandos recibidos desde el servidor Windows.
  void _handleAdbServerCommand(Map<String, dynamic> msg) {
    if (!mounted) return;
    final type = msg['type'] as String? ?? '';
    if (type == 'request_nfc_read') {
      debugPrint('📨 ADB-FROM: request_nfc_read recibido desde Windows — simulando tap');
      _triggerAdbFromNfcRead();
    } else if (type == 'request_print') {
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      final htmlContent = payload['htmlContent'] as String? ?? '';
      final title = payload['title'] as String? ?? 'Impresión';
      if (htmlContent.isNotEmpty) {
        debugPrint('🖨️ ADB-FROM: request_print recibido — imprimiendo directo');
        _printDirectFromAdb(htmlContent, title);
      }
    }
  }

  Future<void> _printDirectFromAdb(String htmlContent, String title) async {
    if (!mounted) return;
    debugPrint('🖨️ Iniciando impresión directa via ADB...');

    // Mostrar indicador
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [
          SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Imprimiendo...'),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        duration: const Duration(seconds: 30),
      ),
    );

    BluetoothDevice? connectedDevice;
    try {
      // Obtener MAC de la impresora
      String? printerMac = FFAppState().printerMacAddress;
      if (printerMac.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        printerMac = prefs.getString('printer_address');
      }

      if (!mounted) return;
      if (printerMac == null || printerMac.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No hay impresora configurada'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Permisos Bluetooth (Android 12+)
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.version.sdkInt >= 31) {
          final result = await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();
          if (result[Permission.bluetoothScan]?.isGranted != true ||
              result[Permission.bluetoothConnect]?.isGranted != true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Permisos Bluetooth denegados'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }
      }

      // Verificar Bluetooth encendido
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Bluetooth desactivado'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      connectedDevice = BluetoothDevice.fromId(printerMac);
      await connectedDevice.connect(timeout: const Duration(seconds: 15));
      debugPrint('✅ Conectado a impresora: $printerMac');

      final services = await connectedDevice.discoverServices();
      BluetoothCharacteristic? writeChar;
      for (final svc in services) {
        for (final ch in svc.characteristics) {
          if (ch.properties.write || ch.properties.writeWithoutResponse) {
            writeChar = ch;
            break;
          }
        }
        if (writeChar != null) break;
      }

      if (writeChar == null) throw Exception('Sin característica de escritura');

      final bytes = actions.htmlToEscPosBytes(htmlContent);

      final data = Uint8List.fromList(bytes);
      for (int i = 0; i < data.length; i += 20) {
        final end = (i + 20 < data.length) ? i + 20 : data.length;
        await writeChar.write(data.sublist(i, end), withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      debugPrint('✅ Impresión completada');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Impreso correctamente'),
          backgroundColor: Color(0xFF00a86b),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ _printDirectFromAdb: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al imprimir: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      try { await connectedDevice?.disconnect(); } catch (_) {}
    }
  }

  /// Busca el primer status de tipo tag-transfer-adb-from y simula el tap
  /// (abre el diálogo NFC y envía el resultado al servidor).
  Future<void> _triggerAdbFromNfcRead() async {
    if (!Platforms.isMobile) return;

    // Asegurar conexión activa
    if (!AdbNfcClientService.instance.isConnected) {
      final connected = await AdbNfcClientService.instance.connect();
      if (!mounted) return;
      setState(() => _adbClientConnected = connected);
      if (!connected) return;
    }

    // Abrir diálogo NFC — mismo flujo que el tap manual
    if (!mounted) return;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => const Dialog(
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: NfcReadDialogWidget(
          autoStart: true,
          isTagTransferMode: false,
        ),
      ),
    );
    if (!mounted) return;

    final nfcContent = FFAppState().nfcRead;
    if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
      await AdbNfcClientService.instance.sendTagData(tagContent: nfcContent);
      if (!mounted) return;

      // Reflejar el resumen inline en Android también (igual que el tap manual)
      // Buscar el statusId del campo adb-from para actualizar _tagReaderData
      final allStatuses = <dynamic>[..._cachedActivityStatus];
      for (final step in _cachedActivitySteps) {
        final ss = getJsonField(step, r'''$.activities_status''');
        if (ss is List) allStatuses.addAll(ss);
      }
      for (final s in allStatuses) {
        final t = getJsonField(s, r'''$.type_status''')?.toString().toLowerCase() ?? '';
        if (t == 'tag-transfer-adb-from') {
          final id = getJsonField(s, r'''$.id_activity_status''') as int?;
          if (id != null) {
            setState(() {
              _tagReaderData[id] = _parseNfcTagContent(nfcContent);
              _tagReaderProductName[id] = '';
            });
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📡 Tag enviado al servidor desktop'),
        backgroundColor: Color(0xFF00a86b),
        duration: Duration(seconds: 3),
      ));
    }
  }

  /// Intenta conectar al servidor ADB. Si falla, programa un reintento.
  void _tryAdbConnect() {
    AdbNfcClientService.instance.connect().then((connected) {
      if (!mounted) return;
      setState(() => _adbClientConnected = connected);
      if (!connected) _scheduleAdbRetry();
    });
  }

  /// Reintenta la conexión cada 5 segundos hasta lograrla.
  void _scheduleAdbRetry() {
    _adbRetryTimer?.cancel();
    _adbRetryTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || AdbNfcClientService.instance.isConnected) return;
      _tryAdbConnect();
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
    // Los hijos viven en otra actividad referenciada por el campo default_status del status raíz
    _referenceListChilds.clear();
    _referenceListParents.clear();
    final activitiesJson = FFAppState().activitiesJSON;
    if (activitiesJson is List) {
      final Map<int, dynamic> activityById = {};
      for (var act in activitiesJson) {
        final actId = getJsonField(act, r'''$.id_activity''');
        if (actId is int) activityById[actId] = act;
      }
      for (var status in _cachedActivityStatus) {
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
        final refStatuses = getJsonField(refActivity, r'''$.activity_status''');
        if (refStatuses is List && refStatuses.isNotEmpty) {
          _referenceListChilds[statusId as int] = refStatuses;
          _referenceListParents[statusId] = status;
          _rootStatusExpansionState[statusId] = true; // auto-expandir
          debugPrint('✅ reference-list status $statusId: ${refStatuses.length} hijos desde actividad $refActivityId');
        } else {
          debugPrint('⚠️ reference-list status $statusId: actividad $refActivityId sin statuses raíz');
        }
      }
    }

    _isDataCacheInitialized = true;
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
      bool result = functions.searchInVisitsDetails(
        FFAppState().visitDetails.toList(),
        id,
        type,
      );

      // Fallback reference-list: los hijos de un status `reference-list` NO
      // tienen fila propia en visitDetails (solo la tiene el padre con el
      // nombre del hijo en statusResponse). Para que el render verde funcione,
      // consideramos al hijo "seleccionado" si la fila del padre lleva su
      // status_name en statusResponse.
      if (!result && type.toUpperCase() == 'STATUS') {
        final refInfo = _findReferenceListParent(id);
        if (refInfo != null) {
          String? childName;
          for (final c in refInfo.siblings) {
            if (getJsonField(c, r'''$.id_activity_status''') == id) {
              childName = getJsonField(c, r'''$.status_name''')?.toString();
              break;
            }
          }
          if (childName != null && childName.isNotEmpty) {
            for (final d in FFAppState().visitDetails) {
              if (d.idActivityStatus == refInfo.parentId &&
                  d.statusResponse == childName) {
                result = true;
                break;
              }
            }
          }
        }
      }

      _visitDetailsSearchCache[cacheKey] = result;
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
    // Limpiar ADB bridge
    _adbStatusSub?.cancel();
    _adbTagSub?.cancel();
    _adbClientConnSub?.cancel();
    _adbServerCommandSub?.cancel();
    _adbRetryTimer?.cancel();
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
        final nfcContent = prefs.getString(key) ?? '';
        if (nfcContent.isEmpty) continue;

        if (_tagTransferData.containsKey(statusId)) {
          // _tagTransferData ya cargado (por form cache), pero asegurar que el contenido raw esté disponible
          if (!_tagTransferSourceContent.containsKey(statusId)) {
            setState(() => _tagTransferSourceContent[statusId] = nfcContent);
          }
          continue;
        }

        final parsedData = _parseNfcTagContentByHeadquarter(nfcContent);
        if (parsedData.isNotEmpty) {
          setState(() {
            _tagTransferData[statusId] = parsedData;
            _tagTransferSourceContent[statusId] = nfcContent;
          });
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
            debugPrint('🎲 NUMBER =RANDOM ya tiene valor, saltando: $statusName');
          }
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

  /// Retorna nombres de status sin respuesta en visitDetails.
  /// Excluye el statusId del tag-transfer actual y tipos contenedor/infraestructura.
  List<String> _getUnresolvedStatuses({required int skipStatusId}) {
    const skipTypes = {
      'step',
      'tag-transfer',
      'tag-transfer-adb-server',
      'tag-transfer-adb-from',
      'dynamic-printing',
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
        // Coincide con la lógica del UI (`searchInVisitsDetails`): basta con que
        // exista una fila para este id_activity_status. El statusResponse puede
        // estar vacío para opciones tipo radio cuando defaultStatus es vacío,
        // pero la fila ya indica que el usuario seleccionó la opción.
        final hasValue = FFAppState()
            .visitDetails
            .any((d) => d.idActivityStatus == id);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _responsiveColumnCount(constraints.maxWidth);

        if (columns == 1) {
          // Pantalla pequeña: lista vertical con lazy loading
          return ListView.separated(
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
        }

        // Pantalla mediana/grande: grilla responsiva con Wrap
        const double spacing = 12.0;
        const double hPadding = 24.0; // 12 izq + 12 der
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1) - hPadding) /
            columns;

        final cardWidgets = <Widget>[
          for (int i = 0; i < activitySteps.length; i++)
            SizedBox(
              width: itemWidth,
              child: _buildStepCard(activitySteps[i], level: 0),
            ),
          for (int i = 0; i < activityStatus.length; i++)
            SizedBox(
              width: itemWidth,
              child: _buildRootStatusCard(
                activityStatus[i],
                allActivityStatus: activityStatus,
                level: 0,
              ),
            ),
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cardWidgets,
            ),
          ),
        );
      },
    );
  }

  /// Determina el número de columnas según el ancho disponible del widget.
  /// < 600px → 1 columna (lista), 600–899px → 2 columnas, ≥ 900px → 3 columnas.
  int _responsiveColumnCount(double availableWidth) {
    if (availableWidth >= 900) return 3;
    if (availableWidth >= 600) return 2;
    return 1;
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
                  ? const Color(0xFF00a86b)
                  : const Color(0xFFF1F8F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
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
                      color: const Color(0xFF00a86b),
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
                                    : const Color(0xFF00a86b),
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
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFF57C00),
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
      {required int level, int? parentMultipleOptionId}) {
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
              // Si ya se leyó el tag origen, bloquear el tap — solo debe usarse TRANSFERIR AHORA
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
                  _tagTransferSourceContent[statusId] = nfcContent;
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
                      backgroundColor: Color(0xFF00a86b),
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

            // tag-transfer-adb-server: el tap intenta habilitar el socket (solo desktop)
            if (isTagTransferAdbServerType) {
              if (Platforms.isDesktop && !AdbNfcBridgeService.instance.isServerRunning) {
                await AdbNfcBridgeService.instance.start();
                if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
              }
              return;
            }

            // tag-transfer-adb-from: el tap lee NFC y envía datos al server (solo móvil)
            if (isTagTransferAdbFromType) {
              if (Platforms.isMobile) {
                if (!AdbNfcClientService.instance.isConnected) {
                  final connected = await AdbNfcClientService.instance.connect();
                  if (!mounted) return;
                  setState(() => _adbClientConnected = connected);
                  if (!connected) return;
                }
                // Abrir diálogo NFC de lectura
                if (!mounted) return;
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  await AdbNfcClientService.instance.sendTagData(tagContent: nfcContent);
                  if (!mounted) return;
                  // Mostrar resumen inline en el dispositivo Android también
                  setState(() {
                    _tagReaderData[statusId] = _parseNfcTagContent(nfcContent);
                    _tagReaderProductName[statusId] = '';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop'),
                    backgroundColor: Color(0xFF00a86b),
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

            // Si es tipo headquarter-weight, cargar weights desde SQLite y calcular
            if (isHeadquarterWeightType) {
              // Buscar el tag-reader previo en el árbol de steps
              // Obtener todos los headquarterIds del tag-reader más reciente
              final List<int> headquarterIds = [];
              int? tagReaderStatusId;

              // Buscar en _tagReaderData el status anterior
              for (var entry in _tagReaderData.entries) {
                tagReaderStatusId = entry.key;
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

                // Calcular peso total: resultados x weight por cada headquarter
                if (tagReaderStatusId != null) {
                  _calculateHeadquarterWeightResults(
                      tagReaderStatusId, 'tag-reader');
                }
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

              await _onStatusSelected(parentStep, status);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: (isTagTransferAdbFromType && Platforms.isMobile)
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        !isTextType &&
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
                    // Radio button visual (no mostrar para tag-transfer, adb-server, adb-from, text, photo, video, number, users-list)
                    if (!isTagTransferType && !isTagTransferAdbServerType && !isTagTransferAdbFromType && !isTextType && !isPhotoType && !isVideoType && !isNumberType && !isUsersListType)
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
                    if (!isTagTransferType && !isTagTransferAdbServerType && !isTagTransferAdbFromType && !isTextType && !isPhotoType && !isVideoType && !isNumberType && !isUsersListType) const SizedBox(width: 12),
                    // Icono específico para date, time, photo y video, indicador de color para otros tipos (excepto number, users-list y text)
                    if (!isTagReaderType && !isTagWriterType && !isTagTransferType && !isNumberType && !isUsersListType && !isTextType)
                      // Para photo y video: solo mostrar icono sin contenedor de fondo cuando no está seleccionado
                      (isPhotoType || isVideoType) && !isSelected
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                isPhotoType
                                    ? Icons.photo_camera_rounded
                                    : Icons.videocam_rounded,
                                color: const Color(0xFF00a86b), // Verde oscuro consistente
                                size: 24,
                              ),
                            )
                          : Container(
                              width: 32,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isDateType || isTimeType || isPhotoType || isVideoType)
                                    ? (isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : ((isPhotoType || isVideoType)
                                            ? const Color(0xFF00a86b).withValues(alpha: 0.2)
                                            : color.withValues(alpha: 0.2)))
                                    : color,
                                borderRadius: BorderRadius.circular(6),
                                border: (isDateType || isTimeType || isPhotoType || isVideoType)
                                    ? Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : ((isPhotoType || isVideoType)
                                                ? const Color(0xFF00a86b)
                                                : color),
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSelected
                                        ? Colors.white
                                        : ((isPhotoType || isVideoType)
                                            ? const Color(0xFF00a86b)
                                            : color)).withValues(alpha: 0.6),
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
                                      : isPhotoType
                                          ? Icon(
                                              Icons.photo_camera_rounded,
                                              color: isSelected ? Colors.white : const Color(0xFF00a86b),
                                              size: 20,
                                            )
                                          : isVideoType
                                              ? Icon(
                                                  Icons.videocam_rounded,
                                                  color: isSelected ? Colors.white : const Color(0xFF00a86b),
                                                  size: 20,
                                                )
                                              : null,
                            ),
                    if (!isTagReaderType && !isTagWriterType && !isTextType)
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
                          // Resumen ADB server en Windows (con checkbox)
                          if (isTagTransferAdbServerType && _tagReaderData.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTagReaderSummary(statusId: statusId, isAdbServer: true),
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
                          // Display para distance-extractor - DEBAJO
                          if (isDistanceExtractorType &&
                              _calculatedDistances.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDistanceExtractorDisplay(
                                statusId: statusId,
                              ),
                            ),
                          // TextField INLINE para headquarter-weight (muestra fórmula evaluada)
                          if (isHeadquarterWeightType &&
                              _calculatedHeadquarterWeights.containsKey(statusId))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildHeadquarterWeightInlineDisplay(
                                statusId: statusId,
                                status: status,
                              ),
                            ),
                          // Resumen de weights of headquarters - DEBAJO
                          if (isHeadquarterWeightType &&
                              (_calculatedHeadquarterWeights.containsKey(statusId) ||
                                  _headquartersWithoutWeight.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildHeadquarterWeightsDisplay(statusId),
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

        // ╔════════════════════════════════════════════════════════════════╗
        // ║ RENDERIZACIÓN ESPECIAL PARA reference-list (type_status)      ║
        // ╚════════════════════════════════════════════════════════════════╝
        if (isReferenceListType && isExpanded && statusChilds.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: [
                // Botón de búsqueda compacto para reference-list
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: _buildCompactSearchButton(statusId, hasValue: isSelected),
                ),

                // Cuadro de búsqueda expandido (solo cuando está activo)
                if ((_searchBoxExpansionState[statusId] ?? false))
                  _buildExpandedSearchBox(statusId),

                // Renderizar statusChilds de reference-list filtrando por búsqueda
                Builder(
                  builder: (context) {
                    // Aplicar filtro de búsqueda a los statusChilds
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
                          .map<Widget>((childStatus) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildStatusOption(parentStep, childStatus,
                                  level: level + 1,
                                  parentMultipleOptionId: statusId),
                            );
                          })
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
    // Para reference-list: buscar hijos en _referenceListChilds (cargados desde activitiesJSON)
    final refListChilds = (typeStatus.toLowerCase() == 'reference-list' && statusId is int)
        ? (_referenceListChilds[statusId] ?? <dynamic>[])
        : <dynamic>[];
    final statusChildsRaw =
        getJsonField(status, r'''$.activities_status_childs''') ??
        getJsonField(status, r'''$.status_childs''');
    final statusChilds = refListChilds.isNotEmpty
        ? refListChilds
        : (statusChildsRaw != null
            ? (statusChildsRaw is List ? statusChildsRaw : [statusChildsRaw])
            : <dynamic>[]);

    // Extraer color del status para unique-option y unique_choice
    final statusColor = getJsonField(status, r'''$.color''')?.toString() ?? '#00ff9f';

    // Función para parsear color hex a Color
    Color parseColor(String hexColor) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return const Color(0xFF00ff9f); // Color por defecto
      }
    }

    final statusColorParsed = parseColor(statusColor);

    // Log de renderizado
    debugPrint(
        '🎯 RENDERIZANDO ROOT STATUS: nombre="$statusName" tipo="$typeStatus" ID=$statusId nivel=$level stepsChilds=${stepsChilds.length} statusChilds=${statusChilds.length}');

    final isExpanded = _rootStatusExpansionState[statusId] ?? false;
    // LOTE 1: Usar búsqueda cacheada
    final hasValue = _cachedSearchInVisitDetails(statusId, 'STATUS');

    final hasChildren = stepsChilds.isNotEmpty || statusChilds.isNotEmpty;
    debugPrint('   hasChildren=$hasChildren isExpanded=$isExpanded typeStatus="$typeStatus"');

    // Para status de tipo "number", "tag-writer", "tag-reader", "tag-transfer", "numbers-operation", "headquarter-weight", "label-info", "distance-extractor" y "dynamic-printing", NO abrir diálogo, mostrar control inline
    final isNumberType = typeStatus.toLowerCase() == 'number';
    final isReferenceListType = typeStatus.toLowerCase() == 'reference-list';
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
    final isTagTransferAdbServerType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-server';
    final isTagTransferAdbFromType =
        typeStatus.toLowerCase() == 'tag-transfer-adb-from';

    // ══ Card especial para reference-list ══
    if (isReferenceListType) {
      String? selectedOptionName;
      for (var child in refListChilds) {
        final childId = getJsonField(child, r'''$.id_activity_status''');
        if (_cachedSearchInVisitDetails(childId, 'STATUS')) {
          selectedOptionName = getJsonField(child, r'''$.status_name''')?.toString();
          break;
        }
      }
      final isSearchOpen = _searchBoxExpansionState[statusId] ?? false;
      final isSelected = selectedOptionName != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: level * 8.0),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00a86b) : const Color(0xFFF1F8F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? const Color(0xFF00a86b) : const Color(0xFFE8F5E9),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Chevron — toca para expandir/colapsar
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _rootStatusExpansionState[statusId] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                      color: isSelected ? Colors.white : const Color(0xFF00a86b),
                      size: 32,
                    ),
                  ),
                ),
                // Nombre + opción seleccionada — toca para expandir/colapsar
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _rootStatusExpansionState[statusId] = !isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusName,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF00a86b),
                            ),
                          ),
                          if (selectedOptionName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              selectedOptionName,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Botón búsqueda — tap independiente (no colapsa la lista)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _searchBoxExpansionState[statusId] = !isSearchOpen;
                      if (!isSearchOpen) {
                        _rootStatusExpansionState[statusId] = true;
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Icon(
                      isSearchOpen ? Icons.search_off : Icons.search_rounded,
                      color: isSelected ? Colors.white : const Color(0xFF00a86b),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Caja de búsqueda
          if (isSearchOpen) _buildExpandedSearchBox(statusId),
          // Lista de opciones
          if (isExpanded && refListChilds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Builder(
                builder: (ctx) {
                  final displayList = _filterStatusList(statusId, refListChilds.cast<dynamic>());
                  if (displayList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: displayList.map<Widget>((childStatus) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildRootStatusChildOption(
                          status,
                          childStatus,
                          level: level + 1,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      );
    }

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
              // Si ya se leyó el tag origen, bloquear el tap — solo debe usarse TRANSFERIR AHORA
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
                        backgroundColor: Color(0xFF00a86b),
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

            // Si es tipo dynamic-printing, el botón maneja su propia lógica
            if (isDynamicPrintingType) {
              debugPrint(
                  '🖨️ DYNAMIC-PRINTING: Tipo detectado, ignorando tap del contenedor');
              return;
            }

            // tag-transfer-adb-server: tap intenta levantar el socket (solo desktop)
            if (isTagTransferAdbServerType) {
              if (Platforms.isDesktop && !AdbNfcBridgeService.instance.isServerRunning) {
                await AdbNfcBridgeService.instance.start();
                if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
              }
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
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  await AdbNfcClientService.instance.sendTagData(tagContent: nfcContent);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop'),
                    backgroundColor: Color(0xFF00a86b),
                    duration: Duration(seconds: 3),
                  ));
                }
              }
              return;
            }

            debugPrint('👆 TAP ROOT STATUS ID=$statusId hasChildren=$hasChildren isExpanded=$isExpanded isReferenceListType=$isReferenceListType');
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
                debugPrint('   ➡️ Nuevo isExpanded=${!isExpanded}');
              });
            } else {
              debugPrint('   ⚠️ Sin hijos → _onRootStatusSelected');
              await _onRootStatusSelected(status, allRootStatus: allActivityStatus);
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: level * 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Reemplazado gradiente por color sólido para mejor rendimiento
              color: (hasValue && !isNumberType && !isTagWriterType)
                  ? const Color(0xFF00a86b)
                  : const Color(0xFFF1F8F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (hasValue && !isNumberType && !isTagWriterType)
                    ? const Color(0xFF00a86b)
                    : const Color(0xFFE8F5E9),
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
                        : const Color(0xFF00a86b),
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
                                        : const Color(0xFF00a86b),
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
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _formatColombianNumber(
                                            _getCurrentNumberValue(statusId, defaultStatus)),
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
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
                      // Resumen ADB server en Windows (con checkbox)
                      if (isTagTransferAdbServerType && _tagReaderData.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildTagReaderSummary(statusId: statusId, isAdbServer: true),
                        ),
                      // Resumen ADB (adb-from) en móvil — se muestra dentro de _buildAdbFromCard
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
                      // Display para distance-extractor
                      if (isDistanceExtractorType && _calculatedDistances.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildDistanceExtractorDisplay(statusId: statusId),
                        ),
                      // TextField INLINE para headquarter-weight (muestra fórmula evaluada)
                      if (isHeadquarterWeightType &&
                          _calculatedHeadquarterWeights.containsKey(statusId))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildHeadquarterWeightInlineDisplay(
                            statusId: statusId,
                            status: status,
                          ),
                        ),
                      // Resumen de weights de headquarters
                      if (isHeadquarterWeightType &&
                          (_calculatedHeadquarterWeights.containsKey(statusId) || _headquartersWithoutWeight.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildHeadquarterWeightsDisplay(statusId),
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
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFF57C00),
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

        // ══ Sección especial para reference-list (sin AnimatedContainer) ══
        if (isReferenceListType && isExpanded && statusChilds.isNotEmpty)
          Builder(
            builder: (ctx) {
              debugPrint('📋 RENDERIZANDO LISTA reference-list ID=$statusId con ${statusChilds.length} hijos');
              final displayList = _filterStatusList(statusId, statusChilds.cast<dynamic>());
              debugPrint('   📋 displayList.length=${displayList.length}');
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: _buildCompactSearchButton(statusId, hasValue: hasValue),
                    ),
                    if ((_searchBoxExpansionState[statusId] ?? false))
                      _buildExpandedSearchBox(statusId),
                    if (displayList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: Colors.grey.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    else
                      ...displayList.map<Widget>((childStatus) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildRootStatusChildOption(
                            status,
                            childStatus,
                            level: level + 1,
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),

        // ══ Sección genérica para otros tipos con hijos ══
        if (isExpanded && hasChildren && !isReferenceListType)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(left: level * 8.0 + 8, top: 8),
            child: Column(
              children: [
                ...statusChilds.map<Widget>((childStatus) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRootStatusChildOption(status, childStatus,
                        level: level + 1),
                  );
                }),
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
        getJsonField(childStatus, r'''$.activities_status_childs''') ??
        getJsonField(childStatus, r'''$.status_childs''');
    final statusChilds = statusChildsRaw != null
        ? (statusChildsRaw is List ? statusChildsRaw : [statusChildsRaw])
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
        return const Color(0xFF00ff9f); // Color por defecto
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
              // Si la transferencia ya está completada, NO procesar el tap
              // El botón TRANSFERENCIA EXITOSA no debe ser clickeable
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

            // tag-transfer-adb-server: tap intenta levantar el socket (solo desktop)
            if (isTagTransferAdbServerType) {
              if (Platforms.isDesktop && !AdbNfcBridgeService.instance.isServerRunning) {
                await AdbNfcBridgeService.instance.start();
                if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
              }
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
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (dialogContext) => const Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: NfcReadDialogWidget(
                      autoStart: true,
                      isTagTransferMode: false,
                    ),
                  ),
                );
                if (!mounted) return;
                final nfcContent = FFAppState().nfcRead;
                if (nfcContent.isNotEmpty && !nfcContent.startsWith('ERROR')) {
                  await AdbNfcClientService.instance.sendTagData(tagContent: nfcContent);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📡 Tag enviado al servidor desktop'),
                    backgroundColor: Color(0xFF00a86b),
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

              // Si era hijo de un reference-list y ya no queda ningún hermano
              // seleccionado, eliminar la fila del padre reference-list para
              // que la validación lo considere de nuevo pendiente.
              final refInfo = _findReferenceListParent(statusId);
              if (refInfo != null) {
                _clearReferenceListParentIfEmpty(
                    refInfo.parentId, refInfo.siblings);
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
              await _onRootStatusSelected(
                childStatus,
                allRootStatus: parentStatusChildsList,
                parentStatusId: parentStatusId,
              );
              // Auto-colapsar si el padre es reference-list
              final parentType = getJsonField(parentStatus, r'''$.type_status''')?.toString().toLowerCase() ?? '';
              if (parentType == 'reference-list') {
                setState(() => _rootStatusExpansionState[parentStatusId] = false);
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: (isTagTransferAdbFromType && Platforms.isMobile)
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        !isTextType &&
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
                // Radio button visual (no mostrar para tag-transfer, adb-server, adb-from, text, photo)
                if (!isTagTransferType && !isTagTransferAdbServerType && !isTagTransferAdbFromType && !isTextType && !isPhotoType)
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
                if (!isTagTransferType && !isTagTransferAdbServerType && !isTagTransferAdbFromType && !isTextType && !isPhotoType) const SizedBox(width: 12),
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
                              : const Color(0xFF00a86b),
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
                // Badge inline para tag-transfer-adb-from
                if (isTagTransferAdbFromType)
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
                    color: const Color(0xFF00a86b),
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

    // CASO REFERENCE-LIST: si este status es hijo de un status `reference-list`
    // (sus opciones se cargan desde otra actividad), guardar SOLO la fila del
    // padre con statusResponse=childName. NO guardamos fila para el hijo: el
    // render verde se resuelve por fallback en `_cachedSearchInVisitDetails`.
    final refListInfo = _findReferenceListParent(statusId);
    if (refListInfo != null && refListInfo.parent != null) {
      debugPrint(
          '🎯 REFERENCE-LIST HIJO (root): statusId=$statusId, parentId=${refListInfo.parentId}');
      _applyReferenceListSelection(
        parentId: refListInfo.parentId,
        parent: refListInfo.parent,
        siblings: refListInfo.siblings,
        childStatusId: statusId,
        childStatusName: statusName,
      );
      setState(() {});
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

  // Devuelve (parentId, parentStatusJson, siblings) si [childStatusId] es hijo
  // de un status de tipo `reference-list` cargado en `_referenceListChilds`,
  // o null si no lo es.
  ({int parentId, dynamic parent, List<dynamic> siblings})?
      _findReferenceListParent(int childStatusId) {
    for (final entry in _referenceListChilds.entries) {
      final hit = entry.value.any((c) =>
          getJsonField(c, r'''$.id_activity_status''') == childStatusId);
      if (hit) {
        return (
          parentId: entry.key,
          parent: _referenceListParents[entry.key],
          siblings: entry.value,
        );
      }
    }
    return null;
  }

  // Cuando se selecciona un hijo de un status `reference-list`:
  //  1) Quita de visitDetails las filas de los hermanos previamente
  //     seleccionados (exclusividad: solo uno permitido por padre).
  //  2) Inserta/actualiza la fila del PADRE reference-list con
  //     idActivityStatus=parentId, statusResponse=childName, para que tanto
  //     la validación (`_getUnresolvedStatuses`) como el render del
  //     breadcrumb encuentren el dato bajo el id del padre.
  // No toca la fila del hijo (la maneja el caller con su lógica habitual).
  void _applyReferenceListSelection({
    required int parentId,
    required dynamic parent,
    required List<dynamic> siblings,
    required int childStatusId,
    required String childStatusName,
  }) {
    // 1) Quitar hermanos previamente seleccionados
    final siblingIds = <int>{};
    for (final s in siblings) {
      final sid = getJsonField(s, r'''$.id_activity_status''');
      if (sid is int && sid != childStatusId) siblingIds.add(sid);
    }
    if (siblingIds.isNotEmpty) {
      final List<int> toRemove = [];
      for (int i = 0; i < FFAppState().visitDetails.length; i++) {
        if (siblingIds
            .contains(FFAppState().visitDetails[i].idActivityStatus)) {
          toRemove.add(i);
          debugPrint(
              '   ❌ Reference-list: deseleccionando hermano id=${FFAppState().visitDetails[i].idActivityStatus}');
        }
      }
      for (int i = toRemove.length - 1; i >= 0; i--) {
        FFAppState().removeAtIndexFromVisitDetails(toRemove[i]);
      }
    }

    // 2) Insertar/actualizar fila del padre reference-list
    final parentName =
        getJsonField(parent, r'''$.status_name''')?.toString() ?? '';
    final parentDefault =
        getJsonField(parent, r'''$.default_status''')?.toString() ?? '';
    final parentRemember =
        getJsonField(parent, r'''$.remember_status''') == true;

    int existingParentIndex = -1;
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == parentId) {
        existingParentIndex = i;
        break;
      }
    }

    if (existingParentIndex >= 0) {
      FFAppState().updateVisitDetailsAtIndex(
        existingParentIndex,
        (detail) => VisitsDetailsStruct(
          idVisitDetail: detail.idVisitDetail,
          idVisit: detail.idVisit,
          idActivityStatus: parentId,
          statusOption: parentName,
          statusResponse: childStatusName,
          idStepParent: 0,
          rememberStatus: parentRemember,
          defaultStatus: parentDefault,
          typeStatus: 'reference-list',
          auxStep: 0,
        ),
      );
    } else {
      FFAppState().addToVisitDetails(
        VisitsDetailsStruct(
          idVisitDetail: 0,
          idVisit: 0,
          idActivityStatus: parentId,
          statusOption: parentName,
          statusResponse: childStatusName,
          idStepParent: 0,
          rememberStatus: parentRemember,
          defaultStatus: parentDefault,
          typeStatus: 'reference-list',
          auxStep: 0,
        ),
      );
    }
    debugPrint(
        '   ✅ Reference-list padre id=$parentId actualizado: statusResponse="$childStatusName"');

    _visitDetailsSearchCache.clear();
  }

  // Quita la fila del padre reference-list cuando ya no queda ningún hijo
  // seleccionado (deselección manual del único hijo).
  void _clearReferenceListParentIfEmpty(int parentId, List<dynamic> siblings) {
    final remaining = <int>{};
    for (final s in siblings) {
      final sid = getJsonField(s, r'''$.id_activity_status''');
      if (sid is int) remaining.add(sid);
    }
    final stillHasChild = FFAppState()
        .visitDetails
        .any((d) => remaining.contains(d.idActivityStatus));
    if (stillHasChild) return;

    final List<int> toRemove = [];
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == parentId) {
        toRemove.add(i);
      }
    }
    for (int i = toRemove.length - 1; i >= 0; i--) {
      FFAppState().removeAtIndexFromVisitDetails(toRemove[i]);
    }
    if (toRemove.isNotEmpty) {
      _visitDetailsSearchCache.clear();
      debugPrint(
          '   🧹 Reference-list padre id=$parentId eliminado (sin hijo seleccionado)');
    }
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

    // EXCLUSIVIDAD + propagación al PADRE reference-list: si este status es
    // hijo de un status de tipo 'reference-list', guardar SOLO la fila del
    // padre con statusResponse=childName. NO guardamos fila para el hijo: el
    // render verde se resuelve por fallback en `_cachedSearchInVisitDetails`.
    final refListInfo = _findReferenceListParent(statusId);
    if (refListInfo != null && refListInfo.parent != null) {
      debugPrint(
          '🎯 REFERENCE-LIST HIJO: statusId=$statusId, parentId=${refListInfo.parentId}');
      _applyReferenceListSelection(
        parentId: refListInfo.parentId,
        parent: refListInfo.parent,
        siblings: refListInfo.siblings,
        childStatusId: statusId,
        childStatusName: statusName,
      );
      setState(() {});
      return;
    }

    // 1. Para unique-list y reference-list: Eliminar TODOS los status previos con el mismo id_step_parent
    // Para container-list: NO eliminar nada, permitir múltiples selecciones
    List<int> indicesToRemove = [];

    if (!isMultiSelectList) {
      for (int i = 0; i < FFAppState().visitDetails.length; i++) {
        if (FFAppState().visitDetails[i].idStepParent == parentStepId &&
            FFAppState().visitDetails[i].idActivityStatus != 0) {
          indicesToRemove.add(i);
          debugPrint('   ⚠️ Eliminando selección previa: ${FFAppState().visitDetails[i].statusOption}');
        }
      }

      if (indicesToRemove.isNotEmpty) {
        debugPrint('   🗑️ Eliminando ${indicesToRemove.length} selección(es) previa(s) para permitir solo UNA selección');
      }

      // Remover en orden inverso para no alterar los índices
      for (int i = indicesToRemove.length - 1; i >= 0; i--) {
        FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
      }
    } else {
      debugPrint('   ✅ container-list: No se eliminan selecciones previas, se permite selección múltiple');
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
        auxStep: parentStepId,
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

      if (typeStatus.toLowerCase() == 'reference-list' && selectedStatusHasChildren) {
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

  Widget _buildNavigationButtons() {
    // Usar activitySelected (ActivitiesStruct tipado desde SQLite) — fuente de verdad fiable
    final isSync = FFAppState().activitySelected.isSync;

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
                  // Obtener la actividad actual
                  final currentActivity = FFAppState().currentActivity;

                  // Verificar si la actividad tiene steps (estructura jerárquica)
                  final hasSteps = getJsonField(currentActivity, r'''$.activity_steps''')?.toList().isNotEmpty ?? false;

                  if (hasSteps) {
                    // VALIDACIÓN 1: Si hay steps, validar que los steps requeridos estén completos
                    final validationResult = _validateRequiredStepsRecursive();

                    if (validationResult != null) {
                      // Hay un step requerido sin completar
                      final message = validationResult['message'] as String;
                      final path = (validationResult['path'] as List<dynamic>).cast<int>();

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
                  } else {
                    // VALIDACIÓN 2: Si NO hay steps (solo estados directos), verificar que haya al menos un estado seleccionado
                    if (FFAppState().visitDetails.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Debe seleccionar al menos un estado antes de guardar la visita',
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
                          duration: const Duration(seconds: 4),
                          backgroundColor: FlutterFlowTheme.of(context).warning,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }
                  }

                  // Verificar si la actividad requiere lectura de TAG NFC, QR o GPS antes de guardar
                  final readDefault = getJsonField(currentActivity, r'''$.read_default''')?.toString().toUpperCase() ?? '';

                  if (readDefault == 'NFC') {
                    // === MODO NFC: Leer TAG y guardar visita directamente ===
                    final nfcTagId = await _showNfcTagIdReaderDialog();

                    // Si el usuario canceló la lectura NFC, no continuar
                    if (nfcTagId == null || nfcTagId.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.nfc_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Lectura de TAG cancelada. No se guardó la visita.',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.orange.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                      return;
                    }

                    // Crear visita directamente con NFC y las últimas geolocalizaciones
                    final success = await _createVisitWithNfc(nfcTagId);

                    if (success && mounted) {
                      // Mostrar mensaje de éxito
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¡Visita Registrada!',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'TAG: $nfcTagId',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: const Color(0xFF00a86b),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );

                      // Limpiar los datos de tags que NO deben ser recordados
                      _cleanupTagDatasByRememberFlag();
                    }
                  } else if (readDefault == 'QR') {
                    // === MODO QR: Escanear código QR y guardar visita directamente ===
                    final qrCode = await _showQrScannerDialog();

                    // Si el usuario canceló el escaneo QR, no continuar
                    if (qrCode == null || qrCode.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.qr_code_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Escaneo de QR cancelado. No se guardó la visita.',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.orange.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                      return;
                    }

                    // Crear visita directamente con QR y las últimas geolocalizaciones
                    final success = await _createVisitWithQr(qrCode);

                    if (success && mounted) {
                      // Mostrar mensaje de éxito
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¡Visita Registrada!',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'QR: ${qrCode.length > 30 ? '${qrCode.substring(0, 30)}...' : qrCode}',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: const Color(0xFF00a86b),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );

                      // Limpiar los datos de tags que NO deben ser recordados
                      _cleanupTagDatasByRememberFlag();
                    }
                  } else {
                    // === MODO GPS (default): Usar LoadCoordinatesVisit con timer ===
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

                    // Limpiar los datos de tags que NO deben ser recordados después de crear la visita
                    _cleanupTagDatasByRememberFlag();
                  }

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


  /// Muestra un diálogo para leer el TAG ID (RFID) del NFC antes de guardar
  /// Retorna el TAG ID leído o null si el usuario cancela
  Future<String?> _showNfcTagIdReaderDialog() async {
    String? tagId;
    bool isReading = false;
    bool isCancelled = false;
    String? errorMessage;

    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            // Función para iniciar la lectura NFC
            Future<void> startNfcReading() async {
              if (isReading || isCancelled) return;

              setDialogState(() {
                isReading = true;
                errorMessage = null;
              });

              try {
                await NfcManager.instance.startSession(
                  pollingOptions: {
                    NfcPollingOption.iso14443,
                    NfcPollingOption.iso15693,
                    NfcPollingOption.iso18092,
                  },
                  onDiscovered: (NfcTag tag) async {
                    try {
                      // Obtener el ID del TAG
                      final androidTag = NfcTagAndroid.from(tag);
                      if (androidTag != null && androidTag.id.isNotEmpty) {
                        tagId = androidTag.id
                            .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
                            .join('');
                      }

                      await NfcManager.instance.stopSession();

                      if (!isCancelled && tagId != null && tagId!.isNotEmpty) {
                        HapticFeedback.mediumImpact();

                        // La visita solo necesita el RFID, retornar inmediatamente
                        debugPrint('✅ TAG RFID leído exitosamente: $tagId');

                        // Cerrar el diálogo retornando el tagId
                        if (builderContext.mounted && Navigator.of(builderContext).canPop()) {
                          Navigator.of(builderContext).pop(tagId);
                        }
                      } else if (!isCancelled) {
                        // TAG alejado muy rápido o no se pudo leer
                        debugPrint('⚠️ No se pudo leer el TAG correctamente');
                        setDialogState(() {
                          isReading = false;
                          errorMessage = 'No se pudo leer el TAG.\nAcerque el TAG y manténgalo cerca hasta que se complete la lectura.';
                        });
                      }
                    } catch (e) {
                      debugPrint('❌ Error leyendo TAG ID: $e');
                      await NfcManager.instance.stopSession();
                      setDialogState(() {
                        isReading = false;
                        errorMessage = 'Error al leer el TAG.\nIntente nuevamente.';
                      });
                    }
                  },
                );
              } catch (e) {
                debugPrint('❌ Error iniciando sesión NFC: $e');
                setDialogState(() {
                  isReading = false;
                  errorMessage = 'Error al iniciar lector NFC.\nVerifique que NFC esté activado.';
                });
              }
            }

            // Iniciar lectura automáticamente
            if (!isReading && !isCancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                startNfcReading();
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: MediaQuery.sizeOf(builderContext).width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono NFC animado
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00a86b).withValues(alpha: 0.1),
                        border: Border.all(
                          color: const Color(0xFF00a86b),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.nfc_rounded,
                        size: 50,
                        color: Color(0xFF00a86b),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Título
                    const Text(
                      'Lectura de TAG Requerida',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Instrucciones o mensaje de error
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        isReading
                            ? 'Acerque el TAG NFC al dispositivo...'
                            : 'Preparando lector NFC...',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    // Indicador de carga
                    if (isReading)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Botones
                    if (errorMessage != null)
                      // Mostrar botón de reintentar cuando hay error
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                isCancelled = true;
                                try {
                                  await NfcManager.instance.stopSession();
                                } catch (_) {}
                                if (builderContext.mounted && Navigator.of(dialogContext).canPop()) {
                                  Navigator.of(dialogContext).pop(null);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
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
                            child: ElevatedButton(
                              onPressed: () async {
                                await startNfcReading();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00a86b),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Reintentar',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Mostrar solo botón cancelar cuando está leyendo
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            isCancelled = true;
                            try {
                              await NfcManager.instance.stopSession();
                            } catch (_) {}
                            if (builderContext.mounted && Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop(null);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
      },
    );
  }

  // ── Claves SharedPreferences para recordar el lote seleccionado por día ──
  static const String _kLotIdKey   = 'selected_lot_id_day';
  static const String _kLotNameKey = 'selected_lot_name_day';
  static const String _kLotDateKey = 'selected_lot_date_day';

  /// Devuelve el lote guardado si es del día de hoy, o null si expiró / no existe.
  Future<HeadquartersStruct?> _getCachedLotForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kLotDateKey);
    final today = DateTime.now().toIso8601String().substring(0, 10); // 'yyyy-MM-dd'
    if (savedDate != today) return null;
    final id   = prefs.getInt(_kLotIdKey);
    final name = prefs.getString(_kLotNameKey);
    if (id == null || name == null) return null;
    return HeadquartersStruct(idHeadquarter: id, nameHeadquarter: name);
  }

  /// Guarda la selección del lote para el día de hoy.
  Future<void> _cacheLotForToday(HeadquartersStruct lot) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_kLotDateKey, today);
    await prefs.setInt(_kLotIdKey,      lot.idHeadquarter);
    await prefs.setString(_kLotNameKey, lot.nameHeadquarter);
    debugPrint('💾 Lote guardado para hoy ($today): ${lot.nameHeadquarter} (ID: ${lot.idHeadquarter})');
  }

  /// Retorna el lote a usar cuando la GPS está fuera del polígono:
  /// - Si ya hay una selección del día → la reutiliza sin mostrar el diálogo.
  /// - Si no → muestra el diálogo, guarda la selección y la retorna.
  Future<HeadquartersStruct?> _showSelectLotDialogOrRecall(
    BuildContext context,
    List<actions.HeadquarterDistance> nearestList,
  ) async {
    // 1. ¿Hay selección guardada de hoy?
    final cached = await _getCachedLotForToday();
    if (cached != null) {
      debugPrint('♻️ Lote recordado del día: ${cached.nameHeadquarter} (ID: ${cached.idHeadquarter})');
      return cached;
    }

    // 2. Primera vez hoy → mostrar diálogo
    if (!mounted) return null;
    final selected = await _showSelectLotDialog(context, nearestList);
    if (selected != null) await _cacheLotForToday(selected);
    return selected;
  }

  /// Crea una visita directamente usando el TAG NFC leído y las últimas 3 geolocalizaciones del AppState
  /// Muestra un bottom sheet elegante para que el usuario seleccione
  /// el lote cuando la ubicación cae fuera de todos los polígonos.
  Future<HeadquartersStruct?> _showSelectLotDialog(
    BuildContext context,
    List<actions.HeadquarterDistance> nearestList,
  ) async {
    return showModalBottomSheet<HeadquartersStruct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Ícono y título
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_searching_rounded,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¿En cuál lote estás?',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu ubicación está fuera de los polígonos registrados.\nSelecciona el lote más cercano:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              // Lista de lotes cercanos
              ...nearestList.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final distLabel = item.distanceMeters == double.infinity
                    ? 'Sin distancia'
                    : item.distanceMeters < 1000
                        ? '${item.distanceMeters.toStringAsFixed(0)} m'
                        : '${(item.distanceMeters / 1000).toStringAsFixed(2)} km';
                final colors = [
                  Colors.green.shade600,
                  Colors.orange.shade600,
                  Colors.red.shade400,
                ];
                final color = colors[index.clamp(0, 2)];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(ctx, item.headquarter),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: color.withOpacity(0.4),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: color.withOpacity(0.06),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.15),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 16,
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
                                  item.headquarter.nameHeadquarter,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.near_me_rounded,
                                        size: 14, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      distLabel,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 13,
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: color),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

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
              final dbPath = FFAppState().pathDatabase;
              final database = await openDatabase(dbPath);

              final productResults = await database.rawQuery('''
                SELECT Type_product FROM Products WHERE Rfid = ? LIMIT 1
              ''', [nfcTagId]);

              if (productResults.isEmpty) {
                // RFID no encontrado
                await database.close();
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
              await database.close();

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

      // Verificar polígono y obtener Id_headquarter
      int idHeadquarter = 0;
      final headquartersList = FFAppState().headquartersSelectedList;
      if (headquartersList.isNotEmpty) {
        final checkResult = await actions.checkLocationInPolygons(
          mainLocation.latitude,
          mainLocation.longitude,
          headquartersList,
        );

        if (checkResult.insideHeadquarter != null) {
          idHeadquarter = checkResult.insideHeadquarter!.idHeadquarter;
          debugPrint('✅ Dentro del polígono del lote: ${checkResult.insideHeadquarter!.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (headquartersList.length == 1) {
          // Solo 1 lote preseleccionado → auto-asignar sin preguntar
          idHeadquarter = headquartersList.first.idHeadquarter;
          debugPrint('✅ Único lote preseleccionado, auto-asignado: ${headquartersList.first.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (checkResult.nearestList.length == 1) {
          // Solo hay 1 candidato cercano → auto-asignar
          idHeadquarter = checkResult.nearestList.first.headquarter.idHeadquarter;
          debugPrint('✅ Único lote cercano, auto-asignado: ${checkResult.nearestList.first.headquarter.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (checkResult.nearestList.isEmpty) {
          debugPrint('⚠️ No hay lotes cercanos, Id_headquarter será 0');
        } else {
          // Más de 1 lote y GPS fuera de todos los polígonos → recordar o mostrar diálogo
          debugPrint('⚠️ Múltiples lotes y GPS fuera de polígonos, verificando selección del día');
          if (!mounted) return false;
          final selected = await _showSelectLotDialogOrRecall(context, checkResult.nearestList);
          if (selected == null) return false;
          idHeadquarter = selected.idHeadquarter;
          debugPrint('✅ Lote asignado: ${selected.nameHeadquarter} (ID: $idHeadquarter)');
        }
      } else {
        debugPrint('⚠️ No hay lotes seleccionados, Id_headquarter será 0');
      }

      // Obtener visitDetails filtrados
      final visitDetails = FFAppState().visitDetails;
      final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();

      // Abrir base de datos
      final dbPath = FFAppState().pathDatabase;
      final database = await openDatabase(dbPath);

      int visitId = 0;
      await database.transaction((txn) async {
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

      await database.close();

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

      // Verificar polígono y obtener Id_headquarter
      int idHeadquarter = 0;
      final headquartersList = FFAppState().headquartersSelectedList;
      if (headquartersList.isNotEmpty) {
        final checkResult = await actions.checkLocationInPolygons(
          mainLocation.latitude,
          mainLocation.longitude,
          headquartersList,
        );

        if (checkResult.insideHeadquarter != null) {
          idHeadquarter = checkResult.insideHeadquarter!.idHeadquarter;
          debugPrint('✅ Dentro del polígono del lote: ${checkResult.insideHeadquarter!.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (headquartersList.length == 1) {
          // Solo 1 lote preseleccionado → auto-asignar sin preguntar
          idHeadquarter = headquartersList.first.idHeadquarter;
          debugPrint('✅ Único lote preseleccionado, auto-asignado: ${headquartersList.first.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (checkResult.nearestList.length == 1) {
          // Solo hay 1 candidato cercano → auto-asignar
          idHeadquarter = checkResult.nearestList.first.headquarter.idHeadquarter;
          debugPrint('✅ Único lote cercano, auto-asignado: ${checkResult.nearestList.first.headquarter.nameHeadquarter} (ID: $idHeadquarter)');
        } else if (checkResult.nearestList.isEmpty) {
          debugPrint('⚠️ No hay lotes cercanos, Id_headquarter será 0');
        } else {
          // Más de 1 lote y GPS fuera de todos los polígonos → recordar o mostrar diálogo
          debugPrint('⚠️ Múltiples lotes y GPS fuera de polígonos, verificando selección del día');
          if (!mounted) return false;
          final selected = await _showSelectLotDialogOrRecall(context, checkResult.nearestList);
          if (selected == null) return false;
          idHeadquarter = selected.idHeadquarter;
          debugPrint('✅ Lote asignado: ${selected.nameHeadquarter} (ID: $idHeadquarter)');
        }
      } else {
        debugPrint('⚠️ No hay lotes seleccionados, Id_headquarter será 0');
      }

      // Obtener visitDetails filtrados
      final visitDetails = FFAppState().visitDetails;
      final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();

      // Abrir base de datos
      final dbPath = FFAppState().pathDatabase;
      final database = await openDatabase(dbPath);

      int visitId = 0;
      await database.transaction((txn) async {
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

      await database.close();

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
        child: Icon(
          Icons.search_rounded,
          size: 16,
          // Blanco cuando el step tiene valor (fondo verde), verde en caso contrario
          color: hasValue ? Colors.white : const Color(0xFF00a86b),
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

  // ===== CAJONES NUMÉRICOS DEL 1 AL 4 =====

  // Control numérico compacto para root status
  Widget _buildCompactInlineNumberControl({required dynamic status}) {
    final statusId = getJsonField(status, r'''$.id_activity_status''');
    final defaultStatus =
        getJsonField(status, r'''$.default_status''').toString();

    if (defaultStatus.toUpperCase().contains('=RANDOM:')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _formatColombianNumber(_getCurrentNumberValue(statusId, defaultStatus)),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
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
    if (defaultStatus.toUpperCase().contains('=RANDOM:')) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _formatColombianNumber(_getCurrentNumberValue(statusId, defaultStatus)),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                ),
              ),
            ),
          ),
        ],
      );
    }
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

  // ===== ADB NFC BRIDGE BADGES =====

  /// Badge para campo tag-transfer-adb-server (desktop).
  /// Verde = servidor activo y cliente conectado.
  /// Naranja = servidor activo esperando cliente.
  /// Rojo = servidor apagado (tap para intentar levantar).
  Widget _buildAdbServerBadge({required int statusId}) {
    Color bgColor;
    IconData icon;
    String label;

    switch (_adbServerStatus) {
      case AdbBridgeStatus.clientConnected:
        bgColor = const Color(0xFF00a86b);
        icon = Icons.usb_rounded;
        label = 'Conectado';
        break;
      case AdbBridgeStatus.waitingForClient:
        bgColor = const Color(0xFFFF9800);
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
        if (!AdbNfcBridgeService.instance.isServerRunning) {
          await AdbNfcBridgeService.instance.start();
          if (mounted) setState(() => _adbServerStatus = AdbNfcBridgeService.instance.currentStatus);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge compacto (solo conexión) — usado en la fila del status cuando no hay datos aún.
  Widget _buildAdbFromBadge({required int statusId}) {
    final connected = _adbClientConnected;
    final bgColor = connected ? const Color(0xFF00a86b) : const Color(0xFFE53935);
    final icon = connected ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded;
    final label = connected ? 'Conectado' : 'Sin conexión';

    return GestureDetector(
      onTap: () async {
        if (!AdbNfcClientService.instance.isConnected) {
          _adbRetryTimer?.cancel();
          _tryAdbConnect();
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                // Icono NFC con pulso
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  onEnd: () => setState(() {}), // loop
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
                // Icono de transferencia animado
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (_, t, __) => Opacity(
                    opacity: (t < 0.5 ? t * 2 : (1.0 - t) * 2).clamp(0.3, 1.0),
                    child: Icon(
                      Icons.sync_alt_rounded,
                      color: connected ? const Color(0xFF00E5FF) : const Color(0xFFE53935),
                      size: 28,
                    ),
                  ),
                  onEnd: () => setState(() {}), // loop
                ),
                const SizedBox(width: 12),
                // Estado
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transferencia NFC',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: connected ? const Color(0xFF00E676) : const Color(0xFFE53935),
                              boxShadow: [BoxShadow(color: (connected ? const Color(0xFF00E676) : const Color(0xFFE53935)).withValues(alpha: 0.6), blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              connected ? 'Servidor conectado' : 'Sin conexión al servidor',
                              style: TextStyle(
                                color: connected ? const Color(0xFF00E676) : const Color(0xFFE53935),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botón reconectar si no está conectado
                if (!connected)
                  GestureDetector(
                    onTap: () { _adbRetryTimer?.cancel(); _tryAdbConnect(); },
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

            // ── Instrucción o resumen ──
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

            // ── Resumen inline cuando ya hay datos ──
            if (hasData) ...[
              const SizedBox(height: 12),
              _buildTagReaderSummary(statusId: statusId),
            ],

            // ── Botón nueva lectura (cuando ya hay datos) ──
            if (hasData) ...[
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
                    context: context,
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
                    gradient: connected
                        ? const LinearGradient(colors: [Color(0xFF00B4D8), Color(0xFF0077B6)])
                        : null,
                    color: connected ? null : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: connected ? [const BoxShadow(color: Color(0x4400B4D8), blurRadius: 12, offset: Offset(0, 4))] : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nfc_rounded, color: connected ? Colors.white : Colors.white38, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Leer otro tag',
                        style: TextStyle(
                          color: connected ? Colors.white : Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
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
    } catch (e) {
      debugPrint('⚠️ Error persistiendo HQ-Weight en visitDetails: $e');
    }
  }

  // ===== CARGAR WEIGHTS DE HEADQUARTERS DESDE SQLITE =====

  /// Carga los weights de headquarters desde SQLite para el mes/año actual
  /// También identifica los lotes que NO tienen peso promedio configurado
  /// Usa la base de datos principal (pathDatabase) con conexión directa
  Future<void> _loadHeadquarterWeights(List<int> headquarterIds) async {
    Database? db;
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

      // Obtener la ruta de la base de datos desde FFAppState
      final dbPath = FFAppState().pathDatabase;
      if (dbPath.isEmpty) {
        debugPrint('❌ Error: pathDatabase está vacío');
        return;
      }

      // Abrir conexión a la base de datos (readonly para evitar bloqueos)
      db = await openDatabase(dbPath, readOnly: true);
      debugPrint('📂 Base de datos abierta: $dbPath');

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
    } finally {
      // Cerrar la conexión para evitar bloqueos
      if (db != null && db.isOpen) {
        await db.close();
        debugPrint('✅ Base de datos cerrada correctamente');
      }
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
          final statusId = getJsonField(status, r'''$.id_activity_status''');
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
  /// Ejemplo: =(TARE-DESTARE)/TAG_READER:Lectura en TAG
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

      // 1. Obtener el valor de TAG_READER (total de RESULTS)
      final tagReaderValue = await _getTotalResultsFromTagReader();
      debugPrint('📊 TAG_READER total results: $tagReaderValue');

      if (tagReaderValue == 0) {
        debugPrint('⚠️ TAG_READER es 0, no se puede calcular');
        debugPrint('🧮 ===== FIN EVALUACIÓN (ERROR) =====');
        debugPrint('');
        return;
      }

      // 2. Obtener valores de variables del formulario (TARE, DESTARE, etc.)
      debugPrint('');
      debugPrint('🔍 Buscando variables del formulario...');
      debugPrint('   Total visitDetails: ${FFAppState().visitDetails.length}');

      final Map<String, double> formVariables = {};

      // Listar todos los campos disponibles para debug
      debugPrint('   Total visitDetails: ${FFAppState().visitDetails.length}');
      for (var detail in FFAppState().visitDetails) {
        final isStepRecord = detail.idActivityStatus == 0;
        final recordType = isStepRecord ? 'STEP' : 'STATUS';
        debugPrint('   📌 [$recordType] Campo: "${detail.statusOption}" = "${detail.statusResponse}"');
      }

      // Buscar TARE - Buscar exactamente por el nombre del campo
      var tareDetail = FFAppState().visitDetails.firstWhere(
            (d) => d.statusOption.toUpperCase() == 'TARE',
            orElse: () => VisitsDetailsStruct(),
          );

      // Si no se encuentra exactamente, buscar que contenga TARE
      if (tareDetail.statusResponse.isEmpty) {
        tareDetail = FFAppState().visitDetails.firstWhere(
              (d) => d.statusOption.toUpperCase().contains('TARE') &&
                     !d.statusOption.toUpperCase().contains('DESTARE'),
              orElse: () => VisitsDetailsStruct(),
            );
      }

      if (tareDetail.statusResponse.isNotEmpty) {
        final tareValue = double.tryParse(tareDetail.statusResponse) ?? 0.0;
        formVariables['TARE'] = tareValue;
        debugPrint('   ✅ TARE encontrado: ${tareDetail.statusOption} = $tareValue');
      } else {
        debugPrint('   ⚠️ TARE no encontrado en visitDetails');
      }

      // Buscar DESTARE - Buscar exactamente por el nombre del campo
      var destareDetail = FFAppState().visitDetails.firstWhere(
            (d) => d.statusOption.toUpperCase() == 'DESTARE',
            orElse: () => VisitsDetailsStruct(),
          );

      // Si no se encuentra exactamente, buscar que contenga DESTARE
      if (destareDetail.statusResponse.isEmpty) {
        destareDetail = FFAppState().visitDetails.firstWhere(
              (d) => d.statusOption.toUpperCase().contains('DESTARE'),
              orElse: () => VisitsDetailsStruct(),
            );
      }

      if (destareDetail.statusResponse.isNotEmpty) {
        final destareValue = double.tryParse(destareDetail.statusResponse) ?? 0.0;
        formVariables['DESTARE'] = destareValue;
        debugPrint('   ✅ DESTARE encontrado: ${destareDetail.statusOption} = $destareValue');
      } else {
        debugPrint('   ⚠️ DESTARE no encontrado en visitDetails');
      }

      if (formVariables.isEmpty) {
        debugPrint('');
        debugPrint('❌ No se encontraron variables (TARE, DESTARE) para evaluar la fórmula');
        debugPrint('🧮 ===== FIN EVALUACIÓN (ERROR) =====');
        debugPrint('');
        return;
      }

      debugPrint('');
      debugPrint('🔄 Procesando fórmula...');

      // 3. Reemplazar TAG_READER:... con su valor
      // El patrón captura desde TAG_READER: hasta el final de la palabra/frase
      String processedFormula = formula;

      // Primero remover el signo = inicial si existe
      if (processedFormula.startsWith('=')) {
        processedFormula = processedFormula.substring(1);
      }

      // Reemplazar TAG_READER con case insensitive y capturar todo después de ":"
      final tagReaderPattern = RegExp(
        r'TAG_READER:[^\s\)]+(?:\s+[^\s\)]+)*',
        caseSensitive: false,
      );

      final match = tagReaderPattern.firstMatch(processedFormula);
      if (match != null) {
        debugPrint('   TAG_READER encontrado: "${match.group(0)}"');
        processedFormula = processedFormula.replaceAll(
          tagReaderPattern,
          tagReaderValue.toString()
        );
        debugPrint('   Reemplazado por: $tagReaderValue');
      } else {
        debugPrint('   ⚠️ No se encontró patrón TAG_READER en la fórmula');
      }

      debugPrint('   Fórmula después de TAG_READER: "$processedFormula"');

      // 4. Reemplazar variables del formulario
      // Crear dos versiones: una para calcular (sin formato) y otra para mostrar (con formato)
      String displayFormula = processedFormula;

      for (var entry in formVariables.entries) {
        final variableName = entry.key;
        final variableValue = entry.value;

        // Para CÁLCULO: usar valor sin formato
        processedFormula = processedFormula.replaceAllMapped(
          RegExp('\\b$variableName\\b', caseSensitive: false),
          (match) => variableValue.toString(),
        );

        // Para DISPLAY: usar valor formateado con separador de miles
        final formattedValue = _formatNumberForFormula(variableValue);
        displayFormula = displayFormula.replaceAllMapped(
          RegExp('\\b$variableName\\b', caseSensitive: false),
          (match) => formattedValue,
        );

        debugPrint('   $variableName reemplazado por: $formattedValue');
      }

      debugPrint('   Fórmula para cálculo: "$processedFormula"');
      debugPrint('   Fórmula para display: "$displayFormula"');

      // 5. Evaluar la expresión matemática (sin formato, sin comas)
      debugPrint('');
      debugPrint('🧮 Evaluando expresión matemática...');
      final result = _evaluateMathExpressionWithParentheses(processedFormula);
      debugPrint('✅ Resultado: $result kg');

      // 6. Guardar resultado en el estado
      _calculatedHeadquarterWeights[statusId] = {
        'isFormulaResult': true,
        'formulaResult': result,
        'grandTotal': result,
        'formula': formula,
        'evaluatedFormula': displayFormula, // Fórmula formateada para mostrar
      };

      _saveHqWeightToVisitDetails(statusId, statusName, {
        'calculationType': 'formula',
        'grandTotal': result,
        'formula': formula,
        'evaluatedFormula': displayFormula,
      });

      debugPrint('');
      debugPrint('🧮 ===== FIN EVALUACIÓN (ÉXITO) =====');
      debugPrint('');

      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ Error evaluando fórmula: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('🧮 ===== FIN EVALUACIÓN (ERROR) =====');
      debugPrint('');
    }
  }

  /// Obtiene el total de RESULTS de todos los registros del TAG_READER
  Future<int> _getTotalResultsFromTagReader() async {
    int totalResults = 0;

    // Sumar todos los RESULTS de todas las entradas del tag
    for (var entry in _tagReaderData.entries) {
      for (var record in entry.value) {
        final results = record['results'] as int? ?? 0;
        totalResults += results;
      }
    }

    return totalResults;
  }

  /// Evalúa una expresión matemática simple con paréntesis
  /// Soporta: +, -, *, /, ()
  double _evaluateMathExpressionWithParentheses(String expression) {
    try {
      debugPrint('   🔢 Evaluando: "$expression"');

      // Remover espacios
      expression = expression.replaceAll(' ', '');

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
        final subResult = _evaluateSimpleMathExpression(subExpr);
        debugPrint('   📐 Resultado: $subResult');

        expression = expression.substring(0, openIndex) +
            subResult.toString() +
            expression.substring(closeIndex + 1);

        debugPrint('   🔄 Expresión actualizada: "$expression"');
      }

      // Evaluar expresión sin paréntesis
      debugPrint('   📊 Evaluando expresión final: "$expression"');
      final result = _evaluateSimpleMathExpression(expression);
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
          final statusId = getJsonField(status, r'''$.id_activity_status''');
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
  double _evaluateSimpleMathExpression(String expression) {
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

      // Convertir números
      final List<dynamic> processed = [];
      for (var token in tokens) {
        if ('+-*/'.contains(token)) {
          processed.add(token);
        } else {
          final num = double.tryParse(token);
          if (num == null) {
            debugPrint('      ⚠️ No se pudo parsear: "$token"');
            return 0.0;
          }
          processed.add(num);
        }
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
          late Directory baseDir;
          if (Platform.isAndroid) {
            final Directory? externalDir = await getExternalStorageDirectory();
            if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
            baseDir = externalDir;
          } else {
            baseDir = await getApplicationDocumentsDirectory();
          }
          final String basePath = '${baseDir.path}/ClickPalmData';
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
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
                            backgroundColor: const Color(0xFF00a86b),
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

    // Buscar el status por nombre en activity_steps y root status
    dynamic targetStatus;
    int? targetStatusId;
    String? targetStatusType;

    // Búsqueda recursiva: status_childs y steps_childs a cualquier profundidad
    void searchInStatus(dynamic status) {
      if (targetStatus != null) return;
      final statusNameField =
          getJsonField(status, r'''$.name_status''')?.toString() ?? '';
      if (statusNameField.toLowerCase() == fieldName.toLowerCase()) {
        targetStatus = status;
        targetStatusId =
            getJsonField(status, r'''$.id_activity_status''')?.toInt();
        targetStatusType =
            getJsonField(status, r'''$.type_status''')?.toString().toLowerCase();
        debugPrint('       ✅ MATCH! id: $targetStatusId, tipo: $targetStatusType');
        return;
      }
      for (var s in (getJsonField(status, r'''$.status_childs''')?.toList() ?? [])) {
        searchInStatus(s);
        if (targetStatus != null) return;
      }
      for (var step in (getJsonField(status, r'''$.steps_childs''')?.toList() ?? [])) {
        for (var s in (getJsonField(step, r'''$.activity_status''')?.toList() ?? [])) {
          searchInStatus(s);
          if (targetStatus != null) return;
        }
      }
    }

    void searchInStep(dynamic step) {
      if (targetStatus != null) return;
      for (var s in (getJsonField(step, r'''$.activity_status''')?.toList() ?? [])) {
        searchInStatus(s);
        if (targetStatus != null) return;
      }
      for (var subStep in (getJsonField(step, r'''$.steps_childs''')?.toList() ?? [])) {
        searchInStep(subStep);
        if (targetStatus != null) return;
      }
    }

    final activity = FFAppState().currentActivity;
    // Buscar en root activity_status
    for (var s in (getJsonField(activity, r'''$.activity_status''')?.toList() ?? [])) {
      searchInStatus(s);
      if (targetStatus != null) break;
    }
    // Buscar en activity_steps (recursivo)
    if (targetStatus == null) {
      for (var step in (getJsonField(activity, r'''$.activity_steps''')?.toList() ?? [])) {
        searchInStep(step);
        if (targetStatus != null) break;
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

    final resolvedId = targetStatusId!;

    // Según el tipo de status, obtener el valor apropiado
    switch (targetStatusType) {
      case 'date':
        return _getDateValue(resolvedId);

      case 'time':
        return _getTimeValue(resolvedId);

      case 'tag-reader':
        return _getTagReaderPlainText(resolvedId);

      case 'distance-extractor':
        return _getDistanceExtractorValue(resolvedId);

      case 'number':
        return _getNumberValue(resolvedId);

      case 'numbers-operation':
        return _getNumbersOperationValue(resolvedId);

      case 'label-info':
        // Para label-info, retornar el contenido de default_status
        final defaultStatus =
            getJsonField(targetStatus, r'''$.default_status''')?.toString() ??
                '';
        return defaultStatus.isNotEmpty ? defaultStatus : '[Sin información]';

      case 'text':
        // Para text, obtener de visitDetails
        final detail = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == resolvedId,
              orElse: () => VisitsDetailsStruct(),
            );
        return detail.statusResponse.isNotEmpty
            ? detail.statusResponse
            : '[$fieldName]';

      case 'unique-list':
      case 'reference-list':
        // Para listas, obtener la opción seleccionada desde statusResponse
        final detail = FFAppState().visitDetails.firstWhere(
              (d) => d.idActivityStatus == resolvedId,
              orElse: () => VisitsDetailsStruct(),
            );
        // Para reference-list (type_status), statusResponse contiene el nombre seleccionado (e.g., "WISTON HERNAN QUIÑONES ORTIZ")
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

  /// Extrae un sub-campo del JSON NFC de un status tag-reader/tag-writer/tag-transfer.
  /// Uso: {NombreCampo.subPath} en el HTML template.
  Future<String> _getNfcJsonSubfieldValue(String baseField, String subPath) async {
    debugPrint('🔎 NFC subfield: "$baseField.$subPath"');

    int? targetStatusId;
    String? targetStatusType;

    void searchInList(List list) {
      for (var status in list) {
        final name = getJsonField(status, r'''$.name_status''')?.toString() ?? '';
        if (name.toLowerCase() == baseField.toLowerCase()) {
          targetStatusId = getJsonField(status, r'''$.id_activity_status''')?.toInt();
          targetStatusType = getJsonField(status, r'''$.type_status''')?.toString().toLowerCase();
        }
      }
    }

    final stepsRaw = getJsonField(FFAppState().currentActivity, r'''$.activity_steps''');
    if (stepsRaw != null) {
      final steps = stepsRaw is List ? stepsRaw : [stepsRaw];
      for (var step in steps) {
        final sl = getJsonField(step, r'''$.activity_status''');
        if (sl != null) searchInList(sl is List ? sl : [sl]);
        if (targetStatusId != null) break;
      }
    }
    if (targetStatusId == null) {
      final rootRaw = getJsonField(FFAppState().currentActivity, r'''$.activity_status''');
      if (rootRaw != null) searchInList(rootRaw is List ? rootRaw : [rootRaw]);
    }

    if (targetStatusId == null || targetStatusType == null) {
      debugPrint('⚠️ NFC subfield: campo "$baseField" no encontrado');
      return '[$baseField.$subPath]';
    }

    const nfcTypes = {'tag-reader', 'tag-writer', 'tag-transfer'};
    if (!nfcTypes.contains(targetStatusType)) {
      debugPrint('⚠️ NFC subfield: tipo "$targetStatusType" no soportado');
      return '[$baseField.$subPath]';
    }

    final detail = FFAppState().visitDetails.firstWhere(
      (d) => d.idActivityStatus == targetStatusId,
      orElse: () => VisitsDetailsStruct(),
    );

    if (detail.statusResponse.isEmpty) {
      debugPrint('⚠️ NFC subfield: statusResponse vacío para "$baseField"');
      return '[$baseField.$subPath]';
    }

    final nfcJson = actions.parseNfcJson(detail.statusResponse);
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
        return (readInfo?['tag_to'] as String? ?? '').isNotEmpty
            ? (readInfo!['tag_to'] as String)
            : '[Sin tag destino]';

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
          );
        }).toList(),
      );
    }

    // Modo normal (un solo tag): comportamiento original
    final tagData = _tagReaderData[statusId] ?? [];
    if (tagData.isEmpty) return const SizedBox.shrink();
    return _buildTagReaderSummarySection(
      sectionData: tagData,
      productName: _tagReaderProductName[statusId] ?? '',
      tagIndex: 0,
      statusId: statusId,
      isAdbServer: isAdbServer,
    );
  }

  Widget _buildTagReaderSummarySection({
    required List<Map<String, dynamic>> sectionData,
    required String productName,
    required int tagIndex,
    required int statusId,
    bool isAdbServer = false,
  }) {
    if (sectionData.isEmpty) return const SizedBox.shrink();

    // Agrupar por lote (headquarterId)
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in sectionData) {
      final heId = record['headquarterId'] as int? ?? 0;
      if (!groupedByHeadquarter.containsKey(heId)) {
        groupedByHeadquarter[heId] = [];
      }
      groupedByHeadquarter[heId]!.add(record);
    }

    // Checkbox state para adb-server
    final checkKey = tagIndex; // 0 en modo normal, 1-based en multi
    final isChecked = isAdbServer && (_adbTagChecked[statusId]?.contains(checkKey) ?? false);

    final treeContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de sección cuando hay múltiples tags
        if (tagIndex > 0) ...[
          Row(
            children: [
              Icon(Icons.nfc, color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 4),
              Text(
                'Tag #$tagIndex',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
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
            Text(
              productName.isNotEmpty ? productName : 'Resumen del TAG',
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            // Geolocalización solo en el primer tag (o modo normal)
            if (tagIndex <= 1 && _tagReaderGeolocations.containsKey(statusId)) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
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
        ...groupedByHeadquarter.entries.map((entry) {
          return _buildHeadquarterGroup(entry.key, entry.value);
        }),
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
                // Árbol de datos
                Expanded(child: treeContent),
                const SizedBox(width: 16),
                // Checkbox ultra moderno centrado verticalmente
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
                              colors: [Color(0xFF00E676), Color(0xFF00C853)],
                            )
                          : null,
                      color: isChecked ? null : Colors.transparent,
                      border: Border.all(
                        color: isChecked ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: isChecked
                          ? [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)]
                          : [],
                    ),
                    child: isChecked
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : null,
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
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
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
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Lote: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF74C69D),
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
    final totalResults = operatorData['totalResults'] as int? ?? 0;

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
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del operador principal (OP) con prefijo Recolector
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Recolector: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF74C69D),
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

    // Obtener Name_product desde el JSON del statusResponse en visitDetails
    String productTitle = _tagWriterProductName[statusId] ?? '';
    if (productTitle.isEmpty) {
      for (final d in FFAppState().visitDetails) {
        if (d.idActivityStatus == statusId && d.statusResponse.isNotEmpty) {
          try {
            final parsed = actions.parseNfcJson(d.statusResponse);
            final name = parsed?['Read_info']?['Name_product'] as String?;
            if (name != null && name.isNotEmpty) productTitle = name;
          } catch (_) {}
          break;
        }
      }
    }
    if (productTitle.isEmpty) productTitle = 'Registros escritos en TAG';

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
              Expanded(
                child: Text(
                  productTitle,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
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
                                  color: Color(0xFF74C69D),
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
                        // Nombre del operador principal (OP) con prefijo Recolector
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Recolector: ',
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
          else
            // TRANSFERIR AHORA - Clickeable
            InkWell(
              onTap: () async {
                // Obtener el contenido del tag de origen (nfcRead o caché local)
                final sourceTagContent = FFAppState().nfcRead.isNotEmpty
                    ? FFAppState().nfcRead
                    : (_tagTransferSourceContent[statusId] ?? '');
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

                // Extraer default_status del status tag-transfer desde la
                // definición de la actividad (currentActivity). NOTA: NO se
                // puede leer desde visitDetails porque el registro del
                // tag-transfer todavía no existe en este momento — solo se
                // crea después de que la escritura al destino sea exitosa.
                String? destinationTitle;
                bool writerStatus = false;
                String? tagTransferDefaultStatus;

                void searchStatusForDefault(dynamic status) {
                  if (tagTransferDefaultStatus != null) return;
                  final id =
                      getJsonField(status, r'''$.id_activity_status''') as int? ?? 0;
                  if (id == statusId) {
                    tagTransferDefaultStatus =
                        getJsonField(status, r'''$.default_status''')?.toString() ??
                            '';
                    return;
                  }
                  final stepsChilds =
                      getJsonField(status, r'''$.activities_steps_childs''') ??
                          getJsonField(status, r'''$.steps_childs''');
                  if (stepsChilds is List) {
                    for (final s in stepsChilds) {
                      final sl = getJsonField(s, r'''$.activity_status''');
                      if (sl is List) {
                        for (final c in sl) {
                          searchStatusForDefault(c);
                          if (tagTransferDefaultStatus != null) return;
                        }
                      }
                    }
                  }
                  final statusChilds =
                      getJsonField(status, r'''$.activities_status_childs''') ??
                          getJsonField(status, r'''$.status_childs''');
                  if (statusChilds is List) {
                    for (final c in statusChilds) {
                      searchStatusForDefault(c);
                      if (tagTransferDefaultStatus != null) return;
                    }
                  }
                }

                final activity = FFAppState().currentActivity;
                final rootStatuses = getJsonField(activity, r'''$.activity_status''');
                if (rootStatuses is List) {
                  for (final s in rootStatuses) {
                    searchStatusForDefault(s);
                    if (tagTransferDefaultStatus != null) break;
                  }
                }
                if (tagTransferDefaultStatus == null) {
                  final activitySteps =
                      getJsonField(activity, r'''$.activity_steps''');
                  if (activitySteps is List) {
                    for (final step in activitySteps) {
                      final sl = getJsonField(step, r'''$.activity_status''');
                      if (sl is List) {
                        for (final s in sl) {
                          searchStatusForDefault(s);
                          if (tagTransferDefaultStatus != null) break;
                        }
                      }
                      if (tagTransferDefaultStatus != null) break;
                    }
                  }
                }

                debugPrint(
                    '🔎 TAG-TRANSFER: default_status del status $statusId = "${tagTransferDefaultStatus ?? "(no encontrado)"}"');

                if (tagTransferDefaultStatus != null) {
                  final defaultStatus = tagTransferDefaultStatus!;
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
                  } else {
                    debugPrint(
                        '📋 TAG-TRANSFER: WRITER_STATUS no presente en default_status — no se inyectará visits_details');
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
                  // ═══════════════════════════════════════════════════════════
                  // DEBUG: Imprimir el contenido completo de visitDetails en
                  // memoria antes de filtrar/inyectar al JSON del tag de destino
                  // ═══════════════════════════════════════════════════════════
                  debugPrint('');
                  debugPrint('═══════════════════════════════════════════════════════════');
                  debugPrint('📦 TAG-TRANSFER WRITE: Contenido de visitDetails EN MEMORIA');
                  debugPrint('   tag-transfer statusId actual (será excluido): $statusId');
                  debugPrint('   total entradas: ${FFAppState().visitDetails.length}');
                  debugPrint('───────────────────────────────────────────────────────────');
                  for (int i = 0; i < FFAppState().visitDetails.length; i++) {
                    final d = FFAppState().visitDetails[i];
                    final excluded = d.idActivityStatus == statusId;
                    debugPrint(
                        '   [$i] ${excluded ? "⏭️ EXCLUIDO" : "✅ INYECTAR "} '
                        'idActivityStatus=${d.idActivityStatus} '
                        'idStepParent=${d.idStepParent} '
                        'typeStatus="${d.typeStatus}" '
                        'statusOption="${d.statusOption}" '
                        'statusResponse="${d.statusResponse.length > 80 ? "${d.statusResponse.substring(0, 80)}…(${d.statusResponse.length} chars)" : d.statusResponse}"');
                  }
                  debugPrint('═══════════════════════════════════════════════════════════');
                  debugPrint('');

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
                    // Imprimir el bloque exacto inyectado al tag (status.visits_details)
                    debugPrint('───────────────────────────────────────────────────────────');
                    debugPrint('📤 BLOQUE INYECTADO en tag.status.visits_details:');
                    debugPrint(const JsonEncoder.withIndent('  ')
                        .convert(srcJson['status']));
                    debugPrint('───────────────────────────────────────────────────────────');
                    debugPrint('📤 JSON FINAL a escribir en tag de destino (${contentToTransfer.length} chars):');
                    debugPrint(contentToTransfer);
                    debugPrint('═══════════════════════════════════════════════════════════');
                  } else {
                    debugPrint(
                        '⚠️ TAG-TRANSFER: parseNfcJson devolvió null — no se pudo inyectar visits_details. Se escribirá el contenido origen sin modificar.');
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
                                  color: Color(0xFF74C69D),
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
                        // Nombre del operador principal (OP) con prefijo Recolector
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Recolector: ',
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
        ? const Color(0xFF40916C).withValues(alpha: 0.5)
        : const Color(0xFFBDBDBD).withValues(alpha: 0.5);

    final iconColor =
        hasBeenCalculated ? const Color(0xFF52B788) : const Color(0xFF9E9E9E);

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
                  Center(
                    child: Text(
                      displayValue,
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
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00a86b).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _textControllers[statusId],
        focusNode: _textFocusNodes[statusId],
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          color: Color(0xFF00a86b),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Escribe aquí...',
          hintStyle: TextStyle(
            color: const Color(0xFF00a86b).withValues(alpha: 0.5),
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
            Color(0xFFF1F8F4),
            Color(0xFFFAFDFB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00a86b).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00a86b).withValues(alpha: 0.1),
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
                    Color(0xFF00a86b),
                    Color(0xFF00d980),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00a86b).withValues(alpha: 0.4),
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
                      color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _usersSearchControllers[statusId],
                    focusNode: _usersSearchFocusNodes[statusId],
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      color: Color(0xFF00a86b),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF00a86b).withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00a86b),
                        size: 22,
                      ),
                      suffixIcon: _usersSearchControllers[statusId]!.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: const Color(0xFF00a86b).withValues(alpha: 0.6),
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
                        Color(0xFF00a86b),
                        Color(0xFF00d980),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00a86b).withValues(alpha: 0.4),
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
                    color: const Color(0xFF00a86b).withValues(alpha: 0.7),
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
            color: const Color(0xFF00a86b).withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00a86b).withValues(alpha: 0.08),
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
                    Color(0xFF00a86b),
                    Color(0xFF00d980),
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
                      color: Color(0xFF00a86b),
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
                      color: const Color(0xFF00a86b).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF00a86b).withValues(alpha: 0.5),
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
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00a86b).withValues(alpha: 0.3),
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
                  color: const Color(0xFF00a86b).withValues(alpha: 0.5),
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
                      color: Color(0xFF00a86b),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Foto capturada',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00a86b),
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
                    color: Color(0xFF00a86b),
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
          color: const Color(0xFFF1F8F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00a86b).withValues(alpha: 0.3),
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
                  color: const Color(0xFF00a86b).withValues(alpha: 0.5),
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
                      color: Color(0xFF00a86b),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Video capturado',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00a86b),
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
                    color: Color(0xFF00a86b),
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
                  color: const Color(0xFF52B788).withValues(alpha: 0.3),
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
                            colors: [Color(0xFF52B788), Color(0xFF40916C)],
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
                        color: const Color(0xFF52B788).withValues(alpha: 0.3),
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
                                    colors: [Color(0xFF52B788), Color(0xFF40916C)],
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
                    colors: [Color(0xFF52B788), Color(0xFF40916C)],
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
                    Text(
                      '${_formatDecimal(grandTotal)} kg',
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
          color: const Color(0xFF40916C).withValues(alpha: 0.3),
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
                    Icon(Icons.analytics_rounded, color: Color(0xFF52B788), size: 20),
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
                Row(
                  children: [
                    _buildDistBadge(
                      label: 'Peso neto',
                      value: '${_formatDecimal(pesoNeto)} kg',
                      color: const Color(0xFF52B788),
                    ),
                    const SizedBox(width: 8),
                    _buildDistBadge(
                      label: 'Factor',
                      value: factor.toStringAsFixed(4),
                      color: const Color(0xFF40916C),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF40916C), height: 1, thickness: 0.5),

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
                          color: const Color(0xFF52B788),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hqName,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _buildDistBadge(
                          label: '',
                          value: '$totalResults rac.',
                          color: const Color(0xFF2196F3).withValues(alpha: 0.7),
                          compact: true,
                        ),
                        const SizedBox(width: 6),
                        _buildDistBadge(
                          label: '',
                          value: '${_formatDecimal(pesoAsignado)} kg',
                          color: const Color(0xFF52B788).withValues(alpha: 0.7),
                          compact: true,
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
                            const Icon(Icons.person_outline, color: Color(0xFF74C69D), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
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
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 11,
                                        color: Color(0xFF74C69D),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildDistBadge(
                              label: '',
                              value: '$opResults rac.',
                              color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                              compact: true,
                            ),
                            const SizedBox(width: 6),
                            _buildDistBadge(
                              label: '',
                              value: '${_formatDecimal(pesoOp)} kg',
                              color: const Color(0xFF52B788).withValues(alpha: 0.5),
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const Divider(color: Color(0xFF40916C), height: 1, thickness: 0.3),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL DISTRIBUIDO:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF74C69D),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF52B788).withValues(alpha: 0.5)),
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

  /// Muestra la fórmula evaluada INLINE para headquarter-weight
  Widget _buildHeadquarterWeightInlineDisplay({
    required int statusId,
    required dynamic status,
  }) {
    // Obtener el dato para este statusId
    final data = _calculatedHeadquarterWeights[statusId];
    if (data == null) {
      return const SizedBox.shrink();
    }

    final evaluatedFormula = data['evaluatedFormula'] as String? ?? '';

    if (evaluatedFormula.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332), // Verde oscuro igual que tag-reader
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF40916C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fórmula evaluada con valores reemplazados
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                color: Color(0xFF52B788),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evaluatedFormula,
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
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
                              AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
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
                                        const Color(0xFF00a86b)
                                            .withValues(alpha: 0.2),
                                        const Color(0xFF00d980)
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
                        Color(0xFF00a86b),
                        Color(0xFF00d980),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00a86b),
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
                              const Color(0xFF00a86b).withValues(alpha: 0.3),
                              const Color(0xFF00d980).withValues(alpha: 0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00a86b)
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
                              color: Color(0xFF00d980),
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
                        Color(0xFF00a86b),
                        Color(0xFF00d980),
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
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
