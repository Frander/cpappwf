// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/widgets.dart'; // ← Para PopupRoute

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geodesy/geodesy.dart';
import 'package:proj4dart/proj4dart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/custom_code/actions/enriched_geo_buffer.dart';
import '/custom_code/platform_utils.dart';

/// Vector 3D simple para cálculos IMU
class Vector3 {
  final double x, y, z;
  const Vector3(this.x, this.y, this.z);

  Vector3 operator +(Vector3 other) =>
      Vector3(x + other.x, y + other.y, z + other.z);
  Vector3 operator -(Vector3 other) =>
      Vector3(x - other.x, y - other.y, z - other.z);
  Vector3 operator *(double scalar) =>
      Vector3(x * scalar, y * scalar, z * scalar);
  Vector3 operator /(double scalar) {
    if (scalar == 0) return Vector3.zero;
    return Vector3(x / scalar, y / scalar, z / scalar);
  }

  double get magnitude => sqrt(x * x + y * y + z * z);

  /// Magnitud al cuadrado (más eficiente que magnitude cuando solo se comparan distancias)
  double get magnitudeSquared => x * x + y * y + z * z;

  Vector3 normalized() {
    final mag = magnitude;
    return mag > 0 ? Vector3(x / mag, y / mag, z / mag) : Vector3.zero;
  }

  /// Producto punto (dot product) - útil para calcular ángulos y proyecciones
  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  /// Producto cruzado (cross product) - útil para calcular vectores perpendiculares
  Vector3 cross(Vector3 other) {
    return Vector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  /// Interpolación lineal entre dos vectores
  Vector3 lerp(Vector3 other, double t) {
    return Vector3(
      x + (other.x - x) * t,
      y + (other.y - y) * t,
      z + (other.z - z) * t,
    );
  }

  /// Limita la magnitud del vector a un máximo
  Vector3 clampMagnitude(double maxMagnitude) {
    final mag = magnitude;
    if (mag > maxMagnitude) {
      return this * (maxMagnitude / mag);
    }
    return this;
  }

  /// Distancia a otro vector
  double distanceTo(Vector3 other) => (this - other).magnitude;

  static const Vector3 zero = Vector3(0, 0, 0);
}

/// Quaternion para rotaciones 3D sin gimbal lock
class Quaternion {
  final double w, x, y, z;

  const Quaternion(this.w, this.x, this.y, this.z);

  /// Quaternion identidad (sin rotación)
  static const Quaternion identity = Quaternion(1, 0, 0, 0);

  /// Crear desde ángulos de Euler (roll, pitch, yaw en radianes)
  factory Quaternion.fromEuler(double roll, double pitch, double yaw) {
    final cy = cos(yaw * 0.5);
    final sy = sin(yaw * 0.5);
    final cp = cos(pitch * 0.5);
    final sp = sin(pitch * 0.5);
    final cr = cos(roll * 0.5);
    final sr = sin(roll * 0.5);

    return Quaternion(
      cr * cp * cy + sr * sp * sy,
      sr * cp * cy - cr * sp * sy,
      cr * sp * cy + sr * cp * sy,
      cr * cp * sy - sr * sp * cy,
    );
  }

  /// Crear desde velocidad angular (para integración de giroscopio)
  factory Quaternion.fromAngularVelocity(
      double wx, double wy, double wz, double dt) {
    final angle = sqrt(wx * wx + wy * wy + wz * wz) * dt;

    if (angle < 1e-8) {
      return Quaternion.identity;
    }

    final halfAngle = angle * 0.5;
    final s = sin(halfAngle) / (angle / dt);

    return Quaternion(
      cos(halfAngle),
      wx * s * dt,
      wy * s * dt,
      wz * s * dt,
    );
  }

  /// Multiplicación de quaternions (composición de rotaciones)
  Quaternion operator *(Quaternion q) {
    return Quaternion(
      w * q.w - x * q.x - y * q.y - z * q.z,
      w * q.x + x * q.w + y * q.z - z * q.y,
      w * q.y - x * q.z + y * q.w + z * q.x,
      w * q.z + x * q.y - y * q.x + z * q.w,
    );
  }

  /// Magnitud del quaternion
  double get magnitude => sqrt(w * w + x * x + y * y + z * z);

  /// Normalizar quaternion
  Quaternion normalize() {
    final mag = magnitude;
    if (mag < 1e-8) return Quaternion.identity;
    return Quaternion(w / mag, x / mag, y / mag, z / mag);
  }

  /// Rotar un vector 3D usando este quaternion
  Vector3 rotateVector(Vector3 v) {
    // Fórmula: v' = q * v * q^-1 (optimizada)
    final qx = x, qy = y, qz = z, qw = w;
    final vx = v.x, vy = v.y, vz = v.z;

    // Producto cruzado intermedio
    final ix = qw * vx + qy * vz - qz * vy;
    final iy = qw * vy + qz * vx - qx * vz;
    final iz = qw * vz + qx * vy - qy * vx;
    final iw = -qx * vx - qy * vy - qz * vz;

    // Segundo producto
    return Vector3(
      ix * qw + iw * -qx + iy * -qz - iz * -qy,
      iy * qw + iw * -qy + iz * -qx - ix * -qz,
      iz * qw + iw * -qz + ix * -qy - iy * -qx,
    );
  }

  /// Convertir a ángulos de Euler (para compatibilidad)
  Map<String, double> toEuler() {
    // Roll (rotación en X)
    final sinrCosp = 2 * (w * x + y * z);
    final cosrCosp = 1 - 2 * (x * x + y * y);
    final roll = atan2(sinrCosp, cosrCosp);

    // Pitch (rotación en Y)
    final sinp = 2 * (w * y - z * x);
    final pitch = sinp.abs() >= 1
        ? (sinp >= 0 ? pi / 2 : -pi / 2) // Gimbal lock
        : asin(sinp);

    // Yaw (rotación en Z / heading)
    final sinyCosp = 2 * (w * z + x * y);
    final cosyCosp = 1 - 2 * (y * y + z * z);
    final yaw = atan2(sinyCosp, cosyCosp);

    return {'roll': roll, 'pitch': pitch, 'yaw': yaw};
  }

  /// Obtener solo el heading (yaw) para GPS
  double getHeading() {
    return toEuler()['yaw']!;
  }

  /// Quaternion conjugado (inverso de rotación)
  Quaternion conjugate() => Quaternion(w, -x, -y, -z);

  /// Interpolación esférica lineal (SLERP) - suaviza transiciones de orientación
  Quaternion slerp(Quaternion target, double t) {
    double dot = w * target.w + x * target.x + y * target.y + z * target.z;

    // Asegurar camino más corto
    Quaternion q2 = target;
    if (dot < 0) {
      dot = -dot;
      q2 = Quaternion(-target.w, -target.x, -target.y, -target.z);
    }

    // Si están muy cercanos, usar interpolación lineal
    if (dot > 0.9995) {
      return Quaternion(
        w + (q2.w - w) * t,
        x + (q2.x - x) * t,
        y + (q2.y - y) * t,
        z + (q2.z - z) * t,
      ).normalize();
    }

    // Interpolación esférica
    double theta0 = acos(dot);
    double theta = theta0 * t;
    double sinTheta = sin(theta);
    double sinTheta0 = sin(theta0);

    double s0 = cos(theta) - dot * sinTheta / sinTheta0;
    double s1 = sinTheta / sinTheta0;

    return Quaternion(
      w * s0 + q2.w * s1,
      x * s0 + q2.x * s1,
      y * s0 + q2.y * s1,
      z * s0 + q2.z * s1,
    );
  }

  /// Calcula el ángulo entre dos quaternions (en radianes)
  double angleTo(Quaternion other) {
    double dot = (w * other.w + x * other.x + y * other.y + z * other.z)
        .abs()
        .clamp(0.0, 1.0);
    return 2.0 * acos(dot);
  }
}

/// Filtro Complementario para separar gravedad de aceleración lineal
class ComplementaryFilter {
  // Estimación de gravedad (baja frecuencia)
  Vector3 gravity = const Vector3(0, 0, 9.81);

  // Bias del acelerómetro
  Vector3 bias = Vector3.zero;

  // Filtro paso-bajo para suavizar acelerómetro
  Vector3 _filteredAccel = Vector3.zero;

  // Constantes de filtrado
  static const double alpha = 0.98; // Peso del giroscopio (alta frecuencia)
  static const double beta = 0.95; // Tasa de decay del bias
  static const double lowPassAlpha =
      0.9; // Suavizado del acelerómetro (reduce ruido de alta frecuencia)

  // Historial para calibración de bias
  final Queue<Vector3> biasHistory = Queue<Vector3>();
  static const int biasHistorySize = 20;

  /// Actualizar filtro con nuevas lecturas
  void update(
      AccelerometerEvent accel, GyroscopeEvent gyro, double dt, bool isStatic) {
    // 1. Aplicar filtro paso-bajo al acelerómetro (reduce ruido de alta frecuencia)
    final accelVector = Vector3(accel.x, accel.y, accel.z);
    _filteredAccel =
        _filteredAccel * lowPassAlpha + accelVector * (1 - lowPassAlpha);

    // 2. Integrar giroscopio para estimar cambio en gravedad (corto plazo)
    // El giroscopio indica rotación del dispositivo
    final gyroVector = Vector3(gyro.x, gyro.y, gyro.z);
    final gravityChange = gyroVector.cross(gravity) * dt;
    final gravityFromGyro = gravity + gravityChange;

    // 3. Fusión complementaria: 98% giroscopio, 2% acelerómetro filtrado
    gravity = Vector3(
      alpha * gravityFromGyro.x + (1 - alpha) * _filteredAccel.x,
      alpha * gravityFromGyro.y + (1 - alpha) * _filteredAccel.y,
      alpha * gravityFromGyro.z + (1 - alpha) * _filteredAccel.z,
    );

    // 4. Calibración de bias cuando está estático
    if (isStatic) {
      final currentBias = accelVector - gravity;
      biasHistory.addLast(currentBias);

      if (biasHistory.length > biasHistorySize) {
        biasHistory.removeFirst();
      }

      // Calcular bias promedio
      if (biasHistory.length >= 10) {
        double sumX = 0, sumY = 0, sumZ = 0;
        for (var b in biasHistory) {
          sumX += b.x;
          sumY += b.y;
          sumZ += b.z;
        }
        final avgBias = Vector3(
          sumX / biasHistory.length,
          sumY / biasHistory.length,
          sumZ / biasHistory.length,
        );

        // Actualización suave del bias
        bias = Vector3(
          beta * bias.x + (1 - beta) * avgBias.x,
          beta * bias.y + (1 - beta) * avgBias.y,
          beta * bias.z + (1 - beta) * avgBias.z,
        );
      }
    }
  }

