; =============================================================================
; CnCNet Red Alert client installer (Inno Setup 7).
; Per-user install by default; all-users can be opted into at startup (UAC).
; Machine-wide dependencies only run for the elevated (all-users) install.
; MOVIES - PLACEHOLDER: the RA1 movie file structure is not finalized yet (the movies currently
; live inside main.mix and will be extracted later); the movies flow is already wired - the profile's
; placeholder entry, the unchecked task and the MAIN2.MIX -> MOVIES-10.MIX mapping are to be replaced.
; Source template: the build renders this to installer.iss (Twig) - edit this file, never the output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Allows adding dependency installers: https://github.com/DomGries/InnoDependencyInstaller

; RA1 palette: the RA1 artwork is dark red, so the shared dark theme with the shared cream
; fore color keeps the labels readable; text boxes stay white with black text.
#define ISThemeBackColor = '$000000'
#define ISThemeForeColor = '$FFF4E8'
#define ISThemeTextBoxBackColor = '$FFFFFF'
#define ISThemeTextBoxForeColor = '$000000'

[Code]
// All library includes live at the top of the [Code] section; their [Code] sections splice into this one.
#include "libs/InnoDependencyInstaller/CodeDependencies.iss"
#include "libs/ISTheme/ISTheme.iss"
#include "libs/CncnetCommon/CncnetCommon.iss"

[CustomMessages]
AccessDenied=Access to: %1 denied. %n Please choose a different directory or restart the installer as administrator (right-click the installer and choose "Run as administrator"). %n If the installer already runs elevated, make sure your Anti-Virus program does not block the installer (turn it off temporarily if you do not know how to configure it)
WriteDeniedPrompt=Access to: %1 denied for the current user. %n%nElevate now and continue the install into this folder for all users? Choosing No keeps the per-user install (choose a different folder instead).
InstallingApp=Installing %1, this may take several minutes...
NotAPatchError=An existing Red Alert game was detected in the selected folder. %n%n CnCNet Red Alert is a complete client, not a patch for the game, and cannot be installed into a folder that contains the original game. %n%n Please select a different folder. (Upgrading a previous CnCNet Red Alert client install is not affected.)
GameInstallDetected=Previous Red Alert installation has been detected in: %n%n %1 %n%nDo you want the installer to copy the movies from there?
PerUserMissingDeps=The following required runtimes are missing:%n%n %1 %n%nThey are machine-wide components and cannot be installed for a single user.%n%nElevate now to install for all users and have them installed automatically? Choosing No continues the per-user install and leaves them missing.
PerUserMissingDepsFailed=Elevation failed, so the following required runtimes could not be installed - they require administrator rights:%n%n %1 %n%nPlease install them using an administrator account (each URL above points to the exact download) and then run this installer again - it will detect them and complete the setup. The per-user install continues for now, but the listed runtimes will remain missing.
Agree=&I Agree
DownloadingFiles=Downloading files
DownloadingFilesDescription=The following files will be downloaded before the installation starts. Depending on your internet connection, this may take a while.

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
DirExistsWarning=no
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableWelcomePage=yes
AllowNoIcons=yes
OutputBaseFilename={{ outputBaseFilename }}
Compression=lzma2/max
SolidCompression=yes
UsePreviouslanguage=no
CreateUninstallRegKey=yes
UsePreviousAppDir=no
UsePreviousGroup=no
SourceDir={{ innoPath }}
OutputDir={{ outputDir }}
SetupIconFile={{ setupIconFile }}
AppendDefaultDirName=no
ShowLanguageDialog=no
LicenseFile={{ licenseFile }}
ArchitecturesInstallIn64BitMode=x64compatible
UsedUserAreasWarning=no
SetupLogging=yes
; Per-user by default (no elevation needed); at startup the user is offered an all-users install
; (UAC); "commandline" also allows /ALL and /LOW overrides for scripted installs.
; All-users installs go to the previous client location (common Start Menu / public desktop);
; per-user installs go to %LocalAppData%\Programs (unless upgrading in place, see GetDefaultDir).
; The .NET / VC++ dependency installers are machine-wide and only run for elevated installs.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; PLACEHOLDER: unchecked while the RA1 movie file structure is not finalized (a default-checked
; task would download the placeholder URL). Drop the flag once the real entries land.
Name: "Installmov"; Description: "Download and install movies"; GroupDescription: "Music and movies"; Flags: unchecked

