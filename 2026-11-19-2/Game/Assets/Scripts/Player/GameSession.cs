using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    [DefaultExecutionOrder(-100)]
    public sealed partial class GameSession : MonoBehaviour
    {
        GameSim sim;
        readonly List<Unit> roster = new List<Unit>(9);
        readonly Dictionary<int,int> lastShots = new Dictionary<int,int>();
        readonly Dictionary<int,float> lastHealth = new Dictionary<int,float>();
        readonly Dictionary<int,Vector3> lastPositions = new Dictionary<int,Vector3>();
        readonly Dictionary<int,float> walkSpeed = new Dictionary<int,float>();
        static readonly string[] Orders = {"移動","警戒","誘導","整備","補給"};
        static readonly string[] Squads = {"警備班","誘導班","整備班"};
        static readonly string[] Circuits = {"排水","昇降機","防護柵"};
        GameUI ui;
        WorldView world;
        FieldAudio sound;
        Camera eye;
        int orderIndex, lastBoarded, lastWave, lastSector, difficulty, missionIndex;
        float departureTime, voiceUntil;
        bool wasReady;
        string voiceLine, speaker;
        FieldEffects fx;
        float recoil, hitTime, hurtTime, pitch, lastOwnHealth, sightNoise, simCarry;
        Vector3 mapCenter;
        float zoom = 23;
        bool forceTouch, lastFieldOverlay;
        public string Phase {get; private set;} = "Title";
        public string Mode => sim.Controlled == null ? "RTS" : "FPS";
        public int MissionIndex => missionIndex;
        public int Unlocked => Mathf.Clamp(sim.Unlocked, 0, 7);
        public int SelectedSquad {get; private set;}
        public int SelectedSoldier {get; private set;}
        public int Saved => sim.Boarded;
        bool ShowingDuty => IsDuty && (Phase=="Playing" || Phase=="Paused" || Phase=="Debrief");
        public int Needed => ShowingDuty ? sim.Mission.quota : GameSim.Missions[missionIndex].quota;
        public int Population => ShowingDuty ? sim.Mission.population : GameSim.Missions[missionIndex].population;
        public int SectorNumber => sim.IsReady ? sim.Sector+1 : 1;
        public int SectorCount => sim.IsReady ? sim.SectorCount : 1;
        public int SectorGoal => sim.IsReady ? sim.SectorGoal : Needed;
        public string SectorName => sim.IsReady ? sim.SectorName : "";
        public int Supply => sim.Stock;
        public int Dead => sim.Lost;
        public int Kills => sim.Kills;
        public int Ammo => Current?.ammo ?? 0;
        public float Stamina01 => Current?.stamina ?? 1;
        public int Reserve => Current?.reserve ?? 0;
        internal Unit Current => sim.Controlled ?? (SelectedSoldier < roster.Count ? roster[SelectedSoldier] : null);
        public float Health01 => Current == null ? 0 : Mathf.Clamp01(Current.hp / Mathf.Max(1,Current.maxHp));
        public float Progress01 => Mathf.Clamp01((float)Saved / Mathf.Max(1,Needed));
        public float Elapsed => sim.Elapsed;
        public float Remaining => sim.Remaining;
        public float Water01 => sim.Water;
        public float Repair01 => sim.Repair;
        public bool PassageOpen => sim.PassageOpen;
        public bool CanDepart => sim.CanDepart;
        public bool CanBuild => sim.IsReady && sim.Site == 0;
        public int DifficultyIndex => difficulty;
        public int CampaignRescued => sim.CampaignRescued;
        public int StockDelivered => sim.Delivered;
        public int DepotRounds => sim.DepotRounds;
        public int MedicalSupplies => sim.MedicalSupplies;
        public int VolunteerCount => sim.VolunteerCount;
        public float MasterVolume {get;private set;}
        public float LookSensitivity {get;private set;}
        public bool ReducedMotion {get;private set;}
        public bool LargeText {get;private set;}
        public bool TouchUI => forceTouch || Application.isMobilePlatform || FieldTouches.Count > 0;
        public bool Won => sim.Result == SimResult.Victory;
        public bool CanContinue => sim.HasSave;
        public string Objective => sim.IsReady ? sim.Objective : "";
        public string Radio => Time.time<voiceUntil ? voiceLine : sim.IsReady ? sim.Notice : "";
        public string RadioSpeaker => Time.time<voiceUntil ? speaker : "現場";
        public string ContextAction
        {
            get
            {
                if(PushedColumn>=0)return "担架の引き継ぎ";
                if(CanOpenLocalMarketGate)return "横戸を開ける";
                if(sim.CanTakeWingFreight)return sim.WingFreightLabel+"を運ぶ";
                if(sim.CanRejoinWingResident)return sim.WingResidentName+"に付き添う";
                if(AtWingDesk>=0)return "現場の対応を選ぶ";
                string regular=sim.InteractionHint;
                if(!string.IsNullOrEmpty(regular))return regular;
                return NearbyColumn()>=0?"避難列に声をかける":"";
            }
        }
        public string SoldierName => Current?.name ?? "";
        public string MissionName(int i) => GameSim.Missions[i].title;
        public string MissionBrief(int i) => GameSim.Missions[i].briefing;
        public string DistrictName(int i) => GameSim.Missions[i].district;
        public string SquadName(int i) => Squads[Mathf.Clamp(i,0,2)];
        public string RosterName(int i) => Valid(i) ? roster[i].name : "";
        public bool RosterAlive(int i) => Valid(i) && roster[i].active && roster[i].hp > 0;
        public string RosterStatus(int i)
        {
            if (!RosterAlive(i)) return "戦闘不能";
            var u=roster[i];
            if (u.escortId>=0) return "介助中";
            if (u.carryingCargo) return "運搬中";
            if (u.reload>0) return "装填中";
            if (u.hp<u.maxHp*.55f) return "負傷";
            return SquadOrderName(u.squad);
        }
        public int RosterCount => roster.Count;
        public int RosterSquad(int i) => Valid(i) ? roster[i].squad : -1;
        public int CircuitCount => sim.IsReady && sim.Mission.rail ? 3 : 0;
        public string CircuitName(int i) => Circuits[i];
        public bool CircuitOn(int i) => (sim.PowerMask & (1<<i))!=0;
        public string CurrentOrder => Orders[orderIndex];
        public string SquadOrderName(int i) => Orders[(int)sim.OrderFor(i)];
        public bool IsMissionComplete(int i) => sim.IsComplete(i);
        public int Best(int i) => sim.Best(i);
        bool Valid(int i) => i>=0 && i<roster.Count;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (!FindFirstObjectByType<GameSession>()) new GameObject("Evacuation Control").AddComponent<GameSession>();
        }

        void Awake()
        {
            sim = new GameSim();
            Application.targetFrameRate = Application.isMobilePlatform ? 30 : 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Input.multiTouchEnabled = true;
            Input.simulateMouseWithTouches = true;
            QualitySettings.vSyncCount = 0;
            MasterVolume = PlayerPrefs.GetFloat("evac.volume",.8f);
            LookSensitivity = PlayerPrefs.GetFloat("evac.sensitivity",1);
            ReducedMotion = PlayerPrefs.GetInt("evac.steady",0)!=0;
            LargeText = PlayerPrefs.GetInt("evac.text",0)!=0;
            difficulty = Mathf.Clamp(PlayerPrefs.GetInt("evac.difficulty",1),0,2);
            forceTouch = System.Array.IndexOf(System.Environment.GetCommandLineArgs(),"-touch-ui")>=0;
#if UNITY_WEBGL && !UNITY_EDITOR
            forceTouch = BrowserTouch() != 0;
#endif
            eye = Camera.main;
            if (!eye) {eye = new GameObject("現場視点").AddComponent<Camera>(); eye.tag="MainCamera";}
            if (!eye.GetComponent<AudioListener>()) eye.gameObject.AddComponent<AudioListener>();
            eye.nearClipPlane=.045f; eye.farClipPlane=240;
            eye.backgroundColor=new Color(.12f,.155f,.17f); eye.clearFlags=CameraClearFlags.SolidColor;
            world=gameObject.AddComponent<WorldView>();
            sound=gameObject.AddComponent<FieldAudio>();
            fx=gameObject.AddComponent<FieldEffects>();
            ui=gameObject.AddComponent<GameUI>();
            Change("Title");
        }
