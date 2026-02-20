import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/components/gps_quality_indicator_widget.dart';
import '/components/calibration_required_dialog_widget.dart';
import '/components/modern_calibrate_compass_widget.dart';
import '/custom_code/actions/index.dart';
import '/backend/schema/structs/read_geo_struct.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '/backend/sqlite/global_db_singleton.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';
import '/index.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

// Modelo para métricas de actividad
class _ActivityMetrics {
  final String activityName;
  final int idActivity;
  final int totalVisits;
  final int totalResults;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String unity;

  _ActivityMetrics({
    required this.activityName,
    required this.idActivity,
    required this.totalVisits,
    required this.totalResults,
    this.firstDate,
    this.lastDate,
    this.unity = '',
  });

  /// Obtiene el label de unidad, retorna 'Resultados' si unity está vacío
  String get unityLabel => unity.isNotEmpty ? unity : 'Resultados';
}

class _HomePageWidgetState extends State<HomePageWidget>
    with TickerProviderStateMixin {
  late HomePageModel _model;
  String _appVersion = '';
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Estados para búsqueda
  List<Map<String, dynamic>> _allActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];
  Map<String, dynamic>? _selectedActivity;
  bool _showSearchPreview = false;

  // Estados para botón flotante de búsqueda
  bool _isSearchExpanded = false;
  late AnimationController _searchButtonController;
  late AnimationController _searchCloudController;
  late Animation<double> _searchButtonRotation;
  late Animation<double> _searchCloudScale;
  late Animation<double> _searchCloudOpacity;

  // Estados para animaciones
  late AnimationController _userBadgeController;
  late AnimationController _activityBadgeController;

  // Estados para carrusel de actividades
  List<_ActivityMetrics> _activityMetrics = [];
  final PageController _carouselController = PageController(viewportFraction: 0.85);
  int _currentCarouselIndex = 0;

  // Última fecha de visita
  String _lastVisitDate = 'Cargando...';

  // Suscripción al servicio de background para eventos GPS
  StreamSubscription<Map<String, dynamic>?>? _gpsServiceSubscription;
  StreamSubscription<Map<String, dynamic>?>? _locationServiceSubscription;

  // Timer para procesar ubicaciones cada 60 segundos
  Timer? _locationProcessingTimer;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    _model.searchController ??= TextEditingController();
    _model.searchFocusNode ??= FocusNode();

    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version} (${info.buildNumber})';
        });
      }
    });

    // Escuchar eventos del servicio de background (GPS estabilizado)
    _setupGpsServiceListener();

    // Controllers de animación
    _userBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _activityBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Controllers para botón flotante de búsqueda
    _searchButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _searchCloudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _searchButtonRotation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _searchButtonController, curve: Curves.easeInOut),
    );
    _searchCloudScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchCloudController, curve: Curves.elasticOut),
    );
    _searchCloudOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchCloudController, curve: Curves.easeOut),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _loadActivities();
      await _loadLastVisitDate();
      await _loadActivityMetrics();
      _userBadgeController.forward();

      // Iniciar servicio de geolocalización en segundo plano
      // IMPORTANTE: Verificar y solicitar permisos ANTES de iniciar el servicio
      // porque el servicio de segundo plano no tiene acceso a UI/Activity
      debugPrint('🚀 Verificando permisos de ubicación antes de iniciar servicio...');
      try {
        // Verificar si el servicio de ubicación está habilitado
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('⚠️ Servicio de ubicación deshabilitado. El usuario debe habilitarlo manualmente.');
          // Opcionalmente mostrar diálogo al usuario
        }

        // Verificar permisos
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 Solicitando permisos de ubicación...');
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint('❌ Permisos de ubicación denegados. No se puede iniciar el servicio.');
          // El servicio no se iniciará sin permisos
        } else {
          // Permisos otorgados, ahora sí iniciar el servicio
          debugPrint('✅ Permisos de ubicación otorgados. Iniciando servicio...');
          await startBackgroundLocationService();
          debugPrint('✅ Servicio de geolocalización iniciado correctamente');
        }
      } catch (e) {
        debugPrint('⚠️ Error al iniciar servicio de geolocalización: $e');
      }

      // Verificar si se necesita calibración
      await _checkAndShowCalibrationDialog();
    });

    // Listener para búsqueda en tiempo real
    _model.searchController?.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _gpsServiceSubscription?.cancel();
    _locationServiceSubscription?.cancel();
    _locationProcessingTimer?.cancel();
    _model.dispose();
    _userBadgeController.dispose();
    _activityBadgeController.dispose();
    _searchButtonController.dispose();
    _searchCloudController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  // Configurar listener para eventos del servicio de background GPS
  void _setupGpsServiceListener() {
    debugPrint('🔧 Configurando listeners del servicio de GPS...');
    final service = FlutterBackgroundService();

    // Listener para evento de GPS estabilizado
    _gpsServiceSubscription = service.on('gpsStabilized').listen((event) {
      if (event != null && event['stabilized'] == true) {
        debugPrint('📡 Evento recibido: GPS estabilizado');
        if (mounted) {
          FFAppState().update(() {
            FFAppState().isStabilized = true;
          });
        }
      }
    });
    debugPrint('   ✅ Listener "gpsStabilized" configurado');

    // Listener para recibir ubicaciones del servicio de background
    _locationServiceSubscription = service.on('newLocation').listen((event) {
      if (event != null && mounted) {
        try {
          final geoStruct = ReadGeoStruct(
            latitude: (event['latitude'] as num?)?.toDouble(),
            longitude: (event['longitude'] as num?)?.toDouble(),
            altitude: (event['altitude'] as num?)?.toDouble(),
            errorHorizontal: (event['horizontalError'] as num?)?.toDouble(),
            dateHourRead: DateTime.tryParse(event['createdAt'] ?? ''),
          );

          // Agregar a la lista en AppState
          FFAppState().update(() {
            FFAppState().geoLocationsList.add(geoStruct);

            // Si están llegando ubicaciones, el GPS YA está estabilizado
            // (el servicio solo envía ubicaciones después de estabilizar)
            if (!FFAppState().isStabilized) {
              FFAppState().isStabilized = true;
              debugPrint('📡 GPS marcado como estabilizado (ubicaciones llegando)');
            }
          });

          // Log cada 20 ubicaciones para no saturar la consola
          if (FFAppState().geoLocationsList.length % 20 == 0) {
            debugPrint(
                '📍 ${FFAppState().geoLocationsList.length} puntos GPS acumulados en AppState');
          }
        } catch (e) {
          debugPrint('❌ Error procesando ubicación recibida: $e');
        }
      }
    }, onError: (error) {
      debugPrint('❌ Error en listener "newLocation": $error');
    }, onDone: () {
      debugPrint('⚠️ Listener "newLocation" cerrado');
    });
    debugPrint('   ✅ Listener "newLocation" configurado');

    // Timer para procesar y depurar ubicaciones cada 60 segundos
    _locationProcessingTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) async {
      await _processAndInsertLocations();
    });

    debugPrint(
        '✅ Listeners de GPS configurados + Timer de procesamiento cada 60s');
  }

  /// Procesa las ubicaciones acumuladas, las depura y las inserta en SQLite
  /// Estrategia de prevención de duplicados:
  /// - Siempre mantiene al menos 1 registro en geoLocationsList
  /// - Procesa e inserta todos los registros EXCEPTO el último
  /// - El último registro se procesará en el siguiente ciclo de 60s
  Future<void> _processAndInsertLocations() async {
    try {
      // Tomar una copia atómica de la lista
      final allLocations = List<ReadGeoStruct>.from(FFAppState().geoLocationsList);

      // Validar que hay suficientes registros para procesar
      if (allLocations.isEmpty) {
        debugPrint('⏭️ Sin ubicaciones para procesar');
        return;
      }

      if (allLocations.length < 2) {
        debugPrint('⏭️ Solo hay ${allLocations.length} ubicación(es), esperando más puntos para procesar...');
        debugPrint('   Se necesitan al menos 2 registros para mantener 1 en AppState y procesar el resto');
        return;
      }

      // Procesar todos EXCEPTO el último para evitar duplicados en el próximo ciclo
      final locationsToProcess = allLocations.sublist(0, allLocations.length - 1);

      debugPrint('🔄 Procesando ${locationsToProcess.length} ubicaciones (guardando última para próximo ciclo)...');
      debugPrint('   Total en AppState: ${allLocations.length} | A procesar: ${locationsToProcess.length} | Quedarán: 1');

      // Depurar las ubicaciones a procesar (agrupar puntos dentro de 2 metros)
      final depurados = _depurarGeolocalizaciones(locationsToProcess);

      debugPrint(
          '📊 Depuración: ${locationsToProcess.length} registros → ${depurados.length} grupos');

      // Insertar a SQLite
      await _insertDepuradosToSQLite(depurados);

      // Limpiar solo los procesados, mantener el último
      FFAppState().geoLocationsList = [allLocations.last];

      debugPrint('✅ Procesamiento completado.');
      debugPrint('   ✓ ${locationsToProcess.length} registros procesados e insertados en SQLite');
      debugPrint('   ✓ Último punto GPS mantenido en AppState para próximo ciclo');
      debugPrint('   ✓ geoLocationsList ahora tiene: ${FFAppState().geoLocationsList.length} registro(s)');
    } catch (e) {
      debugPrint('❌ Error en _processAndInsertLocations: $e');
    }
  }

  /// Depura geolocalizaciones agrupando puntos dentro de un radio de 2 metros
  List<Map<String, dynamic>> _depurarGeolocalizaciones(
      List<ReadGeoStruct> locations) {
    if (locations.isEmpty) return [];

    if (locations.length == 1) {
      final loc = locations.first;
      return [
        _crearRegistroDepurado([loc]),
      ];
    }

    const double radioUmbral = 2.0; // metros
    final List<Map<String, dynamic>> resultado = [];

    // Ordenar por fecha
    final sortedLocations = List<ReadGeoStruct>.from(locations)
      ..sort((a, b) =>
          (a.dateHourRead ?? DateTime.now())
              .compareTo(b.dateHourRead ?? DateTime.now()));

    // Iniciar primer grupo
    List<ReadGeoStruct> grupoActual = [sortedLocations.first];

    for (int i = 1; i < sortedLocations.length; i++) {
      final puntoActual = sortedLocations[i];
      final centroide = _calcularCentroide(grupoActual);

      final distancia = _haversineDistance(
        centroide['lat']!,
        centroide['lon']!,
        puntoActual.latitude,
        puntoActual.longitude,
      );

      if (distancia <= radioUmbral) {
        // Agregar al grupo actual
        grupoActual.add(puntoActual);
      } else {
        // Finalizar grupo y crear registro depurado
        resultado.add(_crearRegistroDepurado(grupoActual));
        // Iniciar nuevo grupo
        grupoActual = [puntoActual];
      }
    }

    // Procesar último grupo
    if (grupoActual.isNotEmpty) {
      resultado.add(_crearRegistroDepurado(grupoActual));
    }

    return resultado;
  }

  /// Calcula el centroide (punto promedio) de un grupo de ubicaciones
  Map<String, double> _calcularCentroide(List<ReadGeoStruct> puntos) {
    double sumLat = 0, sumLon = 0;
    for (final p in puntos) {
      sumLat += p.latitude;
      sumLon += p.longitude;
    }
    return {
      'lat': sumLat / puntos.length,
      'lon': sumLon / puntos.length,
    };
  }

  /// Crea un registro depurado a partir de un grupo de puntos
  Map<String, dynamic> _crearRegistroDepurado(List<ReadGeoStruct> grupo) {
    final centroide = _calcularCentroide(grupo);

    // Calcular promedios
    double sumAlt = 0, sumErr = 0;
    for (final p in grupo) {
      sumAlt += p.altitude;
      sumErr += p.errorHorizontal;
    }

    final int count = grupo.length;

    // Calcular radio máximo (distancia del centroide al punto más lejano)
    double maxRadius = 0.0;
    for (final p in grupo) {
      final dist = _haversineDistance(
        centroide['lat']!,
        centroide['lon']!,
        p.latitude,
        p.longitude,
      );
      if (dist > maxRadius) maxRadius = dist;
    }

    final dateStart = grupo.first.dateHourRead ?? DateTime.now();
    final dateFinish = grupo.last.dateHourRead ?? DateTime.now();

    return {
      'Id_company': FFAppState().companyDefault.idCompany,
      'Imei': FFAppState().deviceDefault.imeI1,
      'Latitude': centroide['lat'],
      'Longitude': centroide['lon'],
      'Altitude': sumAlt / count,
      'HorizontalError': sumErr / count,
      'Speed': 0.0, // Promedio no disponible en ReadGeoStruct
      'Battery': 0, // No disponible en ReadGeoStruct
      'CreatedAt': dateStart.toIso8601String(),
      'SyncedAt': DateTime.now().toIso8601String(),
      'batch_id': null,
      'date_start': dateStart.toIso8601String(),
      'date_finish': dateFinish.toIso8601String(),
      'evaluated_radius': maxRadius,
      'point_count': count,
      'Id_user': FFAppState().userSelected.idUser,
      'Id_activity': FFAppState().activitySelected.idActivity,
    };
  }

  /// Calcula distancia Haversine entre dos puntos en metros
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000.0; // Radio de la Tierra en metros
    final double lat1Rad = lat1 * 3.141592653589793 / 180;
    final double lat2Rad = lat2 * 3.141592653589793 / 180;
    final double dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final double dLon = (lon2 - lon1) * 3.141592653589793 / 180;

    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  /// Inserta los registros depurados en SQLite
  Future<void> _insertDepuradosToSQLite(
      List<Map<String, dynamic>> depurados) async {
    if (depurados.isEmpty) return;

    int insertados = 0;

    try {
      await globalDb.executeOperation((db) async {
        for (final loc in depurados) {
          // Usar INSERT OR IGNORE para evitar errores de duplicados
          final result = await db.rawInsert('''
            INSERT OR IGNORE INTO Location_tracking
            (Id_company, Imei, Latitude, Longitude, Altitude, HorizontalError,
             Speed, Battery, CreatedAt, SyncedAt, batch_id,
             date_start, date_finish, evaluated_radius, point_count,
             Id_user, Id_activity)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            loc['Id_company'],
            loc['Imei'],
            loc['Latitude'],
            loc['Longitude'],
            loc['Altitude'],
            loc['HorizontalError'],
            loc['Speed'],
            loc['Battery'],
            loc['CreatedAt'],
            loc['SyncedAt'],
            loc['batch_id'],
            loc['date_start'],
            loc['date_finish'],
            loc['evaluated_radius'],
            loc['point_count'],
            loc['Id_user'],
            loc['Id_activity'],
          ]);
          if (result > 0) insertados++;
        }
      });

      debugPrint('💾 $insertados/${depurados.length} registros insertados en SQLite');
    } catch (e) {
      debugPrint('❌ Error insertando en SQLite: $e');
    }
  }

  // Obtener iniciales del usuario
  String _getUserInitials() {
    final userName = FFAppState().userSelected.nameUser;
    if (userName.isEmpty) return 'U';

    final words = userName.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return userName[0].toUpperCase();
  }

  // Cargar última fecha de visita - usando singleton global
  Future<void> _loadLastVisitDate() async {
    try {
      final result = await globalDb.executeOperation((db) async {
        return await db.rawQuery('''
          SELECT MAX(Created_at) as last_date
          FROM Visits
          WHERE Id_user = ?
        ''', [FFAppState().userSelected.idUser]);
      });

      if (result.isNotEmpty && result.first['last_date'] != null) {
        final lastDate = DateTime.parse(result.first['last_date'] as String);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(lastDate);

        if (mounted) {
          setState(() {
            _lastVisitDate = 'Última actividad: $formattedDate';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastVisitDate = 'Sin actividad reciente';
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando última visita: $e');
      if (mounted) {
        setState(() {
          _lastVisitDate = 'Sin información';
        });
      }
    }
  }

  // Cargar actividades desde SQLite - usando singleton global
  Future<void> _loadActivities() async {
    try {
      final activities = await globalDb.executeOperation((db) async {
        return await db.query('Activities', orderBy: 'Name_activity ASC');
      });

      if (mounted) {
        setState(() {
          _allActivities = activities;
        });
      }
    } catch (e) {
      debugPrint('Error cargando actividades: $e');
    }
  }

  // Cargar métricas de actividades para el carrusel - usando singleton global
  Future<void> _loadActivityMetrics() async {
    try {
      final activities = await globalDb.executeOperation((db) async {
        return await db.rawQuery('''
          SELECT
            a.Id_activity,
            a.Name_activity as activity_name,
            a.Unity as unity,
            COUNT(DISTINCT v.Id_visit) as total_visits,
            MIN(v.Created_at) as first_date,
            MAX(v.Created_at) as last_date
          FROM Activities a
          LEFT JOIN Visits v ON a.Id_activity = v.Id_activity
          WHERE v.Id_visit IS NOT NULL
          GROUP BY a.Id_activity, a.Name_activity, a.Unity
          ORDER BY total_visits DESC
        ''');
      });

      List<_ActivityMetrics> metrics = [];
      for (var activity in activities) {
        final activityId = (activity['Id_activity'] as int?) ?? 0;

        // Calcular totalResults usando la fórmula: Primer Total + Segundo Total
        final totalResults = await _calculateTotalResultsForActivity(activityId);

        metrics.add(_ActivityMetrics(
          activityName: activity['activity_name'] as String,
          idActivity: activityId,
          totalVisits: (activity['total_visits'] as int?) ?? 0,
          totalResults: totalResults,
          firstDate: activity['first_date'] != null
              ? DateTime.tryParse(activity['first_date'] as String)
              : null,
          lastDate: activity['last_date'] != null
              ? DateTime.tryParse(activity['last_date'] as String)
              : null,
          unity: (activity['unity'] as String?) ?? '',
        ));
      }

      if (mounted) {
        setState(() {
          _activityMetrics = metrics;
        });
      }
    } catch (e) {
      debugPrint('Error cargando métricas de actividades: $e');
    }
  }

  // Método helper para calcular el total de resultados por actividad
  // Total Results = Total1 + Total2 (basado en Visits_details registrados)
  // Total1: Suma de factores de status SIN step parent (ligados directamente a la actividad)
  // Total2: Suma de factores de status CON step parent donde Calculation = '=SUMAFACTORES'
  // Los status con step parent donde Calculation != '=SUMAFACTORES' (ej: =NINGUNO) NO se suman
  Future<int> _calculateTotalResultsForActivity(int activityId) async {
    try {
      final result = await globalDb.executeOperation((db) async {
        return await db.rawQuery('''
          SELECT COALESCE(SUM(factor_value), 0) as total_results
          FROM (
            -- Total1: Status sin step parent (ligados directamente a la actividad)
            SELECT acs.Factor as factor_value
            FROM Visits_details vd
            INNER JOIN Visits v ON vd.Id_visit = v.Id_visit
            INNER JOIN Activities_status acs ON vd.Id_activity_status = acs.Id_activity_status
            WHERE v.Id_activity = ?
              AND (acs.Id_activity_step_parent IS NULL OR acs.Id_activity_step_parent = 0)

            UNION ALL

            -- Total2: Status con step parent donde Calculation = '=SUMAFACTORES'
            SELECT acs.Factor as factor_value
            FROM Visits_details vd
            INNER JOIN Visits v ON vd.Id_visit = v.Id_visit
            INNER JOIN Activities_status acs ON vd.Id_activity_status = acs.Id_activity_status
            INNER JOIN Activities_steps ast ON acs.Id_activity_step_parent = ast.Id_activity_step
            WHERE v.Id_activity = ?
              AND ast.Calculation = '=SUMAFACTORES'
          )
        ''', [activityId, activityId]);
      });

      if (result.isNotEmpty) {
        return (result[0]['total_results'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('Error calculating total results for activity $activityId: $e');
    }
    return 0;
  }

  // Búsqueda en tiempo real
  void _onSearchChanged() {
    final query = _model.searchController?.text ?? '';

    if (query.isEmpty) {
      setState(() {
        _filteredActivities = [];
        _showSearchPreview = false;
      });
      return;
    }

    setState(() {
      _filteredActivities = _allActivities.where((activity) {
        final activityName = (activity['Name_activity'] as String? ?? '').toLowerCase();
        return activityName.contains(query.toLowerCase());
      }).toList();
      _showSearchPreview = true;
    });
  }

  // Verificar y mostrar diálogo de calibración si es necesario
  Future<void> _checkAndShowCalibrationDialog() async {
    try {
      // Verificar si se necesita calibración usando la custom action
      final needsCalibration = await checkCalibrationNeeded();

      if (needsCalibration && mounted) {
        // Mostrar el diálogo de calibración
        await showDialog(
          context: context,
          barrierDismissible: false, // No se puede cerrar tocando fuera
          builder: (dialogContext) => CalibrationRequiredDialogWidget(
            onCalibrateNow: () async {
              // Cerrar el diálogo de aviso
              Navigator.of(dialogContext).pop();

              // Abrir el diálogo de calibración
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (calibrateContext) => Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.95,
                    width: MediaQuery.sizeOf(context).width * 0.95,
                    child: ModernCalibrateCompassWidget(),
                  ),
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al verificar calibración: $e');
    }
  }

  // Seleccionar actividad - actualiza inmediatamente el AppState
  void _selectActivity(Map<String, dynamic> activity) {
    setState(() {
      _selectedActivity = activity;
      _showSearchPreview = false;
      _model.searchController?.clear();
    });

    // Actualizar inmediatamente el AppState para que DoActivitiesPage lo vea
    FFAppState().update(() {
      FFAppState().activitySelectedJSON = activity;
    });

    FocusScope.of(context).unfocus();
    _activityBadgeController.forward(from: 0);
  }

  // Limpiar actividad seleccionada
  void _clearSelectedActivity() {
    setState(() {
      _selectedActivity = null;
    });

    // Limpiar también el AppState
    FFAppState().update(() {
      FFAppState().activitySelectedJSON = null;
    });

    _activityBadgeController.reverse();
  }

  // Toggle del botón flotante de búsqueda
  void _toggleSearchCloud() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });

    if (_isSearchExpanded) {
      _searchButtonController.forward();
      _searchCloudController.forward();
      // Auto-focus en el campo de búsqueda
      Future.delayed(Duration(milliseconds: 300), () {
        _model.searchFocusNode?.requestFocus();
      });
    } else {
      _searchButtonController.reverse();
      _searchCloudController.reverse();
      _model.searchController?.clear();
      setState(() {
        _showSearchPreview = false;
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return PopScope(
      canPop: false, // Bloquea el botón back del sistema - HomePage es la página principal
      onPopInvokedWithResult: (didPop, result) async {
        // Si alguien intenta hacer pop, no hacemos nada
        // HomePage es la raíz de la navegación
        if (didPop) {
          return;
        }
        // Opcionalmente puedes mostrar un diálogo preguntando si quiere salir de la app
        // pero por ahora simplemente bloqueamos la navegación
      },
      child: GPSQualityWrapper(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Stack(
              children: [
                // Contenido principal
                SafeArea(
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Header con identificación de usuario
                          _buildUserHeader(),

                          SizedBox(height: 16),

                          // 2. Botones de Información y Sincronización (compactos)
                          _buildInfoSyncButtons(),

                          SizedBox(height: 16),

                          // 3. Cuadro de búsqueda con badge de actividad seleccionada
                          _buildSearchSection(),

                          SizedBox(height: 20),

                          // 4. Lista de módulos (5 primeros + "Ver más")
                          _buildModulesList(),

                          SizedBox(height: 20),

                          // 5. Dashboard Agronómico (sin título superior, 2 tabs)
                          _buildDashboard(),

                          SizedBox(height: 100), // Espacio para el botón flotante
                        ],
                      ),
                    ),
                  ),
                ),

                // Indicador de versión
                if (_appVersion.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: SafeArea(
                      child: Text(
                        _appVersion,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                // Botones flotantes y nube de búsqueda
                _buildFloatingButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // COMPONENTES
  // ============================================================================

  Widget _buildUserHeader() {
    final userName = FFAppState().userSelected.nameUser;

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _userBadgeController,
        curve: Curves.elasticOut,
      ),
      child: InkWell(
        onTap: () async {
          context.pushNamed('UsersPage');
        },
        splashColor: Color(0xFF00a86b).withOpacity(0.3),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
          padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00a86b).withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFF00a86b).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00a86b).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Row(
                children: [
                  // Badge circular con iniciales
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF003420), // Verde oscuro sólido, sin gradiente
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getUserInitials(),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // Información del usuario
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          userName.isNotEmpty ? userName : 'Usuario',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _lastVisitDate,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00ff9f),
                              letterSpacing: 0.3,
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
      ),
    );
  }

  Widget _buildInfoSyncButtons() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          context.pushNamed(
            InformationPageWidget.routeName,
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.bottomToTop,
                duration: Duration(milliseconds: 600),
              ),
            },
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: (FFAppState().visitsAdd.length > 0) ||
                      (FFAppState().productsAdd.length > 0) ||
                      (FFAppState().newsSelected.length > 0)
                  ? [
                      FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).primary.withOpacity(0.7),
                    ]
                  : [
                      FlutterFlowTheme.of(context).orange,
                      FlutterFlowTheme.of(context).orange.withOpacity(0.7),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 15,
                color: ((FFAppState().visitsAdd.length > 0) ||
                        (FFAppState().productsAdd.length > 0) ||
                        (FFAppState().newsSelected.length > 0)
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).orange)
                    .withOpacity(0.4),
                offset: Offset(0, 6),
                spreadRadius: 1,
              )
            ],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información y sincronización',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      (FFAppState().visitsAdd.length > 0) ||
                              (FFAppState().productsAdd.length > 0)
                          ? 'Hay información pendiente'
                          : 'Sin información pendiente',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
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
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Badge de actividad seleccionada
              if (_selectedActivity != null)
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _activityBadgeController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    padding: EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF00ff9f),
                          Color(0xFF00a86b),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00ff9f).withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 100),
                          child: Text(
                            _selectedActivity!['Name_activity'] as String? ?? '',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: _clearSelectedActivity,
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Botones flotantes con nube de búsqueda ultra moderna
  Widget _buildFloatingButtons() {
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(right: 16, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Nube de búsqueda emergente
              AnimatedBuilder(
                animation: _searchCloudController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _searchCloudScale.value,
                    alignment: Alignment.bottomRight,
                    child: Opacity(
                      opacity: _searchCloudOpacity.value,
                      child: _isSearchExpanded
                          ? Container(
                              width: MediaQuery.of(context).size.width - 32,
                              constraints: BoxConstraints(maxHeight: 400),
                              margin: EdgeInsets.only(bottom: 12, left: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00ff9f).withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 5,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.black.withOpacity(0.85),
                                      Color(0xFF001a0f).withOpacity(0.9),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Color(0xFF00ff9f).withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Campo de búsqueda
                                    Container(
                                      padding: EdgeInsets.all(20),
                                      child: TextField(
                                        controller: _model.searchController,
                                        focusNode: _model.searchFocusNode,
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Buscar actividad...',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 16,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: Color(0xFF00ff9f),
                                            size: 26,
                                          ),
                                          suffixIcon: _model.searchController?.text.isNotEmpty ?? false
                                              ? IconButton(
                                                  icon: Icon(
                                                    Icons.clear_rounded,
                                                    color: Colors.white.withOpacity(0.7),
                                                    size: 22,
                                                  ),
                                                  onPressed: () {
                                                    _model.searchController?.clear();
                                                    setState(() {
                                                      _showSearchPreview = false;
                                                    });
                                                  },
                                                )
                                              : null,
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.1),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Color(0xFF00ff9f).withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Color(0xFF00ff9f).withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Color(0xFF00ff9f),
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Resultados de búsqueda
                                    if (_showSearchPreview && _filteredActivities.isNotEmpty)
                                      Container(
                                        constraints: BoxConstraints(maxHeight: 280),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                                          itemCount: _filteredActivities.length > 6
                                              ? 6
                                              : _filteredActivities.length,
                                          itemBuilder: (context, index) {
                                            final activity = _filteredActivities[index];
                                            return TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              duration: Duration(milliseconds: 300 + (index * 50)),
                                              curve: Curves.easeOutBack,
                                              builder: (context, value, child) {
                                                return Transform.translate(
                                                  offset: Offset(30 * (1 - value), 0),
                                                  child: Opacity(
                                                    opacity: value.clamp(0.0, 1.0),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                margin: EdgeInsets.only(bottom: 8),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white.withOpacity(0.08),
                                                      Colors.white.withOpacity(0.03),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Color(0xFF00a86b).withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(14),
                                                    onTap: () {
                                                      _selectActivity(activity);
                                                      _toggleSearchCloud();
                                                    },
                                                    child: Padding(
                                                      padding: EdgeInsets.all(14),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 42,
                                                            height: 42,
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [
                                                                  Color(0xFF00ff9f),
                                                                  Color(0xFF00a86b),
                                                                ],
                                                              ),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Icon(
                                                              Icons.work_outline_rounded,
                                                              color: Colors.white,
                                                              size: 22,
                                                            ),
                                                          ),
                                                          SizedBox(width: 14),
                                                          Expanded(
                                                            child: Text(
                                                              activity['Name_activity'] as String? ?? '',
                                                              style: TextStyle(
                                                                fontFamily: 'Roboto',
                                                                color: Colors.white,
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.w600,
                                                                height: 1.3,
                                                              ),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          Icon(
                                                            Icons.chevron_right_rounded,
                                                            color: Color(0xFF00ff9f).withOpacity(0.6),
                                                            size: 24,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox.shrink(),
                ),
              );
            },
          ),

              // Botón flotante de búsqueda
              AnimatedBuilder(
                animation: _searchButtonRotation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _searchButtonRotation.value * 2 * 3.14159,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isSearchExpanded
                              ? [
                                  Color(0xFFff6b6b),
                                  Color(0xFFee5a6f),
                                ]
                              : [
                                  Color(0xFF00ff9f),
                                  Color(0xFF00a86b),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isSearchExpanded
                                    ? Color(0xFFff6b6b)
                                    : Color(0xFF00ff9f))
                                .withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(32),
                          onTap: _toggleSearchCloud,
                          child: Icon(
                            _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModulesList() {
    final modules = [
      {
        'title': 'Polinización',
        'icon': 'assets/images/task-svgrepo-com.png',
        'moduleKey': 'POLINIZACION',
      },
      {
        'title': 'Cosecha',
        'icon': 'assets/images/box-time-svgrepo-com.png',
        'moduleKey': 'COSECHA',
      },
      {
        'title': 'Sanidad',
        'icon': 'assets/images/health-svgrepo-com.png',
        'moduleKey': 'SANIDAD',
      },
    ];

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Módulos rápidos',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Grid de módulos 2x2 (3 módulos + VER MÁS)
          Row(
            children: [
              // Columna izquierda: Polinización + Sanidad
              Expanded(
                child: Column(
                  children: [
                    _buildCompactModuleCard(modules[0]),
                    SizedBox(height: 12),
                    _buildCompactModuleCard(modules[2]),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Columna derecha: Cosecha + VER MÁS
              Expanded(
                child: Column(
                  children: [
                    _buildCompactModuleCard(modules[1]),
                    SizedBox(height: 12),
                    // Botón VER MÁS
                    InkWell(
                      onTap: () {
                        context.pushNamed(
                          ModulesPageWidget.routeName,
                          extra: <String, dynamic>{
                            kTransitionInfoKey: TransitionInfo(
                              hasTransition: true,
                              transitionType: PageTransitionType.fade,
                              duration: Duration(milliseconds: 600),
                            ),
                          },
                        );
                      },
                      child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00a86b).withOpacity(0.3),
                              Color(0xFF00a86b).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF00ff9f).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.apps_rounded,
                                color: Color(0xFF00ff9f),
                                size: 32,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'VER MÁS',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00ff9f),
                                  letterSpacing: 1,
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
        ],
      ),
    );
  }

  Widget _buildCompactModuleCard(Map<String, dynamic> module) {
    return InkWell(
      onTap: () async {
        FFAppState().moduleSelected = module['moduleKey'] as String;
        FFAppState().activitySelectedJSON = null;
        safeSetState(() {});

        context.pushNamed(
          DoActivitiesPageWidget.routeName,
          queryParameters: {
            'tittle': serializeParam(
              'Módulo de ${module['title']?.toString().toLowerCase()}',
              ParamType.String,
            ),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.bottomToTop,
              duration: Duration(milliseconds: 600),
            ),
          },
        );
      },
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF00a86b).withOpacity(0.25),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Row(
              children: [
                SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        module['icon'] as String,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    module['title'] as String,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    if (_activityMetrics.isEmpty) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFF00a86b).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              'Sin actividades registradas',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Resumen de Actividades',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Carrusel de actividades
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _carouselController,
              itemCount: _activityMetrics.length,
              onPageChanged: (index) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildActivityCard(_activityMetrics[index]);
              },
            ),
          ),

          // Indicadores de página
          if (_activityMetrics.length > 1)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_activityMetrics.length, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentCarouselIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentCarouselIndex == index
                          ? Color(0xFF00ff9f)
                          : Colors.white.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(_ActivityMetrics activity) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A3A2E).withOpacity(0.9),
            Color(0xFF0D1F17).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF00FF7F).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF00FF7F).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre de actividad
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.agriculture,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activity.activityName,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Métricas compactas + Gráfico de torta
            Expanded(
              child: Row(
                children: [
                  // Contadores compactos
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCompactMetric(
                        'Visitas',
                        activity.totalVisits.toString(),
                        Icons.location_on,
                        Color(0xFF00B4D8),
                      ),
                      SizedBox(height: 12),
                      _buildCompactMetric(
                        activity.unityLabel,
                        activity.totalResults.toString(),
                        Icons.fact_check,
                        Color(0xFF00C853),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  // Gráfico de torta
                  Expanded(
                    child: _buildPieChart(
                      activity.totalVisits,
                      activity.totalResults,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Rango de fechas
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(0xFF00a86b).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Color(0xFF00ff9f),
                    size: 12,
                  ),
                  SizedBox(width: 6),
                  Text(
                    _formatDateRange(activity.firstDate, activity.lastDate),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
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

  Widget _buildCompactMetric(String label, String value, IconData icon, Color color) {
    return Container(
      width: 110,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(int visits, int results) {
    final total = visits + results;
    if (total == 0) {
      return Center(
        child: Text(
          'Sin datos',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
        child: CustomPaint(
          painter: _PieChartPainter(
            visits: visits,
            results: results,
            visitColor: Color(0xFF00B4D8),
            resultColor: Color(0xFF00C853),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total.toString(),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateRange(DateTime? first, DateTime? last) {
    final dateFormat = DateFormat('dd/MM/yy');
    if (first == null && last == null) return 'Sin fechas';
    if (first != null && last != null) {
      if (first == last) return dateFormat.format(first);
      return '${dateFormat.format(first)} - ${dateFormat.format(last)}';
    }
    return dateFormat.format(first ?? last!);
  }

}

// Custom Painter para el gráfico de torta
class _PieChartPainter extends CustomPainter {
  final int visits;
  final int results;
  final Color visitColor;
  final Color resultColor;

  _PieChartPainter({
    required this.visits,
    required this.results,
    required this.visitColor,
    required this.resultColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = visits + results;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 20.0;

    final visitAngle = (visits / total) * 2 * 3.14159;
    final resultAngle = (results / total) * 2 * 3.14159;

    // Fondo del anillo
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Arco de visitas
    final visitPaint = Paint()
      ..color = visitColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      visitAngle,
      false,
      visitPaint,
    );

    // Arco de resultados
    final resultPaint = Paint()
      ..color = resultColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2 + visitAngle,
      resultAngle,
      false,
      resultPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
