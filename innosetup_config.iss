[Setup]
AppId={C84D92A4-F291-4D6C-8D15-1A938C219B22}
AppName=Cashier System
AppVersion=1.0.0
DefaultDirName={autopf}\CashierSystem
DefaultGroupName=Cashier System
OutputDir=Output
OutputBaseFilename=Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Custom icon for the Setup wizard executable itself
SetupIconFile=assets\icon\pos_cashier_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Flutter Windows Executable
Source: "build\windows\x64\runner\Release\cashier_system.exe"; DestDir: "{app}"; Flags: ignoreversion
; All supporting DLLs, shaders, data folders, and native assets from the Flutter build
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Standalone .NET sidecar PrintServer engine binary tree
Source: "PrintServer\bin\Release\net8.0\*"; DestDir: "{app}\PrintServer"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Shortcuts point to the main executable (which natively inherits windows/runner/resources/app_icon.ico)
Name: "{group}\Cashier System"; Filename: "{app}\cashier_system.exe"
Name: "{autodesktop}\Cashier System"; Filename: "{app}\cashier_system.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cashier_system.exe"; Description: "{cm:LaunchProgram,Cashier System}"; Flags: nowait postinstall skipifsilent