# Guía: generar instalador `.exe` de ClickPalm Desktop (Windows)

Esta guía describe cómo producir el instalador de Windows **a partir del proyecto Flutter**, usando [Inno Setup 6](https://jrsoftware.org/isinfo.php). Todo se ejecuta en una máquina Windows — el script (`installer.iss`) y esta guía viven en el repo y se mantienen desde cualquier sistema.

---

## 1. Instalaciones únicas (una sola vez en la laptop Windows)

1. **Visual Studio Community 2022** — https://visualstudio.microsoft.com/vs/community/
   Durante la instalación marca la workload **"Desktop development with C++"** (incluye MSVC + Windows SDK, ~8 GB).

2. **Flutter SDK para Windows** — https://docs.flutter.dev/get-started/install/windows
   Misma versión que uses en los otros sistemas. Verifica con `flutter doctor`.

3. **Inno Setup 6** — https://jrsoftware.org/isinfo.php
   Instalador ~3 MB. Al terminar añade `iscc` al PATH automáticamente (si no, agrega `C:\Program Files (x86)\Inno Setup 6` a la variable PATH del usuario).

4. **Microsoft Visual C++ Redistributable** (para bundlearlo en el instalador):
   Descargar desde https://aka.ms/vs/17/release/vc_redist.x64.exe
   y guardarlo exactamente con ese nombre en la carpeta del proyecto:
   ```
   windows\redist\vc_redist.x64.exe
   ```
   Este archivo se embebe dentro del instalador final. Ver [windows/redist/README.md](windows/redist/README.md) para detalles. **No se commitea al repo** — cada persona que compile lo descarga una vez.

5. (Opcional, sólo si vas a probar el ADB NFC bridge en Windows) **Android Platform-Tools** con `adb` en PATH — https://developer.android.com/tools/releases/platform-tools

Verifica:

```powershell
flutter --version
iscc /?                                     # debe mostrar la ayuda de Inno Setup
dir windows\redist\vc_redist.x64.exe        # debe listar el archivo descargado
```

---

## 2. Flujo de build (cada release)

Cada vez que quieras generar un nuevo instalador:

```powershell
cd C:\ruta\a\ClickPalmAPP
git pull
flutter pub get
flutter build windows --release
iscc installer.iss
```

Resultado: **`Output\ClickPalm-Desktop-Setup-<version>.exe`**.

Ese único archivo es el que distribuyes a usuarios finales. Lo copian, doble-click, sigue el asistente.

---

## 3. Cómo actualizar la versión antes de un release

1. En [pubspec.yaml](pubspec.yaml) sube la versión:
   ```yaml
   version: 1.0.2+47    # versionName 1.0.2, versionCode 47
   ```

2. En [installer.iss](installer.iss) actualiza el define al mismo versionName:
   ```ini
   #define AppVersion  "1.0.2"
   ```

3. Rebuild + reinstaller:
   ```powershell
   flutter build windows --release
   iscc installer.iss
   ```

El `AppId` del `.iss` es un GUID fijo — Windows detecta la instalación previa y la actualiza en sitio cuando el usuario corre el nuevo instalador.

---

## 4. Probar el instalador

En la misma laptop donde lo generaste:

1. Ejecuta `Output\ClickPalm-Desktop-Setup-1.0.1.exe`.
2. Confirma elevación UAC (la app requiere admin por ADB + otras funciones).
3. El asistente debe mostrar el icono ClickPalm, idioma español por defecto, ruta de instalación `C:\Program Files\ClickPalm Desktop`, checkbox opcional para icono en escritorio.
4. Tras instalar, ofrece "Iniciar ClickPalm Desktop". La app debe abrir normalmente.
5. Probar desinstalación: Windows Settings → Apps → ClickPalm Desktop → Desinstalar. Debe eliminar limpiamente la carpeta y los accesos directos.

**Prueba adicional recomendada:** copiar el `.exe` a una segunda PC Windows limpia (sin Flutter ni VS instalados) y probar ahí. Si al abrir la app aparece `VCRUNTIME140.dll not found`, el usuario final necesita el "Microsoft Visual C++ Redistributable" (ver Troubleshooting abajo).

---

## 5. Troubleshooting

### `VCRUNTIME140.dll not found` o `MSVCP140.dll not found` al abrir la app

El instalador bundlea y ejecuta automáticamente el VC++ Redistributable si no está presente, así que este error **no debería ocurrir** en instalaciones hechas con el `.exe` generado. Si aparece, verifica:

1. Que `windows\redist\vc_redist.x64.exe` exista en tu proyecto al compilar con `iscc`.
2. Que el usuario final haya ejecutado el instalador con permisos de administrador (lo pide vía UAC automáticamente).
3. Revisar el log del instalador: Inno Setup crea uno en `%TEMP%\Setup Log <fecha>.txt` con el código de retorno del redist.

Códigos de retorno útiles del redist:
- `0` = instalación exitosa
- `1638` = versión igual o más nueva ya instalada (no es error)
- `3010` = requiere reinicio del sistema

### Windows SmartScreen bloquea el `.exe`

Pasa con cualquier instalador sin firma digital. Usuario debe hacer clic en **"Más información" → "Ejecutar de todos modos"**. Se resuelve firmando el instalador con un certificado Code Signing EV (~USD 300/año) — pendiente para producción.

### `iscc` no es reconocido

Agregar manualmente al PATH de Windows: `C:\Program Files (x86)\Inno Setup 6`. Cerrar y reabrir la terminal.

### El build `flutter build windows --release` falla con `clang-cl` o similar

Revisar que la workload "Desktop development with C++" de Visual Studio esté instalada **completa**, incluyendo el Windows SDK. `flutter doctor -v` debe mostrar Visual Studio sin errores.

---

## 6. Pendientes para iteraciones futuras

- **Firma digital** con certificado Code Signing para eliminar el aviso de SmartScreen.
- **CI con GitHub Actions `windows-latest`** — construir el instalador automáticamente en cada push a una rama de release, subirlo como artifact. Evita depender de la laptop manual.
- **Auto-updater** dentro de la app (por ejemplo, con el paquete `auto_updater`).
