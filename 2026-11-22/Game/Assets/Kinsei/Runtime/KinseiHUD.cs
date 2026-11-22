using UnityEngine;

public sealed partial class KinseiSession
{
    Font hudSerif, hudSans;
    GUIStyle hudText;
    Texture2D hudFade, morningCover, ledgerCover, broadcastCover;
    bool showFps;
    int pauseSelection;
    float hudW, hudH;
    readonly Color ink = new(.065f,.040f,.049f,.94f);
    readonly Color brass = new(.79f,.61f,.36f);
    readonly Color rule = new(.76f,.60f,.38f,.48f);
    readonly System.Collections.Generic.List<Rect> drawnLabels = new();

    void InitStyle()
    {
        hallSigns=Resources.Load<Texture2D>("HallSigns");
        morningCover=Resources.Load<Texture2D>("Art/lotus-dawn");
        ledgerCover=Resources.Load<Texture2D>("Art/kinsei-ledger-dawn");
        broadcastCover=Resources.Load<Texture2D>("Art/lotus-listens");
        hudSerif=Font.CreateDynamicFontFromOSFont(new[]{"Yu Mincho","MS PMincho","Noto Serif CJK JP","serif"},48);
        hudSans=Font.CreateDynamicFontFromOSFont(new[]{"Yu Gothic","Meiryo","MS Gothic","Noto Sans CJK JP","Arial"},24);
        hudFade=new Texture2D(128,1,TextureFormat.RGBA32,false);
        for(int i=0;i<128;i++) hudFade.SetPixel(i,0,new Color(.044f,.017f,.028f,Mathf.SmoothStep(.99f,0,i/127f)));
        hudFade.wrapMode=TextureWrapMode.Clamp; hudFade.Apply();
        showFps=PlayerPrefs.GetInt("KinseiFps",0)!=0;
    }

