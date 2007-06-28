unit Prefs;
{
    Copyright 2001, Peter Millard

    This file is part of Exodus.

    Exodus is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Exodus is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Exodus; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

interface

uses
    // panels
    PrefPanel, PrefSystem, PrefRoster, PrefSubscription, PrefFont, PrefDialogs,
    PrefMsg, PrefNotify, PrefAway, PrefPresence, PrefPlugins, PrefTransfer,
    PrefNetwork, PrefGroups, PrefLayouts,       

    // other stuff
    Menus, ShellAPI, Unicode,
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    ComCtrls, StdCtrls, ExtCtrls, buttonFrame, CheckLst,
    ExRichEdit, Dialogs, RichEdit2, TntStdCtrls, TntComCtrls, TntExtCtrls;

type
  TfrmPrefs = class(TForm)
    Scroller: TScrollBox;
    imgDialog: TImage;
    lblDialog: TTntLabel;
    imgFonts: TImage;
    lblFonts: TTntLabel;
    imgS10n: TImage;
    lblS10n: TTntLabel;
    imgRoster: TImage;
    lblRoster: TTntLabel;
    PageControl1: TTntPageControl;
    ColorDialog1: TColorDialog;
    imgSystem: TImage;
    lblSystem: TTntLabel;
    imgNotify: TImage;
    lblNotify: TTntLabel;
    imgAway: TImage;
    lblAway: TTntLabel;
    tbsKeywords: TTntTabSheet;
    memKeywords: TTntMemo;
    tbsBlockList: TTntTabSheet;
    memBlocks: TTntMemo;
    imgKeywords: TImage;
    lblKeywords: TTntLabel;
    imgBlockList: TImage;
    lblBlockList: TTntLabel;
    imgCustompres: TImage;
    lblCustomPres: TTntLabel;
    Panel1: TPanel;
    Panel3: TPanel;
    btnOK: TTntButton;
    btnCancel: TTntButton;
    Button6: TTntButton;
    Panel2: TPanel;
    Label1: TTntLabel;
    chkRegex: TTntCheckBox;
    imgMessages: TImage;
    lblMessages: TTntLabel;
    imgPlugins: TImage;
    lblPlugins: TTntLabel;
    imgNetwork: TImage;
    imgTransfer: TImage;
    lblTransfer: TTntLabel;
    Bevel1: TBevel;
    imgGroups: TImage;
    lblGroups: TTntLabel;
    imgLayouts: TImage;
    lblLayouts: TTntLabel;
    Memo1: TTntMemo;
    pnlBlocked: TTntPanel;
    pnlKeyword: TTntPanel;
    Shape1: TShape;
    Shape2: TShape;
    lblNetwork: TTntLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure TabSelect(Sender: TObject);
    procedure frameButtons1btnOKClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure imgSystemMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure OffBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    _cur_panel: TfrmPrefPanel;
    _cur_label: TTntLabel;
    _system: TfrmPrefSystem;
    _roster: TfrmPrefRoster;
    _groups: TfrmPrefGroups;
    _subscription: TfrmPrefSubscription;
    _font: TfrmPrefFont;
    _dialogs: TfrmPrefDialogs;
    _message: TfrmPrefMsg;
    _notify: TfrmPrefNotify;
    _away: TfrmPrefAway;
    _pres: TfrmPrefPresence;
    _plugs: TfrmPrefPlugins;
    _xfer: TfrmPrefTransfer;
    _network: TfrmPrefNetwork;
    _layouts: TfrmPrefLayouts;
    
  public
    { Public declarations }
    procedure LoadPrefs;
    procedure SavePrefs;
  end;

var
  frmPrefs: TfrmPrefs;

procedure StartPrefs;

{---------------------------------------}
{---------------------------------------}
{---------------------------------------}
implementation

{$R *.DFM}
{$WARN UNIT_PLATFORM OFF}

uses
    GnuGetText, PrefController, Session, ExUtils;

{---------------------------------------}
procedure StartPrefs;
var
    f: TfrmPrefs;
begin
    f := TfrmPrefs.Create(Application);
    f.LoadPrefs;
    // frmExodus.PreModal(f);
    f.ShowModal;
    //frmExodus.PostModal();
    f.Free();
end;

{---------------------------------------}
procedure TfrmPrefs.LoadPrefs;
begin
    // load prefs from the reg.
    with MainSession.Prefs do begin

        // Keywords and Blockers
        fillStringList('keywords', memKeywords.Lines);
        chkRegex.Checked := getBool('regex_keywords');
        fillStringList('blockers', memBlocks.Lines);
   end;
end;


{---------------------------------------}
procedure TfrmPrefs.SavePrefs;
begin
    // save prefs to the reg
    with MainSession.Prefs do begin
        BeginUpdate();

        // Iterate over all the panels we have
        if (_roster <> nil) then
            _roster.SavePrefs();

        if (_groups <> nil) then
            _groups.SavePrefs();

        if (_system <> nil) then
            _system.SavePrefs();

        if (_subscription <> nil) then
            _subscription.SavePrefs();

        if (_font <> nil) then
            _font.SavePrefs();

        if (_dialogs <> nil) then
            _dialogs.SavePrefs();

        if (_layouts <> nil) then
            _layouts.SavePrefs();

        if (_message <> nil) then
            _message.SavePrefs();

        if (_notify <> nil) then
            _notify.SavePrefs();

        if (_away <> nil) then
            _away.SavePrefs();

        if (_pres <> nil) then
            _pres.SavePrefs();

        if (_plugs <> nil) then
            _plugs.SavePrefs();

        if (_xfer <> nil) then
            _xfer.SavePrefs();

        if (_network <> nil) then
            _network.SavePrefs();

        // Keywords
        setStringList('keywords', memKeywords.Lines);
        setBool('regex_keywords', chkRegex.Checked);
        setStringList('blockers', memBlocks.Lines);

        endUpdate();
    end;
    MainSession.FireEvent('/session/prefs', nil);
end;

{---------------------------------------}
procedure TfrmPrefs.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    MainSession.Prefs.SavePosition(Self);
    Action := caFree;
end;

{---------------------------------------}
procedure TfrmPrefs.FormCreate(Sender: TObject);
begin
    // Setup some fonts
    AssignUnicodeFont(Self);
    AssignUnicodeFont(memKeywords.Font, 10);
    AssignUnicodeFont(memBlocks.Font, 10);

    // Our panels..
    AssignUnicodeHighlight(pnlKeyword.Font, 10);
    AssignUnicodeHighlight(pnlBlocked.Font, 10);

    TranslateComponent(Self);

    tbsKeywords.TabVisible := false;
    tbsBlockList.TabVisible := false;

    // Load the system panel
    _system := nil;
    _cur_panel := nil;

    // branding
    with (MainSession.Prefs) do begin
        imgTransfer.Visible := getBool('brand_ft');
        lblTransfer.Visible := getBool('brand_ft');
        imgPlugins.Visible := getBool('brand_plugs');
        lblPlugins.Visible := getBool('brand_plugs');
    end;

    // Init all the other panels
    _roster := nil;
    _groups := nil;
    _subscription := nil;
    _font := nil;
    _dialogs := nil;
    _layouts := nil;
    _message := nil;
    _notify := nil;
    _away := nil;
    _pres := nil;
    _plugs := nil;
    _xfer := nil;
    _network := nil;

    MainSession.Prefs.RestorePosition(Self);

    with Shape1 do begin
        Left := 1;
        Top := 1;
        Width := imgSystem.Width - 1;
    end;
    with Shape2 do begin
        Left := 1;
        Width := Shape1.Width;
        Visible := false;
    end;

end;

{---------------------------------------}
procedure TfrmPrefs.TabSelect(Sender: TObject);

    procedure toggleSelector(lbl: TTntLabel);
    var
        i: integer;
        c: TControl;
    begin
        for i := 0 to Scroller.ControlCount - 1 do begin
            c := Scroller.Controls[i];
            if (c is TTntLabel) then begin
                if (c = lbl) then begin
                    // left, top, width, height
                    Shape1.SetBounds(1, c.Top - imgSystem.Height - 2,
                        Scroller.ClientWidth - 2,
                        c.Height + imgSystem.Height - 1);
                    TTntLabel(c).Font.Color := clMenuText;
                    _cur_label := TTntLabel(c);
                end
                else begin
                    TTntLabel(c).Font.Color := clWindowText;
                end;
            end;
        end;
        Self.Scroller.Repaint();
    end;


var
    f: TfrmPrefPanel;
begin
    Shape2.Visible := false;
    f := nil;
    if ((Sender = imgSystem) or (Sender = lblSystem)) then begin
        toggleSelector(lblSystem);
        if (_system <> nil) then
            f := _system
        else begin
            _system := TfrmPrefSystem.Create(Self);
            f := _system;
        end;
    end
    else if ((Sender = imgRoster) or (Sender = lblRoster)) then begin
        toggleSelector(lblRoster);
        if (_roster <> nil) then
            f := _roster
        else begin
            _roster := TfrmPrefRoster.Create(Self);
            f := _roster;
        end;
    end
    else if ((Sender = imgGroups) or (Sender = lblGroups)) then begin
        toggleSelector(lblGroups);
        if (_groups <> nil) then
            f := _groups
        else begin
            _groups := TfrmPrefGroups.Create(Self);
            f := _groups;
        end;
    end
    else if ((Sender = imgS10n) or (Sender = lblS10n)) then begin
        toggleSelector(lblS10n);
        if (_subscription <> nil) then
            f := _subscription
        else begin
            _subscription := TfrmPrefSubscription.Create(Self);
            f := _subscription;
        end;
    end
    else if ((Sender = imgFonts) or (Sender = lblFonts)) then begin
        toggleSelector(lblFonts);
        if (_font <> nil) then
            f := _font
        else begin
            _font := TfrmPrefFont.Create(Self);
            f := _font;
        end;
    end
    else if ((Sender = imgDialog) or (Sender = lblDialog)) then begin
        toggleSelector(lblDialog);
        if (_dialogs <> nil) then
            f := _dialogs
        else begin
            _dialogs := TfrmPrefDialogs.Create(Self);
            f := _dialogs;
        end;
    end
    else if ((Sender = imgLayouts) or (Sender = lblLayouts)) then begin
        toggleSelector(lblLayouts);
        if (_layouts <> nil) then
            f := _layouts
        else begin
            _layouts := TfrmPrefLayouts.Create(Self);
            f := _layouts;
        end;
    end
    else if ((Sender = imgMessages) or (Sender = lblMessages)) then begin
        toggleSelector(lblMessages);
        if (_message <> nil) then
            f := _message
        else begin
            _message := TfrmPrefMsg.Create(Self);
            f := _message;
        end;
    end
    else if ((Sender = imgNotify) or (Sender = lblNotify)) then begin
        toggleSelector(lblNotify);
        if (_notify <> nil) then
            f := _notify
        else begin
            _notify := TfrmPrefNotify.Create(Self);
            f := _notify;
        end;
    end
    else if ((Sender = imgAway) or (Sender = lblAway)) then begin
        toggleSelector(lblAway);
        if (_away <> nil) then
            f := _away
        else begin
            _away := TfrmPrefAway.Create(Self);
            f := _away;
        end;
    end
    else if ((Sender = imgCustompres) or (Sender = lblCustomPres)) then begin
        toggleSelector(lblCustompres);
        if (_pres <> nil) then
            f := _pres
        else begin
            _pres := TfrmPrefPresence.Create(Self);
            f := _pres;
        end;
    end
    else if ((Sender = imgPlugins) or (Sender = lblPlugins)) then begin
        toggleSelector(lblPlugins);
        if (_plugs <> nil) then
            f := _plugs
        else begin
            _plugs := TfrmPrefPlugins.Create(Self);
            f := _plugs;
        end;
    end
    else if ((Sender = imgTransfer) or (Sender = lblTransfer)) then begin
        toggleSelector(lblTransfer);
        if (_xfer <> nil) then
            f := _xfer
        else begin
            _xfer := TfrmPrefTransfer.Create(Self);
            f := _xfer;
        end;
    end
    else if ((Sender = imgNetwork) or (Sender = lblNetwork)) then begin
        toggleSelector(lblNetwork);
        if (_network <> nil) then
            f := _network
        else begin
            _network := TfrmPrefNetwork.Create(Self);
            f := _network;
        end;
    end
    else if ((Sender = imgKeywords) or (Sender = lblKeywords)) then begin
        PageControl1.ActivePage := tbsKeywords;
        toggleSelector(lblKeywords);
    end
    else if ((Sender = imgBlockList) or (Sender = lblBlockList)) then begin
        PageControl1.ActivePage := tbsBlockList;
        toggleSelector(lblBlocklist);
    end
    else
        exit;

    // setup the panel..
    if (f <> nil) then begin
        if PageControl1.Visible then
            PageControl1.Visible := false;
        f.Parent := Self;
        f.Align := alClient;
        f.Visible := true;
        f.BringToFront();
        _cur_panel := f;
    end
    else begin
        if (not PageControl1.Visible) then
            PageControl1.Visible := true;
        PageControl1.BringToFront();
    end;
end;

{---------------------------------------}
procedure TfrmPrefs.frameButtons1btnOKClick(Sender: TObject);
begin
    SavePrefs;
    Self.BringToFront();
end;

{---------------------------------------}
procedure TfrmPrefs.FormDestroy(Sender: TObject);
begin
    // destroy all panels we have..
    _system.Free();
    _roster.Free();
    _groups.Free();
    _subscription.Free();
    _font.Free();
    _dialogs.Free();
    _message.Free();
    _notify.Free();
    _away.Free();
    _pres.Free();
    _plugs.Free();
    _xfer.Free();
    _network.Free();
end;

{---------------------------------------}
procedure TfrmPrefs.imgSystemMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
    // We are moving over one of the images..
    // Move shape2 to highlight.

    (*
    if ((Sender = imgSystem) or (Sender = lblSystem) and
        (_cur_label <> lblSystem)) then begin
        Shape2.Top := lblSystem.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgRoster) or (Sender = lblRoster) and
        (_cur_label <> lblRoster)) then begin
        Shape2.Top := lblRoster.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgGroups) or (Sender = lblGroups) and
        (_cur_label <> lblGroups)) then begin
        Shape2.Top := lblGroups.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgS10n) or (Sender = lblS10n) and
        (_cur_label <> lblS10n)) then begin
        Shape2.Top := lblS10n.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgFonts) or (Sender = lblFonts) and
        (_cur_label <> lblFonts)) then begin
        Shape2.Top := lblFonts.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgDialog) or (Sender = lblDialog) and
        (_cur_label <> lblDialog)) then begin
        Shape2.Top := lblDialog.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgLayouts) or (Sender = lblLayouts) and
        (_cur_label <> lblLayouts)) then begin
        Shape2.Top := lblLayouts.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgMessages) or (Sender = lblMessages) and
        (_cur_label <> lblMessages)) then begin
        Shape2.Top := lblMessages.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgNotify) or (Sender = lblNotify) and
        (_cur_label <> lblNotify)) then begin
        Shape2.Top := lblNotify.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgAway) or (Sender = lblAway) and
        (_cur_label <> lblAway)) then begin
        Shape2.Top := lblAway.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgCustompres) or (Sender = lblCustomPres) and
        (_cur_label <> lblCustomPres)) then begin
        Shape2.Top := lblCustomPres.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgPlugins) or (Sender = lblPlugins) and
        (_cur_label <> lblPlugins)) then begin
        Shape2.Top := lblPlugins.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgTransfer) or (Sender = lblTransfer) and
        (_cur_label <> lblTransfer)) then begin
        Shape2.Top := lblTransfer.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgNetwork) or (Sender = lblNetwork) and
        (_cur_label <> lblNetwork)) then begin
        Shape2.Top := lblNetwork.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgKeywords) or (Sender = lblBlockList) and
        (_cur_label <> lblBlockList)) then begin
        Shape2.Top := lblBlockList.Top - 40;
        Shape2.Visible := true;
    end
    else if ((Sender = imgBlockList) or (Sender = lblBlockList) and
        (_cur_label <> lblBlockList)) then begin
        Shape2.Top := lblBlockList.Top - 40;
        Shape2.Visible := true;
    end
    else
        Shape2.Visible := false;
    *)

end;

{---------------------------------------}
procedure TfrmPrefs.OffBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
    Shape2.Visible := false;
end;

{---------------------------------------}
procedure TfrmPrefs.FormShow(Sender: TObject);
var
    i: integer;
    c: TControl;
    cap: Widestring;
begin
    for i := 0 to Scroller.ControlCount - 1 do begin
        c := Scroller.Controls[i];
        if (c is TTntLabel) then with TTntLabel(c) do begin
            AutoSize := false;
            Height := 20;
            cap := Caption;
            Caption := WideTrim(cap);
            AutoSize := true;
            AutoSize := false;
            Height := Height + 4;
        end;
    end;

    TabSelect(lblSystem);
    _cur_label := lblSystem;

end;

end.
