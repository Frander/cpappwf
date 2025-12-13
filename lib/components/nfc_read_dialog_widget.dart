import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'nfc_read_dialog_model.dart';
export 'nfc_read_dialog_model.dart';

class NfcReadDialogWidget extends StatefulWidget {
  const NfcReadDialogWidget({
    super.key,
    this.autoStart = false,
    this.isTagTransferMode = false,
  });

  final bool autoStart;
  /// Modo tag-transfer: no limpia el tag automáticamente, muestra mensaje de reintentar
  final bool isTagTransferMode;

  @override
  State<NfcReadDialogWidget> createState() => _NfcReadDialogWidgetState();
}

class _NfcReadDialogWidgetState extends State<NfcReadDialogWidget>
    with TickerProviderStateMixin {
  late NfcReadDialogModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Estado para modo tag-transfer cuando el tag está vacío o inválido
  bool _isTagEmptyOrInvalid = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NfcReadDialogModel());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Si autoStart es true, iniciar la lectura automáticamente
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startReading();
      });
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _model.isReading = true;
      _model.isSuccess = false;
      _model.errorMessage = null;
      _model.parsedRecords = [];
      _isTagEmptyOrInvalid = false;
    });

    try {
      final nfcData = await actions.readNFC(context);

      if (nfcData != null && nfcData.isNotEmpty) {
        // Para modo tag-transfer, validar que tenga contenido válido con visitas
        if (widget.isTagTransferMode) {
          final isValidForTransfer = _isValidForTagTransfer(nfcData);

          if (!isValidForTransfer) {
            // Tag vacío o inválido - mostrar mensaje y botón reintentar
            setState(() {
              _model.isReading = false;
              _model.isSuccess = false;
              _isTagEmptyOrInvalid = true;
            });
            HapticFeedback.vibrate();
            return; // No cerrar el diálogo, quedarse para reintentar
          }
        } else {
          // Modo normal: VALIDAR CONTENIDO DEL TAG y limpiar si es inválido
          final isValid = await _validateAndClearIfNeeded(nfcData);

          if (!isValid) {
            // El tag fue limpiado, informar al usuario
            setState(() {
              _model.isReading = false;
              _model.isSuccess = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Contenido inválido detectado. TAG limpiado automáticamente',
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );

            // Cerrar el diálogo después de mostrar el mensaje
            await Future.delayed(Duration(seconds: 2));
            if (mounted) {
              Navigator.pop(context);
            }
            return;
          }
        }

        // Parsear el contenido del tag
        final records = _parseNfcContent(nfcData);

        setState(() {
          _model.rawContent = nfcData;
          _model.parsedRecords = records;
          _model.isSuccess = records.isNotEmpty;
          _model.isReading = false;
        });

        if (records.isEmpty) {
          // En modo tag-transfer, mostrar error y permitir reintentar
          if (widget.isTagTransferMode) {
            setState(() {
              _isTagEmptyOrInvalid = true;
            });
            HapticFeedback.vibrate();
            return;
          }
          throw Exception('No se pudieron parsear los datos del tag');
        }

        HapticFeedback.heavyImpact();

        // Si autoStart es true, mostrar estado de éxito y luego cerrar
        if (widget.autoStart) {
          // Mantener el estado de éxito visible por 800ms para feedback visual
          // y para dar tiempo a Android de procesar el cierre del diálogo correctamente
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          // Mostrar diálogo de confirmación para eliminar el contenido del tag
          await _showDeleteConfirmationDialog();
        }
      } else {
        throw Exception('No se pudo leer el tag NFC');
      }
    } catch (e) {
      setState(() {
        _model.isReading = false;
        _model.errorMessage = e.toString();
      });
      HapticFeedback.vibrate();
    }
  }

  /// Valida si el contenido del tag es válido para transferir (tiene visitas guardadas)
  bool _isValidForTagTransfer(String content) {
    // "0" significa tag vacío/limpio
    if (content.trim() == '0') {
      debugPrint('⚠️ TAG-TRANSFER: Tag vacío ("0")');
      return false;
    }

    // Debe tener el formato válido con visitas
    final validPattern =
        RegExp(r'\{DH:[^}]+;OP:[^}]+;VISITS:[^}]+;RESULTS:[^}]+;HE:[^}]+\}');
    if (!validPattern.hasMatch(content)) {
      debugPrint('⚠️ TAG-TRANSFER: Formato inválido');
      return false;
    }

    debugPrint('✅ TAG-TRANSFER: Contenido válido para transferir');
    return true;
  }

  /// Valida el contenido del tag y lo limpia automáticamente si es inválido
  /// Retorna true si el contenido es válido, false si fue limpiado
  Future<bool> _validateAndClearIfNeeded(String content) async {
    // Pattern 1: "0" es válido (tag vacío)
    if (content.trim() == '0') {
      debugPrint('✅ TAG vacío válido ("0")');
      return true;
    }

    // Pattern 2: Formato válido {DH:...;OP:...;VISITS:...;RESULTS:...;HE:...}
    final validPattern =
        RegExp(r'\{DH:[^}]+;OP:[^}]+;VISITS:[^}]+;RESULTS:[^}]+;HE:[^}]+\}');
    if (validPattern.hasMatch(content)) {
      debugPrint('✅ Contenido del TAG válido');
      return true;
    }

    // Contenido inválido - limpiar el tag automáticamente
    debugPrint('⚠️ Contenido inválido detectado: $content');
    debugPrint('🧹 Limpiando TAG automáticamente...');

    try {
      final cleared = await actions.clearNFCTag(context);
      if (cleared) {
        debugPrint('✅ TAG limpiado exitosamente');
        return false; // Retorna false para indicar que el tag fue limpiado
      } else {
        debugPrint('❌ No se pudo limpiar el TAG');
        // Si no se pudo limpiar, dejar pasar el contenido inválido
        // para que el usuario vea el error
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error al limpiar TAG: $e');
      return true; // Si hay error, dejar pasar
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.3),
                          Colors.red.withOpacity(0.3)
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_forever,
                        color: Colors.white, size: 40),
                  ),
                  SizedBox(height: 20),

                  // Título
                  Text(
                    '¿Eliminar contenido del tag?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Descripción
                  Text(
                    'Se encontraron ${_model.parsedRecords.length} registro(s) en el tag. ¿Desea eliminar todo el contenido?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Botones
                  Row(
                    children: [
                      // Botón Cancelar
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(dialogContext, false);
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Cancelar',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),

                      // Botón Eliminar
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(dialogContext, true);
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red, Colors.red.shade700],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Eliminar',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
      },
    );

    // Si el usuario seleccionó eliminar
    if (result == true) {
      await _deleteTagContent();
    }
  }

  Future<void> _deleteTagContent() async {
    try {
      HapticFeedback.mediumImpact();

      // Llamar a la acción para escribir contenido vacío en el tag
      final success = await actions.writeNFCTag(context, '');

      if (success) {
        HapticFeedback.heavyImpact();

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Contenido del tag eliminado correctamente',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Limpiar el estado
        setState(() {
          _model.rawContent = '';
          _model.parsedRecords = [];
          _model.isSuccess = false;
        });
      } else {
        throw Exception('No se pudo eliminar el contenido del tag');
      }
    } catch (e) {
      HapticFeedback.vibrate();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error al eliminar: ${e.toString()}',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  List<NfcRecord> _parseNfcContent(String content) {
    List<NfcRecord> records = [];

    try {
      // Los registros están separados por comas
      // Formato: {DH:2025_11_06_13:20:00;OP:4214;VISITS:50;RESULTS:25;HE:204}
      final recordStrings = content.split('},').where((r) => r.isNotEmpty);

      for (var recordStr in recordStrings) {
        // Limpiar el string
        recordStr = recordStr.trim();
        if (!recordStr.startsWith('{')) {
          recordStr = '{$recordStr';
        }
        if (!recordStr.endsWith('}')) {
          recordStr = '$recordStr}';
        }

        // Extraer contenido entre llaves
        if (recordStr.startsWith('{') && recordStr.endsWith('}')) {
          final content = recordStr.substring(1, recordStr.length - 1);
          final parts = content.split(';');

          String? dateHour;
          String? operatorId;
          int? visits;
          int? results;
          int? headquarterId;

          for (var part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim();
              final value = keyValue[1].trim();

              switch (key) {
                case 'DH':
                  dateHour = value;
                  break;
                case 'OP':
                  operatorId = value;
                  break;
                case 'VISITS':
                  visits = int.tryParse(value);
                  break;
                case 'RESULTS':
                  results = int.tryParse(value);
                  break;
                case 'HE':
                  headquarterId = int.tryParse(value);
                  break;
              }
            }
          }

          if (dateHour != null && operatorId != null) {
            // Buscar operador en usersList
            // operatorId contiene el idUser (identificador numérico del usuario)
            String operatorName = 'Desconocido';
            String operatorIdentification = '';

            try {
              final idUserFromTag = int.tryParse(operatorId);
              if (idUserFromTag != null) {
                final user = FFAppState().usersList.firstWhere(
                      (u) => u.idUser == idUserFromTag,
                      orElse: () => UsersStruct(),
                    );

                if (user.nameUser.isNotEmpty) {
                  operatorName = user.nameUser;
                  operatorIdentification = user.operID;
                  debugPrint('✅ Operador encontrado por idUser=$idUserFromTag: $operatorName');
                } else {
                  debugPrint('❌ No se encontró operador con idUser=$idUserFromTag');
                }
              }
            } catch (e) {
              debugPrint('❌ Error buscando operador: $e');
            }

            // Buscar lote en headquartersList
            String loteName = 'N/A';
            if (headquarterId != null) {
              final headquarter = FFAppState().headquartersList.firstWhere(
                    (h) => h.idHeadquarter == headquarterId,
                    orElse: () => HeadquartersStruct(),
                  );

              if (headquarter.nameHeadquarter.isNotEmpty) {
                loteName = headquarter.nameHeadquarter;
              }
            }

            records.add(NfcRecord(
              dateHour: _parseDateHour(dateHour),
              operatorName: operatorName,
              operatorIdentification: operatorIdentification,
              visits: visits ?? 0,
              results: results ?? 0,
              loteName: loteName,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error al parsear contenido NFC: $e');
    }

    return records;
  }

  DateTime? _parseDateHour(String dateHourStr) {
    try {
      // Formato: 2025_11_06_13:20:00
      final parts = dateHourStr.split('_');
      if (parts.length >= 4) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final timeParts = parts[3].split(':');
        if (timeParts.length == 3) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final second = int.parse(timeParts[2]);

          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (e) {
      debugPrint('Error al parsear fecha: $e');
    }
    return null;
  }

  String _formatDateHour(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final DateFormat formatter =
        DateFormat('dd \'de\' MMM. yyyy - h:mm a', 'es');
    return formatter.format(dateTime);
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
                      Navigator.pop(context);
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
                    child: Column(
                      children: [
                        Text(
                          'LEER TAG NFC',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.blue,
                              Colors.blue.withOpacity(0.7),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LECTURA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 60),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: _model.isReading
                  ? _buildReadingState()
                  : _model.isSuccess
                      ? _buildTableState()
                      : _isTagEmptyOrInvalid
                          ? _buildTagEmptyOrInvalidState()
                          : _model.errorMessage != null
                              ? _buildErrorState()
                              : _buildEmptyState(),
            ),

            // Botón de acción
            if (!_model.isReading && !_model.isSuccess)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: InkWell(
                  onTap: _startReading,
                  child: Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.lightBlue],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Leer Tag',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.lightBlue.withOpacity(0.3)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.contactless,
                  color: Colors.white.withOpacity(0.7), size: 60),
            ),
          ),
          SizedBox(height: 30),
          Text(
            'Listo para leer',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Toca el botón de abajo y acerca el tag NFC para leer los datos',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingState() {
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
                gradient:
                    LinearGradient(colors: [Colors.blue, Colors.lightBlue]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nfc, color: Colors.white, size: 60),
            ),
          ),
          SizedBox(height: 30),
          Text(
            'Acerque el tag para leer',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Mantenga el dispositivo cerca del tag NFC',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGISTROS ENCONTRADOS: ${_model.parsedRecords.length}',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 16),

          // Tabla de resultados
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Header de tabla
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.3),
                        Colors.lightBlue.withOpacity(0.2)
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Fecha y hora',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Operador',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Visitas',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Resul.',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Lote',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filas de datos
                ..._model.parsedRecords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final isEven = index % 2 == 0;

                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isEven
                          ? Colors.white.withOpacity(0.02)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            _formatDateHour(record.dateHour),
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            record.operatorName,
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${record.visits}',
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${record.results}',
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            record.loteName,
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
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
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _model.errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado cuando el tag está vacío o tiene formato inválido (solo para tag-transfer)
  Widget _buildTagEmptyOrInvalidState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de advertencia
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.3),
                    Colors.amber.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 60,
              ),
            ),
            SizedBox(height: 24),

            // Título
            Text(
              'TAG VACÍO O INVÁLIDO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),

            // Mensaje descriptivo
            Text(
              'El TAG no tiene el formato correcto o está limpio',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 8),

            // Subtítulo con instrucción
            Text(
              'Acerque un TAG con visitas guardadas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 32),

            // Botón de reintentar
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _startReading();
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.amber.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'REINTENTAR LECTURA DE TAG DE ORIGEN',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NfcRecord {
  final DateTime? dateHour;
  final String operatorName;
  final String operatorIdentification;
  final int visits;
  final int results;
  final String loteName;

  NfcRecord({
    this.dateHour,
    required this.operatorName,
    required this.operatorIdentification,
    required this.visits,
    required this.results,
    required this.loteName,
  });
}
