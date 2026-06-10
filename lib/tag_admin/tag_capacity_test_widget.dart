import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'dart:async';

class TagCapacityTestWidget extends StatefulWidget {
  const TagCapacityTestWidget({super.key});

  @override
  State<TagCapacityTestWidget> createState() => _TagCapacityTestWidgetState();
}

class _TagCapacityTestWidgetState extends State<TagCapacityTestWidget>
    with TickerProviderStateMixin {
  // Registro base a escribir
  static const String baseRecord =
      'N1:{"R":{"i":999999,"r":"TEST1234","n":"TAG de Prueba","d":1700000000,"f":"","t":"","u":4442},"V":[{"h":1700000000,"o":4442,"v":30,"s":120,"e":112}]}';

  // Capacidades de TAGs NFC (en bytes)
  static const int ntag213Capacity = 144;
  static const int ntag215Capacity = 504;
  static const int ntag216Capacity = 888;

  // Estado de la prueba
  bool _isTestRunning = false;
  bool _isSuccess = false;
  String? _errorMessage;
  int _recordsWritten = 0;
  int _maxRecordsCalculated = 0;
  int _bytesUsed = 0;
  int _bytesAvailable = 0;
  int _totalCapacity = 0; // Se detectará automáticamente
  String _tagType = 'Detectando...';
  String _currentData = '';
  Timer? _writeTimer;
  bool _capacityDetected = false;
  bool _isDetecting = false; // Nueva variable para controlar el estado de detección

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _writeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// PASO 1: Detecta la capacidad del TAG NFC
  Future<void> _detectTagCapacity() async {
    setState(() {
      _errorMessage = null;
      _isDetecting = true;
    });

    try {
      debugPrint('🔍 PASO 1: Detectando capacidad del TAG...');
      final capacity = await actions.detectNfcCapacity(context);

      if (capacity > 0) {
        setState(() {
          _totalCapacity = capacity;
          _capacityDetected = true;
          _bytesAvailable = capacity;
          _isDetecting = false;

          // Determinar tipo de TAG según capacidad
          if (capacity >= 8192) {
            _tagType = 'Mifare DESFire EV3 8K';
          } else if (capacity >= 4096) {
            _tagType = 'Mifare Classic 4K';
          } else if (capacity >= 1024) {
            _tagType = 'Mifare Classic 1K';
          } else if (capacity >= 888) {
            _tagType = 'NTAG216';
          } else if (capacity >= 504) {
            _tagType = 'NTAG215';
          } else if (capacity >= 144) {
            _tagType = 'NTAG213';
          } else {
            _tagType = 'TAG NFC';
          }

          // Calcular máximo de registros
          const recordSize = baseRecord.length + 1;
          _maxRecordsCalculated = (capacity / recordSize).floor();

          debugPrint('✅ PASO 1 COMPLETADO: Capacidad del TAG detectada: $capacity bytes ($_tagType)');
          debugPrint('📊 Registros máximos calculados: $_maxRecordsCalculated');
        });
      } else {
        setState(() {
          _errorMessage = 'No se pudo detectar la capacidad del TAG. Intente de nuevo.';
          _isDetecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error detectando capacidad: ${e.toString()}';
        _isDetecting = false;
      });
    }
  }

  /// Verifica si el siguiente registro cabe en el TAG
  bool _canFitNextRecord() {
    const recordSize = baseRecord.length;
    final separatorSize = _recordsWritten > 0 ? 1 : 0; // Coma separadora
    final nextRecordSize = recordSize + separatorSize;

    return (_bytesUsed + nextRecordSize) <= _totalCapacity;
  }

  /// PASO 2: Inicia el test de capacidad (escritura de registros)
  Future<void> _startCapacityTest() async {
    setState(() {
      _isTestRunning = true;
      _isSuccess = false;
      _errorMessage = null;
      _recordsWritten = 0;
      _bytesUsed = 0;
      _currentData = '';
    });

    debugPrint('📝 PASO 2: Iniciando escritura de registros...');

    // Escribir el primer registro
    await _writeNextRecord();
  }

  /// Escribe el siguiente registro al TAG
  Future<void> _writeNextRecord() async {
    // Verificar si cabe el siguiente registro ANTES de escribir
    if (!_canFitNextRecord()) {
      // No cabe más registros
      setState(() {
        _isTestRunning = false;
        _errorMessage =
            'MÁXIMO DE REGISTROS ALCANZADO. NO HAY ESPACIO SUFICIENTE PARA EL PRÓXIMO REGISTRO COMPLETO.';
      });
      return;
    }

    // Preparar el siguiente registro (SIN modificar el estado aún)
    String nextData = _currentData;
    int nextBytesUsed = _bytesUsed;

    if (_recordsWritten > 0) {
      nextData += ',';
      nextBytesUsed += 1;
    }
    nextData += baseRecord;
    nextBytesUsed += baseRecord.length;

    // Escribir al TAG usando escritura directa optimizada (sin lectura previa)
    try {
      debugPrint(
          '📝 Escribiendo registro ${_recordsWritten + 1} al TAG ($nextBytesUsed/$_totalCapacity bytes)...');

      // USAR writeNFCTagDirect() - Escritura directa sin lectura previa
      // Esto elimina el cuello de botella de lectura que causa lentitud
      final success = await actions.writeNFCTagDirect(context, nextData);

      if (!success) {
        setState(() {
          _isTestRunning = false;
          _errorMessage = 'Error al escribir en el TAG. Intente de nuevo.';
        });
        debugPrint('❌ Error escribiendo registro ${_recordsWritten + 1}. Estado preservado en: $_recordsWritten registros');
        return;
      }

      // SOLO SI LA ESCRITURA FUE EXITOSA, actualizar el estado
      _currentData = nextData;
      _bytesUsed = nextBytesUsed;
      _recordsWritten++;
      _bytesAvailable = _totalCapacity - _bytesUsed;

      debugPrint('✅ Registro $_recordsWritten escrito exitosamente');

      // Mostrar éxito temporalmente antes de solicitar el siguiente
      setState(() {
        _isSuccess = true;
      });

      // Esperar 1.5 segundos antes de solicitar el siguiente registro
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // Si aún hay espacio, continuar con el siguiente registro
      if (_canFitNextRecord()) {
        setState(() {
          _isSuccess = false;
        });
        // Llamar recursivamente para escribir el siguiente registro
        await _writeNextRecord();
      } else {
        // Ya no hay más espacio
        setState(() {
          _isTestRunning = false;
          _isSuccess = false;
          _errorMessage =
              'MÁXIMO DE REGISTROS ALCANZADO. NO HAY ESPACIO SUFICIENTE PARA EL PRÓXIMO REGISTRO COMPLETO.';
        });
      }
    } catch (e) {
      debugPrint('❌ Excepción escribiendo registro ${_recordsWritten + 1}: $e. Estado preservado en: $_recordsWritten registros');
      setState(() {
        _isTestRunning = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  /// Continúa el test después de un error
  Future<void> _continueTest() async {
    setState(() {
      _isTestRunning = true;
      _isSuccess = false;
      _errorMessage = null;
    });

    debugPrint('🔄 Continuando test desde registro $_recordsWritten...');

    // Continuar escribiendo el siguiente registro
    await _writeNextRecord();
  }

  /// Detiene el test manualmente
  void _stopTest() {
    _writeTimer?.cancel();
    setState(() {
      _isTestRunning = false;
      _isSuccess = _recordsWritten > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        color: Color(0xFF8B5CF6),
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Test de Capacidad TAG',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _writeTimer?.cancel();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Información del TAG
              if (!_isTestRunning && !_isDetecting && _recordsWritten == 0)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info del registro (siempre visible)
                        _buildInfoCard(),
                        const SizedBox(height: 16),

                        // PASO 1: Capacidad detectada (solo si ya se detectó)
                        if (_capacityDetected) ...[
                          _buildStepIndicator('PASO 1 COMPLETADO', const Color(0xFF10B981), true),
                          const SizedBox(height: 12),
                          _buildCapacityCard(),
                          const SizedBox(height: 16),
                          _buildStepIndicator('PASO 2', const Color(0xFF8B5CF6), false),
                          const SizedBox(height: 12),
                          _buildRecordPreview(),
                        ],
                      ],
                    ),
                  ),
                ),

              // PASO 1: Detectando capacidad
              if (_isDetecting)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildStepIndicator('PASO 1 - Detectando TAG', const Color(0xFF3B82F6), false),
                        const SizedBox(height: 24),
                        // Animación NFC
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc,
                              color: Color(0xFF3B82F6),
                              size: 64,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF3B82F6)),
                          ),
                          child: const Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Detectando capacidad del TAG',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Acerque el TAG NFC al dispositivo...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // PASO 2: Estado del test en ejecución (escritura de registros)
              if (_isTestRunning)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildStepIndicator('PASO 2 - Escribiendo registros', const Color(0xFF8B5CF6), false),
                        const SizedBox(height: 24),
                        // Animación NFC
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc,
                              color: Color(0xFF8B5CF6),
                              size: 64,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Contador de registros
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'REGISTROS ESCRITOS',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white60,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_recordsWritten',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildProgressBar(),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    'Bytes usados',
                                    '$_bytesUsed',
                                    const Color(0xFF3B82F6),
                                  ),
                                  _buildStatItem(
                                    'Disponibles',
                                    '$_bytesAvailable',
                                    const Color(0xFF10B981),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF10B981)),
                                strokeWidth: 3,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _isSuccess
                                      ? '✅ Registro $_recordsWritten escrito exitosamente'
                                      : 'Acerque el TAG NFC al dispositivo...',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error o completado
              if (!_isTestRunning && _errorMessage != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFEF4444),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                color: Color(0xFFEF4444),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildResultItem(
                                      'Registros escritos',
                                      '$_recordsWritten',
                                      const Color(0xFF10B981),
                                    ),
                                    const Divider(color: Colors.white12),
                                    _buildResultItem(
                                      'Bytes utilizados',
                                      '$_bytesUsed / $_totalCapacity bytes',
                                      const Color(0xFF3B82F6),
                                    ),
                                    const Divider(color: Colors.white12),
                                    _buildResultItem(
                                      'Espacio restante',
                                      '$_bytesAvailable bytes',
                                      const Color(0xFFF59E0B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_isTestRunning && _isSuccess && _errorMessage == null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¡Test completado!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Se escribieron $_recordsWritten registros exitosamente',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () {
                        _writeTimer?.cancel();
                        Navigator.of(context).pop();
                      },
                      text: 'Cerrar',
                      options: FFButtonOptions(
                        height: 48,
                        color: const Color(0xFF374151),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: _isDetecting
                        ? null  // Deshabilitar durante detección
                        : _isTestRunning
                          ? _stopTest
                          : !_capacityDetected
                            ? _detectTagCapacity  // PASO 1: Detectar TAG
                            : (_errorMessage != null && !_errorMessage!.contains('MÁXIMO') && _recordsWritten > 0)
                              ? _continueTest  // Continuar después de error
                              : _startCapacityTest,  // PASO 2: Iniciar escritura
                      text: _isDetecting
                        ? 'Detectando...'
                        : _isTestRunning
                          ? 'Detener'
                          : !_capacityDetected
                            ? 'Iniciar Test'
                            : (_errorMessage != null && !_errorMessage!.contains('MÁXIMO') && _recordsWritten > 0)
                              ? 'Continuar'
                              : 'Escribir Registros',
                      icon: Icon(
                        _isDetecting
                          ? Icons.hourglass_empty
                          : _isTestRunning
                            ? Icons.stop
                            : !_capacityDetected
                              ? Icons.play_arrow
                              : (_errorMessage != null && !_errorMessage!.contains('MÁXIMO') && _recordsWritten > 0)
                                ? Icons.refresh
                                : Icons.edit,
                        size: 20,
                      ),
                      options: FFButtonOptions(
                        height: 48,
                        color: _isDetecting
                            ? const Color(0xFF6B7280)
                            : _isTestRunning
                              ? const Color(0xFFEF4444)
                              : !_capacityDetected
                                ? const Color(0xFF3B82F6)
                                : (_errorMessage != null && !_errorMessage!.contains('MÁXIMO') && _recordsWritten > 0)
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF8B5CF6),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                'Test de Capacidad TAG',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Este test medirá la capacidad real de su TAG NFC:\n\n'
            '• PASO 1: Detectará el tipo y capacidad del TAG\n'
            '• PASO 2: Escribirá registros hasta alcanzar el límite\n\n'
            'Deberá acercar el TAG cuando se solicite.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard() {
    const recordSize = baseRecord.length + 1; // +1 por separador
    final percentage = _totalCapacity > 0
        ? ((_maxRecordsCalculated * recordSize) / _totalCapacity * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.2),
            const Color(0xFF3B82F6).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TAG Detectado: $_tagType',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCapacityItem(
            'Capacidad total',
            '$_totalCapacity bytes',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildCapacityItem(
            'Tamaño por registro',
            '$recordSize bytes',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 8),
          _buildCapacityItem(
            'Registros máximos',
            '$_maxRecordsCalculated registros',
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildCapacityItem(
            'Eficiencia',
            '${percentage.toStringAsFixed(1)}%',
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: Colors.white60,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            const Color(0xFF6366F1).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                'Preparado para escribir',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Este registro se escribirá repetidamente hasta llenar el TAG',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Text(
              baseRecord,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 10,
                color: Color(0xFF8B5CF6),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    // Calcular progreso basado en bytes usados vs capacidad total
    final progress = _totalCapacity > 0
        ? _bytesUsed / _totalCapacity
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: const Color(0xFF1F2937),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% del TAG utilizado',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String stepText, Color color, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            Icon(Icons.check_circle, color: color, size: 20)
          else
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            stepText,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}