  /// Obtener aceleración lineal (sin gravedad ni bias)
  Vector3 getLinearAcceleration(AccelerometerEvent accel) {
    return Vector3(
      accel.x - gravity.x - bias.x,
      accel.y - gravity.y - bias.y,
      accel.z - gravity.z - bias.z,
    );
  }

  /// Obtener magnitud de gravedad estimada
  double getGravityMagnitude() => gravity.magnitude;
}

/// Integrador IMU mejorado con Quaternions y Filtro Complementario
class IMUIntegrator {
  // Estado de velocidad y posición estimada (en coordenadas UTM)
  Vector3 velocity = Vector3.zero;
  double estimatedX = 0.0;
  double estimatedY = 0.0;

  // Orientación usando Quaternions (sin gimbal lock)
  Quaternion orientation = Quaternion.identity;

  // Filtro complementario integrado
  final ComplementaryFilter complementaryFilter = ComplementaryFilter();

  // Última actualización
  DateTime? lastUpdateTime;

  // Factor de amortiguamiento (decay) para evitar deriva
  static const double velocityDecay = 0.95;

  // Detección de cambios bruscos (para ventana adaptativa)
  double _lastHeading = 0.0;
  double _lastSpeed = 0.0;
  bool isBrushChange = false;
  DateTime? _lastBrushChangeTime;

  /// Actualiza orientación con giroscopio usando Quaternions
  void updateOrientation(GyroscopeEvent gyro, double dt) {
    // Crear quaternion incremental desde velocidad angular
    final dq = Quaternion.fromAngularVelocity(gyro.x, gyro.y, gyro.z, dt);

    // Componer rotación: q_new = q_old * dq
    orientation = (orientation * dq).normalize();
  }

  /// Actualiza posición estimada con aceleración compensada
  void updatePosition(AccelerometerEvent accel, GyroscopeEvent gyro, double dt,
      bool isMoving, bool isStatic) {
    if (dt <= 0 || dt > 1.0) return; // Filtrar deltas inválidos

    // 1. Actualizar filtro complementario
    complementaryFilter.update(accel, gyro, dt, isStatic);

    // 2. Obtener aceleración lineal (sin gravedad ni bias)
    final linearAccel = complementaryFilter.getLinearAcceleration(accel);

    // 3. Rotar aceleración del frame del dispositivo al frame mundial usando Quaternion
    final accelWorld = orientation.rotateVector(linearAccel);

    // 4. Calcular threshold adaptativo según el estado de movimiento
    final accelThreshold =
        isStatic ? 0.2 : (velocity.magnitude > 5 ? 1.0 : 0.5);

    // 5. Solo integrar si hay movimiento significativo
    if (isMoving && accelWorld.magnitude > accelThreshold) {
      // Integrar aceleración → velocidad
      velocity = velocity + (accelWorld * dt);

      // Aplicar amortiguamiento para evitar deriva
      velocity = velocity * velocityDecay;

      // Integrar velocidad → posición (en metros)
      estimatedX += velocity.x * dt;
      estimatedY += velocity.y * dt;
    } else {
      // Si no hay movimiento, reducir velocidad gradualmente
      velocity = velocity * 0.9;
    }
  }

  /// Sincroniza con posición GPS (corrige deriva acumulada)
  void syncWithGPS(
      double gpsX, double gpsY, double gpsSpeed, double gpsHeading) {
    // Resetear posición estimada al GPS
    estimatedX = gpsX;
    estimatedY = gpsY;

    // Corregir velocidad con GPS
    final gpsVelocityX = gpsSpeed * cos(gpsHeading);
    final gpsVelocityY = gpsSpeed * sin(gpsHeading);

    // Calcular diferencia de velocidad entre GPS e IMU
    final velocityDiff = sqrt(
        pow(gpsVelocityX - velocity.x, 2) + pow(gpsVelocityY - velocity.y, 2));

    // Si la diferencia es muy grande (>5 m/s), el IMU derivó mucho - reset completo
    if (velocityDiff > 5.0) {
      velocity = Vector3(gpsVelocityX, gpsVelocityY, 0);
    } else {
      // Fusión suave: 70% GPS, 30% IMU estimado
      velocity = Vector3(
        gpsVelocityX * 0.7 + velocity.x * 0.3,
        gpsVelocityY * 0.7 + velocity.y * 0.3,
        velocity.z * 0.3, // Solo mantener componente Z del IMU
      );
    }

    // Actualizar orientación con GPS heading usando SLERP (suave, sin saltos)
    final targetOrientation = Quaternion.fromEuler(0, 0, gpsHeading);
    orientation = orientation.slerp(targetOrientation, 0.3); // 30% GPS, 70% IMU
  }

  /// Obtiene posición predicha actual
  Map<String, double> getPredictedPosition() {
    return {
      'x': estimatedX,
      'y': estimatedY,
      'velocityMagnitude': velocity.magnitude,
    };
  }

  /// Obtener heading actual (para compatibilidad)
  double getHeading() {
    return orientation.getHeading();
  }

  /// Obtener aceleración mundial actual
  Vector3 getWorldAcceleration(AccelerometerEvent accel) {
    final linearAccel = complementaryFilter.getLinearAcceleration(accel);
    return orientation.rotateVector(linearAccel);
  }

  /// Detecta cambios bruscos de dirección o velocidad para ventana adaptativa
  void detectBrushChange() {
    final currentHeading = orientation.getHeading();
    final currentSpeed = velocity.magnitude;

    // Detectar giro brusco (>45° en 200ms = 225°/segundo)
    final headingChange = (currentHeading - _lastHeading).abs();
    if (headingChange > 0.785) {
      // 45° en radianes
      isBrushChange = true;
      _lastBrushChangeTime = DateTime.now();
    }

    // Detectar frenado/aceleración brusca (>3 m/s² en 200ms)
    final speedChange = (currentSpeed - _lastSpeed).abs();
    if (speedChange > 0.6) {
      // 3 m/s² × 0.2s = 0.6 m/s
      isBrushChange = true;
      _lastBrushChangeTime = DateTime.now();
    }

    // Auto-reset después de 3 segundos sin cambios bruscos
    if (isBrushChange && _lastBrushChangeTime != null) {
      final timeSinceChange = DateTime.now().difference(_lastBrushChangeTime!);
      if (timeSinceChange.inSeconds >= 3) {
        isBrushChange = false;
      }
    }

    // Actualizar valores para próxima iteración
    _lastHeading = currentHeading;
    _lastSpeed = currentSpeed;
  }
}

/// Configuración mejorada del sistema de geolocalización
class LocationConfig {
  static const double maxAccuracy = 25.0; // Reducido de 30m
  static const double outlierFactorMoving = 3.0; // Más estricto cuando se mueve
  static const double outlierFactorStatic =
      5.0; // Más permisivo cuando está quieto
  static const int medianWindowSize =
      12; // Ventana de mediana: 12 × 1.5s = 18 segundos de historial
  static const int kalmanWindowSize = 10; // Ventana para adaptación dinámica
  static const double processNoiseBase = 0.003; // Reducido
  static const double processNoiseMultiplier = 2.0;
  static const int warmupSeconds =
      10; // Período de warm-up antes de procesar datos
  static const int stabilizationSeconds =
      3; // Período de estabilización después del warm-up
  static const double minMovementThreshold = 1.5; // metros
  static const double staticAccelThreshold = 0.6; // Más sensible
  static const double dynamicAccelThreshold = 2.0;
  static const int maxConsecutiveRejects = 3;
  static const double hdopThreshold = 3.0; // Umbral HDOP si está disponible
}

/// Estado del filtro optimizado con límites de memoria
class FilterState {
  double? xEst, yEst, altEst, speedEst;
  double xCov = 15, yCov = 15, altCov = 15, speedCov = 5;
  DateTime? lastUpdateTime;
  int consecutiveRejects = 0;

  // Ventanas para análisis estadístico con límites explícitos
  final accuracyWindow = Queue<double>();
  final speedWindow = Queue<double>();

  // Límites máximos para evitar memory leak
  static const int maxWindowSize = 50;

  void enforceMemoryLimits() {
    if (accuracyWindow.length > maxWindowSize) {
      accuracyWindow.removeFirst();
    }
    if (speedWindow.length > maxWindowSize) {
      speedWindow.removeFirst();
    }
  }
}

/// Detector de Multipath (rebotes de señal GPS)
class MultipathDetector {
  final accuracyHistory = Queue<double>();
  final altitudeHistory = Queue<double>();
  double? lastAccuracy;
  double? lastAltitude;
  int consecutiveMultipathDetections = 0;

  static const int historySize = 10;
  static const double accuracyJumpThreshold = 2.5; // Si el error sube 2.5x
  static const double altitudeJumpThreshold = 15.0; // Salto de altitud > 15m
  static const double minAccuracyForMultipath =
      8.0; // Solo considerar si accuracy > 8m

