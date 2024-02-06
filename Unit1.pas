unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,Fields,Debug;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Label1: TLabel;
    ProgressBar1: TProgressBar;
    StyleBook1: TStyleBook;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Button1Click(Sender: TObject);
    procedure FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure ProgressBar1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }

   procedure DrawGrid;
   procedure DrawCrossZeros;
   procedure DrawCross(i,j:Byte;CellSize:Word);
   procedure DrawZero(i,j:Byte;CellSize:Word);

  end;
  TThreadRenew = class(TThread)
  MainFlag : Boolean;
  constructor Create;
  Destructor Destroy;
  procedure Execute; override;
 // procedure ChangeL2;
end;

var
  Form1: TForm1;
  HardTurnOn :Boolean=False;
  ThreadRenew  :  TThreadRenew;
implementation

{$R *.fmx}

procedure NewGame;
begin
  DebugFLag:= False;
  //if (Fields.Debug<>nil) then Fields.Debug.Finalize;
 // Fields.Debug := TDebug.Initialize('debug.txt');
  if MainField<>nil then MainField.Destroy;
  MainField := TField.Create;
  Win := False;
  Lose := False;
  Form1.Label1.Visible := False;
  NTurn := 0;
end;


procedure TForm1.DrawGrid;
var
 { GridSize,} CellSize, I: Integer;
  p1, p2: TPointF;
begin
  CellSize := ClientWidth div GridSize; // Size of each grid cell

  // Set the pen properties for grid lines
  Canvas.Stroke.Color := TAlphaColors.Black;
  Canvas.Stroke.Dash := TStrokeDash.Solid;//TSrokeDash
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Thickness:= 1;

  // Draw vertical grid lines
  for I := 0 to GridSize do
  begin
    p1 := TPointF.Create(I * CellSize, 0);
    p2 := TPointF.Create(I * CellSize, CellSize*GridSize);
    Canvas.DrawLine(p1,p2,100);
    //Canvas.MoveTo(I * CellSize, 0);
    //Canvas.LineTo(I * CellSize, CellSize*GridSize);
  end;

  // Draw horizontal grid lines
  for I := 0 to GridSize do
  begin
    p1 := TPointF.Create(0, I * CellSize);
    p2 := TPointF.Create(CellSize*GridSize, I * CellSize);
    Canvas.DrawLine(p1,p2,100);
    //Canvas.MoveTo(0, I * CellSize);
    //Canvas.LineTo(CellSize*GridSize, I * CellSize);
  end;
end;



procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   ThreadRenew.MainFlag := False;
end;

procedure TForm1.FormCreate(Sender: TObject);
var ch,cw : Single;
begin
  Fields.Debug := TDebug.Initialize('');
  ThreadRenew := TThreadRenew.Create;
  NewGame;
  Randomize;
  Ch := ClientHeight;
  Cw := ClientWidth;
  if Cw>Ch then
   begin
     Ch := ClientWidth;
     Cw := ClientHeight;
   end;
  Button1.Position.X := 0.35*Cw;
  Button1.Width := 0.3*Cw;
  Button1.Position.Y := 0.6*Ch;
  Label1.Position.X := 0.37*Cw;
  Label1.Position.Y := 0.2*Ch ;
  Label1.Height := 0.06*Ch;
  //ProgressBar1.Height := 10;
  ProgressBar1.Width := 0.9*Cw;
  ProgressBar1.Position.X := 0.05*Cw;
  ProgressBar1.Position.Y := 0.7*Ch;

end;



procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
CellSize, GridX, GridY: Integer;
Color:Byte;

begin
  if HardTurnOn  then exit;

  if Win or Lose then exit;
  if NTurn>=sqr(GridSize) then exit;
  CellSize := ClientWidth div GridSize; // Size of each grid cell

  // Calculate the grid coordinates based on the mouse click position
  GridX := Trunc(X/CellSize);  //0..15
  GridY := Trunc(Y/CellSize);  //0..15
  if Button=TMouseButton.mbLeft then Color :=2
                                else Color :=0;

  if OutOfBounds(GridX,GridY) then exit;

  if MainField.Data[GridX,GridY].Color=1 then
    begin
      MainField.SetData(GridX,GridY,Color);
      //Repaint;
      //Timer1.Enabled := True;
      HardTurnOn := True;
      ProgressBar1.Value := 0;
     // HardTurn(MainField,0,0);//SimpleTurn;
      //Timer1.Enabled := False;
     // HardTurnOn := False;
      //ProgressBar1.Value := 0;
    end;
 Invalidate;

end;

