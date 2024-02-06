unit Fields;

//{$DEFINE SetError}
//{$DEFINE DeepArr}

interface
uses Debug,SysUtils
{$IFDEF FMX}
,FMX.Forms
{$ENDIF}
;
const
  GridSize = 16; // Size of the grid (16x16)
  XIndex :array[0..7] of ShortInt = (-1,-1,-1,0,1,1,1,0);
  YIndex :array[0..7] of ShortInt = (1,0,-1,-1,-1,0,1,1);
  MaxDeep = 10;
type
TFPoint = Record
  Color : Byte;   //0 - нолик 1-ничего  2- крестик
  Figure : Array[0..7] of int16;  //0-вправо вверх, 1-слева направо 2- вправо -вниз, 3 - сверху вниз  и т.д.
End;

TFMax = Record
  X,Y:Byte;
  ScoreP,ScoreN : Integer;
  Turn : Byte;
end;

TMaxArr = Array of Integer;



TFigure = Record
  Color : Byte;
  StartX,StartY :Byte;
  Length : Byte;
  Hole : Boolean;
  Turn : Byte; //4..7
  BlockStart:Boolean;
  BLockEnd:Boolean;
  Score : Byte;
  //Rx : Boolean;
  //Ry : int8;
end;

TField = class(TObject)
Data : Array[0..GridSize-1,0..GridSize-1] of TFPoint; //0 - нолик 1-ничего  2- крестик
Figures : Array of TFigure;
constructor Create(Noinit:Boolean=False);
destructor Destroy;
procedure Copy(var F:TField);
procedure SetFigures(X,Y,i,Holemul:Byte);
procedure FindFigures(X,Y:Byte);
procedure FindBlocks(X,Y:Byte);
procedure IncLength(i:Word);
procedure RefreshScore(i:Word);
procedure SetData(i,j:Byte;Color:Word);
procedure CloseHole(I:Integer;Color:Byte);
Function  AppendF(I:Integer):Boolean;
Function  AppendHard(Max:TMaxArr;TurnColor:Byte;RecDeep:Word;var Score:Double):Boolean;
Function  AppendSide(i:Integer;Start:Boolean;Color:Byte):Boolean;
Function  AppendMode(i:Integer;Mode:Byte;Color:Byte):Boolean;
procedure Join(i:Integer; Turn,X,Y:byte;Holemul:Byte);
Procedure GetFreePlace(X,Y:Int8;Zone:Int8; StopColor:Byte;var Score:Int8);
procedure FindFreeTurn(TurnColor:Int8);
procedure Split(X,Y:Int8;i:Integer);
function CenterHole(X,Y:Int8;i:Integer):Boolean;
procedure Combine(X,Y:Int8;i,i2:Integer);
procedure RefreshFigure(X,Y,Turn,Offset:Int8;i,OldI:Integer);
procedure RefreshCombine(X,Y,Turn,Offset:Int8;i:Integer;First,Last:Boolean);
procedure GetEnd(var X,Y:Int8;i:Integer);

end;

var
  MainField : TField;
  Win,Lose : Boolean;
  Debug : TDebug;
  XLast,YLast:Byte;
  DeepArray : Array [0..10] of String;
  GDeep : Byte;
  NTurn : Word;

Procedure SimpleTurn(TurnColor:Int8);
function OutOfBounds(X,Y:int8):Boolean;
Function HardTurn(Field:TField;TurnColor:Byte;RecDeep:Word):Double;

implementation
constructor TField.Create;
var  i,j,k:Byte;
begin
  if Not Noinit then
  for I := 0 to GridSize-1 do
   for J := 0 to GridSize-1 do
    begin
      Data[i,j].Color := 1;
      for k := 0 to 7 do
        Data[i,j].Figure[k] := -1;
    end;

  SetLength(Figures,0);
end;

destructor TField.Destroy;
var  i,j:Byte;
begin
  SetLength(Figures,0);
  SetLength(Figures,0);
end;

procedure TField.Copy;
var  i,j:Byte;
begin
   F.Data := Data;
   SetLength(F.Figures,Length(Figures));
   if Length(Figures)>0 then F.Figures := System.Copy(Figures,0,Length(Figures));
end;

