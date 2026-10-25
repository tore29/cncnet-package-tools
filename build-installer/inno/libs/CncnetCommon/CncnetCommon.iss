// =============================================================================
// CncnetCommon.iss - shared CnCNet installer functionality (Inno Setup 7)
//
// This file is ISPP-included from a [Code] section of a game template
// (NOT Twig-processed - unlike the templates themselves, it is compiled
// verbatim by ISCC). Include it AFTER libs/ISTheme/ISTheme.iss:
//
//   [Code]
//   #define ISTheme... (per-game palette, if not the default)
//   #include "libs/ISTheme/ISTheme.iss"
//   #include "libs/CncnetCommon/CncnetCommon.iss"
//
// It is included from a [Code] section, so only Pascal-style (//) comments
// are allowed here, not .iss-style (;) comments.
//
// What it provides (all Cncnet-prefixed; the templates keep their
// game-specific policy code):
//   - kernel32 / shell32 externals (Cncnet* names, unique per script)
//   - CncnetIsUserAnAdmin / CncnetRunsOnWine / CncnetIsWineSnap
//   - CncnetSteam_ParseConfig / CncnetSteam_GetPath /
//     CncnetSteam_LibraryRoots / CncnetDetectGame (ordered install lookup)
//   - CncnetGotWritePermissions (target dir write test)
//   - CncnetBuildRelaunchCommandLine / CncnetRelaunchElevated (smart UAC:
//     elevation is requested only when needed, never at startup)
//   - CncnetCollectPerUserDeps / CncnetWarnMissingDeps (machine-wide
//     dependencies for per-user installs, hooks into InnoDependencyInstaller)
//   - CncnetWriteDenied (dir-page write-test failure: offers the same
//     smart-UAC relaunch as CncnetWarnMissingDeps)
//   - CncnetRunElevated (post-install launch of a program whose manifest
//     requires elevation: asks first, then 'runas' verb + UAC consent)
//   - CncnetThemeLicenseRadios (Inno 7 license-radio caption fix)
//   - the generic download page (IDP-style layout, overall + per-file bars,
//     speed/status/time rows, retry + abort/retry/ignore) and the download
//     queue: CncnetSetupDownloadPage / CncnetDlQueueReset /
//     CncnetDlQueueAdd / CncnetDlDownloadAll
//   - CncnetSetupDependencyDownloadPage: gives the
//     InnoDependencyInstaller dependency page the same layout (requires
//     libs/InnoDependencyInstaller/CodeDependencies.iss included first)
//
// No event handlers are defined here: the game templates keep their own
// InitializeWizard / NextButtonClick / prepareToInstall and call the
// functions below from there.
// =============================================================================

[Code]

type
  // One download page, its IDP-style layout controls and its per-download
  // progress state. Two instances exist (see the var section below):
  // CncnetDl for the template's own download page (movies etc.) and
  // CncnetDep for the InnoDependencyInstaller dependency page.
  TCncnetDl = record
    Page: TDownloadWizardPage;
    TitleLabel: TNewStaticText;
    DescriptionLabel: TNewStaticText;
    TotalCaptionLabel: TNewStaticText;
    TotalValueLabel: TNewStaticText;
    CurrentCaptionLabel: TNewStaticText;
    CurrentValueLabel: TNewStaticText;
    FileCaptionLabel: TNewStaticText;
    SpeedLabel: TNewStaticText;
    SpeedValueLabel: TNewStaticText;
    StatusLabel: TNewStaticText;
    StatusValueLabel: TNewStaticText;
    ElapsedLabel: TNewStaticText;
    ElapsedValueLabel: TNewStaticText;
    RemainingLabel: TNewStaticText;
    RemainingValueLabel: TNewStaticText;
    OverallBar: TNewProgressBar;
    // Bytes of the queued files preceding the one currently downloading,
    // set before each download starts; the callback adds the current
    // file's received bytes on top of it to position the overall bar.
    BytesBase: Int64;
    // Total bytes of the current download session (all its files), used
    // for the "Total progress" value, the remaining-time estimate and the
    // overall bar sizing. 0 = unknown (the overall bar is hidden and the
    // total shown as "Unknown").
    SessionTotal: Int64;
    // Size in bytes of the file currently downloading (known from the
    // profile data), used for the "Current file" value while the engine
    // has not reported the file size yet (ProgressMax = 0).
    CurrentFileSize: Int64;
    // GetTickCount at the start of the session (the first file), for the
    // elapsed-time row.
    SessionStartTick: Longword;
    // Divisor applied to the overall bar's Max/Position: 1 (bytes)
    // normally, 1048576 (megabytes) when the session total would overflow
    // the bar's 32-bit Max (see CncnetOverallBarByteLimit).
    OverallBarScale: Int64;
    // Download speed measurement state, only touched by the progress
    // callback (main thread); cumulative-average speed and 1 Hz refresh.
    FileStartTick: Longword;
    LastSpeedTick: Longword;
    LastBytes: Int64;
    // Set once the layout has been built for this instance (guards
    // CncnetDlBuildLayout against creating the labels twice).
    Started: Boolean;
    // True when SessionTotal was adopted from the engine's progress
    // callback (ProgressMax) because no total was given up front (the
    // dependency page, which the library drives one file at a time);
    // False when a total was given by CncnetDlPrepareProgressEx (the
    // movie page). On a file restart (a new dependency file starts with
    // Progress back at 0) only an ADOPTED total is cleared, so a given
    // multi-file session total survives a retry of one file - the retry
    // path does not call CncnetDlPrepareProgressEx again.
    TotalAdopted: Boolean;
  end;

const
  // Name of the write-permission test file the templates bundle in [Files]
  // (Flags: dontcopy); it is extracted to the temp dir and copied into the
  // target directory to verify the user can write there.
  CncnetWritePermissionTestFile = 'WritePermissionTestFile.txt';

  // Largest total the overall progress bar can represent in its native
  // (byte) units before we switch to megabyte units (the bar's Max is
  // 32-bit; Max and Position are scaled by the same factor, so the ratio
  // is unchanged).
  CncnetOverallBarByteLimit = 2000000000;

var
  // Generic download page (created by CncnetSetupDownloadPage, laid out
  // by CncnetDlBuildLayout) for the template's own downloads (movies etc.).
  CncnetDl: TCncnetDl;
  // The InnoDependencyInstaller dependency page: the library creates its
  // own page in Dependency_InitializeWizard (nil progress callback), and
  // CncnetSetupDependencyDownloadPage recreates it with the
  // CncnetDepProgress callback - the callback can only be set at
  // CreateDownloadPage time (Inno 7.0.2 exposes no OnDownloadProgress
  // property to scripts) - plus the same layout. The library's
  // Dependency_PrepareToInstall reads the Dependency_DownloadPage global
  // at install time, so the replacement is picked up. The original page
  // is never visited: download pages carry the psAlwaysSkip style, which
  // TWizardForm.ShouldSkipPage skips during Next/Back navigation (they
  // only appear via Show() during PrepareToInstall).
  CncnetDep: TCncnetDl;
  // Download queue (filled by CncnetDlQueueAdd, drained by
  // CncnetDlDownloadAll). Sizes are in KB (Inno has no TArrayOfInt64;
  // converted with Int64(KB) * 1024). 0 = size unknown.
  CncnetDlQueueUrls: TArrayOfString;
  CncnetDlQueueFiles: TArrayOfString;
  CncnetDlQueueTitles: TArrayOfString;
  CncnetDlQueueSizesKB: TArrayOfInteger;

// ==================================================================== externals
//
// Declared under Cncnet* names so they cannot collide with names in the
// game templates (ISTheme already declares its own GetTickCount import,
// ISThemeGetTickCount). Note: the shell32 import must be wrapped in a
// named function rather than used bare - Inno's expression engine
// (Check:, BeforeInstall:, AfterInstall:) resolves script functions by
// name, and bare DLL imports are stored without a name, so using a bare
// external in a Check: expression fails at install time with
// "Internal error: Expression error 'Script error: Could not call proc.'".

function CncnetGetCurrentProcess(): THandle;
  external 'GetCurrentProcess@kernel32.dll';
function CncnetGetModuleHandleA(lpLibFileName: PAnsiChar): THandle;
  external 'GetModuleHandleA@kernel32.dll stdcall';
function CncnetGetProcAddress(Module: THandle; ProcName: PAnsiChar): Longword;
  external 'GetProcAddress@kernel32.dll stdcall';
function CncnetIsWow64Process(hProcess: THandle; var Wow64Flag: Boolean): Boolean;
  external 'IsWow64Process@kernel32.dll stdcall';
