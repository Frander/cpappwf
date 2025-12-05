import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'nfc_view_raw_dialog_model.dart';
export 'nfc_view_raw_dialog_model.dart';

class NfcViewRawDialogWidget extends StatefulWidget {
  const NfcViewRawDialogWidget({super.key});

  @override
  State<NfcViewRawDialogWidget> createState() => _NfcViewRawDialogWidgetState();
}

class _NfcViewRawDialogWidgetState extends State<NfcViewRawDialogWidget> {
  late NfcViewRawDialogModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NfcViewRawDialogModel());
    // Iniciar lectura automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNfcReading();
    });
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    _model.dispose();
    super.dispose();
  }

  /// Inicia la lectura del TAG NFC (versión personalizada que no cierra el diálogo)
  Future<void> _startNfcReading() async {
    // Verificar si NFC está disponible
    bool nfcAvailable = await NfcManager.instance.isAvailable();
    if (!nfcAvailable) {
      setState(() {
        _model.isReading = false;
        _model.errorMessage = 'NFC no está disponible en este dispositivo';
      });
      return;
    }

    setState(() {
      _model.isReading = true;
      _model.rawContent = '';
      _model.errorMessage = '';
    });

    // Iniciar sesión NFC (invalidateAfterFirstRead: true para evitar caché)
    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          String tagData = '';

          // Intentar leer como NDEF primero - LEER DIRECTAMENTE, NO USAR CACHÉ
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            try {
              // Leer el mensaje actual del TAG (no usar cachedMessage)
              final message = await ndef.read();
              if (message != null && message.records.isNotEmpty) {
                final records = message.records;
                final firstRecord = records.first;
                final payload = firstRecord.payload;

                if (payload.isNotEmpty) {
                  try {
                    // Decodificar Text Record
                    final statusByte = payload[0];
                    final languageCodeLength = statusByte & 0x3F;

                    if (payload.length > languageCodeLength + 1) {
                      final textBytes = payload.sublist(1 + languageCodeLength);
                      tagData = utf8.decode(textBytes);
                      debugPrint('✅ Leído desde NDEF: ${tagData.length} bytes');
                    }
                  } catch (e) {
                    debugPrint('⚠️ Error decodificando NDEF: $e');
                  }
                }
              } else {
                debugPrint('ℹ️ TAG NDEF sin contenido o vacío');
              }
            } catch (e) {
              debugPrint('⚠️ Error leyendo NDEF: $e');
            }
          }

          // Si no se pudo leer como NDEF, mostrar información del tag
          if (tagData.isEmpty) {
            tagData = 'TAG detectado pero sin contenido NDEF\n\n';
            tagData += 'Información del TAG:\n';
            tagData += 'Data: ${tag.data.toString()}';
          }

          // Actualizar el estado con el contenido leído
          if (mounted) {
            setState(() {
              _model.isReading = false;
              _model.rawContent = tagData;
            });
          }

          // Detener la sesión NFC
          await NfcManager.instance.stopSession();
        } catch (e) {
          debugPrint('❌ Error leyendo TAG: $e');
          if (mounted) {
            setState(() {
              _model.isReading = false;
              _model.errorMessage = 'Error al leer el TAG: $e';
            });
          }
          await NfcManager.instance.stopSession();
        }
      },
    );
  }

  /// Copia el contenido al portapapeles
  void _copyToClipboard() {
    if (_model.rawContent.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _model.rawContent));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contenido copiado al portapapeles'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.nfc_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ver contenido del TAG',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Estado de lectura
            if (_model.isReading)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Esperando TAG NFC...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Acerque el TAG NFC al dispositivo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

            // Error
            if (!_model.isReading && _model.errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFDC2626), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _model.errorMessage,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenido crudo
            if (!_model.isReading && _model.rawContent.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contenido del TAG:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _copyToClipboard,
                        icon: Icon(Icons.copy, size: 18, color: Color(0xFF3B82F6)),
                        label: Text(
                          'Copiar',
                          style: GoogleFonts.inter(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: 300),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF374151), width: 1),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _model.rawContent,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          color: Color(0xFF10B981),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Caracteres: ${_model.rawContent.length}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),

            SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                if (!_model.isReading && _model.errorMessage.isNotEmpty)
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: _startNfcReading,
                      text: 'Intentar de nuevo',
                      icon: Icon(Icons.refresh, size: 20),
                      options: FFButtonOptions(
                        height: 48,
                        color: Color(0xFF3B82F6),
                        textStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (!_model.isReading && _model.rawContent.isNotEmpty)
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () => Navigator.of(context).pop(),
                      text: 'Cerrar',
                      options: FFButtonOptions(
                        height: 48,
                        color: Color(0xFF374151),
                        textStyle: GoogleFonts.inter(
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
      ),
    );
  }
}