function TField.CenterHole;
var k:int8;
j,j2 : Integer;
begin
  result := False;
  k:=(i+4) mod 8;
  j2 := Data[X+XIndex[i],Y+YIndex[i]].Figure[k];
  j := Data[X+XIndex[k],Y+YIndex[k]].Figure[i];
  if (j2=j) and (Figures[j].Hole) then
    begin
      Figures[j].Hole := False;
      IncLength(j);
      Data[X,Y].Figure[k] := j;
      result:=True;
  end;
end;

procedure TField.Combine(X,Y:Int8;i,i2:Integer);
var l,m:Int8;
First,Last :Boolean;
begin
  Figures[i].Length := Figures[i].Length +  Figures[i2].Length;
  RefreshScore(i);
  l:=0;
  m:=0;

 if (i2 =16) and (i=22) then
   l:=0;

  if Figures[i2].Length=0 then
    begin
      l:=0;
      exit;
    end;



  with Figures[i] do
    repeat
      if OutofBounds(StartX+l*XIndex[Turn],StartY+l*YIndex[Turn]) then
       begin
         break;
         m:=Length;
       end;

      if Data[StartX+l*XIndex[Turn],StartY+l*YIndex[Turn]].Color=Color  then
        begin
          inc(m);
          First := m=1; //Первый элемент
          Last  := m=Length;
          RefreshCombine(StartX,StartY,Turn,l,i,First,Last);
        end;
      inc(l);
    until m=Length;
  if l-m>1 then
    begin
      m:=Figures[i2].Length;
    end;

  Figures[i2].Length := 0;
  RefreshScore(i2);
  Data[X,Y].Figure[Figures[i].Turn] := i;
  Data[X,Y].Figure[Figures[i].Turn-4] := i;
end;


procedure TField.FindFigures(X,Y:Byte);  //А если вываливаемся за границы массива?
var i,k,l:int8;
j,j2,j3 :Integer;
begin
  for i := 0 to 7 do
    begin
      if Data[X,Y].Figure[i]>=0 then continue;
      if OutOfBounds(X+XIndex[i],Y+YIndex[i]) then continue;
      if Data[X+XIndex[i],Y+YIndex[i]].Color=Data[X,Y].Color then
        begin
           k:=(i+4) mod 8;
           j  := Data[X+XIndex[i],Y+YIndex[i]].Figure[i];
           j2 := Data[X+XIndex[i],Y+YIndex[i]].Figure[k];
             if (j2>=0) and (i<4) then  //xvx  //and (CenterHole(X,Y,i))) then // xvx
               begin
                 if OutOfBounds(X+XIndex[k],Y+YIndex[k]) then j3:=-1
                 else j3 := Data[X+XIndex[k],Y+YIndex[k]].Figure[k];
                 if ((j>=0) and (j<>j2)) or ((j3>=0) and (j3<>j2)) then
                   begin
                     if ((j>=0) and (j<>j2)) then
                       begin
                         Figures[j2].StartX := Figures[j].StartX;
                         Figures[j2].StartY := Figures[j].StartY;
                         Combine(X,Y,j2,j);
                       end
                     else Combine(X,Y,j2,j3);
                   end
                 else CenterHole(X,Y,i);
               end
             else
               if j>=0 then
                 begin
                   j2 := Data[X,Y].Figure[k];
                   if (i>=4) and (j2>=0) and (Figures[j2].Length>0) and((Figures[j].Hole=False) or (Figures[j2].Hole=False)) then  //Спорная вставка
                     Combine(X,Y,j2,j)
                   else Join(j,i,X,Y,1);
                 end
               else
                 if Data[X,Y].Figure[k]>=0 then  //С другой стороны проставили фигуру
                   Join(Data[X,Y].Figure[k],k,X+XIndex[i],Y+YIndex[i],1)
                 else
                   SetFigures(X,Y,i,1); // Есть две точки одного цвета, но фигуры ещё нет
        end
      else
        begin
         if OutOfBounds(X+2*XIndex[i],Y+2*YIndex[i]) then continue;
         if (Data[X+2*XIndex[i],Y+2*YIndex[i]].Color=Data[X,Y].Color) and
         (abs(Data[X+XIndex[i],Y+YIndex[i]].Color-Data[X,Y].Color)<>2) //Нет вражеского знака в дыре.
         then //Простроение дыры
          begin
            j :=Data[X+2*XIndex[i],Y+2*YIndex[i]].Figure[i];
            k:=(i+4) mod 8;
            if (j>=0) and (Figures[j].Hole=False) then
              begin
               j2 := Data[X,Y].Figure[k];
               if (j2>=0) and (Figures[j2].Hole=False) then
                 begin
                  Combine(X,Y,j2,j);//Обьединение фигур
                  Figures[j2].Hole := True;
                  RefreshScore(j2);
                 end
               else Join(j,i,X,Y,2)//Присоединиться к фигуре
              end
            else
              if (Data[X,Y].Figure[k]>=0) and (Figures[Data[X,Y].Figure[k]].Hole=False) then
                Join(Data[X,Y].Figure[k],k,X+2*XIndex[i],Y+2*YIndex[i],2)
              else SetFigures(X,Y,i,2);
          end;
       end;
    end;
