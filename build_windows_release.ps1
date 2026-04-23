# Build Windows Release - ClickPalm APP
# Este script compila en release y parchea los plugins problematicos automaticamente.

Write-Host "=== ClickPalm Windows Release Build ===" -ForegroundColor Green

# Paso 1: Build normal con Flutter
Write-Host "`n[1/4] Compilando con Flutter..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter build fallo" -ForegroundColor Red
    exit 1
}

# Paso 2: Parchear generated_plugins.cmake
Write-Host "`n[2/4] Parcheando plugins nativos..." -ForegroundColor Cyan

$cmakeFile = "windows/flutter/generated_plugins.cmake"
$cmakeContent = Get-Content $cmakeFile -Raw
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)battery_plus\s*$', '$1# battery_plus'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)file_selector_windows\s*$', '$1# file_selector_windows'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)flutter_tts\s*$', '$1# flutter_tts'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)geolocator_windows\s*$', '$1# geolocator_windows'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)permission_handler_windows\s*$', '$1# permission_handler_windows'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)printing\s*$', '$1# printing'
$cmakeContent = $cmakeContent -replace '(?m)^(\s*)share_plus\s*$', '$1# share_plus'
Set-Content $cmakeFile $cmakeContent -NoNewline

# Paso 3: Parchear generated_plugin_registrant.cc
$regFile = "windows/flutter/generated_plugin_registrant.cc"
$regContent = @"
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
"@
Set-Content $regFile $regContent

# Paso 4: Recompilar con CMake
Write-Host "`n[3/4] Recompilando con CMake..." -ForegroundColor Cyan
$cmakePath = "C:/Program Files/Microsoft Visual Studio/18/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
& $cmakePath --build build/windows/x64 --config Release --target INSTALL
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: cmake build fallo" -ForegroundColor Red
    exit 1
}

# Paso 5: Limpiar DLLs sobrantes
Write-Host "`n[4/4] Limpiando DLLs innecesarios..." -ForegroundColor Cyan
$releaseDir = "build/windows/x64/runner/Release"
$dllsToRemove = @(
    "battery_plus_plugin.dll",
    "file_selector_windows_plugin.dll",
    "flutter_tts_plugin.dll",
    "geolocator_windows_plugin.dll",
    "permission_handler_windows_plugin.dll",
    "printing_plugin.dll",
    "share_plus_plugin.dll",
    "pdfium.dll"
)
foreach ($dll in $dllsToRemove) {
    $dllPath = Join-Path $releaseDir $dll
    if (Test-Path $dllPath) {
        Remove-Item $dllPath
        Write-Host "  Eliminado: $dll" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Build completado! ===" -ForegroundColor Green
Write-Host "Ejecutable: $releaseDir\click_palm_a_p_p.exe" -ForegroundColor Yellow
