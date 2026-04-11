import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Página moderna de sincronización con cuatro opciones:
/// 1. Sincronización Completa (redes estables - con compresión)
/// 2. Sincronización Optimizada (redes lentas - sin compresión)
/// 3. Sincronización Solo Visitas
/// 4. Sincronización Básica (resetea y redirige al login)
class ModernSyncPageWidget extends StatefulWidget {
  const ModernSyncPageWidget({
    super.key,
    List<VisitsNewsStruct>? newsAdd,
    int? idCompany,
    String? idsHeadquarters,
    String? imei,
    String? authToken,
  })  : this.newsAdd = newsAdd ?? const [],
        this.idCompany = idCompany ?? 0,
        this.idsHeadquarters = idsHeadquarters ?? '',
        this.imei = imei ?? '',
        this.authToken = authToken ?? '';

  final List<VisitsNewsStruct> newsAdd;
  final int idCompany;
  final String idsHeadquarters;
  final String imei;
  final String authToken;

  static String routeName = 'ModernSyncPage';
  static String routePath = '/modernSyncPage';

  @override
  State<ModernSyncPageWidget> createState() => _ModernSyncPageWidgetState();
}

enum SyncMode {
  selectMode,       // Selección inicial
  fullSync,         // Sincronización completa (con compresión - redes estables)
  optimizedSync,    // Sincronización optimizada (sin compresión - redes lentas)
  visitsOnly,       // Solo visitas
  basicSync,        // Básica (resetea tablas)
  smartSync,        // Inteligente: detecta qué sincronizar + básica al final
  baseDataSync,     // Sincronización de datos base (12 endpoints GZIP)
}

enum SyncStep {
  idle,
  checkingConnection,
  collectingData,
  analyzingExclusions,
  sendingExclusions,
  sendingProducts,
  sendingVisits,
  completed,
  error,
}

