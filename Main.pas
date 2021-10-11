unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls;

const
  NAME_LOG                 = 'System';
  BUFFER_SIZE              = 65535;
  IS_EQUAL                 = 0;
  EVENT_ID_DISCONNECT      = 20159;
  EVENT_ID_CONNECT         = 20158;
  SecsPerHour              = SecsPerMin * MinsPerHour;
  SERVER_DELAY_DISCONNECT  = 2; // ������ ������������ ���������� � ���������
                                //  �� ��������� � ��������� ������������
  EVENTLOG_SEQUENTIAL_READ = 1;
  EVENTLOG_SEEK_READ       = 2;
  EVENTLOG_FORWARDS_READ   = 4;
  EVENTLOG_BACKWARDS_READ  = 8;

type
  TMainForm = class(TForm)
    ListView1: TListView;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;
  EVENTLOGRECORD = record
    Length: DWORD;        // ����� ����� ������
    Reserved: DWORD;      // ������������ ������� ����������� �������
    RecordNumber: DWORD;  // ���������� ����� ������
    TimeGenerated: DWORD; // ������ � 1-1-1970 (UNIX ������)
    TimeWritten: DWORD;   // ������ � 1-1-1970 (UNIX ������)
    EventID: DWORD;
    EventType: WORD;
    NumStrings: WORD;
    EventCategory: WORD;
    ReservedFlags: WORD;  // ��� ������������� � ������� ��������� (�����)
    ClosingRecordNumber: DWORD; // ��� ������������� � ������� ��������� (�����)
    StringOffset: DWORD;  // �������� �� ������ ������
    UserSidLength: DWORD;
    UserSidOffset: DWORD;
    DataLength: DWORD;
    DataOffset: DWORD;    // �������� �� ������ ������
    //
    // ����� �������:
    //
    // WCHAR SourceName[]
    // WCHAR Computername[]
    // SID   UserSid
    // WCHAR Strings[]
    // BYTE  Data[]
    // CHAR  Pad[]
    // DWORD Length;
    //
  end;
  PEVENTLOGRECORD = ^EVENTLOGRECORD;
  AConnList = record
    Conn, Login: String;
    TotalTime: DWORD;
  end;
  PConnList = ^AConnList;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormShow(Sender: TObject);
var
  h: THandle;
  pevlr: PEVENTLOGRECORD;
  bBuffer: array[0..BUFFER_SIZE] of BYTE;
  dwRead, dwNeeded: DWORD;
  pevsrc, pevstr: LPWSTR;
  i: Integer; AddOffset, DD, HH, MM, SS: WORD;
  LastDisConn, LastDisLogin: String; LastDisTime: DWORD;
  NAME_CONNECTION, NAME_LOGIN: String;
  ConnList: TList; ConnInfo: PConnList; Found: Boolean;
