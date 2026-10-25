; =============================================================================
; CnCNet Red Alert 2 Yuri's Revenge client installer
;
; This client is a PATCH: it installs the CnCNet files into the user's
; existing Red Alert 2 Yuri's Revenge game folder. The dir page validates
; that the chosen folder contains the game (gamemd.exe), and the default
; directory is the detected game install (registry / Steam library /
; classic locations) or C:\Westwood\RA2 when nothing is found.
;
; Install scope: per-user by default (no elevation needed). At startup the
; user can opt into an all-users install (UAC prompt). The machine-wide
; dependency installers only run for all-users (elevated) installs.
;
; Shared functionality (admin/wine detection, Steam install lookup,
; write-permission test, per-user deps + elevation relaunch, the dependency
; download page) lives in libs/CncnetCommon/CncnetCommon.iss and is
; #include'd below; this template keeps the YR-specific policy code.
;
; This is the source template. The build renders it to installer.iss (Twig,
; "npm run build-installer") - edit this file, never the generated output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Allows us to add dependency installers
; https://github.com/DomGries/InnoDependencyInstaller

[Code]
// All library includes live at the top of the [Code] section (the same
// shape as the RA1 template): their [Code] sections splice into this one,
// and the policy code below follows them.
// No palette #defines are needed: the shared ISTheme defaults ARE the YR
// dark palette (black background, cream text, silver text boxes).
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
; The target folder already exists (this is a patch into the game folder);
; do not warn about it.
DirExistsWarning=no
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableWelcomePage=yes
; The finished page is kept (not disabled): YRDiag.exe runs before the
; finished page and needs time to complete, so the launcher must not be
; auto-launched too early (the legacy YR installer kept it enabled for the
; same reason).
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
; Per-user (current user) install by default: no elevation is needed, and
; non-administrators can install without any extra step. At startup the
; user is offered the chance to install for all users instead (UAC prompt);
; "dialog commandline" also allows /ALL and /LOW command line overrides for
; scripted installs.
;
; The .NET / VC++ dependency installers are machine-wide and require
; elevation, so they only run for all-users (elevated) installs - see
; InitializeSetup below.
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
; Installer theming resources (used at runtime, not installed). Relative to
; [Setup] SourceDir (the inno dir) - the same shape as the TS/RA1 templates.
; The source names are prefixed per game; DestName maps them back to the
; generic names ISTheme() loads from the temp dir.
Source: "Resources\yr\YurisRevengeWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\yr\YurisRevengeInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\yr\YurisRevengePageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package (referenced by absolute path; critical files are also
; listed explicitly below so the compile fails if any of them is missing)
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\gamemd-spawn.exe"; DestDir: "{app}";
Source: "{{ sourceDir }}\YRDiag.exe"; DestDir: "{app}";

[Icons]
; All-users (elevated) installs: common Start Menu (Start Menu > CnCNet >
; <app name>) and the public desktop. WizardNoIcons honors the wizard's
; "Don't create any icons for this application" checkbox (AllowNoIcons=yes).
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\CnCNetYRLauncher.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful (like the legacy YR
; installer), so they are skipped there.
Name: "{app}\Uninstall {{ app.name }}"; Filename: "{uninstallexe}"

[Run]
; The diagnostic tool (task 'runyrdiag') needs time to finish before the
; game is launched, which is why the launcher launch is deferred to the
; finished page (postinstall).
; YRDiag.exe is NOT a [Run] entry: its manifest requires elevation, and a
; plain launch from the per-user setup fails with error 740
; (ERROR_ELEVATION_REQUIRED). It is started elevated from CurStepChanged
; (see [Code]) with a user prompt - ask first, then 'runas' + UAC.
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
; Enable long path support (Windows 10 1607+). Only possible (and only
; relevant) for elevated all-users installs; noerror guards the write.
Root: HKLM; Subkey: SYSTEM\CurrentControlSet\Control\FileSystem; ValueType: dword; ValueName: LongPathsEnabled; ValueData: 1; Check: CncnetIsUserAnAdmin; Flags: noerror; MinVersion: 10.0.14393

; AppCompat cleanup of legacy compatibility flags for the game EXEs
; (carried over from the legacy YR installer). The HKCU entries do not need
; elevation; the HKLM ones only apply to elevated all-users installs.
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\Ra2.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\Ra2.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\RA2MD.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\RA2MD.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\YURI.exe; Flags: deletevalue
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueName: {app}\YURI.exe; Flags: deletevalue; Check: CncnetIsUserAnAdmin

; High-DPI awareness for the game spawn process (legacy YR behavior).
Root: HKCU; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueType: String; ValueName: {app}\gamemd-spawn.exe; ValueData: "HIGHDPIAWARE"
Root: HKLM; Subkey: Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers; ValueType: String; ValueName: {app}\gamemd-spawn.exe; ValueData: "HIGHDPIAWARE"; Check: CncnetIsUserAnAdmin

