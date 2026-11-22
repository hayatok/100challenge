using UnityEngine;

public sealed partial class KinseiSession
{
    enum WestOutcome { Waiting, Active, Won, Lost, Left }
    enum WestBeat { Waiting, Signal, Opening }
    const string WestChallenge="瀬尾に一騎打ちを申し込む";
    static readonly Vector3 SeoDoor=new(-37.2f,0,-11.5f);
    static readonly Vector3[] WestHomes={new(-39,0,-12.4f),new(-39.9f,0,-12.4f)};
    static readonly Vector3[] EastBank={new(-24,0,-10.9f),new(-23.2f,0,-9.9f)};
    readonly Person[] westGuests=new Person[2],westEscorts=new Person[2];
    readonly bool[] pickedWest=new bool[2],safeWest=new bool[2];
    Person westSeo,westRelieved;
    WestOutcome westOutcome;
    WestBeat westBeat;
    bool westDuel,westFollowing;
    int westReplies,westMisses;
    float westDeadline,westBeatAt;
    Vector3 westMark;

    bool WestNearby => !finale && phase==Phase.Arrival && player!=null && !AboveStreet &&
        player.Position.x< -20.5f && player.Position.z>=-16.9f && player.Position.z<=-6.7f;
    bool WestAvailable => westOutcome==WestOutcome.Waiting || westOutcome==WestOutcome.Active;
    bool WestCanOrder => WestNearby && westSeo!=null && WestAvailable;
    bool WestCanChallenge => WestCanOrder && !westDuel && Flat(player.Position,westSeo.Position)<1.85f;

    void ResetWestDispute()
    {
        westOutcome=WestOutcome.Waiting;westBeat=WestBeat.Waiting;
        westDuel=westFollowing=false;westReplies=westMisses=0;westSeo=westRelieved=null;
        for(int i=0;i<2;i++){westGuests[i]=westEscorts[i]=null;pickedWest[i]=safeWest[i]=false;}
    }

    int WestEscortIndex(Person p)
    {
        if(p!=null)for(int i=0;i<2;i++)if(westEscorts[i]==p)return i;
        return -1;
    }

    void ReleaseWestEscort(Person p)
    {
        int i=WestEscortIndex(p);
        if(i<0)return;
        westEscorts[i]=null;pickedWest[i]=false;p.path=null;
    }

    void CloseWestDispute()
    {
        foreach(var p in westEscorts)ReleaseWestEscort(p);
        if(westSeo!=null)Motion(westSeo,"idle");
        foreach(var guest in westGuests)if(guest!=null)Motion(guest,"idle");
        if(WestAvailable)westOutcome=WestOutcome.Left;
        westDuel=false;
    }

    void StartWestClock()
    {
        if(westOutcome!=WestOutcome.Waiting)return;
        westOutcome=WestOutcome.Active;westDeadline=clock+38;
    }

    string WestOrderLabel
    {
        get {
            int mask=SelectedMembers;
            for(int i=0;i<crew.Count;i++)if((mask&(1<<i))!=0 && WestEscortIndex(crew[i])<0)return "客を迎える　E";
            return mask!=0?"迎えを取消　E":"客を迎える　E";
        }
    }

    void OrderWestEscorts()
    {
        int mask=SelectedMembers,count=CountMembers(mask);
        if(count<1 || count>2){Say("迎えに出す組員を一人か二人選ぶ");return;}
        int needed=0,free=0;
        for(int i=0;i<2;i++)if(!safeWest[i] && westEscorts[i]==null)free++;
        for(int i=0;i<crew.Count;i++){
            if((mask&(1<<i))==0 || WestEscortIndex(crew[i])>=0)continue;
            var p=crew[i];
            if(!GroupOrder(p.duty)){Say(p.name+"の今の仕事を先に解いてください");return;}
            needed++;
        }
        if(needed>free){Say("今の迎えを取り消してから交代");return;}
        if(needed==0){
            for(int i=0;i<crew.Count;i++)if((mask&(1<<i))!=0)ReleaseWestEscort(crew[i]);
            Say("迎えを取り消した");return;
        }
        for(int i=0;i<crew.Count;i++){
            if((mask&(1<<i))==0 || WestEscortIndex(crew[i])>=0)continue;
            for(int j=0;j<2;j++)if(!safeWest[j] && westEscorts[j]==null){
                westEscorts[j]=crew[i];crew[i].path=null;break;
            }
        }
        StartWestClock();Say("湯客を橋の東へ。瀬尾が見張る間は客が動けない");
    }

    void StartWestChallenge()
    {
        StartWestClock();westDuel=westFollowing=true;westBeat=WestBeat.Waiting;westBeatAt=clock+.4f;
        Say("瀬尾「わしが相手や」　踏み込みをかわして F");
    }

    void ReplyWest()
    {
        if(westBeat!=WestBeat.Opening || clock>=westBeatAt || Flat(player.Position,westSeo.Position)>2.65f)return;
        attackUntil=clock+.32f;player.lastAction=clock;Motion(player,"punch");sound.Cue("strike");westBeat=WestBeat.Waiting;westBeatAt=clock+1.0f;
        if(++westReplies>=2)WinWestDispute();
        else Say("一本返した。あと一本",1.1f);
    }