    void Block(Rect rect,Color color)
    {
        if(Event.current.type!=EventType.Repaint)return;
        GUI.color=color; GUI.DrawTexture(rect,Texture2D.whiteTexture); GUI.color=Color.white;
    }
    void Letter(Rect rect,string value,int size,Color color,bool serif=false,TextAnchor align=TextAnchor.MiddleLeft,bool wrap=false)
    {
        if(Event.current.type!=EventType.Repaint)return;
        hudText.font=serif?hudSerif:hudSans; hudText.fontSize=size; hudText.alignment=align;
        hudText.normal.textColor=color; hudText.wordWrap=wrap;
        GUI.Label(rect,value,hudText);
    }
    bool Plate(Rect rect,string label,bool primary=false)
    {
        bool hover=rect.Contains(Event.current.mousePosition);
        Block(rect,hover?cream:primary?gold:ink);
        Block(new Rect(rect.x,rect.yMax-1,rect.width,1),brass);
        Letter(rect,label,17,hover||primary?ink:cream,false,TextAnchor.MiddleCenter);
        return GUI.Button(rect,GUIContent.none,GUIStyle.none);
    }
    void OnGUI()
    {
        if(hudText==null) hudText=new GUIStyle{clipping=TextClipping.Clip,richText=false};
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        if(scale<=0)return;
        hudW=Screen.width/scale; hudH=Screen.height/scale;
        var old=GUI.matrix;
        GUI.matrix=Matrix4x4.Scale(new Vector3(scale,scale,1));
        if(phase==Phase.Title || phase==Phase.Result) SalonCover();
        else if(paused) Intermission();
        else if(InDawn)DrawDawnHUD();
        else if(player!=null) LiveHUD();
        GUI.matrix=old;
    }
    void SalonCover()
    {
        bool title=phase==Phase.Title;
        Texture cover=!title && (outcome=="accord" || outcome=="cooperative") && morningCover?morningCover:keyArt;
        if(!title && (outcome=="pursuit" || outcome=="showdown" || outcome=="exclusive") && ledgerCover)cover=ledgerCover;
        if(!title && outcome=="stage-broadcast" && broadcastCover)cover=broadcastCover;
        if(cover!=null) GUI.DrawTexture(new Rect(0,0,hudW,hudH),cover,ScaleMode.ScaleAndCrop);
        GUI.DrawTexture(new Rect(0,0,hudW*.75f,hudH),hudFade);
        float x=hudW*.056f, w=Mathf.Min(525,hudW*.44f), y=hudH*.31f;
        Block(new Rect(x,37,37,2),gold);
        Letter(new Rect(x+49,22,450,32),"宵 待 町　／　大阪・昭和一〇一年",15,cream);
        Letter(new Rect(x,y-32,w,30),title?"キャバレー金星　開演":"キャバレー金星　終幕",18,gold);
        Letter(new Rect(x-4,y,w+18,100),title?"金星の一夜":endingTitle,title?77:Mathf.Min(57,Mathf.FloorToInt(w/Mathf.Max(1,endingTitle.Length))),cream,true);
        Block(new Rect(x,y+105,w,1),rule);
        Letter(new Rect(x,y+115,w,114),title?"真壁は六人を率いて金星に踏み込む。通用口で兄貴分を止めるか、中継卓から梶の弟を帰すか。組員を送り、真壁が現場で決める。":endingText+"\n"+settlementMessage,18,cream,true,TextAnchor.UpperLeft,true);
        if(pendingEnding!=null) Letter(new Rect(x,hudH-221,w,99),"保存先の空き容量や使用状況を確認し、Rで記帳してください。今終了すると、この帰還の売上と結末の記録を失います。",16,gold,false,TextAnchor.UpperLeft,true);
        else if(CampaignError.Length>0)Letter(new Rect(x,hudH-221,w,95),CampaignError,16,gold,false,TextAnchor.UpperLeft,true);
        else Letter(new Rect(x,hudH-212,w,84),CampaignSummary,16,gold,false,TextAnchor.UpperLeft,true);
        if(Plate(new Rect(x,hudH-113,246,52),title?"幕を開ける　　↵":"もう一度、金星へ　　↵",true)) StartNight();
        if(!title && Plate(new Rect(x+260,hudH-113,135,52),"表題に戻る")) ReturnToTitle();
        if(pendingEnding!=null) {
            if(Plate(new Rect(x,hudH-54,300,43),"帰還の記帳をやり直す　R")) RetrySettlement();
        } else if(FinaleUnlocked) {
            if(Plate(new Rect(x,hudH-54,300,43),"最終夜　四十軒の朝　F")) StartFinale();
        } else Letter(new Rect(x,hudH-55,w,29),"ENTER　開始",13,cream);
        if(!title && floorGuardReport.Length>0)
            Letter(new Rect(x,y-61,w,27),floorGuardReport,17,mint,true);
        DrawDawnDepartures();
    }
    void ReturnToTitle()
    {
        if(paused) TogglePause();
        sound.ListenAtBath(false,Vector3.zero);
        CloseWestDispute();
        ClearFloorAssignments();sound.StopFloorYields();
        if(InDawn)ClearDawn();else ResetRailRide();
        portraitOwner=null;neighbours.EndCounterLine(clock);
        ClearStageWitness();
        relayCam.enabled=false; phase=Phase.Title; command=false; SetCamera(0);
    }
    bool PauseButton(int index,Rect rect,string label,bool primary=false)
    {
        var e=Event.current;
        bool keyboard=pauseSelection==index && e.type==EventType.KeyDown &&
            (e.keyCode==KeyCode.Return || e.keyCode==KeyCode.Space || e.keyCode==KeyCode.KeypadEnter);
        if(keyboard)e.Use();
        if(index==pauseSelection) Block(new Rect(rect.x-7,rect.y,3,rect.height),gold);
        return Plate(rect,label,primary) || keyboard;
    }
    void Intermission()
    {
        var e=Event.current;
        if(e.type==EventType.KeyDown && (e.keyCode==KeyCode.UpArrow || e.keyCode==KeyCode.DownArrow)) {
            pauseSelection=(pauseSelection+(e.keyCode==KeyCode.UpArrow?5:1))%6;
            e.Use();
        }
        Block(new Rect(0,0,hudW,hudH),new Color(.035f,.018f,.031f,.72f));
        float width=464,x=(hudW-width)/2,y=(hudH-494)/2;
        Block(new Rect(x,y,width,494),ink); Block(new Rect(x,y,width,2),brass);
        float l=x+32,w=width-64;
        Letter(new Rect(l,y+16,w,30),"キャバレー金星",15,gold);
        Letter(new Rect(l,y+44,w,67),"幕　間",46,cream,true);
        if(PauseButton(0,new Rect(l,y+120,w,48),InDawn?"町歩きに戻る　　Esc":"舞台へ戻る　　Esc",true)) TogglePause();
        if(PauseButton(1,new Rect(l,y+180,w,44),"揺れ・点滅を抑える　　"+(reducedMotion?"入":"切"))) {
            reducedMotion=!reducedMotion; PlayerPrefs.SetInt("ReducedMotion",reducedMotion?1:0); PlayerPrefs.Save();
        }
        if(PauseButton(2,new Rect(l,y+230,w,44),"FPS 表示　　"+(showFps?"入":"切"))) {
            showFps=!showFps; PlayerPrefs.SetInt("KinseiFps",showFps?1:0); PlayerPrefs.Save();
        }
        if(PauseButton(3,new Rect(l,y+296,w,44),InDawn?"この朝を初めから歩く":"初めから遊ぶ")) {TogglePause();if(InDawn)OpenDawn(dawnBranch);else OpenNight(finale);}
        if(PauseButton(4,new Rect(l,y+346,w,44),"表題に戻る")) ReturnToTitle();
        if(PauseButton(5,new Rect(l,y+396,w,44),"ゲームを終了")) Application.Quit();
        if(showFps) Letter(new Rect(l,y+448,w,29),Mathf.RoundToInt(fpsSmooth)+" FPS（中断直前）",14,gold);
    }

