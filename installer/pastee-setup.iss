; Pastee Installer Script for Inno Setup
; Download Inno Setup from: https://jrsoftware.org/isdl.php

; Build before packaging
#expr Exec("dotnet", "publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false", "..\Pastee.App", 1, SW_SHOW)

#define MyAppName "Pastee"
#define MyAppVersion "3.9.0"
#define MyAppPublisher "Pastee"
#define MyAppURL "https://pastee.im"
#define MyAppExeName "Pastee.App.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir=..\dist
OutputBaseFilename=Pastee-Setup-{#MyAppVersion}
SetupIconFile=..\assets\pastee.ico
Compression=lzma2
SolidCompression=yes

WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

CloseApplications=yes
CloseApplicationsFilter=*.exe
RestartApplications=no

UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Launch on Windows startup"; GroupDescription: "Startup:"

[Files]
Source: "..\Pastee.App\bin\Release\netcoreapp3.1\win-x64\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\pastee.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\pastee.ico"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "PasteeApp"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\PasteeNative"

[Code]
function KillPasteeProcess(): Boolean;
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/F /IM Pastee.App.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  KillPasteeProcess();
  Sleep(500);
end;

function InitializeUninstall(): Boolean;
begin
  KillPasteeProcess();
  Sleep(500);
  Result := True;
end;