end;



procedure TField.Join;
var X1,Y1 : int8;
begin
  Figures[i].Hole := Figures[i].Hole or (Holemul=2); //Была дыра? Значит остаётся после Join
  X1 := X-XIndex[Turn]; //Смотрим точку в противоположном направлении
  Y1 := Y-YIndex[Turn];
  if Turn>=4 then
   begin
     Figures[i].StartX := X;
     Figures[i].StartY := Y;
     if OutofBounds(X1,Y1) or (abs(Data[X,Y].Color-Data[X1,Y1].Color)=2) then Figures[i].BlockStart := True;  //Пересчёт блокировок при соединении.
  end
  else
    if OutofBounds(X1,Y1) or (abs(Data[X,Y].Color-Data[X1,Y1].Color)=2) then Figures[i].BlockEnd := True;
  Data[X+Holemul*XIndex[Turn],Y+Holemul*YIndex[Turn]].Figure[(Turn+4) mod 8] := i;
  Data[X,Y].Figure[Turn] := i;
  IncLength(i);
end;

procedure TField.SetFigures;
var
Buf : TFigure;
k:Byte;
j:Integer;
//GridX,GridY:Byte;
StartPX, StartPY:int8;
EndPX,EndPY:int8;
begin
  k:= (i + 4) mod 8;
  Buf.Color:=Data[X,Y].Color;
  if i<4 then
    begin
      Buf.StartX := X+Holemul*XIndex[i];
      Buf.StartY := Y+Holemul*YIndex[i];
      StartPX := X+(Holemul+1)*XIndex[i];
      StartPY := Y+(Holemul+1)*YIndex[i];
      EndPX := X-XIndex[i];
      EndPY := Y-YIndex[i];
    end
  else
    begin
      Buf.StartX := X;
      Buf.StartY := Y;
      StartPX := X-XIndex[i];
      StartPY := Y-YIndex[i];
      EndPX := X+(Holemul+1)*XIndex[i];
      EndPY := Y+(Holemul+1)*YIndex[i];
    end;
  Buf.Length := 2;
  Buf.Hole := (Holemul=2);
  if Buf.Hole  then      //Для отладки
    Buf.Length := 2;

  if abs(Data[X,Y].Color-Data[X+XIndex[i],Y+YIndex[i]].Color)=2 then exit;//Центр заблокирован
  Buf.Turn := (i mod 4) + 4; //5..8
  Figures := Figures +[Buf];
  j := Length(Figures)-1;
 

  Data[X,Y].Figure[i] := j;
  Data[X+Holemul*XIndex[i],Y+Holemul*YIndex[i]].Figure[k] := j;
  //Для каждой из двух соседних точек проверяем, не блокирует ли она свежесозданную фигуру.
  if OutOfBounds(StartPX,StartPY) then Figures[j].BlockStart := True
  else
    begin
      Figures[j].BlockStart := False;
      if abs(Data[X,Y].Color-Data[StartPX,StartPY].Color)=2 then Figures[j].BlockStart := True;
      //FindBlocks(StartPX,StartPY);
    end;
  if OutOfBounds(EndPX,EndPY) then Figures[j].BlockEnd := True
  else
    begin
      Figures[j].BlockEnd := False;
       if abs(Data[X,Y].Color-Data[EndPX,EndPY].Color)=2 then Figures[j].BlockEnd := True;
      //FindBlocks(EndPX,EndPY);
    end;
  RefreshScore(j);
end;


procedure TField.RefreshFigure;
var AntiTurn:Integer;
First,Last :Boolean;
begin
  AntiTurn :=(Turn+4) mod 8;
  First := Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[AntiTurn]<>OldI;
  Last  := Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[Turn]<>OldI;
  RefreshCombine(X,Y,Turn,Offset,i,First,Last);
  //if Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[Turn]=OldI then
  //  Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[Turn]:=i;
  //if Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[AntiTurn]=OldI then
   // Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[AntiTurn]:=i;
