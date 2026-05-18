import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'advanced_sync_dialog_model.dart';
export 'advanced_sync_dialog_model.dart';

/// Diálogo de Sincronización Completa con Funciones Avanzadas
///
/// Este diálogo moderno permite al usuario:
/// 1. Ver ruta optimizada por IA
/// 2. Descargar plantas y coordenadas del lote actual
/// 3. Sincronizar: headquarters_coordinates, virtual_points, type_points, products, products_coordinates
///
/// Evalúa el campo is_sync_full de la actividad:
/// - Si is_sync_full es true: Sincronización OBLIGATORIA (solo botón Sincronizar y Volver)
/// - Si is_sync_full es false/null: Sincronización OPCIONAL (botones Sincronizar y Omitir)
class AdvancedSyncDialogWidget extends StatefulWidget {
  const AdvancedSyncDialogWidget({
    super.key,
    required this.onSyncNow,
    required this.onSkip,
    this.lastSyncInfo,
  });

  final Future<void> Function() onSyncNow;
  final VoidCallback onSkip;

  /// Texto con la última fecha de sincronización por lote.
  /// Ejemplo: "QA10: hace 2 días\nQA28: Nunca sincronizado"
  final String? lastSyncInfo;

  @override
  State<AdvancedSyncDialogWidget> createState() =>
      _AdvancedSyncDialogWidgetState();
}

