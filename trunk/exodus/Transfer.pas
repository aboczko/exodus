unit Transfer;
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

{$ifdef VER150}
    {$define INDY9}
{$endif}

interface

uses
    // Exodus things
    XMLTag, Dockable, ExRichEdit, RichEdit2, buttonFrame,

    // Indy Things
    IdTCPConnection, IdTCPClient, IdHTTP, IdBaseComponent,
    IdComponent, IdThreadMgr,

    // Normal Delphi things
    Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
    Dialogs, ComCtrls, StdCtrls, ExtCtrls;

type
  TfrmTransfer = class(TfrmDockable)
    pnlFrom: TPanel;
    txtMsg: TExRichEdit;
    frameButtons1: TframeButtons;
    pnlProgress: TPanel;
    Label1: TLabel;
    bar1: TProgressBar;
    httpClient: TIdHTTP;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    lblFrom: TLabel;
    txtFrom: TLabel;
    lblFile: TLabel;
    Label5: TLabel;
    lblDesc: TLabel;
    procedure frameButtons1btnOKClick(Sender: TObject);
    procedure httpClientWork(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCount: Integer);
    procedure httpClientWorkBegin(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCountMax: Integer);
    procedure httpClientWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
    procedure frameButtons1btnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lblFileClick(Sender: TObject);
    procedure txtMsgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure httpClientDisconnected(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure httpClientStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: String);
    procedure httpClientConnected(Sender: TObject);
  private
    { Private declarations }
    fstream: TFileStream;
  public
    { Public declarations }
    Mode: integer;
    url: string;
    filename: string;
    jid: string;
  end;

var
  frmTransfer: TfrmTransfer;

resourcestring
    sXferRecv = '%s is sending you a file.';
    sXferURL = 'File transfer URL: ';
    sXferDesc = 'File Description: ';
    sXferOnline = 'The Contact must be online before you can send a file.';
    sSend = 'Send';
    sOpen = 'Open';
    sClose = 'Close';
    sTo = 'To:     ';
    sXferOverwrite = 'This file already exists. Overwrite?';
    sXferWaiting = 'Waiting for connection...';
    sXferSending = 'Sending file...';
    sXferRecvDisconnected = 'Receiver disconnected.';
    sXferTryingClose = 'Trying to close.';
    sXferConn = 'Got connection.';
    sXferDefaultDesc = 'Sending you a file.';
    sXferCreateDir = 'This directory does not exist. Create it?';
    sXferStreamError = 'There was an error trying to create the file.';

procedure FileReceive(tag: TXMLTag); overload;
procedure FileReceive(from, url, desc: string); overload;

procedure FileSend(tojid: string; fn: string = '');

{---------------------------------------}
{---------------------------------------}
{---------------------------------------}
implementation

{$R *.dfm}

uses
    JabberConst, Notify, JabberID, Roster, Session, Presence,
    ShellAPI, Jabber1, ExUtils;

{---------------------------------------}
procedure FileReceive(tag: TXMLTag); overload;
var
    qTag, tmp_tag: TXMLTag;
    from, url, desc: string;
begin
    // Callback for receiving file transfers
    from := tag.GetAttribute('from');
    qTag := tag.getFirstTag('query');
    tmp_tag := qtag.GetFirstTag('url');
    url := tmp_tag.Data;

    // if this isn't an http:// url, then ignore.
    if (Pos('http:', url) <> 1) then exit;

    tmp_tag := qTag.GetFirstTag('desc');
    if (tmp_tag <> nil) then
        desc := tmp_tag.Data
    else
        desc := '';
    FileReceive(from, url, desc);
end;

{---------------------------------------}
procedure FileReceive(from, url, desc: string); overload;
var
    tmps: string;
    tmp_jid: TJabberID;
    xfer: TfrmTransfer;
    ritem: TJabberRosterItem;
