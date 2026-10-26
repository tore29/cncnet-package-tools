; CnCNet Red Alert 2 Yuri's Revenge client installer (Inno Setup 7).
; This client is a PATCH: it installs into the user's existing game folder (the dir page
; validates gamemd.exe; default = the detected install or C:\Westwood\RA2).
; Per-user install by default; all-users can be opted into at startup (UAC).
; Machine-wide dependencies only run for the elevated (all-users) install.
; Source template: the build renders this to installer.iss (Twig) - edit this file, never the output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Allows adding dependency installers: https://github.com/DomGries/InnoDependencyInstaller

[Code]
// All library includes live at the top of [Code]; their [Code] sections splice into this one.
// No palette #defines needed: the shared ISTheme defaults ARE the YR dark palette.
#include "libs/InnoDependencyInstaller/CodeDependencies.iss"
#include "libs/ISTheme/ISTheme.iss"
#include "libs/CncnetCommon/CncnetCommon.iss"

[CustomMessages]
AccessDenied=Access to: %1 denied. %n Please choose a different directory or restart the installer as administrator (right-click the installer and choose "Run as administrator"). %n If the installer already runs elevated, make sure your Anti-Virus program does not block the installer (turn it off temporarily if you do not know how to configure it)
WriteDeniedPrompt=Access to: %1 denied for the current user. %n%nElevate now and continue the install into this game folder for all users? Choosing No keeps the per-user install (choose a different game folder instead).
InstallingApp=Installing %1, this may take several minutes...
GameNotFound=Red Alert 2 Yuri's Revenge not found in %1 %nPlease select the right folder...%nNote: You need to have the game installed, Red Alert 2 is not freeware and therefore not included in this installer!
PerUserMissingDeps=The following required runtimes are missing:%n%n %1 %n%nThey are machine-wide components and cannot be installed for a single user.%n%nElevate now to install for all users and have them installed automatically? Choosing No continues the per-user install and leaves them missing.
PerUserMissingDepsFailed=Elevation failed, so the following required runtimes could not be installed - they require administrator rights:%n%n %1 %n%nPlease install them using an administrator account (each URL above points to the exact download) and then run this installer again - it will detect them and complete the setup. The per-user install continues for now, but the listed runtimes will remain missing.
Agree=&I Agree
DownloadingFiles=Downloading files
DownloadingFilesDescription=The following files will be downloaded before the installation starts. Depending on your internet connection, this may take a while.
RunDiagPrompt=The diagnostic tool YRDiag.exe requires administrator rights, which this per-user install does not have. %n%nAllow the setup to run YRDiag.exe elevated now?
RunDiagSkipped=YRDiag.exe was not started (it requires administrator rights). You can run it manually from the game folder later, if needed.

[Setup]
AppId={{ '{{' ~ app.appId ~ '}}' }}
AppName={{ app.name }}
AppVersion={{ app.version }}
AppVerName={{ app.versionName }}
AppPublisher={{ app.publisher }}
AppPublisherURL={{ app.publisherUrl }}
AppSupportURL={{ app.supportUrl }}
AppUpdatesURL={{ app.updatesUrl }}
VersionInfoVersion=0.0.0.0
VersionInfoTextVersion={{ app.version }}
VersionInfoProductName={{ app.name }}
VersionInfoDescription={{ app.description }}
; The target folder already exists (patch into the game folder); do not warn about it.
DirExistsWarning=no
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableWelcomePage=yes
; The finished page is kept: YRDiag.exe runs before it and the launcher must not auto-launch too early.
DisableFinishedPage=no
AllowNoIcons=yes
OutputBaseFilename={{ outputBaseFilename }}
Compression=lzma2/max
SolidCompression=yes
UsePreviouslanguage=no
CreateUninstallRegKey=yes
UsePreviousAppDir=no
SourceDir={{ innoPath }}
OutputDir={{ outputDir }}
SetupIconFile={{ setupIconFile }}
AppendDefaultDirName=no
ShowLanguageDialog=no
LicenseFile={{ licenseFile }}
ArchitecturesInstallIn64BitMode=x64compatible
UsedUserAreasWarning=no
SetupLogging=yes
; Per-user by default (no elevation needed); at startup the user is offered an all-users
; install (UAC); "commandline" also allows /ALL and /LOW overrides for scripted installs.
; The .NET / VC++ dependency installers are machine-wide and only run for elevated installs.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "runyrdiag"; Description: "Run the diagnostic tool to automatically fix common game launch issues (recommended)"

