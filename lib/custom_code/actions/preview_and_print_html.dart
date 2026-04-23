// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '/custom_code/platform_utils.dart';

/// Muestra un previsualizador HTML con WebView y un botón para imprimir
///
/// Parámetros:
/// - context: BuildContext de Flutter
/// - htmlContent: Contenido HTML procesado con placeholders reemplazados
/// - title: Título del previsualizador
Future<void> previewAndPrintHTML(
  BuildContext context,
  String htmlContent,
  String title,
) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HTMLPreviewScreen(
        htmlContent: htmlContent,
        title: title,
      ),
    ),
  );
}

class HTMLPreviewScreen extends StatefulWidget {
  final String htmlContent;
  final String title;

  const HTMLPreviewScreen({
    Key? key,
    required this.htmlContent,
    required this.title,
  }) : super(key: key);

  @override
  State<HTMLPreviewScreen> createState() => _HTMLPreviewScreenState();
}

class _HTMLPreviewScreenState extends State<HTMLPreviewScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Crear HTML completo con estilos optimizados para ticket
    final fullHTML = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow-x: hidden;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 0;
      margin: 0;
      background-color: #f5f5f5;
      font-size: 14px;
      line-height: 1.6;
    }
    h1, h2, h3, h4, h5, h6 {
      margin-bottom: 10px;
      color: #333;
      word-wrap: break-word;
    }
    p {
      margin-bottom: 10px;
      word-wrap: break-word;
    }
    .container {
      width: 100%;
      min-height: 100vh;
      background-color: white;
      padding: 16px;
      box-shadow: none;
    }
    /* Asegurar que las tablas se ajusten al ancho */
    table {
      width: 100% !important;
      table-layout: auto;
      word-wrap: break-word;
    }
    /* Asegurar que las imágenes se ajusten al ancho */
    img {
      max-width: 100% !important;
      height: auto !important;
    }
    /* Asegurar que los divs no se salgan */
    div {
      max-width: 100%;
      word-wrap: break-word;
    }
  </style>
