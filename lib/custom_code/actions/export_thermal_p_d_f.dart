// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Necesario para PdfGoogleFonts
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart';

Future<String> exportThermalPDF(
  BuildContext context,
  String companyTitle,
  dynamic jsonData,
) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  try {
    // 1. Verificar y solicitar permisos
    final hasPermissions = await _checkAndRequestStoragePermissions(context);
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // 2. Procesar los datos de entrada
    Map<String, dynamic> data;
    try {
      if (jsonData is Map<String, dynamic>) {
        // Si ya es un Map, usarlo directamente
        data = jsonData;
      } else if (jsonData is String) {
        // Si es un String JSON, parsearlo
        data = json.decode(jsonData);
      } else {
        // Intentar convertir a Map
        data = Map<String, dynamic>.from(jsonData);
      }

      // DEBUG: Verificar contenido de data
      debugPrint('Datos procesados:');
      debugPrint('Form: ${data['Form']}');
      debugPrint('DateHour: ${data['DateHour']}');
      debugPrint(
          'WorkersPairsSummary length: ${data['WorkersPairsSummary']?.length ?? 0}');
      if (data['WorkersPairsSummary'] != null &&
          data['WorkersPairsSummary'].isNotEmpty) {
        debugPrint('Primer trabajador: ${data['WorkersPairsSummary'][0]}');

        // DEBUG: Verificar si es la nueva estructura (con campo Caja individual)
        var firstWorker = data['WorkersPairsSummary'][0];
        if (firstWorker.containsKey('Caja')) {
          debugPrint(
              'Nueva estructura detectada: Caja individual por registro');
        } else if (firstWorker.containsKey('Cajas')) {
          debugPrint('Estructura anterior detectada: Cajas concatenadas');
        }
      }
    } catch (e) {
      debugPrint('Error procesando datos: $e');
      debugPrint('Tipo de jsonData: ${jsonData.runtimeType}');
      debugPrint('Contenido: $jsonData');
      throw Exception('Error al procesar datos: $e');
    }

    // 3. Crear el PDF con soporte Unicode
    final pdf = pw.Document();

    // Cargar fuente con soporte Unicode
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Dimensiones para impresora térmica (58mm de ancho) - IGUAL QUE ORIGINAL
    const double pageWidth = 58 * PdfPageFormat.mm;

    // Calcular altura aproximada basada en el contenido
    final List<dynamic> workers = data['WorkersPairsSummary'] ?? [];
    double estimatedHeight = 40; // Header + footer base
    estimatedHeight += workers.length *
        45; // ~45mm por trabajador (basado en análisis visual real)

    // Agregar altura por texto largo en nombres
    for (var worker in workers) {
      String recolector = worker['Recolector']?.toString() ?? '';
      String cortero = worker['Cortero']?.toString() ?? '';

      // ACTUALIZADO: Manejar tanto la nueva estructura (Caja) como la anterior (Cajas)
      String cajas = '';
      if (worker.containsKey('Caja')) {
        // Nueva estructura: una caja por registro
        cajas = worker['Caja']?.toString() ?? '';
      } else if (worker.containsKey('Cajas')) {
        // Estructura anterior: cajas concatenadas
        cajas = worker['Cajas']?.toString() ?? '';
      }

      String lotes = worker['Lotes']?.toString() ?? '';

      // Calcular líneas adicionales por texto largo
      int extraLines = 0;
      if (recolector.length > 35) {
        extraLines += (recolector.length / 35).ceil() - 1;
      }
      if (cortero.length > 35) extraLines += (cortero.length / 35).ceil() - 1;
      if (cajas.length > 35) extraLines += (cajas.length / 35).ceil() - 1;
      if (lotes.length > 35) extraLines += (lotes.length / 35).ceil() - 1;

      estimatedHeight += extraLines * 5; // 5mm por línea extra
    }

    // Margen de seguridad generoso
    estimatedHeight += 20; // Margen adicional

    final double pageHeight = estimatedHeight * PdfPageFormat.mm;

    // Crear formato de página personalizado para papel térmico - ORIGINAL
    final customFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginLeft: 2 * PdfPageFormat.mm,
      marginRight: 2 * PdfPageFormat.mm,
      marginTop: 2 * PdfPageFormat.mm,
      marginBottom: 2 * PdfPageFormat.mm,
    );

    // Crear página del PDF
    pdf.addPage(
      pw.Page(
        pageFormat: customFormat,
        build: (pw.Context context) {
          // DEBUG: Verificar que tenemos datos
          debugPrint('Construyendo PDF con datos: ${data.keys}');

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER - FUENTES AUMENTADAS
              pw.Text(
                companyTitle,
                style: pw.TextStyle(
                  fontSize: 16, // Aumentado de 12 a 16
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                data['Form']?.toString() ?? 'REPORTE',
                style: pw.TextStyle(
                  fontSize: 14, // Aumentado de 10 a 14
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                data['DateHour']?.toString() ?? '',
                style: pw.TextStyle(
                    fontSize: 12, font: font), // Aumentado de 8 a 12
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),

              // SEPARADOR
              pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.symmetric(vertical: 2),
              ),

              // BODY - WorkersPairs
              ...(_buildWorkersWidgets(data, font, fontBold)),

              // FOOTER - FUENTES AUMENTADAS
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generado: ${DateTime.now().day.toString().padLeft(2, '0')}/'
                '${DateTime.now().month.toString().padLeft(2, '0')}/'
                '${DateTime.now().year} ${DateTime.now().hour.toString().padLeft(2, '0')}:'
                '${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: pw.TextStyle(
                    fontSize: 10, font: font), // Aumentado de 6 a 10
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '--- FIN DEL REPORTE ---',
                style: pw.TextStyle(
                    fontSize: 10, // Aumentado de 6 a 10
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    // 4. Guardar el archivo PDF
    final String filePath = await _savePDFFile(pdf, data['Form'] ?? 'reporte');

    // 5. Abrir el PDF con el context correcto
    if (!context.mounted) return filePath;
    await _openPDF(filePath, context);

    return filePath;
  } catch (e) {
    debugPrint('Error crítico en exportThermalPDF: $e');
    throw Exception('Error al generar PDF: $e');
  }
}

List<pw.Widget> _buildWorkersWidgets(
    Map<String, dynamic> data, pw.Font font, pw.Font fontBold) {
  final List<dynamic> workers = data['WorkersPairsSummary'] ?? [];

  debugPrint('Construyendo widgets para ${workers.length} trabajadores');

  if (workers.isEmpty) {
    return [
      pw.Text(
        'No hay datos de trabajadores',
        style: pw.TextStyle(fontSize: 12, font: font), // Aumentado de 8 a 12
        textAlign: pw.TextAlign.center,
      ),
    ];
  }

  List<pw.Widget> workersWidgets = [];

  for (int i = 0; i < workers.length; i++) {
    var worker = workers[i];
    debugPrint('Procesando trabajador $i: ${worker['Recolector']}');

    // NUEVO ORDEN: 1. LOTES (primero)
    if (worker['Lotes'] != null && worker['Lotes'].toString().isNotEmpty) {
      workersWidgets.addAll([
        pw.Text(
          'LOTES:',
          style: pw.TextStyle(
              fontSize: 11, // Aumentado de 7 a 11
              fontWeight: pw.FontWeight.bold,
              font: fontBold),
        ),
        pw.Text(
          _wrapText(worker['Lotes'].toString(), 35), // ORIGINAL: 35
          style: pw.TextStyle(
              fontSize: 11,
              font: font,
              lineSpacing: 1.2), // Aumentado de 7 a 11
        ),
        pw.SizedBox(height: 1.5), // Mayor espaciado
      ]);
    }

    // NUEVO ORDEN: 2. CAJA (segundo)
    String cajasText = '';
    if (worker.containsKey('Caja')) {
      // Nueva estructura: una caja por registro
      cajasText = worker['Caja']?.toString() ?? '';
      debugPrint('Usando nueva estructura - Caja: $cajasText');
    } else if (worker.containsKey('Cajas')) {
      // Estructura anterior: cajas concatenadas
      cajasText = worker['Cajas']?.toString() ?? '';
      debugPrint('Usando estructura anterior - Cajas: $cajasText');
    }

    if (cajasText.isNotEmpty) {
      workersWidgets.addAll([
        pw.Text(
          'CAJA${cajasText.contains(',') ? 'S' : ''}:', // Plural si hay múltiples cajas
          style: pw.TextStyle(
              fontSize: 11, // Aumentado de 7 a 11
              fontWeight: pw.FontWeight.bold,
              font: fontBold),
        ),
        pw.Text(
          _wrapText(cajasText, 35), // ORIGINAL: 35
          style: pw.TextStyle(
              fontSize: 11,
              font: font,
              lineSpacing: 1.2), // Aumentado de 7 a 11
        ),
        pw.SizedBox(height: 1.5), // Mayor espaciado
      ]);
    } else {
      debugPrint('No hay información de cajas para este trabajador');
    }

    workersWidgets.addAll([
      // ORDEN: 3. RECOLECTOR (tercero)
      pw.Text(
        'RECOLECTOR:',
        style: pw.TextStyle(
            fontSize: 11, // Aumentado de 7 a 11
            fontWeight: pw.FontWeight.bold,
            font: fontBold),
      ),
      pw.Text(
        _wrapText(worker['Recolector']?.toString() ?? '', 35), // ORIGINAL: 35
        style: pw.TextStyle(
            fontSize: 11, font: font, lineSpacing: 1.2), // Aumentado de 7 a 11
      ),
      pw.SizedBox(height: 1.5), // Mayor espaciado

      // ORDEN: 4. CORTERO (cuarto)
      pw.Text(
        'CORTERO:',
        style: pw.TextStyle(
            fontSize: 11, // Aumentado de 7 a 11
            fontWeight: pw.FontWeight.bold,
            font: fontBold),
      ),
      pw.Text(
        _wrapText(worker['Cortero']?.toString() ?? '', 35), // ORIGINAL: 35
        style: pw.TextStyle(
            fontSize: 11, font: font, lineSpacing: 1.2), // Aumentado de 7 a 11
      ),
      pw.SizedBox(height: 1.5), // Mayor espaciado

      // ORDEN: 5. Estadísticas en una línea (último) - ACTUALIZADO CON NEGRITA
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Racimos: ',
                  style: pw.TextStyle(
                      fontSize: 11, // Aumentado de 7 a 11
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold),
                ),
                pw.TextSpan(
                  text: '${worker['TotalRacimos'] ?? 0}',
                  style: pw.TextStyle(
                      fontSize: 11, // Aumentado de 7 a 11
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold),
                ),
              ],
            ),
          ),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Tusa: ',
                  style: pw.TextStyle(
                      fontSize: 11, // Aumentado de 7 a 11
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold),
                ),
                pw.TextSpan(
                  text: '${worker['TotalTusa'] ?? 0}',
                  style: pw.TextStyle(
                      fontSize: 11, // Aumentado de 7 a 11
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 1.5), // Mayor espaciado
    ]);

    // Línea separadora (excepto para el último)
    if (i < workers.length - 1) {
      workersWidgets.add(
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.grey400,
          margin: const pw.EdgeInsets.only(top: 4, bottom: 4), // Mayor margen
        ),
      );
    }
  }

  debugPrint('Generados ${workersWidgets.length} widgets');
  return workersWidgets;
}

