using UnityEngine;

public sealed partial class KinseiSession
{
    const float CommandPanelHeight=193f;
    int extraMembers;
    readonly int[] squads=new int[2];
    readonly Vector3[] groupDestinations=new Vector3[6];

    void ResetSquads()
    {
        chosen=0;extraMembers=0;
        squads[0]=squads[1]=0;
    }

    bool IsMemberSelected(int i) => i>=0 && i<crew.Count && crew[i].hp>0 &&
        (chosen==i || (extraMembers & (1<<i))!=0);

    int LivingMembers(int mask)
    {
        int live=0;
        for(int i=0;i<crew.Count;i++)
            if((mask & (1<<i))!=0 && crew[i].hp>0)live|=1<<i;
        return live;
    }

    int SelectedMembers => LivingMembers(extraMembers | (chosen>=0?1<<chosen:0));

    static int CountMembers(int mask)
    {
        int count=0;
        while(mask!=0){mask&=mask-1;count++;}
        return count;
    }

    void SetSelection(int mask)
    {
        chosen=-1;extraMembers=0;
        for(int i=0;i<crew.Count;i++){
            if((mask & (1<<i))==0)continue;
            if(chosen<0)chosen=i;
            else extraMembers|=1<<i;
        }
    }

    void SelectMember(int index,bool extend)
    {
        if(crew[index].hp<=0){if(!extend)SetSelection(0);Say(crew[index].name+"は動けない");return;}
        int bit=1<<index;
        SetSelection(extend?SelectedMembers^bit:bit);
    }

    static string SquadLabel(int slot) => slot==0?"一班":"二班";

    void SaveSquad(int slot)
    {
        int members=SelectedMembers;
        if(members==0){Say("登録する組員を選んでください");return;}
        squads[slot]=members;
        Say(SquadLabel(slot)+"に"+CountMembers(members)+"人を登録した");
        sound.Cue("dial");
    }

    void RecallSquad(int slot)
    {
        int members=LivingMembers(squads[slot]);
        SetSelection(members);
        if(members==0){
            Say(squads[slot]==0?SquadLabel(slot)+"は未登録":SquadLabel(slot)+"に動ける組員がいない");
            return;
        }
        Say(SquadLabel(slot)+"の"+CountMembers(members)+"人を選んだ");
        sound.Cue("dial");
    }

    static bool GroupOrder(Duty duty) => duty==Duty.Go || duty==Duty.Follow || duty==Duty.Guard || duty==Duty.Rest;

    void Assign(Duty duty,Vector3 destination=default)
    {
        if(command && duty==Duty.Attend && WestCanOrder){OrderWestEscorts();return;}
        int members=SelectedMembers;
        int count=CountMembers(members);
        if(count==0){Say("動ける組員を選んでください");return;}
        SetSelection(members);
        if(count==1){AssignMember(chosen,duty,destination,true);return;}
        if(!GroupOrder(duty)){
            Say(duty==Duty.Attend && !finale?"梶との交渉は辰を一人選んでください":"この仕事は担当する組員を一人選んでください");
            return;
        }
        if(duty==Duty.Go && !FindGroupDestinations(members,destination)){
            Say("全員が立てる場所を指定してください");return;
        }
        for(int i=0;i<crew.Count;i++){
            if((members & (1<<i))!=0)
                AssignMember(i,duty,duty==Duty.Go?groupDestinations[i]:destination,false);
        }
        string order=duty==Duty.Go?"が指定地点へ向かう":duty==Duty.Follow?"が真壁に随行する":
            duty==Duty.Guard?"をホールへ回した":"を表へ下げた";
        Say(count+"人"+order);sound.Cue("dial");
    }

