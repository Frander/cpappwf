# Visual C++ 2015-2022 Redistributable (x64)

Esta carpeta contiene el instalador del VC++ Redistributable que `installer.iss` bundlea dentro del instalador final de ClickPalm Desktop.

## Archivo esperado

`vc_redist.x64.exe` (~14 MB)

**Este archivo NO se commitea al repositorio** (ver `.gitignore`). Cada persona que compile el instalador debe descargarlo una vez en su laptop Windows.

## Cómo obtenerlo

Descargar desde el sitio oficial de Microsoft:

https://aka.ms/vs/17/release/vc_redist.x64.exe

Guardarlo **exactamente con ese nombre** en esta carpeta:

```
windows\redist\vc_redist.x64.exe
```

## Verificación

Antes de correr `iscc installer.iss`, confirma que el archivo existe:

```powershell
dir windows\redist\vc_redist.x64.exe
```

Si falta, `iscc` fallará con un error tipo `cannot open file "windows\redist\vc_redist.x64.exe"`.

## ¿Por qué se bundlea?

Flutter compila la app con MSVC, lo que genera dependencias sobre `VCRUNTIME140.dll` y `MSVCP140.dll`. Estas DLL vienen con el VC++ Redistributable; la mayoría de Windows modernos ya lo tienen instalado, pero un equipo recién formateado no. Bundlearlo hace que el instalador sea **self-contained**: el usuario final ejecuta un único `.exe` y todo queda listo sin pasos manuales adicionales.

El `installer.iss` detecta automáticamente si el redist ya está presente (lee `HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64\Installed`) y sólo lo ejecuta si falta — no reinstala innecesariamente.
