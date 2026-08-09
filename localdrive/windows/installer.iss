; Windows installer for the Local Drive client, built with Inno Setup.
;
; Not an MSI. MSI exists for enterprise deployment through Group Policy and
; SCCM, and buying into it means WiX, a schema, GUID management and a component
; model, in exchange for nothing a person double clicking a download will ever
; notice. Inno produces the ordinary setup.exe people expect, from this one
; file, and it is what most open source Windows apps ship.
;
; The portable zip stays in the release too. Some people want a folder they can
; carry on a stick, and an installer cannot be that.
;
; Built by .github/workflows/release.yml. To build locally:
;   iscc /DAppVersion=0.0.1 localdrive\windows\installer.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "Local Drive"
#define AppPublisher "MultiX"
#define AppURL "https://localdrive.iprog.dev"
#define AppExeName "localdrive.exe"

[Setup]
; Never reuse this between applications. It is how Windows recognises an
; upgrade rather than a second copy installed alongside the first.
AppId={{7F2B9E14-3C6A-4D58-9A21-8E5F0C7B4D93}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/docs
AppUpdatesURL=https://github.com/MultiX0/LocalDrive/releases
VersionInfoVersion={#AppVersion}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir=.
OutputBaseFilename=localdrive-client-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

; per user by default, so no administrator prompt for someone installing on
; their own machine. Choosing "for all users" asks for elevation at that point
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; the whole build directory, because a Flutter app resolves its engine and its
; assets from files beside the exe. Shipping the exe alone produces something
; that will not start.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes its cache and window state under the app's own data folder.
; Leaving it behind means a reinstall inherits the old window position and a
; stale cache, which looks like the uninstall did not work.
Type: filesandordirs; Name: "{localappdata}\{#AppPublisher}\{#AppName}"
