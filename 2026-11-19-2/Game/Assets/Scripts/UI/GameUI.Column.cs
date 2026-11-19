using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool columnDesk;
        int lastColumn;

        internal void OpenColumn(int column)
        {
            if(Field.ColumnCount<=0 || (!Field.ColumnsActive && !Field.ColumnsComplete))return;
            CloseFieldOverlay();
            lastColumn=Mathf.Clamp(column,0,Field.ColumnCount-1);
            columnDesk=bookOpen=true;
        }

        void DrawColumnDesk()
        {
            ModalBackdrop();
            Rect sheet=Dialog(794,466);
            float x=sheet.x+18,y=sheet.y,width=sheet.width-36;
            int c=Mathf.Clamp(lastColumn,0,Field.ColumnCount-1);
            Text(R(x,y+8,width-380,27),G.DistrictName(G.MissionIndex)+"　／　避難隊列",19,Amber,true);
            if(Button(R(x+width-382,y+7,154,40),G.Mode=="FPS"?"隊列の位置を確認":"地図で隊列を見る",dark:true))
                Submit(()=>
                {
                    if(G.TouchUI && G.Mode=="RTS")rosterFolded=ordersFolded=true;
                    G.LocateColumn(c);
                    columnDesk=bookOpen=false;
                });
            if(Button(R(x+width-220,y+7,112,40),"作戦手帳へ",dark:true))columnDesk=false;
            if(Button(R(x+width-100,y+7,100,40),"閉じる",dark:true)){columnDesk=bookOpen=false;return;}
            int columns=Field.ColumnCount;
            float tab=(width-8*(columns-1))/columns;
            if(columns==1)Text(R(x,y+43,width,39),Field.ColumnTitle(0),26,Cream,true);
            else for(int i=0;i<columns;i++)
                if(Button(R(x+i*(tab+8),y+52,tab,37),Field.ColumnTitle(i),selected:c==i,dark:true))lastColumn=i;
            Rect roll=R(x,y+97,width*.38f,288);
            Instrument(roll);
            Text(R(roll.x+9,roll.y+5,roll.width-18,28),"同行者　"+Field.ColumnMemberCount(c)+"人",19,Cream,true);
            bool needsAid=false;
            for(int i=0;i<Field.ColumnMemberCount(c);i++)
            {
                var u=Field.Find(Field.ColumnMemberId(c,i));
                if(u==null)continue;
                needsAid|=u.active && u.wounded;
                float row=roll.y+35+i*32;
                string mobility=Field.ColumnMemberOutcome(c,i) switch
                {
                    1=>"乗車済み", 2=>"退避済み", 3=>"死亡", _=>u.id==Field.ColumnCarriedId(c)?"担架":u.wounded?"負傷":"歩行可"
                };
                Text(R(roll.x+10,row,roll.width-85,29),u.name,17,Cream,true);
                Text(R(roll.xMax-87,row,77,29),mobility,16,u.wounded?Amber:Mist,false,TextAnchor.MiddleRight);
                Fill(R(roll.x+10,row+30,roll.width-20,1),Edge);
            }
            float left=roll.x+10,staffWidth=roll.width-20;
            var leader=Field.Find(Field.ColumnLeaderId(c));
            var bearer=Field.Find(Field.ColumnCarrierId(c));
            if(leader==null && bearer==null)
                Text(R(left,roll.y+165,staffWidth,38),Field.ColumnFinished(c)?"付添終了":"先導役は未配置",17,Amber,true);
            else
            {
                float slot=leader!=null && bearer!=null && leader!=bearer?(staffWidth-4)*.5f:staffWidth;
                if(leader!=null && leader!=bearer)ColumnStaff(R(left,roll.y+165,slot,38),leader,"先導");
                if(bearer!=null)ColumnStaff(R(roll.xMax-10-slot,roll.y+165,slot,38),bearer,"担架");
            }
            Paragraph(R(left,roll.y+205,staffWidth,36),Field.ColumnStatus(c),16,Mist);
            if(needsAid)DrawColumnAction(c,6,R(left,roll.y+242,roll.width-20,39));
            float right=roll.xMax+13,cw=x+width-right;
            string next=Field.ColumnNextStop(c);
            string stops=Field.ColumnCurrentStop(c)+(string.IsNullOrEmpty(next)?"":" → "+next);
            Text(R(right,y+95,cw,28),stops,19,Cream,true);
            if(G.Mode=="FPS")
                Text(R(right,y+126,cw,43),G.SoldierName+"　／　隊列まで "+Mathf.RoundToInt(Vector3.Distance(Field.Controlled.pos,Field.ColumnPosition(c)))+"m",17,Mist);
            else
            {
                float sw=(cw-8)/3;
                for(int i=0;i<3;i++)
                {
                    int squad=i;
                    if(Button(R(right+i*(sw+4),y+127,sw,40),G.SquadName(i),enabled:HasSquad(i),selected:G.SelectedSquad==i,dark:true))
                        Submit(()=>G.SelectSquad(squad));
                }
            }
            for(int route=0;route<2;route++)
            {
                float top=y+177+route*69;
                DrawColumnAction(c,route,R(right,top,cw,37));
                Text(R(right+5,top+37,cw-10,26),Field.ColumnRouteDetail(c,route),15,Mist);
            }
            float half=(cw-6)/2;
            DrawColumnAction(c,Field.ColumnHeld(c)?3:2,R(right,y+319,half,46));
            DrawColumnAction(c,4,R(right+half+6,y+319,half,46));
            Text(R(right,y+365,cw,22),Field.ColumnRouteDetail(c,4),14,Mist);
            Fill(R(x,y+391,width,1),Edge);
            if(G.MissionIndex==5 && c==1)
            {
                DrawColumnAction(c,7,R(x,y+396,roll.width,40));
                Text(R(x+5,y+435,roll.width-10,24),Field.ColumnRouteDetail(c,7),14,Mist);
            }
            DrawColumnAction(c,5,R(right,y+396,cw,40));
            Text(R(right,y+435,cw,24),Field.ColumnRouteDetail(c,5),14,Mist);
        }

        void ColumnStaff(Rect rect,Unit actor,string role)
        {
            string label=role+"　"+actor.name;
            if(G.Mode=="FPS"){Text(rect,label,17,Amber,true);return;}
            if(Button(rect,label+"に入る",dark:true))
                Submit(()=>{columnDesk=bookOpen=false;G.PossessFieldActor(actor.id);});
        }

        void DrawColumnAction(int column,int action,Rect rect)
        {
            string label=Field.ColumnActionLabel(column,action);
            if(string.IsNullOrEmpty(label))return;
            bool enabled=Field.CanCommandColumn(column,action,G.SelectedSquad);
            bool selected=action<=1 && Field.ColumnRoute(column)==action;
            if(Button(rect,label,primary:enabled && action==0,enabled:enabled,selected:selected,dark:true))
                Submit(()=>G.ColumnAction(column,action));
        }
    }
}