    bool FindGroupDestinations(int members,Vector3 centre)
    {
        if(!walkways.Ready)return false;
        // Try the clicked point first, then nearby positions in concentric rings.
        for(int i=0;i<crew.Count;i++){
            if((members & (1<<i))==0)continue;
            bool found=false;
            for(int candidate=0;candidate<25 && !found;candidate++){
                float angle=(candidate-1)*Mathf.PI*.25f;
                float radius=candidate==0?0:1.02f*(1+(candidate-1)/8);
                var at=centre+new Vector3(Mathf.Cos(angle)*radius,0,Mathf.Sin(angle)*radius);
                if(!walkways.Project(at,out var floor) || Mathf.Abs(floor.y-centre.y)>.42f)continue;
                bool occupied=false;
                for(int earlier=0;earlier<i;earlier++)
                    if((members & (1<<earlier))!=0 && Flat(floor,groupDestinations[earlier])<.90f){occupied=true;break;}
                if(occupied || !walkways.GetPath(crew[i].Position,floor,searchPath))continue;
                groupDestinations[i]=floor;found=true;
            }
            if(!found)return false;
        }
        return true;
    }

    void DrawSquadOrders(float top)
    {
        int mask=SelectedMembers,count=CountMembers(mask);
        float left=22,y=top+83;
        string label=count==0?"組員を選択":count==1?crew[FirstMember(mask)].name+" に指示":count+"人に指示";
        Letter(new Rect(left,y,152,44),label,21,gold,true);
        int buttons=3+(finale?1:2)+(CanOrderStageWitness?1:0)+(CanOrderBackstage?1:0);
        float x=178,width=Mathf.Min(153,(hudW-x-left-(buttons-1)*6)/buttons);
        void OrderButton(Duty duty,string caption)
        {
            Rect rect=new Rect(x,y,width,44);x+=width+6;
            if(count>1 && !GroupOrder(duty) && !(WestCanOrder && duty==Duty.Attend && count==2)){
                Letter(rect,caption,16,new Color(.88f,.85f,.80f),false,TextAnchor.MiddleCenter);
                Block(new Rect(rect.x,rect.yMax-1,rect.width,1),rule);
                if(GUI.Button(rect,GUIContent.none,GUIStyle.none))Assign(duty);
                return;
            }
            if(Plate(rect,caption))Assign(duty);
        }
        OrderButton(Duty.Follow,"随行　F");
        OrderButton(Duty.Guard,"持ち場　G");
        OrderButton(Duty.Rest,"休息　R");
        OrderButton(Duty.Attend,WestCanOrder?WestOrderLabel:finale?FinaleOrderLabel:"梶の席へ　E");
        if(!finale)OrderButton(Duty.BoxOffice,"伝票　T");
        if(CanOrderStageWitness)OrderButton(Duty.StageWitness,count==1 && crew[FirstMember(mask)]==stageWitness?"立会取消　V":"舞台立会　V");
        if(CanOrderBackstage)OrderButton(Duty.Backstage,count==1 && crew[FirstMember(mask)].duty==Duty.Backstage?"札口取消　B":"楽屋口　B");
        y=top+136;
        Letter(new Rect(left,y-2,445,25),"Shift＋数字・顔札　組員を追加／解除",16,cream);
        Letter(new Rect(left,y+20,445,25),phase==Phase.Floor?"右クリック　用心棒を指名／地面へ移動":count>1?"右クリックで移動　　個別の仕事は一人を選択":"右クリックで移動　　ホイールで拡縮",15,cream);
        float groupWidth=Mathf.Min(168,(hudW-492)/4);
        x=hudW-left-groupWidth*4;
        for(int slot=0;slot<2;slot++){
            string name=SquadLabel(slot);
            string recall=name+" "+CountMembers(LivingMembers(squads[slot]))+"人　F"+(slot+1);
            if(Plate(new Rect(x,y,groupWidth-5,44),recall))RecallSquad(slot);
            x+=groupWidth;
            if(Plate(new Rect(x,y,groupWidth-5,44),name+"登録　F"+(slot+3)))SaveSquad(slot);
            x+=groupWidth;
        }
    }

    static int FirstMember(int mask)
    {
        int i=0;
        while((mask & (1<<i))==0)i++;
        return i;
    }
}