    void WinWestDispute()
    {
        westOutcome=WestOutcome.Won;westDuel=false;westBeatAt=clock+.86f;Motion(westSeo,"surrender");
        if(upstairs.Count>0){
            westRelieved=upstairs[upstairs.Count-1];westRelieved.name="浜口";
            westRelieved.retired=true;westRelieved.watching=null;
        }
        Say("橋が開いた。二階の浜口は今夜の加勢を降りた",4.2f);Mark("west-open");
    }

    void LoseWestDispute()
    {
        CloseWestDispute();westOutcome=WestOutcome.Lost;
        Say("瀬尾が客を引き留めた。金星へ戻れる");
    }

    void WestWalk(Person p,Vector3 to,float speed,float dt,float stop=.2f)
    {
        if(Flat(p.Position,to)<=stop || !FollowWalkway(p,to,speed,dt))Motion(p,"idle");
    }

    void TickWestDispute(float dt)
    {
        if(phase!=Phase.Arrival || finale || InDawn)return;
        if(westSeo==null){
            if(!WestNearby || westOutcome!=WestOutcome.Waiting)return;
            westSeo=Make("湊組の代貸・瀬尾","seo",SeoDoor,1);
            for(int i=0;i<2;i++){
                westGuests[i]=Make(i==0?"湯客・文子":"湯客・喜一",i==0?"west-fumiko":"west-kiichi",WestHomes[i],i==0?0:2);
                Face(westGuests[i],new Vector3(-37.35f,0,-14.20f));
            }
        }
        if(westOutcome==WestOutcome.Active && !WestNearby){CloseWestDispute();return;}
        if(westOutcome==WestOutcome.Won){
            if(clock>=westBeatAt)WestWalk(westSeo,new Vector3(-42.7f,0,-9.65f),1.58f,dt);
            for(int i=0;i<2;i++)AdvanceGuest(i,dt,true);
            return;
        }
        if(!WestAvailable || !WestNearby)return;
        if(westOutcome==WestOutcome.Waiting){Face(westSeo,player.Position);return;}
        if(clock>=westDeadline){LoseWestDispute();return;}
        float gap=Flat(westSeo.Position,player.Position);
        if(gap<5.3f)westFollowing=true;else if(gap>9.5f)westFollowing=false;
        if(westBeat==WestBeat.Waiting){
            if(westFollowing)WestWalk(westSeo,player.Position,2.65f,dt,1.25f);
            else WestWalk(westSeo,SeoDoor,2.1f,dt);
            if(westDuel && gap<1.95f && clock>=westBeatAt){
                westBeat=WestBeat.Signal;westBeatAt=clock+.84f;westMark=player.Position;
                Face(westSeo,westMark);Motion(westSeo,"guard");Say("瀬尾が踏み込む！",.75f);
            }
        } else if(clock>=westBeatAt){
            if(westBeat==WestBeat.Signal){
                westSeo.lastAction=clock;Motion(westSeo,"punch");
                if(Flat(westMark,player.Position)>.7f){
                    westBeat=WestBeat.Opening;westBeatAt=clock+1.2f;Say("今や　F で返す",1.2f);
                } else {
                    if(++westMisses>=2){LoseWestDispute();return;}
                    westBeat=WestBeat.Waiting;westBeatAt=clock+.95f;Say("押し戻された。次は一歩かわす",1);
                }
            } else {westBeat=WestBeat.Waiting;westBeatAt=clock+.45f;}
        }
        for(int i=0;i<2;i++)AdvanceGuest(i,dt,false);
        if(safeWest[0] && safeWest[1])WinWestDispute();
    }

    void AdvanceGuest(int index,float dt,bool open)
    {
        if(safeWest[index])return;
        var runner=westEscorts[index];var guest=westGuests[index];
        if(runner!=null && (runner.hp<=0 || !GroupOrder(runner.duty))){ReleaseWestEscort(runner);runner=null;}
        if(open && runner==null)WestWalk(guest,EastBank[index],2.25f,dt);
        else if(runner==null){Motion(guest,"idle");return;}
        else {
            bool blocked=!open && Flat(guest.Position,westSeo.Position)<3.1f;
            float gap=Flat(guest.Position,runner.Position);
            if(!pickedWest[index]){
                WestWalk(runner,guest.Position+Vector3.right*.50f,3.55f,dt);
                if(gap<1.05f && !blocked){pickedWest[index]=true;runner.path=null;}
                Motion(guest,"idle");return;
            }
            if(blocked || gap>1.35f)Motion(runner,"idle");
            else WestWalk(runner,EastBank[index]+Vector3.right*.43f,2.1f,dt);
            if(blocked)Motion(guest,"idle");
            else WestWalk(guest,runner.Position-Vector3.right*.34f,2.42f,dt,.28f);
        }
        if(Flat(guest.Position,EastBank[index])>.92f)return;
        safeWest[index]=true;ReleaseWestEscort(runner);Motion(guest,"idle");
        if(!open)Say(guest.name+"が橋を渡った");
    }

    string WestObjective()
    {
        if(westOutcome==WestOutcome.Won)return "湯客の道が開いた　二階の浜口は手を引いた";
        if(!WestAvailable)return "橋の一件は終わった　金星へ";
        if(westOutcome==WestOutcome.Waiting)return "銭湯前の瀬尾に E ／ 指揮で湯客の迎えを出す";
        string action=westDuel?(westBeat==WestBeat.Opening?"F で返す":"踏み込みをかわす"):"瀬尾の注意を引く";
        return "湯客 "+((safeWest[0]?1:0)+(safeWest[1]?1:0))+"/2　"+Mathf.CeilToInt(westDeadline-clock)+"秒　"+action;
    }
}
