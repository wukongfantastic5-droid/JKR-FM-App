[Setup]
AppId={{8E9A2D5C-1B3F-4C7E-9A61-JKRFMGUIDE01}}
AppName=JKR FM Guide
AppVersion=1.0.9
AppVerName=JKR FM Guide 1.0.9
AppPublisher=Cakra Mahkota Sdn Bhd
DefaultDirName={autopf}\JKR FM Guide
DefaultGroupName=JKR FM Guide
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=JKR_FM_Guide_Setup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\jkr_fm_guide.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\JKR FM Guide"; Filename: "{app}\jkr_fm_guide.exe"
Name: "{group}\{cm:UninstallProgram,JKR FM Guide}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\JKR FM Guide"; Filename: "{app}\jkr_fm_guide.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\jkr_fm_guide.exe"; Description: "{cm:LaunchProgram,JKR FM Guide}"; Flags: nowait postinstall skipifsilent
