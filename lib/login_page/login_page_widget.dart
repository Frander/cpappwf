import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/device_transfer_service.dart';
import '/adb_install_page/adb_install_page_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import '/home_page/home_page_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/backend/sqlite/global_db_singleton.dart';
import '/release_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page_model.dart';
export 'login_page_model.dart';

class LoginPageWidget extends StatefulWidget {
  const LoginPageWidget({
    super.key,
    this.forceSelection = false,
  });

  /// Si es true, siempre muestra la lista aunque ya haya un usuario seleccionado.
  /// Usar al navegar desde la app para cambiar de operador.
  final bool forceSelection;

  static String routeName = 'LoginPage';
  static String routePath = '/loginPage';

  @override
  State<LoginPageWidget> createState() => _LoginPageWidgetState();
}

class _LoginPageWidgetState extends State<LoginPageWidget> {
  late LoginPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Timer? _debounceTimer;
  List<UsersStruct> _filteredUsers = [];
  bool _isLoading = false;
  bool _isLoadingUsers = true;

  // ── Primer inicio: detección de conectividad ────────────────────────────
  bool _showUsbTransferOption = false;
  bool _showNoConnectionError = false;
  bool _isDownloadingDb = false;
  double _downloadProgress = 0.0;
  String? _detectedGatewayUrl;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginPageModel());
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!widget.forceSelection) {
        _checkAndNavigateIfUserSelected();
      }
    });

    _loadUsersFromSqlite();
    _model.textController!.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _model.textController!.removeListener(_onSearchChanged);
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadUsersFromSqlite() async {
    try {
      final users = await actions.searchUsersSqlite('');
      if (mounted) {
        setState(() {
          _filteredUsers = users;
          _isLoadingUsers = false;
        });
        // Sin usuarios y no es modo cambio de operador → verificar primer inicio
        if (users.isEmpty && !widget.forceSelection) {
          _checkFirstRunConnectivity();
        }
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

  /// Detecta el tipo de conectividad disponible en el primer inicio.
  /// Prioridad: internet → si no hay, mostrar opciones TCP / ADB.
  Future<void> _checkFirstRunConnectivity() async {
    final isNew = await actions.isNewDevice();
    if (!isNew || !mounted) return;

    // 1. Internet primero — si hay, flujo normal sin intervención
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (hasInternet) return;

    // 2. Sin internet → mostrar card con opciones de instalación
    if (mounted) setState(() => _showNoConnectionError = true);
  }

  /// Sondea las IPs USB tethering; si hay servidor TCP activo, muestra la card de transferencia.
  Future<void> _tryTcpInstall() async {
    setState(() => _showNoConnectionError = false);
    for (final ip in DeviceTransferService.kUsbGatewayIps) {
      final url = 'http://$ip:${DeviceTransferService.port}/db';
      if (await DeviceTransferService.instance.probeServer(url)) {
        if (mounted) {
          setState(() {
            _showUsbTransferOption = true;
            _detectedGatewayUrl = url;
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() => _showNoConnectionError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se detectó el dispositivo. Activa "Conexión compartida por USB" en el celular origen.'),
          backgroundColor: Color(0xFFE65100),
        ),
      );
    }
  }

  Future<void> _startUsbTransfer() async {
    setState(() {
      _isDownloadingDb = true;
      _downloadProgress = 0;
    });
    final success = await DeviceTransferService.instance.downloadDatabase(
      _detectedGatewayUrl!,
      onProgress: (progress) {
        if (mounted) setState(() => _downloadProgress = progress);
      },
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _showUsbTransferOption = false;
        _isDownloadingDb = false;
      });
      await _loadUsersFromSqlite(); // Recargar con la BD recibida
    } else {
      setState(() => _isDownloadingDb = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo transferir la base de datos. Verifica la conexión USB.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

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
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _checkAndNavigateIfUserSelected() async {
    try {
      final userSelected = FFAppState().userSelected;
      if (userSelected.idUser > 0 && userSelected.nameUser.isNotEmpty) {
        debugPrint('✅ Usuario persistente detectado: ${userSelected.nameUser}');
        if (mounted) {
          if (Navigator.of(context).canPop()) context.pop();
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

  Future<void> _onUserSelected(UsersStruct user) async {
    setState(() => _isLoading = true);
    try {
      // Guardar last_used en SQLite para ordenar por uso en próximas sesiones
      await globalDb.executeOperation((db) async {
        await db.rawUpdate(
          'UPDATE Users SET last_used = ? WHERE Id_user = ?',
          [DateTime.now().toIso8601String(), user.idUser],
        );
      });

      FFAppState().userSelected = user;
      FFAppState().update(() {});
      debugPrint('✅ Usuario seleccionado: ${user.nameUser}');

      if (!mounted) return;
      if (widget.forceSelection) {
        // Cambio de operador desde dentro de la app: volver a quien llamó
        context.pop();
      } else {
        // Flujo de login inicial: siempre ir a HomePage limpiando el stack
        if (Navigator.of(context).canPop()) context.pop();
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
    } catch (e) {
      debugPrint('Error en selección de usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Escape hatch para usuarios con SharedPreferences corrupto: borra TODO
  /// el estado local persistido (incluye structs de FlutterFlow) y reinicia
  /// FFAppState en memoria. La app vuelve al estado de primera instalación.
  Future<void> _resetLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer datos locales'),
        content: const Text(
          'Esto borrará el usuario, actividad y lote seleccionados, así como '
          'cualquier otro dato guardado en este dispositivo. Tendrás que volver '
          'a sincronizar la base.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restablecer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      releaseLog('LoginPage._resetLocalData OK');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos locales restablecidos')),
      );
      setState(() {});
    } catch (e, st) {
      releaseLog('LoginPage._resetLocalData failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restablecer: $e')),
      );
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
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (widget.forceSelection)
                            InkWell(
                              onTap: () => context.safePop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 10),
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
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
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
                                Text(
                                  widget.forceSelection
                                      ? 'Cambiar operador'
                                      : 'Inicio de sesion',
                                  style: const TextStyle(
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

                      // Barra de busqueda
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
                            prefixIconConstraints: const BoxConstraints(minWidth: 34),
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
                                        onPressed: () => _model.textController?.clear(),
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

                        if (_filteredUsers.isEmpty) {
                          // Primer inicio: USB detectado
                          if (_showUsbTransferOption) {
                            return _buildUsbDetectedCard();
                          }
                          // Primer inicio: sin ninguna conexión
                          if (_showNoConnectionError) {
                            return _buildNoConnectionCard();
                          }
                          // Estado vacío normal (búsqueda sin resultados)
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
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
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
                                  // BackdropFilter eliminado: con sigma=2 el efecto glass
                                  // es prácticamente imperceptible, pero cada item disparaba
                                  // un render-pass adicional con sample del fondo en GPU
                                  // (caro en gama media, saturaba BLASTBufferQueue).
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
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
                                                        'Codigo: ${user.codeUser.isNotEmpty ? user.codeUser : user.operID}',
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
                              );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Escape hatch: si HomePage queda en blanco al entrar, este
                // botón borra el state local corrupto y permite re-sincronizar.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: _resetLocalData,
                    child: Text(
                      '¿Pantalla en blanco al entrar? Restablecer datos locales',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.4),
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

  // ── UI: USB detectado ────────────────────────────────────────────────────

  Widget _buildUsbDetectedCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.usb_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Celular anterior detectado',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Se encontró un dispositivo con datos conectado por cable USB. ¿Deseas recuperar la base de datos?',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloadingDb ? null : _startUsbTransfer,
                icon: _isDownloadingDb
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isDownloadingDb
                      ? 'Transfiriendo... ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                      : 'Transferir datos',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_isDownloadingDb) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showUsbTransferOption = false),
              child: Text(
                'Ignorar y continuar',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI: Sin conexión en primer inicio — elegir método ───────────────────

  Widget _buildNoConnectionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 36, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sin conexión a internet',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Para configurar este dispositivo, elige una opción de instalación:',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Opción TCP
            _buildInstallOptionButton(
              icon: Icons.usb_rounded,
              title: 'Instalar por TCP',
              subtitle: 'Conecta otro Android con la app\nvía USB tethering',
              color: const Color(0xFF0D47A1),
              borderColor: const Color(0xFF1565C0),
              onTap: _tryTcpInstall,
            ),
            const SizedBox(height: 12),
            // Opción ADB
            _buildInstallOptionButton(
              icon: Icons.computer_rounded,
              title: 'Instalar por ADB',
              subtitle: 'Conecta un PC Windows con la\nBD actualizada vía cable USB',
              color: const Color(0xFF1A237E),
              borderColor: const Color(0xFF3949AB),
              onTap: () async {
                final ctx = context;
                await Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => const AdbInstallPageWidget()),
                );
                if (mounted) _loadUsersFromSqlite();
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _showNoConnectionError = false);
                  _checkFirstRunConnectivity();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Reintentar internet',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor.withValues(alpha: 0.3),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
