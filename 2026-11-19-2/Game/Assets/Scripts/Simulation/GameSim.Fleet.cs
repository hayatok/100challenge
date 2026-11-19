using System;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal sealed class EvacuationBus
    {
        public int load, leg;
        public float heading;
        public Vector3 position, waypoint, goal;
        public bool path;
    }

    [Serializable]
    internal sealed class EvacuationFleet
    {
        public int shuttleStop, decision, delivered, trips;
        public bool injuredFirst;
        public EvacuationBus[] vehicles;
    }

    public partial class GameSim
    {
        const int AtStop=0, ToShelter=1, ToStop=2;
        public bool FleetEnabled => !IsDuty && (state.index==2 || state.index==3 || state.index>=6);
        public bool FleetDecisionPending => FleetEnabled && state.fleet?.decision==1;
        public int FleetRepairCost => state.index>=6 ? 4 : 3;
        public int FleetShuttleStop => state.fleet?.shuttleStop ?? 0;
        public int FleetDelivered => state.fleet?.delivered ?? Boarded;
        public bool FleetTriage => state.fleet!=null && state.fleet.injuredFirst;
        public Vector3 FleetBoardingPoint
        {
            get
            {
                if(state.fleet?.decision!=3)return BasePlan.exit;
                if(state.index==7)return Ground(new Vector3(-2,0,-41));
                if(state.index==6)return Ground(new Vector3(1,0,-30));
                if(state.index==3)return Ground(new Vector3(-5,0,-30));
                return Ground(BasePlan.exit+new Vector3(8,0,9));
            }
        }

        public string FleetRoadChoice(bool repair)
        {
            switch(state.index)
            {
                case 2:return repair ? "荷台の渡し板を補強。本線に2席追加" : "荷受け場の東側で乗車";
                case 3:return repair ? "車両を応急整備。耐久を20回復" : "整備棟の南側で乗車";
                case 6:return repair ? "河岸の通路を補強。次の群れを遅らせる" : "川下の待避所に乗車口を移す";
                case 7:return repair ? "連結路を補強。迎車に2席追加" : "南街区入口から車列を出す";
                default:return "";
            }
        }
        public Vector3 FleetStopPosition(int stop)
        {
            if(stop==1 || stop==2)return Ground(new Vector3(0,0,stop==1?65:-65));
            return Ground(FleetBoardingPoint+Vector3.forward*7.5f);
        }

        public float FleetVehicleHeading(int bus) => GetBus(bus)?.heading ?? 0;
        public int FleetVehicleLoad(int bus) => GetBus(bus)?.load ?? 0;
        public int FleetVehicleCapacity(int bus)
        {
            bool repaired=state.fleet?.decision==2;
            if(bus==0)return (state.index==7?9:state.index==6?7:6)+(repaired && state.index==2?2:0);
            if(bus==1)return (state.index>=6?4:3)+(repaired && state.index==7?2:0);
            return 0;
        }
        public Vector3 FleetVehiclePosition(int bus) => GetBus(bus)?.position ?? ActiveExit;
        public bool FleetVehicleAway(int bus) => GetBus(bus)!=null && GetBus(bus).leg!=AtStop;
        public int FleetWaiting(int stop)
        {
            if(!FleetEnabled || stop<0 || stop>2)return 0;
            int count=0;
            var curb=FleetStopPosition(stop);
            foreach(var c in state.units)
                if(c.active && IsCivilian(c) && FlatSq(c.pos,curb)<22*22 && !Brain(c).auxiliary)count++;
            return count;
        }

        public Vector3 FleetBlockPoint => Ground(BasePlan.exit+new Vector3(BasePlan.exit.x>0?-4:4,0,4));
        bool AtFleetBlock(Unit u) => FleetDecisionPending && FlatSq(u.pos,FleetBlockPoint)<6.25f;

        public string FleetReport => !FleetEnabled ? "" : FleetDecisionPending ? "本線が陥没。資材で修復、現地で補修、または迂回" :
            "退避先に到着 "+FleetDelivered+"人　輸送 "+(state.fleet?.trips ?? 0)+"便";

        EvacuationBus GetBus(int bus) => state.fleet?.vehicles!=null && bus>=0 && bus<state.fleet.vehicles.Length ? state.fleet.vehicles[bus] : null;
        Vector3 FleetShelter => Ground(new Vector3(0,0,BasePlan.exit.z-14));
        Vector3 BusStop(int bus) => bus==0 ? Ground(FleetBoardingPoint) : FleetStopPosition(FleetShuttleStop);

        static bool ValidFleet(MissionMemory memory)
        {
            var fleet=memory.fleet;
            // Unity serializes null nested classes as empty objects on some targets.
            if(fleet?.vehicles==null || fleet.vehicles.Length==0)return true;
            if(fleet.vehicles.Length!=2 || fleet.decision<0 || fleet.decision>3 || fleet.shuttleStop<0 || fleet.shuttleStop>2 ||
                fleet.delivered<0 || fleet.delivered>memory.boarded || fleet.trips<0)return false;
            int counted=fleet.delivered;
            foreach(var bus in fleet.vehicles)
            {
                if(bus==null || bus.load<0 || bus.load>11 || bus.leg<AtStop || bus.leg>ToStop ||
                    !Finite(bus.position.x) || !Finite(bus.position.z) || !Finite(bus.heading))return false;
                counted+=bus.load;
            }
            return counted==memory.boarded;
        }

        static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);

        void InitFleet()
        {
            if(!FleetEnabled || (GetBus(0)!=null && GetBus(1)!=null))return;
            // Residents boarded in an older save have already reached safety.
            state.fleet=new EvacuationFleet { delivered=Boarded, vehicles=new[]{new EvacuationBus(),new EvacuationBus()} };
            for(int i=0;i<2;i++)GetBus(i).position=BusStop(i);
        }

        public bool SetFleetTriage(bool on)
        {
            if(!IsReady || !FleetEnabled || Result!=SimResult.Active)return false;
            state.fleet.injuredFirst=on;return true;
        }

        public bool SendShuttle(int stop)
        {
            if(!IsReady || !FleetEnabled || Result!=SimResult.Active || stop<0 || stop>2 || stop==FleetShuttleStop)return false;
            var bus=GetBus(1);
            state.fleet.shuttleStop=stop;
            if(bus.leg!=ToShelter)bus.leg=bus.load>0 ? ToShelter : ToStop;
            bus.path=false;
            SoundNotice(stop==0?"迎車を中央へ":stop==1?"迎車を北街区へ":"迎車を南街区へ");
            return true;
        }

        public bool DispatchFleetVehicle(int index)
        {
            var bus=GetBus(index);
            if(!IsReady || Result!=SimResult.Active || bus==null || bus.leg!=AtStop || bus.load==0)return false;
            bus.leg=ToShelter;bus.path=false;
            return true;
        }

        public bool ResolveFleetBlock(bool repair)
        {
            if(!IsReady || Result!=SimResult.Active || !FleetDecisionPending || (repair && Stock<FleetRepairCost))return false;
            if(repair)state.stock-=FleetRepairCost;
            if(repair)RepairFleetPassage();
            else state.fleet.decision=3;
            var shuttle=GetBus(1);
            if(!repair && FleetShuttleStop==0 && shuttle.leg==AtStop)
            {
                shuttle.leg=shuttle.load>0?ToShelter:ToStop;
                shuttle.path=false;
            }
            var main=GetBus(0);
            if(main.leg==AtStop){main.leg=main.load>0?ToShelter:ToStop;main.path=false;}
            SoundNotice(repair?"道路を応急修復。本線を再開":"本線の乗車口を迂回路へ変更");
            return true;
        }

        void RepairFleetPassage()
        {
            state.fleet.decision=2;
            if(state.index==3)state.vehicle=Mathf.Min(100,state.vehicle+20);
            if(state.index==6)state.waveIn+=18;
        }

        void PatchFleetRoad()
        {
            RepairFleetPassage();
            SoundNotice("現地の通り道を補修。本線を再開");
        }

        void TickFleet(float dt)
        {
            if(!FleetEnabled)return;
            for(int i=0;i<2;i++)
            {
                var bus=GetBus(i);
                if(bus.leg==AtStop)
                {
                    if(bus.load>=FleetVehicleCapacity(i) ||
                        (Sector==SectorCount-1 && IsSectorCleared() && FleetDelivered<Mission.quota && bus.load>0))
                        DispatchFleetVehicle(i);
                    continue;
                }
                var destination=bus.leg==ToShelter ? FleetShelter : BusStop(i);
                if(!bus.path || FlatSq(bus.goal,destination)>.04f || FlatSq(bus.position,bus.waypoint)<.006f)
                {
                    bus.waypoint=geometry.Waypoint(bus.position,destination);
                    bus.goal=destination;bus.path=true;
                }
                var direction=bus.waypoint-bus.position;
                if(FlatSq(bus.position,destination)>.25f && direction.sqrMagnitude>.001f)
                {
                    float heading=Mathf.Atan2(direction.x,direction.z)*Mathf.Rad2Deg;
                    bus.heading=Mathf.MoveTowardsAngle(bus.heading,heading,165*dt);
                    // Turn around at the curb before pulling away.
                    if(Mathf.Abs(Mathf.DeltaAngle(bus.heading,heading))>50)continue;
                }
                bus.position=geometry.Move(bus.position,Vector3.MoveTowards(bus.position,bus.waypoint,(i==0?5.8f:7f)*dt));
                if(FlatSq(bus.position,destination)>.25f)continue;
                bus.path=false;
                if(bus.leg==ToShelter)
                {
                    state.fleet.trips++;state.fleet.delivered+=bus.load;bus.load=0;bus.leg=ToStop;
                    if(state.fleet.decision==0 && state.fleet.delivered>=FleetVehicleCapacity(0))
                    {
                        state.fleet.decision=1;
                        SoundNotice("本線に陥没。迎車の運行中に修復か迂回を選択");
                    }
                }
                else
                {
                    bus.heading=Mathf.MoveTowardsAngle(bus.heading,0f,165*dt);
                    if(Mathf.Abs(Mathf.DeltaAngle(bus.heading,0))<.1f)bus.leg=AtStop;
                }
            }
        }

        bool CanBoardBus(int index,Unit civilian)
        {
            var bus=GetBus(index);
            if(bus.leg!=AtStop || bus.load>=FleetVehicleCapacity(index) || (index==0 && FleetDecisionPending))return false;
            if(index==0 || !FleetTriage || civilian.wounded || bus.load+1<FleetVehicleCapacity(1))return true;
            foreach(var other in state.units)
                if(other.active && IsCivilian(other) && other.wounded && FlatSq(other.pos,bus.position)<20*20)return false;
            return true;
        }

        bool FieldPickup(Unit c,ActorMemory a) => FleetEnabled && a.fieldShelter && FleetShuttleStop!=0 &&
            Mathf.Abs(c.pos.z-FleetStopPosition(FleetShuttleStop).z)<29;

        int PreferredBus(Unit c)
        {
            if(FieldPickup(c,Brain(c)))return 1;
            if(FleetShuttleStop==0 && CanBoardBus(1,c) &&
                (!CanBoardBus(0,c) || (FleetTriage && c.wounded)))return 1;
            return 0;
        }

        Vector3 AvoidFleetBodies(Vector3 position)
        {
            if(!FleetEnabled || state.fleet==null)return position;
            for(int bus=0;bus<2;bus++)
                position=WorldGeometry.VehicleClearance(position,FleetVehiclePosition(bus),bus,FleetVehicleHeading(bus));
            return position;
        }

        bool EnterBus(Unit c)
        {
            int index=PreferredBus(c);
            var bus=GetBus(index);
            if(!CanBoardBus(index,c) || FlatSq(c.pos,bus.position)>12.25f)return false;
            bus.load++;return true;
        }
    }
}
