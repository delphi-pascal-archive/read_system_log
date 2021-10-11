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
  SERVER_DELAY_DISCONNECT  = 2; // —ервер регистрирует отключение с задержкой
                                //  по сравнению с локальной регистрацией
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
    Length: DWORD;        // ќбща€ длина записи
    Reserved: DWORD;      // »спользуетс€ службой регистрации событий
    RecordNumber: DWORD;  // јбсолютный номер записи
    TimeGenerated: DWORD; // —екунд с 1-1-1970 (UNIX формат)
    TimeWritten: DWORD;   // —екунд с 1-1-1970 (UNIX формат)
    EventID: DWORD;
    EventType: WORD;
    NumStrings: WORD;
    EventCategory: WORD;
    ReservedFlags: WORD;  // ƒл€ использовани€ с парными событи€ми (аудит)
    ClosingRecordNumber: DWORD; // ƒл€ использовани€ с парными событи€ми (аудит)
    StringOffset: DWORD;  // —мещение от начала записи
    UserSidLength: DWORD;
    UserSidOffset: DWORD;
    DataLength: DWORD;
    DataOffset: DWORD;    // —мещение от начала записи
    //
    // ƒалее следуют:
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

  // ќткрыть журнал регистрации событий NAME_LOG.

  h := OpenEventLog(nil,        // используетс€ локальный компьютер
                    NAME_LOG);  // им€ журнала
  if h = THandle(nil) then
    begin
    Windows.MessageBox(0, 'Ќевозможно открыть журнал регистрации событий "' +
                          NAME_LOG + '".', 'ReadLog', MB_OK);
    Exit;
    end;

  // ќткрытие журнала регистрации событий устанавливает указатель файла дл€
  // этого дескриптора в конец журнала регистрации. «аписи журнала регистрации
  // событий читаютс€ последовательно в обратном направлении, пока перва€ запись
  // не будет прочитана.

  ConnList := TList.Create;
  ConnList.Clear;
  LastDisConn := ''; LastDisLogin := ''; LastDisTime := 0;
  pevlr := PEVENTLOGRECORD(@bBuffer);

  while (ReadEventLog(h,                // дескриптор журнала регистрации
              EVENTLOG_BACKWARDS_READ + // чтение в обратном направлении
              EVENTLOG_SEQUENTIAL_READ, // последовательное чтение
              0,                // игнорируетс€ дл€ последовательного чтени€
              pevlr,            // указатель буфера
              SizeOf(bBuffer),  // размер буфера
              dwRead,           // число прочитанных байт
              dwNeeded)) do     // байт в следующей записи
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

