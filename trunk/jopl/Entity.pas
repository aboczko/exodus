unit Entity;
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
    IQ, JabberID, XMLTag, Signals, Session, Unicode, 
    Classes, SysUtils;

const

    // browse stuff
    FEAT_SEARCH         = 'search';
    FEAT_REGISTER       = 'register';
    FEAT_GROUPCHAT      = 'groupchat';
    FEAT_PRIVATE        = 'private';
    FEAT_PUBLIC         = 'gc-public';
    FEAT_JUD            = 'jud';
    FEAT_GATEWAY        = 'gateway';
    FEAT_AIM            = 'aim';
    FEAT_ICQ            = 'icq';
    FEAT_YAHOO          = 'yahoo';
    FEAT_MSN            = 'msn';
    FEAT_PROXY          = 'proxy';
    FEAT_BYTESTREAMS    = 'bytestreams';

type

    TJabberEntityType = (ent_unknown, ent_disco, ent_browse, ent_agents);

    // This class is designed to gather information about a host.
    // It first tries disco, then falls back on browse, and finally agents.
    TJabberEntity = class
    published
        procedure ItemsCallback(event: string; tag: TXMLTag);
        procedure InfoCallback(event: string; tag: TXMLTag);
        procedure BrowseCallback(event: string; tag: TXMLTag);
        procedure AgentsCallback(event: string; tag: TXMLTag);

        procedure WalkCallback(event: string; tag: TXMLTag);
        procedure WalkItemsCallback(event: string; tag: TXMLTag);
        
    private
        _jid: TJabberID;
        _node: Widestring;
        _name: Widestring;
        _feats: TWidestringlist;
        _type: TJabberEntityType;

        _has_info: Boolean;             // do we need to do a disco#info?
        _has_items: boolean;            // do we have children?
        _items: TWidestringlist;        // our children
        _iq: TJabberIQ;

        _cat: Widestring;
        _cat_type: Widestring;

        function _getFeature(i: integer): Widestring;
        function _getFeatureCount: integer;

        function _getItem(i: integer): TJabberEntity;
        function _getItemCount: integer;

        procedure _discoInfo(js: TJabberSession; callback: TSignalEvent);
        procedure _discoItems(js: TJabberSession; callback: TSignalEvent);

        procedure _processDiscoInfo(tag: TXMLTag);
        procedure _processDiscoItems(tag: TXMLTag);
        procedure _processLegacyFeatures();

    public
        Tag: integer;
        Data: TObject;
        
        constructor Create(jid: TJabberID);
        destructor Destroy; override;

        procedure getInfo(js: TJabberSession);
        procedure getItems(js: TJabberSession);
        procedure walk(js: TJabberSession);

        function ItemByJid(jid: Widestring): TJabberEntity;
        function hasFeature(f: Widestring): boolean;
        function getItemByFeature(f: Widestring): TJabberEntity;

        property Jid: TJabberID read _jid;
        property Node: Widestring read _node;
        property entityType: TJabberEntityType read _type;
        property Category: Widestring read _cat;
        property CatType: Widestring read _cat_type;
        property Name: Widestring read _name;

        property hasItems: boolean read _has_items;
        property hasInfo: boolean read _has_info;

        property FeatureCount: Integer read _getFeatureCount;
        property Features[Index: integer]: Widestring read _getFeature;

        property ItemCount: Integer read _getItemCount;
        property Items[Index: integer]: TJabberEntity read _getItem;

    end;

implementation
uses
    EntityCache, JabberConst, XMLUtils;

{---------------------------------------}
constructor TJabberEntity.Create(jid: TJabberID);
begin
    _jid := jid;
    _node := '';
    _name := '';
    _feats := TWidestringlist.Create();
    _type := ent_unknown;
    _has_info := false;
    _has_items := false;
    _items := TWidestringlist.Create();

    Data := nil;
end;

{---------------------------------------}
destructor TJabberEntity.Destroy;
begin
    ClearStringListObjects(_items);
    _items.Clear();
    _feats.Clear();
    FreeAndNil(_items);
    FreeAndNil(_feats);
    _jid.Free();
end;

{---------------------------------------}
function TJabberEntity._getFeature(i: integer): Widestring;
begin
    if (i < _feats.Count) then
        Result := _feats[i]
    else
        Result := '';
end;

{---------------------------------------}
function TJabberEntity.hasFeature(f: Widestring): boolean;
begin
    Result := (_feats.IndexOf(f) >= 0)