[InstallDelete]
; files to delete prior to installation (from preupdateexec/updateexec)
{% for item in installDeleteFiles %}
Type: filesandordirs; Name: "{app}\{{ item }}"
{% endfor %}

[Files]
; Installer theming resources (used at runtime, not installed), relative to SourceDir.
; Source names are prefixed per game; DestName maps them back to the names ISTheme() loads.
Source: "Resources\yr\YurisRevengeWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\yr\YurisRevengeInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\yr\YurisRevengePageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package; critical files are also listed explicitly (compile fails if any is missing).
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\gamemd-spawn.exe"; DestDir: "{app}";
Source: "{{ sourceDir }}\YRDiag.exe"; DestDir: "{app}";

[Icons]
; All-users (elevated) installs: common Start Menu + public desktop. WizardNoIcons honors the "no icons" checkbox.
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful; skip them.
Name: "{app}\Uninstall {{ app.name }}"; Filename: "{uninstallexe}"

[Run]
; The launcher launch is deferred to the finished page (postinstall) so YRDiag.exe has time to finish first.
; YRDiag.exe is NOT a [Run] entry: its manifest requires elevation (a plain launch fails with error 740);
; it is started elevated from CurStepChanged, right before the finished page.
Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,Yuri's Revenge}"; Flags: nowait postinstall runascurrentuser skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\version"
Type: files; Name: "{app}\version_u"
Type: files; Name: "{app}\stats.dmp"
Type: files; Name: "{app}\spawnmap.ini"
Type: files; Name: "{app}\spawn.ini"
Type: filesandordirs; Name: "{app}\INI"
Type: filesandordirs; Name: "{app}\Maps"
Type: filesandordirs; Name: "{app}\Map Renderer"
Type: filesandordirs; Name: "{app}\QM"
Type: filesandordirs; Name: "{app}\Qt"
Type: filesandordirs; Name: "{app}\Resources"
Type: filesandordirs; Name: "{app}\Client"
Type: filesandordirs; Name: "{app}\Tools"
Type: filesandordirs; Name: "{app}\Replays"

[Registry]
; Enable long path support (Win 10 1607+); only relevant for elevated all-users installs; noerror guards the write.
Root: HKLM; Subkey: SYSTEM\CurrentControlSet\Control\FileSystem; ValueType: dword; ValueName: LongPathsEnabled; ValueData: 1; Check: CncnetIsUserAnAdmin; Flags: noerror; MinVersion: 10.0.14393

; AppCompat cleanup: remove compatibility flags set on the game EXEs (HKLM only for elevated installs).
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\Ra2.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\Ra2.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\RA2MD.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\RA2MD.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\YURI.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\YURI.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin

; High-DPI awareness for the game spawn process.
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueType: String; ValueName: {app}\gamemd-spawn.exe; ValueData: "HIGHDPIAWARE"
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueType: String; ValueName: {app}\gamemd-spawn.exe; ValueData: "HIGHDPIAWARE"; Check: CncnetIsUserAnAdmin

; Wine: per-app defaults for the game spawn process (the same values YRLauncherUnix.sh writes at runtime).
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe; ValueType: string; ValueName: Version; ValueData: win10; Check: CncnetRunsOnWine
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe\DllOverrides; ValueType: string; ValueName: ddraw; ValueData: native, builtin; Check: CncnetRunsOnWine
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe\DllOverrides; ValueType: string; ValueName: wsock32; ValueData: native, builtin; Check: CncnetRunsOnWine

