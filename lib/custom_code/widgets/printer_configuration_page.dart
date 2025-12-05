// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
// WIDGET - CONFIGURACIÓN DE IMPRESORAS BLUETOOTH
// ============================================================================

class PrinterConfigurationPage extends StatefulWidget {
  const PrinterConfigurationPage({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<PrinterConfigurationPage> createState() =>
      _PrinterConfigurationPageState();
}

class _PrinterConfigurationPageState extends State<PrinterConfigurationPage>
    with TickerProviderStateMixin {
  // Estado de Bluetooth
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  bool _isScanning = false;

  // Lista de dispositivos
  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDiscoveryResult> _discoveredDevices = [];

  // Dispositivo seleccionado actualmente
  String? _selectedPrinterAddress;
  String? _selectedPrinterName;

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Subscripciones
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initBluetooth();
    _loadSavedPrinter();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _discoverySubscription?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initBluetooth() async {
    try {
      // Obtener estado actual de Bluetooth
      BluetoothState state = await FlutterBluetoothSerial.instance.state;

      if (mounted) {
        setState(() {
          _bluetoothState = state;
        });
      }

      // Escuchar cambios en el estado de Bluetooth
      FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
        if (mounted) {
          setState(() {
            _bluetoothState = state;
          });
        }
      });

      // Si el Bluetooth está encendido, cargar dispositivos emparejados
      if (state.isEnabled) {
        await _loadPairedDevices();
      }
    } catch (e) {
      debugPrint('❌ Error inicializando Bluetooth: $e');
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      // Solicitar permisos antes de obtener dispositivos emparejados
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
      ].request();

      debugPrint('📋 Permiso BLUETOOTH_CONNECT: ${statuses[Permission.bluetoothConnect]}');

      if (statuses[Permission.bluetoothConnect]?.isGranted != true) {
        debugPrint('⚠️ Permiso BLUETOOTH_CONNECT no concedido, intentando sin permiso...');
      }

      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      if (mounted) {
        setState(() {
          _pairedDevices = devices;
        });
      }

      debugPrint('✅ Dispositivos emparejados cargados: ${devices.length}');
      for (var device in devices) {
        debugPrint('   📱 ${device.name ?? 'Sin nombre'} (${device.address})');
      }
    } catch (e) {
      debugPrint('❌ Error cargando dispositivos emparejados: $e');
      _showErrorSnackBar('Error al cargar dispositivos emparejados: ${e.toString()}');
    }
  }

  Future<void> _loadSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('printer_address');
      final savedName = prefs.getString('printer_name');

      if (mounted && savedAddress != null) {
        setState(() {
          _selectedPrinterAddress = savedAddress;
          _selectedPrinterName = savedName ?? 'Impresora';
        });

        // Actualizar también en AppState
        FFAppState().printerMacAddress = savedAddress;
        FFAppState().printerName = savedName ?? 'Impresora';

        debugPrint('✅ Impresora guardada cargada: $savedName ($savedAddress)');
      }
    } catch (e) {
      debugPrint('❌ Error cargando impresora guardada: $e');
    }
  }

  Future<void> _savePrinter(String address, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_address', address);
      await prefs.setString('printer_name', name);

      // Actualizar AppState
      FFAppState().printerMacAddress = address;
      FFAppState().printerName = name;

      if (mounted) {
        setState(() {
          _selectedPrinterAddress = address;
          _selectedPrinterName = name;
        });
      }

      _showSuccessSnackBar('Impresora "$name" configurada correctamente');
      debugPrint('✅ Impresora guardada: $name ($address)');
    } catch (e) {
      debugPrint('❌ Error guardando impresora: $e');
      _showErrorSnackBar('Error al guardar la configuración');
    }
  }

  Future<void> _removeSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('printer_address');
      await prefs.remove('printer_name');

      // Limpiar AppState
      FFAppState().printerMacAddress = '';
      FFAppState().printerName = '';

      if (mounted) {
        setState(() {
          _selectedPrinterAddress = null;
          _selectedPrinterName = null;
        });
      }

      _showSuccessSnackBar('Impresora desconectada');
      debugPrint('✅ Impresora eliminada de la configuración');
    } catch (e) {
      debugPrint('❌ Error eliminando impresora: $e');
      _showErrorSnackBar('Error al eliminar la configuración');
    }
  }

  Future<void> _startDiscovery() async {
    if (_isScanning) return;

    try {
      // Solicitar permisos de Bluetooth para Android 12+
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location, // Necesario para escaneo Bluetooth en Android
      ].request();

      debugPrint('📋 Permisos solicitados:');
      debugPrint('   BLUETOOTH_SCAN: ${statuses[Permission.bluetoothScan]}');
      debugPrint('   BLUETOOTH_CONNECT: ${statuses[Permission.bluetoothConnect]}');
      debugPrint('   LOCATION: ${statuses[Permission.location]}');

      // Verificar si los permisos fueron concedidos
      if (statuses[Permission.bluetoothScan]?.isDenied == true ||
          statuses[Permission.bluetoothConnect]?.isDenied == true ||
          statuses[Permission.location]?.isDenied == true) {
        _showErrorSnackBar(
            'Se requieren permisos de Bluetooth y ubicación para escanear dispositivos');
        return;
      }

      // Si los permisos fueron denegados permanentemente, abrir configuración
      if (statuses[Permission.bluetoothScan]?.isPermanentlyDenied == true ||
          statuses[Permission.bluetoothConnect]?.isPermanentlyDenied == true ||
          statuses[Permission.location]?.isPermanentlyDenied == true) {
        _showPermissionDialog();
        return;
      }

      setState(() {
        _isScanning = true;
        _discoveredDevices.clear();
      });

      _discoverySubscription?.cancel();
      _discoverySubscription =
          FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) {
          if (mounted) {
            setState(() {
              // Agregar solo si no está ya en la lista
              final existingIndex = _discoveredDevices
                  .indexWhere((d) => d.device.address == result.device.address);
              if (existingIndex == -1) {
                _discoveredDevices.add(result);
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
          debugPrint('✅ Escaneo completado');
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
          debugPrint('❌ Error en escaneo: $error');
          _showErrorSnackBar('Error al escanear dispositivos');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      debugPrint('❌ Error iniciando escaneo: $e');
      _showErrorSnackBar('Error al iniciar escaneo: ${e.toString()}');
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _discoverySubscription?.cancel();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      debugPrint('✅ Escaneo detenido');
    } catch (e) {
      debugPrint('❌ Error deteniendo escaneo: $e');
    }
  }

  Future<void> _requestBluetoothEnable() async {
    try {
      await FlutterBluetoothSerial.instance.requestEnable();
    } catch (e) {
      debugPrint('❌ Error habilitando Bluetooth: $e');
      _showErrorSnackBar('Error al habilitar Bluetooth');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF52B788),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B4332),
        title: const Text(
          'Permisos Requeridos',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Para escanear dispositivos Bluetooth, necesitas activar los permisos de Bluetooth y ubicación en la configuración de la aplicación.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Abre la configuración de la app
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081C15),
      body: Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B4332), // Verde oscuro
              Color(0xFF081C15), // Verde muy oscuro
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _bluetoothState.isEnabled
                    ? _buildPrinterList()
                    : _buildBluetoothDisabled(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4332), // Verde oscuro
            Color(0xFF2D6A4F), // Verde medio
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), // Púrpura
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.print,
              color: Color(0xFF8B5CF6), // Púrpura
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración de Impresoras',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Impresoras térmicas Bluetooth',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Botón de cerrar
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cerrar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothDisabled() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    const Color(0xFFFF8C42).withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                color: Color(0xFFFF6B35),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth Desactivado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Para conectar una impresora, primero debes activar el Bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B5CF6), // Púrpura
                    Color(0xFF7C3AED),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _requestBluetoothEnable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Activar Bluetooth',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Impresora actualmente configurada
          if (_selectedPrinterAddress != null) ...[
            _buildCurrentPrinterCard(),
            const SizedBox(height: 24),
          ],

          // Dispositivos emparejados
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF52B788).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.devices,
                  color: Color(0xFF52B788),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dispositivos Emparejados',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_pairedDevices.isEmpty)
            _buildEmptyCard('No hay dispositivos emparejados'),
          if (_pairedDevices.isNotEmpty)
            ..._pairedDevices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDeviceCard(
                    name: device.name ?? 'Dispositivo desconocido',
                    address: device.address,
                    isPaired: true,
                    isSelected: device.address == _selectedPrinterAddress,
                  ),
                )),

          const SizedBox(height: 24),

          // Buscar nuevos dispositivos
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Buscar Nuevos Dispositivos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isScanning)
                ElevatedButton.icon(
                  onPressed: _startDiscovery,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _stopDiscovery,
                  icon: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  label: const Text('Detener'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isScanning && _discoveredDevices.isEmpty)
            _buildScanningCard(),
          if (_discoveredDevices.isNotEmpty)
            ..._discoveredDevices.map((result) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDeviceCard(
                    name:
                        result.device.name ?? 'Dispositivo desconocido',
                    address: result.device.address,
                    isPaired: result.device.isBonded,
                    isSelected:
                        result.device.address == _selectedPrinterAddress,
                    rssi: result.rssi,
                  ),
                )),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCurrentPrinterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF52B788).withValues(alpha: 0.4),
            const Color(0xFF40916C).withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF52B788).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF52B788),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impresora Configurada',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedPrinterName ?? 'Impresora',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  // Confirmar antes de eliminar
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1B4332),
                      title: const Text(
                        'Desconectar Impresora',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        '¿Deseas desconectar la impresora actual?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _removeSavedPrinter();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                          ),
                          child: const Text('Desconectar'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Desconectar impresora',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPrinterAddress ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
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

  Widget _buildDeviceCard({
    required String name,
    required String address,
    required bool isPaired,
    required bool isSelected,
    int? rssi,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D6A4F).withValues(alpha: 0.3),
            const Color(0xFF1B4332).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF52B788).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _savePrinter(address, name);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isSelected
                            ? const Color(0xFF52B788)
                            : const Color(0xFF8B5CF6))
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.print,
                    color: isSelected
                        ? const Color(0xFF52B788)
                        : const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (rssi != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.signal_cellular_alt,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Señal: $rssi dBm',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPaired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF52B788).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Emparejado',
                      style: TextStyle(
                        color: Color(0xFF52B788),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildScanningCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            const Color(0xFF7C3AED).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Buscando dispositivos Bluetooth...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
