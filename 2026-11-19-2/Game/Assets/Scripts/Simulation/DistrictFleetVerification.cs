#if UNITY_EDITOR
using System;
using System.Linq;
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        internal void FleetAndDistrictChecks(StringBuilder report)
        {
            StartMission(7,Difficulty.Story);
            VerifyParkedVehicle();
            Verify(DispatchDistrict(0,1,false) && DispatchDistrict(2,0,true),"Two squads dispatched to independent districts");
            var survey=soldiers.First(s=>s.squad==0);
            var hauler=soldiers.First(s=>s.squad==2);
            survey.pos=DistrictPosition(1);hauler.pos=DistrictPosition(0);
            Possess(survey.id);Verify(Interact() && DistrictProgress(1)==.5f,"FPS field register");
            Release();Tick(.1f);
            Verify(DistrictProgress(0)==.5f,"Second independent register");
            Verify(Save() && Load() && RegisterCarrier(1).id==survey.id && RegisterCarrier(0).id==hauler.id,
                "Both couriers and registers persist");
            survey=Find(survey.id);hauler=Find(hauler.id);
            var successor=soldiers.First(s=>s.squad==1);
            Verify(DispatchDistrict(1,1,false) && FlatSq(DistrictPosition(1),survey.pos)<.1f,
                "Reassigned squad must rendezvous with actual courier");
            Possess(successor.id);successor.pos=survey.pos;
            Verify(Interact() && RegisterCarrier(1)==successor && DistrictProgress(1)==.5f,"Receiver takes register in person");
            successor.pos=DistrictPosition(1);Verify(Interact() && DistrictOutcome(1)==2,"FPS secures future district");
            state.vehicle=50;float before=VehicleHealth;
            Tick(.1f);Verify(VehicleHealth>before && DistrictAssignment(1)==1,"Staffed relay repairs convoy");
            Verify(Order(1,SquadOrder.Move,ActiveDepot),"Recall relay team");
            before=VehicleHealth;Tick(.1f);Verify(VehicleHealth==before,"Vacated relay stops providing repairs");
            Release();Possess(hauler.id);hauler.pos=DistrictPosition(0);
            int stock=Stock;Verify(Interact() && DistrictOutcome(0)==1 && Stock==stock+2,"Independent freight arrives");

            Verify(SetFleetTriage(true) && SendShuttle(ApproachBlocks.FieldStation(7,0).z>0?1:2),"Send reserve vehicle to field shelter");
            for(int i=0;i<500 && FleetVehicleAway(1);i++)Tick(.1f);
            Verify(!FleetVehicleAway(1),"Reserve vehicle reached a satellite stop");
            VerifyPrioritySeat();
            var remote=state.units.First(c=>c.active && IsCivilian(c) && Brain(c).fieldShelter);
            remote.pos=FleetStopPosition(FleetShuttleStop);
            int boarded=Boarded;
            Board(remote);
            Verify(Boarded==boarded+1 && FleetVehicleLoad(1)==1 && FleetDelivered==0,"Remote boarding precedes arrival at shelter");
            Verify(DispatchFleetVehicle(1) && FleetVehicleAway(1),"Dispatch an under-capacity shuttle");
            var departure=FleetVehiclePosition(1);
            for(int i=0;i<20;i++)Tick(.1f);Verify(FlatSq(departure,FleetVehiclePosition(1))>.1f,"Vehicle travelled on the map");
            Verify(Save() && Load() && FleetVehicleLoad(1)==1 && FleetVehicleAway(1) && FleetTriage,
                "Partially filled vehicle, journey and priority persist");
            for(int i=0;i<500 && FleetDelivered==0;i++)Tick(.1f);
            Verify(FleetDelivered==1 && FleetVehicleLoad(1)==0,"Passenger actually arrived");

            // Recreate the same road closure for all three public responses.
            state.fleet.decision=1;Verify(Save(),"Save closure");
            Verify(!CanBoardBus(0,remote),"Blocked vehicle cannot board");
            stock=Stock;Verify(ResolveFleetBlock(true) && Stock==stock-FleetRepairCost && FleetBoardingPoint==BasePlan.exit,
                "Supplied repair retained original stop");
            Verify(Load() && ResolveFleetBlock(false) && FlatSq(FleetBoardingPoint,BasePlan.exit)>64 && Stock==stock,
                "Diversion moved boarding queue and saved materials");
            Verify(Load() && Possess(soldiers[0].id),"Restore field repair branch");
            Controlled.pos=FleetBlockPoint;
            Verify(Interact() && !FleetDecisionPending && Stock==stock && FleetBoardingPoint==BasePlan.exit,
                "Physical patch restored the road without depot materials");

            state.fleet=null;state.districtOutcome=null;state.districtCourier=null;state.registerCollected=null;
            state.sector=2;state.boarded=Mission.quota;state.sectionBoarded=1;
            foreach(var group in state.squads)group.districtTask=0;
            Verify(Save() && Load() && FleetDelivered==Boarded && DistrictOutcome(0)>0 &&
                DistrictOutcome(1)>0 && DistrictOutcome(2)>0,"Legacy save keeps its settled districts and already transported count");
            report.AppendLine("Districts: parallel work, physical register handoff, FPS settlement, save and occupied relay. Fleet: reserve routes, under-capacity run, road closure, three responses and legacy transfer passed.");
        }

        internal string FleetDiagnostics()
        {
            if(!FleetEnabled)return "";
            var detail=new StringBuilder();
            for(int i=0;i<2;i++)detail.Append(" bus"+i+"="+GetBus(i).position+"/"+GetBus(i).leg+"/"+GetBus(i).load);
            detail.Append(" road="+state.fleet.decision+" arrived="+FleetDelivered+" repair="+state.sectionRepair+" trips="+SectorTrips+" newlyBoarded="+state.sectionBoarded);
            foreach(var u in state.units)
                if(u.active && (IsSoldier(u) || IsCivilian(u)))
                    detail.Append(" "+u.name+":"+u.pos+"/"+Brain(u).route+"/"+Brain(u).discovered);
            return detail.ToString();
        }

        void VerifyParkedVehicle()
        {
            var bus=GetBus(0);
            var original=bus.position;
            bus.position=Ground(new Vector3(0,0,40));RefreshFleetBodies();
            var body=parkedBodies[0];
            var walker=soldiers[0];
            var originalSoldier=walker.pos;
            walker.pos=Ground(body.center+body.right*4);
            var otherSide=Ground(body.center-body.right*4);
            bool arrived=false;
            for(int i=0;i<180 && !arrived;i++)
            {
                arrived=Walk(walker,otherSide,3.6f,.1f);
                Verify(!body.Cuts(walker.pos,walker.pos),"NPC entered a parked vehicle");
            }
            Verify(arrived,"NPC can pass around a parked full-size bus");
            Possess(walker.id);
            for(int i=0;i<40;i++)Move(body.right,90,.1f);
            Verify(Vector3.Dot(walker.pos-body.center,body.right)<-1.75f,"FPS cannot walk through bus body");
            Release();
            walker.pos=originalSoldier;bus.position=original;mapSource=null;RefreshFleetBodies();
        }

        void VerifyPrioritySeat()
        {
            var shuttle=GetBus(1);
            var patient=state.units.First(c=>c.active && IsCivilian(c) && c.wounded);
            var walker=state.units.First(c=>c.active && IsCivilian(c) && !c.wounded);
            int previousLoad=shuttle.load;
            var previousPosition=patient.pos;
            shuttle.load=FleetVehicleCapacity(1)-1;patient.pos=shuttle.position;
            Verify(!CanBoardBus(1,walker) && CanBoardBus(1,patient),"Last seat waits for nearby injured passenger");
            SetFleetTriage(false);Verify(CanBoardBus(1,walker),"Opening last seat lets a healthy passenger board");
            SetFleetTriage(true);shuttle.load=previousLoad;patient.pos=previousPosition;
        }

        static void Verify(bool value,string reason)
        {
            if(!value)throw new InvalidOperationException(reason);
        }
    }
}
#endif
