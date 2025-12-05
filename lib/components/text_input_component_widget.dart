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
import 'text_input_component_model.dart';
export 'text_input_component_model.dart';

class TextInputComponentWidget extends StatefulWidget {
  const TextInputComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
    String? placeholder,
    int? maxLength,
    bool? multiline,
  })  : this.tittle = tittle ?? 'Ingresar Texto',
        this.idStepParent = idStepParent ?? 0,
        this.placeholder = placeholder ?? 'Escribe aquí...',
        this.maxLength = maxLength ?? 500,
        this.multiline = multiline ?? false;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;
  final String placeholder;
  final int maxLength;
  final bool multiline;

  @override
  State<TextInputComponentWidget> createState() =>
      _TextInputComponentWidgetState();
}

class _TextInputComponentWidgetState extends State<TextInputComponentWidget>
    with TickerProviderStateMixin {
  late TextInputComponentModel _model;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TextInputComponentModel());

    _textController = TextEditingController();
    _focusNode = FocusNode();

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

    // Cargar texto existente si hay
    _loadExistingText();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _slideController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingText() async {
    final existingText = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingText.isNotEmpty) {
      setState(() {
        _textController.text = existingText;
        _model.hasText = true;
      });
    }
  }

  Future<void> _saveText() async {
    final text = _textController.text.trim();

    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      text,
      getJsonField(widget.statusJSON, r'''$.remember_status'''),
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy!.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});

    HapticFeedback.mediumImpact();
  }

  Future<void> _clearText() async {
    HapticFeedback.lightImpact();

    setState(() {
      _textController.clear();
      _model.hasText = false;
    });

    await _saveText();
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
        child: SlideTransition(
          position: _slideAnimation,
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
                        padding: EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 0.0),
                        child: Text(
                          widget.tittle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (_model.hasText)
                      InkWell(
                        onTap: _clearText,
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
                            Icons.clear_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    else
                      SizedBox(width: 44),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Contenido principal
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Tarjeta con el campo de texto
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00a86b).withOpacity(0.15),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Ícono y título
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF00ff9f).withOpacity(0.3),
                                              Color(0xFF00a86b).withOpacity(0.3),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.edit_note_rounded,
                                          color: Color(0xFF00ff9f),
                                          size: 28,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.statusName,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Máximo ${widget.maxLength} caracteres',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 20),

                                  // Campo de texto
                                  Container(
                                    constraints: BoxConstraints(
                                      minHeight: widget.multiline ? 150 : 56,
                                      maxHeight: widget.multiline ? 300 : 56,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _focusNode.hasFocus
                                            ? Color(0xFF00ff9f)
                                            : Colors.white.withOpacity(0.2),
                                        width: _focusNode.hasFocus ? 2 : 1.5,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _textController,
                                      focusNode: _focusNode,
                                      maxLength: widget.maxLength,
                                      maxLines: widget.multiline ? null : 1,
                                      minLines: widget.multiline ? 6 : 1,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: widget.placeholder,
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.4),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        counterStyle: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _model.hasText = value.trim().isNotEmpty;
                                        });
                                      },
                                    ),
                                  ),

                                  if (_model.hasText) ...[
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Color(0xFF00ff9f),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Texto ingresado: ${_textController.text.trim().length} caracteres',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botón de guardar
              Padding(
                padding: EdgeInsets.all(20),
                child: InkWell(
                  onTap: () async {
                    await _saveText();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00ff9f),
                          Color(0xFF00a86b),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00a86b).withOpacity(0.4),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Guardar',
                            style: GoogleFonts.inter(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
