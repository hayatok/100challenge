using UnityEngine;

public sealed partial class KinseiSession
{
    enum FinaleStep { Collect, Connect, Choose, Cooperative, Exclusive }
    enum FinaleAction { None, Take, Broadcast, Deliver, Talk }

    static readonly Vector3 NeedleDesk = new Vector3(-1.34f,0,-17.2f);
    static readonly Vector3 RelayDesk = new Vector3(14.9f,0,-17.2f);
    static readonly Vector3 RelaySeat = new Vector3(17.1f,0,-17.2f);
    static readonly Vector3 LotusDesk = new Vector3(-16,0,-17.2f);
    bool finale;
    float nextFinaleFrame;
    float firstPictureAt=-1;
    bool OnAir => finale && firstPictureAt>=0;
    FinaleStep finaleStep;
    Person operatorOnDuty, stageDirector;
    bool FinaleUnlocked => ledger.kajiPromise && ledger.stagePromise;

    void StartFinale()
    {
        if(!FinaleUnlocked)return;
        OpenNight(true);
    }

    void SetUpFinale()
    {
        finaleStep=FinaleStep.Collect;
        firstPictureAt=-1;
        nextFinaleFrame=0;
        operatorOnDuty=null;
        club.SetMasterOnDesk(new Vector3(-.88f,1.15f,-18.16f),false);
        foreach(var person in everyone) {
            if(person==player || crew.Contains(person))continue;
            person.retired=true;
            person.root.gameObject.SetActive(false);
        }
        stageDirector=Make("金星の座長","resident",KinseiBoxOffice.Counter+new Vector3(1.1f,0,.5f),4);
        Face(stageDirector,KinseiBoxOffice.Counter);
        Say("兵藤の書き置き「原盤は針音堂の左のターンテーブル。真壁さんに預けます」",6);
    }

    string FinaleObjective()
    {
        if(OnAir)return finaleStep==FinaleStep.Cooperative?"ロータスの一番席から共同放送を始める":"金星の帳場から専属興行を知らせる";
        switch(finaleStep) {
            case FinaleStep.Collect:return "針音堂の左の卓で原盤を受け取る";
            case FinaleStep.Connect:return operatorOnDuty==null?"指揮で組員を一人、東の送像所へ":"組員が送像所に着くのを待つ";
            case FinaleStep.Choose:return "送像所で共同放送、または金星の座長に原盤を渡す";
            case FinaleStep.Cooperative:return "指揮で組員をロータスの最初の客席へ";
            default:return "指揮で組員を金星の帳場へ";
        }
    }

    bool AtFinaleDesk(Vector3 target) => player.Position.y<.85f && Flat(player.Position,target)<1.18f;

    FinaleAction CurrentFinaleAction()
    {
        if(command)return FinaleAction.None;
        if(finaleStep==FinaleStep.Collect && AtFinaleDesk(NeedleDesk))return FinaleAction.Take;
        if(finaleStep==FinaleStep.Choose) {
            if(AtFinaleDesk(RelayDesk))return FinaleAction.Broadcast;
            if(AtFinaleDesk(KinseiBoxOffice.Counter))return FinaleAction.Deliver;
        }
        return StreetContact(out _,out _)?FinaleAction.Talk:FinaleAction.None;
    }

    string FinaleVerb()
    {
        if(OnAir)return "";
        switch(CurrentFinaleAction()) {
            case FinaleAction.Take:return "左の卓から原盤を受け取る";
            case FinaleAction.Broadcast:return "共同放送に針を落とす";
            case FinaleAction.Deliver:return "座長に専属の原盤を渡す";
            case FinaleAction.Talk:return "近くの人と話す";
            default:return "";
        }
    }

