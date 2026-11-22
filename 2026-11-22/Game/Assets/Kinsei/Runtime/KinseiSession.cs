using System;
using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiSession : MonoBehaviour
{
    enum Phase { Title, Arrival, Floor, Choice, Chase, Showdown, Mirror, Release, Result, Dawn }
    enum Duty { Follow, Go, Attend, Guard, Rest, BoxOffice, FinalePost, StageWitness, Backstage, Designated, HallDoor, HallRelay }
    sealed class Person
    {
        public string name, role, pose = "idle";
        public Transform root;
        public KinseiActor actor;
        public Renderer[] portraitRenderers;
        public Duty duty;
        public Vector3 destination;
        public float hp = 100, maxHp=100, lastAction, speed, cooldown, flinchUntil;
        public Person watching,assignedGuard;
        public bool floorYielded;
        public float lastNamedHit=float.NegativeInfinity,lastPlayerHit=float.NegativeInfinity;
        public Vector3 mark;
        public float signalEnds;
        public Vector3[] path;
        public int corner;
        public Vector3 routeGoal;
        public float repathAt;
        public bool retired;
        public Vector3 Position => root.position;
    }

    readonly List<Person> crew = new(), guards = new(), upstairs = new();
    readonly List<Person> everyone = new();
    Person player, brother, elder, boss;
    Camera cam, relayCam;
    KinseiRainStreet rainStreet;
    float nextHallPicture;
    KinseiWorld club;
    KinseiBoxOffice boxOffice;
    KinseiDistrictPeople neighbours;
    KinseiStageDuet performers;
    bool showInterrupted;
    KinseiWalkways walkways;
    KinseiSound sound;
    KinseiActionLight actionLight;
    RenderTexture relayImage;
    readonly Vector3 witness = new(-3f, 0, -.6f);
    readonly Vector3 bossDoor = new(4, 0, 4);
    readonly Vector3 table = new(-1.14f, 3.21f, 7.4f);
    Phase phase = Phase.Title;
    Phase beforePause;
    bool paused, command, held, accord, escorted, reducedMotion;
    int chosen, shots;
    Person lockedTarget;
    float clock, phaseAge, angle, tilt = 12, shootDelay, hitFlash, flashTime, escapeTime, bossHp;
    float talkProgress, relayProgress, bannerUntil, lastHit, entranceTime, fpsSmooth = 60;
    string banner = "", endingTitle = "", endingText = "", outcome = "";
    Texture2D keyArt;
    Vector3 viewVelocity;
    Vector2 mapOffset;
    float chartSize=12.8f;
    bool snapCamera = true;
    bool terraceShot;
    readonly List<float> profile = new();
    readonly List<float> coachFrames = new();
    bool measure;
    int screenWidth, screenHeight;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (FindFirstObjectByType<KinseiSession>() == null)
            new GameObject("宵待町").AddComponent<KinseiSession>();
    }

    void Awake()
    {
        LoadCampaign();
        searchPath=new UnityEngine.AI.NavMeshPath();
        Application.targetFrameRate = 60;
        QualitySettings.vSyncCount = 0;
        QualitySettings.antiAliasing = 4;
        QualitySettings.shadowDistance = 32;
        QualitySettings.shadows = ShadowQuality.All;
        QualitySettings.shadowResolution = ShadowResolution.High;
        reducedMotion = PlayerPrefs.GetInt("ReducedMotion", 0) == 1;
        measure = Array.IndexOf(Environment.GetCommandLineArgs(), "-kinsei-metrics") >= 0;
        screenWidth = Screen.width;
        screenHeight = Screen.height;
        keyArt = Resources.Load<Texture2D>("Art/kinsei-key");
        club = new GameObject("金星・本館").AddComponent<KinseiWorld>();
        club.Construct();
        club.gameObject.AddComponent<KinseiHouseProps>().Dress();
        boxOffice=club.gameObject.AddComponent<KinseiBoxOffice>();
        boxOffice.Build();
        neighbours=new GameObject("宵待町の店主と常連").AddComponent<KinseiDistrictPeople>();
        neighbours.transform.SetParent(transform,false);neighbours.Initialize(club);
        performers=KinseiStageDuet.Install(club.transform);
        walkways=club.gameObject.AddComponent<KinseiWalkways>();
        cam = new GameObject("プレイヤーカメラ").AddComponent<Camera>();
        cam.tag = "MainCamera";
        rainStreet=cam.gameObject.AddComponent<KinseiRainStreet>();
        Camera.onPreCull+=ClearPortraitForeground;
        Camera.onPostRender+=RestorePortraitForeground;
        cam.allowHDR = true;
        cam.nearClipPlane = .08f;
        cam.farClipPlane = 110;
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(.022f,.015f,.032f);
        cam.gameObject.AddComponent<AudioListener>();
        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-kinsei-neutral-optics")<0)
            cam.gameObject.AddComponent<KinseiFilm>();
        relayImage = new RenderTexture(384, 320, 16, RenderTextureFormat.ARGB32);
        relayCam = new GameObject("卓間中継カメラ").AddComponent<Camera>();
        relayCam.clearFlags = CameraClearFlags.SolidColor;
        relayCam.backgroundColor = new Color(.055f,.019f,.028f);
        relayCam.nearClipPlane = .1f;
        relayCam.farClipPlane = 24;
        relayCam.fieldOfView = 30;
        relayCam.targetTexture = relayImage;
        relayCam.enabled = false;
        sound = gameObject.AddComponent<KinseiSound>();
        actionLight = gameObject.AddComponent<KinseiActionLight>();
        InitStyle();
        AddHouseLights();
        SetCamera(0);
    }

    System.Collections.IEnumerator Start()
    {
        // Construction removes non-solid ornamental primitive colliders at end-of-frame.
        yield return null;
        walkways.Rebuild(club.transform);
    }

    void AddHouseLights()
    {
        var spot = new GameObject("ダンスホールの吊りスポット").AddComponent<Light>();
        spot.transform.position = new Vector3(-3.8f,5.6f,-3.6f);
        spot.transform.LookAt(new Vector3(.4f,0,.3f));
        spot.type = LightType.Spot; spot.spotAngle = 91; spot.range = 15;
        spot.color = new Color(1,.80f,.63f); spot.intensity = 4.1f;
        spot.shadows = LightShadows.Soft; spot.shadowStrength = .54f;
        spot.shadowBias = .035f; spot.shadowNormalBias = .17f;
        QualitySettings.pixelLightCount = 6;
    }

    Person Make(string name, string role, Vector3 at, int variant)
    {
        var root = new GameObject(name);
        root.transform.SetParent(transform, false);
        root.transform.position = at;
        var person = new Person {name=name, role=role, root=root.transform, destination=at, actor=root.AddComponent<KinseiActor>()};
        person.actor.Init(role,variant);
        everyone.Add(person);
        return person;
    }

    static Vector3 FollowOffset(int index) =>
        new Vector3(index%2==0?-1.75f:1.75f,0,-1.70f-(index/2)*1.05f);

    void Populate()
    {
        player = Make("真壁","makabe",new Vector3(0,0,-10.65f),0);
        string[] names = {"辰","千代","源","新田","茂","ハル"};
        for(int i=0;i<names.Length;i++)
            crew.Add(Make(CrewName(i,names[i]),i==0?"tatsu":"ally",CrewPosition(i,player.Position+FollowOffset(i)),i));
        brother=Make("梶の弟","brother",new Vector3(-.6f,0,1.4f),1);
        guards.Add(Make("用心棒・紺谷","guard",GuardPosition(0,new Vector3(-2,0,1.9f)),0));
        guards.Add(Make("用心棒・浦","guard",GuardPosition(1,new Vector3(1.5f,0,2.7f)),1));
        elder=Make("梶","kaji",new Vector3(1.14f,3.21f,7.4f),0);
        elder.root.rotation=Quaternion.Euler(0,-90,0);
        for(int i=0;i<4;i++)
            upstairs.Add(Make("梶の連れ "+(i+1),"guard",new Vector3((i<2?-2.4f:2.4f)+(i%2)*.65f,3.2f,7.1f+(i%2)*.55f),i+2));
        boss=Make("兄貴分","boss",new Vector3(-6.62f,.49f,3.72f),0);
        foreach(var p in guards) Face(p,player.Position);
        Face(brother, player.Position); Face(boss,player.Position);
        ApplyCampaignCrew();
    }

    void StartNight() => OpenNight(false);

    void OpenNight(bool finalNight)
    {
        if(!BeginCampaign(finalNight))return;
        PrepareVisit(finalNight,0);
        Say("真壁「辰、行こか。今夜で金星を取り戻す」",4f);
        sound.Cue("door");
        if(finale)SetUpFinale();
        Mark(finale?"start-finale":"start");
    }

    void PrepareVisit(bool finalNight,int morning)
    {
        sound.ListenAtBath(false,Vector3.zero);
        rainStreet.ResetContacts();
        sound.StopFloorYields();
        ClearDawn();
        portraitOwner=null;yieldingPortrait=null;
        ClearStageWitness();
        finale=finalNight;
        shopView=ShopView.None;
        SetPerformance(true);
        boxOffice.SetCollected(false);
        boxOffice.SetTicketPress(0);
        ResetWestDispute();
        ResetStreets();
        ResetRailRide();
        ResetBackstage();
        ResetHallFronts();
        club.PutAwayMaster();
        club.SetExchangePicture(null);
        foreach(var p in everyone) Destroy(p.root.gameObject);
        everyone.Clear(); crew.Clear(); guards.Clear(); upstairs.Clear();
        operatorOnDuty=stageDirector=null;boss=brother=elder=null;
        firstPictureAt=-1;
        if(morning==0)Populate();
        else player=Make("真壁","makabe",new Vector3(0,0,-10.65f),0);
        phase=morning==0?Phase.Arrival:Phase.Dawn; phaseAge=clock=shootDelay=hitFlash=relayProgress=talkProgress=lastHit=flashTime=0;
        ResetSquads();
        entranceTime=0; escapeTime=morning==0?34:0; bossHp=100; chosen=0; shots=0; lockedTarget=null;
        command=held=accord=escorted=paused=terraceShot=false; angle=0; tilt=9; snapCamera=true;
        club.SetTactical(false); sound.SetPaused(false); attackUntil=0; moveBlend=0; nextStep=0;
        profile.Clear(); relayCam.enabled=false; club.SetMirror(0,null);club.SetAshtray(0);
        mapOffset=Vector2.zero;chartSize=12.8f;
        SetCamera(0);
    }

    void Say(string words,float seconds=3.4f) { neighbours.EndCounterLine(clock);banner=words; bannerUntil=clock+seconds; }
    void Mark(string label) { if(measure) Debug.Log($"KINSEI {label} t={clock:F2} phase={phase} pos={player.Position:F2}"); }

    void Update()
    {
        float dt=Time.deltaTime;
        if(Input.GetKeyDown(KeyCode.F12)) {
            string dir=System.IO.Path.Combine(Application.persistentDataPath,"Photos");
            System.IO.Directory.CreateDirectory(dir);
            string path=System.IO.Path.Combine(dir,DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".png");
            ScreenCapture.CaptureScreenshot(path); Debug.Log("KINSEI_PHOTO "+path);
        }
        if(phase==Phase.Title || phase==Phase.Result) {
            if(pendingEnding!=null && Input.GetKeyDown(KeyCode.R)) RetrySettlement();
            else if(Input.GetKeyDown(KeyCode.Return)) StartNight();
            else if(Input.GetKeyDown(KeyCode.F)) StartFinale();
            else if(Input.GetKeyDown(KeyCode.Alpha1))OpenDawn(1);
            else if(Input.GetKeyDown(KeyCode.Alpha2))OpenDawn(2);
            if(phase==Phase.Title && Input.GetKeyDown(KeyCode.Escape)) Application.Quit();
            return;
        }
        if(Input.GetKeyDown(KeyCode.Escape)) { TogglePause(); return; }
        if(paused) return;
        if(Input.GetKeyDown(KeyCode.Tab)) ToggleCommand();
        HallPortraitInput();
        if(!ticketActing)PortraitInput();
        if(!command && !OnAir && !AboveStreet && !ticketActing)ShopViewInput();
        dt=Mathf.Min(dt,.09f);
        clock+=dt; phaseAge+=dt;
        fpsSmooth=Mathf.Lerp(fpsSmooth,1f/Mathf.Max(Time.unscaledDeltaTime,.001f),.06f);
        if(measure && phaseAge>.2f){
            float elapsed=Time.unscaledDeltaTime*1000;
            if(profile.Count<108000)profile.Add(elapsed);
            if(railPlace==RailPlace.Coach && coachFrames.Count<108000)coachFrames.Add(elapsed);
        }
        AdvanceRail(dt);
        if(ticketActing)Motion(player,"idle"); else if(command) CommandInput(); else if(shopView==ShopView.None)PlayerInput(dt); else Motion(player,"idle");
        neighbours.Tick(clock);neighbours.LookAtNeighbours();neighbours.PoseCounterLine(clock,player.actor.EyePosition);club.TickShops(dt,player.Position);
        club.SetProgrammeLevel(sound.ReadProgrammeLevel(dt));
        if(phase==Phase.Result)return;
        if(InDawn)TickDawn(dt);
        else if(finale)SimulateFinale(dt); else Simulate(dt);
        sound.SetDialogue(clock<bannerUntil);
        float songSeconds=sound.MusicSeconds;
        club.PlayKeys(songSeconds,!showInterrupted,out var bassKey,out var melodyKey);
        performers.Tick(dt,songSeconds,bassKey,melodyKey);
        var bathInMap=command?cam.WorldToViewportPoint(KinseiWorld.BathSpeakerPosition):Vector3.back;
        bool mapShowsBath=bathInMap.z>0 && bathInMap.x>=0 && bathInMap.x<=1 && bathInMap.y>=0 && bathInMap.y<=1;
        bool streetView=phase==Phase.Arrival && (mapShowsBath || !command &&
            ((player.Position.z< -8.3f && player.Position.z> -14.2f && Mathf.Abs(player.Position.x-5.5f)<6.5f) ||
                KinseiWorld.WestBathInView(player.Position)));
        club.UpdateMarquee(!showInterrupted,streetView,Time.unscaledTime);
        sound.ListenAtBath(!command && phase==Phase.Arrival && !finale && !AboveStreet,player.Position);
        foreach(var p in everyone)
        {
            float action=(p==player || p==brother || p==elder || p==hallMirrorOperator) && phase==Phase.Mirror?relayProgress:Mathf.Clamp01(1-(clock-p.lastAction)/.36f);
            bool reacting=p.flinchUntil>clock && p.hp>0 && p.pose!="talk";
            p.actor.Pose(p.floorYielded?"floor-yield":reacting?"flinch":p.pose,p.speed,action);
            ApplyBackstageHands(p);
        }
        if(InDawn && dawnBranch==2)PoseTicketHands();
        SetCamera(dt);
    }

    void SetPerformance(bool playing)
    {
        showInterrupted=!playing;sound.QuietStage(!playing);performers.SetPerforming(playing);
    }

    void LateUpdate()
    {
        if(rainStreet) {
            bool liveNight=player!=null && phase!=Phase.Title && phase!=Phase.Result && !InDawn;
            if(liveNight) {
                if(!paused) {
                    TrackStreetWalker(0,player);
                    for(int i=0;i<crew.Count && i+1<KinseiRainStreet.WalkerCount;i++)
                        TrackStreetWalker(i+1,crew[i]);
                }
                bool viewOfStreet=command || shopView==ShopView.None || shopView==ShopView.Marquee;
                if(viewOfStreet) {
                    bool behindWalls=!command && (player.Position.z>= -8.4f || player.Position.z<= -15.8f || AboveStreet);
                    rainStreet.Draw(cam,clock,command,paused,behindWalls);
                }
            } else if(streetContactsActive)rainStreet.ResetContacts();
            streetContactsActive=liveNight;
        }
        if(phase==Phase.Mirror && !paused && clock>=nextHallPicture && SystemInfo.graphicsDeviceType!=UnityEngine.Rendering.GraphicsDeviceType.Null) {
            relayCam.transform.position=new Vector3(-3.02f,1.43f,-.23f);
            relayCam.transform.LookAt(brother.actor.EyePosition-Vector3.up*.048f);
            relayCam.Render();
            nextHallPicture=Mathf.Max(nextHallPicture+1001f/30000f,clock+.005f);
        }
    }

    bool streetContactsActive;
    void TrackStreetWalker(int seat,Person person)
    {
        bool walking=person.hp>0 && !person.retired && !person.floorYielded && person.flinchUntil<=clock &&
            (person.pose=="walk" || person.pose=="run");
        rainStreet.Track(seat,person.actor,walking,clock,measure);
    }

    void TogglePause()
    {
        paused=!paused; sound.SetPaused(paused);
        if(paused) {beforePause=phase; Mark("pause");}
        else {phase=beforePause; snapCamera=true; Mark("resume");}
    }

    void ToggleCommand()
    {
        if(InDawn)return;
        if(AboveStreet){Say("通りへ降りると指揮に戻れる");return;}
        if(pullingBackstage || phase==Phase.Mirror || (StageActive && (StageSpeaking || stageBeat==StageBeat.Settled || player.hp<=0)) || OnAir) return;
        shopView=ShopView.None;
        command=!command; club.SetTactical(command); snapCamera=true; lockedTarget=null;
        if(command && (player.Position.z< -13.9f || Mathf.Abs(player.Position.x)>8.8f))
            mapOffset=new Vector2(player.Position.x,player.Position.z-1.55f);
        if(StageActive && command){mapOffset=new Vector2(-3.5f,.45f);Motion(player,"guard");}
        sound.Cue("dial"); Mark(command?"RTS":"TPS"); SetCamera(0);
    }

    bool framingStageDesk, inspectingStageLevel, insideBathCurtain;

    void SetCamera(float dt)
    {
        Vector3 eye, focus;
        bool bathDoor=player!=null && !command && !AboveStreet && (phase==Phase.Arrival || InDawn) &&
            player.Position.x> -43.8f && player.Position.x< -34.6f && player.Position.z>= -14.68f && player.Position.z< -11.2f;
        bool inVestibule=player!=null && !command && !AboveStreet && (phase==Phase.Arrival || InDawn) &&
            player.Position.x> -43.20f && player.Position.x< -35.20f && player.Position.z< -14.68f;
        if(inVestibule!=insideBathCurtain){insideBathCurtain=inVestibule;snapCamera=true;}
        bool frameHands=InDawn && ticketActing && ticketAligned;
        bool deskShot=StageActive && stageFeedLive && clock>=stageBeatEnds-1.1f;
        bool seeLevel=StageActive && command && !StageSpeaking && stageDeskRunner!=null && Input.GetKey(KeyCode.C);
        if(seeLevel!=inspectingStageLevel){inspectingStageLevel=seeLevel;snapCamera=true;}
        if(deskShot!=framingStageDesk){framingStageDesk=deskShot;snapCamera=true;}
        if(framingTicket!=frameHands){framingTicket=frameHands;snapCamera=true;}
        if(phase==Phase.Title || phase==Phase.Result) {
            cam.orthographic=false; cam.fieldOfView=49;
            eye=new Vector3(6.3f,2.3f,-5.6f); focus=new Vector3(-2.5f,1.6f,3.5f);
        } else if(StageActive && StageSpeaking) {
            cam.orthographic=false;cam.fieldOfView=deskShot?38:44;
            if(deskShot)club.ViewStageMonitor(out eye,out focus);else StageBroadcastShot(out eye,out focus);
        } else if(seeLevel) {
            cam.orthographic=false;cam.fieldOfView=43;
            club.ViewStageFader(out eye,out focus);
        } else if(frameHands) {
            cam.orthographic=false;
            cam.fieldOfView=42;
            if(dawnStep==0){
                eye=new Vector3(-2.09f,1.53f,-6.45f);
                focus=new Vector3(-1.67f,1.11f,-6.01f);
            }else{
                eye=new Vector3(-2.47f,1.71f,-17.78f);
                focus=new Vector3(-2.17f,1.19f,-18.47f);
            }
        } else if(OnAir) {
            cam.orthographic=false;cam.fieldOfView=40;
            if(finaleStep==FinaleStep.Cooperative) {
                eye=new Vector3(15.66f,1.68f,-16.93f);
                focus=new Vector3(14.88f,1.49f,-18.13f);
            } else {
                float reveal=Mathf.SmoothStep(0,1,Mathf.InverseLerp(1.63f,2.68f,clock-firstPictureAt));
                if(reducedMotion)reveal=1;
                PressShot(reveal,pressFromWest,out eye,out focus);
                cam.fieldOfView=Mathf.Lerp(40,30,reveal);
            }
        } else if(phase==Phase.Mirror) {
            bool returnShot=phaseAge>=2.2f;
            if(returnShot!=terraceShot){terraceShot=returnShot;snapCamera=true;}
            cam.orthographic=false;cam.fieldOfView=returnShot?39:40;
            eye=returnShot?new Vector3(.99f,4.59f,6.86f):new Vector3(-3.06f,1.57f,-2.18f);
            focus=returnShot?new Vector3(.22f,4.21f,7.70f):new Vector3(-3.05f,1.29f,-.12f);
        } else if(insideBathCurtain){
            cam.orthographic=false;cam.fieldOfView=70;
            Quaternion yaw=Quaternion.Euler(0,angle,0);
            Vector3 look=Quaternion.Euler(tilt,angle,0)*Vector3.forward;
            var pivot=player.Position+Vector3.up*1.52f;
            eye=pivot+yaw*new Vector3(.34f,.035f,-.76f);
            eye.x=Mathf.Clamp(eye.x,-43.0f,-35.36f);
            eye.z=Mathf.Clamp(eye.z,-16.47f,-14.77f);
            var boom=eye-pivot;
            if(Physics.SphereCast(pivot,.08f,boom.normalized,out var obstruction,boom.magnitude,~0,QueryTriggerInteraction.Ignore) && obstruction.collider!=motor)
                eye=pivot+boom.normalized*Mathf.Max(.08f,obstruction.distance-.075f);
            focus=eye+look*3;
        } else if(railPlace==RailPlace.Coach || railPlace==RailPlace.Lift) {
            // Keep the camera inside the saloon instead of putting the roof between lens and rider.
            cam.orthographic=false;cam.fieldOfView=67;
            Vector3 look=Quaternion.Euler(Mathf.Clamp(tilt,-20,29),angle,0)*Vector3.forward;
            var pivot=player.Position+Vector3.up*1.55f;
            var right=Quaternion.Euler(0,angle,0)*Vector3.right;
            var wanted=railPlace==RailPlace.Coach?pivot+right*.27f-look*.82f:pivot+right*.3f-look*1.15f;
            var delta=wanted-pivot;
            if(Physics.SphereCast(pivot,.10f,delta.normalized,out var hit,delta.magnitude,~0,QueryTriggerInteraction.Ignore))
                wanted=pivot+delta.normalized*Mathf.Max(.025f,hit.distance-.055f);
            eye=wanted;focus=pivot+look*6;
        } else if(yieldingPortrait!=null && !command && (phase==Phase.Floor || phase==Phase.Choice || phase==Phase.Chase)) {
            cam.orthographic=false;cam.fieldOfView=49;FrameYieldingGuard(out eye,out focus);
        } else if(portraitOwner && !command && shopView==ShopView.None) {
            cam.orthographic=false;cam.fieldOfView=35;FrameConversation(out eye,out focus);
        } else if(shopView!=ShopView.None) {
            cam.orthographic=false;
            cam.fieldOfView=shopView switch { ShopView.Wardrobe=>63, ShopView.Marquee=>61, ShopView.Records=>52, _=>42 };
            FrameCounter(out eye,out focus);
        } else if(command) {
            cam.orthographic=true; cam.orthographicSize=Mathf.Max(chartSize,15f/cam.aspect);
            float centreZ=HallFrontsVisible?-1.05f:1.55f;
            focus=new Vector3(mapOffset.x,0,centreZ+mapOffset.y);eye=focus+new Vector3(0,18,-11f);
        } else {
            cam.orthographic=false; cam.fieldOfView=57;
            Vector3 look=Quaternion.Euler(tilt,angle,0)*Vector3.forward;
            Vector3 right=Quaternion.Euler(0,angle,0)*Vector3.right;
            Vector3 shoulder=player.Position+Vector3.up*1.53f+right*.49f;
            if(bathDoor || player.Position.x< -8.5f && player.Position.z> -8f) {
                var pivot=player.Position+Vector3.up*1.53f;
                if(Physics.SphereCast(pivot,.12f,right,out var shoulderHit,.49f,~0,QueryTriggerInteraction.Ignore))
                    shoulder=pivot+right*Mathf.Max(0,shoulderHit.distance-.025f);
            }
            eye=shoulder-look*2.55f; focus=shoulder+look*8;
            // Shorten the boom against the built environment; actors do not own camera colliders.
            Vector3 delta=eye-shoulder;
            if(Physics.SphereCast(shoulder,.12f,delta.normalized,out var hit,delta.magnitude,~0,QueryTriggerInteraction.Ignore))
                eye=shoulder+delta.normalized*Mathf.Max(.24f,hit.distance-.08f);
        }
        if(snapCamera || dt<=0) {cam.transform.position=eye; viewVelocity=Vector3.zero;}
        else cam.transform.position=Vector3.SmoothDamp(cam.transform.position,eye,ref viewVelocity,.085f,80f,dt);
        if(bathDoor) {
            // Rotation can sweep the damped camera through the projecting CRT between two clear positions.
            var pivot=player.Position+Vector3.up*1.53f;
            var boom=cam.transform.position-pivot;
            if(Physics.SphereCast(pivot,.12f,boom.normalized,out var face,boom.magnitude,~0,QueryTriggerInteraction.Ignore) && face.collider!=motor) {
                cam.transform.position=pivot+boom.normalized*Mathf.Max(.02f,face.distance-.045f);
                viewVelocity=Vector3.zero;
            }
        }
        cam.transform.LookAt(focus); snapCamera=false;
    }

    void End(string id,string title,string body)
    {
        if(phase==Phase.Result || InDawn)return;
        sound.ListenAtBath(false,Vector3.zero);
        ClearStageWitness();
        ClearFloorAssignments();sound.StopFloorYields();
        ReleaseHallTeam(0);ReleaseHallTeam(1);
        floorGuardReport=FloorGuardReport();
        outcome=id; endingTitle=title; endingText=body; settlementMessage=FinishCampaign(id=="showdown" || id=="stage-broadcast"?"pursuit":id); phase=Phase.Result; command=false;
        SetPerformance(true);
        relayCam.enabled=false; sound.Cue(id=="loss"?"loss":"result"); Mark("ending-"+id);
        ReportFrames(id);
    }

    void ReportFrames(string scene) => WriteFrameReport(scene,profile);

    void WriteFrameReport(string scene,List<float> samples)
    {
        if(samples.Count==0)return;
        samples.Sort();
        Debug.Log($"KINSEI_FRAME n={samples.Count} median_ms={samples[samples.Count/2]:F2} p95_ms={samples[(int)(samples.Count*.95f)]:F2} size={Screen.width}x{Screen.height} gpu={SystemInfo.graphicsDeviceName} scene={scene}");
        samples.Clear();
    }

    void OnApplicationFocus(bool focus)
    {
        if(!focus && !paused && phase!=Phase.Title && phase!=Phase.Result) TogglePause();
    }
    void OnDestroy()
    {
        Camera.onPreCull-=ClearPortraitForeground;
        Camera.onPostRender-=RestorePortraitForeground;
        RestorePortraitForeground(cam);
        if(relayImage!=null) { relayImage.Release(); Destroy(relayImage); }
        if(stageRingMaterial!=null) Destroy(stageRingMaterial);
    }
}