[Code]
const
  // Registry keys that may point at an existing RA2/YR install; each is read from both the
  // HKLM (32-bit) and HKLM64 registry views. The value may be the install directory or a full
  // path to the game EXE (AddRegistryDir normalizes both).
  GameRegKeyWestwood = 'Software\Westwood\Red Alert 2';
  GameRegKeyTFD = 'Software\Electronic Arts\EA Games\Command and Conquer The First Decade';
  GameRegKeyOrigin = 'Software\EA Games\Command and Conquer Red Alert II';
  // Steam library game folders (the shared lookup checks <library root>\steamapps\common\<folder>).
  // The standalone YR app installs into 'Command & Conquer Red Alert II' (gamemd.exe marks it as YR,
  // so a plain RA2 in the same folder is not a false positive); First Decade uses the nested EA Games path.
  SteamGameFolderStandalone = 'Command & Conquer Red Alert II';
  SteamGameFolderEnglish = 'EA Games\Command & Conquer The First Decade\Command & Conquer Red Alert(tm) II\RA2';
  SteamGameFolderGerman = 'EA Games\Command & Conquer Die ersten 10 Jahre\Command & Conquer Red Alert(tm) II\RA2';
  // The classic install location - also the fallback default when no install is detected.
  ClassicInstallDir = 'C:\Westwood\RA2';
  // Marker EXE of a YR install (this client is a patch and must go into the game folder).
  // 'gamemd.exe' is the YR engine EXE; the launchers are present inconsistently across releases.
  GameCheckFile = 'gamemd.exe';

var
  DetectedInstallPath: String;
  DetectionDone: Boolean;
  // Missing machine-wide dependencies that cannot be installed in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;
  // The custom welcome page (created in InitializeWizard).
  CustomPage: TWizardPage;

// ================================================== Existing install lookup
// Shared ordered lookup (CncnetDetectGame): registry install paths as ExtraDirs, the Steam
// folders as SteamCommonFolders, the classic locations as ClassicDirs; the first dir with gamemd.exe wins.
// This client is a patch: the detected game folder IS the install target (see GetDefaultDir).
function QueryGameRegValue(const SubKey, ValueName: String): String;
var
  Value: String;
begin
  Result := '';
  if RegQueryStringValue(HKLM, SubKey, ValueName, Value) then
  begin
    Result := Value;
    Exit;
  end;
  if RegQueryStringValue(HKLM64, SubKey, ValueName, Value) then
  begin
    Result := Value;
    Exit;
  end;
end;

// Adds a candidate install directory (the registry value may be a directory or a full path to the game EXE).
procedure AddRegistryDir(var Dirs: TArrayOfString; const Value: String);
var
  Dir: String;