class _ModernSyncPageWidgetState extends State<ModernSyncPageWidget>
    with TickerProviderStateMixin {
  SyncMode _currentMode = SyncMode.selectMode;
  SyncStep _currentStep = SyncStep.idle;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _currentMessage = '';
  String _errorMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _progressController;

  // Estadísticas de sincronización
  int _totalVisits = 0;
  int _totalProducts = 0;
  int _totalExclusions = 0;
  int _syncedItems = 0;

  // Archivos de media para envío multipart
  Map<String, String> _mediaFilesToUpload = {};
  int _mediaFileCounter = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialStats();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _loadInitialStats() async {
    try {
      debugPrint('📊 Cargando estadísticas iniciales...');

      // 1. Cargar estadísticas de visitas desde SQLite
      await _loadVisitsStats();
      debugPrint('   📋 Visitas: $_totalVisits');

      // 2. Cargar estadísticas de productos desde SQLite
      await _loadProductsStats();
      debugPrint('   📦 Productos: $_totalProducts');

      // 3. Cargar estadísticas de exclusiones desde SQLite
      await _loadExclusionsStats();
      debugPrint('   🚫 Exclusiones: $_totalExclusions');

      if (mounted) {
        setState(() {});
      }

      debugPrint('✅ Estadísticas iniciales cargadas correctamente');
    } catch (e) {
      debugPrint('⚠️ Error cargando estadísticas: $e');
    }
  }

  /// Carga el conteo de visitas pendientes de sincronización
  Future<void> _loadVisitsStats() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Contar todas las visitas pendientes (el sync envía todas sin filtro de Status)
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM Visits
      ''');

      await db.close();

      _totalVisits = result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error cargando estadísticas de visitas: $e');
      _totalVisits = 0;
    }
  }

  /// Carga el conteo de productos pendientes de sincronización
  Future<void> _loadProductsStats() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Contar productos con Sync_status = 'new' o 'updated'
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM Products
        WHERE Sync_status IN ('new', 'updated')
      ''');

      await db.close();

      _totalProducts = result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error cargando estadísticas de productos: $e');
      _totalProducts = 0;
    }
  }

  /// Carga el conteo de zonas de exclusión pendientes
  Future<void> _loadExclusionsStats() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Contar modificaciones pendientes en Exclusion_zones_history
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM Exclusion_zones_history
      ''');

      await db.close();

      _totalExclusions = result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error cargando estadísticas de exclusiones: $e');
      _totalExclusions = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _currentMode == SyncMode.selectMode
            ? _buildModeSelectionScreen()
            : _buildSyncProgressScreen(),
      ),
    );
  }

  /// Pantalla de selección de modo de sincronización
  Widget _buildModeSelectionScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _buildSmartSyncButton(),
                  const SizedBox(height: 16),
                  _buildBaseDataSyncButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF00a86b).withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sincronización',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Enviar información al servidor',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF00a86b).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF00a86b).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF00ff9f),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Información pendiente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatRow('Visitas', _totalVisits, Icons.location_on_rounded),
          const SizedBox(height: 12),
          _buildStatRow('Productos', _totalProducts, Icons.eco_rounded),
          const SizedBox(height: 12),
          _buildStatRow(
              'Exclusiones', _totalExclusions, Icons.do_not_disturb_on_rounded),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF00ff9f).withOpacity(0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFF00a86b).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00ff9f),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartSyncButton() {
    final hasPending = _totalVisits > 0 || _totalProducts > 0 || _totalExclusions > 0;

    final List<String> pendingParts = [];
    if (_totalVisits > 0) pendingParts.add('$_totalVisits visita${_totalVisits != 1 ? 's' : ''}');
    if (_totalProducts > 0) pendingParts.add('$_totalProducts producto${_totalProducts != 1 ? 's' : ''}');
    if (_totalExclusions > 0) pendingParts.add('$_totalExclusions exclusión${_totalExclusions != 1 ? 'es' : ''}');

    final description = hasPending
        ? 'Se sincronizarán: ${pendingParts.join(', ')}. Al finalizar se actualizarán los datos base.'
        : 'No hay datos pendientes. Se actualizarán los datos base del sistema.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sincronización',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _startSync(SyncMode.smartSync),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasPending
                    ? [Color(0xFF00a86b), Color(0xFF00c07a)]
                    : [Color(0xFF374151), Color(0xFF4B5563)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (hasPending ? Color(0xFF00a86b) : Color(0xFF374151)).withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sincronizar Ahora',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'INTELIGENTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Al finalizar se refrescarán los datos base y deberás iniciar sesión nuevamente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.4,
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
      ],
    );
  }


  /// Botón de sincronización de datos base (12 endpoints GZIP)
  Widget _buildBaseDataSyncButton() {
    final lastSync = FFAppState().lastSyncBase;
    final hasSync  = lastSync != null;

    String lastSyncLabel;
    if (!hasSync) {
      lastSyncLabel = 'Sin sincronización — primera vez requerida';
    } else {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inDays > 0) {
        lastSyncLabel = 'Último sync: hace ${diff.inDays} día${diff.inDays != 1 ? "s" : ""}';
      } else if (diff.inHours > 0) {
        lastSyncLabel = 'Último sync: hace ${diff.inHours} hora${diff.inHours != 1 ? "s" : ""}';
      } else {
        lastSyncLabel = 'Último sync: hace ${diff.inMinutes} min';
      }
    }

    return InkWell(
      onTap: () => _startSync(SyncMode.baseDataSync),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasSync
                ? [Color(0xFF1E3A5F), Color(0xFF2563EB)]
                : [Color(0xFF3B1F6B), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasSync ? Color(0xFF2563EB) : Color(0xFF7C3AED)).withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.cloud_download_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sincronizar Datos Base',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DATOS BASE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Descarga completa de lotes, productos, actividades, zonas, puntos virtuales y zonas de exclusión. Ejecuta en lotes de 3 endpoints en paralelo.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.88),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSync ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lastSyncLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
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

  /// Pantalla de progreso de sincronización
  Widget _buildSyncProgressScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentStep != SyncStep.error &&
                  _currentStep != SyncStep.completed) ...[
                _buildAnimatedIcon(),
                const SizedBox(height: 40),
                _buildProgressIndicator(),
                const SizedBox(height: 32),
                _buildProgressMessage(),
                const SizedBox(height: 48),
                _buildStepsList(),
              ] else if (_currentStep == SyncStep.completed) ...[
                _buildCompletedScreen(),
              ] else ...[
                _buildErrorScreen(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFF00a86b).withOpacity(0.3),
                  Color(0xFF00a86b).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Color(0xFF00a86b),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00a86b).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Círculo de fondo
              SizedBox(
                width: 280,
                height: 280,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Círculo de progreso
              SizedBox(
                width: 280,
                height: 280,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF00a86b),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
              // Porcentaje
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sincronizando...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF00a86b).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00ff9f)),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              _currentMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    final steps = _getStepsForMode();
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = _progress > (index / steps.length);
        final isCurrent =
            _progress >= (index / steps.length) &&
            _progress < ((index + 1) / steps.length);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildStepItem(
            step['icon'] as IconData,
            step['label'] as String,
            isCompleted,
            isCurrent,
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _getStepsForMode() {
    switch (_currentMode) {
      case SyncMode.fullSync:
        return [
          {'icon': Icons.wifi_rounded, 'label': 'Verificar conexión'},
          {'icon': Icons.folder_rounded, 'label': 'Recolectar datos'},
          {
            'icon': Icons.do_not_disturb_on_rounded,
            'label': 'Analizar exclusiones'
          },
          {'icon': Icons.cloud_upload_rounded, 'label': 'Enviar exclusiones'},
          {'icon': Icons.eco_rounded, 'label': 'Enviar productos'},
          {'icon': Icons.archive_rounded, 'label': 'Comprimir visitas'},
          {'icon': Icons.location_on_rounded, 'label': 'Enviar visitas'},
        ];
      case SyncMode.optimizedSync:
        return [
          {'icon': Icons.wifi_rounded, 'label': 'Verificar conexión'},
          {'icon': Icons.folder_rounded, 'label': 'Recolectar datos'},
          {
            'icon': Icons.do_not_disturb_on_rounded,
            'label': 'Analizar exclusiones'
          },
          {'icon': Icons.cloud_upload_rounded, 'label': 'Enviar exclusiones'},
          {'icon': Icons.eco_rounded, 'label': 'Enviar productos'},
          {'icon': Icons.location_on_rounded, 'label': 'Enviar visitas'},
        ];
      case SyncMode.visitsOnly:
        return [
          {'icon': Icons.wifi_rounded, 'label': 'Verificar conexión'},
          {'icon': Icons.folder_rounded, 'label': 'Recolectar visitas'},
          {'icon': Icons.cloud_upload_rounded, 'label': 'Enviar visitas'},
        ];
      case SyncMode.basicSync:
        return [
          {'icon': Icons.delete_rounded, 'label': 'Limpiar datos base'},
          {'icon': Icons.logout_rounded, 'label': 'Cerrar sesión'},
          {'icon': Icons.login_rounded, 'label': 'Redirigir a login'},
        ];
      case SyncMode.smartSync:
        return [
          {'icon': Icons.wifi_rounded, 'label': 'Verificar conexión'},
          {'icon': Icons.do_not_disturb_on_rounded, 'label': 'Analizar exclusiones'},
          {'icon': Icons.eco_rounded, 'label': 'Enviar productos'},
          {'icon': Icons.location_on_rounded, 'label': 'Enviar visitas'},
          {'icon': Icons.delete_rounded, 'label': 'Cerrar sesión'},
        ];
      case SyncMode.baseDataSync:
        return [
          {'icon': Icons.wifi_rounded,              'label': 'Verificar conexión'},
          {'icon': Icons.cloud_download_rounded,    'label': 'Lote 1: actividades, usuarios, lotes'},
          {'icon': Icons.cloud_download_rounded,    'label': 'Lote 2: zonas, productos, noticias'},
          {'icon': Icons.cloud_download_rounded,    'label': 'Lote 3: pesos, tipos, empresa'},
          {'icon': Icons.cloud_download_rounded,    'label': 'Lote 4: dispositivos, puntos, exclusiones'},
          {'icon': Icons.save_rounded,              'label': 'Guardar en base de datos'},
        ];
      default:
        return [];
    }
  }

  Widget _buildStepItem(
      IconData icon, String label, bool isCompleted, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? Color(0xFF00a86b).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? Color(0xFF00a86b)
              : isCompleted
                  ? Color(0xFF00a86b).withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted || isCurrent
                  ? Color(0xFF00a86b)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isCurrent
                    ? Colors.white
                    : isCompleted
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.5),
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (isCurrent)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Color(0xFF00a86b),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00a86b).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 64,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '¡Sincronización Exitosa!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Todos los datos se enviaron correctamente',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF00a86b),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Continuar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFFEF4444).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 64,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Error de Sincronización',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentMode = SyncMode.selectMode;
                  _currentStep = SyncStep.idle;
                  _isProcessing = false;
                  _progress = 0.0;
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Volver',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => _retrySync(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00a86b),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // LÓGICA DE SINCRONIZACIÓN
  // ============================================================================

  void _startSync(SyncMode mode) {
    setState(() {
      _currentMode = mode;
      _isProcessing = true;
      _currentStep = SyncStep.checkingConnection;
      _progress = 0.0;
      _currentMessage = 'Iniciando sincronización...';
    });

    switch (mode) {
      case SyncMode.fullSync:
        _performFullSync();
        break;
      case SyncMode.optimizedSync:
        _performOptimizedSync();
        break;
      case SyncMode.visitsOnly:
        _performVisitsOnlySync();
        break;
      case SyncMode.basicSync:
        _performBasicSync();
        break;
      case SyncMode.smartSync:
        _performSmartSync();
        break;
      case SyncMode.baseDataSync:
        _performBaseDataSync();
        break;
      default:
        break;
    }
  }

  void _retrySync() {
    _startSync(_currentMode);
  }

  Future<void> _performFullSync() async {
    try {
      // 1. Verificar conexión a Internet con calidad
      await _updateProgress(0.1, 'Verificando la conexión a internet');

      final hasConnection = await _checkInternetConnectionWithQuality();
      if (!hasConnection) {
        throw Exception('No hay conexión a Internet disponible');
      }

      await Future.delayed(Duration(milliseconds: 800));

      // 2. Recolectar datos y estadísticas
      await _updateProgress(0.2, 'Preparando información para enviar');

      final syncStats = SyncStats();
      await _collectSyncData(syncStats);
      await Future.delayed(Duration(milliseconds: 800));

      // 3. Analizar zonas de exclusión modificadas
      await _updateProgress(0.4, 'Verificando cambios en zonas de exclusión');

      await _analyzeExclusionZones(syncStats);
      await Future.delayed(Duration(milliseconds: 800));

      // 4. Sincronizar zonas de exclusión si hay cambios
      if (syncStats.hasPendingExclusions) {
        await _updateProgress(
          0.5,
          'Enviando ${syncStats.totalExclusionZones} zonas de exclusión'
        );

        await _syncExclusionZones(syncStats);
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 4.5. Recolectar y sincronizar productos pendientes
      await _collectProductsData(syncStats);

      if (syncStats.hasPendingProducts) {
        await _updateProgress(
          0.65,
          'Enviando ${syncStats.getTotalPendingProducts()} productos (${syncStats.totalProductsNew} nuevos, ${syncStats.totalProductsUpdated} actualizados)'
        );

        await _syncProducts(syncStats);
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 5. Guardar backup JSON y sincronizar visitas
      await _updateProgress(0.80, 'Guardando backup local...');
      await _saveVisitsBackup();

      await _updateProgress(0.85, 'Enviando ${syncStats.totalVisits} visitas');

      bool success = await _syncVisits();

      if (success) {
        await _updateProgress(0.95, 'Limpiando datos sincronizados...');

        // Limpiar AppState igual que el código anterior (sync_visits_form.dart)
        debugPrint('🧹 Limpiando AppState después de sincronización total...');
        FFAppState().lastSync = DateTime.fromMillisecondsSinceEpoch(1743526800000);
        // ✅ MANTENER isSync = true (solo limpiamos datos temporales, NO datos base de login)
        FFAppState().usersList = [];
        FFAppState().headquarterSelected = HeadquartersStruct();
        FFAppState().zoneSelected = ZonesStruct();
        FFAppState().visitsAdd = [];
        FFAppState().productsAdd = [];
        FFAppState().visitDetails = [];
        FFAppState().activitySelectedJSON = null;
        FFAppState().activityStatusSelectedJSON = null;
        FFAppState().userSelectedJSON = null;
        FFAppState().update(() {});
        debugPrint('✅ AppState limpiado (configuraciones del dispositivo conservadas)');

        await _updateProgress(1.0, 'Envío completado exitosamente');

        setState(() {
          _currentStep = SyncStep.completed;
        });

        await Future.delayed(Duration(seconds: 2));
      } else {
        throw Exception('Error al sincronizar las visitas');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en sincronización completa: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentStep = SyncStep.error;
        _errorMessage = 'Error al sincronizar: ${e.toString()}';
      });
    }
  }

  Future<void> _performOptimizedSync() async {
    try {
      // 1. Verificar conexión a Internet (sin verificación de calidad)
      await _updateProgress(0.1, 'Verificando la conexión a internet');

      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        throw Exception('No hay conexión a Internet disponible');
      }

      await Future.delayed(Duration(milliseconds: 800));

      // 2. Recolectar datos y estadísticas
      await _updateProgress(0.2, 'Preparando información para enviar');

      final syncStats = SyncStats();
      await _collectSyncData(syncStats);
      await Future.delayed(Duration(milliseconds: 800));

      // 3. Analizar zonas de exclusión modificadas
      await _updateProgress(0.4, 'Verificando cambios en zonas de exclusión');

      await _analyzeExclusionZones(syncStats);
      await Future.delayed(Duration(milliseconds: 800));

      // 4. Sincronizar zonas de exclusión si hay cambios
      if (syncStats.hasPendingExclusions) {
        await _updateProgress(
          0.5,
          'Enviando ${syncStats.totalExclusionZones} zonas de exclusión'
        );

        await _syncExclusionZones(syncStats);
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 4.5. Recolectar y sincronizar productos pendientes
      await _collectProductsData(syncStats);

      if (syncStats.hasPendingProducts) {
        await _updateProgress(
          0.65,
          'Enviando ${syncStats.getTotalPendingProducts()} productos (${syncStats.totalProductsNew} nuevos, ${syncStats.totalProductsUpdated} actualizados)'
        );

        await _syncProducts(syncStats);
        await Future.delayed(Duration(milliseconds: 800));
      }

      // 5. Guardar backup JSON y sincronizar visitas SIN COMPRIMIR (modo optimizado para redes lentas)
      await _updateProgress(0.80, 'Guardando backup local...');
      await _saveVisitsBackup();

      await _updateProgress(0.85, 'Enviando ${syncStats.totalVisits} visitas (sin comprimir)');

      // Usar _syncVisitsOptimized que envía sin comprimir
      bool success = await _syncVisitsOptimized();

      if (success) {
        await _updateProgress(0.95, 'Limpiando datos sincronizados...');

        // Limpiar AppState
        debugPrint('🧹 Limpiando AppState después de sincronización optimizada...');
        FFAppState().lastSync = DateTime.fromMillisecondsSinceEpoch(1743526800000);
        // ✅ MANTENER isSync = true (solo limpiamos datos temporales, NO datos base de login)
        FFAppState().usersList = [];
        FFAppState().headquarterSelected = HeadquartersStruct();
        FFAppState().zoneSelected = ZonesStruct();
        FFAppState().visitsAdd = [];
        FFAppState().productsAdd = [];
        FFAppState().visitDetails = [];
        FFAppState().activitySelectedJSON = null;
        FFAppState().activityStatusSelectedJSON = null;
        FFAppState().userSelectedJSON = null;
        FFAppState().update(() {});
        debugPrint('✅ AppState limpiado (configuraciones del dispositivo conservadas)');

        await _updateProgress(1.0, 'Envío completado exitosamente');

        setState(() {
          _currentStep = SyncStep.completed;
        });

        await Future.delayed(Duration(seconds: 2));
      } else {
        throw Exception('Error al sincronizar las visitas');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en sincronización optimizada: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentStep = SyncStep.error;
        _errorMessage = 'Error al sincronizar: ${e.toString()}';
      });
    }
  }

  Future<void> _performVisitsOnlySync() async {
    try {
      await _updateProgress(0.1, 'Verificando conexión a internet...');

      // Verificar conexión
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        throw Exception('No hay conexión a Internet disponible');
      }

      await _updateProgress(0.3, 'Recolectando visitas pendientes...');

      // Guardar backup JSON antes de sincronizar
      await _updateProgress(0.4, 'Guardando backup local...');
      await _saveVisitsBackup();

      // Intentar con endpoint multipart primero
      await _updateProgress(0.5, 'Enviando visitas (método 1)...');
      debugPrint('📤 Intento 1: Usando endpoint multipart (SyncVisitsAddMultipart)');

      bool multipartSuccess = false;
      if (mounted) {
        multipartSuccess = await actions.syncVisitsv2(
          context,
          widget.newsAdd,
          widget.idCompany,
          widget.idsHeadquarters,
          widget.imei,
          widget.authToken,
        );
      }

      if (multipartSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint multipart');
        await _updateProgress(0.9, 'Limpiando datos sincronizados...');

        // Limpiar solo visitsAdd y visitDetails del AppState
        debugPrint('🧹 Limpiando visitas sincronizadas del AppState...');
        FFAppState().visitsAdd = [];
        FFAppState().visitDetails = [];
        FFAppState().update(() {});
        debugPrint('✅ Visitas limpiadas del AppState');

        await _updateProgress(1.0, 'Visitas sincronizadas exitosamente');

        setState(() {
          _currentStep = SyncStep.completed;
        });
        return;
      }

      // FALLBACK: Usar endpoint simple JSON
      debugPrint('⚠️ Endpoint multipart falló, iniciando FALLBACK...');
      await _updateProgress(0.7, 'Enviando visitas (método 2)...');
      debugPrint('📤 Intento 2: Usando endpoint simple JSON (SyncVisitsAdd)');

      final jsonSuccess = await _syncVisitsJsonFallback();

      if (jsonSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint JSON (fallback)');
        await _updateProgress(0.9, 'Limpiando datos sincronizados...');

        // Limpiar solo visitsAdd y visitDetails del AppState
        debugPrint('🧹 Limpiando visitas sincronizadas del AppState...');
        FFAppState().visitsAdd = [];
        FFAppState().visitDetails = [];
        FFAppState().update(() {});
        debugPrint('✅ Visitas limpiadas del AppState');

        await _updateProgress(1.0, 'Visitas sincronizadas exitosamente');

        setState(() {
          _currentStep = SyncStep.completed;
        });
      } else {
        throw Exception('Ambos métodos de sincronización fallaron');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en sincronización de visitas: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentStep = SyncStep.error;
        _errorMessage = 'Error al sincronizar visitas: ${e.toString()}';
      });
    }
  }

  /// Sincronización inteligente: detecta qué hay pendiente y lo sincroniza.
  /// Siempre finaliza ejecutando la sincronización básica (limpieza de datos base + redirect a login).
  Future<void> _performBaseDataSync() async {
    try {
      // 1. Verificar conexión
      await _updateProgress(0.02, 'Verificando conexión a internet...');
      final hasConnection = await _checkInternetConnectionWithQuality();
      if (!hasConnection) {
        throw Exception('Sin conexión a internet disponible');
      }

      // 2. Llamar syncBaseData con callback de progreso en tiempo real
      await _updateProgress(0.04, 'Iniciando descarga de datos base...');

      final success = await actions.syncBaseData(
        context,
        widget.imei,
        widget.authToken,
        widget.idCompany,
        onProgress: (p, m) {
          if (mounted) {
            setState(() {
              _progress       = 0.04 + p * 0.94;
              _currentMessage = m;
            });
          }
        },
      );

      if (!success) throw Exception('Error al sincronizar datos base. Verifica tu conexión e intenta nuevamente.');

      // 3. Guardar fecha de última sincronización base
      FFAppState().lastSyncBase = DateTime.now();

      // 4. Completado
      if (mounted) {
        setState(() {
          _currentStep    = SyncStep.completed;
          _progress       = 1.0;
          _currentMessage = 'Datos base sincronizados exitosamente';
        });
      }

      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.goNamed('StartPage');

    } catch (e) {
      debugPrint('❌ [BaseDataSync] Error: $e');
      if (mounted) {
        setState(() {
          _currentStep  = SyncStep.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _performSmartSync() async {
    try {
      // 1. Verificar conexión
      await _updateProgress(0.05, 'Verificando conexión a internet...');
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) throw Exception('No hay conexión a Internet disponible');

      // 2. Recolectar estadísticas
      await _updateProgress(0.10, 'Analizando datos pendientes...');
      final syncStats = SyncStats();
      await _collectSyncData(syncStats);

      // 3. Zonas de exclusión
      await _analyzeExclusionZones(syncStats);
      if (syncStats.hasPendingExclusions) {
        await _updateProgress(0.20, 'Enviando ${syncStats.totalExclusionZones} zonas de exclusión...');
        await _syncExclusionZones(syncStats);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 4. Productos pendientes
      await _collectProductsData(syncStats);
      if (syncStats.hasPendingProducts) {
        await _updateProgress(
          0.35,
          'Enviando ${syncStats.getTotalPendingProducts()} productos '
          '(${syncStats.totalProductsNew} nuevos, ${syncStats.totalProductsUpdated} actualizados)...',
        );
        await _syncProducts(syncStats);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 5. Visitas: solo si hay pendientes
      bool visitsSuccess = true;
      if (syncStats.totalVisits > 0) {
        await _updateProgress(0.50, 'Guardando backup local...');
        await _saveVisitsBackup();

        await _updateProgress(0.60, 'Enviando ${syncStats.totalVisits} visitas...');
        visitsSuccess = false;
        if (mounted) {
          visitsSuccess = await actions.syncVisitsv2(
            context,
            widget.newsAdd,
            widget.idCompany,
            widget.idsHeadquarters,
            widget.imei,
            widget.authToken,
          );
        }
        if (!visitsSuccess) {
          debugPrint('⚠️ syncVisitsv2 falló (multipart + JSON), intentando fallback directo...');
          visitsSuccess = await _syncVisitsJsonFallback();
        }
        if (!visitsSuccess) {
          throw Exception('No se pudieron sincronizar las visitas pendientes');
        }
      } else {
        debugPrint('ℹ️ Sin visitas pendientes, se omite el envío al servidor');
      }

      // 6. Limpiar AppState de visitas
      debugPrint('🧹 [SmartSync] Paso 6: Limpiando AppState de visitas...');
      FFAppState().visitsAdd = [];
      FFAppState().visitDetails = [];
      FFAppState().update(() {});

      // 7. Limpiar solo los datos de visitas enviadas (sin tocar la sesión)
      debugPrint('🧹 [SmartSync] Paso 7: Limpiando datos de visitas del AppState...');
      FFAppState().newsAdd = [];
      FFAppState().StatusAdd = [];
      FFAppState().productsAdd = [];
      FFAppState().visitsAdd = [];
      FFAppState().visitDetails = [];
      FFAppState().formCacheMap = {};
      FFAppState().update(() {});

      // 8. Renovar token para la próxima operación
      await _updateProgress(0.97, 'Renovando sesión...');
      await _renewAndSaveToken();

      await _updateProgress(1.0, 'Sincronización completada');
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ [SmartSync] Completado. Regresando...');
      if (mounted) context.pop();
    } catch (e, stackTrace) {
      debugPrint('❌ Error en sincronización inteligente: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _currentStep = SyncStep.error;
          _errorMessage = 'Error al sincronizar: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _performBasicSync() async {
    try {
      await _updateProgress(0.2, 'Preparando limpieza de datos...');
      await Future.delayed(Duration(milliseconds: 500));

      await _updateProgress(0.4, 'Limpiando tablas base...');

      // Limpiar tablas de login en SQLite
      final dbPath = await _getDatabasePath();
      final db = await openDatabase(dbPath);

      await db.transaction((txn) async {
        debugPrint('🧹 Limpiando tablas base de sincronización...');

        // Orden inverso de dependencias (FK constraints)
        // Envuelto en try-catch para manejar tablas que puedan no existir
        final tablesToClean = [
          'Nfc_tags_history',
          'Login_sessions',
          'News',
          'Headquarters_weights',
          'Activities_status',
          'Activities_steps',
          'Activities',
          'Devices',
          'Users',
          'Zones_polygons',
          'Zones',
          'Companies',
          'Types_points',
        ];

        int cleanedCount = 0;
        for (final table in tablesToClean) {
          try {
            final count = await txn.delete(table);
            debugPrint('   ✓ Limpiados $count registros de $table');
            cleanedCount++;
          } catch (e) {
            debugPrint('   ⚠️ Error limpiando $table: $e');
            // Continuar con la siguiente tabla aunque esta falle
          }
        }

        debugPrint('✅ $cleanedCount/${tablesToClean.length} tablas base limpiadas');
      });

      await db.close();

      await _updateProgress(0.7, 'Cerrando sesión...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Limpiar AppState manualmente (solo datos de login, NO configuraciones del dispositivo)
      debugPrint('🧹 Limpiando AppState (conservando configuraciones del dispositivo y trabajo en curso)...');
      FFAppState().lastSync = DateTime.fromMillisecondsSinceEpoch(1743526800000);
      FFAppState().isSync = false;
      FFAppState().usersList = [];
      FFAppState().zonesList = [];
      FFAppState().headquartersList = [];
      FFAppState().productsList = [];
      FFAppState().newsList = [];
      FFAppState().newsSelected = [];
      FFAppState().activitiesStatusSelected = [];
      FFAppState().newsAdd = [];
      FFAppState().StatusAdd = [];
      // CRÍTICO: Mantener al menos la última ubicación en geoLocationsList
      final currentGeoLocations = FFAppState().geoLocationsList;
      if (currentGeoLocations.isNotEmpty) {
        FFAppState().geoLocationsList = [currentGeoLocations.last];
        debugPrint('📍 geoLocationsList: mantenida última ubicación (${currentGeoLocations.length} -> 1)');
      } else {
        FFAppState().geoLocationsList = [];
        debugPrint('⚠️ geoLocationsList estaba vacío al hacer logout');
      }
      FFAppState().loginResponse = null;
      // userSelected NO se limpia después de sync — debe persistir para el próximo ciclo
      FFAppState().companyDefault = CompaniesStruct();
      FFAppState().activityDefault = ActivitiesStruct();
      FFAppState().activitiesJSON = null;
      FFAppState().activityStatusSelectedJSON = null;
      FFAppState().userSelectedJSON = null;

      // Variables temporales
      FFAppState().codeSupervisor = '';
      FFAppState().codeOperator = '';
      FFAppState().codeKeyboard = '';
      FFAppState().moduleSelected = '';
      FFAppState().nfcRead = '';
      FFAppState().qrRead = '';
      FFAppState().stopVoice = false;
      FFAppState().idActivityStatus = 0;
      FFAppState().totalStepsActivity = 0;
      FFAppState().countStepsActivity = 0;
      FFAppState().visitCount = 0;
      FFAppState().formCacheMap = {};

      FFAppState().update(() {});
      debugPrint('✅ AppState limpiado (actividad en curso, sedes seleccionadas y configuraciones conservadas)');

      await _updateProgress(1.0, 'Reiniciando aplicación...');
      await Future.delayed(const Duration(milliseconds: 800));

      // Redirigir al StartPage para que re-ejecute todo el flujo de login
      // El StartPage detectará isSync = false y forzará la sincronización completa
      if (mounted) {
        context.goNamed('StartPage');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en sincronización básica: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentStep = SyncStep.error;
        _errorMessage = 'Error al limpiar datos: ${e.toString()}';
      });
    }
  }

  Future<void> _updateProgress(double progress, String message) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _currentMessage = message;
      });
    }
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  /// Obtiene la ruta de la base de datos SQLite
  /// Renueva el token via RenewToken y actualiza únicamente loginResponse['token'].
  /// No modifica ningún otro campo de sesión. Si falla, solo loguea el error.
  Future<void> _renewAndSaveToken() async {
    try {
      if (widget.imei.isEmpty) {
        debugPrint('⚠️ [SmartSync] IMEI vacío, no se puede renovar token');
        return;
      }
      debugPrint('🔑 [SmartSync] Renovando token...');
      final response = await http.post(
        Uri.parse('https://api.clickpalm.com/Users/RenewToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Type_login': 'IMEI', 'Username': widget.imei, 'Password': widget.imei}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          final current = FFAppState().loginResponse;
          if (current != null) {
            final updated = Map<String, dynamic>.from(current as Map);
            updated['token'] = newToken;
            FFAppState().loginResponse = updated;
            debugPrint('✅ [SmartSync] Token renovado y guardado en loginResponse');
          } else {
            debugPrint('⚠️ [SmartSync] loginResponse es null, no se pudo guardar el nuevo token');
          }
          return;
        }
      }
      debugPrint('⚠️ [SmartSync] RenewToken respondió ${response.statusCode}, token no actualizado');
    } catch (e) {
      debugPrint('⚠️ [SmartSync] Error al renovar token: $e');
    }
  }

  Future<String> _getDatabasePath() async {
    final String docsPath = await _getBestDocumentsPath();
    return path.join(docsPath, 'clickpalm_database.db');
  }

  /// Obtiene la mejor ruta para el almacenamiento de datos
  Future<String> _getBestDocumentsPath() async {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final String customPath = '${baseDir.path}/ClickPalmData';
    final Directory targetDir = Directory(customPath);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return targetDir.path;
  }

  /// Verifica la conexión a Internet
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'));
      return result.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Sin conexión a Internet: $e');
      return false;
    }
  }

  /// Fallback: envía visitas al endpoint simple JSON SyncVisitsAdd (POST).
  /// Se usa cuando el endpoint multipart SyncVisitsAddMultipart no está disponible.
  Future<bool> _syncVisitsJsonFallback() async {
    try {
      debugPrint('🔄 Iniciando fallback: endpoint simple JSON (SyncVisitsAdd)...');

      const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

      // Resetear contador y mapa de archivos media
      _mediaFileCounter = 0;
      _mediaFilesToUpload.clear();

      // Preparar newsAdd
      final List<Map<String, dynamic>> newsAddJson =
          widget.newsAdd.map((visitNews) {
        return {
          'id_new': visitNews.idNew,
          'id_device': FFAppState().deviceDefault.idDevice,
          'id_user': FFAppState().userSelected.idUser,
          'created_at': (visitNews.createdAt != null)
              ? visitNews.createdAt!.toIso8601String()
              : DateTime.now().toIso8601String(),
          'descripcion_new': visitNews.descripcionNew,
          'locations_add': visitNews.locationsAdd,
        };
      }).toList();

      // Obtener visits_add desde SQLite (llena _mediaFilesToUpload)
      final visitsAddJson = await _getVisitsAddFromSQLiteForJson(widget.idCompany);

      final payload = {
        'created_at': DateTime.now().toIso8601String(),
        'news_add': newsAddJson,
        'visits_add': visitsAddJson,
        'id_company': widget.idCompany,
        'ids_headquarters': widget.idsHeadquarters,
        'imei': widget.imei,
        'id_user': FFAppState().userSelected.idUser,
      };

      debugPrint('📤 ===== PAYLOAD MULTIPART =====');
      debugPrint('   - URL: $url');
      debugPrint('   - News: ${newsAddJson.length}');
      debugPrint('   - Visits: ${visitsAddJson.length}');
      debugPrint('   - Archivos media: ${_mediaFilesToUpload.length}');

      // DEBUG: Verificar que status_response tenga solo referencias, no base64
      if (visitsAddJson.isNotEmpty && visitsAddJson[0]['visits_details'] != null) {
        final firstDetail = (visitsAddJson[0]['visits_details'] as List).firstOrNull;
        if (firstDetail != null) {
          debugPrint('   🔍 DEBUG - Primer detail status_response: ${firstDetail['status_response']}');
        }
      }

      // Crear request multipart
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ${widget.authToken}';

      // Agregar JSON como campo de texto (nombre esperado por el backend)
      request.fields['SyncModelJson'] = jsonEncode(payload);

      // Agregar archivos de media
      for (final entry in _mediaFilesToUpload.entries) {
        final fieldName = entry.key; // "media_0", "media_1", etc.
        final filePath = entry.value;

        final file = File(filePath);
        if (await file.exists()) {
          final fileBytes = await file.readAsBytes();
          final fileName = filePath.split('/').last;

          // Detectar tipo MIME
          String mimeType = 'application/octet-stream';
          if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          } else if (fileName.endsWith('.png')) {
            mimeType = 'image/png';
          } else if (fileName.endsWith('.mp4')) {
            mimeType = 'video/mp4';
          } else if (fileName.endsWith('.mov')) {
            mimeType = 'video/quicktime';
          }

          request.files.add(http.MultipartFile.fromBytes(
            fieldName,
            fileBytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ));

          debugPrint('   📎 $fieldName: $fileName (${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        } else {
          debugPrint('   ⚠️ Archivo no encontrado: $filePath');
        }
      }

      // Enviar request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 ===== RESPUESTA DEL API =====');
      debugPrint('   - Status Code: ${response.statusCode}');
      debugPrint('   - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        debugPrint('✅ Sincronización multipart exitosa');

        // Limpiar datos después de sincronización exitosa
        await _cleanupSQLiteDataAfterSync();
        return true;
      } else {
        debugPrint('❌ Error en sincronización multipart');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en fallback JSON (SyncVisitsAdd): $e');
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
          v.Id_user as id_user,
          v.Id_device as id_device,
          v.Created_at as created_at,
          v.Latitude,
          v.Longitude,
          v.Altitude,
          v.Error_horizontal,
          v.Rfid as rfid,

          vd.Id_visit_detail as detail_id,
          vd.Id_activity_status as detail_activity_status,
          vd.Status_option as detail_status_option,
          vd.Status_response as detail_status_response,

          ast.Type_status as detail_type_status
        FROM Visits v
        LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        LEFT JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
        WHERE v.Id_company = ?
        ORDER BY v.Created_at DESC, vd.Id_visit_detail ASC
      ''', [idCompany]);

      // NO cerrar la BD todavía - la necesitamos para obtener Visits_locations
      debugPrint('📍 Obteniendo ubicaciones desde tabla Visits_locations (SQLite)...');

      final Map<int, Map<String, dynamic>> visitsMap = {};

      for (final row in rawData) {
        final int visitId = row['id_visit'];

        if (!visitsMap.containsKey(visitId)) {
          // Parsear y validar created_at
          String createdAt;
          try {
            final rawCreatedAt = row['created_at'];
            if (rawCreatedAt != null && rawCreatedAt.toString().isNotEmpty) {
              final parsedDate = DateTime.tryParse(rawCreatedAt.toString());
              if (parsedDate != null && parsedDate.year > 1900) {
                createdAt = parsedDate.toIso8601String();
              } else {
                createdAt = DateTime.now().toIso8601String();
              }
            } else {
              createdAt = DateTime.now().toIso8601String();
            }
          } catch (e) {
            createdAt = DateTime.now().toIso8601String();
            debugPrint('⚠️ Error parseando created_at para visita $visitId: $e');
          }

          // Obtener las últimas 3 ubicaciones desde la tabla Visits_locations
          final locationRows = await db.rawQuery('''
            SELECT Latitude, Longitude, Altitude, HorizontalError, CreatedAt
            FROM Visits_locations
            WHERE Id_visit = ?
            ORDER BY CreatedAt DESC
            LIMIT 3
          ''', [visitId]);

          debugPrint('📍 Visita $visitId: ${locationRows.length} ubicaciones encontradas en Visits_locations');

          // Construir location_default desde los campos de la tabla Visits
          final String locationDefault = 'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}';

          // Construir locations_add: primero location_default, luego las últimas 3 de Visits_locations
          final List<String> locationsAddList = [locationDefault];

          // Agregar las últimas 3 ubicaciones de Visits_locations
          locationsAddList.addAll(locationRows.map((locRow) {
            final lat = locRow['Latitude'] ?? 0.0;
            final lon = locRow['Longitude'] ?? 0.0;
            final alt = locRow['Altitude'] ?? 0.0;
            final erh = locRow['HorizontalError'] ?? 0.0;
            return 'LAT:$lat;LON:$lon;ALT:$alt;ERH:$erh';
          }).toList());

          debugPrint('📍 locations_add total: ${locationsAddList.length} ubicaciones (1 default + ${locationRows.length} adicionales)');

          visitsMap[visitId] = {
            'created_at': createdAt,
            'id_visit': row['id_visit'],
            'id_company': row['id_company'],
            'id_activity': row['id_activity'],
            'id_headquarter': row['id_headquarter'],
            'id_product': row['id_product'],
            'id_user': row['id_user'],
            'id_device': row['id_device'],
            'rfid': row['rfid'],
            'visits_details': <Map<String, dynamic>>[],
            'locations_add': locationsAddList,
            'location_default': locationDefault,
            '_details_ids': <int>{},
          };
        }

        final visit = visitsMap[visitId]!;

        // Procesar detalles de visita
        if (row['detail_id'] != null) {
          final int detailId = row['detail_id'];
          if (!visit['_details_ids'].contains(detailId)) {
            visit['_details_ids'].add(detailId);

            String statusResponse = row['detail_status_response'] ?? '';
            final String typeStatus = (row['detail_type_status'] ?? '').toString().toLowerCase();

            // Para photo/video: crear referencia "media_X" y guardar path del archivo
            if ((typeStatus == 'photo' || typeStatus == 'video') && statusResponse.isNotEmpty) {
              // Verificar que sea una ruta de archivo válida
              if (statusResponse.contains('/') && !statusResponse.startsWith('http')) {
                final mediaFieldName = 'media_$_mediaFileCounter';
                _mediaFilesToUpload[mediaFieldName] = statusResponse;
                statusResponse = mediaFieldName; // Reemplazar con referencia
                _mediaFileCounter++;

                final filePath = _mediaFilesToUpload[mediaFieldName]!;
                debugPrint('📎 Archivo $typeStatus agregado: $mediaFieldName → ${filePath.length > 80 ? "${filePath.substring(0, 80)}..." : filePath}');
              }
            }

            visit['visits_details'].add({
              'id_visit_detail': 0,
              'id_visit': 0,
              'id_activity_status': row['detail_activity_status'],
              'status_option': row['detail_status_option'] ?? '',
              'status_response': statusResponse,
            });
          }
        }
      }

      final List<Map<String, dynamic>> visitsFormatted =
          visitsMap.values.map((visit) {
        visit.remove('_details_ids');
        return visit;
      }).toList();

      // Cerrar la base de datos
      await db.close();

      debugPrint('✅ Visits_add procesadas: ${visitsFormatted.length}');
      for (var i = 0; i < visitsFormatted.length && i < 5; i++) {
        final visit = visitsFormatted[i];
        debugPrint('   📍 Visita ${visit['id_visit']}: ${visit['locations_add'].length} ubicaciones');
      }

      return visitsFormatted;
    } catch (e) {
      debugPrint('❌ Error obteniendo visits_add: $e');
      return [];
    }
  }

  /// Limpia datos de SQLite después de sincronización exitosa
  Future<void> _cleanupSQLiteDataAfterSync() async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      await db.transaction((txn) async {
        // Limpiar visitas, detalles y ubicaciones
        await txn.delete('Visits');
        await txn.delete('Visits_details');
        await txn.delete('Visits_locations');
        debugPrint('✅ Visitas, detalles y ubicaciones limpiadas de SQLite');
      });

      await db.close();

      // Limpiar AppState
      FFAppState().visitsAdd = [];
      FFAppState().newsAdd = [];

      debugPrint('✅ AppState limpiado');
    } catch (e) {
      debugPrint('⚠️ Error limpiando datos después de sincronización: $e');
    }
  }

  // ==========================================================================
  // MÉTODOS PARA SINCRONIZACIÓN COMPLETA
  // ==========================================================================

  /// Verifica conexión a Internet con calidad usando checkInternetQuality
  Future<bool> _checkInternetConnectionWithQuality() async {
    try {
      debugPrint('🌐 Verificando calidad de conexión con checkInternetQuality...');

      // Llamar a la función checkInternetQuality personalizada
      final result = await actions.checkInternetQuality();

      // Extraer los valores del resultado
      final String message = result['message'] as String? ?? 'Error desconocido';
      final bool isGoodConnection = result['isGoodConnection'] as bool? ?? false;

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
      if (!isGoodConnection && mounted) {
        debugPrint('⚠️ Conexión no apta para sincronización: $message');

        await Future.delayed(const Duration(milliseconds: 500));

        final shouldContinue = await showDialog<bool>(
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
                    Row(
                      children: [
                        const Icon(Icons.wifi, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '• Conectarte a una red WiFi',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '• Moverte a una zona con mejor señal',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
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
                    Navigator.pop(dialogContext, true);
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
        );

        if (shouldContinue != true) {
          throw Exception('Envío cancelado por el usuario');
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// Recolecta datos de visitas para sincronización
  Future<void> _collectSyncData(SyncStats stats) async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Obtener todas las visitas con sus relaciones
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

      stats.visitsSummary = visitsMap.values.toList();
      stats.totalVisits = stats.visitsSummary.length;
      stats.totalVisitDetails = totalDetails;
      stats.totalVisitLocations = totalLocations;

      // Contar location_tracking
      final locationsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Location_tracking',
      );
      stats.totalLocations = locationsCount.first['count'] as int? ?? 0;

      // Preparar newsAdd summary
      stats.newsAddSummary = widget.newsAdd.map((visitNews) {
        final map = visitNews.toMap();
        return {
          'id_new': map['id_new'] ?? map['idNew'] ?? 0,
          'descripcion': map['descripcion_new'] ?? map['descripcionNew'] ?? '',
          'locations_count': (map['locations_add'] ?? map['locationsAdd'] ?? []).length,
        };
      }).toList();
      stats.totalNewsAdd = widget.newsAdd.length;

      await db.close();

      debugPrint('✅ Estadísticas COMPLETAS recolectadas:');
      debugPrint('   📋 Visitas: ${stats.totalVisits}');
      debugPrint('      └─ Detalles totales: ${stats.totalVisitDetails}');
      debugPrint('      └─ Locations de visitas: ${stats.totalVisitLocations}');
      debugPrint('   📍 Location_tracking: ${stats.totalLocations}');
      debugPrint('   📰 NewsAdd: ${stats.totalNewsAdd}');
    } catch (e) {
      debugPrint('❌ Error recolectando datos: $e');
      rethrow;
    }
  }

  /// Analiza zonas de exclusión modificadas
  Future<void> _analyzeExclusionZones(SyncStats stats) async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      debugPrint('🔍 Obteniendo TODAS las zonas de exclusión con relaciones completas...');

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

      stats.exclusionModifications = modificationsRaw;
      stats.totalExclusionZones = modificationsRaw.length;
      stats.hasPendingExclusions = modificationsRaw.isNotEmpty;

      await db.close();

      debugPrint('✅ Zonas de exclusión COMPLETAS analizadas:');
      debugPrint('   📍 Total modificaciones: ${stats.totalExclusionZones}');
      debugPrint('   🔔 Hay pendientes: ${stats.hasPendingExclusions}');
    } catch (e) {
      debugPrint('❌ Error analizando exclusiones: $e');
      rethrow;
    }
  }

  /// Sincroniza zonas de exclusión al API
  Future<void> _syncExclusionZones(SyncStats stats) async {
    try {
      debugPrint('🔄 Sincronizando zonas de exclusión...');

      // Preparar el payload
      final List<Map<String, dynamic>> exclusionZonesPayload = [];

      for (var modification in stats.exclusionModifications) {
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

      debugPrint('📦 Total de modificaciones a enviar: ${exclusionZonesPayload.length}');

      // Crear el payload completo
      final Map<String, dynamic> fullPayload = {
        'exclusion_zones_modifications': exclusionZonesPayload,
      };

      // Convertir a JSON
      final String jsonBody = jsonEncode(fullPayload);

      debugPrint('📤 POST /Sync_times/ProcessExclusionZonesModification');

      // Enviar al API
      const String url = 'https://api.clickpalm.com/Sync_times/ProcessExclusionZonesModification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonBody,
      );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        debugPrint('✅ Zonas de exclusión sincronizadas exitosamente');

        // Limpiar la tabla Exclusion_zones_history después de sincronizar
        await _cleanExclusionZonesHistory();
      } else {
        throw Exception('Error al sincronizar exclusiones: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando exclusiones: $e');
      rethrow;
    }
  }

  /// Limpia el historial de zonas de exclusión
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

  /// Recolecta productos pendientes de sincronización
  Future<void> _collectProductsData(SyncStats stats) async {
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
          Id_rfid,
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

      stats.productsSummary = [];

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

        stats.productsSummary.add(ProductSummary(
          idProduct: idProduct,
          idHeadquarter: row['Id_headquarter'] as int,
          idCompany: row['Id_company'] as int,
          idType: row['Id_type'] as int?,
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

      stats.totalProductsNew = newCount;
      stats.totalProductsUpdated = updatedCount;
      stats.hasPendingProducts = productsRaw.isNotEmpty;

      debugPrint('✅ Productos pendientes recolectados:');
      debugPrint('   📦 Nuevos (POST): ${stats.totalProductsNew}');
      debugPrint('   🔄 Actualizados (PUT): ${stats.totalProductsUpdated}');
      debugPrint('   📊 Total: ${stats.getTotalPendingProducts()}');
    } catch (e) {
      debugPrint('❌ Error recolectando productos: $e');
      stats.totalProductsNew = 0;
      stats.totalProductsUpdated = 0;
      stats.hasPendingProducts = false;
    }
  }

  /// Sincroniza productos pendientes al API
  Future<bool> _syncProducts(SyncStats stats) async {
    if (!stats.hasPendingProducts) {
      debugPrint('ℹ️ No hay productos pendientes de sincronización');
      return true;
    }

    try {
      debugPrint('🔄 Sincronizando productos...');
      debugPrint('   📦 Nuevos: ${stats.totalProductsNew}');
      debugPrint('   🔄 Actualizados: ${stats.totalProductsUpdated}');

      int successCount = 0;
      int errorCount = 0;
      List<int> syncedProductIds = [];

      for (final product in stats.productsSummary) {
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
          // Para productos nuevos se envía id_product = 0 para que el servidor asigne el ID real
          final Map<String, dynamic> productPayload = {
            'id_product': product.syncStatus == 'new' ? 0 : product.idProduct,
            'id_headquarter': product.idHeadquarter,
            'id_company': product.idCompany,
            'id_type': product.idType ?? 0,
            'name_product': product.nameProduct ?? '',
            'type_product': product.typeProduct ?? '',
            'r_f_i_d': product.rfid ?? '',
            'created_at': product.createdAt ?? DateTime.now().toIso8601String(),
            'modified_at': product.modifiedAt ?? DateTime.now().toIso8601String(),
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

            debugPrint('📤 POST /Products - Nuevo producto ID: ${product.idProduct}');

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

            debugPrint('📤 PUT /Products/${product.idProduct} - Actualizar producto');

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

      debugPrint('📊 Resumen de sincronización de productos:');
      debugPrint('   ✅ Exitosos: $successCount');
      debugPrint('   ❌ Errores: $errorCount');

      // Actualizar Sync_status a 'synced' para productos sincronizados exitosamente
      if (syncedProductIds.isNotEmpty) {
        await _updateProductsSyncStatus(syncedProductIds);
      }

      // Retornar true si al menos un producto fue sincronizado
      return successCount > 0 || errorCount == 0;
    } catch (e) {
      debugPrint('❌ Error general sincronizando productos: $e');
      return false;
    }
  }

  /// Actualiza el Sync_status de productos sincronizados
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

  /// Sincroniza visitas con fallback
  Future<bool> _syncVisits() async {
    try {
      debugPrint('🔄 Sincronizando visitas...');

      // INTENTO 1: Endpoint multipart
      debugPrint('📤 Intento 1: Usando endpoint multipart (SyncVisitsAddMultipart)');

      bool multipartSuccess = false;
      if (mounted) {
        multipartSuccess = await actions.syncVisitsv2(
          context,
          widget.newsAdd,
          widget.idCompany,
          widget.idsHeadquarters,
          widget.imei,
          widget.authToken,
        );
      }

      if (multipartSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint multipart');
        return true;
      }

      // INTENTO 2: FALLBACK - Endpoint JSON
      debugPrint('⚠️ Endpoint multipart falló, iniciando FALLBACK...');
      debugPrint('📤 Intento 2: Usando endpoint simple JSON (SyncVisitsAdd)');

      final bool jsonSuccess = await _syncVisitsJsonFallback();

      if (jsonSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint JSON (fallback)');
        return true;
      } else {
        debugPrint('❌ Ambos endpoints fallaron (multipart y JSON)');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando visitas: $e');
      return false;
    }
  }

  /// Guarda un backup JSON de las visitas antes de sincronizar
  Future<void> _saveVisitsBackup() async {
    try {
      debugPrint('💾 Guardando backup JSON de visitas...');

      // Obtener todas las visitas del AppState
      final visits = FFAppState().visitsAdd;

      if (visits.isEmpty) {
        debugPrint('⚠️ No hay visitas para guardar en backup');
        return;
      }

      // Llamar a la función que guarda el archivo JSON
      await actions.saveVisitsToDownloads(visits);

      debugPrint('✅ Backup JSON guardado exitosamente (${visits.length} visitas)');
    } catch (e) {
      debugPrint('⚠️ Error guardando backup JSON: $e');
      // No lanzar excepción para no interrumpir la sincronización
      // El backup es opcional, si falla continuamos con la sincronización
    }
  }

  /// Sincroniza visitas en modo optimizado (sin compresión) con fallback
  /// Para redes lentas: envía visits_add y news_add sin comprimir
  Future<bool> _syncVisitsOptimized() async {
    try {
      debugPrint('🔄 Sincronizando visitas en modo optimizado (sin compresión)...');

      // INTENTO 1: Endpoint simple JSON (SyncVisitsAdd) - sin compresión
      debugPrint('📤 Intento 1: Usando endpoint simple JSON (SyncVisitsAdd)');

      final bool jsonSuccess = await _syncVisitsJsonFallback();

      if (jsonSuccess) {
        debugPrint('✅ Sincronización optimizada exitosa con endpoint JSON');
        return true;
      }

      // INTENTO 2: FALLBACK - Endpoint multipart
      debugPrint('⚠️ Endpoint JSON falló, iniciando FALLBACK a multipart...');
      debugPrint('📤 Intento 2: Usando endpoint multipart (SyncVisitsAddMultipart)');

      bool multipartSuccess = false;
      if (mounted) {
        multipartSuccess = await actions.syncVisitsv2(
          context,
          widget.newsAdd,
          widget.idCompany,
          widget.idsHeadquarters,
          widget.imei,
          widget.authToken,
        );
      }

      if (multipartSuccess) {
        debugPrint('✅ Sincronización exitosa con endpoint multipart (fallback)');
        return true;
      } else {
        debugPrint('❌ Ambos endpoints fallaron (JSON y multipart)');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando visitas optimizadas: $e');
      return false;
    }
  }
}

// ==========================================================================
// CLASES DE DATOS AUXILIARES
// ==========================================================================

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
  int? idType;
  String? nameProduct;
  String? typeProduct;
  String? rfid;
  String? stateProduct;
  String? descriptionProduct;
  int? line;
  int? palm;
  String syncStatus;
  String? createdAt;
  String? modifiedAt;
  String? locationRaw;
  List<Map<String, dynamic>>? coordinates;

  ProductSummary({
    required this.idProduct,
    required this.idHeadquarter,
    required this.idCompany,
    this.idType,
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

class SyncStats {
  // Visitas
  List<VisitSummary> visitsSummary = [];
  int totalVisits = 0;
  int totalVisitDetails = 0;
  int totalVisitLocations = 0;
  int totalLocations = 0;

  // NewsAdd
  List<Map<String, dynamic>> newsAddSummary = [];
  int totalNewsAdd = 0;

  // Exclusiones
  List<Map<String, dynamic>> exclusionModifications = [];
  int totalExclusionZones = 0;
  bool hasPendingExclusions = false;

  // Productos
  List<ProductSummary> productsSummary = [];
  int totalProductsNew = 0;
  int totalProductsUpdated = 0;
  bool hasPendingProducts = false;

  bool hasInternetConnection = false;

  int getTotalPendingProducts() => totalProductsNew + totalProductsUpdated;
}
