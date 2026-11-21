using UnityEngine;

public sealed partial class KinseiSession
{
    int dawnBranch,dawnStep;
    float dawnPrintTime;
    GameObject dawnTicket;
    Material dawnTicketInk;
    bool InDawn => phase==Phase.Dawn;

    bool DawnUnlocked(int branch) => pendingEnding==null && (branch==1?ledger.cooperativeEnding:
        branch==2 && ledger.exclusiveEnding);

    void OpenDawn(int branch)
    {
        if(!DawnUnlocked(branch) || (phase!=Phase.Title && phase!=Phase.Result && !InDawn))return;
        PrepareVisit(false,branch);
        dawnBranch=branch;dawnStep=0;dawnPrintTime=0;
        if(branch==2){
            stageDirector=Make("金星の座長","resident",KinseiBoxOffice.Counter+new Vector3(.84f,0,.68f),3);
            Face(stageDirector,boxOffice.LeverGrip);
            stageDirector.actor.SetAttentionTarget(boxOffice.LeverGrip);
            Motion(stageDirector,"print-ticket");
        }
        boxOffice.SetCollected(true);
        neighbours.SetDawnSchedule(branch);
        club.SetDawnProgramme(branch,0);
        SetPerformance(false);
        Say(branch==1?"澄子「堺の吹き手から、朝の一曲を預かってるで」":"座長「一番券が刷り上がる。針音堂に届けてくれへんか」",4.5f);
        Mark("dawn-enter-"+branch);
    }

    void ClearDawn()
    {
        if(dawnBranch==0)return;
        ReportFrames(dawnBranch==1?"morning-cooperative":"morning-exclusive");
        ClearDawnTicket();
        ResetRailRide();
        neighbours.SetDawnSchedule(0);club.SetDawnProgramme(0,0);
        sound.SetMorningRequest(false);
        SetPerformance(true);boxOffice.SetCollected(false);boxOffice.SetTicketPress(0);
        if(stageDirector!=null)stageDirector.root.gameObject.SetActive(false);
        shopView=ShopView.None;dawnBranch=dawnStep=0;
    }

    void TickDawn(float dt)
    {
        if(dawnBranch==2 && dawnStep==0){
            dawnPrintTime=Mathf.Min(2,dawnPrintTime+dt);
            boxOffice.SetTicketPress(dawnPrintTime);
            if(dawnPrintTime>=1.82f)Motion(stageDirector,"idle");
        }
    }

    string DawnObjective()
    {
        if(dawnBranch==1)return dawnStep==0?"ロータスで澄子の朝のリクエストを預かる":
            dawnStep==1?"共同送像所で「堺の朝」を放送する":"放送中の三店を歩いて訪ねる";
        return dawnStep==0?"金星の帳場で座長から一番券を受け取る":
            dawnStep==1?"針音堂の窓口へ一番券を届ける":"針音堂の前売り窓口と金星の帳場を訪ねる";
    }

    // Each job has a real counter contact. Speaking elsewhere never advances the programme.
    string DawnJob()
    {
        if(AboveStreet || dawnStep>=2)return "";
        if(dawnBranch==1){
            if(dawnStep==0 && AtFinaleDesk(LotusDesk))return "澄子から「堺の朝」のリクエストを預かる";
            if(dawnStep==1 && AtFinaleDesk(RelayDesk))return "送出卓から「堺の朝」をかける";
        } else {
            if(dawnStep==0 && dawnPrintTime>=1.64f && AtFinaleDesk(KinseiBoxOffice.Counter))return "座長から一番券を受け取る";
            if(dawnStep==1 && AtFinaleDesk(NeedleDesk))return "兵藤に一番券を渡す";
        }
        return "";
    }

    string DawnVerb()
    {
        string job=DawnJob();
        if(job.Length>0)return job;
        if(dawnBranch==2 && AtFinaleDesk(KinseiBoxOffice.Counter))return "座長と話す";
        if(!StreetContact(out _,out string words))return "";
        int quote=words.IndexOf('「');
        return (quote>0?words.Substring(0,quote):"近くの人")+"と話す";
    }

    void DawnInteract()
    {
        string job=DawnJob();
        if(job.Length>0){
            dawnStep++;
            if(dawnBranch==1){
                SpeakAtCounter(dawnStep==1?0:2,dawnStep==1?"澄子「吹き手が待ってる。村瀬さんの卓から、うちの一番席にも頼むわ」":
                    "村瀬「送出入った。ロータスまで聞こえてるで」",5);
                if(dawnStep==2){
                    sound.SetMorningRequest(true);
                    SetPerformance(true);
                }
            }else{
                if(dawnStep==1){boxOffice.SetTicketPress(0);CarryDawnTicket();Motion(stageDirector,"idle");Face(stageDirector,player.Position);}
                else ClearDawnTicket();
                if(dawnStep==1)Say("座長「金星専属の一番券や。針音堂に窓口を頼んだで」",5);
                else SpeakAtCounter(1,"兵藤「一番券、預かった。ほな前売りを始めよか」",5);
            }
            club.SetDawnProgramme(dawnBranch,dawnStep);
            sound.Cue("dial");Mark("dawn-work-"+dawnBranch+"-"+dawnStep);return;
        }
        if(dawnBranch==2 && AtFinaleDesk(KinseiBoxOffice.Counter)){
            Say(dawnStep==0?"座長「今、刷ってるところや」":dawnStep==1?"座長「兵藤の窓口に渡してや」":"座長「針音堂で前売りが始まったそうや」");return;
        }
        if(!StreetContact(out int shop,out string words))return;
        if(shop<0){Say(words);return;}
        string[] lines=dawnBranch==1?JointMorningLines:ExclusiveMorningLines;
        SpeakAtCounter(shop,lines[shop*2+(dawnStep==2?1:0)],4);
    }

