using UnityEngine;

public sealed partial class KinseiSession
{
    int dawnBranch,dawnStep;
    float dawnPrintTime;
    GameObject dawnTicket;
    bool ticketActing, ticketAligned, ticketInTray, framingTicket;
    float ticketTime, alignmentTime;
    Vector3 printedCorner;
    static readonly Vector3 TicketCorner=new Vector3(-.031f,.0015f,.012f);
    static readonly Vector3 PressStand=new Vector3(-1.48f,0,-6.32f);
    static readonly Vector3 TrayStand=new Vector3(-2.65f,0,-18.56f);
    Vector3 TicketStand => dawnStep==0?PressStand:TrayStand;
    Vector3 TicketFacing => dawnStep==0?Vector3.forward:Vector3.right;
    Vector3 CarryPoint => player.root.TransformPoint(new Vector3(-.23f,1.13f,.25f));
    Vector3 TrayPaper => club.TicketTray.TransformPoint(new Vector3(-.100f,.0135f,-.060f));
    static float Stroke(float t,float start,float end)=>Mathf.SmoothStep(0,1,Mathf.InverseLerp(start,end,t));
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
        if(ticketActing)AdvanceTicket(dt);
        if(dawnBranch==2 && dawnStep==0 && !dawnTicket){
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
            dawnStep==1?"針音堂のカウンター左端で一番券を渡す":"針音堂の前売り窓口と金星の帳場を訪ねる";
    }

    // Each job has a real counter contact. Speaking elsewhere never advances the programme.
    string DawnJob()
    {
        if(ticketActing || AboveStreet || dawnStep>=2)return "";
        if(dawnBranch==1){
            if(dawnStep==0 && AtFinaleDesk(LotusDesk))return "澄子から「堺の朝」のリクエストを預かる";
            if(dawnStep==1 && AtFinaleDesk(RelayDesk))return "送出卓から「堺の朝」をかける";
        } else {
            if(dawnStep==0 && dawnPrintTime>=1.82f && CanStartTicket())return "座長から一番券を受け取る";
            if(dawnStep==1 && CanStartTicket())return "兵藤に一番券を渡す";
        }
        return "";
    }

    string DawnVerb()
    {
        if(ticketActing)return "";
        string job=DawnJob();
        if(job.Length>0)return job;
        if(dawnBranch==2 && AtFinaleDesk(KinseiBoxOffice.Counter))return "座長と話す";
        if(!StreetContact(out _,out string words))return "";
        int quote=words.IndexOf('「');
        return (quote>0?words.Substring(0,quote):"近くの人")+"と話す";
    }

