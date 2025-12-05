// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

// SISTEMA DE CACHÉ PARA RESULTADOS DE CALIDAD DE INTERNET
DateTime? _lastCheckTime;
Map<String, dynamic>? _cachedResult;
final Duration _cacheDuration = Duration(minutes: 2);

class ServerConfig {
  final String url;
  final String name;
  final String city;
  final double lat;
  final double lon;
  final String type; // 'speed', 'ping', 'cdn', 'api'

  ServerConfig({
    required this.url,
    required this.name,
    required this.city,
    required this.lat,
    required this.lon,
    required this.type,
  });
}

// FUNCIÓN OPTIMIZADA CON SELECCIÓN INTELIGENTE DE SERVIDORES Y SCORING NUEVO
Future<dynamic> checkInternetQuality() async {
  // VERIFICAR CACHÉ AL INICIO
  if (_lastCheckTime != null && _cachedResult != null) {
    final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);

    if (timeSinceLastCheck < _cacheDuration) {
      final secondsSinceCheck = timeSinceLastCheck.inSeconds;
      print('📦 ✅ Usando resultado en caché (${secondsSinceCheck}s desde último chequeo, válido por ${_cacheDuration.inMinutes} minutos)');
      print('⏱️ Próximo chequeo en: ${(_cacheDuration.inSeconds - secondsSinceCheck)}s');
      return _cachedResult;
    } else {
      print('⏰ Caché expirado (${timeSinceLastCheck.inMinutes} minutos y ${timeSinceLastCheck.inSeconds % 60} segundos), realizando nuevo chequeo...');
    }
  } else {
    print('🔍 Primera ejecución o caché vacío, realizando chequeo completo...');
  }

  Dio? dio;
  FlutterInternetSpeedTest? speedTest; // NO SE USARÁ - PLUGIN PROBLEMÁTICO
  double? downloadSpeed; // Declarar la variable aquí

  try {
    print(
        '🚀 Iniciando diagnóstico avanzado con selección inteligente de servidores...');

    // 1. DETECTAR UBICACIÓN ACTUAL
    Position? currentPosition;
    try {
      print('📍 Detectando ubicación actual...');
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(Duration(seconds: 10));
      print(
          '✅ Ubicación detectada: ${currentPosition.latitude}, ${currentPosition.longitude}');
    } catch (e) {
      print('⚠️ No se pudo obtener ubicación GPS: $e');
      print('📍 Usando ubicación por defecto (Manizales)');
      currentPosition = Position(
        latitude: 5.0703,
        longitude: -75.5138,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    // 2. VERIFICAR TIPO DE CONECTIVIDAD
    print('📱 Verificando tipo de conexión...');
    final connectivityResults = await Connectivity().checkConnectivity();

    String connectionType = 'Desconocido';
    bool isHighSpeedConnection = false;

    for (var result in connectivityResults) {
      switch (result) {
        case ConnectivityResult.wifi:
          connectionType = 'WiFi';
          isHighSpeedConnection = true;
          break;
        case ConnectivityResult.ethernet:
          connectionType = 'Ethernet';
          isHighSpeedConnection = true;
          break;
        case ConnectivityResult.mobile:
          connectionType = 'Datos móviles';
          isHighSpeedConnection = false;
          break;
        case ConnectivityResult.none:
          connectionType = 'Sin conexión';
          break;
        default:
          connectionType = 'Otra conexión';
      }
    }

    print('✅ Tipo de conexión detectado: $connectionType');

    if (connectionType == 'Sin conexión') {
      final result = {
        'message': 'Sin conectividad detectada',
        'isGoodConnection': false,
      };

      // CACHEAR RESULTADO DE SIN CONEXIÓN (para evitar chequeos repetitivos)
      _cachedResult = result;
      _lastCheckTime = DateTime.now();
      print('💾 Sin conexión - resultado cacheado');

      return result;
    }

    // 3. OBTENER SERVIDORES ÓPTIMOS SEGÚN UBICACIÓN
    List<ServerConfig> optimalServers = _getOptimalServers(currentPosition);
    print('🎯 Servidores seleccionados para ubicación actual:');
    for (var server in optimalServers.take(3)) {
      print('   📡 ${server.name} (${server.city}) - ${server.type}');
    }

    // 4. VERIFICAR CONECTIVIDAD CON INTERNET_CONNECTION_CHECKER_PLUS
    print('🌐 Verificando acceso real a internet...');

    final internetChecker = InternetConnection.createInstance(
      customCheckOptions: optimalServers
          .where((s) => s.type == 'ping')
          .take(4)
          .map((s) => InternetCheckOption(uri: Uri.parse(s.url)))
          .toList(),
      checkInterval: Duration(seconds: 1),
    );

    bool hasInternet = false;
    try {
      hasInternet = await internetChecker.hasInternetAccess;
      print('✅ Acceso a internet confirmado: $hasInternet');
    } catch (e) {
      print('❌ Error verificando internet: $e');
      hasInternet = false;
    }

    if (!hasInternet) {
      final result = {
        'message': 'Sin acceso a internet verificado',
        'isGoodConnection': false,
      };

      // CACHEAR RESULTADO DE SIN INTERNET (para evitar chequeos repetitivos)
      _cachedResult = result;
      _lastCheckTime = DateTime.now();
      print('💾 Sin internet - resultado cacheado');

      return result;
    }

    // 5. CONFIGURAR DIO OPTIMIZADO
    print('⚙️ Configurando cliente HTTP optimizado...');

    dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 8),
      sendTimeout: Duration(seconds: 5),
      followRedirects: true,
      validateStatus: (status) => status! < 500,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Mobile; rv:91.0) Gecko/91.0 Firefox/91.0',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    ));

    // 6. PING TEST INTELIGENTE CON PRIORIDAD PARA TU API
    print('📡 Ejecutando ping test inteligente con tu API prioritaria...');

    List<ServerConfig> pingServers = optimalServers
        .where((s) => s.type == 'ping' || s.type == 'cdn' || s.type == 'api')
        .take(8)
        .toList();

    Map<String, int> serverPings = {};
    int? apiPing; // Ping específico a tu API
    String? bestLocalServer;
    int? bestLocalPing;

    // PRIMERO: Medir ping a TU API (más importante)
    ServerConfig? apiServer = optimalServers.firstWhere(
      (s) => s.type == 'api',
      orElse: () =>
          ServerConfig(url: '', name: '', city: '', lat: 0, lon: 0, type: ''),
    );

    if (apiServer.name.isNotEmpty) {
      try {
        print('🎯 Midiendo ping prioritario a tu API (${apiServer.name})...');

        List<int> apiPings = [];
        for (int attempt = 0; attempt < 3; attempt++) {
          final stopwatch = Stopwatch()..start();
          final response = await dio.get(apiServer.url);
          stopwatch.stop();

          if (response.statusCode! >= 200 && response.statusCode! < 300) {
            apiPings.add(stopwatch.elapsedMilliseconds);
            print(
                '✅ API ping intento ${attempt + 1}: ${stopwatch.elapsedMilliseconds}ms');
          }
        }

        if (apiPings.isNotEmpty) {
          apiPing =
              (apiPings.reduce((a, b) => a + b) / apiPings.length).round();
          serverPings[apiServer.name] = apiPing;
          print('🏆 Ping promedio a tu API: ${apiPing}ms');
        }
      } catch (e) {
        print('❌ Error midiendo API: $e');
      }
    }

    // SEGUNDO: Medir servidores locales colombianos
    for (var server in pingServers) {
      if (server.type == 'api') continue; // Ya medido arriba

      List<int> pings = [];
      try {
        print('📡 Probando ping a ${server.name}...');

        for (int attempt = 0; attempt < 3; attempt++) {
          final stopwatch = Stopwatch()..start();
          final response = await dio.get(server.url);
          stopwatch.stop();

          if (response.statusCode! >= 200 && response.statusCode! < 300) {
            pings.add(stopwatch.elapsedMilliseconds);
          }
        }

        if (pings.isNotEmpty) {
          int avgPing = (pings.reduce((a, b) => a + b) / pings.length).round();
          serverPings[server.name] = avgPing;
          print('✅ ${server.name}: ${avgPing}ms promedio');

          // Identificar mejor servidor local (no API)
          if (server.type != 'api' &&
              (bestLocalPing == null || avgPing < bestLocalPing)) {
            bestLocalPing = avgPing;
            bestLocalServer = server.name;
          }
        }
      } catch (e) {
        print('❌ Error ping ${server.name}: $e');
        continue;
      }
    }

    // Determinar mejor ping general y mostrar resultados
    int? bestPing;
    String? bestServerName;
    if (serverPings.isNotEmpty) {
      var bestEntry =
          serverPings.entries.reduce((a, b) => a.value < b.value ? a : b);
      bestPing = bestEntry.value;
      bestServerName = bestEntry.key;
      print('🏆 Mejor ping general: $bestServerName con ${bestPing}ms');

      if (apiPing != null) {
        print(
            '📊 Comparación: API=${apiPing}ms, Mejor local=${bestLocalPing ?? 'N/A'}ms');
      }
    }

    // 7. SPEED TEST SOLO CON CDNs PÚBLICOS (SIN PLUGIN PROBLEMÁTICO)
    print('⚡ Midiendo velocidad con CDNs públicos verificados...');
    downloadSpeed = await _fallbackSpeedTestPublic(dio, optimalServers);

    print(
        '🏆 Velocidad final: ${downloadSpeed?.toStringAsFixed(2) ?? 'No medida'} Mbps');

    // 8. CÁLCULO DE CALIDAD PONDERADO (API + LOCAL + VELOCIDAD) - SISTEMA NUEVO
    print('🧮 Calculando calidad con ponderación inteligente...');

    int score = 0;

    // Bonus por tipo de conexión (10% del score)
    if (connectionType == 'Ethernet') {
      score += 10;
      print('📊 Bonus Ethernet: +10 puntos');
    } else if (connectionType == 'WiFi') {
      score += 8;
      print('📊 Bonus WiFi: +8 puntos');
    } else if (connectionType == 'Datos móviles') {
      score += 5;
      print('📊 Bonus móvil: +5 puntos');
    }

    // PING SCORING PONDERADO (30% total): 60% API + 40% Local
    int totalPingScore = 0;

    // Evaluar ping a tu API (18% del score total - 60% del ping scoring)
    if (apiPing != null) {
      int apiPingScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas para conectividad internacional (Colombia -> Oregon)
        if (apiPing < 180)
          apiPingScore = 18; // Excelente (fibra directa)
        else if (apiPing < 220)
          apiPingScore = 16; // Muy bueno (fibra estándar)
        else if (apiPing < 280)
          apiPingScore = 14; // Bueno (conexión premium)
        else if (apiPing < 350)
          apiPingScore = 12; // Regular (ADSL+)
        else if (apiPing < 450)
          apiPingScore = 8; // Deficiente (ADSL)
        else if (apiPing < 600)
          apiPingScore = 4; // Malo
        else
          apiPingScore = 2; // Muy malo
      } else {
        // Expectativas móviles a Oregon
        if (apiPing < 250)
          apiPingScore = 18;
        else if (apiPing < 300)
          apiPingScore = 16;
        else if (apiPing < 400)
          apiPingScore = 14;
        else if (apiPing < 500)
          apiPingScore = 10;
        else if (apiPing < 700)
          apiPingScore = 6;
        else
          apiPingScore = 3;
      }
      totalPingScore += apiPingScore;
      print('📊 Score ping API: ${apiPingScore}/18 (${apiPing}ms a Oregon)');
    } else {
      totalPingScore += 9; // Score neutro para API
      print('📊 Score neutro ping API: 9/18');
    }

    // Evaluar ping local (12% del score total - 40% del ping scoring)
    if (bestLocalPing != null) {
      int localPingScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas MUY REALISTAS para servidores locales colombianos
        if (bestLocalPing < 80)
          localPingScore = 12; // Excelente (fibra local)
        else if (bestLocalPing < 120)
          localPingScore = 11; // Muy bueno (conexión premium)
        else if (bestLocalPing < 160)
          localPingScore = 10; // Bueno (conexión estándar)
        else if (bestLocalPing < 220)
          localPingScore = 9; // Regular superior
        else if (bestLocalPing < 300)
          localPingScore = 7; // Regular
        else if (bestLocalPing < 450)
          localPingScore = 5; // Deficiente
        else
          localPingScore = 2; // Malo
      } else {
        // Móvil local con expectativas ajustadas
        if (bestLocalPing < 100)
          localPingScore = 12;
        else if (bestLocalPing < 150)
          localPingScore = 11;
        else if (bestLocalPing < 200)
          localPingScore = 10;
        else if (bestLocalPing < 280)
          localPingScore = 8;
        else if (bestLocalPing < 400)
          localPingScore = 6;
        else
          localPingScore = 3;
      }
      totalPingScore += localPingScore;
      print(
          '📊 Score ping local: ${localPingScore}/12 (${bestLocalPing}ms a $bestLocalServer - EXCELENTE)');
    } else {
      totalPingScore += 6; // Score neutro para local
      print('📊 Score neutro ping local: 6/12');
    }

    score += totalPingScore;

    // Evaluar velocidad (60% del score) - ESCALA MUY REALISTA PARA COLOMBIA CON CDNs
    if (downloadSpeed != null) {
      int speedScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas MUY REALISTAS para WiFi/Ethernet medido con CDNs públicos
        if (downloadSpeed >= 10)
          speedScore = 60; // Excelente (fibra óptica premium)
        else if (downloadSpeed >= 7)
          speedScore = 55; // Muy bueno (fibra óptica estándar)
        else if (downloadSpeed >= 5)
          speedScore = 50; // Bueno (fibra/cable detectado)
        else if (downloadSpeed >= 3)
          speedScore = 40; // Regular superior (ADSL+)
        else if (downloadSpeed >= 2)
          speedScore = 30; // Regular (ADSL estándar)
        else if (downloadSpeed >= 1)
          speedScore = 20; // Deficiente (ADSL básico)
        else if (downloadSpeed >= 0.5)
          speedScore = 10; // Muy deficiente
        else
          speedScore = 5; // Extremadamente lenta
      } else {
        // Expectativas MUY REALISTAS para datos móviles con CDNs
        if (downloadSpeed >= 8)
          speedScore = 60; // Excelente (5G premium)
        else if (downloadSpeed >= 5)
          speedScore = 55; // Muy bueno (5G/4G+)
        else if (downloadSpeed >= 3)
          speedScore = 50; // Bueno (4G estándar)
        else if (downloadSpeed >= 2)
          speedScore = 40; // Regular (4G básico)
        else if (downloadSpeed >= 1)
          speedScore = 30; // Regular (3G+)
        else if (downloadSpeed >= 0.5)
          speedScore = 20; // Deficiente (3G)
        else
          speedScore = 10; // 2G/Edge
      }

      score += speedScore;
      print(
          '📊 Score por velocidad: ${speedScore}/60 (${downloadSpeed.toStringAsFixed(2)} Mbps vía CDNs - indica fibra)');
    } else {
      score += 25;
      print('📊 Score neutro por velocidad: 25/60');
    }

    print('📊 Score total: ${score}/100');

    // 9. DETERMINAR CALIDAD CON UMBRALES MUY REALISTAS PARA COLOMBIA
    String quality;
    if (score >= 70)
      quality = 'excellent'; // 70+ puntos (conexión premium)
    else if (score >= 55)
      quality = 'good'; // 55-69 puntos (buena conexión)
    else if (score >= 40)
      quality = 'fair'; // 40-54 puntos (conexión regular)
    else if (score >= 25)
      quality = 'poor'; // 25-39 puntos (conexión deficiente)
    else
      quality = 'none'; // <25 puntos (muy mala conexión)

    // 10. MENSAJE CONTEXTUAL FINAL
    String baseMessage;
    switch (quality) {
      case 'excellent':
        baseMessage = isHighSpeedConnection
            ? 'Conexión excelente'
            : 'Conexión móvil excelente';
        break;
      case 'good':
        baseMessage =
            isHighSpeedConnection ? 'Conexión buena' : 'Conexión móvil buena';
        break;
      case 'fair':
        baseMessage = isHighSpeedConnection
            ? 'Conexión regular'
            : 'Conexión móvil regular';
        break;
      case 'poor':
        baseMessage = isHighSpeedConnection
            ? 'Conexión deficiente'
            : 'Conexión móvil deficiente';
        break;
      default:
        baseMessage = 'Conexión muy limitada';
    }

    String finalMessage = '$baseMessage ($connectionType)';

    // Determinar si es una buena conexión
    bool isGoodConnection =
        (quality == 'excellent' || quality == 'good' || quality == 'fair');

    print('🎉 Resultado final: $finalMessage');
    print('📊 Es buena conexión: $isGoodConnection');
    if (apiPing != null) {
      print('🌍 Ping a tu API (Oregon): ${apiPing}ms');
    }
    if (bestLocalServer != null) {
      print('🇨🇴 Mejor servidor local: $bestLocalServer (${bestLocalPing}ms)');
    }

    // PREPARAR RESULTADO
    final result = {
      'message': finalMessage,
      'isGoodConnection': isGoodConnection,
    };

    // ACTUALIZAR CACHÉ
    _cachedResult = result;
    _lastCheckTime = DateTime.now();
    print('💾 Resultado guardado en caché (válido por ${_cacheDuration.inMinutes} minutos)');

    return result;
  } catch (e) {
    print('💥 Error general: $e');

    final result = {
      'message': 'Error al verificar la conexión',
      'isGoodConnection': false,
    };

    // CACHEAR RESULTADO DE ERROR (para evitar chequeos repetitivos cuando hay problemas)
    _cachedResult = result;
    _lastCheckTime = DateTime.now();
    print('💾 Error - resultado cacheado (evita reintentos inmediatos)');

    return result;
  } finally {
    // Limpiar recursos
    try {
      dio?.close();
      print('🔒 Recursos liberados correctamente');
    } catch (e) {
      print('⚠️ Error liberando recursos: $e');
    }
  }
}

