(*
 * Hedgewars, a worms-like game
 * Copyright (c) 2004-2007 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *)

unit uGears;
interface
uses SDLh, uConsts, uFloat;
{$INCLUDE options.inc}
const AllInactive: boolean = false;

type PGear = ^TGear;
     TGearStepProcedure = procedure (Gear: PGear);
     TGear = record
             NextGear, PrevGear: PGear;
             Active: Boolean;
             State : Longword;
             X : hwFloat;
             Y : hwFloat;
             dX: hwFloat;
             dY: hwFloat;
             Kind: TGearType;
             Pos: Longword;
             doStep: TGearStepProcedure;
             Radius: LongInt;
             Angle, Power : Longword;
             DirAngle: real;
             Timer : LongWord;
             Elasticity: hwFloat;
             Friction  : hwFloat;
             Message, MsgParam : Longword;
             Hedgehog: pointer;
             Health, Damage: LongInt;
             CollisionIndex: LongInt;
             Tag: LongInt;
             Tex: PTexture;
             Z: Longword;
             IntersectGear: PGear;
             TriggerId: Longword;
             end;

function  AddGear(X, Y: LongInt; Kind: TGearType; State: Longword; dX, dY: hwFloat; Timer: LongWord): PGear;
procedure ProcessGears;
procedure SetAllToActive;
procedure SetAllHHToActive;
procedure DrawGears(Surface: PSDL_Surface);
procedure FreeGearsList;
procedure AddMiscGears;
procedure AddClouds;
procedure AssignHHCoords;
procedure InsertGearToList(Gear: PGear);
procedure RemoveGearFromList(Gear: PGear);

var CurAmmoGear: PGear = nil;
    GearsList: PGear = nil;
    KilledHHs: Longword = 0;

implementation
uses uWorld, uMisc, uStore, uConsole, uSound, uTeams, uRandom, uCollisions,
     uLand, uIO, uLandGraphics, uAIMisc, uLocale, uAI, uAmmos, uTriggers, GL;

const MAXROPEPOINTS = 300;
var RopePoints: record
                Count: Longword;
                HookAngle: GLfloat;
                ar: array[0..MAXROPEPOINTS] of record
                                  X, Y: hwFloat;
                                  dLen: hwFloat;
                                  b: boolean;
                                  end;
                 end;
    StepDamage: Longword = 0;

procedure DeleteGear(Gear: PGear); forward;
procedure doMakeExplosion(X, Y, Radius: LongInt; Mask: LongWord); forward;
procedure AmmoShove(Ammo: PGear; Damage, Power: LongInt); forward;
procedure AmmoFlameWork(Ammo: PGear); forward;
function  CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear; forward;
procedure SpawnBoxOfSmth; forward;
procedure AfterAttack; forward;
procedure FindPlace(Gear: PGear; withFall: boolean; Left, Right: LongInt); forward;
procedure HedgehogStep(Gear: PGear); forward;
procedure HedgehogChAngle(Gear: PGear); forward;
procedure ShotgunShot(Gear: PGear); forward;
procedure AddDamageTag(X, Y, Damage: LongWord; Gear: PGear); forward;

{$INCLUDE GSHandlers.inc}
{$INCLUDE HHHandlers.inc}

const doStepHandlers: array[TGearType] of TGearStepProcedure = (
                                                               @doStepCloud,
                                                               @doStepBomb,
                                                               @doStepHedgehog,
                                                               @doStepGrenade,
                                                               @doStepHealthTag,
                                                               @doStepGrave,
                                                               @doStepUFO,
                                                               @doStepShotgunShot,
                                                               @doStepPickHammer,
                                                               @doStepRope,
                                                               @doStepSmokeTrace,
                                                               @doStepExplosion,
                                                               @doStepMine,
                                                               @doStepCase,
                                                               @doStepDEagleShot,
                                                               @doStepDynamite,
                                                               @doStepTeamHealthSorter,
                                                               @doStepBomb,
                                                               @doStepCluster,
                                                               @doStepShover,
                                                               @doStepFlame,
                                                               @doStepFirePunch,
                                                               @doStepActionTimer,
                                                               @doStepActionTimer,
                                                               @doStepActionTimer,
                                                               @doStepParachute,
                                                               @doStepAirAttack,
                                                               @doStepAirBomb,
                                                               @doStepBlowTorch,
                                                               @doStepGirder,
                                                               @doStepTeleport,
                                                               @doStepHealthTag,
                                                               @doStepSwitcher,
                                                               @doStepCase
                                                               );

