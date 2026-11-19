#if UNITY_EDITOR || EVAC_INSPECTION
namespace Evac
{
    public partial class GameSim
    {
        // Inspection uses exactly the same field dispatch as the command panel.
        public bool DriveWingInspection()
        {
            if(!WingActive || WingComplete || (state.index==0 && DistrictOutcome(Sector)==0))
                return false;
            int station=WingRecommendedStation;
            int squad=state.index==0?0:2;
            if(WingAssignment(squad)!=station && WingAvailable(station,0))return DispatchWing(squad,station,0);
            return true;
        }
    }
}
#endif
