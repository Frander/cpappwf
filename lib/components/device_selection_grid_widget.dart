import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/custom_code/actions/index.dart' as actions;
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

    // Cargar dispositivos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _model.isLoading = true;
    });

    try {
      _model.apiResultDevices =
          await APIClickPalmGroup.devicesFiltersGETCall.call(
        typeSearch: 'ID COMPANY',
        textSearch1: widget.idCompany.toString(),
        textSearch2: widget.idCompany.toString(),
        idCompany: widget.idCompany,
        daysToProcess: 0,
      );

      if ((_model.apiResultDevices?.succeeded ?? false)) {
        setState(() {
          _model.devicesList = getJsonField(
            (_model.apiResultDevices?.jsonBody ?? ''),
            r'''$''',
            true,
          )!
              .toList();
          _model.filteredDevicesList = List.from(_model.devicesList);
          _model.isLoading = false;
        });
      } else {
        setState(() {
          _model.isLoading = false;
        });
        _showError('No se pudieron cargar los dispositivos');
      }
    } catch (e) {
      setState(() {
        _model.isLoading = false;
      });
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
      // Convertir el JSON a DevicesStruct
      final device = DevicesStruct(
        idDevice: deviceId,
        idCompany: deviceJson['id_company'] ?? 0,
        deviceName: deviceJson['device_name'] ?? '',
        cellPhone: deviceJson['cellPhone'] ?? '',
        serialId: deviceJson['serial_id'] ?? '',
        imeI1: deviceJson['imeI1'] ?? '',
        imeI2: deviceJson['imeI2'] ?? '',
        model: deviceJson['model'] ?? '',
        state: deviceJson['state'] ?? '',
      );

      // Persistir el ID del dispositivo en el archivo
      await _persistDeviceId(device.idDevice);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dispositivo "${device.deviceName}" seleccionado',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: FlutterFlowTheme.of(context).success,
          duration: Duration(seconds: 2),
        ),
      );

      // Llamar al callback
      await widget.onDeviceSelected(device);
    } catch (e) {
      debugPrint('❌ Error al seleccionar dispositivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar dispositivo'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      // Ocultar indicador de carga
      if (mounted) {
        setState(() {
          _model.selectingDeviceId = null;
        });
      }
    }
  }

  Future<void> _persistDeviceId(int deviceId) async {
    try {
      // Guardar el ID del dispositivo en persistent_id.txt
      await actions.savePersistentId(
        context,
        deviceId.toString(),
      );
      debugPrint('✅ ID de dispositivo $deviceId persistido correctamente');
    } catch (e) {
      debugPrint('❌ Error al persistir ID de dispositivo: $e');
    }
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
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 8.0),
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
                            Text(
                              'Seleccionar Dispositivo CTR',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Elige tu dispositivo de la lista',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
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
                                  .withOpacity(0.4),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.devices,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 14),

                  // Campo de búsqueda
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
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
                        hintText: 'Buscar por nombre, serial, IMEI o modelo...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white.withOpacity(0.7),
                          size: 24,
                        ),
                        suffixIcon: _model.textController!.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
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
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Contador de resultados
                  Text(
                    '${_model.filteredDevicesList.length} dispositivo${_model.filteredDevicesList.length != 1 ? 's' : ''} encontrado${_model.filteredDevicesList.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
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
                          SizedBox(height: 12),
                          Text(
                            'Cargando dispositivos...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
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

            // Botón agregar nuevo dispositivo
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 12.0),
              child: InkWell(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await widget.onAddNewDevice();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FlutterFlowTheme.of(context).warning,
                        FlutterFlowTheme.of(context).warning.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .warning
                            .withOpacity(0.4),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'NO ENCUENTRO MI DISPOSITIVO - AGREGA UNO NUEVO',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
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
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        padding: EdgeInsets.only(bottom: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.68, // Más espacio vertical para el contenido
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
    final deviceName = device['device_name'] ?? 'Sin nombre';
    final serialId = device['serial_id'] ?? 'N/A';
    final model = device['model'] ?? 'N/A';
    final imei1 = device['imeI1'] ?? '';
    final state = device['state'] ?? 'Desconocido';

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
                FlutterFlowTheme.of(context).primary.withOpacity(0.15),
                FlutterFlowTheme.of(context).secondary.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: FlutterFlowTheme.of(context).primary.withOpacity(0.2),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono y estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primary,
                            FlutterFlowTheme.of(context).secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_android,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? FlutterFlowTheme.of(context).success
                            : FlutterFlowTheme.of(context).error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Información del dispositivo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        deviceName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      _buildInfoRow(Icons.tag, 'Serial:', serialId),
                      SizedBox(height: 4),
                      _buildInfoRow(Icons.smartphone, 'Modelo:', model),
                      if (imei1.isNotEmpty) ...[
                        SizedBox(height: 4),
                        _buildInfoRow(Icons.numbers, 'IMEI:', imei1,
                            maxLength: 15),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Botón de selección
                Container(
                  width: double.infinity,
                  height: 36,
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
                              color: FlutterFlowTheme.of(context).primary.withOpacity(0.6),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _model.selectingDeviceId == device['id_device']
                        ? Row(
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
                              SizedBox(width: 8),
                              Text(
                                'SELECCIONANDO...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Text(
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
      displayValue = value.substring(0, maxLength) + '...';
    }

    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.6),
          size: 12,
        ),
        SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
                  FlutterFlowTheme.of(context).primary.withOpacity(0.3),
                  FlutterFlowTheme.of(context).secondary.withOpacity(0.3),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              color: Colors.white.withOpacity(0.7),
              size: 48,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No se encontraron dispositivos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Intenta con otro término de búsqueda o agrega un nuevo dispositivo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
