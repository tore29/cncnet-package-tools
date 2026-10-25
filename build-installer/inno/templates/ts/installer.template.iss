; =============================================================================
; CnCNet Tiberian Sun client installer
;
; Install scope: per-user by default (no elevation needed). At startup the
; user can opt into an all-users install (UAC prompt). The machine-wide
; dependency installers only run for all-users (elevated) installs.
;
; Shared functionality (admin/wine detection, Steam install lookup,
; write-permission test, per-user deps + elevation relaunch, the generic
; download page) lives in libs/CncnetCommon/CncnetCommon.iss and is
; #include'd below; this template keeps the TS-specific policy code.
;
; This is the source template. The build renders it to installer.iss (Twig,
; "npm run build-installer") - edit this file, never the generated output.
; =============================================================================

#define public Dependency_NoExampleSetup
; Dependency_CustomExecute hook: runs dependency installers from Inno's temp
; directory instead of the installer's launch directory (the library's
; default). The DirectX web setup in particular creates a "$tmp" subfolder
; in its working directory to extract its redistributables into, which would
; otherwise be left behind in the folder the user launched the installer
; from. Inno's temp directory is deleted automatically when the install
; finishes. The value must be a quoted preprocessor string (an unquoted
; identifier would be evaluated as a reference to another preprocessor
; constant).
#define public Dependency_CustomExecute 'Dependency_RunWithTempWorkingDir'

[Code]
// Dependency_CustomExecute hook implementation (declared before the library's
// Dependency_Install below, which calls it; Inno's Pascal script is
// order-sensitive, so the implementation lives in this preamble).
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
; Per-user (current user) install by default: no elevation is needed, and
; non-administrators can install without any extra step. At startup the
; user is offered the chance to install for all users instead (UAC prompt);
; "dialog commandline" also allows /ALL and /LOW command line overrides for
; scripted installs.
;
; All-users installs go to the legacy C:\Westwood\ts-client location with
; common Start Menu / public desktop shortcuts. Per-user installs go to
; %LocalAppData%\Programs with per-user shortcuts (unless a previous client
; install is at the legacy location, see GetDefaultDir).
;
; The .NET / VC++ / DirectX dependency installers are machine-wide and
; require elevation, so they only run for all-users (elevated) installs -
; see InitializeSetup below.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
; ArchiveExtraction must be "full" (the default) because the [Files] section
; uses the extractarchive flag for the restored-movies archive. "basic" would
; be smaller but does not support extraction at install time.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "Installmov"; Description: "Download and install movies (1.4 GB)"; GroupDescription: "Music and movies"

[InstallDelete]
{% for file in installDeleteFiles %}
Type: filesandordirs; Name: "{app}\{{ file }}"
{% endfor %}
; Leftover extraction folder of the DirectX web setup from older versions of
; this installer (it used to create "$tmp" in the app directory)
Type: filesandordirs; Name: "{app}\$tmp"

[Files]
; Installer theming resources (used at runtime, not installed)
Source: "Resources\ts\TiberianSunWizardFormBackground.bmp"; DestName: "WizardFormBackground.bmp"; Flags: dontcopy
Source: "Resources\ts\TiberianSunInnerPageBackground.bmp"; DestName: "InnerPageBackground.bmp"; Flags: dontcopy
Source: "Resources\ts\TiberianSunPageBackground.bmp"; DestName: "PageBackground.bmp"; Flags: dontcopy
Source: "Resources\WritePermissionTestFile.txt"; Flags: dontcopy

; Main client package (referenced by absolute path; critical files are also
; listed explicitly below so the compile fails if any of them is missing)
Source: "{{ sourceDir }}\*"; DestDir: "{app}"; Excludes: "{{ excludedInstallerFiles | join(',') }}"; Flags: recursesubdirs ignoreversion overwritereadonly sortfilesbyextension
Source: "{{ sourceDir }}\version"; DestDir: "{app}";
Source: "{{ sourceDir }}\TiberianSun.exe"; DestDir: "{app}";
Source: "{{ sourceDir }}\game.exe"; DestDir: "{app}";
; Tiberian Sun Movies (no existing install in use): downloaded to the temp
; directory in the "Preparing to install" step (see prepareToInstall below,
; on a download page with a real per-file progress bar), then installed from
; there.
{% for movie in movies %}
Source: "{tmp}\{{ movie.file }}"; DestDir: "{app}\MIX"; DestName: "{{ movie.file }}"; Check: DownloadFullMovies; Flags: external skipifsourcedoesntexist ignoreversion
{% endfor %}

