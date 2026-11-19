using System;
using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public static readonly MissionDef[] Missions = Array.ConvertAll(RoutePlan.All, p => new MissionDef(Array.IndexOf(RoutePlan.All,p),p));
        WorldGeometry geometry;
        MissionMemory state = new MissionMemory();
        CampaignLog campaign;
        readonly Dictionary<int,int> indices = new Dictionary<int,int>();
        readonly List<Unit> soldiers = new List<Unit>();
        readonly List<Unit> threats = new List<Unit>();
        public GameSim()
        {
            campaign = EvacStorage.Read<CampaignLog>("campaign", c => c.Valid()) ?? new CampaignLog();
            if(campaign.requests?.Length!=8)campaign.requests=new int[8];
            if(campaign.roster==null)campaign.roster=new List<ReturnedSoldier>();
            dutyLog=EvacStorage.Read<DutyRecord>("duty-record",record=>record.completed?.Length==4) ?? new DutyRecord();
        }
        public bool IsReady { get; private set; }
        public MissionDef Mission => activeMission ?? Missions[state.index];
        public IReadOnlyList<Unit> Units => state.units;
        public Unit Controlled => Find(state.controlled);
        public Difficulty Level => (Difficulty)state.difficulty;
        public SimResult Result => (SimResult)state.result;
        public int Boarded => state.boarded;
        public int Lost => state.losses;
        public int Kills => state.kills;
        public bool CargoRequired => NeedsCargo || DutyAlternativeBridge;
        public bool RepairRequired => NeedsRepair || Rail || DutyAlternativeBridge;
        public Vector3 EngineerDestination => NeedsCargo && SectorTrips<RequiredTrips ? ActiveCache : ActiveWorks;
        public bool LastShotHit { get; private set; }
        public int Stock => state.stock;
        public int VolunteerCount => state.volunteers;
        public int DepotRounds => state.depotRounds;
        public int MedicalSupplies => state.medPacks;
        public int Delivered => state.delivered;
        public int Wave => state.waveCount;
        public int PowerMask => state.powerMask;
        public int Unlocked => campaign.unlocked;
        public int Site => state.site;
        public float Elapsed => state.clock;
        public float Remaining => Mathf.Max(0,state.deadline - state.clock);
        public float Water => state.water;
        public float Repair => NeedsRepair ? state.sectionRepair : state.repair;
        public bool Repaired => !Rail && NeedsRepair ? state.sectionRepair>=1 : state.repaired;
        public float Construction => state.construction;
        public float VehicleHealth => state.vehicle;
        public Vector3 VehiclePosition => Route.exit + Vector3.forward * (2 + (1 - state.exitClock) * 10f);
        public bool HasSave => EvacStorage.Exists("suspend");
        public bool CanDepart => IsReady && Result==SimResult.Active && Sector==SectorCount-1 && IsSectorCleared() && state.exitClock>=1;
        public int CampaignRescued => campaign.bestTotal;
        public int CampaignInjured => Sum(campaign.injured);
        public int CampaignStock => Sum(campaign.freight);
        public int NoticeSerial { get; private set; }
        public string Notice { get; private set; } = "";
        public string Objective
        {
            get
            {
                if (!IsReady) return "";
                if (Result==SimResult.Defeat) return state.dutyFailed ? state.dutyFailure : "作戦を再開してください";
                if (Result==SimResult.Victory && IsDuty) return DutyEnding;
                if (Result==SimResult.Victory) return state.index==7 ? "最後の輸送が完了" : "輸送完了";
                if (CanDepart) return "出発可能。残る住民を待つか、出発を指示";
                if(IsDuty)return DutyObjective();
                string prefix=SectorName+"　";
                if (NeedsCargo && SectorTrips < RequiredTrips) return prefix+"資材を集積所へ　"+SectorTrips+"/"+RequiredTrips;
                if (NeedsScreen && !state.screened) return prefix+"警備班を合流点に配置";
                if (NeedsTriage && state.sectionAssists==0) return prefix+"負傷者を乗車口まで搬送";
                if (NeedsRepair && state.sectionRepair<1) return prefix+"整備班で設備を復旧";
                if (Rail && Water>=.73f) return "地下通路が冠水。排水を続けてください";
                if (Rail && (PowerMask&2)==0) return "昇降機の電源を入れてください";
                return prefix+"集合場所から乗車口へ　"+Boarded+"/"+SectorGoal;
            }
        }

        static int Sum(int[] values) { int sum=0; foreach(int v in values) sum+=v; return sum; }
        public bool IsComplete(int index) => index>=0 && index<8 && campaign.complete[index];
        public int Best(int index) => index>=0 && index<8 ? campaign.best[index] : 0;
        public Unit Find(int id) => indices.TryGetValue(id,out var i) ? state.units[i] : null;
        ActorMemory Brain(Unit u) => state.actors[indices[u.id]];
        static bool IsCivilian(Unit u) => u.kind==UnitKind.Civilian;
        static bool IsSoldier(Unit u) => u.kind==UnitKind.Soldier;
        static bool Active(Unit u) => u.active;
        static float FlatSq(Vector3 a,Vector3 b) { float x=a.x-b.x,z=a.z-b.z; return x*x+z*z; }
        Vector3 Ground(Vector3 p) => geometry.Clamp(p);
        internal Vector3 RouteWaypoint(Vector3 from,Vector3 to) => geometry.Waypoint(from,to);
        void SoundNotice(string message) { Notice=message; NoticeSerial++; }

        public void StartMission(int index,Difficulty difficulty)=>StartOperation(index,difficulty,false);
        void StartOperation(int index,Difficulty difficulty,bool duty)
        {
            int n=Mathf.Clamp(index,0,Missions.Length-1);
            bool training=!duty && n==0;
            state=new MissionMemory { duty=duty, index=n, difficulty=Mathf.Clamp((int)difficulty,0,2),random=(uint)(71109+n*179),
                waveIn=n==0?25:17, water=n==5?.91f:.26f, deadline=(n==0?360:720) * (difficulty==Difficulty.Hard?.8f:1),
                crates=4+n, stock=4+(!duty && n>0?Mathf.Min(12,campaign.freight[n-1]):0) };
            if(!duty && n>0 && campaign.complete[n-1])
            {
                int extra=Mathf.Max(0,campaign.latest[n-1]-Missions[n-1].quota);
                state.volunteers=Mathf.Clamp(1+extra/2,1,6);
                state.site=campaign.facilities[n-1];
                if(state.site!=0){state.built=true;state.construction=1;}
            }
            if(duty)
            {
                state.deadline=300*(difficulty==Difficulty.Hard?.85f:1);
                state.requestState=(int)RequestState.Unplayed;
            }
            state.depotRounds=144+state.stock*6+state.volunteers*18;
            state.medPacks=3+state.volunteers;
            SetRoute();
            indices.Clear(); soldiers.Clear(); threats.Clear();AlarmAttracted=0;
            int squadCount=training?1:3;
            string[] names={"佐藤","岡田","藤井","森","青木","松田","井上","高橋","安田"};
            for(int j=0;j<3;j++)
            {
                Vector3 target = j==0?Route.gate+Vector3.forward*5:j==1?Route.assembly:Route.works;
                SquadOrder order=j==0?(training?SquadOrder.Guide:SquadOrder.Guard):j==1?SquadOrder.Guide:SquadOrder.Engineer;
                state.squads[j]=new SquadMemory { order=(int)order,destination=target };
                if(j>=squadCount) continue;
                for(int i=0;i<(training?2:3);i++)
                {
                    var p=Route.depot+new Vector3(j*1.35f-2.5f,0,i*1.15f);
                    Unit u=Spawn(UnitKind.Soldier,p,names[j*3+i],j);
                    Vector3 facing=(training?Route.assembly:target)-u.pos;
                    u.yaw=Mathf.Atan2(facing.x,facing.z)*Mathf.Rad2Deg;
                    u.ammo=18; u.reserve=72;u.medkits=1;
                    if(!duty && n>0 && campaign.complete[n-1])
                    {
                        var record=campaign.roster.Find(r=>r.operation==n-1 && r.name==u.name);
                        if(record!=null)
                        {
                            u.hp=Mathf.Clamp(record.hp,36,u.maxHp);u.wounded=u.hp<80;
                            if(!record.returned)u.reserve=54;
                        }
                    }
                }
            }
            OpenSector(true);
            if(n>0) SpawnWave(2);
            state.exitClock = NeedsCargo || NeedsRepair ? 0f : 1f;
            IsReady=true;
            SoundNotice(Mission.title);
            EvacStorage.Write(CheckpointSlot,state); Save();
        }

        Unit Spawn(UnitKind kind,Vector3 pos,string name,int squad)
        {
            var u=new Unit {id=state.nextId++,kind=kind,pos=Ground(pos),name=name,squad=squad,hp=100,maxHp=100,visible=kind!=UnitKind.Infected};
            indices.Add(u.id,state.units.Count);
            state.units.Add(u); state.actors.Add(new ActorMemory {id=u.id});
            if(IsSoldier(u)) soldiers.Add(u);
            if(kind==UnitKind.Infected) threats.Add(u);
            return u;
        }

        public void Retry() { if(IsReady) StartOperation(state.index,Level,IsDuty); }
        public bool Next()
        {
            if(!IsReady || IsDuty || Result!=SimResult.Victory || state.index>=7) return false;
            StartMission(state.index+1,Level);return true;
        }
        public bool Save() => IsReady && EvacStorage.Write(IsDuty?"duty-suspend":"suspend",state);
        public bool Load() => Restore("suspend");
        public bool LoadCheckpoint() => Restore(CheckpointSlot);
        static bool Valid(MissionMemory m)
        {
            if(m.version!=2 || m.index<0 || m.index>=8 || m.difficulty<0 || m.difficulty>2 || m.sector<0 || m.sector>=(m.duty?DutyPlan.All[m.index/2].stages.Length:SectorDef.Operations[m.index].Length) ||
                m.result<0 || m.result>2 || m.units==null || m.actors==null ||
                m.units.Count==0 || m.units.Count!=m.actors.Count || m.squads?.Length!=3) return false;
            var ids=new HashSet<int>();
            for(int i=0;i<m.units.Count;i++)
                if(m.units[i]==null || m.actors[i]==null || m.units[i].id!=m.actors[i].id || !ids.Add(m.units[i].id)) return false;
            foreach(var s in m.squads) if(s==null) return false;
            return true;
        }
        bool Restore(string slot)
        {
            bool dutySlot=slot.StartsWith("duty-",StringComparison.Ordinal);
            var saved=EvacStorage.Read<MissionMemory>(slot,m=>Valid(m) && m.duty==dutySlot);
            if(saved==null) return false;
            state=saved;
            if(!IsDuty && state.requestState==(int)RequestState.Unplayed)
            {
                state.requestState=(int)RequestState.Offered;state.requestActor=-1;state.requestCarrier=-1;
            }
            SetRoute();indices.Clear();soldiers.Clear();threats.Clear();AlarmAttracted=0;
            for(int i=0;i<state.units.Count;i++)
            {
                var u=state.units[i]; indices.Add(u.id,i);
                if(IsSoldier(u)) soldiers.Add(u);
                if(u.kind==UnitKind.Infected){threats.Add(u);if(u.active && u.distracted)AlarmAttracted++;}
            }
            IsReady=true; SoundNotice("作戦記録を復元");
            return true;
        }

        public void Order(int squad,SquadOrder order,Vector3 destination)
        {
            if(!IsReady || Result!=SimResult.Active || squad<0 || squad>=3) return;
            if(Find(AlarmActorId)?.squad==squad)state.alarmDispatch=0;
            if(DutyAlternativeBridge && order==SquadOrder.Engineer)
                state.dutyBridge=FlatSq(destination,ActiveWorks)<FlatSq(destination,ActiveCache);
            var group=state.squads[squad];group.order=(int)order;group.destination=Ground(destination);group.assigned=true;group.sector=Sector;
            group.requestDuty=HasRequestPoint && order==RequestOrder && FlatSq(group.destination,RequestPoint)<=12.25f;
            foreach(var s in soldiers) if(s.squad==squad) Brain(s).route=0;
            SoundNotice(new[]{"警備班","誘導班","整備班"}[squad]+"、指示を受信");
        }
        public SquadOrder OrderFor(int squad) => (SquadOrder)state.squads[Mathf.Clamp(squad,0,2)].order;
        public Vector3 DestinationFor(int squad) => state.squads[Mathf.Clamp(squad,0,2)].destination;
        public bool Possess(int id)
        {
            var u=Find(id);if(!IsReady || Result!=SimResult.Active || u==null || !IsSoldier(u) || !u.active) return false;
            Brain(u).hasPath=false;state.controlled=id;SoundNotice(u.name+"を直接操作");return true;
        }
        public void Release() { if(Controlled!=null) {Brain(Controlled).hasPath=false;state.controlled=-1;SoundNotice("現場から指揮へ復帰");} }
        public bool SetPower(PowerCircuit circuit,bool on)
        {
            if(!IsReady || Result!=SimResult.Active || !Rail || (int)circuit<0 || (int)circuit>2) return false;
            int bit=1<<(int)circuit, next=on ? PowerMask|bit : PowerMask&~bit;
            if(!Repaired && next==7) {SoundNotice("電力不足。ほかの系統を一つ停止");return false;}
            state.powerMask=next;return true;
        }
        public bool Build(Facility facility)
        {
            if(!IsReady || Result!=SimResult.Active || state.site!=0 || state.stock<4) return false;
            state.stock-=4;state.site=facility==Facility.Clinic?1:2;
            SoundNotice("建設予定地を確保。整備班が施工します");return true;
        }
        public bool Depart()
        {
            if(!CanDepart) return false;
            state.result=(int)SimResult.Victory;state.controlled=-1;
            if(IsDuty){FinishDuty();return true;}
            int n=state.index;
            campaign.latest[n]=Boarded;
            campaign.complete[n]=true;campaign.unlocked=Mathf.Max(campaign.unlocked,Mathf.Min(7,n+1));
            campaign.best[n]=Mathf.Max(campaign.best[n],Boarded);
            campaign.facilities[n]=state.built?state.site:0;
            campaign.freight[n]=Stock;campaign.injured[n]=0;campaign.returned[n]=0;
            campaign.roster.RemoveAll(r=>r.operation==n);
            foreach(var s in soldiers)
            {
                if(s.active)campaign.returned[n]++;
                if(s.hp<80)campaign.injured[n]++;
                campaign.roster.Add(new ReturnedSoldier {operation=n,name=s.name,hp=s.hp,returned=s.active});
            }
            RecordRequest();
            campaign.bestTotal=Sum(campaign.best);EvacStorage.Write("campaign",campaign);
            SoundNotice("輸送車が出発");Save();return true;
        }

        void Board(Unit c)
        {
            var a=Brain(c);
            if(a.sector==Sector){state.sectionBoarded++;if(a.injured && a.escort>=0)state.sectionAssists++;}
            Unlink(c);c.active=false;c.boarded=true;c.moving=false;state.boarded++;

        }
    }
}