procedure InsertGearToList(Gear: PGear);
var tmp: PGear;
begin
if GearsList = nil then
   GearsList:= Gear
   else begin
   // WARNING: this code assumes that the first gears added to the list are clouds (have maximal Z)
   tmp:= GearsList;
   while (tmp <> nil) and (tmp^.Z < Gear^.Z) do
          tmp:= tmp^.NextGear;

   if tmp^.PrevGear <> nil then tmp^.PrevGear^.NextGear:= Gear;
   Gear^.PrevGear:= tmp^.PrevGear;
   tmp^.PrevGear:= Gear;
   Gear^.NextGear:= tmp;
   if GearsList = tmp then GearsList:= Gear
   end
end;

procedure RemoveGearFromList(Gear: PGear);
begin
if Gear^.NextGear <> nil then Gear^.NextGear^.PrevGear:= Gear^.PrevGear;
if Gear^.PrevGear <> nil then Gear^.PrevGear^.NextGear:= Gear^.NextGear
   else begin
   GearsList:= Gear^.NextGear;
   if GearsList <> nil then GearsList^.PrevGear:= nil
   end;
end;

function AddGear(X, Y: LongInt; Kind: TGearType; State: Longword; dX, dY: hwFloat; Timer: LongWord): PGear;
const Counter: Longword = 0;
var Result: PGear;
begin
inc(Counter);
{$IFDEF DEBUGFILE}AddFileLog('AddGear: ('+inttostr(x)+','+inttostr(y)+'), d('+floattostr(dX)+','+floattostr(dY)+')');{$ENDIF}
New(Result);
{$IFDEF DEBUGFILE}AddFileLog('AddGear: type = ' + inttostr(ord(Kind)));{$ENDIF}
FillChar(Result^, sizeof(TGear), 0);
Result^.X:= int2hwFloat(X);
Result^.Y:= int2hwFloat(Y);
Result^.Kind := Kind;
Result^.State:= State;
Result^.Active:= true;
Result^.dX:= dX;
Result^.dY:= dY;
Result^.doStep:= doStepHandlers[Kind];
Result^.CollisionIndex:= -1;
Result^.Timer:= Timer;

if CurrentTeam <> nil then
   begin
   Result^.Hedgehog:= CurrentHedgehog;
   Result^.IntersectGear:= CurrentHedgehog^.Gear
   end;
   
case Kind of
       gtCloud: Result^.Z:= High(Result^.Z);
   gtAmmo_Bomb: begin
                Result^.Radius:= 4;
                Result^.Elasticity:= _0_6;
                Result^.Friction:= _0_995;
                end;
    gtHedgehog: begin
                Result^.Radius:= cHHRadius;
                Result^.Elasticity:= _0_35;
                Result^.Friction:= _0_999;
                Result^.Angle:= cMaxAngle div 2;
                Result^.Z:= cHHZ;
                end;
gtAmmo_Grenade: begin
                Result^.Radius:= 4;
                end;
   gtHealthTag: begin
                Result^.Timer:= 1500;
                Result^.Z:= 2001;
                end;
       gtGrave: begin
                Result^.Radius:= 10;
                Result^.Elasticity:= _0_6;
                end;
         gtUFO: begin
                Result^.Radius:= 5;
                Result^.Timer:= 500;
                Result^.Elasticity:= _0_9
                end;
 gtShotgunShot: begin
                Result^.Timer:= 900;
                Result^.Radius:= 2
                end;
  gtPickHammer: begin
                Result^.Radius:= 10;
                Result^.Timer:= 4000
                end;
  gtSmokeTrace: begin
                Result^.X:= Result^.X - _16;
                Result^.Y:= Result^.Y - _16;
                Result^.State:= 8
                end;
        gtRope: begin
                Result^.Radius:= 3;
                Result^.Friction:= _450;
                RopePoints.Count:= 0;
                end;
   gtExplosion: begin
                Result^.X:= Result^.X - _25;
                Result^.Y:= Result^.Y - _25;
                end;
        gtMine: begin
                Result^.State:= Result^.State or gstMoving;
                Result^.Radius:= 3;
                Result^.Elasticity:= _0_55;
                Result^.Friction:= _0_995;
                Result^.Timer:= 3000;
                end;
        gtCase: begin
                Result^.Radius:= 16;
                Result^.Elasticity:= _0_3
                end;
  gtDEagleShot: begin
                Result^.Radius:= 1;
                Result^.Health:= 50
                end;
    gtDynamite: begin
                Result^.Radius:= 3;
                Result^.Elasticity:= _0_55;
                Result^.Friction:= _0_03;
                Result^.Timer:= 5000;
                end;
 gtClusterBomb: begin
                Result^.Radius:= 4;
                Result^.Elasticity:= _0_6;
                Result^.Friction:= _0_995;
                end;
       gtFlame: begin
                Result^.Angle:= Counter mod 64;
                Result^.Radius:= 1;
                Result^.Health:= 2;
                Result^.dY:= (getrandom - _0_8) * _0_03;
                Result^.dX:= (getrandom - _0_5) * _0_4
                end;
   gtFirePunch: begin
                Result^.Radius:= 15;
                Result^.Tag:= Y
                end;
     gtAirBomb: begin
                Result^.Radius:= 5;
                end;
   gtBlowTorch: begin
                Result^.Radius:= cHHRadius + cBlowTorchC;
                Result^.Timer:= 7500;
                end;
 gtSmallDamage: begin
                Result^.Timer:= 1100;
                Result^.Z:= 2000;
                end;
    gtSwitcher: begin
                Result^.Z:= cCurrHHZ
                end;
      gtTarget: begin
                Result^.Radius:= 16;
                Result^.Elasticity:= _0_3
                end;
     end;
