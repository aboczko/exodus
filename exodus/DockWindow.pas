unit DockWindow;

{
    Copyright 2003, Peter Millard

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
  Windows, Messages, SysUtils,
  Variants, Classes, Graphics,
  Controls, Forms, Dialogs,
  ExForm, Dockable, TntComCtrls,
  ComCtrls, ExtCtrls, TntExtCtrls,
  ExodusDockManager, StdCtrls,
  ExGradientPanel, AWItem, Unicode,
  StateForm;

type

  TSortState = (ssUnsorted, ssAlpha, ssRecent, ssType, ssUnread);
  TGlueEdge = (geNone, geTop, geRight, geLeft, geBottom);

  TfrmDockWindow = class(TfrmState, IExodusDockManager)
    splAW: TTntSplitter;
    AWTabControl: TTntPageControl;
    pnlActivityList: TExGradientPanel;
    timFlasher: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure AWTabControlDockDrop(Sender: TObject; Source: TDragDockObject; X,
      Y: Integer);
    procedure AWTabControlUnDock(Sender: TObject; Client: TControl;
      NewTarget: TWinControl; var Allow: Boolean);
    procedure FormShow(Sender: TObject);
    procedure WMActivate(var msg: TMessage); message WM_ACTIVATE;
    procedure FormDockDrop(Sender: TObject; Source: TDragDockObject; X,
      Y: Integer);
    procedure timFlasherTimer(Sender: TObject);
    Procedure WMSyscommand(Var msg: TWmSysCommand); message WM_SYSCOMMAND;
    procedure FormResize(Sender: TObject);
    procedure OnMove(var Msg: TWMMove); message WM_MOVE;
    procedure FormHide(Sender: TObject);
  private
    { Private declarations }

  protected
    { Protected declarations }
    _docked_forms: TList;
    _dockState: TDockStates;
    _sortState: TSortState;
    _glueEdge: TGlueEdge;

    procedure CreateParams(Var params: TCreateParams); override;
    procedure _removeTabs(idx:integer = -1);
    procedure _layoutDock();
    procedure _layoutAWOnly();
    procedure _saveDockWidths();
    procedure _glueCheck();
    function _withinGlueSnapRange(): TGlueEdge;

  public
    { Public declarations }

    // IExodusDockManager interface
    procedure CloseDocked(frm: TfrmDockable);
    function OpenDocked(frm : TfrmDockable) : TTntTabSheet;
    procedure FloatDocked(frm : TfrmDockable);
    function GetDockSite() : TWinControl;
    procedure BringDockedToTop(form: TfrmDockable);
    function getTopDocked(): TfrmDockable;
    procedure SelectNext(goforward: boolean; visibleOnly:boolean=false);
    procedure OnNotify(frm: TForm; notifyEvents: integer);
    procedure UpdateDocked(frm: TfrmDockable);
    procedure BringToFront();
    function isActive(): boolean;

    function getTabSheet(frm : TfrmDockable) : TTntTabSheet;
    function getTabForm(tab: TTabSheet): TForm;
    procedure updateLayoutDockChange(frm: TfrmDockable; docking: boolean; FirstOrLastDock: boolean);
    procedure setWindowCaption(txt: widestring);
    procedure Flash();
    procedure checkFlash();
    procedure moveGlued();
  end;

var
  frmDockWindow: TfrmDockWindow;

implementation

uses
    RosterWindow, Session, PrefController,
    ActivityWindow, Jabber1, ExUtils;

{$R *.dfm}

{---------------------------------------}
{---------------------------------------}
{---------------------------------------}
procedure TfrmDockWindow.CreateParams(Var params: TCreateParams);
begin
    // Make this window show up on the taskbar
    inherited CreateParams( params );
    params.ExStyle := params.ExStyle or WS_EX_APPWINDOW;
    params.WndParent := GetDesktopwindow;
end;

{---------------------------------------}
procedure TfrmDockWindow.CloseDocked(frm: TfrmDockable);
var
    idx: integer;
    aw: TfrmActivityWindow;
begin
    if (frm = nil) then exit;

    try
        aw := GetActivityWindow();
        if (aw <> nil) then begin
            aw.removeItem(frm.UID);
        end;

        if (frm.Docked) then begin
            updateLayoutDockChange(frm, true, _docked_forms.Count = 1);
            frm.Docked := false;
            idx := _docked_forms.IndexOf(frm);
            if (idx >= 0) then
                _docked_forms.Delete(idx);
        end;
    except
    end;
end;

{---------------------------------------}
function TfrmDockWindow.OpenDocked(frm : TfrmDockable) : TTntTabSheet;
begin
    if (not Self.Showing) then begin
        Self.ShowDefault(false);
    end;
    frm.ManualDock(AWTabControl); //fires TabsDockDrop event
    setWindowCaption(frm.Caption);
    Result := GetTabSheet(frm);
    frm.Visible := true;
    _removeTabs();
end;

{---------------------------------------}
procedure TfrmDockWindow.FloatDocked(frm : TfrmDockable);
begin
    frm.ManualFloat(frm.FloatPos);
end;

{---------------------------------------}
procedure TfrmDockWindow.FormCreate(Sender: TObject);
begin
    inherited;
    setWindowCaption('');
    _docked_forms := TList.Create;
    _dockState := dsUninitialized;
    _sortState := ssUnsorted;
    _glueEdge := geNone;
    _layoutAWOnly();
end;

{---------------------------------------}
procedure TfrmDockWindow.FormDestroy(Sender: TObject);
begin
    try
        inherited;
        _docked_forms.Free;
    except
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.FormDockDrop(Sender: TObject; Source: TDragDockObject;
  X, Y: Integer);
begin
    if (Source.Control is TfrmDockable) then begin
        // We got a new form dropped on us.
        OpenDocked(TfrmDockable(Source.Control));
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.FormHide(Sender: TObject);
begin
    inherited;
    frmExodus.mnuWindows_View_ShowActivityWindow.Checked := false;
end;

{---------------------------------------}
procedure TfrmDockWindow.FormResize(Sender: TObject);
begin
    inherited;
    Self.Constraints.MaxWidth := 0;
end;

{---------------------------------------}
procedure TfrmDockWindow.FormShow(Sender: TObject);
var
    aw: TfrmActivityWindow;
begin
    inherited;
    aw := GetActivityWindow();
    if (aw <> nil) and (not aw.docked)then begin
        aw.DockActivityWindow(pnlActivityList);
        aw.dockwindow := Self;
        aw.Show;
        aw.OnDockDrop := FormDockDrop;
    end;
    frmExodus.mnuWindows_View_ShowActivityWindow.Checked := true;

    _glueCheck();
end;

{---------------------------------------}
function TfrmDockWindow.GetDockSite() : TWinControl;
begin
    if (Self.DockSite) then
        Result := Self
    else
        Result := nil;
end;

{---------------------------------------}
procedure TfrmDockWindow.AWTabControlDockDrop(Sender: TObject;
  Source: TDragDockObject; X, Y: Integer);
var
    aw: TfrmActivityWindow;
    item: TAWTrackerItem;
begin
    // We got a new form dropped on us.
    if (Source.Control is TfrmDockable) then begin
        updateLayoutDockChange(TfrmDockable(Source.Control), true, false);
        TfrmDockable(Source.Control).Docked := true;
        TTntTabSheet(AWTabControl.Pages[AWTabControl.PageCount - 1]).ImageIndex := TfrmDockable(Source.Control).ImageIndex;
        TfrmDockable(Source.Control).OnDocked();
        _docked_forms.Add(TfrmDockable(Source.Control));
        _removeTabs();
        aw := GetActivityWindow();
        if (aw <> nil) then begin
            item := aw.findItem(TfrmDockable(Source.Control));
            if (item <> nil) then begin
                aw.activateItem(item.awItem); //???dda
            end;
//            aw.resetCurrentSheet();
        end;

        if (Self.WindowState = wsMaximized) then begin
            Self.Top := Self.Monitor.WorkareaRect.Top;
            Self.Left := Self.Monitor.WorkareaRect.Top;
            Self.Height := Self.Monitor.WorkareaRect.Bottom - Self.Monitor.WorkareaRect.Top;
            Self.Width := Self.Monitor.WorkareaRect.Right - Self.Monitor.WorkareaRect.Left;
        end;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.AWTabControlUnDock(Sender: TObject;
  Client: TControl; NewTarget: TWinControl; var Allow: Boolean);
begin
    // check to see if the tab is a frmDockable
    Allow := true;
    if ((Client is TfrmDockable) and TfrmDockable(Client).Docked)then begin
        CloseDocked(TfrmDockable(Client));
        TfrmDockable(Client).Docked := false;
        TfrmDockable(Client).OnFloat();
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.BringDockedToTop(form: TfrmDockable);
var
    tsheet: TTntTabSheet;
begin
    if (Self.AWTabControl.PageCount > 0) then begin
        tsheet := GetTabSheet(form);
        if (tsheet <> nil) then begin
            Self.AWTabControl.ActivePage := tsheet;
            form.gotActivate();
        end;
    end;
end;

{---------------------------------------}
function TfrmDockWindow.getTopDocked() : TfrmDockable;
var
    top : TForm;
begin
    Result := nil;
    try
        top := getTabForm(Self.AWTabControl.ActivePage);
        if ((top is TfrmDockable) and (TfrmDockable(top).Docked)) then
            Result := TfrmDockable(top);
    finally
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.SelectNext(goforward: boolean; visibleOnly:boolean=false);
begin
    AWTabControl.SelectNextPage(goforward, visibleonly);
end;

{---------------------------------------}
procedure TfrmDockWindow.OnNotify(frm: TForm; notifyEvents: integer);
begin
    //if dockmanager is being notified directly or the given form is docked
    //handle bring to front and flash
    if ((frm = nil) or (frm = Self) or
        ((frm is TfrmDockable) and (TfrmDockable(frm).Docked))) then begin
        if ((notifyEvents and notify_front) > 0) then
            bringToFront()
        else if ((notifyEvents and notify_flash) > 0) then
            Self.Flash();
    end;
    //tray notifications are always directed and dockmanager
    if (((notifyEvents and notify_tray) > 0) and ((notifyEvents and notify_front) = 0))then
        StartTrayAlert();
end;

{---------------------------------------}
procedure TfrmDockWindow.UpdateDocked(frm: TfrmDockable);
var
    item: TAWTrackerItem;
    aw: TfrmActivityWindow;
    dda: integer;
begin
    if (frm = nil) then exit;
    
    aw := ActivityWindow.GetActivityWindow();

    if (aw <> nil) then begin
        // See if item is in list
        //item := aw.findItem(frm.UID);
        item := aw.findItem(frm);
        if ((item = nil) and
            (frm.UID <> ''))then begin
            // Item NOT being tracked so let's add it
            item := aw.addItem(frm.UID, frm);
        end;

        if (item <> nil) then begin
            // Deal with priority
            item.awItem.priorityFlag(frm.PriorityFlag);

            // Successful lookup or add
            item.awItem.imgIndex := frm.ImageIndex;

            // Deal with msg count
            item.awItem.count := frm.UnreadMsgCount;

            // Deal with docked/undocked for popup menu
            item.awItem.docked := frm.Docked;

            // Deal with change of nickname
            item.awItem.name := frm.Caption;

            // Deal with undocked window focus
            if (frm.Activating) then begin
                if ((not Self.Showing) and
                    (frm.Docked)) then begin
                    Self.ShowDefault(true);
                end;
                aw.activateItem(item.awItem);
            end;

            aw.itemChangeUpdate();
            checkFlash();

            // Make sure SOMETHING is visible in the docked side
            // assuming that something IS docked.
//            if ((aw.currentActivePage = nil) and
//                (_dockState = dsDock)) then begin
//                aw.activateItem(item.awItem);
//            end;
        end;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.BringToFront();
begin
    ShowWindow(Self.Handle, SW_SHOWNORMAL);
    Self.Visible := true;
    ForceForegroundWindow(Self.Handle);
end;

{---------------------------------------}
function TfrmDockWindow.isActive(): boolean;
begin
    Result := Self.Active;
end;

{---------------------------------------}
function TfrmDockWindow.getTabSheet(frm : TfrmDockable) : TTntTabSheet;
var
    i : integer;
    tf : TForm;
begin
    //walk currently docked sheets and try to find a match
    Result := nil;
    for i := 0 to AWTabControl.PageCount - 1 do begin
        tf := getTabForm(AWTabControl.Pages[i]);
        if (tf = frm) then begin
            Result := TTntTabSheet(AWTabControl.Pages[i]);
            exit;
        end;
    end;
end;

{---------------------------------------}
function TfrmDockWindow.getTabForm(tab: TTabSheet): TForm;
begin
    // Get an associated form for a specific tabsheet
    Result := nil;
    if ((tab <> nil) and (tab.ControlCount = 1)) then begin
        if (tab.Controls[0] is TForm) then begin
            Result := TForm(tab.Controls[0]);
            exit;
        end;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow._removeTabs(idx: integer);
var
    i: integer;
begin
    if ((idx >= 0) and
        (idx < AWTabControl.PageCount)) then begin
        AWTabControl.Pages[idx].TabVisible := false;
    end
    else begin
        for i := 0 to AWTabControl.PageCount - 1 do begin
            AWTabControl.Pages[i].TabVisible := false
        end;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.WMActivate(var msg: TMessage);
var
    frm: TfrmDockable;
begin
    if (Msg.WParamLo <> WA_INACTIVE) then begin
        checkFlash();
        StopTrayAlert();
    end;

    if (Self.Visible) then begin
        frm := getTopDocked();
        if (frm <> nil) then begin
            frm.Activating := true;
            UpdateDocked(frm);
            frm.Activating := false;
        end;
    end;

    inherited;
end;

{
    Update UI after some dock event has occurred.

    HideDock if last tab was undocked, ShowNormalDock if moving from
    no tabs to at least one tab, handle embedded roster state changes.

    Since it can be difficult to know exactly when to perform a
    change in the DockState (in some instances this method may be called
    before the TPageControl has had a chance to cleanup an tab), a
    flag is passed to force a state change.

    @param frm the form that was just docked/undocked
    @param docking  is the form beign docked or undocked?
    @toggleDockState moving from (dsDockOnly or dsRosterDock) to dsRosterOnly or vice versa
}
{---------------------------------------}
procedure TfrmDockWindow.updateLayoutDockChange(frm: TfrmDockable; docking: boolean; FirstOrLastDock: boolean);

var
    oldState : TDockStates;
    newState : TDockStates;
begin
    oldState := _dockState;
    //figure out what state we are moving to...
    if (docking) then begin
       if (FirstOrLastDock) then begin
         newState := dsRosterOnly;
       end
       else begin
         newState := dsDock;
       end
    end
    else
      newState := dsRosterOnly;

    if (newState <> oldState) then begin
          if (newState = dsDock) then
            _layoutDock()
          else
            _layoutAWOnly();
    end;

    _glueCheck();
end;

{
    Adjust layout so roster panel and dock panel are shown
}
{---------------------------------------}
procedure TfrmDockWindow._layoutDock();
var
  mon: TMonitor;
  ratioRoster: real;
  aw: TfrmActivityWindow;
begin
    if (_dockState <> dsDock) then begin
        _saveDockWidths();
        //this is a mess. To get splitter working with the correct control
        //we need to hide/de-align/set their relative positions/size them and show them
        pnlActivityList.align := alNone;
        splAW.align := alNone;
        AWTabControl.align := alNone;

        splAW.Visible := false; //hide this first or will expand and throw widths off
        pnlActivityList.Visible := false;
        AWTabControl.Visible := false;

        //Obtain the width of the monitor
        //If we exceed the width of the monitor,
        //recalculate widths for roster based on the same ratio
        mon := Screen.MonitorFromWindow(Self.Handle, mdNearest);
        if (MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH) + 3 + MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_TAB_WIDTH) >= mon.Width) then begin
          ratioRoster := (MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH) + 3)/(MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH) + 3 + MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_TAB_WIDTH));
          Self.ClientWidth  := mon.Width;
          pnlActivityList.Width := Trunc(Self.ClientWidth * ratioRoster);
        end
        else begin
            Self.ClientWidth := MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH) + 3 + MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_TAB_WIDTH);
            pnlActivityList.Width := MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH);
        end;

        pnlActivityList.Left := 0;
        pnlActivityList.Align := alLeft;
        pnlActivityList.Visible := true;
        splAW.Left := pnlActivityList.BoundsRect.Right + 1;
        splAW.Align := alLeft;
        splAW.Visible := true;
        AWTabControl.Left := pnlActivityList.BoundsRect.Right + 4;
        AWTabControl.Align := alClient;
        AWTabControl.Visible := true;

        Self.DockSite := false;
        pnlActivityList.DockSite := false;
        AWTabControl.DockSite := true;

        _dockState := dsDock;

        aw := GetActivityWindow();
        if (aw <> nil) then begin
            aw.setDockingSpacers(_dockState);
        end;
    end;
