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
import '/components/nfc_view_raw_dialog_widget.dart';
import '/components/nfc_clear_dialog_widget.dart';
import '/tag_admin/tag_admin_center_widget.dart';

// ============================================================================
// WIDGET PRINCIPAL - FORMULARIO DE INFORMACIÓN Y SINCRONIZACIÓN
// ============================================================================

class InformationForm extends StatefulWidget {
  const InformationForm({
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
  State<InformationForm> createState() => _InformationFormState();
}

class _InformationFormState extends State<InformationForm>
    with TickerProviderStateMixin {
  // Variable estática para cachear la autenticación durante la sesión de la app
  static bool _isAuthenticatedForSession = false;

  // Estado de carga
  bool _isLoadingData = true;

  // Datos pendientes por sincronizar
  int _pendingVisits = 0;
  int _pendingLocationTracking = 0;
  int _pendingExclusionZones = 0;
  int _pendingNewsAdd = 0;

  // Datos descargados (conteo de registros por tabla)
  Map<String, int> _downloadedDataCounts = {};

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAllData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoadingData = true;
      });

      await _loadPendingSyncData();
      await _loadDownloadedData();

      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _loadPendingSyncData() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Contar Visits
      final visitsResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM Visits');
      _pendingVisits = visitsResult.first['count'] as int? ?? 0;

      // Contar Location_tracking
      final locationResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM Location_tracking');
      _pendingLocationTracking = locationResult.first['count'] as int? ?? 0;

      // Contar Exclusion_zones_history
      final exclusionResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM Exclusion_zones_history');
      _pendingExclusionZones = exclusionResult.first['count'] as int? ?? 0;

      // NewsAdd viene del AppState
      _pendingNewsAdd = widget.newsAdd.length;

      await db.close();

