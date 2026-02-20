// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// ============================================================================
// MODELO DE DATOS PARA ESTADÍSTICAS Y RESUMEN COMPLETO
// ============================================================================

class VisitSummary {
  int idVisit;
  int idCompany;
  int idActivity;
  int idHeadquarter;
  String createdAt;
  int detailsCount;
  int locationsCount;
  List<Map<String, dynamic>> details;
  List<String> locations;

  VisitSummary({
    required this.idVisit,
    required this.idCompany,
    required this.idActivity,
    required this.idHeadquarter,
    required this.createdAt,
    required this.detailsCount,
    required this.locationsCount,
    required this.details,
    required this.locations,
  });
}

class ExclusionZoneSummary {
  int idHistory;
  int? idPolygonCoordinate;
  int? idVirtualPoint;
  int? lineNumber;
  int? pointNumber;
  String? previousTypeName;
  String? newTypeName;
  String modifiedAt;

  // Datos relacionados
  String? polygonCoordinateInfo;
  String? virtualPointInfo;

  ExclusionZoneSummary({
    required this.idHistory,
    this.idPolygonCoordinate,
    this.idVirtualPoint,
    this.lineNumber,
    this.pointNumber,
    this.previousTypeName,
    this.newTypeName,
    required this.modifiedAt,
    this.polygonCoordinateInfo,
    this.virtualPointInfo,
  });
}

class ProductSummary {
  int idProduct;
  int idHeadquarter;
  int idCompany;
  String? nameProduct;
  String? typeProduct;
  String? rfid;
  String? stateProduct;
  String? descriptionProduct;
  int? line;
  int? palm;
  String syncStatus; // 'new' o 'updated'
  String? createdAt;
  String? modifiedAt;
  String? locationRaw; // Coordenada del producto en formato "lat,lon"
  List<Map<String, dynamic>>? coordinates; // Coordenadas adicionales de Products_coordinates

  ProductSummary({
    required this.idProduct,
    required this.idHeadquarter,
    required this.idCompany,
    this.nameProduct,
    this.typeProduct,
    this.rfid,
    this.stateProduct,
    this.descriptionProduct,
    this.line,
    this.palm,
    required this.syncStatus,
    this.createdAt,
    this.modifiedAt,
    this.locationRaw,
    this.coordinates,
  });
}

class SyncStatistics {
  int totalVisits = 0;
  int totalExclusionZones = 0;
  int totalLocations = 0;
  int totalNewsAdd = 0;
  int totalVisitDetails = 0;
  int totalVisitLocations = 0;

  // Productos pendientes de sincronización
  int totalProductsNew = 0;
  int totalProductsUpdated = 0;

  bool hasInternetConnection = false;
  bool hasPendingExclusions = false;
  bool hasPendingProducts = false;

  List<Map<String, dynamic>> exclusionModifications = [];
  List<VisitSummary> visitsSummary = [];
  List<ExclusionZoneSummary> exclusionsSummary = [];
  List<Map<String, dynamic>> newsAddSummary = [];
  List<ProductSummary> productsSummary = [];

  SyncStatistics();

  // Método para obtener el total de items a sincronizar
  int getTotalItems() {
    return totalVisits + totalExclusionZones + totalNewsAdd + totalProductsNew + totalProductsUpdated;
  }

  // Método para verificar si hay datos para sincronizar
  bool hasDataToSync() {
    return totalVisits > 0 || totalExclusionZones > 0 || totalNewsAdd > 0 ||
           totalProductsNew > 0 || totalProductsUpdated > 0;
  }

  // Total de productos pendientes
  int getTotalPendingProducts() {
    return totalProductsNew + totalProductsUpdated;
  }
}

// ============================================================================
// ENUM PARA ESTADOS DE SINCRONIZACIÓN
// ============================================================================

