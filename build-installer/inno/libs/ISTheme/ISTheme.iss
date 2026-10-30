// Palette and size defaults (shared by all games); each value is #ifndef-guarded so a
// template can #define its own BEFORE including this file.
// #include'd from inside a [Code] section: only Pascal-style (//) comments are allowed here.
#ifndef ISThemeBackgroundWidth
  #define ISThemeBackgroundWidth = '640'
#endif
#ifndef ISThemeBackgroundHeight
  #define ISThemeBackgroundHeight = '480'
#endif
#ifndef ISThemeBackColor
  #define ISThemeBackColor = '$000000'
#endif
#ifndef ISThemeForeColor
  #define ISThemeForeColor = '$FFF4E8'
#endif
#ifndef ISThemeTextBoxBackColor
  #define ISThemeTextBoxBackColor = '$FFFFFF'
#endif
#ifndef ISThemeTextBoxForeColor
  #define ISThemeTextBoxForeColor = '$000000'
#endif

[Code]
procedure ReplaceLabel(sourceLabel: TNewStaticText);
var
  newLabel: TLabel;
begin
  newLabel := TLabel.Create(WizardForm);
  newLabel.Parent := sourceLabel.Parent;
  newLabel.Font := sourceLabel.Font;
  newLabel.Caption := sourceLabel.Caption;
  newLabel.WordWrap := sourceLabel.WordWrap;
  newLabel.Left := sourceLabel.Left;
  newLabel.Top := sourceLabel.Top;
  newLabel.Width := sourceLabel.Width;
  newLabel.Height := sourceLabel.Height;
  newLabel.Visible := sourceLabel.Visible;
  newLabel.Transparent := True;
  
  sourceLabel.Visible := false;
end;

procedure SetPageBackground(page: TNewNotebookPage; fileName: string);
var
  BackgroundBmp: TBitmapImage;