end;

{
    Adjust layout so only roster panel is shown
}
{---------------------------------------}
procedure TfrmDockWindow._layoutAWOnly();
var
  aw: TfrmActivityWindow;
begin
    //if tabs were being shown, save tab size
    _saveDockWidths();
    if (_dockState <> dsRosterOnly) then begin
        AWTabControl.Visible := false;
        pnlActivityList.Align := alClient;
        splAW.Visible := false;
        Self.ClientWidth := MainSession.Prefs.getInt(PrefController.P_ACTIVITY_WINDOW_WIDTH);
        Self.DockSite := true;
        pnlActivityList.DockSite := true;
        AWTabControl.DockSite := false;

        _dockState := dsRosterOnly;

        aw := GetActivityWindow();
        if (aw <> nil) then begin
            aw.setDockingSpacers(_dockState);
        end;
    end;
end;

{
    Save the current roster and dock panel widths.

    Depending on current state...
}
{---------------------------------------}
procedure TfrmDockWindow._saveDockWidths();
begin
    if (_dockState = dsRosterOnly) then
        MainSession.Prefs.setInt(PrefController.P_ACTIVITY_WINDOW_WIDTH, pnlActivityList.Width)
    else if (_dockState = dsDock) then begin
        MainSession.Prefs.setInt(PrefController.P_ACTIVITY_WINDOW_WIDTH, pnlActivityList.Width);
        MainSession.Prefs.setInt(PrefController.P_ACTIVITY_WINDOW_TAB_WIDTH, AWTabControl.Width);
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.setWindowCaption(txt: widestring);
begin
    if (txt = '') then begin
        Caption := MainSession.Prefs.getString('brand_caption');
    end
    else begin
        Caption := MainSession.Prefs.getString('brand_caption') +
                   ' - ' +
                   txt;
    end;
