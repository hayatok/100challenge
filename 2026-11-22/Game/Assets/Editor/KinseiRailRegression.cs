using System;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiRailRegression
{
    const string Pending="KinseiRailRegression.pending";
    const float Dt=1f/60f;
    const BindingFlags Access=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static KinseiSession game;
    static KinseiWorld house;
    static CharacterController motor;
    static Transform rider;

    static KinseiRailRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=WhenReady;}
    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiRail-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);EditorApplication.update-=WhenReady;EditorApplication.update+=WhenReady;
        EditorApplication.EnterPlaymode();
    }

    static object Field(object target,string name)=>target.GetType().GetField(name,Access).GetValue(target);
    static object Call(string name,params object[] args)=>typeof(KinseiSession).GetMethod(name,Access).Invoke(game,args);
    static string Place=>Field(game,"railPlace").ToString();
    static string Phase=>Field(game,"phase").ToString();
    static void Require(bool ok,string message){if(!ok)throw new InvalidOperationException(message+" ("+Place+", "+rider.position+")");}
    static void Tick()
    {
        Call("AdvanceRail",Dt);
        Physics.SyncTransforms();
    }
    static void Until(Func<bool> goal,int seconds,string message)
    {
        for(int i=0;i<seconds*60 && !goal();i++)Tick();
        Require(goal(),message);
    }
    static void Walk(Vector3 vector,float metres)
    {
        float left=metres;
        while(left>.001f){
            Tick();
            float step=Mathf.Min(.046f,left);
            Vector3 at=(Vector3)Call("RailBounds",rider.position,rider.position+vector*step);
            motor.Move(new Vector3(at.x-rider.position.x,-.028f,at.z-rider.position.z));
            Call("CheckBoarding");left-=step;
        }
    }
    static void WhenReady()
    {
        if(!EditorApplication.isPlaying)return;
        game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!game || !((KinseiWalkways)Field(game,"walkways")).Ready)return;
        EditorApplication.update-=WhenReady;SessionState.EraseBool(Pending);
        try{Trip();Debug.Log("KINSEI_RAIL_PASS lift / two-car service / held threshold / ride / call / ground / retry");EditorApplication.Exit(0);}
        catch(Exception ex){Debug.LogException(ex);EditorApplication.Exit(1);}
    }
    static void Trip()
    {
        Call("StartNight");house=(KinseiWorld)Field(game,"club");Call("PlayerInput",Dt);
        motor=(CharacterController)Field(game,"motor");rider=motor.transform;
        // Place the fixture at the west lift. All subsequent distance is covered by the live controller or carrier.
        rider.position=new Vector3(-8,.05f,-19.48f);Physics.SyncTransforms();
        Require(((string)Call("Interaction")).Contains("ホームへ上がる"),"No ground lift action");Call("Interact");
        Until(()=>Place=="Platform",5,"Lift failed to reach platform");
        Require(rider.position.y>6.8f && Phase=="Arrival","Lift changed phase or lost height");
        Call("ToggleCommand");Require(!(bool)Field(game,"command"),"Aerial command interrupted the rider");
        Walk(Vector3.back,1.92f);Walk(Vector3.left,5.65f);
        Until(()=>house.Docked && house.RailStation==0 && house.RailSeconds>=5,43,"No usable west stop");
        Walk(Vector3.back,1.20f);
        Require(Mathf.Abs(rider.position.z+22.62f)<.38f,"Unable to stand in doorway");
        for(int i=0;i<600;i++)Tick();
        Require(house.Docked && house.RailStation==0,"Train departed across occupied doorway");
        Walk(Vector3.back,.80f);
        Require(Place=="Coach" && rider.parent==house.Train,"Player did not enter actual second coach");
        Vector3 local=rider.localPosition;
        Until(()=>house.Train.position.x> -12,14,"Train did not leave west stop");
        var boundary=(Vector3)Call("RailBounds",rider.position,rider.position+Vector3.forward*5);
        Require(boundary.z< -22.85f,"Moving coach permits stepping onto the track");
        Require(Vector3.Distance(local,rider.localPosition)<.03f,"Rider did not move with the coach");
        Call("OnApplicationFocus",false);Require((bool)Field(game,"paused"),"Focus loss did not pause");
        Call("TogglePause");
        Until(()=>house.Docked && house.RailStation==1,18,"Train did not reach east stop");
        // Stay aboard for another complete circuit.
        Until(()=>house.Docked && house.RailStation==0,30,"No return trip");
        Until(()=>house.Docked && house.RailStation==1,30,"No second east stop");
        Require(Mathf.Abs(rider.position.x-22.35f)<.4f && Phase=="Arrival","Trip did not physically move 36 m");
        Walk(Vector3.forward,1.96f);Require(Place=="Platform" && rider.parent!=house.Train,"Could not step off");
        Walk(Vector3.left,14.35f);Walk(Vector3.forward,1.5f);
        Require(((string)Call("Interaction")).Contains("呼ぶ"),"No upstairs lift call");Call("Interact");
        Until(()=>house.AtLiftHeight(1,KinseiWorld.RailHeight),5,"Empty east lift did not rise");
        Walk(Vector3.forward,1.27f);
        Require(((string)Call("Interaction")).Contains("降りる"),"No down button");Call("Interact");
        Until(()=>Place=="Street",5,"East lift did not descend");
        Walk(Vector3.forward,2.9f);Require(rider.position.y<.25f && rider.position.z> -17.35f,"Could not walk away on the east street");
        Call("ToggleCommand");Require((bool)Field(game,"command"),"Command unavailable after alighting");
        Call("StartNight");Require(Place=="Street" && house.AtLiftHeight(0,0) && house.AtLiftHeight(1,0) && house.RailStation==0,"Retry kept the previous trip");
    }
}
