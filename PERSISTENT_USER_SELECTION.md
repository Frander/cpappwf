# Selección de Usuario Persistente

## Descripción del Cambio
Se ha implementado una funcionalidad que permite que la selección de usuario sea **persistente entre sesiones**. Una vez que un usuario es seleccionado en la pantalla de login, esta selección se guarda localmente y se reutiliza automáticamente en inicios posteriores de la aplicación, evitando que el usuario tenga que seleccionar manualmente su perfil cada vez.

## Cambios Implementados

### 1. **LoginPageWidget** (`lib/login_page/login_page_widget.dart`)

#### Imports Agregados:
```dart
import 'package:flutter/scheduler.dart';
```

#### Método `_checkAndNavigateIfUserSelected()` (NUEVO)
Este método se ejecuta **después de que el frame se ha renderizado** (post-frame callback) y verifica si existe un usuario seleccionado en la persistencia:

```dart
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
```

#### Modificación en `initState()`:
Se agregó un `SchedulerBinding.instance.addPostFrameCallback()` que ejecuta el método de verificación después de que el widget se ha construido:

```dart
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
```

## Flujo de Ejecución

### Primera sesión (sin usuario previo):
1. App inicia → StartPage
2. StartPage hace login automático por IMEI
3. Se navega a LoginPageWidget
4. `_checkAndNavigateIfUserSelected()` verifica (no hay usuario persistente)
5. Se muestra la pantalla de selección de usuario
6. Usuario selecciona su perfil
7. Se guarda automáticamente en `FFAppState().userSelected`
8. SharedPreferences persiste la selección con la key `ff_userSelected`
9. Se navega a HomePage

### Sesiones posteriores (con usuario previo):
1. App inicia → StartPage
2. StartPage hace login automático por IMEI
3. Se navega a LoginPageWidget
4. `_checkAndNavigateIfUserSelected()` se ejecuta:
   - Carga el usuario persistente desde SharedPreferences (en `FFAppState.initializePersistedState()`)
   - Detecta que existe un usuario válido
   - Navega directamente a HomePage sin mostrar la pantalla de selección
5. La aplicación continúa normalmente

## Persistencia

### Cómo se guarda el datos:
La persistencia está manejada por `FFAppState` en [app_state.dart](app_state.dart#L432-L440):

```dart
UsersStruct get userSelected => _userSelected;
set userSelected(UsersStruct value) {
  _userSelected = value;
  prefs.setString('ff_userSelected', value.serialize());
}
```

Cuando se asigna `FFAppState().userSelected = user`, automáticamente se persiste en SharedPreferences.

### Cómo se carga al iniciar:
En `initializePersistedState()` del app_state.dart (líneas 39-43):

```dart
if (prefs.containsKey('ff_userSelected')) {
  try {
    final serializedData = prefs.getString('ff_userSelected') ?? '{}';
    _userSelected = UsersStruct.fromSerializableMap(jsonDecode(serializedData));
  } catch (e) {
    print("Can't decode persisted data type. Error: $e.");
  }
}
```

## Ventajas de esta implementación

✅ **Menor tiempo de inicio**: Los usuarios no necesitan seleccionar su perfil cada vez que abren la app  
✅ **Mejor UX**: Acceso más rápido a las funcionalidades principales  
✅ **Persistente entre sesiones**: Funciona incluso después de cerrar y abrir nuevamente la app  
✅ **Automático**: No requiere configuración adicional del usuario  
✅ **Seguro**: La validación aún ocurre en el backend (a través del login por IMEI)  

## Cambio de usuario

Si en el futuro se necesita permitir que el usuario cambie de perfil, se puede:

1. Agregar un botón "Cambiar usuario" en un menú de configuración
2. Limpiar la persistencia: `FFAppState().userSelected = UsersStruct();` y `prefs.remove('ff_userSelected')`
3. Navegar nuevamente a LoginPageWidget

Este cambio no está implementado actualmente según los requisitos, pero está lista la infraestructura para hacerlo.

## Pruebas recomendadas

1. ✅ Primera instalación: Seleccionar un usuario, cerrar y abrir la app. El usuario debe cargarse automáticamente.
2. ✅ Cambio de dispositivo: Los datos generados en un dispositivo deben ser accesibles si se instala la app en otro.
3. ✅ Limpieza de datos: Si se borra el almacenamiento de la app, debe volver a mostrar la selección de usuario.