end;

procedure TfrmDockWindow.timFlasherTimer(Sender: TObject);
begin
    inherited;
    // Flash the window
    FlashWindow(Self.Handle, true);
end;

{---------------------------------------}
procedure TfrmDockWindow.Flash();
begin
    If (Self.Active and not MainSession.Prefs.getBool('notify_docked_flasher')) then begin
        timFlasher.Enabled := false;
        exit; //0.9.1.0 behavior
    end;
    // flash window
    if (not Self.Showing) then begin
        Self.WindowState := wsMinimized;
        Self.Visible := true;
        ShowWindow(Handle, SW_SHOWMINNOACTIVE);
    end;
    if MainSession.Prefs.getBool('notify_flasher') then begin
        timFlasher.Enabled := true;
    end
    else begin
        timFlasher.Enabled := false;
        timFlasherTimer(Self);
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.checkFlash();
begin
    if (timFlasher.Enabled and
       (not MainSession.Prefs.getBool('notify_docked_flasher'))) then
        timFlasher.Enabled := false;
end;

{---------------------------------------}
procedure TfrmDockWindow.WMSyscommand(var msg: TWmSysCommand);
begin
    case (msg.cmdtype and $FFF0) of
        SC_MAXIMIZE: begin
            if (_dockState = dsRosterOnly) then begin
                Self.Constraints.MaxWidth := Self.Width;
            end;
            inherited;
        end;
        SC_RESTORE: begin
            if (_dockState = dsRosterOnly) then begin
                Self.Constraints.MaxWidth := Self.Width;
            end;
            inherited;
        end;
        else begin
            inherited;
        end;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.OnMove(var Msg: TWMMove);
