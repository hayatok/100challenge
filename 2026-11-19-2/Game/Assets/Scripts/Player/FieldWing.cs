using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        bool wingReported;
        int wingPin=-1;

        public int AtWingDesk
        {
            get
            {
                var pawn=sim.Controlled;
                if(!sim.WingActive || sim.WingComplete || pawn==null || pawn.pos.z<94) return -1;
                for(int i=0;i<6;i++)
                {
                    if(!sim.AtWingStation(i))continue;
                    if(sim.WingAvailable(i,0) || sim.WingAvailable(i,1))return i;
                }
                return -1;
            }
        }

        public bool HandleWing(int station,int option)
        {
            bool direct=sim.Controlled!=null;
            bool sent=direct?sim.UseWing(station,option):sim.DispatchWing(SelectedSquad,station,option);
            if(!sent)return false;
            wingPin=station;
            if(!direct){mapCenter=sim.WingPosition(station);zoom=TouchUI?15:12;ShowOrderPin(mapCenter);}
            sound.Signal(direct?"action":"dispatch");
            return true;
        }

        public void LocateWing(int station)
        {
            wingPin=station;
            if(sim.Controlled!=null)return;
            mapCenter=sim.WingPosition(station);zoom=TouchUI?15:12;
            ShowOrderPin(mapCenter);
        }

        void UpdateWingField(float dt)
        {
            if(!sim.IsDuty && sim.WingActive && !wingReported)
            {
                wingReported=true;
                Receive("field_pa","現場",sim.WingStatus,true);
            }
            world.SetWingGates(sim.WingRoomOpen(0),sim.WingRoomOpen(1),dt);
            world.SetWingFreight(sim.WingFreightPosition,sim.WingHasFreight);
        }

        void WingMarker()
        {
            if(!sim.WingActive || sim.WingComplete)return;
            int assigned=sim.WingSquadStation(SelectedSquad);
            int selected=wingPin>=0 && !sim.WingStationDone(wingPin)?wingPin:assigned>=0?assigned:sim.WingRecommendedStation;
            if(selected<0 || selected>=6)return;
            Vector3 point=sim.WingPosition(selected);
            string label=sim.WingRoomName(selected);
            if(sim.Controlled!=null)label+="　"+Mathf.RoundToInt(Vector3.Distance(sim.Controlled.pos,point))+"m";
            WorldTag(point+Vector3.up*1.8f,label,new Color(.94f,.82f,.53f),true);
        }
    }
}
