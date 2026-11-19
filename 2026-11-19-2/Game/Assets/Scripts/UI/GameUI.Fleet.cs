using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool fleetOpen;
        static readonly string[] Stops={"中央通り","北街区","南街区"};
        void FleetDesk()
        {
            ModalBackdrop();
            Rect card=Dialog(692,458);
            float x=card.x+22, y=card.y, width=card.width-44, half=(width-10)*.5f;
            Text(R(x,y+12,width,43),"避難車両 運行表",28,Cream,true);
            Text(R(x,y+53,width,28),"避難先への到着　"+G.ReachedShelter+"人",18,Amber,true);
            for (int n=0;n<2;n++)
            {
                int bus=n;
                float left=x+n*(half+10);
                Instrument(R(left,y+91,half,129));
                Text(R(left+12,y+97,half-24,24),n==0?"本線便":"迎車　"+Stops[Mathf.Clamp(G.FleetStop,0,2)],19,Cream,true);
                Text(R(left+12,y+127,half-24,27),G.VehicleLoad(n)+" / "+G.VehicleCapacity(n)+"人　"+(G.VehicleAway(n)?"走行中":"停車中"),18,Mist);
                if (Button(R(left+10,y+164,half-20,45),"この人数で発車",enabled:!G.VehicleAway(n)&&G.VehicleLoad(n)>0,dark:true))
                    Submit(()=>G.SendVehicle(bus));
            }
            if (G.FleetBlocked)
            {
                Text(R(x,y+230,width,33),"本線で通行障害",22,Amber,true);
                Paragraph(R(x,y+266,width,54),G.FleetOptions,16,Cream);
                if(Button(R(x,y+328,half,52),"資材"+G.FleetStockCost+"で復旧",primary:true,enabled:G.Supply>=G.FleetStockCost))
                    Submit(()=>G.ResolveBlock(true));
                if(Button(R(x+half+10,y+328,half,52),"乗車口を迂回先へ移す",dark:true)) Submit(()=>G.ResolveBlock(false));
            }
            else
            {
                Text(R(x,y+228,width,26),"迎車の停車場所",18,Cream,true);
                float third=(width-12)/3;
                for(int n=0;n<3;n++)
                {
                    int stop=n;
                    if(Button(R(x+n*(third+6),y+262,third,44),Stops[n]+"　"+G.StopWaiting(n)+"人",selected:G.FleetStop==n,dark:true))
                        Submit(()=>G.CallShuttle(stop));
                }
                if(Button(R(x,y+322,width,45),G.ReserveForInjured?"最後の1席　負傷者を優先":"最後の1席　到着順",selected:G.ReserveForInjured,dark:true))
                    Submit(G.ReserveSeat);
                Text(R(x,y+371,width,26),G.FleetUpdate,16,Mist);
            }
            if(Button(R(x,y+403,width,43),G.Mode=="FPS"?"現場に戻る":"指揮に戻る",dark:true))fleetOpen=false;
        }
    }
}
