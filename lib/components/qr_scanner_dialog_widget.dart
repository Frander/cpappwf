import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;

/// Diálogo moderno para escanear códigos QR
/// Diseño elegante con animaciones sutiles y alto rendimiento
class QrScannerDialogWidget extends StatefulWidget {
  const QrScannerDialogWidget({
    super.key,
    this.title = 'Escanear QR',
    this.subtitle = 'Alinee el código QR dentro del marco',
  });

  final String title;
  final String subtitle;

  @override
  State<QrScannerDialogWidget> createState() => _QrScannerDialogWidgetState();
}

class _QrScannerDialogWidgetState extends State<QrScannerDialogWidget>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _borderAnimationController;
  late Animation<double> _borderAnimation;

  bool _isScanning = true;
  bool _hasScanned = false;
  String? _scannedValue;
  String? _errorMessage;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      // Escáner QR no disponible en Windows — no inicializar MobileScannerController
      return;
    }

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Animación sutil para el borde del escáner
    _borderAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _borderAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _borderAnimationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _hasScanned = true;
          _isScanning = false;
          _scannedValue = barcode.rawValue;
        });

        HapticFeedback.mediumImpact();
        _scannerController.stop();

        // Pequeño delay para mostrar el estado de éxito
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pop(context, _scannedValue);
          }
        });
        break;
      }
    }
  }

  void _toggleTorch() {
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
    _scannerController.toggleTorch();
    HapticFeedback.lightImpact();
  }

  void _retryScanning() {
    setState(() {
      _hasScanned = false;
      _isScanning = true;
      _scannedValue = null;
      _errorMessage = null;
    });
    _scannerController.start();
    HapticFeedback.lightImpact();
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
            Color(0xFF003420),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Área del escáner
            Expanded(
              child: _hasScanned
                  ? _buildSuccessState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildScannerArea(),
            ),

            // Controles inferiores
            if (_isScanning) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Botón cerrar
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 16),

          // Título
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00a86b),
                        const Color(0xFF00a86b).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CÓDIGO QR',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildScannerArea() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cámara
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _errorMessage = 'No se pudo acceder a la cámara';
                      });
                    }
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),

        // Overlay oscuro con hueco transparente
        _buildScannerOverlay(),

        // Marco animado del escáner
        _buildAnimatedFrame(),

        // Instrucciones
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: CustomPaint(
          size: Size.infinite,
          painter: _ScannerOverlayPainter(
            borderRadius: 24,
            scanAreaSize: 240,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFrame() {
    return AnimatedBuilder(
      animation: _borderAnimation,
      builder: (context, child) {
        return Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00a86b).withValues(alpha: _borderAnimation.value),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00a86b).withValues(alpha: 0.2 * _borderAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Esquinas decorativas
              _buildCorner(Alignment.topLeft, 0),
              _buildCorner(Alignment.topRight, 90),
              _buildCorner(Alignment.bottomRight, 180),
              _buildCorner(Alignment.bottomLeft, 270),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment, double rotation) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF00a86b), width: 4),
              left: BorderSide(color: Color(0xFF00a86b), width: 4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón de linterna
          InkWell(
            onTap: _toggleTorch,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _torchEnabled
                    ? const Color(0xFF00a86b).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _torchEnabled
                      ? const Color(0xFF00a86b)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _torchEnabled ? Icons.flash_on : Icons.flash_off,
                color: _torchEnabled ? const Color(0xFF00a86b) : Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono de éxito
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00a86b),
                  const Color(0xFF00a86b).withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00a86b).withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            '¡CÓDIGO ESCANEADO!',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _scannedValue ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de error
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.orange,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'ERROR DE CÁMARA',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),

            // Botón reintentar
            InkWell(
              onTap: _retryScanning,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00a86b), Color(0xFF008855)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00a86b).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Reintentar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
}

/// Painter para el overlay oscuro con hueco transparente
class _ScannerOverlayPainter extends CustomPainter {
  final double borderRadius;
  final double scanAreaSize;

  _ScannerOverlayPainter({
    required this.borderRadius,
    required this.scanAreaSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanAreaRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        scanAreaRect,
        const Radius.circular(16),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