  /// Detecta si una posición GPS es probable resultado de multipath
  bool isLikelyMultipath(Position pos, MovementDetector movement) {
    final currentAccuracy = pos.accuracy;
    final currentAltitude = pos.altitude;

    // Solo analizar si la precisión es sospechosa
    if (currentAccuracy < minAccuracyForMultipath) {
      consecutiveMultipathDetections = 0;
      _updateHistory(currentAccuracy, currentAltitude);
      return false;
    }

    bool isMultipath = false;

    // 1. Detectar salto repentino en precisión (señal degrada de golpe)
    if (lastAccuracy != null && lastAccuracy! < 10) {
      final accuracyRatio = currentAccuracy / lastAccuracy!;
      if (accuracyRatio > accuracyJumpThreshold) {
        isMultipath = true;
        debugPrint(
            '🌊 Multipath detectado: Salto de precisión ${lastAccuracy!.toStringAsFixed(1)}m → ${currentAccuracy.toStringAsFixed(1)}m (${accuracyRatio.toStringAsFixed(1)}x)');
      }
    }

    // 2. Detectar salto de altitud sin movimiento (rebote causa error vertical)
    if (!movement.isStaticState && lastAltitude != null && pos.speed < 2.0) {
      // Solo si velocidad baja
      final altitudeChange = (currentAltitude - lastAltitude!).abs();
      if (altitudeChange > altitudeJumpThreshold) {
        isMultipath = true;
        debugPrint(
            '🌊 Multipath detectado: Salto de altitud ${altitudeChange.toStringAsFixed(1)}m sin movimiento significativo');
      }
    }

    // 3. Analizar varianza de precisión (multipath causa oscilación)
    if (accuracyHistory.length >= 5) {
      double sumAcc = 0.0;
      for (final v in accuracyHistory) { sumAcc += v; }
      final mean = sumAcc / accuracyHistory.length;
      double sumSq = 0.0;
      for (final v in accuracyHistory) {
        final d = v - mean;
        sumSq += d * d;
      }
      final stdDev = sqrt(sumSq / accuracyHistory.length);

      // Si la desviación estándar es > 50% de la media, hay inestabilidad
      if (stdDev > mean * 0.5 && currentAccuracy > mean * 1.3) {
        isMultipath = true;
        debugPrint(
            '🌊 Multipath detectado: Alta varianza en precisión (σ=${stdDev.toStringAsFixed(1)}m, μ=${mean.toStringAsFixed(1)}m)');
      }
    }

    // Contador de detecciones consecutivas
    if (isMultipath) {
      consecutiveMultipathDetections++;
    } else {
      consecutiveMultipathDetections = 0;
    }

    _updateHistory(currentAccuracy, currentAltitude);
    return isMultipath;
  }

  void _updateHistory(double accuracy, double altitude) {
    accuracyHistory.addLast(accuracy);
    if (accuracyHistory.length > historySize) {
      accuracyHistory.removeFirst();
    }

    altitudeHistory.addLast(altitude);
    if (altitudeHistory.length > historySize) {
      altitudeHistory.removeFirst();
    }

    lastAccuracy = accuracy;
    lastAltitude = altitude;
  }

  /// Calcula factor de penalización para multipath (1.0 = normal, 3.0 = multipath severo)
  double getMultipathPenalty() {
    if (consecutiveMultipathDetections == 0) return 1.0;
    // Penalización crece exponencialmente con detecciones consecutivas
    return (1.0 + consecutiveMultipathDetections * 0.5).clamp(1.0, 3.0);
  }
}

/// Detector de movimiento mejorado con límites de memoria
class MovementDetector {
  double accelMagnitude = 9.81;
  double accelVariance = 0.0;
  final accelHistory = Queue<double>();
  bool isStaticState = false;
  DateTime lastMovementTime = DateTime.now();
  double lastValidSpeed = 0.0;

  static const int accelHistorySize = 20;

  void updateAccelerometer(AccelerometerEvent event) {
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    accelHistory.addLast(magnitude);

    // Límite explícito de memoria
    while (accelHistory.length > accelHistorySize) {
      accelHistory.removeFirst();
    }

    if (accelHistory.length >= 5) {
      double sum = 0.0;
      for (final v in accelHistory) { sum += v; }
      final mean = sum / accelHistory.length;
      double sumSq = 0.0;
      for (final v in accelHistory) {
        final d = v - mean;
        sumSq += d * d;
      }
      accelVariance = sumSq / accelHistory.length;
      accelMagnitude = mean;

      // Estado estático más sofisticado
      final gravityDeviation = (mean - 9.81).abs();
      isStaticState = gravityDeviation < LocationConfig.staticAccelThreshold &&
          accelVariance < LocationConfig.dynamicAccelThreshold;

      if (!isStaticState) {
        lastMovementTime = DateTime.now();
      }
    }
  }

  bool isCurrentlyStatic() {
    final timeSinceMovement =
        DateTime.now().difference(lastMovementTime).inSeconds;
    return isStaticState && timeSinceMovement > 3;
  }
}

/// Corrección por HDOP/VDOP (Dilución Geométrica de Precisión)
class HDOPCorrector {
  static const double defaultHDOP = 2.0; // HDOP típico en buenas condiciones

  /// Ajusta la precisión reportada según HDOP/VDOP
  /// HDOP alto = satélites mal distribuidos = peor precisión real
  static double adjustAccuracyByDOP(Position pos) {
    // Intentar obtener HDOP de diferentes fuentes según plataforma
    double? hdop;

    // En Android, a veces viene en verticalAccuracy o como metadata
    // En iOS, puede estar disponible en extensiones
    if (pos.accuracy > 0) {
      // Estimar HDOP basado en la precisión reportada y número de satélites
      // Si la precisión es muy mala, probablemente el HDOP es alto
      if (pos.accuracy > 20) {
        hdop = 5.0; // HDOP estimado alto
      } else if (pos.accuracy > 10) {
        hdop = 3.0; // HDOP estimado medio
      } else if (pos.accuracy > 5) {
        hdop = 2.0; // HDOP estimado bueno
      } else {
        hdop = 1.5; // HDOP estimado excelente
      }
    }

    if (hdop == null || hdop <= 0) {
      hdop = defaultHDOP;
    }

    // Factor de corrección: HDOP alto amplifica el error
    // HDOP 1.0 = ideal (no corrección)
    // HDOP 5.0 = muy malo (multiplicar error por ~1.6)
    final hdopFactor = 1.0 + ((hdop - 1.0) * 0.2).clamp(0.0, 2.0);

    return pos.accuracy * hdopFactor;
  }

  /// Calcula confianza normalizada (0.0 = no confiable, 1.0 = muy confiable)
  static double calculateConfidence(double correctedAccuracy) {
    // Mapear precisión a confianza usando función sigmoide
    // accuracy 5m = confianza ~0.9
    // accuracy 15m = confianza ~0.5
    // accuracy 30m = confianza ~0.1
    return 1.0 / (1.0 + (correctedAccuracy / 10.0));
  }
}

/// Caché para proyecciones UTM y conversiones
class UTMCache {
  Projection? proj4326;
  Projection? projUTM;
  int? currentZone;
  String? currentEpsgKey;

  // Caché de última conversión
  double? lastLat, lastLon, lastX, lastY;

  void updateZone(double longitude) {
    final zone = ((longitude + 180) / 6).ceil();
    if (zone != currentZone) {
      currentZone = zone;
      final epsgCode = 32600 + zone;
      currentEpsgKey = 'EPSG:$epsgCode';

      if (Projection.get(currentEpsgKey!) == null) {
        final projDef = '+proj=utm +zone=$zone +datum=WGS84 +units=m +no_defs';
        Projection.add(currentEpsgKey!, projDef);
      }

      proj4326 = Projection.get('EPSG:4326')!;
      projUTM = Projection.get(currentEpsgKey!)!;
    }
  }

  Point? toUTM(double latitude, double longitude) {
    // Verificar si ya tenemos esta conversión en caché
    if (lastLat == latitude && lastLon == longitude && lastX != null) {
      return Point(x: lastX!, y: lastY!);
    }

    updateZone(longitude);
    final ptGeo = Point(x: longitude, y: latitude);
    final ptUtm = proj4326!.transform(projUTM!, ptGeo);

    // Guardar en caché
    lastLat = latitude;
    lastLon = longitude;
    lastX = ptUtm.x;
    lastY = ptUtm.y;

    return ptUtm;
  }

