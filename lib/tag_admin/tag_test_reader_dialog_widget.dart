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
      // Decodificar como LISTA de registros: un tag puede acumular varios
      // productos (uno por RFID de origen). decodeNfcRecords soporta objeto
      // único o array, en cualquier formato (canónico / N1 / C1 / multi-chunk).
      // Cada visita se etiqueta con su Name_product para poder agrupar el árbol
      // por PRODUCTO (extractVisitsFromJson no incluye el nombre del producto).
      final records = actions.decodeNfcRecords(nfcContent);
      for (final record in records) {
        final readInfo = record['Read_info'] as Map<String, dynamic>?;
        final productName = (readInfo?['Name_product'] as String?)?.trim();
        final visits = actions.extractVisitsFromJson(record);
        for (final v in visits) {
          v['productName'] =
              (productName?.isNotEmpty ?? false) ? productName : 'Producto';
          parsedData.add(v);
        }
      }
      debugPrint(
          '📋 TAG TEST READER: ${records.length} registro(s), ${parsedData.length} visitas');
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

    // Agrupar por PRODUCTO (Name_product) — primer nivel del árbol
    final Map<String, List<Map<String, dynamic>>> groupedByProduct = {};
    for (var record in tagData) {
      final product = record['productName'] as String? ?? 'Producto';
      groupedByProduct.putIfAbsent(product, () => []).add(record);
    }

    // Calcular totales generales
    int grandTotalVisits = 0;
    for (var record in tagData) {
      grandTotalVisits += (record['visits'] as int?) ?? 0;
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A4B), // Azul oscuro como tag-transfer
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFF64B5F6),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Contenido del TAG',
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
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$grandTotalVisits visita${grandTotalVisits != 1 ? "s" : ""}',
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
              ...groupedByProduct.entries.map((entry) {
                final productName = entry.key;
                final records = entry.value;
                return _buildProductGroup(productName, records);
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Nivel 1 del árbol: agrupa por PRODUCTO (Name_product). Al expandir,
  /// agrupa sus registros por lote y delega en _buildHeadquarterGroup.
  Widget _buildProductGroup(
      String productName, List<Map<String, dynamic>> records) {
    final expansionKey = 'PR_$productName';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    // Totales del producto
    int totalVisits = 0;
    int totalResults = 0;
    for (var record in records) {
      totalVisits += (record['visits'] as int?) ?? 0;
      totalResults += (record['results'] as int?) ?? 0;
    }

    // Agrupar por lote (headquarterId) para el segundo nivel
    final Map<int, List<Map<String, dynamic>>> groupedByHeadquarter = {};
    for (var record in records) {
      final heId = record['headquarterId'] as int? ?? 0;
      groupedByHeadquarter.putIfAbsent(heId, () => []).add(record);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.45),
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
                    color: const Color(0xFF90CAF9),
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF90CAF9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Producto: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF90CAF9),
                                ),
                              ),
                              TextSpan(
                                text: productName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$totalVisits visita${totalVisits != 1 ? "s" : ""}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${groupedByHeadquarter.length}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
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
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: groupedByHeadquarter.entries.map((entry) {
                  return _buildHeadquarterGroup(
                      entry.key, entry.value, productKey: productName);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadquarterGroup(
      int headquarterId, List<Map<String, dynamic>> records,
      {String productKey = ''}) {
    // Buscar el nombre del lote
    String loteName = 'Lote #$headquarterId';
    final headquarters = FFAppState().headquartersList.firstWhere(
      (h) => h.idHeadquarter == headquarterId,
      orElse: () => HeadquartersStruct(),
    );

    if (headquarters.nameHeadquarter.isNotEmpty) {
      loteName = headquarters.nameHeadquarter;
    }

    final expansionKey = 'HE_${productKey}_$headquarterId';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    // Agrupar por operador
    final Map<String, Map<String, dynamic>> operatorGroups = {};
    for (var record in records) {
      final operatorId = record['operatorId'] as String? ?? 'N/A';

      if (!operatorGroups.containsKey(operatorId)) {
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
    int totalResults = 0;
    for (var operatorGroup in operatorGroups.values) {
      totalResults += (operatorGroup['totalResults'] as int?) ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
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
                    color: const Color(0xFF64B5F6),
                    size: 32,
                    weight: 700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Lote: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF74C69D),
                                ),
                              ),
                              TextSpan(
                                text: loteName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
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
              padding: const EdgeInsets.only(
                  left: 16, right: 10, bottom: 10, top: 10),
              child: Column(
                children: operatorGroups.entries.map((entry) {
                  final operatorId = entry.key;
                  final operatorData = entry.value;
                  return _buildTagReaderOperatorGroup(
                      headquarterId, operatorId, operatorData,
                      productKey: productKey);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagReaderOperatorGroup(
      int headquarterId, String operatorId, Map<String, dynamic> operatorData,
      {String productKey = ''}) {
    final operatorName = operatorData['operatorName'] as String? ?? 'Operador';
    final totalVisits = operatorData['totalVisits'] as int? ?? 0;
    final totalResults = operatorData['totalResults'] as int? ?? 0;
    final records =
        operatorData['records'] as List<Map<String, dynamic>>? ?? [];

    final expansionKey = 'TR_OP_${productKey}_${headquarterId}_$operatorId';
    final isExpanded = _tagReaderExpansionState[expansionKey] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
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
                    color: const Color(0xFF64B5F6),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Operador: ',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64B5F6),
                                ),
                              ),
                              TextSpan(
                                text: operatorName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_unityLabel: ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '$totalResults',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$totalVisits visita${totalVisits != 1 ? "s" : ""}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${records.length}',
                    style: const TextStyle(fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64B5F6),
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
                      color: const Color(0xFF1B3A4B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF64B5F6),
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
                            color: Color(0xFF64B5F6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$results R',
                          style: const TextStyle(fontFamily: 'Roboto',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64B5F6),
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
