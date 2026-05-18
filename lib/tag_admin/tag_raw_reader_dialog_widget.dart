import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tag_raw_reader_dialog_model.dart';
export 'tag_raw_reader_dialog_model.dart';

class TagRawReaderDialogWidget extends StatefulWidget {
  const TagRawReaderDialogWidget({super.key});

  @override
  State<TagRawReaderDialogWidget> createState() =>
      _TagRawReaderDialogWidgetState();
}

class _TagRawReaderDialogWidgetState extends State<TagRawReaderDialogWidget>
    with TickerProviderStateMixin {
  late TagRawReaderDialogModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TagRawReaderDialogModel());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-iniciar la lectura
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startReading();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    setState(() {
      _model.isReading = true;
      _model.isSuccess = false;
      _model.errorMessage = null;
      _model.rawContent = '';
    });

    try {
      // Usar la nueva función que devuelve información detallada
      final result = await actions.readNfcDetailed(context);

      if (mounted) {
        if (result['success'] == true) {
          final String content = result['content'] ?? '';

          // Construir tagInfo con toda la información del TAG
          final tagInfo = <String, dynamic>{
            'tagId': result['tagId'] ?? '',
            'tagType': result['tagType'] ?? 'Desconocido',
            'maxSize': result['maxSize'] ?? 0,
            'currentSize': result['currentSize'] ?? 0,
            'availableSize': result['availableSize'] ?? 0,
            // Información adicional del contenido
            ...(_extractTagInfo(content)),
          };

          setState(() {
            _model.rawContent = content;
            _model.tagInfo = tagInfo;
            _model.isSuccess = true;
            _model.isReading = false;
          });

          debugPrint('');
          debugPrint('✅ ============ TAG LEÍDO EXITOSAMENTE ============');
          debugPrint('📱 ID del TAG: ${tagInfo['tagId']}');
          debugPrint('🏷️ Tipo de TAG: ${tagInfo['tagType']}');
          debugPrint('💾 Capacidad Total: ${tagInfo['maxSize']} bytes');
          debugPrint('📊 Espacio Usado: ${tagInfo['currentSize']} bytes');
          debugPrint('📂 Espacio Disponible: ${tagInfo['availableSize']} bytes');
          debugPrint('📝 Contenido: ${content.length} caracteres');
          debugPrint('📋 Registros: ${tagInfo['recordCount'] ?? 0}');
          debugPrint('🔍 tagInfo completo: $tagInfo');
          debugPrint('================================================');
          debugPrint('');
        } else {
          setState(() {
            _model.isReading = false;
            _model.errorMessage = result['errorMessage'] ?? 'Error desconocido al leer el TAG';
          });
          debugPrint('⚠️ Error: ${result['errorMessage']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error leyendo TAG: $e');
      if (mounted) {
        setState(() {
          _model.isReading = false;
          _model.errorMessage = e.toString();
        });
      }
    }
  }

  Map<String, dynamic> _extractTagInfo(String content) {
    final info = <String, dynamic>{};

    // Tamaño en bytes (UTF-8)
    info['sizeBytes'] = content.length;

    // Tamaño estimado en KB
    info['sizeKB'] = (content.length / 1024).toStringAsFixed(2);

    // Detectar formato y contar registros
    if (actions.isNewJsonFormat(content)) {
      // Formato JSON nuevo
      info['format'] = 'JSON';
      final nfcJson = actions.parseNfcJson(content);
      if (nfcJson != null) {
        final visits = nfcJson['Visits'] as List?;
        info['recordCount'] = visits?.length ?? 0;

        // Extraer información de Read_info
        if (nfcJson['Read_info'] != null) {
          final readInfo = nfcJson['Read_info'] as Map<String, dynamic>;
          info['productId'] = readInfo['Id_product'];
          info['rfid'] = readInfo['RFID'];
          info['productName'] = readInfo['Name_product'];
          info['dateCreated'] = readInfo['Date_created'];
        }

        // Campos del formato JSON
        info['fields'] = ['DH', 'OP', 'VISITS', 'RESULTS', 'HE'];
      } else {
        info['recordCount'] = 0;
        info['fields'] = [];
      }
    } else if (actions.isOldFormat(content)) {
      // Formato antiguo
      info['format'] = 'Antiguo (compatibilidad)';
      final regexRecords = RegExp(r'\{([^}]+)\}');
      final matches = regexRecords.allMatches(content);
      info['recordCount'] = matches.length;

      // Extraer campos únicos
      final Set<String> fields = {};
      for (var match in matches) {
        final recordContent = match.group(1);
        if (recordContent != null) {
          final parts = recordContent.split(';');
          for (var part in parts) {
            final keyValue = part.split(':');
            if (keyValue.isNotEmpty) {
              fields.add(keyValue[0].trim());
            }
          }
        }
      }
      info['fields'] = fields.toList();
    } else {
      info['format'] = 'Desconocido';
      info['recordCount'] = 0;
      info['fields'] = [];
    }

    return info;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _model.rawContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Contenido copiado al portapapeles',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Contenido Raw del TAG',
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
            const SizedBox(height: 24),

            // Estado de lectura
            if (_model.isReading)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.nfc,
                          color: Color(0xFFF59E0B),
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ACERQUE EL TAG',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          strokeWidth: 3,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Leyendo contenido raw...',
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

            // Contenido Raw (cuando se ha leído exitosamente)
            if (_model.isSuccess)
              Container(
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información técnica
                      if (_model.tagInfo != null) _buildTagInfoSection(),
                      const SizedBox(height: 16),

                      // Contenido raw
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Contenido Raw',
                                  style: TextStyle(fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                InkWell(
                                  onTap: _copyToClipboard,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.copy,
                                          color: Color(0xFFF59E0B),
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Copiar',
                                          style: TextStyle(fontFamily: 'Roboto',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                _model.rawContent,
                                style: const TextStyle(fontFamily: 'Roboto Mono',
                                  fontSize: 11,
                                  color: Color(0xFFF59E0B),
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Decodificación del contenido
                      _buildDecodedContent(),
                    ],
                  ),
                ),
              ),

            // Error
            if (!_model.isReading && _model.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDC2626), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _model.errorMessage!,
                        style: const TextStyle(fontFamily: 'Roboto',
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_model.isReading) const SizedBox(height: 24),

            // Botones de acción
            if (!_model.isReading)
              Row(
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () => Navigator.of(context).pop(),
                      text: 'Cerrar',
                      options: FFButtonOptions(
                        height: 48,
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
                  if (_model.errorMessage != null) const SizedBox(width: 12),
                  if (_model.errorMessage != null)
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: _startReading,
                        text: 'Reintentar',
                        icon: const Icon(Icons.refresh, size: 20),
                        options: FFButtonOptions(
                          height: 48,
                          color: const Color(0xFFF59E0B),
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
        ),
      ),
    );
  }

  Widget _buildTagInfoSection() {
    final info = _model.tagInfo!;

    debugPrint('🎨 Construyendo sección de información del TAG');
    debugPrint('   Info recibido: $info');

    // Información del TAG (ID, Tipo, Capacidad)
    final tagId = info['tagId'] ?? 'N/A';
    final tagType = info['tagType'] ?? 'Desconocido';
    final maxSize = info['maxSize'] ?? 0;
    final currentSize = info['currentSize'] ?? 0;
    final availableSize = info['availableSize'] ?? 0;

    debugPrint('   📱 ID: $tagId');
    debugPrint('   🏷️ Tipo: $tagType');
    debugPrint('   💾 Capacidad: $maxSize bytes');

    // Información del contenido
    final recordCount = info['recordCount'] ?? 0;
    final sizeBytes = info['sizeBytes'] ?? 0;
    final sizeKB = info['sizeKB'] ?? '0.00';
    final fields = (info['fields'] as List<dynamic>?) ?? [];

    // Calcular porcentaje de uso
    final usagePercent = maxSize > 0 ? ((currentSize / maxSize) * 100).toStringAsFixed(1) : '0.0';

    return Column(
      children: [
        // Información del TAG (Hardware)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B82F6).withValues(alpha: 0.2),
                const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.nfc, color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Información del TAG',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('ID', tagId),
              _buildInfoRow('Tipo', tagType),
              _buildInfoRow('Capacidad Total', '$maxSize bytes'),
              _buildInfoRow('Espacio Usado', '$currentSize bytes ($usagePercent%)'),
              _buildInfoRow('Espacio Disponible', '$availableSize bytes'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Información del Contenido
        if (recordCount > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Información del Contenido',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Registros', '$recordCount'),
                _buildInfoRow('Tamaño', '$sizeBytes bytes ($sizeKB KB)'),
                if (fields.isNotEmpty) _buildInfoRow('Campos detectados', fields.join(', ')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecodedContent() {
    // Parsear y mostrar cada registro de forma estructurada
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(_model.rawContent);

    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registros Decodificados',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...matches.map((match) {
            final index = matches.toList().indexOf(match) + 1;
            final recordContent = match.group(1) ?? '';
            final fields = recordContent.split(';');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro #$index',
                    style: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...fields.map((field) {
                    final parts = field.split(':');
                    if (parts.length >= 2) {
                      final key = parts[0].trim();
                      final value = parts.sublist(1).join(':').trim();
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$key: ',
                              style: const TextStyle(fontFamily: 'Roboto Mono',
                                fontSize: 10,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                value,
                                style: const TextStyle(fontFamily: 'Roboto Mono',
                                  fontSize: 10,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