end;

procedure TField.RefreshCombine;
var AntiTurn:Integer;
begin
  AntiTurn :=(Turn+4) mod 8;
  if not Last then
    Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[Turn]:=i;
  if not First then
    Data[X+Offset*XIndex[Turn],Y+Offset*YIndex[Turn]].Figure[AntiTurn]:=i;
end;

procedure TField.GetEnd(var X: ShortInt; var Y: ShortInt; i: Integer);
var
l:byte;
begin
  with Figures[i] do
    begin
      l := Length;
      if not Hole then dec(l);
      X  := StartX + l*XIndex[Turn];
      Y  := StartY + l*YIndex[Turn];
    end;
end;

procedure TField.Split(X: ShortInt; Y: ShortInt; i: Integer);
var
Buf : TFigure;
l:byte;
AntiTurn,Turn:Int8;
EndX,EndY : Int8;
k,j: Integer;
begin
  GetEnd(EndX,EndY,i);
  Buf.BLockEnd := Figures[i].BLockEnd;
  Buf.BlockStart := True;
  Buf.Color := Figures[i].Color;
  Figures[i].BlockEnd := True;
  Figures[i].Hole := False;
  Turn:=Figures[i].Turn;
  AntiTurn := (Turn +4) mod 8;
  //k:=(j+4) mod 8;
  Buf.Turn := Turn;
  Buf.StartX := X+XIndex[Turn];
  Buf.StartY := Y+YIndex[Turn];
  Buf.Hole := False;


  if XIndex[Figures[i].Turn]<>0 then l:=abs(Figures[i].StartX-X)
                                else l:=abs(Figures[i].StartY-Y);
  if l>Figures[i].Length then
    begin
      Buf.Hole := False;
      Exit;
    end;
  Buf.Length := Figures[i].Length-l;
  Figures[i].Length := l;
  RefreshScore(i);
  if l=1 then RefreshFigure(Figures[i].StartX,Figures[i].StartY,Turn,0,-1,i);
  j := Data[Figures[i].StartX,Figures[i].StartY].Figure[AntiTurn];
  if (j>-1) and (j<>i) and (Figures[j].Length>0) then
    begin
      dec(Figures[j].Length);
      Combine(Figures[i].StartX,Figures[i].StartY,j,i);
    end;
  if Buf.Length>1 then
    begin
      Figures := Figures+[buf];
      k := Length(Figures)-1;
      RefreshScore(i);
      for l := 0 to Buf.Length-1 do RefreshFigure(Buf.StartX,Buf.StartY,Turn,l,k,i);
    end
  else RefreshFigure(Buf.StartX,Buf.StartY,Turn,0,-1,i);
  j := Data[EndX,EndY].Figure[Turn];
  if (j>-1) and (Buf.Length>1) and (j<>Length(Figures)-1) and (Figures[j].Length>0)  then
    begin
      dec(Figures[j].Length);
      Figures[j].StartX := Buf.StartX;
      Figures[j].StartY := Buf.StartY;
      Combine(Buf.StartX,Buf.StartY,j,Length(Figures)-1);
    end;

end;

procedure TField.FindBlocks(X: Byte; Y: Byte);
var i:byte;
j:Integer;
k:Int8;
begin
 if OutOfBounds(X,Y) then exit;
 if Data[X,Y].Color=1 then exit;
 for i := 0 to 7 do
    begin
      if OutOfBounds(X+XIndex[i],Y+YIndex[i]) then continue;
      if  abs(Data[X+XIndex[i],Y+YIndex[i]].Color-Data[X,Y].Color)>=2 then  //Действительно есть блок
        begin
          k:=(i+4) mod 8;
          if not(OutOfBounds(X-XIndex[i],Y-YIndex[i])) and
          (abs(Data[X-XIndex[i],Y-YIndex[i]].Color-Data[X,Y].Color)>=2)  then
           begin
             j:=Data[X+XIndex[i],Y+YIndex[i]].Figure[k];
             if j>=0 then
              begin
                if i<4 then Split(X,Y,j);
                continue;
              end;
           end;
          j :=Data[X+XIndex[i],Y+YIndex[i]].Figure[i];
          if j>=0 then
            begin
              if i>=4 then Figures[j].BlockStart := True
              else Figures[j].BlockEnd := True;
              RefreshScore(j);
            end;
        end;
    end;
