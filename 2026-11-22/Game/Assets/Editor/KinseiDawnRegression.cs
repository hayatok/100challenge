using System;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiDawnRegression
{
    const string Pending="KinseiDawnRegression.pending";
    const BindingFlags Access=BindingFlags.Static|BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static KinseiSession game;
    static string directory;
    static double waitingSince;
    static KinseiDawnRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=WhenReady;}
    public static void Run()
    {
        string temp=Path.Combine(Path.GetTempPath(),"KinseiDawn-"+Guid.NewGuid().ToString("N"));
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",temp);
        SessionState.SetBool(Pending,true);EditorApplication.update-=WhenReady;EditorApplication.update+=WhenReady;
        EditorApplication.EnterPlaymode();
    }
    static object Field(object target,string name)=>target.GetType().GetField(name,Access).GetValue(target);
    static object Call(string name,params object[] args)=>typeof(KinseiSession).GetMethod(name,Access).Invoke(game,args);
    static string Phase=>Field(game,"phase").ToString();
    static int Step=>(int)Field(game,"dawnStep");
    static string FilePath=>Path.Combine(directory,"kinsei-ledger.json");
    static void Require(bool ok,string why){if(!ok)throw new InvalidOperationException(why+" ("+Phase+")");}
    static void Stand(Vector3 at)
    {
        ((Transform)Field(Field(game,"player"),"root")).position=at;Physics.SyncTransforms();
    }
    static void Action(Vector3 at,string part)
    {
        Stand(at);Require(((string)Call("Interaction")).Contains(part),"Missing action "+part);Call("Interact");
    }
    static void WhenReady()
    {
        if(!EditorApplication.isPlaying)return;
        game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        var routes=game ? Field(game,"walkways") as KinseiWalkways : null;
        if(routes==null || !routes.Ready){
            if(waitingSince==0)waitingSince=EditorApplication.timeSinceStartup;
            if(EditorApplication.timeSinceStartup-waitingSince>30){
                Debug.LogError("Dawn regression could not start the game and its walkways");
                EditorApplication.update-=WhenReady;SessionState.EraseBool(Pending);EditorApplication.Exit(1);
            }
            return;
        }
        EditorApplication.update-=WhenReady;SessionState.EraseBool(Pending);
        try{
            directory=Environment.GetEnvironmentVariable("KINSEI_SAVE_DIRECTORY");
            Inspect();
            Debug.Log("KINSEI_DAWN_PASS fresh / legacy / branch gates / both jobs / ticket / rail / pause / readonly ledger / return to night");
            EditorApplication.Exit(0);
        }catch(Exception ex){Debug.LogException(ex);EditorApplication.Exit(1);}
    }

    static void Inspect()
    {
        Call("OpenDawn",1);Call("OpenDawn",2);
        Require(Phase=="Title" && !File.Exists(FilePath),"A new game opened or recorded a morning");
        Directory.CreateDirectory(directory);
        File.WriteAllText(FilePath,"{\"version\":1,\"seal\":\"金星・出納帳\",\"nights\":1,\"completed\":1,\"lastSettledNight\":1,\"kajiPromise\":true}");
        Call("LoadCampaign");Call("OpenDawn",1);Require(Phase=="Title","Legacy ledger unlocked a morning");
        var store=new KinseiLedgerStore(directory);
        foreach(string end in new[]{"pursuit","cooperative"})
            store.Change(l=>{l.nights++;l.Settle(end,0);});
        Call("LoadCampaign");
        string before=File.ReadAllText(FilePath);
        Call("OpenDawn",2);Require(Phase=="Title","Exclusive morning opened without exclusive return");
        Call("OpenDawn",1);Require(Phase=="Dawn" && Step==0,"Cooperative morning did not open");
        Stand((Vector3)Field(game,"RelayDesk"));Call("Interact");Require(Step==0,"Out-of-order request");
        Action((Vector3)Field(game,"LotusDesk"),"リクエスト");
        Action((Vector3)Field(game,"RelayDesk"),"送出卓");
        Require(Step==2 && !(bool)Field(game,"showInterrupted"),"Programme did not start");
        var music=(AudioSource)Field(Field(game,"sound"),"music");
        Require(music.clip && music.clip.name=="sakai-morning","Request did not play its score");
        Call("TogglePause");Require((bool)Field(game,"paused"),"Morning cannot pause");Call("TogglePause");
        Call("ToggleCommand");Require(!(bool)Field(game,"command"),"Morning entered a combat command");
        Call("Attack",false,false);Call("End","loss","invalid","invalid");
        Require(Phase=="Dawn" && (int)Field(game,"shots")==0,"Combat or settlement ran");
        Stand(new Vector3(-8,0,-19.48f));
        Require(((string)Call("Interaction")).Contains("上がる"),"Morning train is inaccessible");Call("Interact");
        for(int i=0;i<300;i++)Call("AdvanceRail",1f/60);
        Require(Field(game,"railPlace").ToString()=="Platform","Morning lift did not carry player");
        Call("ReturnToTitle");
        Require(Phase=="Title" && Field(game,"railPlace").ToString()=="Street" && before==File.ReadAllText(FilePath),"Free exploration changed the ledger or kept the passenger");
        Require(music.clip && music.clip.name=="kinsei-waltz","Night music did not return");
        store.Change(l=>{l.nights++;l.Settle("exclusive",0);});Call("LoadCampaign");
        before=File.ReadAllText(FilePath);
        var phase=typeof(KinseiSession).GetField("phase",Access);
        phase.SetValue(game,Enum.Parse(phase.FieldType,"Result"));
        Call("OpenDawn",2);Require(Phase=="Dawn" && Step==0,"Result cover cannot open morning");
        for(int i=0;i<121;i++)Call("TickDawn",1f/60);
        Action(KinseiBoxOffice.Counter,"一番券を受け取る");
        Require(Step==1 && (GameObject)Field(game,"dawnTicket")!=null,"No ticket is being carried");
        Action((Vector3)Field(game,"NeedleDesk"),"一番券を渡す");
        Require(Step==2 && (GameObject)Field(game,"dawnTicket")==null,"Ticket handoff failed");
        Call("OpenDawn",2);Require(Step==0,"Replay retained work progress");
        Call("ReturnToTitle");Call("OpenDawn",1);
        Require(Phase=="Dawn" && Step==0 && before==File.ReadAllText(FilePath),"Both unlocked mornings did not remain available");
        int nights=store.Load().nights;Call("ReturnToTitle");Call("StartNight");
        Require(Phase=="Arrival" && (int)Field(game,"dawnBranch")==0 && store.Load().nights==nights+1,"Normal start did not resume");
    }
}
