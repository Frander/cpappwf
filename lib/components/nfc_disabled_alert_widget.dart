import 'package:flutter/material.dart';
import 'dart:async';

/// Diálogo elegante para alertar cuando NFC está desactivado
class NfcDisabledAlertWidget extends StatefulWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback? onCancel;

  const NfcDisabledAlertWidget({
    super.key,
    this.onOpenSettings,
    this.onCancel,
  });

  @override
  State<NfcDisabledAlertWidget> createState() => _NfcDisabledAlertWidgetState();

  /// Muestra el diálogo de NFC desactivado
  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NFC Disabled Alert',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NfcDisabledAlertWidget(
          onOpenSettings: () {
            Navigator.of(context).pop(true);
          },
          onCancel: () {
            Navigator.of(context).pop(false);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}

class _NfcDisabledAlertWidgetState extends State<NfcDisabledAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono animado de NFC
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                            const Color(0xFFFF8E8E).withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.nfc_rounded,
                        size: 40,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Título
                  const Text(
                    'NFC Desactivado',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Descripción
                  Text(
                    'Para leer etiquetas NFC necesitas activar la función NFC en tu dispositivo.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Instrucciones
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Color(0xFF4FC3F7),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ajustes > Conexiones > NFC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Botones
                  Row(
                    children: [
                      // Botón Cancelar
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botón Abrir Ajustes
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: widget.onOpenSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.settings_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Abrir Ajustes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
