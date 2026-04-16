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
import 'dart:io';
import '/services/map_download_service.dart';
import '/services/ortomosaic_download_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TEMA DE COLORES (dark green)
// ─────────────────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D1521);
const _cardBg = Color(0xFF1A2535);
const _cardBorder = Color(0xFF004629);
const _green = Color(0xFF004629);
const _greenLight = Color(0xFF00a86b);
const _greenNeon = Color(0xFF00ff9f);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF8A9BB0);
const _errorColor = Color(0xFFE53935);
const _successColor = Color(0xFF00a86b);

// ─────────────────────────────────────────────────────────────────────────────

class LoadResourcesMapTiles extends StatefulWidget {
  const LoadResourcesMapTiles({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  State<LoadResourcesMapTiles> createState() => _LoadResourcesMapTilesState();
}

class _LoadResourcesMapTilesState extends State<LoadResourcesMapTiles>
    with TickerProviderStateMixin {
  final _mapService = MapDownloadService();
  final _ortService = OrtomosaicDownloadService();

  StreamSubscription<MapDownloadState>? _mapSub;
  StreamSubscription<Map<String, OrtomosaicDownloadProgress>>? _ortSub;

  // Estado mapa base
  bool _checkingBase = true;

  // Estado ortomosaicos
  bool _loadingZones = false;
  bool _loadingSizes = false;
  String? _zonesError;
  List<ZoneTile> _zones = [];
  Map<String, OrtomosaicInfo?> _downloadedInfo = {};
  Map<String, int> _zoneSizes = {}; // bytes esperados por zona (del endpoint S3Files)

  // Progreso de todas las descargas activas
  Map<String, OrtomosaicDownloadProgress> _activeDownloads = {};

  @override
  void initState() {
    super.initState();
    _initBase();
    _initZones();

    _mapSub = _mapService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });

    // Solo actualizar UI local — el SnackBar global lo maneja el servicio
    _ortSub = _ortService.progressStream.listen((downloads) {
      if (!mounted) return;
      setState(() => _activeDownloads = downloads);

      // Cuando terminan descargas, actualizar estado descargado
      final finished = downloads.values
          .where((p) => p.isComplete || p.hasError || p.isCancelled);
      if (finished.isNotEmpty) {
        Future.delayed(const Duration(seconds: 2), () {
          _ortService.clearFinished();
          _refreshDownloadedInfo();
        });
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    _ortSub?.cancel();
    super.dispose();
  }

  // ── Inicialización ─────────────────────────────────────────────────────

  Future<void> _initBase() async {
    await _mapService.checkExistingFile();
    if (mounted) setState(() => _checkingBase = false);
    // Obtener tamaño real del PMTiles en background (HEAD request a S3)
    _mapService.fetchRemoteSize();
  }

  Future<void> _initZones() async {
    if (mounted) setState(() { _loadingZones = true; _zonesError = null; });
    try {
      final zones = await _ortService.fetchActiveZones();
      // Consultar estado descargado (solo SQLite, sin peticiones S3)
      final info = <String, OrtomosaicInfo?>{};
      for (final z in zones) {
        info[z.relativePath] = await _ortService.getOrtomosaicInfo(z.relativePath);
      }
      if (mounted) setState(() { _zones = zones; _downloadedInfo = info; });

      // Cargar tamaños reales en background (endpoint S3Files, ~1 call por carpeta raíz)
      _fetchSizesInBackground(zones);
    } catch (e) {
      if (mounted) setState(() => _zonesError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Future<void> _fetchSizesInBackground(List<ZoneTile> zones) async {
    if (mounted) setState(() => _loadingSizes = true);
    try {
      final sizes = await _ortService.fetchFolderSizes(zones);
      if (mounted) setState(() => _zoneSizes = sizes);
    } catch (_) {
      // Silencioso — sin tamaños disponibles
    } finally {
      if (mounted) setState(() => _loadingSizes = false);
    }
  }

  Future<void> _refreshDownloadedInfo() async {
    for (final z in _zones) {
      final info = await _ortService.getOrtomosaicInfo(z.relativePath);
      if (mounted) setState(() => _downloadedInfo[z.relativePath] = info);
    }
  }

  // ── Acciones mapa base ─────────────────────────────────────────────────

  void _startBaseDownload() {
    _mapService.startDownload();
    if (mounted) setState(() {});
    _showSimpleSnack('Descargando mapa base en segundo plano...', _green);
  }

  Future<void> _deleteBaseMap() async {
    final ok = await _confirmDialog(
      title: 'Eliminar mapa base',
      message: '¿Eliminar el mapa base de Colombia?\nDeberás volver a descargarlo.',
    );
    if (ok != true) return;
    final fp = _mapService.filePath;
    if (fp.isNotEmpty) {
      final f = File(fp);
      if (await f.exists()) await f.delete();
      final pf = File('$fp.partial');
      if (await pf.exists()) await pf.delete();
    }
    _mapService.resetState();
    FFAppState().update(() => FFAppState().pathPmtiles = '');
    if (mounted) setState(() {});
  }

  // ── Acciones ortomosaicos ──────────────────────────────────────────────

  Future<void> _startOrtDownload(ZoneTile zone) async {
    await _ortService.downloadZone(zone);
  }

  Future<void> _deleteOrt(ZoneTile zone) async {
    final ok = await _confirmDialog(
      title: 'Eliminar ortomosaico',
      message: '¿Eliminar "${zone.displayName}"?\nDeberás volver a descargarlo.',
    );
    if (ok != true) return;
    await _ortService.deleteZone(zone.relativePath);
    await _refreshDownloadedInfo();
    _showSimpleSnack('${zone.displayName} eliminado', _errorColor);
  }


  void _showSimpleSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool?> _confirmDialog({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _cardBorder.withValues(alpha: 0.5))),
        title: Text(title, style: const TextStyle(color: _textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: _textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _errorColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildBaseSection(),
                    const SizedBox(height: 20),
                    _buildOrtSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        _iconBox(Icons.map_rounded, const [Color(0xFF004D40), Color(0xFF00695C)]),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gestión de Mapas',
                style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Descarga y administra tus mapas offline',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ── Sección mapa base ─────────────────────────────────────────────────────

  Widget _buildBaseSection() {
    return _Card(
      icon: Icons.public_rounded,
      title: 'Mapa Base',
      subtitle: 'Colombia completa · Cartografía general',
      child: _checkingBase ? _spinner() : _buildBaseContent(),
    );
  }

  Widget _buildBaseContent() {
    final isComplete = _mapService.isComplete;
    final isDownloading = _mapService.isDownloading && !_mapService.isPaused;
    final isPaused = _mapService.isPaused;
    final progress = _mapService.progress;
    final dlBytes = _mapService.downloadedBytes;
    final totalBytes = _mapService.totalBytes;
    final speed = _mapService.speed;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        _Chip(Icons.storage_rounded,
            totalBytes > 0 ? _fmtBytes(totalBytes) : '— MB'),
        _Chip(Icons.wifi_rounded, 'Recomendado WiFi'),
        _Chip(Icons.place_rounded, 'Colombia'),
      ]),
      const SizedBox(height: 14),
      if (isComplete) ...[
        _StatusBadge(Icons.check_circle_rounded,
            'Descargado · ${_fmtBytes(totalBytes)}', _successColor),
        const SizedBox(height: 12),
        _DangerBtn('Eliminar y re-descargar', Icons.delete_outline_rounded, _deleteBaseMap),
      ] else if (isDownloading || isPaused) ...[
        _ProgressBar(progress),
        const SizedBox(height: 6),
        Row(children: [
          Text('${_fmtBytes(dlBytes)} / ${_fmtBytes(totalBytes)} · ${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _greenNeon, fontSize: 12)),
          const Spacer(),
          if (speed.isNotEmpty)
            Text(speed, style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        if (isPaused)
          _GreenBtn('Reanudar', Icons.play_arrow_rounded,
              _mapService.resumeDownload, fullWidth: false)
        else
          _GreenBtn('Pausar', Icons.pause_rounded,
              _mapService.pauseDownload, fullWidth: false),
      ] else ...[
        _GreenBtn('Descargar mapa base', Icons.download_rounded,
            _startBaseDownload, fullWidth: true),
      ],
    ]);
  }

  // ── Sección ortomosaicos ──────────────────────────────────────────────────

  Widget _buildOrtSection() {
    return _Card(
      icon: Icons.satellite_alt_rounded,
      title: 'Ortomosaicos de Vuelos',
      subtitle: 'Imágenes detalladas por zona · Zoom 16–21',
      trailingAction: _loadingZones
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: _greenLight, strokeWidth: 2))
          : GestureDetector(
              onTap: _initZones,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded, color: _greenLight, size: 18),
              )),
      child: Column(children: [
        if (_zonesError != null) _buildZonesError(),
        if (_zones.isEmpty && !_loadingZones && _zonesError == null) _buildZonesEmpty(),
        ..._zones.map(_buildZoneCard),
      ]),
    );
  }

  Widget _buildZonesError() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: _errorColor, size: 16),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('No se pudieron cargar las zonas.',
                style: TextStyle(color: _textSecondary, fontSize: 13))),
        GestureDetector(
            onTap: _initZones,
            child: const Text('Reintentar',
                style: TextStyle(color: _greenLight, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildZonesEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Icon(Icons.layers_clear_rounded, color: _textSecondary.withValues(alpha: 0.3), size: 36),
        const SizedBox(height: 8),
        const Text('No hay ortomosaicos activos',
            style: TextStyle(color: _textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildZoneCard(ZoneTile zone) {
    final path = zone.relativePath;
    final info = _downloadedInfo[path];
    final isDownloaded = info != null;
    final progress = _activeDownloads[path];
    final isActive = progress?.isActive ?? false;
    final isError = progress?.hasError ?? false;
    final isComplete = progress?.isComplete ?? false;
    final isCancelled = progress?.isCancelled ?? false;

    // Color de borde según estado
    Color borderColor;
    if (isActive) borderColor = _greenLight.withValues(alpha: 0.5);
    else if (isDownloaded) borderColor = _greenLight.withValues(alpha: 0.25);
    else if (isError) borderColor = _errorColor.withValues(alpha: 0.35);
    else borderColor = _cardBorder.withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0E2A1A)
            : const Color(0xFF111E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Encabezado ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _zoneIcon(isDownloaded, isActive, isError),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(zone.displayName,
                  style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              _zoneSubtitle(path, info, progress, isActive, isDownloaded, isError, isCancelled),
            ]),
          ),
          // Badge de estado
          if (isActive)
            _badge('Descargando', _greenNeon)
          else if (isComplete)
            _badge('Completado', _successColor)
          else if (isDownloaded)
            _badge('Disponible', _greenLight)
          else if (isError)
            _badge('Error', _errorColor),
        ]),

        // ── Progreso inline ──
        if (isActive && progress != null) ...[
          const SizedBox(height: 12),
          _ProgressBar(progress.fraction),
          const SizedBox(height: 5),
          Row(children: [
            Text(
              progress.expectedTotalBytes > 0
                  ? '${progress.downloadedMB} MB / ${progress.totalMB} MB'
                  : '${progress.downloadedTiles} / ${progress.totalTiles} tiles · ${progress.downloadedMB} MB',
              style: const TextStyle(color: _greenNeon, fontSize: 11),
            ),
            const Spacer(),
            Text(progress.percent,
                style: const TextStyle(color: _greenLight, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ],

        // ── Botones ──
        const SizedBox(height: 12),
        _zoneActions(zone, isDownloaded, isActive, isError),
      ]),
    );
  }

  Widget _zoneIcon(bool isDownloaded, bool isActive, bool isError) {
    Color bg;
    IconData icon;
    Color iconColor;
    if (isActive) {
      bg = _greenNeon.withValues(alpha: 0.12);
      icon = Icons.download_rounded;
      iconColor = _greenNeon;
    } else if (isDownloaded) {
      bg = _greenLight.withValues(alpha: 0.12);
      icon = Icons.check_rounded;
      iconColor = _greenNeon;
    } else if (isError) {
      bg = _errorColor.withValues(alpha: 0.12);
      icon = Icons.error_outline_rounded;
      iconColor = _errorColor;
    } else {
      bg = _textSecondary.withValues(alpha: 0.08);
      icon = Icons.terrain_rounded;
      iconColor = _textSecondary;
    }
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, color: iconColor, size: 17),
    );
  }

  Widget _zoneSubtitle(
      String zonePath, OrtomosaicInfo? info, OrtomosaicDownloadProgress? progress,
      bool isActive, bool isDownloaded, bool isError, bool isCancelled) {
    if (isActive && progress != null) {
      final total = progress.totalMB != '?' ? '/ ${progress.totalMB} MB' : '';
      return Text('Descargando... ${progress.downloadedMB} MB $total',
          style: const TextStyle(color: _greenLight, fontSize: 11));
    }
    if (isError && progress != null) {
      return Text('Error: ${progress.errorMessage ?? "desconocido"}',
          style: const TextStyle(color: _errorColor, fontSize: 11),
          maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    if (isCancelled) {
      return const Text('Cancelado',
          style: TextStyle(color: _textSecondary, fontSize: 11));
    }
    if (isDownloaded && info != null) {
      return Text(
          '${info.tileCount} tiles · ${_fmtBytes(info.totalBytes)} · Zoom ${info.minZoom}–${info.maxZoom}',
          style: const TextStyle(color: _textSecondary, fontSize: 11));
    }
    // Sin descargar: mostrar tamaño real si ya lo tenemos
    final sizeBytes = _zoneSizes[zonePath] ?? 0;
    if (sizeBytes > 0) {
      return Text(
        '~${_fmtBytes(sizeBytes)} · Zoom 16–21',
        style: const TextStyle(color: _textSecondary, fontSize: 11),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('Zoom 16–21', style: TextStyle(color: _textSecondary, fontSize: 11)),
      if (_loadingSizes) ...[
        const SizedBox(width: 6),
        const SizedBox(width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: _textSecondary)),
      ],
    ]);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _zoneActions(ZoneTile zone, bool isDownloaded, bool isActive, bool isError) {
    final path = zone.relativePath;

    if (isActive) {
      return _DangerBtn('Cancelar descarga', Icons.stop_rounded,
          () => _ortService.cancelDownload(path), compact: true);
    }

    if (isDownloaded) {
      return Row(children: [
        Expanded(child: _DangerBtn('Eliminar', Icons.delete_outline_rounded,
            () => _deleteOrt(zone), compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _GreenBtn('Re-descargar', Icons.refresh_rounded,
            () async {
              await _ortService.deleteZone(path);
              await _refreshDownloadedInfo();
              await _startOrtDownload(zone);
            }, compact: true)),
      ]);
    }

    if (isError) {
      return _GreenBtn('Reintentar', Icons.replay_rounded,
          () => _startOrtDownload(zone), fullWidth: true, compact: true);
    }

    return _GreenBtn('Descargar esta zona', Icons.download_rounded,
        () => _startOrtDownload(zone), fullWidth: true, compact: true);
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _spinner() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator(color: _greenLight, strokeWidth: 2)));

  Widget _iconBox(IconData icon, List<Color> grad) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 22));
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES REUTILIZABLES
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  final Widget? trailingAction;
  const _Card({required this.icon, required this.title, required this.subtitle,
      required this.child, this.trailingAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_green.withValues(alpha: 0.18), Colors.transparent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.25))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: _greenNeon, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 1),
              Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ])),
            if (trailingAction != null) trailingAction!,
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: _greenLight),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ]));
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusBadge(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]));
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar(this.value);
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: const Color(0xFF1A3A2A),
          color: _greenNeon,
          minHeight: 5));
}

class _GreenBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool fullWidth, compact;
  const _GreenBtn(this.label, this.icon, this.onTap,
      {this.fullWidth = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    Widget btn = GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 12),
        decoration: BoxDecoration(
          gradient: disabled ? null : const LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00695C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: disabled ? const Color(0xFF1A2535) : null,
          borderRadius: BorderRadius.circular(10),
          border: disabled ? Border.all(color: _cardBorder.withValues(alpha: 0.2)) : null,
          boxShadow: disabled ? null : [
            BoxShadow(color: const Color(0xFF004D40).withValues(alpha: 0.35),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(icon, color: disabled ? _textSecondary : Colors.white, size: 15),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(
                  color: disabled ? _textSecondary : Colors.white,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600)),
            ]),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class _DangerBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  const _DangerBtn(this.label, this.icon, this.onTap, {this.compact = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 11),
          decoration: BoxDecoration(
              color: _errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _errorColor.withValues(alpha: 0.35))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _errorColor, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                color: _errorColor, fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600)),
          ])));
}
