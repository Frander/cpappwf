# Fix: Crash en Windows Release Mode

## Problema

Al compilar con `flutter build windows --release`, el .exe crashea ~3 segundos despues de abrir.
El visor de eventos de Windows muestra: `ucrtbase.dll` con codigo `0xc0000409` (STATUS_STACK_BUFFER_OVERRUN).

## Causa

Varios plugins nativos registrados para Windows causan un crash a nivel C++ durante su inicializacion.
Estos plugins son de uso exclusivo movil y no se necesitan en el build de Windows:

- battery_plus
- file_selector_windows
- flutter_tts
- geolocator_windows
- permission_handler_windows
- printing
- share_plus

## Solucion rapida (automatica)

Ejecutar el script de build en lugar de `flutter build windows --release`:

```bash
./build_windows_release.sh
```

O en PowerShell:

```powershell
.\build_windows_release.ps1
```

## Solucion manual (paso a paso)

### Paso 1: Compilar normalmente

```bash
flutter build windows --release
```

### Paso 2: Editar `windows/flutter/generated_plugins.cmake`

Comentar los plugins problematicos:

```cmake
list(APPEND FLUTTER_PLUGIN_LIST
  # battery_plus
  connectivity_plus
  # file_selector_windows
  # flutter_tts
  # geolocator_windows
  # permission_handler_windows
  # printing
  # share_plus
  sqlite3_flutter_libs
  url_launcher_windows
)
```

### Paso 3: Editar `windows/flutter/generated_plugin_registrant.cc`

Comentar los includes y llamadas Register de los mismos plugins:

```cpp
// #include <battery_plus/battery_plus_windows_plugin.h>
#include <connectivity_plus/connectivity_plus_windows_plugin.h>
// #include <file_selector_windows/file_selector_windows.h>
// #include <flutter_tts/flutter_tts_plugin.h>
// #include <geolocator_windows/geolocator_windows.h>
// #include <permission_handler_windows/permission_handler_windows_plugin.h>
// #include <printing/printing_plugin.h>
// #include <share_plus/share_plus_windows_plugin_c_api.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  ConnectivityPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  Sqlite3FlutterLibsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("Sqlite3FlutterLibsPlugin"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
```

### Paso 4: Recompilar solo C++ con CMake (sin que Flutter regenere los archivos)

```bash
"C:/Program Files/Microsoft Visual Studio/18/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe" --build build/windows/x64 --config Release --target INSTALL
```

### Paso 5: Limpiar DLLs sobrantes de la carpeta Release

Eliminar de `build/windows/x64/runner/Release/`:
- battery_plus_plugin.dll
- file_selector_windows_plugin.dll
- flutter_tts_plugin.dll
- geolocator_windows_plugin.dll
- permission_handler_windows_plugin.dll
- printing_plugin.dll
- share_plus_plugin.dll
- pdfium.dll

## Por que ocurre

`flutter build windows` auto-genera `generated_plugin_registrant.cc` y `generated_plugins.cmake` incluyendo TODOS los plugins que tienen soporte nativo para Windows, aunque la app solo los use en movil. Algunos de estos plugins (probablemente geolocator_windows o flutter_tts) tienen bugs en su inicializacion nativa en release mode que causan un crash en ucrtbase.dll.
