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

import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart';

/// Genera un PDF dinámico procesando HTML con placeholders
///
/// Parámetros:
/// - context: BuildContext de Flutter
/// - htmlTemplate: Plantilla HTML con placeholders {NombreCampo}
/// - visitDetails: Lista de detalles de la visita con los valores de los campos
/// - title: Título del documento PDF
Future<String> exportDynamicPDF(
  BuildContext context,
  String htmlTemplate,
  List<VisitsDetailsStruct> visitDetails,
  String title,
) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  try {
    // 1. Verificar y solicitar permisos
    final hasPermissions = await _checkAndRequestStoragePermissionsDynamic(context);
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // 2. Reemplazar placeholders en el HTML
    final processedContent = _replacePlaceholders(htmlTemplate, visitDetails);
    debugPrint('📄 Contenido procesado: $processedContent');

    // 3. Crear el PDF
    final pdf = pw.Document();

    // Cargar fuentes con soporte Unicode
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    // Formato A4 estándar
    final format = PdfPageFormat.a4;

    // 4. Parsear el HTML simplificado y crear widgets de PDF
    final widgets = _parseHTMLToWidgets(processedContent, font, fontBold, fontItalic);

    // Crear página del PDF
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: widgets,
            ),
          );
        },
      ),
    );

    // 5. Guardar el archivo PDF
    final String filePath = await _savePDFFileDynamic(pdf, title);

    // 6. Abrir el PDF
    await _openPDFDynamic(filePath, context, title);

    return filePath;
  } catch (e) {
    debugPrint('❌ Error crítico en exportDynamicPDF: $e');
    throw Exception('Error al generar PDF: $e');
  }
}

/// Reemplaza los placeholders {NombreCampo} con los valores reales
String _replacePlaceholders(String htmlTemplate, List<VisitsDetailsStruct> visitDetails) {
  String result = htmlTemplate;

  // Buscar todos los placeholders en formato {NombreCampo}
  final placeholderPattern = RegExp(r'\{([^}]+)\}');
  final matches = placeholderPattern.allMatches(htmlTemplate);

  for (final match in matches) {
    final placeholder = match.group(0)!; // {NombreCampo}
    final fieldName = match.group(1)!;   // NombreCampo

    // Buscar el valor correspondiente en visitDetails
    final fieldValue = _findFieldValue(fieldName, visitDetails);

    // Reemplazar el placeholder con el valor
    result = result.replaceAll(placeholder, fieldValue);
    debugPrint('🔄 Reemplazo: $placeholder -> $fieldValue');
  }

  return result;
}

/// Busca el valor de un campo por su nombre en visitDetails
String _findFieldValue(String fieldName, List<VisitsDetailsStruct> visitDetails) {
  for (final detail in visitDetails) {
    // Comparar el nombre del status (case insensitive)
    if (detail.statusOption.toLowerCase() == fieldName.toLowerCase()) {
      // Retornar el statusResponse si existe y no está vacío
      if (detail.statusResponse.isNotEmpty) {
        return detail.statusResponse;
      }
    }
  }

  // Si no se encuentra, retornar el placeholder original o un valor por defecto
  return '[${fieldName}]';
}

/// Parsea HTML simple y lo convierte en widgets de PDF
List<pw.Widget> _parseHTMLToWidgets(
  String html,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItalic,
) {
  List<pw.Widget> widgets = [];

  // Eliminar espacios en blanco extras
  html = html.trim();

  // Primero, remover todos los estilos CSS inline y atributos style
  // Usando comillas dobles para el raw string para evitar conflictos
  html = html.replaceAll(RegExp(r'\s+style\s*=\s*["\x27][^"\x27]*["\x27]', caseSensitive: false), '');

  // Remover etiquetas <style> completas
  html = html.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');

  // Remover etiquetas <script>
  html = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');

  // Dividir por etiquetas de bloque y saltos de línea
  final lines = html.split(RegExp(r'<br\s*/?>|</p>|</div>|</h[1-6]>', caseSensitive: false));

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;

    // Detectar y procesar headers (antes de remover tags de apertura)
    if (line.contains(RegExp(r'<h[1-6][^>]*>', caseSensitive: false))) {
      final headerMatch = RegExp(r'<h([1-6])[^>]*>', caseSensitive: false).firstMatch(line);
      if (headerMatch != null) {
        final headerLevel = int.tryParse(headerMatch.group(1) ?? '1') ?? 1;

        // Remover todas las etiquetas HTML de la línea
        line = line.replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '');
        line = line.replaceAll(RegExp(r'</?[^>]+>', caseSensitive: false), '');
        line = line.trim();

        if (line.isNotEmpty) {
          widgets.add(pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: 24 - (headerLevel * 4).toDouble(),
              fontWeight: pw.FontWeight.bold,
              font: fontBold,
            ),
          ));
          widgets.add(pw.SizedBox(height: 10));
        }
        continue;
      }
    }

    // Detectar formateo de texto (negrita, cursiva)
    bool isBold = line.contains(RegExp(r'<(b|strong)[^>]*>', caseSensitive: false));
    bool isItalic = line.contains(RegExp(r'<(i|em)[^>]*>', caseSensitive: false));

    // Remover TODAS las etiquetas HTML (incluidas tags de apertura de <p>, <div>, etc.)
    line = line.replaceAll(RegExp(r'</?[^>]+>', caseSensitive: false), '');
    line = line.trim();

    // Decodificar entidades HTML comunes
    line = line.replaceAll('&nbsp;', ' ');
    line = line.replaceAll('&amp;', '&');
    line = line.replaceAll('&lt;', '<');
    line = line.replaceAll('&gt;', '>');
    line = line.replaceAll('&quot;', '"');
    line = line.replaceAll('&#39;', "'");

    // Agregar texto como widget
    if (line.isNotEmpty) {
      widgets.add(pw.Text(
        line,
        style: pw.TextStyle(
          fontSize: 12,
          font: isBold ? fontBold : (isItalic ? fontItalic : font),
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ));
      widgets.add(pw.SizedBox(height: 6));
    }
  }

  return widgets;
}

