import 'dart:convert';

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

  // ── Depuración de registros corruptos ──
  // Contenido depurado en memoria (sin chunks corruptos); null si el contenido
  // leído está sano o si el chunk base es irrecuperable.
  String? _purgedCandidate;
  bool _isPurgeWriting = false;
  bool _purgeSuccess = false;
  String? _purgeMessage;

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
      _purgedCandidate = null;
      _isPurgeWriting = false;
      _purgeSuccess = false;
      _purgeMessage = null;
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
            'tagTechnology': result['tagTechnology'] ?? 'Desconocido',
            'ndefWritable': result['ndefWritable'] ?? false,
            if ((result['atqaSak'] ?? '').toString().isNotEmpty)
              'atqaSak': result['atqaSak'],
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
            _purgedCandidate = _computePurgedCandidate(content);
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

  /// Calcula el contenido depurado (sin registros corruptos) a partir del
  /// contenido leído. Retorna null si el contenido está sano (no hay nada que
  /// depurar) o si el chunk base es irrecuperable.
  String? _computePurgedCandidate(String raw) {
    if (raw.isEmpty) return null;
    try {
      final purged = actions.purgeCorruptedNfcContent(raw);
      if (purged == null || purged.isEmpty || purged == raw) return null;
      debugPrint('🧹 Corrupción detectada: ${raw.length} chars → '
          '${purged.length} chars tras depurar');
      return purged;
    } catch (e) {
      debugPrint('⚠️ Error calculando contenido depurado: $e');
      return null;
    }
  }

  /// Depura los registros corruptos del contenido en memoria y solicita
  /// acercar el tag para reemplazar su contenido por la versión depurada.
  Future<void> _purgeAndRewrite() async {
    final original = _model.rawContent;
    final purged = _purgedCandidate;
    if (purged == null) return;

    final removed = original.split(actions.kNfcChunkDelimiter).length -
        purged.split(actions.kNfcChunkDelimiter).length;

    setState(() {
      _isPurgeWriting = true;
      _purgeSuccess = false;
      _purgeMessage = null;
    });

    debugPrint('🧹 DEPURAR: contenido depurado en memoria '
        '(${original.length} → ${purged.length} chars, '
        '$removed chunk(s) eliminados). Esperando tag para reescribir...');

    final ok = await actions.writeNFCTagDirect(context, purged);
    if (!mounted) return;

    if (ok) {
      final newSize = utf8.encode(purged).length;
      final maxSize = (_model.tagInfo?['maxSize'] as int?) ?? 0;
      setState(() {
        _isPurgeWriting = false;
        _purgeSuccess = true;
        _purgeMessage = removed == 1
            ? 'Se eliminó 1 registro corrupto. El tag fue reescrito con el '
                'contenido válido ($newSize bytes).'
            : 'Se eliminaron $removed registros corruptos. El tag fue '
                'reescrito con el contenido válido ($newSize bytes).';
        _model.rawContent = purged;
        _model.tagInfo = {
          ...?_model.tagInfo,
          'currentSize': newSize,
          'availableSize': maxSize > newSize ? maxSize - newSize : 0,
          ..._extractTagInfo(purged),
        };
        _purgedCandidate = null;
      });
      debugPrint('✅ DEPURAR: tag reescrito con contenido depurado');
    } else {
      setState(() {
        _isPurgeWriting = false;
        _purgeSuccess = false;
        _purgeMessage = 'No se pudo reescribir el tag. El contenido depurado '
            'sigue en memoria: vuelva a intentar acercando bien el tag.';
      });
      debugPrint('❌ DEPURAR: fallo al reescribir el tag');
    }
  }

  Map<String, dynamic> _extractTagInfo(String content) {
    final info = <String, dynamic>{};

    info['sizeBytes'] = content.length;
    info['sizeKB'] = (content.length / 1024).toStringAsFixed(2);

    if (actions.isMultiChunkFormat(content)) {
      final parts = content.split(actions.kNfcChunkDelimiter);
      final firstChunk = parts[0];
      final deltaCount = parts.length - 1;
      final dl = deltaCount == 1 ? 'delta' : 'deltas';

      if (firstChunk.startsWith('N1:')) {
        info['format'] = 'Multi-chunk (N1 + $deltaCount $dl)';
      } else if (firstChunk.startsWith('C1:')) {
        info['format'] = 'Multi-chunk (C1 + $deltaCount $dl)';
      } else {
        info['format'] = 'Multi-chunk ($deltaCount $dl)';
      }
      info['chunkCount'] = parts.length;
      info['deltaCount'] = deltaCount;

      final nfcJson = actions.parseNfcJson(content);
      if (nfcJson != null) {
        final visits = nfcJson['Visits'] as List?;
        info['recordCount'] = visits?.length ?? 0;
        final readInfo = nfcJson['Read_info'] as Map<String, dynamic>?;
        if (readInfo != null) {
          info['productId'] = readInfo['Id_product'];
          info['rfid'] = readInfo['RFID'];
          info['productName'] = readInfo['Name_product'];
          info['dateCreated'] = readInfo['Date_created'];
        }
      } else {
        info['recordCount'] = 0;
      }
    } else if (actions.isNfcCompressedFormat(content)) {
      info['format'] = content.startsWith('C1:')
          ? 'Comprimido (C1 — zlib + base64url)'
          : 'Minificado (N1 — JSON compacto)';
      final nfcJson = actions.nfcDecode(content);
      if (nfcJson != null) {
        final visits = nfcJson['Visits'] as List?;
        info['recordCount'] = visits?.length ?? 0;
        final readInfo = nfcJson['Read_info'] as Map<String, dynamic>?;
        if (readInfo != null) {
          info['productId'] = readInfo['Id_product'];
          info['rfid'] = readInfo['RFID'];
          info['productName'] = readInfo['Name_product'];
          info['dateCreated'] = readInfo['Date_created'];
        }
      } else {
        info['recordCount'] = 0;
      }
    } else if (actions.isNewJsonFormat(content)) {
      info['format'] = 'JSON Canónico';
      final nfcJson = actions.parseNfcJson(content);
      if (nfcJson != null) {
        final visits = nfcJson['Visits'] as List?;
        info['recordCount'] = visits?.length ?? 0;
        final readInfo = nfcJson['Read_info'] as Map<String, dynamic>?;
        if (readInfo != null) {
          info['productId'] = readInfo['Id_product'];
          info['rfid'] = readInfo['RFID'];
          info['productName'] = readInfo['Name_product'];
          info['dateCreated'] = readInfo['Date_created'];
        }
        info['fields'] = ['DH', 'OP', 'VISITS', 'RESULTS', 'HE'];
      } else {
        info['recordCount'] = 0;
        info['fields'] = [];
      }
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
          child: SingleChildScrollView(
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
                                _model.rawContent.replaceAll(
                                    actions.kNfcChunkDelimiter, '\n── DELTA ──\n'),
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

            // ── Depuración de registros corruptos ──
            // Esperando tag para reescribir el contenido depurado
            if (_isPurgeWriting) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.nfc,
                          color: Color(0xFFEF4444),
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ACERQUE EL TAG',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Se reemplazará el contenido del tag por la versión '
                      'depurada (sin los registros corruptos)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Resultado de la depuración
            if (_purgeMessage != null && !_isPurgeWriting) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_purgeSuccess
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _purgeSuccess
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _purgeSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _purgeSuccess
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _purgeMessage!,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 13,
                          color: _purgeSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Botón de depuración (solo cuando hay registros corruptos)
            if (_model.isSuccess &&
                !_model.isReading &&
                !_isPurgeWriting &&
                _purgedCandidate != null) ...[
              const SizedBox(height: 16),
              FFButtonWidget(
                onPressed: _purgeAndRewrite,
                text: 'Depurar registros corruptos',
                icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                options: FFButtonOptions(
                  width: double.infinity,
                  height: 48,
                  color: const Color(0xFFEF4444),
                  textStyle: const TextStyle(fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],

            if (!_model.isReading) const SizedBox(height: 24),

            // Botones de acción
            if (!_model.isReading && !_isPurgeWriting)
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
              if ((info['tagTechnology'] ?? '').toString().isNotEmpty &&
                  info['tagTechnology'] != 'Desconocido')
                _buildInfoRow('Tecnología', info['tagTechnology'].toString()),
              if ((info['atqaSak'] ?? '').toString().isNotEmpty)
                _buildInfoRow('ATQA / SAK', info['atqaSak'].toString()),
              _buildInfoRow('Capacidad Total', '$maxSize bytes'),
              _buildInfoRow('Espacio Usado', '$currentSize bytes ($usagePercent%)'),
              _buildInfoRow('Espacio Disponible', '$availableSize bytes'),
              _buildInfoRow(
                'NDEF Escribible',
                (info['ndefWritable'] == true) ? 'Sí' : 'No',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Análisis de capacidad teniendo en cuenta formato N1:/C1:
        _buildCapacityAnalysisSection(info),
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
                if (info['format'] != null)
                  _buildInfoRow('Formato', info['format'].toString()),
                _buildInfoRow('Registros', '$recordCount'),
                _buildInfoRow('Tamaño', '$sizeBytes bytes ($sizeKB KB)'),
                if ((info['chunkCount'] ?? 0) > 1)
                  _buildInfoRow(
                    'Chunks',
                    '${info['chunkCount']} total  (1 principal + ${info['deltaCount']} delta${(info['deltaCount'] ?? 0) > 1 ? "s" : ""})',
                  ),
                if (info['productName'] != null)
                  _buildInfoRow('Producto', info['productName'].toString()),
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

  Widget _buildCapacityAnalysisSection(Map<String, dynamic> info) {
    final maxSize = (info['maxSize'] as int?) ?? 0;
    final contentBytes = (info['sizeBytes'] as int?) ?? 0;
    if (maxSize <= 0 || contentBytes <= 0) return const SizedBox.shrink();

    final content = _model.rawContent;

    // NDEF overhead (igual que write_n_f_c_tag.dart):
    // flags(1)+type_len(1)+type_char(1)+payload_len_field(1 o 4)+status_byte(1)+lang_code(2)
    // = 7 bytes si payload ≤ 255, 10 bytes si payload > 255
    final ndefOverhead = (contentBytes + 3) > 255 ? 10 : 7;
    final maxContentBytes = maxSize - ndefOverhead;
    final freeContentBytes = (maxContentBytes - contentBytes).clamp(0, maxSize);
    final usageFraction =
        maxContentBytes > 0 ? (contentBytes / maxContentBytes).clamp(0.0, 1.0) : 0.0;
    final usagePercent = (usageFraction * 100).toStringAsFixed(1);

    // Formato del contenido
    final isMultiChunk = actions.isMultiChunkFormat(content);
    final isC1 = content.startsWith('C1:');
    final isN1 = content.startsWith('N1:');

    String formatShort;
    String formatDesc;
    Color formatColor;
    if (isMultiChunk) {
      final prefix = content.startsWith('C1:') ? 'C1:' : (content.startsWith('N1:') ? 'N1:' : '');
      formatShort = 'Multi-chunk ($prefix)';
      formatDesc = prefix == 'C1:'
          ? 'Bloque base comprimido + deltas de visita'
          : 'Bloque base minificado + deltas de visita';
      formatColor = const Color(0xFFF59E0B);
    } else if (isC1) {
      formatShort = 'C1: Comprimido';
      formatDesc = 'zlib + base64url — máxima densidad';
      formatColor = const Color(0xFF10B981);
    } else if (isN1) {
      formatShort = 'N1: Minificado';
      formatDesc = 'JSON compacto — óptimo para < 200 bytes';
      formatColor = const Color(0xFF3B82F6);
    } else {
      formatShort = 'JSON Canónico';
      formatDesc = 'Formato sin comprimir';
      formatColor = Colors.white60;
    }

    // Deltas adicionales aproximados para fast-append (tag-writer)
    // Cada delta ≈ 1 (delimitador \x1E) + ~50 bytes (V:{...}) = ~51 bytes
    const int deltaBytes = 51;
    final approxDeltasLeft = freeContentBytes > 0 ? (freeContentBytes / deltaBytes).floor() : 0;

    // Color del progreso según uso
    final Color progressColor;
    if (usageFraction < 0.6) {
      progressColor = const Color(0xFF10B981);
    } else if (usageFraction < 0.85) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_usage_rounded, color: progressColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Capacidad NFC',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: formatColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: formatColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  formatShort,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: formatColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usageFraction,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),

          // Bytes usados / disponibles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$contentBytes / $maxContentBytes bytes  ($usagePercent%)',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, color: Colors.white60),
              ),
              Text(
                '$freeContentBytes bytes libres',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          _buildCapacityRow(
            'Overhead NDEF',
            '$ndefOverhead bytes (cabecera de registro)',
            Icons.layers_outlined,
            Colors.white38,
          ),
          _buildCapacityRow(
            'Codificación',
            formatDesc,
            Icons.description_outlined,
            formatColor,
          ),
          if (approxDeltasLeft > 0)
            _buildCapacityRow(
              'Visitas adicionales',
              '≈ $approxDeltasLeft más antes del próximo tag  (~$deltaBytes bytes/delta)',
              Icons.add_circle_outline_rounded,
              const Color(0xFF10B981),
            ),
          if (approxDeltasLeft == 0 && freeContentBytes < deltaBytes)
            _buildCapacityRow(
              'Estado',
              'Tag casi lleno — el siguiente escaneo usará un segundo tag',
              Icons.warning_amber_rounded,
              const Color(0xFFF59E0B),
            ),
        ],
      ),
    );
  }

  Widget _buildCapacityRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, color: Colors.white54),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
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
    final content = _model.rawContent;
    if (content.isEmpty) return const SizedBox.shrink();

    final isMultiChunk = actions.isMultiChunkFormat(content);
    final isCompressed = actions.isNfcCompressedFormat(content);
    final isNewJson = actions.isNewJsonFormat(content);

    if (!isMultiChunk &&
        !isCompressed &&
        !isNewJson &&
        !actions.isJsonArrayFormat(content)) {
      return const SizedBox.shrink();
    }

    // Decodificar como LISTA de registros (objeto único o array multi-producto,
    // en cualquier formato: canónico / N1 / C1 / multi-chunk).
    final records = actions.decodeNfcRecords(content);

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
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (isMultiChunk) ...[
            _buildChunkBreakdown(content),
            const SizedBox(height: 12),
          ],
          ...List.generate(
            records.length,
            (idx) => Padding(
              padding: EdgeInsets.only(top: idx > 0 ? 10 : 0),
              child: _buildDecodedRecords(
                records[idx],
                content,
                recordLabel: records.length > 1 ? 'Producto ${idx + 1}' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChunkBreakdown(String content) {
    final chunks = content.split(actions.kNfcChunkDelimiter);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_rounded, color: Color(0xFF3B82F6), size: 15),
              const SizedBox(width: 6),
              Text(
                'Estructura Multi-chunk (${chunks.length} segmento${chunks.length != 1 ? "s" : ""})',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(chunks.length, (i) {
            final chunk = chunks[i];
            final isFirst = i == 0;
            final sizeB = chunk.length;
            final String label;
            final String encoding;
            final Color labelColor;

            if (isFirst) {
              label = 'Chunk inicial';
              encoding = chunk.startsWith('N1:')
                  ? 'N1 — ${sizeB}B'
                  : chunk.startsWith('C1:')
                      ? 'C1 — ${sizeB}B (comprimido)'
                      : '${sizeB}B';
              labelColor = const Color(0xFF10B981);
            } else {
              label = 'Delta #$i';
              encoding = '${sizeB}B';
              labelColor = const Color(0xFFF59E0B);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isFirst ? Icons.home_rounded : Icons.add_circle_outline,
                    color: labelColor,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$label  ',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  Text(
                    encoding,
                    style: const TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 10,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDecodedRecords(Map<String, dynamic> canonical, String rawContent,
      {String? recordLabel}) {
    final readInfo = canonical['Read_info'] as Map<String, dynamic>?;
    final visits = (canonical['Visits'] as List?)
        ?.map((v) => v as Map<String, dynamic>)
        .toList();
    final isMultiChunk = actions.isMultiChunkFormat(rawContent);
    final chunkCount =
        isMultiChunk ? rawContent.split(actions.kNfcChunkDelimiter).length : 0;

    // status.visits_details: campos del formulario inyectados por WRITER_STATUS.
    // Solo se renderiza si existe y tiene elementos.
    final statusBlock = canonical['status'];
    final formDetails =
        (statusBlock is Map ? statusBlock['visits_details'] : null) as List?;
    final formDetailsList = formDetails
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recordLabel != null) ...[
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  color: Color(0xFF60A5FA), size: 14),
              const SizedBox(width: 6),
              Text(
                recordLabel,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (readInfo != null) ...[
          _buildReadInfoCard(readInfo),
          const SizedBox(height: 8),
        ],
        if (visits != null)
          ...List.generate(visits.length, (i) {
            String? source;
            if (isMultiChunk) {
              source = i == 0 ? 'Chunk inicial' : 'Delta #$i';
              if (i >= chunkCount - 1 && chunkCount > 1) {
                source = 'Delta #$i';
              }
            }
            return _buildVisitCard(i + 1, visits[i], source: source);
          }),
        if (formDetailsList.isNotEmpty) _buildStatusDetailsCard(formDetailsList),
      ],
    );
  }

  /// Renderiza el bloque status.visits_details como una lista de etiquetas:
  /// status_option → status_response (con la hora formateada). No se llama si
  /// la lista está vacía.
  Widget _buildStatusDetailsCard(List<Map<String, dynamic>> details) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: Color(0xFF10B981), size: 14),
              SizedBox(width: 6),
              Text(
                'Detalles del Formulario',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((d) {
            final option = (d['status_option'] ?? '').toString();
            final response =
                _formatStatusResponse((d['status_response'] ?? '').toString());
            final idStatus = (d['id_activity_status'] ?? '').toString();
            final label = option.isNotEmpty
                ? option
                : (idStatus.isNotEmpty ? 'Status $idStatus' : 'Campo');
            return _buildFieldRow(label, response.isNotEmpty ? response : '—');
          }),
        ],
      ),
    );
  }

  /// Convierte el literal "TimeOfDay(HH:MM)" en "HH:MM"; deja el resto intacto.
  String _formatStatusResponse(String response) {
    final m = RegExp(r'TimeOfDay\((\d{1,2}:\d{2})\)').firstMatch(response);
    if (m != null) return m.group(1)!;
    return response;
  }

  Widget _buildReadInfoCard(Map<String, dynamic> readInfo) {
    final productName = readInfo['Name_product']?.toString() ?? '';
    final productId = readInfo['Id_product']?.toString() ?? '';
    final rfid = readInfo['RFID']?.toString() ?? '';
    final dateCreated = readInfo['Date_created'];
    final tagTo = readInfo['tag_to']?.toString() ?? '';
    final userId = readInfo['US']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Color(0xFF8B5CF6), size: 14),
              SizedBox(width: 6),
              Text(
                'Información del Producto',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (productName.isNotEmpty) _buildFieldRow('Nombre', productName),
          if (productId.isNotEmpty) _buildFieldRow('ID Producto', productId),
          if (rfid.isNotEmpty) _buildFieldRow('RFID', rfid),
          if (dateCreated != null)
            _buildFieldRow('Fecha creación', _epochToReadable(dateCreated)),
          if (tagTo.isNotEmpty) _buildFieldRow('Tag destino', tagTo),
          if (userId.isNotEmpty) _buildFieldRow('Usuario escritor', userId),
        ],
      ),
    );
  }

  Widget _buildVisitCard(int number, Map<String, dynamic> visit, {String? source}) {
    final dh = visit['DH'] ?? visit['h'];
    final op = visit['OP'] ?? visit['o'];
    final visitCount = visit['VISITS'] ?? visit['v'];
    final results = visit['RESULTS'] ?? visit['s'];
    final he = visit['HE'] ?? visit['e'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 6),
              Text(
                'Visita #$number',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
              if (source != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    source,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (dh != null) _buildFieldRow('Fecha / Hora', _epochToReadable(dh)),
          if (op != null) _buildFieldRow('Operador (OP)', op.toString()),
          if (visitCount != null) _buildFieldRow('Visitas', visitCount.toString()),
          if (results != null) _buildFieldRow('Resultados', results.toString()),
          if (he != null) _buildFieldRow('Lote (HE)', he.toString()),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key: ',
            style: const TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 10,
              color: Color(0xFFA78BFA),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 10,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _epochToReadable(dynamic epoch) {
    try {
      final int seconds = epoch is int ? epoch : int.parse(epoch.toString());
      final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${dt.day}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return epoch.toString();
    }
  }
}