; Movies copied from a detected existing TS install (plain file copy - the
; movies of an existing install are already in their final, usable form, so
; no decryption step is needed). The source install is left untouched.
Source: {code:GetMovieSourceDir}\Movies01.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
Source: {code:GetMovieSourceDir}\Movies02.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
Source: {code:GetMovieSourceDir}\Movies03.mix; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external skipifsourcedoesntexist ignoreversion
; Restored-movies archive: downloaded to the temp directory in the
; "Preparing to install" step (with a real progress bar), then extracted
; into {app}\MIX during the install phase (native Inno Setup 7 extraction).
Source: "{tmp}\{{ extraMovies.file }}"; DestDir: "{app}\MIX"; Check: UseDetectedMovies; Flags: external extractarchive skipifsourcedoesntexist ignoreversion

[Icons]
; All-users (elevated) installs: common Start Menu (Start Menu > CnCNet >
; <app name>) and the public desktop. WizardNoIcons honors the wizard's
; "Don't create any icons for this application" checkbox (AllowNoIcons=yes),
; like the legacy ts-client-installer does.
Name: "{commonprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{commondesktop}\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Per-user installs: the user's own Start Menu and desktop.
Name: "{autoprograms}\CnCNet\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
Name: "{userdesktop}\{{ app.name }}"; Filename: "{app}\TiberianSun.exe"; Check: not CncnetIsUserAnAdmin and not CncnetRunsOnWine and not WizardNoIcons
; Under Wine the Windows shortcuts are not useful (like the Yuri's Revenge
; installer), so they are skipped there.
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
; Leftover extraction folder of the DirectX web setup from older versions of
; this installer
Type: filesandordirs; Name: "{app}\$tmp"
Type: files; Name: "{app}\MIX\Movies01.mix"
Type: files; Name: "{app}\MIX\Movies02.mix"
Type: files; Name: "{app}\MIX\Movies03.mix"
Type: files; Name: "{app}\MIX\Expand00.mix"
Type: dirifempty; Name: "{app}\MIX"

[Registry]
; Enable long path support (Windows 10 1607+). Only possible (and only
; relevant) for elevated all-users installs; noerror guards the write.
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
  // Titles of the machine-wide dependencies that are missing and cannot be
  // installed automatically in a per-user install (see InitializeSetup).
  PerUserMissingDeps: String;

// ================================================== Existing install lookup
//
// Detects an existing Tiberian Sun install (registry, then Steam library
// folders, then the classic C:\Westwood\SUN location) with the shared
// ordered lookup (CncnetDetectGame): the registry installpath values are
// passed as ExtraDirs, the Steam game folder as SteamCommonFolders and the
// classic location as ClassicDirs; the first directory containing
// game.exe wins. The detected path is used both as the source for copying
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

// Default install directory.
//
// All-users (elevated) installs go to the legacy C:\Westwood\ts-client
// location. Per-user installs default to %LocalAppData%\Programs - except
// when a previous client install is at the legacy location, in which case
// the upgrade happens in place. The write-permission test on the
// select-dir page (NextButtonClick) still verifies the directory is
// writable for this user, so a locked-down legacy location is caught
// before the install starts.
//
// The detected existing game install is deliberately NOT the default
// directory: this client is not a patch and must not be installed into a
// folder that already contains a game (enforced in NextButtonClick). The
// detected install is only used as the source for copying movies from.
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

// The full-size Tiberian Sun Movies are downloaded (see the [Files] section) when
// the movies task is selected and the movies of a detected existing install
// are not used instead.
function DownloadFullMovies(): Boolean;
begin
  Result := WizardIsTaskSelected('Installmov') and (not DetectedMoviesAnswer);
end;

// Decides whether to copy the movies from a detected existing install (then
// only the small restored-movies archive is downloaded, see the [Files]
// section) or to download the full movies (when the Installmov task is
// selected). In silent installs no prompt is shown: the movies of a detected
// existing install are used when one is found and the Installmov task is
// selected, otherwise the full movies are downloaded when the task is
// selected. (Without the task selection a silent install installs no movies
// at all, mirroring the interactive flow's default.)
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

// Restored-movies archive metadata (generated from extraMovies).
function GetExtraMoviesUrl(): String;
begin
  Result := '{{ extraMovies.url }}';
end;

function GetExtraMoviesFile(): String;
begin
  Result := '{{ extraMovies.file }}';
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

function GetExtraMoviesSizeKB(): Integer;
begin
  Result := {{ extraMovies.sizeKB }};
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