Future<String> _savePDFFileDynamic(pw.Document pdf, String documentName) async {
  final String docsPath = await _getBestDocumentsPathDynamic();
  final DateTime now = DateTime.now();
  final String timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';

  final String fileName = '${documentName}_$timestamp.pdf';
  final String filePath = '$docsPath/$fileName';
  final File file = File(filePath);

  final Uint8List pdfBytes = await pdf.save();
  await file.writeAsBytes(pdfBytes, flush: true);

  debugPrint('📁 PDF guardado en: $filePath');
  return filePath;
}

Future<void> _openPDFDynamic(String filePath, BuildContext context, String title) async {
  try {
    final File file = File(filePath);
    if (await file.exists()) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreenDynamic(
            filePath: filePath,
            title: title,
          ),
        ),
      );
    } else {
      throw Exception('El archivo PDF no existe');
    }
  } catch (e) {
    debugPrint('❌ Error al abrir PDF: $e');
    throw Exception('No se pudo abrir el PDF: $e');
  }
}

Future<String> _getBestDocumentsPathDynamic() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String path = '${baseDir.path}/ClickPalmData/PDFs';
  final Directory targetDir = Directory(path);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return targetDir.path;
}

Future<bool> _checkAndRequestStoragePermissionsDynamic(BuildContext context) async {
  try {
    if (!Platform.isAndroid) return false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    if (sdkVersion >= 33) {
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

      if (photosStatus.isGranted && videosStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialogDynamic(
        context,
        'La aplicación necesita acceso a tus archivos para guardar el PDF.',
      );
      if (!shouldContinue) return false;

      final result = await [
        Permission.photos,
        Permission.videos,
      ].request();

      return result[Permission.photos]?.isGranted == true &&
          result[Permission.videos]?.isGranted == true;
    }

    if (sdkVersion >= 30) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialogDynamic(
        context,
        'Para guardar el PDF, se requiere permiso para gestionar el almacenamiento.',
      );
      if (!shouldContinue) return false;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    await _showPermissionExplanationDialogDynamic(
      context,
      'Se necesita permiso para guardar el PDF en el almacenamiento.',
    );

    final result = await Permission.storage.request();
    return result.isGranted;
  } catch (e) {
    debugPrint('❌ Error solicitando permisos: $e');
    return false;
  }
}

Future<bool> _showPermissionExplanationDialogDynamic(
    BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;
}

class PDFViewerScreenDynamic extends StatefulWidget {
  final String filePath;
  final String title;

  const PDFViewerScreenDynamic({
    Key? key,
    required this.filePath,
    required this.title,
  }) : super(key: key);

  @override
  State<PDFViewerScreenDynamic> createState() => _PDFViewerScreenDynamicState();
}

class _PDFViewerScreenDynamicState extends State<PDFViewerScreenDynamic> {
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePDF(),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPDF(),
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: false,
            pageSnap: true,
            defaultPage: currentPage!,
            fitPolicy: FitPolicy.WIDTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                pages = pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
              debugPrint('Error en PDFView: $error');
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = 'Error en página $page: $error';
              });
              debugPrint('Error en página $page: $error');
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                currentPage = page;
              });
            },
          ),
          if (errorMessage.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          if (!isReady && errorMessage.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando PDF...'),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: isReady && errorMessage.isEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Página ${(currentPage ?? 0) + 1} de ${pages ?? 0}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _sharePDF() async {
    try {
      final File file = File(widget.filePath);
      final Uint8List pdfBytes = await file.readAsBytes();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${widget.title}.pdf',
      );
    } catch (e) {
      debugPrint('Error al compartir PDF: $e');
    }
  }

  void _printPDF() async {
    try {
      final File file = File(widget.filePath);
      final Uint8List pdfBytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      debugPrint('Error al imprimir PDF: $e');
    }
  }
}