    void FinaleInteract()
    {
        switch(CurrentFinaleAction()) {
            case FinaleAction.Take:
                club.CarryMaster(player.actor.LeftWrist);
                finaleStep=FinaleStep.Connect;
                Say("真壁「原盤はここや。誰か送像所の交換卓を頼む」");break;
            case FinaleAction.Broadcast:
                club.SetMasterOnDesk(new Vector3(14.05f,1.264f,-18.22f),true);
                finaleStep=FinaleStep.Cooperative;
                Say("四十の回線が開いた。澄子「最初のお客さん、うちへ案内して」",5);break;
            case FinaleAction.Deliver:
                club.SetMasterOnDesk(KinseiBoxOffice.Counter+new Vector3(.27f,1.049f,.56f),false);
                finaleStep=FinaleStep.Exclusive;
                Face(stageDirector,player.Position);Motion(stageDirector,"talk");
                Say("座長「一枚目は金星の専属盤や。帳場へ一人、切符を頼むわ」",5);break;
            case FinaleAction.Talk:
                if(StreetContact(out _,out string words))Say(words);
                return;
            default:return;
        }
        sound.Cue("dial");
        Mark("finale-"+finaleStep);
    }

    string FinaleOrderLabel => finaleStep==FinaleStep.Cooperative?"客席へ　E":
        finaleStep==FinaleStep.Exclusive?"開場　E":"送像所　E";

    void OrderFinale()
    {
        if(finaleStep==FinaleStep.Collect || finaleStep==FinaleStep.Choose){Say(FinaleObjective());return;}
        Person member=crew[chosen];
        if(operatorOnDuty!=null && operatorOnDuty!=member && operatorOnDuty.duty==Duty.FinalePost)
            operatorOnDuty.duty=Duty.Follow;
        operatorOnDuty=member;
        member.duty=Duty.FinalePost;
        member.destination=finaleStep==FinaleStep.Cooperative?LotusDesk:
            finaleStep==FinaleStep.Exclusive?KinseiBoxOffice.Counter:RelaySeat;
        Say(member.name+"「任せてくれ」");
        sound.Cue("dial");Mark("finale-order-"+chosen+"-"+finaleStep);
    }

    void SimulateFinale(float dt)
    {
        if((finaleStep==FinaleStep.Cooperative || finaleStep==FinaleStep.Exclusive) && clock>=nextFinaleFrame) {
            nextFinaleFrame=clock+.12f;
            Vector3 target=finaleStep==FinaleStep.Cooperative?LotusDesk:stageDirector.Position;
            relayCam.transform.position=target+new Vector3(2f,1.72f,1.8f);
            relayCam.transform.LookAt(target+Vector3.up*1.26f);
            relayCam.Render();
            club.SetExchangePicture(relayImage);
        }
        for(int i=0;i<crew.Count;i++)UpdateCrew(crew[i],i,dt);
        if(operatorOnDuty==null)return;
        if(operatorOnDuty.duty!=Duty.FinalePost){
            operatorOnDuty=null;
            if(finaleStep==FinaleStep.Choose)finaleStep=FinaleStep.Connect;
            return;
        }
        if(Vector3.Distance(operatorOnDuty.Position,operatorOnDuty.destination)>.65f)return;
        if(finaleStep==FinaleStep.Connect) {
            finaleStep=FinaleStep.Choose;
            Say(operatorOnDuty.name+"「送像所、つながった。真壁さん、どちらに盤を？」",5);
            sound.Cue("choice");
        } else if((finaleStep==FinaleStep.Cooperative && operatorOnDuty.destination==LotusDesk) ||
                  (finaleStep==FinaleStep.Exclusive && operatorOnDuty.destination==KinseiBoxOffice.Counter)) {
            bool cooperative=finaleStep==FinaleStep.Cooperative;
            if(!OnAir) {
                firstPictureAt=clock;command=false;club.SetTactical(false);snapCamera=true;
                Face(operatorOnDuty,cooperative?new Vector3(-16,0,-19):stageDirector.Position);
                sound.Cue("accord");
                Say(cooperative?"澄子「一番席、聞こえてるよ。ほな始めよか」":"座長「宵待町のみなさん、お待たせしました」",3.6f);
                Mark("first-broadcast");
            }
            Motion(operatorOnDuty,"idle");
            if(clock-firstPictureAt<3.6f)return;
            if(cooperative)End("cooperative","四十軒の朝","ロータスの一席から拍手が返る。店ごとに出し物を決め、金星は四十軒の共同舞台になった。");
            else End("exclusive","金星の朝","座長が最初の切符を切る。金星が演目を決め、四十軒は専属興行の客席として朝を迎えた。");
        }
    }
}