// True when a DirectX 9 d3dx9 runtime DLL is present in either system
// directory (on 64-bit systems 32-bit apps use the SysWOW64 copy).
function HasD3DX9Runtime(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\d3dx9_41.dll'))
       or FileExists(ExpandConstant('{sys}\d3dx9_42.dll'))
       or FileExists(ExpandConstant('{sys}\d3dx9_43.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_41.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_42.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\d3dx9_43.dll'));
end;

// True when the XNA 4.0 runtime is already usable: the Refresh redist
// registers Refresh1Installed under HKLM\SOFTWARE\Microsoft\XNA\Framework\v4.0
// (the original 4.0 redist registers ...XNA\Framework40), or the 32-bit
// X3DAudio audio engine DLL is already in a system directory (leftover
// copies from an uninstalled redist are still loadable by the renderer).
function IsXNA40Installed(): Boolean;
begin
  Result := RegValueExists(HKLM32, 'SOFTWARE\Microsoft\XNA\Framework\v4.0', 'Refresh1Installed')
       or RegKeyExists(HKLM32, 'SOFTWARE\Microsoft\XNA\Framework40')
       or FileExists(ExpandConstant('{sys}\X3DAudio1_7.dll'))
       or FileExists(ExpandConstant('{sys}\..\SysWOW64\X3DAudio1_7.dll'));
end;

// Registers all machine-wide dependencies. The library only keeps the ones
// that are actually missing (Dependency_AddIfMissing), so afterwards
// Dependency_List holds exactly the missing ones.
procedure RegisterDependencies;
begin
  // The launcher stub (TiberianSun.exe, CnCNet.LauncherStub) is a .NET
  // Framework 4.x app.
  Dependency_AddDotNet48;
  // The OpenTS client backends (Resources\BinariesNET8\clientdx etc.) are
  // .NET 8 WPF apps that require the .NET 8 Desktop Runtime. The launcher
  // (TiberianSun.exe) is 32-bit and always starts .NET 8 clients with the
  // x86 dotnet host, finding it only in the 32-bit registry view
  // (SOFTWARE\dotnet\Setup\InstalledVersions\x86), so force the x86 variant
  // even for 64-bit setups - the x64 runtime would be useless to the client.
  Dependency_ForceX86 := true;
  Dependency_AddDotNet80Desktop;
  Dependency_ForceX86 := false;
  // The legacy XNA renderer (Resources\Binaries*\XNA, clientxna.exe) also
  // needs the XNA 4.0 runtime itself: its assemblies import the X3DAudio
  // audio engine (X3DAudio1_7.dll), which the XNA 4.0 Refresh
  // Redistributable (xnafx40_redist.msi, still downloadable from
  // Microsoft) installs along with XACT, XInput and the d3dx9 runtimes.
  // Register it before the VC++ 2010 redist below so the VC++ 2010 SP1
  // CRT build wins. (Per-user installs cannot install it: without the
  // redist the legacy XNA renderer will not start - the ready page offers
  // elevation, and if that fails tells the user to install the redist with
  // an admin account and re-run the installer.)
  Dependency_AddIfMissing(not IsXNA40Installed(),
    'xnafx40_refresh_redist.msi',
    Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
    'XNA Framework 4.0 Refresh Redistributable',
    'https://download.microsoft.com/download/5/3/a/53a804c8-ec78-43cd-a0f0-2fb4d45603d3/xnafx40_redist.msi',
    '2b03c130c4bb5f106b9619bea8150201f7e982709cfe9a0ccbde75ff0a83b27',
    False, False);
  // The legacy XNA renderer (Resources\Binaries*\XNA, clientxna.exe) is
  // 32-bit and its XNA 4.0 assemblies import MSVCR100.dll / MSVCP100.dll
  // (Visual C++ 2010 SP1 Redistributable) at load time, so force the x86
  // variant of the redistributable even for 64-bit setups. (No binary in
  // the package needs the newer VC++ runtimes; the OpenGL and DirectX
  // renderers are fully managed MonoGame / SharpDX.)
  Dependency_ForceX86 := true;
  Dependency_AddVC2010;
  Dependency_ForceX86 := false;
  // The XNA renderer also imports d3dx9_*.dll (DirectX 9 runtime), which is
  // missing on some clean Windows installs. The library's Dependency_Add
  // DirectX helper always installs, so only register it when no d3dx9
  // runtime is present.
  if not HasD3DX9Runtime() then
    Dependency_AddDirectX;
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
    // that contains an original Tiberian Sun game install (game.exe), or
    // the client files would mix with the game files. A folder that ALSO
    // contains the client launcher (TiberianSun.exe) is a previous CnCNet
    // client install, and installing over it is the normal in-place
    // upgrade (see GetDefaultDir), so it is allowed.
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
