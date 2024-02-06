unit Debug;


interface
uses SysUtils;



type
  TDebug = class
  private
    var FFileName: string;
    var FLogFile: TextFile;
    procedure OpenLogFile;
    procedure CloseLogFile;
  public
    //constructor Create(const FileName: string);
    constructor Initialize(const FileName: string);
    procedure Log(const Message: string);
    destructor Finalize;
  end;

 var DebugFLag:Boolean=True;

implementation

constructor TDebug.Initialize(const FileName: string);
begin
  FFileName := FileName;
  AssignFile(FLogFile, FFileName);
  Rewrite(FLogFile);
end;

 procedure TDebug.Log(const Message: string);
begin
  if FFileName <> '' then
  begin
    //if not FileExists(FFileName) then
     // Initialize(FFileName);
    Writeln(FLogFile, Message);
    Flush(FLogFile);
  end;
end;

destructor TDebug.Finalize;
begin
  CloseLogFile;
end;

 procedure TDebug.OpenLogFile;
begin
  if FFileName <> '' then
  begin
    AssignFile(FLogFile, FFileName);
    Append(FLogFile);
  end;
end;

 procedure TDebug.CloseLogFile;
begin
  if FFileName <> '' then
  begin
    CloseFile(FLogFile);
    FFileName := '';
  end;
end;

end.

end.