String _wrapText(String text, int lineLength) {
  if (text.length <= lineLength) return text;

  // Dividir por espacios para mantener palabras completas
  final words = text.split(' ');
  final lines = <String>[];
  String currentLine = '';

  for (final word in words) {
    // Si agregar la palabra excede el límite
    if ((currentLine + (currentLine.isEmpty ? '' : ' ') + word).length >
        lineLength) {
      // Si la línea actual no está vacía, guardarla
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = word;
      } else {
        // Si la palabra sola es muy larga, cortarla
        if (word.length > lineLength) {
          lines.add(word.substring(0, lineLength));
          currentLine = word.substring(lineLength);
        } else {
          currentLine = word;
        }
      }
    } else {
      // Agregar la palabra a la línea actual
      currentLine += currentLine.isEmpty ? word : ' $word';
    }
  }

  // Agregar la última línea si no está vacía
  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines.join('\n');
}

Future<String> _savePDFFile(pw.Document pdf, String reportName) async {
  final String docsPath = await _getBestDocumentsPath();
  final DateTime now = DateTime.now();
  final String timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';

  final String fileName = '${reportName}_$timestamp.pdf';
  final String filePath = '$docsPath/$fileName';
  final File file = File(filePath);

  final Uint8List pdfBytes = await pdf.save();
  await file.writeAsBytes(pdfBytes, flush: true);

  debugPrint('PDF guardado en: $filePath');
  return filePath;
}

