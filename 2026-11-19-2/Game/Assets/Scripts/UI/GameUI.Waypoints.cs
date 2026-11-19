using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        void DrawWaypointEditor(Rect box,float x,float width,float half)
        {
            Text(R(x,box.y+4,width,24),G.SquadName(G.SelectedSquad)+"の経路　"+G.DraftCount+"/4",18,Amber,true);
            Text(R(x,box.y+30,width,25),"地図を順にタップして2〜4地点を指定",15,Mist);
            float right=x+half+6;
            if(Button(R(x,box.y+61,half,48),"終点で"+G.CurrentOrder,dark:true))Submit(G.CycleOrder);
            if(Button(R(right,box.y+61,half,48),"1点戻す",enabled:G.DraftCount>0,dark:true))Submit(G.UndoWaypoint);
            if(Button(R(x,box.y+114,half,48),"経路を送信",true,G.DraftCount>=2))Submit(G.SendWaypoints);
            if(Button(R(right,box.y+114,half,48),"編集を閉じる",dark:true))Submit(G.EndWaypointEdit);
            if(G.HasWaypoints && Button(R(x,box.y+167,width,48),"経路を解除して待機",dark:true))Submit(G.HaltWaypoints);
        }
    }
}