    string Objective()
    {
        if(WestNearby && westSeo!=null)return WestObjective();
        if(finale)return FinaleObjective();
        switch(phase) {
            case Phase.Arrival:return "金星へ入る。向かいの三店や西の運河橋にも寄れる";
            case Phase.Floor:return held?"梶の連れは待機中。弟と用心棒を制圧せよ":"弟と用心棒を制圧せよ。辰は二階の梶の席へ";
            case Phase.Choice:return escorted?"弟をホール左手の中継鏡へ連れて行く":escapeTime>0?"弟に肩を貸すか、舞台袖の兄貴分を追う":"弟に肩を貸し、二階の梶に顔を見せる";
            case Phase.Chase:return "舞台袖で兄貴分との決着をつける";
            case Phase.Showdown:return StageBroadcastObjective();
            case Phase.Mirror:return "卓間中継鏡で、梶に弟の顔を見せる";
            default:return "梶と弟が店を出るのを見届ける";
        }
    }
    string DutyName(Person p)
    {
        int guest=WestEscortIndex(p);if(guest>=0)return guest==0?"文子の迎え":"喜一の迎え";
        if(p.hp<=0)return "行動不能";
        if(p.duty==Duty.Designated && p.assignedGuard!=null)return GuardName(p.assignedGuard)+"を担当";
        if(StageActive && p==stageWitness)return "立会中";
        if(StageActive && p==stageDeskRunner)return StageDeskReady?"実況卓・接続済":"実況卓へ";
        switch(p.duty) {
            case Duty.Backstage:return AtBackstagePost(p)?"札を渡す":"楽屋口へ";
            case Duty.Go:return "移動"; case Duty.Guard:return "持ち場";
            case Duty.FinalePost:return finaleStep==FinaleStep.Choose?"交換卓":"興行の持ち場";
            case Duty.BoxOffice:return "帳場へ";
            case Duty.StageWitness:return StageWitnessReady?"立会中":"舞台袖へ";
            case Duty.Rest:return "休息"; case Duty.Attend:return held?"交渉中":"梶の席へ";
            case Duty.HallDoor:return "通用口";
            case Duty.HallRelay:return "中継卓";
            default:return "随行";
        }
    }
    void LiveHUD()
    {
        pauseSelection=0;
        if(HallFrontsVisible){DrawHallBattle();return;}
        if(!inspectingStageLevel){
            WorldMarks();
            DrawAddresses();
            DrawBackstageMark();
        }
        DrawStageStatus();
        float pad=22;
        Block(new Rect(0,0,hudW,74),ink);
        Block(new Rect(0,73,hudW,1),rule);
        Letter(new Rect(pad,4,150,65),"金　星",35,gold,true);
        Block(new Rect(151,17,1,39),rule);
        Letter(new Rect(171,4,490,23),"今夜の目的",13,brass);
        Letter(new Rect(171,25,hudW-493,42),Objective(),21,cream,true);
        if(!AboveStreet && phase!=Phase.Mirror && (!StageActive || (!StageSpeaking && stageBeat!=StageBeat.Settled)) && !OnAir && Plate(new Rect(hudW-286,14,193,45),command?"現場に戻る　 Tab":"指揮に切替　 Tab")) ToggleCommand();
        if(Plate(new Rect(hudW-81,14,59,45),"幕間"))TogglePause();
        float bottom=command?hudH-CommandPanelHeight:hudH-66;
        if(bannerUntil>clock && banner.Length>0) {
            float width=Mathf.Min(hudW-80,Mathf.Max(300,banner.Length*19+42));
            Rect box=new Rect((hudW-width)/2,shopView==ShopView.None?bottom-55:84,width,39);
            Block(box,ink); Block(new Rect(box.x,box.y,3,box.height),gold);
            Letter(box,banner,18,cream,false,TextAnchor.MiddleCenter);
        }
        if(command) CrewConsole(bottom);
        else {
            Block(new Rect(0,bottom,hudW,66),ink);
            Letter(new Rect(pad,bottom+4,165,38),"真壁　"+Mathf.CeilToInt(player.hp),24,cream,true);
            Meter(new Rect(pad,bottom+47,134,4),player.hp,player.hp<28?red:gold);
            string hints=OnAir?"共同送像所　生中継":finale?"WASD　移動　　E　調べる・渡す　　Tab　組員を指揮":phase==Phase.Arrival?"WASD　移動　　E　話す　　通りの西から ロータス・針音堂・送像所":
                phase==Phase.Mirror?"卓間中継　接続中":
                StageActive?(StageSpeaking?"町内中継":"WASD　移動　　白い輪で F　返し　　Tab　実況係の指揮"):
                "WASD　移動　　右ドラッグ　視点　　左クリック・Space　射撃　　Q　注視　　F　打撃";
            if(!finale && phase==Phase.Arrival && player.Position.x< -9.18f && player.Position.z> -6f)
                hints=backstageTravel>=1?"舞台脇へ　引戸を通ってホールに入る":
                    pullingBackstage?"真壁が引戸を開けている":
                    BackstageRunner==null?"楽屋口　Tab で指揮に入り、組員に B で通し札を頼む":
                    AtBackstagePost(BackstageRunner)?"楽屋口　引戸の取手に近づいて E":"楽屋口　組員が通し札を取りに向かっている";
            if(phase==Phase.Floor && guards.Exists(HasGuardOrder))
                hints="Q　注視切替　　左クリック・Space　指名中の相手に合わせて撃つ";
            var counter=shopView==ShopView.None?NearbyCounter():shopView;
            if(counter!=ShopView.None)hints=shopView==ShopView.None?"C　"+ShopViewLabel(counter)+"を見る　　Tab　組員を指揮":ShopViewLabel(counter)+"　　C　元の視点へ　　Tab　組員を指揮";
            string railHint=RailHint();if(railHint.Length>0)hints=railHint;
            if(WestNearby && westSeo!=null)hints=westDuel?"WASD　かわす　　F　返す　　Tab　組員を指揮":
                "WASD　移動　　右ドラッグ　視点　　Tab　組員を指揮";
            if(PortraitHint.Length>0)hints="E　話す　　"+PortraitHint;
            Letter(new Rect(185,bottom+6,hudW-207,50),GuardViewHint(hints),17,cream);
            string interact=Interaction();
            if(interact.Length>0 && shopView==ShopView.None && !portraitOwner && yieldingPortrait==null){
                float promptWidth=Mathf.Min(hudW-48,Mathf.Max(300,(interact.Length+3)*20+36));
                Rect prompt=new Rect((hudW-promptWidth)*.5f,hudH*.60f,promptWidth,42);Block(prompt,ink);
                Letter(prompt,"E　　"+interact,19,gold,false,TextAnchor.MiddleCenter);
            }
        }
        if(phase==Phase.Choice && escapeTime>0) {
            Rect timer=new Rect(hudW-182,85,160,34);Block(timer,ink);
            Letter(timer,"逃走まで　"+Mathf.CeilToInt(escapeTime)+" 秒",16,gold,false,TextAnchor.MiddleCenter);
        }
        if(showFps) Letter(new Rect(pad,78,90,28),Mathf.RoundToInt(fpsSmooth)+" FPS",14,cream);
        if(!StageActive && (phase==Phase.Arrival || command) && shopView==ShopView.None) {
            Rect ledgerPlate=new Rect(pad,showFps?112:86,510,29);
            Block(ledgerPlate,ink);Letter(new Rect(ledgerPlate.x+9,ledgerPlate.y,ledgerPlate.width-12,29),finale?"最終夜　四十軒の朝":NightSummary,14,gold);
        }
        if(!reducedMotion && hitFlash>clock) Block(new Rect(0,74,hudW,4),red);
        if(!command && (phase==Phase.Floor || phase==Phase.Chase)){
            float cx=hudW*.5f,cy=hudH*.51f;
            var c=lastHit>clock?red:cream;
            Block(new Rect(cx-9,cy,6,2),c);Block(new Rect(cx+4,cy,6,2),c);
            Block(new Rect(cx,cy-8,2,5),c);Block(new Rect(cx,cy+4,2,5),c);
        }
    }
    string GuardViewHint(string fallback)
    {
        if(yieldingPortrait!=null)return GuardName(yieldingPortrait)+"　　Z を離して真壁に戻る";
        var nearby=NearbyYieldingGuard();
        return nearby==null?fallback:"Z 長押し　"+GuardName(nearby)+"を見る　　Tab　組員を指揮";
    }
    void Meter(Rect rect,float value,Color color)
    {
        Block(rect,rule);rect.width*=Mathf.Clamp01(value/100f);Block(rect,color);
    }
    void CrewConsole(float top)
    {
        Block(new Rect(0,top,hudW,hudH-top),ink);
        Block(new Rect(0,top,hudW,1),brass);
        float left=22,w=(hudW-44)/6;
        for(int i=0;i<crew.Count;i++) {
            var p=crew[i];Rect rect=new Rect(left+i*w,top+7,w-5,70);
            bool active=IsMemberSelected(i);
            if(active || rect.Contains(Event.current.mousePosition))Block(rect,new Color(.29f,.21f,.15f));
            var tint=active?gold:cream;
            Letter(new Rect(rect.x+9,rect.y+1,24,33),(i+1).ToString(),14,cream);
            Letter(new Rect(rect.x+34,rect.y,rect.width-76,36),p.name,23,tint,true);
            bool first=(squads[0] & (1<<i))!=0,second=(squads[1] & (1<<i))!=0;
            if(first || second)Letter(new Rect(rect.xMax-52,rect.y+5,46,25),first?(second?"一・二":"一班"):"二班",15,cream,false,TextAnchor.MiddleRight);
            Letter(new Rect(rect.x+10,rect.y+35,rect.width-20,22),DutyName(p)+"　体力 "+Mathf.CeilToInt(p.hp),14,cream);
            Meter(new Rect(rect.x+10,rect.y+61,rect.width-20,3),100*p.hp/p.maxHp,active?gold:mint);
            if(GUI.Button(rect,GUIContent.none,GUIStyle.none))SelectMember(i,Event.current.shift);
        }
        if(StageActive){
            Letter(new Rect(22,top+81,hudW-44,29),stageDeskRunner==null?"立会人は舞台袖へ。別の組員を一人選んで実況卓に送る":"C を押している間は、実況卓の手元を見る",17,cream);
            if(Plate(new Rect(22,top+118,236,48),stageDeskRunner!=null && IsMemberSelected(crew.IndexOf(stageDeskRunner))?"実況係を取り消す　E":"実況卓へ　E"))OrderStageDesk();
            if(Plate(new Rect(273,top+118,218,48),"舞台に戻る　Tab"))ToggleCommand();
        }else DrawSquadOrders(top);

    }
    void WorldMarks()
    {
        if(Event.current.type!=EventType.Repaint || cam==null || phase==Phase.Mirror || (StageActive && !command) || OnAir || shopView!=ShopView.None)return;
        drawnLabels.Clear();
        guardTags[0]=guardTags[1]=default;
        foreach(var p in everyone) {
            if(p.retired || (p.hp<=0 && !(p==brother && phase==Phase.Choice)))continue;
            int index=crew.IndexOf(p);
            bool ally=index>=0 || p==player;
            if(!command && (p==player || (ally && p!=crew[0] && p!=stageWitness)))continue;
            if(!command && (p.Position-player.Position).sqrMagnitude>16*16)continue;
            Vector3 head=p.Position+Vector3.up*1.96f;
            var screen=cam.WorldToViewportPoint(head);
            if(screen.z<=0 || screen.x<.04f || screen.x>.96f || screen.y<.25f || screen.y>.85f)continue;
            if(!command && Physics.Linecast(cam.transform.position,head,out var hit,~0,QueryTriggerInteraction.Ignore)
                && hit.collider!=motor && !hit.transform.IsChildOf(p.root))continue;
            bool chosenCrew=command && IsMemberSelected(index);
            bool inFocus=Mathf.Abs(screen.x-.5f)<.12f && Mathf.Abs(screen.y-.52f)<.21f;
            if(!command && upstairs.Contains(p) && !inFocus)continue;
            bool named=IsHallGuard(p) && HasGuardOrder(p);
            bool westContact=p==westSeo || p==westGuests[0] || p==westGuests[1];
            bool label=(command && WestNearby && westContact) || (IsHallGuard(p) && (command || named || p.floorYielded)) || chosenCrew || (!command && (inFocus || p==brother || p==stageWitness || (p==boss && phase>=Phase.Choice) || (p==crew[0] && held)));
            Color tint=ally || p==westGuests[0] || p==westGuests[1]?mint:(p==elder || (p==brother && phase==Phase.Choice) || (p==boss && phase!=Phase.Chase))?gold:red;
            float x=screen.x*hudW,y=(1-screen.y)*hudH;
            if(label) {
                string name=p.name;
                if(command && westContact)name=p==westSeo?"瀬尾":p==westGuests[0]?"文子":"喜一";
                if(IsHallGuard(p)){
                    if(p.floorYielded)name=GuardName(p)+"　降参";
                    else if(named)name=GuardName(p)+(p.flinchUntil>clock?"　ひるみ":"　指名中");
                    else if(command)name=GuardName(p);
                }
                float width=Mathf.Max(45,name.Length*14+24);
                Rect tag=new Rect(x-width/2,y-23,width,22);
                bool displaced=false;
                for(int row=0;row<drawnLabels.Count;row++) {
                    bool overlap=false;
                    foreach(var previous in drawnLabels)if(previous.Overlaps(tag)){overlap=true;break;}
                    if(!overlap)break;
                    tag.y-=25;displaced=true;
                }
                if(tag.y<78)continue;
                drawnLabels.Add(tag);
                if(command && IsHallGuard(p))guardTags[guards.IndexOf(p)]=tag;
                if(displaced)Block(new Rect(x,tag.yMax+2,1,y-tag.yMax-3),tint);
                Block(tag,ink);Letter(tag,name,13,tint,false,TextAnchor.MiddleCenter);
                Meter(new Rect(tag.x,tag.yMax,width,2),100*p.hp/p.maxHp,tint);
            } else {
                Rect mark=new Rect(x-9,y-10,18,18);Block(mark,ink);
                Letter(mark,index>=0?(index+1).ToString():p==player?"主":"◆",13,tint,false,TextAnchor.MiddleCenter);
            }
        }
    }
}

