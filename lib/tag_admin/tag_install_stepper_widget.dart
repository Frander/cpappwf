import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// Tipos de TAG disponibles para instalación
enum TagType {
  puntoVigilancia,
  puntoAcopio,
  tijera,
  caja,
}

extension TagTypeExtension on TagType {
  String get displayName {
    switch (this) {
      case TagType.puntoVigilancia:
        return 'Punto de Vigilancia';
      case TagType.puntoAcopio:
        return 'Punto de Acopio';
      case TagType.tijera:
        return 'Tijera';
      case TagType.caja:
        return 'Caja';
    }
  }

  IconData get icon {
    switch (this) {
      case TagType.puntoVigilancia:
        return Icons.security;
      case TagType.puntoAcopio:
        return Icons.inventory_2;
      case TagType.tijera:
        return Icons.content_cut;
      case TagType.caja:
        return Icons.inbox;
    }
  }

  Color get color {
    switch (this) {
      case TagType.puntoVigilancia:
        return Color(0xFF3B82F6);
      case TagType.puntoAcopio:
        return Color(0xFF10B981);
      case TagType.tijera:
        return Color(0xFFF59E0B);
      case TagType.caja:
        return Color(0xFF8B5CF6);
    }
  }
}

class TagInstallStepperWidget extends StatefulWidget {
  const TagInstallStepperWidget({super.key});

  @override
  State<TagInstallStepperWidget> createState() =>
      _TagInstallStepperWidgetState();
}