  Point? toGeo(double x, double y) {
    if (projUTM == null || proj4326 == null) return null;
    final ptUtm = Point(x: x, y: y);
    return projUTM!.transform(proj4326!, ptUtm);
  }
}

/// Validador de posiciones mejorado con UKF, HDOP y Multipath
class PositionValidator {
  static bool isValidPosition(Position pos, UnscentedKalmanFilter? ukf,
      MovementDetector movement, UTMCache utmCache, DateTime? lastUpdateTime) {
    // Aplicar corrección HDOP primero
    final correctedAccuracy = HDOPCorrector.adjustAccuracyByDOP(pos);

    // Validaciones básicas con precisión corregida
    if (correctedAccuracy > LocationConfig.maxAccuracy) return false;
    if (pos.latitude.abs() > 90 || pos.longitude.abs() > 180) return false;

    // Validación de velocidad realista
    if (pos.speed > 150) return false; // 540 km/h máximo

    // Si tenemos UKF previo, validar consistencia
    if (ukf != null && lastUpdateTime != null) {
      final ukfPos = ukf.getPosition();
      final timeDelta = DateTime.now().difference(lastUpdateTime).inSeconds;

      if (timeDelta > 0 && ukfPos['x'] != 0.0) {
        // Usar caché UTM para conversión
        final ptUtm = utmCache.toUTM(pos.latitude, pos.longitude);
        if (ptUtm == null) return false;

        final distance = sqrt(
            pow(ptUtm.x - ukfPos['x']!, 2) + pow(ptUtm.y - ukfPos['y']!, 2));
        final maxExpectedDistance = max(
            pos.speed * timeDelta + pos.accuracy * 2,
            LocationConfig.minMovementThreshold);

        if (distance > maxExpectedDistance && !movement.isCurrentlyStatic()) {
          return false;
        }
      }
    }

    return true;
  }
}

/// Calculador de Ruido de Proceso Adaptativo
class AdaptiveProcessNoise {
  /// Calcula el ruido de proceso según el estado dinámico del sistema.
  /// Unidades: metros² (el UKF opera en UTM).
  /// Un operario de campo camina ~1 m/s entre palmas (7-9 m por árbol),
  /// por eso el ruido no puede ser inferior a ~0.5 m² ni siquiera en reposo.
  static double calculate(double speed, double acceleration, bool isStatic) {
    // Caso 1: Dispositivo estático o velocidad muy baja
    // 0.5 m² permite que el filtro siga actualizando aunque el operario
    // esté quieto registrando una visita y luego camine al siguiente árbol.
    if (isStatic || speed < 0.5) {
      return 0.5;
    }

    // Caso 2: Movimiento constante (poca aceleración)
    // Ruido crece linealmente con velocidad (base 2.0 para caminar ~1 m/s → ~2.2 m²)
    if (acceleration.abs() < 0.3) {
      return 2.0 * (1 + speed / 10.0);
    }

    // Caso 3: Acelerando o frenando
    return 5.0 * (1 + acceleration.abs() / 5.0);
  }
}

/// Unscented Kalman Filter (UKF) para fusión GPS + IMU
/// Estado: [x, y, vx, vy, ax, ay] (posición, velocidad, aceleración en UTM)
///
/// OPTIMIZACIÓN: todos los buffers de trabajo se pre-alocan en el constructor
/// y se reutilizan en cada ciclo (zero heap allocations por predict/update).
class UnscentedKalmanFilter {
  // Estado del sistema: [x, y, vx, vy, ax, ay]
  final List<double> state = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  // Matriz de covarianza del estado (6x6) — se modifica in-place
  final List<List<double>> covariance = List.generate(
    6,
    (i) => List.generate(6, (j) => i == j ? 15.0 : 0.0),
  );

  // Parámetros UKF
  static const double alpha = 0.001;
  static const double beta = 2.0;
  static const double kappa = 0.0;
  static const int stateDim = 6;
  static const int _numSigma = 2 * stateDim + 1; // = 13

  late final double lambda;
  late final List<double> weightsM;
  late final List<double> weightsC;

  // ── Buffers pre-alocados (nunca se reasignan después del constructor) ────
  // Sigma points y puntos propagados
  late final List<List<double>> _sigmaPoints;    // [13][6]
  late final List<List<double>> _propagated;     // [13][6]
  // Predict intermedios
  late final List<double> _predMean;             // [6]
  late final List<List<double>> _predCov;        // [6][6]
  late final List<double> _diffBuf;              // [6]  (reutilizado por iteración)
  // Cholesky
  late final List<List<double>> _choleskyL;      // [6][6]
  // Update intermedios — espacio de medición [x, y]
  late final List<List<double>> _measPts;        // [13][2]
  late final List<double> _predMeas;             // [2]
  late final List<List<double>> _innovCov;       // [2][2]
  late final List<List<double>> _crossCov;       // [6][2]
  late final List<List<double>> _kalmanGain;     // [6][2]
  late final List<List<double>> _invInnovCov;    // [2][2]
  late final List<double> _diffMBuf;             // [2]
  late final List<double> _diffSBuf;             // [6]
  late final List<double> _innovBuf;             // [2]

  UnscentedKalmanFilter() {
    lambda = alpha * alpha * (stateDim + kappa) - stateDim;

    weightsM = List.filled(_numSigma, 0.0);
    weightsC = List.filled(_numSigma, 0.0);
    weightsM[0] = lambda / (stateDim + lambda);
    weightsC[0] = lambda / (stateDim + lambda) + (1 - alpha * alpha + beta);
    for (int i = 1; i < _numSigma; i++) {
      weightsM[i] = 1.0 / (2.0 * (stateDim + lambda));
      weightsC[i] = weightsM[i];
    }

    // Pre-alocar todos los buffers de trabajo
    _sigmaPoints  = List.generate(_numSigma, (_) => List.filled(stateDim, 0.0));
    _propagated   = List.generate(_numSigma, (_) => List.filled(stateDim, 0.0));
    _predMean     = List.filled(stateDim, 0.0);
    _predCov      = List.generate(stateDim, (_) => List.filled(stateDim, 0.0));
    _diffBuf      = List.filled(stateDim, 0.0);
    _choleskyL    = List.generate(stateDim, (_) => List.filled(stateDim, 0.0));
    _measPts      = List.generate(_numSigma, (_) => List.filled(2, 0.0));
    _predMeas     = List.filled(2, 0.0);
    _innovCov     = List.generate(2, (_) => List.filled(2, 0.0));
    _crossCov     = List.generate(stateDim, (_) => List.filled(2, 0.0));
    _kalmanGain   = List.generate(stateDim, (_) => List.filled(2, 0.0));
    _invInnovCov  = List.generate(2, (_) => List.filled(2, 0.0));
    _diffMBuf     = List.filled(2, 0.0);
    _diffSBuf     = List.filled(stateDim, 0.0);
    _innovBuf     = List.filled(2, 0.0);
  }

  // ── Helpers internos (sin allocations) ──────────────────────────────────

  /// Cholesky in-place: escribe en _choleskyL, escala la matriz por `scale`.
  void _cholesky(double scale) {
    for (int i = 0; i < stateDim; i++) {
      for (int j = 0; j < stateDim; j++) { _choleskyL[i][j] = 0.0; }
    }
    for (int i = 0; i < stateDim; i++) {
      for (int j = 0; j <= i; j++) {
        double sum = 0.0;
        for (int k = 0; k < j; k++) { sum += _choleskyL[i][k] * _choleskyL[j][k]; }
        if (i == j) {
          final val = covariance[i][i] * scale - sum;
          _choleskyL[i][j] = val > 0 ? sqrt(val) : 0.0;
        } else {
          _choleskyL[i][j] = _choleskyL[j][j] > 0
              ? ((covariance[i][j] * scale - sum) / _choleskyL[j][j])
              : 0.0;
        }
      }
    }
  }

  /// Genera sigma points en _sigmaPoints (in-place, sin allocations).
  void _generateSigmaPoints() {
    _cholesky(stateDim + lambda);
    // Sigma point 0: estado actual
    for (int j = 0; j < stateDim; j++) { _sigmaPoints[0][j] = state[j]; }
    // Sigma points 1..n y n+1..2n: ±columna i de L
    for (int i = 0; i < stateDim; i++) {
      for (int j = 0; j < stateDim; j++) {
        _sigmaPoints[i + 1][j]          = state[j] + _choleskyL[j][i];
        _sigmaPoints[i + 1 + stateDim][j] = state[j] - _choleskyL[j][i];
      }
    }
  }

  /// Modelo de proceso in-place: escribe en `out` (sin allocations).
  void _processModel(List<double> s, double dt, List<double> out) {
    final vx = s[2], vy = s[3], ax = s[4], ay = s[5];
    out[0] = s[0] + vx * dt + 0.5 * ax * dt * dt;
    out[1] = s[1] + vy * dt + 0.5 * ay * dt * dt;
    out[2] = vx + ax * dt;
    out[3] = vy + ay * dt;
    out[4] = ax * 0.95;
    out[5] = ay * 0.95;
  }

  /// Invierte matriz 2×2 en `out` (in-place, sin allocations).
  void _invert2x2(List<List<double>> m, List<List<double>> out) {
    final det = m[0][0] * m[1][1] - m[0][1] * m[1][0];
    if (det.abs() < 1e-10) {
      out[0][0] = 1.0; out[0][1] = 0.0;
      out[1][0] = 0.0; out[1][1] = 1.0;
      return;
    }
    final inv = 1.0 / det;
    out[0][0] =  m[1][1] * inv; out[0][1] = -m[0][1] * inv;
    out[1][0] = -m[1][0] * inv; out[1][1] =  m[0][0] * inv;
  }

  // ── API pública ──────────────────────────────────────────────────────────

  /// Predicción UKF (zero allocations).
  void predict(double dt, double processNoise) {
    _generateSigmaPoints();

    // Propagar sigma points a través del modelo
    for (int i = 0; i < _numSigma; i++) {
      _processModel(_sigmaPoints[i], dt, _propagated[i]);
    }

    // Media ponderada → _predMean
    for (int j = 0; j < stateDim; j++) { _predMean[j] = 0.0; }
    for (int i = 0; i < _numSigma; i++) {
      final w = weightsM[i];
      for (int j = 0; j < stateDim; j++) { _predMean[j] += w * _propagated[i][j]; }
    }

    // Covarianza ponderada → _predCov
    for (int r = 0; r < stateDim; r++) {
      for (int c = 0; c < stateDim; c++) { _predCov[r][c] = 0.0; }
    }
    for (int i = 0; i < _numSigma; i++) {
      final wc = weightsC[i];
      for (int j = 0; j < stateDim; j++) {
        _diffBuf[j] = _propagated[i][j] - _predMean[j];
      }
      for (int r = 0; r < stateDim; r++) {
        for (int c = 0; c < stateDim; c++) {
          _predCov[r][c] += wc * _diffBuf[r] * _diffBuf[c];
        }
      }
    }
    for (int i = 0; i < stateDim; i++) { _predCov[i][i] += processNoise; }

    // Copiar al estado principal (in-place)
    for (int j = 0; j < stateDim; j++) { state[j] = _predMean[j]; }
    for (int r = 0; r < stateDim; r++) {
      for (int c = 0; c < stateDim; c++) { covariance[r][c] = _predCov[r][c]; }
    }
  }

