import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io' show Platform;

import '/components/animated_splash_screen_widget.dart';
import '/custom_code/actions/background_location_service.dart'
    show
        initializeBackgroundLocationService,
        startBackgroundLocationService,
        stopBackgroundLocationService,
        gpsServiceRequestedByUser;
import '/custom_code/actions/enriched_geo_buffer.dart';
import '/custom_code/actions/get_location_list.dart' show depurarGeolocalizaciones;
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/components/gps_quality_indicator_widget.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:battery_plus/battery_plus.dart';

StreamSubscription<Position>? locationSubscription;

/// Key global para mostrar SnackBars desde cualquier parte de la app,
/// incluso desde servicios en background sin contexto de página.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await SQLiteManager.initialize();

  // Inicializar el servicio de geolocalización en segundo plano (solo móvil)
  if (!Platform.isWindows) {
    await initializeBackgroundLocationService();
  }

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  // En desktop no hay GPS ni brújula — simular sensores estabilizados
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    appState.isStabilized = true;
    appState.calibrateCompass = true;
  }

  WakelockPlus.enable();
  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;

  ThemeMode _themeMode = ThemeMode.system;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  bool displaySplashImage = true;
  bool _showAnimatedSplash = true;

  // Suscripciones globales al servicio GPS — viven toda la sesión de la app,
  // independientemente de qué página esté activa.
  StreamSubscription<Map<String, dynamic>?>? _gpsStabilizedSub;
  StreamSubscription<Map<String, dynamic>?>? _newLocationSub;
  final Set<String> _processedGpsKeys = {};

  // Contadores para detección de calidad GPS baja post-estabilización.
  // Se requieren N lecturas consecutivas para cambiar de estado (evita parpadeos).
  int _consecutiveBadReadings  = 0;
  int _consecutiveGoodReadings = 0;
  // Marca "ya estabilizó alguna vez" — independiente de isStabilized (que ahora
  // es dinámico y puede volver a false si la calidad se degrada).
  bool _everStabilized = false;
  static const int _badThreshold  = 3;   // lecturas malas seguidas → mostrar aviso
  static const int _goodThreshold = 3;   // lecturas buenas seguidas → ocultar aviso
  static const double _qualityThreshold = 10.0; // metros

  // Timer de persistencia periódica: cada 2 minutos depura y persiste la mitad
  // más vieja de geoLocationsList a SQLite, conservando la mitad más reciente.
  Timer? _sqlitePersistTimer;

  @override
  void initState() {
    super.initState();

    // Registrar observer para el ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);

    // Iniciar listeners GPS globales (solo móvil)
    if (!Platform.isWindows) {
      _setupGlobalGpsListeners();
      _startSqlitePersistTimer();
    }
  }

  @override
  void dispose() {
    _gpsStabilizedSub?.cancel();
    _newLocationSub?.cancel();
    _sqlitePersistTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Timer periódico que cada 2 minutos depura la mitad más vieja de
  /// geoLocationsList (agrupa por proximidad 2m) y la persiste en
  /// Location_tracking. La mitad más reciente permanece en memoria para
  /// brújula, compass, y la UI de GPS en Tiempo Real.
  void _startSqlitePersistTimer() {
    _sqlitePersistTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _persistToSqlite();
    });
    debugPrint('💾 [Global] Timer de persistencia SQLite iniciado (cada 2 min)');
  }

  Future<void> _persistToSqlite() async {
    final currentList = List<ReadGeoStruct>.from(FFAppState().geoLocationsList);
    if (currentList.length < 4) return; // mínimo para dividir

    try {
      final half = currentList.length ~/ 2;
      final toSave = currentList.sublist(0, half);      // mitad más vieja → SQLite
      final toKeep = currentList.sublist(half);          // mitad más reciente → memoria
      debugPrint('💾 [Global] Persistiendo $half de ${currentList.length} puntos a SQLite');

      // Obtener speed y batería reales
      final lastPoint = EnrichedGeoBuffer().getAll();
      final speed = lastPoint.isNotEmpty ? lastPoint.last.speed : 0.0;
      int batteryLevel = 100;
      try {
        batteryLevel = await Battery().batteryLevel;
      } catch (_) {}

      // Depurar geolocalizaciones (agrupar puntos < 2m en centroides)
      final depurados = depurarGeolocalizaciones(toSave, speed, batteryLevel);

      // Insertar en SQLite vía singleton global
      final globalDb = GlobalDbSingleton();
      await globalDb.executeOperation<void>((database) async {
        final batch = database.batch();
        for (final loc in depurados) {
          batch.rawInsert('''
            INSERT OR IGNORE INTO Location_tracking
            (Id_company, Imei, Latitude, Longitude, Altitude, HorizontalError,
             Speed, Battery, CreatedAt, SyncedAt, batch_id,
             date_start, date_finish, evaluated_radius, point_count,
             Id_user, Id_activity, Method)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            loc['Id_company'], loc['Imei'],
            loc['Latitude'], loc['Longitude'], loc['Altitude'],
            loc['HorizontalError'], loc['Speed'], loc['Battery'],
            loc['CreatedAt'], loc['SyncedAt'], loc['batch_id'],
            loc['date_start'], loc['date_finish'], loc['evaluated_radius'],
            loc['point_count'], loc['Id_user'], loc['Id_activity'],
            loc['Method'] ?? 'UNKNOWN',
          ]);
        }
        final results = await batch.commit(noResult: false);
        final inserted = results.whereType<int>().where((id) => id > 0).length;
        debugPrint(
            '💾 [Global] $inserted/${depurados.length} registros insertados en SQLite (de ${toSave.length} puntos)');
      });

      // Mantener solo los recientes en memoria
      FFAppState().geoLocationsList = toKeep;
    } catch (e) {
      debugPrint('❌ [Global] Error persistiendo a SQLite: $e');
    }
  }

  /// Listeners globales del servicio GPS. Al estar en _MyAppState (raíz de la app)
  /// permanecen activos en cualquier página — no dependen del ciclo de vida de
  /// home_page ni de ninguna otra pantalla.
  void _setupGlobalGpsListeners() {
    final service = FlutterBackgroundService();

    _gpsStabilizedSub = service.on('gpsStabilized').listen((event) {
      if (event != null && event['stabilized'] == true) {
        _everStabilized = true;
        FFAppState().update(() {
          FFAppState().isStabilized = true;
        });
        debugPrint('📡 [Global] GPS estabilizado');
      }
    });

    _newLocationSub = service.on('newLocation').listen((event) {
      if (event == null) return;
      try {
        final timestamp = DateTime.tryParse(event['createdAt'] ?? '') ?? DateTime.now();
        final lat = (event['latitude']  as num?)?.toDouble() ?? 0.0;
        final lon = (event['longitude'] as num?)?.toDouble() ?? 0.0;

        // Rechazar el segundo emit del broadcast stream de flutter_background_service.
        // Clave compuesta (timestamp + lat + lon) — resistente a clock drift del isolate.
        final dedupKey =
            '${timestamp.toIso8601String()}_${lat.toStringAsFixed(7)}_${lon.toStringAsFixed(7)}';
        if (_processedGpsKeys.contains(dedupKey)) return;
        _processedGpsKeys.add(dedupKey);
        if (_processedGpsKeys.length > 500) {
          _processedGpsKeys.remove(_processedGpsKeys.first);
        }

        final method = (event['method'] as String?) ?? 'UNKNOWN';

        // Poblar EnrichedGeoBuffer (13 campos con datos UKF/IMU + method)
        EnrichedGeoBuffer().add(EnrichedGeoPoint(
          latitude:         (event['latitude']         as num?)?.toDouble() ?? 0.0,
          longitude:        (event['longitude']        as num?)?.toDouble() ?? 0.0,
          altitude:         (event['altitude']         as num?)?.toDouble() ?? 0.0,
          errorHorizontal:  (event['horizontalError']  as num?)?.toDouble() ?? 0.0,
          timestamp:        timestamp,
          speed:            (event['speed']            as num?)?.toDouble() ?? 0.0,
          heading:          (event['heading']          as num?)?.toDouble() ?? 0.0,
          acceleration:     (event['acceleration']     as num?)?.toDouble() ?? 0.0,
          isStatic:          event['isStatic']         as bool? ?? false,
          isBrushChange:     event['isBrushChange']    as bool? ?? false,
          ukfPositionError: (event['ukfPositionError'] as num?)?.toDouble() ?? 0.0,
          vx:               (event['vx']               as num?)?.toDouble() ?? 0.0,
          vy:               (event['vy']               as num?)?.toDouble() ?? 0.0,
          method:           method,
        ));

        // Poblar geoLocationsList en AppState (5 campos para brújula/mapa/compass/historial)
        FFAppState().update(() {
          FFAppState().geoLocationsList.add(ReadGeoStruct(
            latitude:      (event['latitude']        as num?)?.toDouble(),
            longitude:     (event['longitude']       as num?)?.toDouble(),
            altitude:      (event['altitude']        as num?)?.toDouble(),
            errorHorizontal: (event['horizontalError'] as num?)?.toDouble(),
            dateHourRead:  timestamp,
            method:        method,
            speed:         (event['speed']           as num?)?.toDouble(),
            battery:       (event['battery']         as int?),
          ));
          // NOTA: ya no forzamos isStabilized=true aquí. El flag es ahora dinámico
          // (Fix 5): lo controlan el evento 'gpsStabilized' del servicio y el
          // detector de calidad más abajo. Ponerlo a true aquí rompería la
          // capacidad de marcarlo false cuando la calidad se degrada.
        });

        if (FFAppState().geoLocationsList.length % 20 == 0) {
          debugPrint('📍 [Global] ${FFAppState().geoLocationsList.length} puntos GPS acumulados');
        }

        // ── Detección de calidad GPS baja post-estabilización (Fix 5) ────────
        // Usa _everStabilized (fijo una vez verdadero) — independiente del flag
        // mutable isStabilized, para poder recuperarlo cuando mejora la señal.
        if (_everStabilized) {
          final err = (event['horizontalError'] as num?)?.toDouble() ?? 0.0;
          if (err > _qualityThreshold) {
            _consecutiveBadReadings++;
            _consecutiveGoodReadings = 0;
            if (_consecutiveBadReadings >= _badThreshold) {
              // Banner en tiempo real
              gpsLowQualityNotifier.value = err;
              // Flag dinámico → pantallas con !isStabilized bloquean acciones
              if (FFAppState().isStabilized) {
                FFAppState().update(() {
                  FFAppState().isStabilized = false;
                });
                debugPrint('⚠️ [Global] GPS degradado (err=${err.toStringAsFixed(1)}m) — isStabilized=false');
              }
            }
          } else {
            _consecutiveGoodReadings++;
            _consecutiveBadReadings = 0;
            if (_consecutiveGoodReadings >= _goodThreshold) {
              final wasLow = gpsLowQualityNotifier.value != null;
              if (wasLow) {
                gpsLowQualityNotifier.value = null;
              }
              if (!FFAppState().isStabilized) {
                FFAppState().update(() {
                  FFAppState().isStabilized = true;
                });
                debugPrint('✅ [Global] GPS recuperado — isStabilized=true');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ [Global] Error procesando newLocation: $e');
      }
    });

    debugPrint('✅ [Global] Listeners GPS configurados en _MyAppState');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App volvió al primer plano (desbloqueo de pantalla o vuelta desde otra app).
      // Si el usuario había iniciado el servicio GPS y Android lo mató mientras
      // la pantalla estaba bloqueada (batería agresiva en Samsung/Xiaomi/Huawei),
      // lo relanzamos automáticamente.
      debugPrint('▶️ App en primer plano');
      if (!Platform.isWindows && gpsServiceRequestedByUser) {
        _checkAndRestartGpsIfDead();
      }
    } else if (state == AppLifecycleState.paused) {
      // La pantalla se bloqueó o el usuario cambió de app.
      // NO detenemos el servicio — es un foreground service y debe sobrevivir.
      // stopWithTask="true" en AndroidManifest se encarga de detenerlo cuando
      // el usuario cierre la app desde el task manager (swipe).
      debugPrint('⏸️ App en segundo plano — servicio GPS continúa activo');
    } else if (state == AppLifecycleState.detached) {
      // La app fue cerrada completamente (proceso terminado).
      debugPrint('🛑 App cerrada (detached) — deteniendo servicio GPS...');
      stopBackgroundLocationService();
    }
  }

  /// Verifica si el servicio GPS está vivo. Si no lo está (Android lo mató
  /// por batería mientras la pantalla estaba bloqueada), lo reinicia.
  Future<void> _checkAndRestartGpsIfDead() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        debugPrint('🔄 Servicio GPS muerto tras bloqueo — relanzando...');
        await startBackgroundLocationService();
        debugPrint('✅ Servicio GPS relanzado automáticamente');
      } else {
        debugPrint('✅ Servicio GPS sigue vivo tras desbloqueo');
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando/relanzando servicio GPS: $e');
    }
  }

  void _onSplashComplete() {
    safeSetState(() {
      _showAnimatedSplash = false;
    });
    // Stop showing FlutterFlow splash image after animated splash completes
    Future.delayed(Duration(milliseconds: 100),
        () => safeSetState(() => _appStateNotifier.stopShowingSplashImage()));
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'ClickPalm APP',
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // Indicador GPS global — visible en CUALQUIER página de la app.
            // Muestra: "Estabilizando GPS", "GPS Estabilizado" y
            // "Calidad GPS baja (±Xm)" cuando error > 10m post-estabilización.
            const GPSQualityIndicator(),
            if (_showAnimatedSplash)
              AnimatedSplashScreenWidget(
                onAnimationComplete: _onSplashComplete,
              ),
          ],
        );
      },
    );
  }
}