begin
    _glueCheck();
    moveGlued();
    inherited;
end;

{---------------------------------------}
procedure TfrmDockWindow._glueCheck();
begin
    _glueEdge := _withinGlueSnapRange();

    if (_glueEdge <> geNone) then begin
        frmExodus.glueWindow(true);
    end
    else begin
        frmExodus.glueWindow(false);
    end;
end;

{---------------------------------------}
function TfrmDockWindow._withinGlueSnapRange(): TGlueEdge;
var
    mainfrmRect: TRect;
    myRect: TRect;
    glueRange: integer;
begin
    // Capture frmExodus rect.
    mainfrmRect.Top := frmExodus.Top;
    mainfrmRect.Left := frmExodus.Left;
    mainfrmRect.Bottom := frmExodus.Top + frmExodus.Height;
    mainfrmRect.Right := frmExodus.Left + frmExodus.Width;

    // Capture My Rect
    myRect.Top := Self.Top;
    myRect.Left := Self.Left;
    myRect.Bottom := Self.Top + Self.Height;
    myRect.Right := Self.Left + Self.Width;

    // Determine glue range
    glueRange := 10;
    if (MainSession.Prefs.getBool('snap_on')) then begin
        glueRange := MainSession.Prefs.getInt('edge_snap');
    end;

    // Check to see if we are in range
    //  - Need to be within glue range of a side
    //  - Need to be within glue range of secondary trait, like the top
    if ((myRect.Left <= (mainfrmRect.Right + glueRange)) and
        (myRect.Left >= (mainfrmRect.Right - glueRange)) and
        (myRect.Top <= (mainfrmRect.Top + glueRange)) and
        (myRect.Top >= (mainfrmRect.Top - glueRange))) then begin
        // Close to my left edge
        Result := geLeft;
    end
    else if ((myRect.Right >= (mainfrmRect.Left - glueRange)) and
            (myRect.Right <= (mainfrmRect.Left + glueRange)) and
            (myRect.Top <= (mainfrmRect.Top + glueRange)) and
            (myRect.Top >= (mainfrmRect.Top - glueRange))) then begin
        // Close to my right edge
        Result := geRight;
    end
    else if ((myRect.Top <= (mainfrmRect.Bottom + glueRange)) and
            (myRect.Top >= (mainfrmRect.Bottom - glueRange)) and
            (myRect.Left <= (mainfrmRect.Left + glueRange)) and
            (myRect.Left >= (mainfrmRect.Left - glueRange))) then begin
        // Close to my top edge
        Result := geTop;
    end
    else if ((myRect.Bottom >= (mainfrmRect.Top - glueRange)) and
            (myRect.Bottom <= (mainfrmRect.Top + glueRange)) and
            (myRect.Left <= (mainfrmRect.Left + glueRange)) and
            (myRect.Left >= (mainfrmRect.Left - glueRange))) then begin
        // Close to my bottom edge
        Result := geBottom;
    end
    else begin
        // Not close enough to anything
        Result := geNone;
    end;
end;

{---------------------------------------}
procedure TfrmDockWindow.moveGlued();
begin
    if (Self.Showing) then begin
        case (_glueEdge) of
            geTop: begin
                // Glued on my Top edge
                Self.Top := frmExodus.Top + frmExodus.Height;
                Self.Left := frmExodus.Left;
            end;
            geLeft: begin
                // Glued on my Left edge
                Self.Top := frmExodus.Top;
                Self.Left := frmExodus.Left + frmExodus.Width;
            end;
            geRight: begin
                // Glued on my Right edge
                Self.Top := frmExodus.Top;
                Self.Left := frmExodus.Left - Self.Width;
            end;
            geBottom: begin
                // Glued on my Bottom edge
                Self.Top := frmExodus.Top - Self.Height;
                Self.Left := frmExodus.Left;
            end;
            else begin
                // Not glued - nothing to do
            end;
        end;
    end;
end;


end.