end;

procedure TField.IncLength(i: Word);
begin
  inc(Figures[i].Length);
  RefreshScore(i);
end;

procedure TField.RefreshScore(i: Word);
var
  PotentialLength,l:Int8;
begin
with  Figures[i] do
begin
  Score:=Length*2;
  PotentialLength := Length;
  if Score=0 then exit;

  if Hole and (Score>=10) then
    begin
      Score:=8;
      exit;
    end;
  //else
  if not Hole then
    if Length=5 then exit;
  if (BlockStart) and (BlockEnd) then
    if (Score<7) or (not Hole) then Score := 0
                               else
                               //else Score := Score - 2
  else
   if (Score<7) {or (not Hole)} then
    begin
      if BlockStart then Score := Score - 2 //x0000 > 000
      else
        begin
          GetFreePlace(StartX,StartY,Turn-4,Color xor 2,l);
          PotentialLength := PotentialLength +l;
        end;
      if BlockEnd then
        begin
          Score := Score - 2;  //x000  = 00
          if Hole then inc(PotentialLength);
        end
      else
        begin
          GetFreePlace(StartX+(Length-1)*XIndex[Turn],StartY+(Length-1)*YIndex[Turn],Turn,Color xor 2,l);
          PotentialLength := PotentialLength +l;
        end;
     if PotentialLength<5 then
     Score := 0;
    end;
end;
end;

procedure TField.SetData;
begin
  if OutofBounds(i,j) then
    begin
      Color := 1;
      exit;
    end;
  {$IFDEF DeepArr}
  if gdeep>0 then
    DeepArray[GDeep]:= IntToStr(i)+':'+IntToStr(j)+':'+IntToStr(Color);
  {$ENDIF}

  {$IFDEF SetError}
  if (Data[i,j].Color<>1) then
   begin
    if (DebugFLag)  then Debug.Log('SetError: '+IntToStr(i)+':'+IntToStr(j));
    exit;
   end;

  {$ENDIF}



  Data[i,j].Color := Color;
  FindFigures(i,j);
  FindBlocks(i,j);
  if (DebugFLag) and (Self=MainField) then  Debug.Log(IntToStr(i)+':'+IntToStr(j)+':'+IntToStr(Color));
  if Self=MainField then
    begin
      XLast := i;
      YLast := j;
      inc(NTurn);
    end;

end;

Procedure TField.CloseHole(I:Integer;Color:Byte); //Скорее всего в TField
var
j:Integer;
Hole : Int8;
X1,Y1 :Int8;
Turn : Byte;
begin
  X1 :=  Figures[i].StartX;
  Y1 :=  Figures[i].StartY;
  Turn := Figures[i].Turn;
  GetFreePlace(X1,Y1,Turn,1,Hole);//
  X1:=X1+(Hole+1)*XIndex[Turn];
  Y1:=Y1+(Hole+1)*YIndex[Turn];
  if OutOfBounds(X1,Y1) then
    Turn:=0; //For Debug

  SetData(X1,Y1,Color);
end;

Function TField.AppendSide;
var
B:Boolean;
k : int8;
X1,Y1 :Int8;

begin
  result:=False;
  if Start then
    begin
      B := Figures[i].BlockStart;
      k := -1;
    end
  else
    begin
       B := Figures[i].BlockEnd;
       k := Figures[i].Length;
       if Figures[i].Hole then inc(k);
    end;
  if not B then
    begin
       X1 := Figures[i].StartX+k*XIndex[Figures[i].Turn];
       Y1 := Figures[i].StartY+k*YIndex[Figures[i].Turn];
       if (not OutOfBounds(X1,Y1)) and (Data[X1,Y1].Color=1) then
         begin
           SetData(X1,Y1,Color);
           result:=True;
         end
       else
         begin
            if Start then Figures[i].BlockStart := True
                     else Figures[i].BlockEnd := True;
            RefreshScore(i);
         end;
    end;

end;

Function TField.AppendF(I:Integer):Boolean;  //Скорее всего в TField
var
X1,Y1 :Byte;
begin
  result := True;
  if Figures[i].Hole then CloseHole(i,0)
  else  //
    begin
      if AppendSide(I,True,0) then exit;
      if AppendSide(I,False,0) then exit;
      result := false;
   end;
