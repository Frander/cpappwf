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
import 'package:package_info_plus/package_info_plus.dart';
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

  // Estado colapsable del panel de dispositivo
  bool _isDeviceInfoExpanded = false;

  // Datos pendientes por sincronizar
  int _pendingVisits = 0;
  int _pendingLocationTracking = 0;
  int _pendingExclusionZones = 0;
  int _pendingNewsAdd = 0;
  int _pendingTagsNew = 0;      // Productos TAG nuevos (Sync_status = 'new')
  int _pendingTagsUpdated = 0;  // Productos TAG actualizados (Sync_status = 'updated')

  // Datos descargados (conteo de registros por tabla)
  Map<String, int> _downloadedDataCounts = {};

  // Versión de la app
  String _appVersion = '';

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAllData();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version} (${info.buildNumber})';
        });
      }
    });
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

      // Contar productos TAG pendientes de sincronización (nuevos y actualizados)
      try {
        final tagsNewResult = await db.rawQuery(
            "SELECT COUNT(*) as count FROM Products WHERE Sync_status = 'new'");
        _pendingTagsNew = tagsNewResult.first['count'] as int? ?? 0;

        final tagsUpdatedResult = await db.rawQuery(
            "SELECT COUNT(*) as count FROM Products WHERE Sync_status = 'updated'");
        _pendingTagsUpdated = tagsUpdatedResult.first['count'] as int? ?? 0;
      } catch (e) {
        // Si la columna Sync_status no existe, establecer en 0
        debugPrint('⚠️ No se pudo contar productos TAG: $e');
        _pendingTagsNew = 0;
        _pendingTagsUpdated = 0;
      }

      await db.close();

      debugPrint('✅ Datos pendientes cargados:');
      debugPrint('   Visits: $_pendingVisits');
      debugPrint('   Location_tracking: $_pendingLocationTracking');
      debugPrint('   Exclusion_zones_history: $_pendingExclusionZones');
      debugPrint('   NewsAdd: $_pendingNewsAdd');
      debugPrint('   Tags (new): $_pendingTagsNew');
      debugPrint('   Tags (updated): $_pendingTagsUpdated');
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
        _pendingNewsAdd +
        _pendingTagsNew +
        _pendingTagsUpdated;
  }

  int get _totalPendingTags {
    return _pendingTagsNew + _pendingTagsUpdated;
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
    final authToken = (FFAppState().loginResponse?['token'] as String?) ?? '';

    // Navegar a la nueva página de sincronización moderna
    await context.pushNamed(
      'ModernSyncPage',
      queryParameters: {
        'newsAdd': serializeParam(newsAdd, ParamType.DataStruct, isList: true),
        'idCompany': serializeParam(idCompany, ParamType.int),
        'idsHeadquarters': serializeParam(idsHeadquarters, ParamType.String),
        'imei': serializeParam(imei, ParamType.String),
        'authToken': serializeParam(authToken, ParamType.String),
      }.withoutNulls,
    );

    // Después de regresar de la página de sincronización, recargar toda la información
    debugPrint('🔄 Regresando de la sincronización - Recargando información de la UI...');

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4332), // Verde oscuro
            Color(0xFF081C15), // Verde muy oscuro
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4332),
            Color(0xFF2D6A4F),
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
          // Botón de regresar (izquierda)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
            tooltip: 'Regresar',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),

          // Título centrado
          Expanded(
            child: Text(
              'Información del Sistema',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Botón de actualizar (derecha)
          IconButton(
            onPressed: _isLoadingData ? null : _loadAllData,
            icon: _isLoadingData
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white, size: 24),
            tooltip: 'Actualizar',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                    const Color(0xFFFF6B35).withValues(alpha: 0.3),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botones de acción modernos (movidos al top)
          _buildModernActionButtons(),
          const SizedBox(height: 24),

          // Grid de Pendientes por Sincronizar
          _buildSectionHeader(
            icon: Icons.cloud_upload_outlined,
            title: 'Pendientes por Sincronizar',
            color: const Color(0xFFFF6B35),
            badgeCount: _totalPendingItems,
          ),
          const SizedBox(height: 12),
          _buildPendingSyncGrid(),
          const SizedBox(height: 24),

          // Información del dispositivo (colapsable)
          _buildDeviceInfoCollapsible(),
          const SizedBox(height: 24),

          // Grid de Datos Descargados
          _buildSectionHeader(
            icon: Icons.cloud_download_outlined,
            title: 'Datos Descargados',
            color: const Color(0xFF52B788),
            badgeCount: _totalDownloadedItems,
          ),
          const SizedBox(height: 12),
          _buildDownloadedDataGrid(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    int? badgeCount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (badgeCount != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              badgeCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingSyncGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B4332).withValues(alpha: 0.6),
            const Color(0xFF081C15).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildPendingListItem(
            icon: Icons.event_note_outlined,
            label: 'Visitas',
            value: _pendingVisits,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 8),
          _buildPendingListItem(
            icon: Icons.my_location_outlined,
            label: 'Geolocalizaciones',
            value: _pendingLocationTracking,
            color: const Color(0xFF52B788),
          ),
          const SizedBox(height: 8),
          _buildPendingListItem(
            icon: Icons.edit_location_alt_outlined,
            label: 'Modificaciones de Zonas',
            value: _pendingExclusionZones,
            color: const Color(0xFFFFAA00),
          ),
          const SizedBox(height: 8),
          _buildPendingListItem(
            icon: Icons.new_releases_outlined,
            label: 'Novedades',
            value: _pendingNewsAdd,
            color: const Color(0xFFFF8C42),
          ),
          const SizedBox(height: 8),
          _buildPendingListItemWithSubtitle(
            icon: Icons.local_offer_outlined,
            label: 'Tags',
            value: _totalPendingTags,
            subtitle: '$_pendingTagsNew nuevos, $_pendingTagsUpdated actualizados',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingListItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingListItemWithSubtitle({
    required IconData icon,
    required String label,
    required int value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (value > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDeviceInfoCollapsible() {
    final device = FFAppState().deviceDefault;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0077B6).withValues(alpha: 0.3),
            const Color(0xFF023E8A).withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0096C7).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isDeviceInfoExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isDeviceInfoExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0096C7).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_android,
              color: Color(0xFF0096C7),
              size: 22,
            ),
          ),
          title: const Text(
            'Información del Dispositivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            _buildDeviceInfoRow(
              icon: Icons.label_outline,
              label: 'Nombre',
              value: device.deviceName.isNotEmpty ? device.deviceName : 'N/A',
            ),
            if (device.cellPhone.isNotEmpty)
              _buildDeviceInfoRow(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: device.cellPhone,
              ),
            _buildDeviceInfoRow(
              icon: Icons.tag,
              label: 'Serial',
              value: device.serialId.isNotEmpty ? device.serialId : 'N/A',
            ),
            if (device.imeI1.isNotEmpty)
              _buildDeviceInfoRow(
                icon: Icons.smartphone_outlined,
                label: 'IMEI 1',
                value: device.imeI1,
              ),
            if (device.imeI2.isNotEmpty && device.imeI2 != device.imeI1)
              _buildDeviceInfoRow(
                icon: Icons.smartphone_outlined,
                label: 'IMEI 2',
                value: device.imeI2,
              ),
            _buildDeviceInfoRow(
              icon: Icons.devices_outlined,
              label: 'Modelo',
              value: device.model.isNotEmpty ? device.model : 'N/A',
            ),
            _buildDeviceInfoRow(
              icon: Icons.info_outline,
              label: 'Versión App',
              value: _appVersion.isNotEmpty ? _appVersion : '...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
      ),
    );
  }

  Widget _buildDownloadedDataGrid() {
    if (_downloadedDataCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4332).withValues(alpha: 0.5),
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

    final entries = _downloadedDataCounts.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B4332).withValues(alpha: 0.6),
            const Color(0xFF081C15).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final color = _getColorForIndex(index);
          return _buildDownloadedGridItem(
            icon: _getIconForTable(entry.key),
            label: _getLabelForTable(entry.key),
            value: entry.value,
            color: color,
          );
        },
      ),
    );
  }

  Widget _buildDownloadedGridItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getIconForTable(String tableName) {
    switch (tableName) {
      case 'Headquarters':
        return Icons.location_city_outlined;
      case 'Headquarters_coordinates':
        return Icons.map_outlined;
      case 'Virtual_points':
        return Icons.place_outlined;
      case 'Optimized_routes':
        return Icons.route_outlined;
      case 'Activities':
        return Icons.work_outline;
      case 'Activities_status':
        return Icons.assignment_outlined;
      case 'Products':
        return Icons.inventory_2_outlined;
      case 'Companies':
        return Icons.business_outlined;
      case 'Users':
        return Icons.people_outline;
      default:
        return Icons.storage_outlined;
    }
  }

  String _getLabelForTable(String tableName) {
    switch (tableName) {
      case 'Headquarters':
        return 'Lotes';
      case 'Headquarters_coordinates':
        return 'Coord. Lotes';
      case 'Virtual_points':
        return 'Puntos Virt.';
      case 'Optimized_routes':
        return 'Rutas Opt.';
      case 'Activities':
        return 'Actividades';
      case 'Activities_status':
        return 'Estados';
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
      const Color(0xFFFF6B35),
      const Color(0xFF52B788),
      const Color(0xFFFF8C42),
      const Color(0xFF74C69D),
      const Color(0xFFFFAA00),
      const Color(0xFF95D5B2),
      const Color(0xFFFF9E66),
      const Color(0xFFB7E4C7),
      const Color(0xFFFFB380),
      const Color(0xFFD8F3DC),
    ];
    return colors[index % colors.length];
  }

  Widget _buildModernActionButtons() {
    return Column(
      children: [
        // Botón Historial de Visitas (icono mejorado)
        _buildModernButton(
          icon: Icons.assignment_outlined,
          label: 'Historial de Visitas',
          gradientColors: const [Color(0xFF52B788), Color(0xFF40916C)],
          shadowColor: const Color(0xFF52B788),
          onTap: _navigateToHistoryVisits,
        ),
        const SizedBox(height: 12),

        // Botón Sincronizar (icono mejorado)
        _buildModernButton(
          icon: Icons.sync,
          label: 'Sincronizar Datos',
          gradientColors: const [Color(0xFFFF6B35), Color(0xFFFF8C42)],
          shadowColor: const Color(0xFFFF6B35),
          onTap: _navigateToSync,
          badge: _totalPendingItems > 0 ? _totalPendingItems.toString() : null,
        ),
        const SizedBox(height: 12),

        // Botón Configuración Avanzada (icono mejorado)
        _buildModernButton(
          icon: Icons.admin_panel_settings,
          label: 'Configuración Avanzada',
          gradientColors: [
            const Color(0xFF2D6A4F).withValues(alpha: 0.7),
            const Color(0xFF1B4332).withValues(alpha: 0.9),
          ],
          shadowColor: Colors.black,
          onTap: _navigateToAdvancedConfig,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildModernButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
    String? badge,
    bool isSecondary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: isSecondary
                ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: isSecondary ? 0.2 : 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSecondary ? Colors.grey[300] : Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSecondary ? Colors.grey[300] : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
                  Color(0xFF1B4332),
                  Color(0xFF081C15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: SingleChildScrollView(
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
                              Color(0xFFFF6B35),
                              Color(0xFFFF8C42),
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
                Color(0xFF1B4332),
                Color(0xFF081C15),
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
                        color: const Color(0xFF52B788),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('ConfigMapsPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.record_voice_over_rounded,
                        title: 'Configuración de Voz',
                        description: 'Descargar modelo IA para asistente de voz offline',
                        color: const Color(0xFF0D9488),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('ConfigVoicePage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.system_update_alt,
                        title: 'Actualización de CTR',
                        description:
                            'Descargar e instalar actualizaciones de la app',
                        color: const Color(0xFFFF6B35),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('UpdatedAPPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.location_history,
                        title: 'Historial de Geolocalizaciones',
                        description: 'Ver registro de ubicaciones rastreadas',
                        color: const Color(0xFF74C69D),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('HistoryGeoPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.backup,
                        title: 'Copias de Seguridad',
                        description: 'Administrar backups del sistema',
                        color: const Color(0xFFFFAA00),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('ConfigBackupsPage');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildAdvancedOptionCard(
                        icon: Icons.nfc,
                        title: 'Centro de Administración NFC',
                        description: 'Configurar, leer, escribir y gestionar TAGs NFC',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.pop(context);
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
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          Navigator.pop(context);
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
