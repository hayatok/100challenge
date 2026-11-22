using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiWestDisputeRegression
{
    const string Pending="KinseiWestDisputeRegression.pending";
    const BindingFlags Access=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance;
    static KinseiWestDisputeRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=Ready;}

    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiWest-"+Guid.NewGuid().ToString("N")));
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
            CheckBath(game,routes);
            CheckInsideCurtain(game);
            CheckDuel(game,false);
            CheckDuel(game,true);
            CheckTimeout(game);
            CheckEscorts(game);
            Debug.Log("KINSEI_WEST_DISPUTE_PASS dodge, defeat, two simultaneous bridge crossings, retirement and night reset");
            EditorApplication.Exit(0);
        }catch(Exception error){Debug.LogException(error);EditorApplication.Exit(1);}
    }

    static void CheckInsideCurtain(KinseiSession game)
    {
        Transform player=Begin(game);
        player.position=new Vector3(-39.2f,.23f,-15.65f);
        Set(game,"angle",180f);Call(game,"SetCamera",0f);
        var camera=(Camera)Get(game,"cam");
        Need(camera.transform.position.z< -14.70f && !camera.orthographic,"The curtain hides the lobby from the shoulder camera");
        player.position=new Vector3(-38.24f,-.01f,-13.42f);
        Set(game,"angle",-40f);Call(game,"SetCamera",0f);
        var viewer=GameObject.Find("木箱と張り出した管面").GetComponent<Collider>();
        var lens=camera.transform.position;
        Need(lens.z>viewer.bounds.max.z && Vector3.Distance(viewer.ClosestPoint(lens),lens)>.10f,
            "Turning toward the patrons put the lens inside the television");
        player.position=new Vector3(-40.82f,.23f,-15.42f);
        Call(game,"SetCamera",0f);
        Need(Mathf.Abs(camera.transform.position.x-player.position.x)<.9f,"Camera could not follow a customer across the lobby");
        var sound=(KinseiSound)Get(game,"sound");
        var music=(AudioSource)Get(sound,"music");
        AudioClip song=music.clip;
        sound.ListenAtBath(true,KinseiWorld.BathSpeakerPosition);
        Need((float)Get(sound,"bathListening")>.99f && music.transform.position==KinseiWorld.BathSpeakerPosition,"Programme failed to reach the physical speaker");
        sound.ListenAtBath(false,player.position);
        Need((float)Get(sound,"bathListening")==0 && music.clip==song,"Leaving the speaker switched the programme");
        Set(game,"command",true);Call(game,"SetCamera",0f);
        Need(camera.orthographic,"The lobby shoulder view overrode command");
        Set(game,"command",false);
        sound.ListenAtBath(true,KinseiWorld.BathSpeakerPosition);
        Call(game,"ReturnToTitle");
        Need((float)Get(sound,"bathListening")==0,"Title kept the bath speaker active");
    }

    static void CheckBath(KinseiSession game,KinseiWalkways routes)
    {
        Need(routes.GetPath(new Vector3(-23,0,-10.2f),new Vector3(-39.2f,.23f,-15.8f),new UnityEngine.AI.NavMeshPath()),"Bath entrance unreachable");
        Physics.SyncTransforms();
        Need(Physics.Raycast(new Vector3(-30.85f,1,-10.2f),Vector3.down,3),"Bridge has no deck");
        Need(!Physics.Raycast(new Vector3(-30.85f,1,-16),Vector3.down,3),"Canal unexpectedly walkable");
        var street=GameObject.Find("金星の生中継画面").GetComponent<Renderer>();
        var bath=GameObject.Find("湯客の金星中継").GetComponent<Renderer>();
        Need(street.sharedMaterial==bath.sharedMaterial,"Bath is not showing the marquee programme");
        var glass=Resources.Load<Shader>("KinseiBathGlass");
        Need(glass && !ShaderUtil.ShaderHasError(glass),"The bathhouse window material failed to compile");
        var lamp=GameObject.Find("浴場・笠下の反射").GetComponent<Light>();
        Call(Get(game,"club"),"SetStreetFixtureDay",true);Need(!lamp.enabled,"Day lamp still lit");
        Call(Get(game,"club"),"SetStreetFixtureDay",false);Need(lamp.enabled,"Night lamp unlit");
    }

    static void Need(bool ok,string why){if(!ok)throw new InvalidOperationException(why);}
    static void Tick(KinseiSession game)
    {
        const float dt=.05f;
        Set(game,"clock",(float)Get(game,"clock")+dt);Call(game,"Simulate",dt);
    }
    static Transform Begin(KinseiSession game)
    {
        Call(game,"OpenNight",false);
        Need(Get(game,"westSeo")==null && Get(game,"westRelieved")==null,"Optional work leaked into the next night");
        Transform player=Root(Get(game,"player"));player.position=new Vector3(-36,0,-11.5f);
        Tick(game);Need(Get(game,"westSeo")!=null,"West encounter missing");return player;
    }
    static void CheckDuel(KinseiSession game,bool dodge)
    {
        var player=Begin(game);Call(game,"Interact");
        Need((bool)Get(game,"westDuel"),"TPS E did not start the challenge");
        bool moved=false;
        for(int frame=0;frame<280 && Get(game,"westOutcome").ToString()=="Active";frame++){
            Tick(game);
            string beat=Get(game,"westBeat").ToString();
            if(beat=="Signal" && dodge && !moved){
                player.position+=(player.position.z< -11?Vector3.forward:Vector3.back)*.93f;moved=true;
            }
            if(beat=="Opening")Call(game,"Attack",true,false);
            if(beat=="Waiting")moved=false;
        }
        Need(Get(game,"westOutcome").ToString()==(dodge?"Won":"Lost"),"Incorrect challenge outcome");
        if(dodge)Need((bool)Get(Get(game,"westRelieved"),"retired"),"Hamaguchi still fighting");
        else Need(Get(game,"westRelieved")==null && (string)Get(Get(game,"westSeo"),"pose")=="idle","Lost duel awarded relief or left Seo punching");
    }
    static void CheckTimeout(KinseiSession game)
    {
        var player=Begin(game);
        player.position=new Vector3(-24,0,-9.8f);
        var crew=(IList)Get(game,"crew");
        var member=crew[0];
        var type=member.GetType().GetField("duty",Access).FieldType;
        Set(game,"command",true);
        Call(game,"Assign",Enum.Parse(type,"Attend"),Vector3.zero);
        var destination=new Vector3(-25,0,-10.2f);
        Call(game,"Assign",Enum.Parse(type,"Go"),destination);
        Need(((Array)Get(game,"westEscorts")).GetValue(0)==null &&
            Get(member,"duty").ToString()=="Go","Ground order did not release the runner");
        Call(game,"Assign",Enum.Parse(type,"Attend"),Vector3.zero);
        for(int f=0;f<780 && Get(game,"westOutcome").ToString()=="Active";f++)Tick(game);
        Need(Get(game,"westOutcome").ToString()=="Lost" && Get(game,"westRelieved")==null,
            "Leaving Seo at the doorway did not block evacuation");
        Begin(game);
        Set(game,"command",true);Call(game,"Assign",Enum.Parse(type,"Attend"),Vector3.zero);
        Root(Get(game,"player")).position=new Vector3(-18,0,-10.2f);
        Tick(game);Need(Get(game,"westOutcome").ToString()=="Left","Walking away kept the side job active");
    }

    static void CheckEscorts(KinseiSession game)
    {
        Transform player=Begin(game);
        var crew=(IList)Get(game,"crew");
        for(int i=0;i<2;i++)Root(crew[i]).position=new Vector3(-23,0,-10.8f+i*.9f);
        Call(game,"SetSelection",3);Set(game,"command",true);
        var attend=Enum.Parse(crew[0].GetType().GetField("duty",Access).FieldType,"Attend");
        Call(game,"Assign",attend,Vector3.zero);Call(game,"Assign",attend,Vector3.zero);
        Need(((Array)Get(game,"westEscorts")).GetValue(0)==null,"Cancellation left a runner");
        Call(game,"Assign",attend,Vector3.zero);Set(game,"command",false);
        var guests=(Array)Get(game,"westGuests");
        int crossed=0;
        for(int frame=0;frame<800 && Get(game,"westOutcome").ToString()=="Active";frame++){
            if(frame<98)player.position=Vector3.MoveTowards(player.position,new Vector3(-25,0,-10.0f),.126f);
            if(frame>150)player.position=Vector3.MoveTowards(player.position,new Vector3(-21,0,-7.0f),.11f);
            Tick(game);
            for(int i=0;i<2;i++){
                Vector3 foot=Root(guests.GetValue(i)).position;
                if(Mathf.Abs(foot.x+30.85f)<.43f){
                    Need(foot.z> -12.75f && foot.z< -7.65f,"Guest crossed outside bridge deck");crossed|=1<<i;
                }
            }
        }
        Need(crossed==3 && Get(game,"westOutcome").ToString()=="Won","Escorts failed: crossed="+crossed+" outcome="+Get(game,"westOutcome")+" guests="+Root(guests.GetValue(0)).position+" / "+Root(guests.GetValue(1)).position);
    }
}
