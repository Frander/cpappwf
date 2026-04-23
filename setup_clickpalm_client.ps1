# ============================================================
# ClickPalm APP - Setup para PC Cliente
# Ejecutar como Administrador en PowerShell:
#   Right-click PowerShell > "Ejecutar como administrador"
#   cd <ruta donde esta este archivo>
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\setup_clickpalm_client.ps1
# ============================================================

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  ClickPalm APP - Setup PC Cliente" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

$errores = @()

# -----------------------------------------------------------
# 1. Visual C++ Redistributable 2015-2022 (x64)
# -----------------------------------------------------------
Write-Host "[1/3] Visual C++ Redistributable..." -ForegroundColor Cyan

# Verificar si ya esta instalado
$vcInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" -ErrorAction SilentlyContinue
if ($vcInstalled) {
    Write-Host "  Ya instalado (v$($vcInstalled.Version))" -ForegroundColor DarkGray
} else {
    Write-Host "  Descargando..."
    try {
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile "$env:TEMP\vc_redist.x64.exe"
        Write-Host "  Instalando (esto puede tardar un momento)..."
        $proc = Start-Process "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1638) {
            Write-Host "  Instalado correctamente" -ForegroundColor Green
        } else {
            $errores += "Visual C++ Redistributable: codigo de salida $($proc.ExitCode)"
            Write-Host "  Advertencia: codigo de salida $($proc.ExitCode)" -ForegroundColor Yellow
        }
        Remove-Item "$env:TEMP\vc_redist.x64.exe" -Force -ErrorAction SilentlyContinue
    } catch {
        $errores += "Visual C++ Redistributable: $_"
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

# -----------------------------------------------------------
# 2. ADB (Android Platform-Tools)
# -----------------------------------------------------------
Write-Host ""
Write-Host "[2/3] Android Platform-Tools (ADB)..." -ForegroundColor Cyan

$adbDir = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$adbExe = "$adbDir\adb.exe"

if (Test-Path $adbExe) {
    $ver = & $adbExe version 2>&1 | Select-Object -First 1
    Write-Host "  Ya instalado ($ver)" -ForegroundColor DarkGray
} else {
    Write-Host "  Descargando platform-tools de Google..."
    try {
        $zipPath = "$env:TEMP\platform-tools.zip"
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zipPath

        $sdkDir = "$env:LOCALAPPDATA\Android\Sdk"
        New-Item -ItemType Directory -Path $sdkDir -Force | Out-Null

        Write-Host "  Extrayendo..."
        Expand-Archive -Path $zipPath -DestinationPath $sdkDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        if (Test-Path $adbExe) {
            $ver = & $adbExe version 2>&1 | Select-Object -First 1
            Write-Host "  Instalado correctamente ($ver)" -ForegroundColor Green
        } else {
            $errores += "ADB: extraccion fallo, adb.exe no encontrado"
            Write-Host "  ERROR: adb.exe no encontrado tras extraccion" -ForegroundColor Red
        }
    } catch {
        $errores += "ADB: $_"
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

# -----------------------------------------------------------
# 3. Agregar ADB al PATH del usuario
# -----------------------------------------------------------
Write-Host ""
Write-Host "[3/3] Configurando variable de entorno PATH..." -ForegroundColor Cyan

if (Test-Path $adbExe) {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$adbDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$adbDir", "User")
        # Actualizar PATH de la sesion actual tambien
        $env:Path = "$env:Path;$adbDir"
        Write-Host "  ADB agregado al PATH" -ForegroundColor Green
    } else {
        Write-Host "  ADB ya esta en el PATH" -ForegroundColor DarkGray
    }
} else {
    $errores += "PATH: no se configuro porque adb.exe no existe"
    Write-Host "  Omitido (adb.exe no encontrado)" -ForegroundColor Yellow
}

# -----------------------------------------------------------
# Resumen
# -----------------------------------------------------------
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green

if ($errores.Count -eq 0) {
    Write-Host "  Setup completado sin errores!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Verificacion:" -ForegroundColor White
    & $adbExe version 2>&1 | Select-Object -First 1 | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
    Write-Host ""
    Write-Host "  Ya puedes ejecutar ClickPalm APP." -ForegroundColor Green
    Write-Host "  Nota: si adb no funciona en otras" -ForegroundColor Yellow
    Write-Host "  terminales, cierralas y abrilas de nuevo." -ForegroundColor Yellow
} else {
    Write-Host "  Setup completado con errores:" -ForegroundColor Yellow
    foreach ($e in $errores) {
        Write-Host "    - $e" -ForegroundColor Red
    }
}

Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
