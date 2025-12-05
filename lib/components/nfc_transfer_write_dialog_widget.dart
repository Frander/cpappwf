import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Diálogo para escribir en el tag de destino durante una transferencia NFC
class NfcTransferWriteDialogWidget extends StatefulWidget {
  const NfcTransferWriteDialogWidget({
    super.key,
    required this.sourceTagContent,
  });

  final String sourceTagContent;

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
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startWriting() async {
    HapticFeedback.mediumImpact();

    try {
      // Primero, limpiar el tag de destino (escribir "0")
      debugPrint('🧹 Limpiando tag de destino...');
      final clearSuccess = await actions.clearNFCTag(context);

      if (!mounted) return;

      if (!clearSuccess) {
        throw Exception(
            'No se pudo limpiar el tag de destino.\n\nIntente de nuevo.');
      }

      debugPrint('✅ Tag de destino limpiado exitosamente');

      // Esperar un momento después de limpiar
      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      // Luego, escribir el contenido del tag de origen en el tag de destino
      debugPrint('📝 Escribiendo contenido en tag de destino...');
      final writeSuccess =
          await actions.writeNFCTag(context, widget.sourceTagContent);

      if (!mounted) return;

      if (!writeSuccess) {
        throw Exception(
            'No se pudo escribir en el tag de destino.\n\nIntente de nuevo.');
      }

      debugPrint('✅ Transferencia completada exitosamente');

      if (!mounted) return;
      setState(() {
        isWriting = false;
        isSuccess = true;
      });

      HapticFeedback.heavyImpact();

      // Esperar un momento y cerrar el diálogo
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
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
      decoration: BoxDecoration(
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
              padding: EdgeInsets.all(20.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, false);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'TRANSFERIR A TAG DE DESTINO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 60),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nfc, color: Colors.white, size: 60),
            ),
          ),
          SizedBox(height: 30),
          Text(
            'ACERQUE EL TAG DE DESTINO',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'El tag será limpiado y se escribirá\nel contenido del tag de origen',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00a86b), Color(0xFF003420)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: Colors.white, size: 64),
          ),
          SizedBox(height: 30),
          Text(
            '¡Transferencia Exitosa!',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'El contenido se ha transferido\ncorrectamente al tag de destino',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
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
          Icon(Icons.error_outline, color: Colors.red, size: 80),
          SizedBox(height: 20),
          Text(
            'Error',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: 30),
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
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00a86b), Color(0xFF003420)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Reintentar',
                style: GoogleFonts.inter(
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
