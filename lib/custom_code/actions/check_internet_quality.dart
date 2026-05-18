import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

// SISTEMA DE CACHÉ PARA RESULTADOS DE CALIDAD DE INTERNET
DateTime? _lastCheckTime;
Map<String, dynamic>? _cachedResult;
const Duration _cacheDuration = Duration(minutes: 2);
const Duration _negativeCacheDuration = Duration(seconds: 15);

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
Future<dynamic> checkInternetQuality({bool forceRefresh = false}) async {
  // VERIFICAR CACHÉ AL INICIO
  if (!forceRefresh && _lastCheckTime != null && _cachedResult != null) {
    final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
    final bool isNegativeResult = _cachedResult!['hasInternet'] == false;
    final effectiveCacheDuration = isNegativeResult ? _negativeCacheDuration : _cacheDuration;

    if (timeSinceLastCheck < effectiveCacheDuration) {
      final secondsSinceCheck = timeSinceLastCheck.inSeconds;
      debugPrint('📦 ✅ Usando resultado en caché (${secondsSinceCheck}s desde último chequeo, válido por ${effectiveCacheDuration.inSeconds}s)');
      debugPrint('⏱️ Próximo chequeo en: ${(effectiveCacheDuration.inSeconds - secondsSinceCheck)}s');
      return _cachedResult;
    } else {
      debugPrint('⏰ Caché expirado (${timeSinceLastCheck.inSeconds}s), realizando nuevo chequeo...');
    }
  } else if (forceRefresh) {
    debugPrint('🔄 Force refresh solicitado, omitiendo caché...');
  } else {
    debugPrint('🔍 Primera ejecución o caché vacío, realizando chequeo completo...');
  }

  Dio? dio;
  double? downloadSpeed;

  try {
    debugPrint(
        '🚀 Iniciando diagnóstico avanzado con selección inteligente de servidores...');

    // 1. DETECTAR UBICACIÓN ACTUAL
    Position? currentPosition;
    try {
      debugPrint('📍 Detectando ubicación actual...');
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 10));
      debugPrint(
          '✅ Ubicación detectada: ${currentPosition.latitude}, ${currentPosition.longitude}');
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener ubicación GPS: $e');
      debugPrint('📍 Usando ubicación por defecto (Manizales)');
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
    debugPrint('📱 Verificando tipo de conexión...');
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

    debugPrint('✅ Tipo de conexión detectado: $connectionType');

    if (connectionType == 'Sin conexión') {
      final result = {
        'message': 'Sin conectividad detectada',
        'isGoodConnection': false,
        'hasInternet': false,
      };

      // CACHEAR RESULTADO DE SIN CONEXIÓN (para evitar chequeos repetitivos)
      _cachedResult = result;
      _lastCheckTime = DateTime.now();
      debugPrint('💾 Sin conexión - resultado cacheado');

      return result;
    }

    // 3. OBTENER SERVIDORES ÓPTIMOS SEGÚN UBICACIÓN
    List<ServerConfig> optimalServers = _getOptimalServers(currentPosition);
    debugPrint('🎯 Servidores seleccionados para ubicación actual:');
    for (var server in optimalServers.take(3)) {
      debugPrint('   📡 ${server.name} (${server.city}) - ${server.type}');
    }

    // 4. VERIFICAR CONECTIVIDAD CON HTTP DIRECTO (más confiable que internet_connection_checker_plus)
    debugPrint('🌐 Verificando acceso real a internet...');

    bool hasInternet = false;
    final checkDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    ));

    try {
      // Intentar múltiples endpoints en paralelo - basta que uno responda
      final results = await Future.wait<bool>([
        _quickHttpCheck(checkDio, 'https://www.google.com/generate_204'),
        _quickHttpCheck(checkDio, 'https://connectivitycheck.gstatic.com/generate_204'),
        _quickHttpCheck(checkDio, 'https://1.1.1.1/cdn-cgi/trace'),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => [false, false, false]);

      hasInternet = results.any((r) => r);
      debugPrint('✅ Acceso a internet confirmado: $hasInternet (${results.where((r) => r).length}/3 endpoints OK)');

      checkDio.close();
    } catch (e) {
      debugPrint('❌ Error verificando internet: $e');
      hasInternet = false;
      checkDio.close();
    }

    if (!hasInternet) {
      final result = {
        'message': 'Sin acceso a internet verificado',
        'isGoodConnection': false,
        'hasInternet': false,
      };

      // CACHEAR RESULTADO DE SIN INTERNET (para evitar chequeos repetitivos)
      _cachedResult = result;
      _lastCheckTime = DateTime.now();
      debugPrint('💾 Sin internet - resultado cacheado');

      return result;
    }

    // 5. CONFIGURAR DIO OPTIMIZADO
    debugPrint('⚙️ Configurando cliente HTTP optimizado...');

    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 5),
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

    // 6. PING TEST SIMPLIFICADO - SOLO 3 SERVIDORES
    debugPrint('📡 Ejecutando ping test (API + 2 locales)...');

    Map<String, int> serverPings = {};
    int? apiPing;
    String? bestLocalServer;
    int? bestLocalPing;

    // Medir ping a cada servidor (solo 2 intentos por servidor)
    for (var server in optimalServers) {
      List<int> pings = [];
      try {
        debugPrint('   🔍 ${server.name}...');

        for (int attempt = 0; attempt < 2; attempt++) {
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
          debugPrint('   ✅ ${server.name}: ${avgPing}ms');

          if (server.type == 'api') {
            apiPing = avgPing;
          } else if (bestLocalPing == null || avgPing < bestLocalPing) {
            bestLocalPing = avgPing;
            bestLocalServer = server.name;
          }
        }
      } catch (e) {
        debugPrint('   ❌ ${server.name}: Error');
        continue;
      }
    }

    // Mostrar resumen
    if (serverPings.isNotEmpty) {
      debugPrint('📊 Resumen: API=${apiPing ?? 'N/A'}ms, Local=${bestLocalPing ?? 'N/A'}ms');
    }

    // 7. SPEED TEST SOLO CON CDNs PÚBLICOS (SIN PLUGIN PROBLEMÁTICO)
    debugPrint('⚡ Midiendo velocidad con CDNs públicos verificados...');
    downloadSpeed = await _fallbackSpeedTestPublic(dio, optimalServers);

    debugPrint(
        '🏆 Velocidad final: ${downloadSpeed?.toStringAsFixed(2) ?? 'No medida'} Mbps');

    // 8. CÁLCULO DE CALIDAD PONDERADO (API + LOCAL + VELOCIDAD) - SISTEMA NUEVO
    debugPrint('🧮 Calculando calidad con ponderación inteligente...');

    int score = 0;

    // Bonus por tipo de conexión (10% del score)
    if (connectionType == 'Ethernet') {
      score += 10;
      debugPrint('📊 Bonus Ethernet: +10 puntos');
    } else if (connectionType == 'WiFi') {
      score += 8;
      debugPrint('📊 Bonus WiFi: +8 puntos');
    } else if (connectionType == 'Datos móviles') {
      score += 5;
      debugPrint('📊 Bonus móvil: +5 puntos');
    }

    // PING SCORING PONDERADO (30% total): 60% API + 40% Local
    int totalPingScore = 0;

    // Evaluar ping a tu API (18% del score total - 60% del ping scoring)
    if (apiPing != null) {
      int apiPingScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas para conectividad internacional (Colombia -> Oregon)
        if (apiPing < 180) {
          apiPingScore = 18; // Excelente (fibra directa)
        } else if (apiPing < 220) {
          apiPingScore = 16; // Muy bueno (fibra estándar)
        } else if (apiPing < 280) {
          apiPingScore = 14; // Bueno (conexión premium)
        } else if (apiPing < 350) {
          apiPingScore = 12; // Regular (ADSL+)
        } else if (apiPing < 450) {
          apiPingScore = 8; // Deficiente (ADSL)
        } else if (apiPing < 600) {
          apiPingScore = 4; // Malo
        } else {
          apiPingScore = 2; // Muy malo
        }
      } else {
        // Expectativas móviles a Oregon
        if (apiPing < 250) {
          apiPingScore = 18;
        } else if (apiPing < 300) {
          apiPingScore = 16;
        } else if (apiPing < 400) {
          apiPingScore = 14;
        } else if (apiPing < 500) {
          apiPingScore = 10;
        } else if (apiPing < 700) {
          apiPingScore = 6;
        } else {
          apiPingScore = 3;
        }
      }
      totalPingScore += apiPingScore;
      debugPrint('📊 Score ping API: $apiPingScore/18 (${apiPing}ms a Oregon)');
    } else {
      totalPingScore += 9; // Score neutro para API
      debugPrint('📊 Score neutro ping API: 9/18');
    }

    // Evaluar ping local (12% del score total - 40% del ping scoring)
    if (bestLocalPing != null) {
      int localPingScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas MUY REALISTAS para servidores locales colombianos
        if (bestLocalPing < 80) {
          localPingScore = 12; // Excelente (fibra local)
        } else if (bestLocalPing < 120) {
          localPingScore = 11; // Muy bueno (conexión premium)
        } else if (bestLocalPing < 160) {
          localPingScore = 10; // Bueno (conexión estándar)
        } else if (bestLocalPing < 220) {
          localPingScore = 9; // Regular superior
        } else if (bestLocalPing < 300) {
          localPingScore = 7; // Regular
        } else if (bestLocalPing < 450) {
          localPingScore = 5; // Deficiente
        } else {
          localPingScore = 2; // Malo
        }
      } else {
        // Móvil local con expectativas ajustadas
        if (bestLocalPing < 100) {
          localPingScore = 12;
        } else if (bestLocalPing < 150) {
          localPingScore = 11;
        } else if (bestLocalPing < 200) {
          localPingScore = 10;
        } else if (bestLocalPing < 280) {
          localPingScore = 8;
        } else if (bestLocalPing < 400) {
          localPingScore = 6;
        } else {
          localPingScore = 3;
        }
      }
      totalPingScore += localPingScore;
      debugPrint(
          '📊 Score ping local: $localPingScore/12 (${bestLocalPing}ms a $bestLocalServer - EXCELENTE)');
    } else {
      totalPingScore += 6; // Score neutro para local
      debugPrint('📊 Score neutro ping local: 6/12');
    }

    score += totalPingScore;

    // Evaluar velocidad (60% del score) - ESCALA MUY REALISTA PARA COLOMBIA CON CDNs
    if (downloadSpeed != null) {
      int speedScore = 0;
      if (isHighSpeedConnection) {
        // Expectativas MUY REALISTAS para WiFi/Ethernet medido con CDNs públicos
        if (downloadSpeed >= 10) {
          speedScore = 60; // Excelente (fibra óptica premium)
        } else if (downloadSpeed >= 7) {
          speedScore = 55; // Muy bueno (fibra óptica estándar)
        } else if (downloadSpeed >= 5) {
          speedScore = 50; // Bueno (fibra/cable detectado)
        } else if (downloadSpeed >= 3) {
          speedScore = 40; // Regular superior (ADSL+)
        } else if (downloadSpeed >= 2) {
          speedScore = 30; // Regular (ADSL estándar)
        } else if (downloadSpeed >= 1) {
          speedScore = 20; // Deficiente (ADSL básico)
        } else if (downloadSpeed >= 0.5) {
          speedScore = 10; // Muy deficiente
        } else {
          speedScore = 5; // Extremadamente lenta
        }
      } else {
        // Expectativas MUY REALISTAS para datos móviles con CDNs
        if (downloadSpeed >= 8) {
          speedScore = 60; // Excelente (5G premium)
        } else if (downloadSpeed >= 5) {
          speedScore = 55; // Muy bueno (5G/4G+)
        } else if (downloadSpeed >= 3) {
          speedScore = 50; // Bueno (4G estándar)
        } else if (downloadSpeed >= 2) {
          speedScore = 40; // Regular (4G básico)
        } else if (downloadSpeed >= 1) {
          speedScore = 30; // Regular (3G+)
        } else if (downloadSpeed >= 0.5) {
          speedScore = 20; // Deficiente (3G)
        } else {
          speedScore = 10; // 2G/Edge
        }
      }

      score += speedScore;
      debugPrint(
          '📊 Score por velocidad: $speedScore/60 (${downloadSpeed.toStringAsFixed(2)} Mbps vía CDNs - indica fibra)');
    } else {
      score += 25;
      debugPrint('📊 Score neutro por velocidad: 25/60');
    }

    debugPrint('📊 Score total: $score/100');

    // 9. DETERMINAR CALIDAD CON UMBRALES MUY REALISTAS PARA COLOMBIA
    String quality;
    if (score >= 70) {
      quality = 'excellent'; // 70+ puntos (conexión premium)
    } else if (score >= 55) {
      quality = 'good'; // 55-69 puntos (buena conexión)
    } else if (score >= 40) {
      quality = 'fair'; // 40-54 puntos (conexión regular)
    } else if (score >= 25) {
      quality = 'poor'; // 25-39 puntos (conexión deficiente)
    } else {
      quality = 'none'; // <25 puntos (muy mala conexión)
    }

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

    debugPrint('🎉 Resultado final: $finalMessage');
    debugPrint('📊 Es buena conexión: $isGoodConnection');
    if (apiPing != null) {
      debugPrint('🌍 Ping a tu API (Oregon): ${apiPing}ms');
    }
    if (bestLocalServer != null) {
      debugPrint('🇨🇴 Mejor servidor local: $bestLocalServer (${bestLocalPing}ms)');
    }

    // PREPARAR RESULTADO
    final result = {
      'message': finalMessage,
      'isGoodConnection': isGoodConnection,
      'hasInternet': true,
    };

    // ACTUALIZAR CACHÉ
    _cachedResult = result;
    _lastCheckTime = DateTime.now();
    debugPrint('💾 Resultado guardado en caché (válido por ${_cacheDuration.inMinutes} minutos)');

    return result;
  } catch (e) {
    debugPrint('💥 Error general: $e');

    final result = {
      'message': 'Error al verificar la conexión',
      'isGoodConnection': false,
      'hasInternet': false,
    };

    // CACHEAR RESULTADO DE ERROR (para evitar chequeos repetitivos cuando hay problemas)
    _cachedResult = result;
    _lastCheckTime = DateTime.now();
    debugPrint('💾 Error - resultado cacheado (evita reintentos inmediatos)');

    return result;
  } finally {
    // Limpiar recursos
    try {
      dio?.close();
      debugPrint('🔒 Recursos liberados correctamente');
    } catch (e) {
      debugPrint('⚠️ Error liberando recursos: $e');
    }
  }
}

