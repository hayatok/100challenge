using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        // The first leg collects the district register. The second delivers it to
        // the depot for supplies or to the rendezvous to open a safer passage.
        public string DistrictName(int sector) => !IsDuty && sector>=0 && sector<SectorCount ? SectorDef.Operations[state.index][sector].name : "";
        public int DistrictOutcome(int sector) => state.districtOutcome!=null && sector>=0 && sector<state.districtOutcome.Length ? state.districtOutcome[sector] : 0;
        public float DistrictProgress(int sector) => DistrictOutcome(sector)>0 ? 1f :
            state.registerCollected!=null && sector>=0 && sector<state.registerCollected.Length && state.registerCollected[sector] ? .5f : 0;
        public int DistrictAssignment(int squad) => squad>=0 && squad<3 && state.squads[squad]!=null ? state.squads[squad].districtTask-1 : -1;
        public int DistrictResidents(int sector)
        {
            int remaining=0;
            foreach(var u in state.units)
                if(IsCivilian(u) && u.active && Brain(u).fieldShelter && Brain(u).sector==sector && !u.boarded)remaining++;
            return remaining;
        }

        public bool DistrictTransport(int squad) => DistrictAssignment(squad)>=0 && state.squads[squad].districtTransport;

        public Vector3 DistrictPosition(int sector)
        {
            if(IsDuty || sector<0 || sector>=SectorCount)return ActiveDepot;
            if(districtPlans==null)districtPlans=new RoutePlan[SectorCount];
            var plan=districtPlans[sector] ?? (districtPlans[sector]=MakeRoute(sector));
            var relay=state.index==0 ? plan.gate : ApproachBlocks.Relay(state.index,sector);
            if(DistrictOutcome(sector)==2)return Ground(relay);
            if(DistrictProgress(sector)==.5f)
            {
                var courier=RegisterCarrier(sector);
                if(courier!=null && (!courier.active || (DistrictOwned(sector) && DistrictAssignment(courier.squad)!=sector)))
                    return courier.pos;
                if(EventStarted(sector))return IncidentExit(sector,EventQuick(sector));
                foreach(var group in state.squads)
                    if(group!=null && group.districtTask==sector+1)
                        return Ground(group.districtTransport ? plan.depot : relay);
                return Ground(relay);
            }
            if(FieldEventLive(sector))return IncidentConsole(sector,AssignedFast(sector));
            return Ground(state.index==0 ? Vector3.Lerp(plan.cache,plan.gate,.5f)+Vector3.right*3.5f : ApproachBlocks.FieldStation(state.index,sector));
        }

        public bool CanDispatchDistrict(int squad,int sector)
        {
            if(!IsReady || IsDuty || Result!=SimResult.Active || squad<0 || squad>=3 ||
                sector<0 || sector>Sector+1 || sector>=SectorCount ||
                (DistrictOutcome(sector)==0 ? sector<Sector : !CanStaffPost(sector)))return false;
            foreach(var s in soldiers)if(s.squad==squad && s.active)return true;
            return false;
        }

        public bool DispatchDistrict(int squad,int sector,bool transport)
        {
            if(!CanDispatchDistrict(squad,sector) || (DistrictOutcome(sector)==2 && transport))return false;
            if(Wing!=null)Wing.jobs[squad]=0;
            ClearWaypoints(squad);
            CancelChapterDispatch(squad);
            CancelSearchDispatch(squad);
            foreach(var other in state.squads)
                if(other.districtTask==sector+1)other.districtTask=0;
            var group=state.squads[squad];
            group.districtTask=sector+1;
            group.districtTransport=transport;
            SoundNotice(DistrictName(sector)+(transport?"の輸送手配へ":"の合流点確保へ"));
            return true;
        }

        public string DistrictWorkLabel(int sector)
        {
            if(CanStaffPost(sector))return DistrictOwned(sector)?"中継所に班を配置":"中継所は無人";
            if(DistrictOutcome(sector)!=0)return "引継ぎ完了";
            if(FieldEventLive(sector)){
                if(DistrictProgress(sector)==0)return EventScript(sector).objectName+"　"+EventCondition(sector);
                if(EventStarted(sector))return EventQuick(sector)?"集積所で引き渡す":"避難口で引き渡す";
            }
            if(DistrictProgress(sector)==0)return "名簿を受け取る";
            var courier=RegisterCarrier(sector);
            if(courier!=null && (!courier.active || (DistrictOwned(sector) && DistrictAssignment(courier.squad)!=sector)))
                return courier.name+"から名簿を引き継ぐ";
            foreach(var group in state.squads)
                if(group.districtTask==sector+1 && group.districtTransport)return "集積所に届ける";
            return "合流点に届ける";
        }

        public string DistrictPostBrief => state.index==4?"駐留中は排水を補助":state.index==5?"駐留中は昇降機の運行間隔を短縮":
            state.index==6?"駐留中は感染者の接近を遅らせる":state.index==7?"駐留中は車列を修理":"";

        Unit RegisterCarrier(int sector) => state.districtCourier!=null && sector>=0 && sector<state.districtCourier.Length ?
            Find(state.districtCourier[sector]-1) : null;

        void InitDistricts(bool restoring=false)
        {
            if(IsDuty)return;
            if(state.districtOutcome==null || state.districtOutcome.Length!=SectorCount)
            {
                state.districtOutcome=new int[SectorCount];
                if(restoring)
                {
                    // Older saves had no register requirement. Keep every district
                    // they already cleared, including an available final departure.
                    for(int i=0;i<Sector;i++)state.districtOutcome[i]=1;
                    int oldGoal=(BasePlan.quota*(Sector+1)+SectorCount-1)/SectorCount;
                    if(state.boarded>=oldGoal && state.sectionBoarded>0 &&
                        (SectorData.work!=FieldWork.Triage || state.sectionAssists>0))
                        state.districtOutcome[Sector]=1;
                }
            }
            if(state.districtCourier==null || state.districtCourier.Length!=SectorCount)
                state.districtCourier=new int[SectorCount];
            if(state.registerCollected==null || state.registerCollected.Length!=SectorCount)
                state.registerCollected=new bool[SectorCount];
        }

        bool DistrictWork(Unit u,float dt)
        {
            int sector=DistrictAssignment(u.squad);
            if(sector<0 || IsDuty)return false;
            if(DistrictOutcome(sector)==2)
            {
                if(!CanStaffPost(sector)){state.squads[u.squad].districtTask=0;return false;}
                Walk(u,DistrictPosition(sector),3.5f,dt);
                return true;
            }
            var courier=RegisterCarrier(sector);
            if(courier!=null && courier!=u && courier.active && courier.squad==u.squad)
            {
                Walk(u,courier.pos+Vector3.right*(u.id%2==0?1:-1),3.5f,dt);
                return true;
            }
            float speed=EventStarted(sector) && EventScript(sector).kind==StreetEvent.Cart?2.65f:3.5f;
            if(Walk(u,DistrictPosition(sector),speed,dt))AdvanceDistrict(sector,DistrictTransport(u.squad),u);
            return true;
        }

        bool CanStaffPost(int sector) => state.index>=4 && DistrictOutcome(sector)==2 && sector>=Sector-1;

        void UpdateDistrictPost(float dt)
        {
            if(IsDuty || state.index<4)return;
            foreach(var u in soldiers)
            {
                int sector=DistrictAssignment(u.squad);
                if(!u.active || sector<0 || !CanStaffPost(sector) || FlatSq(u.pos,ApproachBlocks.Relay(state.index,sector))>9)continue;
                switch(state.index)
                {
                    case 4:state.water=Mathf.Max(0,state.water-.025f*dt);break;
                    case 5:state.liftClock-=dt*.8f;break;
                    case 6:state.waveIn+=dt*.32f;break;
                    case 7:state.vehicle=Mathf.Min(100,state.vehicle+dt*.55f);break;
                }
                return;
            }
        }

        bool DistrictOwned(int sector)
        {
            foreach(var group in state.squads)if(group.districtTask==sector+1)return true;
            return false;
        }

        int NearbyDistrict(Unit u)
        {
            if(IsDuty)return -1;
            int assigned=DistrictAssignment(u.squad);
            if(assigned>=0 && DistrictOutcome(assigned)==0 && CanReachRegister(u,assigned))return assigned;
            for(int sector=Sector;sector<Mathf.Min(SectorCount,Sector+2);sector++)
            {
                if(DistrictOutcome(sector)!=0)continue;
                if(DistrictOwned(sector))continue;
                if(CanReachRegister(u,sector))return sector;
            }
            return -1;
        }

        bool CanReachRegister(Unit u,int sector)
        {
            var courier=RegisterCarrier(sector);
            if(FieldEventLive(sector) && DistrictProgress(sector)==0)return HasIncidentConsole(u,sector);
            return FlatSq(u.pos,courier!=null && courier!=u ? courier.pos : DistrictPosition(sector))<7;
        }

        string RegisterAction(Unit u)
        {
            int sector=NearbyDistrict(u);
            if(FieldEventLive(sector)){
                if(DistrictProgress(sector)==0)return EventChoiceName(sector,ChosenAtConsole(sector,u));
                if(EventStarted(sector))return RegisterCarrier(sector)!=u?"現場の担当を引き継ぐ":"現場の引き渡しを終える";
            }
            if(DistrictProgress(sector)==0)return "地区の名簿を受け取る";
            return RegisterCarrier(sector)!=u ? "名簿を引き継ぐ" : "地区の引継ぎを完了";
        }

        static readonly string[] FreightBrief = {
            "飲料を積み、備蓄を4増やす", "薬局の救急箱を5箱届ける", "橋材を運び、必要な搬送を1回済ませる",
            "部品を届け、作業車の耐久を25回復", "非常電源で全回路を使えるようにする",
            "排水部材を運び、水位を半分下げる", "中継所から予備弾薬を90発届ける", "予備部品で車列の耐久を40回復"
        };
        public string DistrictBrief(int sector,bool transport)
        {
            if(IsDuty || sector<0 || sector>=SectorCount)return "";
            if(FieldEventLive(sector))return EventBrief(sector,transport);
            if(transport)return FreightBrief[state.index];
            switch(SectorDef.Operations[state.index][sector].work)
            {
                case FieldWork.Screen:return "警備班が離れても合流点を開放";
                case FieldWork.Haul:
                case FieldWork.HaulAndRepair:return "地元の搬送員が資材を1回分運ぶ";
                case FieldWork.Repair:
                case FieldWork.Generator:return "現地の技師が設備を半分修復";
                case FieldWork.Drain:
                case FieldWork.Lift:return "排水路を開け、水位を半分下げる";
                case FieldWork.Triage:return "応急処置で歩ける負傷者を増やす";
                default:return "住民に避難路を伝え、歩ける人を送り出す";
            }
        }

        void ApplyDistrictRoute()
        {
            if(IsDuty)return;
            int outcome=DistrictOutcome(Sector);
            if(outcome==1 && state.index==2){state.delivered++;return;}
            if(outcome!=2)return;
            state.waveIn+=8;
            switch(SectorData.work)
            {
                case FieldWork.Screen:state.screened=true;break;
                case FieldWork.Haul:
                case FieldWork.HaulAndRepair:state.delivered++;break;
                case FieldWork.Repair:
                case FieldWork.Generator:PerformRepair(.5f);break;
                case FieldWork.Drain:
                case FieldWork.Lift:state.water=Mathf.Max(0,state.water-.5f);break;
                default:
                    bool keptPatient=false;
                    foreach(var c in state.units)
                    {
                        if(!IsCivilian(c) || !c.active)continue;
                        var a=Brain(c);
                        if(a.sector!=Sector || a.auxiliary)continue;
                        if(a.injured && !keptPatient){keptPatient=true;continue;}
                        if(a.escort<0){a.injured=false;c.wounded=false;a.discovered=true;}
                    }
                    break;
            }
        }

        void DeliverDistrictFreight()
        {
            state.stock+=2;state.medPacks+=2;state.depotRounds+=36;
            switch(state.index)
            {
                case 0:state.stock+=2;break;
                case 1:state.medPacks+=3;break;
                case 3:state.vehicle=Mathf.Min(100,state.vehicle+25);break;
                case 4:state.repair=1;state.repaired=true;break;
                case 5:state.water=Mathf.Max(0,state.water-.5f);break;
                case 6:state.depotRounds+=54;break;
                case 7:state.vehicle=Mathf.Min(100,state.vehicle+40);break;
            }
        }

        void AdvanceDistrict(int sector,bool transport,Unit u)
        {
            if(!state.registerCollected[sector])
            {
                state.registerCollected[sector]=true;
                state.districtCourier[sector]=u.id+1;
                if(FieldEventLive(sector))BeginIncident(sector,u,ChosenAtConsole(sector,u));
                else SoundNotice(DistrictName(sector)+"の名簿を確認");
                return;
            }
            if(RegisterCarrier(sector)!=u)
            {
                state.districtCourier[sector]=u.id+1;
                if(EventStarted(sector)){
                    EventState(sector).choice=DistrictAssignment(u.squad)==sector?(transport?1:2):EventState(sector).choice;
                    SoundNotice(u.name+"が現場を引き継ぎました");
                }else SoundNotice(u.name+"が名簿を引き継ぎました");
                return;
            }
            if(EventStarted(sector)){transport=EventQuick(sector);FinishIncident(sector);}
            state.districtCourier[sector]=0;
            state.districtOutcome[sector]=transport?1:2;
            if(transport)DeliverDistrictFreight();
            if(sector==Sector)ApplyDistrictRoute();
            if(!CanStaffPost(sector))
                foreach(var group in state.squads)if(group.districtTask==sector+1)group.districtTask=0;
            SoundNotice(DistrictName(sector)+(transport?"の補給便が到着":"の合流点を確保"));
        }
    }
}
