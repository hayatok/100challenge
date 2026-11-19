using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool requestOpen, requestLog;
        void DrawRequest()
        {
            ModalBackdrop();
            Rect panel=Dialog(530,345);
            float x=panel.x+24, top=panel.y, width=panel.width-48;
            Text(R(x,top+15,width,24),"現場からの追加要請",16,Amber,true);
            Text(R(x,top+45,width,45),G.RequestTitle,28,Cream,true);
            Paragraph(R(x,top+97,width,80),G.RequestDescription,BodySize,Mist);
            if(G.RequestStatus==RequestState.Offered)
            {
                Text(R(x,top+184,width,32),"避難作戦を続けながら対応できます。",17,Cream);
                if(Button(R(x,top+232,(width-8)/2,48),"引き受ける",true))
                    Submit(G.AcceptRequest);
                if(Button(R(x+(width+8)/2,top+232,(width-8)/2,48),"今回は見送る",dark:true))
                    Submit(G.DeclineRequest);
            }
            else if(G.RequestStatus==RequestState.Accepted)
            {
                Paragraph(R(x,top+181,width,49),G.RequestObjective,BodySize,Amber);
                if(Button(R(x,top+237,width,46),G.RequestSquadName+"を現場へ",true))
                    Submit(()=>{G.DispatchRequest();requestOpen=false;});
            }
            else Text(R(x,top+188,width,34),GameSession.RequestLabel(G.RequestStatus),20,Green,true);
            if(Button(R(x,top+291,width,42),G.Mode=="FPS"?"現場に戻る":"指揮に戻る",dark:true))requestOpen=false;
        }
        void DrawRequestRecords()
        {
            Rect panel=Dialog(560,460);
            float x=panel.x+24,width=panel.width-48;
            Text(R(x,panel.y+11,width,40),"現場要請の記録",26,Cream,true);
            for(int i=0;i<8;i++)
                Text(R(x,panel.y+58+i*41,width,34),(i+1).ToString("00")+"　"+G.RequestRecord(i),18,Mist);
            if(Button(R(x,panel.y+397,width,47),"最終報告に戻る",true))requestLog=false;
        }
    }
}