end;

{---------------------------------------}
function TJabberEntity._getFeatureCount: integer;
begin
    Result := _feats.Count;
end;

{---------------------------------------}
function TJabberEntity._getItem(i: integer): TJabberEntity;
begin
    if (i < _items.Count) then
        Result := TJabberEntity(_items.Objects[i])
    else
        Result := nil;
end;

{---------------------------------------}
function TJabberEntity.ItemByJid(jid: Widestring): TJabberEntity;
var
    i: integer;
begin
    i := _items.IndexOf(jid);
    if (i >= 0) then
        Result := TJabberEntity(_items.Objects[i])
    else
        Result := nil;
end;

{---------------------------------------}
function TJabberEntity.getItemByFeature(f: Widestring): TJabberEntity;
var
    c: TJabberEntity;
    i: integer;
begin
    Result := nil;
    for i := 0 to _items.Count - 1 do begin
        c := TJabberEntity(_items.Objects[i]);
        if (c.hasFeature(f)) then begin
            Result := c;
            exit;
        end;
    end;
end;

{---------------------------------------}
function TJabberEntity._getItemCount: integer;
begin
    Result := _items.Count;
end;

{---------------------------------------}
procedure TJabberEntity._discoInfo(js: TJabberSession; callback: TSignalEvent);
begin
    // Dispatch a disco#info query
    _iq := TJabberIQ.Create(js, js.generateID(), callback, 10);
    _iq.toJid := _jid.full;
    _iq.Namespace := XMLNS_DISCOINFO;
    _iq.iqType := 'get';
    
    if (_node <> '') then
        _iq.qTag.setAttribute('node', _node);
        
    _iq.Send();
end;

{---------------------------------------}
procedure TJabberEntity.getInfo(js: TJabberSession);
var
    t: TXMLTag;
begin
    if ((_has_info) or (_type = ent_browse) or (_type = ent_agents)) then begin
        t := TXMLTag.Create('entity');
        t.setAttribute('from', _jid.full);
        js.FireEvent('/session/entity/info', t);
        t.Free();
        exit;
    end;

    _discoInfo(js, InfoCallback);
end;

{---------------------------------------}
procedure TJabberEntity._discoItems(js: TJabberSession; callback: TSignalEvent);
begin
    // Dispatch a disco#items query
    _iq := TJabberIQ.Create(js, js.generateID(), callback, 10);
    _iq.toJid := _jid.full;
    _iq.Namespace := XMLNS_DISCOITEMS;
    _iq.iqType := 'get';

    if (_node <> '') then
        _iq.qTag.setAttribute('node', _node);
        
    _iq.Send();
end;

{---------------------------------------}
procedure TJabberEntity.getItems(js: TJabberSession);
var
    t: TXMLTag;
begin
    if ((_has_items) or (_type = ent_browse) or (_type = ent_agents)) then begin
        // send info for ea. child
        t := TXMLTag.Create('entity');
        t.setAttribute('from', _jid.full);
        js.FireEvent('/session/entity/items', t);
        t.Free();
        exit;
    end;

    _discoItems(js, ItemsCallback);
end;

{---------------------------------------}
procedure TJabberEntity.ItemsCallback(event: string; tag: TXMLTag);
var
    js: TJabberSession;
begin
    js := _iq.JabberSession;

    if ((event <> 'xml') or (tag.getAttribute('type') = 'error')) then begin
        // Dispatch a disco#items query
        _iq := TJabberIQ.Create(js, js.generateID(), Self.BrowseCallback, 10);
        _iq.toJid := _jid.full;
        _iq.Namespace := XMLNS_BROWSE;
        _iq.iqType := 'get';
        _iq.Send();
        exit;
    end;

    _processDiscoItems(tag);
    js.FireEvent('/session/entity/items', tag);
end;

{---------------------------------------}
procedure TJabberEntity.InfoCallback(event: string; tag: TXMLTag);
var
    js: TJabberSession;
begin
    // if disco didn't so much workout, try browse next
    js := _iq.JabberSession;

    if ((event <> 'xml') or (tag.getAttribute('type') = 'error')) then begin
        // Dispatch a disco#items query
        _iq := TJabberIQ.Create(js, js.generateID(), Self.BrowseCallback, 10);
        _iq.toJid := _jid.full;
        _iq.Namespace := XMLNS_BROWSE;
        _iq.iqType := 'get';
        _iq.Send();
        exit;
    end;

    _processDiscoInfo(tag);
    js.FireEvent('/session/entity/info', tag);
