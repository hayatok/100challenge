using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool bookOpen;
        Texture2D operationMaps;
        GameSim Field => G.SearchSimulation;
        bool ChapterTask => Field.ChapterPhase==1 || Field.ChapterPhase==3;
        void ToggleBook()
        {
            if(G.IsDuty)return;
            bool show=!bookOpen;
            CloseFieldOverlay();
            bookOpen=show;
        }
        string ImmediateLabel()
        {
            if(ChapterTask)return Field.ChapterChoice<0?"現場方針を決める":Field.ChapterTitle;
            if(G.FleetBlocked)return "本線の通行障害";
            if(Field.WingActive && !Field.WingComplete)return "館内の救助を指揮";
            if(!G.IsDuty && !G.HasPosting(G.CurrentDistrict) && G.FieldOutcome(G.CurrentDistrict)==0) return G.FieldDistrict(G.CurrentDistrict)+"に班を派遣";
            return G.CanDepart?"出発を指示":"作戦手帳";
        }
        void Immediate()
        {
            if(ChapterTask){bookOpen=true;return;}
            if(G.FleetBlocked){fleetOpen=true;return;}
            if(Field.WingActive && !Field.WingComplete){OpenWing();return;}
            if(!G.IsDuty && !G.HasPosting(G.CurrentDistrict) && G.FieldOutcome(G.CurrentDistrict)==0){OpenDispatch();return;}
            if(G.CanDepart)Submit(G.Depart);else bookOpen=true;
        }
        void DrawFieldAccess(bool direct)
        {
            if(G.IsDuty)return;
            if(direct)
            {
                if(Button(R(w*.50f-70,BoardHeight+12,140,G.TouchUI?43:31),G.TouchUI?"作戦手帳":"F2　作戦手帳",dark:true))ToggleBook();
                return;
            }
            float height=G.TouchUI?45:36;
            string next=ImmediateLabel();
            float x=w-328, y=BoardHeight+18;
            if(next!="作戦手帳" && Button(R(x,y,190,height),next,primary:true))Immediate();
            if(Button(R(w-132,y,118,height),"作戦手帳",dark:true))ToggleBook();
        }
        void DrawBook()
        {
            ModalBackdrop();
            Rect panel=Dialog(768,463);
            float x=panel.x+20,y=panel.y,width=panel.width-40;
            string section=Field.ChapterPhase==1?"前哨":Field.ChapterPhase==3?"撤収":"避難輸送";
            Text(R(x,y+9,width-120,33),G.DistrictName(G.MissionIndex)+"　／　"+section,20,Amber,true);
            if(Button(R(x+width-94,y+7,94,37),"閉じる",dark:true)){bookOpen=false;return;}
            Text(R(x,y+47,width,40),ChapterTask?Field.ChapterTitle:FieldName,29,Cream,true);
            Paragraph(R(x,y+90,width,51),ChapterTask?Field.ChapterIncident:G.Objective,BodySize,Mist);
            Rect map=R(x,y+147,146,235);
            DrawStripMap(map);
            float content=map.xMax+17,cw=x+width-content;
            if(ChapterTask) ChapterOrders(content,y+144,cw);
            else BookOrders(content,y+144,cw);
            Fill(R(x,y+390,width,1),Edge);
            bool showWing=Field.WingActive || Field.WingComplete;
            int count=(G.HasFleet?4:3)+(showWing?1:0);
            float tile=(width-(count-1)*6)/count;
            if(Button(R(x,y+401,tile,49),"地区派遣",dark:true)){bookOpen=false;OpenDispatch();}
            if(Button(R(x+tile+6,y+401,tile,49),"市街捜索",dark:true)){bookOpen=false;searchDeskOpen=true;}
            int slot=2;
            if(G.HasFleet && Button(R(x+slot++*(tile+6),y+401,tile,49),"車列の運行",primary:G.FleetBlocked,dark:true)){bookOpen=false;fleetOpen=true;}
            if(showWing && Button(R(x+slot++*(tile+6),y+401,tile,49),"館内見取図",dark:true))OpenWing();
            if(Button(R(x+slot*(tile+6),y+401,tile,49),"現場からの要請",dark:true)){bookOpen=false;requestOpen=true;}
        }
        void ChapterOrders(float x,float y,float width)
        {
            int chosen=Field.ChapterChoice;
            for(int index=0;index<2;index++)
            {
                int response=index;
                float top=y+index*68;
                bool selected=chosen==index;
                if(Button(R(x,top,width,39),Field.ChapterOptionTitle(index),selected:selected,dark:true))
                    Submit(()=>G.ChooseResponse(response));
                Text(R(x+7,top+39,width-14,26),Field.ChapterOptionDetail(index),15,selected?Amber:Mist);
            }
            if(chosen<0){Text(R(x,y+154,width,41),"先に対応する方針を選んでください。",17,Cream);return;}
            if(G.Mode=="FPS"){
                Paragraph(R(x,y+143,width,46),Field.ChapterInstruction,17,Amber);
                if(Button(R(x,y+190,width,44),"現場に戻る",true))bookOpen=false;
                return;
            }
            float gap=5,third=(width-2*gap)/3;
            for(int i=0;i<3;i++)
            {
                int group=i;
                if(Button(R(x+i*(third+gap),y+139,third,41),G.SquadName(i),enabled:HasSquad(i),selected:G.SelectedSquad==i,dark:true))
                    Submit(()=>G.SelectSquad(group));
            }
            bool signal=Field.ChapterNeedsSupport;
            float mainWidth=signal?(width-6)*.53f:width;
            if(Button(R(x,y+188,mainWidth,45),G.SquadName(G.SelectedSquad)+"を現場へ",true))
                Submit(()=>{G.AssignResponse(false);bookOpen=false;});
            if(signal && Button(R(x+mainWidth+6,y+188,width-mainWidth-6,45),"反対側を担当",dark:true))
                Submit(()=>{G.AssignResponse(true);bookOpen=false;});
        }
        void BookOrders(float x,float y,float width)
        {
            Text(R(x,y,width,30),G.SectorName+"　"+G.FieldTask(G.CurrentDistrict),19,Amber,true);
            string state=G.FleetBlocked?G.FleetUpdate:G.Radio;
            Paragraph(R(x,y+36,width,58),state,17,Mist);
            if(Button(R(x,y+102,width,47),G.FleetBlocked?"車列の運行を決める":"地区の派遣先を選ぶ",true)){
                bookOpen=false;
                if(G.FleetBlocked)fleetOpen=true;else OpenDispatch();
            }
            float half=(width-6)/2;
            if(Button(R(x,y+157,half,46),G.LampName+"　"+G.LampCost,enabled:G.LampAvailable,dark:true))
                Submit(()=>{bookOpen=false;G.UseLamp();});
            if(Button(R(x+half+6,y+157,half,46),"設備・資材",dark:true)){bookOpen=false;fieldPanel=true;}
            if(Field.HasChapterPost)
            {
                string label=Field.ChapterPostLabel+"で補給　残り"+Field.ChapterPostStock+"箱";
                if(Button(R(x,y+207,width,33),label,enabled:Field.ChapterPostStock>0 && G.Mode=="RTS",dark:true))
                    Submit(()=>{G.AssignPostSupply();bookOpen=false;});
            }
        }
        void DrawStripMap(Rect map)
        {
            Instrument(map);
            Rect plan=R(map.x+3,map.y+27,map.width-6,map.height-53);
            if(!operationMaps)operationMaps=Resources.Load<Texture2D>("UI/OperationMaps");
            GUI.DrawTextureWithTexCoords(plan,operationMaps,new Rect((G.MissionIndex/2)*.25f,0,.25f,1));
            Vector2 Plot(Vector3 p)=>new Vector2(plan.center.x+p.x*plan.width/86,plan.center.y-p.z*plan.height/186);
            Vector2 stop=Plot(Field.ActiveExit);
            Outline(R(stop.x-4,stop.y-2,8,4),Mist);
            int inside=0;
            foreach(var unit in Field.Units)
                if(unit.active && !unit.boarded && unit.kind==UnitKind.Soldier && unit.pos.z>92)inside++;
            Text(R(map.x+4,map.y+2,map.width-8,24),inside>0?"北　館内に"+inside+"人":"北街区",14,Mist,true,TextAnchor.MiddleCenter);
            Text(R(map.x+8,map.yMax-24,map.width-16,22),"南街区",14,Mist,true,TextAnchor.MiddleCenter);
            foreach(var unit in Field.Units)
            {
                if(!unit.active || unit.boarded || Mathf.Abs(unit.pos.z)>92 || (unit.kind!=UnitKind.Soldier && !unit.visible))continue;
                var p=Plot(unit.pos);
                var color=unit.kind==UnitKind.Soldier?Green:unit.kind==UnitKind.Infected?Rail:Mist;
                bool selected=unit==Field.Controlled || (unit.kind==UnitKind.Soldier && unit.squad==G.SelectedSquad);
                float width=selected?5:3;
                Fill(R(p.x-width*.5f-.5f,p.y-width*.5f-.5f,width+1,width+1),Ink);
                Fill(R(p.x-width*.5f,p.y-width*.5f,width,width),selected?Cream:color);
            }
            if(ChapterTask && Field.ChapterChoice<0)return;
            bool support=ChapterTask && Field.ChapterAssigned(G.SelectedSquad)==1;
            if(ChapterTask && Field.ChapterNeedsSupport)
            {
                var other=Plot(Field.ChapterPoint(!support));
                Outline(R(other.x-3,other.y-3,6,6),Mist);
            }
            Vector3 target=ChapterTask?Field.ChapterPoint(support):Field.DistrictPosition(Field.Sector);
            var site=Plot(target);
            Outline(R(site.x-5,site.y-5,10,10),Amber,2);
        }
    }
}