class _AdvancedSyncDialogWidgetState extends State<AdvancedSyncDialogWidget>
    with TickerProviderStateMixin {
  late AdvancedSyncDialogModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdvancedSyncDialogModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fuente única de verdad: campo is_sync_full del activitySelectedJSON
    final activityJSON = context.watch<FFAppState>().activitySelectedJSON;
    final isSyncMandatory = activityJSON != null &&
        (getJsonField(activityJSON, r'''$.is_sync_full''') == true ||
            getJsonField(activityJSON, r'''$.is_sync_full''') == 1);

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 340,
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isSyncMandatory
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF00a86b))
                  .withValues(alpha: 0.4),
              blurRadius: 50,
              spreadRadius: 8,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF003420).withValues(alpha: 0.98),
                    const Color(0xFF002415).withValues(alpha: 0.98),
                    const Color(0xFF00150A).withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isSyncMandatory
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF00a86b))
                      .withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header decorativo brillante
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isSyncMandatory
                            ? [
                                Colors.transparent,
                                const Color(0xFFFF8E53),
                                const Color(0xFFFF6B6B),
                                const Color(0xFFFF8E53),
                                Colors.transparent,
                              ]
                            : [
                                Colors.transparent,
                                const Color(0xFF00ff9f),
                                const Color(0xFF00a86b),
                                const Color(0xFF00ff9f),
                                Colors.transparent,
                              ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Ícono y título en fila compacta
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isSyncMandatory
                                  ? [
                                      const Color(0xFFFF6B6B).withValues(alpha: 0.35),
                                      const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                                    ]
                                  : [
                                      const Color(0xFF00a86b).withValues(alpha: 0.35),
                                      const Color(0xFF00a86b).withValues(alpha: 0.2),
                                    ],
                            ),
                            border: Border.all(
                              color: (isSyncMandatory
                                      ? const Color(0xFFFF8E53)
                                      : const Color(0xFF00ff9f))
                                  .withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.cloud_sync_rounded,
                            size: 24,
                            color: isSyncMandatory
                                ? const Color(0xFFFF8E53)
                                : const Color(0xFF00ff9f),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isSyncMandatory
                                        ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                                        : [const Color(0xFF00ff9f), const Color(0xFF00a86b)],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  isSyncMandatory
                                      ? 'Sincronización Obligatoria'
                                      : 'Sincronización Completa',
                                  style: const TextStyle(fontFamily: 'Roboto',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                isSyncMandatory
                                    ? 'Requerida por la Actividad'
                                    : 'Funciones Avanzadas',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (isSyncMandatory
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF00ff9f))
                                      .withValues(alpha: 0.8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Características incluidas - compactas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureItemCompact(
                          icon: Icons.route_rounded,
                          title: 'Ruta IA',
                        ),
                        _buildFeatureItemCompact(
                          icon: Icons.download_rounded,
                          title: 'Plantas',
                        ),
                        _buildFeatureItemCompact(
                          icon: Icons.location_on_rounded,
                          title: 'Coords',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Última sincronización por lote (solo cuando se provee)
                  if (widget.lastSyncInfo != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              color: Color(0xFF60A5FA),
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ÚLTIMA SINCRONIZACIÓN',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF60A5FA),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.lastSyncInfo!,
                                    style: const TextStyle(fontFamily: 'Roboto',
                                      fontSize: 11,
                                      color: Color(0xFFBFDBFE),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Advertencia compacta
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSyncMandatory
                              ? [
                                  const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                  const Color(0xFFFF8E53).withValues(alpha: 0.08),
                                ]
                              : [
                                  const Color(0xFFFFA726).withValues(alpha: 0.15),
                                  const Color(0xFFFF9800).withValues(alpha: 0.08),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isSyncMandatory
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFA726))
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              isSyncMandatory
                                  ? Icons.warning_rounded
                                  : Icons.wifi_rounded,
                              color: isSyncMandatory
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFA726),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSyncMandatory
                                    ? 'Requiere sincronización para continuar'
                                    : 'Se necesita conexión a internet',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (isSyncMandatory
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFFFFA726))
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Botón SINCRONIZAR AHORA (principal)
                        InkWell(
                          onTap: _model.isSyncing
                              ? null
                              : () async {
                                  setState(() {
                                    _model.isSyncing = true;
                                  });

                                  try {
                                    await widget.onSyncNow();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(true);
                                  } catch (e) {
                                    debugPrint('Error en sincronización: $e');
                                    if (mounted) {
                                      setState(() {
                                        _model.isSyncing = false;
                                      });
                                    }
                                  }
                                },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: _model.isSyncing
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.withValues(alpha: 0.5),
                                        Colors.grey.withValues(alpha: 0.3),
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF00ff9f),
                                        Color(0xFF00a86b),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _model.isSyncing
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF00a86b)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: _model.isSyncing
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Sincronizando...',
                                          style: TextStyle(fontFamily: 'Roboto',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_download_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'SINCRONIZAR',
                                          style: TextStyle(fontFamily: 'Roboto',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Botón secundario: OMITIR o VOLVER según si es obligatorio
                        InkWell(
                          onTap: _model.isSyncing
                              ? null
                              : () {
                                  if (isSyncMandatory) {
                                    Navigator.of(context).pop(false);
                                  } else {
                                    widget.onSkip();
                                    Navigator.of(context).pop(false);
                                  }
                                },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSyncMandatory
                                    ? [
                                        const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                                        const Color(0xFFFF8E53).withValues(alpha: 0.06),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.12),
                                        Colors.white.withValues(alpha: 0.06),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSyncMandatory
                                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSyncMandatory)
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      color: const Color(0xFFFF6B6B).withValues(alpha: 
                                          _model.isSyncing ? 0.4 : 0.9),
                                      size: 16,
                                    ),
                                  if (isSyncMandatory) const SizedBox(width: 6),
                                  Text(
                                    isSyncMandatory
                                        ? 'VOLVER'
                                        : 'OMITIR',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: (isSyncMandatory
                                              ? const Color(0xFFFF6B6B)
                                              : Colors.white)
                                          .withValues(alpha: 
                                              _model.isSyncing ? 0.4 : 0.85),
                                      letterSpacing: 0.5,
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

                  const SizedBox(height: 14),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItemCompact({
    required IconData icon,
    required String title,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF00a86b).withValues(alpha: 0.3),
                const Color(0xFF00a86b).withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00ff9f).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF00ff9f),
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
