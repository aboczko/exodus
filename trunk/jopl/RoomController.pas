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
unit RoomController;

interface
uses XMLTag, Exodus_TLB, Unicode;

type TRoomController = class
     private
         _JS: TObject;
         _SessionCB: Integer;

         //Methods
         procedure _GetRooms();
         procedure _ParseRooms(Event: string; Tag: TXMLTag);
         procedure _ParseRoom(Room: IExodusItem; Tag: TXMLTag);
         procedure _SessionCallback(Event: string; Tag: TXMLTag);
     public
         constructor Create(JS: TObject);
         destructor  Destroy; override;
         procedure   AddRoom(const JabberID, RoomName, Nickname: WideString;
                                 AutoJoin, UseRegisteredNick: Boolean; 
                                 Groups: TWideStringList);
         procedure RemoveRoom(const JabberID: WideString);
         procedure SaveRooms();

end;

implementation
uses Session, IQ, JabberConst, SysUtils, COMExodusItem, JabberID, RosterImages,
     DisplayName;

{---------------------------------------}
constructor TRoomController.Create(JS: TObject);
begin
    _JS := JS;
    _SessionCB := TJabberSession(_JS).RegisterCallback(_SessionCallback, '/session');

end;

{---------------------------------------}
destructor  TRoomController.Destroy();
begin
    with TJabberSession(_js) do begin
        UnregisterCallback(_SessionCB);
    end;

end;

{---------------------------------------}
procedure TRoomController.AddRoom(const JabberID, RoomName, Nickname: WideString;
                                  AutoJoin, UseRegisteredNick: Boolean; Groups: TWideStringList);
var
    Room: IExodusItem;
    i: Integer;
begin
    Room := TJabberSession(_js).ItemController.AddItemByUid(JabberID, EI_TYPE_ROOM);
    Room.ImageIndex := RI_CONFERENCE_INDEX;
    Room.Text := RoomName;    
    Room.AddProperty('name', RoomName);
    Room.AddProperty('nick', Nickname);
    if (AutoJoin) then
        Room.AddProperty('autojoin', 'true')
    else
        Room.AddProperty('autojoin', 'false');
        
    if (UseRegisteredNick) then
        Room.AddProperty('reg_nick', 'true')
    else
        Room.AddProperty('reg_nick', 'false');

    for i := 0 to Groups.Count - 1 do
    begin
        Room.AddGroup(Groups[i]);
    end;
      

    TJabberSession(_JS).FireEvent('/item/add', Room);
    SaveRooms();
end;

{---------------------------------------}
procedure TRoomController.RemoveRoom(const JabberID: WideString);
var
    Idx: Integer;
    Room: IExodusItem;
begin
    Room :=  TJabberSession(_js).ItemController.GetItem(JabberID);
    TJabberSession(_JS).FireEvent('/item/remove', Room);
    TJabberSession(_js).ItemController.RemoveItem(JabberID);
    SaveRooms();
end;

{---------------------------------------}
procedure TRoomController.SaveRooms();
var
    i,j: Integer;
    IQ, RoomTag, GroupTag, StorageTag:TXMLTag;
    Room: IExodusItem;
begin
    IQ := TXMLTag.Create('iq');
    with IQ do begin
        setAttribute('type', 'set');
        setAttribute('id', TJabberSession(_js).generateID());
        with AddTag('query') do begin
            setAttribute('xmlns', XMLNS_PRIVATE);
            StorageTag := AddTag('storage');
            StorageTag.setAttribute('xmlns', XMLNS_BM);
            for i := 0 to TJabberSession(_js).ItemController.ItemsCount - 1 do
            begin
                if (TJabberSession(_js).ItemController.Item[i].Type_ <> EI_TYPE_ROOM) then continue;
                Room := TJabberSession(_js).ItemController.Item[i];
                RoomTag := TXMLTag.Create('conference');
                RoomTag.setAttribute('xmlns', XMLNS_BM);
                RoomTag.setAttribute('jid', Room.uid);
                RoomTag.setAttribute('name', Room.Value['name']);
                RoomTag.setAttribute('autojoin', Room.Value['autojoin']);
                RoomTag.setAttribute('reg_nick', Room.Value['reg_nick']);
                RoomTag.AddBasicTag('nick', Room.Value['nick']);
                for j := 0 to Room.GroupCount - 1 do
                begin
                    GroupTag := RoomTag.AddBasicTag('group', Room.Group[j]);
                    GroupTag.setAttribute('xmlns', 'http://jabber.com/protocols');
                end;
            end;
        end;
    end;
    TJabberSession(_JS).SendTag(IQ);
end;

{---------------------------------------}
procedure TRoomController._SessionCallback(Event: string; Tag: TXMLTag);
begin
     if Event = '/session/authenticated'  then
     begin
         _GetRooms();
     end