end;

{---------------------------------------}
procedure TJabberEntity.walk(js: TJabberSession);
begin
    // Get Items, then get info for each one.
    _discoInfo(js, WalkCallback);
end;

{---------------------------------------}
procedure TJabberEntity._processDiscoInfo(tag: TXMLTag);
var
    id, q: TXMLTag;
    fset: TXMLTagList;
    i: integer;
begin
    {
    We get back something like:
        <iq
            type='result'
            from='plays.shakespeare.lit'
            to='romeo@montague.net/orchard'
            id='info1'>
          <query xmlns='http://jabber.org/protocol/disco#info'>
            <identity
                category='conference'
                type='text'
                name='Play-Specific Chatrooms'/>
            <identity
                category='directory'
                type='room'
                name='Play-Specific Chatrooms'/>
            <feature var='gc-1.0'/>
            <feature var='http://jabber.org/protocol/muc'/>
            <feature var='jabber:iq:register'/>
            <feature var='jabber:iq:search'/>
            <feature var='jabber:iq:time'/>
            <feature var='jabber:iq:version'/>
          </query>
        </iq>
    }

    _has_info := true;
    _feats.Clear();

    q := tag.GetFirstTag('query');
    if (q = nil) then exit;

    // process features
    fset := q.QueryTags('feature');
    for i := 0 to fset.count - 1 do
        _feats.Add(fset[i].GetAttribute('var'));
    fset.Free();

    // TODO: What to do w/ the other <identity> elements?
    id := q.getFirstTag('identity');
    if (id <> nil) then begin
        _cat := id.getAttribute('category');
        _cat_type := id.getAttribute('type');
        _name := id.getAttribute('name');
    end;

    _processLegacyFeatures();
end;

{---------------------------------------}
procedure TJabberEntity._processLegacyFeatures();
begin
    // check for some legacy stuff..
    if (_feats.IndexOf(XMLNS_SEARCH) >= 0) then _feats.Add(FEAT_SEARCH);
    if (_feats.IndexOf(XMLNS_REGISTER) >= 0) then _feats.Add(FEAT_REGISTER);
    if (_feats.IndexOf(XMLNS_MUC) >= 0) then _feats.Add(FEAT_GROUPCHAT);
    if (_feats.IndexOf('gc-1.0') >= 0) then _feats.Add(FEAT_GROUPCHAT);
    if (_cat = 'conference') then
        _feats.Add(FEAT_GROUPCHAT);
end;

{---------------------------------------}
procedure TJabberEntity._processDiscoItems(tag: TXMLTag);
var
    q: TXMLTag;
    iset: TXMLTagList;
    idx, i: integer;
    tmps: Widestring;
    cj: TJabberID;
    ce: TJabberEntity;
begin
    {
    <iq
        type='result'
        from='catalog.shakespeare.lit'
        to='romeo@montague.net/orchard'
        id='items2'>
      <query xmlns='http://jabber.org/protocol/disco#items'>
        <item
            jid='catalog.shakespeare.lit'
            node='books'
            name='Books by and about Shakespeare'/>
        <item
            jid='catalog.shakespeare.lit'
            node='clothing'
            name='Show off your literary taste'/>
        <item
            jid='catalog.shakespeare.lit'
            node='music'
            name='Music from the time of Shakespeare'/>
      </query>
    </iq>
    }

    _has_items := true;
    q := tag.GetFirstTag('query');
    if (q = nil) then exit;

    iset := q.QueryTags('item');
    if (iset.Count > 0) then begin
        // clear out the old items
        ClearStringListObjects(_items);
        _items.Clear();

        for i := 0 to iset.Count - 1 do begin
            tmps := iset[i].getAttribute('jid');
            idx := _items.IndexOf(tmps);
            if (idx < 0) then begin
                cj := TJabberID.Create(tmps);
                ce := TJabberEntity.Create(cj);
                _items.AddObject(tmps, ce);
                ce._name := iset[i].getAttribute('name');
                ce._node := iset[i].getAttribute('node');
                jEntityCache.Add(tmps, ce);
            end;
        end;
    end;

end;


{---------------------------------------}
procedure TJabberEntity.WalkCallback(event: string; tag: TXMLTag);
var
    js: TJabberSession;

