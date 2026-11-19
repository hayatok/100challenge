using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        public bool HasFleet => sim.IsReady && sim.FleetEnabled;
        public bool FleetBlocked => sim.FleetDecisionPending;
        public bool ReserveForInjured => sim.FleetTriage;
        public int FleetStop => sim.FleetShuttleStop;
        public int FleetStockCost => sim.FleetRepairCost;
        public int ReachedShelter => sim.FleetDelivered;
        public string FleetUpdate => sim.FleetReport;
        public string FleetOptions => sim.FleetRoadChoice(true)+"　／　"+sim.FleetRoadChoice(false);
        public int StopWaiting(int n) => sim.FleetWaiting(n);
        public int VehicleLoad(int n) => sim.FleetVehicleLoad(n);
        public int VehicleCapacity(int n) => sim.FleetVehicleCapacity(n);
        public bool VehicleAway(int n) => sim.FleetVehicleAway(n);
        public void CallShuttle(int stop) { sim.SendShuttle(stop); sound.Signal("dispatch"); }
        public void SendVehicle(int n) { sim.DispatchFleetVehicle(n); sound.Signal("arrival"); }
        public void ResolveBlock(bool repair) { sim.ResolveFleetBlock(repair); sound.Signal("radio"); }
        public void ReserveSeat() { sim.SetFleetTriage(!sim.FleetTriage); sound.Signal("dial"); }
        void DrawFleetMarkers()
        {
            if (!HasFleet || sim.Controlled != null) return;
            for (int n = 0; n < 2; n++)
                WorldTag(sim.FleetVehiclePosition(n)+Vector3.up*3.1f,
                    (n==0?"本線便 ":"迎車 ")+sim.FleetVehicleLoad(n)+"/"+sim.FleetVehicleCapacity(n),
                    new Color(.73f,.85f,1),true);
        }
    }
}
