; =============================================================================
; CnCNet Tiberian Sun client installer (Inno Setup 7).
; Per-user install by default; all-users can be opted into at startup (UAC).
; Machine-wide dependencies only run for the elevated (all-users) install.
; Source template: the build renders this to installer.iss (Twig) - edit this file, never the output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Dependency_CustomExecute hook: run dependency installers from Inno's temp directory (the library's
; default is the launch directory, where the DirectX web setup would leave a "$tmp" subfolder behind).
; The value must be a quoted preprocessor string (an unquoted identifier is evaluated as a constant reference).
#define public Dependency_CustomExecute 'Dependency_RunWithTempWorkingDir'

[Code]
// Dependency_CustomExecute hook implementation; must precede the library's Dependency_Install (order-sensitive Pascal).
function Dependency_RunWithTempWorkingDir(const FilePath, Parameters: String; var ResultCode: Integer): Boolean;
begin
  Result := ShellExec('', FilePath, Parameters, ExpandConstant('{tmp}'), SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);
end;

#include "libs/InnoDependencyInstaller/CodeDependencies.iss"
#include "libs/ISTheme/ISTheme.iss"
#include "libs/CncnetCommon/CncnetCommon.iss"

[CustomMessages]
AccessDenied=Access to: %1 denied. %n Please choose a different directory or restart the installer as administrator (right-click the installer and choose "Run as administrator"). %n If the installer already runs elevated, make sure your Anti-Virus program does not block the installer (turn it off temporarily if you do not know how to configure it)
WriteDeniedPrompt=Access to: %1 denied for the current user. %n%nElevate now and continue the install into this folder for all users? Choosing No keeps the per-user install (choose a different folder instead).
InstallingApp=Installing %1, this may take several minutes...
NotAPatchError=An existing Tiberian Sun game was detected in the selected folder. %n%n CnCNet Tiberian Sun is a complete client, not a patch for the game, and cannot be installed into a folder that contains the original game. %n%n Please select a different folder. (Upgrading a previous CnCNet Tiberian Sun client install is not affected.)
GameInstallDetected=Previous Tiberian Sun installation has been detected in: %n%n %1 %n%nDo you want the installer to copy the movies from there? The installer will then download only about 52 MB of restored movies instead of all of them.
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
; All-users installs go to C:\Westwood\ts-client (common Start Menu / public desktop);
; per-user installs go to %LocalAppData%\Programs (unless upgrading in place, see GetDefaultDir).
; The .NET / VC++ / DirectX dependency installers are machine-wide and only run for elevated installs.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
; ArchiveExtraction must be "full" (default): the extractarchive flag (restored-movies) is not supported by "basic".

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "Installmov"; Description: "Download and install movies (1.4 GB)"; GroupDescription: "Music and movies"

[InstallDelete]
{% for file in installDeleteFiles %}
Type: filesandordirs; Name: "{app}\{{ file }}"
{% endfor %}
; Leftover DirectX web-setup "$tmp" folder from older versions of this installer
Type: filesandordirs; Name: "{app}\$tmp"

[Files]
; Installer theming resources (used at runtime, not installed)
Source: "Resources\ts\TiberianSunWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\ts\TiberianSunInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\ts\TiberianSunPageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package; critical files are also listed explicitly (compile fails if any is missing).
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\TiberianSun.exe"; DestDir: "{app}";
Source: "{{ sourceDir }}\game.exe"; DestDir: "{app}";
; Tiberian Sun Movies (no existing install in use): downloaded to the temp dir in the
; "Preparing to install" step (download page with a per-file progress bar), then installed from there.
{% for movie in movies %}
Source: "{tmp}\{{ movie.file }}"; DestDir: "{app}\MIX"; DestName: "{{ movie.file }}"; Check: DownloadFullMovies; Flags: external skipifsourcedoesntexist ignoreversion
{% endfor %}

; Movies copied from a detected existing TS install (already in final form, no decryption needed);
; the source install is left untouched.
Source: {code:GetMovieSourceDir}\Movies01.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
Source: {code:GetMovieSourceDir}\Movies02.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
Source: {code:GetMovieSourceDir}\Movies03.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
; Restored-movies archive: downloaded to the temp dir in the "Preparing to install" step, then
; extracted into {app}\MIX during the install phase (native Inno Setup 7 extraction).
Source: "{tmp}\{{ extraMovies.file }}"; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external extractarchive skipifsourcedoesntexist ignoreversion

