// CncnetCommon.iss - shared CnCNet installer code (Inno Setup 7).
// ISPP-included from a [Code] section AFTER libs/ISTheme/ISTheme.iss, so
// only // (Pascal) comments are allowed here.
// Provides (all Cncnet-prefixed): admin/Wine/Steam detection, smart-UAC
// relaunch, dependency collection, license-radio theming, the generic
// download page + queue and the dependency-download page layout.
// No event handlers: templates keep theirs and call these from them.

[Code]

type
  // One download page: layout controls + progress state (CncnetDl, CncnetDep).
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
    // Bytes of earlier queued files (offset for the overall bar).
    BytesBase: Int64;
    // Total bytes of the session (all files); 0 = unknown (bar hidden).
    SessionTotal: Int64;
    // Known size of the current file, shown until the engine reports one.
    CurrentFileSize: Int64;
    // GetTickCount at session start (elapsed row).
    SessionStartTick: Longword;
    // Overall bar Max/Position divisor: 1, or 1048576 when bytes would overflow the 32-bit Max.
    OverallBarScale: Int64;
    // Speed measurement state (callback only; cumulative average, 1 Hz refresh).
    FileStartTick: Longword;
    LastSpeedTick: Longword;
    LastBytes: Int64;
    // Set once the layout is built (guards against double creation).
    Started: Boolean;
    // SessionTotal came from the engine callback (cleared on file restart);
    // a total given up front survives file retries.
    TotalAdopted: Boolean;
  end;

const
  // Write-test file bundled by templates ([Files] dontcopy), copied into the target dir.
  CncnetWritePermissionTestFile = 'WritePermissionTestFile.txt';

  // Largest total the overall bar can hold in bytes before scaling to MB (32-bit Max).
  CncnetOverallBarByteLimit = 2000000000;

var
  // The template's own download page (movies etc.).
  CncnetDl: TCncnetDl;
  // InnoDependencyInstaller's page, recreated with the progress callback
  // (only settable at CreateDownloadPage time); the library's
  // Dependency_PrepareToInstall reads this global, so the swap applies.
  CncnetDep: TCncnetDl;
  // Download queue (CncnetDlQueueAdd / CncnetDlDownloadAll); sizes in KB (Inno has no TArrayOfInt64), 0 = unknown.
  CncnetDlQueueUrls: TArrayOfString;
  CncnetDlQueueFiles: TArrayOfString;
  CncnetDlQueueTitles: TArrayOfString;
  CncnetDlQueueSizesKB: TArrayOfInteger;

// ==================================================================== externals
// Cncnet* names avoid collisions with template/ISTheme declarations.
// Bare DLL imports cannot appear in Check:/BeforeInstall: expressions - wrap in a named function.

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

// Direct ShellExecuteA import for elevation: Inno's built-in ShellExec() is
// short-circuited when the target is {srcexe} before install, so no UAC prompt is shown.
// Paths and arguments are ASCII, so the ANSI entry point is the right match.
function CncnetShellExecuteA(hWnd: Integer; Operation: PAnsiChar; Filename: PAnsiChar; Parameters: PAnsiChar; Directory: PAnsiChar; nShow: Integer): Integer;
  external 'ShellExecuteA@shell32.dll stdcall';

// kernel32 ExitProcess: Abort() from NextButtonClick does not exit Setup, so this closes the
// non-elevated instance once the elevated one has taken over.
function CncnetExitProcess(ExitCode: Integer): Integer;
  external 'ExitProcess@kernel32.dll stdcall';

// ==================================================================== admin
// True when running elevated: with PrivilegesRequired=lowest, decides the install scope.
function CncnetShellIsUserAnAdmin(): Boolean;
  external 'IsUserAnAdmin@shell32.dll stdcall';
function CncnetIsUserAnAdmin(): Boolean;
begin
  Result := CncnetShellIsUserAnAdmin();
end;

