import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';

import 'tag_test_reader_dialog_model.dart';
export 'tag_test_reader_dialog_model.dart';

class TagTestReaderDialogWidget extends StatefulWidget {
  const TagTestReaderDialogWidget({super.key});

  @override
  State<TagTestReaderDialogWidget> createState() =>
      _TagTestReaderDialogWidgetState();
}

class _TagTestReaderDialogWidgetState extends State<TagTestReaderDialogWidget>
    with TickerProviderStateMixin {
  late TagTestReaderDialogModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Map para controlar el estado de expansión del tree view de tag-reader (por lote)
  final Map<String, bool> _tagReaderExpansionState = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TagTestReaderDialogModel());

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
      _model.parsedRecords = [];
    });

    try {
      // Usar readNFCBasic para Centro de Administración (sin validación de tipo)
      final nfcData = await actions.readNFCBasic(context, autoClose: false);

      if (nfcData.isNotEmpty) {
        // Parsear el contenido del tag
        final records = _parseNfcContent(nfcData);

        setState(() {
          _model.rawContent = nfcData;
          _model.parsedRecords = records;
          _model.isSuccess = records.isNotEmpty;
          _model.isReading = false;
        });

        if (records.isEmpty) {
          throw Exception('No se pudieron parsear los datos del tag');
        }
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

  List<Map<String, dynamic>> _parseNfcContent(String nfcContent) {
    final List<Map<String, dynamic>> parsedData = [];

    try {
      // Detectar si es formato JSON nuevo
      if (actions.isNewJsonFormat(nfcContent)) {
        debugPrint('📋 TAG TEST READER: Parseando formato JSON nuevo');
        final nfcJson = actions.parseNfcJson(nfcContent);
        if (nfcJson != null) {
          return actions.extractVisitsFromJson(nfcJson);
        }
      } else if (actions.isOldFormat(nfcContent)) {
        // Formato antiguo (retrocompatibilidad)
        debugPrint('📋 TAG TEST READER: Parseando formato antiguo');
        final regexRecords = RegExp(r'\{([^}]+)\}');
        final matches = regexRecords.allMatches(nfcContent);

        for (var match in matches) {
          final recordContent = match.group(1);
          if (recordContent == null) continue;

          final Map<String, dynamic> record = {};
          final fields = recordContent.split(';');

          for (var field in fields) {
            final parts = field.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join(':').trim();

              switch (key) {
                case 'DH':
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
            parsedData.add(record);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error parseando contenido NFC: $e');
    }

    return parsedData;
  }

  String get _unityLabel {
    final unityValue = getJsonField(
      FFAppState().currentActivity,
      r'''$.Unity''',
    )?.toString() ??
        '';

    return unityValue.isNotEmpty ? unityValue : 'Resultados';
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
                      Icons.visibility_rounded,
                      color: Color(0xFF3B82F6),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Leer TAG NFC',
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
                    color: const Color(0xFF3B82F6),
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
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.nfc,
                          color: Color(0xFF3B82F6),
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
                        color: Color(0xFF3B82F6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                          strokeWidth: 3,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Leyendo TAG NFC...',
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

            // Resumen del TAG (cuando se ha leído exitosamente)
            if (_model.isSuccess) _buildTagReaderSummary(),

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
                  if (_model.errorMessage != null)
                    const SizedBox(width: 12),
                  if (_model.errorMessage != null)
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: _startReading,
                        text: 'Reintentar',
                        icon: const Icon(Icons.refresh, size: 20),
                        options: FFButtonOptions(
                          height: 48,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagReaderSummary() {
    final tagData = _model.parsedRecords;
    if (tagData.isEmpty) return const SizedBox.shrink();

    // Agrupar por lote (headquarterId)
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in tagData) {
      final heId = record['headquarterId'] as int? ?? 0;
      if (!groupedByHeadquarter.containsKey(heId)) {
        groupedByHeadquarter[heId] = [];
      }
      groupedByHeadquarter[heId]!.add(record);
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4332), // Verde oscuro
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.summarize_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Resumen del TAG',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tagData.length} ${tagData.length == 1 ? 'registro' : 'registros'}',
                      style: const TextStyle(fontFamily: 'Roboto',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...groupedByHeadquarter.entries.map((entry) {
                final headquarterId = entry.key;
                final records = entry.value;
                return _buildHeadquarterGroup(headquarterId, records);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadquarterGroup(
      int headquarterId, List<Map<String, dynamic>> records) {
    // Buscar el nombre del lote
    String loteName = 'Lote #$headquarterId';
    final headquarters = FFAppState().headquartersList.firstWhere(
      (h) => h.idHeadquarter == headquarterId,
      orElse: () => HeadquartersStruct(),
    );

    if (headquarters.nameHeadquarter.isNotEmpty) {
      loteName = headquarters.nameHeadquarter;
    }

    final expansionKey = 'HE_$headquarterId';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    // Agrupar por operador
    final Map<String, Map<String, dynamic>> operatorGroups = {};
    for (var record in records) {
      final operatorId = record['operatorId'] as String? ?? 'N/A';

      if (!operatorGroups.containsKey(operatorId)) {
        // Buscar nombre del operador en usersList
        // operatorId contiene el idUser (identificador numérico del usuario)
        String operatorName = 'Operador';
        try {
          final idUserFromTag = int.tryParse(operatorId);
          if (idUserFromTag != null) {
            final user = FFAppState().usersList.firstWhere(
              (u) => u.idUser == idUserFromTag,
              orElse: () => UsersStruct(),
            );
            if (user.nameUser.isNotEmpty) {
              operatorName = user.nameUser;
            }
          }
        } catch (e) {
          debugPrint('Error buscando operador: $e');
        }

        operatorGroups[operatorId] = {
          'operatorName': operatorName,
          'totalVisits': 0,
          'totalResults': 0,
          'records': <Map<String, dynamic>>[],
        };
      }

      final visits = (record['visits'] as int?) ?? 0;
      final results = (record['results'] as int?) ?? 0;

      operatorGroups[operatorId]!['totalVisits'] =
          (operatorGroups[operatorId]!['totalVisits'] as int) + visits;
      operatorGroups[operatorId]!['totalResults'] =
          (operatorGroups[operatorId]!['totalResults'] as int) + results;
      (operatorGroups[operatorId]!['records'] as List<Map<String, dynamic>>)
          .add(record);
    }

    // Calcular totales del lote
    int totalVisits = 0;
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
      totalVisits += (operatorGroup['totalVisits'] as int?) ?? 0;
      totalResults += (operatorGroup['totalResults'] as int?) ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            const Color(0xFF2D6A4F).withValues(alpha: 0.3), // Verde medio con transparencia
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagReaderExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.white,
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loteName,
                          style: const TextStyle(fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${operatorGroups.length}',
                      style: const TextStyle(fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: operatorGroups.entries.map((entry) {
                  final operatorId = entry.key;
                  final operatorData = entry.value;
                  return _buildTagReaderOperatorGroup(
                      headquarterId, operatorId, operatorData);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagReaderOperatorGroup(
      int headquarterId, String operatorId, Map<String, dynamic> operatorData) {
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;
    final records =
        operatorData['records'] as List<Map<String, dynamic>>? ?? [];

    final expansionKey = 'TR_OP_${headquarterId}_$operatorId';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tagReaderExpansionState[expansionKey] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFF74C69D),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF74C69D),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          operatorName,
                          style: const TextStyle(fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVisits visitas • $totalResults ${_unityLabel.toLowerCase()}',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${records.length}',
                    style: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF74C69D),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 24, right: 10, bottom: 10),
              child: Column(
                children: records.map((record) {
                  final dateTime = record['dateTime'] as DateTime?;
                  final visits = record['visits'] as int? ?? 0;
                  final results = record['results'] as int? ?? 0;

                  String formattedDate = 'N/A';
                  if (dateTime != null) {
                    final DateFormat formatter =
                        DateFormat('dd/MM/yyyy HH:mm:ss');
                    formattedDate = formatter.format(dateTime);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B4332).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF74C69D).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF95D5B2),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        Text(
                          '$visits V',
                          style: const TextStyle(fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF95D5B2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$results R',
                          style: const TextStyle(fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF95D5B2),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
