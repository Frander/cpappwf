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
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ============================================================================
// NOTA IMPORTANTE: BLUETOOTH
// ============================================================================
// Este widget usa flutter_blue_plus para la funcionalidad de Bluetooth.
// ============================================================================

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // Para MethodChannel
import 'package:share_plus/share_plus.dart'; // Para compartir archivos

// ============================================================================
// MODELOS DE DATOS
// ============================================================================

class FileItem {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modifiedDate;
  bool isSelected;

  FileItem({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedDate,
    this.isSelected = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(modifiedDate);
  }
}

enum FileCategory {
  csvExports,
  syncFiles,
}

enum SortOption {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  sizeAsc,
  sizeDesc,
}

// ============================================================================
// WIDGET PRINCIPAL - GESTOR DE ARCHIVOS DE BACKUP
// ============================================================================

class LoadBackupsForm extends StatefulWidget {
  const LoadBackupsForm({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<LoadBackupsForm> createState() => _LoadBackupsFormState();
}

class _LoadBackupsFormState extends State<LoadBackupsForm>
    with TickerProviderStateMixin {
  // Estado
  bool _isLoading = true;
  String _errorMessage = '';
  FileCategory _selectedCategory = FileCategory.csvExports;
  SortOption _sortOption = SortOption.dateNewest;

  // Listas de archivos
  List<FileItem> _csvFiles = [];
  List<FileItem> _syncFiles = [];

  // Bluetooth
  bool _isBluetoothEnabled = false;
  List<BluetoothDevice> _devicesList = [];
  bool _isScanning = false;
  bool _isSending = false;

  // Progreso de envío
  int _currentFileIndex = 0;
  int _totalFilesToSend = 0;
  String _currentFileName = '';
  double _currentFileProgress = 0.0;
  int _currentFileBytesTransferred = 0;
  int _currentFileTotalBytes = 0;
  String _transferSpeed = '';
  DateTime? _transferStartTime;

  // Animación
  late TabController _tabController;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressPulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _tabController.index == 0
              ? FileCategory.csvExports
              : FileCategory.syncFiles;
        });
      }
    });

    // Animación de progreso
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _progressPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadFiles();
    _checkBluetoothStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MÉTODOS DE CARGA DE ARCHIVOS
  // ==========================================================================

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      late Directory baseDir;
      if (Platform.isAndroid) {
        final Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
        baseDir = externalDir;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final String basePath = '${baseDir.path}/ClickPalmData';

      // Cargar archivos CSV
      final String csvPath = '$basePath/csv_exports';
      _csvFiles = await _loadFilesFromDirectory(csvPath);

      // Cargar archivos Sync
      final String syncPath = '$basePath/sync_files';
      _syncFiles = await _loadFilesFromDirectory(syncPath);

      _sortFiles();

      setState(() {
        _isLoading = false;
      });

      debugPrint('✅ Archivos cargados:');
      debugPrint('   - CSV: ${_csvFiles.length}');
      debugPrint('   - Sync: ${_syncFiles.length}');
    } catch (e) {
      debugPrint('❌ Error cargando archivos: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<FileItem>> _loadFilesFromDirectory(String directoryPath) async {
    final List<FileItem> files = [];

    try {
      final Directory dir = Directory(directoryPath);

      if (!await dir.exists()) {
        debugPrint('⚠️ Directorio no existe: $directoryPath');
        return files;
      }

      final List<FileSystemEntity> entities = dir.listSync();

      for (final entity in entities) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          files.add(FileItem(
            name: entity.path.split('/').last,
            path: entity.path,
            sizeBytes: stat.size,
            modifiedDate: stat.modified,
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Error leyendo directorio $directoryPath: $e');
    }

    return files;
  }

  void _sortFiles() {
    final sortFunction = _getSortFunction();
    _csvFiles.sort(sortFunction);
    _syncFiles.sort(sortFunction);
  }

  int Function(FileItem, FileItem) _getSortFunction() {
    switch (_sortOption) {
      case SortOption.nameAsc:
        return (a, b) => a.name.compareTo(b.name);
      case SortOption.nameDesc:
        return (a, b) => b.name.compareTo(a.name);
      case SortOption.dateNewest:
        return (a, b) => b.modifiedDate.compareTo(a.modifiedDate);
      case SortOption.dateOldest:
        return (a, b) => a.modifiedDate.compareTo(b.modifiedDate);
      case SortOption.sizeAsc:
        return (a, b) => a.sizeBytes.compareTo(b.sizeBytes);
      case SortOption.sizeDesc:
        return (a, b) => b.sizeBytes.compareTo(a.sizeBytes);
    }
  }

  // ==========================================================================
  // MÉTODOS DE SELECCIÓN
  // ==========================================================================

  List<FileItem> get _currentFiles {
    return _selectedCategory == FileCategory.csvExports
        ? _csvFiles
        : _syncFiles;
  }

  List<FileItem> get _selectedFiles {
    return _currentFiles.where((file) => file.isSelected).toList();
  }

  void _toggleSelection(FileItem file) {
    setState(() {
      file.isSelected = !file.isSelected;
    });
  }

  void _selectAll() {
    setState(() {
      for (var file in _currentFiles) {
        file.isSelected = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (var file in _currentFiles) {
        file.isSelected = false;
      }
    });
  }

  // ==========================================================================
  // MÉTODOS DE BLUETOOTH
  // ==========================================================================

  Future<void> _checkBluetoothStatus() async {
    if (Platform.isWindows) return; // Bluetooth no disponible en Windows
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      setState(() {
        _isBluetoothEnabled = adapterState == BluetoothAdapterState.on;
      });
    } catch (e) {
      debugPrint('❌ Error verificando Bluetooth: $e');
    }
  }

  Future<void> _enableBluetooth() async {
    try {
      // Solicitar permisos
      await _requestBluetoothPermissions();

      // Habilitar Bluetooth
      await FlutterBluePlus.turnOn();

      // Verificar estado después de solicitar
      final adapterState = await FlutterBluePlus.adapterState.first;
      setState(() {
        _isBluetoothEnabled = adapterState == BluetoothAdapterState.on;
      });

      if (_isBluetoothEnabled) {
        _showSnackBar('Bluetooth habilitado', isError: false);
      }
    } catch (e) {
      debugPrint('❌ Error habilitando Bluetooth: $e');
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    try {
      if (!Platform.isAndroid) return true;

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 31) {
        final result = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        return result[Permission.bluetoothScan]?.isGranted == true &&
            result[Permission.bluetoothConnect]?.isGranted == true;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  Future<void> _scanForDevices() async {
    if (!_isBluetoothEnabled) {
      _showSnackBar('Bluetooth deshabilitado', isError: true);
      return;
    }

    // Solicitar permisos de Bluetooth primero
    final hasPermissions = await _requestBluetoothPermissions();
    if (!hasPermissions) {
      _showSnackBar('Se requieren permisos de Bluetooth para continuar',
          isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
      _devicesList.clear();
    });

    try {
      // Obtener dispositivos emparejados (bonded) usando flutter_blue_plus
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      setState(() {
        _devicesList = bondedDevices;
        _isScanning = false;
      });

      debugPrint('✅ Dispositivos encontrados: ${_devicesList.length}');

      if (_devicesList.isEmpty) {
        _showSnackBar('No se encontraron dispositivos emparejados',
            isError: false);
      } else {
        _showDeviceSelectionDialog();
      }
    } catch (e) {
      debugPrint('❌ Error escaneando dispositivos: $e');
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('Error al escanear dispositivos. Verifica los permisos.',
          isError: true);
    }
  }

  Future<void> _sendFilesToDevice(BluetoothDevice device) async {
    final selectedFiles = _selectedFiles;

    if (selectedFiles.isEmpty) {
      _showSnackBar('No hay archivos seleccionados', isError: true);
      return;
    }

    setState(() {
      _isSending = true;
      _totalFilesToSend = selectedFiles.length;
      _currentFileIndex = 0;
      _transferStartTime = DateTime.now();
    });

    try {
      final deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
      debugPrint('📤 Iniciando envío de ${selectedFiles.length} archivos a $deviceName');
      debugPrint('📱 Dirección del dispositivo: ${device.remoteId.str}');

      // Mostrar diálogo de espera de aceptación
      final shouldContinue = await _showConnectionWaitingDialog(device);

      if (!shouldContinue) {
        debugPrint('❌ Conexión cancelada por el usuario');
        setState(() {
          _isSending = false;
        });
        return;
      }

      debugPrint('🔗 Intentando conectar...');

      // Mostrar diálogo de progreso de transferencia
      _showTransferProgressDialog(device, selectedFiles);

      // Conectar al dispositivo BLE
      await device.connect(timeout: const Duration(seconds: 30));
      debugPrint('✅ Conectado exitosamente');

      // Descubrir servicios
      final services = await device.discoverServices();
      debugPrint('📋 Servicios descubiertos: ${services.length}');

      // Buscar característica de escritura
      BluetoothCharacteristic? writeCharacteristic;
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            writeCharacteristic = characteristic;
            debugPrint('✅ Característica de escritura encontrada: ${characteristic.uuid}');
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic == null) {
        throw Exception('No se encontró característica de escritura en el dispositivo');
      }

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];

        setState(() {
          _currentFileIndex = i;
          _currentFileName = file.name;
          _currentFileProgress = 0.0;
          _currentFileBytesTransferred = 0;
          _currentFileTotalBytes = file.sizeBytes;
        });

        debugPrint(
            '📄 Enviando archivo ${i + 1}/${selectedFiles.length}: ${file.name} (${file.formattedSize})');

        // Leer archivo
        final fileBytes = await File(file.path).readAsBytes();
        debugPrint('   📖 Archivo leído: ${fileBytes.length} bytes');

        // Enviar header con información del archivo
        final header = '${file.name}|${fileBytes.length}\n';
        await writeCharacteristic.write(Uint8List.fromList(header.codeUnits), withoutResponse: true);
        debugPrint('   📤 Header enviado');

        // Pequeña pausa para asegurar que el receptor procese el header
        await Future.delayed(const Duration(milliseconds: 100));

        // Enviar archivo en chunks con progreso (BLE tiene MTU limitado ~20 bytes típicamente)
        const chunkSize = 20; // Tamaño típico de MTU para BLE
        int bytesTransferred = 0;
        final startTime = DateTime.now();

        for (int offset = 0; offset < fileBytes.length; offset += chunkSize) {
          final end = (offset + chunkSize < fileBytes.length)
              ? offset + chunkSize
              : fileBytes.length;

          await writeCharacteristic.write(
            fileBytes.sublist(offset, end),
            withoutResponse: true,
          );
          await Future.delayed(const Duration(milliseconds: 20)); // Pausa entre chunks

          bytesTransferred = end;

          // Actualizar progreso
          setState(() {
            _currentFileBytesTransferred = bytesTransferred;
            _currentFileProgress = bytesTransferred / fileBytes.length;

            // Calcular velocidad
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            if (elapsed > 0) {
              final bytesPerSecond = bytesTransferred / elapsed;
              final kbPerSecond = bytesPerSecond / 1024;
              _transferSpeed = '${kbPerSecond.toStringAsFixed(1)} KB/s';
            }
          });
        }

        debugPrint('   ✅ ${file.name} enviado completamente');

        // Pequeña pausa entre archivos
        if (i < selectedFiles.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      debugPrint('🎉 Todos los archivos enviados exitosamente');

      setState(() {
        _isSending = false;
      });

      // Desconectar dispositivo
      await device.disconnect();
      debugPrint('🔌 Conexión cerrada');

      // Cerrar diálogo de progreso y mostrar éxito
      Navigator.of(context).pop();
      _showSuccessDialog(selectedFiles.length);
    } catch (e) {
      debugPrint('❌ Error durante el envío de archivos:');
      debugPrint('   Tipo de error: ${e.runtimeType}');
      debugPrint('   Mensaje: $e');

      setState(() {
        _isSending = false;
      });

      // Intentar desconectar dispositivo
      try {
        await device.disconnect();
        debugPrint('🔌 Conexión cerrada después del error');
      } catch (closeError) {
        debugPrint('⚠️ Error al desconectar: $closeError');
      }

      // Cerrar diálogo de progreso
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de error más específico
      String errorMessage = 'Error al enviar archivos';
      if (e.toString().contains('timeout')) {
        errorMessage =
            'Timeout: El dispositivo no respondió. ¿Está preparado para recibir?';
      } else if (e.toString().contains('característica')) {
        errorMessage =
            'El dispositivo no soporta transferencia de archivos por BLE.';
      } else if (e.toString().contains('connect')) {
        errorMessage =
            'Error de conexión. Verifica que el dispositivo esté cerca y disponible.';
      }

      _showSnackBar(errorMessage, isError: true);
    }
  }

  // ============================================================================
  // MÉTODO ALTERNATIVO: Compartir archivos usando el sistema nativo de Android
  // ============================================================================
  // Este método es más simple y no requiere que el receptor tenga una app
  // específica escuchando. Usa el sistema de compartir nativo de Android.
  Future<void> _shareFilesNative() async {
    final selectedFiles = _selectedFiles;

    if (selectedFiles.isEmpty) {
      _showSnackBar('No hay archivos seleccionados', isError: true);
      return;
    }

    try {
      debugPrint(
          '📤 Compartiendo ${selectedFiles.length} archivos usando sistema nativo');

      // Convertir archivos a XFile para share_plus
      final List<XFile> xFiles = selectedFiles
          .map((file) => XFile(
                file.path,
                name: file.path.split('/').last,
                mimeType: 'application/octet-stream',
              ))
          .toList();

      // Compartir usando el sistema nativo (incluye Bluetooth si está disponible)
      final result = await Share.shareXFiles(
        xFiles,
        text: 'Archivos de respaldo - ClickPalm',
        subject: 'Compartir archivos vía Bluetooth',
      );

      debugPrint('📤 Resultado de compartir: ${result.status}');

      if (result.status == ShareResultStatus.success) {
        debugPrint('✅ Archivos compartidos exitosamente');
        _showSnackBar('Archivos compartidos', isError: false);

        // Desmarcar archivos después de compartir
        setState(() {
          for (var file in selectedFiles) {
            file.isSelected = false;
          }
        });
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('ℹ️ Usuario canceló la compartición');
      }
    } catch (e) {
      debugPrint('❌ Error compartiendo archivos: $e');
      _showSnackBar('Error al compartir archivos', isError: true);
    }
  }

  // Diálogo de espera para que el otro dispositivo acepte la conexión
  Future<bool> _showConnectionWaitingDialog(BluetoothDevice device) async {
    int countdown = 10; // 10 segundos de espera
    bool dialogResult = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Iniciar countdown
            if (countdown == 10) {
              Future.doWhile(() async {
                await Future.delayed(const Duration(seconds: 1));
                if (countdown > 0 && dialogResult) {
                  setDialogState(() {
                    countdown--;
                  });
                  return true; // Continuar
                }
                return false; // Detener
              }).then((_) {
                if (countdown == 0 && dialogResult) {
                  // Auto cerrar después de 10 segundos
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).secondaryBackground,
                      FlutterFlowTheme.of(context).alternate,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono animado de Bluetooth
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bluetooth_searching,
                        size: 48,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título
                    Text(
                      'Esperando Aceptación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Mensaje
                    Text(
                      'Solicitando conexión con:',
                      style: TextStyle(
                        fontSize: 14,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Nombre del dispositivo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        device.platformName.isNotEmpty ? device.platformName : device.remoteId.str,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contador
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).info,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).primary,
                          width: 3,
                        ),
                      ),
                      child: Text(
                        '$countdown',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Instrucciones
                    Text(
                      'El otro dispositivo debe aceptar la conexión Bluetooth',
                      style: TextStyle(
                        fontSize: 12,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón Cancelar
                        TextButton(
                          onPressed: () {
                            dialogResult = false;
                            Navigator.of(dialogContext).pop(false);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),

                        const SizedBox(width: 16),

                        // Botón Conectar Ahora
                        ElevatedButton(
                          onPressed: countdown == 0
                              ? null
                              : () {
                                  dialogResult = true;
                                  Navigator.of(dialogContext).pop(true);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                FlutterFlowTheme.of(context).primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            countdown > 0 ? 'Conectar Ahora' : 'Conectando...',
                            style: TextStyle(
                              color: FlutterFlowTheme.of(context).info,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result ?? false;
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bluetooth,
                color: FlutterFlowTheme.of(context).primary, size: 28),
            const SizedBox(width: 12),
            const Text('Seleccionar Método'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona cómo enviar los archivos:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),

                // Opción 1: Sistema nativo (RECOMENDADO)
                Container(
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.share,
                          color: FlutterFlowTheme.of(context).info, size: 24),
                    ),
                    title: const Text(
                      'Compartir (Recomendado)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Usa el sistema de compartir de Android. Más simple y compatible.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FÁCIL',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _shareFilesNative();
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Opción 2: Conexión directa (requiere receptor)
                Container(
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).alternate,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: Icon(Icons.bluetooth_connected,
                        color: FlutterFlowTheme.of(context).secondaryText),
                    title: const Text(
                      'Conexión Directa',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Requiere app receptora en el otro dispositivo',
                      style: TextStyle(fontSize: 11),
                    ),
                    children: [
                      // Contenedor con altura máxima para evitar desbordamiento
                      Container(
                        constraints: const BoxConstraints(
                          maxHeight: 300, // Altura máxima para la lista
                        ),
                        child: _devicesList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No hay dispositivos emparejados',
                                  style: TextStyle(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _devicesList.length,
                                itemBuilder: (context, index) {
                                  final device = _devicesList[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _sendFilesToDevice(device);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Icono del dispositivo
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.bluetooth,
                                                size: 24,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Información del dispositivo
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    device.platformName.isNotEmpty
                                                        ? device.platformName
                                                        : 'Dispositivo desconocido',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    device.remoteId.str,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Icono de flecha
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showTransferProgressDialog(dynamic device, List<FileItem> files) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).secondaryBackground,
                    FlutterFlowTheme.of(context).alternate,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono animado
                  ScaleTransition(
                    scale: _progressPulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bluetooth_audio,
                        color: FlutterFlowTheme.of(context).info,
                        size: 48,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Título
                  Text(
                    'Enviando Archivos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Dispositivo
                  Text(
                    'a ${device.platformName.isNotEmpty ? device.platformName : "dispositivo"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Progreso general
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Archivo ${_currentFileIndex + 1} de $_totalFilesToSend',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                            Text(
                              '${(_currentFileProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Nombre del archivo actual
                        Text(
                          _currentFileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Barra de progreso del archivo actual
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 8,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor:
                                      _currentFileProgress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          FlutterFlowTheme.of(context).primary,
                                          FlutterFlowTheme.of(context)
                                              .secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Información de transferencia
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.swap_vert,
                                  size: 14,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _transferSpeed.isNotEmpty
                                      ? _transferSpeed
                                      : 'Calculando...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(_currentFileBytesTransferred / 1024).toStringAsFixed(1)} KB / '
                              '${(_currentFileTotalBytes / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lista de archivos
                  if (_totalFilesToSend > 1) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final isCompleted = index < _currentFileIndex;
                          final isCurrent = index == _currentFileIndex;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle
                                      : isCurrent
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isCompleted
                                      ? FlutterFlowTheme.of(context).success
                                      : isCurrent
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCompleted
                                          ? FlutterFlowTheme.of(context).success
                                          : isCurrent
                                              ? FlutterFlowTheme.of(context)
                                                  .primaryText
                                              : FlutterFlowTheme.of(context)
                                                  .secondaryText,
                                      fontWeight: isCurrent
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mensaje
                  Text(
                    'No cierres esta ventana durante la transferencia',
                    style: TextStyle(
                      fontSize: 12,
                      color: FlutterFlowTheme.of(context)
                          .secondaryText
                          .withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSuccessDialog(int filesCount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FlutterFlowTheme.of(context).success,
                FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de éxito
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: FlutterFlowTheme.of(context).info,
                  size: 64,
                ),
              ),

              const SizedBox(height: 24),

              // Título
              Text(
                '¡Transferencia Completa!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).info,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Mensaje
              Text(
                '$filesCount ${filesCount == 1 ? "archivo enviado" : "archivos enviados"} '
                'exitosamente por Bluetooth',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Botón
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).info,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Deseleccionar archivos
                    _deselectAll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continuar',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).success,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método temporal mientras no esté Bluetooth
  void _showBluetoothNotImplemented() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline,
                color: FlutterFlowTheme.of(context).primary),
            const SizedBox(width: 12),
            const Text('Bluetooth No Configurado'),
          ],
        ),
        content: const Text(
          'Para habilitar la funcionalidad de Bluetooth, necesitas:\n\n'
          '1. Agregar a pubspec.yaml:\n'
          '   flutter_bluetooth_serial: ^0.4.0\n\n'
          '2. Ejecutar: flutter pub get\n\n'
          '3. Descomentar el código de Bluetooth en load_backups_form.dart\n\n'
          '4. Verificar permisos en AndroidManifest.xml',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? FlutterFlowTheme.of(context).error
            : FlutterFlowTheme.of(context).success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            FlutterFlowTheme.of(context).alternate,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            _buildToolbar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingView()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorView()
                      : _buildFilesList(),
            ),
            if (_selectedFiles.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.folder_open,
              color: FlutterFlowTheme.of(context).info,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archivos de Backup',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CSV Exports & Sync Files',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: FlutterFlowTheme.of(context).info),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: FlutterFlowTheme.of(context).secondaryBackground,
      child: TabBar(
        controller: _tabController,
        labelColor: FlutterFlowTheme.of(context).primary,
        unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
        indicatorColor: FlutterFlowTheme.of(context).primary,
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.table_chart, size: 20),
                const SizedBox(width: 8),
                Text('CSV (${_csvFiles.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync, size: 20),
                const SizedBox(width: 8),
                Text('Sync (${_syncFiles.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final selectedCount = _selectedFiles.length;
    final totalCount = _currentFiles.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: FlutterFlowTheme.of(context).secondaryBackground,
      child: Row(
        children: [
          // Seleccionar todos / Deseleccionar todos
          if (selectedCount > 0)
            TextButton.icon(
              onPressed: _deselectAll,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Deseleccionar'),
              style: TextButton.styleFrom(
                foregroundColor: FlutterFlowTheme.of(context).error,
              ),
            )
          else
            TextButton.icon(
              onPressed: totalCount > 0 ? _selectAll : null,
              icon: const Icon(Icons.check_box, size: 18),
              label: const Text('Seleccionar todo'),
              style: TextButton.styleFrom(
                foregroundColor: FlutterFlowTheme.of(context).primary,
              ),
            ),

          const Spacer(),

          // Ordenar
          PopupMenuButton<SortOption>(
            initialValue: _sortOption,
            icon: Icon(
              Icons.sort,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
                _sortFiles();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.dateNewest,
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 12),
                    Text('Más recientes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.dateOldest,
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 12),
                    Text('Más antiguos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.nameAsc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 12),
                    Text('Nombre A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.nameDesc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 12),
                    Text('Nombre Z-A'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.sizeAsc,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 18),
                    SizedBox(width: 12),
                    Text('Tamaño menor'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.sizeDesc,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 18),
                    SizedBox(width: 12),
                    Text('Tamaño mayor'),
                  ],
                ),
              ),
            ],
          ),

          // Refrescar
          IconButton(
            onPressed: _loadFiles,
            icon: Icon(
              Icons.refresh,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    if (_currentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 20),
            Text(
              'No hay archivos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == FileCategory.csvExports
                  ? 'No se encontraron archivos CSV'
                  : 'No se encontraron archivos de sincronización',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentFiles.length,
      itemBuilder: (context, index) {
        final file = _currentFiles[index];
        return _buildFileItem(file);
      },
    );
  }

  Widget _buildFileItem(FileItem file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: file.isSelected
            ? FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1)
            : FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file.isSelected
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).alternate,
          width: file.isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: file.isSelected,
          onChanged: (value) => _toggleSelection(file),
          activeColor: FlutterFlowTheme.of(context).primary,
        ),
        title: Text(
          file.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FlutterFlowTheme.of(context).primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                file.formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.sd_storage,
                size: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                file.formattedSize,
                style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _toggleSelection(file),
      ),
    );
  }

  Widget _buildBottomBar() {
    final selectedCount = _selectedFiles.length;
    final totalSize = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.sizeBytes,
    );

    String formattedTotalSize;
    if (totalSize < 1024 * 1024) {
      formattedTotalSize = '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else {
      formattedTotalSize =
          '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: [
          BoxShadow(
            color:
                FlutterFlowTheme.of(context).primaryText.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Información de selección
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedCount archivos seleccionados',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              Text(
                formattedTotalSize,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Botón de enviar por Bluetooth
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).primary,
                  FlutterFlowTheme.of(context).secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: FlutterFlowTheme.of(context)
                      .primary
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () {
                      _scanForDevices();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).info,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Enviando...',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).info,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: FlutterFlowTheme.of(context).info,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Enviar por Bluetooth',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).info,
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
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando archivos...',
            style: TextStyle(
              fontSize: 16,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: FlutterFlowTheme.of(context).error,
            ),
            const SizedBox(height: 20),
            Text(
              'Error al cargar archivos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
                foregroundColor: FlutterFlowTheme.of(context).info,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
