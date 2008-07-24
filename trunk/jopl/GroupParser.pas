unit GroupParser;



interface

uses RegExpr, Unicode;

type
   TGroupParser = class
   private
       _GroupSeparator: WideString;
       _Session: TObject;
   public
       constructor Create(Session: TObject);
       function GetNestedGroups(Group: WideString): TWideStringList;
       function GetGroupName(Group: WideString): WideString;
       function GetGroupParent(Group: WideString): WideString;
       function ParseGroupName(Group: WideString): TWideStringList;
       function BuildNestedGroupList(Groups: TWideStringList): TWideStringList;

       property Separator: Widestring read _GroupSeparator;
   end;

implementation

uses
    Session,
    StrUtils,
    SysUtils;

{---------------------------------------}
constructor TGroupParser.Create(Session: TObject);
begin
   _Session := Session;

   _GroupSeparator := TJabberSession(_Session).Prefs.getString('group_separator');
end;

{---------------------------------------}
function TGroupParser.GetNestedGroups(Group: WideString): TWideStringList;
var
    Groups: TWideStringList;
begin
    Groups := ParseGroupName(Group);
    Result := BuildNestedGroupList(Groups);
    Groups.Free;
end;

{---------------------------------------}
//This function will use regular expression to parse group strings in
//format a/b/c or /a/b/c or /a/b/c/  and will return node with the name
//matching the passed string in the above format.
function TGroupParser.ParseGroupName(Group: WideString): TWideStringList;
var
    Found: Boolean;
    sep: Widestring;
    sepoffset: integer;
    temp: widestring;
begin
   Result := TWideStringList.Create();

    sep := TJabberSession(_Session).Prefs.getString('group_separator');

    temp := Group;
    if (TJabberSession(_Session).Prefs.getBool('nested_groups') and
        TJabberSession(_Session).prefs.getBool('branding_nested_subgroup') and
        (sep <> '')) then
    begin
        sepoffset := Pos(sep, temp);
        while (sepoffset > 0) do
        begin
            Result.Add(LeftStr(temp, sepoffset - 1));
            temp := MidStr(temp, sepoffset + 1, Length(temp));
            sepoffset := Pos(sep, temp);
        end;
    end;
    Result.Add(temp);
end;

{---------------------------------------}
//Builds the list of all nested subgroups for the group
//Takes list in the format 'a','b','c' and builds '/a','/a/b','/a/b/c'
function TGroupParser.BuildNestedGroupList(Groups: TWideStringList): TWideStringList;
var
    i: Integer;
    GroupName: WideString;
begin
   Result := TWideStringList.Create();
   GroupName := '';
   for i := 0 to Groups.Count - 1 do
   begin
       if (i <> 0) then
         GroupName :=  GroupName + _GroupSeparator;
       GroupName := GroupName + Groups[i];
       Result.Add(GroupName);
   end;
end;

{---------------------------------------}
//Returns groups name based on UID
//For uid "/a/b/c" name would be "c"
function TGroupParser.GetGroupName(Group: WideString): WideString;
var
    Groups: TWideStringList;
begin
    Groups := ParseGroupName(Group);
    Result := Groups[Groups.Count -1];
    Groups.Free();
end;

{---------------------------------------}
//Returns groups name based on UID
//For uid "/a/b/c" name would be "c"
function TGroupParser.GetGroupParent(Group: WideString): WideString;
var
    Groups, GroupList: TWideStringList;
begin
    Result := '';
    Groups := ParseGroupName(Group);
    Groups.Delete(Groups.Count -1 );
    GroupList := BuildNestedGroupList(Groups);
    if (GroupList.Count > 0) then
       Result := GroupList[GroupList.Count - 1];

    Groups.Free();
    GroupList.Free();
end;
end.