; Wine: per-app defaults for the game spawn process (the same values the
; package's YRLauncherUnix.sh writes at runtime, so a fresh install also
; works under Wine out of the box).
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe; ValueType: string; ValueName: Version; ValueData: win10; Check: CncnetRunsOnWine
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe\DllOverrides; ValueType: string; ValueName: ddraw; ValueData: native, builtin; Check: CncnetRunsOnWine
Root: HKCU; Subkey: Software\Wine\AppDefaults\gamemd-spawn.exe\DllOverrides; ValueType: string; ValueName: wsock32; ValueData: native, builtin; Check: CncnetRunsOnWine

[Code]
const
  // The registry keys that may point at an existing Red Alert 2 /
  // Yuri's Revenge install. Each key is read from both the 32-bit (HKLM)
  // and the 64-bit (HKLM64) registry views: the legacy Westwood key is a
  // 32-bit key, the EA keys may live in the 64-bit view. The value may be
  // the install directory or a full path to the game EXE (AddRegistryDir
  // normalizes both). Keys and value names are from the legacy YR
  // installer (verified in production).
  GameRegKeyWestwood = 'Software\Westwood\Red Alert 2';
  GameRegKeyTFD = 'Software\Electronic Arts\EA Games\Command and Conquer The First Decade';
  GameRegKeyOrigin = 'Software\EA Games\Command and Conquer Red Alert II';
  // Steam library game folders; the shared lookup checks
  // <library root>\steamapps\common\<folder> for each Steam library root.
  // The standalone Steam Red Alert 2 / Yuri's Revenge app installs into
  // 'Command & Conquer Red Alert II' (gamemd.exe marks it as YR, so a plain
  // RA2 install in the same folder is not a false positive); the First
  // Decade bundle (English + German) uses the nested EA Games path.
  SteamGameFolderStandalone = 'Command & Conquer Red Alert II';
  SteamGameFolderEnglish = 'EA Games\Command & Conquer The First Decade\Command & Conquer Red Alert(tm) II\RA2';
  SteamGameFolderGerman = 'EA Games\Command & Conquer Die ersten 10 Jahre\Command & Conquer Red Alert(tm) II\RA2';
  // The classic (original) install location - also the fallback default
  // when no install is detected.
  ClassicInstallDir = 'C:\Westwood\RA2';
  // The marker EXE of a Yuri's Revenge game install. This client is a patch
  // and must be installed into a folder that contains the game. 'gamemd.exe'
  // (game + mission disk) is the YR engine EXE - the launchers (ra2.exe /
  // yuri.exe) are present inconsistently across releases, so they are not a
  // reliable marker (the legacy installer used ra2md.mix for the same reason).
  GameCheckFile = 'gamemd.exe';

var
  DetectedInstallPath: String;
  DetectionDone: Boolean;
  // Titles of the machine-wide dependencies that are missing and cannot be
  // installed automatically in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;
  // The custom welcome page (created in InitializeWizard).
  CustomPage: TWizardPage;

// ================================================== Existing install lookup
//
// Detects an existing Red Alert 2 Yuri's Revenge install with the shared
// ordered lookup (CncnetDetectGame): the registry install paths (the three
// game keys, both registry views) are passed as ExtraDirs, the Steam First
// Decade game folders as SteamCommonFolders and the classic locations as
// ClassicDirs; the first directory containing gamemd.exe wins.
//
// Unlike the standalone TS/RA1 clients, this client is a patch: the
// detected game folder IS the install target (see GetDefaultDir), and the
// dir page validates that the chosen folder contains the game.
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

// Adds a candidate install directory to the lookup list. The registry
// value may be a directory (with or without a trailing backslash) or a
// full path to the game EXE - both are normalized to a bare directory.
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

// Default install directory: the detected game install (this client is a
// patch and installs INTO the game folder), or the classic location
// C:\Westwood\RA2 when no install was found - the dir-page validation then
// asks the user to pick the real game folder.
function GetDefaultDir(Param: String): String;
begin
  DetectExistingInstall();
  Result := DetectedInstallPath;
end;

// ============================================================ Dependencies