begin
  BackgroundBmp := TBitmapImage.Create(WizardForm);
  BackgroundBmp.Bitmap.LoadFromFile(ExpandConstant('{tmp}\') + fileName);
  BackgroundBmp.Stretch := True;
  BackgroundBmp.Align := alClient;
  BackgroundBmp.Parent := page;
end;
  
procedure ISTheme();
var
  BackgroundBmp: TBitmapImage;
  WelcomePageNotebook: TNewNotebook; 
begin
  //### resize and align ###
  WizardForm.Left := WizardForm.Left - ((ScaleX({#ISThemeBackgroundWidth}) - WizardForm.ClientWidth) / 2);
  WizardForm.Top := WizardForm.Top - ((ScaleY({#ISThemeBackgroundHeight}) - WizardForm.ClientHeight) / 2);
  WizardForm.ClientWidth := ScaleX({#ISThemeBackgroundWidth});
  WizardForm.ClientHeight := ScaleY({#ISThemeBackgroundHeight});
  WizardForm.OuterNotebook.Width := 498
  WizardForm.OuterNotebook.Height := 312
  WizardForm.OuterNotebook.Left := (WizardForm.ClientWidth / 2) - (WizardForm.OuterNotebook.Width / 2);
  WizardForm.OuterNotebook.Top := (WizardForm.ClientHeight / 2) - (WizardForm.OuterNotebook.Height / 2) - (WizardForm.InnerNotebook.Top / 2);
  WizardForm.CancelButton.Left := WizardForm.OuterNotebook.Left + WizardForm.InnerNotebook.Width + WizardForm.InnerNotebook.Left - WizardForm.CancelButton.Width;
  WizardForm.CancelButton.Top := WizardForm.OuterNotebook.Top + WizardForm.InnerNotebook.Height + WizardForm.InnerNotebook.Top + ScaleY(10);
  WizardForm.NextButton.Left := WizardForm.CancelButton.Left - WizardForm.NextButton.Width - ScaleX(10);
  WizardForm.NextButton.Top := WizardForm.CancelButton.Top;
  WizardForm.BackButton.Left := WizardForm.NextButton.Left - WizardForm.BackButton.Width;
  WizardForm.BackButton.Top := WizardForm.CancelButton.Top;
  WizardForm.FinishedLabel.Left := WizardForm.InnerNotebook.Left;
  WizardForm.FinishedLabel.Width := WizardForm.InnerNotebook.Width;
  WizardForm.FinishedLabel.Height := WizardForm.InnerNotebook.Height;
  WizardForm.RunList.Left := WizardForm.InnerNotebook.Left;
  WizardForm.RunList.Width := WizardForm.InnerNotebook.Width;
  WizardForm.RunList.Height := WizardForm.InnerNotebook.Height;
  
  //# welcome page #
  WelcomePageNotebook := TNewNotebook.Create(WizardForm);
  WelcomePageNotebook.Parent := WizardForm.WelcomePage;
  WelcomePageNotebook.Top := WizardForm.InnerNotebook.Top;
  WelcomePageNotebook.Left := WizardForm.InnerNotebook.Left;
  WelcomePageNotebook.Width := WizardForm.InnerNotebook.Width;
  WelcomePageNotebook.Height := WizardForm.InnerNotebook.Height;
  WizardForm.WelcomeLabel1.Parent := WelcomePageNotebook;
  WizardForm.WelcomeLabel1.Top := 0;
  WizardForm.WelcomeLabel1.Left := 0;
  WizardForm.WelcomeLabel1.Width := WizardForm.InnerNotebook.Width;
  WizardForm.WelcomeLabel2.Parent := WelcomePageNotebook;
  WizardForm.WelcomeLabel2.Top := WizardForm.WelcomeLabel1.Height;
  WizardForm.WelcomeLabel2.Left := 0;
  WizardForm.WelcomeLabel2.Width := WizardForm.InnerNotebook.Width;
  WizardForm.WelcomeLabel2.Height := WizardForm.InnerNotebook.Height - WizardForm.WelcomeLabel1.Height;

  //### set backgrounds ###
  ExtractTemporaryFile('WizardFormBackground.bmp');
  ExtractTemporaryFile('InnerPageBackground.bmp');
  ExtractTemporaryFile('PageBackground.bmp');
  
  SetPageBackground(WizardForm.WelcomePage ,'InnerPageBackground.bmp');
  SetPageBackground(WizardForm.InnerPage ,'InnerPageBackground.bmp');
  SetPageBackground(WizardForm.FinishedPage ,'InnerPageBackground.bmp');
  SetPageBackground(WizardForm.LicensePage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.PasswordPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.InfoBeforePage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.UserInfoPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.SelectDirPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.SelectComponentsPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.SelectProgramGroupPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.SelectTasksPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.ReadyPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.PreparingPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.InstallingPage ,'PageBackground.bmp');
  SetPageBackground(WizardForm.InfoAfterPage ,'PageBackground.bmp');
  
  BackgroundBmp := TBitmapImage.Create(WizardForm);
  BackgroundBmp.Bitmap.LoadFromFile(ExpandConstant('{tmp}\PageBackground.bmp'));
  BackgroundBmp.Stretch := True;
  BackgroundBmp.Align := alClient;
  BackgroundBmp.Parent:= WelcomePageNotebook;
  
  BackgroundBmp := TBitmapImage.Create(WizardForm);
  BackgroundBmp.Bitmap.LoadFromFile(ExpandConstant('{tmp}\WizardFormBackground.bmp'));
  BackgroundBmp.Stretch := True;
  BackgroundBmp.Align := alClient;
  BackgroundBmp.Parent:= WizardForm;

  //### hide unwanted stuff ###
  WizardForm.FinishedHeadingLabel.Visible := False;
  WizardForm.Bevel1.Visible := false;
  WizardForm.Bevel.Visible := false;
  WizardForm.MainPanel.Visible := false;
  WizardForm.SelectDirBitmapImage.Visible := False;
  WizardForm.SelectGroupBitmapImage.Visible := False;
  WizardForm.WizardSmallBitmapImage.Visible := false;
  WizardForm.WizardBitmapImage.Visible := false;
  //WizardForm.NoIconsCheck.Visible := false;
  
  //### color text ###
  WizardForm.Font.Color := {#ISThemeForeColor};
  WizardForm.WelcomeLabel1.Font.Color := {#ISThemeForeColor};
  WizardForm.PageNameLabel.Font.Color := {#ISThemeForeColor}; 
  WizardForm.FinishedLabel.Font.Color := {#ISThemeForeColor};
  WizardForm.FinishedHeadingLabel.Font.Color := {#ISThemeForeColor};
  WizardForm.ComponentsList.Font.Color := {#ISThemeForeColor};
  WizardForm.TypesCombo.Font.Color := {#ISThemeForeColor};
  WizardForm.NoIconsCheck.Font.Color := {#ISThemeForeColor};

  // Install page labels sit on the dark page artwork: use the theme fore color,
  // and keep the ReplaceLabel lines below commented out for these two.
  WizardForm.StatusLabel.Font.Color := {#ISThemeForeColor};
  WizardForm.FilenameLabel.Font.Color := {#ISThemeForeColor};
  // The license memo follows the page theme (dark + cream), not the textbox palette.
  WizardForm.LicenseMemo.Font.Color := {#ISThemeForeColor};

  WizardForm.GroupEdit.font.Color := {#ISThemeTextBoxForeColor};
  WizardForm.DirEdit.font.Color := {#ISThemeTextBoxForeColor};
  WizardForm.InfoBeforeMemo.Font.Color := {#ISThemeTextBoxForeColor}; 
  WizardForm.ReadyMemo.Font.Color := {#ISThemeTextBoxForeColor};
  WizardForm.InfoAfterMemo.Font.Color := {#ISThemeTextBoxForeColor};
  
  //### color backgrounds ###
  WizardForm.MainPanel.Color := {#ISThemeBackColor};
  WizardForm.WelcomePage.Color := {#ISThemeBackColor}; 
  WizardForm.Color := {#ISThemeBackColor}; 
  WizardForm.InnerPage.Color := {#ISThemeBackColor}; 
  WizardForm.SelectDirPage.Color := {#ISThemeBackColor}; 
  WizardForm.TasksList.Color := {#ISThemeBackColor};
  WizardForm.TypesCombo.Color := {#ISThemeBackColor};
  WizardForm.ComponentsList.Color := {#ISThemeBackColor};
  WizardForm.FinishedPage.Color := {#ISThemeBackColor};
  WizardForm.LicenseMemo.Color := {#ISThemeBackColor};
  
  // FinishedLabel/RunList are opaque windows over the finished page: use clNone
  // (Transparent is a no-op on these) so the page background image shows through.
  WizardForm.FinishedLabel.Color := clNone;
  WizardForm.RunList.Color := clNone;

  WizardForm.GroupEdit.Color := {#ISThemeTextBoxBackColor};
  WizardForm.DirEdit.Color := {#ISThemeTextBoxBackColor};
  WizardForm.InfoAfterMemo.Color := {#ISThemeTextBoxBackColor};
  WizardForm.ReadyMemo.Color := {#ISThemeTextBoxBackColor};
  WizardForm.InfoBeforeMemo.Color := {#ISThemeTextBoxBackColor};
  
  //### bold textbox font ###
  WizardForm.InfoAfterMemo.Font.Style := [fsBold];
  WizardForm.InfoBeforeMemo.Font.Style := [fsBold];
  WizardForm.ReadyMemo.Font.Style := [fsBold];
  WizardForm.LicenseMemo.Font.Style := [fsBold];

  //### disable border ###
  WizardForm.ReadyMemo.BorderStyle := bsNone;
  WizardForm.InfoAfterMemo.BorderStyle := bsNone;
  WizardForm.ComponentsList.BorderStyle := bsNone;
  //WizardForm.DirEdit.BorderStyle := bsNone;
  //WizardForm.GroupEdit.BorderStyle := bsNone;
  WizardForm.UserInfoNameEdit.BorderStyle := bsNone;
  WizardForm.UserInfoOrgEdit.BorderStyle := bsNone;
  WizardForm.UserInfoSerialEdit.BorderStyle := bsNone;
  WizardForm.InfoBeforeMemo.BorderStyle := bsNone;
  WizardForm.LicenseMemo.BorderStyle := bsNone;
   
  //### Transparent labels ###
  ReplaceLabel(WizardForm.DiskSpaceLabel);
  ReplaceLabel(WizardForm.PasswordLabel);
  ReplaceLabel(WizardForm.PasswordEditLabel);
  ReplaceLabel(WizardForm.WelcomeLabel1);
  ReplaceLabel(WizardForm.InfoBeforeClickLabel);
  ReplaceLabel(WizardForm.PageNameLabel);
  ReplaceLabel(WizardForm.PageDescriptionLabel);
  //ReplaceLabel(WizardForm.ReadyLabel);
  //ReplaceLabel(WizardForm.FinishedLabel);
  ReplaceLabel(WizardForm.WelcomeLabel2);
  ReplaceLabel(WizardForm.LicenseLabel1);
  ReplaceLabel(WizardForm.InfoAfterClickLabel);
  ReplaceLabel(WizardForm.ComponentsDiskSpaceLabel);
  ReplaceLabel(WizardForm.BeveledLabel);
  //ReplaceLabel(WizardForm.StatusLabel);
  //ReplaceLabel(WizardForm.FilenameLabel);
  ReplaceLabel(WizardForm.SelectDirLabel);
  ReplaceLabel(WizardForm.SelectStartMenuFolderLabel);
  ReplaceLabel(WizardForm.SelectComponentsLabel);
  ReplaceLabel(WizardForm.SelectTasksLabel);
  ReplaceLabel(WizardForm.UserInfoNameLabel);
  ReplaceLabel(WizardForm.UserInfoOrgLabel);
  ReplaceLabel(WizardForm.PreparingLabel);
  ReplaceLabel(WizardForm.FinishedHeadingLabel);
  ReplaceLabel(WizardForm.UserInfoSerialLabel);
  ReplaceLabel(WizardForm.SelectDirBrowseLabel);
  ReplaceLabel(WizardForm.SelectStartMenuFolderBrowseLabel);
  
  //### No RichEdit ###
  WizardForm.InfoBeforeMemo.UseRichEdit := false;
  WizardForm.LicenseMemo.UseRichEdit := false;
  WizardForm.InfoAfterMemo.UseRichEdit := false;
  WizardForm.LicenseMemo.UseRichEdit := false;
end;

// Dir-page double-Next guard: veto one rapid second Next (double-click / key
// repeat) before it flashes past the page and starts the install. Never veto
// when WizardSilent (a False aborts unattended installs); return True when not vetoing.

var
  ISThemeDirPageEnterTick: Longword;

function ISThemeGetTickCount(): Longword;
  external 'GetTickCount@kernel32.dll stdcall';

<event('CurPageChanged')>
procedure ISThemeTrackDirPage(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
    ISThemeDirPageEnterTick := ISThemeGetTickCount();
end;

<event('NextButtonClick')>
function ISThemeDirPageNextGuard(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpSelectDir)
    and not WizardSilent
    and (ISThemeDirPageEnterTick <> 0)
    and ((ISThemeGetTickCount() - ISThemeDirPageEnterTick) < 1500) then
  begin
    Log('ISTheme: swallowed a rapid Next on the dir page (' +
      IntToStr(ISThemeGetTickCount() - ISThemeDirPageEnterTick) + ' ms after page entry)');
    Result := False;
  end;
end;