Future<void> _openPDF(String filePath, BuildContext context) async {
  try {
    final File file = File(filePath);
    if (await file.exists()) {
      // Usar flutter_pdfview para mejor control de la visualización
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(
            filePath: filePath,
            title: 'Reporte Térmico',
          ),
        ),
      );
    } else {
      throw Exception('El archivo PDF no existe');
    }
  } catch (e) {
    debugPrint('Error al abrir PDF: $e');
    throw Exception('No se pudo abrir el PDF: $e');
  }
}

Future<String> _getBestDocumentsPath() async {
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

Future<bool> _checkAndRequestStoragePermissions(BuildContext context) async {
  try {
    if (!Platform.isAndroid) return false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    if (sdkVersion >= 33) {
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

      if (photosStatus.isGranted && videosStatus.isGranted) return true;

      if (!context.mounted) return false;
      final shouldContinue = await _showPermissionExplanationDialog(
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

      if (!context.mounted) return false;
      final shouldContinue = await _showPermissionExplanationDialog(
        context,
        'Para guardar el PDF, se requiere permiso para gestionar el almacenamiento.',
      );
      if (!shouldContinue) return false;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    // Android 6 - 10
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    if (!context.mounted) return false;
    await _showPermissionExplanationDialog(
      context,
      'Se necesita permiso para guardar el PDF en el almacenamiento.',
    );

    final result = await Permission.storage.request();
    return result.isGranted;
  } catch (e) {
    debugPrint('Error solicitando permisos: $e');
    return false;
  }
}

Future<bool> _showPermissionExplanationDialog(
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

// Widget personalizado para visualizar PDF con flutter_pdfview
class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PDFViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
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
            fitPolicy: FitPolicy.WIDTH, // Ajustar al ancho de pantalla
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
            onViewCreated: (PDFViewController pdfViewController) {
              // PDF cargado exitosamente
              debugPrint('PDF cargado: ${widget.filePath}');
            },
            onLinkHandler: (String? uri) {
              debugPrint('Link presionado: $uri');
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
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
      // Implementar compartir PDF si es necesario
      debugPrint('Compartir PDF: ${widget.filePath}');
    } catch (e) {
      debugPrint('Error al compartir PDF: $e');
    }
  }

// 3. Agrega esta función auxiliar para mostrar errores:
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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

  void _printPDF() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Enviando a impresora...'),
            ],
          ),
        ),
      );

      // Leer el archivo PDF
      final File file = File(widget.filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorDialog('El archivo PDF no existe');
        return;
      }

      final Uint8List pdfBytes = await file.readAsBytes();

      // MÉTODO 1: Intentar con share en lugar de print
      try {
        if (!mounted) return;
        // Cerrar dialog de carga
        Navigator.pop(context);

        // Usar share que puede dirigir a impresoras
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${widget.title}_termica.pdf',
        );

        if (!mounted) return;
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 8),
                Text('📄 Seleccione su app de impresión térmica'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      } catch (shareError) {
        debugPrint('Error con share: $shareError');

        // MÉTODO 2: Si falla, intentar impresión directa simple
        await _tryDirectPrint(pdfBytes);
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      debugPrint('Error general: $e');
      _showErrorDialog('Error al procesar PDF: $e');
    }
  }

  Future<void> _tryDirectPrint(Uint8List pdfBytes) async {
    try {
      // NO usar layoutPdf que siempre abre preview
      // Usar solo directPrintPdf sin formato predefinido
      await Printing.directPrintPdf(
        printer: const Printer(url: ''), // Impresora por defecto
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: widget.title,
      );

      if (!mounted) return;
      // Cerrar loading si está abierto
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.print, color: Colors.white),
              SizedBox(width: 8),
              Text('🖨️ Enviado a impresora predeterminada'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (directError) {
      debugPrint('Error impresión directa: $directError');

      if (!mounted) return;
      // Cerrar loading si está abierto
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // ÚLTIMO RECURSO: Mostrar opción manual
      _showManualPrintDialog(pdfBytes);
    }
  }

// Dialog final para impresión manual (solo si todo falla)
  Future<void> _showManualPrintDialog(Uint8List pdfBytes) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Impresión Manual'),
        content: const Text('No se pudo imprimir automáticamente.\n\n'
            '¿Desea abrir el archivo para imprimir manualmente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Como último recurso, compartir el archivo
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: '${widget.title}.pdf',
              );
            },
            child: const Text('Compartir archivo'),
          ),
        ],
      ),
    );
  }

  Future<void> _printDirectlyToThermal(Uint8List pdfBytes) async {
    try {
      // Intentar impresión directa sin preview
      await Printing.directPrintPdf(
        printer: const Printer(url: ''), // Impresora predeterminada
        onLayout: (PdfPageFormat format) async {
          debugPrint('Imprimiendo directamente en formato térmico');
          return pdfBytes;
        },
        name: widget.title,
        format: const PdfPageFormat(
          58 * PdfPageFormat.mm, // Ancho térmico 58mm
          double.infinity, // Alto automático
          marginAll: 1 * PdfPageFormat.mm, // Márgenes mínimos
        ),
      );

      if (!mounted) return;
      // Mostrar confirmación de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('✅ Documento enviado a impresora térmica'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (directPrintError) {
      debugPrint('Error en impresión directa: $directPrintError');

      // Si falla impresión directa, usar método alternativo
      await _fallbackThermalPrint(pdfBytes);
    }
  }

  Future<void> _fallbackThermalPrint(Uint8List pdfBytes) async {
    try {
      debugPrint('Usando método alternativo de impresión térmica');

      final messenger = ScaffoldMessenger.of(context);
      // Mostrar el dialog de impresión del sistema pero con configuración térmica
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          // Mostrar mensaje sobre configuración térmica
          WidgetsBinding.instance.addPostFrameCallback((_) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  '🎫 Configuración automática: 58mm ancho - Presione IMPRIMIR',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          });

          return pdfBytes;
        },
        name: '${widget.title} (TERMICA)',
        format: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 1 * PdfPageFormat.mm,
        ),
      );
    } catch (e) {
      debugPrint('Error en método alternativo: $e');
      _showErrorDialog('Error al configurar impresión térmica: $e');
    }
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