begin
    xfer := TfrmTransfer.Create(Application);
    xfer.url := url;
    with xfer do begin
        jid := from;
        Mode := 0;

        tmp_jid := TJabberID.Create(jid);
        ritem := MainSession.Roster.Find(tmp_jid.jid);
        if (ritem = nil) then
            ritem := MainSession.Roster.Find(tmp_jid.full);

        if (ritem <> nil) then begin
            tmps := ritem.Nickname;
            txtFrom.Hint := from;
        end
        else
            tmps := tmp_jid.full;
        txtFrom.Caption := tmps;

        lblFile.Caption := ExtractFilename(URLToFileName(url));
        lblFile.Hint := url;

        txtMsg.Lines.Clear();
        txtMsg.Lines.Add(Format(sXferRecv, [from]));

        if (desc <> '') then
            txtMsg.Lines.Add(sXferDesc + desc);

        txtMsg.ReadOnly := true;
        lblDesc.Visible := false;
        tmp_jid.Free();

    end;
    xfer.ShowDefault();
    DoNotify(xfer, 'notify_oob', 'File from ' + tmps, ico_service);
end;

{---------------------------------------}
procedure FileSend(tojid: string; fn: string = '');
var
    xfer: TFrmTransfer;
    tmp_id: TJabberID;
    ip, tmps: string;
    pri: TJabberPres;
    ritem: TJabberRosterItem;
    p: integer;
begin
    xfer := TfrmTransfer.Create(Application);

    with xfer do begin
        Mode := 1;
        tmp_id := TJabberID.Create(tojid);
        if (tmp_id.resource = '') then begin
            pri := MainSession.ppdb.FindPres(tmp_id.jid, '');
            if (pri = nil) then begin
                MessageDlg(sXferOnline, mtError, [mbOK], 0);
                Mode := -1;
                xfer.Close;
                exit;
            end;
            tmps := pri.fromJID.full;
        end
        else
            tmps := tojid;

        jid := tmps;
        tmp_id.Free();

        tmp_id := TJabberID.Create(tmps);
        ritem := MainSession.Roster.Find(tmp_id.jid);
        if (ritem = nil) then
            ritem := MainSession.Roster.Find(tmp_id.full);

        if (ritem <> nil) then begin
            tmps := ritem.Nickname;
            txtFrom.Hint := tmps;
        end
        else
            tmps := tmp_id.full;
        tmp_id.Free();

        txtFrom.Caption := tmps;
        txtFrom.Hint := jid;
        lblFrom.Caption := sTo;

        pnlProgress.Visible := false;
        frameButtons1.btnOK.Caption := sSend;
        if (fn <> '') then
            filename := fn
        else begin
            if not OpenDialog1.Execute then exit;
            filename := OpenDialog1.Filename;
        end;

        // get xfer prefs, and spin up URL
        ip := MainSession.Prefs.getString('xfer_ip');
        p := MainSession.Prefs.getInt('xfer_port');

        if (ip = '') then ip := MainSession.Stream.LocalIP;
        url := 'http://' + ip + ':' + IntToStr(p) + '/' + ExtractFileName(filename);
        
        txtMsg.Lines.Clear();
        txtMsg.Lines.Add(sXferDefaultDesc);
        lblFile.Hint := filename;
        lblFile.Caption := ExtractFileName(filename);
    end;
    xfer.ShowDefault();
end;

{---------------------------------------}
procedure TfrmTransfer.frameButtons1btnOKClick(Sender: TObject);
var
    file_path: String;
    iq: TXMLTag;
