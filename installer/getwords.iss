; Inno Setup script — builds GetWords-Setup.exe (Windows installer).
; Compiled in CI with: ISCC.exe installer/getwords.iss

[Setup]
AppName=GetWords
AppVerName=GetWords 1.0
AppPublisher=GetWords
DefaultDirName={autopf}\GetWords
DefaultGroupName=GetWords
DisableProgramGroupPage=yes
OutputDir=installer_out
OutputBaseFilename=GetWords-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\GetWords.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\dist\GetWords.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\GetWords"; Filename: "{app}\GetWords.exe"
Name: "{group}\{cm:UninstallProgram,GetWords}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\GetWords"; Filename: "{app}\GetWords.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\GetWords.exe"; Description: "{cm:LaunchProgram,GetWords}"; Flags: nowait postinstall skipifsilent