  /// Actualización con medición GPS (zero allocations).
  void update(double measX, double measY, double measNoise, Vector3? imuAccel) {
    _generateSigmaPoints();

    // Mapear sigma points al espacio de medición [x, y]
    for (int i = 0; i < _numSigma; i++) {
      _measPts[i][0] = _sigmaPoints[i][0];
      _measPts[i][1] = _sigmaPoints[i][1];
    }

    // Media de medición predicha
    _predMeas[0] = 0.0; _predMeas[1] = 0.0;
    for (int i = 0; i < _numSigma; i++) {
      _predMeas[0] += weightsM[i] * _measPts[i][0];
      _predMeas[1] += weightsM[i] * _measPts[i][1];
    }

    // Covarianza de innovación
    _innovCov[0][0] = 0.0; _innovCov[0][1] = 0.0;
    _innovCov[1][0] = 0.0; _innovCov[1][1] = 0.0;
    for (int i = 0; i < _numSigma; i++) {
      _diffMBuf[0] = _measPts[i][0] - _predMeas[0];
      _diffMBuf[1] = _measPts[i][1] - _predMeas[1];
      final wc = weightsC[i];
      _innovCov[0][0] += wc * _diffMBuf[0] * _diffMBuf[0];
      _innovCov[0][1] += wc * _diffMBuf[0] * _diffMBuf[1];
      _innovCov[1][0] += wc * _diffMBuf[1] * _diffMBuf[0];
      _innovCov[1][1] += wc * _diffMBuf[1] * _diffMBuf[1];
    }
    _innovCov[0][0] += measNoise;
    _innovCov[1][1] += measNoise;

    // Covarianza cruzada estado × medición
    for (int r = 0; r < stateDim; r++) {
      _crossCov[r][0] = 0.0; _crossCov[r][1] = 0.0;
    }
    for (int i = 0; i < _numSigma; i++) {
      for (int j = 0; j < stateDim; j++) {
        _diffSBuf[j] = _sigmaPoints[i][j] - state[j];
      }
      _diffMBuf[0] = _measPts[i][0] - _predMeas[0];
      _diffMBuf[1] = _measPts[i][1] - _predMeas[1];
      final wc = weightsC[i];
      for (int r = 0; r < stateDim; r++) {
        _crossCov[r][0] += wc * _diffSBuf[r] * _diffMBuf[0];
        _crossCov[r][1] += wc * _diffSBuf[r] * _diffMBuf[1];
      }
    }

    // Ganancia de Kalman: K = Pxy × Pyy⁻¹
    _invert2x2(_innovCov, _invInnovCov);
    for (int i = 0; i < stateDim; i++) {
      _kalmanGain[i][0] = _crossCov[i][0] * _invInnovCov[0][0]
                        + _crossCov[i][1] * _invInnovCov[1][0];
      _kalmanGain[i][1] = _crossCov[i][0] * _invInnovCov[0][1]
                        + _crossCov[i][1] * _invInnovCov[1][1];
    }

    // Actualizar estado: x = x + K × (z - z_pred)
    _innovBuf[0] = measX - _predMeas[0];
    _innovBuf[1] = measY - _predMeas[1];
    for (int i = 0; i < stateDim; i++) {
      state[i] += _kalmanGain[i][0] * _innovBuf[0]
                + _kalmanGain[i][1] * _innovBuf[1];
    }

    // Fusión IMU para aceleración
    if (imuAccel != null) {
      state[4] = imuAccel.x * 0.7 + state[4] * 0.3;
      state[5] = imuAccel.y * 0.7 + state[5] * 0.3;
    }

    // Actualizar covarianza: P = P - K × Pyy × Kᵀ
    for (int i = 0; i < stateDim; i++) {
      for (int j = 0; j < stateDim; j++) {
        for (int k = 0; k < 2; k++) {
          covariance[i][j] -=
              _kalmanGain[i][k] * _innovCov[k][0] * _kalmanGain[j][0]
            + _kalmanGain[i][k] * _innovCov[k][1] * _kalmanGain[j][1];
        }
      }
    }
  }

  /// Obtener posición estimada.
  Map<String, double> getPosition() {
    return {
      'x': state[0],
      'y': state[1],
      'vx': state[2],
      'vy': state[3],
      'speed': sqrt(state[2] * state[2] + state[3] * state[3]),
      'acceleration': sqrt(state[4] * state[4] + state[5] * state[5]),
    };
  }

  double getPositionError() {
    return sqrt((covariance[0][0] + covariance[1][1]) / 2.0);
  }

  void increaseUncertainty(double factor) {
    for (int i = 0; i < stateDim; i++) {
      for (int j = 0; j < stateDim; j++) { covariance[i][j] *= factor; }
    }
  }

  /// Reinicia el filtro a su estado inicial (in-place, sin allocations).
  void reset() {
    for (int i = 0; i < stateDim; i++) {
      state[i] = 0.0;
      for (int j = 0; j < stateDim; j++) {
        covariance[i][j] = i == j ? 15.0 : 0.0;
      }
    }
  }
}

/// Suscripciones globales
StreamSubscription<Position>? _locationSubscription;
StreamSubscription<AccelerometerEvent>? _accelSubscription;
StreamSubscription<GyroscopeEvent>? _gyroSubscription;

/// Caché de batería para evitar llamadas frecuentes a platform channel
class BatteryCache {
  int _cachedLevel = 0;
  DateTime? _lastUpdate;
  final Battery _battery = Battery();
  static const Duration _cacheValidity = Duration(minutes: 1);

  Future<int> getBatteryLevel() async {
    final now = DateTime.now();
    if (_lastUpdate == null || now.difference(_lastUpdate!) > _cacheValidity) {
      try {
        _cachedLevel = await _battery.batteryLevel;
        _lastUpdate = now;
        debugPrint('🔋 Batería actualizada: $_cachedLevel%');
      } catch (e) {
        debugPrint('⚠️ No se pudo obtener nivel de batería: $e');
      }
    }
    return _cachedLevel;
  }
}

/// Throttler para actualizaciones de AppState
class StateUpdateThrottler {
  DateTime? _lastUpdate;
  static const Duration _minInterval = Duration(seconds: 2);

  bool shouldUpdate() {
    final now = DateTime.now();
    if (_lastUpdate == null || now.difference(_lastUpdate!) > _minInterval) {
      _lastUpdate = now;
      return true;
    }
    return false;
  }
}

/// Sistema de logging resumido cada N segundos
class PeriodicLogger {
  DateTime? _lastLog;
  static const Duration _logInterval = Duration(seconds: 40);

  // Contadores acumulados
  int _totalReadings = 0;
  int _outliersRejected = 0;
  int _multipathDetected = 0;
  int _brushChanges = 0;
  double _avgAccuracy = 0.0;
  double _avgSpeed = 0.0;
  int _windowSizeSum = 0;

  void recordReading({
    required bool isOutlier,
    required bool isMultipath,
    required bool isBrushChange,
    required double accuracy,
    required double speed,
    required int windowSize,
  }) {
    _totalReadings++;
    if (isOutlier) _outliersRejected++;
    if (isMultipath) _multipathDetected++;
    if (isBrushChange) _brushChanges++;
    _avgAccuracy += accuracy;
    _avgSpeed += speed;
    _windowSizeSum += windowSize;
  }

  bool shouldLog() {
    final now = DateTime.now();
    if (_lastLog == null || now.difference(_lastLog!) >= _logInterval) {
      if (_totalReadings > 0) {
        _printSummary();
        _reset();
      }
      _lastLog = now;
      return true;
    }
    return false;
  }

  void _printSummary() {
    if (_totalReadings == 0) return;

    // Logs deshabilitados - solo mostrar cada 3 minutos si es necesario
    // final avgAcc = _avgAccuracy / _totalReadings;
    // final avgSpd = _avgSpeed / _totalReadings;
    // final avgWindow = _windowSizeSum / _totalReadings;
    // final outlierRate = (_outliersRejected / _totalReadings * 100);
    // final multipathRate = (_multipathDetected / _totalReadings * 100);

    // debugPrint('');
    // debugPrint('═══════════════════════════════════════════════');
    // debugPrint('📊 RESUMEN GPS (últimos ${_logInterval.inSeconds}s)');
    // debugPrint('═══════════════════════════════════════════════');
    // debugPrint('📍 Lecturas procesadas: $_totalReadings');
    // debugPrint('🎯 Precisión promedio: ${avgAcc.toStringAsFixed(1)}m');
    // debugPrint('🚀 Velocidad promedio: ${avgSpd.toStringAsFixed(2)}m/s');
    // debugPrint('📏 Ventana filtrado: ${avgWindow.toStringAsFixed(1)} muestras');
    // debugPrint(
    //     '⚠️  Outliers rechazados: $_outliersRejected (${outlierRate.toStringAsFixed(1)}%)');
    // debugPrint(
    //     '📡 Multipath detectado: $_multipathDetected (${multipathRate.toStringAsFixed(1)}%)');
    // debugPrint('🔄 Cambios bruscos: $_brushChanges');
    // debugPrint('═══════════════════════════════════════════════');
    // debugPrint('');
  }

  void _reset() {
    _totalReadings = 0;
    _outliersRejected = 0;
    _multipathDetected = 0;
    _brushChanges = 0;
    _avgAccuracy = 0.0;
    _avgSpeed = 0.0;
    _windowSizeSum = 0;
  }
}

/// Caché para operaciones matemáticas costosas
class MathCache {
  final Map<double, double> _sqrtCache = {};
  final Map<String, double> _powCache = {};
  static const int maxCacheSize = 100;

