// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '/custom_code/platform_utils.dart';

/// Muestra un previsualizador HTML con WebView y botones para imprimir y guardar PDF.
Future<void> previewAndPrintHTML(
  BuildContext context,
  String htmlContent,
  String title, {
  String pdfFilename = 'ticket',
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HTMLPreviewScreen(
        htmlContent: htmlContent,
        title: title,
        pdfFilename: pdfFilename,
      ),
    ),
  );
}

class HTMLPreviewScreen extends StatefulWidget {
  final String htmlContent;
  final String title;
  final String pdfFilename;

  const HTMLPreviewScreen({
    super.key,
    required this.htmlContent,
    required this.title,
    this.pdfFilename = 'ticket',
  });

  @override
  State<HTMLPreviewScreen> createState() => _HTMLPreviewScreenState();
}

class _HTMLPreviewScreenState extends State<HTMLPreviewScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _isPrinting = false;
  bool _isSavingPdf = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final fullHTML = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow-x: hidden; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 0; margin: 0;
      background-color: #f5f5f5;
      font-size: 14px; line-height: 1.6;
    }
    h1, h2, h3, h4, h5, h6 { margin-bottom: 10px; color: #333; word-wrap: break-word; }
    p { margin-bottom: 10px; word-wrap: break-word; }
    .container { width: 100%; min-height: 100vh; background-color: white; padding: 16px; box-shadow: none; }
    table { width: 100% !important; table-layout: auto; word-wrap: break-word; }
    img { max-width: 100% !important; height: auto !important; }
    div { max-width: 100%; word-wrap: break-word; }
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
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (e) =>
              debugPrint('❌ Error cargando WebView: ${e.description}'),
        ),
      )
      ..loadHtmlString(fullHTML);
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _isPrinting || _isSavingPdf;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // WebView ocupa todo el espacio disponible
          Expanded(
            child: Stack(
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
          ),
          // Barra de botones fija en la parte inferior — visible siempre
          SafeArea(
            top: false,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: busy
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _savePdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 22),
                          label: const Text(
                            'GUARDAR PDF',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _printToThermalPrinter,
                          icon: const Icon(Icons.print, size: 22),
                          label: const Text(
                            'IMPRIMIR',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00a86b),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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

  // ─── GUARDAR PDF ──────────────────────────────────────────────────────────

  Future<void> _savePdf() async {
    setState(() => _isSavingPdf = true);
    try {
      await savePdfToFile(context, widget.htmlContent, widget.pdfFilename);
    } catch (e) {
      debugPrint('❌ Error guardando PDF: $e');
      _showErrorDialog(
          'Error al guardar PDF', 'No se pudo guardar el PDF.\n\nError: $e');
    } finally {
      if (mounted) setState(() => _isSavingPdf = false);
    }
  }

  // ─── IMPRIMIR TÉRMICA ─────────────────────────────────────────────────────

  Future<void> _printToThermalPrinter() async {
    if (!Platforms.isMobile) return;
    setState(() => _isPrinting = true);

    BluetoothDevice? connectedDevice;
    BluetoothCharacteristic? writeCharacteristic;

    try {
      String? printerMac = FFAppState().printerMacAddress;
      String? printerName = FFAppState().printerName;

      if (printerMac.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        printerMac = prefs.getString('printer_address');
        printerName = prefs.getString('printer_name');
      }

      if (printerMac == null || printerMac.isEmpty) {
        _showErrorDialog('No hay impresora configurada',
            'Por favor, configura una impresora en Configuración > Configuración de Impresoras');
        return;
      }

      debugPrint('🖨️ Usando impresora: ${printerName ?? "Impresora"} ($printerMac)');

      final hasPermissions = await _requestBluetoothPermissions();
      if (!hasPermissions) {
        _showErrorDialog('Permisos requeridos',
            'Se necesitan permisos de Bluetooth para conectar con la impresora.');
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _showErrorDialog('Bluetooth desactivado',
            'Por favor, activa el Bluetooth para conectar con la impresora.');
        return;
      }

      debugPrint('🖨️ Conectando a impresora: $printerMac');

      try {
        connectedDevice = BluetoothDevice.fromId(printerMac);
        await connectedDevice.connect(timeout: const Duration(seconds: 15));
        debugPrint('✅ Conectado a la impresora');

        final services = await connectedDevice.discoverServices();
        debugPrint('📋 Servicios descubiertos: ${services.length}');

        for (final service in services) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse) {
              writeCharacteristic = characteristic;
              debugPrint(
                  '✅ Característica de escritura encontrada: ${characteristic.uuid}');
              break;
            }
          }
          if (writeCharacteristic != null) break;
        }

        if (writeCharacteristic == null) {
          throw Exception(
              'No se encontró característica de escritura en la impresora');
        }

        final bytes = htmlToEscPosBytes(widget.htmlContent);
        final data = Uint8List.fromList(bytes);
        const chunkSize = 20;

        for (int i = 0; i < data.length; i += chunkSize) {
          final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
          final chunk = data.sublist(i, end);
          await writeCharacteristic.write(chunk, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20));
        }

        debugPrint('✅ Impresión completada');

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
        try {
          await connectedDevice?.disconnect();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Error general: $e');
      _showErrorDialog('Error', 'Ocurrió un error al intentar imprimir: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    try {
      if (!Platform.isAndroid) return false;

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 31) {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus.isGranted && connectStatus.isGranted) return true;

        final result = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        return result[Permission.bluetoothScan]?.isGranted == true &&
            result[Permission.bluetoothConnect]?.isGranted == true;
      }

      return true;
    } catch (_) {
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

class _DirOption {
  final String label;
  final String path;
  const _DirOption(this.label, this.path);
}

const _prefKeySavePath = 'pdf_save_directory';

/// Función pública reutilizable: guarda [htmlContent] como PDF en disco.
/// Muestra selector de carpeta (desktop) o diálogo de opciones (Android).
/// Recuerda la última carpeta elegida en SharedPreferences.
Future<void> savePdfToFile(
  BuildContext context,
  String htmlContent,
  String pdfFilename,
) async {
  final prefs = await SharedPreferences.getInstance();
  final savedDir = prefs.getString(_prefKeySavePath);
  final dirValid =
      savedDir != null && savedDir.isNotEmpty && Directory(savedDir).existsSync();

  String? targetDir;

  if (dirValid) {
    targetDir = savedDir;
    debugPrint('💾 Usando directorio guardado: $targetDir');
  } else if (Platform.isAndroid) {
    if (!context.mounted) return;
    targetDir = await _pickDirAndroid(context, prefs);
  } else {
    targetDir = await _pickDirDesktop(prefs);
  }

  if (targetDir == null) return;

  // ignore: deprecated_member_use
  final pdfBytes = await Printing.convertHtml(
    format: PdfPageFormat.a4,
    html: '''<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
<style>
  *{margin:0;padding:0;box-sizing:border-box;}
  body{font-family:Arial,sans-serif;font-size:12px;line-height:1.5;}
  .c{padding:12px;}
  table{width:100%;border-collapse:collapse;}
  td,th{padding:4px 6px;}
  img{max-width:100%;}
  div{word-wrap:break-word;}
</style></head>
<body><div class="c">$htmlContent</div></body></html>''',
  );

  final cleanName =
      pdfFilename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  final filename = '$cleanName.pdf';
  final filePath = '$targetDir${Platform.pathSeparator}$filename';
  await File(filePath).writeAsBytes(pdfBytes);
  debugPrint('✅ PDF guardado en: $filePath');

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ PDF guardado: $filename'),
        backgroundColor: const Color(0xFF1565C0),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

Future<String?> _pickDirDesktop(SharedPreferences prefs) async {
  final picked = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Seleccionar carpeta para guardar PDF',
  );
  if (picked == null) return null;
  await prefs.setString(_prefKeySavePath, picked);
  return picked;
}

Future<String?> _pickDirAndroid(
    BuildContext context, SharedPreferences prefs) async {
  final List<_DirOption> options = [];

  final dl = Directory('/storage/emulated/0/Downloads');
  if (dl.existsSync()) {
    options.add(const _DirOption('Downloads', '/storage/emulated/0/Downloads'));
  }
  final docs = Directory('/storage/emulated/0/Documents');
  if (docs.existsSync()) {
    options.add(
        const _DirOption('Documents', '/storage/emulated/0/Documents'));
  }
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null && ext.existsSync()) {
      options.add(_DirOption('Almacenamiento externo (app)', ext.path));
    }
  } catch (_) {}
  final appDoc = await getApplicationDocumentsDirectory();
  options.add(_DirOption('Documentos internos (app)', appDoc.path));

  if (!context.mounted) return null;

  final chosen = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Guardar PDF en…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map<Widget>((o) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(o.label),
                  subtitle: Text(o.path,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, o.path),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );

  if (chosen == null) return null;

  // Permiso de escritura en Android < 10
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt < 29) {
      final status = await Permission.storage.request();
      if (!status.isGranted) return null;
    }
  } catch (_) {}

  await prefs.setString(_prefKeySavePath, chosen);
  return chosen;
}

