#if UNITY_EDITOR || EVAC_INSPECTION
namespace Evac
{
    public partial class GameSim
    {
        public void DriveColumnInspection()
        {
            if(!ColumnsActive || ColumnsComplete || Controlled!=null)return;
            for(int c=0;c<ColumnCount;c++){
                var l=Line(c);if(l.finished)continue;
                if(!MarketColumn && c==1 && !l.open && l.operatorId<0)CommandColumn(1,4,2);
                if(c==1 && l.leg==1 && l.open && !l.finished && l.carrier<0 && l.pickup<0)CommandColumn(c,7,1);
                if(l.held)CommandColumn(c,MarketColumn?0:c,MarketColumn?0:c);
            }
        }
    }
}
#endif