enum SyncStep {
  initial,
  checkingConnection,
  collectingData,
  analyzingExclusions,
  sendingExclusions,
  sendingProducts,
  sendingVisits,
  completed,
  error,
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class SyncVisitsForm extends StatefulWidget {
  const SyncVisitsForm({
    super.key,
    this.width,
    this.height,
    required this.newsAdd,
    required this.idCompany,
    required this.idsHeadquarters,
    required this.imei,
    required this.authToken,
  });

  final double? width;
  final double? height;
  final List<VisitsNewsStruct> newsAdd;
  final int idCompany;
  final String idsHeadquarters;
  final String imei;
  final String authToken;

  @override
  State<SyncVisitsForm> createState() => _SyncVisitsFormState();
}

class _SyncVisitsFormState extends State<SyncVisitsForm>
    with SingleTickerProviderStateMixin {
  // Estado
  SyncStep _currentStep = SyncStep.initial;
  SyncStatistics _stats = SyncStatistics();
  String _currentMessage = '';
  bool _isProcessing = false;
  double _progress = 0.0;
  bool _isLoadingInitialData = true;

  // Animación
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoadingInitialData = true;
      });

      // Cargar datos inmediatamente al abrir la vista
      await _collectSyncData();
      await _analyzeExclusionZones();
      await _collectProductsData();

      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
        });
      }

      debugPrint('✅ Datos iniciales cargados para vista previa');
    } catch (e) {
      debugPrint('⚠️ Error cargando datos iniciales: $e');
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
        });
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MÉTODOS PRINCIPALES DE SINCRONIZACIÓN
  // ==========================================================================

  Future<void> _startSyncProcess() async {
    setState(() {
      _isProcessing = true;
      _currentStep = SyncStep.checkingConnection;
      _currentMessage = 'Verificando la conexión a internet';
      _progress = 0.1;
    });

    try {
      // 1. Verificar conexión a Internet
      _stats.hasInternetConnection = await _checkInternetConnection();
      if (!_stats.hasInternetConnection) {
        throw Exception('No hay conexión a Internet disponible');
      }

      await Future.delayed(Duration(milliseconds: 800));

      // 2. Recolectar datos y estadísticas
      setState(() {
        _currentStep = SyncStep.collectingData;
        _currentMessage = 'Preparando información para enviar';
        _progress = 0.2;
      });

      await _collectSyncData();
      await Future.delayed(Duration(milliseconds: 800));

      // 3. Analizar zonas de exclusión modificadas
      setState(() {
        _currentStep = SyncStep.analyzingExclusions;
        _currentMessage = 'Verificando cambios en zonas de exclusión';
        _progress = 0.4;
      });

      await _analyzeExclusionZones();
      await Future.delayed(Duration(milliseconds: 800));

      // 4. Sincronizar zonas de exclusión si hay cambios
      if (_stats.hasPendingExclusions) {
        setState(() {
          _currentStep = SyncStep.sendingExclusions;
          _currentMessage =
              'Enviando ${_stats.totalExclusionZones} zonas de exclusión';
          _progress = 0.5;
        });

        await _syncExclusionZones();
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 4.5. Recolectar y sincronizar productos pendientes
      await _collectProductsData();

      if (_stats.hasPendingProducts) {
        setState(() {
          _currentStep = SyncStep.sendingProducts;
          _currentMessage =
              'Enviando ${_stats.getTotalPendingProducts()} productos (${_stats.totalProductsNew} nuevos, ${_stats.totalProductsUpdated} actualizados)';
          _progress = 0.65;
        });

        await _syncProducts();
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 5. Sincronizar visitas
      setState(() {
        _currentStep = SyncStep.sendingVisits;
        _currentMessage = 'Enviando ${_stats.totalVisits} visitas';
        _progress = 0.85;
      });

      bool success = await _syncVisits();

      if (success) {
        setState(() {
          _currentStep = SyncStep.completed;
          _currentMessage = 'Envío completado exitosamente';
          _progress = 1.0;
        });

        await Future.delayed(Duration(seconds: 2));
        _showSuccessDialog();
      } else {
        throw Exception('Error al sincronizar las visitas');
      }
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
      setState(() {
        _currentStep = SyncStep.error;
        _currentMessage = 'Error: ${e.toString()}';
        _progress = 0.0;
      });

      _showErrorDialog('Error al Enviar', e.toString());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      debugPrint(
          '🌐 Verificando calidad de conexión con checkInternetQuality...');

      // Llamar a la función checkInternetQuality personalizada
      final result = await checkInternetQuality();

      // Extraer los valores del resultado
      final String message =
          result['message'] as String? ?? 'Error desconocido';
      final bool isGoodConnection =
          result['isGoodConnection'] as bool? ?? false;

      debugPrint('📊 Resultado de checkInternetQuality:');
      debugPrint('   Mensaje: $message');
      debugPrint('   Es buena conexión: $isGoodConnection');

      // Actualizar el mensaje en la UI
      if (mounted) {
        setState(() {
          _currentMessage = message;
        });
      }

      // Si no es una buena conexión, mostrar advertencia al usuario
      if (!isGoodConnection) {
        debugPrint('⚠️ Conexión no apta para sincronización: $message');

        // Mostrar un diálogo de advertencia al usuario
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: FlutterFlowTheme.of(context).warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Conexión Inadecuada',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'El envío de información requiere una conexión estable. Puedes:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _buildAdviceItem(
                        '• Conectarte a una red WiFi',
                        Icons.wifi,
                      ),
                      _buildAdviceItem(
                        '• Acercarte a una zona con mejor señal',
                        Icons.signal_cellular_alt,
                      ),
                      _buildAdviceItem(
                        '• Intentar más tarde',
                        Icons.schedule,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .warning
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: FlutterFlowTheme.of(context).warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Puedes continuar bajo tu responsabilidad, pero puede fallar.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false); // Cancelar
                    },
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                          dialogContext, true); // Continuar de todos modos
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).warning,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Continuar de todos modos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ).then((shouldContinue) {
            if (shouldContinue != true) {
              // Usuario canceló, lanzar excepción para detener el proceso
              throw Exception('Envío cancelado por el usuario');
            }
          });
        }
      }

      return true; // Retornar true si llegó aquí (conexión buena o usuario decidió continuar)
    } catch (e) {
      debugPrint('❌ Error verificando conexión: $e');
      return false;
    }
  }

  Widget _buildAdviceItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: FlutterFlowTheme.of(context).primaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _collectSyncData() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // ===== OBTENER TODAS LAS VISITAS CON SUS RELACIONES =====
      debugPrint('🔍 Obteniendo TODAS las visitas con relaciones completas...');

      final List<Map<String, dynamic>> visitsRaw = await db.rawQuery('''
        SELECT
          v.Id_visit as id_visit,
          v.Id_company as id_company,
          v.Id_activity as id_activity,
          v.Id_headquarter as id_headquarter,
          v.Id_product as id_product,
          p.Rfid as rfid,
          v.Id_user as id_user,
          v.Id_device as id_device,
          v.Created_at as created_at,
          v.Latitude,
          v.Longitude,
          v.Altitude,
          v.Error_horizontal,

          vd.Id_visit_detail as detail_id,
          vd.Id_activity_status as detail_activity_status,
          vd.Status_option as detail_status_option,
          vd.Status_response as detail_status_response,

          vl.Id as location_id,
          vl.Latitude as location_latitude,
          vl.Longitude as location_longitude,
          vl.Altitude as location_altitude,
          vl.HorizontalError as location_horizontal_error
        FROM Visits v
        LEFT JOIN Products p ON v.Id_product = p.Id_product
        LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        LEFT JOIN Visits_locations vl ON v.Id_visit = vl.Id_visit
        WHERE v.Id_company = ?
        ORDER BY v.Created_at DESC, vd.Id_visit_detail ASC, vl.Id ASC
      ''', [widget.idCompany]);

      // Agrupar visitas con sus relaciones
      final Map<int, VisitSummary> visitsMap = {};
      int totalDetails = 0;
      int totalLocations = 0;

      for (final row in visitsRaw) {
        final int visitId = row['id_visit'];

        if (!visitsMap.containsKey(visitId)) {
          visitsMap[visitId] = VisitSummary(
            idVisit: visitId,
            idCompany: row['id_company'],
            idActivity: row['id_activity'],
            idHeadquarter: row['id_headquarter'],
            createdAt: row['created_at'],
            detailsCount: 0,
            locationsCount: 0,
            details: [],
            locations: [],
          );
        }

        final visit = visitsMap[visitId]!;

        // Agregar detalles
        if (row['detail_id'] != null) {
          final detailId = row['detail_id'];
          final exists = visit.details.any((d) => d['id'] == detailId);
          if (!exists) {
            visit.details.add({
              'id': detailId,
              'id_activity_status': row['detail_activity_status'],
              'status_option': row['detail_status_option'],
              'status_response': row['detail_status_response'],
            });
            visit.detailsCount++;
            totalDetails++;
          }
        }

        // Agregar locations
        if (row['location_id'] != null) {
          final locationId = row['location_id'];
          final locationString =
              'LAT:${row['location_latitude']};LON:${row['location_longitude']};ALT:${row['location_altitude']};ERH:${row['location_horizontal_error']}';
          if (!visit.locations.contains(locationString)) {
            visit.locations.add(locationString);
            visit.locationsCount++;
            totalLocations++;
          }
        }
      }

      _stats.visitsSummary = visitsMap.values.toList();
      _stats.totalVisits = _stats.visitsSummary.length;
      _stats.totalVisitDetails = totalDetails;
      _stats.totalVisitLocations = totalLocations;

      // ===== CONTAR LOCATION_TRACKING =====
      final locationsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Location_tracking',
      );
      _stats.totalLocations = locationsCount.first['count'] as int? ?? 0;

      // ===== PREPARAR NEWSADD SUMMARY =====
      _stats.newsAddSummary = widget.newsAdd.map((visitNews) {
        final map = visitNews.toMap();
        return {
          'id_new': map['id_new'] ?? map['idNew'] ?? 0,
          'descripcion': map['descripcion_new'] ?? map['descripcionNew'] ?? '',
          'locations_count':
              (map['locations_add'] ?? map['locationsAdd'] ?? []).length,
        };
      }).toList();
      _stats.totalNewsAdd = widget.newsAdd.length;

      await db.close();

      debugPrint('✅ Estadísticas COMPLETAS recolectadas:');
      debugPrint('   📋 Visitas: ${_stats.totalVisits}');
      debugPrint('      └─ Detalles totales: ${_stats.totalVisitDetails}');
      debugPrint(
          '      └─ Locations de visitas: ${_stats.totalVisitLocations}');
      debugPrint('   📍 Location_tracking: ${_stats.totalLocations}');
      debugPrint('   📰 NewsAdd: ${_stats.totalNewsAdd}');
      debugPrint('   🔢 TOTAL items a sincronizar: ${_stats.getTotalItems()}');
    } catch (e) {
      debugPrint('❌ Error recolectando datos: $e');
      rethrow;
    }
  }

  Future<void> _analyzeExclusionZones() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // ===== OBTENER TODAS LAS MODIFICACIONES CON RELACIONES =====
      debugPrint(
          '🔍 Obteniendo TODAS las zonas de exclusión con relaciones completas...');

      final List<Map<String, dynamic>> modificationsRaw = await db.rawQuery('''
        SELECT
          ezh.Id_history,
          ezh.Id_polygon_coordinate,
          ezh.Id_virtual_point,
          ezh.Line_number,
          ezh.Point_number,
          ezh.Previous_type_id,
          ezh.Previous_type_name,
          ezh.New_type_id,
          ezh.New_type_name,
          ezh.Modified_at,
          ezh.User_id,

          hc.Name_polygon_coordinate as polygon_name,
          hc.Coordinates_raw as polygon_coordinates,
          hc.Point_type as polygon_point_type,
          hc.Id_headquarter as polygon_id_headquarter,

          vp.Point_display_name as virtual_point_name,
          vp.Description_virtual_point as virtual_point_description,
          vp.Id_headquarter as virtual_point_id_headquarter,
          vp.Line_number as virtual_point_line,
          vp.Point_number as virtual_point_point,
          vp.Latitude as virtual_point_latitude,
          vp.Longitude as virtual_point_longitude

        FROM Exclusion_zones_history ezh
        LEFT JOIN Headquarters_coordinates hc
          ON ezh.Id_polygon_coordinate = hc.Id_polygon_coordinate
        LEFT JOIN Virtual_points vp
          ON ezh.Id_virtual_point = vp.Id_virtual_point
        ORDER BY ezh.Modified_at DESC
      ''');

      _stats.exclusionModifications = modificationsRaw;
      _stats.totalExclusionZones = modificationsRaw.length;
      _stats.hasPendingExclusions = modificationsRaw.isNotEmpty;

      // Crear resumen detallado
      _stats.exclusionsSummary = modificationsRaw.map((row) {
        String? polygonInfo;
        String? virtualInfo;

        // Información del polígono (Headquarters_coordinates)
        if (row['polygon_name'] != null || row['polygon_coordinates'] != null) {
          final name = row['polygon_name'] ?? 'Sin nombre';
          final type = row['polygon_point_type'] ?? 'N/A';
          final hq = row['polygon_id_headquarter'] ?? 'N/A';
          polygonInfo = '$name - Type:$type, HQ:$hq';
        }

        // Información del punto virtual
        if (row['virtual_point_name'] != null ||
            row['virtual_point_latitude'] != null) {
          final name = row['virtual_point_name'] ??
              row['virtual_point_description'] ??
              'Punto Virtual';
          final line = row['virtual_point_line'] ?? row['Line_number'] ?? 'N/A';
          final point =
              row['virtual_point_point'] ?? row['Point_number'] ?? 'N/A';
          final lat = row['virtual_point_latitude'];
          final lon = row['virtual_point_longitude'];
          final hq = row['virtual_point_id_headquarter'] ?? 'N/A';

          if (lat != null && lon != null) {
            virtualInfo =
                '$name (L:$line, P:$point, LAT:${lat.toStringAsFixed(6)}, LON:${lon.toStringAsFixed(6)}, HQ:$hq)';
          } else {
            virtualInfo = '$name (L:$line, P:$point, HQ:$hq)';
          }
        }

        return ExclusionZoneSummary(
          idHistory: row['Id_history'],
          idPolygonCoordinate: row['Id_polygon_coordinate'],
          idVirtualPoint: row['Id_virtual_point'],
          lineNumber: row['Line_number'],
          pointNumber: row['Point_number'],
          previousTypeName: row['Previous_type_name'],
          newTypeName: row['New_type_name'],
          modifiedAt: row['Modified_at'],
          polygonCoordinateInfo: polygonInfo,
          virtualPointInfo: virtualInfo,
        );
      }).toList();

      await db.close();

      debugPrint('✅ Zonas de exclusión COMPLETAS analizadas:');
      debugPrint('   📍 Total modificaciones: ${_stats.totalExclusionZones}');
      debugPrint('   🔔 Hay pendientes: ${_stats.hasPendingExclusions}');

      if (_stats.exclusionsSummary.isNotEmpty) {
        debugPrint('   📋 Ejemplos de modificaciones:');
        for (int i = 0; i < _stats.exclusionsSummary.length && i < 3; i++) {
          final exclusion = _stats.exclusionsSummary[i];
          debugPrint('      [$i] ${exclusion.previousTypeName ?? "N/A"} → '
              '${exclusion.newTypeName ?? "N/A"} '
              '(${exclusion.modifiedAt})');
          if (exclusion.polygonCoordinateInfo != null) {
            debugPrint('          Polygon: ${exclusion.polygonCoordinateInfo}');
          }
          if (exclusion.virtualPointInfo != null) {
            debugPrint('          Virtual: ${exclusion.virtualPointInfo}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error analizando exclusiones: $e');
      rethrow;
    }
  }

  /// Recolecta productos pendientes de sincronización (nuevos y actualizados)
  Future<void> _collectProductsData() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      debugPrint('🔍 Obteniendo productos pendientes de sincronización...');

      // Obtener productos con Sync_status = 'new' o 'updated'
      final List<Map<String, dynamic>> productsRaw = await db.rawQuery('''
        SELECT
          Id_product,
          Id_headquarter,
          Id_company,
          Id_type,
          Created_at,
          Modified_at,
          Type_product,
          Name_product,
          Rfid,
          State_product,
          Description_product,
          Location_raw,
          Line,
          Palm,
          Sync_status
        FROM Products
        WHERE Sync_status IN ('new', 'updated')
        ORDER BY Modified_at DESC
      ''');

      // Procesar resultados
      int newCount = 0;
      int updatedCount = 0;

      _stats.productsSummary = [];

      for (var row in productsRaw) {
        final syncStatus = row['Sync_status'] as String? ?? 'new';
        if (syncStatus == 'new') {
          newCount++;
        } else if (syncStatus == 'updated') {
          updatedCount++;
        }

        final idProduct = row['Id_product'] as int;

        // Obtener coordenadas de Products_coordinates para este producto
        final List<Map<String, dynamic>> coordinates = await db.rawQuery('''
          SELECT Latitude, Longitude
          FROM Products_coordinates
          WHERE Id_product = ?
        ''', [idProduct]);

        _stats.productsSummary.add(ProductSummary(
          idProduct: idProduct,
          idHeadquarter: row['Id_headquarter'] as int,
          idCompany: row['Id_company'] as int,
          nameProduct: row['Name_product'] as String?,
          typeProduct: row['Type_product'] as String?,
          rfid: row['Rfid'] as String?,
          stateProduct: row['State_product'] as String?,
          descriptionProduct: row['Description_product'] as String?,
          line: row['Line'] as int?,
          palm: row['Palm'] as int?,
          syncStatus: syncStatus,
          createdAt: row['Created_at'] as String?,
          modifiedAt: row['Modified_at'] as String?,
          locationRaw: row['Location_raw'] as String?,
          coordinates: coordinates,
        ));
      }

      await db.close();

      _stats.totalProductsNew = newCount;
      _stats.totalProductsUpdated = updatedCount;
      _stats.hasPendingProducts = productsRaw.isNotEmpty;

      debugPrint('✅ Productos pendientes recolectados:');
      debugPrint('   📦 Nuevos (POST): $_stats.totalProductsNew');
      debugPrint('   🔄 Actualizados (PUT): $_stats.totalProductsUpdated');
      debugPrint('   📊 Total: ${_stats.getTotalPendingProducts()}');

      if (_stats.productsSummary.isNotEmpty) {
        debugPrint('   📋 Ejemplos de productos:');
        for (int i = 0; i < _stats.productsSummary.length && i < 3; i++) {
          final product = _stats.productsSummary[i];
          debugPrint('      [$i] ${product.nameProduct ?? "Sin nombre"} '
              '(RFID: ${product.rfid ?? "N/A"}, Status: ${product.syncStatus})');
        }
      }
    } catch (e) {
      debugPrint('❌ Error recolectando productos: $e');
      // No relanzamos el error para no interrumpir el flujo principal
      _stats.totalProductsNew = 0;
      _stats.totalProductsUpdated = 0;
      _stats.hasPendingProducts = false;
    }
  }

  Future<void> _syncExclusionZones() async {
    try {
      debugPrint('🔄 Sincronizando zonas de exclusión...');

      // Preparar el payload
      final List<Map<String, dynamic>> exclusionZonesPayload = [];

      for (var modification in _stats.exclusionModifications) {
        exclusionZonesPayload.add({
          'id_polygon_coordinate': modification['Id_polygon_coordinate'],
          'id_virtual_point': modification['Id_virtual_point'],
          'line_number': modification['Line_number'],
          'point_number': modification['Point_number'],
          'previous_type_id': modification['Previous_type_id'],
          'previous_type_name': modification['Previous_type_name'],
          'new_type_id': modification['New_type_id'],
          'new_type_name': modification['New_type_name'],
          'modified_at': modification['Modified_at'],
          'user_id': null,
        });
      }

      debugPrint(
          '📦 Total de modificaciones a enviar: ${exclusionZonesPayload.length}');

      // Crear el payload completo
      final Map<String, dynamic> fullPayload = {
        'exclusion_zones_modifications': exclusionZonesPayload,
      };

      // Convertir a JSON con formato legible
      final String jsonBody = jsonEncode(fullPayload);

      // DEBUG: Imprimir payload completo
      debugPrint('');
      debugPrint('📤 ===== PAYLOAD ENVIADO AL API (EXCLUSIONES) =====');
      debugPrint(
          '🔗 URL: https://api.clickpalm.com/Sync_times/ProcessExclusionZonesModification');
      debugPrint('');
      debugPrint('📋 Headers:');
      debugPrint('   Content-Type: application/json');
      debugPrint(
          '   Authorization: Bearer ${widget.authToken.substring(0, 20)}...');
      debugPrint('');
      debugPrint('📦 Body (JSON):');

      // Formatear JSON con indentación para mejor legibilidad
      try {
        final prettyJson =
            const JsonEncoder.withIndent('  ').convert(fullPayload);
        debugPrint(prettyJson);
      } catch (e) {
        debugPrint(jsonBody);
      }

      debugPrint('');
      debugPrint('📊 Resumen del payload:');
      debugPrint('   - Total modificaciones: ${exclusionZonesPayload.length}');
      if (exclusionZonesPayload.isNotEmpty) {
        debugPrint('   - Primera modificación:');
        final first = exclusionZonesPayload.first;
        debugPrint(
            '      * id_polygon_coordinate: ${first['id_polygon_coordinate']}');
        debugPrint('      * id_virtual_point: ${first['id_virtual_point']}');
        debugPrint(
            '      * previous_type_name: ${first['previous_type_name']}');
        debugPrint('      * new_type_name: ${first['new_type_name']}');
        debugPrint('      * modified_at: ${first['modified_at']}');
      }
      debugPrint('📤 ===== FIN PAYLOAD =====');
      debugPrint('');

      // Enviar al API
      const String url =
          'https://api.clickpalm.com/Sync_times/ProcessExclusionZonesModification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonBody,
      );

      debugPrint('');
      debugPrint('📥 ===== RESPUESTA DEL API (EXCLUSIONES) =====');
      debugPrint('   - Status Code: ${response.statusCode}');
      debugPrint('   - Body: ${response.body}');
      debugPrint('📥 ===== FIN RESPUESTA =====');
      debugPrint('');

      if (response.statusCode == 200 || response.statusCode == 202) {
        debugPrint('✅ Zonas de exclusión sincronizadas exitosamente');

        // Limpiar la tabla Exclusion_zones_history después de sincronizar
        await _cleanExclusionZonesHistory();
      } else {
        throw Exception(
            'Error al sincronizar exclusiones: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando exclusiones: $e');
      rethrow;
    }
  }

  Future<void> _cleanExclusionZonesHistory() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      final int deleted = await db.delete('Exclusion_zones_history');
      debugPrint('✅ Limpiadas $deleted modificaciones de exclusión');

      await db.close();
    } catch (e) {
      debugPrint('⚠️ Error limpiando historial de exclusiones: $e');
    }
  }

  /// Sincroniza productos pendientes al API
  /// - Productos con Sync_status='new' -> POST /Products (crear)
  /// - Productos con Sync_status='updated' -> PUT /Products/{id} (actualizar)
  Future<bool> _syncProducts() async {
    if (!_stats.hasPendingProducts) {
      debugPrint('ℹ️ No hay productos pendientes de sincronización');
      return true;
    }

    try {
      debugPrint('🔄 Sincronizando productos...');
      debugPrint('   📦 Nuevos: ${_stats.totalProductsNew}');
      debugPrint('   🔄 Actualizados: ${_stats.totalProductsUpdated}');

      int successCount = 0;
      int errorCount = 0;
      List<int> syncedProductIds = [];

      for (final product in _stats.productsSummary) {
        try {
          // Construir array de locations_add con formato LAT:X,LON:Y
          List<String> locationsAdd = [];

          // 1. Agregar Location_raw si existe
          if (product.locationRaw != null && product.locationRaw!.isNotEmpty) {
            final parts = product.locationRaw!.split(',');
            if (parts.length == 2) {
              final lat = parts[0].trim();
              final lon = parts[1].trim();
              locationsAdd.add('LAT:$lat,LON:$lon');
            }
          }

          // 2. Agregar coordenadas de Products_coordinates
          if (product.coordinates != null && product.coordinates!.isNotEmpty) {
            for (var coord in product.coordinates!) {
              final lat = coord['Latitude'];
              final lon = coord['Longitude'];
              if (lat != null && lon != null) {
                locationsAdd.add('LAT:$lat,LON:$lon');
              }
            }
          }

          // Preparar el payload según ProductsInputDTO del API
          final Map<String, dynamic> productPayload = {
            'id_product': product.idProduct,
            'id_headquarter': product.idHeadquarter,
            'id_company': product.idCompany,
            'name_product': product.nameProduct ?? '',
            'type_product': product.typeProduct ?? '',
            'rfid': product.rfid ?? '',
            'created_at': product.createdAt ?? DateTime.now().toUtc().toIso8601String(),
            'modified_at': product.modifiedAt ?? DateTime.now().toUtc().toIso8601String(),
            'state_product': product.stateProduct ?? 'Activo',
            'description_product': product.descriptionProduct ?? '',
            'locations_add': locationsAdd,
            'line': product.line ?? 0,
            'palm': product.palm ?? 0,
          };

          final String jsonBody = jsonEncode(productPayload);
          http.Response response;

          if (product.syncStatus == 'new') {
            // POST - Crear nuevo producto
            const String url = 'https://api.clickpalm.com/Products';

            debugPrint('');
            debugPrint('📤 POST /Products - Nuevo producto ID: ${product.idProduct}');
            debugPrint('   RFID: ${product.rfid}');
            debugPrint('   Nombre: ${product.nameProduct}');
            debugPrint('   Tipo: ${product.typeProduct}');
            debugPrint('   Coordenadas: ${locationsAdd.length} ubicaciones');
            if (locationsAdd.isNotEmpty) {
              for (int i = 0; i < locationsAdd.length; i++) {
                debugPrint('      [$i] ${locationsAdd[i]}');
              }
            }

            response = await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.authToken}',
              },
              body: jsonBody,
            );
          } else {
            // PUT - Actualizar producto existente
            final String url = 'https://api.clickpalm.com/Products/${product.idProduct}';

            debugPrint('');
            debugPrint('📤 PUT /Products/${product.idProduct} - Actualizar producto');
            debugPrint('   RFID: ${product.rfid}');
            debugPrint('   Nombre: ${product.nameProduct}');
            debugPrint('   Tipo: ${product.typeProduct}');
            debugPrint('   Coordenadas: ${locationsAdd.length} ubicaciones');
            if (locationsAdd.isNotEmpty) {
              for (int i = 0; i < locationsAdd.length; i++) {
                debugPrint('      [$i] ${locationsAdd[i]}');
              }
            }

            response = await http.put(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.authToken}',
              },
              body: jsonBody,
            );
          }

          debugPrint('   📥 Response Status: ${response.statusCode}');

          if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
            successCount++;
            syncedProductIds.add(product.idProduct);
            debugPrint('   ✅ Producto sincronizado exitosamente');
          } else {
            errorCount++;
            debugPrint('   ❌ Error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          errorCount++;
          debugPrint('   ❌ Excepción sincronizando producto ${product.idProduct}: $e');
        }
      }

      debugPrint('');
      debugPrint('📊 Resumen de sincronización de productos:');
      debugPrint('   ✅ Exitosos: $successCount');
      debugPrint('   ❌ Errores: $errorCount');

      // Actualizar Sync_status a 'synced' para productos sincronizados exitosamente
      if (syncedProductIds.isNotEmpty) {
        await _updateProductsSyncStatus(syncedProductIds);
      }

      // Retornar true si al menos un producto fue sincronizado, o si hubo errores pero algunos fueron exitosos
      return successCount > 0 || errorCount == 0;
    } catch (e) {
      debugPrint('❌ Error general sincronizando productos: $e');
      return false;
    }
  }

  /// Actualiza el Sync_status de productos sincronizados a 'synced'
  Future<void> _updateProductsSyncStatus(List<int> productIds) async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      final String placeholders = productIds.map((_) => '?').join(',');
      final int updated = await db.rawUpdate('''
        UPDATE Products
        SET Sync_status = 'synced'
        WHERE Id_product IN ($placeholders)
      ''', productIds);

      await db.close();

      debugPrint('✅ Actualizados $updated productos a Sync_status = "synced"');
    } catch (e) {
      debugPrint('⚠️ Error actualizando Sync_status de productos: $e');
    }
  }

  Future<bool> _syncVisits() async {
    try {
      debugPrint('🔄 Sincronizando visitas...');

      // INTENTO 1: Llamar a la función existente syncVisitsv2 (endpoint multipart)
      debugPrint(
          '📤 Intento 1: Usando endpoint multipart (SyncVisitsAddMultipart)');
      final bool multipartSuccess = await syncVisitsv2(
        context,
        widget.newsAdd,
        widget.idCompany,
        widget.idsHeadquarters,
        widget.imei,
        widget.authToken,
      );

      if (multipartSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint multipart');
        return true;
      }

      // INTENTO 2: FALLBACK - Usar endpoint simple JSON (SyncVisitsAdd)
      debugPrint('');
      debugPrint('⚠️ Endpoint multipart falló, iniciando FALLBACK...');
      debugPrint('📤 Intento 2: Usando endpoint simple JSON (SyncVisitsAdd)');

      final bool jsonSuccess = await _syncVisitsSimpleJson();

      if (jsonSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint JSON (fallback)');
        return true;
      } else {
        debugPrint('❌ Ambos endpoints fallaron (multipart y JSON)');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error general sincronizando visitas: $e');
      return false;
    }
  }

  /// Método de fallback que usa el endpoint simple SyncVisitsAdd (JSON POST)
  Future<bool> _syncVisitsSimpleJson() async {
    try {
      debugPrint('🚀 Iniciando sincronización con endpoint JSON simple...');

      const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

      // Preparar newsAdd
      final List<Map<String, dynamic>> newsAddJson =
          widget.newsAdd.map((visitNews) {
        final map = visitNews.toMap();

        // Mantener formato completo de ubicaciones
        List<String> locationsFormatted = [];
        final locationsRaw = map['locations_add'] ?? map['locationsAdd'] ?? [];

        if (locationsRaw is List) {
          for (var loc in locationsRaw) {
            if (loc is String) {
              locationsFormatted.add(loc);
            }
          }
        }

        return {
          'id_new': map['id_new'] ?? map['idNew'] ?? 0,
          'id_device': map['id_device'] ?? map['idDevice'],
          'id_user': map['id_user'] ?? map['idUser'],
          'created_at': (visitNews.createdAt != null)
              ? visitNews.createdAt!.toIso8601String()
              : DateTime.now().toIso8601String(),
          'descripcion_new':
              map['descripcion_new'] ?? map['descripcionNew'] ?? '',
          'locations_add': locationsFormatted,
        };
      }).toList();

      // Obtener visits_add desde SQLite
      debugPrint('🔍 Obteniendo visits_add desde SQLite...');
      final List<Map<String, dynamic>> visitsAddJson =
          await _getVisitsAddFromSQLiteForJson(widget.idCompany);
      debugPrint('✅ Obtenidas ${visitsAddJson.length} visitas');

      // Crear JSON del modelo completo
      final Map<String, dynamic> syncData = {
        'created_at': DateTime.now().toIso8601String(),
        'ids_headquarters': widget.idsHeadquarters,
        'imei': widget.imei,
        'news_add': newsAddJson,
        'visits_add': visitsAddJson,
      };

      final String jsonBody = jsonEncode(syncData);

      debugPrint('');
      debugPrint('📤 ===== PAYLOAD ENVIADO AL API (JSON FALLBACK) =====');
      debugPrint('🔗 URL: $url');
      debugPrint('');
      debugPrint('📋 Headers:');
      debugPrint('   Content-Type: application/json');
      debugPrint(
          '   Authorization: Bearer ${widget.authToken.substring(0, 20)}...');
      debugPrint('');
      debugPrint('📊 Resumen del payload:');
      debugPrint('   - news_add: ${newsAddJson.length} registros');
      debugPrint('   - visits_add: ${visitsAddJson.length} registros');
      debugPrint('   - Tamaño JSON: ${jsonBody.length} caracteres');
      debugPrint('📤 ===== FIN PAYLOAD =====');
      debugPrint('');

      // Enviar request JSON
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonBody,
      );

      debugPrint('');
      debugPrint('📥 ===== RESPUESTA DEL API (JSON) =====');
      debugPrint('   - Status Code: ${response.statusCode}');
      debugPrint('   - Body: ${response.body}');
      debugPrint('📥 ===== FIN RESPUESTA =====');
      debugPrint('');

      if (response.statusCode == 200 || response.statusCode == 202) {
        debugPrint('✅ Sincronización JSON exitosa');

        // Limpiar datos después de sincronización exitosa
        await _cleanupSQLiteDataAfterSyncInWidget();
        return true;
      } else {
        debugPrint('❌ Error en sincronización JSON');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ EXCEPCIÓN en _syncVisitsSimpleJson: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Obtiene visits_add desde SQLite para el payload JSON
  Future<List<Map<String, dynamic>>> _getVisitsAddFromSQLiteForJson(
      int idCompany) async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      final List<Map<String, dynamic>> rawData = await db.rawQuery('''
        SELECT
          v.Id_visit as id_visit,
          v.Id_company as id_company,
          v.Id_activity as id_activity,
          v.Id_headquarter as id_headquarter,
          v.Id_product as id_product,
          p.Rfid as rfid,
          v.Id_user as id_user,
          v.Id_device as id_device,
          v.Created_at as created_at,
          v.Latitude,
          v.Longitude,
          v.Altitude,
          v.Error_horizontal,

          vd.Id_visit_detail as detail_id,
          vd.Id_activity_status as detail_activity_status,
          vd.Status_option as detail_status_option,
          vd.Status_response as detail_status_response,

          vl.Id as location_id,
          vl.Latitude as location_latitude,
          vl.Longitude as location_longitude,
          vl.Altitude as location_altitude,
          vl.HorizontalError as location_horizontal_error
        FROM Visits v
        LEFT JOIN Products p ON v.Id_product = p.Id_product
        LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        LEFT JOIN Visits_locations vl ON v.Id_visit = vl.Id_visit
        WHERE v.Id_company = ?
        ORDER BY v.Created_at DESC, vd.Id_visit_detail ASC, vl.Id ASC
      ''', [idCompany]);

      final Map<int, Map<String, dynamic>> visitsMap = {};

      for (final row in rawData) {
        final int visitId = row['id_visit'];

        if (!visitsMap.containsKey(visitId)) {
          visitsMap[visitId] = {
            'created_at': row['created_at'],
            'id_visit': row['id_visit'],
            'id_company': row['id_company'],
            'id_activity': row['id_activity'],
            'id_headquarter': row['id_headquarter'],
            'id_product': row['id_product'],
            'rfid': row['rfid'],
            'id_user': row['id_user'],
            'id_device': row['id_device'],
            'visits_details': <Map<String, dynamic>>[],
            'locations_add': <String>[],
            'location_default':
                'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}',
            '_details_ids': <int>{},
            '_location_ids': <int>{},
          };
        }

        final visit = visitsMap[visitId]!;

        // Agregar detalles
        if (row['detail_id'] != null) {
          final int detailId = row['detail_id'];
          if (!visit['_details_ids'].contains(detailId)) {
            visit['_details_ids'].add(detailId);
            visit['visits_details'].add({
              'id_visit_detail': 0,
              'id_visit': 0,
              'id_activity_status': row['detail_activity_status'],
              'status_option': row['detail_status_option'] ?? '',
              'status_response': row['detail_status_response'] ?? '',
            });
          }
        }

        // Agregar locations
        if (row['location_id'] != null) {
          final int locationId = row['location_id'];
          if (!visit['_location_ids'].contains(locationId)) {
            visit['_location_ids'].add(locationId);
            final String locationString =
                'LAT:${row['location_latitude']?.toDouble() ?? 0.0};'
                'LON:${row['location_longitude']?.toDouble() ?? 0.0};'
                'ALT:${row['location_altitude']?.toDouble() ?? 0.0};'
                'ERH:${row['location_horizontal_error']?.toDouble() ?? 0.0}';
            visit['locations_add'].add(locationString);
          }
        }
      }

      await db.close();

      final List<Map<String, dynamic>> visitsFormatted =
          visitsMap.values.map((visit) {
        visit.remove('_details_ids');
        visit.remove('_location_ids');
        return visit;
      }).toList();

      debugPrint(
          '✅ Visits_add procesadas para JSON: ${visitsFormatted.length}');
      return visitsFormatted;
    } catch (e) {
      debugPrint('❌ Error en _getVisitsAddFromSQLiteForJson: $e');
      return [];
    }
  }

  /// Limpia los datos de SQLite después de una sincronización exitosa
  Future<void> _cleanupSQLiteDataAfterSyncInWidget() async {
    try {
      debugPrint(
          '🧹 Iniciando limpieza de datos sincronizados (desde widget)...');

      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // 1. Limpiar Location_tracking - TODOS los registros hasta el momento
      final DateTime syncTime = DateTime.now();
      final String syncTimeISO = syncTime.toIso8601String();

      final int deletedLocations = await db.rawDelete('''
        DELETE FROM Location_tracking
        WHERE CreatedAt <= ?
      ''', [syncTimeISO]);
      debugPrint('   ✅ Eliminadas $deletedLocations geolocalizaciones');

      // 2. Obtener IDs de visitas antes de eliminar
      final List<Map<String, dynamic>> allVisits = await db.rawQuery('''
        SELECT Id_visit FROM Visits
      ''');

      if (allVisits.isNotEmpty) {
        final List<int> visitIds =
            allVisits.map((v) => v['Id_visit'] as int).toList();
        final String placeholders = visitIds.map((_) => '?').join(',');

        // Eliminar coordenadas de visitas
        await db.rawDelete('''
          DELETE FROM Visits_locations
          WHERE Id_visit IN ($placeholders)
        ''', visitIds);

        // Eliminar detalles de visitas
        await db.rawDelete('''
          DELETE FROM Visits_details
          WHERE Id_visit IN ($placeholders)
        ''', visitIds);

        // Eliminar visitas
        final int deletedVisits = await db.delete('Visits');
        debugPrint('   ✅ Eliminadas $deletedVisits visitas');
      }

      // 3. Limpiar otras tablas necesarias
      await db.delete('Optimized_route_points');
      await db.delete('Optimized_routes');
      await db.delete('Products_coordinates');
      await db.delete('Products');
      await db.delete('Headquarters_coordinates');
      await db.delete('Types_points');
      await db.delete('Virtual_points');
      await db.delete('Headquarters_polygons');
      await db.delete('Headquarters');
      await db.delete('Exclusion_zones_history');

      await db.close();

      // 4. Limpiar AppState
      FFAppState().visitCount = 0;
      FFAppState().visitsAdd = [];
      FFAppState().visitDetails = [];
      FFAppState().update(() {});

      debugPrint('✅ Limpieza completa finalizada (desde widget)');
    } catch (e) {
      debugPrint('❌ Error en limpieza: $e');
    }
  }

  Future<String> _getDatabasePath() async {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }
    final String pathStr = '${externalDir.path}/ClickPalmData';
    return path.join(pathStr, 'clickpalm_database.db');
  }

  /// Obtiene los nombres de los lotes seleccionados desde AppState
  String _getHeadquartersNames() {
    try {
      final headquartersList = FFAppState().headquartersSelectedList;

      if (headquartersList.isEmpty) {
        return 'No hay lotes seleccionados';
      }

      // Obtener solo los nombres y concatenarlos
      final names = headquartersList
          .map((hq) => hq.nameHeadquarter)
          .where((name) => name.isNotEmpty)
          .toList();

      if (names.isEmpty) {
        return 'Sin nombres (${headquartersList.length} lotes)';
      }

      // Si hay muchos lotes, mostrar solo los primeros 3 + contador
      if (names.length > 3) {
        final firstThree = names.take(3).join(', ');
        final remaining = names.length - 3;
        return '$firstThree... (+$remaining más)';
      }

      // Si son 3 o menos, mostrar todos
      return names.join(', ');
    } catch (e) {
      debugPrint('⚠️ Error obteniendo nombres de lotes: $e');
      return widget.idsHeadquarters; // Fallback al valor original
    }
  }

  // ==========================================================================
  // MÉTODOS DE UI
  // ==========================================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FlutterFlowTheme.of(context).success,
                FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: FlutterFlowTheme.of(context).info,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Envío Exitoso',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).info,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Toda la información ha sido\nenviada correctamente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // ✅ MANTENER isSync = true (la app ya está sincronizada, solo enviamos visitas)
                  debugPrint('✅ Sincronización de visitas completada (isSync se mantiene en true)');

                  // Cerrar diálogo de éxito
                  Navigator.pop(context);
                  // Cerrar formulario sync con resultado exitoso
                  Navigator.pop(context, true);

                  // Navegar a HomePage (no necesitamos re-sincronizar todo desde StartPage)
                  context.goNamed('HomePage');
                  debugPrint('✅ Navegando a HomePage');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).info,
                  foregroundColor: FlutterFlowTheme.of(context).success,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Finalizar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline,
                color: FlutterFlowTheme.of(context).error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: FlutterFlowTheme.of(context).secondaryText,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: Text(
              'Cerrar',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).info,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            FlutterFlowTheme.of(context).alternate,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _currentStep == SyncStep.initial
                  ? _buildInitialScreen()
                  : _buildSyncProgressScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud_sync,
              color: FlutterFlowTheme.of(context).info,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envío de Información',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Envía tus visitas y cambios',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_currentStep == SyncStep.initial)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: FlutterFlowTheme.of(context).info),
              tooltip: 'Cerrar',
            ),
        ],
      ),
    );
  }

  Widget _buildInitialScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactInfoCard(
            icon: Icons.cloud_sync_outlined,
            title: 'Preparando Envío',
            color: FlutterFlowTheme.of(context).primary,
          ),
          const SizedBox(height: 16),
          _buildPreviewCard(),
          const SizedBox(height: 24),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context)
                .primaryText
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                color: FlutterFlowTheme.of(context).primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Vista Previa de Envío',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Información básica
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatRow(
                  icon: Icons.location_city,
                  label: 'Lotes Seleccionados',
                  value: _getHeadquartersNames(),
                  color: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  icon: Icons.smartphone,
                  label: 'Identificador del Dispositivo',
                  value: widget.imei,
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Estadísticas de datos
          Text(
            'Información para Enviar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          const SizedBox(height: 12),

          // Mostrar indicador de carga o datos
          if (_isLoadingInitialData)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cargando información...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // VISITAS
            _buildStatRow(
              icon: Icons.event_note,
              label: 'Visitas',
              value: '${_stats.totalVisits}',
              color: const Color(0xFF6366F1), // Indigo
            ),
            const SizedBox(height: 8),

            // GEOLOCALIZACIONES (Location Tracking)
            _buildStatRow(
              icon: Icons.my_location,
              label: 'Geolocalizaciones',
              value: '${_stats.totalLocations}',
              color: const Color(0xFF10B981), // Green
            ),
            const SizedBox(height: 8),

            // EXCLUSION ZONES HISTORY
            _buildStatRow(
              icon: Icons.edit_location_alt,
              label: 'Modificaciones de Zonas',
              value: '${_stats.totalExclusionZones}',
              color: const Color(0xFFF59E0B), // Amber
            ),
            const SizedBox(height: 8),

            // NEWSADD
            _buildStatRow(
              icon: Icons.new_releases_outlined,
              label: 'Novedades',
              value: '${_stats.totalNewsAdd}',
              color: const Color(0xFFEC4899), // Pink
            ),
            const SizedBox(height: 8),

            // PRODUCTS (Nuevos y Actualizados)
            if (_stats.getTotalPendingProducts() > 0)
              _buildStatRow(
                icon: Icons.local_offer,
                label: 'Productos TAG',
                value: '${_stats.getTotalPendingProducts()} (${_stats.totalProductsNew} new, ${_stats.totalProductsUpdated} upd)',
                color: const Color(0xFF8B5CF6), // Purple
              ),
            const SizedBox(height: 16),

            // Detalles adicionales
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          size: 16,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Detalles Adicionales',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItem(
                      'Detalles de visitas', _stats.totalVisitDetails),
                  const SizedBox(height: 6),
                  _buildDetailItem(
                      'Ubicaciones de visitas', _stats.totalVisitLocations),
                  const SizedBox(height: 6),
                  _buildDetailItem(
                      'Total de elementos para enviar', _stats.getTotalItems()),
                ],
              ),
            ),
          ], // Cierre del else
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlutterFlowTheme.of(context).primaryText,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, int value) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FlutterFlowTheme.of(context).secondaryText,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).success,
            FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _startSyncProcess,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync,
              color: FlutterFlowTheme.of(context).info,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Iniciar Envío',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).info,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).secondary,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animación de carga pulsante
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: _buildStepIcon(),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Mensaje actual
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _currentMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                                       fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).info,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Barra de progreso
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).info,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 40),

              // Estadísticas en tiempo real
              if (_currentStep != SyncStep.checkingConnection)
                _buildStatsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIcon() {
    IconData icon;
    switch (_currentStep) {
      case SyncStep.checkingConnection:
        icon = Icons.wifi_find;
        break;
      case SyncStep.collectingData:
        icon = Icons.inventory_2;
        break;
      case SyncStep.analyzingExclusions:
        icon = Icons.analytics;
        break;
      case SyncStep.sendingExclusions:
        icon = Icons.map;
        break;
      case SyncStep.sendingProducts:
        icon = Icons.local_offer;
        break;
      case SyncStep.sendingVisits:
        icon = Icons.cloud_upload;
        break;
      case SyncStep.completed:
        icon = Icons.check_circle;
        break;
      case SyncStep.error:
        icon = Icons.error;
        break;
      default:
        icon = Icons.sync;
    }

    return Icon(
      icon,
      color: FlutterFlowTheme.of(context).info,
      size: 60,
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: FlutterFlowTheme.of(context).info,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen Completo de Envío',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fila 1: Visitas y Detalles
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment_turned_in,
                  value: '${_stats.totalVisits}',
                  label: 'Visitas',
                  subtitle: '${_stats.totalVisitDetails} detalles',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.location_on,
                  value: '${_stats.totalVisitLocations}',
                  label: 'Ubicaciones',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 2: Location Tracking y Exclusiones
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.gps_fixed,
                  value: '${_stats.totalLocations}',
                  label: 'Rastreo GPS',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.terrain,
                  value: '${_stats.totalExclusionZones}',
                  label: 'Exclusiones',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 3: NewsAdd y Productos
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.fiber_new,
                  value: '${_stats.totalNewsAdd}',
                  label: 'Novedades',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_offer,
                  value: '${_stats.getTotalPendingProducts()}',
                  label: 'Productos',
                  subtitle: '${_stats.totalProductsNew} nuevos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 4: Total
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.layers,
                  value: '${_stats.getTotalItems()}',
                  label: 'Total',
                  highlight: true,
                ),
              ),
            ],
          ),

          // Información adicional si hay datos
          if (_stats.hasDataToSync()) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    FlutterFlowTheme.of(context).info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stats.visitsSummary.isNotEmpty) ...[
                    Text(
                      '📋 Primera Visita:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                    ),
                    Text(
                      'ID: ${_stats.visitsSummary.first.idVisit}, '
                      'HQ: ${_stats.visitsSummary.first.idHeadquarter}',
                      style: TextStyle(
                        fontSize: 11,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (_stats.exclusionsSummary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🗺️ Última Exclusión:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                    ),
                    Text(
                      '${_stats.exclusionsSummary.first.previousTypeName ?? "N/A"} → '
                      '${_stats.exclusionsSummary.first.newTypeName ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    String? subtitle,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? FlutterFlowTheme.of(context).info.withValues(alpha: 0.25)
            : FlutterFlowTheme.of(context).info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.5),
                width: 2,
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: FlutterFlowTheme.of(context).info,
            size: highlight ? 28 : 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: FlutterFlowTheme.of(context).info,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