    void DawnInteract()
    {
        if(ticketActing)return;
        string job=DawnJob();
        if(job.Length>0){
            if(dawnBranch==2){
                ticketActing=true;ticketAligned=false;ticketTime=alignmentTime=0;
                neighbours.ReceivingTicket=dawnStep==1;
                return;
            }
            dawnStep++;
            if(dawnBranch==1){
                SpeakAtCounter(dawnStep==1?0:2,dawnStep==1?"澄子「吹き手が待ってる。村瀬さんの卓から、うちの一番席にも頼むわ」":
                    "村瀬「送出入った。ロータスまで聞こえてるで」",5);
                if(dawnStep==2){
                    sound.SetMorningRequest(true);
                    SetPerformance(true);
                }
            }
            club.SetDawnProgramme(dawnBranch,dawnStep);
            sound.Cue("dial");Mark("dawn-work-"+dawnBranch+"-"+dawnStep);return;
        }
        if(dawnBranch==2 && AtFinaleDesk(KinseiBoxOffice.Counter)){
            Say(dawnStep==0?(dawnPrintTime<1.82f?"座長「今、刷ってるところや」":"座長「印字機の正面に回って、出てる端をつまんでや」"):dawnStep==1?"座長「兵藤の窓口に渡してや」":"座長「針音堂で前売りが始まったそうや」");return;
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

    bool CanStartTicket()
    {
        var p=player.Position;
        var delta=p-TicketStand;delta.y=0;
        return delta.sqrMagnitude<.65f*.65f &&
            (dawnStep==0?p.z<=-6.22f:p.x<=-2.57f);
    }

    void AdvanceTicket(float dt)
    {
        if(!ticketAligned){
            if(Input.GetKeyDown(KeyCode.S)){
                ticketActing=false;neighbours.ReceivingTicket=false;return;
            }
            var delta=TicketStand-player.Position;delta.y=0;
            if(delta.magnitude>.022f){
                if(!motor || alignmentTime>1.4f){
                    ticketActing=false;neighbours.ReceivingTicket=false;return;
                }
                motor.Move(Vector3.ClampMagnitude(delta,dt*1.45f));
                Motion(player,"walk",1.3f);
            }else Motion(player,"idle");
            var orientation=Quaternion.LookRotation(TicketFacing);
            player.root.rotation=Quaternion.RotateTowards(player.root.rotation,orientation,dt*340);
            alignmentTime+=dt;
            ticketAligned=delta.magnitude<=.022f && Quaternion.Angle(player.root.rotation,orientation)<1;
            return;
        }
        ticketTime+=dt;
    }

    void PoseTicketHands()
    {
        if(!ticketActing || !ticketAligned){
            if(dawnTicket)player.actor.TouchTicket(CarryPoint,1,true);
            return;
        }
        var paper=boxOffice.PrintedTicket;
        if(dawnStep==0){
            Vector3 corner=paper.TransformPoint(TicketCorner);
            Vector3 target=corner;
            float blend=Stroke(ticketTime,0,.55f);
            if(dawnTicket){
                var edge=printedCorner;
                var free=edge+Vector3.back*.15f+Vector3.up*.025f;
                target=Vector3.Lerp(Vector3.Lerp(edge,free,Stroke(ticketTime,.55f,.94f)),CarryPoint,Stroke(ticketTime,.94f,1.46f));
            }
            player.actor.TouchTicket(target,blend,true);
            if(ticketTime>=.55f && !dawnTicket){
                if(Vector3.Distance(player.actor.LeftWrist.TransformPoint(KinseiActor.TicketPinch),corner)>.035f){
                    ticketActing=false;return;
                }
                printedCorner=corner;dawnTicket=paper.gameObject;paper.SetParent(player.actor.LeftWrist,true);
            }
            if(ticketTime>=1.46f)FinishTicket(1);
            return;
        }
        Vector3 released=TrayPaper+TicketCorner;
        Vector3 above=released+Vector3.up*.105f;
        Vector3 place=Vector3.Lerp(Vector3.Lerp(CarryPoint,above,Stroke(ticketTime,0,.70f)),released,Stroke(ticketTime,.70f,1.12f));
        float release=Stroke(ticketTime,1.12f,1.49f);
        player.actor.TouchTicket(place+Vector3.up*(.12f*release),1-Stroke(ticketTime,1.42f,1.85f),true);
        if(!ticketInTray){
            // Rotate about the pinched corner so the printed face stays upward as the paper settles.
            Vector3 corner=paper.TransformPoint(TicketCorner);
            paper.rotation=Quaternion.Slerp(paper.rotation,club.TicketTray.rotation,Stroke(ticketTime,0,.70f));
            paper.position+=corner-paper.TransformPoint(TicketCorner);
            if(ticketTime>=1.12f){
                if(Vector3.Distance(paper.position,TrayPaper)>.040f){
                    ticketActing=false;neighbours.ReceivingTicket=false;return;
                }
                paper.SetParent(club.TicketTray,true);ticketInTray=true;dawnTicket=null;
            }
        }
        if(ticketInTray){
            paper.localRotation=Quaternion.identity;
            paper.localPosition=Vector3.Lerp(paper.localPosition,new Vector3(-.10f,.0135f,-.06f),Stroke(ticketTime,1.12f,1.32f));
            club.DrawTicketTray(Stroke(ticketTime,1.89f,2.50f));
            float lower=Stroke(ticketTime,1.65f,1.89f),lift=Stroke(ticketTime,2.50f,2.68f);
            Vector3 hover=Vector3.up*.078f-Vector3.forward*.030f;
            var pad=club.TrayFingerRest+hover*(1-lower+lift);
            float reach=Stroke(ticketTime,1.30f,1.65f)*(1-Stroke(ticketTime,2.68f,2.85f));
            neighbours.Owner(1).DrawTrayWithFingers(pad,reach);
        }
        if(ticketTime>=2.85f)FinishTicket(2);
    }

    void FinishTicket(int step)
    {
        ticketActing=false;dawnStep=step;neighbours.ReceivingTicket=false;
        club.SetDawnProgramme(2,step);sound.Cue("dial");Mark("dawn-work-2-"+step);
        if(step==1)Say("座長「金星専属の一番券や。針音堂に窓口を頼んだで」",5);
        else SpeakAtCounter(1,"兵藤「一番券、預かった。ほな前売りを始めよか」",5);
    }

    void ClearDawnTicket()
    {
        boxOffice.ReturnTicket();ticketActing=ticketAligned=ticketInTray=false;
        dawnTicket=null;
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
        string hints=ticketActing?(!ticketAligned?"仕事の位置につく　　S　やめる":
            dawnStep==0?"印字口から一番券を抜き取る":"受け皿に置いて兵藤に渡す"):RailHint();
        if(hints.Length==0)hints=shopView==ShopView.None?"WASD　町を歩く　　E　話す・仕事をする　　Esc　幕間・表題へ":
            ShopViewLabel(shopView)+"　　C　元の視点へ";
        if(!ticketActing && shopView==ShopView.None && NearbyCounter()!=ShopView.None)hints+="　　C　"+ShopViewLabel(NearbyCounter())+"を見る";
        if(!ticketActing && PortraitHint.Length>0)hints="E　話す　　"+PortraitHint;
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