[InstallDelete]
; files to delete prior to installation (from preupdateexec/updateexec)
{% for file in installDeleteFiles %}
Type: filesandordirs; Name: "{app}\{{ file }}"
{% endfor %}

[Files]
; Installer theming resources (used at runtime, not installed), relative to SourceDir.
Source: "Resources\ra1\RedAlertWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\ra1\RedAlertInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\ra1\RedAlertPageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package; critical files are also listed explicitly (compile fails if any is missing).
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\RedAlert.exe"; DestDir: "{app}";

; Red Alert movies (PLACEHOLDER - see the header): downloaded to the temp dir in the
; "Preparing to install" step (download page with a per-file progress bar), then installed from there.
{% for movie in movies %}
Source: "{tmp}\{{ movie.file }}"; DestDir: "{app}"; DestName: "{{ movie.file }}"; Check: DownloadFullMovies; Flags: external skipifsourcedoesntexist ignoreversion
{% endfor %}

; Movies copied from a detected existing Red Alert install (the TUC game ships the movie mix as
; MAIN2.MIX, installed as MOVIES-10.MIX - PLACEHOLDER until the structure is finalized). Source left untouched.
Source: {code:GetMovieSourceDir}\MAIN2.MIX; DestDir: "{app}"; DestName: "MOVIES-10.MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion

[Icons]
; All-users (elevated) installs: common Start Menu + public desktop. WizardNoIcons honors the wizard's "no icons" checkbox.
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful; skip them.
Name: "{app}\Uninstall {{ app.name }}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{{ app.name }}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallDelete]
Type: files; Name: "{app}\version"
Type: files; Name: "{app}\version_u"
Type: files; Name: "{app}\stats.dmp"
Type: files; Name: "{app}\spawnmap.ini"
Type: files; Name: "{app}\spawn.ini"
Type: filesandordirs; Name: "{app}\INI"
Type: filesandordirs; Name: "{app}\Maps"
Type: filesandordirs; Name: "{app}\Resources"
Type: filesandordirs; Name: "{app}\Client"
Type: filesandordirs; Name: "{app}\Qt"
; Movies (PLACEHOLDER - see the [Files] section)
{% for movie in movies %}
Type: files; Name: "{app}\{{ movie.file }}"
{% endfor %}
Type: files; Name: "{app}\MOVIES-10.MIX"

[Registry]
; Enable long path support (Win 10 1607+); only relevant for elevated installs; noerror guards the write.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\FileSystem"; ValueType: dword; ValueName: "LongPathsEnabled"; ValueData: 1; Check: CncnetIsUserAnAdmin; Flags: noerror; MinVersion: 10.0.14393

[Code]
const
  GameRegKey = 'Software\Westwood\Red Alert Windows 95 Edition';
  WOW6432GameRegKey = 'Software\WOW6432Node\Westwood\Red Alert Windows 95 Edition';
  SteamGameFolder = 'Command & Conquer Red Alert';
  ClassicInstallDir = 'C:\Westwood\RedAlert';
  // Marker file of an original RA (TUC) install; the detected install is only used as the movie-copy source.
  GameCheckFile = 'RA95.EXE';

var
  GameDetected: Boolean;
  DetectedInstallPath: String;
  DetectionDone: Boolean;
  DetectedMoviesAnswer: Boolean;
  // Missing machine-wide dependencies that cannot be installed in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;