InsertGearToList(Result);
AddGear:= Result
end;

procedure DeleteGear(Gear: PGear);
var team: PTeam;
    t: Longword;
begin
DeleteCI(Gear);

if Gear^.Tex <> nil then
   begin
   FreeTexture(Gear^.Tex);
   Gear^.Tex:= nil
   end;

if Gear^.Kind = gtHedgehog then
   if CurAmmoGear <> nil then
      begin
      Gear^.Message:= gm_Destroy;
      CurAmmoGear^.Message:= gm_Destroy;
      exit
      end else
      begin
      if not (hwRound(Gear^.Y) < cWaterLine) then
         begin
         t:= max(Gear^.Damage, Gear^.Health);
         AddGear(hwRound(Gear^.X), hwRound(Gear^.Y), gtHealthTag, t, _0, _0, 0)^.Hedgehog:= Gear^.Hedgehog;
         inc(StepDamage, t)
         end;
      team:= PHedgehog(Gear^.Hedgehog)^.Team;
      if CurrentHedgehog^.Gear = Gear then
         FreeActionsList; // to avoid ThinkThread on drawned gear
      PHedgehog(Gear^.Hedgehog)^.Gear:= nil;
      inc(KilledHHs);
      RecountTeamHealth(team);
      end;
{$IFDEF DEBUGFILE}AddFileLog('DeleteGear');{$ENDIF}
if Gear^.TriggerId <> 0 then TickTrigger(Gear^.TriggerId);
if CurAmmoGear = Gear then CurAmmoGear:= nil;
if FollowGear = Gear then FollowGear:= nil;
RemoveGearFromList(Gear);
Dispose(Gear)
end;

function CheckNoDamage: boolean; // returns TRUE in case of no damaged hhs
var Gear: PGear;
begin
CheckNoDamage:= true;
Gear:= GearsList;
while Gear <> nil do
      begin
      if Gear^.Kind = gtHedgehog then
         if Gear^.Damage <> 0 then
            begin
            CheckNoDamage:= false;
            inc(StepDamage, Gear^.Damage);
            if Gear^.Health < Gear^.Damage then Gear^.Health:= 0
                                           else dec(Gear^.Health, Gear^.Damage);
            AddGear(hwRound(Gear^.X), hwRound(Gear^.Y) - cHHRadius - 12,
                    gtHealthTag, Gear^.Damage, _0, _0, 0)^.Hedgehog:= Gear^.Hedgehog;
            RenderHealth(PHedgehog(Gear^.Hedgehog)^);
            RecountTeamHealth(PHedgehog(Gear^.Hedgehog)^.Team);

            Gear^.Damage:= 0
            end;
      Gear:= Gear^.NextGear
      end;
end;

procedure AddDamageTag(X, Y, Damage: LongWord; Gear: PGear);
begin
if cAltDamage then
   AddGear(X, Y, gtSmallDamage, Damage, _0, _0, 0)^.Hedgehog:= Gear^.Hedgehog;
end;

procedure ProcessGears;
const delay: LongWord = 0;
      step: (stDelay, stChDmg, stChWin, stSpawn, stNTurn) = stDelay;
var Gear, t: PGear;
begin
AllInactive:= true;
t:= GearsList;
while t<>nil do
      begin
      Gear:= t;
      t:= Gear^.NextGear;
      if Gear^.Active then Gear^.doStep(Gear);
      end;

if AllInactive then
   case step of
        stDelay: begin
                 if delay = 0 then
                    delay:= cInactDelay
                 else
                    dec(delay);

                 if delay = 0 then
                    inc(step)
                 end;
        stChDmg: if CheckNoDamage then inc(step) else step:= stDelay;
        stChWin: if not CheckForWin then inc(step) else step:= stDelay;
        stSpawn: begin
                 if not isInMultiShoot then SpawnBoxOfSmth;
                 inc(step)
                 end;
        stNTurn: begin
                 //AwareOfExplosion(0, 0, 0);
                 if isInMultiShoot then isInMultiShoot:= false
                    else begin
                    with CurrentHedgehog^ do
                         if MaxStepDamage < StepDamage then MaxStepDamage:= StepDamage;
                    StepDamage:= 0;
                    ParseCommand('/nextturn', true);
                    end;
                 step:= Low(step)
                 end;
        end;