end;

Function TField.AppendMode;
begin
  case Mode of
    0:
      if Figures[i].Hole then
         begin
           CloseHole(i,Color);
           result := True;
         end
       else result := False;
    1: result := AppendSide(I,True,Color);
    2: result := AppendSide(I,False,Color);
  end;
end;

Function TField.AppendHard;  // AppendHard(Max:TMaxArr;TurnColor:Byte;RecDeep:Word;var Score:Integer):Boolean;
var i,j:Integer;
F:TField;
YesTurn : Boolean;
ScorePr : Double;
imax,jmax : Integer;
begin
   result := False;
   F := TField.Create(True);
   if (TurnColor=0) then Score := -1000
                    else Score := 1000;
   imax:=-1;


   for i:=0 to Length(Max)-1 do
   for j:=0 to 2 do
     begin
       Copy(F);
       {$IFDEF DeepArr}
       GDeep := RecDeep;
       {$ENDIF}
       YesTurn :=F.AppendMode(Max[i],j,TurnColor);      //Надо пробовать разные варианты Append , а сейчас пробуется только некоторые
       if (YesTurn) then
         begin
           ScorePr := HardTurn(F,TurnColor xor 2,RecDeep);
           if (TurnColor=0) and (ScorePr>Score) then //Выбираем лучшую игру компьютера
             begin
               Result := True;
               Score := ScorePr;
               imax:=i;
               jmax:=j;

             end;
           if (TurnColor=2) and (ScorePr<Score) then //Предполагаем, что игрок играет лучше всего
             begin
               Result := True;
               Score := ScorePr;
               imax:=i;
               jmax:=j;
             end;
         end;
     end;
   F.Destroy;
   if (imax>-1) and (RecDeep<2) then
     AppendMode(Max[imax],jmax,TurnColor); //Делаем реальный ход
end;


Procedure TField.GetFreePlace(X,Y:Int8;Zone:Int8; StopColor:Byte;var Score:Int8);
var i:Integer;
X1,Y1:Int8;
begin
  Score := 0;
  for i := 1 to 4 do
    begin
      X1:=X+i*XIndex[Zone];
      Y1:=Y+i*YIndex[Zone];
      if OutOfBounds(X1,Y1) then break;
      if (Data[X1,Y1].Color=StopColor) then break;
      Score := i;
    end;
end;



procedure TField.FindFreeTurn;
var I,J,K,M: Integer;
Zone :Byte;
Max : TFMax;
ScoreP,ScoreN:Int8;
begin
    begin
       Max.ScoreP := 0;
       Max.ScoreN := 0;
       for I := 0 to GridSize-1 do
         for J := 0 to GridSize-1 do
           if Data[i,j].Color=TurnColor then
             begin
               for k := 0 to 3 do
                 begin
                   GetFreePlace(i,j,k,TurnColor xor 2,ScoreP);
                   GetFreePlace(i,j,k+4,TurnColor xor 2,ScoreN);
                   if (ScoreP+ScoreN)>(Max.ScoreP+Max.ScoreN) then
                      begin
                        Max.X := i;
                        Max.Y := j;
                        Max.ScoreP := ScoreP;
                        Max.ScoreN := ScoreN;
                        if  Max.ScoreP>Max.ScoreN then Max.Turn := k
                                                  else Max.Turn := k+4;
                      end;
                 end;
             end;
       if (Max.ScoreP+Max.ScoreN)>=4 then
         begin
           SetData(Max.X+XIndex[Max.Turn],Max.Y+YIndex[Max.Turn],TurnColor);
           exit;
         end;

       for I := 0 to GridSize-1 do
         for J := 0 to GridSize-1 do
           if Data[i,j].Color=(TurnColor xor 2) then
             begin
               Zone := Random(2);
               if i=GridSize-1 then Zone :=0;
               if j<(GridSize div 2) then  Zone := 7-Zone
                                     else  Zone := Zone + 3;
               if Data[i+XIndex[Zone],j+YIndex[Zone]].Color=1 then //Ставим только в пустую клетку
                 begin
                   SetData(i+XIndex[Zone],j+YIndex[Zone],TurnColor);
                   exit;
                 end;
             end;
       repeat   //Когда ничего не помогает ставим рандом.
        I := Random(GridSize);
        J := Random(GridSize);
      until Data[I,J].Color=1 ;
      SetData(I,J,TurnColor);
    end;
end;

