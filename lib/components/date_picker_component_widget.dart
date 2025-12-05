import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'date_picker_component_model.dart';
export 'date_picker_component_model.dart';

class DatePickerComponentWidget extends StatefulWidget {
  const DatePickerComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
  })  : this.tittle = tittle ?? 'Seleccionar Fecha',
        this.idStepParent = idStepParent ?? 0;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;

  @override
  State<DatePickerComponentWidget> createState() =>
      _DatePickerComponentWidgetState();
}

class _DatePickerComponentWidgetState extends State<DatePickerComponentWidget>
    with TickerProviderStateMixin {
  late DatePickerComponentModel _model;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DatePickerComponentModel());

    // Animación de deslizamiento
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();

    // Cargar fecha existente si hay
    _loadExistingDate();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDate() async {
    final existingDate = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingDate.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(existingDate);
        setState(() {
          _model.selectedDate = parsedDate;
          _model.isDateSelected = true;
        });
      } catch (e) {
        debugPrint('Error parsing existing date: $e');
      }
    } else {
      // Si no hay fecha existente, establecer la fecha actual por defecto
      final today = DateTime.now();
      setState(() {
        _model.selectedDate = today;
        _model.isDateSelected = true;
      });
      // Guardar la fecha actual automáticamente
      await _saveDate(today);
    }
  }

  void _onDateSelected(DateTime date) {
    HapticFeedback.heavyImpact();

    setState(() {
      _model.selectedDate = date;
      _model.isDateSelected = true;
      _model.showCalendar = false;
    });

    _saveDate(date);
  }

  void _onCancelCalendar() {
    HapticFeedback.lightImpact();
    setState(() {
      _model.showCalendar = false;
    });
  }

  Future<void> _saveDate(DateTime date) async {
    final dateString = date.toIso8601String();

    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      dateString,
      getJsonField(widget.statusJSON, r'''$.remember_status'''),
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy!.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});
  }

  Future<void> _clearDate() async {
    HapticFeedback.lightImpact();

    setState(() {
      _model.selectedDate = null;
      _model.isDateSelected = false;
    });

    await _saveDate(DateTime(1900));
  }

  String _formatDate(DateTime date) {
    // Formato: "Miércoles 25 de Julio 2025"
    final dayName = DateFormat('EEEE', 'es_ES').format(date);
    final day = date.day;
    final month = DateFormat('MMMM', 'es_ES').format(date);
    final year = date.year;

    // Capitalizar primera letra del día y del mes
    final capitalizedDay = dayName[0].toUpperCase() + dayName.substring(1);
    final capitalizedMonth = month[0].toUpperCase() + month.substring(1);

    return '$capitalizedDay $day de $capitalizedMonth $year';
  }

  String _getShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getDayOfWeek(DateTime date) {
    final dayName = DateFormat('EEEE', 'es_ES').format(date);
    return dayName[0].toUpperCase() + dayName.substring(1);
  }

  String _getMonth(DateTime date) {
    final month = DateFormat('MMMM', 'es_ES').format(date);
    return month[0].toUpperCase() + month.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📅 DatePickerComponent build - showCalendar: ${_model.showCalendar}');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
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
          child: SlideTransition(
            position: _slideAnimation,
            child: _model.showCalendar
              ? _InlineCalendarView(
                  initialDate: _model.selectedDate ?? DateTime.now(),
                  primaryColor: FlutterFlowTheme.of(context).primary,
                  secondaryColor: FlutterFlowTheme.of(context).secondary,
                  onDateSelected: _onDateSelected,
                  onCancel: _onCancelCalendar,
                )
              : Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Header
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 10.0),
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
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
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
                          if (_model.isDateSelected)
                            InkWell(
                              onTap: _clearDate,
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

                    // Visualización de fecha
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: _model.isDateSelected && _model.selectedDate != null
                            ? _buildDateDisplay()
                            : _buildEmptyState(),
                      ),
                    ),

                    // Botón de selección
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
                      child: InkWell(
                        onTap: () {
                          debugPrint('🔘 Botón "Seleccionar Fecha" presionado');
                          HapticFeedback.mediumImpact();
                          setState(() {
                            debugPrint('⚙️ Activando showCalendar = true');
                            _model.showCalendar = true;
                          });
                          debugPrint('✅ setState completado - showCalendar: ${_model.showCalendar}');
                        },
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
                                Icons.calendar_today_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                _model.isDateSelected
                                    ? 'Cambiar Fecha'
                                    : 'Seleccionar Fecha',
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
        ),
      ),
    );
  }

  Widget _buildDateDisplay() {
    final date = _model.selectedDate!;

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
          // Icono
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FlutterFlowTheme.of(context).primary,
                  FlutterFlowTheme.of(context).secondary,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      FlutterFlowTheme.of(context).primary.withOpacity(0.5),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.event_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),

          SizedBox(height: 32),

          // Día de la semana
          Text(
            _getDayOfWeek(date).toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 2,
            ),
          ),

          SizedBox(height: 8),

          // Día del mes
          Text(
            date.day.toString(),
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),

          SizedBox(height: 8),

          // Mes y año
          Text(
            '${_getMonth(date).toUpperCase()} ${date.year}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 1,
            ),
          ),

          SizedBox(height: 24),

          // Formato corto
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
              _getShortDate(date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
          Container(
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
              Icons.calendar_month_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 56,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Sin fecha seleccionada',
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
              'Toca el botón de abajo para\nseleccionar una fecha',
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
// CALENDARIO INLINE (SIN DIALOG)
// ============================================================================

class _InlineCalendarView extends StatefulWidget {
  final DateTime initialDate;
  final Color primaryColor;
  final Color secondaryColor;
  final Function(DateTime) onDateSelected;
  final VoidCallback onCancel;

  const _InlineCalendarView({
    required this.initialDate,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onDateSelected,
    required this.onCancel,
  });

  @override
  State<_InlineCalendarView> createState() => _InlineCalendarViewState();
}

class _InlineCalendarViewState extends State<_InlineCalendarView> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  void _selectToday() {
    final today = DateTime.now();
    setState(() {
      _currentMonth = DateTime(today.year, today.month);
      _selectedDate = today;
    });
  }

  String _getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Header con botón atrás
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onCancel();
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
                Text(
                  'Seleccionar Fecha',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 44),
              ],
            ),
          ),

          // Calendario
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
              // Header con mes/año y controles
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.secondaryColor],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: Icon(Icons.chevron_left, color: Colors.white, size: 28),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _getMonthName(_currentMonth.month),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_currentMonth.year}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: Icon(Icons.chevron_right, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Botón HOY
                    InkWell(
                      onTap: _selectToday,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          'HOY',
                          style: GoogleFonts.inter(
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

              // Días de la semana
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                color: Colors.white.withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                      .map((day) => SizedBox(
                            width: 40,
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

              // Calendario
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildCalendarGrid(),
                ),
              ),

              // Botones de acción
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
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
                        onPressed: _selectedDate != null
                            ? () {
                                HapticFeedback.mediumImpact();
                                widget.onDateSelected(_selectedDate!);
                              }
                            : null,
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
                          style: GoogleFonts.inter(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // Lunes = 1, Domingo = 7
    int firstWeekday = firstDayOfMonth.weekday;

    final List<Widget> dayWidgets = [];

    // Días vacíos al inicio
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(SizedBox(width: 40, height: 40));
    }

    // Días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected = _selectedDate != null &&
          date.year == _selectedDate!.year &&
          date.month == _selectedDate!.month &&
          date.day == _selectedDate!.day;
      final isToday = date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;

      dayWidgets.add(
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [widget.primaryColor, widget.secondaryColor],
                    )
                  : null,
              color: isToday && !isSelected
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: widget.primaryColor.withOpacity(0.5), width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.5),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? widget.primaryColor
                          : Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }
}