// Registers all machine-wide dependencies. The library only keeps the ones
// that are actually missing (Dependency_AddIfMissing), so afterwards
// Dependency_List holds exactly the missing ones.
procedure RegisterDependencies;
begin
  // The client tooling is a .NET Framework 4.x app.
  Dependency_AddDotNet48;

  // The Red Alert 2 engine (Yuri's Revenge) and the CnCNet client
  // components are 32-bit and import the Visual C++ 2005-2022 runtimes, so
  // force the x86 variants even for 64-bit setups; the x64 variants cover
  // 64-bit tooling. (The same set as the RA1 installer, verified in
  // production.)
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

  // Under Wine the Windows runtimes come from Wine itself; the
  // machine-wide dependency installers cannot run there (legacy YR
  // behavior).
  if CncnetRunsOnWine() then
  begin
    Log('Running on Wine: skipping machine-wide dependency registration.');
    Exit;
  end;

  RegisterDependencies;

  if CncnetIsUserAnAdmin() then
  begin
    // All-users (elevated) install: the library downloads and installs
    // everything still in Dependency_List before the install starts
    // (Dependency_PrepareToInstall).
    if GetArrayLength(Dependency_List) > 0 then
      Log('All-users install: installing missing machine-wide dependencies first.');
  end
  else
  begin
    // Per-user install: the .NET / VC++ redistributables are machine-wide
    // installers that require elevation, so they cannot be installed here.
    // Collect the missing ones for the ready-page warning
    // (CncnetWarnMissingDeps) and unqueue them so the library does not try
    // to install them.
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

  // Wizard title bar: client version + installer version (rendered by
  // build-installer; the value is Pascal-escaped for this string literal).
  WizardForm.Caption := '{{ wizardCaption }}';

  // Custom welcome page (the text is the verified legacy wording): the
  // installScript.vdf backup note. Created after ISTheme() so it gets the
  // final form geometry.
  CustomPage := CreateCustomPage(wpWelcome, 'Welcome to the CnCNet Red Alert 2 Yuri''s Revenge Setup', 'Need help? Join our Discord: cncnet.org/discord');

  Memo := TRichEditViewer.Create(WizardForm);
  Memo.Parent := CustomPage.Surface;
  Memo.SetBounds(0, 0, CustomPage.SurfaceWidth, CustomPage.SurfaceHeight);
  Memo.ReadOnly := True;
  Memo.ScrollBars := ssVertical;
  Memo.WordWrap := True;
  Memo.Text := 'Important info, please read!'#13#10#13#10'This installer will move Steams "installScript.vdf" to "Backup\installScript.vdf", this is done to ensure the correct compatibility flags are set for the CnCNet Client to function correctly.';
  // Match the shared theme's textbox look (silver background, black text) -
  // the default ISTheme values. The pre-quoted string renders a literal
  // Inno preprocessor constant reference (Twig would otherwise swallow the
  // leading brace-hash sequence as the start of a comment).
  Memo.Font.Color := {{ '{#' }}ISThemeTextBoxForeColor};
  Memo.Color := {{ '{#' }}ISThemeTextBoxBackColor};

  // Give the InnoDependencyInstaller dependency page the shared layout
  // (recreated here with the shared progress callback; the library's
  // PrepareToInstall then shows it for its queued runtimes).
  CncnetSetupDependencyDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  // License radio labels: Inno 7's TNewRadioButton ignores Color and always
  // draws its caption in black - unreadable on the dark theme artwork.
  // Replace each native caption with a themed TLabel beside the circle
  // (shared implementation, libs/CncnetCommon); clicking the label checks
  // the underlying radio, which Inno's Next-button gating reads.
  CncnetThemeLicenseRadios();
end;

function NextButtonClick(CurPage: Integer): Boolean;
begin
  Result := True;

  if (CurPage = wpSelectDir) then
  begin
    if not CncnetGotWritePermissions(ExpandConstant('{app}')) then
    begin
      // Smart UAC: offer the elevated relaunch (the same mechanism as the
      // ready-page deps prompt) so an elevated instance can install into
      // this folder; declining or failing falls back to the plain
      // access-denied explanation. In silent installs no prompt is shown
      // (the abort ends up in the install log).
      CncnetWriteDenied(
        ExpandConstant('{app}'),
        ExpandConstant('{cm:WriteDeniedPrompt}'),
        ExpandConstant('{cm:AccessDenied}'));
      Result := False;
      Exit;
    end;

    // This client is a patch: the target folder must contain the game
    // (gamemd.exe), or the client files would mix with a different game
    // install. Silent-safe: no prompt is shown in silent installs, the
    // abort is logged.
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
    // Smart UAC: only here (deps missing in a per-user install) is
    // elevation offered - never at startup. The runyrdiag task selection
    // is carried into the elevated instance.
    CncnetWarnMissingDeps(
      PerUserMissingDeps,
      ExpandConstant('{cm:PerUserMissingDeps}'),
      ExpandConstant('{cm:PerUserMissingDepsFailed}'),
      'runyrdiag');
  end;
end;

// YRDiag.exe carries a manifest that requires elevation: a plain launch
// from the per-user setup fails with error 740 (ERROR_ELEVATION_REQUIRED).
// Ask the user first, then start it elevated via the shared smart-UAC
// helper (libs/CncnetCommon) - the same ask-then-elevate shape as the
// dir-page write-denied offer. Defined before CurStepChanged (Inno's
// script Pascal has no forward references).
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
    // Move Steam's installScript.vdf out of the way: it holds the
    // compatibility flags Steam wrote for the game, and the installer's
    // AppCompat entries must win (the legacy YR installer did the same).
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
    // The diagnostic tool (task 'runyrdiag'): started elevated here, right
    // before the finished page - the moment its old [Run] entry used to
    // fire (and fail with error 740).
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