</head>
<body>
  <div class="container">
    ${widget.htmlContent}
  </div>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Error cargando WebView: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(fullHTML);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando vista previa...'),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isPrinting
          ? Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade400,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _printToThermalPrinter,
              backgroundColor: const Color(0xFF00a86b),
              elevation: 6,
              icon: const Icon(
                Icons.print,
                size: 32,
                color: Colors.white,
              ),
              label: const Text(
                'IMPRIMIR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _printToThermalPrinter() async {
    if (!Platforms.isMobile) return; // Bluetooth no disponible en desktop
    setState(() {
      _isPrinting = true;
    });

    BluetoothDevice? connectedDevice;
    BluetoothCharacteristic? writeCharacteristic;

    try {
      // Obtener la impresora guardada (primero desde AppState, luego SharedPreferences)
      String? printerMac = FFAppState().printerMacAddress;
      String? printerName = FFAppState().printerName;

      // Si no está en AppState, intentar cargar desde SharedPreferences
      if (printerMac.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        printerMac = prefs.getString('printer_mac_address');
        printerName = prefs.getString('printer_name');
      }

      if (printerMac == null || printerMac.isEmpty) {
        _showErrorDialog('No hay impresora configurada',
            'Por favor, configura una impresora en Configuración > Configuración de Impresoras');
        return;
      }

      debugPrint('🖨️ Usando impresora: ${printerName ?? "Impresora"} ($printerMac)');

      // Solicitar permisos de Bluetooth antes de conectar
      final hasPermissions = await _requestBluetoothPermissions();
      if (!hasPermissions) {
        _showErrorDialog('Permisos requeridos',
            'Se necesitan permisos de Bluetooth para conectar con la impresora.');
        return;
      }

      // Verificar que Bluetooth esté encendido
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _showErrorDialog('Bluetooth desactivado',
            'Por favor, activa el Bluetooth para conectar con la impresora.');
        return;
      }

      // Conectar a la impresora Bluetooth usando flutter_blue_plus
      debugPrint('🖨️ Conectando a impresora: $printerMac');

      try {
        // Crear dispositivo desde MAC address
        connectedDevice = BluetoothDevice.fromId(printerMac);

        // Conectar al dispositivo
        await connectedDevice.connect(timeout: const Duration(seconds: 15));
        debugPrint('✅ Conectado a la impresora');

        // Descubrir servicios
        final services = await connectedDevice.discoverServices();
        debugPrint('📋 Servicios descubiertos: ${services.length}');

        // Buscar característica de escritura para impresión
        // Las impresoras térmicas BLE generalmente usan estos UUIDs comunes
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
          throw Exception('No se encontró característica de escritura en la impresora');
        }

        // Convertir HTML a texto plano para imprimir
        final printableText = await _htmlToPlainText(widget.htmlContent);

        // Comandos ESC/POS básicos
        final List<int> bytes = [];

        // Inicializar impresora
        bytes.addAll([0x1B, 0x40]); // ESC @ - Initialize printer

        // Configurar tamaño de fuente normal
        bytes.addAll([0x1B, 0x21, 0x00]); // ESC ! - Select print mode

        // Imprimir el contenido
        bytes.addAll(utf8.encode(printableText));

        // Alimentar papel y cortar
        bytes.addAll([0x0A, 0x0A, 0x0A]); // Line feeds
        bytes.addAll([0x1D, 0x56, 0x41, 0x00]); // GS V - Cut paper

        // Enviar a la impresora en chunks (BLE tiene límite de MTU)
        final data = Uint8List.fromList(bytes);
        const chunkSize = 20; // Tamaño típico de MTU para BLE

        for (int i = 0; i < data.length; i += chunkSize) {
          final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
          final chunk = data.sublist(i, end);
          await writeCharacteristic.write(chunk, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20)); // Pequeña pausa entre chunks
        }

        debugPrint('✅ Impresión completada');

        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Documento impreso correctamente'),
              backgroundColor: Color(0xFF00a86b),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error de conexión: $e');
        _showErrorDialog('Error de conexión',
            'No se pudo conectar a la impresora. Verifica que esté encendida y cerca del dispositivo.\n\nError: $e');
      } finally {
        // Desconectar dispositivo
        try {
          await connectedDevice?.disconnect();
        } catch (e) {
          debugPrint('⚠️ Error al desconectar: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error general: $e');
      _showErrorDialog('Error', 'Ocurrió un error al intentar imprimir: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<String> _htmlToPlainText(String html) async {
    // Remover tags HTML y convertir a texto plano
    String text = html;

    // Reemplazar <br> y </p> con saltos de línea
    text = text.replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</h[1-6]>',
        caseSensitive: false), '\n');

    // Agregar énfasis para headers
    text = text.replaceAllMapped(
        RegExp(r'<h([1-6])[^>]*>(.*?)', caseSensitive: false), (match) {
      final content = match.group(2) ?? '';
      return '\n=== $content ===\n';
    });

    // Remover todas las etiquetas HTML
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decodificar entidades HTML
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    // Limpiar espacios múltiples y líneas vacías excesivas
    text = text.replaceAll(RegExp(r' +'), ' ');
    text = text.replaceAll(RegExp(r'\n\n+'), '\n\n');
    text = text.trim();

    return text;
  }

  Future<bool> _requestBluetoothPermissions() async {
    try {
      if (!Platform.isAndroid) return false;

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      debugPrint('📱 SDK Version: $sdkVersion');

      // Android 12+ (SDK 31+) requiere BLUETOOTH_SCAN y BLUETOOTH_CONNECT
      if (sdkVersion >= 31) {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus.isGranted && connectStatus.isGranted) {
          debugPrint('✅ Permisos de Bluetooth ya otorgados');
          return true;
        }

        debugPrint('🔐 Solicitando permisos de Bluetooth...');
        final result = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        final granted = result[Permission.bluetoothScan]?.isGranted == true &&
            result[Permission.bluetoothConnect]?.isGranted == true;

        debugPrint(granted
            ? '✅ Permisos de Bluetooth otorgados'
            : '❌ Permisos de Bluetooth denegados');

        return granted;
      }

      // Android < 12 ya tiene permisos en el manifest
      debugPrint('✅ Android < 12, usando permisos del manifest');
      return true;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