function CncnetIsDebuggerPresent(): Boolean;
  external 'IsDebuggerPresent@kernel32.dll stdcall';
function CncnetGetTickCount(): Longword;
  external 'GetTickCount@kernel32.dll stdcall';

// ShellExecute (ANSI entry point) imported directly to request elevation.
// The built-in script function ShellExec() cannot be used for this: when
// the target file is setup's own executable (our {srcexe} relaunch) and
// the install step has not started yet, Inno's script layer short-circuits
// the call in IsProtectedSrcExe (Setup.ScriptFunc.HelperFunc.pas) and
// reports ERROR_ACCESS_DENIED (5) WITHOUT any shell call at all - so
// ShellExec('runas', '{srcexe}', ...) never elevates and no UAC prompt is
// ever shown. A direct ShellExecute call with the 'runas' verb goes
// through the standard elevation path and does show the UAC consent prompt.
// All installer paths and the relaunch command line are ASCII, so the ANSI
// entry point (ShellExecuteA) with PAnsiChar parameters is the correct
// match (same marshaling pattern as GetModuleHandleA above).
//
// Return contract: > 32 = success (an HINSTANCE pseudo-handle, e.g. 0x2A);
// <= 32 = an SE_ERR_* code (5 = access denied / user cancelled the UAC
// prompt). The call blocks until the user makes the UAC decision.
function CncnetShellExecuteA(hWnd: Integer; Operation: PAnsiChar; Filename: PAnsiChar; Parameters: PAnsiChar; Directory: PAnsiChar; nShow: Integer): Integer;
  external 'ShellExecuteA@shell32.dll stdcall';

// Terminates this process (kernel32 ExitProcess, never returns). Used to
// close the per-user instance once the elevated instance has taken over:
// per Inno's docs, Abort() called from NextButtonClick only escapes the
// current execution path and does NOT exit Setup, which would leave this
// wizard window open behind the elevated one. Setup's log writes are
// unbuffered direct WriteFile calls (TTextFileWriter -> WriteBuffer), so
// terminating without finalization loses nothing.
function CncnetExitProcess(ExitCode: Integer): Integer;
  external 'ExitProcess@kernel32.dll stdcall';

// ==================================================================== admin
//
// True when the current process is running elevated (UAC). Used to decide
// the install scope: PrivilegesRequired=lowest plus the startup scope
// dialog means an elevated process installs for all users, a non-elevated
// one installs for the current user.
function CncnetShellIsUserAnAdmin(): Boolean;
  external 'IsUserAnAdmin@shell32.dll stdcall';
function CncnetIsUserAnAdmin(): Boolean;
begin
  Result := CncnetShellIsUserAnAdmin();
end;

// ====================================================================== Wine
//
// Full Wine detection (command line, debugger, kernel32/ntdll wine_*
// exports, {win}\wine / {sys}\wine files). Ported from the TS template.
function CncnetRunsOnWine(): boolean;
var
  A: Array[0..3] of String;
  C: THandle;
  D: Longword;
  E: Longword;
  F: Longword;
  I: Integer;
  Wow64: Boolean;
begin
  Result := false;

  if (ParamCount() > 0) then
  begin
    A[0] := '/wine';
    A[1] := '/WINE';
    A[2] := '/WINEDEBUG=';
    A[3] := '/WINEDLLOVERRIDES=';

    for I := 1 to ParamCount() do
    begin
      if (ParamStr(I) = A[0]) or (ParamStr(I) = A[1]) then
      begin
        Result := true;
        Exit;
      end;

      if (Pos(A[2], ParamStr(I)) = 1) or (Pos(A[3], ParamStr(I)) = 1) then
      begin
        Result := true;
        Exit;
      end;
    end;
  end;

  if CncnetIsDebuggerPresent() then
  begin
    Result := true;
    Exit;
  end;

  if not CncnetIsWow64Process(CncnetGetCurrentProcess(), Wow64) then Exit;

  D := CncnetGetProcAddress(CncnetGetModuleHandleA('kernel32.dll'), 'wine_get_version');
  E := CncnetGetProcAddress(CncnetGetModuleHandleA('kernel32.dll'), 'wine_get_buildstring');
  F := CncnetGetProcAddress(CncnetGetModuleHandleA('kernel32.dll'), 'wine_get_version_nodebug');

  if ((D <> 0) or (E <> 0) or (F <> 0)) then
  begin
    Result := true;
    Exit;
  end;

  if FileExists(ExpandConstant('{win}') + '\wine') then
  begin
    Result := true;
    Exit;
  end;

  if FileExists(ExpandConstant('{sys}') + '\wine') then
  begin
    Result := true;
    Exit;
  end;

  C := CncnetGetModuleHandleA('ntdll.dll');

  if (C <> 0) then
  begin
    D := CncnetGetProcAddress(C, 'wine_get_version');
    E := CncnetGetProcAddress(C, 'wine_get_buildstring');
    F := CncnetGetProcAddress(C, 'wine_get_version_nodebug');

    if ((D <> 0) or (E <> 0) or (F <> 0)) then
      Result := true;
  end;
end;

// True on Wine Snap (the YR installer's heuristic: the Tahoma font
// registry value points into Z:\snap\).
function CncnetIsWineSnap(): Boolean;
var
  s: String;
