unit Responder;
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
    XMLTag,
    Session,
    SysUtils, Classes;

type
    TJabberResponder = class
    private
        _cb: integer;
    protected
        _session: TJabberSession;
    published
        procedure iqCallback(event: string; tag: TXMLTag); virtual; abstract;
    public
        constructor Create(Session: TJabberSession; namespace: string); overload; virtual;
        destructor Destroy; override;
    end;

{---------------------------------------}
{---------------------------------------}
{---------------------------------------}
implementation

{---------------------------------------}
constructor TJabberResponder.Create(Session: TJabberSession; namespace: string);
begin
    inherited Create();

    _cb := Session.RegisterCallback(iqCallback, '/packet/iq[@type="get"]/query[@xmlns="' + namespace + '"]');
    _session := Session;
end;

{---------------------------------------}
destructor TJabberResponder.Destroy;
begin
    _session.UnRegisterCallback(_cb);
    inherited Destroy;
end;

end.