Procedure SimpleTurn;
var
Max:Array[0..2] of Integer;
Score:Array[0..2] of Int8;
i:Int8;
Color : Int8;
YesTurn:Boolean;
begin
  if Length(MainField.Figures)=0 then MainField.FindFreeTurn(TurnColor)
  else
    repeat
    YesTurn := True;
      for I := 0 to 2 do
        begin
          Score[i] := 0;
          Max[i] :=-1;
        end;
      for I := 0 to Length(MainField.Figures)-1 do
        begin
          Color := MainField.Figures[i].Color;
          if MainField.Figures[i].Score>Score[Color] then
            begin
              MainField.RefreshScore(i);
              if  MainField.Figures[i].Score<=Score[Color] then continue;
              Score[Color] := MainField.Figures[i].Score;
              Max[Color] := i;
            end;
        end;
      if Score[2]>=10 then
        begin
          Win := True;
          exit;
        end;
      if (Max[0]<0) and (Max[2]<0) then MainField.FindFreeTurn(TurnColor)
      else
        if Score[2]>Score[0] then YesTurn :=MainField.AppendF(Max[2])
        else YesTurn := MainField.AppendF(Max[0]);
    until YesTurn;  //Зачем нужен, если циклы индентичные?
    for I := 0 to Length(MainField.Figures)-1 do
      if (MainField.Figures[i].Score>=10) and (MainField.Figures[i].Color=0)  then Lose := True;
end;

Function HardTurn(Field:TField;TurnColor:Byte;RecDeep:Word):Double; // Возвращает количество очков
var
Max:Array[0..2] of TMaxArr;
Score:Array[0..2] of Int8;
ScoreDeep : Double;
i:Integer;
Color : Int8;
YesTurn:Boolean;
begin
  //{$IFDEF FMX} if RecDeep<4 then Application.ProcessMessages; {$ENDIF}
  result := 0;
  if Length(Field.Figures)=0 then Field.FindFreeTurn(TurnColor)
  else
    begin//repeat
    YesTurn := True;
      for I := 0 to 2 do
        begin
          Score[i] := 0;
          SetLength(Max[i],1);
          Max[i,0] :=-1;
        end;
      for I := 0 to Length(Field.Figures)-1 do
        begin
          Color := Field.Figures[i].Color;
          if Field.Figures[i].Score>=Score[Color] then Field.RefreshScore(i);
          if Field.Figures[i].Score>Score[Color] then
            begin
              Score[Color] := Field.Figures[i].Score;
              SetLength(Max[Color],1);
              Max[Color,0] := i;
            end
          else
            if  Field.Figures[i].Score=Score[Color] then Max[Color] :=  Max[Color] + [i];
        end;
      if (RecDeep=0) and (Score[2]>=10) then
        begin
          Win := True;
          exit;
        end;
      if (Max[0,0]<0) and (Max[2,0]<0) then 
        begin
          Field.FindFreeTurn(TurnColor);
          Result := 0;
        end
      else
        begin
         YesTurn:=True;
         if (RecDeep<MaxDeep) and (Score[2]<10) and (Score[0]<10) then
           begin
             if Score[TurnColor xor 2]>Score[TurnColor] then YesTurn :=Field.AppendHard(Max[TurnColor xor 2],TurnColor,RecDeep+1,result)
             else YesTurn := Field.AppendHard(Max[TurnColor],TurnColor,RecDeep+1,result);
           end;
         if (RecDeep=MaxDeep) or (Score[2]>=10) or (Score[0]>=10)  or (not YesTurn) then
          begin
            if Score[2]>Score[0] then Result := -Score[2]-0.01*Length(Max[2])+0.01*RecDeep
                                 else Result :=  Score[0]+0.01*Length(Max[0])-0.01*RecDeep; //Лучше к победе прийди быстрее, а к поражению дольше
            if (RecDeep=0) and (not YesTurn) then Field.FindFreeTurn(TurnColor);
          end;
        end;
    end;//until YesTurn;
    if RecDeep=0 then for I := 0 to Length(Field.Figures)-1 do
      if (Field.Figures[i].Score>=10) and (Field.Figures[i].Color=0)  then Lose := True;
end;


function OutOfBounds(X,Y:int8):Boolean;
begin
 result := False;
 if (X<0) or (Y<0) then result := True;
 if (X>=GridSize) or (Y>=GridSize) then result := True;
end;

end.
