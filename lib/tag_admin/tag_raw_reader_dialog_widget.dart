import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
    });

    try {
      final nfcData = await actions.readNFC(context, autoClose: false);

      if (nfcData != null && nfcData.isNotEmpty) {
        // Extraer información técnica del tag
        final tagInfo = _extractTagInfo(nfcData);

        setState(() {
          _model.rawContent = nfcData;
          _model.tagInfo = tagInfo;
          _model.isSuccess = true;
          _model.isReading = false;
        });
      } else {
        throw Exception('No se pudo leer el tag NFC');
      }
    } catch (e) {
      setState(() {
        _model.isReading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Map<String, dynamic> _extractTagInfo(String content) {
    final info = <String, dynamic>{};

    // Contar registros
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(content);
    info['recordCount'] = matches.length;

    // Tamaño en bytes (UTF-8)
    info['sizeBytes'] = content.length;

    // Tamaño estimado en KB
    info['sizeKB'] = (content.length / 1024).toStringAsFixed(2);

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

    return info;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _model.rawContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Contenido copiado al portapapeles',
              style: GoogleFonts.inter(
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
                      Icons.code_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Contenido Raw del TAG',
                      style: GoogleFonts.inter(
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

            // Estado de lectura
            if (_model.isReading)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFF59E0B),
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
                          color: Color(0xFFF59E0B).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.nfc,
                          color: Color(0xFFF59E0B),
                          size: 48,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'ACERQUE EL TAG',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
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
                          style: GoogleFonts.inter(
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
                constraints: BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información técnica
                      if (_model.tagInfo != null) _buildTagInfoSection(),
                      SizedBox(height: 16),

                      // Contenido raw
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(0xFFF59E0B).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Contenido Raw',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                InkWell(
                                  onTap: _copyToClipboard,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFF59E0B),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
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
                                          style: GoogleFonts.inter(
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
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                _model.rawContent,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: Color(0xFFF59E0B),
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Decodificación del contenido
                      _buildDecodedContent(),
                    ],
                  ),
                ),
              ),

            // Error
            if (!_model.isReading && _model.errorMessage != null)
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
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_model.isReading) SizedBox(height: 24),

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
                  if (_model.errorMessage != null) SizedBox(width: 12),
                  if (_model.errorMessage != null)
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: _startReading,
                        text: 'Reintentar',
                        icon: Icon(Icons.refresh, size: 20),
                        options: FFButtonOptions(
                          height: 48,
                          color: Color(0xFFF59E0B),
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
      ),
    );
  }

  Widget _buildTagInfoSection() {
    final info = _model.tagInfo!;
    final recordCount = info['recordCount'] ?? 0;
    final sizeBytes = info['sizeBytes'] ?? 0;
    final sizeKB = info['sizeKB'] ?? '0.00';
    final fields = (info['fields'] as List<dynamic>?) ?? [];

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'Información Técnica',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildInfoRow('Registros', '$recordCount'),
          _buildInfoRow('Tamaño', '$sizeBytes bytes ($sizeKB KB)'),
          _buildInfoRow('Campos detectados', fields.join(', ')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chevron_right, color: Color(0xFFF59E0B), size: 16),
          SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
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
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registros Decodificados',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          ...matches.map((match) {
            final index = matches.toList().indexOf(match) + 1;
            final recordContent = match.group(1) ?? '';
            final fields = recordContent.split(';');

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(0xFFF59E0B).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro #$index',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(height: 8),
                  ...fields.map((field) {
                    final parts = field.split(':');
                    if (parts.length >= 2) {
                      final key = parts[0].trim();
                      final value = parts.sublist(1).join(':').trim();
                      return Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$key: ',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                value,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
