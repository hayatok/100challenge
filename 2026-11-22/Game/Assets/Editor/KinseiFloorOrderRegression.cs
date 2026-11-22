using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiFloorOrderRegression
{
    const string Pending="KinseiFloorOrderRegression.pending";
    const BindingFlags Access=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance;
    static KinseiFloorOrderRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=Ready;}

    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiFloor-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);
        EditorApplication.update-=Ready;EditorApplication.update+=Ready;EditorApplication.EnterPlaymode();
    }

    static object Get(object owner,string name)=>owner.GetType().GetField(name,Access).GetValue(owner);
    static void Set(object owner,string name,object value)=>owner.GetType().GetField(name,Access).SetValue(owner,value);
    static void Call(object owner,string name,params object[] args)=>owner.GetType().GetMethod(name,Access).Invoke(owner,args);
    static Transform Root(object person)=>(Transform)Get(person,"root");

    static void Ready()
    {
        if(!EditorApplication.isPlaying)return;
        var game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!game || !(Get(game,"walkways") is KinseiWalkways routes) || !routes.Ready)return;
        SessionState.EraseBool(Pending);EditorApplication.update-=Ready;
        try{
            Check(game);
            Debug.Log("KINSEI_FLOOR_ORDERS_PASS selection, retarget, pursuit, paired hit, surrender, portrait, result, retry");
            EditorApplication.Exit(0);
        }catch(Exception error){Debug.LogException(error);EditorApplication.Exit(1);}
    }

    static object Invoke(object o,string name,params object[] args)=>o.GetType().GetMethod(name,Access).Invoke(o,args);
    static void Need(bool ok,string message){if(!ok)throw new InvalidOperationException(message);}
    static void Place(object person,Vector3 at)=>Root(person).position=at;
    static void Duty(KinseiSession game,object member,string name,Vector3 goal)
    {
        var type=Get(member,"duty").GetType();
        Call(game,"Assign",Enum.Parse(type,name),goal);
    }
    static void TimeAt(KinseiSession game,float t)=>Set(game,"clock",t);

    static void Check(KinseiSession game)
    {
        Call(game,"StartNight");
        var player=Get(game,"player");Place(player,new Vector3(0,0,-5.4f));
        Call(game,"Simulate",.016f);
        Need(Get(game,"phase").ToString()=="Floor","Hall did not open");
        var guards=(IList)Get(game,"guards");var crew=(IList)Get(game,"crew");
        var a=guards[0];var b=guards[1];
        Place(a,new Vector3(-1.5f,0,-2));Place(b,new Vector3(1.5f,0,-2));
        var cam=(Camera)Get(game,"cam");
        Call(game,"ToggleCommand");Call(game,"SelectMember",0,false);Call(game,"SelectMember",1,true);
        Call(game,"SaveSquad",0);Call(game,"SelectMember",4,false);Call(game,"RecallSquad",0);
        void Click(object target){
            var screen=cam.WorldToScreenPoint(Root(target).position+Vector3.up);
            var picked=Invoke(game,"GuardAtScreen",(Vector2)screen);
            Need(picked==target,"Right click failed to resolve named guard");
            Call(game,"DesignateGuard",picked);
        }
        Call(game,"SelectMember",2,false);Duty(game,crew[2],"StageWitness",Vector3.zero);
        Call(game,"SelectMember",1,true);Click(a);
        Need(Get(crew[2],"duty").ToString()=="StageWitness" && Get(crew[1],"assignedGuard")==null,
            "An incompatible group silently replaced an individual job");
        Call(game,"RecallSquad",0);
        Click(a);Need(Get(crew[0],"assignedGuard")==a && Get(crew[1],"assignedGuard")==a,"Squad assignment");
        Click(b);Need(Get(crew[0],"assignedGuard")==b && Get(crew[1],"assignedGuard")==b,"Retarget did not replace both assignments");
        Call(game,"SelectMember",1,false);
        Duty(game,crew[1],"Go",Root(crew[1]).position+Vector3.right*.3f);
        Need(Get(crew[1],"assignedGuard")==null && Get(crew[1],"duty").ToString()=="Go","Ground order failed to cancel");
        Call(game,"SelectMember",0,false);
        Place(crew[0],new Vector3(0,0,-4.8f));Place(b,new Vector3(1.5f,0,3.7f));
        var old=Root(crew[0]).position;
        for(int i=0;i<30;i++){TimeAt(game,1+i/60f);Call(game,"UpdateCrew",crew[0],0,1f/60);}
        Need(Vector3.Distance(old,Root(crew[0]).position)>.6f && Get(crew[0],"assignedGuard")==b,"Assigned member did not pursue moved target");
        Click(a);Call(game,"ToggleCommand");
        Place(a,new Vector3(-.62f,0,-3.8f));Place(b,new Vector3(1.4f,0,-3.0f));
        Place(player,new Vector3(0,0,-5.4f));Place(crew[0],new Vector3(-1.2f,0,-5.1f));Physics.SyncTransforms();
        void PlayerHit(object guard,float t){
            TimeAt(game,t);
            Call(game,"Targets");
            Set(game,"lockedTarget",guard);
            cam.transform.position=Root(player).position+new Vector3(0,1.6f,-1.9f);
            cam.transform.LookAt(Root(guard).position+Vector3.up*1.15f);
            var before=(float)Get(guard,"hp");Call(game,"Attack",false,false);
            Need((float)Get(guard,"hp")<before || (bool)Get(guard,"floorYielded"),"TPS shot did not hit "+Get(guard,"name"));
        }
        void CrewHit(float t){
            TimeAt(game,t);Set(crew[0],"cooldown",0f);Call(game,"UpdateCrew",crew[0],0,1f/60);
            Need(Mathf.Abs((float)Get(crew[0],"lastNamedHit")-t)<.0001f || (bool)Get(a,"floorYielded") || (bool)Get(b,"floorYielded"),"No assigned shot");
        }
        PlayerHit(b,4);
        CrewHit(4.2f);Need(!(bool)Get(a,"floorYielded") && !(bool)Get(b,"floorYielded"),"Hits on two people combined");
        PlayerHit(a,6);
        Need((float)Get(a,"flinchUntil")>6 && Get(a,"watching")==null,"No real stagger");
        CrewHit(7.60f);Need(!(bool)Get(a,"floorYielded"),"Expired player hit combined");
        float boundary=(float)Get(crew[0],"lastNamedHit")+1.55f;
        Quaternion priorFacing=Root(a).rotation;
        PlayerHit(a,boundary);
        Need(Quaternion.Angle(priorFacing,Root(a).rotation)<.01f,"Yield snapped planted feet");
        Need((bool)Get(a,"floorYielded") && (float)Get(a,"hp")>0 && Get(a,"pose").ToString()=="floor-yield","Inclusive boundary did not yield a living guard");
        Need(Get(crew[0],"assignedGuard")==null,"Surrender left a job");
        Need(!(bool)Invoke(game,"CanWatchStage",a),"A kneeling guard walked through the audience after yielding");
        Call(game,"Targets");Need(!((IList)Get(game,"combatants")).Contains(a),"Surrendered man remained a target");
        Call(game,"Opponent",a,1f/60);
        Need(Get(a,"watching")==null && Get(a,"pose").ToString()=="floor-yield","Surrendered guard resumed combat");
        Call(game,"ToggleCommand");Click(b);Call(game,"ToggleCommand");
        PlayerHit(b,12);CrewHit(12.27f);
        Need((bool)Get(b,"floorYielded") && (float)Get(b,"hp")>0,"Player-first pair failed");
        Set(Get(game,"brother"),"hp",0f);Call(game,"Simulate",.016f);
        Need(Get(game,"phase").ToString()=="Choice","Living surrendered guards blocked the choice");
        // Makabe can stand in front of a kneeling guard without pushing the camera into the guard's lapel.
        var originalA=Root(a).position;var originalFacing=Root(a).rotation;
        Place(a,Vector3.zero);Root(a).rotation=Quaternion.identity;
        Place(player,Vector3.forward*.8f);Call(game,"PlayerInput",.016f);Physics.SyncTransforms();
        Set(game,"yieldingPortrait",a);
        var closeFocus=Vector3.up*.63f;
        var point=(Vector3)Invoke(game,"PortraitCameraPoint",closeFocus,0f);
        Need(Vector3.Distance(closeFocus,point)>1.72f,"Makabe's controller pushed the portrait camera into the suit");
        cam.transform.position=point;
        Call(game,"ClearPortraitForeground",cam);
        Need(((IList)Get(game,"portraitForeground")).Count>0,"Foreground actor still blocks the close camera");
        Call(game,"RestorePortraitForeground",cam);
        Need(((IList)Get(game,"portraitForeground")).Count==0,"Close camera retained hidden foreground renderers");
        Set(game,"yieldingPortrait",null);Place(a,originalA);Root(a).rotation=originalFacing;
        var boss=Get(game,"boss");Place(player,Root(boss).position+Vector3.left*.8f);Call(game,"Interact");
        Set(boss,"hp",0f);Call(game,"Simulate",.016f);
        string result=(string)Get(game,"floorGuardReport");
        Need((string)Get(game,"outcome")=="pursuit" && result.Contains("紺谷　降参") && result.Contains("浦　降参"),"Result lost surrender distinction");
        Call(game,"StartNight");
        Need(!(bool)Get(((IList)Get(game,"guards"))[0],"floorYielded") && Get(((IList)Get(game,"crew"))[0],"assignedGuard")==null,"Retry retained surrender or assignments");
        player=Get(game,"player");guards=(IList)Get(game,"guards");crew=(IList)Get(game,"crew");
        a=guards[0];b=guards[1];
        Place(player,new Vector3(0,0,-5.4f));Call(game,"Simulate",.016f);
        Place(a,new Vector3(-.62f,0,-3.8f));Place(b,new Vector3(1.4f,0,-3f));Physics.SyncTransforms();
        Call(game,"ToggleCommand");Call(game,"SelectMember",0,false);Click(a);
        Duty(game,crew[0],"Follow",Vector3.zero);
        Need(Get(crew[0],"assignedGuard")==null,"F did not release the target");
        Click(a);Call(game,"ToggleCommand");
        Set(a,"hp",32f);PlayerHit(a,3f);
        Need((float)Get(a,"hp")==0 && !(bool)Get(a,"floorYielded") && Get(crew[0],"assignedGuard")==null &&
            ((string)Invoke(game,"FloorGuardReport")).Contains("紺谷　撃破"),"An unpaired lethal hit was not a defeat");
        Call(game,"ToggleCommand");Click(b);
        var phase=Get(game,"phase").GetType();Call(game,"Change",Enum.Parse(phase,"Showdown"));
        Need(Get(crew[0],"assignedGuard")==null && Get(crew[0],"duty").ToString()=="Follow","Entering another phase retained the order");

        foreach(bool surrender in new[]{false,true}){
            Call(game,"StartNight");
            player=Get(game,"player");guards=(IList)Get(game,"guards");crew=(IList)Get(game,"crew");
            a=guards[0];b=guards[1];var brother=Get(game,"brother");
            Place(player,new Vector3(0,0,-5.4f));Call(game,"Simulate",.016f);
            Place(a,new Vector3(-.9f,0,-3.8f));Place(b,new Vector3(1.2f,0,-3.0f));
            Place(brother,new Vector3(0,0,-3.2f));Place(crew[0],new Vector3(-1.5f,0,-4.6f));
            Physics.SyncTransforms();Call(game,"ToggleCommand");Call(game,"SelectMember",0,false);
            Call(game,"DesignateGuard",a);Call(game,"ToggleCommand");
            Call(game,"CycleTarget");
            if(surrender)PlayerHit(a,2);else Set(a,"hp",8f);
            Call(game,"CycleTarget");Need(Get(game,"lockedTarget")==b,"Q did not select Ura");
            TimeAt(game,2.7f);Set(crew[0],"cooldown",0f);Call(game,"UpdateCrew",crew[0],0,1f/60);
            Need(surrender?(bool)Get(a,"floorYielded"):(float)Get(a,"hp")==0,"The other guard did not leave combat");
            // Leave the brother at the centre of the crosshair; only Q should select Ura.
            cam.transform.position=Root(player).position+new Vector3(0,1.6f,-1.9f);
            cam.transform.LookAt(Root(brother).position+Vector3.up*1.15f);
            float otherHealth=(float)Get(brother,"hp"),uraHealth=(float)Get(b,"hp");
            TimeAt(game,4);Call(game,"Attack",false,false);
            Need(Get(game,"lockedTarget")==b && (float)Get(b,"hp")<uraHealth && (float)Get(brother,"hp")==otherHealth,
                "Q jumped to the brother when Kontani left combat");
        }
    }
}
