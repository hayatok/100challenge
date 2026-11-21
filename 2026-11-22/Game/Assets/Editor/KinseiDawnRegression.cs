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

    static void AnimateTicket(Transform paper,KinseiActor actor,bool pickup)
    {
        var people=(KinseiDistrictPeople)Field(game,"neighbours");
        float clock=(float)Field(game,"clock");
        Vector3 previous=paper.position;
        var world=(KinseiWorld)Field(game,"club");
        var clerkWrist=people.Owner(1).transform.Find("Pelvis/Spine/Right shoulder/Elbow/Wrist");
        var hand=clerkWrist.Find("Anatomical hand").GetComponent<SkinnedMeshRenderer>();
        var baked=new Mesh();
        var sleeveExtension=hand.transform.Find("Wrist beneath cotton").GetComponent<SkinnedMeshRenderer>();
        Require(sleeveExtension && sleeveExtension.bones[0]==clerkWrist && sleeveExtension.bones[2]==clerkWrist.parent,
            "Clerk wrist skin does not continue from the hand into the sleeve");
        float minimumDuringPull=float.PositiveInfinity,maximumContactError=0,releaseHeight=0;
        var raw=hand.sharedMesh.vertices;
        var wristBind=hand.sharedMesh.bindposes[0];
        bool observedPull=false,observedLift=false;
        for(int i=0;i<300 && (bool)Field(game,"ticketActing");i++){
            clock+=1f/60;people.Tick(clock);
            actor.Pose("idle",0,0);Call("TickDawn",1f/60);Call("PoseTicketHands");
            // Delivery starts after relocating the player to the shop, so settle the carrying pose first.
            if(i>0 && (bool)Field(game,"ticketAligned"))
                Require(Vector3.Distance(previous,paper.position)<.06f,"Sheet jumped during the stroke");
            float t=(float)Field(game,"ticketTime");
            if(!pickup && t>=1.65f && t<=2.68f){
                hand.BakeMesh(baked,true);
                float padDistance=float.PositiveInfinity,nearestHeight=float.PositiveInfinity;
                int vertexIndex=-1;
                foreach(var vertex in baked.vertices){
                    vertexIndex++;
                    var point=hand.transform.position+hand.transform.rotation*vertex;
                    var local=world.TicketTray.InverseTransformPoint(point);
                    if(t>=1.90f && t<=2.50f){
                        // All points are wrist-weighted by the anatomical cuff fitting. Check the
                        // actual weighted model alongside Unity's CPU-baked positions.
                        var physical=clerkWrist.TransformPoint(wristBind.MultiplyPoint3x4(raw[vertexIndex]));
                        minimumDuringPull=Mathf.Min(minimumDuringPull,world.TicketTray.InverseTransformPoint(physical).y);
                    }
                    padDistance=Mathf.Min(padDistance,Vector3.Distance(point,world.TrayFingerRest));
                    nearestHeight=Mathf.Min(nearestHeight,local.y);
                    bool rearRim=Mathf.Abs(local.z+.135f)<=.007f && Mathf.Abs(local.x)<=.21f;
                    if(rearRim && local.y<.0525f) throw new InvalidOperationException($"Fitted hand penetrated the brass rim t={t:F4} vertex={vertexIndex} local={local.ToString("F5")} wrist={clerkWrist.position.ToString("F4")}");
                }
                if(t>=1.90f && t<=2.50f){
                    Require(padDistance<.006f && nearestHeight>=.0525f,$"No fingertip contact t={t:F4}, error={padDistance:F5}, lowest={nearestHeight:F5}");
                    maximumContactError=Mathf.Max(maximumContactError,padDistance);
                    observedPull=true;
                }
                if(t>=2.65f){
                    Require(nearestHeight>.108f,"Clerk released the tray through the rim instead of lifting the fingers");
                    releaseHeight=nearestHeight;observedLift=true;
                }
            }
            previous=paper.position;
        }
        if(!pickup){
            Require(minimumDuringPull>=.053f,$"Actual fingertip below rim during pull: {minimumDuringPull:F5}");
            Debug.Log($"KINSEI_TRAY_CONTACT minY={minimumDuringPull:F5} rimY=0.05300 maxError={maximumContactError:F5} liftedY={releaseHeight:F5}");
        }
        UnityEngine.Object.DestroyImmediate(baked);
        Require(pickup || (observedPull && observedLift),"Tray contact or lift was not observed");
        Require(Step==(pickup?1:2),"Timed ticket gesture did not complete");
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
        var printer=(KinseiBoxOffice)Field(game,"boxOffice");
        var world=(KinseiWorld)Field(game,"club");
        Transform paper=printer.PrintedTicket,press=paper.parent;
        var pawn=Field(game,"player");var actor=(KinseiActor)Field(pawn,"actor");
        Call("PlayerInput",0f);
        Action(new Vector3(-1.48f,0,-6.32f),"一番券を受け取る");
        Require(Step==0 && paper.parent==press,"Ticket left press before fingers reached it");
        Call("Interact"); // key repeat cannot skip the stroke
        AnimateTicket(paper,actor,true);
        Require(paper.parent==actor.LeftWrist,"Printed sheet was replaced at pickup");
        Require(Step==1 && (GameObject)Field(game,"dawnTicket")!=null,"No ticket is being carried");
        Stand((Vector3)Field(game,"NeedleDesk"));Call("Interact");
        Require(!(bool)Field(game,"ticketActing"),"Handoff accepted from across the furniture");
        Action(new Vector3(-2.65f,.065f,-18.56f),"一番券を渡す");
        AnimateTicket(paper,actor,false);
        Require(paper.parent==world.TicketTray && world.TicketTray.localPosition.z< -18.55f,"Clerk did not draw the original sheet and tray");
        Require(Mathf.Abs(paper.localPosition.y-.0135f)<.001f,"Ticket did not rest on the tray");
        Require(Step==2 && (GameObject)Field(game,"dawnTicket")==null,"Ticket handoff failed");
        Call("OpenDawn",2);Require(Step==0 && paper.parent==press && !paper.gameObject.activeSelf,"Replay retained work progress or lost the original sheet");
        for(int i=0;i<121;i++)Call("TickDawn",1f/60);
        Action(new Vector3(-1.48f,0,-6.32f),"一番券を受け取る");
        Call("TogglePause");Require((bool)Field(game,"paused") && Step==0,"Pause skipped the pickup");
        Call("TogglePause");Call("ReturnToTitle");
        Require(!paper.gameObject.activeSelf && paper.parent==press && !(bool)Field(game,"ticketActing"),"Aborted pickup survived title return");
        Call("OpenDawn",1);
        Require(Phase=="Dawn" && Step==0 && before==File.ReadAllText(FilePath),"Both unlocked mornings did not remain available");
        int nights=store.Load().nights;Call("ReturnToTitle");Call("StartNight");
        Require(Phase=="Arrival" && (int)Field(game,"dawnBranch")==0 && store.Load().nights==nights+1,"Normal start did not resume");
    }
}
