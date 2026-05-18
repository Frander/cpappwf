import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class TagConfigurationStepperWidget extends StatefulWidget {
  const TagConfigurationStepperWidget({super.key});

  @override
  State<TagConfigurationStepperWidget> createState() =>
      _TagConfigurationStepperWidgetState();
}

class _TagConfigurationStepperWidgetState
    extends State<TagConfigurationStepperWidget>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isReading = false;
  bool _isClearing = false;
  // null = no escaneado aún, '' = escaneado pero ilegible/incompatible, otro = contenido
  String? _tagContent;
  String? _rawContent;
  bool _showRaw = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _tagContent = null; // Resetear para el siguiente paso
        _rawContent = null;
        _slideController.reset();
        _slideController.forward();
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _tagContent = null;
        _rawContent = null;
        _slideController.reset();
        _slideController.forward();
      });
    }
  }

  Future<void> _readTag() async {
    setState(() {
      _isReading = true;
      _tagContent = null;
      _rawContent = null;
    });

    try {
      // autoClose: true para cerrar la sesión NFC después de leer,
      // evitando conflicto con clearNFCTag en el paso 2
      final content = await actions.readNFCBasic(context, autoClose: true);
      if (mounted) {
        setState(() {
          _tagContent = content; // null si no se pudo leer, '' si ilegible
          _rawContent = content;
          _isReading = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tagContent = 'Error: $e';
          _isReading = false;
        });
      }
    }
  }

  Future<void> _clearTag() async {
    setState(() {
      _isClearing = true;
    });

    try {
      final result = await actions.clearNFCTag(context);
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
        if (result) {
          HapticFeedback.heavyImpact();
          _nextStep(); // Pasar automáticamente al paso 3 (resetea _tagContent)
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo limpiar el TAG'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings_suggest,
                            color: Color(0xFF3B82F6), size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Configurar TAG',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress indicator
                _buildProgressIndicator(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildStepContent(),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF4B5563),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (index < 2) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1VerifyContent();
      case 1:
        return _buildStep2ClearTag();
      case 2:
        return _buildStep3VerifyClean();
      default:
        return Container();
    }
  }

  Widget _buildStep1VerifyContent() {
    final scanned = _tagContent != null;
    final hasContent = scanned && _tagContent!.isNotEmpty;
    final isUnreadable = scanned && _tagContent!.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.visibility,
            title: 'Paso 1: Verificar Contenido',
            subtitle: 'Revise el contenido actual del TAG antes de limpiarlo',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 24),

          if (!_isReading && !scanned)
            _buildReadyToScanCard(
              icon: Icons.nfc,
              title: 'Acerque el TAG para leer',
              subtitle: 'Presione el botón y acerque el TAG NFC',
              color: const Color(0xFF3B82F6),
            ),

          if (_isReading) _buildScanningCard(),

          // TAG escaneado pero contenido ilegible/incompatible
          if (isUnreadable && !_isReading)
            _buildUnreadableWarningCard(),

          // TAG escaneado con contenido legible
          if (hasContent && !_isReading)
            Column(
              children: [
                _buildContentPreview(),
                const SizedBox(height: 16),
                _buildRawContentToggle(),
              ],
            ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _readTag,
                  text: !scanned ? 'Leer TAG' : 'Leer Nuevamente',
                  icon: const Icon(Icons.nfc, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFF3B82F6),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Mostrar "Continuar" siempre que se haya escaneado (con o sin contenido)
              if (scanned) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FFButtonWidget(
                    onPressed: _nextStep,
                    text: 'Continuar',
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    options: FFButtonOptions(
                      height: 50,
                      color: const Color(0xFF10B981),
                      textStyle: const TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ClearTag() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.cleaning_services,
            title: 'Paso 2: Limpiar TAG',
            subtitle: 'Borre el contenido actual del TAG',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBBF24)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFBBF24), size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Esta acción escribirá "0" en el TAG, eliminando su contenido actual.',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_isClearing)
            _buildScanningCard(message: 'Limpiando TAG...'),

          if (!_isClearing)
            _buildReadyToScanCard(
              icon: Icons.cleaning_services,
              title: 'Acerque el TAG para limpiar',
              subtitle: 'Mantenga el TAG cerca hasta que finalice',
              color: const Color(0xFFEF4444),
            ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: const Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFF374151),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
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
                  onPressed: _isClearing ? null : _clearTag,
                  text: 'Limpiar TAG',
                  icon: const Icon(Icons.cleaning_services, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFFEF4444),
                    disabledColor: const Color(0xFF4B5563),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
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
    );
  }

  Widget _buildStep3VerifyClean() {
    final scanned = _tagContent != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.check_circle,
            title: 'Paso 3: Verificar Limpieza',
            subtitle: 'Confirme que el TAG contiene solo "0"',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 24),

          if (!_isReading && !scanned)
            _buildReadyToScanCard(
              icon: Icons.verified,
              title: 'Acerque el TAG para verificar',
              subtitle: 'Confirme que solo contiene "0"',
              color: const Color(0xFF10B981),
            ),

          if (_isReading) _buildScanningCard(),

          if (scanned && !_isReading)
            Column(
              children: [
                _tagContent == '0'
                    ? _buildSuccessCard()
                    : _buildErrorCard(),
                const SizedBox(height: 16),
                _buildContentPreview(),
              ],
            ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FFButtonWidget(
                  onPressed: _previousStep,
                  text: 'Atrás',
                  icon: const Icon(Icons.arrow_back, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFF374151),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
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
                  onPressed: _readTag,
                  text: !scanned ? 'Verificar' : 'Verificar Nuevamente',
                  icon: const Icon(Icons.check, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFF10B981),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
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

          if (_tagContent == '0')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: FFButtonWidget(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ TAG configurado exitosamente'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  text: 'Finalizar',
                  icon: const Icon(Icons.done_all, size: 20),
                  options: FFButtonOptions(
                    height: 50,
                    color: const Color(0xFF8B5CF6),
                    textStyle: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadyToScanCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningCard({String message = 'Leyendo TAG...'}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF3B82F6)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontFamily: 'Roboto',
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso cuando el TAG fue detectado pero su contenido no es legible/compatible
  Widget _buildUnreadableWarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAG detectado pero ilegible',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'El contenido del TAG no es compatible o no pudo leerse (puede estar vacío, encriptado o en formato no soportado). Puede continuar con la limpieza para formatearlo correctamente.',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.article, color: Color(0xFF3B82F6), size: 20),
              SizedBox(width: 8),
              Text(
                'Contenido del TAG',
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _showRaw ? (_rawContent ?? '') : (_tagContent ?? ''),
              style: const TextStyle(fontFamily: 'Roboto Mono',
                fontSize: 12,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawContentToggle() {
    return InkWell(
      onTap: () => setState(() => _showRaw = !_showRaw),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showRaw ? const Color(0xFFF59E0B) : const Color(0xFF4B5563),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showRaw ? Icons.visibility_off : Icons.code,
              color: _showRaw ? const Color(0xFFF59E0B) : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _showRaw ? 'Ocultar Raw' : 'Ver Raw',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 13,
                color: _showRaw ? const Color(0xFFF59E0B) : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡TAG Limpio!',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                Text(
                  'El TAG contiene solo "0"',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error, color: Color(0xFFEF4444), size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAG con Contenido',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                Text(
                  'El TAG no está limpio. Vuelva al paso 2.',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
