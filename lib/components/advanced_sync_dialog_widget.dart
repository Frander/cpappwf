import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '/app_state.dart';
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
  });

  final Future<void> Function() onSyncNow;
  final VoidCallback onSkip;

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
    // Evaluar si la sincronización es obligatoria según el campo is_sync_full de la actividad
    final isSyncMandatory = () {
      final activityJSON = context.watch<FFAppState>().activitySelectedJSON;
      if (activityJSON != null) {
        final isSyncFull = getJsonField(activityJSON, r'''$.is_sync_full''');
        // Si is_sync_full es true (1 en SQLite), la sincronización es obligatoria
        return isSyncFull == true || isSyncFull == 1;
      }
      return false; // Por defecto, no es obligatoria
    }();

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isSyncMandatory
                      ? Color(0xFFFF6B6B)
                      : Color(0xFF00a86b))
                  .withOpacity(0.4),
              blurRadius: 50,
              spreadRadius: 8,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF003420).withOpacity(0.98),
                    Color(0xFF002415).withOpacity(0.98),
                    Color(0xFF00150A).withOpacity(0.98),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: (isSyncMandatory
                          ? Color(0xFFFF6B6B)
                          : Color(0xFF00a86b))
                      .withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header decorativo brillante
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isSyncMandatory
                            ? [
                                Colors.transparent,
                                Color(0xFFFF8E53),
                                Color(0xFFFF6B6B),
                                Color(0xFFFF8E53),
                                Colors.transparent,
                              ]
                            : [
                                Colors.transparent,
                                Color(0xFF00ff9f),
                                Color(0xFF00a86b),
                                Color(0xFF00ff9f),
                                Colors.transparent,
                              ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Ícono principal con animación
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Círculo exterior pulsante
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isSyncMandatory
                                ? [
                                    Color(0xFFFF6B6B).withOpacity(0.4),
                                    Color(0xFFFF6B6B).withOpacity(0.15),
                                    Colors.transparent,
                                  ]
                                : [
                                    Color(0xFF00a86b).withOpacity(0.4),
                                    Color(0xFF00a86b).withOpacity(0.15),
                                    Colors.transparent,
                                  ],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      // Círculo medio con borde brillante
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSyncMandatory
                                ? [
                                    Color(0xFFFF6B6B).withOpacity(0.35),
                                    Color(0xFFFF6B6B).withOpacity(0.2),
                                  ]
                                : [
                                    Color(0xFF00a86b).withOpacity(0.35),
                                    Color(0xFF00a86b).withOpacity(0.2),
                                  ],
                          ),
                          border: Border.all(
                            color: (isSyncMandatory
                                    ? Color(0xFFFF8E53)
                                    : Color(0xFF00ff9f))
                                .withOpacity(0.5),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isSyncMandatory
                                      ? Color(0xFFFF8E53)
                                      : Color(0xFF00ff9f))
                                  .withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.cloud_sync_rounded,
                          size: 48,
                          color: isSyncMandatory
                              ? Color(0xFFFF8E53)
                              : Color(0xFF00ff9f),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Título principal
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isSyncMandatory
                              ? [Color(0xFFFF6B6B), Color(0xFFFF8E53)]
                              : [Color(0xFF00ff9f), Color(0xFF00a86b)],
                        ).createShader(bounds);
                      },
                      child: Text(
                        isSyncMandatory
                            ? 'Sincronización Obligatoria'
                            : 'Sincronización Completa',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 6),

                  // Subtítulo
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      isSyncMandatory
                          ? 'Requerida por la Actividad'
                          : 'Funciones Avanzadas',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: (isSyncMandatory
                                ? Color(0xFFFF6B6B)
                                : Color(0xFF00ff9f))
                            .withOpacity(0.8),
                        letterSpacing: 1.2,
                        height: 1.3,
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Características incluidas
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildFeatureItem(
                          icon: Icons.route_rounded,
                          title: 'Ruta Optimizada por IA',
                          description:
                              'Calcula la mejor ruta para maximizar eficiencia',
                        ),
                        SizedBox(height: 12),
                        _buildFeatureItem(
                          icon: Icons.download_rounded,
                          title: 'Descarga de Plantas Completas',
                          description:
                              'Productos, coordenadas y puntos virtuales del lote',
                        ),
                        SizedBox(height: 12),
                        _buildFeatureItem(
                          icon: Icons.location_on_rounded,
                          title: 'Coordenadas de Alta Precisión',
                          description:
                              'Sincroniza headquarters_coordinates y types_points',
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Advertencia de conexión o mensaje de sincronización obligatoria
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSyncMandatory
                              ? [
                                  Color(0xFFFF6B6B).withOpacity(0.18),
                                  Color(0xFFFF8E53).withOpacity(0.12),
                                ]
                              : [
                                  Color(0xFFFFA726).withOpacity(0.18),
                                  Color(0xFFFF9800).withOpacity(0.12),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (isSyncMandatory
                                  ? Color(0xFFFF6B6B)
                                  : Color(0xFFFFA726))
                              .withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        (isSyncMandatory
                                                ? Color(0xFFFF6B6B)
                                                : Color(0xFFFFA726))
                                            .withOpacity(0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSyncMandatory
                                        ? Icons.warning_rounded
                                        : Icons.wifi_rounded,
                                    color: isSyncMandatory
                                        ? Color(0xFFFF6B6B)
                                        : Color(0xFFFFA726),
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSyncMandatory
                                            ? 'Sincronización Obligatoria'
                                            : 'Conexión Requerida',
                                        style: TextStyle(fontFamily: 'Roboto',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSyncMandatory
                                              ? Color(0xFFFF6B6B)
                                              : Color(0xFFFFA726),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        isSyncMandatory
                                            ? 'La actividad requiere sincronización completa antes de continuar'
                                            : 'Se necesita internet para sincronizar',
                                        style: TextStyle(fontFamily: 'Roboto',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (isSyncMandatory
                                                  ? Color(0xFFFF6B6B)
                                                  : Color(0xFFFFA726))
                                              .withOpacity(0.85),
                                          letterSpacing: 0.2,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Botones de acción
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
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
                                    if (mounted) {
                                      Navigator.of(context).pop(true);
                                    }
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
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _model.isSyncing
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.withOpacity(0.5),
                                        Colors.grey.withOpacity(0.3),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF00ff9f),
                                        Color(0xFF00a86b),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _model.isSyncing
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Color(0xFF00a86b)
                                            .withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: Offset(0, 10),
                                        spreadRadius: 2,
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: _model.isSyncing
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Sincronizando...',
                                          style: TextStyle(fontFamily: 'Roboto',
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_download_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'SINCRONIZAR AHORA',
                                          style: TextStyle(fontFamily: 'Roboto',
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12),

                        // Botón secundario: OMITIR o VOLVER según si es obligatorio
                        InkWell(
                          onTap: _model.isSyncing
                              ? null
                              : () {
                                  if (isSyncMandatory) {
                                    // Si es obligatorio, solo cerrar el diálogo y volver
                                    Navigator.of(context).pop(false);
                                  } else {
                                    // Si no es obligatorio, permitir omitir
                                    widget.onSkip();
                                    Navigator.of(context).pop(false);
                                  }
                                },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSyncMandatory
                                    ? [
                                        Color(0xFFFF6B6B).withOpacity(0.15),
                                        Color(0xFFFF8E53).withOpacity(0.08),
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.08),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSyncMandatory
                                    ? Color(0xFFFF6B6B).withOpacity(0.4)
                                    : Colors.white.withOpacity(0.25),
                                width: 1.8,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSyncMandatory)
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      color: Color(0xFFFF6B6B).withOpacity(
                                          _model.isSyncing ? 0.4 : 0.9),
                                      size: 20,
                                    ),
                                  if (isSyncMandatory) SizedBox(width: 8),
                                  Text(
                                    isSyncMandatory
                                        ? 'VOLVER'
                                        : 'OMITIR ESTE PASO',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: (isSyncMandatory
                                              ? Color(0xFFFF6B6B)
                                              : Colors.white)
                                          .withOpacity(
                                              _model.isSyncing ? 0.4 : 0.9),
                                      letterSpacing: 1.0,
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

                  SizedBox(height: 24),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Color(0xFF00a86b).withOpacity(0.3),
                Color(0xFF00a86b).withOpacity(0.15),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Color(0xFF00ff9f).withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: Color(0xFF00ff9f),
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
