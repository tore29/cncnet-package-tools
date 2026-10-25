; =============================================================================
; CnCNet Red Alert client installer
;
; Install scope: per-user by default (no elevation needed). At startup the
; user can opt into an all-users install (UAC prompt). The machine-wide
; dependency installers only run for all-users (elevated) installs.
;
; Shared functionality (admin/wine detection, Steam install lookup,
; write-permission test, per-user deps + elevation relaunch, the generic
; download page) lives in libs/CncnetCommon/CncnetCommon.iss and is
; #include'd below; this template keeps the RA1-specific policy code.
;
; MOVIES - PLACEHOLDER: the RA1 movie file structure is not finalized yet
; (the movies currently live inside main.mix and will be extracted to their
; own file(s) at a later date). The whole movies flow (task, detected-install
; prompt, download page, [Files] entries, UninstallDelete) is already wired;
; the placeholder entry in the profile's movies array, the task's unchecked
; flag and the MAIN2.MIX -> MOVIES-10.MIX copy mapping below are placeholders
; to replace once the structure is finalized.
;
; This is the source template. The build renders it to installer.iss (Twig,
; "npm run build-installer") - edit this file, never the generated output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Allows us to add dependency installers
; https://github.com/DomGries/InnoDependencyInstaller

; RA1 palette: DARK, like the YR/TS themes (the RA1 artwork is dark red).
; The fore color is the shared cream so the page labels and radio captions
; stay readable on the dark red RA1 artwork, same overlay approach as the
; YR template. Text boxes stay white with black text (legacy RAPatch
; values, visible on the license memo and the dir edit).
; (The legacy 'light' ISThemeBackColor='$FFFFFF' was wrong for Inno 7: it
; painted white panels behind the finished-page label/run list.)
#define ISThemeBackColor = '$000000'
#define ISThemeForeColor = '$FFF4E8'
#define ISThemeTextBoxBackColor = '$FFFFFF'
#define ISThemeTextBoxForeColor = '$000000'

[Code]
// All library includes live at the top of the single [Code] section (the
// same shape as the TS template): their [Code] sections splice into this
// one, and the policy code below follows them.
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
; Per-user (current user) install by default: no elevation is needed, and
; non-administrators can install without any extra step. At startup the
; user is offered the chance to install for all users instead (UAC prompt);
; "dialog commandline" also allows /ALL and /LOW command line overrides for
; scripted installs.
;
; All-users installs go to the previous CnCNet Red Alert client location
; with common Start Menu / public desktop shortcuts. Per-user installs go
; to %LocalAppData%\Programs with per-user shortcuts (unless a previous
; client install is at the legacy location, see GetDefaultDir).
;
; The .NET / VC++ dependency installers are machine-wide and require
; elevation, so they only run for all-users (elevated) installs - see
; InitializeSetup below.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; PLACEHOLDER: unchecked while the RA1 movie file structure (and therefore
; the movies URLs/sizes) is not finalized yet - a default-checked task would
; download the placeholder URL. Drop the flag once the real entries land.
Name: "Installmov"; Description: "Download and install movies"; GroupDescription: "Music and movies"; Flags: unchecked

[InstallDelete]
; files to delete prior to installation (from preupdateexec/updateexec)
{% for file in installDeleteFiles %}
Type: filesandordirs; Name: "{app}\{{ file }}"
{% endfor %}

[Files]
; Installer theming resources (used at runtime, not installed). Relative to
; [Setup] SourceDir (the inno dir) - the same shape as the TS template.
Source: "Resources\ra1\RedAlertWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\ra1\RedAlertInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\ra1\RedAlertPageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package (referenced by absolute path; critical files are also
; listed explicitly below so the compile fails if any of them is missing)
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\RedAlert.exe"; DestDir: "{app}";

; Red Alert movies (PLACEHOLDER - see the header): downloaded to the temp
; directory in the "Preparing to install" step (see prepareToInstall below,
; on a download page with a real per-file progress bar), then installed
; from there.
{% for movie in movies %}
Source: "{tmp}\{{ movie.file }}"; DestDir: "{app}"; DestName: "{{ movie.file }}"; Check: DownloadFullMovies; Flags: external skipifsourcedoesntexist ignoreversion
{% endfor %}

; Movies copied from a detected existing Red Alert install (legacy mapping:
; the TUC movie mix MAIN2.MIX installed as MOVIES-10.MIX - PLACEHOLDER until
; the file structure is finalized). The source install is left untouched.
Source: {code:GetMovieSourceDir}\MAIN2.MIX; DestDir: "{app}"; DestName: "MOVIES-10.MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion

[Icons]
; All-users (elevated) installs: common Start Menu (Start Menu > CnCNet >
; <app name>) and the public desktop. WizardNoIcons honors the wizard's
; "Don't create any icons for this application" checkbox (AllowNoIcons=yes),
; like the legacy ts-client-installer does.
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\RedAlert.exe"; WorkingDir: "{app}"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful (like the Yuri's Revenge
; installer), so they are skipped there.
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
; Enable long path support (Windows 10 1607+). Only possible (and only
; relevant) for elevated all-users installs; noerror guards the write.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\FileSystem"; ValueType: dword; ValueName: "LongPathsEnabled"; ValueData: 1; Check: CncnetIsUserAnAdmin; Flags: noerror; MinVersion: 10.0.14393

[Code]
const
  GameRegKey = 'Software\Westwood\Red Alert Windows 95 Edition';
  WOW6432GameRegKey = 'Software\WOW6432Node\Westwood\Red Alert Windows 95 Edition';
  SteamGameFolder = 'Command & Conquer Red Alert';
  ClassicInstallDir = 'C:\Westwood\RedAlert';
  // The marker file of an original Red Alert (TUC) game install - the
  // detected install is only used as the source for copying movies from.
  GameCheckFile = 'RA95.EXE';

