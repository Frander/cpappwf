import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/home_page/home_page_widget.dart';
import 'login_page_model.dart';
export 'login_page_model.dart';

class LoginPageWidget extends StatefulWidget {
  const LoginPageWidget({super.key});

  static String routeName = 'LoginPage';
  static String routePath = '/loginPage';

  @override
  State<LoginPageWidget> createState() => _LoginPageWidgetState();
}

class _LoginPageWidgetState extends State<LoginPageWidget> {
  late LoginPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Variables para optimizar el filtrado
  Timer? _debounceTimer;
  List<UsersStruct> _filteredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginPageModel());
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // Inicializar lista filtrada con todos los usuarios
    _filteredUsers = FFAppState().usersList.toList();

    // Agregar listener con debouncing al TextEditingController
    _model.textController!.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _model.textController!.removeListener(_onSearchChanged);
    _model.dispose();
    super.dispose();
  }

  // Función de debouncing para el filtrado - busca por nombre Y operID
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        final searchText = _model.textController!.text.toLowerCase().trim();
        if (searchText.isEmpty) {
          _filteredUsers = FFAppState().usersList.toList();
        } else {
          _filteredUsers = FFAppState().usersList.where((user) {
            final nameMatch = user.nameUser.toLowerCase().contains(searchText);
            final operIdMatch = user.operID.toLowerCase().contains(searchText);
            return nameMatch || operIdMatch;
          }).toList();
        }
      });
    });
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Manejar selección de usuario
  Future<void> _onUserSelected(UsersStruct user) async {
    setState(() => _isLoading = true);

    try {
      // Guardar usuario seleccionado
      FFAppState().userSelected = user;
      FFAppState().update(() {});

      debugPrint('✅ Usuario seleccionado: ${user.nameUser}');

      // Navegar a HomePage
      if (Navigator.of(context).canPop()) {
        context.pop();
      }
      context.pushNamed(
        HomePageWidget.routeName,
        extra: <String, dynamic>{
          kTransitionInfoKey: const TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.fade,
            duration: Duration(milliseconds: 300),
          ),
        },
      );
    } catch (e) {
      debugPrint('Error en selección de usuario: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header moderno
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      // Fila con logo centrado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          SizedBox(
                            width: 150,
                            height: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo2_(1).png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Titulo principal
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  FlutterFlowTheme.of(context).primary,
                                  FlutterFlowTheme.of(context).secondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inicio de sesion ClickPalm',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Seleccione un usuario para ingresar a la aplicacion',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Barra de busqueda
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _model.textController,
                          focusNode: _model.textFieldFocusNode,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o codigo...',
                            hintStyle: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 22,
                            ),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _model.textController!,
                              builder: (context, value, child) {
                                return value.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _model.textController?.clear();
                                        },
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de usuarios
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Builder(
                      builder: (context) {
                        final userItem = _filteredUsers;

                        if (userItem.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
                                        FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.2),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_search,
                                    size: 60,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No se encontraron usuarios',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Intenta con otro termino de busqueda',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 16, bottom: 20),
                          itemCount: userItem.length,
                          itemBuilder: (context, index) {
                            final user = userItem[index];
                            final initials = _getInitials(user.nameUser);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: _isLoading ? null : () => _onUserSelected(user),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Avatar con iniciales
                                            Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF006847),
                                                    Color(0xFF003d29),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF004d2e).withValues(alpha: 0.5),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 16),

                                            // Informacion del usuario
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.nameUser,
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                                                          FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.3),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.5),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.tag,
                                                          size: 14,
                                                          color: FlutterFlowTheme.of(context).primary,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Codigo: ${user.operID}',
                                                          style: TextStyle(
                                                            fontFamily: 'Roboto',
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white.withValues(alpha: 0.9),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Icono de navegacion
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    FlutterFlowTheme.of(context).primary,
                                                    FlutterFlowTheme.of(context).secondary,
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_ios,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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
}