      debugPrint('✅ Datos pendientes cargados:');
      debugPrint('   Visits: $_pendingVisits');
      debugPrint('   Location_tracking: $_pendingLocationTracking');
      debugPrint('   Exclusion_zones_history: $_pendingExclusionZones');
      debugPrint('   NewsAdd: $_pendingNewsAdd');
    } catch (e) {
      debugPrint('❌ Error cargando datos pendientes: $e');
      rethrow;
    }
  }

  Future<void> _loadDownloadedData() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Lista de tablas para contar (datos descargados)
      final List<String> tablesToCount = [
        'Headquarters',
        'Headquarters_coordinates',
        'Virtual_points',
        'Optimized_routes',
        'Activities',
        'Activities_status',
        'Products',
        'Companies',
        'Users',
      ];

      _downloadedDataCounts.clear();

      for (String tableName in tablesToCount) {
        try {
          final result =
              await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
          final count = result.first['count'] as int? ?? 0;
          _downloadedDataCounts[tableName] = count;
          debugPrint('   $tableName: $count registros');
        } catch (e) {
          debugPrint('   ⚠️ Error contando $tableName: $e');
          _downloadedDataCounts[tableName] = 0;
        }
      }

      await db.close();

      debugPrint(
          '✅ Datos descargados contados: ${_downloadedDataCounts.length} tablas');
    } catch (e) {
      debugPrint('❌ Error cargando datos descargados: $e');
      rethrow;
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

  int get _totalPendingItems {
    return _pendingVisits +
        _pendingLocationTracking +
        _pendingExclusionZones +
        _pendingNewsAdd;
  }

  int get _totalDownloadedItems {
    return _downloadedDataCounts.values.fold(0, (sum, count) => sum + count);
  }

  // ==========================================================================
  // NAVEGACIÓN A HISTORIAL Y SINCRONIZACIÓN
  // ==========================================================================

  void _navigateToHistoryVisits() {
    // Mostrar diálogo con HistoryVisitsForm
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: HistoryVisitsForm(
          width: MediaQuery.of(context).size.width - 32,
          height: MediaQuery.of(context).size.height - 100,
        ),
      ),
    );
  }

  void _navigateToSync() async {
    // Obtener parámetros del App State
    final newsAdd = FFAppState().newsAdd;
    final idCompany = FFAppState().companyDefault.idCompany;
    final idsHeadquarters =
        joinHeadquarterIds(FFAppState().headquartersSelectedList);
    final imei = FFAppState().deviceDefault.imeI1;
    final authToken = FFAppState().loginResponse['token'] as String? ?? '';

    // Mostrar diálogo con SyncVisitsForm y esperar resultado
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SyncVisitsForm(
          width: MediaQuery.of(context).size.width - 32,
          height: MediaQuery.of(context).size.height - 100,
          newsAdd: newsAdd,
          idCompany: idCompany,
          idsHeadquarters: idsHeadquarters,
          imei: imei,
          authToken: authToken,
        ),
      ),
    );

    // Si la sincronización fue exitosa, recargar toda la información
    if (result == true) {
      debugPrint(
          '✅ Sincronización exitosa - Recargando información de la UI...');

      // Mostrar indicador de carga mientras se recargan los datos
      if (mounted) {
        setState(() {
          _isLoadingData = true;
        });
      }

      // Pequeño delay para que la UI se actualice
      await Future.delayed(const Duration(milliseconds: 300));

      // Recargar todos los datos
      await _loadAllData();

      debugPrint('✅ Información de la UI actualizada correctamente');
    }
  }

  void _navigateToAdvancedConfig() {
    // Si ya está autenticado en esta sesión, ir directo al menú
    if (_isAuthenticatedForSession) {
      _showAdvancedConfigMenu();
      return;
    }

    // Si no está autenticado, mostrar diálogo de código de acceso
    showDialog(
      context: context,
      builder: (context) => _buildAccessCodeDialog(),
    );
  }

  void _showAdvancedConfigMenu() {
    // Mostrar menú de opciones avanzadas después de autenticación exitosa
    showDialog(
      context: context,
      builder: (context) => _buildAdvancedConfigMenu(),
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
            const Color(0xFF1B4332), // Verde oscuro
            const Color(0xFF081C15), // Verde muy oscuro
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child:
                  _isLoadingData ? _buildLoadingScreen() : _buildInfoScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B4332), // Verde oscuro
            const Color(0xFF2D6A4F), // Verde medio
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.2), // Naranja brillante
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFFFF6B35), // Naranja brillante
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información del Sistema',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Datos pendientes y descargados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Botón de actualizar
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar información',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Botón de cerrar
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cerrar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.3), // Naranja brillante
                    const Color(0xFFFF8C42).withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_download,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Cargando información...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de totales
          _buildTotalsSummary(),
          const SizedBox(height: 16),

          // Información del dispositivo CTR
          _buildDeviceInfoPanel(),
          const SizedBox(height: 24),

          // Sección: Pendientes por Sincronizar (Colapsable)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2), // Naranja brillante
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_upload,
                    color: Color(0xFFFF6B35), size: 20), // Naranja brillante
              ),
              title: const Text(
                'Pendientes por Sincronizar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                _buildPendingSyncCard(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sección: Datos Descargados (Colapsable)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF52B788).withValues(alpha: 0.3), // Verde claro
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_download,
                    color: Color(0xFF52B788), size: 20), // Verde claro
              ),
              title: const Text(
                'Datos Descargados',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                _buildDownloadedDataCard(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botones de acción
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D6A4F).withValues(alpha: 0.4), // Verde medio
            const Color(0xFF1B4332).withValues(alpha: 0.6), // Verde oscuro
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTotalCard(
              icon: Icons.cloud_upload,
              title: 'Pendientes',
              value: _totalPendingItems.toString(),
              color: const Color(0xFFFF6B35), // Naranja brillante
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 2,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTotalCard(
              icon: Icons.cloud_done,
              title: 'Descargados',
              value: _totalDownloadedItems.toString(),
              color: const Color(0xFF52B788), // Verde claro
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoPanel() {
    final device = FFAppState().deviceDefault;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0077B6).withValues(alpha: 0.4), // Azul medio
            const Color(0xFF023E8A).withValues(alpha: 0.6), // Azul oscuro
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del panel
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0096C7).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Color(0xFF0096C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Información del Dispositivo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Información del dispositivo
          _buildDeviceInfoRow(
            icon: Icons.label,
            label: 'Nombre',
            value: device.deviceName.isNotEmpty ? device.deviceName : 'N/A',
          ),
          const SizedBox(height: 10),

          if (device.cellPhone.isNotEmpty) ...[
            _buildDeviceInfoRow(
              icon: Icons.phone,
              label: 'Teléfono',
              value: device.cellPhone,
            ),
            const SizedBox(height: 10),
          ],

          _buildDeviceInfoRow(
            icon: Icons.tag,
            label: 'Serial',
            value: device.serialId.isNotEmpty ? device.serialId : 'N/A',
          ),
          const SizedBox(height: 10),

          if (device.imeI1.isNotEmpty) ...[
            _buildDeviceInfoRow(
              icon: Icons.smartphone,
              label: 'IMEI 1',
              value: device.imeI1,
            ),
            const SizedBox(height: 10),
          ],

          if (device.imeI2.isNotEmpty && device.imeI2 != device.imeI1) ...[
            _buildDeviceInfoRow(
              icon: Icons.smartphone,
              label: 'IMEI 2',
              value: device.imeI2,
            ),
            const SizedBox(height: 10),
          ],

          _buildDeviceInfoRow(
            icon: Icons.devices,
            label: 'Modelo',
            value: device.model.isNotEmpty ? device.model : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0096C7).withValues(alpha: 0.8),
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingSyncCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332).withValues(alpha: 0.5), // Verde oscuro semi-transparente
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildDataRow(
            icon: Icons.event_note,
            label: 'Visitas',
            value: _pendingVisits.toString(),
            color: const Color(0xFFFF6B35), // Naranja brillante
          ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildDataRow(
            icon: Icons.my_location,
            label: 'Geolocalizaciones',
            value: _pendingLocationTracking.toString(),
            color: const Color(0xFF52B788), // Verde claro
          ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildDataRow(
            icon: Icons.edit_location_alt,
            label: 'Modificaciones de Zonas',
            value: _pendingExclusionZones.toString(),
            color: const Color(0xFFFFAA00), // Amarillo/naranja
          ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildDataRow(
            icon: Icons.new_releases_outlined,
            label: 'Novedades',
            value: _pendingNewsAdd.toString(),
            color: const Color(0xFFFF8C42), // Naranja claro
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedDataCard() {
    if (_downloadedDataCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4332).withValues(alpha: 0.5), // Verde oscuro semi-transparente
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'No hay datos descargados',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332).withValues(alpha: 0.5), // Verde oscuro semi-transparente
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _downloadedDataCounts.keys.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 16),
              _buildDivider(),
              const SizedBox(height: 16),
            ],
            _buildDataRow(
              icon: _getIconForTable(_downloadedDataCounts.keys.elementAt(i)),
              label: _getLabelForTable(_downloadedDataCounts.keys.elementAt(i)),
              value: _downloadedDataCounts.values.elementAt(i).toString(),
              color: _getColorForIndex(i),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForTable(String tableName) {
    switch (tableName) {
      case 'Headquarters':
        return Icons.location_city;
      case 'Headquarters_coordinates':
        return Icons.map;
      case 'Virtual_points':
        return Icons.place;
      case 'Optimized_routes':
        return Icons.route;
      case 'Activities':
        return Icons.work;
      case 'Activities_status':
        return Icons.assignment;
      case 'Products':
        return Icons.inventory_2;
      case 'Companies':
        return Icons.business;
      case 'Users':
        return Icons.people;
      default:
        return Icons.storage;
    }
  }

  String _getLabelForTable(String tableName) {
    switch (tableName) {
      case 'Headquarters':
        return 'Lotes';
      case 'Headquarters_coordinates':
        return 'Coordenadas de Lotes';
      case 'Virtual_points':
        return 'Puntos Virtuales';
      case 'Optimized_routes':
        return 'Recorridos Optimizados';
      case 'Activities':
        return 'Actividades';
      case 'Activities_status':
        return 'Estados de Actividades';
      case 'Products':
        return 'Productos';
      case 'Companies':
        return 'Empresas';
      case 'Users':
        return 'Usuarios';
      default:
        return tableName;
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFFFF6B35), // Naranja brillante
      const Color(0xFF52B788), // Verde claro
      const Color(0xFFFF8C42), // Naranja claro
      const Color(0xFF74C69D), // Verde medio claro
      const Color(0xFFFFAA00), // Amarillo/naranja
      const Color(0xFF95D5B2), // Verde muy claro
      const Color(0xFFFF9E66), // Naranja suave
      const Color(0xFFB7E4C7), // Verde pastel
      const Color(0xFFFFB380), // Naranja pastel
      const Color(0xFFD8F3DC), // Verde muy suave
    ];
    return colors[index % colors.length];
  }

  Widget _buildDataRow({
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
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botón Historial de Visitas
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF52B788), // Verde claro
                Color(0xFF40916C), // Verde medio
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _navigateToHistoryVisits,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Historial de Visitas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Botón Sincronizar
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B35), // Naranja brillante
                Color(0xFFFF8C42), // Naranja claro
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _navigateToSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.sync, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Sincronizar Datos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Botón Configuración Avanzada
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2D6A4F).withValues(alpha: 0.5),
                const Color(0xFF1B4332).withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ElevatedButton(
            onPressed: _navigateToAdvancedConfig,
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
                Icon(Icons.settings, color: Colors.grey[300], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Configuración Avanzada',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.3),
                    const Color(0xFF059669).withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_sync,
                color: Color(0xFF10B981),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sincronizar Datos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Se sincronizarán $_totalPendingItems elementos pendientes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Aquí iría la lógica de sincronización
                      // Llamar a syncVisitsv2 o navegar a la pantalla de sincronización
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildAccessCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    String errorMessage = '';

    return StatefulBuilder(
      builder: (BuildContext dialogContext, StateSetter setState) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B4332), // Verde oscuro
                  Color(0xFF081C15), // Verde muy oscuro
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de seguridad
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFF6B35).withValues(alpha: 0.3),
                        const Color(0xFFFF8C42).withValues(alpha: 0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFFFF6B35),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  'Acceso Restringido',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Descripción
                Text(
                  'Ingrese el código de acceso de 9 dígitos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Campo de texto para el código
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: errorMessage.isEmpty
                          ? Colors.white.withValues(alpha: 0.3)
                          : const Color(0xFFFF6B35),
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: codeController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 9,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: '•••••••••',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        letterSpacing: 6,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      if (errorMessage.isNotEmpty) {
                        setState(() {
                          errorMessage = '';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Mensaje de error
                if (errorMessage.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFFF6B35),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF2D6A4F).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF6B35), // Naranja brillante
                              Color(0xFFFF8C42), // Naranja claro
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            String inputCode = codeController.text.trim();

                            // Validar el código usando la función personalizada
                            if (validateAdvancedAccessCode(inputCode)) {
                              // Código correcto - marcar como autenticado para esta sesión
                              _isAuthenticatedForSession = true;

                              // Cerrar diálogo y mostrar menú
                              Navigator.pop(dialogContext);

                              // Usar addPostFrameCallback para asegurar que el diálogo anterior se cierre completamente
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _showAdvancedConfigMenu();
                                }
                              });
                            } else {
                              // Código incorrecto - mostrar error
                              setState(() {
                                errorMessage = 'Código de acceso incorrecto';
                              });
                              // Limpiar el campo
                              codeController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Verificar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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
      },
    );
  }

  Widget _buildAdvancedConfigMenu() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
          maxHeight: 480,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B4332), // Verde oscuro
                Color(0xFF081C15), // Verde muy oscuro
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          const Color(0xFFFF8C42).withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFFFF6B35),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configuración Avanzada',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Opciones del sistema',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close,
                        color: Colors.grey[300],
                        size: 20),
                    tooltip: 'Cerrar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Opciones de configuración (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildAdvancedOptionCard(
                        icon: Icons.map,
                        title: 'Configuración de Mapas',
                        description: 'Gestionar recursos de mapas y tiles',
                        color: const Color(0xFF52B788), // Verde claro
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a ConfigMapsPage
                          context.pushNamed('ConfigMapsPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.system_update_alt,
                        title: 'Actualización de CTR',
                        description:
                            'Descargar e instalar actualizaciones de la app',
                        color: const Color(0xFFFF6B35), // Naranja brillante
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a UpdatedAPPage
                          context.pushNamed('UpdatedAPPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.location_history,
                        title: 'Historial de Geolocalizaciones',
                        description: 'Ver registro de ubicaciones rastreadas',
                        color: const Color(0xFF74C69D), // Verde medio claro
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a HistoryGeoPage
                          context.pushNamed('HistoryGeoPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.backup,
                        title: 'Copias de Seguridad',
                        description: 'Administrar backups del sistema',
                        color: const Color(0xFFFFAA00), // Amarillo/naranja
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a ConfigBackupsPage
                          context.pushNamed('ConfigBackupsPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.nfc,
                        title: 'Centro de Administración NFC',
                        description: 'Configurar, leer, escribir y gestionar TAGs NFC',
                        color: const Color(0xFF3B82F6), // Azul
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar al Centro de Administración de TAGs
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TagAdminCenterWidget(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.print,
                        title: 'Configuración de Impresoras',
                        description: 'Conectar y configurar impresoras Bluetooth térmicas',
                        color: const Color(0xFF8B5CF6), // Púrpura
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a PrinterConfigurationPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrinterConfigurationPage(),
                            ),
                          );
                        },
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

  Widget _buildAdvancedOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2D6A4F).withValues(alpha: 0.3),
                const Color(0xFF1B4332).withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Flecha
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