var
  GameDetected: Boolean;
  DetectedInstallPath: String;
  DetectionDone: Boolean;
  DetectedMoviesAnswer: Boolean;
  // Titles of the machine-wide dependencies that are missing and cannot be
  // installed automatically in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;

// ================================================== Existing install lookup
//
// Detects an existing Red Alert install (registry, then Steam library
// folders, then the classic C:\Westwood\RedAlert location) with the shared
// ordered lookup (CncnetDetectGame): the registry installpath values are
// passed as ExtraDirs, the Steam game folder as SteamCommonFolders and the
// classic location as ClassicDirs; the first directory containing
// RA95.EXE wins. The detected path is used both as the source for copying
// movies from (and shown in the movies prompt).
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

// Default install directory.
//
// All-users (elevated) installs go to the previous CnCNet Red Alert client
// location (C:\Program Files\CnCNet\Red Alert). Per-user installs default
// to %LocalAppData%\Programs - except when a previous client install is at
// the legacy location, in which case the upgrade happens in place. The
// write-permission test on the select-dir page (NextButtonClick) still
// verifies the directory is writable for this user, so a locked-down legacy
// location is caught before the install starts.
//
// The detected existing game install is deliberately NOT the default
// directory: this client is not a patch and must not be installed into a
// folder that already contains the game (enforced in NextButtonClick). The
// detected install is only used as the source for copying movies from.
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

// The full-size Red Alert movies are downloaded (see the [Files] section)
// when the movies task is selected and the movies of a detected existing
// install are not used instead.
function DownloadFullMovies(): Boolean;
begin
  Result := WizardIsTaskSelected('Installmov') and (not DetectedMoviesAnswer);
end;

// Decides whether to copy the movies from a detected existing install or to
// download the full movies (when the Installmov task is selected). In
// silent installs no prompt is shown: the movies of a detected existing
// install are used when one is found and the Installmov task is selected,
// otherwise the full movies are downloaded when the task is selected.
// (Without the task selection a silent install installs no movies at all,
// mirroring the interactive flow's default.)
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

// Movie file metadata (generated from the movies array in the profile, the
// single source of truth for the movie URLs and filenames; the [Files]
// section is generated from the same array).
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

// Movie file sizes in KB (generated from the sizeKB values in the profile -
// the same values the [Files] section reports as the download size). The
// shared download engine converts to bytes (Int64(KB) * 1024).
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

// "Preparing to install" step: downloads the movie files with a real
// progress bar (the shared CncnetCommon download page, the same page type
// InnoDependencyInstaller uses for its dependency downloads), instead of
// the generic install progress gauge the [Files] "download" flag would
// produce. The files are downloaded to the temp directory and the [Files]
// section installs them from there (Inno removes the temp directory when
// the install finishes).
//
// Runs after InnoDependencyInstaller's own PrepareToInstall (the library's
// [Code] is included first, and same-name event functions run in order),
// so machine-wide dependencies are downloaded/installed first and the
// movies afterwards.
//
// Returning a non-empty string aborts the install with that message.
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

// Registers all machine-wide dependencies. The library only keeps the ones
// that are actually missing (Dependency_AddIfMissing), so afterwards
// Dependency_List holds exactly the missing ones.
procedure RegisterDependencies;
begin
  // The client tooling is a .NET Framework 4.x app.
  Dependency_AddDotNet48;

  // The Red Alert 95 engine and the CnCNet client components are 32-bit
  // and import the Visual C++ 2005-2022 runtimes, so force the x86
  // variants even for 64-bit setups; the x64 variants cover 64-bit
  // tooling. (Carried over from the legacy RA1 installer, where the
  // same set was verified in production.)
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

  Result := true;
end;

// ================================================================== Wizard

procedure InitializeWizard();
begin
  DetectExistingInstall();

  WizardForm.SelectDirBrowseLabel.Visible := false;
  ISTheme();

  // Wizard title bar: client version + installer version (rendered by
  // build-installer; the value is Pascal-escaped for this string literal).
  WizardForm.Caption := '{{ wizardCaption }}';

  // The RA1 license memo follows the finished-page theme (dark + cream),
  // per user request (the dir page's edit stays white - the user verified
  // it reads fine there).
  WizardForm.LicenseMemo.Color := {{ '{#' }}ISThemeBackColor};
  WizardForm.LicenseMemo.Font.Color := {{ '{#' }}ISThemeForeColor};

  // Download page for the movies (shared lib; hidden until
  // prepareToInstall shows it; the same page type InnoDependencyInstaller
  // uses for its dependency downloads, with a real per-file progress bar
  // and a Stop button).
  CncnetSetupDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  // Give the InnoDependencyInstaller dependency page the same layout
  // (recreated here with the shared progress callback; the library's
  // PrepareToInstall then shows it for its queued runtimes).
  CncnetSetupDependencyDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  // License radio labels: Inno 7's TNewRadioButton ignores Color and always
  // draws its caption in black - unreadable on the dark red RA1 artwork.
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

    // This client is not a patch: it must not be installed into a folder
    // that contains an original Red Alert game install (RA95.EXE), or the
    // client files would mix with the game files. A folder that ALSO
    // contains the client launcher (RedAlert.exe) is a previous CnCNet
    // client install, and installing over it is the normal in-place
    // upgrade (see GetDefaultDir), so it is allowed.
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
    // Smart UAC: only here (deps missing in a per-user install) is
    // elevation offered - never at startup.
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
