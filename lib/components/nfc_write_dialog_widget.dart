import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:convert';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'nfc_write_dialog_model.dart';
export 'nfc_write_dialog_model.dart';

class NfcWriteDialogWidget extends StatefulWidget {
  const NfcWriteDialogWidget({
    super.key,
  });

  @override
  State<NfcWriteDialogWidget> createState() => _NfcWriteDialogWidgetState();
}

class _NfcWriteDialogWidgetState extends State<NfcWriteDialogWidget>
    with TickerProviderStateMixin {
  late NfcWriteDialogModel _model;
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
    _model = createModel(context, () => NfcWriteDialogModel());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Calcular datos automáticamente al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateData());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _calculateData() async {
    setState(() {
      _model.isCalculating = true;
    });

    try {
      // 1. Obtener el status actual del tag-writer desde currentActivity
      final currentActivity = FFAppState().currentActivity;
      String? defaultStatusJson;

      // Buscar en activity_status el status con type_status = 'tag-writer'
      final activityStatus =
          getJsonField(currentActivity, r'''$.activity_status''').toList();
      for (var status in activityStatus) {
        final typeStatus =
            getJsonField(status, r'''$.type_status''').toString();
        if (typeStatus.toLowerCase() == 'tag-writer') {
          defaultStatusJson =
              getJsonField(status, r'''$.default_status''').toString();
          break;
        }
      }

      // 2. Procesar inputCommand y outputCommand del JSON
      String? inputCommand;
      String? outputCommand;

      if (defaultStatusJson != null && defaultStatusJson.isNotEmpty) {
        try {
          final defaultStatusMap = jsonDecode(defaultStatusJson);
          inputCommand = defaultStatusMap['inputCommand'] as String?;
          outputCommand = defaultStatusMap['outputCommand'] as String?;
          debugPrint('📋 inputCommand: $inputCommand');
          debugPrint('📋 outputCommand: $outputCommand');
        } catch (e) {
          debugPrint('⚠️ Error parseando default_status JSON: $e');
        }
      }

      // 3. Calcular visitas y resultados basándose en los comandos
      int totalVisits = 0;
      int totalResults = 0;

      // Verificar si inputCommand contiene VISITS_STATUS=true (filtrar solo visitas no sincronizadas)
      bool filterByStatus =
          inputCommand != null && inputCommand.contains('VISITS_STATUS=true');

      // Verificar si outputCommand contiene VISITS=COUNTER
      bool useCounter =
          outputCommand != null && outputCommand.contains('VISITS=COUNTER');

      // SIEMPRE contar visitas pendientes desde SQLite primero
      final counters = await _countVisitsFromDatabase(filterByStatus);
      totalVisits = counters['visits'] ?? 0;
      totalResults = counters['results'] ?? 0;
      debugPrint(
          '✅ Visitas pendientes desde SQLite: $totalVisits, Results: $totalResults');

      // Si no hay visitas en SQLite y no se usa COUNTER, intentar con calculateActivityResults
      if (totalVisits == 0 && !useCounter) {
        try {
          final activityResults =
              await actions.calculateActivityResults(context);
          final activityVisits = activityResults['visits'] ?? 0;
          final activityResultsCount = activityResults['results'] ?? 0;
          if (activityVisits > 0) {
            totalVisits = activityVisits;
            totalResults = activityResultsCount;
            debugPrint(
                '✅ Visitas desde calculateActivityResults: $totalVisits, Results: $totalResults');
          }
        } catch (e) {
          debugPrint('⚠️ Error en calculateActivityResults: $e');
        }
      }

      // VALIDACIÓN: Si no hay visitas, NO permitir escritura
      if (totalVisits <= 0) {
        setState(() {
          _model.isCalculating = false;
          _model.errorMessage =
              'No hay visitas pendientes para escribir en el TAG.\\n\\nRealice al menos una visita antes de continuar.';
        });
        return;
      }

      _model.totalVisits = totalVisits;
      _model.totalResults = totalResults;

      // 4. Obtener ID y nombre del operador desde AppState
      // OP field = idUser (identificador numérico del usuario)
      _model.operatorId = FFAppState().userSelected.idUser.toString();
      _model.operatorName = FFAppState().userSelected.nameUser;
      
      debugPrint('👤 NFC WRITE - Operador ID (idUser): ${_model.operatorId}');
      debugPrint('👤 NFC WRITE - Operador Nombre: ${_model.operatorName}');
      debugPrint('👤 NFC WRITE - userSelected.operID: ${FFAppState().userSelected.operID}');

      // 4.1 Obtener el ID del Cortero (OP2) desde visitDetails
      // El Cortero viene del step con name_step = "Cortero"
      // OP2 debe almacenar el IdActivityStatus (ID único de Activities_status)
      String operator2Id = '';
      String operator2Name = ''; // También guardamos el nombre para display

      // Obtener los steps de la actividad actual
      final activityStepsRaw =
          getJsonField(currentActivity, r'''$.activity_steps''');

      if (activityStepsRaw != null) {
        final activitySteps = activityStepsRaw.toList();

        // Buscar el step con name_step = "Cortero" (case insensitive)
        int? corteroStepId;
        for (var step in activitySteps) {
          final stepName =
              getJsonField(step, r'''$.name_step''')?.toString() ?? '';
          if (stepName.toLowerCase() == 'cortero') {
            corteroStepId = getJsonField(step, r'''$.id_activity_step''');
            debugPrint('🔍 Step Cortero encontrado: ID=$corteroStepId');
            break;
          }
        }

        // Si encontramos el step Cortero, buscar el visitDetail correspondiente
        if (corteroStepId != null) {
          for (var detail in FFAppState().visitDetails) {
            // Buscar el visitDetail que pertenece al step Cortero
            // y que tiene un status seleccionado (idActivityStatus > 0)
            if (detail.idStepParent == corteroStepId &&
                detail.idActivityStatus > 0) {
              debugPrint('🔍 Detail del Cortero encontrado:');
              debugPrint('   - idActivityStatus: ${detail.idActivityStatus}');
              debugPrint('   - statusResponse: "${detail.statusResponse}"');

              // OP2 almacena el idActivityStatus (el ID del registro en Activities_status)
              operator2Id = detail.idActivityStatus.toString();

              // Obtener el Status_name desde Activities_status para display
              if (detail.idActivityStatus > 0) {
                try {
                  final dbPath = FFAppState().pathDatabase;
                  if (dbPath.isNotEmpty) {
                    final db = await openDatabase(dbPath);
                    
                    final result = await db.rawQuery(
                      'SELECT Status_name FROM Activities_status WHERE Id_activity_status = ? LIMIT 1',
                      [detail.idActivityStatus],
                    );
                    
                    if (result.isNotEmpty && result.first['Status_name'] != null) {
                      operator2Name = result.first['Status_name'].toString();
                      debugPrint('✅ Cortero encontrado - ID: $operator2Id, Nombre: $operator2Name');
                    } else {
                      debugPrint('❌ No se encontró Status_name para idActivityStatus=$operator2Id');
                    }
                    await db.close();
                  }
                } catch (e) {
                  debugPrint('❌ Error buscando Cortero: $e');
                }
              }
              break;
            }
          }
        } else {
          debugPrint('⚠️ No se encontró step "Cortero" en la actividad');
        }
      }

      // Limpiar si es "false"
      if (operator2Id == 'false') {
        operator2Id = '';
      }
      if (operator2Name == 'false') {
        operator2Name = '';
      }

      _model.operator2Id = operator2Id;
      _model.operator2Name = operator2Name;

      // 5. Calcular lote actual usando geolocalización
      final currentHeadquarter = await actions.calculateCurrentHeadquarter(
        FFAppState().headquartersSelectedList.toList(),
        FFAppState().geoLocationsList.toList(),
      );

      // Si no se encuentra lote por geolocalización, usar el primer lote de la lista seleccionada
      if (currentHeadquarter != null) {
        _model.headquarterId = currentHeadquarter.idHeadquarter;
        _model.headquarterName = currentHeadquarter.nameHeadquarter;
        debugPrint(
            '✅ Lote obtenido por geolocalización: ${_model.headquarterName} (ID: ${_model.headquarterId})');
      } else {
        // Fallback: usar el primer lote de headquartersSelectedList
        final firstHeadquarter =
            FFAppState().headquartersSelectedList.isNotEmpty
                ? FFAppState().headquartersSelectedList.first
                : null;

        if (firstHeadquarter != null) {
          _model.headquarterId = firstHeadquarter.idHeadquarter;
          _model.headquarterName = firstHeadquarter.nameHeadquarter;
          debugPrint(
              '⚠️ No se encontró lote por geolocalización. Usando primer lote de la lista: ${_model.headquarterName} (ID: ${_model.headquarterId})');
        } else {
          _model.headquarterId = 0;
          _model.headquarterName = 'N/A';
          debugPrint('❌ No hay lotes disponibles en headquartersSelectedList');
        }
      }

      // 6. Obtener fecha y hora actual
      final now = DateTime.now();
      _model.dateHour = now;

      // 7. Generar string de datos a escribir
      _model.dataToWrite = _generateNfcData(now);

      setState(() {
        _model.isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _model.isCalculating = false;
        _model.errorMessage = 'Error al calcular datos: $e';
      });
      debugPrint('❌ Error en _calculateData: $e');
    }
  }

  String _generateNfcData(DateTime dateTime) {
    // Formato: {DH:2025_11_06_13:20:00;OP:4214;OP2:5432;VISITS:50;RESULTS:25;HE:204}
    // OP = operID del operador principal (ID del usuario)
    // OP2 = IdActivityStatus del cortero (ID único en Activities_status)
    final formattedDate =
        '${dateTime.year}_${dateTime.month.toString().padLeft(2, '0')}_${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

    // Validar que el operatorId no esté vacío
    final operatorIdValue = _model.operatorId.isEmpty 
        ? FFAppState().userSelected.operID 
        : _model.operatorId;
    
    if (operatorIdValue.isEmpty) {
      debugPrint('❌ ERROR: OP field es vacío. No se puede escribir el tag.');
      throw Exception('No se pudo obtener el ID del operador. Por favor seleccione un operador.');
    }
    
    debugPrint('✅ NFC TAG: OP field = $operatorIdValue');

    // Usar el ID del cortero (IdActivityStatus) - si está vacío o es "false", no incluirlo
    final operator2Value =
        (_model.operator2Id == 'false' || _model.operator2Id.isEmpty)
            ? ''
            : _model.operator2Id;

    // Incluir OP2 (Cortero ID) en el formato del tag
    return '{DH:$formattedDate;OP:$operatorIdValue;OP2:$operator2Value;VISITS:${_model.totalVisits};RESULTS:${_model.totalResults};HE:${_model.headquarterId}}';
  }

  /// Cuenta visitas desde la base de datos SQLite agrupadas por Lote (Id_headquarter)
  /// Solo cuenta visitas con Status=0 (pendientes de escribir en TAG)
  /// Retorna un Map con 'visits' (conteo total) y 'results' (suma total de factors)
  /// También pobla _model.visitsByHeadquarter con los datos discriminados por lote
  Future<Map<String, int>> _countVisitsFromDatabase(bool filterByStatus) async {
    try {
      final dbPath = FFAppState().pathDatabase;
      if (dbPath.isEmpty) {
        debugPrint('⚠️ No hay ruta de base de datos disponible');
        return {'visits': 0, 'results': 0};
      }

      final db = await openDatabase(dbPath);

      // IMPORTANTE: Solo contar visitas con Status = 0 (pendientes de escribir en tag)
      // Status = 0 = visitas que AÚN NO han sido procesadas/escritas en TAG
      // Status = 1 = visitas que YA fueron procesadas/escritas en TAG

      // Obtener visitas pendientes agrupadas por Id_headquarter
      final visitsGrouped = await db.rawQuery('''
        SELECT
          v.Id_headquarter,
          h.Name_headquarter,
          COUNT(*) as visit_count
        FROM Visits v
        LEFT JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
        WHERE v.Status = 0
        GROUP BY v.Id_headquarter
        ORDER BY v.Id_headquarter
      ''');

      debugPrint('📊 Lotes con visitas pendientes: ${visitsGrouped.length}');

      int totalVisits = 0;
      int totalResults = 0;
      List<HeadquarterVisitData> visitsByHq = [];

      // Obtener lista de headquarters del AppState para buscar nombres
      final headquartersList = FFAppState().headquartersSelectedList;

      for (var hqGroup in visitsGrouped) {
        final hqId = hqGroup['Id_headquarter'] as int;
        final hqNameFromDb = hqGroup['Name_headquarter'];
        final visitCount = hqGroup['visit_count'] as int;

        // Buscar el nombre del lote: primero en DB, luego en AppState, finalmente fallback
        String hqName;
        if (hqNameFromDb != null && hqNameFromDb.toString().isNotEmpty) {
          hqName = hqNameFromDb.toString();
        } else {
          // Buscar en headquartersSelectedList del AppState
          final hqFromAppState = headquartersList.firstWhere(
            (hq) => hq.idHeadquarter == hqId,
            orElse: () => HeadquartersStruct(),
          );
          if (hqFromAppState.nameHeadquarter.isNotEmpty) {
            hqName = hqFromAppState.nameHeadquarter;
          } else {
            hqName = hqId == 0 ? 'Sin lote asignado' : 'Lote #$hqId';
          }
        }

        debugPrint('🏢 Lote $hqId ($hqName): $visitCount visitas');

        // Calcular results para este lote
        int hqResults = 0;

        // Obtener las visitas de este lote
        final visitsResult = await db.rawQuery(
          'SELECT Id_visit FROM Visits WHERE Status = 0 AND Id_headquarter = ?',
          [hqId],
        );

        for (var visit in visitsResult) {
          final idVisit = visit['Id_visit'] as int;

          // DEBUG: Ver TODOS los detalles de la visita para entender qué se está guardando
          final allDetails = await db.rawQuery('''
            SELECT
              ast.Factor,
              ast.Type_status,
              ast.Status_name
            FROM Visits_details vd
            INNER JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
            WHERE vd.Id_visit = ?
          ''', [idVisit]);

          debugPrint(
              '   📝 Visita $idVisit tiene ${allDetails.length} detalles:');
          for (var d in allDetails) {
            debugPrint(
                '      - "${d['Status_name']}" tipo=${d['Type_status']} factor=${d['Factor']}');
          }

          // Solo sumar factores de tipo 'unique-option' con Factor > 0
          // Esto incluye: "1 Racimo", "2 Racimos", etc.
          // Excluye: "No hay racimos" (factor=0), "Despachar Fruta" (tag-writer)
          final detailsResult = await db.rawQuery('''
            SELECT
              ast.Factor,
              ast.Type_status,
              ast.Status_name
            FROM Visits_details vd
            INNER JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
            WHERE vd.Id_visit = ?
              AND ast.Type_status = 'unique-option'
              AND ast.Factor IS NOT NULL
              AND ast.Factor > 0
          ''', [idVisit]);

          for (var detail in detailsResult) {
            final factor = detail['Factor'];
            final factorValue = (factor is int)
                ? factor
                : (factor is double ? factor.toInt() : 0);
            hqResults += factorValue;
            debugPrint(
                '      ✅ SUMANDO Factor: $factorValue de "${detail['Status_name']}"');
          }
        }

        debugPrint('   📈 Results del lote $hqId: $hqResults');

        totalVisits += visitCount;
        totalResults += hqResults;

        visitsByHq.add(HeadquarterVisitData(
          headquarterId: hqId,
          headquarterName: hqName,
          visits: visitCount,
          results: hqResults,
        ));
      }

      // Guardar los datos agrupados en el modelo
      _model.visitsByHeadquarter = visitsByHq;

      debugPrint('═══════════════════════════════════════');
      debugPrint('📊 TOTAL VISITAS: $totalVisits');
      debugPrint('📊 TOTAL RESULTS: $totalResults');
      debugPrint('📊 LOTES: ${visitsByHq.length}');
      debugPrint('═══════════════════════════════════════');

      await db.close();

      return {
        'visits': totalVisits,
        'results': totalResults,
      };
    } catch (e) {
      debugPrint('❌ Error contando visitas desde SQLite: $e');
      return {'visits': 0, 'results': 0};
    }
  }

  /// Actualiza el campo Status de las visitas en SQLite después de escribir exitosamente
  /// También actualiza el Id_headquarter con el [headquarterId] del tag actual
  Future<void> _updateVisitsStatus() async {
    try {
      debugPrint(
          '✅ Actualizando Status de visitas después de escritura exitosa');

      // Actualizar el campo Status de TODAS las visitas a true (1)
      final dbPath = FFAppState().pathDatabase;
      if (dbPath.isEmpty) {
        debugPrint('⚠️ No hay ruta de base de datos disponible');
        return;
      }

      final db = await openDatabase(dbPath);

      // Actualizar Status=1 Y TAMBIÉN Id_headquarter para corregir visitas con lote 0
      // Usamos _model.headquarterId que es el lote que se acaba de escribir en el tag
      final headquarterId = _model.headquarterId;

      debugPrint(
          '🔄 Actualizando visitas pendientes: Status=1, Id_headquarter=$headquarterId');

      final rowsUpdated = await db.rawUpdate('''
        UPDATE Visits 
        SET Status = 1, Id_headquarter = ? 
        WHERE Status = 0
      ''', [headquarterId]);

      debugPrint(
          '✅ Actualizadas $rowsUpdated visitas con Status=1 y Lote=$headquarterId');

      await db.close();
    } catch (e) {
      debugPrint('❌ Error actualizando Status de visitas: $e');
    }
  }

  Future<void> _startWriting() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _model.isWriting = true;
      _model.isSuccess = false;
      _model.errorMessage = null;
    });

    // Iniciar polling para detectar cambios en el estado de NFC
    _startNfcStatePolling();

    try {
      // Escribir el tag NFC primero (con los datos calculados de visitas Status=0)
      final success = await actions.writeNFCTag(
        context,
        _model.dataToWrite,
      );

      if (success) {
        // DESPUÉS de escribir exitosamente, actualizar el campo Status de las visitas
        await _updateVisitsStatus();

        setState(() {
          _model.isSuccess = true;
          _model.isWriting = false;
        });
        HapticFeedback.heavyImpact();

        // Esperar un momento y cerrar
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Verificar si el error es por espacio insuficiente
        final nfcReadState = FFAppState().nfcRead;

        // Si se solicita otro tag, NO es un error - mantener el estado de escritura
        if (nfcReadState == 'SOLICITAR_OTRO_TAG') {
          debugPrint('⏳ Esperando que el usuario acerque otro tag...');
          // Mantener isWriting = true para que siga mostrando la pantalla de escritura
          // El usuario verá el mensaje especial en _buildWritingState()
          return;
        }

        if (nfcReadState.startsWith('ERROR:ESPACIO_INSUFICIENTE:')) {
          // Extraer información del error
          final parts = nfcReadState.split(':');
          if (parts.length >= 3) {
            final bytesInfo = parts[2]; // "requiredBytes/maxCapacity"
            throw Exception(
                'Espacio insuficiente en el TAG.\nSe requieren $bytesInfo bytes.\n\nUtilice otro TAG para continuar.');
          }
          throw Exception('Espacio insuficiente, utilice otro TAG');
        }

        if (nfcReadState == 'ERROR:TAG_ALEJADO') {
          throw Exception(
              'El TAG se alejó demasiado rápido.\n\nPor favor, mantenga el TAG cerca del dispositivo durante al menos 2 segundos mientras se completa la escritura.');
        }

        if (nfcReadState == 'ERROR:TAG_PROTEGIDO') {
          throw Exception(
              'El TAG está protegido contra escritura.\n\nUtilice otro TAG que permita escritura.');
        }

        if (nfcReadState == 'ERROR:ESCRITURA_FALLIDA') {
          throw Exception(
              'Error al escribir en el TAG.\n\nIntente de nuevo o utilice otro TAG.');
        }

        throw Exception('No se pudo escribir el tag');
      }
    } catch (e) {
      setState(() {
        _model.isWriting = false;
        _model.errorMessage = e.toString();
      });
      HapticFeedback.vibrate();
    }
  }

  // Polling para detectar cambios en el estado de NFC
  void _startNfcStatePolling() {
    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: 300));

      if (!mounted || !_model.isWriting) {
        return false; // Detener el polling
      }

      final nfcReadState = FFAppState().nfcRead;

      // Actualizar UI cuando cambia el estado
      if (nfcReadState == 'SOLICITAR_OTRO_TAG' ||
          nfcReadState.startsWith('ERROR:') ||
          !nfcReadState.isEmpty && nfcReadState != 'SOLICITAR_OTRO_TAG') {
        setState(() {}); // Forzar rebuild
      }

      return _model.isWriting; // Continuar mientras isWriting sea true
    });
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
                          'ESCRIBIR TAG NFC',
                          style: TextStyle(
                            fontFamily: 'Roboto',
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
                              Colors.orange,
                              Colors.orange.withOpacity(0.7),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ESCRITURA',
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
              child: _model.isCalculating
                  ? _buildCalculatingState()
                  : _model.isWriting
                      ? _buildWritingState()
                      : _model.isSuccess
                          ? _buildSuccessState()
                          : _model.errorMessage != null
                              ? _buildErrorState()
                              : _buildPreviewState(),
            ),

            // Botón de acción
            if (!_model.isCalculating &&
                !_model.isWriting &&
                !_model.isSuccess &&
                _model.errorMessage == null)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: InkWell(
                  onTap: _startWriting,
                  child: Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
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
                          'Iniciar Escritura',
                          style: TextStyle(
                            fontFamily: 'Roboto',
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

  Widget _buildCalculatingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00a86b)),
          ),
          SizedBox(height: 20),
          Text(
            'Calculando datos...',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Icono compacto
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.edit, color: Colors.white, size: 28),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listo para escribir',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_model.totalVisits} visitas · ${_model.totalResults} resultados',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.orange.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Preview de datos con scroll
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATOS A ESCRIBIR',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildDataRow(
                        'Fecha/Hora', _formatDateTime(_model.dateHour)),
                    _buildDataRow(
                        'Operador',
                        _model.operatorName.isNotEmpty
                            ? _model.operatorName
                            : _model.operatorId),
                    if (_model.operator2Id.isNotEmpty)
                      _buildDataRow(
                          'Cortero',
                          _model.operator2Name.isNotEmpty
                              ? _model.operator2Name
                              : _model.operator2Id),
                    // Mostrar visitas y resultados discriminados por lote
                    if (_model.visitsByHeadquarter.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DETALLE POR LOTE',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.4),
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 6),
                            ..._model.visitsByHeadquarter
                                .map((hqData) => _buildHeadquarterRow(hqData))
                                .toList(),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Divider(color: Colors.white.withOpacity(0.15), height: 1),
                      SizedBox(height: 10),
                    ],
                    _buildDataRow(
                        'Total Visitas', _model.totalVisits.toString()),
                    _buildDataRow(
                        'Total Resultados', _model.totalResults.toString()),
                    _buildDataRow('Lote Destino',
                        '${_model.headquarterName} (#${_model.headquarterId})'),
                    SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.15)),
                    SizedBox(height: 12),
                    Text(
                      'FORMATO TAG:',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFF00a86b).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Color(0xFF00a86b).withOpacity(0.3)),
                      ),
                      child: Text(
                        _model.dataToWrite,
                        style: TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 10,
                          color: Color(0xFF00a86b),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para mostrar fila de datos de un lote específico
  Widget _buildHeadquarterRow(HeadquarterVisitData hqData) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Icono y nombre del lote
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hqData.headquarterName,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Visitas
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'V:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '${hqData.visits}',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // Resultados
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'R:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '${hqData.results}',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritingState() {
    // Verificar si se está solicitando otro tag
    final nfcReadState = FFAppState().nfcRead;
    final bool needsAnotherTag = nfcReadState == 'SOLICITAR_OTRO_TAG';

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
                  colors: needsAnotherTag
                      ? [Colors.amber, Colors.orange]
                      : [Colors.orange, Colors.deepOrange],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nfc, color: Colors.white, size: 60),
            ),
          ),
          SizedBox(height: 30),
          Text(
            needsAnotherTag
                ? '⚠️ Acerque OTRO tag'
                : 'Acerque el tag para escribir',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            needsAnotherTag
                ? 'El contenido no cabe en el tag actual.\n\nEl contenido existente se conservará.\n\nAcerque un NUEVO tag para escribir.'
                : 'Mantenga el dispositivo cerca del tag NFC',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          if (needsAnotherTag) ...[
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Esperando nuevo tag...',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            '¡Tag Escrito Exitosamente!',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
            style: TextStyle(
              fontFamily: 'Roboto',
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
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: 32),
          // Botones de acción
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Botón Cancelar
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF374151),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Botón Reintentar
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Limpiar el error y reiniciar la escritura
                      setState(() {
                        _model.errorMessage = null;
                        _model.isWriting = false;
                      });
                      _startWriting();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.refresh, size: 20),
                    label: Text(
                      'Reintentar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    // Nombres de días en español
    const diasSemana = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];

    // Nombres de meses en español
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];

    final diaSemana = diasSemana[dateTime.weekday - 1];
    final mes = meses[dateTime.month - 1];
    final dia = dateTime.day;
    final anio = dateTime.year;

    // Formato 12 horas con am/pm
    final hora12 = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minuto = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'pm' : 'am';

    return '$diaSemana $dia de $mes $anio - $hora12:$minuto $amPm';
  }
}
