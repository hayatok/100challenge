using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool fieldDispatchOpen;
        int dispatchSector;
        internal bool FieldOverlay => bookOpen || fieldPanel || requestOpen || fieldDispatchOpen || fleetOpen || searchDeskOpen;
        internal bool CloseFieldOverlay()
        {
            if(!FieldOverlay) return false;
            bookOpen=fieldPanel=requestOpen=fieldDispatchOpen=fleetOpen=searchDeskOpen=false;
            return true;
        }
        internal void SearchHotkey()
        {
            ToggleBook();
        }
        internal void InspectDispatchPanel() => OpenDispatch();
        internal void InspectFleetPanel() { fleetOpen=true; }
        void OpenDispatch()
        {
            dispatchSector = G.CurrentDistrict;
            fieldDispatchOpen = true;
        }
        void FieldDesk()
        {
            ModalBackdrop();
            Rect sheet = Dialog(724, 462);
            float x = sheet.x + 22, y = sheet.y, width = sheet.width - 44;
            Fill(R(x,y+21,5,38),Rail);
            Text(R(x+16,y+15,232,44),"地区派遣表",29,Cream,true);
            Text(R(x+250,y+21,width-250,32),G.DistrictName(G.MissionIndex)+"　"+FieldName,17,Mist,false,TextAnchor.MiddleRight);
            int current = G.CurrentDistrict;
            int first = Mathf.Max(0,current-1), last = Mathf.Min(G.SectorCount-1,current+1);
            dispatchSector = Mathf.Clamp(dispatchSector,first,last);
            float col = (width-8*(last-first))/(last-first+1);
            for (int i=first;i<=last;i++)
            {
                int section=i;
                string when = i<current?"通過":i==current?"進行中":"先遣";
                if (Button(R(x+(i-first)*(col+8),y+69,col,50),when+"　"+G.FieldDistrict(i),selected:i==dispatchSector,dark:true))
                    dispatchSector=section;
            }
            int n=dispatchSector;
            Text(R(x,y+127,width,26),G.FieldHeading(n)+"　／　"+G.FieldTask(n),20,Amber,true);
            string waiting=G.WaitingResidents(n)>0?"出張所で救助を待つ住民　"+G.WaitingResidents(n)+"人":n>current?"次の避難先を先に調べられます":"地区名簿と避難経路を確認";
            Text(R(x,y+156,width,25),waiting,16,Mist);
            float squadWidth=(width-12)/3;
            for(int squad=0;squad<3;squad++)
            {
                int group=squad, assigned=G.SquadPosting(squad);
                string job=assigned<0?G.SquadOrderName(squad):G.FieldDistrict(assigned);
                if(Button(R(x+squad*(squadWidth+6),y+190,squadWidth,56),G.SquadName(squad)+"　"+job,
                    enabled:HasSquad(squad),selected:G.SelectedSquad==squad,dark:true))
                    Submit(()=>G.SelectSquad(group));
            }
            float half=(width-10)/2;
            bool can=G.CanPost(G.SelectedSquad,n);
            int outcome=G.FieldOutcome(n);
            for(int i=0;i<2;i++)
            {
                bool freight=i==0;
                float left=x+i*(half+10);
                Instrument(R(left,y+258,half,122));
                Text(R(left+10,y+263,half-20,26),G.IncidentChoice(n,freight),19,Cream,true);
                Paragraph(R(left+10,y+294,half-20,48),G.FieldPayoff(n,freight),16,Mist);
                string label=outcome==1?"輸送済み":outcome==2?(freight?"確保済み":"中継所に配置"):G.SquadName(G.SelectedSquad)+"を派遣";
                if(Button(R(left+8,y+335,half-16,39),label,primary:can&&!freight,enabled:can && (!freight || outcome==0),dark:freight))
                    Submit(()=>{G.SendDistrict(n,freight);fieldDispatchOpen=false;});
            }
            Text(R(x,y+383,width,25),G.FieldPost,15,Amber);
            if(Button(R(x,y+411,half,40),"地図で見る",dark:true))
                Submit(()=>{G.InspectDistrict(n);fieldDispatchOpen=false;});
            if(Button(R(x+half+10,y+411,half,40),G.Mode=="FPS"?"現場に戻る":"指揮に戻る",dark:true)) fieldDispatchOpen=false;
        }
    }
}