// FUNCIÓN PARA SELECCIONAR SERVIDORES ÓPTIMOS SEGÚN UBICACIÓN
List<ServerConfig> _getOptimalServers(Position position) {
  // Base de datos de servidores públicos colombianos verificados
  List<ServerConfig> allServers = [
    // TU API AWS OREGON - SERVIDOR PRIORITARIO PARA TU APLICACIÓN
    ServerConfig(
      url: 'https://api.clickpalm.com/',
      name: 'ClickPalm API Oregon',
      city: 'Oregon AWS',
      lat: 45.5152,
      lon: -122.6784,
      type: 'api', // Nuevo tipo para tu API
    ),

    // FAST.COM (NETFLIX) - SERVICIO PÚBLICO DE SPEED TEST
    ServerConfig(
      url: 'https://fast.com',
      name: 'Fast.com Netflix',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'speed',
    ),

    // CDNs PÚBLICOS CON EDGE EN COLOMBIA
    ServerConfig(
      url:
          'https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js',
      name: 'Google CDN Colombia',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'speed',
    ),
    ServerConfig(
      url: 'https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.js',
      name: 'jsDelivr CDN',
      city: 'Medellín',
      lat: 6.2442,
      lon: -75.5812,
      type: 'speed',
    ),
    ServerConfig(
      url: 'https://unpkg.com/react@18/umd/react.production.min.js',
      name: 'unpkg CDN',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'speed',
    ),

    // UNIVERSIDADES PÚBLICAS COLOMBIANAS (RENATA)
    ServerConfig(
      url: 'https://www.unal.edu.co',
      name: 'Universidad Nacional',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.udea.edu.co',
      name: 'Universidad de Antioquia',
      city: 'Medellín',
      lat: 6.2442,
      lon: -75.5812,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.univalle.edu.co',
      name: 'Universidad del Valle',
      city: 'Cali',
      lat: 3.4516,
      lon: -76.5320,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.uis.edu.co',
      name: 'Universidad Industrial Santander',
      city: 'Bucaramanga',
      lat: 7.1193,
      lon: -73.1227,
      type: 'ping',
    ),

    // ENTIDADES PÚBLICAS COLOMBIANAS
    ServerConfig(
      url: 'https://www.gov.co',
      name: 'Gobierno Nacional',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.mintic.gov.co',
      name: 'MinTIC Colombia',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://bogota.gov.co',
      name: 'Alcaldía de Bogotá',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.medellin.gov.co',
      name: 'Alcaldía de Medellín',
      city: 'Medellín',
      lat: 6.2442,
      lon: -75.5812,
      type: 'ping',
    ),

    // MEDIOS DE COMUNICACIÓN COLOMBIANOS
    ServerConfig(
      url: 'https://www.eltiempo.com',
      name: 'El Tiempo',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.caracol.com.co',
      name: 'Caracol Radio',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),

    // CDNs GLOBALES COMO FALLBACK
    ServerConfig(
      url: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js',
      name: 'Cloudflare CDN',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'cdn',
    ),
    ServerConfig(
      url:
          'https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js',
      name: 'jsDelivr Bootstrap',
      city: 'Global',
      lat: 4.0,
      lon: -74.0,
      type: 'cdn',
    ),

    // BANCOS COLOMBIANOS (PING TEST)
    ServerConfig(
      url: 'https://www.bancolombia.com',
      name: 'Bancolombia',
      city: 'Medellín',
      lat: 6.2442,
      lon: -75.5812,
      type: 'ping',
    ),
    ServerConfig(
      url: 'https://www.bancodebogota.com',
      name: 'Banco de Bogotá',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),
  ];

  // Calcular distancia y ordenar por proximidad
  allServers.sort((a, b) {
    double distanceA = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      a.lat,
      a.lon,
    );
    double distanceB = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      b.lat,
      b.lon,
    );
    return distanceA.compareTo(distanceB);
  });

  print('📍 Servidores ordenados por distancia desde ubicación actual:');
  for (int i = 0; i < allServers.length && i < 5; i++) {
    double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          allServers[i].lat,
          allServers[i].lon,
        ) /
        1000; // Convertir a kilómetros
    print(
        '   ${i + 1}. ${allServers[i].name} - ${distance.toStringAsFixed(0)}km');
  }

  return allServers;
}