// ================================================== Existing install lookup
// Shared ordered lookup (CncnetDetectGame): registry installpath as ExtraDirs, the Steam folder as
// SteamCommonFolders, the classic location as ClassicDirs; first dir with RA95.EXE wins.
// The detected path is used as the source for copying movies from (and shown in the movies prompt).
procedure DetectExistingInstall();
var
  RegistryPath: String;
  ExtraDirs, SteamCommonFolders, ClassicDirs: TArrayOfString;
  DetectedDir: String;
begin
  if DetectionDone then Exit;
  DetectionDone := True;
  GameDetected := False;
  DetectedInstallPath := ClassicInstallDir;

  // 1. Registry (original install path, both views)
  SetArrayLength(ExtraDirs, 0);
  if RegQueryStringValue(HKLM, GameRegKey, 'installpath', RegistryPath) then
  begin
    RegistryPath := ExtractFilePath(RegistryPath);
    if RegistryPath <> '' then
    begin
      SetArrayLength(ExtraDirs, Length(ExtraDirs) + 1);
      ExtraDirs[Length(ExtraDirs) - 1] := RegistryPath;
    end;
  end;
  if RegQueryStringValue(HKLM, WOW6432GameRegKey, 'installpath', RegistryPath) then
  begin
    RegistryPath := ExtractFilePath(RegistryPath);
    if RegistryPath <> '' then
    begin
      SetArrayLength(ExtraDirs, Length(ExtraDirs) + 1);
      ExtraDirs[Length(ExtraDirs) - 1] := RegistryPath;
    end;
  end;

  // 2. Steam library folders (shared lookup, both config.vdf locations)
  SetArrayLength(SteamCommonFolders, 1);
  SteamCommonFolders[0] := SteamGameFolder;

  // 3. Classic install location
  SetArrayLength(ClassicDirs, 1);
  ClassicDirs[0] := ClassicInstallDir;

  if CncnetDetectGame(GameCheckFile, ExtraDirs, SteamCommonFolders, ClassicDirs, DetectedDir) then
  begin
    GameDetected := True;
    DetectedInstallPath := DetectedDir;
  end;
end;

// Default install directory: all-users -> C:\Program Files\CnCNet\Red Alert; per-user -> %LocalAppData%\Programs
// (in place when a previous client install is there). The select-dir write-permission test still
// verifies the directory is writable.
// The detected existing game install is NOT the default: this client is not a patch and must not be
// installed into a game folder (enforced in NextButtonClick); it is only the movie-copy source.
function GetDefaultDir(Param: String): String;
begin
  if (CncnetIsUserAnAdmin()) or (FileExists(ExpandConstant('{pf}\CnCNet\Red Alert\RedAlert.exe'))) then
  begin
    Result := ExpandConstant('{pf}\CnCNet\Red Alert');
    Exit;
  end;

  Result := ExpandConstant('{userpf}\CnCNet Red Alert');
end;

function GetMovieSourceDir(Param: String): String;
begin
  DetectExistingInstall();
  Result := DetectedInstallPath;
end;

// ================================================================== Movies

function UseDetectedMovies(): Boolean;
begin
  Result := DetectedMoviesAnswer;
end;

// Download the full movies when the task is selected and the movies of a detected existing install are not used.
function DownloadFullMovies(): Boolean;
begin
  Result := WizardIsTaskSelected('Installmov') and (not DetectedMoviesAnswer);
end;

// Decides whether to copy the movies from a detected existing install or to download the full movies.
// Silent installs: use the detected install's movies when found and the task is selected; otherwise follow the task.
function PrepareMovies(): Boolean;
begin
  if WizardSilent then
  begin
    DetectedMoviesAnswer := GameDetected and WizardIsTaskSelected('Installmov');
    Exit;
  end;

  if GameDetected then
    DetectedMoviesAnswer :=
      (MsgBox(FmtMessage(ExpandConstant('{cm:GameInstallDetected}'), [DetectedInstallPath]), mbConfirmation, MB_YESNO) = IDYES);

  Result := True;
