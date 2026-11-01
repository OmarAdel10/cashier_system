[Setup]
AppId={{C84D92A4-F291-4D6C-8D15-1A938C219B22}
AppName=Daftari
AppVersion=1.0.0
DefaultDirName={autopf}\Daftari
DefaultGroupName=Daftari
OutputDir=Output
OutputBaseFilename=Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Custom icon for the Setup wizard executable itself
SetupIconFile=apps\daftari\assets\icon\daftari_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Flutter Windows Executable
Source: "apps\daftari\build\windows\x64\runner\Release\daftari.exe"; DestDir: "{app}"; Flags: ignoreversion
; All supporting DLLs, shaders, data folders, and native assets from the Flutter build
Source: "apps\daftari\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Standalone .NET sidecar PrintServer engine binary tree
Source: "PrintServer\bin\Release\net8.0\*"; DestDir: "{app}\PrintServer"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Shortcuts point to the main executable (which natively inherits windows/runner/resources/app_icon.ico)
Name: "{group}\Daftari"; Filename: "{app}\daftari.exe"
Name: "{autodesktop}\Daftari"; Filename: "{app}\daftari.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\daftari.exe"; Description: "{cm:LaunchProgram,Daftari}"; Flags: nowait postinstall skipifsilent