class _TagInstallStepperWidgetState extends State<TagInstallStepperWidget>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isReading = false;
  bool _isSaving = false;

  // Datos del TAG
  String _tagId = '';
  String _tagContent = '';

  // Producto existente (si se encontró)
  Map<String, dynamic>? _existingProduct;
  bool _isUpdateMode = false;

  // Selecciones del usuario
  TagType? _selectedTagType;
  Map<String, dynamic>? _selectedZone;
  Map<String, dynamic>? _selectedHeadquarter;

  // Datos del formulario
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Listas cargadas desde SQLite
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _nearbyHeadquarters = [];

  // Ubicación actual
  double? _currentLatitude;
  double? _currentLongitude;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        _slideController.reset();
        _slideController.forward();
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _slideController.reset();
        _slideController.forward();
      });
    }
  }

  /// Obtiene la ruta de la base de datos
  Future<String> _getDatabasePath() async {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }
    return path.join('${externalDir.path}/ClickPalmData', 'clickpalm_database.db');
  }

  /// Lee el TAG NFC y obtiene su ID
  Future<void> _readTag() async {
    setState(() {
      _isReading = true;
      _tagId = '';
      _tagContent = '';
      _existingProduct = null;
      _isUpdateMode = false;
    });

    try {
      // Verificar NFC
      bool nfcReady = await actions.checkNfcStatus(context, showAlert: true);
      if (!nfcReady) {
        setState(() => _isReading = false);
        return;
      }

      // Leer TAG usando NfcManager directamente para obtener el ID
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            String tagId = '';

            // Obtener el ID del TAG
            final androidTag = NfcTagAndroid.from(tag);
            if (androidTag != null && androidTag.id.isNotEmpty) {
              tagId = androidTag.id
                  .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
                  .join('');
            }

            // Leer contenido NDEF si existe
            String content = '';
            final ndef = Ndef.from(tag);
            if (ndef != null && ndef.cachedMessage != null) {
              final records = ndef.cachedMessage!.records;
              if (records.isNotEmpty) {
                final payload = records.first.payload;
                if (payload.isNotEmpty && payload.length > 1) {
                  final statusByte = payload[0];
                  final languageCodeLength = statusByte & 0x3F;
                  if (payload.length > languageCodeLength + 1) {
                    content = String.fromCharCodes(payload.sublist(1 + languageCodeLength));
                  }
                }
              }
            }

            await NfcManager.instance.stopSession();

            if (mounted) {
              setState(() {
                _tagId = tagId;
                _tagContent = content;
                _isReading = false;
              });

              HapticFeedback.mediumImpact();

              // Buscar producto existente con este RFID
              await _searchProductByRfid(tagId);
            }
          } catch (e) {
            debugPrint('Error leyendo TAG: $e');
            await NfcManager.instance.stopSession();
            if (mounted) {
              setState(() => _isReading = false);
              _showError('Error al leer el TAG: $e');
            }
          }
        },
      );
    } catch (e) {
      setState(() => _isReading = false);
      _showError('Error: $e');
    }
  }

  /// Busca un producto existente por RFID
  Future<void> _searchProductByRfid(String rfid) async {
    if (rfid.isEmpty) return;

    try {
      final dbPath = await _getDatabasePath();
      final db = await openDatabase(dbPath);

      final results = await db.query(
        'Products',
        where: 'Rfid = ?',
        whereArgs: [rfid],
      );

      await db.close();

      if (results.isNotEmpty) {
        setState(() {
          _existingProduct = results.first;
          _isUpdateMode = true;
          // Pre-llenar campos con datos existentes
          _nameController.text = _existingProduct!['Name_product'] ?? '';
          _descriptionController.text = _existingProduct!['Description_product'] ?? '';
        });
        debugPrint('Producto existente encontrado: ${_existingProduct!['Id_product']}');
      } else {
        setState(() {
          _existingProduct = null;
          _isUpdateMode = false;
        });
        debugPrint('No se encontró producto con RFID: $rfid');
      }
    } catch (e) {
      debugPrint('Error buscando producto: $e');
    }
  }

  /// Carga las zonas desde SQLite
  Future<void> _loadZones() async {
    try {
      final dbPath = await _getDatabasePath();
      final db = await openDatabase(dbPath);

      final results = await db.query(
        'Zones',
        orderBy: 'Name_zone ASC',
      );

      await db.close();

      setState(() {
        _zones = results;
      });
    } catch (e) {
      debugPrint('Error cargando zonas: $e');
    }
  }

  /// Obtiene la ubicación actual desde FFAppState().geoLocationsList
  void _getCurrentLocation() {
    try {
      final geoList = FFAppState().geoLocationsList;

      if (geoList.isNotEmpty) {
        // Obtener la última ubicación de la lista
        final lastLocation = geoList.last;
        setState(() {
          _currentLatitude = lastLocation.latitude;
          _currentLongitude = lastLocation.longitude;
        });
        debugPrint('📍 Ubicación actual desde AppState: $_currentLatitude, $_currentLongitude');
      } else {
        debugPrint('⚠️ No hay ubicación en geoLocationsList');
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación: $e');
    }
  }

  /// Calcula la distancia entre dos puntos usando Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Calcula la distancia mínima desde un punto a un segmento de línea (polígono)
  double _distanceToPolygonEdge(double pointLat, double pointLon, List<Map<String, dynamic>> polygon) {
    if (polygon.isEmpty) return double.infinity;

    double minDistance = double.infinity;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      final lat1 = p1['Latitude'] as double? ?? 0;
      final lon1 = p1['Longitude'] as double? ?? 0;
      final lat2 = p2['Latitude'] as double? ?? 0;
      final lon2 = p2['Longitude'] as double? ?? 0;

      // Distancia al vértice
      final distToVertex = _calculateDistance(pointLat, pointLon, lat1, lon1);
      if (distToVertex < minDistance) {
        minDistance = distToVertex;
      }

      // Distancia al segmento (aproximación)
      final distToSegment = _distanceToSegment(pointLat, pointLon, lat1, lon1, lat2, lon2);
      if (distToSegment < minDistance) {
        minDistance = distToSegment;
      }
    }

    return minDistance;
  }

  /// Calcula la distancia desde un punto a un segmento de línea
  double _distanceToSegment(double px, double py, double x1, double y1, double x2, double y2) {
    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return _calculateDistance(px, py, x1, y1);
    }

    final double t = math.max(0, math.min(1,
        ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)));

    final double projX = x1 + t * dx;
    final double projY = y1 + t * dy;

    return _calculateDistance(px, py, projX, projY);
  }

  /// Carga los headquarters cercanos basados en la zona seleccionada y ubicación
  Future<void> _loadNearbyHeadquarters() async {
    if (_selectedZone == null) return;

    _getCurrentLocation();

    try {
      final dbPath = await _getDatabasePath();
      final db = await openDatabase(dbPath);

      // Obtener headquarters de la zona seleccionada
      final headquarters = await db.query(
        'Headquarters',
        where: 'Id_zone = ?',
        whereArgs: [_selectedZone!['Id_zone']],
      );

      // Para cada headquarter, obtener sus polígonos y calcular distancia
      List<Map<String, dynamic>> headquartersWithDistance = [];

      for (final hq in headquarters) {
        final hqId = hq['Id_headquarter'];

        // Obtener polígonos del headquarter
        final polygons = await db.query(
          'Headquarters_polygons',
          where: 'Id_headquarter = ?',
          whereArgs: [hqId],
          orderBy: 'Id_headquarter_polygon ASC',
        );

        double distance = double.infinity;

        if (_currentLatitude != null && _currentLongitude != null && polygons.isNotEmpty) {
          distance = _distanceToPolygonEdge(_currentLatitude!, _currentLongitude!, polygons);
        }

        headquartersWithDistance.add({
          ...hq,
          'distance': distance,
          'polygons': polygons,
        });
      }

      await db.close();

      // Ordenar por distancia y tomar los 5 más cercanos
      headquartersWithDistance.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _nearbyHeadquarters = headquartersWithDistance.take(5).toList();
      });

      debugPrint('Headquarters cercanos cargados: ${_nearbyHeadquarters.length}');
    } catch (e) {
      debugPrint('Error cargando headquarters: $e');
    }
  }

  /// Guarda o actualiza el producto en SQLite
  Future<void> _saveProduct() async {
    if (_selectedTagType == null || _selectedZone == null ||
        _selectedHeadquarter == null || _tagId.isEmpty) {
      _showError('Por favor complete todos los campos');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dbPath = await _getDatabasePath();
      final db = await openDatabase(dbPath);

      final now = DateTime.now().toUtc().toIso8601String();

      // Obtener el id_company del AppState o de la zona
      final idCompany = _selectedZone!['Id_company'] ?? 1;

      // Determinar el id_type basado en el tipo de TAG seleccionado
      // Por ahora usamos un valor por defecto, idealmente debería mapearse a Types_points
      final idType = _selectedTagType!.index + 1;

      if (_isUpdateMode && _existingProduct != null) {
        // Actualizar producto existente - marcar como 'updated' para sincronización
        await db.update(
          'Products',
          {
            'Id_headquarter': _selectedHeadquarter!['Id_headquarter'],
            'Id_company': idCompany,
            'Id_type': idType,
            'Modified_at': now,
            'Type_product': _selectedTagType!.displayName,
            'Name_product': _nameController.text.trim(),
            'Description_product': _descriptionController.text.trim(),
            'State_product': 'Activo',
            'Line': 0,
            'Palm': 0,
            'Sync_status': 'updated', // Marcar para sincronizar como actualización
          },
          where: 'Id_product = ?',
          whereArgs: [_existingProduct!['Id_product']],
        );
        debugPrint('Producto actualizado: ${_existingProduct!['Id_product']} (Sync_status: updated)');
      } else {
        // Insertar nuevo producto - marcar como 'new' para sincronización
        await db.insert(
          'Products',
          {
            'Id_headquarter': _selectedHeadquarter!['Id_headquarter'],
            'Id_company': idCompany,
            'Id_type': idType,
            'Created_at': now,
            'Modified_at': now,
            'Type_product': _selectedTagType!.displayName,
            'Name_product': _nameController.text.trim(),
            'Rfid': _tagId,
            'State_product': 'Activo',
            'Description_product': _descriptionController.text.trim(),
            'Location_raw': _currentLatitude != null && _currentLongitude != null
                ? '$_currentLatitude,$_currentLongitude'
                : null,
            'Line': 0,
            'Palm': 0,
            'Sync_status': 'new', // Marcar para sincronizar como nuevo
          },
        );
        debugPrint('Nuevo producto insertado con RFID: $_tagId (Sync_status: new)');
      }

      await db.close();

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isUpdateMode
                ? 'Producto actualizado exitosamente'
                : 'TAG instalado exitosamente'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error guardando producto: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_location_alt,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instalar TAG',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_isUpdateMode)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MODO ACTUALIZAR',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Leer', 'Tipo', 'Zona', 'Lote', 'Datos'];
    return Row(
      children: List.generate(5, (index) {
        final isActive = index <= _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive ? Color(0xFF10B981) : Color(0xFF4B5563),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        color: isActive ? Color(0xFF10B981) : Colors.white38,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 4) SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1ReadTag();
      case 1:
        return _buildStep2SelectType();
      case 2:
        return _buildStep3SelectZone();
      case 3:
        return _buildStep4SelectHeadquarter();
      case 4:
        return _buildStep5ProductData();
      default:
        return Container();
    }
  }

  // ==================== PASO 1: LEER TAG ====================
  Widget _buildStep1ReadTag() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.nfc,
            title: 'Paso 1: Leer TAG',
            subtitle: 'Acerque el TAG NFC para obtener su identificación',
            color: Color(0xFF3B82F6),
          ),
          SizedBox(height: 24),

          if (!_isReading && _tagId.isEmpty)
            _buildReadyToScanCard(),

          if (_isReading)
            _buildScanningCard(),

          if (_tagId.isNotEmpty && !_isReading)
            _buildTagInfoCard(),

          SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _isReading ? null : _readTag,
                  text: _tagId.isEmpty ? 'Leer TAG' : 'Leer Otro TAG',
                  icon: Icon(Icons.nfc, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF3B82F6),
                    disabledColor: Color(0xFF4B5563),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_tagId.isNotEmpty) ...[
                SizedBox(width: 12),
                Expanded(
                  child: FFButtonWidget(
                    onPressed: _nextStep,
                    text: 'Continuar',
                    icon: Icon(Icons.arrow_forward, size: 20),
                    options: FFButtonOptions(
                      height: 50,
                      color: Color(0xFF10B981),
                      textStyle: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyToScanCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.nfc, color: Color(0xFF3B82F6), size: 56),
          ),
          SizedBox(height: 20),
          Text(
            'Acerque el TAG NFC',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Presione el botón y acerque el TAG al dispositivo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const RepaintBoundary(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
          SizedBox(height: 20),
          Text(
            'Leyendo TAG...',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Mantenga el TAG cerca del dispositivo',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isUpdateMode ? Color(0xFFF59E0B) : Color(0xFF10B981),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isUpdateMode ? Icons.update : Icons.check_circle,
                color: _isUpdateMode ? Color(0xFFF59E0B) : Color(0xFF10B981),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                _isUpdateMode ? 'Producto Existente' : 'TAG Nuevo',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isUpdateMode ? Color(0xFFF59E0B) : Color(0xFF10B981),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('TAG ID (RFID)', _tagId),
          if (_tagContent.isNotEmpty && _tagContent != '0')
            _buildInfoRow('Contenido', _tagContent),
          if (_isUpdateMode && _existingProduct != null) ...[
            Divider(color: Colors.white24, height: 24),
            _buildInfoRow('Nombre actual', _existingProduct!['Name_product'] ?? 'Sin nombre'),
            _buildInfoRow('Tipo actual', _existingProduct!['Type_product'] ?? 'Sin tipo'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PASO 2: SELECCIONAR TIPO ====================
  Widget _buildStep2SelectType() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.category,
            title: 'Paso 2: Tipo de TAG',
            subtitle: 'Seleccione el tipo de punto a instalar',
            color: Color(0xFF8B5CF6),
          ),
          SizedBox(height: 24),

          // Grid de tipos
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: TagType.values.map((type) => _buildTypeCard(type)).toList(),
          ),

          SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF374151),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FFButtonWidget(
                  onPressed: _selectedTagType != null ? () {
                    _loadZones();
                    _nextStep();
                  } : null,
                  text: 'Continuar',
                  icon: Icon(Icons.arrow_forward, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF10B981),
                    disabledColor: Color(0xFF4B5563),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(TagType type) {
    final isSelected = _selectedTagType == type;
    return InkWell(
      onTap: () => setState(() => _selectedTagType = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? type.color.withOpacity(0.2) : Color(0xFF374151),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? type.color : Color(0xFF4B5563),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: type.color.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: type.color.withOpacity(isSelected ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(type.icon, color: type.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              type.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? type.color : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: type.color, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== PASO 3: SELECCIONAR ZONA ====================
  Widget _buildStep3SelectZone() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.map,
            title: 'Paso 3: Seleccionar Zona',
            subtitle: 'Elija la zona donde se instalará el TAG',
            color: Color(0xFFF59E0B),
          ),
          SizedBox(height: 24),

          if (_zones.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const RepaintBoundary(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                  SizedBox(height: 16),
                  Text(
                    'Cargando zonas...',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _zones.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) => _buildZoneCard(_zones[index]),
            ),

          SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF374151),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FFButtonWidget(
                  onPressed: _selectedZone != null ? () {
                    _loadNearbyHeadquarters();
                    _nextStep();
                  } : null,
                  text: 'Continuar',
                  icon: Icon(Icons.arrow_forward, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF10B981),
                    disabledColor: Color(0xFF4B5563),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final isSelected = _selectedZone?['Id_zone'] == zone['Id_zone'];
    return InkWell(
      onTap: () => setState(() => _selectedZone = zone),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFF59E0B).withOpacity(0.15) : Color(0xFF374151),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFF59E0B) : Color(0xFF4B5563),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.map, color: Color(0xFFF59E0B), size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone['Name_zone'] ?? 'Sin nombre',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ID: ${zone['Id_zone']}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(0xFFF59E0B), size: 24),
          ],
        ),
      ),
    );
  }

  // ==================== PASO 4: SELECCIONAR HEADQUARTER ====================
  Widget _buildStep4SelectHeadquarter() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.location_on,
            title: 'Paso 4: Seleccionar Lote',
            subtitle: 'Top 5 lotes más cercanos a tu ubicación',
            color: Color(0xFF10B981),
          ),
          SizedBox(height: 16),

          // Info de ubicación actual
          if (_currentLatitude != null && _currentLongitude != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.my_location, color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu ubicación: ${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_nearbyHeadquarters.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const RepaintBoundary(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                  SizedBox(height: 16),
                  Text(
                    'Buscando lotes cercanos...',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _nearbyHeadquarters.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) => _buildHeadquarterCard(
                _nearbyHeadquarters[index],
                index + 1,
              ),
            ),

          SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF374151),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FFButtonWidget(
                  onPressed: _selectedHeadquarter != null ? _nextStep : null,
                  text: 'Continuar',
                  icon: Icon(Icons.arrow_forward, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF10B981),
                    disabledColor: Color(0xFF4B5563),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeadquarterCard(Map<String, dynamic> hq, int rank) {
    final isSelected = _selectedHeadquarter?['Id_headquarter'] == hq['Id_headquarter'];
    final distance = hq['distance'] as double;

    // Manejar distancia: metros si < 1000, km si >= 1000, "Sin ubicación" si infinity
    String distanceStr;
    if (distance.isInfinite || distance.isNaN) {
      distanceStr = 'Sin ubicación';
    } else if (distance < 1000) {
      distanceStr = '${distance.toStringAsFixed(0)} m';
    } else {
      distanceStr = '${(distance / 1000).toStringAsFixed(2)} km';
    }

    return InkWell(
      onTap: () => setState(() => _selectedHeadquarter = hq),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF10B981).withOpacity(0.15) : Color(0xFF374151),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF10B981) : Color(0xFF4B5563),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Ranking badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank == 1 ? Color(0xFF10B981) : Color(0xFF4B5563),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hq['Name_headquarter'] ?? 'Lote ${hq['Id_headquarter']}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.white38, size: 14),
                      SizedBox(width: 4),
                      Text(
                        distanceStr,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: distance.isInfinite || distance.isNaN
                              ? Colors.orange
                              : (distance < 100 ? Color(0xFF10B981) : Colors.white60),
                          fontWeight: !distance.isInfinite && !distance.isNaN && distance < 100
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'ID: ${hq['Id_headquarter']}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
          ],
        ),
      ),
    );
  }

  // ==================== PASO 5: DATOS DEL PRODUCTO ====================
  Widget _buildStep5ProductData() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.edit_note,
            title: 'Paso 5: Datos del Producto',
            subtitle: 'Complete la información del producto',
            color: Color(0xFF8B5CF6),
          ),
          SizedBox(height: 24),

          // Resumen de selecciones
          _buildSummaryCard(),
          SizedBox(height: 20),

          // Formulario
          _buildTextField(
            controller: _nameController,
            label: 'Nombre del Producto',
            hint: 'Ej: Punto de vigilancia entrada',
            icon: Icons.label,
          ),
          SizedBox(height: 16),

          _buildTextField(
            controller: _descriptionController,
            label: 'Descripción',
            hint: 'Descripción opcional del producto',
            icon: Icons.description,
            maxLines: 3,
          ),
          SizedBox(height: 16),

          // Campos de solo lectura
          _buildReadOnlyField('RFID (TAG ID)', _tagId, Icons.nfc),
          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField('Line', '0', Icons.horizontal_rule),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildReadOnlyField('Palm', '0', Icons.park),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF374151),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FFButtonWidget(
                  onPressed: _isSaving ? null : _saveProduct,
                  text: _isSaving
                      ? 'Guardando...'
                      : (_isUpdateMode ? 'Actualizar' : 'Instalar TAG'),
                  icon: Icon(_isSaving ? Icons.hourglass_empty : Icons.save, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: Color(0xFF10B981),
                    disabledColor: Color(0xFF4B5563),
                    textStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de instalación',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 12),
          _buildSummaryRow(Icons.category, 'Tipo', _selectedTagType?.displayName ?? '-'),
          _buildSummaryRow(Icons.map, 'Zona', _selectedZone?['Name_zone'] ?? '-'),
          _buildSummaryRow(Icons.location_on, 'Lote', _selectedHeadquarter?['Name_headquarter'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(icon, color: Colors.white38, size: 20),
            filled: true,
            fillColor: Color(0xFF374151),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF4B5563)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF4B5563)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF4B5563)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ),
              Icon(Icons.lock, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== COMPONENTES COMUNES ====================
  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
