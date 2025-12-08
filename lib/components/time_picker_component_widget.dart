import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'dart:math' as math;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'time_picker_component_model.dart';
export 'time_picker_component_model.dart';

class TimePickerComponentWidget extends StatefulWidget {
  const TimePickerComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
  })  : this.tittle = tittle ?? 'Seleccionar Hora',
        this.idStepParent = idStepParent ?? 0;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;

  @override
  State<TimePickerComponentWidget> createState() =>
      _TimePickerComponentWidgetState();
}

class _TimePickerComponentWidgetState extends State<TimePickerComponentWidget>
    with TickerProviderStateMixin {
  late TimePickerComponentModel _model;
  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TimePickerComponentModel());

    // Animación de rotación para las manecillas
    _rotateController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Cargar hora existente si hay
    _loadExistingTime();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingTime() async {
    final existingTime = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingTime.isNotEmpty) {
      try {
        final parts = existingTime.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          setState(() {
            _model.selectedTime = TimeOfDay(hour: hour, minute: minute);
            _model.isTimeSelected = true;
          });
        }
      } catch (e) {
        debugPrint('Error parsing existing time: $e');
      }
    } else {
      // Si no hay hora existente, establecer la hora actual por defecto
      final now = TimeOfDay.now();
      setState(() {
        _model.selectedTime = now;
        _model.isTimeSelected = true;
      });
      // Guardar la hora actual automáticamente
      await _saveTime(now);
    }
  }

  Future<void> _selectTime() async {
    HapticFeedback.mediumImpact();

    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _ModernTimePickerDialog(
        initialTime: _model.selectedTime ?? TimeOfDay.now(),
        primaryColor: FlutterFlowTheme.of(context).primary,
        secondaryColor: FlutterFlowTheme.of(context).secondary,
      ),
    );

    if (picked != null) {
      HapticFeedback.heavyImpact();

      setState(() {
        _model.selectedTime = picked;
        _model.isTimeSelected = true;
      });

      await _saveTime(picked);
    }
  }

  Future<void> _saveTime(TimeOfDay time) async {
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      timeString,
      getJsonField(widget.statusJSON, r'''$.remember_status'''),
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy!.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});
  }

  Future<void> _clearTime() async {
    HapticFeedback.lightImpact();

    setState(() {
      _model.selectedTime = null;
      _model.isTimeSelected = false;
    });

    await _saveTime(TimeOfDay(hour: 0, minute: 0));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTime12Hour(TimeOfDay time) {
    // Formato: "03:20 pm" (con leading zero y am/pm en minúsculas)
    final hour = (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod)
        .toString()
        .padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 10.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      child: Text(
                        widget.tittle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (_model.isTimeSelected)
                    InkWell(
                      onTap: _clearTime,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).error,
                              FlutterFlowTheme.of(context)
                                  .error
                                  .withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context)
                                  .error
                                  .withOpacity(0.4),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.clear,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 44),
                ],
              ),
            ),

            // Visualización de hora
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: _model.isTimeSelected && _model.selectedTime != null
                    ? _buildTimeDisplay()
                    : _buildEmptyState(),
              ),
            ),

            // Botón de selección
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
              child: InkWell(
                onTap: _selectTime,
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FlutterFlowTheme.of(context).primary,
                        FlutterFlowTheme.of(context).secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withOpacity(0.5),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        _model.isTimeSelected
                            ? 'Cambiar Hora'
                            : 'Seleccionar Hora',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }

  Widget _buildTimeDisplay() {
    final time = _model.selectedTime!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary.withOpacity(0.2),
            FlutterFlowTheme.of(context).secondary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withOpacity(0.3),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reloj analógico animado
          Stack(
            alignment: Alignment.center,
            children: [
              // Círculo del reloj
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
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
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withOpacity(0.5),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
              ),

              // Círculo interior
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E293B),
                ),
              ),

              // Marcas de horas
              ...List.generate(12, (index) {
                final angle = (index * 30 - 90) * math.pi / 180;
                return Transform.translate(
                  offset: Offset(
                    70 * math.cos(angle),
                    70 * math.sin(angle),
                  ),
                  child: Container(
                    width: index % 3 == 0 ? 4 : 2,
                    height: index % 3 == 0 ? 12 : 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),

              // Manecilla de horas
              Transform.rotate(
                angle: ((time.hour % 12) * 30 + time.minute * 0.5 - 90) *
                    math.pi /
                    180,
                child: Container(
                  width: 4,
                  height: 50,
                  margin: EdgeInsets.only(bottom: 50),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Manecilla de minutos
              Transform.rotate(
                angle: (time.minute * 6 - 90) * math.pi / 180,
                child: Container(
                  width: 3,
                  height: 70,
                  margin: EdgeInsets.only(bottom: 70),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Centro del reloj
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),

          SizedBox(height: 40),

          // Hora digital (24h)
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
              letterSpacing: 2,
            ),
          ),

          SizedBox(height: 16),

          // Hora formato 12h
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              _formatTime12Hour(time),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reloj animado
          RotationTransition(
            turns: _rotateAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary.withOpacity(0.3),
                    FlutterFlowTheme.of(context).secondary.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 56,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Sin hora seleccionada',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Toca el botón de abajo para\nseleccionar una hora',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELECTOR DE TIEMPO MODERNO Y FLEXIBLE
// ============================================================================

class _ModernTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Color primaryColor;
  final Color secondaryColor;

  const _ModernTimePickerDialog({
    required this.initialTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<_ModernTimePickerDialog> createState() => _ModernTimePickerDialogState();
}

class _ModernTimePickerDialogState extends State<_ModernTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  bool _is24HourFormat = true;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
  }

  void _incrementHour() {
    setState(() {
      _selectedHour = (_selectedHour + 1) % 24;
    });
    HapticFeedback.selectionClick();
  }

  void _decrementHour() {
    setState(() {
      _selectedHour = (_selectedHour - 1 + 24) % 24;
    });
    HapticFeedback.selectionClick();
  }

  void _incrementMinute() {
    setState(() {
      _selectedMinute = (_selectedMinute + 1) % 60;
    });
    HapticFeedback.selectionClick();
  }

  void _decrementMinute() {
    setState(() {
      _selectedMinute = (_selectedMinute - 1 + 60) % 60;
    });
    HapticFeedback.selectionClick();
  }

  void _setCurrentTime() {
    final now = TimeOfDay.now();
    setState(() {
      _selectedHour = now.hour;
      _selectedMinute = now.minute;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxWidth: 380, maxHeight: 550),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.secondaryColor],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Seleccionar Hora',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Botón AHORA
                    InkWell(
                      onTap: _setCurrentTime,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          'AHORA',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Selector de tiempo
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Horas
                      _buildTimeColumn(
                        value: _selectedHour,
                        onIncrement: _incrementHour,
                        onDecrement: _decrementHour,
                        label: 'HORA',
                      ),
                      SizedBox(width: 20),
                      // Separador
                      Text(
                        ':',
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(width: 20),
                      // Minutos
                      _buildTimeColumn(
                        value: _selectedMinute,
                        onIncrement: _incrementMinute,
                        onDecrement: _decrementMinute,
                        label: 'MIN',
                      ),
                    ],
                  ),
                ),
              ),

              // Botones de acción
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(
                            context,
                            TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: widget.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                        ),
                        child: Text(
                          'Confirmar',
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeColumn({
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón incrementar
        InkWell(
          onTap: onIncrement,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.primaryColor.withOpacity(0.3),
                  widget.secondaryColor.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        SizedBox(height: 16),
        // Valor
        Container(
          width: 100,
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.primaryColor, widget.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value.toString().padLeft(2, '0'),
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Botón decrementar
        InkWell(
          onTap: onDecrement,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.primaryColor.withOpacity(0.3),
                  widget.secondaryColor.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}