begin
  Dir := Trim(Value);
  if Dir = '' then
    Exit;

  if not DirExists(Dir) then
    Dir := ExtractFilePath(Dir);

  while (Length(Dir) > 0) and (Dir[Length(Dir)] = '\') do
    Delete(Dir, Length(Dir), 1);

  if (Dir <> '') and (Dir <> '\') and (Dir <> '.') then
  begin
    SetArrayLength(Dirs, Length(Dirs) + 1);
    Dirs[Length(Dirs) - 1] := Dir;
  end;
end;

procedure DetectExistingInstall();
var
  ExtraDirs, SteamCommonFolders, ClassicDirs: TArrayOfString;
  DetectedDir: String;
begin
  if DetectionDone then Exit;
  DetectionDone := True;
  DetectedInstallPath := ClassicInstallDir;

  // 1. Registry (original install paths, both registry views)
  SetArrayLength(ExtraDirs, 0);
  AddRegistryDir(ExtraDirs, QueryGameRegValue(GameRegKeyWestwood, 'InstallPath'));
  AddRegistryDir(ExtraDirs, QueryGameRegValue(GameRegKeyTFD, 'r2_folder'));
  AddRegistryDir(ExtraDirs, QueryGameRegValue(GameRegKeyOrigin, 'Install Dir'));

  // 2. Steam library folders (standalone app + First Decade bundle,
  // English + German)
  SetArrayLength(SteamCommonFolders, 3);
  SteamCommonFolders[0] := SteamGameFolderStandalone;
  SteamCommonFolders[1] := SteamGameFolderEnglish;
  SteamCommonFolders[2] := SteamGameFolderGerman;

  // 3. Classic install locations
  SetArrayLength(ClassicDirs, 4);
  ClassicDirs[0] := ExpandConstant('{pf}\EA Games\Command & Conquer The First Decade\Command & Conquer Red Alert(tm) II\RA2');
  ClassicDirs[1] := ExpandConstant('{pf}\EA Games\Command & Conquer Die ersten 10 Jahre\Command & Conquer Red Alert(tm) II\RA2');
  ClassicDirs[2] := ExpandConstant('{pf}\Origin Games\Command and Conquer Red Alert II');
  ClassicDirs[3] := ClassicInstallDir;

  if CncnetDetectGame(GameCheckFile, ExtraDirs, SteamCommonFolders, ClassicDirs, DetectedDir) then
    DetectedInstallPath := DetectedDir;
end;

// Default install directory: the detected game install (this client is a patch), else the classic location.
function GetDefaultDir(Param: String): String;
begin
  DetectExistingInstall();
  Result := DetectedInstallPath;
end;

// ============================================================ Dependencies

// Registers all machine-wide dependencies; the library only keeps the ones that are actually missing.
procedure RegisterDependencies;
begin
  // The client tooling is a .NET Framework 4.x app.
  Dependency_AddDotNet48;

  // The RA2 engine (YR) and the CnCNet client components are 32-bit and import the VC++ 2005-2022
  // runtimes - force the x86 variants even on 64-bit setups; x64 covers 64-bit tooling.
  Dependency_ForceX86 := True;
  Dependency_AddVC2005;
  Dependency_AddVC2008;
  Dependency_AddVC2010;
  Dependency_AddVC2012;
  Dependency_AddVC2013;
  Dependency_AddVC2015To2022;
  Dependency_ForceX86 := False;

  if IsWin64 then
  begin
    Dependency_AddVC2005;
    Dependency_AddVC2008;
    Dependency_AddVC2010;
    Dependency_AddVC2012;
    Dependency_AddVC2013;
    Dependency_AddVC2015To2022;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;

  // Under Wine the Windows runtimes come from Wine itself; the machine-wide installers cannot run there.
  if CncnetRunsOnWine() then
  begin
    Log('Running on Wine: skipping machine-wide dependency registration.');
    Exit;
  end;

  RegisterDependencies;

  if CncnetIsUserAnAdmin() then
  begin
    // All-users install: the library downloads and installs everything still missing (Dependency_PrepareToInstall).
    if GetArrayLength(Dependency_List) > 0 then
      Log('All-users install: installing missing machine-wide dependencies first.');
  end
  else
  begin
    // Per-user: the redistributables are machine-wide and require elevation; collect the missing
    // ones for the ready-page warning (CncnetWarnMissingDeps) and unqueue them.
    CncnetCollectPerUserDeps(PerUserMissingDeps);
  end;
end;

// ================================================================== Wizard

procedure InitializeWizard();
var
  Memo: TRichEditViewer;
begin
  DetectExistingInstall();

  WizardForm.SelectDirBrowseLabel.Visible := false;
  ISTheme();

  // Wizard title bar: client version + installer version (rendered by build-installer, Pascal-escaped).
  WizardForm.Caption := '{{ wizardCaption }}';

  // Custom welcome page with the installScript.vdf backup note; created after ISTheme() for the final form geometry.
  CustomPage := CreateCustomPage(wpWelcome, 'Welcome to the CnCNet Red Alert 2 Yuri''s Revenge Setup', 'Need help? Join our Discord: cncnet.org/discord');

  Memo := TRichEditViewer.Create(WizardForm);
  Memo.Parent := CustomPage.Surface;
  Memo.SetBounds(0, 0, CustomPage.SurfaceWidth, CustomPage.SurfaceHeight);
  Memo.ReadOnly := True;
  Memo.ScrollBars := ssVertical;
  Memo.WordWrap := True;
  Memo.Text := 'Important info, please read!'#13#10#13#10'This installer will move Steams "installScript.vdf" to "Backup\installScript.vdf", this is done to ensure the correct compatibility flags are set for the CnCNet Client to function correctly.';
  // Match the shared theme's textbox look (silver background, black text).
  // Pre-quoted so Twig does not swallow the leading brace-hash as a comment start.
  Memo.Font.Color := {{ '{#' }}ISThemeTextBoxForeColor};
  Memo.Color := {{ '{#' }}ISThemeTextBoxBackColor};

  // Give the InnoDependencyInstaller dependency page the shared layout (the library's PrepareToInstall then shows it).
  CncnetSetupDependencyDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  // License radio labels: Inno 7 draws the captions in black - replace them with themed labels (shared implementation).
  CncnetThemeLicenseRadios();
