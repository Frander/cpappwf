import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';


/// Diálogo para escribir en el tag de destino durante una transferencia NFC
class NfcTransferWriteDialogWidget extends StatefulWidget {
  const NfcTransferWriteDialogWidget({
    super.key,
    required this.sourceTagContent,
    this.destinationTitle,
  });

  final String sourceTagContent;
  /// Título personalizado para el tag de destino (ej: "Escribir Tijera de destino")
  final String? destinationTitle;

  @override
  State<NfcTransferWriteDialogWidget> createState() =>
      _NfcTransferWriteDialogWidgetState();
}

class _NfcTransferWriteDialogWidgetState
    extends State<NfcTransferWriteDialogWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool isWriting = true;
  bool isSuccess = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Iniciar automáticamente la escritura
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWriting());
  }

  @override
  void dispose() {
    // Abortar cualquier sesión NFC activa para que cerrar el diálogo
    // (botón X, botón atrás del sistema, etc.) cancele realmente la escritura.
    if (Platforms.isMobile) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startWriting() async {
    HapticFeedback.mediumImpact();

    // Arrancar el polling ANTES del await: cuando el tag de destino está lleno,
    // writeNFCTag NO completa su Completer (mantiene la sesión NFC activa
    // esperando otro tag) y señala el estado con FFAppState().nfcRead =
    // 'SOLICITAR_OTRO_TAG'. El polling detecta ese cambio y refresca la UI para
    // pedir un nuevo tag vacío, sin que el await regrese.
    _startNfcStatePolling();

    try {
      // writeNFCTag lee el contenido actual del tag destino en la misma sesión NFC,
      // fusiona (array) e inyecta tag_to/US. El contenido final queda en FFAppState().nfcRead.
      debugPrint('📝 TAG-TRANSFER: Esperando tag de destino...');
      final writeSuccess = await actions.writeNFCTag(context, widget.sourceTagContent);

      if (!mounted) return;

      if (!writeSuccess) {
        final nfcReadState = FFAppState().nfcRead;

        // Salvaguarda: si justo se solicitó otro tag, no tratarlo como error.
        if (nfcReadState == 'SOLICITAR_OTRO_TAG') {
          debugPrint('⏳ TAG-TRANSFER: Esperando que el usuario acerque otro tag...');
          return;
        }

        if (nfcReadState.startsWith('ERROR:PRODUCTO_NO_ENCONTRADO:')) {
          final parts = nfcReadState.split(':');
          final requiredType = parts.length > 2 ? parts[2] : 'producto';
          throw Exception(
              'El TAG de destino no está registrado.\n\nDebe instalar primero el TAG como $requiredType en el Centro de Administración NFC.');
        }

        if (nfcReadState.startsWith('ERROR:TIPO_INCORRECTO:')) {
          final parts = nfcReadState.split(':');
          final requiredType = parts.length > 2 ? parts[2] : 'producto';
          final foundType = parts.length > 3 ? parts[3] : 'desconocido';
          throw Exception(
              'El TAG de destino no es del tipo correcto.\n\nEsperado: $requiredType\nEncontrado: $foundType\n\nUtilice el TAG correcto.');
        }

        // El contenido no cabe ni siquiera en un tag de destino vacío.
        if (nfcReadState.startsWith('ERROR:ESPACIO_INSUFICIENTE:')) {
          final parts = nfcReadState.split(':');
          final bytesInfo = parts.length > 2 ? parts[2] : '';
          throw Exception(
              'El contenido no cabe en el tag de destino.${bytesInfo.isNotEmpty ? '\n\nTamaño: $bytesInfo bytes.' : ''}\n\nUtilice un tag con mayor capacidad.');
        }

        throw Exception('No se pudo escribir en el tag de destino.\n\nIntente de nuevo.');
      }

      // Contenido realmente escrito: array fusionado (o fuente solo si era el primer transfer)
      final contentWritten = FFAppState().nfcRead.isNotEmpty
          ? FFAppState().nfcRead
          : widget.sourceTagContent;

      debugPrint('✅ Transferencia completada: ${contentWritten.length} chars escritos');

      if (!mounted) return;
      setState(() {
        isWriting = false;
        isSuccess = true;
      });

      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, contentWritten);
      }
    } catch (e) {
      debugPrint('❌ Error en transferencia: $e');
      if (!mounted) return;

      setState(() {
        isWriting = false;
        errorMessage = e.toString();
      });
      HapticFeedback.vibrate();
    }
  }

  /// Polling del estado NFC mientras se escribe. Permite reflejar en la UI el
  /// estado 'SOLICITAR_OTRO_TAG' (tag de destino lleno) que writeNFCTag publica
  /// en FFAppState().nfcRead sin completar su Completer.
  void _startNfcStatePolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));

      // Detener el polling cuando el diálogo deja de estar en estado de escritura.
      if (!mounted || !isWriting) return false;

      // Forzar rebuild para que _buildWritingState() refleje el estado actual
      // (p.ej. cambiar a "Acerque OTRO tag" cuando el destino está lleno).
      setState(() {});

      return isWriting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF003420),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Sin resultado: el diálogo se abrió con showDialog<String?>,
                      // devolver un bool aquí lanzaba un TypeError y el pop fallaba.
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.destinationTitle ?? 'TRANSFERIR A TAG DE DESTINO',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: isSuccess
                  ? _buildSuccessState()
                  : errorMessage != null
                      ? _buildErrorState()
                      : _buildWritingState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWritingState() {
    // El tag de destino está lleno: writeNFCTag conserva su contenido y espera
    // que el usuario acerque un tag NUEVO (vacío) para escribir la transferencia.
    final bool needsAnotherTag =
        FFAppState().nfcRead == 'SOLICITAR_OTRO_TAG';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: needsAnotherTag
                      ? [Colors.amber, Colors.orange]
                      : [Colors.orange, Colors.deepOrange],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 60),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            needsAnotherTag
                ? '⚠️ ACERQUE OTRO TAG'
                : 'ACERQUE EL TAG DE DESTINO',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            needsAnotherTag
                ? 'El contenido no cabe en el tag de destino.\n\nEl contenido existente se conservará.\n\nAcerque un NUEVO tag (vacío) para continuar.'
                : 'Se leerá el tag de destino y se agregarán\nlas visitas del tag de origen',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          if (needsAnotherTag) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Esperando nuevo tag...',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00a86b), Color(0xFF003420)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 64),
          ),
          const SizedBox(height: 30),
          const Text(
            '¡Transferencia Exitosa!',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'El contenido se ha transferido\ncorrectamente al tag de destino',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Error',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 30),
          InkWell(
            onTap: () {
              // Reintentar
              setState(() {
                isWriting = true;
                errorMessage = null;
              });
              _startWriting();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00a86b), Color(0xFF003420)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
