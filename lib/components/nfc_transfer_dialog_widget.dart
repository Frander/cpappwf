import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nfc_transfer_dialog_model.dart';
export 'nfc_transfer_dialog_model.dart';

class NfcTransferDialogWidget extends StatefulWidget {
  const NfcTransferDialogWidget({
    super.key,
  });

  @override
  State<NfcTransferDialogWidget> createState() =>
      _NfcTransferDialogWidgetState();
}

class _NfcTransferDialogWidgetState extends State<NfcTransferDialogWidget>
    with TickerProviderStateMixin {
  late NfcTransferDialogModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NfcTransferDialogModel());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Iniciar automáticamente en el paso 1 (leer tag de origen)
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStep1());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Valida que el contenido del tag tenga el formato correcto
  bool _validateTagFormat(String content) {
    debugPrint('🔍 TAG-TRANSFER: Validando formato del tag');

    // Validar que contenga al menos un registro con el formato {DH:...;OP:...;VISITS:...;RESULTS:...;HE:...}
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(content);

    debugPrint('📊 TAG-TRANSFER: Registros encontrados en validación: ${matches.length}');

    if (matches.isEmpty) {
      debugPrint('❌ TAG-TRANSFER: No se encontraron registros con formato {}');
      return false;
    }

    // Verificar que cada registro tenga los campos requeridos
    for (var match in matches) {
      final recordContent = match.group(1);
      if (recordContent == null) continue;

      debugPrint('📄 TAG-TRANSFER: Validando registro: $recordContent');

      // Validar que contenga todos los campos requeridos
      if (!recordContent.contains('DH:') ||
          !recordContent.contains('OP:') ||
          !recordContent.contains('VISITS:') ||
          !recordContent.contains('RESULTS:') ||
          !recordContent.contains('HE:')) {
        debugPrint('❌ TAG-TRANSFER: Registro sin todos los campos requeridos');
        return false;
      }
    }

    debugPrint('✅ TAG-TRANSFER: Formato válido');
    return true;
  }

  /// Muestra una alerta elegante cuando el tag es inválido
  Future<void> _showInvalidTagAlert(String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 50,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Tag Inválido',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Entendido',
                        textAlign: TextAlign.center,
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
            ),
          ),
        );
      },
    );
  }

  /// Paso 1: Leer el tag de origen
  Future<void> _startStep1() async {
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() {
      _model.currentStep = 1;
      _model.isReading = true;
      _model.errorMessage = null;
    });

    try {
      // Leer el contenido del tag de origen
      // Usar autoClose: false para mantener el diálogo abierto
      final nfcData = await actions.readNFC(context, autoClose: false);

      debugPrint('📦 TAG-TRANSFER: readNFC retornó, validando contenido');

      if (nfcData == null || nfcData.isEmpty) {
        debugPrint('❌ TAG-TRANSFER: Contenido vacío o null');
        FFAppState().nfcRead = 'ERROR: Tag vacío';
        return;
      }

      // Validar que el contenido no sea solo "0" (tag vacío)
      if (nfcData.trim() == '0') {
        debugPrint('❌ TAG-TRANSFER: Tag contiene solo "0"');
        FFAppState().nfcRead = 'ERROR: Tag vacío (solo contiene "0")';
        return;
      }

      // Validar que el contenido tenga el formato correcto
      if (!_validateTagFormat(nfcData)) {
        debugPrint('❌ TAG-TRANSFER: Formato inválido');
        FFAppState().nfcRead = 'ERROR: Formato inválido';
        return;
      }

      // Parsear el contenido
      final parsedData = _parseNfcTagContentByHeadquarter(nfcData);

      // Validar que se haya parseado correctamente
      if (parsedData.isEmpty) {
        debugPrint('❌ TAG-TRANSFER: No se pudo parsear el contenido');
        if (!mounted) return;
        setState(() {
          _model.isReading = false;
          _model.errorMessage = 'No se pudo interpretar el contenido del TAG';
        });
        return;
      }

      // Guardar el contenido válido y mostrar resumen
      if (!mounted) return;
      setState(() {
        _model.isReading = false;
        _model.sourceTagContent = nfcData;
        _model.parsedData = parsedData;
      });

      debugPrint('✅ TAG-TRANSFER: Contenido válido parseado y guardado');
      debugPrint('✅ TAG-TRANSFER: Mostrando resumen en el diálogo');

      HapticFeedback.heavyImpact();

      // Esperar 2 segundos antes de pasar automáticamente al paso 2
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        _startStep2();
      }
    } catch (e) {
      debugPrint('❌ Error en paso 1: $e');
      FFAppState().nfcRead = 'ERROR: ${e.toString()}';
    }
  }

  /// Paso 2: Limpiar y escribir en el tag de destino
  Future<void> _startStep2() async {
    if (!mounted) return;
    setState(() {
      _model.currentStep = 2;
      _model.isClearingAndWriting = true;
      _model.errorMessage = null;
    });

    try {
      // Primero, limpiar el tag de destino (escribir "0")
      debugPrint('🧹 Limpiando tag de destino...');
      final clearSuccess = await actions.clearNFCTag(context);

      if (!mounted) return;

      if (!clearSuccess) {
        throw Exception(
            'No se pudo limpiar el tag de destino.\\n\\nIntente de nuevo.');
      }

      debugPrint('✅ Tag de destino limpiado exitosamente');

      // Esperar un momento después de limpiar
      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      // Luego, escribir el contenido del tag de origen en el tag de destino
      debugPrint('📝 Escribiendo contenido en tag de destino...');
      final writeSuccess =
          await actions.writeNFCTag(context, _model.sourceTagContent);

      if (!mounted) return;

      if (!writeSuccess) {
        throw Exception(
            'No se pudo escribir en el tag de destino.\\n\\nIntente de nuevo.');
      }

      debugPrint('✅ Transferencia completada exitosamente');

      if (!mounted) return;
      setState(() {
        _model.isClearingAndWriting = false;
        _model.isSuccess = true;
      });

      HapticFeedback.heavyImpact();

      // Esperar un momento y cerrar el diálogo
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error en paso 2: $e');
      if (!mounted) return;

      setState(() {
        _model.isClearingAndWriting = false;
        _model.errorMessage = e.toString();
      });
      HapticFeedback.vibrate();
    }
  }

  /// Parsea el contenido del tag NFC y lo agrupa por lote (headquarterId)
  /// Retorna un Map donde la clave es el headquarterId y el valor es un Map con la data agregada
  Map<int, Map<String, dynamic>> _parseNfcTagContentByHeadquarter(
      String nfcContent) {
    final Map<int, Map<String, dynamic>> groupedByHeadquarter = {};

    debugPrint('🔍 TAG-TRANSFER: Parseando contenido del tag');
    debugPrint('📄 Contenido: $nfcContent');

    // El contenido puede tener múltiples registros separados por comas
    // Ejemplo: {DH:2025_11_06_13:20:00;OP:4214;VISITS:50;RESULTS:25;HE:204},{DH:...}

    // Extraer todos los registros entre {}
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(nfcContent);

    debugPrint('📊 Registros encontrados: ${matches.length}');

    for (var match in matches) {
      final recordContent = match.group(1);
      if (recordContent == null) continue;

      // Parsear cada campo dentro del registro
      final Map<String, dynamic> record = {};
      final fields = recordContent.split(';');

      for (var field in fields) {
        final parts = field.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          switch (key) {
            case 'DH':
              // Parsear fecha: 2025_11_06_13:20:00
              try {
                final dateStr = value.replaceAll('_', '-');
                final dateParts = dateStr.split('-');
                if (dateParts.length >= 4) {
                  final year = int.parse(dateParts[0]);
                  final month = int.parse(dateParts[1]);
                  final day = int.parse(dateParts[2]);
                  final timeParts = dateParts[3].split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  final second = int.parse(timeParts[2]);
                  record['dateTime'] =
                      DateTime(year, month, day, hour, minute, second);
                }
              } catch (e) {
                record['dateTime'] = DateTime.now();
              }
              break;
            case 'OP':
              record['operatorId'] = value;
              break;
            case 'VISITS':
              record['visits'] = int.tryParse(value) ?? 0;
              break;
            case 'RESULTS':
              record['results'] = int.tryParse(value) ?? 0;
              break;
            case 'HE':
              record['headquarterId'] = int.tryParse(value) ?? 0;
              break;
          }
        }
      }

      if (record.isNotEmpty) {
        final heId = record['headquarterId'] as int? ?? 0;

        // Si el lote no existe en el map, crearlo
        if (!groupedByHeadquarter.containsKey(heId)) {
          groupedByHeadquarter[heId] = {
            'totalVisits': 0,
            'totalResults': 0,
            'records': <Map<String, dynamic>>[],
          };
        }

        // Agregar el registro al lote
        groupedByHeadquarter[heId]!['totalVisits'] =
            (groupedByHeadquarter[heId]!['totalVisits'] as int) +
                (record['visits'] as int? ?? 0);
        groupedByHeadquarter[heId]!['totalResults'] =
            (groupedByHeadquarter[heId]!['totalResults'] as int) +
                (record['results'] as int? ?? 0);
        (groupedByHeadquarter[heId]!['records'] as List<Map<String, dynamic>>)
            .add(record);
      }
    }

    debugPrint(
        '✅ TAG-TRANSFER: Parseado completado. Lotes encontrados: ${groupedByHeadquarter.length}');
    return groupedByHeadquarter;
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
                    child: Column(
                      children: [
                        Text(
                          'TRANSFERIR TAG NFC',
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
                              Color(0xFF00a86b),
                              Color(0xFF003420),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PASO ${_model.currentStep} DE 2',
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
              child: _model.isSuccess
                  ? _buildSuccessState()
                  : _model.errorMessage != null
                      ? _buildErrorState()
                      : _model.currentStep == 1
                          ? _buildStep1State()
                          : _buildStep2State(),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado del paso 1: Leyendo tag de origen
  Widget _buildStep1State() {
    if (_model.isReading) {
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
                    colors: [Color(0xFF00a86b), Color(0xFF003420)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.nfc, color: Colors.white, size: 60),
              ),
            ),
            SizedBox(height: 30),
            Text(
              'ACERQUE EL TAG DE ORIGEN',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Mantenga el dispositivo cerca del tag\\npara leer su contenido',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Mostrar resumen del contenido leído
    return _buildSourceSummary();
  }

  /// Estado del paso 2: Limpiando y escribiendo en tag de destino
  Widget _buildStep2State() {
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
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'El tag será limpiado y se escribirá\\nel contenido del tag de origen',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Mostrar resumen del contenido leído del tag de origen
  Widget _buildSourceSummary() {
    final parsedData = _model.parsedData;
    if (parsedData.isEmpty) return SizedBox.shrink();

    // Calcular totales generales
    int totalVisits = 0;
    int totalResults = 0;
    for (var entry in parsedData.values) {
      totalVisits += (entry['totalVisits'] as int?) ?? 0;
      totalResults += (entry['totalResults'] as int?) ?? 0;
    }

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF00a86b), size: 80),
          SizedBox(height: 20),
          Text(
            'Contenido Leído',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESUMEN',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                _buildDataRow('Total Visitas', totalVisits.toString()),
                _buildDataRow('Total Resultados', totalResults.toString()),
                _buildDataRow('Lotes', parsedData.length.toString()),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Preparando transferencia al tag de destino...',
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

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'El contenido se ha transferido\\ncorrectamente al tag de destino',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto',
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
          SizedBox(height: 30),
          InkWell(
            onTap: () {
              // Reintentar desde el paso 1
              _startStep1();
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