end;

{---------------------------------------}
//Creates and sends out an IQ to retrieve
//bookmarks from the server.
procedure TRoomController._GetRooms();
var
    IQ: TJabberIQ;
    Session: TJabberSession;
begin
    Session := TJabberSession(_js);
    IQ := TJabberIQ.Create(Session, Session.generateID(), _ParseRooms, 180);
    with iq do begin
        iqType := 'get';
        toJid := '';
        Namespace := XMLNS_PRIVATE;
        with qtag.AddTag('storage') do
            setAttribute('xmlns', XMLNS_BM);
        Send();
    end;
end;

{---------------------------------------}
//Parses the xml with bookmarks received from the server.
procedure TRoomController._ParseRooms(Event: string; Tag: TXMLTag);
var
    RoomTags: TXMLTagList;
    i, idx: integer;
    bm, StorageTag, RoomTag: TXMLTag;
    jid: Widestring;
    TmpJID: TJabberID;
    Item: IExodusItem;
begin
    Item := nil;
    TJabberSession(_JS).FireEvent('/item/begin', Item);
    RoomTags := nil;
    if ((Event = 'xml') and (Tag.getAttribute('type') <> 'result')) then exit;

    // We got a response..
    StorageTag := tag.QueryXPTag('/iq/query/storage');
    if (StorageTag <> nil) then
        RoomTags := StorageTag.ChildTags();

    for i := 0 to RoomTags.Count - 1 do begin
            if (RoomTags[i].Name <> 'conference') then continue;
            RoomTag := RoomTags.Tags[i];
            jid := WideLowerCase(RoomTag.GetAttribute('jid'));
            TmpJID := TJabberID.Create(RoomTag.GetAttribute('jid'));
            Item := TJabberSession(_js).ItemController.AddItemByUid(TmpJID.full, EI_TYPE_ROOM);
            //Make sure item exists
            if (Item <> nil) then
            begin
                _ParseRoom(Item, RoomTag);

                if (Item.IsVisible) then
                    TJabberSession(_JS).FireEvent('/item/add', Item);
            end;
            TmpJID.Free();
     end;

     Item := nil;
     TJabberSession(_JS).FireEvent('/item/end', Item);

     RoomTags.Free();

end;

{---------------------------------------}
//Sets some specific and generic properties of
//IExodusItem interface based on the tag data.
procedure TRoomController._ParseRoom(Room: IExodusItem; Tag: TXMLTag);
var
    TmpJid: TJabberID;
    Grps: TXMLTagList;
    TmpTag: TXMLTag;
    i: Integer;
    Grp, Groups: WideString;
begin
    {
        <iq type="set" id="jcl_4">
            <query xmlns="jabber:iq:private">
                <storage xmlns="storage:bookmarks">
                    <conference name='Council of Oberon'
                                  autojoin='true'
                                  jid='council@conference.underhill.org'>
                        <nick>Puck</nick>
                        <group ns="http://jabber.com/protocols">abc</group>
                    </conference>
                </storage>
        </query></iq>
        }
    Room.ImageIndex := RI_CONFERENCE_INDEX;
    TmpJid := TJabberID.Create(Tag.GetAttribute('jid'));
    Room.AddProperty('name', Tag.GetAttribute('name'));
    //Retrieve room name from display cache
    GetDisplayNameCache().UpdateDisplayName(Room);
    Room.Text := GetDisplayNameCache().GetDisplayName(Room.Uid);
    Room.AddProperty('autojoin', Tag.GetAttribute('autojoin'));
    Room.AddProperty('reg_nick', Tag.GetAttribute('reg_nick'));
    TmpTag := Tag.QueryXPTag('/conference/nick');
    if (TmpTag <> nil) then
        Room.AddProperty('nick', TmpTag.Data);


    Grps := Tag.QueryXPTags('/conference/group');
    //Build temporary list of groups for future comparison of the lists.
    for i := 0 to Grps.Count - 1 do
    begin
        Grp := WideTrim(TXMLTag(grps[i]).Data);
        Groups := Groups + Grp + LineSeparator;
    end;

    if (Room.GroupsChanged(Groups)) then
    begin
    //If groups changed, update the list.
        Room.ClearGroups();
        for i := 0 to Grps.Count - 1 do
        begin
            Grp := WideTrim(TXMLTag(Grps[i]).Data);
            if (Grp <> '') then
            begin
                Room.AddGroup(grp);
                TJabberSession(_js).ItemController.AddGroup(grp);
            end;

        end;
    end;

    if (Room.GroupCount = 0) then
        Room.AddGroup(TJabberSession(_JS).Prefs.getString('roster_default'));

   
    Grps.Free();
    TmpJid.Free();
end;

end.