#if UNITY_WEBGL && !UNITY_EDITOR
        [System.Runtime.InteropServices.DllImport("__Internal")] static extern int BrowserTouch();
        [System.Runtime.InteropServices.DllImport("__Internal")] static extern void BrowserWantsLook(int wanted);
#endif
        void Change(string p)
        {
            Phase=p;
            UpdateCursor();
            AudioListener.pause=p=="Paused";
            AudioListener.volume=MasterVolume;
            sound.SetPlay(p=="Playing");
            if (p!="Playing") ClearTouches();
        }
        void UpdateCursor()
        {
            bool lockIt = Phase=="Playing" && sim.Controlled!=null && !TouchUI && (ui==null || !ui.FieldOverlay);
#if UNITY_WEBGL && !UNITY_EDITOR
            BrowserWantsLook(lockIt?1:0);
#else
            Cursor.lockState=lockIt ? CursorLockMode.Locked : CursorLockMode.None;
#endif
            Cursor.visible=!lockIt;
        }
        public void SetDifficulty(int i) {difficulty=Mathf.Clamp(i,0,2);PlayerPrefs.SetInt("evac.difficulty",difficulty);}
        public void SetVolume(float v) {MasterVolume=Mathf.Clamp01(v);AudioListener.volume=MasterVolume;PlayerPrefs.SetFloat("evac.volume",MasterVolume);}
        public void SetSensitivity(float v) {LookSensitivity=Mathf.Clamp(v,.25f,3f);PlayerPrefs.SetFloat("evac.sensitivity",LookSensitivity);}
        public void SetReducedMotion(bool b) {ReducedMotion=b;PlayerPrefs.SetInt("evac.steady",b?1:0);}
        public void SetLargeText(bool b) {LargeText=b;PlayerPrefs.SetInt("evac.text",b?1:0);}
        public void Brief(int i)
        {
            if (i<0 || i>Unlocked) return;
            missionIndex=i; sound.Signal("paper"); Change("Briefing");
        }
        public void Deploy() {sim.StartMission(missionIndex,(Difficulty)difficulty);EnterField();}
        public void Continue() {if(sim.Load()) EnterField();}
        public void RetryCheckpoint()
        {
            bool duty=sim.IsDuty;
            if(sim.LoadCheckpoint()) EnterField();
            else if(duty) RetryDuty();
            else Deploy();
        }
        public void DebriefNext()
        {
            if(!Won) {Brief(missionIndex);return;}
            if(missionIndex==7) ShowEnding(); else Brief(missionIndex+1);
        }
        public void Home() {if(Phase=="Playing"||Phase=="Paused") sim.Save(); Change("Title");PlayerPrefs.Save();}
        public void ShowEnding() {if(sim.IsComplete(7)) Change("Ending");}
        public void Pause() {if(Phase=="Playing") {sim.Save();Change("Paused");}}
        public void Resume() {if(Phase=="Paused") Change("Playing");}
        void OnApplicationPause(bool b) {if(b) Pause();}
        void OnApplicationFocus(bool b)
        {
#if UNITY_EDITOR || EVAC_INSPECTION
            if(inspectionFolder!=null)return;
#endif
            if(!b && Phase=="Playing") Pause();
        }
        void OnApplicationQuit() {if(Phase=="Playing"||Phase=="Paused") sim.Save();PlayerPrefs.Save();}

        void EnterField()
        {
            EndWaypointEdit();
            missionIndex=sim.Mission.index;
            difficulty=(int)sim.Level;
            roster.Clear();
            lastShots.Clear();lastHealth.Clear();lastPositions.Clear();walkSpeed.Clear();
            foreach(var u in sim.Units) if(u.kind==UnitKind.Soldier) roster.Add(u);
            SelectedSoldier=sim.Controlled!=null ? Mathf.Max(0,roster.IndexOf(sim.Controlled)):0;
            SelectedSquad=roster.Count>0?roster[SelectedSoldier].squad:0;
            orderIndex=(int)sim.OrderFor(SelectedSquad);
            EndViewTransfer();
            world.Build(missionIndex);
            fx.ResetField();
            choosingBeacon=false;seenBeacon=sim.BeaconSerial;beaconGlint=0;
            wingReported=sim.WingActive;wingPin=-1;followedColumn=-1;
            marketPaths=null;
            ReleaseAim();
            mapCenter=Vector3.Lerp(sim.Mission.assembly, sim.Mission.exit,.5f);
            zoom=TouchUI?25:22;
            mapYaw=-19;
            lastBoarded=Saved;lastWave=sim.Wave;lastSector=sim.Sector;departureTime=0;pitch=0;hitTime=hurtTime=recoil=simCarry=0;
            lastOwnHealth=Health01;wasReady=sim.CanDepart;
            Change("Playing"); UpdateObjectiveSigns(); FrameCamera(0,true); SyncWorld(0);
            if(sim.Result!=SimResult.Active){Finish();return;}
            sound.Signal("dispatch");
            Receive("field_pa","指令","各班、出動してください。",true);
        }
        void Receive(string clip,string from,string line,bool urgent=false)
        {
            float duration=sound.Say(clip,urgent);
            if(duration<=0)return;
            speaker=from;voiceLine=line;voiceUntil=Time.time+Mathf.Max(duration,2.1f);
        }
        public void SelectSquad(int squad)
        {
            for(int i=0;i<roster.Count;i++) if(roster[i].squad==squad&&RosterAlive(i)) {SelectSoldier(i);break;}
        }
        public void SelectSoldier(int i)
        {
            if(!RosterAlive(i)) return;
            if(SelectedSquad!=roster[i].squad)EndWaypointEdit();
            SelectedSoldier=i;SelectedSquad=roster[i].squad;
            orderIndex=(int)sim.OrderFor(SelectedSquad);sound.Signal("dial");
        }
        public void Possess(int i)
        {
            if(Phase!="Playing"||!RosterAlive(i)||!sim.Possess(roster[i].id)) return;
            EndWaypointEdit();
            SelectSoldier(i);pitch=0;recoil=0;choosingBeacon=false;ReleaseAim();lastOwnHealth=Health01;
            BeginViewTransfer(sim.Controlled,true);
            Change("Playing");FrameCamera(0,true); sound.Signal("radio");
        }
        public void CommandMode()
        {
            if(sim.Controlled!=null){mapCenter=sim.Controlled.pos;BeginViewTransfer(sim.Controlled,false);}
            sim.Release(); recoil=0;ReleaseAim();Change("Playing");FrameCamera(0,true);sound.Signal("radio");
        }
        public void CycleOrder() {orderIndex=(orderIndex+1)%Orders.Length;sound.Signal("dial");}
        public void SelectOrder(int order) {orderIndex=Mathf.Clamp(order,0,Orders.Length-1);sound.Signal("dial");}
        void IssueOrder(Vector3 p)
        {
            if(Phase!="Playing" || sim.Controlled!=null) return;
            sim.Order(SelectedSquad,(SquadOrder)orderIndex,p);
            ShowOrderPin(p);sound.Signal("dispatch");
            Receive("accepted_pa",SquadName(SelectedSquad),"了解。現場に向かいます。");
        }
        public void OrderAtObjective()
        {
            var m=sim.Mission;
            Vector3 dest=orderIndex switch {1=>m.gate,2=>m.assembly,3=>sim.EngineerDestination,4=>m.depot,_=>m.gate};
            IssueOrder(dest);
        }
        public void OrderAtSupply() {orderIndex=(int)SquadOrder.Supply;IssueOrder(sim.Mission.depot);}
        public void ToggleCircuit(int i) {if(i>=0&&i<CircuitCount && sim.SetPower((PowerCircuit)i,!CircuitOn(i)))sound.Signal("relay");}
        public void BuildClinic() {if(sim.Build(Facility.Clinic))sound.Signal("relay");}
        public void BuildWorkshop() {if(sim.Build(Facility.Workshop))sound.Signal("relay");}
        public void TryAction()
        {
            FinishTransferForInput();
            int pushed=PushedColumn;
            if(pushed>=0){ui.OpenColumn(pushed);return;}
            if(CanOpenLocalMarketGate && ColumnAction(0,4))return;
            if(sim.CanTakeWingFreight && sim.WingTakeCart()){sound.Signal("action");return;}
            if(sim.CanRejoinWingResident && sim.WingRejoin()){sound.Signal("action");return;}
            int station=AtWingDesk;
            if(station>=0){ui.OpenWing(station);return;}
            if(!string.IsNullOrEmpty(sim.InteractionHint) && sim.Interact()){sound.Signal("action");return;}
            int column=NearbyColumn();
            if(column>=0)ui.OpenColumn(column);
        }
        public void Reload() {if(sim.Reload())sound.Signal("reload");}
        public void FireOnce()
        {
            var u=sim.Controlled; if(u==null || Phase!="Playing") return;
            FinishTransferForInput();
            int shots=u.shots; int ammo=u.ammo;
            Vector3 direction=Quaternion.Euler(pitch-(ReducedMotion?0:cameraKick),u.yaw,0)*Vector3.forward;
            sim.Shoot(direction);
            if(u.shots!=shots||u.ammo<ammo)
            {
                recoil=1;
                kickVelocity+=aimBlend>.7f?12:20;
                sound.Signal("fire");fx.Flash(eye.transform,ReducedMotion);
                if(!sim.LastShotHit && sim.SurfaceContact(u.pos+Vector3.up*1.52f,direction,out var impact,out bool road))
                    fx.Surface(impact,direction,road,ReducedMotion);
                if(sim.LastShotHit) hitTime=.16f;
            }
        }
        public void Depart()
        {
            if(Phase!="Playing" || !sim.Depart())return;
            CommandMode(); mapCenter=sim.Mission.exit; zoom=12;
            departureTime=2.8f; sound.Signal("arrival");
            Receive("arrival_pa","指令","乗車を確認。避難輸送を出発します。",true);
        }
        void Finish() {sound.Signal(Won?"arrival":"loss");Change("Debrief");}
        void UpdateObjectiveSigns()
        {
            var m=sim.Mission;
            world.SetObjective("集合",m.assembly,0,true);
            world.SetObjective("通路",m.gate,1,true);
            world.SetObjective("乗車",m.exit,2,true);
            world.SetObjective("補給",m.depot,3,true);
            world.SetObjective("設備",m.works,4,sim.RepairRequired);
            world.SetObjective("資材",m.cache,5,sim.CargoRequired);
        }
        void Update()
        {
#if UNITY_WEBGL && EVAC_WEB_TEST && !UNITY_EDITOR
            ReportControls();
#endif
            if(ControlPreferences.CapturingKey)return;
            if(lastFieldOverlay!=ui.FieldOverlay){lastFieldOverlay=ui.FieldOverlay;ClearTouches();UpdateCursor();}
            if(Phase=="Playing" && Input.GetKeyDown(KeyCode.F2)) {ui.SearchHotkey();UpdateCursor();ClearTouches();return;}
            if(Phase=="Playing" && Input.GetKeyDown(KeyCode.Escape) && ui.CloseFieldOverlay()){UpdateCursor();ClearTouches();return;}
            if(Input.GetKeyDown(KeyCode.F12))CaptureFrame();
            if(Input.GetKeyDown(KeyCode.Escape) && ui.TryBackFromSettings())return;
            if(Input.GetKeyDown(KeyCode.Escape)) {if(Phase=="Paused")Resume();else if(Phase=="Playing")Pause();else if(Phase=="Briefing")Home();return;}
            if(Phase!="Playing")return;
            float dt=Mathf.Min(Time.deltaTime,.1f);
            if(departureTime>0)
            {
                departureTime=Mathf.Max(0,departureTime-dt);
                world.SetDeparture(1-departureTime/2.8f);
                FrameCamera(dt,false);SyncWorld(dt);
                if(departureTime==0) Finish();
                return;
            }
            var was=sim.Controlled;
            if (!ui.FieldOverlay) HandleInput(dt);
            else ClearTouches();
            if (Phase!="Playing") return;
            simCarry+=dt;
            while(simCarry>=1f/30f) {sim.Tick(1f/30f);simCarry-=1f/30f;}
            if (was!=null && sim.Controlled==null)
            {mapCenter=was.pos;UpdateCursor();if(!was.active)Receive("casualty_pa","指令","こちら指令。隊員の救護を要請します。",true);}
            if(sim.Result!=SimResult.Active) {Finish();return;}
            if(sim.Sector!=lastSector)
            {lastSector=sim.Sector;UpdateObjectiveSigns();sound.Signal("radio");Receive("section_pa","指令","次の避難場所を地図に表示します。",true);}
            recoil=Mathf.MoveTowards(recoil,0,dt*6);
            // Exact critically damped return, stable at either desktop or touch frame rates.
            float spring=17, decay=Mathf.Exp(-spring*dt), impulse=kickVelocity+spring*cameraKick;
            cameraKick=(cameraKick+impulse*dt)*decay;
            kickVelocity=(kickVelocity-spring*impulse*dt)*decay;
            hitTime-=dt;hurtTime-=dt;
            if(sim.Controlled!=null && Health01<lastOwnHealth-.001f){hurtTime=.43f;sound.Signal("impact");}
            lastOwnHealth=Health01;
            FrameCamera(dt,false);
            SyncWorld(dt);
            if(Saved!=lastBoarded){lastBoarded=Saved;sound.Signal("board");}
            if(sim.Wave!=lastWave){lastWave=sim.Wave;sound.Signal("warning");Receive("danger_pa","指令","接近警報。現場からの報告です。");}
            if(sim.CanDepart&&!wasReady)Receive("ready_pa","指令","輸送の準備ができました。出発の指示を待ちます。",true);
            wasReady=sim.CanDepart;
            sound.Tick(dt,sim,eye.transform.position,sim.Controlled!=null);
        }
        void CaptureFrame()
        {
#if !UNITY_WEBGL || UNITY_EDITOR
            string folder=System.IO.Path.Combine(Application.persistentDataPath,"Screenshots");
            System.IO.Directory.CreateDirectory(folder);
            string path=System.IO.Path.Combine(folder,System.DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss-fff")+".png");
            ScreenCapture.CaptureScreenshot(path);
#endif
        }
        void SyncWorld(float dt)
        {
            bool alarmOn=sim.AlarmActiveRemaining>0;
            world.SetAlarm(sim.AlarmPoint,missionIndex/2,alarmOn);
            sound.SetFieldAlarm(sim.AlarmPoint,missionIndex/2,alarmOn);
            world.SetFieldState(sim.Site,sim.Construction,HasFleet?sim.FleetVehicleLoad(0):Saved,sim.PowerMask,sim.Water,sim.PassageOpen);
            if(HasFleet && departureTime<=0) world.DrawFleet(sim,dt);
            UpdateLamp(dt);
            UpdateIncidents();
            UpdateWingField(dt);
            world.DrawColumnShelters(sim,missionIndex);
            world.SetObjective("追加要請",sim.RequestPoint,6,sim.HasRequestPoint);
            world.SetRequestProp(sim.RequestPropType,sim.RequestPropPosition);
            Unit carried=null,bearer=null;
            float stretcherYaw=0;
            if(sim.ColumnsActive)
            {
                for(int c=0;c<sim.ColumnCount && carried==null;c++)
                {
                    if(sim.ColumnCarriedId(c)<0)continue;
                    carried=sim.Find(sim.ColumnCarriedId(c));
                    bearer=sim.Find(sim.ColumnCarrierId(c));
                    if(carried==null || bearer==null || !carried.active || !bearer.active)
                    {carried=null;bearer=null;continue;}
                    stretcherYaw=sim.ColumnStretcherYaw(c);
                }
            }
            bool pushing=bearer!=null && bearer==sim.Controlled && InBodyView(bearer);
            world.DrawStretcher(carried,stretcherYaw,pushing);
            bool marketCast=sim.Mission.index==0 && !sim.IsDuty && sim.ColumnCount>0;
            int grocer=marketCast?sim.ColumnMemberId(0,0):-1;
            int florist=marketCast?sim.ColumnMemberId(0,1):-1;
            int marketGuide=marketCast?sim.ColumnLeaderId(0):-1;
            int marketAttacker=marketCast?sim.MarketAttackerId:-1;
            foreach(var u in sim.Units)
            {
                if(u.boarded || (u.kind==UnitKind.Infected && !u.visible && sim.Controlled==null))continue;
                if(u==carried)
                {
                    world.DrawStretcherPatient(u.id,u.id%4,u.pos,stretcherYaw);
                    continue;
                }
                int kind=u.kind==UnitKind.Soldier?0:u.kind==UnitKind.Infected?1:2;
                bool acted=u.windup>0||u.reload>0||u.escortId>=0||u.carryingCargo;
                bool fired=lastShots.TryGetValue(u.id,out int oldShots)&&oldShots!=u.shots;
                if(fired && u!=sim.Controlled && Vector3.Distance(eye.transform.position,u.pos)<70)
                {
                    sound.At("distant",u.pos);
                    fx.SquadFlash(u.pos,u.yaw,ReducedMotion);
                }
                lastShots[u.id]=u.shots;
                if(lastHealth.TryGetValue(u.id,out float prev)&&prev>u.hp && kind==1)
                {
                    fx.Impact(u.pos+Vector3.up*1.1f,u.id,ReducedMotion);
                    if(u.hp<=0 && sim.Controlled!=null)sound.At("fallen",u.pos);
                }
                lastHealth[u.id]=u.hp;
                int activity=u.escortId>=0?1:u.carryingCargo?3:fired||u.windup>0?4:
                    (u.kind==UnitKind.Soldier && sim.OrderFor(u.squad)==SquadOrder.Engineer && !u.moving?2:0);
                int visual=kind==0?u.squad:kind==2?u.id%4:u.variant==0&&u.id%3==0?3:u.variant;
                float actualSpeed=lastPositions.TryGetValue(u.id,out Vector3 oldPosition)&&dt>0?
                    Mathf.Min(7,(u.pos-oldPosition).magnitude/dt):0;
                walkSpeed.TryGetValue(u.id,out float previousSpeed);
                actualSpeed=Mathf.Lerp(previousSpeed,actualSpeed,1-Mathf.Exp(-dt*12));
                walkSpeed[u.id]=actualSpeed;
                lastPositions[u.id]=u.pos;
                var partner=AssistedPartner(u);
                if(partner!=null && kind==0)activity=1;
                MarketCastPose cast=default;
                if(u.id==marketGuide)
                {
                    visual=3;
                    var follower=sim.Find(grocer);
                    if(follower==null || !follower.active)follower=sim.Find(florist);
                    Vector3 side=Quaternion.Euler(0,u.yaw,0)*Vector3.right;
                    float glance=follower!=null && Vector3.Dot(follower.pos-u.pos,side)>0?1:-1;
                    cast=MarketCastPose.Guide(sim.MarketWaiting(u.id),glance);
                }
                else if(u.id==grocer || u.id==florist)
                {
                    visual=u.id==grocer?4:5;
                    cast=MarketCastPose.Shopkeeper(sim.MarketWaiting(u.id),sim.MarketCrossing(u.id),
                        u.id==grocer?1:-1);
                }
                else if(u.id==marketAttacker)
                {
                    float anticipation=u.windup>0?Mathf.Lerp(.24f,1,Mathf.InverseLerp(.92f,0,u.windup)):0;
                    float recovery=sim.MarketImpactCount>0?Mathf.Clamp01(1-sim.MarketImpactAge/4.5f):0;
                    cast=MarketCastPose.Infected(anticipation,sim.MarketCharging,recovery);
                }
                world.DrawActor(u.id,kind,visual,u.pos+Vector3.up*sim.VaultLift(u),u.yaw,actualSpeed,
                    Mathf.Clamp01(u.hp/Mathf.Max(1,u.maxHp)),acted||fired||u.stagger>0||activity==2,InBodyView(u),dt,
                    activity,u.lastHitDirection,partner?.pos,partner?.yaw??0,cast);
            }
            world.EndFrame();
            var pawn=sim.Controlled;
            world.DrawFirstPerson(pawn!=null && InBodyView(pawn),ReducedMotion?0:stepWeight,recoil,
                pawn==null?0:Mathf.Clamp01(pawn.reload/1.55f),stride/8f,pawn==null?0:pawn.escortId>=0?1:pawn.carryingCargo?3:0,aimBlend,pushing);
        }
    }
}
