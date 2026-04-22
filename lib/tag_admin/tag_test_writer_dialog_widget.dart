import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'tag_test_writer_dialog_model.dart';
export 'tag_test_writer_dialog_model.dart';

class TagTestWriterDialogWidget extends StatefulWidget {
  const TagTestWriterDialogWidget({super.key});

  @override
  State<TagTestWriterDialogWidget> createState() => _TagTestWriterDialogWidgetState();
}

class _TagTestWriterDialogWidgetState extends State<TagTestWriterDialogWidget>
    with TickerProviderStateMixin {
  late TagTestWriterDialogModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TagTestWriterDialogModel());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Generar datos de prueba en formato JSON
    final testJson = actions.buildInitialNfcJson(
      idProduct: 999999,
      rfid: 'TEST1234',
      nameProduct: 'TAG de Prueba',
    );

    // Agregar visitas de prueba
    actions.addVisitToNfcJson(
      testJson,
      operatorId: 293,
      visits: 10,
      results: 8,
      headquarterId: 204,
      dateTime: DateTime.now(),
    );

    actions.addVisitToNfcJson(
      testJson,
      operatorId: 294,
      visits: 15,
      results: 10,
      headquarterId: 204,
      dateTime: DateTime.now().add(Duration(minutes: 10)),
    );

    actions.addVisitToNfcJson(
      testJson,
      operatorId: 295,
      visits: 17,
      results: 11,
      headquarterId: 204,
      dateTime: DateTime.now().add(Duration(minutes: 20)),
    );

    _model.dataToWrite = actions.nfcJsonToString(testJson);
  }

  @override
  void dispose() {
    _model.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startWriting() async {
    setState(() {
      _model.isWriting = true;
      _model.isSuccess = false;
      _model.errorMessage = null;
    });

    try {
      final success = await actions.writeNFCTag(
        context,
        _model.dataToWrite,
      );

      if (success) {
        setState(() {
          _model.isSuccess = true;
          _model.isWriting = false;
        });

        // Esperar un momento y cerrar
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('No se pudo escribir el tag');
      }
    } catch (e) {
      setState(() {
        _model.isWriting = false;
        _model.errorMessage = e.toString();
      });
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
      child: SafeArea(
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
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Escribir Datos de Prueba',
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Preview de datos
            if (!_model.isWriting && !_model.isSuccess && _model.errorMessage == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF374151),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Datos de prueba',
                              style: TextStyle(fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Se escribirá el siguiente contenido de prueba en el TAG:',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF10B981).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _model.dataToWrite,
                            style: TextStyle(fontFamily: 'Roboto Mono',
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildDataPreview(),
                ],
              ),

            // Estado de escritura
            if (_model.isWriting)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.nfc,
                          color: Color(0xFF10B981),
                          size: 48,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'ACERQUE EL TAG',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          strokeWidth: 3,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Escribiendo datos de prueba...',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Éxito
            if (_model.isSuccess)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF10B981), width: 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF10B981),
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '¡TAG escrito exitosamente!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Los datos de prueba han sido escritos en el TAG NFC.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

            // Error
            if (!_model.isWriting && _model.errorMessage != null)
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
                        _model.errorMessage!,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Botones de acción
            if (!_model.isWriting)
              Row(
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () => Navigator.of(context).pop(),
                      text: _model.isSuccess ? 'Cerrar' : 'Cancelar',
                      options: FFButtonOptions(
                        height: 48,
                        color: Color(0xFF374151),
                        textStyle: TextStyle(fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (!_model.isSuccess)
                    SizedBox(width: 12),
                  if (!_model.isSuccess)
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: _startWriting,
                        text: _model.errorMessage != null ? 'Reintentar' : 'Escribir TAG',
                        icon: Icon(
                          _model.errorMessage != null ? Icons.refresh : Icons.edit_note_rounded,
                          size: 20,
                        ),
                        options: FFButtonOptions(
                          height: 48,
                          color: Color(0xFF10B981),
                          textStyle: TextStyle(fontFamily: 'Roboto',
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
      ),
    );
  }

  Widget _buildDataPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa del contenido',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 12),
          _buildPreviewItem('Fecha/Hora', '27/11/2025 13:36:48'),
          _buildPreviewItem('Operador ID', '4442'),
          _buildPreviewItem('Visitas', '3 (por registro)'),
          _buildPreviewItem('Resultados', '6 (por registro)'),
          _buildPreviewItem('Lote ID', '112'),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.copy_all, color: Color(0xFF3B82F6), size: 14),
              SizedBox(width: 6),
              Text(
                '2 registros duplicados',
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Color(0xFF3B82F6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.chevron_right, color: Color(0xFF10B981), size: 16),
          SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
