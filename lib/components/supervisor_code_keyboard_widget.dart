import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

class SupervisorCodeKeyboardWidget extends StatefulWidget {
  const SupervisorCodeKeyboardWidget({
    super.key,
    required this.onCodeEntered,
  });

  final Future Function(String code) onCodeEntered;

  @override
  State<SupervisorCodeKeyboardWidget> createState() =>
      _SupervisorCodeKeyboardWidgetState();
}

class _SupervisorCodeKeyboardWidgetState
    extends State<SupervisorCodeKeyboardWidget>
    with TickerProviderStateMixin {
  String _code = '';
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_code.length < 12 && !_isProcessing) {
      setState(() {
        _code += number;
      });
    }
  }

  void _onDeletePressed() {
    if (_code.isNotEmpty && !_isProcessing) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  void _onClearPressed() {
    if (!_isProcessing) {
      setState(() {
        _code = '';
      });
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_code.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onCodeEntered(_code);
    } catch (e) {
      // Error, shake animation
      _shakeController.forward(from: 0);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void showError() {
    _shakeController.forward(from: 0);
    setState(() {
      _code = '';
      _isProcessing = false;
    });
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
            Color(0xFF003420),
          ],
        ),
      ),
      child: SafeArea(
        bottom: true,
        top: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20),

            // Header con icono animado
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.1);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF003420),
                          Color(0xFF00a86b),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00a86b).withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 24),

            // Título
            Text(
              'Código de Supervisor',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 12),

            Text(
              'Ingrese el código para continuar',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),

            SizedBox(height: 32),

            // Display del código con animación de shake
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.85,
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _code.isEmpty
                            ? Colors.white.withOpacity(0.2)
                            : Color(0xFF00a86b),
                        width: 2,
                      ),
                      boxShadow: _code.isNotEmpty
                          ? [
                              BoxShadow(
                                color: Color(0xFF00a86b).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: _code.isEmpty
                        ? Center(
                            child: Text(
                              'Ingrese el código',
                              style: TextStyle(fontFamily: 'Roboto',
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_code.length, (index) {
                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 200),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF00a86b),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFF00a86b).withOpacity(0.6 * value),
                                            blurRadius: 10 * value,
                                            spreadRadius: 2 * value,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                  ),
                );
              },
            ),

            SizedBox(height: 16),

            // Contador de dígitos
            Text(
              '${_code.length} / 12 dígitos',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),

            SizedBox(height: 24),

            // Teclado numérico
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // Fila 1-2-3
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('1'),
                      _buildNumberButton('2'),
                      _buildNumberButton('3'),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Fila 4-5-6
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('4'),
                      _buildNumberButton('5'),
                      _buildNumberButton('6'),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Fila 7-8-9
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('7'),
                      _buildNumberButton('8'),
                      _buildNumberButton('9'),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Fila clear-0-delete
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.clear_all,
                        onPressed: _onClearPressed,
                        color: Colors.orange,
                      ),
                      _buildNumberButton('0'),
                      _buildActionButton(
                        icon: Icons.backspace_outlined,
                        onPressed: _onDeletePressed,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Botón de confirmar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: InkWell(
                onTap: _code.isEmpty || _isProcessing ? null : _onConfirmPressed,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: _code.isEmpty || _isProcessing
                        ? LinearGradient(
                            colors: [
                              Colors.grey.shade700,
                              Colors.grey.shade600,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Color(0xFF003420),
                              Color(0xFF00a86b),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _code.isNotEmpty && !_isProcessing
                        ? [
                            BoxShadow(
                              color: Color(0xFF00a86b).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: _isProcessing
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'VALIDAR CÓDIGO',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: _isProcessing ? null : () => _onNumberPressed(number),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B).withOpacity(0.8),
              Color(0xFF004629).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF00a86b).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: _isProcessing ? null : onPressed,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
