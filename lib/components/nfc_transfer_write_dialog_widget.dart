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

    try {
      // Leer el contenido actual del tag de destino
      debugPrint('📖 Leyendo contenido actual del tag de destino...');
      final destContent = await actions.readNFC(context, autoClose: false);

      if (!mounted) return;

      String contentToWrite;

      if (destContent.trim().isEmpty || destContent.trim() == '0') {
        // Tag de destino vacío: escribir el JSON completo del origen
        debugPrint(
            '📝 TAG-TRANSFER: Tag destino vacío, escribiendo JSON completo del origen');
        contentToWrite = widget.sourceTagContent;
      } else if (actions.isNewJsonFormat(destContent)) {
        // Tag de destino ya tiene JSON: fusionar los arrays Visits
        debugPrint('🔀 TAG-TRANSFER: Fusionando Visits del origen al destino...');
        final destJson = actions.parseNfcJson(destContent);
        final srcJson = actions.parseNfcJson(widget.sourceTagContent);

        if (destJson != null && srcJson != null) {
          final destVisits =
              List<dynamic>.from(destJson['Visits'] as List? ?? []);
          final srcVisits =
              List<dynamic>.from(srcJson['Visits'] as List? ?? []);
          destVisits.addAll(srcVisits);
          destJson['Visits'] = destVisits;
          if (srcJson['status'] != null) {
            destJson['status'] = srcJson['status'];
          }
          contentToWrite = jsonEncode(destJson);
          debugPrint(
              '✅ TAG-TRANSFER: Fusionados ${srcVisits.length} Visits nuevos. Total destino: ${destVisits.length}');
        } else {
          debugPrint(
              '⚠️ TAG-TRANSFER: No se pudo parsear JSON, escribiendo JSON completo del origen');
          contentToWrite = widget.sourceTagContent;
        }
      } else {
        // Formato de destino no reconocido: escribir fuente completo
        debugPrint(
            '⚠️ TAG-TRANSFER: Formato destino no reconocido, escribiendo JSON completo del origen');
        contentToWrite = widget.sourceTagContent;
      }

      // Escribir el contenido final en el tag de destino
      debugPrint('📝 Escribiendo contenido en tag de destino...');
      final writeSuccess =
          await actions.writeNFCTag(context, contentToWrite);

      if (!mounted) return;

      if (!writeSuccess) {
        // Verificar si hubo un error de validación
        final nfcReadState = FFAppState().nfcRead;

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

        throw Exception(
            'No se pudo escribir en el tag de destino.\n\nIntente de nuevo.');
      }

      debugPrint('✅ Transferencia completada exitosamente');
      debugPrint('📦 TAG-TRANSFER: Contenido escrito en destino: ${contentToWrite.length} caracteres');

      if (!mounted) return;
      setState(() {
        isWriting = false;
        isSuccess = true;
      });

      HapticFeedback.heavyImpact();

      // Esperar un momento y cerrar el diálogo retornando el contenido escrito
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, contentToWrite);
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 60),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'ACERQUE EL TAG DE DESTINO',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Se leerá el tag de destino y se agregarán\nlas visitas del tag de origen',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
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