begin

  // ������� ������ ����������� ������� NAME_LOG.

  h := OpenEventLog(nil,        // ������������ ��������� ���������
                    NAME_LOG);  // ��� �������
  if h = THandle(nil) then
    begin
    Windows.MessageBox(0, '���������� ������� ������ ����������� ������� "' +
                          NAME_LOG + '".', 'ReadLog', MB_OK);
    Exit;
    end;

  // �������� ������� ����������� ������� ������������� ��������� ����� ���
  // ����� ����������� � ����� ������� �����������. ������ ������� �����������
  // ������� �������� ��������������� � �������� �����������, ���� ������ ������
  // �� ����� ���������.

  ConnList := TList.Create;
  ConnList.Clear;
  LastDisConn := ''; LastDisLogin := ''; LastDisTime := 0;
  pevlr := PEVENTLOGRECORD(@bBuffer);

  while (ReadEventLog(h,                // ���������� ������� �����������
              EVENTLOG_BACKWARDS_READ + // ������ � �������� �����������
              EVENTLOG_SEQUENTIAL_READ, // ���������������� ������
              0,                // ������������ ��� ����������������� ������
              pevlr,            // ��������� ������
              SizeOf(bBuffer),  // ������ ������
              dwRead,           // ����� ����������� ����
              dwNeeded)) do     // ���� � ��������� ������
    begin
    while (dwRead > 0) do
      begin

      pevsrc := LPWSTR(LPSTR(pevlr) + SizeOf(EVENTLOGRECORD));

      if StrComp(PChar(pevsrc), 'RemoteAccess') = IS_EQUAL then
        if pevlr^.NumStrings > 0 then
          begin
          AddOffset := 0;

          for i := 1 to pevlr^.NumStrings do
            begin
            pevstr := LPWSTR(LPSTR(pevlr) + pevlr^.StringOffset + AddOffset);
            if WORD(pevlr^.EventID) = EVENT_ID_DISCONNECT then
              begin
              if i = 1 then NAME_CONNECTION := PChar(pevstr);
              if i = 2 then NAME_LOGIN      := PChar(pevstr);
              end;
            if WORD(pevlr^.EventID) = EVENT_ID_CONNECT then
              begin
              if i = 1 then NAME_LOGIN      := PChar(pevstr);
              if i = 2 then NAME_CONNECTION := PChar(pevstr);
              end;
            AddOffset := AddOffset + StrLen(PChar(pevstr)) + 1;
            end;

          Found := False;
          for i := 0 to (ConnList.Count - 1) do
            begin
            ConnInfo := ConnList.Items[i];
            if (ConnInfo^.Conn + ConnInfo^.Login) =
               (NAME_CONNECTION + NAME_LOGIN) then
              begin
              Found := True;
              Break;
              end;
            end;
          if not Found then
            begin
            New(ConnInfo);
            ConnInfo^.Conn      := NAME_CONNECTION;
            ConnInfo^.Login     := NAME_LOGIN;
            ConnInfo^.TotalTime := 0;
            ConnList.Add(ConnInfo);
            end;

          if WORD(pevlr^.EventID) = EVENT_ID_DISCONNECT then
            begin
            LastDisConn  := NAME_CONNECTION;
            LastDisLogin := NAME_LOGIN;
            LastDisTime  := pevlr^.TimeGenerated;
            end;
          if WORD(pevlr^.EventID) = EVENT_ID_CONNECT then
            begin
            if ((LastDisConn + LastDisLogin) =
                (NAME_CONNECTION + NAME_LOGIN)) and (LastDisTime > 0) then
              ConnInfo^.TotalTime := ConnInfo^.TotalTime + (LastDisTime -
                                     pevlr^.TimeGenerated) +
                                     SERVER_DELAY_DISCONNECT;
            LastDisConn := ''; LastDisLogin := ''; LastDisTime := 0;
            end;
          end;

      dwRead := dwRead - pevlr^.Length;
      pevlr  := PEVENTLOGRECORD(LPSTR(pevlr) + pevlr^.Length);
      end;

    pevlr := PEVENTLOGRECORD(@bBuffer);
    end;

  CloseEventLog(h);
  with ListView1 do
    begin
    Items.BeginUpdate;
    Items.Clear;
    for i := 0 to (ConnList.Count - 1) do
      begin
      ConnInfo := ConnList.Items[i];
        with Items.Add do
          begin
          Caption := ConnInfo^.Conn;
          SubItems.Add(ConnInfo^.Login);
          DD := (ConnInfo^.TotalTime div SecsPerDay);
          ConnInfo^.TotalTime := (ConnInfo^.TotalTime mod SecsPerDay);
          HH := (ConnInfo^.TotalTime div SecsPerHour);
          ConnInfo^.TotalTime := (ConnInfo^.TotalTime mod SecsPerHour);
          MM := (ConnInfo^.TotalTime div SecsPerMin);
          SS := (ConnInfo^.TotalTime mod SecsPerMin);
          SubItems.Add(IntToStr(DD) + ':' + IntToStr(HH) + ':' +
                       IntToStr(MM) + ':' + IntToStr(SS));
          end;
      Dispose(ConnInfo);
      end;
    Items.EndUpdate;
    end;
  ConnList.Free;
  with ListView1 do
    begin
     if Items.Count>0
     then
      begin
       Items[0].Selected := True;
       ItemFocused := Items[0];
      end; 
    end;
end;

end.

