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

      // 4. Obtener ID operador desde AppState
      _model.operatorId = FFAppState().userSelected.operID;

      // 4.1 Buscar el operador Cortero (OP2) desde visitDetails
      // El Cortero viene de un status_name que contiene "cortero" (case insensitive)
      String operator2Id = '';
      for (var detail in FFAppState().visitDetails) {
        final statusOption = detail.statusOption.toLowerCase();
        if (statusOption.contains('cortero')) {
          operator2Id = detail.statusResponse;
          debugPrint('✅ Cortero encontrado: $operator2Id (status: ${detail.statusOption})');
          break;
        }
      }
      _model.operator2Id = operator2Id;

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
    final formattedDate =
        '${dateTime.year}_${dateTime.month.toString().padLeft(2, '0')}_${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

    // Incluir OP2 (Cortero) en el formato del tag
    return '{DH:$formattedDate;OP:${_model.operatorId};OP2:${_model.operator2Id};VISITS:${_model.totalVisits};RESULTS:${_model.totalResults};HE:${_model.headquarterId}}';
  }

  /// Cuenta visitas desde la base de datos SQLite
  /// Si [filterByStatus] es true, solo cuenta visitas con Status=0 (pendientes de sincronizar)
  /// Si [filterByStatus] es false, cuenta TODAS las visitas
  /// Retorna un Map con 'visits' (conteo) y 'results' (suma de factors)
  Future<Map<String, int>> _countVisitsFromDatabase(bool filterByStatus) async {
    try {
      final dbPath = FFAppState().pathDatabase;
      if (dbPath.isEmpty) {
        debugPrint('⚠️ No hay ruta de base de datos disponible');
        return {'visits': 0, 'results': 0};
      }

      final db = await openDatabase(dbPath);

      // IMPORTANTE: Solo contar visitas con Status = 0 (pendientes de escribir en tag)
      // Estas son las visitas que aún NO han sido escritas en un tag NFC

      // Contar visitas con Status = 0
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Visits WHERE Status = 0',
      );

      final visitCount = Sqflite.firstIntValue(countResult) ?? 0;
      debugPrint('📊 Visitas pendientes (Status=0) encontradas: $visitCount');

      // Obtener los IDs de las visitas con Status = 0 para calcular results
      final visitsResult = await db.rawQuery(
        'SELECT Id_visit FROM Visits WHERE Status = 0',
      );

      int totalResults = 0;

      debugPrint('🔍 Calculando RESULTS sumando Factores de cada Visit_details:');
      debugPrint('📋 Total de visitas a procesar: ${visitsResult.length}');

      // Para cada visita, obtener sus detalles y sumar el factor
      for (var visit in visitsResult) {
        final idVisit = visit['Id_visit'] as int;

        // Obtener los detalles de la visita con sus factores individuales
        final detailsResult = await db.rawQuery('''
          SELECT
            vd.Id_visit_detail,
            vd.Id_activity_status,
            ast.Factor,
            ast.Status_name
          FROM Visits_details vd
          INNER JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
          WHERE vd.Id_visit = ?
        ''', [idVisit]);

        debugPrint('  🔎 Visita Id_visit=$idVisit → ${detailsResult.length} detalles encontrados');

        if (detailsResult.isEmpty) {
          debugPrint('    ⚠️ Esta visita NO tiene Visits_details asociados');

          // Verificar si existen detalles sin el JOIN
          final checkDetails = await db.rawQuery('''
            SELECT COUNT(*) as count FROM Visits_details WHERE Id_visit = ?
          ''', [idVisit]);
          final detailCount = checkDetails.first['count'] as int;
          debugPrint('    ℹ️ Registros en Visits_details para esta visita: $detailCount');

          if (detailCount > 0) {
            // Hay detalles pero el JOIN falló, verificar los IDs
            final detailsCheck = await db.rawQuery('''
              SELECT Id_activity_status FROM Visits_details WHERE Id_visit = ?
            ''', [idVisit]);
            final activityStatusIds = detailsCheck.map((d) => d['Id_activity_status']).toList();
            debugPrint('    ℹ️ Id_activity_status en Visits_details: $activityStatusIds');

            // Verificar si esos IDs existen en Activities_status
            for (var id in activityStatusIds) {
              final statusCheck = await db.rawQuery('''
                SELECT Id_activity_status, Status_name, Factor
                FROM Activities_status
                WHERE Id_activity_status = ?
              ''', [id]);

              if (statusCheck.isEmpty) {
                debugPrint('    ❌ Id_activity_status=$id NO existe en Activities_status (dato huérfano!)');
              } else {
                final status = statusCheck.first;
                final factor = status['Factor'];
                final statusName = status['Status_name'];
                debugPrint('    ✅ Id_activity_status=$id SÍ existe: "$statusName", Factor=$factor');
              }
            }
          }
        } else {
          debugPrint('  📍 Visita Id_visit=$idVisit (${detailsResult.length} detalles):');

          int visitTotal = 0;
          for (var detail in detailsResult) {
            final factor = detail['Factor'];
            final statusName = detail['Status_name'];
            final factorValue = (factor is int) ? factor : (factor is double ? factor.toInt() : 0);

            visitTotal += factorValue;
            debugPrint('    ➕ Status: "$statusName", Factor: $factorValue');
          }

          totalResults += visitTotal;
          debugPrint('    ✅ Subtotal visita $idVisit: $visitTotal');
        }
      }

      debugPrint('═══════════════════════════════════════');
      debugPrint('📊 TOTAL RESULTS (suma de todos los Factores): $totalResults');
      debugPrint('═══════════════════════════════════════');

      await db.close();

      return {
        'visits': visitCount,
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
            style: TextStyle(fontFamily: 'Roboto',
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
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Icono
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.edit, color: Colors.white, size: 48),
            ),
          ),

          SizedBox(height: 30),

          // Preview de datos
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
                  'DATOS A ESCRIBIR',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                _buildDataRow('Fecha/Hora', _formatDateTime(_model.dateHour)),
                _buildDataRow('Operador', _model.operatorId),
                if (_model.operator2Id.isNotEmpty)
                  _buildDataRow('Cortero', _model.operator2Id),
                _buildDataRow('Visitas', _model.totalVisits.toString()),
                _buildDataRow('Resultados', _model.totalResults.toString()),
                _buildDataRow('Lote',
                    '${_model.headquarterName} (#${_model.headquarterId})'),
                SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2)),
                SizedBox(height: 16),
                Text(
                  'FORMATO TAG:',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _model.dataToWrite,
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 11,
                    color: Color(0xFF00a86b),
                  ),
                ),
              ],
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
            style: TextStyle(fontFamily: 'Roboto',
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
            style: TextStyle(fontFamily: 'Roboto',
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
                    style: TextStyle(fontFamily: 'Roboto',
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
            style: TextStyle(fontFamily: 'Roboto',
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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
