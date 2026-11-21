using UnityEngine;

public sealed partial class KinseiSession
{
    enum RailPlace { Street, Lift, Platform, Coach }
    RailPlace railPlace;
    int railStop,railCar;
    bool liftGoingUp;
    bool AboveStreet =>railPlace!=RailPlace.Street;
    bool RailAvailable =>!finale && (phase==Phase.Arrival || InDawn);
    const float LiftZ=-19.48f,DoorZ=-22.62f;

    void ResetRailRide()
    {
        if(player!=null && player.root)player.root.SetParent(transform,true);
        club.ResetRail();railPlace=RailPlace.Street;railStop=railCar=0;liftGoingUp=false;
    }

    static bool NearLift(Vector3 at,int station)
        =>Mathf.Abs(at.x-KinseiWorld.LiftX(station))<.68f && Mathf.Abs(at.z-LiftZ)<.74f;

    int StationAt(Vector3 at)=>at.x<0?0:1;
    bool LinedUp(Vector3 at,int stop,out int car)
    {
        float dx=at.x-KinseiWorld.StopX(stop);
        car=dx<0?0:1;
        return Mathf.Abs(dx-(car-.5f)*8.7f)<.54f;
    }

    string RailVerb()
    {
        if(!RailAvailable || command)return "";
        Vector3 at=player.Position;
        int stop=railPlace==RailPlace.Street?StationAt(at):railStop;
        if(railPlace==RailPlace.Street && at.y<.4f && NearLift(at,stop) && club.AtLiftHeight(stop,0))
            return KinseiWorld.StopName(stop)+"のホームへ上がる";
        if(railPlace==RailPlace.Street && Mathf.Abs(at.x-KinseiWorld.LiftX(stop))<1.4f &&
            Mathf.Abs(at.z-LiftZ)<1.95f && !club.AtLiftHeight(stop,0))return "地上へ昇降台を呼ぶ";
        if(railPlace==RailPlace.Platform && NearLift(at,stop) && club.AtLiftHeight(stop,KinseiWorld.RailHeight))
            return "昇降台で通りへ降りる";
        if(railPlace==RailPlace.Platform && Mathf.Abs(at.x-KinseiWorld.LiftX(stop))<1.15f &&
            at.z> -21.48f && !club.AtLiftHeight(stop,KinseiWorld.RailHeight))return "ホームへ昇降台を呼ぶ";
        return "";
    }

    void UseRail(string verb)
    {
        if(verb=="地上へ昇降台を呼ぶ" || verb=="ホームへ昇降台を呼ぶ"){
            club.CallLift(StationAt(player.Position),railPlace==RailPlace.Platform);sound.Cue("dial");return;
        }
        railStop=StationAt(player.Position);
        liftGoingUp=railPlace==RailPlace.Street;
        railPlace=RailPlace.Lift;
        player.root.SetParent(club.Lift(railStop),true);
        Face(player,club.Lift(railStop).TransformPoint(new Vector3(.77f,1.08f,.28f)));
        fallVelocity=0;moveBlend=0;Motion(player,"idle");club.CallLift(railStop,liftGoingUp);
        sound.Cue("dial");Mark(liftGoingUp?"rail-lift-up":"rail-lift-down");
    }

    void AdvanceRail(float dt)
    {
        bool threshold=AboveStreet && railPlace!=RailPlace.Lift && club.Docked &&
            LinedUp(player.Position,club.RailStation,out _) && Mathf.Abs(player.Position.z-DoorZ)<.39f;
        club.TickRail(dt,threshold);
        if(railPlace==RailPlace.Lift && club.AtLiftHeight(railStop,liftGoingUp?KinseiWorld.RailHeight:0)){
            player.root.SetParent(transform,true);
            railPlace=liftGoingUp?RailPlace.Platform:RailPlace.Street;
            fallVelocity=0;snapCamera=true;
            Say(liftGoingUp?"ホームに到着。停車中の開いた戸から乗れます":InDawn?"通りに到着。三店を歩いて訪ねられます":"通りに到着。Tabで組員を指揮できます",3);
        }
        if(AboveStreet)Physics.SyncTransforms();
    }

