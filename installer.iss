; ClickPalm Desktop — instalador Windows con Inno Setup 6
; Genera: Output\ClickPalm-Desktop-Setup-{AppVersion}.exe
;
; Uso (en Windows, después de `flutter build windows --release`):
;   iscc installer.iss

#define AppName        "ClickPalm Desktop"
#define AppPublisher   "3lox"
#define AppVersion     "1.0.3"
#define AppExeName     "click_palm_a_p_p.exe"
#define BuildDir       "build\windows\x64\runner\Release"
#define VcRedistExe    "windows\redist\vc_redist.x64.exe"

[Setup]
; AppId es el identificador único de esta aplicación para el registro de Windows.
; NO CAMBIAR entre versiones — si cambia, Windows tratará cada versión como una app
; distinta y el instalador no detectará la instalación previa al actualizar.
AppId={{E5F3B7A0-9E7F-4B25-A1A3-CLICKPALM0001}}

AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://clickpalm.com
AppSupportURL=https://clickpalm.com
VersionInfoVersion={#AppVersion}.0

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

OutputDir=Output
OutputBaseFilename=ClickPalm-Desktop-Setup-{#AppVersion}

SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Windows 10 1809 (build 17763) o superior — requisito mínimo de Flutter Windows.
MinVersion=10.0.17763

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Empaqueta todo lo que produce `flutter build windows --release`:
; el .exe + flutter_windows.dll + plugins .dll + carpeta data\ con assets.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

; Microsoft Visual C++ 2015-2022 Redistributable (x64).
; Se extrae a una carpeta temporal durante la instalación y se borra al terminar.
; NO se copia al directorio de la app — sólo se ejecuta si no está ya instalado en el sistema.
Source: "{#VcRedistExe}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}";             Filename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";       Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Instala el VC++ Redist silenciosamente si no está presente en el sistema.
; Se ejecuta ANTES que el launch de la app para que las DLL ya estén disponibles.
Filename: "{tmp}\vc_redist.x64.exe"; \
  Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Instalando Microsoft Visual C++ Redistributable..."; \
  Check: VCRedistNeedsInstall

Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// Verifica si el Visual C++ 2015-2022 Redistributable x64 ya está instalado.
// Lee la clave del registro que instala el redist al completarse.
//   HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64
// Si existe y tiene "Installed"=1, no es necesario reinstalar.
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Installed', Installed) then
  begin
    Result := Installed <> 1;
  end
  else
  begin
    Result := True;
  end;
end;