end;

// ------------------------------------------------------------------ Download

// Movie metadata generated from the movies array in the profile (the same array as the [Files] section).
function GetMovieUrl(const Index: Integer): String;
begin
  case Index of
  {% for movie in movies %}
    {{ loop.index0 }}: Result := '{{ movie.url }}';
  {% endfor %}
  else
    Result := '';
  end;
end;

function GetMovieFile(const Index: Integer): String;
begin
  case Index of
  {% for movie in movies %}
    {{ loop.index0 }}: Result := '{{ movie.file }}';
  {% endfor %}
  else
    Result := '';
  end;
end;

// Movie sizes in KB (the profile's values; the shared engine converts to bytes).
function GetMovieSizeKB(const Index: Integer): Integer;
begin
  case Index of
  {% for movie in movies %}
    {{ loop.index0 }}: Result := {{ movie.sizeKB }};
  {% endfor %}
  else
    Result := 0;
  end;
end;

// "Preparing to install" step: downloads the movie files to the temp dir with a real progress bar
// (the shared download page); the [Files] section installs them from there.
// Runs after InnoDependencyInstaller's PrepareToInstall (same-name events run in include order);
// returning a non-empty string aborts the install.
function prepareToInstall(var NeedsRestart: Boolean): String;
var
  MovieIndex: Integer;
begin
  Result := '';

  if DownloadFullMovies then
  begin
    CncnetDlQueueReset();
    for MovieIndex := 0 to {{ movies|length }} - 1 do
      CncnetDlQueueAdd(GetMovieUrl(MovieIndex), GetMovieFile(MovieIndex), '', GetMovieSizeKB(MovieIndex));
    if not CncnetDlDownloadAll() then
      Result := 'The download of the Red Alert movies was stopped.';
  end;
end;

// ============================================================ Dependencies

// Registers all machine-wide dependencies; the library only keeps the ones that are actually missing.
procedure RegisterDependencies;
begin
  // The client tooling is a .NET Framework 4.x app.
  Dependency_AddDotNet48;

  // The Red Alert 95 engine and the CnCNet client components are 32-bit and import the VC++ 2005-2022
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

  Result := true;
end;

// ================================================================== Wizard

procedure InitializeWizard();
begin
  DetectExistingInstall();

  WizardForm.SelectDirBrowseLabel.Visible := false;
  ISTheme();

  // Wizard title bar: client version + installer version (rendered by build-installer, Pascal-escaped).
  WizardForm.Caption := '{{ wizardCaption }}';

  // The license memo follows the page theme (dark + cream); the dir page's edit stays white with black text.
  WizardForm.LicenseMemo.Color := {{ '{#' }}ISThemeBackColor};
  WizardForm.LicenseMemo.Font.Color := {{ '{#' }}ISThemeForeColor};

  // Download page for the movies (shared lib; hidden until prepareToInstall shows it).
  CncnetSetupDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

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

    // This client is not a patch: installing into a folder that contains the original game (RA95.EXE) is refused;
    // a folder with the client launcher (RedAlert.exe) is a previous client install - the normal in-place upgrade.
    if FileExists(ExpandConstant('{app}\RA95.EXE')) and
       (not FileExists(ExpandConstant('{app}\RedAlert.exe'))) then
    begin
      if not WizardSilent then
        MsgBox(ExpandConstant('{cm:NotAPatchError}'), mbInformation, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  if (CurPage = wpReady) then
  begin
    ForceDirectories(ExpandConstant('{app}'));
    // Smart UAC: elevation is only offered here (deps missing in a per-user install), never at startup.
    CncnetWarnMissingDeps(
      PerUserMissingDeps,
      ExpandConstant('{cm:PerUserMissingDeps}'),
      ExpandConstant('{cm:PerUserMissingDepsFailed}'),
      'Installmov');
    PrepareMovies();
  end;
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
