#!/bin/bash
# Build Windows Release - ClickPalm APP
# Este script compila en release y parchea los plugins problematicos automaticamente.

set -e

echo "=== ClickPalm Windows Release Build ==="

# Paso 1: Build normal con Flutter
echo ""
echo "[1/4] Compilando con Flutter..."
flutter build windows --release

# Paso 2: Parchear generated_plugins.cmake
echo ""
echo "[2/4] Parcheando plugins nativos..."

CMAKE_FILE="windows/flutter/generated_plugins.cmake"
sed -i 's/^  battery_plus$/  # battery_plus/' "$CMAKE_FILE"
sed -i 's/^  file_selector_windows$/  # file_selector_windows/' "$CMAKE_FILE"
sed -i 's/^  flutter_tts$/  # flutter_tts/' "$CMAKE_FILE"
sed -i 's/^  geolocator_windows$/  # geolocator_windows/' "$CMAKE_FILE"
sed -i 's/^  permission_handler_windows$/  # permission_handler_windows/' "$CMAKE_FILE"
sed -i 's/^  printing$/  # printing/' "$CMAKE_FILE"
sed -i 's/^  share_plus$/  # share_plus/' "$CMAKE_FILE"

# Paso 3: Parchear generated_plugin_registrant.cc
REG_FILE="windows/flutter/generated_plugin_registrant.cc"
cat > "$REG_FILE" << 'ENDOFFILE'
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

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
ENDOFFILE

# Paso 4: Recompilar con CMake
echo ""
echo "[3/4] Recompilando con CMake..."
CMAKE_PATH="C:/Program Files/Microsoft Visual Studio/18/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
"$CMAKE_PATH" --build build/windows/x64 --config Release --target INSTALL

# Paso 5: Limpiar DLLs sobrantes
echo ""
echo "[4/4] Limpiando DLLs innecesarios..."
RELEASE_DIR="build/windows/x64/runner/Release"
for dll in battery_plus_plugin.dll file_selector_windows_plugin.dll flutter_tts_plugin.dll \
           geolocator_windows_plugin.dll permission_handler_windows_plugin.dll \
           printing_plugin.dll share_plus_plugin.dll pdfium.dll; do
    if [ -f "$RELEASE_DIR/$dll" ]; then
        rm "$RELEASE_DIR/$dll"
        echo "  Eliminado: $dll"
    fi
done

echo ""
echo "=== Build completado! ==="
echo "Ejecutable: $RELEASE_DIR/click_palm_a_p_p.exe"
