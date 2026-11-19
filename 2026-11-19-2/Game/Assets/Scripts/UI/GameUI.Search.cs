using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool searchDeskOpen;
        int searchPage, searchRow;
        void DrawSearchTab(Rect button)
        {
            if(Button(button,"市街捜索",dark:true))searchDeskOpen=true;
        }
        void DrawSearchDesk()
        {
            ModalBackdrop();
            var sim=G.SearchSimulation;
            Rect box=Dialog(754,458);
            float x=box.x+18,y=box.y,width=box.width-36;
            Text(R(x,y+10,width-99,35),"市街捜索　"+sim.SearchTitle,23,Cream,true);
            if(Button(R(x+width-90,y+7,90,39),"閉じる",dark:true)){searchDeskOpen=false;return;}
            string[] pages={"聞き込み","捜索先","同行・救護"};
            for(int i=0;i<3;i++)
                if(Button(R(x+i*(width+6)/3,y+53,(width-12)/3,40),pages[i],selected:searchPage==i,dark:true)){
                    searchPage=i;searchRow=0;
                }
            int first=3*searchPage;
            string intro=searchPage==0?sim.SearchCall:searchPage==1?
                "報告を2件集めたら、二人の行き先を推理します。選んだ部屋が無人なら、別の部屋を調べてください。":
                "住民を集積所の救護班まで連れていきます。別の班を前方救護所に置くと、そちらが近い住民は現地で引き渡せます。";
            Paragraph(R(x,y+100,width,46),intro,16,Mist);
            float left=width*.40f,right=x+left+14,rw=width-left-14;
            for(int i=0;i<3;i++){
                int t=first+i;
                if(Button(R(x,y+151+i*49,left,43),sim.SearchTaskName(t),selected:searchRow==i,dark:true))searchRow=i;
            }
            int task=first+searchRow;
            Instrument(R(right,y+151,rw,145));
            Text(R(right+10,y+157,rw-20,29),sim.SearchTaskName(task),19,Cream,true);
            string body=task<3?sim.SearchReport(task):task<6?sim.SearchTaskState(task):
                task<8?sim.SearchPersonLine(task-6):"班が現地にいる間、救助した住民を受け入れます。";
            if(task>=6 && task<8 && sim.PreviousSearchReturn(task-6))body+="　以前の作戦で救出済み。";
            if(task<3 && body=="未聴取")body="班を送るか、自分で現地に入り、証言や書き置きを確かめてください。";
            if(task>=3 && task<6 && body.Length==0)body="報告と行き先を照合し、この部屋を捜すなら班を派遣してください。";
            Paragraph(R(right+10,y+191,rw-20,65),body,17,Mist);
            var spot=sim.SearchPoint(task);
            string area=spot.z>35?"北街区":spot.z< -35?"南街区":"中央通り";
            Text(R(right+10,y+258,rw-20,29),area+"　"+(spot.x<0?"西側":"東側")+"　"+sim.SearchSupply(task),15,Amber);
            Text(R(x,y+304,width,26),"聞き込み "+sim.SearchReportCount+"/3　　"+sim.SearchName(0)+"・"+sim.SearchName(1),16,Cream);
            for(int i=0;i<3;i++){
                int squad=i;
                if(Button(R(x+i*(width+6)/3,y+338,(width-12)/3,42),G.SquadName(i),
                    enabled:HasSquad(i),selected:G.SelectedSquad==i,dark:true))Submit(()=>G.SelectSquad(squad));
            }
            float half=(width-8)/2;
            if(Button(R(x,y+393,half,48),G.Mode=="FPS"?"行き先を表示":"地図で見る",enabled:sim.SearchTaskOpen(task),dark:true))
                Submit(()=>{G.LocateSearchPoint(task,false);searchDeskOpen=false;});
            if(Button(R(x+half+8,y+393,half,48),G.SquadName(G.SelectedSquad)+"を派遣",
                primary:true,enabled:sim.CanSendSearch(G.SelectedSquad,task)))
                Submit(()=>{G.LocateSearchPoint(task,true);searchDeskOpen=false;});
        }
    }
}