/// Convierte HTML a bytes ESC/POS con encoding CP1252 (Latin-1).
/// Compatible con impresoras térmicas PT210_UB y similares.
List<int> htmlToEscPosBytes(String html) {
  final bytes = <int>[];

  bytes..addAll([0x1B, 0x40])       // ESC @ — initialize
       ..addAll([0x1B, 0x74, 0x10]); // ESC t 16 — CP1252

  void addAlign(int a) => bytes.addAll([0x1B, 0x61, a]);
  void addBold(bool on) => bytes.addAll([0x1B, 0x45, on ? 1 : 0]);

  void addText(String text) {
    for (final c in text.codeUnits) {
      bytes.add(c < 256 ? c : 0x3F);
    }
  }

  bool bold = false;
  bool centered = false;
  bool skip = false;

  final re = RegExp(r'<([^>]*)>|([^<]+)', dotAll: true);
  for (final m in re.allMatches(html)) {
    final tag = m.group(1);
    final text = m.group(2);

    if (tag != null) {
      final t = tag.toLowerCase().trim();

      if (t == 'style' || t.startsWith('style ') ||
          t == 'script' || t.startsWith('script ')) {
        skip = true;
        continue;
      }
      if (t == '/style' || t == '/script') { skip = false; continue; }
      if (skip) continue;

      if (t.startsWith('hr')) {
        if (centered) addAlign(0);
        addText('--------------------------------\n');
        if (centered) addAlign(1);
      } else if (t.startsWith('br')) {
        bytes.add(0x0A);
      } else if (t == 'b' || t == 'strong') {
        addBold(true); bold = true;
      } else if (t == '/b' || t == '/strong') {
        addBold(false); bold = false;
      } else if (RegExp(r'^h[1-6](\s|$)').hasMatch(t)) {
        addAlign(1); centered = true;
        addBold(true); bold = true;
      } else if (RegExp(r'^/h[1-6]$').hasMatch(t)) {
        addBold(false); bold = false;
        addAlign(0); centered = false;
        bytes.add(0x0A);
      } else if ((t.startsWith('div') || t == 'p' || t.startsWith('p ')) &&
          !t.startsWith('/')) {
        final hasCenter = t.contains('text-align:center') ||
            t.contains('text-align: center');
        final hasBold = t.contains('font-weight:bold') ||
            t.contains('font-weight: bold');
        if (hasCenter && !centered) { addAlign(1); centered = true; }
        if (hasBold && !bold) { addBold(true); bold = true; }
      } else if (t.startsWith('/div') || t.startsWith('/p')) {
        if (bold) { addBold(false); bold = false; }
        if (centered) { addAlign(0); centered = false; }
        bytes.add(0x0A);
      }
    } else if (text != null && !skip) {
      final decoded = text
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('\r\n', ' ')
          .replaceAll('\n', ' ')
          .replaceAll('\r', ' ');
      if (decoded.trim().isNotEmpty) addText(decoded);
    }
  }

  bytes..addAll([0x0A, 0x0A, 0x0A])..addAll([0x1D, 0x56, 0x41, 0x00]);
  return bytes;
}