  double cachedSqrt(double value) {
    // Redondear a 2 decimales para mejorar hit rate del caché
    final key = (value * 100).round() / 100;
    if (!_sqrtCache.containsKey(key)) {
      if (_sqrtCache.length >= maxCacheSize) {
        _sqrtCache.remove(_sqrtCache.keys.first);
      }
      _sqrtCache[key] = sqrt(value);
    }
    return _sqrtCache[key]!;
  }

  double cachedPow(double base, double exponent) {
    final key = '${base.toStringAsFixed(2)}_${exponent.toStringAsFixed(0)}';
    if (!_powCache.containsKey(key)) {
      if (_powCache.length >= maxCacheSize) {
        _powCache.remove(_powCache.keys.first);
      }
      _powCache[key] = pow(base, exponent).toDouble();
    }
    return _powCache[key]!;
  }

  void clear() {
    _sqrtCache.clear();
    _powCache.clear();
  }
}

/// Manager SQLite - Wrapper para usar el singleton global
/// TODA la app debe usar globalDb para evitar locks de base de datos
class DatabaseManager {
  /// Ejecutar operación SQLite usando el singleton global
  static Future<T> executeOperation<T>(
      Future<T> Function(Database) operation) async {
    // Asegurar que la tabla existe antes de operar
    await globalDb.ensureLocationTrackingTable();
    return await globalDb.executeOperation(operation);
  }
}

/// Sistema principal mejorado
Future<void> getLocationList(BuildContext context) async {
  if (!Platforms.isMobile) return; // GPS/sensores no disponibles en desktop
  debugPrint('=== Sistema de Geolocalización Mejorado Iniciado ===');

  // GPS debe mantenerse activo SIEMPRE en segundo plano
  // NO hacer cleanup cuando el usuario navega - solo cuando la app se cierra completamente

  // Inicialización de componentes optimizados con UKF
  final ukf = UnscentedKalmanFilter(); // ← NUEVO: UKF reemplaza filterState
  final movementDetector = MovementDetector();
  final multipathDetector = MultipathDetector();
  final imuIntegrator = IMUIntegrator();
  final utmCache = UTMCache();
  final batteryCache = BatteryCache();
  final stateThrottler = StateUpdateThrottler();
  final mathCache = MathCache();
  final periodicLogger = PeriodicLogger(); // ← Sistema de logging resumido

  // Contador de rechazos consecutivos
  int consecutiveRejects = 0;

  // Ventanas para filtrado estadístico (post-procesamiento)
  final xWindow = Queue<double>();
  final yWindow = Queue<double>();
  final altWindow = Queue<double>();
  final speedWindow = Queue<double>();

  // Variables para sincronización de sensores
  DateTime? lastSensorUpdate;
  DateTime? lastGPSUpdate;
  AccelerometerEvent? lastAccelEvent;
  GyroscopeEvent? lastGyroEvent;

  // Configuración del acelerómetro con frecuencia reducida (200ms)
  _accelSubscription = accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 200))
      .listen((event) {
    lastAccelEvent = event;
    movementDetector.updateAccelerometer(event);
  });

  // Configuración del giroscopio para orientación
  _gyroSubscription =
      gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 200))
          .listen((event) {
    lastGyroEvent = event;

    // Actualizar IMU solo si tenemos ambos sensores
    if (lastAccelEvent != null && lastSensorUpdate != null) {
      final now = DateTime.now();
      final dt = now.difference(lastSensorUpdate!).inMilliseconds / 1000.0;

      if (dt > 0 && dt < 1.0) {
        // Actualizar orientación
        imuIntegrator.updateOrientation(event, dt);

        // Actualizar posición con ambos sensores
        imuIntegrator.updatePosition(
          lastAccelEvent!,
          event,
          dt,
          !movementDetector.isCurrentlyStatic(),
          movementDetector.isCurrentlyStatic(),
        );

        // Detectar cambios bruscos para ventana adaptativa
        imuIntegrator.detectBrushChange();
      }

      lastSensorUpdate = now;
    } else {
      lastSensorUpdate ??= DateTime.now();
    }
  });

  // Verificación de permisos mejorada
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await _accelSubscription?.cancel();
      throw Exception('Permisos de ubicación requeridos');
    }
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    await _accelSubscription?.cancel();
    throw Exception('Servicios de ubicación deshabilitados');
  }

  // Configuración optimizada por plataforma
  late LocationSettings settings;
  if (defaultTargetPlatform == TargetPlatform.android) {
    settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter:
          0, // 0 = recibir actualizaciones continuas sin importar movimiento
      intervalDuration: const Duration(milliseconds: 1500), // Cada 1.5 segundos
      forceLocationManager: false,
    );
    debugPrint('📱 Android GPS config: distanceFilter=0m, interval=1500ms');
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    settings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // 0 = recibir actualizaciones continuas
      pauseLocationUpdatesAutomatically: false,
      activityType: ActivityType.fitness,
      showBackgroundLocationIndicator: false,
      allowBackgroundLocationUpdates: false,
    );
    debugPrint('📱 iOS GPS config: distanceFilter=0m');
  } else {
    settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // 0 = recibir actualizaciones continuas
    );
    debugPrint('📱 Otro GPS config: distanceFilter=0m');
  }

  final startTime = DateTime.now();
  bool isWarmedUp = false;
  bool isStabilized = false;

  debugPrint('🚀 Iniciando stream de posiciones...');
  debugPrint(
      '   Configuración: accuracy=${settings.accuracy}, distanceFilter=${settings.distanceFilter}m');

  _locationSubscription =
      Geolocator.getPositionStream(locationSettings: settings).listen(
    (position) async {
      final elapsed = DateTime.now().difference(startTime).inSeconds;

      // Debug: Coordenadas originales de Geolocator (SILENCIADO - funcionando correctamente)
      // debugPrint(
      // '📍 GPS RAW: lat=${position.latitude.toStringAsFixed(6)}, lon=${position.longitude.toStringAsFixed(6)}, acc=${position.accuracy.toStringAsFixed(1)}m, speed=${position.speed.toStringAsFixed(2)}m/s, elapsed=${elapsed}s');

      // Validación inicial con caché UTM (usando UKF)
      if (!PositionValidator.isValidPosition(
          position, ukf, movementDetector, utmCache, lastGPSUpdate)) {
        consecutiveRejects++;
        debugPrint(
            '❌ Posición rechazada - consecutivos: $consecutiveRejects, acc=${position.accuracy.toStringAsFixed(1)}m');

        if (consecutiveRejects > LocationConfig.maxConsecutiveRejects) {
          debugPrint('Demasiados rechazos consecutivos, reiniciando UKF');
          consecutiveRejects = 0;
          // Incrementar incertidumbre del UKF para aceptar próximas mediciones
          ukf.increaseUncertainty(2.0);
        }
        return;
      }

      consecutiveRejects = 0;
      lastGPSUpdate = DateTime.now();
      // debugPrint('✅ Posición aceptada (acc=${position.accuracy.toStringAsFixed(1)}m)'); // SILENCIADO - funcionando correctamente

      // Forzar límites de memoria en ventanas
      while (xWindow.length >= LocationConfig.medianWindowSize) {
        xWindow.removeFirst();
      }
      while (yWindow.length >= LocationConfig.medianWindowSize) {
        yWindow.removeFirst();
      }

      // Período de warm-up mejorado
      if (elapsed < LocationConfig.warmupSeconds) {
        // debugPrint('⏳ Warm-up: ${elapsed}s/${LocationConfig.warmupSeconds}s'); // SILENCIADO - logging excesivo
        return;
      }

      if (!isWarmedUp) {
        isWarmedUp = true;
        xWindow.clear();
        yWindow.clear();
        altWindow.clear();
        speedWindow.clear();
        // debugPrint('Warm-up completado, reiniciando ventanas'); // SILENCIADO - logging excesivo
      }

      // Período de estabilización
      if (elapsed >= LocationConfig.warmupSeconds &&
          elapsed <
              LocationConfig.warmupSeconds +
                  LocationConfig.stabilizationSeconds &&
          !isStabilized) {
        // debugPrint(
        //     'Estabilización: ${elapsed - LocationConfig.warmupSeconds}s/${LocationConfig.stabilizationSeconds}s'); // SILENCIADO - logging excesivo
      }

      // Marcar como estabilizado una vez que pase el tiempo total
      if (elapsed >=
              LocationConfig.warmupSeconds +
                  LocationConfig.stabilizationSeconds &&
          !isStabilized) {
        isStabilized = true;
        FFAppState().isStabilized = true;
        if (context.mounted) {
          _notifyUIUpdate(context);
        }
        debugPrint(
            '✅ Sistema estabilizado después de ${elapsed}s - Comenzando a agregar estructuras');
      }

      // Conversión a UTM usando caché (evita doble conversión)
      final ptUtm = utmCache.toUTM(position.latitude, position.longitude);
      if (ptUtm == null) {
        debugPrint('⚠️ Error en conversión UTM');
        return;
      }

      final measX = ptUtm.x;
      final measY = ptUtm.y;
      final measAlt = position.altitude;

      // Detectar multipath y ajustar ruido de medición
      final isMultipath =
          multipathDetector.isLikelyMultipath(position, movementDetector);
      final multipathPenalty = multipathDetector.getMultipathPenalty();

      // Ruido base ajustado por HDOP
      final baseAccuracy = HDOPCorrector.adjustAccuracyByDOP(position);

      // Aplicar penalización por multipath (aumenta el ruido = menos confianza)
      final adjustedAccuracy = baseAccuracy * multipathPenalty;
      final measNoise = mathCache.cachedPow(adjustedAccuracy, 2);

      if (isMultipath) {
        debugPrint(
            '⚠️ Posición con multipath: accuracy ajustada ${baseAccuracy.toStringAsFixed(1)}m → ${adjustedAccuracy.toStringAsFixed(1)}m (penalty=${multipathPenalty.toStringAsFixed(2)}x)');
      }

      // ============================================
      // UNSCENTED KALMAN FILTER (UKF) + IMU FUSION
      // ============================================

      // Inicializar UKF con primera lectura GPS válida (evita valores absurdos)
      if (ukf.state[0] == 0.0 && ukf.state[1] == 0.0) {
        ukf.state[0] = measX;
        ukf.state[1] = measY;
        debugPrint(
            '🎬 UKF inicializado en primera posición GPS: (${measX.toStringAsFixed(2)}, ${measY.toStringAsFixed(2)})');
      }

      // Obtener aceleración IMU en marco de referencia mundial (si disponible)
      Vector3? imuAccel = lastAccelEvent != null
          ? imuIntegrator.getWorldAcceleration(lastAccelEvent!)
          : null;

      // Calcular ruido de proceso adaptativo según estado de movimiento
      final ukfPos = ukf.getPosition();
      final currentSpeed = ukfPos['speed'] ?? position.speed;
      final currentAccel = ukfPos['acceleration'] ?? 0.0;
      final processNoise = AdaptiveProcessNoise.calculate(
          currentSpeed, currentAccel, movementDetector.isCurrentlyStatic());

      // SILENCIADO - Ahora se muestra en resumen cada 10s
      // debugPrint(
      //     '🎯 UKF - Ruido adaptativo: ${processNoise.toStringAsFixed(6)} (speed=${currentSpeed.toStringAsFixed(2)}m/s, accel=${currentAccel.toStringAsFixed(2)}m/s², static=${movementDetector.isCurrentlyStatic()})');

      // PASO 1: Predicción UKF (propagación de sigma points)
      ukf.predict(1.5, processNoise); // dt=1.5s (intervalo GPS típico)

      // PASO 2: Actualización UKF con medición GPS + aceleración IMU
      ukf.update(measX, measY, measNoise, imuAccel);

      // Obtener estado filtrado por UKF
      final ukfState = ukf.getPosition();
      final ukfX = ukfState['x']!;
      final ukfY = ukfState['y']!;
      final ukfSpeed = ukfState['speed']!;

      // SILENCIADO - Ahora se muestra en resumen cada 10s
      // debugPrint(
      //     '🔄 UKF Fusion: GPS=(${measX.toStringAsFixed(2)},${measY.toStringAsFixed(2)}) → UKF=(${ukfX.toStringAsFixed(2)},${ukfY.toStringAsFixed(2)}) speed=${ukfSpeed.toStringAsFixed(2)}m/s');

      // Sincronizar IMU con salida del UKF (corregir deriva)
      final gpsHeading = position.heading * (pi / 180.0);
      imuIntegrator.syncWithGPS(ukfX, ukfY, ukfSpeed, gpsHeading);

      // Filtrado por ventana deslizante mejorado (post-procesamiento con mediana)
      void addToWindow(Queue<double> window, double value, int maxSize) {
        window.addLast(value);
        if (window.length > maxSize) window.removeFirst();
      }

      addToWindow(xWindow, ukfX, LocationConfig.medianWindowSize);
      addToWindow(yWindow, ukfY, LocationConfig.medianWindowSize);
      addToWindow(altWindow, measAlt, LocationConfig.medianWindowSize);
      addToWindow(speedWindow, ukfSpeed, LocationConfig.medianWindowSize);

      // Calcular mediana simple con soporte para ventana adaptativa
      double getMedian(Queue<double> window, {int? customSize}) {
        if (window.isEmpty) return 0.0;

        // Usar tamaño personalizado (últimos N elementos) o toda la ventana
        final elementsToUse = customSize != null && customSize < window.length
            ? window.toList().sublist(window.length - customSize)
            : window.toList();

        elementsToUse.sort();
        final len = elementsToUse.length;

        if (len == 1) return elementsToUse[0];

        // Mediana pura
        final medianIndex = len ~/ 2;
        if (len.isOdd) {
          return elementsToUse[medianIndex];
        } else {
          return (elementsToUse[medianIndex - 1] + elementsToUse[medianIndex]) /
              2;
        }
      }

      // Ventana adaptativa: reduce tamaño cuando hay cambios bruscos
      final adaptiveWindowSize = imuIntegrator.isBrushChange
          ? 5 // Cambio brusco detectado → ventana pequeña (5 × 1.5s = 7.5s) para respuesta rápida
          : LocationConfig
              .medianWindowSize; // Normal → ventana completa (12 × 1.5s = 18s) para filtrado óptimo

      final filteredX = getMedian(xWindow, customSize: adaptiveWindowSize);
      final filteredY = getMedian(yWindow, customSize: adaptiveWindowSize);
      final filteredAlt = getMedian(altWindow, customSize: adaptiveWindowSize);
      final filteredSpeed =
          getMedian(speedWindow, customSize: adaptiveWindowSize);

      // Estimación de error mejorada usando UKF
      final baseError = ukf.getPositionError();
      final speedFactor = filteredSpeed > 1.0 ? 1 + (filteredSpeed / 10) : 1.0;
      final movementFactor = movementDetector.isCurrentlyStatic() ? 0.8 : 1.2;
      final finalError = max(
          baseError * speedFactor * movementFactor, position.accuracy * 0.7);

      // Registrar métricas para logging resumido
      periodicLogger.recordReading(
        isOutlier: false, // Esta lectura ya pasó validación
        isMultipath: isMultipath,
        isBrushChange: imuIntegrator.isBrushChange,
        accuracy: finalError,
        speed: filteredSpeed,
        windowSize: adaptiveWindowSize,
      );

      // Imprimir resumen cada 10 segundos
      periodicLogger.shouldLog();

      // Conversión de vuelta a coordenadas geográficas usando caché
      final filteredGeo = utmCache.toGeo(filteredX, filteredY);
      if (filteredGeo == null) {
        debugPrint('⚠️ Error en conversión inversa UTM');
        return;
      }

      // Debug: Coordenadas finales procesadas
      // debugPrint(
      // '🎯 PROCESSED FINAL: lat=${filteredGeo.y.toStringAsFixed(8)}, lon=${filteredGeo.x.toStringAsFixed(8)}, alt=${filteredAlt.toStringAsFixed(2)}m, err=${finalError.toStringAsFixed(2)}m, speed=${filteredSpeed.toStringAsFixed(2)}m/s, static=${movementDetector.isCurrentlyStatic()}');

      //debugPrint('Posición procesada: lat=${filteredGeo.y.toStringAsFixed(8)}, '
      //'lon=${filteredGeo.x.toStringAsFixed(8)}, '
      //'alt=${filteredAlt.toStringAsFixed(2)}, '
      //'err=${finalError.toStringAsFixed(2)}, '
      //'speed=${filteredSpeed.toStringAsFixed(2)}, '
      //'static=${movementDetector.isCurrentlyStatic()}');

      // Crear estructura solo si el sistema está estabilizado
      if (isStabilized) {
        final geoStruct = createReadGeoStruct(
          latitude: filteredGeo.y,
          longitude: filteredGeo.x,
          altitude: filteredAlt,
          errorHorizontal: finalError,
          dateHourRead: DateTime.now(),
        );

        // Alimentar buffer enriquecido con datos completos del UKF/IMU
        EnrichedGeoBuffer().add(EnrichedGeoPoint(
          latitude: filteredGeo.y,
          longitude: filteredGeo.x,
          altitude: filteredAlt,
          errorHorizontal: finalError,
          timestamp: DateTime.now(),
          speed: filteredSpeed,
          heading: gpsHeading,
          acceleration: currentAccel,
          isStatic: movementDetector.isCurrentlyStatic(),
          vx: ukfState['vx']!,
          vy: ukfState['vy']!,
          ukfPositionError: baseError,
          isBrushChange: imuIntegrator.isBrushChange,
        ));

        // NUEVA OPTIMIZACION CON SQFLITE DIRECTAMENTE
        // Configuración: Insertar cada 1 minuto (60 segundos / 1.5 segundos por lectura = ~40 registros)
        const int maxBatchSize = 40; // Registros antes de guardar (~1 minuto)
        const int recentToKeep =
            30; // Registros a mantener en memoria (últimas 30 ≈ 45 segundos de historial)

        // Obtener la lista actual del estado
        List<ReadGeoStruct> currentList =
            List.from(FFAppState().geoLocationsList);
        // Agregar la nueva localización
        currentList.add(geoStruct);

        // debugPrint('📊 AppState: ${currentList.length} registros en memoria'); // SILENCIADO - funcionando correctamente

        // Verificar si necesitamos guardar en SQLite
        if (currentList.length >= maxBatchSize + recentToKeep) {
          try {
            // Calcular cuántos registros guardar
            int recordsToSave = currentList.length - recentToKeep;

            // Separar registros a guardar y a mantener
            List<ReadGeoStruct> toSave = currentList.sublist(0, recordsToSave);
            List<ReadGeoStruct> toKeep = currentList.sublist(recordsToSave);

            // Obtener nivel de batería desde caché (se actualiza cada minuto)
            final batteryLevel = await batteryCache.getBatteryLevel();

            // Depurar geolocalizaciones antes de insertar (agrupar puntos dentro de 2m)
            final depurados = depurarGeolocalizaciones(toSave, filteredSpeed, batteryLevel);

            // Ejecutar operación SQLite asíncrona (sin bloqueo)
            await DatabaseManager.executeOperation<void>((database) async {
              final Batch batch = database.batch();

              for (final loc in depurados) {
                batch.rawInsert('''
                INSERT OR IGNORE INTO Location_tracking
                (Id_company, Imei, Latitude, Longitude, Altitude, HorizontalError,
                 Speed, Battery, CreatedAt, SyncedAt, batch_id,
                 date_start, date_finish, evaluated_radius, point_count,
                 Id_user, Id_activity, Method)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                  loc['Method'] ?? 'UNKNOWN',
                ]);
              }

              final results = await batch.commit(noResult: false);
              int insertedCount =
                  results.whereType<int>().where((id) => id > 0).length;
              debugPrint(
                  '💾 $insertedCount/${depurados.length} registros depurados insertados en SQLite (de ${toSave.length} puntos originales)');
            });

            // Actualizar el estado con solo los registros recientes (con throttling)
            if (stateThrottler.shouldUpdate()) {
              FFAppState().update(() {
                FFAppState().geoLocationsList = toKeep;
              });
              // debugPrint(
              //     '🔄 AppState actualizado con notificación UI: ${toKeep.length} registros mantenidos'); // SILENCIADO - logging excesivo
            } else {
              // Actualizar sin notificar UI
              FFAppState().geoLocationsList = toKeep;
              // debugPrint(
              //     '🔄 AppState actualizado (sin UI): ${toKeep.length} registros mantenidos'); // SILENCIADO - logging excesivo
            }
          } catch (e) {
            debugPrint('❌ Error guardando en SQLite: $e');
            // En caso de error, mantener la lista completa
            FFAppState().geoLocationsList = currentList;
          }
        } else {
          // Si no alcanza el límite, actualizar sin notificar UI frecuentemente
          if (stateThrottler.shouldUpdate()) {
            FFAppState().update(() {
              FFAppState().geoLocationsList = currentList;
            });
            // debugPrint('✏️ AppState actualizado (< ${maxBatchSize + recentToKeep} registros): ${currentList.length} en memoria'); // SILENCIADO - funcionando correctamente
          } else {
            // Actualizar sin notificar UI
            FFAppState().geoLocationsList = currentList;
            // No log aquí para no saturar (ocurre cada 1.5s)
          }
        }
      } else {
        // debugPrint(
        //     '⏳ Sistema aún no estabilizado (${elapsed}s/${LocationConfig.warmupSeconds + LocationConfig.stabilizationSeconds}s)'); // SILENCIADO - logging excesivo
      }
    },
    onError: (error) {
      debugPrint('❌ Error en stream de posiciones: $error');
    },
    onDone: () {
      debugPrint('⚠️ Stream de posiciones finalizado');
    },
    cancelOnError: false,
  );

  debugPrint('✅ Listener de posiciones GPS registrado correctamente');
}

// ============================================================================
// DEPURACIÓN DE GEOLOCALIZACIONES (agrupación por proximidad de 2m)
// ============================================================================

/// Depura geolocalizaciones agrupando puntos dentro de un radio de 2 metros.
/// Produce registros consolidados con centroide, radio evaluado y conteo de puntos.
/// Pública para que main.dart pueda usarla en el timer de persistencia global.
List<Map<String, dynamic>> depurarGeolocalizaciones(
    List<ReadGeoStruct> locations, double speed, int battery) {
  if (locations.isEmpty) return [];

  if (locations.length == 1) {
    return [_crearRegistroDepurado([locations.first], speed, battery)];
  }

  const double radioUmbral = 2.0; // metros
  final List<Map<String, dynamic>> resultado = [];

  // Ordenar por fecha
  final sortedLocations = List<ReadGeoStruct>.from(locations)
    ..sort((a, b) => (a.dateHourRead ?? DateTime.now())
        .compareTo(b.dateHourRead ?? DateTime.now()));

  // Agrupar puntos consecutivos dentro del radio umbral
  List<ReadGeoStruct> grupoActual = [sortedLocations.first];

  for (int i = 1; i < sortedLocations.length; i++) {
    final puntoActual = sortedLocations[i];
    final centroide = _calcularCentroide(grupoActual);

    final distancia = _haversineDistanceDepuracion(
      centroide['lat']!, centroide['lon']!,
      puntoActual.latitude, puntoActual.longitude,
    );

    if (distancia <= radioUmbral) {
      grupoActual.add(puntoActual);
    } else {
      resultado.add(_crearRegistroDepurado(grupoActual, speed, battery));
      grupoActual = [puntoActual];
    }
  }

  if (grupoActual.isNotEmpty) {
    resultado.add(_crearRegistroDepurado(grupoActual, speed, battery));
  }

  return resultado;
}

Map<String, double> _calcularCentroide(List<ReadGeoStruct> puntos) {
  double sumLat = 0, sumLon = 0;
  for (final p in puntos) {
    sumLat += p.latitude;
    sumLon += p.longitude;
  }
  return {'lat': sumLat / puntos.length, 'lon': sumLon / puntos.length};
}

Map<String, dynamic> _crearRegistroDepurado(
    List<ReadGeoStruct> grupo, double speed, int battery) {
  final centroide = _calcularCentroide(grupo);
  final int count = grupo.length;

  double sumAlt = 0, sumErr = 0;
  for (final p in grupo) {
    sumAlt += p.altitude;
    sumErr += p.errorHorizontal;
  }

  // Radio máximo: distancia del centroide al punto más lejano
  double maxRadius = 0.0;
  for (final p in grupo) {
    final dist = _haversineDistanceDepuracion(
      centroide['lat']!, centroide['lon']!, p.latitude, p.longitude,
    );
    if (dist > maxRadius) maxRadius = dist;
  }

  final dateStart = grupo.first.dateHourRead ?? DateTime.now();
  final dateFinish = grupo.last.dateHourRead ?? DateTime.now();

  // Método GPS del grupo: si todos coinciden usar ese, si no 'MIXED'.
  final methods = grupo.map((p) => p.method).toSet();
  final groupMethod = methods.length == 1 ? methods.first : 'MIXED';

  return {
    'Id_company': FFAppState().companyDefault.idCompany,
    'Imei': FFAppState().deviceDefault.imeI1,
    'Latitude': centroide['lat'],
    'Longitude': centroide['lon'],
    'Altitude': sumAlt / count,
    'HorizontalError': sumErr / count,
    'Speed': speed,
    'Battery': battery,
    'CreatedAt': dateStart.toIso8601String(),
    'SyncedAt': DateTime.now().toIso8601String(),
    'batch_id': null,
    'date_start': dateStart.toIso8601String(),
    'date_finish': dateFinish.toIso8601String(),
    'evaluated_radius': maxRadius,
    'point_count': count,
    'Id_user': FFAppState().userSelected.idUser != 0
        ? FFAppState().userSelected.idUser
        : null,
    'Id_activity': FFAppState().activitySelected.idActivity != 0
        ? FFAppState().activitySelected.idActivity
        : null,
    'Method': groupMethod,
  };
}

double _haversineDistanceDepuracion(
    double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371000.0;
  final double lat1Rad = lat1 * pi / 180;
  final double lat2Rad = lat2 * pi / 180;
  final double dLat = (lat2 - lat1) * pi / 180;
  final double dLon = (lon2 - lon1) * pi / 180;
  final double a = (sin(dLat / 2) * sin(dLat / 2)) +
      (cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2));
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

/// Obtener ruta de la base de datos usando el mismo patrón de los otros archivos
Future<String> _getDatabasePathSqflite() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}

/// Asegurar que la tabla Location_tracking existe
Future<void> _ensureLocationTrackingTableExists(Database database) async {
  try {
    // Verificar si la tabla Location_tracking existe
    final List<Map<String, dynamic>> tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Location_tracking';");

    if (tables.isEmpty) {
      // Crear la tabla Location_tracking si no existe (compatible con sync_visitsv2.dart)
      await database.execute('''
        CREATE TABLE IF NOT EXISTS Location_tracking (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          Id_company INTEGER NOT NULL DEFAULT 0,
          Imei TEXT NOT NULL DEFAULT '',
          Latitude DECIMAL(10,8) NOT NULL,
          Longitude DECIMAL(11,8) NOT NULL,
          Altitude DECIMAL(8,2) NOT NULL DEFAULT 0,
          HorizontalError DECIMAL(8,2) NOT NULL DEFAULT 0,
          Speed DECIMAL(8,2) NOT NULL DEFAULT 0,
          Battery INTEGER NOT NULL DEFAULT 0,
          CreatedAt DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
          SyncedAt DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
          batch_id TEXT
        );
      ''');

      // Crear índices para optimizar consultas
      await database.execute(
          'CREATE INDEX IF NOT EXISTS IX_Location_tracking_CreatedAt ON Location_tracking(CreatedAt);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS IX_Location_tracking_coordinates ON Location_tracking(Latitude, Longitude);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS IX_Location_tracking_Id_company ON Location_tracking(Id_company);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS IX_Location_tracking_Imei ON Location_tracking(Imei);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS IX_Location_tracking_batch_id ON Location_tracking(batch_id);');

      // Crear índice UNIQUE para prevenir duplicados por fecha/hora
      await database.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS UX_Location_tracking_CreatedAt ON Location_tracking(CreatedAt);');

      debugPrint(
          '✅ Tabla Location_tracking creada con índices (incluido UNIQUE en CreatedAt)');
    }
  } catch (e) {
    debugPrint('❌ Error verificando/creando tabla Location_tracking: $e');
    rethrow;
  }
}

/// Función de limpieza mejorada
Future<void> stopLocationUpdates(BuildContext context) async {
  if (!Platforms.isMobile) return; // GPS/sensores no disponibles en desktop
  debugPrint('Deteniendo actualizaciones de ubicación...');

  await _locationSubscription?.cancel();
  _locationSubscription = null;

  await _accelSubscription?.cancel();
  _accelSubscription = null;

  await _gyroSubscription?.cancel();
  _gyroSubscription = null;

  // No es necesario cerrar la base de datos - cada operación la abre y cierra automáticamente

  FFAppState().isStabilized = false;

  if (context.mounted) {
    _notifyUIUpdate(context);
  }

  debugPrint(
      'Limpieza completada - GPS, Acelerómetro, Giroscopio desconectados');
}

void _notifyUIUpdate(BuildContext context) {
  if (context.mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        (context as Element).markNeedsBuild();
      }
    });
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