    static readonly string[] JointMorningLines={
        "澄子「一番席は空けたで。朝の一曲を頼みたいんよ」","澄子「堺まで鳴ってるね。ここが今日の一番席や」",
        "兵藤「朝の盤なら、村瀬の卓に届いとる」","兵藤「ええ音やな。針音堂にも同じ曲が来とる」",
        "村瀬「ロータスの注文が来たら、この卓から送ろう」","村瀬「四十の客席、全部つながったで」"};
    static readonly string[] ExclusiveMorningLines={
        "澄子「今日は金星の開場待ちや。コーヒー淹れよか」","澄子「針音堂で切符が買えるって。常連に教えとくわ」",
        "兵藤「金星の券を待っとる。持ってきたら窓口を開くで」","兵藤「今朝の一枚はここや。次のお客さん、どうぞ」",
        "村瀬「今日は金星の開場を預かる回線や」","村瀬「前売りの知らせ、町内に回ったで」"};

    void CarryDawnTicket()
    {
        var paper=GameObject.CreatePrimitive(PrimitiveType.Cube);dawnTicket=paper;
        paper.name="座長から預かった一番券";
        var collider=paper.GetComponent<Collider>();collider.enabled=false;Destroy(collider);
        paper.transform.SetParent(player.actor.LeftWrist,false);
        paper.transform.localPosition=new Vector3(-.012f,-.118f,.042f);
        paper.transform.localRotation=Quaternion.Euler(8,5,-15);
        paper.transform.localScale=new Vector3(.14f,.068f,.003f);
        dawnTicketInk=new Material(Shader.Find("Standard")){name="金星専属の一番券",color=new Color(.92f,.77f,.52f)};
        var print=Resources.Load<Texture2D>("KinseiPrintworks/FirstTicket");
        if(print){dawnTicketInk.mainTexture=print;dawnTicketInk.color=Color.white;}
        paper.GetComponent<Renderer>().sharedMaterial=dawnTicketInk;
    }

    void ClearDawnTicket()
    {
        if(dawnTicket){dawnTicket.SetActive(false);Destroy(dawnTicket);dawnTicket=null;}
        if(dawnTicketInk){Destroy(dawnTicketInk);dawnTicketInk=null;}
    }

    void DrawDawnDepartures()
    {
        bool joint=DawnUnlocked(1),exclusive=DawnUnlocked(2);
        if(!joint && !exclusive)return;
        float x=hudW-372,y=hudH-180;
        Block(new Rect(x,y,344,161),ink);
        Letter(new Rect(x+14,y+6,318,28),"翌朝の宵待町を歩く",19,gold,true);
        if(joint && Plate(new Rect(x+14,y+40,316,45),"共同放送の朝　1"))OpenDawn(1);
        if(exclusive && Plate(new Rect(x+14,y+(joint?96:40),316,45),"専属興行の朝　2"))OpenDawn(2);
    }

    void DrawDawnHUD()
    {
        pauseSelection=0;
        Block(new Rect(0,0,hudW,69),ink);Block(new Rect(0,68,hudW,1),brass);
        Letter(new Rect(22,3,hudW-140,23),dawnBranch==1?"翌朝の宵待町　共同放送":"翌朝の宵待町　金星専属興行",15,gold);
        Letter(new Rect(22,24,hudW-135,38),DawnObjective(),21,cream,true);
        if(Plate(new Rect(hudW-102,11,80,44),"幕間 Esc"))TogglePause();
        float bottom=hudH-62;
        Block(new Rect(0,bottom,hudW,62),ink);
        string hints=RailHint();
        if(hints.Length==0)hints=shopView==ShopView.None?"WASD　町を歩く　　E　話す・仕事をする　　Esc　幕間・表題へ":
            ShopViewLabel(shopView)+"　　C　元の視点へ";
        if(shopView==ShopView.None && NearbyCounter()!=ShopView.None)hints+="　　C　"+ShopViewLabel(NearbyCounter())+"を見る";
        if(PortraitHint.Length>0)hints="E　話す　　"+PortraitHint;
        Letter(new Rect(22,bottom+6,hudW-44,48),hints,17,cream);
        string verb=Interaction();
        if(shopView==ShopView.None && !portraitOwner && verb.Length>0){
            var prompt=new Rect((hudW-540)/2,hudH*.60f,540,42);
            Block(prompt,ink);Letter(prompt,"E　"+verb,19,gold,false,TextAnchor.MiddleCenter);
        }
        if(bannerUntil>clock && banner.Length>0){
            var band=new Rect((hudW-800)/2,bottom-49,800,40);
            Block(band,ink);Letter(band,banner,17,cream,false,TextAnchor.MiddleCenter);
        }
        if(showFps)Letter(new Rect(22,75,180,28),Mathf.RoundToInt(fpsSmooth)+" FPS",14,cream);
    }
}
