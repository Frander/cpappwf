import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    with SingleTickerProviderStateMixin {
  String _code = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 8).chain(
      CurveTween(curve: Curves.easeInOut),
    ).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_code.length < 12 && !_isProcessing) {
      HapticFeedback.lightImpact();
      setState(() {
        _code += number;
      });
    }
  }

  void _onDeletePressed() {
    if (_code.isNotEmpty && !_isProcessing) {
      HapticFeedback.lightImpact();
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  void _onClearPressed() {
    if (!_isProcessing) {
      HapticFeedback.mediumImpact();
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
        top: true,
        bottom: true,
        left: true,
        right: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).viewPadding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),

            // Header compacto: icono + título en una fila
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF003420), Color(0xFF00a86b)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x6600a86b),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de Supervisor',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ingrese el código para continuar',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Display del código con animación de shake
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.85,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0x0DFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _code.isEmpty
                            ? const Color(0x33FFFFFF)
                            : const Color(0xFF00a86b),
                        width: 2,
                      ),
                      boxShadow: _code.isNotEmpty
                          ? const [
                              BoxShadow(
                                color: Color(0x4D00a86b),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : const [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_code.isEmpty)
                          const Text(
                            'Ingrese el código',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: Color(0x6BFFFFFF),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              _code.length,
                              (index) => Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00a86b),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          '${_code.length}/12',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Color(0x80FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Teclado numérico
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
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
                  const SizedBox(height: 16),
                  // Fila 4-5-6
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('4'),
                      _buildNumberButton('5'),
                      _buildNumberButton('6'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Fila 7-8-9
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('7'),
                      _buildNumberButton('8'),
                      _buildNumberButton('9'),
                    ],
                  ),
                  const SizedBox(height: 16),
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

            const SizedBox(height: 14),

            // Botón de confirmar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GestureDetector(
                onTap: _code.isEmpty || _isProcessing ? null : _onConfirmPressed,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: _code.isEmpty || _isProcessing
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF616161),
                              Color(0xFF757575),
                            ],
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF003420),
                              Color(0xFF00a86b),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _code.isNotEmpty && !_isProcessing
                        ? const [
                            BoxShadow(
                              color: Color(0x8000a86b),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: _isProcessing
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : const Row(
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
                                style: TextStyle(
                                  fontFamily: 'Roboto',
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

            const SizedBox(height: 10),

            // Espaciado adicional para evitar botones de navegación
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom > 0
                ? 0
                : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: _isProcessing ? null : () => _onNumberPressed(number),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xCC1E293B),
              Color(0x99004629),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0x4D00a86b),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontFamily: 'Roboto',
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
    return GestureDetector(
      onTap: _isProcessing ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