if TurnTimeLeft > 0 then
      if CurrentHedgehog^.Gear <> nil then
         if ((CurrentHedgehog^.Gear^.State and gstAttacking) = 0)
            and not isInMultiShoot then dec(TurnTimeLeft);

if (not CurrentTeam^.ExtDriven) and
   ((GameTicks and $FFFF) = $FFFF) then
   begin
   SendIPCTimeInc;
   inc(hiTicks) // we do not recieve a message for it
   end;

inc(GameTicks)
end;

procedure SetAllToActive;
var t: PGear;
begin
AllInactive:= false;
t:= GearsList;
while t <> nil do
      begin
      t^.Active:= true;
      t:= t^.NextGear
      end
end;

procedure SetAllHHToActive;
var t: PGear;
begin
AllInactive:= false;
t:= GearsList;
while t <> nil do
      begin
      if t^.Kind = gtHedgehog then t^.Active:= true;
      t:= t^.NextGear
      end
end;

procedure DrawHH(Gear: PGear; Surface: PSDL_Surface);
var t: LongInt;
begin
DrawHedgehog(hwRound(Gear^.X) - 15 + WorldDx, hwRound(Gear^.Y) - 18 + WorldDy,
             hwSign(Gear^.dX), 0,
             PHedgehog(Gear^.Hedgehog)^.visStepPos div 2,
             Surface);

with PHedgehog(Gear^.Hedgehog)^ do
     if (Gear^.State{ and not gstAnimation}) = 0 then
        begin
        t:= hwRound(Gear^.Y) - cHHRadius - 10 + WorldDy;
        if (cTagsMask and 1) <> 0 then
           begin
           dec(t, HealthTagTex^.h + 2);
           DrawCentered(hwRound(Gear^.X) + WorldDx, t, HealthTagTex)
           end;
        if (cTagsMask and 2) <> 0 then
           begin
           dec(t, NameTagTex^.h + 2);
           DrawCentered(hwRound(Gear^.X) + WorldDx, t, NameTagTex)
           end;
        if (cTagsMask and 4) <> 0 then
           begin
           dec(t, Team^.NameTagTex^.h + 2);
           DrawCentered(hwRound(Gear^.X) + WorldDx, t, Team^.NameTagTex)
           end
        end else // Current hedgehog
      if (Gear^.State and gstHHDriven) <> 0 then
        begin
        if bShowFinger and ((Gear^.State and gstHHDriven) <> 0) then
           DrawSprite(sprFinger, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 64 + WorldDy,
                      GameTicks div 32 mod 16, Surface);
        if (Gear^.State and (gstMoving or gstDrowning)) = 0 then
           if (Gear^.State and gstHHThinking) <> 0 then
              DrawSprite(sprQuestion, hwRound(Gear^.X) - 10 + WorldDx, hwRound(Gear^.Y) - cHHRadius - 34 + WorldDy, 0, Surface)
              else
              if ShowCrosshair and ((Gear^.State and gstAttacked) = 0) then
                 DrawRotatedTex(Team^.CrosshairTex,
                                12, 12,
                                Round(hwRound(Gear^.X) +
                                hwSign(Gear^.dX) * Sin(Gear^.Angle*pi/cMaxAngle)*60) + WorldDx,
                                Round(hwRound(Gear^.Y) -
                                Cos(Gear^.Angle*pi/cMaxAngle)*60) + WorldDy,
                                hwSign(Gear^.dX) * Gear^.Angle * 180 / cMaxAngle)
        end;
end;

procedure DrawGears(Surface: PSDL_Surface);
var Gear: PGear;
    i: Longword;
    roplen: LongInt;

    procedure DrawRopeLine(X1, Y1, X2, Y2: LongInt);
    var  eX, eY, dX, dY: LongInt;
         i, sX, sY, x, y, d: LongInt;
         b: boolean;
    begin
    if (X1 = X2) and (Y1 = Y2) then
       begin
       OutError('WARNING: zero length rope line!', false);
       exit
       end;
    eX:= 0;
    eY:= 0;
    dX:= X2 - X1;
    dY:= Y2 - Y1;

    if (dX > 0) then sX:= 1
    else
      if (dX < 0) then
         begin
         sX:= -1;
         dX:= -dX
         end else sX:= dX;

    if (dY > 0) then sY:= 1
       else
    if (dY < 0) then
       begin
       sY:= -1;
       dY:= -dY
       end else sY:= dY;

    if (dX > dY) then d:= dX
                 else d:= dY;

    x:= X1;
    y:= Y1;

    for i:= 0 to d do
        begin
        inc(eX, dX);
        inc(eY, dY);
        b:= false;
        if (eX > d) then
           begin
           dec(eX, d);
           inc(x, sX);
           b:= true
           end;
        if (eY > d) then
           begin
           dec(eY, d);
           inc(y, sY);
           b:= true
           end;
        if b then
           begin
           inc(roplen);
           if (roplen mod 4) = 0 then DrawSprite(sprRopeNode, x - 2, y - 2, 0, Surface)
           end
       end
    end;