[Icons]
; All-users (elevated) installs: common Start Menu + public desktop. WizardNoIcons honors the "no icons" checkbox.
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful; skip them.
Name: "{app}\Uninstall {{ app.name }}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\TiberianSun.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{{ app.name }}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallDelete]
Type: files; Name: "{app}\version_u"
Type: files; Name: "{app}\version_cc"
Type: files; Name: "{app}\stats.dmp"
Type: files; Name: "{app}\spawn.ini"
Type: files; Name: "{app}\spawnmap.ini"
Type: files; Name: "{app}\spawnSG.ini"
Type: files; Name: "{app}\HALLFAME.DAT"
Type: files; Name: "{app}\ts.log"
Type: files; Name: "{app}\except.txt"
; Leftover decrypted movie files from an interrupted install
Type: files; Name: "{app}\MIX\*.mix.d"
Type: files; Name: "{app}\mpstats.log"
Type: files; Name: "{app}\mpstats.txt"
Type: files; Name: "{app}\sync*.txt"
Type: files; Name: "{app}\_gsdata_"
Type: files; Name: "{app}\buffer"
Type: files; Name: "{app}\sun.ini"
Type: files; Name: "{app}\SUN.ini"
Type: files; Name: "{app}\KEYBOARD.INI"
Type: files; Name: "{app}\SAVEGAME.NET"
Type: filesandordirs; Name: "{app}\QM"
Type: filesandordirs; Name: "{app}\Client"
; Leftover DirectX web-setup "$tmp" folder from older versions of this installer
Type: filesandordirs; Name: "{app}\$tmp"
Type: files; Name: "{app}\MIX\Movies01.mix"
Type: files; Name: "{app}\MIX\Movies02.mix"
Type: files; Name: "{app}\MIX\Movies03.mix"
Type: files; Name: "{app}\MIX\Expand00.mix"
Type: dirifempty; Name: "{app}\MIX"

[Registry]
; Enable long path support (Win 10 1607+); only relevant for elevated installs; noerror guards the write.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\FileSystem"; ValueType: dword; ValueName: "LongPathsEnabled"; ValueData: 1; Check: CncnetIsUserAnAdmin; Flags: noerror; MinVersion: 10.0.14393

[Code]
const
  GameRegKey = 'Software\Westwood\Tiberian Sun';
  WOW6432GameRegKey = 'Software\WOW6432Node\Westwood\Tiberian Sun';
  SteamGameFolder = 'Command & Conquer Tiberian Sun';

var
  GameDetected: Boolean;
  DetectedInstallPath: String;
  DetectionDone: Boolean;
  DetectedMoviesAnswer: Boolean;
  // Missing machine-wide dependencies that cannot be installed in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;

// ================================================== Existing install lookup
// Shared ordered lookup (CncnetDetectGame): registry installpath as ExtraDirs, the Steam folder as
// SteamCommonFolders, the classic location as ClassicDirs; first dir with game.exe wins.
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
  DetectedInstallPath := 'C:\Westwood\SUN';

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
  ClassicDirs[0] := 'C:\Westwood\SUN';

  if CncnetDetectGame('game.exe', ExtraDirs, SteamCommonFolders, ClassicDirs, DetectedDir) then
  begin
    GameDetected := True;
    DetectedInstallPath := DetectedDir;
  end;
end;

// Default install directory: all-users -> C:\Westwood\ts-client; per-user -> %LocalAppData%\Programs
// (in place when a previous client install is there). The select-dir write-permission test still
// verifies the directory is writable.
// The detected existing game install is NOT the default: this client is not a patch and must not be
// installed into a game folder (enforced in NextButtonClick); it is only the movie-copy source.
function GetDefaultDir(Param: String): String;
begin
  if (CncnetIsUserAnAdmin()) or (FileExists('C:\Westwood\ts-client\TiberianSun.exe')) then
  begin
    Result := 'C:\Westwood\ts-client';
    Exit;
  end;

  Result := ExpandConstant('{userpf}\CnCNet Tiberian Sun');
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

// Decides whether to copy the movies from a detected existing install (then only the small
// restored-movies archive is downloaded) or to download the full movies. Silent installs: use the
// detected install's movies when found and the task is selected; otherwise follow the task.
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

// Restored-movies archive metadata (generated from extraMovies).
function GetExtraMoviesUrl(): String;
begin
  Result := '{{ extraMovies.url }}';
end;

function GetExtraMoviesFile(): String;
begin
  Result := '{{ extraMovies.file }}';
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

