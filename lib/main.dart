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

import '/components/animated_splash_screen_widget.dart';
import '/custom_code/actions/background_location_service.dart';

StreamSubscription<Position>? locationSubscription;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await SQLiteManager.initialize();

  // Inicializar el servicio de geolocalización en segundo plano
  await initializeBackgroundLocationService();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();
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
  Timer? _pausedStopTimer;

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

  @override
  void initState() {
    super.initState();

    // Registrar observer para el ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);

    // Keep the FlutterFlow splash active until animated splash completes
    // The animated splash will call _onSplashComplete when done
  }

  @override
  void dispose() {
    _pausedStopTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App volvió al primer plano — cancelar cualquier timer de parada pendiente
      _pausedStopTimer?.cancel();
      _pausedStopTimer = null;
      debugPrint('▶️ App en primer plano');
    } else if (state == AppLifecycleState.paused) {
      // App pasó a segundo plano. En Android, si el usuario cierra la app desde
      // el task manager, "detached" a veces NO se dispara. Usamos un timer de
      // 8 minutos como fallback: si en ese tiempo no vuelve a "resumed", se
      // considera que el usuario cerró la app y se detiene el servicio.
      // (El propio stopWithTask="true" en AndroidManifest ya maneja la mayoría
      // de los casos al matar el proceso nativo, esto es un seguro extra en Dart.)
      _pausedStopTimer?.cancel();
      _pausedStopTimer = Timer(const Duration(minutes: 8), () {
        debugPrint('⏱️ App en pausa >8 min — deteniendo servicio GPS como fallback');
        stopBackgroundLocationService();
        _pausedStopTimer = null;
      });
      debugPrint('⏸️ App en segundo plano — timer de seguridad iniciado (8 min)');
    } else if (state == AppLifecycleState.detached) {
      // Detached sí se disparó — cancelar timer y detener inmediatamente
      _pausedStopTimer?.cancel();
      _pausedStopTimer = null;
      debugPrint('🛑 App cerrada (detached) - Deteniendo servicio de geolocalización...');
      stopBackgroundLocationService();
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
            child ?? SizedBox.shrink(),
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