begin
Gear:= GearsList;
while Gear<>nil do
      begin
      case Gear^.Kind of
           gtCloud: DrawSprite(sprCloud, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.State, Surface);
       gtAmmo_Bomb: DrawRotated(sprBomb, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.DirAngle);
        gtHedgehog: DrawHH(Gear, Surface);
    gtAmmo_Grenade: DrawRotated(sprGrenade, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, DxDy2Angle(Gear^.dY, Gear^.dX));
       gtHealthTag,
     gtSmallDamage: if Gear^.Tex <> nil then DrawCentered(hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.Tex);
           gtGrave: DrawSurfSprite(hwRound(Gear^.X) + WorldDx - 16, hwRound(Gear^.Y) + WorldDy - 16, 32, (GameTicks shr 7) and 7, PHedgehog(Gear^.Hedgehog)^.Team^.GraveTex, Surface);
             gtUFO: DrawSprite(sprUFO, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 16 + WorldDy, (GameTicks shr 7) mod 4, Surface);
            gtRope: begin
                    roplen:= 0;
                    if RopePoints.Count > 0 then
                       begin
                       i:= 0;
                       while i < Pred(RopePoints.Count) do
                             begin
                             DrawRopeLine(hwRound(RopePoints.ar[i].X) + WorldDx, hwRound(RopePoints.ar[i].Y) + WorldDy,
                                          hwRound(RopePoints.ar[Succ(i)].X) + WorldDx, hwRound(RopePoints.ar[Succ(i)].Y) + WorldDy);
                             inc(i)
                             end;
                       DrawRopeLine(hwRound(RopePoints.ar[i].X) + WorldDx, hwRound(RopePoints.ar[i].Y) + WorldDy,
                                    hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy);
                       DrawRopeLine(hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy,
                                    hwRound(PHedgehog(Gear^.Hedgehog)^.Gear^.X) + WorldDx, hwRound(PHedgehog(Gear^.Hedgehog)^.Gear^.Y) + WorldDy);
                       DrawRotated(sprRopeHook, hwRound(RopePoints.ar[0].X) + WorldDx, hwRound(RopePoints.ar[0].Y) + WorldDy, RopePoints.HookAngle)
                       end else
                       begin
                       DrawRopeLine(hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy,
                                    hwRound(PHedgehog(Gear^.Hedgehog)^.Gear^.X) + WorldDx, hwRound(PHedgehog(Gear^.Hedgehog)^.Gear^.Y) + WorldDy);
                       DrawRotated(sprRopeHook, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, DxDy2Angle(Gear^.dY, Gear^.dX));
                       end;
                    end;
      gtSmokeTrace: if Gear^.State < 8 then DrawSprite(sprSmokeTrace, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.State, Surface);
       gtExplosion: DrawSprite(sprExplosion50, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.State, Surface);
            gtMine: if ((Gear^.State and gstAttacking) = 0)or((Gear^.Timer and $3FF) < 420)
                       then DrawRotated(sprMineOff, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.DirAngle)
                       else DrawRotated(sprMineOn, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.DirAngle);
            gtCase: case Gear^.Pos of
                         posCaseAmmo  : DrawSprite(sprCase, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 16 + WorldDy, 0, Surface);
                         posCaseHealth: DrawSprite(sprFAid, hwRound(Gear^.X) - 24 + WorldDx, hwRound(Gear^.Y) - 24 + WorldDy, (GameTicks shr 6) mod 13, Surface);
                         end;
        gtDynamite: DrawSprite2(sprDynamite, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 25 + WorldDy, Gear^.Tag and 1, Gear^.Tag shr 1, Surface);
     gtClusterBomb: DrawRotated(sprClusterBomb, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, Gear^.DirAngle);
         gtCluster: DrawSprite(sprClusterParticle, hwRound(Gear^.X) - 8 + WorldDx, hwRound(Gear^.Y) - 8 + WorldDy, 0, Surface);
           gtFlame: DrawSprite(sprFlame, hwRound(Gear^.X) - 8 + WorldDx, hwRound(Gear^.Y) - 8 + WorldDy,(GameTicks div 128 + Gear^.Angle) mod 8, Surface);
       gtParachute: DrawSprite(sprParachute, hwRound(Gear^.X) - 24 + WorldDx, hwRound(Gear^.Y) - 48 + WorldDy, 0, Surface);
       gtAirAttack: if Gear^.Tag > 0 then DrawSprite(sprAirplane, hwRound(Gear^.X) - 60 + WorldDx, hwRound(Gear^.Y) - 25 + WorldDy, 0, Surface)
                                     else DrawSprite(sprAirplane, hwRound(Gear^.X) - 60 + WorldDx, hwRound(Gear^.Y) - 25 + WorldDy, 1, Surface);
         gtAirBomb: DrawRotated(sprAirBomb, hwRound(Gear^.X) + WorldDx, hwRound(Gear^.Y) + WorldDy, DxDy2Angle(Gear^.dY, Gear^.dX));
        gtSwitcher: DrawSprite(sprSwitch, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 56 + WorldDy, (GameTicks shr 6) mod 12, Surface);
          gtTarget: DrawSprite(sprTarget, hwRound(Gear^.X) - 16 + WorldDx, hwRound(Gear^.Y) - 16 + WorldDy, 0, Surface);
              end;
      Gear:= Gear^.NextGear
      end;
