using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool directRadioOpen;
        void DrawDirectStrip()
        {
            float hgt=G.TouchUI?55:48;
            float left=G.TouchUI?Mathf.Min(309,w*.37f):335;
            Rect identity=R(14,12,left,hgt);
            Instrument(identity);
            Fill(R(14,12,4,hgt),Rail);
            string objective=ChapterTask?Field.ChapterTitle:G.SectorName;
            var actor=Field.Controlled;
            if(Field.WingActive && actor!=null && actor.pos.z>=93 && Mathf.Abs(actor.pos.x)<14.5f)
            {
                objective=Field.WingTitle;
                if(Mathf.Abs(actor.pos.x)>3.5f)
                {
                    int row=actor.pos.z<110?0:actor.pos.z<130?1:2;
                    objective=Field.WingRoomName(row*2+(actor.pos.x<0?0:1));
                }
            }
            Text(R(25,14,left-22,20),G.DistrictName(G.MissionIndex)+"　"+G.SquadName(G.SelectedSquad),14,Mist,true);
            Text(R(25,32,left-22,hgt-20),objective,20,Cream,true);
            float pauseW=G.TouchUI?81:76, bookW=G.TouchUI?111:123;
            float pauseX=w-14-pauseW, bookX=pauseX-bookW-6;
            if(Button(R(pauseX,12,pauseW,hgt),"一時停止",dark:true))Submit(G.Pause);
            if(!G.IsDuty && Button(R(bookX,12,bookW,hgt),G.TouchUI?"作戦手帳":"F2 作戦手帳",dark:true))ToggleBook();
            float statusWidth=G.TouchUI?170:188;
            float statusX=(G.IsDuty?pauseX:bookX)-statusWidth-6;
            Instrument(R(statusX,12,statusWidth,hgt));
            Text(R(statusX+9,13,statusWidth-18,19),G.IsDuty?"救出人数":"避難輸送",14,Mist,true);
            Text(R(statusX+9,31,statusWidth-18,hgt-18),G.Saved+"／"+G.Needed+"　"+Clock(G.Remaining),19,Amber,true);
        }
    }
}