function GetExtraMoviesSizeKB(): Integer;
begin
  Result := {{ extraMovies.sizeKB }};
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
      Result := 'The download of the Tiberian Sun Movies was stopped.';
  end
  else if UseDetectedMovies then
  begin
    CncnetDlQueueReset();
    CncnetDlQueueAdd(GetExtraMoviesUrl(), GetExtraMoviesFile(), 'Restored movies archive', GetExtraMoviesSizeKB());
    if not CncnetDlDownloadAll() then
      Result := 'The download of the restored movies archive was stopped.';
  end;
end;

// ============================================================ Dependencies

// True when a DirectX 9 d3dx9 runtime DLL is present (32-bit apps use the SysWOW64 copy).
function HasD3DX9Runtime(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\d3dx9_41.dll'))
       or FileExists(ExpandConstant('{sys}\d3dx9_42.dll'))
       or FileExists(ExpandConstant('{sys}\d3dx9_43.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_41.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_42.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_43.dll'));
end;

// True when the XNA 4.0 runtime is usable: the Refresh redist's Refresh1Installed value, the original
// 4.0 registry key, or a leftover X3DAudio1_7.dll (still loadable by the renderer).
function IsXNA40Installed(): Boolean;
begin
  Result := RegValueExists(HKLM32, 'SOFTWARE\Microsoft\XNA\Framework\v4.0', 'Refresh1Installed')
       or RegKeyExists(HKLM32, 'SOFTWARE\Microsoft\XNA\Framework40')
       or FileExists(ExpandConstant('{sys}\X3DAudio1_7.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\X3DAudio1_7.dll'));
end;

// Registers all machine-wide dependencies; the library only keeps the ones that are actually missing.
procedure RegisterDependencies;
begin
  // The launcher stub (TiberianSun.exe, CnCNet.LauncherStub) is a .NET Framework 4.x app.
  Dependency_AddDotNet48;
  // The OpenTS client backends are .NET 8 WPF apps; the 32-bit launcher always finds the .NET 8 host
  // only in the 32-bit registry view, so force the x86 runtime even on 64-bit setups.
  Dependency_ForceX86 := true;
  Dependency_AddDotNet80Desktop;
  Dependency_ForceX86 := false;
  // The legacy XNA renderer needs the XNA 4.0 Refresh Redistributable (X3DAudio + XACT + d3dx9 runtimes).
  // Registered before the VC++ 2010 redist so the VC++ 2010 SP1 CRT build wins.
  // Per-user installs cannot install it - the ready page offers elevation,
  // else the user must install it with an admin account.
  Dependency_AddIfMissing(not IsXNA40Installed(),
    'xnafx40_refresh_redist.msi',
    Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
    'XNA Framework 4.0 Refresh Redistributable',
    'https://download.microsoft.com/download/5/3/a/53a804c8-ec78-43cd-a0f0-2fb4d45603d3/xnafx40_redist.msi',
    '2b03c130c4bb5f106b9619bea8150201f7e982709cfe9a0ccbde75ff0a83b27',
    False, False);
  // The legacy XNA renderer is 32-bit and imports MSVCR100.dll / MSVCP100.dll (VC++ 2010 SP1) - force x86.
  // (The other renderers are fully managed MonoGame / SharpDX.)
  Dependency_ForceX86 := true;
  Dependency_AddVC2010;
  Dependency_ForceX86 := false;
  // The XNA renderer also imports d3dx9_*.dll; the library's DirectX helper always installs,
  // so only register it when no d3dx9 runtime is present.
  if not HasD3DX9Runtime() then
    Dependency_AddDirectX;
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

  // Download page for the movies (shared lib; hidden until prepareToInstall shows it).
  CncnetSetupDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  // Give the InnoDependencyInstaller dependency page the shared layout (the library's PrepareToInstall then shows it).
  CncnetSetupDependencyDownloadPage(
    ExpandConstant('{cm:DownloadingFiles}'),
    ExpandConstant('{cm:DownloadingFilesDescription}'));

  WizardForm.LicenseAcceptedRadio.Checked := True;
  WizardForm.LicenseAcceptedRadio.Visible := False;
  WizardForm.LicenseNotAcceptedRadio.Visible := False;
  WizardForm.LicenseMemo.Height :=
    WizardForm.LicenseNotAcceptedRadio.Top +
    WizardForm.LicenseNotAcceptedRadio.Height -
    WizardForm.LicenseMemo.Top - ScaleY(5);
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

    // This client is not a patch: installing into a folder that contains the original game (game.exe) is refused;
    // a folder with the client launcher (TiberianSun.exe) is a previous client install - the normal in-place upgrade.
    if FileExists(ExpandConstant('{app}\game.exe')) and
       (not FileExists(ExpandConstant('{app}\TiberianSun.exe'))) then
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
    CreateDir(ExpandConstant('{app}\MIX'));
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