end;

procedure FreeGearsList;
var t, tt: PGear;
begin
tt:= GearsList;
GearsList:= nil;
while tt<>nil do
      begin
      t:= tt;
      tt:= tt^.NextGear;
      Dispose(t)
      end;
end;

procedure AddMiscGears;
var i: LongInt;
begin
AddGear(0, 0, gtATStartGame, 0, _0, _0, 2000);
if (GameFlags and gfForts) = 0 then
   for i:= 0 to Pred(cLandAdditions) do
       FindPlace(AddGear(0, 0, gtMine, 0, _0, _0, 0), false, 0, 2048);
end;

procedure AddClouds;
var i: LongInt;
    dx, dy: hwFloat;
begin
for i:= 0 to cCloudsNumber do
    begin
    dx.isNegative:= random(2) = 1;
    dx.QWordValue:= random(214748364);
    dy.isNegative:= (i and 1) = 1;
    dy.QWordValue:= 21474836 + random(64424509);
    AddGear( - cScreenWidth + i * ((cScreenWidth * 2 + 2304) div cCloudsNumber), -140,
             gtCloud, random(4), dx, dy, 0)
    end
end;

procedure doMakeExplosion(X, Y, Radius: LongInt; Mask: LongWord);
var Gear: PGear;
    dmg, dmgRadius: LongInt;
begin
TargetPoint.X:= NoPointX;
{$IFDEF DEBUGFILE}if Radius > 3 then AddFileLog('Explosion: at (' + inttostr(x) + ',' + inttostr(y) + ')');{$ENDIF}
if Radius = 50 then AddGear(X, Y, gtExplosion, 0, _0, _0, 0);
if (Mask and EXPLAutoSound) <> 0 then PlaySound(sndExplosion, false);
if (Mask and EXPLAllDamageInRadius)=0 then dmgRadius:= Radius shl 1
                                      else dmgRadius:= Radius;
Gear:= GearsList;
while Gear <> nil do
      begin
      dmg:= dmgRadius - hwRound(Distance(Gear^.X - int2hwFloat(X), Gear^.Y - int2hwFloat(Y)));
      if (dmg > 1) and
         ((Gear^.State and gstNoDamage) = 0) then
         begin
         dmg:= dmg div 2;
         case Gear^.Kind of
              gtHedgehog,
                  gtMine,
                  gtCase,
                gtTarget,
                 gtFlame: begin
                          {$IFDEF DEBUGFILE}AddFileLog('Damage: ' + inttostr(dmg));{$ENDIF}
                          if (Mask and EXPLNoDamage) = 0 then
                             begin
                             inc(Gear^.Damage, dmg);
                             if Gear^.Kind = gtHedgehog then
                                AddDamageTag(hwRound(Gear^.X), hwRound(Gear^.Y), dmg, Gear)
                             end;
                          if ((Mask and EXPLDoNotTouchHH) = 0) or (Gear^.Kind <> gtHedgehog) then
                             begin
                             DeleteCI(Gear);
                             Gear^.dX:= Gear^.dX + SignAs(_0_005 * dmg + cHHKick, Gear^.X - int2hwFloat(X));
                             Gear^.dY:= Gear^.dY + SignAs(_0_005 * dmg + cHHKick, Gear^.Y - int2hwFloat(Y));
                             Gear^.State:= Gear^.State or gstMoving;
                             Gear^.Active:= true;
                             FollowGear:= Gear
                             end;
                          end;
                 gtGrave: begin
                          Gear^.dY:= - _0_004 * dmg;
                          Gear^.Active:= true;
                          end;
              end;
         end;
      Gear:= Gear^.NextGear
      end;
if (Mask and EXPLDontDraw) = 0 then
   if (GameFlags and gfSolidLand) = 0 then DrawExplosion(X, Y, Radius);
uAIMisc.AwareOfExplosion(0, 0, 0)
end;

