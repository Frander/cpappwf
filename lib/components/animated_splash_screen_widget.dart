import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

class AnimatedSplashScreenWidget extends StatefulWidget {
  const AnimatedSplashScreenWidget({
    super.key,
    this.onAnimationComplete,
  });

  final VoidCallback? onAnimationComplete;

  @override
  State<AnimatedSplashScreenWidget> createState() =>
      _AnimatedSplashScreenWidgetState();
}

class _AnimatedSplashScreenWidgetState
    extends State<AnimatedSplashScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _showFirstCycle = true;
  int _cycleCount = 0;

  @override
  void initState() {
    super.initState();

    // Controlador de fade
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controlador de escala
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Animación de fade in/out
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Animación de escala
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    // Listener para controlar los ciclos
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Fade completado, esperar y luego fade out
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _fadeController.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        // Fade out completado
        _cycleCount++;

        if (_cycleCount >= 2) {
          // Después de 2 ciclos, completar
          widget.onAnimationComplete?.call();
        } else {
          // Iniciar otro ciclo
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _showFirstCycle = !_showFirstCycle;
              });
              _fadeController.forward();
              _scaleController.forward(from: 0);
            }
          });
        }
      }
    });

    // Iniciar animaciones
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fadeController.forward();
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF003420), // Verde oscuro
              Color(0xFF002415), // Verde muy oscuro
              Color(0xFF00150A), // Verde casi negro
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Efecto de partículas sutiles en el fondo.
            // RepaintBoundary aísla las 20 animaciones del resto del árbol,
            // evitando que cada tick invalide el logo y el fondo.
            // BoxShadow eliminado: causaba compilación de shaders Impeller
            // para cada partícula en el primer frame (→ 58+ frames saltados).
            RepaintBoundary(
              child: Stack(
                children: List.generate(20, (index) {
                  return Positioned(
                    left: (index * 50.0) % MediaQuery.of(context).size.width,
                    top: (index * 80.0) % MediaQuery.of(context).size.height,
                    child: AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: (0.1 + (index % 3) * 0.05) * _fadeAnimation.value,
                          child: Container(
                            width: 4 + (index % 4) * 2,
                            height: 4 + (index % 4) * 2,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00a86b),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),

            // Logo y texto animado
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícono del árbol con efecto glow
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFF00a86b).withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: Size(80, 80),
                                painter: PalmTreeIconPainter(
                                  color: Color(0xFF00a86b),
                                  glowIntensity: _fadeAnimation.value,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Texto "CLICKPALM" con efecto brillante
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF00ff9f),
                                  Color(0xFF00a86b),
                                  Color(0xFF007d51),
                                ],
                              ).createShader(bounds);
                            },
                            child: Text(
                              'CLICKPALM',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF00a86b).withOpacity(0.8),
                                    blurRadius: 20,
                                  ),
                                  Shadow(
                                    color: Color(0xFF00a86b).withOpacity(0.5),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Subtítulo con animación
                          Opacity(
                            opacity: _fadeAnimation.value * 0.7,
                            child: Text(
                              'Agricultural Solutions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 2,
                                color: Color(0xFF00a86b).withOpacity(0.8),
                              ),
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Indicador de carga animado
                          SizedBox(
                            width: 200,
                            height: 3,
                            child: Stack(
                              children: [
                                // Fondo
                                Container(
                                  width: double.infinity,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF00a86b).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Barra de progreso
                                AnimatedBuilder(
                                  animation: _fadeController,
                                  builder: (context, child) {
                                    return FractionallySizedBox(
                                      widthFactor: _fadeController.value,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF00a86b),
                                              Color(0xFF00ff9f),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF00a86b)
                                                  .withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CustomPainter para el ícono del árbol de palma con racimos
class PalmTreeIconPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;

  PalmTreeIconPainter({
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3 * glowIntensity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Dibujar glow
    canvas.drawCircle(Offset(centerX, centerY), size.width * 0.5, glowPaint);

    // Tronco del árbol
    final trunkPath = Path();
    trunkPath.moveTo(centerX - 3, size.height * 0.85);
    trunkPath.lineTo(centerX - 5, centerY + 2);
    trunkPath.lineTo(centerX + 5, centerY + 2);
    trunkPath.lineTo(centerX + 3, size.height * 0.85);
    trunkPath.close();
    canvas.drawPath(trunkPath, paint);

    // Hojas/ramas (forma de palma)
    final leafPaths = <Path>[];

    // Hoja izquierda superior
    final leftLeaf1 = Path();
    leftLeaf1.moveTo(centerX - 2, centerY);
    leftLeaf1.quadraticBezierTo(
      centerX - 20,
      centerY - 15,
      centerX - 25,
      centerY - 20,
    );
    leftLeaf1.quadraticBezierTo(
      centerX - 28,
      centerY - 22,
      centerX - 30,
      centerY - 20,
    );
    leftLeaf1.quadraticBezierTo(
      centerX - 25,
      centerY - 12,
      centerX,
      centerY - 5,
    );
    leftLeaf1.close();
    leafPaths.add(leftLeaf1);

    // Hoja derecha superior
    final rightLeaf1 = Path();
    rightLeaf1.moveTo(centerX + 2, centerY);
    rightLeaf1.quadraticBezierTo(
      centerX + 20,
      centerY - 15,
      centerX + 25,
      centerY - 20,
    );
    rightLeaf1.quadraticBezierTo(
      centerX + 28,
      centerY - 22,
      centerX + 30,
      centerY - 20,
    );
    rightLeaf1.quadraticBezierTo(
      centerX + 25,
      centerY - 12,
      centerX,
      centerY - 5,
    );
    rightLeaf1.close();
    leafPaths.add(rightLeaf1);

    // Hoja central superior
    final centerLeaf = Path();
    centerLeaf.moveTo(centerX, centerY);
    centerLeaf.quadraticBezierTo(
      centerX - 3,
      centerY - 25,
      centerX,
      centerY - 32,
    );
    centerLeaf.quadraticBezierTo(
      centerX + 3,
      centerY - 25,
      centerX,
      centerY,
    );
    centerLeaf.close();
    leafPaths.add(centerLeaf);

    // Hojas laterales medias
    final leftLeaf2 = Path();
    leftLeaf2.moveTo(centerX - 1, centerY + 5);
    leftLeaf2.quadraticBezierTo(
      centerX - 25,
      centerY - 5,
      centerX - 32,
      centerY - 8,
    );
    leftLeaf2.quadraticBezierTo(
      centerX - 28,
      centerY - 2,
      centerX,
      centerY + 8,
    );
    leftLeaf2.close();
    leafPaths.add(leftLeaf2);

    final rightLeaf2 = Path();
    rightLeaf2.moveTo(centerX + 1, centerY + 5);
    rightLeaf2.quadraticBezierTo(
      centerX + 25,
      centerY - 5,
      centerX + 32,
      centerY - 8,
    );
    rightLeaf2.quadraticBezierTo(
      centerX + 28,
      centerY - 2,
      centerX,
      centerY + 8,
    );
    rightLeaf2.close();
    leafPaths.add(rightLeaf2);

    // Dibujar todas las hojas
    for (var leaf in leafPaths) {
      canvas.drawPath(leaf, paint);
    }

    // Racimos (pequeños círculos agrupados)
    final racimoPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Racimo izquierdo
    _drawRacimo(canvas, racimoPaint, centerX - 15, centerY + 5, 3);

    // Racimo derecho
    _drawRacimo(canvas, racimoPaint, centerX + 15, centerY + 5, 3);

    // Racimo central
    _drawRacimo(canvas, racimoPaint, centerX, centerY - 5, 4);
  }

  void _drawRacimo(Canvas canvas, Paint paint, double x, double y, int count) {
    final radius = 1.5;
    final positions = [
      Offset(x, y),
      Offset(x - 2.5, y + 2),
      Offset(x + 2.5, y + 2),
      Offset(x - 1, y + 4),
      Offset(x + 1, y + 4),
    ];

    for (int i = 0; i < count && i < positions.length; i++) {
      canvas.drawCircle(positions[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(PalmTreeIconPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}