end;

function NextButtonClick(CurPage: Integer): Boolean;
begin
  Result := True;

  if (CurPage = wpSelectDir) then
  begin
    if not CncnetGotWritePermissions(ExpandConstant('{app}')) then
    begin
      // Smart UAC: offer the elevated relaunch for this folder; no prompt in silent installs (the abort is logged).
      CncnetWriteDenied(
        ExpandConstant('{app}'),
        ExpandConstant('{cm:WriteDeniedPrompt}'),
        ExpandConstant('{cm:AccessDenied}'));
      Result := False;
      Exit;
    end;

    // Patch: the target folder must contain the game (gamemd.exe).
    // Silent-safe: no prompt in silent installs, the abort is logged.
    if not FileExists(ExpandConstant('{app}\gamemd.exe')) then
    begin
      if not WizardSilent then
        MsgBox(FmtMessage(ExpandConstant('{cm:GameNotFound}'), [WizardForm.DirEdit.Text]), mbConfirmation, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  if (CurPage = wpReady) then
  begin
    ForceDirectories(ExpandConstant('{app}'));
    // Smart UAC: elevation is only offered here (deps missing in a per-user install), never at startup;
    // the runyrdiag task selection is carried into the elevated instance.
    CncnetWarnMissingDeps(
      PerUserMissingDeps,
      ExpandConstant('{cm:PerUserMissingDeps}'),
      ExpandConstant('{cm:PerUserMissingDepsFailed}'),
      'runyrdiag');
  end;
end;

// YRDiag.exe's manifest requires elevation (a plain launch from per-user setup fails with error 740);
// ask first, then start it elevated via the shared smart-UAC helper. Defined before CurStepChanged
// (Inno's script Pascal has no forward references).
procedure CncnetRunYRDiag();
begin
  if not WizardIsTaskSelected('runyrdiag') then
    Exit;

  CncnetRunElevated(
    ExpandConstant('{app}\YRDiag.exe'),
    ExpandConstant('{app}'),
    ExpandConstant('{cm:RunDiagPrompt}'),
    ExpandConstant('{cm:RunDiagSkipped}'));
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  SteamInstallScript, SteamInstallScriptDest: String;
begin
  if CurStep = ssInstall then
  begin
    // Move Steam's installScript.vdf out of the way: it holds the compatibility flags Steam wrote
    // for the game, and the installer's AppCompat entries must win.
    SteamInstallScript := ExpandConstant('{app}\installScript.vdf');
    SteamInstallScriptDest := ExpandConstant('{app}\Backup\installScript.vdf');

    if not DirExists(ExtractFilePath(SteamInstallScriptDest)) then
    begin
      if not ForceDirectories(ExtractFilePath(SteamInstallScriptDest)) then
      begin
        MsgBox('Failed to create backup directory for Steam install script.', mbError, MB_OK);
        Exit;
      end;
    end;

    if FileExists(SteamInstallScript) then
    begin
      if not RenameFile(SteamInstallScript, SteamInstallScriptDest) then
      begin
        MsgBox('Failed to move the file from ' + SteamInstallScript + ' to ' + SteamInstallScriptDest, mbError, MB_OK);
      end;
    end;
  end;

  if CurStep = ssPostInstall then
    // YRDiag.exe (task 'runyrdiag'): started elevated before the finished page (a plain [Run] would fail with 740).
    CncnetRunYRDiag();
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
  begin
    WizardForm.NextButton.Caption := SetupMessage(msgButtonInstall);
    WizardForm.BackButton.Visible := False;
  end;

  if CurPageID = wpLicense then
    WizardForm.NextButton.Caption := ExpandConstant('{cm:Agree}');
end;