procedure ShotgunShot(Gear: PGear);
var t: PGear;
    dmg: integer;
    hh: PHedgehog;
begin
Gear^.Radius:= cShotgunRadius;
hh:= Gear^.Hedgehog;
t:= GearsList;
while t <> nil do
    begin
    dmg:= min(Gear^.Radius + t^.Radius - hwRound(Distance(Gear^.X - t^.X, Gear^.Y - t^.Y)), 25);
    if dmg > 0 then
       case t^.Kind of
           gtHedgehog,
               gtMine,
               gtCase,
             gtTarget: begin
                       inc(t^.Damage, dmg);
                       if t^.Kind = gtHedgehog then
                          begin
                          AddDamageTag(hwRound(Gear^.X), hwRound(Gear^.Y), dmg, t);
                          inc(hh^.DamageGiven, dmg)
                          end;
                       DeleteCI(t);
                       t^.dX:= t^.dX + SignAs(Gear^.dX * dmg * _0_01 + cHHKick, t^.X - Gear^.X);
                       t^.dY:= t^.dY + Gear^.dY * dmg * _0_01;
                       t^.State:= t^.State or gstMoving;
                       t^.Active:= true;
                       FollowGear:= t
                       end;
              gtGrave: begin
                       t^.dY:= - _0_1;
                       t^.Active:= true
                       end;
           end;
    t:= t^.NextGear
    end;
if (GameFlags and gfSolidLand) = 0 then DrawExplosion(hwRound(Gear^.X), hwRound(Gear^.Y), cShotgunRadius)
end;

procedure AmmoShove(Ammo: PGear; Damage, Power: LongInt);
var t: PGearArray;
    i: LongInt;
    hh: PHedgehog;
begin
t:= CheckGearsCollision(Ammo);
i:= t^.Count;
hh:= Ammo^.Hedgehog;
while i > 0 do
    begin
    dec(i);
    if (t^.ar[i]^.State and gstNoDamage) = 0 then
       case t^.ar[i]^.Kind of
           gtHedgehog,
               gtMine,
             gtTarget,
               gtCase: begin
                       inc(t^.ar[i]^.Damage, Damage);
                       if t^.ar[i]^.Kind = gtHedgehog then
                          begin
                          AddDamageTag(hwRound(t^.ar[i]^.X), hwRound(t^.ar[i]^.Y), Damage, t^.ar[i]);
                          inc(hh^.DamageGiven, Damage)
                          end;
                       DeleteCI(t^.ar[i]);
                       t^.ar[i]^.dX:= Ammo^.dX * Power * _0_01;
                       t^.ar[i]^.dY:= Ammo^.dY * Power * _0_01;
                       t^.ar[i]^.Active:= true;
                       t^.ar[i]^.State:= t^.ar[i]^.State or gstMoving;
                       FollowGear:= t^.ar[i]
                       end;
           end
    end;
SetAllToActive
end;

procedure AssignHHCoords;
var i, t, p: LongInt;
    ar: array[0..Pred(cMaxHHs)] of PGear;
    Count: Longword;
begin
if (GameFlags and gfForts) <> 0 then
   begin
   t:= 0;
   for p:= 0 to Pred(TeamsCount) do
     with TeamsArray[p]^ do
      begin
      for i:= 0 to cMaxHHIndex do
          with Hedgehogs[i] do
               if (Gear <> nil) and (Gear^.X.QWordValue = 0) then FindPlace(Gear, false, t, t + 1024);
      inc(t, 1024);
      end
   end else // mix hedgehogs
   begin
   Count:= 0;
   for p:= 0 to Pred(TeamsCount) do
     with TeamsArray[p]^ do
      begin
      for i:= 0 to cMaxHHIndex do
          with Hedgehogs[i] do
               if (Gear <> nil) and (Gear^.X.QWordValue = 0) then
                  begin
                  ar[Count]:= Gear;
                  inc(Count)
                  end;
      end;

   while (Count > 0) do
      begin
      i:= GetRandom(Count);
      FindPlace(ar[i], false, 0, 2048);
      ar[i]:= ar[Count - 1];
      dec(Count)
      end
   end
end;

function CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear;
var t: PGear;
begin
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);
while t <> nil do
      begin
      if (t <> Gear) and (t^.Kind = Kind) then
         if not((hwSqr(Gear^.X - t^.X) / rX + hwSqr(Gear^.Y - t^.Y) / rY) > _1) then
            exit(t);
      t:= t^.NextGear
      end;
CheckGearNear:= nil
end;