procedure TForm1.FormPaint(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
  //var ABrush : TBrush;
  //AOpacity : Single;
begin
  Canvas.BeginScene();
//  Canvas.Brush.Color:= TAlphaColors.White;//clBtnFace;
  {Self.
  ABrush := TBrush.Create();
  ABrush.Color := TAlphaColors.White;
  AOpacity := 0;
  Canvas.FillRect(ARect,AOpacity,ABrush); }
  //Canvas.FillRect(ClientRect);    //полностью очищаем форму.
  DrawGrid;
  {if (not Win) and (not Lose) then} DrawCrossZeros;
  Canvas.EndScene();
  if Win then
    begin
      Label1.Text := 'Победа!';
      Label1.TextSettings.FontColor := TAlphaColors.Maroon;
    end;
  if Lose then
    begin
      Label1.Text := 'Поражение...';
      Label1.TextSettings.FontColor  := TAlphaColors.Aqua;
    end;
  if  Win or Lose then  Form1.Label1.Visible := True;
  if NTurn>=sqr(GridSize) then
    begin
      Label1.Text := 'Ничья';
      Label1.TextSettings.FontColor  := TAlphaColors.Black;
      Label1.Visible := True;
    end;
  Label1.Repaint;
end;

procedure TForm1.ProgressBar1Click(Sender: TObject);
begin
  Invalidate;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if HardTurnOn then
    begin
      if ProgressBar1.Value>99 then ProgressBar1.Value := 0;
      ProgressBar1.Value := ProgressBar1.Value+1;
      //Invalidate;
      ProgressBar1.Repaint;
    end;
  Invalidate;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  NewGame;
  Invalidate;
end;

procedure TForm1.DrawCrossZeros;
var  CellSize, I,J: Integer;
begin
  CellSize := ClientWidth div GridSize;
  for I := 0 to GridSize-1 do
    for J := 0 to GridSize-1 do
      case MainField.Data[i,j].Color of
        0: DrawZero(i,j,CellSize);
        2: DrawCross(i,j,CellSize);
      end;
end;

procedure TForm1.DrawCross(i: Byte; j: Byte; CellSize: Word);
var
  CrossSize, CrossHalfSize: Integer;
  CrossMargin : Integer;
  CrossLeft, CrossTop: Integer;
  p1,p2 : TPointF;
begin
  CrossSize := Round(CellSize*0.8); // Size of the cross
  CrossHalfSize := CrossSize div 2;
  CrossMargin := CellSize div 2 - CrossHalfSize;


  CrossLeft := i*CellSize + CrossMargin; // Calculate the left position of the cross
  CrossTop :=  j*CellSize + CrossMargin; // Calculate the top position of the cross

  // Set the pen properties for the cross
  if (i=XLast) and (j=Ylast) then Canvas.Stroke.Color := TAlphaColors.Black
                             else Canvas.Stroke.Color := TAlphaColors.Red;
  Canvas.Stroke.Thickness := 3;

  // Draw the first line of the cross
  p1 := TPointF.Create(CrossLeft, CrossTop);
  p2 := TPointF.Create(CrossLeft + CrossSize, CrossTop + CrossSize);
  Canvas.DrawLine(p1,p2,100);
  //Canvas.MoveTo(CrossLeft, CrossTop);
  //Canvas.LineTo(CrossLeft + CrossSize, CrossTop + CrossSize);
  // Draw the second line of the cross
  p1 := TPointF.Create(CrossLeft + CrossSize, CrossTop);
  p2 := TPointF.Create(CrossLeft, CrossTop + CrossSize);
  Canvas.DrawLine(p1,p2,100);
 // Canvas.MoveTo(CrossLeft + CrossSize, CrossTop);
  //Canvas.LineTo(CrossLeft, CrossTop + CrossSize);
end;

procedure TForm1.DrawZero(i: Byte; j: Byte; CellSize: Word);
var
  CircleDiameter: Integer;
  CircleRadius: Integer;
  CircleMargin : Integer;
  CircleLeft, CircleTop: Integer;
  ARect : TRect;
begin
  CircleDiameter := Round(CellSize*0.8); // Diameter of the circle (50 pixels)
  CircleRadius := CircleDiameter div 2;
  CircleMargin := CellSize div 2 - CircleRadius;

  CircleLeft := i*CellSize + CircleMargin; // Calculate the left position of the circle
  CircleTop := j*CellSize + CircleMargin; // Calculate the top position of the circle

  // Set the pen properties for the circle
  if (i=XLast) and (j=Ylast) then Canvas.Stroke.Color := TAlphaColors.Black//clBlack
                             else Canvas.Stroke.Color := TAlphaColors.Blue;//clBlue;
  Canvas.Stroke.Thickness := 3;
  ARect:= TRect.Create(CircleLeft, CircleTop, CircleLeft + CircleDiameter, CircleTop + CircleDiameter);
  // Draw the circle
  Canvas.DrawEllipse(ARect,100);
  //Canvas.Ellipse(CircleLeft, CircleTop, CircleLeft + CircleDiameter, CircleTop + CircleDiameter);
end;

constructor TThreadRenew.Create;
begin
  inherited Create(False);  //Автозапуск потока
  MainFlag := True;
end;

destructor TThreadRenew.Destroy;
begin
  inherited  Destroy;
end;





procedure TThreadRenew.Execute;
begin
  while MainFlag do
    begin
      if HardTurnOn then
        begin
         HardTurn(MainField,0,0);
         HardTurnOn := False;
         Form1.Invalidate;
        end;
      Sleep(50);
    end;
end;




end.
