import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:shared_preferences/shared_preferences.dart';
import 'device_selection_grid_model.dart';
export 'device_selection_grid_model.dart';

class DeviceSelectionGridWidget extends StatefulWidget {
  const DeviceSelectionGridWidget({
    super.key,
    required this.idCompany,
    required this.onDeviceSelected,
    required this.onAddNewDevice,
  });

  final int idCompany;
  final Future Function(DevicesStruct device) onDeviceSelected;
  final Future Function() onAddNewDevice;

  @override
  State<DeviceSelectionGridWidget> createState() =>
      _DeviceSelectionGridWidgetState();
}

class _DeviceSelectionGridWidgetState
    extends State<DeviceSelectionGridWidget> {
  late DeviceSelectionGridModel _model;
  bool _hideAddDevice = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DeviceSelectionGridModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    _checkAdbInstall();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Evitar que el teclado aparezca automáticamente al abrir el diálogo.
      // Flutter a veces enfoca el primer TextField visible al mostrarse un Dialog.
      if (mounted) FocusScope.of(context).unfocus();
      _loadDevices();
    });
  }

  Future<void> _checkAdbInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdb = prefs.getBool('clickpalm_adb_install') ?? false;
    if (isAdb && mounted) setState(() => _hideAddDevice = true);
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  /// Normaliza un mapa de dispositivo (de API o SQLite) a campos snake_case uniformes.
  Map<String, dynamic> _normalizeDevice(Map<String, dynamic> raw) {
    return {
      'id_device':   raw['Id_device']   ?? raw['id_device']   ?? 0,
      'id_company':  raw['Id_company']  ?? raw['id_company']  ?? 0,
      'device_name': raw['Device_name'] ?? raw['device_name'] ?? '',
      'cell_phone':  raw['Cell_phone']  ?? raw['cell_phone']  ?? raw['cellPhone'] ?? '',
      'serial_id':   raw['Serial_id']   ?? raw['serial_id']   ?? '',
      'imei1':       raw['Imei1']       ?? raw['imei1']       ?? raw['imeI1']     ?? '',
      'imei2':       raw['Imei2']       ?? raw['imei2']       ?? raw['imeI2']     ?? '',
      'model':       raw['Model']       ?? raw['model']       ?? '',
      'state':       raw['State']       ?? raw['state']       ?? '',
    };
  }

  Future<void> _loadDevices() async {
    setState(() => _model.isLoading = true);

    try {
      // ── 1. Intentar cargar desde SQLite ──────────────────────────────────
      List<Map<String, dynamic>> sqliteDevices = [];
      try {
        final db = await globalDb.database;
        final rows = await db.query(
          'Devices',
          where: 'Id_company = ?',
          whereArgs: [widget.idCompany],
          orderBy: 'Device_name ASC',
        );
        sqliteDevices = rows.map(_normalizeDevice).toList();
        debugPrint('📦 [CTR] SQLite: ${sqliteDevices.length} dispositivos para empresa ${widget.idCompany}');
      } catch (e) {
        debugPrint('⚠️ [CTR] SQLite no disponible: $e');
      }

      if (sqliteDevices.isNotEmpty) {
        // Usar datos de SQLite directamente
        setState(() {
          _model.devicesList = sqliteDevices;
          _model.filteredDevicesList = List.from(sqliteDevices);
          _model.isLoading = false;
        });
        return;
      }

      // ── 2. SQLite vacía → llamar API y cachear ────────────────────────────
      debugPrint('📡 [CTR] SQLite vacía, consultando API /Devices/filters...');
      _model.apiResultDevices =
          await APIClickPalmGroup.devicesFiltersGETCall.call(
        typeSearch: 'ID COMPANY',
        textSearch1: widget.idCompany.toString(),
        textSearch2: widget.idCompany.toString(),
        idCompany: widget.idCompany,
        daysToProcess: 0,
      );

      if (!(_model.apiResultDevices?.succeeded ?? false)) {
        setState(() => _model.isLoading = false);
        _showError('No se pudieron cargar los dispositivos');
        return;
      }

      final rawList = (getJsonField(
        _model.apiResultDevices?.jsonBody ?? '',
        r'''$''',
        true,
      ) as List?)?.cast<dynamic>() ?? [];

      // Cachear en SQLite para uso futuro
      try {
        final db = await globalDb.database;
        await db.transaction((txn) async {
          // Limpiar registros anteriores de esta empresa
          await txn.delete('Devices', where: 'Id_company = ?', whereArgs: [widget.idCompany]);
          final batch = txn.batch();
          for (final d in rawList) {
            final map = d as Map<String, dynamic>;
            batch.insert('Devices', {
              'Id_device':   map['id_device']  ?? 0,
              'Id_company':  map['id_company'] ?? widget.idCompany,
              'Device_name': map['device_name'] ?? '',
              'Cell_phone':  map['cellPhone'] ?? map['cell_phone'] ?? '',
              'Serial_id':   map['serial_id'] ?? '',
              'Imei1':       map['imeI1'] ?? map['imei1'] ?? '',
              'Imei2':       map['imeI2'] ?? map['imei2'] ?? '',
              'Model':       map['model'] ?? '',
              'State':       map['state'] ?? '',
              'Is_default':  0,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });
        debugPrint('✅ [CTR] ${rawList.length} dispositivos cacheados en SQLite');
      } catch (e) {
        debugPrint('⚠️ [CTR] No se pudo cachear en SQLite: $e');
      }

      // Normalizar y mostrar
      final normalized = rawList
          .cast<Map<String, dynamic>>()
          .map(_normalizeDevice)
          .toList();

      setState(() {
        _model.devicesList = normalized;
        _model.filteredDevicesList = List.from(normalized);
        _model.isLoading = false;
      });
    } catch (e) {
      setState(() => _model.isLoading = false);
      _showError('Error al cargar dispositivos: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlutterFlowTheme.of(context).error,
      ),
    );
  }

  Future<void> _selectDevice(dynamic deviceJson) async {
    HapticFeedback.mediumImpact();

    final deviceId = deviceJson['id_device'] ?? 0;

    // Mostrar indicador de carga
    setState(() {
      _model.selectingDeviceId = deviceId;
    });

    try {
      // Convertir el JSON a DevicesStruct (ya normalizado a snake_case)
      final device = DevicesStruct(
        idDevice: deviceId,
        idCompany: deviceJson['id_company'] ?? 0,
        deviceName: deviceJson['device_name'] ?? '',
        cellPhone: deviceJson['cell_phone'] ?? '',
        serialId: deviceJson['serial_id'] ?? '',
        imeI1: deviceJson['imei1'] ?? '',
        imeI2: deviceJson['imei2'] ?? '',
        model: deviceJson['model'] ?? '',
        state: deviceJson['state'] ?? '',
      );

      // Persistir el IMEI del dispositivo en el archivo (si está disponible)
      if (device.imeI1.isNotEmpty) {
        await _persistDeviceImei(device.imeI1);
        if (!mounted) return;
      }

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dispositivo "${device.deviceName}" seleccionado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: FlutterFlowTheme.of(context).success,
          duration: const Duration(seconds: 2),
        ),
      );

      // Llamar al callback
      await widget.onDeviceSelected(device);
    } catch (e) {
      debugPrint('❌ Error al seleccionar dispositivo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al seleccionar dispositivo'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      // Ocultar indicador de carga
      if (mounted) {
        setState(() {
          _model.selectingDeviceId = null;
        });
      }
    }
  }

  Future<void> _persistDeviceImei(String imei) async {
    try {
      // Guardar el IMEI del dispositivo en persistent_id.txt
      await actions.savePersistentId(
        context,
        imei,
      );
      debugPrint('✅ IMEI $imei persistido correctamente');
    } catch (e) {
      debugPrint('❌ Error al persistir IMEI del dispositivo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seleccionar Dispositivo CTR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Elige tu dispositivo de la lista',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context)
                                  .primary
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.devices,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Campo de búsqueda
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _model.textController,
                      focusNode: _model.textFieldFocusNode,
                      onChanged: (value) {
                        setState(() {
                          _model.filterDevices(value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, serial, IMEI...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                        ),
                        suffixIcon: _model.textController!.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _model.textController!.clear();
                                    _model.filterDevices('');
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Contador de resultados
                  Text(
                    '${_model.filteredDevicesList.length} dispositivo${_model.filteredDevicesList.length != 1 ? 's' : ''} encontrado${_model.filteredDevicesList.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de dispositivos
            Expanded(
              child: _model.isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cargando dispositivos...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _model.filteredDevicesList.isEmpty
                      ? _buildEmptyState()
                      : _buildDeviceGrid(),
            ),

            // Botón agregar nuevo dispositivo (oculto si instalación fue por ADB)
            if (!_hideAddDevice)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 12.0),
              child: InkWell(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await widget.onAddNewDevice();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FlutterFlowTheme.of(context).warning,
                        FlutterFlowTheme.of(context).warning.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'NO ENCUENTRO MI DISPOSITIVO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildDeviceGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85, // Tarjetas más compactas
        ),
        itemCount: _model.filteredDevicesList.length,
        itemBuilder: (context, index) {
          final device = _model.filteredDevicesList[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(dynamic device) {
    // Todos los campos ya normalizados a snake_case por _normalizeDevice()
    final deviceName = (device['device_name'] as String?) ?? 'Sin nombre';
    final serialId = (device['serial_id'] as String?) ?? '';
    final model = (device['model'] as String?) ?? '';
    final imei1 = (device['imei1'] as String?) ?? '';
    final cellPhone = (device['cell_phone'] as String?) ?? '';
    final state = (device['state'] as String?) ?? 'Desconocido';

    final isActive = state.toLowerCase() == 'activo' ||
        state.toLowerCase() == 'active';

    final isSelecting = _model.selectingDeviceId != null;
    final isThisDeviceSelecting = _model.selectingDeviceId == device['id_device'];

    return Opacity(
      opacity: isSelecting && !isThisDeviceSelecting ? 0.5 : 1.0,
      child: InkWell(
        onTap: _model.selectingDeviceId == null
            ? () => _selectDevice(device)
            : null, // Deshabilitar clic si ya se está seleccionando un dispositivo
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FlutterFlowTheme.of(context).primary.withValues(alpha: 0.15),
                FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre y estado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? FlutterFlowTheme.of(context).success
                            : FlutterFlowTheme.of(context).error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        state.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Información del dispositivo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (serialId.isNotEmpty) ...[
                        _buildInfoRow(Icons.tag, 'Serial:', serialId),
                        const SizedBox(height: 3),
                      ],
                      if (model.isNotEmpty) ...[
                        _buildInfoRow(Icons.smartphone, 'Modelo:', model),
                        const SizedBox(height: 3),
                      ],
                      if (cellPhone.isNotEmpty) ...[
                        _buildInfoRow(Icons.phone, 'Tel:', cellPhone),
                        const SizedBox(height: 3),
                      ],
                      if (imei1.isNotEmpty)
                        _buildInfoRow(Icons.numbers, 'IMEI:', imei1,
                            maxLength: 15),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Botón de selección
                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FlutterFlowTheme.of(context).primary,
                        FlutterFlowTheme.of(context).secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _model.selectingDeviceId == device['id_device']
                        ? [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.6),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _model.selectingDeviceId == device['id_device']
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'SELECCIONANDO...',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'SELECCIONAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ); // Cierre de Opacity
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {int? maxLength}) {
    String displayValue = value;
    if (maxLength != null && value.length > maxLength) {
      displayValue = '${value.substring(0, maxLength)}...';
    }

    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.6),
          size: 12,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: displayValue),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                  FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.3),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              color: Colors.white.withValues(alpha: 0.7),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No se encontraron dispositivos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Intenta con otro término de búsqueda o agrega un nuevo dispositivo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