// CHECK RÁPIDO DE HTTP - retorna true si el endpoint responde
Future<bool> _quickHttpCheck(Dio dio, String url) async {
  try {
    final response = await dio.get(url);
    return response.statusCode != null && response.statusCode! < 400;
  } catch (e) {
    return false;
  }
}

// FUNCIÓN SIMPLIFICADA - SOLO 3 SERVIDORES: API EC2 + 2 LOCALES
List<ServerConfig> _getOptimalServers(Position position) {
  // Lista reducida: Solo API + 2 servidores locales confiables
  List<ServerConfig> servers = [
    // TU API AWS OREGON - SERVIDOR PRIORITARIO
    ServerConfig(
      url: 'https://api.clickpalm.com/',
      name: 'ClickPalm API',
      city: 'Oregon AWS',
      lat: 45.5152,
      lon: -122.6784,
      type: 'api',
    ),

    // SERVIDOR LOCAL 1 - Google (muy confiable, edge en Colombia)
    ServerConfig(
      url: 'https://www.google.com',
      name: 'Google',
      city: 'Colombia',
      lat: 4.7110,
      lon: -74.0721,
      type: 'ping',
    ),

    // SERVIDOR LOCAL 2 - Cloudflare CDN (rápido y confiable)
    ServerConfig(
      url: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js',
      name: 'Cloudflare CDN',
      city: 'Colombia',
      lat: 4.7110,
      lon: -74.0721,
      type: 'speed',
    ),
  ];

  debugPrint('📡 Servidores de verificación:');
  for (var server in servers) {
    debugPrint('   - ${server.name} (${server.type})');
  }

  return servers;
}

