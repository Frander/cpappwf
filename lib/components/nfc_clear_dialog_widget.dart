import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'nfc_clear_dialog_model.dart';
export 'nfc_clear_dialog_model.dart';

class NfcClearDialogWidget extends StatefulWidget {
  const NfcClearDialogWidget({super.key});

  @override
  State<NfcClearDialogWidget> createState() => _NfcClearDialogWidgetState();
}

class _NfcClearDialogWidgetState extends State<NfcClearDialogWidget> {
  late NfcClearDialogModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NfcClearDialogModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Inicia el proceso de limpieza del TAG
  Future<void> _startClearProcess() async {
    setState(() {
      _model.isClearing = true;
      _model.isSuccess = false;
      _model.errorMessage = '';
    });

    try {
      // Usar la custom action clearNFCTag que borra completamente todos los sectores
      final result = await actions.clearNFCTag(context);

      // Si result es true, significa que fue exitoso
      if (result == true) {
        setState(() {
          _model.isClearing = false;
          _model.isSuccess = true;
        });
      } else {
        // Si es false, hubo un error
        setState(() {
          _model.isClearing = false;
          _model.errorMessage =
            'No se pudo limpiar el TAG.\n\n'
            'Posibles causas:\n'
            '• TAG protegido contra escritura\n'
            '• TAG DESFire con aplicaciones protegidas\n'
            '• TAG requiere formateo con app externa\n\n'
            'Sugerencia: Use NXP TagWriter para formatear el TAG como NDEF primero.';
        });
      }
    } catch (e) {
      setState(() {
        _model.isClearing = false;
        _model.errorMessage =
          'Error al limpiar el TAG.\n\n'
          'Detalles técnicos: ${e.toString().split('\n').first}\n\n'
          'Si es un TAG DESFire, use NXP TagWriter para formatearlo.';
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
                      Icons.cleaning_services_rounded,
                      color: Color(0xFFEF4444),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Limpiar TAG NFC',
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

            // Advertencia inicial
            if (!_model.isClearing && !_model.isSuccess && _model.errorMessage.isEmpty)
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFFBBF24).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFFBBF24), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Advertencia!',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Esta acción borrará TODA la información almacenada en el TAG NFC. Esta operación no se puede deshacer.',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF374151),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antes de continuar:',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildCheckItem('Asegúrese de que desea borrar este TAG'),
                        _buildCheckItem('Verifique que el TAG no contiene datos importantes'),
                        _buildCheckItem('Tenga el TAG NFC listo para acercarlo al dispositivo'),
                      ],
                    ),
                  ),
                ],
              ),

            // Estado de limpieza
            if (_model.isClearing)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Icono animado
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFEF4444).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.nfc,
                        color: Color(0xFFEF4444),
                        size: 48,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '⚠️ MANTENGA EL TAG CERCA',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFBBF24).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                                strokeWidth: 3,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Limpiando TAG...\nNo retire el TAG hasta que finalice',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(fontFamily: 'Roboto',
                                    fontSize: 13,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Esto puede tomar unos segundos',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                      ),
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
                      '¡TAG limpiado exitosamente!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'El TAG NFC ha sido borrado y está listo para ser utilizado nuevamente.',
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
            if (!_model.isClearing && _model.errorMessage.isNotEmpty)
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
            if (!_model.isClearing)
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
                        onPressed: _startClearProcess,
                        text: _model.errorMessage.isNotEmpty ? 'Reintentar' : 'Limpiar TAG',
                        icon: Icon(
                          _model.errorMessage.isNotEmpty ? Icons.refresh : Icons.cleaning_services_rounded,
                          size: 20,
                        ),
                        options: FFButtonOptions(
                          height: 48,
                          color: Color(0xFFEF4444),
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
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFF10B981),
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