// SPEED TEST DE RESPALDO CON CDNs PÚBLICOS VERIFICADOS
Future<double?> _fallbackSpeedTestPublic(
    Dio dio, List<ServerConfig> servers) async {
  // Seleccionar CDNs públicos y servidores de speed test como respaldo
  List<ServerConfig> fallbackServers = servers
      .where((s) => s.type == 'cdn' || s.type == 'speed')
      .take(5)
      .toList();

  // Agregar servidores adicionales específicos para fallback
  fallbackServers.addAll([
    ServerConfig(
      url: 'https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js',
      name: 'Google jQuery CDN',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'cdn',
    ),
    ServerConfig(
      url:
          'https://cdnjs.cloudflare.com/ajax/libs/lodash.js/4.17.21/lodash.min.js',
      name: 'Cloudflare Lodash',
      city: 'Bogotá',
      lat: 4.7110,
      lon: -74.0721,
      type: 'cdn',
    ),
  ]);

  List<double> speeds = [];

  for (var server in fallbackServers) {
    try {
      print('📡 Probando CDN de respaldo: ${server.name}...');

      // Hacer 2 mediciones por servidor para mayor precisión
      for (int attempt = 0; attempt < 2; attempt++) {
        final stopwatch = Stopwatch()..start();
        final response = await dio.get(
          server.url,
          options: Options(
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ),
        );
        stopwatch.stop();

        if (response.statusCode == 200 && response.data != null) {
          int bytes = 0;
          if (response.data is String) {
            bytes = (response.data as String).length;
          } else {
            bytes = response.data.toString().length;
          }

          if (bytes > 10000) {
            // Al menos 10KB para medición válida
            final seconds = stopwatch.elapsedMilliseconds / 1000.0;
            final mbps = (bytes * 8) / (1024 * 1024 * seconds);
            double speed = double.parse(mbps.toStringAsFixed(2));

            speeds.add(speed);
            print(
                '⚡ CDN ${server.name} (intento ${attempt + 1}): ${speed} Mbps');

            // Si obtenemos una velocidad buena, salir del loop de intentos
            if (speed > 5.0) break;
          }
        }
      }

      // Si ya tenemos suficientes mediciones buenas, parar
      if (speeds.length >= 4) break;
    } catch (e) {
      print('❌ Error CDN ${server.name}: $e');
      continue;
    }
  }

  if (speeds.isNotEmpty) {
    // Ordenar velocidades y tomar el promedio de las mejores
    speeds.sort((a, b) => b.compareTo(a));

    double finalSpeed;
    if (speeds.length >= 3) {
      // Promedio de las 3 mejores velocidades
      finalSpeed = (speeds[0] + speeds[1] + speeds[2]) / 3;
    } else if (speeds.length >= 2) {
      // Promedio de las 2 mejores
      finalSpeed = (speeds[0] + speeds[1]) / 2;
    } else {
      // Una sola medición
      finalSpeed = speeds[0];
    }

    print(
        '🏆 Velocidad de respaldo promedio: ${finalSpeed.toStringAsFixed(2)} Mbps');
    return double.parse(finalSpeed.toStringAsFixed(2));
  }

  return null;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