begin
    if Self.Mode = 0 then begin
        // receive mode
        filename := URLToFilename(Self.url);

        // use the save as dialog
        SaveDialog1.Filename := filename;
        if (not SaveDialog1.Execute) then exit;
        filename := SaveDialog1.filename;

        if FileExists(filename) then begin
            if MessageDlg(sXferOverwrite,
                mtConfirmation, [mbYes, mbNo], 0) = mrNo then exit;
            DeleteFile(filename);
        end;

        file_path := ExtractFilePath(filename);
        if (not DirectoryExists(file_path)) then begin
            if MessageDlg(sXferCreateDir, mtConfirmation,
                [mbYes, mbNo], 0) = mrNo then exit;
            CreateDir(file_path);
        end;

        // Create a stream, and get the file into it.
        try
            fstream := TFileStream.Create(filename, fmCreate);
        except
            on EStreamError do begin
                MessageDlg(sXferStreamError, mtError, [mbOK], 0);
                exit;
            end;
        end;

        try
            httpClient.Get(Self.url, fStream);
        finally
            FreeAndNil(fstream);
        end;
        exit;
    end
    else if Self.Mode = 1 then begin
        // send mode
        Self.Mode := 3;
        iq := TXMLTag.Create('iq');
        with iq do begin
            setAttribute('to', jid);
            setAttribute('id', MainSession.generateID());
            setAttribute('type', 'set');
            with AddTag('query') do begin
                setAttribute('xmlns', XMLNS_IQOOB);
                AddBasicTag('url', url);
                AddBasicTag('desc', txtMsg.WideText);
            end;
        end;
        MainSession.SendTag(iq);
        frmExodus.FileServer.AddFile(filename);
        Self.Close();
    end
    else if Self.Mode = 2 then begin
        // Open the file.
        ShellExecute(0, 'open', PChar(filename), '', '', SW_NORMAL);
        Self.Close;
    end;
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientWork(Sender: TObject;
  AWorkMode: TWorkMode; const AWorkCount: Integer);
begin
    // Update the progress meter
    bar1.Position := AWorkCount;
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientWorkBegin(Sender: TObject;
  AWorkMode: TWorkMode; const AWorkCountMax: Integer);
begin
    bar1.Max := AWorkCountMax;
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientWorkEnd(Sender: TObject;
  AWorkMode: TWorkMode);
begin
    frameButtons1.btnOK.Caption := sOpen;
    frameButtons1.btnCancel.Caption := sClose;
    Self.mode := 2;
end;

{---------------------------------------}
procedure TfrmTransfer.frameButtons1btnCancelClick(Sender: TObject);
begin
    case Self.Mode of
    0: httpClient.DisconnectSocket();
    end;
    Self.Close;
end;

{---------------------------------------}
procedure TfrmTransfer.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
    Action := caFree;
end;

{---------------------------------------}
procedure TfrmTransfer.lblFileClick(Sender: TObject);
begin
    // Browse for a new file..
    if Mode = 0 then begin
        frameButtons1btnOKClick(Sender);
    end
    else if Mode = 1 then begin
        if OpenDialog1.Execute then begin
            // reset the text in the txtMsg richedit..
            filename := OpenDialog1.FileName;
            url := 'http://' + MainSession.Stream.LocalIP + ':5280/' +
                   ExtractFileName(filename);
            txtMsg.Lines.Clear();
            txtMsg.Lines.Add(sXferURL + url);
        end;
    end
    else if Mode = 2 then
        ShellExecute(0, 'open', PChar(filename), '', '', SW_NORMAL);
end;

{---------------------------------------}
procedure TfrmTransfer.txtMsgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
    if ((Key = 13) and (ssCtrl in Shift)) then
        frameButtons1btnOKClick(Self);
end;

{---------------------------------------}
procedure TfrmTransfer.FormCreate(Sender: TObject);
begin
    //
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientDisconnected(Sender: TObject);
begin
    // NB: For Indy9, it fires disconnected before it actually
    // connects. So if we drop the stream here, our GETs
    // never work since the response stream gets freed.
    {$ifndef INDY9}
    if (fstream <> nil) then
        FreeAndNil(fstream);
    {$endif}
end;

{---------------------------------------}
procedure TfrmTransfer.FormDestroy(Sender: TObject);
begin
    if (fstream <> nil) then
        FreeAndNil(fstream);
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientStatus(ASender: TObject;
  const AStatus: TIdStatus; const AStatusText: String);
begin
    txtMsg.Lines.Add(AStatusText);
end;

{---------------------------------------}
procedure TfrmTransfer.httpClientConnected(Sender: TObject);
begin
    txtMsg.Lines.Add(sXferConn);
end;

end.
