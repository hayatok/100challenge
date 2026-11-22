using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiHallFrontRegression
{
    const string Pending="KinseiHallFrontRegression.pending";
    const BindingFlags Access=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    const float Step=1f/30;
    static KinseiSession game;
    static object player;
    static IList crew;

    static KinseiHallFrontRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=Ready;}
    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiFront-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);
        EditorApplication.update-=Ready;EditorApplication.update+=Ready;EditorApplication.EnterPlaymode();
    }
    static object Get(object owner,string name)=>owner.GetType().GetField(name,Access).GetValue(owner);
    static void Set(object owner,string name,object value)=>owner.GetType().GetField(name,Access).SetValue(owner,value);
    static object Call(string name,params object[] args)=>typeof(KinseiSession).GetMethod(name,Access).Invoke(game,args);
    static Vector3 Position(object person)=>((Transform)Get(person,"root")).position;
    static string Phase=>Get(game,"phase").ToString();
    static void Need(bool ok,string message){if(!ok)throw new InvalidOperationException(message+" (phase "+Phase+", t="+Get(game,"clock")+")");}

    static void Ready()
    {
        if(!EditorApplication.isPlaying)return;
        game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!game || Get(game,"walkways") is not KinseiWalkways routes || !routes.Ready)return;
        SessionState.EraseBool(Pending);EditorApplication.update-=Ready;
        try{
            for(int front=0;front<=1;front++)Play(front);
            Play(-1);
            Debug.Log("KINSEI_HALL_FRONTS_PASS dispatch, contest, relief, pursuit, crew transmission, withdrawal, retry, unassigned pursuit");
            EditorApplication.Exit(0);
        }catch(Exception ex){Debug.LogException(ex);EditorApplication.Exit(1);}
    }

    static void Tick()
    {
        Set(game,"clock",(float)Get(game,"clock")+Step);
        Set(game,"phaseAge",(float)Get(game,"phaseAge")+Step);
        Call("Simulate",Step);
    }
    static void Until(Func<bool> done,int frames,string message,Action play=null)
    {
        for(int i=0;i<frames && !done() && Phase!="Result";i++){play?.Invoke();Tick();}
        Need(done(),message);
    }
    static void Walk(Vector3 to,float tolerance)
    {
        Until(()=>Vector3.Distance(Position(player),to)<tolerance,240,"Could not walk to "+to,
            ()=>Call("MovePerson",player,to,4.1f,Step));
    }

    static void FireAt(object person)
    {
        for(int i=0;i<8 && Get(game,"lockedTarget")!=person;i++)Call("CycleTarget");
        var at=Position(person);var cam=(Camera)Get(game,"cam");
        cam.transform.position=Position(player)+Vector3.up*1.52f;
        cam.transform.LookAt(at+Vector3.up*1.15f);
        Call("Attack",false,false);
    }

    static void Fight()
    {
        var guards=(IList)Get(game,"guards");
        object target=Get(game,"brother");
        foreach(var guard in guards)
            if((float)Get(guard,"hp")>0 && !(bool)Get(guard,"floorYielded")){target=guard;break;}
        if((float)Get(target,"hp")<=0)return;
        if(!(bool)Call("ClearBetween",player,target) || Vector3.Distance(Position(player),Position(target))>6)
            Call("MovePerson",player,Position(target),4.1f,Step);
        FireAt(target);
    }

    static void PrepareTwoCrews(int side)
    {
        Call("ToggleCommand");
        Call("SelectMember",1,false);Call("SelectMember",2,true);Call("AssignHallFront",1-side);
        Call("SelectMember",2,false);Call("AssignHallFront",side);
        Need((int)Call("HallFrontMember",1)==1-side && (int)Call("HallFrontMember",2)==side,"Retarget changed the other member");
        var initial=Position(crew[2]);
        Until(()=>(float)Call("HallFrontProgress",side)>=.615f,390,"Crew failed to prepare the front");
        Need(Vector3.Distance(initial,Position(crew[2]))>2,"Crew did not travel to its post");
        Need(!(bool)Call("HallFrontReady",side),"Command alone secured a side");
        Call("ToggleCommand");
        var spot=(Vector3)Call("HallFrontPosition",side);
        Walk(spot+Vector3.back*1.65f,.45f);
        Call("ToggleCommand");
        for(int i=0;i<39;i++)Tick();
        Need(!(bool)Call("HallFrontReady",side),"The overhead view completed an unattended breakthrough");
        Call("ToggleCommand");
        object threat=Call("HallThreat",side);
        if(threat!=null){
            float before=(float)Call("HallFrontProgress",side);
            for(int i=0;i<4;i++)Tick();
            Need(Call("HallThreat",side)==null || (float)Call("HallFrontProgress",side)<=Mathf.Max(.6201f,before),"Moving into a guarded front captured it");
            FireAt(threat);
        }
        Until(()=>(bool)Call("HallFrontReady",side),180,"Supporting the crew failed to secure the front",()=>{
            var blocker=Call("HallThreat",side);
            if(blocker!=null)FireAt(blocker);
        });
        Need((int)Call("HallFrontMember",1)==-1 && !(bool)Call("HallFrontReady",1-side),"Other front did not stand down");
    }

    static void Play(int side)
    {
        Call("StartNight");player=Get(game,"player");crew=(IList)Get(game,"crew");
        Need((int)Get(game,"securedFront")==-1 && (float)Call("HallFrontProgress",0)==0 &&
            (float)Call("HallFrontProgress",1)==0 && Get(game,"hallMirrorOperator")==null,"A retry retained a front");
        Walk(new Vector3(0,0,-6),.42f);
        Need(Phase=="Floor","The front door did not open the hall");
        if(side>=0)PrepareTwoCrews(side);
        if(side==1)Need((bool)Get(game,"escorted") && (float)Get(Get(game,"brother"),"hp")==0,
            "The brother remained hostile after the relay opened");
        if(side==0)Need((float)Get(game,"escapeTime")>34,"The door did not buy pursuit time");
        Until(()=>Phase=="Choice",540,"The ordinary combatants did not yield the floor",Fight);
        if(side==1){
            Walk((Vector3)Call("HallFrontPosition",1)+Vector3.back*1.3f,.4f);
            Until(()=>(string)Call("Interaction")=="中継係に合図する",160,"The rescued brother did not make it to the desk");
            Need(!(bool)Get(game,"held"),"Test unexpectedly used Tatsu's seat");
            Call("ToggleCommand");
            Call("SelectMember",2,false);
            Call("Assign",Enum.Parse(Get(crew[2],"duty").GetType(),"Follow"),Vector3.zero);
            Need(Call("HallRelayCrew")==null,"The recalled operator stayed assigned");
            // Exercise the deadline with Tatsu down and a different living member available.
            Set(crew[0],"hp",0f);Set(game,"escapeTime",Step);
            Tick();
            Need(Phase=="Choice" && (bool)Get(Get(game,"boss"),"retired"),"The boss's exit ended the relay route");
            Need((bool)typeof(KinseiSession).GetProperty("HallFrontsVisible",Access).GetValue(game),"The relay orders disappeared");
            Call("SelectMember",1,false);Call("AssignHallFront",0);
            Need((int)Call("HallFrontMember",1)==-1,"A crew took the exit after the boss escaped");
            Call("AssignHallFront",1);Call("ToggleCommand");
            Until(()=>(string)Call("Interaction")=="中継係に合図する",180,"The replacement failed to take over after the escape");
            Call("Interact");
            Need(Phase=="Mirror" && Get(game,"hallMirrorOperator")==crew[1],"The replacement did not take over the mirror");
            Until(()=>Phase=="Result",1100,"The brothers did not leave the hall");
            Need((string)Get(game,"outcome")=="accord" && Position(Get(game,"brother")).z< -8.5f,"The brothers did not return together");
        }else{
            object boss=Get(game,"boss");
            if(side==0){
                Until(()=>Vector3.Distance(Position(boss),(Vector3)Get(game,"bossDoor"))<.6f,260,"The boss never reached his intercepted door");
                Need((bool)Call("DoorInterception"),"The posted crew did not intercept the boss");
                Call("ToggleCommand");
                Call("SelectMember",2,false);
                Call("Assign",Enum.Parse(Get(crew[2],"duty").GetType(),"Follow"),Vector3.zero);
                Need(!(bool)Call("DoorInterception") && (string)Call("HallFrontStatus",0)=="逃走猶予 ＋18秒",
                    "The recalled crew still appeared to intercept the boss");
                Call("AssignHallFront",0);Call("ToggleCommand");
                Until(()=>(bool)Call("DoorInterception"),100,"The returning crew did not resume the interception");
            }
            Until(()=>(string)Call("Interaction")=="兄貴分を追う",350,"No pursuit interaction",()=>
                Call("MovePerson",player,Position(boss),4.1f,Step));
            Call("Interact");Need(Phase=="Chase","Pursuit was blocked");
            if(side==0)Need((float)Get(boss,"cooldown")>(float)Get(game,"clock")+3,"The intercept did not interrupt the first counterattack");
            Until(()=>Phase=="Result",240,"The pursuit did not finish",()=>FireAt(boss));
            Need((string)Get(game,"outcome")=="pursuit","Wrong pursuit outcome");
        }
        Need((int)Call("HallFrontMember",2)==-1,"The previous assignment survived the ending");
    }
}
