import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '/home_page/home_page_widget.dart';
import '/custom_code/actions/index.dart' as actions;
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
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginPageModel());
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // Verificar si ya existe un usuario seleccionado de sesiones anteriores
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _checkAndNavigateIfUserSelected();
    });

    // Cargar usuarios desde SQLite al iniciar
    _loadUsersFromSqlite();

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

  // Cargar todos los usuarios desde SQLite
  Future<void> _loadUsersFromSqlite() async {
    try {
      final users = await actions.searchUsersSqlite('');
      if (mounted) {
        setState(() {
          _filteredUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuarios desde SQLite: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  // Función de debouncing para el filtrado - busca desde SQLite por nombre Y operID
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchUsersFromSqlite(_model.textController!.text.trim());
    });
  }

  Future<void> _searchUsersFromSqlite(String searchText) async {
    try {
      final users = await actions.searchUsersSqlite(searchText);
      if (mounted) {
        setState(() {
          _filteredUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error buscando usuarios en SQLite: $e');
    }
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

  // Verificar si ya existe un usuario seleccionado y navegar si es así
  Future<void> _checkAndNavigateIfUserSelected() async {
    try {
      final userSelected = FFAppState().userSelected;
      
      // Si existe un usuario válido, navegar directamente a HomePage
      if (userSelected.idUser != null && userSelected.idUser! > 0 &&
          userSelected.nameUser != null && userSelected.nameUser!.isNotEmpty) {
        
        debugPrint('✅ Usuario persistente detectado: ${userSelected.nameUser}');
        debugPrint('🚀 Navegando directamente a HomePage...');
        
        // Navegar a HomePage sin mostrar la selección
        if (mounted) {
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
        }
      }
    } catch (e) {
      debugPrint('Error al verificar usuario persistente: $e');
    }
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    children: [
                      // Logo y titulo en una sola fila
                      Row(
                        children: [
                          SizedBox(
                            width: 100,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/images/logo2_(1).png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 3,
                            height: 32,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inicio de sesion',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Seleccione un usuario',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Barra de busqueda compacta
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _model.textController,
                          focusNode: _model.textFieldFocusNode,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o codigo...',
                            hintStyle: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 18,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                            ),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _model.textController!,
                              builder: (context, value, child) {
                                return value.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _model.textController?.clear();
                                        },
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
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
                        if (_isLoadingUsers) {
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          );
                        }

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
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: userItem.length,
                          itemBuilder: (context, index) {
                            final user = userItem[index];
                            final initials = _getInitials(user.nameUser);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
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
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            // Avatar con iniciales
                                            Container(
                                              width: 44,
                                              height: 44,
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
                                                    color: const Color(0xFF004d2e).withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 10),

                                            // Informacion del usuario
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    user.nameUser,
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.tag,
                                                        size: 12,
                                                        color: FlutterFlowTheme.of(context).primary,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Codigo: ${user.operID}',
                                                        style: TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white.withValues(alpha: 0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Icono de navegacion
                                            Container(
                                              width: 32,
                                              height: 32,
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
                                                size: 14,
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