begin
  Result := False;

  if CncnetRunsOnWine() and
    RegQueryStringValue(HKLM, 'Software\Microsoft\Windows NT\CurrentVersion\Fonts', 'Tahoma (TrueType)', s) and
    (Pos('Z:\snap\', s) = 1) then
    Result := True;
end;

// ============================================================ Steam lookup

// Parses Steam's config.vdf and returns the Steam library roots
// (the "BaseInstallFolder_N" values). Ported from the legacy
// ts-client-installer (Shared.iss), which used this format correctly.
function CncnetSteam_ParseConfig(const FileName: String; var Paths: TArrayOfString): Boolean;
var
  Lines: TArrayOfString;
  I: Integer;
  Line: String;
  P: Integer;
  Key: String;
  Value: String;
  Count: Integer;
  BaseInstallFolderKeyPrefix: String;
begin
  BaseInstallFolderKeyPrefix := 'BaseInstallFolder_';
  Result := LoadStringsFromFile(FileName, Lines);
  Count := 0;

  if not Result then Exit;

  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);

    if Copy(Line, 1, 1) <> '"' then
      Continue;

    Delete(Line, 1, 1);
    P := Pos('"', Line);

    if P = 0 then
      Continue;

    Key := Trim(Copy(Line, 1, P - 1));
    Line := Trim(Copy(Line, P + 1, Length(Line) - P));

    if CompareText(Copy(Key, 1, Length(BaseInstallFolderKeyPrefix)), BaseInstallFolderKeyPrefix) <> 0 then
      Continue;

    if Copy(Line, 1, 1) <> '"' then
      Continue;

    Delete(Line, 1, 1);
    P := Pos('"', Line);

    if P = 0 then
      Continue;

    Value := Trim(Copy(Line, 1, P - 1));
    StringChange(Value, '\\', '\');

    Count := Count + 1;
    SetArrayLength(Paths, Count);
    Paths[Count - 1] := Value;
  end;
end;

// Returns the Steam installation directory (registry first, then the
// default install location).
function CncnetSteam_GetPath(): String;
var
  SteamPath: String;
begin
  Result := '';

  SteamPath := ExpandConstant('{reg:HKLM\SOFTWARE\Valve\Steam,SteamPath|}');
  if (SteamPath = '') or (not DirExists(SteamPath)) then
    SteamPath := ExpandConstant('{reg:HKLM64\SOFTWARE\Valve\Steam,SteamPath|}');

  if (SteamPath = '') or (not DirExists(SteamPath)) then
    SteamPath := ExpandConstant('{reg:HKCU\SOFTWARE\Valve\Steam,SteamPath|}');

  if (SteamPath = '') or (not DirExists(SteamPath)) then
    SteamPath := ExpandConstant('{pf}\Steam');

  if DirExists(SteamPath) then
    Result := SteamPath;
end;

// Parses Steam's libraryfolders.vdf (modern Steam builds) and returns the
// library roots (the "path" value of each library entry).
function CncnetSteam_ParseLibraryFolders(const FileName: String; var Paths: TArrayOfString): Boolean;
var
  Lines: TArrayOfString;
  I: Integer;
  Line: String;
  P: Integer;
  Value: String;
  Count: Integer;
begin
  Result := LoadStringsFromFile(FileName, Lines);
  Count := 0;

  if not Result then Exit;

  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);

    if Copy(Line, 1, 1) <> '"' then
      Continue;

    Delete(Line, 1, 1);
    P := Pos('"', Line);

    if P = 0 then
      Continue;

    if CompareText(Trim(Copy(Line, 1, P - 1)), 'path') <> 0 then
      Continue;

    Line := Trim(Copy(Line, P + 1, Length(Line) - P));

    if Copy(Line, 1, 1) <> '"' then
      Continue;

    Delete(Line, 1, 1);
    P := Pos('"', Line);

    if P = 0 then
      Continue;

    Value := Trim(Copy(Line, 1, P - 1));
    StringChange(Value, '\\', '\');

    Count := Count + 1;
    SetArrayLength(Paths, Count);
    Paths[Count - 1] := Value;
  end;
end;

// Appends a library root unless it is already present (case-insensitive).
procedure CncnetSteam_AppendRoot(var Roots: TArrayOfString; var Count: Integer; const Root: String);
var
  J: Integer;
begin
  if Root = '' then
    Exit;

  for J := 0 to Count - 1 do
  begin
    if CompareText(Roots[J], Root) = 0 then
      Exit;
  end;

  SetArrayLength(Roots, Count + 1);
  Roots[Count] := Root;
  Count := Count + 1;
end;

// Returns the Steam library roots: the "path" entries of
// steamapps\libraryfolders.vdf (modern Steam builds), the BaseInstallFolder_N
// entries of config.vdf (older builds; checked in BOTH the current
// steamapps\config location and the legacy config location), with the main
// Steam library (SteamPath itself) included.
function CncnetSteam_LibraryRoots(var Roots: TArrayOfString): Boolean;
var
  SteamPath: String;
  ConfigFile: String;
  Parsed: TArrayOfString;
  I, Count: Integer;
begin
  SetArrayLength(Roots, 0);

  SteamPath := CncnetSteam_GetPath();
  if SteamPath = '' then
  begin
    Result := False;
    Exit;
  end;

  // The registry SteamPath value uses forward slashes (as written by Steam);
  // normalize so the dedup against the libraryfolders.vdf entries works.
  StringChange(SteamPath, '/', '\');

  Count := 0;

  // Modern Steam lists all library roots (including the main one) here.
  if CncnetSteam_ParseLibraryFolders(SteamPath + '\steamapps\libraryfolders.vdf', Parsed) then
  begin
    for I := 0 to Length(Parsed) - 1 do
      CncnetSteam_AppendRoot(Roots, Count, Parsed[I]);
  end;

  // Older Steam builds use the BaseInstallFolder_N entries of config.vdf.
  ConfigFile := SteamPath + '\steamapps\config\config.vdf';
  if FileExists(ConfigFile) and CncnetSteam_ParseConfig(ConfigFile, Parsed) then
  begin
    for I := 0 to Length(Parsed) - 1 do
      CncnetSteam_AppendRoot(Roots, Count, Parsed[I]);
  end;

  ConfigFile := SteamPath + '\config\config.vdf';
  if FileExists(ConfigFile) and CncnetSteam_ParseConfig(ConfigFile, Parsed) then
  begin
    for I := 0 to Length(Parsed) - 1 do
      CncnetSteam_AppendRoot(Roots, Count, Parsed[I]);
  end;

  // The main Steam library (SteamPath) is not listed on older builds.
  CncnetSteam_AppendRoot(Roots, Count, SteamPath);

  Result := Count > 0;
end;

// ====================================================== Existing game lookup
//
// Ordered game-install detection shared by all installers:
//   1. ExtraDirs (e.g. the paths the game-specific registry entries point
//      at - the templates read their own registry keys and pass the
//      resulting directories),
//   2. Steam: <library root>\steamapps\common\<SteamCommonFolder> for each
//      SteamCommonFolder and each library root,
//   3. ClassicDirs (the legacy install locations).
// The first directory that contains CheckFile wins; it is returned in
// DetectedDir WITHOUT a trailing backslash.
function CncnetDetectGame(const CheckFile: String; const ExtraDirs, SteamCommonFolders, ClassicDirs: TArrayOfString; var DetectedDir: String): Boolean;
var
  Roots: TArrayOfString;
  I, J: Integer;
  Candidate: String;
begin
  Result := False;
  DetectedDir := '';

  for I := 0 to Length(ExtraDirs) - 1 do
  begin
    Candidate := ExtraDirs[I];
    if (Candidate <> '') and FileExists(Candidate + '\' + CheckFile) then
    begin
      Result := True;
      DetectedDir := Candidate;
      Exit;
    end;
  end;

  if CncnetSteam_LibraryRoots(Roots) then
  begin
    for I := 0 to Length(Roots) - 1 do
      for J := 0 to Length(SteamCommonFolders) - 1 do
      begin
        Candidate := Roots[I] + '\steamapps\common\' + SteamCommonFolders[J];
        if FileExists(Candidate + '\' + CheckFile) then
        begin
          Result := True;
          DetectedDir := Candidate;
          Exit;
        end;
      end;
  end;

  for I := 0 to Length(ClassicDirs) - 1 do
  begin
    Candidate := ClassicDirs[I];
    if (Candidate <> '') and FileExists(Candidate + '\' + CheckFile) then
    begin
      Result := True;
      DetectedDir := Candidate;
      Exit;
    end;
  end;
end;

// ======================================================== write permissions
//
// Verifies the user can write to the target directory (the directory does
// not exist yet at the select-dir stage - Inno creates it during the
// install phase - so it is created first; a creation failure is exactly
// the outcome we want to report). Ported from the TS template / the
// legacy ts-client-installer (Shared.iss): extract the bundled test file
// to the temp dir and copy it into the target directory.
function CncnetGotWritePermissions(const TestDir: String): Boolean;
var
  TestFileName: String;
begin
  Result := False;

  TestFileName := TestDir + '\' + CncnetWritePermissionTestFile;

  if not ForceDirectories(TestDir) then
    Exit;

  if FileExists(TestFileName) then
    DeleteFile(TestFileName);

  // (Inno 7: ExtractTemporaryFile is a statement, so the copy result is
  // what is checked, exactly like the legacy installer.)
  ExtractTemporaryFile(CncnetWritePermissionTestFile);
  if CopyFile(ExpandConstant('{tmp}\') + CncnetWritePermissionTestFile, TestFileName, True) then
  begin
    DeleteFile(TestFileName);
    Result := True;
  end;
end;

// =================================================================== UAC

// Builds the standard relaunch command line for the elevated instance:
// the current wizard directory and language, the given task (if any,
// e.g. the movies task) and the no-icons choice.
function CncnetBuildRelaunchCommandLine(const TaskToKeep: String): String;
begin
  Result := '/DIR="' + RemoveBackslashUnlessRoot(WizardDirValue) + '" /LANG="' + ExpandConstant('{language}') + '"';
  if TaskToKeep <> '' then
    Result := Result + ' /TASKS="' + TaskToKeep + '"';
  if WizardNoIcons then
    Result := Result + ' /NOICONS';
end;

// Requests elevation: relaunches this setup.exe with the 'runas' verb and
// the given command line, then terminates this instance (never returns)
// when the UAC prompt was accepted. Returns False when elevation was
// declined or failed (e.g. this account has no usable administrator
// rights) - the caller decides whether to continue or warn.
function CncnetRelaunchElevated(const CommandLine: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;

  Log('Relaunching elevated: ' + ExpandConstant('{srcexe}') + ' ' + CommandLine);
  // Elevate via the direct ShellExecuteA call - why not the built-in
  // ShellExec and the return-value contract are on the declaration above.
  ResultCode := CncnetShellExecuteA(0, 'runas', ExpandConstant('{srcexe}'), CommandLine, '', SW_SHOWNORMAL);
  if ResultCode > 32 then
  begin
    // The elevated instance takes over; close this one (why not Abort():
    // see the CncnetExitProcess declaration above).
    CncnetExitProcess(0);
  end;
end;

// Per-user installs cannot install machine-wide dependencies (they are
// machine-wide installers that require elevation): collects the titles and
// download URLs of everything still queued in Dependency_List into
// MissingText (for the ready-page prompt) and unqueues them so the
// library does not try to install them. Call from InitializeSetup when
// not CncnetIsUserAnAdmin().
procedure CncnetCollectPerUserDeps(var MissingText: String);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(Dependency_List) - 1 do
  begin
    MissingText := MissingText + '  -  ' + Dependency_List[I].Title + #13#10;
    if Dependency_List[I].URL <> '' then
      MissingText := MissingText + '       ' + Dependency_List[I].URL + #13#10;
  end;
  SetArrayLength(Dependency_List, 0);

  if MissingText <> '' then
    Log('Per-user install: missing machine-wide dependencies (cannot be installed without elevation):' + #13#10 + MissingText)
  else
    Log('Per-user install: all machine-wide dependencies are already installed.');
end;

// Ready-page prompt: offers to relaunch elevated so the machine-wide
// dependencies can be installed. No-op when MissingText is empty or the
// install is silent (a scripted run must not trigger a UAC prompt).
// PromptMessage / FailedMessage are the (already cm:-expanded) format
// messages with one %1 placeholder. TaskToKeep is the task name to
// re-select in the elevated instance ('' for none).
procedure CncnetWarnMissingDeps(const MissingText, PromptMessage, FailedMessage: String; const TaskToKeep: String);
begin
  if (MissingText = '') or WizardSilent then
    exit;

  // Default is IDNO: a scripted (/SUPPRESSMSGBOXES) run must not trigger a
  // UAC prompt - it continues the per-user install instead.
  if (SuppressibleMsgBox(FmtMessage(PromptMessage, [TrimRight(MissingText)]), mbConfirmation, MB_YESNO, IDNO) <> IDYES) then
  begin
    Log('Per-user install continues with missing machine-wide dependencies:' + #13#10 + MissingText);
    exit;
  end;

  if not CncnetRelaunchElevated(CncnetBuildRelaunchCommandLine(TaskToKeep)) then
  begin
    // Elevation was declined or failed: the runtimes cannot be installed
    // without elevation, so do not continue silently - tell the user
    // exactly what is missing and where to get it.
    Log('Elevation declined or failed; missing machine-wide dependencies:' + #13#10 + MissingText);
    SuppressibleMsgBox(FmtMessage(FailedMessage, [TrimRight(MissingText)]), mbError, MB_OK, IDOK);
  end;
end;

// Dir-page write-permission failure: offers the same smart-UAC relaunch as
// CncnetWarnMissingDeps, so an elevated instance can install into the
// chosen folder (the elevated instance re-runs the write test and passes
// it). PromptMessage / DeniedMessage are the (already cm:-expanded) format
// messages with one %1 placeholder (the target dir). No-op in silent
// installs (a scripted run must not trigger a UAC prompt); when the run is
// already elevated the elevation offer is skipped and only the Denied
// message is shown (elevation cannot fix a read-only location or an
// anti-virus block).
procedure CncnetWriteDenied(const AppDir, PromptMessage, DeniedMessage: String);
begin
  if WizardSilent then
    Exit;

  if CncnetIsUserAnAdmin() then
  begin
    Log('Write-permission test failed (already elevated): ' + AppDir);
    SuppressibleMsgBox(FmtMessage(DeniedMessage, [AppDir]), mbConfirmation, MB_OK, IDOK);
    Exit;
  end;

  // Default is IDNO: a scripted (/SUPPRESSMSGBOXES) run must not trigger a
  // UAC prompt - it stays per-user instead.
  if SuppressibleMsgBox(FmtMessage(PromptMessage, [AppDir]), mbConfirmation, MB_YESNO, IDNO) <> IDYES then
  begin
    Log('Write-permission test failed; elevation declined: ' + AppDir);
    SuppressibleMsgBox(FmtMessage(DeniedMessage, [AppDir]), mbConfirmation, MB_OK, IDOK);
    Exit;
  end;

  // No task is selected yet at the dir page, so none is passed through.
  // When the elevated instance takes over this never returns (the current
  // instance terminates); otherwise elevation failed - explain the failure.
  if not CncnetRelaunchElevated(CncnetBuildRelaunchCommandLine('')) then
  begin
    Log('Write-permission test failed; elevation failed: ' + AppDir);
    SuppressibleMsgBox(FmtMessage(DeniedMessage, [AppDir]), mbError, MB_OK, IDOK);
  end;
end;

// Launches a program whose manifest requires elevation (a plain Exec /
// CreateProcess from a per-user setup fails with error 740,
// ERROR_ELEVATION_REQUIRED): asks the user first, then requests elevation
// via the 'runas' verb (UAC consent). Unlike CncnetRelaunchElevated (which
// relaunches this setup.exe itself and never returns on success), this
// launches an EXTERNAL program and always returns, so the install
// continues either way. ExeFile / WorkDir are the expanded target path and
// working directory; PromptMessage / SkippedMessage are the (already
// cm:-expanded) texts, SkippedMessage may be '' (no box on decline).
// No-op (log only) in silent installs - a scripted run must not trigger a
// UAC prompt; a /SUPPRESSMSGBOXES run is declined the same way. Returns
// True when the program was started.
function CncnetRunElevated(const ExeFile, WorkDir, PromptMessage, SkippedMessage: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;

  if CncnetIsUserAnAdmin() then
  begin
    // An elevated setup can spawn an elevation-required program directly
    // (no UAC involved).
    if ShellExec('open', ExeFile, '', WorkDir, SW_SHOWNORMAL, ewNoWait, ResultCode) then
    begin
      Log('Elevated program started (setup already elevated): ' + ExeFile);
      Result := True;
    end
    else
      Log('Elevated program failed to start (code ' + IntToStr(ResultCode) + '): ' + ExeFile);
    Exit;
  end;

  if WizardSilent then
  begin
    Log('Elevated program skipped (silent install): ' + ExeFile);
    Exit;
  end;

  // Default is IDNO: a scripted (/SUPPRESSMSGBOXES) run must not trigger a
  // UAC prompt - it is skipped instead.
  if SuppressibleMsgBox(PromptMessage, mbConfirmation, MB_YESNO, IDNO) <> IDYES then
  begin
    Log('Elevated program skipped (declined by the user): ' + ExeFile);
    if SkippedMessage <> '' then
      SuppressibleMsgBox(SkippedMessage, mbInformation, MB_OK, IDOK);
    Exit;
  end;

  // 'runas' goes through the shell's standard elevation path and shows the
  // UAC consent prompt; the call blocks until the user decides. (Why not
  // the built-in ShellExec, and the return-value contract, are on the
  // CncnetShellExecuteA declaration above.)
  ResultCode := CncnetShellExecuteA(0, 'runas', ExeFile, '', WorkDir, SW_SHOWNORMAL);
  if ResultCode > 32 then
  begin
    Log('Elevated program started: ' + ExeFile);
    Result := True;
  end
  else
  begin
    Log('Elevation declined or failed (code ' + IntToStr(ResultCode) + '): ' + ExeFile);
    if SkippedMessage <> '' then
      SuppressibleMsgBox(SkippedMessage, mbInformation, MB_OK, IDOK);
  end;
end;

// ================================================== license radio overlay

// Inno 7's TNewRadioButton ignores Color and always draws its caption in
// black - unreadable on the theme artwork. Replace each native caption
// with a themed TLabel beside the circle; clicking the label checks the
// underlying radio, which Inno's Next-button gating reads. Ported from
// the RA1/YR templates (they were verbatim identical).
procedure CncnetThemeLicenseRadio(sourceRadio: TRadioButton; onClick: TNotifyEvent);
var
  rLeft, rTop, rWidth, rHeight: Integer;
  cap: string;
  circleWidth: Integer;
  newLabel: TLabel;
begin
  cap := sourceRadio.Caption;
  rLeft := sourceRadio.Left;
  rTop := sourceRadio.Top;
  rWidth := sourceRadio.Width;
  rHeight := sourceRadio.Height;

  // The circle (ring + dot) sits ~14-16px at the control's left edge.
  circleWidth := ScaleX(20);

  // Clear the native caption (Inno 7: TNewRadioButton always draws it in
  // black - Color is ignored; Font.Color only colors the selection dot),
  // which is unreadable on the theme artwork.
  sourceRadio.Caption := '';
  // Inno 7: Font.Color only affects the selection dot - theme it to match.
  sourceRadio.Font.Color := {#ISThemeForeColor};
  // Shrink the radio HWND to just the circle zone. Its full-width HWND would
  // otherwise sit on top of the caption area and swallow clicks there: the
  // empty-caption radio hit-tests the circle only, and the windowless label
  // below can't intercept messages that go to the radio's HWND. With the
  // HWND limited to the circle, caption clicks reach the parent surface
  // instead, whose VCL dispatch routes them to the label's OnClick.
  sourceRadio.Width := circleWidth;

  newLabel := TLabel.Create(WizardForm);
  newLabel.Parent := sourceRadio.Parent;
  newLabel.Caption := cap;
  newLabel.Left := rLeft + circleWidth;
  newLabel.Top := rTop;
  newLabel.Width := rWidth - circleWidth;
  newLabel.Height := rHeight;
  newLabel.Transparent := True;
  newLabel.Font.Color := {#ISThemeForeColor};
  newLabel.OnClick := onClick;
  newLabel.BringToFront;
end;

procedure CncnetLicenseAcceptLabelClick(Sender: TObject);
begin
  WizardForm.LicenseAcceptedRadio.Checked := True;
end;

procedure CncnetLicenseNotAcceptLabelClick(Sender: TObject);
begin
  WizardForm.LicenseNotAcceptedRadio.Checked := True;
end;

procedure CncnetThemeLicenseRadios();
begin
  CncnetThemeLicenseRadio(WizardForm.LicenseAcceptedRadio, @CncnetLicenseAcceptLabelClick);
  CncnetThemeLicenseRadio(WizardForm.LicenseNotAcceptedRadio, @CncnetLicenseNotAcceptLabelClick);
end;

// ============================================================ download page

// Human-readable download speed (IDP's formatspeed): integral KB/s below
// 1 MiB/s, one-decimal MB/s below 10 MiB/s, integral MB/s above (binary
// units; Format gives the locale-aware decimal separator).
function CncnetDlFormatSpeed(const BytesPerSecond: Double): String;
begin
  if BytesPerSecond < 1048576 then
    Result := IntToStr(Trunc(BytesPerSecond / 1024.0)) + ' KB/s'
  else if BytesPerSecond < 10485760 then
    Result := Format('%.1f MB/s', [BytesPerSecond / 1048576.0])
  else
    Result := IntToStr(Trunc(BytesPerSecond / 1048576.0)) + ' MB/s';
end;

// Human-readable byte count (IDP's formatsize): integral KB below 1 MiB,
// two-decimal MB below 1 GiB, two-decimal GB above (binary units; Format
// gives the locale-aware decimal separator).
function CncnetDlFormatSize(const Bytes: Int64): String;
begin
  if Bytes < 1048576 then
    Result := IntToStr(Bytes div 1024) + ' KB'
  else if Bytes < 1073741824 then
    Result := Format('%.2f MB', [Bytes / 1048576.0])
  else
    Result := Format('%.2f GB', [Bytes / 1073741824.0]);
end;

// "x of y" pair (IDP's formatsize(ofmsg, size1, size2) overload): the unit
// is picked from the total and both values use it with two decimals, so
// the two halves of the pair never disagree about units. A zero total
// (unknown size) renders as a single value.
function CncnetDlFormatSizeOf(const Bytes, TotalBytes: Int64): String;
begin
  if TotalBytes = 0 then
    Result := CncnetDlFormatSize(Bytes)
  else if TotalBytes < 1073741824 then
    Result := Format('%.2f MB of %.2f MB', [Bytes / 1048576.0, TotalBytes / 1048576.0])
  else
    Result := Format('%.2f GB of %.2f GB', [Bytes / 1073741824.0, TotalBytes / 1073741824.0]);
end;

// hh:mm:ss from whole seconds, hours zero-padded (IDP formats the timer
// as %02u:%02u:%02u). Delphi's Format('%2.0d') pads with spaces, so the
// padding is done explicitly.
function CncnetDlFormatTime(const Seconds: Int64): String;
var
  Hours, Minutes, Secs: Int64;
begin
  Hours := Seconds div 3600;
  Minutes := (Seconds mod 3600) div 60;
  Secs := Seconds mod 60;
  if Hours < 10 then
    Result := '0'
  else
    Result := '';
  Result := Result + IntToStr(Hours) + ':';
  if Minutes < 10 then
    Result := Result + '0';
  Result := Result + IntToStr(Minutes) + ':';
  if Secs < 10 then
    Result := Result + '0';
  Result := Result + IntToStr(Secs);
end;

// Progress callback body, instance-based. The engine runs the HTTP
// download on a worker thread and invokes this on the main thread (while
// pumping window messages) at most once every 50 ms per file, with the
// bytes received so far for the current file and the total size of that
// file (ProgressMax is 0 while the size is still unknown). Returning
// False would cancel the download, so always return True.
function CncnetDlProgressEx(const Url, FileName: String; const Progress, ProgressMax: Int64; var L: TCncnetDl): Boolean;
var
  Now: Longword;
  Speed: Double;
  Received: Int64;
  CurrentMax: Int64;
begin
  Result := True;

  Now := CncnetGetTickCount();

  // A new file (or a retry) starts with a lower byte count than the last
  // sample; restart the per-file speed clocks (IDP starts a fresh
  // speedTimer for every file). On the dependency page (which the library
  // drives one file at a time without a CncnetDlPrepareProgressEx reset)
  // also drop the previous file's adopted total so the new file's size is
  // adopted as the fresh total on its first sized tick.
  if Progress < L.LastBytes then
  begin
    L.LastBytes := 0;
    L.FileStartTick := Now;
    L.LastSpeedTick := Now;
    // Only clear an ADOPTED total (the dependency page, which the library
    // drives one file at a time without a CncnetDlPrepareProgressEx reset)
    // so this file's size is adopted as the fresh total on its first sized
    // tick. A given total (the movie page's multi-file session total, set
    // by CncnetDlPrepareProgressEx) must survive a retry of one file -
    // the retry path does not call CncnetDlPrepareProgressEx again.
    if L.TotalAdopted then
    begin
      L.SessionTotal := 0;
      L.OverallBar.Visible := False;
      L.TotalValueLabel.Caption := 'Unknown';
      L.TotalAdopted := False;
    end;
  end;
  L.LastBytes := Progress;

  // The engine writes the current file name into Msg2Label (the "File:"
  // row value) on every tick itself; update all the other rows here.
  Received := L.BytesBase + Progress;
  if ProgressMax > 0 then
    CurrentMax := ProgressMax
  else
    CurrentMax := L.CurrentFileSize;

  // The overall bar and the "Total progress" value need a session total.
  // The movie page gets it from CncnetDlPrepareProgressEx (the sum of the
  // known file sizes); the dependency page gets it from the engine, which
  // reports each file's size in this callback (ProgressMax > 0). The
  // library downloads dependencies one file at a time (Clear -> Add ->
  // Download, no CncnetDlPrepareProgressEx in between), so the current
  // file's size IS the whole session - adopt it the first time the engine
  // reports it (ProgressMax is 0 until the size is known). On the movie
  // page this cannot fire: Received = BaseBytes + Progress stays below
  // the given session total, and a total of 0 there is only adopted if
  // the engine reports a size - still better than "Unknown".
  if (ProgressMax > 0) and ((L.SessionTotal = 0) or (L.BytesBase + Progress > L.SessionTotal)) then
  begin
    L.SessionTotal := ProgressMax;
    if ProgressMax > CncnetOverallBarByteLimit then
      L.OverallBarScale := 1048576
    else
      L.OverallBarScale := 1;
    L.OverallBar.Visible := True;
    L.OverallBar.Min := 0;
    L.OverallBar.Max := ProgressMax div L.OverallBarScale;
    L.TotalAdopted := True;
  end;

  if L.SessionTotal > 0 then
  begin
    L.OverallBar.Position := Received div L.OverallBarScale;
    L.TotalValueLabel.Caption := CncnetDlFormatSizeOf(Received, L.SessionTotal);
  end;

  L.CurrentValueLabel.Caption := CncnetDlFormatSizeOf(Progress, CurrentMax);
  L.StatusValueLabel.Caption := 'Downloading...';
  L.ElapsedValueLabel.Caption := CncnetDlFormatTime((Now - L.SessionStartTick) div 1000);

  // Speed and remaining time, refreshed at most once a second (IDP's
  // speedTimer(1000) - not on every progress tick). The speed is the
  // cumulative average for the file currently downloading, so each
  // per-second step is stable, and the 1 Hz cadence keeps the rows from
  // flickering on every ~50 ms tick.
  if Now >= L.LastSpeedTick + 1000 then
  begin
    L.LastSpeedTick := Now;
    if Now > L.FileStartTick then
      Speed := Progress * 1000.0 / (Now - L.FileStartTick)
    else
      Speed := 0;
    if Speed > 0 then
    begin
      L.SpeedValueLabel.Caption := CncnetDlFormatSpeed(Speed);
      // Remaining (IDP): the session's remaining bytes at this average
      // speed. Speed is in bytes/second, so (bytes / bytes-per-second) is
      // already seconds - no unit conversion. (Session total unknown:
      // the comparison below is false, so '-' is shown.)
      if (L.SessionTotal > 0) and (Received < L.SessionTotal) then
        L.RemainingValueLabel.Caption := CncnetDlFormatTime(Trunc((L.SessionTotal - Received) / Speed))
      else
        L.RemainingValueLabel.Caption := '-';
    end
    else
    begin
      L.SpeedValueLabel.Caption := '-';
      L.RemainingValueLabel.Caption := '-';
    end;
  end;
end;

// Progress callback for the template's own download page (CncnetDl); the
// fixed signature CreateDownloadPage requires (the engine's
// TOnDownloadProgress type).
function CncnetDlProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  Result := CncnetDlProgressEx(Url, FileName, Progress, ProgressMax, CncnetDl);
end;

// Progress callback for the InnoDependencyInstaller dependency page
// (CncnetDep).
function CncnetDepProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  Result := CncnetDlProgressEx(Url, FileName, Progress, ProgressMax, CncnetDep);
end;

// Sizes the overall bar and resets the per-row state before a download (or
// the next file of a multi-file download) starts.
procedure CncnetDlPrepareProgressEx(var L: TCncnetDl; const BaseBytes, TotalBytes, FileSize: Int64);
begin
  L.BytesBase := BaseBytes;
  L.SessionTotal := TotalBytes;
  L.CurrentFileSize := FileSize;
  L.LastBytes := 0;
  // A given total is never "adopted": on a file restart (a retry, on the
  // movie page) the given multi-file total must survive - only adopted
  // totals (dependency page) are dropped there.
  L.TotalAdopted := False;
  L.FileStartTick := CncnetGetTickCount();
  L.LastSpeedTick := CncnetGetTickCount();
  if BaseBytes = 0 then
    L.SessionStartTick := CncnetGetTickCount();

  if TotalBytes > 0 then
  begin
    // The overall bar's Max is 32-bit, so when the session total approaches
    // that limit, switch the bar to megabyte units (Max and Position are
    // scaled by the same factor, so the ratio is unchanged).
    if TotalBytes > CncnetOverallBarByteLimit then
      L.OverallBarScale := 1048576
    else
      L.OverallBarScale := 1;
    L.OverallBar.Visible := True;
    L.OverallBar.Min := 0;
    L.OverallBar.Max := TotalBytes div L.OverallBarScale;
    L.OverallBar.Position := BaseBytes div L.OverallBarScale;
    L.TotalValueLabel.Caption := CncnetDlFormatSizeOf(BaseBytes, TotalBytes);
  end
  else
  begin
    // Unknown session total (all sizes 0): the overall bar cannot be
    // sized, hide it and mark the total as unknown.
    L.OverallBar.Visible := False;
    L.TotalValueLabel.Caption := 'Unknown';
  end;

  L.CurrentValueLabel.Caption := CncnetDlFormatSizeOf(0, FileSize);
  L.SpeedValueLabel.Caption := '-';
  L.StatusValueLabel.Caption := 'Starting...';
  L.ElapsedValueLabel.Caption := CncnetDlFormatTime(0);
  L.RemainingValueLabel.Caption := '-';
end;

// Sleep alone would freeze the wizard (Inno's Sleep does not process
// window messages), so pump in 100 ms steps exactly like
// InnoDependencyInstaller's Dependency_Wait: TDownloadWizardPage.SetText
// calls ProcessMsgs, which runs Application.ProcessMessages while this
// page is current (it is, during the retry wait). The file name is passed
// as Msg2 so the "File:" row keeps showing it during the wait (the engine
// itself writes it there on each progress tick); the wait reason is shown
// on the "Status:" row, not in Msg1 (that label is hidden in the IDP
// layout).
//
// Note: a custom PeekMessage/TranslateMessage/DispatchMessage pump was
// tried first, but newer Windows builds (10.0.26300 verified) no longer
// export user32.dll's TranslateMessageA/W entry points, so Inno's script
// engine failed to import the external at script load and the installer
// died at startup with "Cannot import dll: utf8 user32.dll". The SetText
// pump avoids any user32 import at all.
procedure CncnetDlWaitEx(var L: TCncnetDl; const Title, FileName, StatusText: String; const Milliseconds: Integer);
var
  Step: Integer;
begin
  L.StatusValueLabel.Caption := StatusText;
  for Step := 1 to Milliseconds div 100 do
  begin
    L.Page.SetText(Title, FileName);
    Sleep(100);
  end;
end;

// Downloads one file to the temp directory on the download page: a real
// per-file progress bar plus a Stop button (TDownloadWizardPage, the same
// page type InnoDependencyInstaller uses for its dependency downloads) -
// instead of the generic install progress gauge the [Files] "download"
// flag produces. The overall (all-files) bar below it is sized for
// TotalBytes and starts at BaseBytes (the bytes of the files queued
// before this one).
//
// Transient failures are retried with a backoff; afterwards the user can
// abort the install, retry again, or ignore the file (the install then
// continues without it; the matching [Files] entry has
// skipifsourcedoesntexist).
//
// Returns True when the file is in the temp directory, or when the user
// chose to ignore the failure.
function CncnetDlDownloadFileEx(var L: TCncnetDl; const Url, Filename, Title: String; const BaseBytes, TotalBytes, FileSize: Int64): Boolean;
var
  Attempt: Integer;
  Retry: Boolean;
begin
  Result := True;
  CncnetDlPrepareProgressEx(L, BaseBytes, TotalBytes, FileSize);
  L.Page.Clear;
  L.Page.Add(Url, Filename, '');
  // Prefill the "File:" row value (the engine writes the file name into it
  // on the first progress tick anyway).
  L.Page.SetText(Title, Filename);

  // break inside try does not leave the loop in Pascal Script, so loop on a flag
  Attempt := 0;
  Retry := True;
  while Retry do
  begin
    Retry := False;
    try
      L.Page.Download;
    except
      if L.Page.AbortedByUser then
      begin
        Log('Download aborted by user: ' + Title);
        Result := False;
      end
      else
      begin
        Log('Download failed: ' + Title + ': ' + GetExceptionMessage);
        Attempt := Attempt + 1;
        if Attempt <= 3 then
        begin
          Log('Retrying download (attempt ' + IntToStr(Attempt) + ' of 3): ' + Title);
          CncnetDlWaitEx(L, Title, Filename, 'Status: Waiting ' + IntToStr(2 * Attempt) + ' s (attempt ' + IntToStr(Attempt) + ' of 3): ' + GetExceptionMessage, 2000 * Attempt);
          Retry := True;
        end
        else
        begin
          case SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_ABORTRETRYIGNORE, IDABORT) of
            IDABORT:
              Result := False;
            IDRETRY:
              begin
                Attempt := 0;
                Retry := True;
              end;
            IDIGNORE:
              Log('Download ignored, continuing without the file: ' + Title);
          end;
        end;
      end;
    end;
  end;
end;

// ------------------------------------------------------------------ queue

procedure CncnetDlQueueReset();
begin
  SetArrayLength(CncnetDlQueueUrls, 0);
  SetArrayLength(CncnetDlQueueFiles, 0);
  SetArrayLength(CncnetDlQueueTitles, 0);
  SetArrayLength(CncnetDlQueueSizesKB, 0);
end;

// Queues one download. SizeKB is the file size in KB for the progress bar
// (0 = unknown - the overall bar and the "Total progress" value then show
// "Unknown"); Title is the display title ('' = "<file> (n of m)").
procedure CncnetDlQueueAdd(const Url, Filename, Title: String; SizeKB: Integer);
var
  I: Integer;
begin
  I := Length(CncnetDlQueueUrls);
  SetArrayLength(CncnetDlQueueUrls, I + 1);
  CncnetDlQueueUrls[I] := Url;
  SetArrayLength(CncnetDlQueueFiles, I + 1);
  CncnetDlQueueFiles[I] := Filename;
  SetArrayLength(CncnetDlQueueTitles, I + 1);
  CncnetDlQueueTitles[I] := Title;
  SetArrayLength(CncnetDlQueueSizesKB, I + 1);
  CncnetDlQueueSizesKB[I] := SizeKB;
end;

// Downloads the whole queue (one file at a time, each with its own
// per-file progress bar, and an overall bar spanning all files with known
// sizes). Shows and hides the page itself. Returns False as soon as a
// download is aborted (the remaining files are not started).
function CncnetDlDownloadAll(): Boolean;
var
  I, Count: Integer;
  TotalBytes: Int64;
  BaseBytes: Int64;
  Title: String;
  Size: Int64;
begin
  Result := True;
  Count := Length(CncnetDlQueueUrls);
  if Count = 0 then
    Exit;

  TotalBytes := 0;
  for I := 0 to Count - 1 do
    TotalBytes := TotalBytes + Int64(CncnetDlQueueSizesKB[I]) * 1024;

  CncnetDl.Page.Show;
  try
    BaseBytes := 0;
    for I := 0 to Count - 1 do
    begin
      Size := Int64(CncnetDlQueueSizesKB[I]) * 1024;
      if CncnetDlQueueTitles[I] <> '' then
        Title := CncnetDlQueueTitles[I]
      else
        Title := CncnetDlQueueFiles[I] + ' (' + IntToStr(I + 1) + ' of ' + IntToStr(Count) + ')';
      if not CncnetDlDownloadFileEx(CncnetDl, CncnetDlQueueUrls[I], CncnetDlQueueFiles[I], Title, BaseBytes, TotalBytes, Size) then
      begin
        Result := False;
        Break;
      end;
      BaseBytes := BaseBytes + Size;
    end;
  finally
    CncnetDl.Page.Hide;
  end;
end;

// ------------------------------------------------------------------ layout
//
// IDP-style (InnoDownloadPlugin) layout of the download page,
//
//   Title (bold)
//   Description (two lines; hidden when the surface is too short for it)
//   Total progress      <x of y MB>       caption + right-aligned value
//   [overall (all-files) progress bar]    full width, 20 high
//   Current file        <x of y MB>       caption + right-aligned value
//   [per-file progress bar]               full width, 20 high
//   File:       <file name>
//   Speed:      <MB/s>
//   Status:     <text>
//   Elapsed time:   <hh:mm:ss>
//   Remaining time: <hh:mm:ss>
//
//   [Stop button - bottom-right, below the last row]
//
// The page's own Caption/Description (CreateDownloadPage) never render,
// because ISTheme.ReplaceLabel hides the form-level labels they update
// (it clones a static label capturing the caption at init time, so the
// real labels stay hidden forever) - hence the title and description are
// drawn as labels on the page surface instead.
//
// The built-in controls are repurposed rather than recreated:
//   Msg1Label   - hidden (the engine's SetText still writes its caption,
//                 but nothing re-shows it)
//   Msg2Label   - the "File:" row value (the engine writes the current
//                 file name into it on every progress tick, and
//                 ShowProgressControls re-shows it on the first tick, so
//                 it cannot stay hidden)
//   ProgressBar - the per-file ("Current file") bar
//   AbortButton - the "Stop" button, below the last row, bottom-right
//
// Coordinates are relative to the page surface, in design pixels scaled
// with ScaleX/ScaleY (like the built-in controls). The IDP gap scheme:
// row->bar 2, bar->next row 12, bar->first info row 16, info row pitch
// 16, last row->button 6; the info row captions sit at x=0 (116 wide)
// with their values in the column at x=120; the Total/Current values
// are right-aligned in a 160-wide box 10 from the surface right edge
// (wide enough for "93.5 MB of 1409.4 MB").
procedure CncnetDlBuildLayout(const Page: TDownloadWizardPage; const Title, Description: String; var L: TCncnetDl);
var
  SurfaceWidth, SurfaceHeight, C: Integer;
  RowHeight, BarHeight, InfoCaptionWidth, ValueColumn, RightMargin, ValueBoxWidth: Integer;
begin
  // Guard against laying out the same page/instance twice.
  if L.Started then
    Exit;
  L.Page := Page;

  // Per-session state defaults. CncnetDlPrepareProgressEx re-sets most of
  // these before each download; for the dependency page (which the
  // library drives without going through it) these are the values that
  // stay, so the speed/elapsed rows must not start from a zero tick.
  L.BytesBase := 0;
  L.SessionTotal := 0;
  L.CurrentFileSize := 0;
  L.OverallBarScale := 1;
  L.SessionStartTick := CncnetGetTickCount();
  L.FileStartTick := CncnetGetTickCount();
  L.LastSpeedTick := CncnetGetTickCount();
  L.LastBytes := 0;
  L.TotalAdopted := False;

  SurfaceWidth := Page.SurfaceWidth;
  SurfaceHeight := Page.SurfaceHeight;
  Log('Download page surface: ' + IntToStr(SurfaceWidth) + 'x' + IntToStr(SurfaceHeight));

  RowHeight := ScaleY(14);
  BarHeight := ScaleY(20);
  InfoCaptionWidth := ScaleX(116);
  ValueColumn := ScaleX(120);
  RightMargin := ScaleX(10);
  ValueBoxWidth := ScaleX(160);

  // Title (bold).
  L.TitleLabel := TNewStaticText.Create(WizardForm);
  L.TitleLabel.Parent := Page.Surface;
  L.TitleLabel.Left := 0;
  L.TitleLabel.Top := 0;
  L.TitleLabel.Width := SurfaceWidth;
  L.TitleLabel.Height := RowHeight;
  L.TitleLabel.Caption := Title;
  L.TitleLabel.Font.Style := [fsBold];

  // Description (two lines).
  L.DescriptionLabel := TNewStaticText.Create(WizardForm);
  L.DescriptionLabel.Parent := Page.Surface;
  L.DescriptionLabel.Left := 0;
  L.DescriptionLabel.Top := ScaleY(16);
  L.DescriptionLabel.Width := SurfaceWidth;
  L.DescriptionLabel.Height := ScaleY(28);
  L.DescriptionLabel.WordWrap := True;
  L.DescriptionLabel.Caption := Description;

  // Content block top: below the title (14) + gap (16), and below the
  // description (28) + gap (16) when it fits - the content block (Total
  // row .. Stop button) is 207 design pixels tall.
  C := ScaleY(14) + ScaleY(16);
  L.DescriptionLabel.Visible := SurfaceHeight >= C + ScaleY(28 + 16 + 207);
  if L.DescriptionLabel.Visible then
    C := C + ScaleY(28 + 16);

  // "Total progress" row: caption + the value right-aligned in a 160-wide
  // box 10 from the surface right edge.
  L.TotalCaptionLabel := TNewStaticText.Create(WizardForm);
  L.TotalCaptionLabel.Parent := Page.Surface;
  L.TotalCaptionLabel.Left := 0;
  L.TotalCaptionLabel.Top := C;
  L.TotalCaptionLabel.Width := ScaleX(200);
  L.TotalCaptionLabel.Height := RowHeight;
  L.TotalCaptionLabel.Caption := 'Total progress';

  L.TotalValueLabel := TNewStaticText.Create(WizardForm);
  L.TotalValueLabel.Parent := Page.Surface;
  L.TotalValueLabel.Left := SurfaceWidth - RightMargin - ValueBoxWidth;
  L.TotalValueLabel.Top := C;
  L.TotalValueLabel.Width := ValueBoxWidth;
  L.TotalValueLabel.Height := RowHeight;
  L.TotalValueLabel.Alignment := taRightJustify;
  // Initial value until the first sized progress tick: the movie page's
  // CncnetDlPrepareProgressEx overwrites this on each file, and the
  // dependency page's total is adopted from the engine's reported size
  // on its first sized tick (see CncnetDlProgressEx).
  L.TotalValueLabel.Caption := 'Unknown';

  // Overall (all-files) progress bar, full width. Hidden until a total
  // becomes known: CncnetDlPrepareProgressEx sizes it for the movie page
  // (the sum of the file sizes), and the engine's reported file size is
  // adopted for the dependency page (one file at a time IS the session,
  // see CncnetDlProgressEx).
  L.OverallBar := TNewProgressBar.Create(WizardForm);
  L.OverallBar.Parent := Page.Surface;
  L.OverallBar.Left := 0;
  L.OverallBar.Top := C + ScaleY(16);
  L.OverallBar.Width := SurfaceWidth;
  L.OverallBar.Height := BarHeight;
  L.OverallBar.Min := 0;
  L.OverallBar.Max := 1;
  L.OverallBar.Position := 0;
  L.OverallBar.Visible := False;

  // "Current file" row + value.
  L.CurrentCaptionLabel := TNewStaticText.Create(WizardForm);
  L.CurrentCaptionLabel.Parent := Page.Surface;
  L.CurrentCaptionLabel.Left := 0;
  L.CurrentCaptionLabel.Top := C + ScaleY(48);
  L.CurrentCaptionLabel.Width := ScaleX(200);
  L.CurrentCaptionLabel.Height := RowHeight;
  L.CurrentCaptionLabel.Caption := 'Current file';

  L.CurrentValueLabel := TNewStaticText.Create(WizardForm);
  L.CurrentValueLabel.Parent := Page.Surface;
  L.CurrentValueLabel.Left := SurfaceWidth - RightMargin - ValueBoxWidth;
  L.CurrentValueLabel.Top := C + ScaleY(48);
  L.CurrentValueLabel.Width := ValueBoxWidth;
  L.CurrentValueLabel.Height := RowHeight;
  L.CurrentValueLabel.Alignment := taRightJustify;
  L.CurrentValueLabel.Caption := 'Unknown';

  // Per-file bar: the page's built-in ProgressBar (the engine keeps its
  // position and updates Style/Max/Position/Visible itself).
  Page.ProgressBar.Left := 0;
  Page.ProgressBar.Top := C + ScaleY(64);
  Page.ProgressBar.Width := SurfaceWidth;
  Page.ProgressBar.Height := BarHeight;

  // "File:" row: caption + the built-in Msg2Label as the value (the
  // engine writes the current file name into it on every progress tick
  // and re-shows it on the first tick, so it cannot stay hidden).
  L.FileCaptionLabel := TNewStaticText.Create(WizardForm);
  L.FileCaptionLabel.Parent := Page.Surface;
  L.FileCaptionLabel.Left := 0;
  L.FileCaptionLabel.Top := C + ScaleY(100);
  L.FileCaptionLabel.Width := InfoCaptionWidth;
  L.FileCaptionLabel.Height := RowHeight;
  L.FileCaptionLabel.Caption := 'File:';

  Page.Msg1Label.Visible := False;
  Page.Msg2Label.Left := ValueColumn;
  Page.Msg2Label.Top := C + ScaleY(100);
  Page.Msg2Label.Width := SurfaceWidth - ValueColumn - RightMargin;
  Page.Msg2Label.Height := RowHeight;

  // Speed / Status / Elapsed time / Remaining time rows (IDP pitch: 16):
  // caption at x=0 (116 wide) + the value in the column at x=120.
  L.SpeedLabel := TNewStaticText.Create(WizardForm);
  L.SpeedLabel.Parent := Page.Surface;
  L.SpeedLabel.Left := 0;
  L.SpeedLabel.Top := C + ScaleY(116);
  L.SpeedLabel.Width := InfoCaptionWidth;
  L.SpeedLabel.Height := RowHeight;
  L.SpeedLabel.Caption := 'Speed:';

  L.SpeedValueLabel := TNewStaticText.Create(WizardForm);
  L.SpeedValueLabel.Parent := Page.Surface;
  L.SpeedValueLabel.Left := ValueColumn;
  L.SpeedValueLabel.Top := C + ScaleY(116);
  L.SpeedValueLabel.Width := SurfaceWidth - ValueColumn - RightMargin;
  L.SpeedValueLabel.Height := RowHeight;
  L.SpeedValueLabel.Caption := '-';

  L.StatusLabel := TNewStaticText.Create(WizardForm);
  L.StatusLabel.Parent := Page.Surface;
  L.StatusLabel.Left := 0;
  L.StatusLabel.Top := C + ScaleY(132);
  L.StatusLabel.Width := InfoCaptionWidth;
  L.StatusLabel.Height := RowHeight;
  L.StatusLabel.Caption := 'Status:';

  L.StatusValueLabel := TNewStaticText.Create(WizardForm);
  L.StatusValueLabel.Parent := Page.Surface;
  L.StatusValueLabel.Left := ValueColumn;
  L.StatusValueLabel.Top := C + ScaleY(132);
  L.StatusValueLabel.Width := SurfaceWidth - ValueColumn - RightMargin;
  L.StatusValueLabel.Height := RowHeight;
  L.StatusValueLabel.Caption := 'Starting...';

  L.ElapsedLabel := TNewStaticText.Create(WizardForm);
  L.ElapsedLabel.Parent := Page.Surface;
  L.ElapsedLabel.Left := 0;
  L.ElapsedLabel.Top := C + ScaleY(148);
  L.ElapsedLabel.Width := InfoCaptionWidth;
  L.ElapsedLabel.Height := RowHeight;
  L.ElapsedLabel.Caption := 'Elapsed time:';

  L.ElapsedValueLabel := TNewStaticText.Create(WizardForm);
  L.ElapsedValueLabel.Parent := Page.Surface;
  L.ElapsedValueLabel.Left := ValueColumn;
  L.ElapsedValueLabel.Top := C + ScaleY(148);
  L.ElapsedValueLabel.Width := SurfaceWidth - ValueColumn - RightMargin;
  L.ElapsedValueLabel.Height := RowHeight;
  L.ElapsedValueLabel.Caption := CncnetDlFormatTime(0);

  L.RemainingLabel := TNewStaticText.Create(WizardForm);
  L.RemainingLabel.Parent := Page.Surface;
  L.RemainingLabel.Left := 0;
  L.RemainingLabel.Top := C + ScaleY(164);
  L.RemainingLabel.Width := InfoCaptionWidth;
  L.RemainingLabel.Height := RowHeight;
  L.RemainingLabel.Caption := 'Remaining time:';

  L.RemainingValueLabel := TNewStaticText.Create(WizardForm);
  L.RemainingValueLabel.Parent := Page.Surface;
  L.RemainingValueLabel.Left := ValueColumn;
  L.RemainingValueLabel.Top := C + ScaleY(164);
  L.RemainingValueLabel.Width := SurfaceWidth - ValueColumn - RightMargin;
  L.RemainingValueLabel.Height := RowHeight;
  L.RemainingValueLabel.Caption := '-';

  // Stop button (the page's built-in AbortButton; its width comes from
  // the button caption computed by the engine), right-aligned 10 from the
  // surface right edge.
  Page.AbortButton.Left := SurfaceWidth - RightMargin - Page.AbortButton.Width;
  Page.AbortButton.Top := C + ScaleY(184);
  Page.AbortButton.Height := ScaleY(23);

  L.Started := True;
end;

// Creates the generic download page (TDownloadWizardPage, the same page
// type InnoDependencyInstaller uses for its dependency downloads, with a
// real per-file progress bar and a Stop button) and applies the IDP-style
// layout to the CncnetDl instance. Call from InitializeWizard (after
// ISTheme(), so the page is created with the final form geometry).
// Title/Description are drawn as labels on the page surface (see
// CncnetDlBuildLayout). ShowBaseNameInsteadOfUrl makes the engine write
// the file name (instead of the download URL) into the "File:" row on
// every progress tick.
procedure CncnetSetupDownloadPage(const Title, Description: String);
begin
  CncnetDl.Page := CreateDownloadPage(Title, Description, @CncnetDlProgress);
  CncnetDl.Page.ShowBaseNameInsteadOfUrl := True;
  CncnetDlBuildLayout(CncnetDl.Page, Title, Description, CncnetDl);
end;

// Gives the InnoDependencyInstaller dependency page the same layout as
// CncnetSetupDownloadPage, using the CncnetDep instance. The library
// creates its own page with a nil progress callback in
// Dependency_InitializeWizard (which runs before the template's
// InitializeWizard - Inno 7 runs InitializeWizard handlers in declaration
// order), and Inno 7.0.2 exposes no OnDownloadProgress property to
// scripts (the callback can only be supplied to CreateDownloadPage), so
// the page is recreated here with the CncnetDepProgress callback. The
// library's Dependency_PrepareToInstall reads the Dependency_DownloadPage
// global at install time, so the replacement is picked up; the original
// page is never visited by navigation (download pages carry the
// psAlwaysSkip style, which TWizardForm.ShouldSkipPage skips during
// Next/Back).
//
// The library does not know the sizes of the queued dependencies, but the
// engine reports each file's size in the progress callback (ProgressMax)
// and the library downloads one file at a time - so CncnetDlProgressEx
// adopts the reported size as the session total and the overall bar, the
// "Total progress" value and the remaining-time estimate all work; until
// the first sized tick the "Total progress" value shows "Unknown". The
// built-in per-file bar and the speed/status/elapsed rows update from the
// engine's progress ticks as well.
//
// Requires libs/InnoDependencyInstaller/CodeDependencies.iss to be
// included before this file (it provides Dependency_DownloadPage).
// Call from InitializeWizard (after ISTheme()).
procedure CncnetSetupDependencyDownloadPage(const Title, Description: String);
begin
  Dependency_DownloadPage := CreateDownloadPage(Title, Description, @CncnetDepProgress);
  Dependency_DownloadPage.ShowBaseNameInsteadOfUrl := True;
  CncnetDep.Page := Dependency_DownloadPage;
  CncnetDlBuildLayout(Dependency_DownloadPage, Title, Description, CncnetDep);
end;
