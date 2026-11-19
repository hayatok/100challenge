using System;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal sealed class DistrictIncidentState
    {
        public float pressure=.34f, mechanism, callIn;
        public int choice,rider;
        public bool started;
        public Vector3 source, cart;
    }

    public partial class GameSim
    {
        static readonly int[] AnnexSectors={2,10,10,18,20,34,20,42};
        bool AnnexIncident(int sector) => (AnnexSectors[state.index]&(1<<sector))!=0;
        int fieldEventSerial,fieldSoundSector;
        public int EventSoundSector => fieldSoundSector;
        public bool ShowFieldEvent(int sector) => FieldEventLive(sector) &&
            (sector==Sector || (sector==Sector+1 && (DistrictOwned(sector) || EventStarted(sector))));
        public int FieldEventSerial => fieldEventSerial;
        public bool FieldEventLive(int district) => IsReady && !IsDuty && ChapterPhase==2 && district>=0 && district<SectorCount;
        StreetCase EventScript(int sector) => StreetCases.Operations[state.index][sector];
        DistrictIncidentState EventState(int sector)
        {
            if(state.incidents==null || state.incidents.Length!=SectorCount)
                Array.Resize(ref state.incidents,SectorCount);
            return state.incidents[sector] ?? (state.incidents[sector]=new DistrictIncidentState());
        }
        public int FieldEventType(int sector) => (int)EventScript(sector).kind;
        public bool EventStarted(int sector) => FieldEventLive(sector) && EventState(sector).started;
        public bool EventQuick(int sector) => EventStarted(sector) && EventState(sector).choice==1;
        public string EventChoiceName(int sector,bool quick)
        {
            if(!FieldEventLive(sector))return quick?"物資の輸送":"合流点の確保";
            var item=EventScript(sector);
            return quick?item.quick:item.refuge;
        }
        string EventBrief(int sector,bool quick)
        {
            switch(EventScript(sector).kind){
                case StreetEvent.Bell:return quick?"荷受け口に合図し、住民と備蓄を集積所へ":"放送を続け、避難口を知らせる";
                case StreetEvent.Lamp:return quick?"手元を照らし、見つけた住民と備蓄を集積所へ":"通路を照らし、離れた住民も避難口へ";
                case StreetEvent.Cart:return quick?"荷車に住民を乗せ、集積所の救護班へ":"近くの避難口で住民を引き渡す";
                case StreetEvent.Water:return quick?"排水を続け、低い道から集積所へ":"水位が上がっても通れる高い道を開く";
                case StreetEvent.Shutter:return quick?"搬出扉を上げ、荷と住民を集積所へ":"側道を開け、避難口に住民を誘導";
                default:return quick?"進路を切り替え、荷役側から補給":"歩行帯を空け、住民の避難路を確保";
            }
        }
        public float EventMechanism(int sector) => EventState(sector).mechanism;
        public float EventPressure(int sector) => EventState(sector).pressure;
        public Vector3 EventObjectPosition(int sector) => EventState(sector).started ? EventState(sector).source : IncidentSource(sector);
        public Vector3 EventCartPosition(int sector) => EventState(sector).cart;
        RoutePlan EventRoute(int sector)
        {
            if(districtPlans==null)districtPlans=new RoutePlan[SectorCount];
            return districtPlans[sector] ?? (districtPlans[sector]=MakeRoute(sector));
        }
        Unit DistrictPatient(int sector)
        {
            Unit nearest=null;float best=float.PositiveInfinity;
            var origin=AnnexIncident(sector)?ApproachBlocks.FieldStation(state.index,sector):EventRoute(sector).assembly;
            foreach(var c in state.units){
                if(!c.active || !IsCivilian(c) || c.boarded)continue;
                var a=Brain(c);
                if(a.auxiliary || a.escort>=0 || !a.injured || a.sector!=sector)continue;
                float d=FlatSq(c.pos,origin);
                if(d<best){best=d;nearest=c;}
            }
            return nearest;
        }
        Vector3 IncidentSource(int sector)
        {
            var route=EventRoute(sector);
            var kind=EventScript(sector).kind;
            var origin=AnnexIncident(sector)?ApproachBlocks.FieldStation(state.index,sector):route.assembly;
            if(kind==StreetEvent.Cart){
                var c=DistrictPatient(sector);
                return Ground(c!=null && FlatSq(c.pos,origin)<225?c.pos:origin+Vector3.right*1.7f);
            }
            if(AnnexIncident(sector))return Ground(origin+new Vector3(-1.25f,0,1.3f));
            if(kind==StreetEvent.Bell || kind==StreetEvent.Lamp)return Ground(route.assembly+new Vector3(1.8f,0,1.9f));
            if(kind==StreetEvent.Points)return Ground(route.gate+new Vector3(2.1f,0,2.8f));
            return Ground(route.works+new Vector3(-2.4f,0,1.8f));
        }
        Vector3 IncidentConsole(int sector,bool quick) => Ground(EventObjectPosition(sector)+Vector3.right*(quick?1.9f:-1.9f));
        Vector3 IncidentExit(int sector,bool quick)
        {
            var rt=EventRoute(sector);
            if(quick)return Ground(rt.depot+new Vector3(.8f,0,1.6f));
            if(AnnexIncident(sector))return Ground(ApproachBlocks.Relay(state.index,sector));
            var area=EventScript(sector).kind;
            var target=area==StreetEvent.Water || area==StreetEvent.Shutter ?
                rt.gate+new Vector3(rt.gate.x>0?-4:4,0,3.1f):rt.gate;
            return Ground(target);
        }
        bool ChosenAtConsole(int sector,Unit u)
        {
            if(u!=Controlled && DistrictAssignment(u.squad)==sector)return DistrictTransport(u.squad);
            return FlatSq(u.pos,IncidentConsole(sector,true))<FlatSq(u.pos,IncidentConsole(sector,false));
        }
        bool HasIncidentConsole(Unit u,int sector) => FlatSq(u.pos,IncidentConsole(sector,true))<7 ||
            FlatSq(u.pos,IncidentConsole(sector,false))<7;
        bool AssignedFast(int sector)
        {
            foreach(var team in state.squads)if(team!=null && team.districtTask==sector+1)return team.districtTransport;
            return false;
        }
        public string EventCondition(int sector)
        {
            if(!FieldEventLive(sector))return "";
            var e=EventState(sector);var kind=EventScript(sector).kind;
            string gauge=kind==StreetEvent.Water?"水位":kind==StreetEvent.Cart?"搬送路の混雑":
                kind==StreetEvent.Shutter?"通路の閉塞":kind==StreetEvent.Lamp?"通路の暗さ":"避難口の混雑";
            return gauge+(e.pressure>.65f?"・高":e.pressure>.31f?"・中":"・低");
        }
        void SoundIncident(int sector){fieldSoundSector=sector;fieldEventSerial++;}
        void BeginIncident(int sector,Unit u,bool quick)
        {
            var e=EventState(sector);
            e.source=IncidentSource(sector);e.cart=e.source;e.started=true;e.choice=quick?1:2;
            e.mechanism=.14f;e.callIn=0;SoundIncident(sector);
            var kind=EventScript(sector).kind;
            if(kind==StreetEvent.Cart){
                var patient=DistrictPatient(sector);
                if(patient!=null && FlatSq(e.source,patient.pos)<8){
                    e.rider=patient.id+1;Brain(patient).injured=false;Brain(patient).discovered=true;
                }
            }
            if(kind==StreetEvent.Points || kind==StreetEvent.Shutter)DrawEvacuees(sector,e.source,25,quick,2);
            SoundNotice(EventScript(sector).message);
        }
        void DrawEvacuees(int sector,Vector3 origin,float range,bool quick,int limit)
        {
            foreach(var c in state.units){
                if(limit<=0)break;
                if(!c.active || !IsCivilian(c) || c.boarded || FlatSq(c.pos,origin)>range*range)continue;
                var a=Brain(c);
                if(a.auxiliary || a.sector!=sector || a.route!=0)continue;
                if(EventScript(sector).kind==StreetEvent.Lamp && range<20){
                    float yaw=Mathf.Sin(Elapsed*.68f)*30*Mathf.Deg2Rad;
                    Vector3 beam=new Vector3(-Mathf.Sin(yaw),0,-Mathf.Cos(yaw));
                    var delta=c.pos-origin;
                    if(delta.sqrMagnitude>8 && Vector3.Dot(delta.normalized,beam)<.54f)continue;
                }
                Vector3 gate=IncidentExit(sector,quick);
                if(a.discovered && FlatSq(a.personalGate,gate)<.04f)continue;
                a.discovered=true;a.personalGate=gate;a.hasPath=false;limit--;
            }
        }
        void ApplyIncidentShutter(Vector3 position,bool closed)
        {
            bool changed=geometry.SetIncidentShutter(position,closed);
            if(WalkingMap!=geometry)changed|=WalkingMap.SetIncidentShutter(position,closed);
            if(changed)foreach(var a in state.actors)a.hasPath=false;
        }
        void StepDistrictIncident(float dt)
        {
            if(!FieldEventLive(Sector)){ApplyIncidentShutter(default,false);return;}
            int door=EventScript(Sector).kind==StreetEvent.Shutter ? Sector : Sector+1;
            bool shutter=ShowFieldEvent(door) && EventScript(door).kind==StreetEvent.Shutter &&
                DistrictOutcome(door)==0 && EventState(door).mechanism<.70f;
            ApplyIncidentShutter(shutter?EventObjectPosition(door):default,shutter);
            for(int s=Sector;s<Mathf.Min(SectorCount,Sector+2);s++){
                var e=EventState(s);
                if(DistrictOutcome(s)!=0 || (s!=Sector && !e.started))continue;
                var kind=EventScript(s).kind;
                bool staffed=false;
                if(e.started)foreach(var u in soldiers)
                    if(u.active && FlatSq(u.pos,e.source)<81){staffed=true;break;}
                float target=.48f+.35f*Mathf.Sin(Elapsed*.079f+s*1.84f+state.index*.53f);
                if(kind==StreetEvent.Water)target=Mathf.Max(target,state.water*.89f);
                if(e.started)target*=staffed?.28f:e.choice==2?.48f:.74f;
                e.pressure=Mathf.MoveTowards(e.pressure,target,dt*(staffed?.058f:.026f));
                if(!e.started){
                    if(s==Sector && (kind==StreetEvent.Water || kind==StreetEvent.Shutter)){
                        e.callIn-=dt;
                        if(e.callIn<=0){
                            e.callIn=2.5f;
                            if(e.pressure>.64f)DivertAroundObstruction(s);
                        }
                    }
                    continue;
                }
                e.mechanism=Mathf.MoveTowards(e.mechanism,staffed || e.choice==2?1:1-e.pressure*.46f,dt*.33f);
                var courier=RegisterCarrier(s);
                if(kind==StreetEvent.Cart && courier!=null && courier.active){
                    var trail=courier.pos-Quaternion.Euler(0,courier.yaw,0)*Vector3.forward*.82f;
                    e.cart=geometry.Move(e.cart,Vector3.MoveTowards(e.cart,trail,3.25f*dt));
                }
                e.callIn-=dt;
                if(e.callIn>0)continue;
                e.callIn=kind==StreetEvent.Bell?3.7f:2.2f;
                if(kind==StreetEvent.Bell || kind==StreetEvent.Lamp){
                    float range=kind==StreetEvent.Bell?(e.choice==1?10:18)+11*e.mechanism:(e.choice==1?4:7)+9*e.mechanism;
                    DrawEvacuees(s,e.source,range,e.choice==1,e.pressure>.58f?1:3);
                    if(s==Sector && kind==StreetEvent.Bell)SoundIncident(s);
                }
                if(kind==StreetEvent.Water && s==Sector && e.choice==1)
                    state.water=Mathf.Max(0,state.water-(staffed?.038f:.017f));
            }
        }
        void DivertAroundObstruction(int sector)
        {
            var route=EventRoute(sector);
            var bypass=IncidentExit(sector,false);
            foreach(var c in state.units){
                if(!c.active || !IsCivilian(c) || FlatSq(c.pos,route.gate)>100)continue;
                var a=Brain(c);
                if(!a.auxiliary && a.sector==sector && a.route==0 && FlatSq(a.personalGate,bypass)>.1f){
                    a.personalGate=bypass;a.hasPath=false;
                }
            }
        }
        bool RideDistrictCart(Unit person)
        {
            if(!FieldEventLive(Sector) || state.incidents?.Length!=SectorCount)return false;
            for(int s=Mathf.Max(0,Sector-1);s<Mathf.Min(SectorCount,Sector+2);s++){
                var e=state.incidents[s];
                if(e==null || e.rider!=person.id+1)continue;
                person.pos=e.cart+Vector3.up*.30f;person.moving=false;
                var courier=RegisterCarrier(s);
                if(courier!=null)person.yaw=courier.yaw;
                return true;
            }
            return false;
        }
        void FinishIncident(int sector)
        {
            var e=EventState(sector);var kind=EventScript(sector).kind;
            if(!e.started)return;
            e.mechanism=1;SoundIncident(sector);
            if(kind==StreetEvent.Cart && e.rider!=0){
                var c=Find(e.rider-1);
                if(c!=null && c.active){
                    c.pos=Ground(e.cart);var a=Brain(c);a.discovered=true;a.injured=false;
                    a.route=1;a.hasPath=false;c.wounded=false;
                    if(sector==Sector)state.sectionAssists++;
                }
                e.rider=0;
            }
            if(kind!=StreetEvent.Cart)DrawEvacuees(sector,e.source,35,e.choice==1,8);
        }
    }
}