    Vector3 RailBounds(Vector3 from,Vector3 at)
    {
        if(railPlace==RailPlace.Street){
            int stop=StationAt(at);
            if(!club.AtLiftHeight(stop,0) && Mathf.Abs(at.x-KinseiWorld.LiftX(stop))<1.12f &&
                at.z<LiftZ+1.19f && at.z>LiftZ-1.18f){
                if(Mathf.Abs(from.x-KinseiWorld.LiftX(stop))>=1.12f)at.x=from.x;
                else at.z=from.z;
            }
            return StreetBounds(at);
        }
        if(railPlace==RailPlace.Lift)return from;
        if(railPlace==RailPlace.Coach){
            float cx=club.Train.position.x+(railCar-.5f)*8.7f;
            at.x=Mathf.Clamp(at.x,cx-3.84f,cx+3.84f);
            bool exit=club.Docked && Mathf.Abs(at.x-cx)<.54f;
            at.z=Mathf.Clamp(at.z,KinseiWorld.RailZ-.13f,exit?DoorZ+.62f:DoorZ-.35f);
            return at;
        }
        int direction=railStop==0?-1:1;
        float x=at.x*direction;
        at.x=direction*Mathf.Clamp(x,7.40f,24.02f);
        bool onLift=club.AtLiftHeight(railStop,KinseiWorld.RailHeight) && Mathf.Abs(at.x-KinseiWorld.LiftX(railStop))<.66f;
        bool board=club.Docked && club.RailStation==railStop && LinedUp(at,railStop,out _);
        at.z=Mathf.Clamp(at.z,board?DoorZ-.62f:DoorZ+.36f,onLift?LiftZ+.62f:-20.65f);
        // While walking out of the lift, an angled input must not cut the parapet corner.
        if(from.z> -20.6f && at.z> -20.6f)
            at.x=Mathf.Clamp(at.x,KinseiWorld.LiftX(railStop)-.64f,KinseiWorld.LiftX(railStop)+.64f);
        return at;
    }

    void CheckBoarding()
    {
        if(!club.Docked)return;
        var at=player.Position;
        if(railPlace==RailPlace.Platform && railStop==club.RailStation && at.z<DoorZ && LinedUp(at,railStop,out railCar)){
            railPlace=RailPlace.Coach;player.root.SetParent(club.Train,true);snapCamera=true;
            Mark("rail-board-"+railStop+"-"+railCar);
        } else if(railPlace==RailPlace.Coach && at.z>DoorZ+.035f && LinedUp(at,club.RailStation,out _)){
            player.root.SetParent(transform,true);railStop=club.RailStation;railPlace=RailPlace.Platform;
            snapCamera=true;Mark("rail-alight-"+railStop);
        }
    }

    string RailHint()
    {
        if(!RailAvailable)return "";
        if(railPlace==RailPlace.Lift)return liftGoingUp?"昇降中　ホームへ":"昇降中　地上へ";
        if(railPlace==RailPlace.Street){
            var at=player.Position;
            return Mathf.Abs(Mathf.Abs(at.x)-8)<2 && at.z< -15.2f?"高架線　路地奥の昇降台に乗って E":"";
        }
        string station=KinseiWorld.StopName(club.RailStation);
        string next=KinseiWorld.StopName(1-club.RailStation);
        if(railPlace==RailPlace.Coach)return club.Docked?
            station+" 停車中　WASDで開いた戸へ　／　出発まで "+club.RailSeconds+" 秒":
            club.Stopped?station+"　戸が動いています":"行先 "+next+"　あと "+club.RailSeconds+" 秒　　右ドラッグ 見回す";
        if(club.Docked && club.RailStation==railStop)return station+"　乗車口が開いています　／　出発まで "+club.RailSeconds+" 秒";
        return KinseiWorld.StopName(railStop)+"　次の乗車まで "+club.SecondsToBoard(railStop)+" 秒　／　地上へは昇降台";
    }
}