// ====================================================================== Wine
// Wine detection (command line, debugger, wine_* exports, {win}/{sys}\wine files).
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

// True on Wine Snap (the Tahoma font registry value points into Z:\snap\).
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
// (the "BaseInstallFolder_N" values).
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

// Returns the Steam library roots: libraryfolders.vdf "path" entries,
// config.vdf BaseInstallFolder_N entries (older Steam), plus SteamPath itself.
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

  // Registry SteamPath uses forward slashes; normalize for dedup.
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
// Ordered install detection: ExtraDirs, Steam <root>\steamapps\common\<folder>, ClassicDirs.
// First directory containing CheckFile wins; DetectedDir has no trailing backslash.
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
// Verifies the user can write to the target dir (creates it first, copies the bundled test file in).
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

  ExtractTemporaryFile(CncnetWritePermissionTestFile);
  if CopyFile(ExpandConstant('{tmp}\') + CncnetWritePermissionTestFile, TestFileName, True) then
  begin
    DeleteFile(TestFileName);
    Result := True;
  end;
end;

// =================================================================== UAC

// Builds the relaunch command line for the elevated instance (dir, language, task, no-icons).
function CncnetBuildRelaunchCommandLine(const TaskToKeep: String): String;
begin
  Result := '/DIR="' + RemoveBackslashUnlessRoot(WizardDirValue) + '" /LANG="' + ExpandConstant('{language}') + '"';
  if TaskToKeep <> '' then
    Result := Result + ' /TASKS="' + TaskToKeep + '"';
  if WizardNoIcons then
    Result := Result + ' /NOICONS';
end;

// Requests elevation: relaunches {srcexe} with the 'runas' verb and terminates this instance.
// Returns False when declined or failed - the caller decides whether to continue.
function CncnetRelaunchElevated(const CommandLine: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;

  Log('Relaunching elevated: ' + ExpandConstant('{srcexe}') + ' ' + CommandLine);
  ResultCode := CncnetShellExecuteA(0, 'runas', ExpandConstant('{srcexe}'), CommandLine, '', SW_SHOWNORMAL);
  if ResultCode > 32 then
  begin
    // The elevated instance takes over; close this one.
    CncnetExitProcess(0);
  end;
end;

// Per-user installs cannot install machine-wide dependencies: collects their titles/URLs into
// MissingText for the ready-page prompt and unqueues them.
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

// Ready-page prompt offering elevation for the machine-wide dependencies.
// No-op when MissingText is empty or the install is silent.
procedure CncnetWarnMissingDeps(const MissingText, PromptMessage, FailedMessage: String; const TaskToKeep: String);
begin
  if (MissingText = '') or WizardSilent then
    exit;

  // Default is IDNO so a scripted run does not trigger a UAC prompt.
  if (SuppressibleMsgBox(FmtMessage(PromptMessage, [TrimRight(MissingText)]), mbConfirmation, MB_YESNO, IDNO) <> IDYES) then
  begin
    Log('Per-user install continues with missing machine-wide dependencies:' + #13#10 + MissingText);
    exit;
  end;

  if not CncnetRelaunchElevated(CncnetBuildRelaunchCommandLine(TaskToKeep)) then
  begin
    // Elevation declined/failed: do not continue silently; report what is missing.
    Log('Elevation declined or failed; missing machine-wide dependencies:' + #13#10 + MissingText);
    SuppressibleMsgBox(FmtMessage(FailedMessage, [TrimRight(MissingText)]), mbError, MB_OK, IDOK);
  end;
end;

// Dir-page write-permission failure: offers the same smart-UAC relaunch as CncnetWarnMissingDeps.
// No-op in silent installs; when already elevated, only the Denied message is shown.
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

  // Default is IDNO so a scripted run does not trigger a UAC prompt.
  if SuppressibleMsgBox(FmtMessage(PromptMessage, [AppDir]), mbConfirmation, MB_YESNO, IDNO) <> IDYES then
  begin
    Log('Write-permission test failed; elevation declined: ' + AppDir);
    SuppressibleMsgBox(FmtMessage(DeniedMessage, [AppDir]), mbConfirmation, MB_OK, IDOK);
    Exit;
  end;

  // No task is selected yet at the dir page, so none is passed through.
  if not CncnetRelaunchElevated(CncnetBuildRelaunchCommandLine('')) then
  begin
    Log('Write-permission test failed; elevation failed: ' + AppDir);
    SuppressibleMsgBox(FmtMessage(DeniedMessage, [AppDir]), mbError, MB_OK, IDOK);
  end;
end;

// Launches a program whose manifest requires elevation (a plain Exec from a per-user setup fails with 740).
// Asks first, then elevates via the 'runas' verb; no-op in silent installs. Returns True when started.
function CncnetRunElevated(const ExeFile, WorkDir, PromptMessage, SkippedMessage: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;

  if CncnetIsUserAnAdmin() then
  begin
    // An elevated setup can launch it directly (no UAC).
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

  // Default is IDNO so a scripted run does not trigger a UAC prompt.
  if SuppressibleMsgBox(PromptMessage, mbConfirmation, MB_YESNO, IDNO) <> IDYES then
  begin
    Log('Elevated program skipped (declined by the user): ' + ExeFile);
    if SkippedMessage <> '' then
      SuppressibleMsgBox(SkippedMessage, mbInformation, MB_OK, IDOK);
    Exit;
  end;

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

// Inno 7's TNewRadioButton always draws its caption in black - replace it with a themed
// TLabel beside the circle; clicking the label checks the underlying radio.
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

  // Clear the native caption (always drawn black in Inno 7).
  sourceRadio.Caption := '';
  // Inno 7: Font.Color only affects the selection dot - theme it to match.
  sourceRadio.Font.Color := {#ISThemeForeColor};
  // Shrink the radio HWND to the circle zone: a full-width HWND would swallow caption clicks.
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

// Human-readable speed: KB/s below 1 MiB/s, one-decimal MB/s below 10 MiB/s, integral MB/s above.
function CncnetDlFormatSpeed(const BytesPerSecond: Double): String;
begin
  if BytesPerSecond < 1048576 then
    Result := IntToStr(Trunc(BytesPerSecond / 1024.0)) + ' KB/s'
  else if BytesPerSecond < 10485760 then
    Result := Format('%.1f MB/s', [BytesPerSecond / 1048576.0])
  else
    Result := IntToStr(Trunc(BytesPerSecond / 1048576.0)) + ' MB/s';
end;

// Human-readable size: KB below 1 MiB, MB below 1 GiB, GB above (binary units).
function CncnetDlFormatSize(const Bytes: Int64): String;
begin
  if Bytes < 1048576 then
    Result := IntToStr(Bytes div 1024) + ' KB'
  else if Bytes < 1073741824 then
    Result := Format('%.2f MB', [Bytes / 1048576.0])
  else
    Result := Format('%.2f GB', [Bytes / 1073741824.0]);
end;

// "x of y" pair; the unit is picked from the total. A zero total renders a single value.
function CncnetDlFormatSizeOf(const Bytes, TotalBytes: Int64): String;
begin
  if TotalBytes = 0 then
    Result := CncnetDlFormatSize(Bytes)
  else if TotalBytes < 1073741824 then
    Result := Format('%.2f MB of %.2f MB', [Bytes / 1048576.0, TotalBytes / 1048576.0])
  else
    Result := Format('%.2f GB of %.2f GB', [Bytes / 1073741824.0, TotalBytes / 1073741824.0]);
end;

// hh:mm:ss, hours zero-padded (Delphi's Format('%2.0d') pads with spaces, so pad manually).
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

// Progress callback body: the engine calls this on the main thread at most once per 50 ms per file.
// Returning False would cancel the download, so always return True.
function CncnetDlProgressEx(const Url, FileName: String; const Progress, ProgressMax: Int64; var L: TCncnetDl): Boolean;
var
  Now: Longword;
  Speed: Double;
  Received: Int64;
  CurrentMax: Int64;
begin
  Result := True;

  Now := CncnetGetTickCount();

  // A new file (or a retry) starts with a lower byte count; restart the speed clocks
  // and, for adopted totals, drop the previous file's total.
  if Progress < L.LastBytes then
  begin
    L.LastBytes := 0;
    L.FileStartTick := Now;
    L.LastSpeedTick := Now;
    // Clear only an adopted total; a total given up front survives file retries.
    if L.TotalAdopted then
    begin
      L.SessionTotal := 0;
      L.OverallBar.Visible := False;
      L.TotalValueLabel.Caption := 'Unknown';
      L.TotalAdopted := False;
    end;
  end;
  L.LastBytes := Progress;

  // The engine writes the "File:" row itself; update the other rows here.
  Received := L.BytesBase + Progress;
  if ProgressMax > 0 then
    CurrentMax := ProgressMax
  else
    CurrentMax := L.CurrentFileSize;

  // The overall bar needs a session total: the movie page gets it from CncnetDlPrepareProgressEx;
  // the dependency page adopts each file's size from the engine (it downloads one file at a time).
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

  // Speed and remaining time, refreshed at most once a second (keeps the rows from flickering).
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
      // Remaining: the session's remaining bytes at this average speed (bytes / bytes-per-second = seconds).
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

// Progress callback for CncnetDl (the fixed signature CreateDownloadPage requires).
function CncnetDlProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  Result := CncnetDlProgressEx(Url, FileName, Progress, ProgressMax, CncnetDl);
end;

// Progress callback for CncnetDep (the dependency page).
function CncnetDepProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  Result := CncnetDlProgressEx(Url, FileName, Progress, ProgressMax, CncnetDep);
end;

// Sizes the overall bar and resets the per-row state before a download (or the next file) starts.
procedure CncnetDlPrepareProgressEx(var L: TCncnetDl; const BaseBytes, TotalBytes, FileSize: Int64);
begin
  L.BytesBase := BaseBytes;
  L.SessionTotal := TotalBytes;
  L.CurrentFileSize := FileSize;
  L.LastBytes := 0;
  // A given total is never "adopted" (it must survive file retries).
  L.TotalAdopted := False;
  L.FileStartTick := CncnetGetTickCount();
  L.LastSpeedTick := CncnetGetTickCount();
  if BaseBytes = 0 then
    L.SessionStartTick := CncnetGetTickCount();

  if TotalBytes > 0 then
  begin
    // The bar's Max is 32-bit; above the limit, scale to MB.
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
    // Unknown session total: the bar cannot be sized; mark the total as unknown.
    L.OverallBar.Visible := False;
    L.TotalValueLabel.Caption := 'Unknown';
  end;

  L.CurrentValueLabel.Caption := CncnetDlFormatSizeOf(0, FileSize);
  L.SpeedValueLabel.Caption := '-';
  L.StatusValueLabel.Caption := 'Starting...';
  L.ElapsedValueLabel.Caption := CncnetDlFormatTime(0);
  L.RemainingValueLabel.Caption := '-';
end;

// Wait while pumping window messages (Inno's Sleep alone would freeze the wizard):
// TDownloadWizardPage.SetText runs ProcessMessages while this page is current.
// Do not swap in a user32 pump - newer Windows no longer export TranslateMessageA/W.
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

// Downloads one file to the temp dir on the download page (per-file bar + Stop button),
// retrying transient failures with backoff; afterwards the user can abort, retry or ignore.
// Returns True when the file is in the temp dir, or when the user chose to ignore the failure.
function CncnetDlDownloadFileEx(var L: TCncnetDl; const Url, Filename, Title: String; const BaseBytes, TotalBytes, FileSize: Int64): Boolean;
var
  Attempt: Integer;
  Retry: Boolean;
begin
  Result := True;
  CncnetDlPrepareProgressEx(L, BaseBytes, TotalBytes, FileSize);
  L.Page.Clear;
  L.Page.Add(Url, Filename, '');
  // Prefill the "File:" row (the engine also writes it on the first tick).
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

// Queues one download; SizeKB = 0 shows "Unknown", Title '' = "<file> (n of m)".
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

// Downloads the whole queue (per-file bar + overall bar). Shows and hides the page. Returns False on abort.
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
// Title/description as labels (the page's own never render under ISTheme),
// then File/Speed/Status/Elapsed/Remaining rows + overall/per-file bars + Stop.
// Repurposed: Msg1Label hidden, Msg2Label = "File:" value, ProgressBar = per-file bar, AbortButton = Stop.
procedure CncnetDlBuildLayout(const Page: TDownloadWizardPage; const Title, Description: String; var L: TCncnetDl);
var
  SurfaceWidth, SurfaceHeight, C: Integer;
  RowHeight, BarHeight, InfoCaptionWidth, ValueColumn, RightMargin, ValueBoxWidth: Integer;
begin
  // Guard against laying out the same page/instance twice.
  if L.Started then
    Exit;
  L.Page := Page;

  // Per-session defaults; CncnetDlPrepareProgressEx re-sets most of these before each download.
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

  // Content block top: below the title, and below the description when it fits (the block is 207px tall).
  C := ScaleY(14) + ScaleY(16);
  L.DescriptionLabel.Visible := SurfaceHeight >= C + ScaleY(28 + 16 + 207);
  if L.DescriptionLabel.Visible then
    C := C + ScaleY(28 + 16);

  // "Total progress" row: caption + the value right-aligned in a 160-wide box.
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
  // Initial value; CncnetDlPrepareProgressEx or the engine's first sized tick overwrites it.
  L.TotalValueLabel.Caption := 'Unknown';

  // Overall (all-files) bar; hidden until a session total becomes known (see CncnetDlProgressEx).
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

  // "File:" row: caption + the built-in Msg2Label as the value (the engine writes it on each tick).
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

  // Speed / Status / Elapsed / Remaining rows: caption at x=0, value in the x=120 column.
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

  // Stop button (the page's AbortButton), right-aligned.
  Page.AbortButton.Left := SurfaceWidth - RightMargin - Page.AbortButton.Width;
  Page.AbortButton.Top := C + ScaleY(184);
  Page.AbortButton.Height := ScaleY(23);

  L.Started := True;
end;

// Creates the generic download page (per-file bar + Stop button) and applies the layout to CncnetDl.
// Call from InitializeWizard (after ISTheme()); ShowBaseNameInsteadOfUrl puts the file name in the "File:" row.
procedure CncnetSetupDownloadPage(const Title, Description: String);
begin
  CncnetDl.Page := CreateDownloadPage(Title, Description, @CncnetDlProgress);
  CncnetDl.Page.ShowBaseNameInsteadOfUrl := True;
  CncnetDlBuildLayout(CncnetDl.Page, Title, Description, CncnetDl);
end;

// Same layout for the InnoDependencyInstaller dependency page, via CncnetDep; the library reads the
// Dependency_DownloadPage global, so recreating it here is picked up. Requires libs/InnoDependencyInstaller/
// CodeDependencies.iss included first; call from InitializeWizard (after ISTheme()).
procedure CncnetSetupDependencyDownloadPage(const Title, Description: String);
begin
  Dependency_DownloadPage := CreateDownloadPage(Title, Description, @CncnetDepProgress);
  Dependency_DownloadPage.ShowBaseNameInsteadOfUrl := True;
  CncnetDep.Page := Dependency_DownloadPage;
  CncnetDlBuildLayout(Dependency_DownloadPage, Title, Description, CncnetDep);
end;