begin
    // if disco didn't so much workout, try browse next
    js := _iq.JabberSession;

    if ((event <> 'xml') or (tag.getAttribute('type') = 'error')) then begin
        // Dispatch a disco#items query
        _iq := TJabberIQ.Create(js, js.generateID(), Self.BrowseCallback, 10);
        _iq.toJid := _jid.full;
        _iq.Namespace := XMLNS_BROWSE;
        _iq.iqType := 'get';
        _iq.Send();
        exit;
    end;

    // we got disco#info back! sweet.
    _type := ent_disco;
    _processDiscoInfo(tag);
    getInfo(js);

    // We got info back... so lets get our items..
    _discoItems(js, WalkItemsCallback);
end;

{---------------------------------------}
procedure TJabberEntity.WalkItemsCallback(event: string; tag: TXMLTag);
var
    js: TJabberSession;
    i: integer;
begin
    js := _iq.JabberSession;

    if ((event <> 'xml') or (tag.getAttribute('type') = 'error')) then begin
        // Hrmpf.. we got info back, but no items?
        _has_items := true;
        getItems(js);
        exit;
    end;

    // We got items back... process them
    _processDiscoItems(tag);
    getItems(js);
    for i := 0 to _items.Count - 1 do
        TJabberEntity(_items.Objects[i]).getInfo(js);
end;

{---------------------------------------}
procedure TJabberEntity.BrowseCallback(event: string; tag: TXMLTag);
var
    idx, i, n: integer;
    t, q: TXMLTag;
    js: TJabberSession;
    nss, clist: TXMLTagList;
    tmps: Widestring;
    cj: TJabberID;
    ce: TJabberEntity;
begin
    // if browse didn't work out so well, try agents
    js := _iq.JabberSession;

    if ((event <> 'xml') or (tag.getAttribute('type') = 'error')) then begin
        // Dispatch a disco#items query
        _iq := TJabberIQ.Create(js, js.generateID(), Self.AgentsCallback, 10);
        _iq.toJid := _jid.full;
        _iq.Namespace := XMLNS_AGENTS;
        _iq.iqType := 'get';
        _iq.Send();
        exit;
    end;

    // we got disco info back.. process it.
    _type := ent_browse;
    _has_info := true;
    _has_items := true;

    // process results
    clist := tag.ChildTags();
    if (clist.Count > 0) then begin
        q := clist[0];
        clist.Free();

        clist := q.ChildTags();

        // clear old junk out..
        _feats.Clear();
        ClearStringListObjects(_items);
        _items.Clear();

        // info for us..
        _name := q.getAttribute('name');
        _cat := q.getAttribute('category');
        _cat_type := q.getAttribute('type');
        
        if ((_cat = '') and (q.name <> 'item')) then
            _cat := q.Name;

        for i := 0 to clist.Count - 1 do begin
            if (clist[i].Name = 'ns') then begin
                // this is a feature
                _feats.Add(clist[i].Data);
            end
            else begin
                // this is a child
                tmps := clist[i].GetAttribute('jid');
                idx := _items.IndexOf(tmps);
                if (idx = -1) then begin
                    cj := TJabberID.Create(tmps);
                    ce := TJabberEntity.Create(cj);

                    ce._name := clist[i].getAttribute('name');
                    ce._cat := clist[i].getAttribute('category');
                    ce._cat_type := clist[i].getAttribute('type');
                    if ((ce._cat = '') and (clist[i].Name <> 'item')) then
                        ce._cat := clist[i].Name;

                    // this item can have ns elements.. *sigh*
                    nss := clist[i].QueryTags('ns');
                    for n := 0 to nss.Count - 1 do
                        ce._feats.Add(nss[n].Data);
                    ce._processLegacyFeatures();

                    // we have the info about this object..
                    ce._has_info := true;

                    // but not it's children
                    ce._has_items := false;
                    jEntityCache.Add(tmps, ce);

                    _items.AddObject(tmps, ce);
                end;
            end;
        end;
        _processLegacyFeatures();

    end;

    // send events for this entity
    getInfo(js);
    getItems(js);

    // Send info for each child
    t := TXMLTag.Create('entity');
    for i := 0 to _items.Count - 1 do begin
        ce := TJabberEntity(_items.Objects[i]);
        t.setAttribute('from', ce.jid.full);
        js.FireEvent('/session/entity/info', t);
    end;
    t.Free();

end;

{---------------------------------------}
procedure TJabberEntity.AgentsCallback(event: string; tag: TXMLTag);
begin
    // XXX: code entity agents
end;

{---------------------------------------}


end.
