import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/custom_code/actions/adb_nfc_client_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/app_state.dart';

enum _AdbState { waiting, connected, transferring, complete, error }

class AdbInstallPageWidget extends StatefulWidget {
  const AdbInstallPageWidget({super.key});

  @override
  State<AdbInstallPageWidget> createState() => _AdbInstallPageWidgetState();
}

class _AdbInstallPageWidgetState extends State<AdbInstallPageWidget> {
  _AdbState _state = _AdbState.waiting;
  double _progress = 0.0;
  DbTransferCompleteEvent? _result;
  bool _isRetrying = false;

  StreamSubscription<bool>? _connSub;
  StreamSubscription<double>? _progressSub;
  StreamSubscription<DbTransferCompleteEvent>? _completeSub;

  @override
  void initState() {
    super.initState();

    _connSub =
        AdbNfcClientService.instance.onConnectionChanged.listen((connected) {
      if (!mounted) return;
      setState(() {
        _state = connected ? _AdbState.connected : _AdbState.waiting;
      });
    });

    _progressSub =
        AdbNfcClientService.instance.onDbTransferProgress.listen((prog) {
      if (!mounted) return;
      setState(() {
        _state = _AdbState.transferring;
        _progress = prog;
      });
    });

    _completeSub =
        AdbNfcClientService.instance.onDbTransferComplete.listen((result) async {
      if (!mounted) return;
      FFAppState().isSync = true;
      FFAppState().lastSyncBase = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('clickpalm_adb_install', true);
      if (mounted) {
        setState(() {
          _state = _AdbState.complete;
          _result = result;
        });
      }
    });

    // Intentar conexión automática al abrir
    _tryConnect();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _progressSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _tryConnect() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    await AdbNfcClientService.instance.forceReconnect();
    if (mounted) setState(() => _isRetrying = false);
  }

  Future<void> _startTransfer() async {
    setState(() => _state = _AdbState.transferring);
    await AdbNfcClientService.instance.requestDbTransfer();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: FlutterFlowTheme.of(context).primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Instalación por ADB',
          style: FlutterFlowTheme.of(context).titleMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildStateCard(),
              const SizedBox(height: 20),
              if (_state == _AdbState.waiting || _state == _AdbState.error)
                _buildInstructions(),
              if (_state == _AdbState.complete && _result != null)
                _buildSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor().withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildStateIcon(),
          const SizedBox(height: 16),
          Text(
            _stateTitle(),
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  fontFamily: 'Roboto',
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _stateSubtitle(),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Roboto',
                  color: FlutterFlowTheme.of(context)
                      .secondaryText
                      .withValues(alpha: 0.8),
                ),
            textAlign: TextAlign.center,
          ),
          if (_state == _AdbState.transferring) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
                backgroundColor: FlutterFlowTheme.of(context)
                    .primaryText
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    fontFamily: 'Roboto',
                    color: FlutterFlowTheme.of(context).primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildStateIcon() {
    switch (_state) {
      case _AdbState.waiting:
      case _AdbState.error:
        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
                ),
              ),
              if (_isRetrying)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                  ),
                )
              else
                const Icon(Icons.computer_rounded,
                    size: 36, color: Color(0xFF42A5F5)),
            ],
          ),
        );
      case _AdbState.connected:
        return Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              size: 40, color: Colors.white),
        );
      case _AdbState.transferring:
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.15),
          ),
          child: Icon(Icons.downloading_rounded,
              size: 40, color: FlutterFlowTheme.of(context).primary),
        );
      case _AdbState.complete:
        return Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.task_alt_rounded,
              size: 40, color: Colors.white),
        );
    }
  }

  String _stateTitle() {
    switch (_state) {
      case _AdbState.waiting:
        return 'Esperando al servidor ADB';
      case _AdbState.error:
        return 'No se pudo conectar';
      case _AdbState.connected:
        return 'PC detectada';
      case _AdbState.transferring:
        return 'Transfiriendo base de datos...';
      case _AdbState.complete:
        return 'Transferencia completada';
    }
  }

  String _stateSubtitle() {
    switch (_state) {
      case _AdbState.waiting:
        return _isRetrying
            ? 'Intentando conectar...'
            : 'Conecta el cable USB al PC y presiona "INTENTAR DE NUEVO"';
      case _AdbState.error:
        return 'Verifica que el cable esté conectado y el PC tenga la app abierta';
      case _AdbState.connected:
        return 'Servidor ADB conectado. Listo para transferir la base de datos.';
      case _AdbState.transferring:
        return 'No desconectes el cable mientras se transfieren los datos';
      case _AdbState.complete:
        return 'La base de datos fue instalada correctamente';
    }
  }

  Color _borderColor() {
    switch (_state) {
      case _AdbState.waiting:
      case _AdbState.error:
        return const Color(0xFF42A5F5);
      case _AdbState.connected:
        return Colors.green;
      case _AdbState.transferring:
        return FlutterFlowTheme.of(context).primary;
      case _AdbState.complete:
        return Colors.green;
    }
  }

  Widget _buildActionButton() {
    switch (_state) {
      case _AdbState.waiting:
      case _AdbState.error:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRetrying ? null : _tryConnect,
            icon: _isRetrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            label: Text(_isRetrying ? 'Conectando...' : 'INTENTAR DE NUEVO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        );
      case _AdbState.connected:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startTransfer,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('TRANSFERIR AHORA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        );
      case _AdbState.transferring:
        return const SizedBox.shrink();
      case _AdbState.complete:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.login_rounded, size: 20),
            label: const Text('CONTINUAR AL INICIO DE SESIÓN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        );
    }
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlutterFlowTheme.of(context)
              .primaryText
              .withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pasos para conectar',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
          ),
          const SizedBox(height: 12),
          ..._steps.map((s) => _buildStep(s.$1, s.$2, s.$3)),
        ],
      ),
    );
  }

  static const _steps = [
    (1, 'Conecta el cable USB de este Android al PC', Icons.cable_rounded),
    (2, 'En el PC, abre ClickPalm (formulario extractora)', Icons.computer_rounded),
    (3, 'Ve a Configuración Avanzada → "Transferir por ADB"', Icons.settings_rounded),
    (4, 'Presiona "INTENTAR DE NUEVO" en esta pantalla', Icons.refresh_rounded),
  ];

  Widget _buildStep(int num, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1565C0).withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$num',
              style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Roboto',
                      color: FlutterFlowTheme.of(context)
                          .secondaryText
                          .withValues(alpha: 0.9),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final r = _result!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.green.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de transferencia',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  color: Colors.green[300],
                ),
          ),
          const SizedBox(height: 14),
          _summaryRow(Icons.folder_rounded, 'Ruta', _shortPath(r.dbPath)),
          _summaryRow(Icons.timer_rounded, 'Duración',
              _formatDuration(r.duration)),
          _summaryRow(
              Icons.storage_rounded, 'Tamaño', _formatBytes(r.totalBytes)),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green[400]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontFamily: 'Roboto', color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _shortPath(String full) {
    final parts = full.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return full;
    return '.../${parts.sublist(parts.length - 3).join('/')}';
  }
}
