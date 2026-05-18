import 'dart:async';
import 'package:flutter/material.dart';
import '/custom_code/actions/adb_nfc_bridge_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';

enum _ServerState {
  waitingClient,
  clientConnected,
  transferring,
  complete,
}

class AdbTransferServerPageWidget extends StatefulWidget {
  const AdbTransferServerPageWidget({super.key});

  @override
  State<AdbTransferServerPageWidget> createState() =>
      _AdbTransferServerPageWidgetState();
}

class _AdbTransferServerPageWidgetState
    extends State<AdbTransferServerPageWidget> {
  _ServerState _state = _ServerState.waitingClient;
  DbTransferState? _transferState;

  StreamSubscription<AdbBridgeStatus>? _statusSub;
  StreamSubscription<DbTransferState>? _transferSub;

  @override
  void initState() {
    super.initState();

    // Iniciar servidor ADB si no está corriendo
    if (!AdbNfcBridgeService.instance.isServerRunning) {
      AdbNfcBridgeService.instance.start();
    }

    // Estado inicial
    final current = AdbNfcBridgeService.instance.currentStatus;
    if (current == AdbBridgeStatus.clientConnected) {
      _state = _ServerState.clientConnected;
    }

    _statusSub =
        AdbNfcBridgeService.instance.onStatusChanged.listen((status) {
      if (!mounted) return;
      setState(() {
        switch (status) {
          case AdbBridgeStatus.waitingForClient:
            _state = _ServerState.waitingClient;
            break;
          case AdbBridgeStatus.clientConnected:
            _state = _ServerState.clientConnected;
            break;
          case AdbBridgeStatus.serverDown:
            _state = _ServerState.waitingClient;
            break;
        }
      });
    });

    _transferSub =
        AdbNfcBridgeService.instance.onDbTransfer.listen((s) {
      if (!mounted) return;
      setState(() {
        _transferState = s;
        _state = s.isComplete ? _ServerState.complete : _ServerState.transferring;
      });
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _transferSub?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildStatusPanel()),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInstructionsPanel()),
                      ],
                    ),
                  ),
                  if (_state == _ServerState.transferring ||
                      _state == _ServerState.complete) ...[
                    const SizedBox(height: 20),
                    _buildProgressPanel(),
                  ],
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).primaryText.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cable_rounded,
                color: Color(0xFF42A5F5), size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transferir Base de Datos al Android vía ADB',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'El Android se conectará por cable USB y descargará la BD de este PC',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Roboto',
                      color: FlutterFlowTheme.of(context)
                          .secondaryText
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusBorderColor().withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTADO DE CONEXIÓN',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context)
                  .secondaryText
                  .withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: _buildStatusIndicator()),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text(
                  _statusTitle(),
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                        color: _statusBorderColor(),
                        fontSize: 16,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _statusSubtitle(),
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Roboto',
                        color: FlutterFlowTheme.of(context)
                            .secondaryText
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildAdbErrorInfo(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    switch (_state) {
      case _ServerState.waitingClient:
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.phonelink_rounded,
                    size: 30, color: Color(0xFF42A5F5)),
              ),
            ],
          ),
        );
      case _ServerState.clientConnected:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.phonelink_ring_rounded,
              size: 40, color: Colors.white),
        );
      case _ServerState.transferring:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1565C0).withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.upload_rounded,
              size: 40, color: Color(0xFF42A5F5)),
        );
      case _ServerState.complete:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.task_alt_rounded,
              size: 44, color: Colors.white),
        );
    }
  }

  Color _statusBorderColor() {
    switch (_state) {
      case _ServerState.waitingClient:
        return const Color(0xFF42A5F5);
      case _ServerState.clientConnected:
        return Colors.green;
      case _ServerState.transferring:
        return const Color(0xFF42A5F5);
      case _ServerState.complete:
        return Colors.green;
    }
  }

  String _statusTitle() {
    switch (_state) {
      case _ServerState.waitingClient:
        return 'Esperando dispositivo...';
      case _ServerState.clientConnected:
        return '✅  Android conectado';
      case _ServerState.transferring:
        return 'Transfiriendo BD...';
      case _ServerState.complete:
        return '✅  Transferencia completada';
    }
  }

  String _statusSubtitle() {
    switch (_state) {
      case _ServerState.waitingClient:
        return 'Servidor ADB activo en puerto 8080';
      case _ServerState.clientConnected:
        return 'Listo — el Android iniciará la transferencia';
      case _ServerState.transferring:
        final s = _transferState;
        if (s == null) return '';
        return 'Enviado: ${_formatBytes(s.sentBytes)} de ${_formatBytes(s.totalBytes)}';
      case _ServerState.complete:
        final s = _transferState;
        if (s == null) return 'Completada';
        return 'Total: ${_formatBytes(s.totalBytes)}';
    }
  }

  Widget _buildAdbErrorInfo() {
    final err = AdbNfcBridgeService.instance.adbError;
    if (err == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              err,
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.orange,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            'INSTRUCCIONES',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context)
                  .secondaryText
                  .withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ..._instructions.map((s) => _buildInstructionStep(s.$1, s.$2, s.$3)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF42A5F5), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta página puede dejarse abierta. La transferencia se activará automáticamente cuando el Android la solicite.',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Color(0xFF90CAF9),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _instructions = [
    (1, 'Conecta el cable USB del Android a este PC', Icons.cable_rounded),
    (2, 'Activa "Depuración USB" en Ajustes → Opciones de desarrollador del Android',
        Icons.developer_mode_rounded),
    (3, 'Abre ClickPalm en el Android y ve al inicio de sesión', Icons.phone_android_rounded),
    (4, 'Elige "Sin internet" → "Instalar por ADB"', Icons.touch_app_rounded),
    (5, 'Presiona "INTENTAR DE NUEVO" en el Android y luego "TRANSFERIR AHORA"',
        Icons.download_rounded),
  ];

  Widget _buildInstructionStep(int num, String text, IconData icon) {
    final isActive = (num == 1 && _state == _ServerState.waitingClient) ||
        (num == 5 && _state == _ServerState.clientConnected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                  : const Color(0xFF1565C0).withValues(alpha: 0.15),
              border: isActive
                  ? Border.all(color: const Color(0xFF42A5F5), width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$num',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF42A5F5)
                    : const Color(0xFF42A5F5).withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: isActive
                      ? FlutterFlowTheme.of(context).primaryText
                      : FlutterFlowTheme.of(context)
                          .secondaryText
                          .withValues(alpha: 0.6),
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPanel() {
    final s = _transferState;
    final isDone = _state == _ServerState.complete;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF1B5E20).withValues(alpha: 0.15)
            : FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xFF42A5F5).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDone ? 'TRANSFERENCIA COMPLETADA' : 'PROGRESO DE TRANSFERENCIA',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDone
                  ? Colors.green.withValues(alpha: 0.7)
                  : const Color(0xFF42A5F5).withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          if (!isDone && s != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s.progress,
                      minHeight: 12,
                      backgroundColor: FlutterFlowTheme.of(context)
                          .primaryText
                          .withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF42A5F5)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${(s.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF42A5F5),
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enviado: ${_formatBytes(s.sentBytes)} de ${_formatBytes(s.totalBytes)}',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  color: FlutterFlowTheme.of(context)
                      .secondaryText
                      .withValues(alpha: 0.6),
                  fontSize: 12),
            ),
          ],
          if (isDone && s != null)
            Row(
              children: [
                _infoChip(Icons.storage_rounded, _formatBytes(s.totalBytes),
                    Colors.green),
                const SizedBox(width: 12),
                _infoChip(Icons.check_circle_rounded, 'Completada',
                    Colors.green),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          top: BorderSide(
            color: FlutterFlowTheme.of(context)
                .primaryText
                .withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cerrar'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  FlutterFlowTheme.of(context).secondaryText,
              side: BorderSide(
                  color: FlutterFlowTheme.of(context)
                      .primaryText
                      .withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