procedure AmmoFlameWork(Ammo: PGear);
var t: PGear;
begin
t:= GearsList;
while t <> nil do
      begin
      if (t^.Kind = gtHedgehog) and (t^.Y < Ammo^.Y) then
         if not (hwSqr(Ammo^.X - t^.X) + hwSqr(Ammo^.Y - t^.Y - int2hwFloat(cHHRadius)) * 2 > _2) then
            begin
            inc(t^.Damage, 5);
            t^.dX:= t^.dX + (t^.X - Ammo^.X) * _0_02;
            t^.dY:= - _0_25;
            t^.Active:= true;
            DeleteCI(t);
            FollowGear:= t
            end;
      t:= t^.NextGear
      end;
end;

function CheckGearsNear(mX, mY: LongInt; Kind: TGearsType; rX, rY: LongInt): PGear;
var t: PGear;
begin
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);
while t <> nil do
      begin
      if t^.Kind in Kind then
         if not (hwSqr(int2hwFloat(mX) - t^.X) / rX + hwSqr(int2hwFloat(mY) - t^.Y) / rY > _1) then
            exit(t);
      t:= t^.NextGear
      end;
CheckGearsNear:= nil
end;

function CountGears(Kind: TGearType): Longword;
var t: PGear;
    Result: Longword;
begin
Result:= 0;
t:= GearsList;
while t <> nil do
      begin
      if t^.Kind = Kind then inc(Result);
      t:= t^.NextGear
      end;
CountGears:= Result
end;

procedure SpawnBoxOfSmth;
var t: LongInt;
    i: TAmmoType;
begin
if (cCaseFactor = 0) or
   (CountGears(gtCase) >= 5) or
   (getrandom(cCaseFactor) <> 0) then exit;
FollowGear:= AddGear(0, 0, gtCase, 0, _0, _0, 0);
case getrandom(2) of
     0: begin
        FollowGear^.Health:= 25;
        FollowGear^.Pos:= posCaseHealth
        end;
     1: begin
        t:= 0;
        for i:= Low(TAmmoType) to High(TAmmoType) do
            inc(t, Ammoz[i].Probability);
        t:= GetRandom(t);
        i:= Low(TAmmoType);
        dec(t, Ammoz[i].Probability);
        while t >= 0 do
          begin
          inc(i);
          dec(t, Ammoz[i].Probability)
          end;
        FollowGear^.Pos:= posCaseAmmo;
        FollowGear^.State:= Longword(i)
        end;
     end;
FindPlace(FollowGear, true, 0, 2048)
end;

procedure FindPlace(Gear: PGear; withFall: boolean; Left, Right: LongInt);

    function CountNonZeroz(x, y, r: LongInt): LongInt;
    var i: LongInt;
        Result: LongInt;
    begin
    Result:= 0;
    if (y and $FFFFFC00) = 0 then
      for i:= max(x - r, 0) to min(x + r, 2043) do
        if Land[y, i] <> 0 then inc(Result);
    CountNonZeroz:= Result
    end;

var x: LongInt;
    y, sy: LongInt;
    ar: array[0..511] of TPoint;
    ar2: array[0..1023] of TPoint;
    cnt, cnt2: Longword;
    delta: LongInt;
begin
delta:= 250;
cnt2:= 0;
repeat
  x:= Left + LongInt(GetRandom(Delta));
  repeat
     inc(x, Delta);
     cnt:= 0;
     y:= -Gear^.Radius * 2;
     while y < 1023 do
        begin
        repeat
         inc(y, 2);
        until (y > 1023) or (CountNonZeroz(x, y, Gear^.Radius - 1) = 0);
        sy:= y;
        repeat
          inc(y);
        until (y > 1023) or (CountNonZeroz(x, y, Gear^.Radius - 1) <> 0);
        if (y - sy > Gear^.Radius * 2)
        and (y < 1023)
        and (CheckGearsNear(x, y - Gear^.Radius, [gtHedgehog, gtMine, gtCase], 110, 110) = nil) then
           begin
           ar[cnt].X:= x;
           if withFall then ar[cnt].Y:= sy + Gear^.Radius
                       else ar[cnt].Y:= y - Gear^.Radius;
           inc(cnt)
           end;
        inc(y, 45)
        end;
     if cnt > 0 then
        with ar[GetRandom(cnt)] do
          begin
          ar2[cnt2].x:= x;
          ar2[cnt2].y:= y;
          inc(cnt2)
          end
  until (x + Delta > Right);
dec(Delta, 60)
until (cnt2 > 0) or (Delta < 70);
if cnt2 > 0 then
   with ar2[GetRandom(cnt2)] do
      begin
      Gear^.X:= int2hwFloat(x);
      Gear^.Y:= int2hwFloat(y);
      {$IFDEF DEBUGFILE}
      AddFileLog('Assigned Gear coordinates (' + inttostr(x) + ',' + inttostr(y) + ')');
      {$ENDIF}
      end
   else
   begin
   OutError('Can''t find place for Gear', false);
   DeleteGear(Gear)
   end
end;

initialization

finalization
FreeGearsList;

end.