// SPEED TEST SIMPLIFICADO - SOLO 1 CDN CON 2 INTENTOS
Future<double?> _fallbackSpeedTestPublic(
    Dio dio, List<ServerConfig> servers) async {
  // Usar solo Cloudflare CDN (el más confiable)
  final speedServer = servers.firstWhere(
    (s) => s.type == 'speed',
    orElse: () => ServerConfig(
      url: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js',
      name: 'Cloudflare CDN',
      city: 'Colombia',
      lat: 4.7110,
      lon: -74.0721,
      type: 'speed',
    ),
  );

  List<double> speeds = [];

  try {
    debugPrint('⚡ Midiendo velocidad con ${speedServer.name}...');

    // Solo 2 intentos
    for (int attempt = 0; attempt < 2; attempt++) {
      final stopwatch = Stopwatch()..start();
      final response = await dio.get(
        speedServer.url,
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
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

        if (bytes > 5000) {
          final seconds = stopwatch.elapsedMilliseconds / 1000.0;
          final mbps = (bytes * 8) / (1024 * 1024 * seconds);
          double speed = double.parse(mbps.toStringAsFixed(2));
          speeds.add(speed);
          debugPrint('   Intento ${attempt + 1}: $speed Mbps');
        }
      }
    }

    if (speeds.isNotEmpty) {
      double avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      debugPrint('🏆 Velocidad promedio: ${avgSpeed.toStringAsFixed(2)} Mbps');
      return double.parse(avgSpeed.toStringAsFixed(2));
    }
  } catch (e) {
    debugPrint('❌ Error midiendo velocidad: $e');
  }

  return null;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
