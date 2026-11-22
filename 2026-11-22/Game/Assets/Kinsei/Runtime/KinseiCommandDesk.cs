using UnityEngine;

public sealed partial class KinseiSession
{
    const float CommandDockHeight=176f;
    static readonly Color DeskPaper=new(.88f,.92f,.94f);
    static readonly Color DeskInk=new(.075f,.12f,.16f);
    static readonly Color DeskMuted=new(.30f,.38f,.43f);
    static readonly Color DeskAmber=new(.97f,.66f,.22f);
    static readonly Color DeskAlly=new(.16f,.65f,.62f);
    Texture2D crewPortraits;

    static readonly Color DeskPanel=new(.055f,.085f,.115f);
    static readonly Color DeskSurface=new(.12f,.17f,.21f);
    static readonly Color DeskEdge=new(.26f,.34f,.39f);
    static readonly Color DeskQuiet=new(.65f,.73f,.77f);

    static string DeskKey(ref string title)
    {
        int split=Mathf.Max(title.LastIndexOf(' '),title.LastIndexOf('　'));
        if(split<0)return "";
        string key=title.Substring(split+1);
        if(key!="Tab" && key!="Esc" && key!="H" && key!="E" && key!="F" && key!="G" && key!="R" && key!="T" && key!="V" && key!="B" && key!="X" && key!="Z" && !(key.Length==2 && key[0]=='F'))return "";
        title=title.Substring(0,split).TrimEnd();return key;
    }
    void DeskKeycap(Rect rect,string key,Color tint)
    {
        Block(rect,DeskPanel);Block(new Rect(rect.x,rect.yMax-1,rect.width,1),DeskEdge);
        Letter(rect,key,11,tint,false,TextAnchor.MiddleCenter);
    }
    bool DeskButton(Rect rect,string title,string detail="",bool selected=false,bool available=true)
    {
        string key=DeskKey(ref title);
        bool hover=available && rect.Contains(Event.current.mousePosition);
        Block(rect,selected?new Color(.29f,.23f,.14f):hover?new Color(.20f,.27f,.31f):DeskSurface);
        Block(new Rect(rect.x,rect.yMax-1,rect.width,1),selected?DeskAmber:DeskEdge);
        Color text=available?DeskPaper:DeskQuiet;
        float keyWidth=key.Length>2?31:23;
        if(key.Length>0)DeskKeycap(new Rect(rect.xMax-keyWidth-7,rect.center.y-10,keyWidth,20),key,text);
        Letter(new Rect(rect.x+10,rect.y+2,rect.width-20-(key.Length>0?keyWidth+6:0),detail.Length>0?26:rect.height-4),title,14,text);
        if(detail.Length>0)Letter(new Rect(rect.x+10,rect.y+28,rect.width-20,rect.height-28),detail,12,DeskQuiet);
        bool click=GUI.Button(rect,GUIContent.none,GUIStyle.none);
        return available && click;
    }
    void DeskGlyph(Rect rect,int kind,Color tint)
    {
        Vector2 At(float x,float y)=>new Vector2(rect.x+x*rect.width,rect.y+y*rect.height);
        void Line(float ax,float ay,float bx,float by)=>HallStroke(At(ax,ay),At(bx,by),tint,2);
        if(kind==0){ // Open doorway and the route through it.
            Line(.18f,.85f,.18f,.12f);Line(.18f,.12f,.72f,.12f);Line(.72f,.12f,.72f,.85f);
            Line(.04f,.55f,.95f,.55f);Line(.76f,.36f,.95f,.55f);Line(.76f,.74f,.95f,.55f);
        }else if(kind==1){ // A cathode-ray display with its desk.
            Line(.12f,.12f,.88f,.12f);Line(.88f,.12f,.88f,.65f);Line(.88f,.65f,.12f,.65f);Line(.12f,.65f,.12f,.12f);
            Line(.5f,.65f,.5f,.86f);Line(.28f,.86f,.72f,.86f);Line(.26f,.38f,.43f,.50f);Line(.43f,.50f,.72f,.27f);
        }else if(kind==2){ // Two chevrons: return to the leader.
            Line(.12f,.32f,.42f,.5f);Line(.42f,.5f,.12f,.68f);Line(.52f,.32f,.82f,.5f);Line(.82f,.5f,.52f,.68f);
        }else if(kind==3){ // A seat: leave the action and rest.
            Line(.22f,.12f,.22f,.60f);Line(.22f,.60f,.82f,.60f);Line(.30f,.60f,.30f,.88f);Line(.74f,.60f,.74f,.88f);
        }else{ // Table and two seats: a named person's business.
            Line(.16f,.46f,.84f,.46f);Line(.28f,.46f,.28f,.86f);Line(.72f,.46f,.72f,.86f);
            Line(.08f,.20f,.30f,.20f);Line(.08f,.20f,.08f,.66f);Line(.70f,.20f,.92f,.20f);Line(.92f,.20f,.92f,.66f);
        }
    }
    bool DeskOrderTile(Rect rect,string title,int glyph,string detail="",bool available=true,bool deployed=false)
    {
        string key=DeskKey(ref title);
        bool hover=available && rect.Contains(Event.current.mousePosition);
        Block(rect,hover?new Color(.19f,.27f,.31f):DeskSurface);
        Color cue=deployed?DeskAlly:DeskPaper;
        Block(new Rect(rect.x,rect.y,rect.width,2),deployed?DeskAlly:DeskEdge);
        DeskGlyph(new Rect(rect.x+14,rect.y+12,29,29),glyph,available?cue:DeskQuiet);
        if(key.Length>0)DeskKeycap(new Rect(rect.xMax-32,rect.y+12,23,21),key,available?DeskPaper:DeskQuiet);
        Letter(new Rect(rect.x+14,rect.y+45,rect.width-28,23),title,18,available?DeskPaper:DeskQuiet,bold:true);
        if(detail.Length>0)Letter(new Rect(rect.x+51,rect.y+10,rect.width-91,33),detail,12,DeskQuiet,false,TextAnchor.MiddleLeft,true);
        bool click=GUI.Button(rect,GUIContent.none,GUIStyle.none);
        return click && available;
    }

    bool CommandDeskHits(Vector2 point,float w,float h) => CommandDeskCovers(new Rect(point.x,point.y,.1f,.1f),w,h);

    bool CommandDeskCovers(Rect area,float w,float h)
    {
        if(area.yMax>h-CommandDockHeight || (DistrictMapVisible && DistrictMapRect(w,h).Overlaps(area)))return true;
        if(new Rect(16,14,Mathf.Min(438,w-350),84).Overlaps(area))return true;
        if(bannerUntil>clock && banner.Length>0 && new Rect(16,105,Mathf.Min(510,w-350),40).Overlaps(area))return true;
        if(new Rect(w-302,14,185,44).Overlaps(area) || new Rect(w-109,14,93,44).Overlaps(area))return true;
        if(!StageActive && stageWitness!=null && CanOrderStageWitness && shopView==ShopView.None && new Rect(w-344,108,328,54).Overlaps(area))return true;
        return phase==Phase.Choice && escapeTime>0 && new Rect(w-233,66,217,33).Overlaps(area);
    }

    void DrawCommandDesk()
    {
        if(!inspectingStageLevel)DrawTacticalMap();
        DrawDistrictMap();
        // Keep the objective persistent; spoken orders have their own small strip.
        Rect mission=new Rect(16,14,Mathf.Min(438,hudW-350),84);
        Block(mission,DeskPanel);
        Block(new Rect(mission.x,mission.y,3,mission.height),DeskEdge);
        Letter(new Rect(30,20,mission.width-132,23),finale?"最終夜 / 四十軒の朝":StageActive?"金星 / 舞台の指揮":HallFrontsVisible?"金星 / ホールの指揮":"宵待町 / 真壁組の指揮",12,DeskQuiet);
        Letter(new Rect(mission.xMax-106,20,94,20),"真壁 HP "+Mathf.CeilToInt(player.hp),12,DeskPaper,false,TextAnchor.MiddleRight);
        Meter(new Rect(mission.xMax-98,41,86,3),100*player.hp/player.maxHp,player.hp<28?red:DeskAlly);
        Letter(new Rect(30,44,mission.width-28,46),HallFrontsVisible?HallFieldObjective():Objective(),20,DeskPaper,false,TextAnchor.MiddleLeft,true,true);
        if(bannerUntil>clock && banner.Length>0){
            Rect voice=new Rect(16,105,Mathf.Min(510,hudW-350),40);
            Block(voice,DeskPanel);Letter(new Rect(27,voice.y+3,voice.width-22,34),banner,14,Color.white,false,TextAnchor.MiddleLeft,true);
        }
        if(DeskButton(new Rect(hudW-302,14,185,44),"現場に戻る  Tab"))ToggleCommand();
        if(DeskButton(new Rect(hudW-109,14,93,44),"幕間  Esc"))TogglePause();
        if(phase==Phase.Choice && escapeTime>0){
            Rect timer=new Rect(hudW-233,66,217,33);Block(timer,DeskPanel);
            Letter(timer,"逃走まで "+Mathf.CeilToInt(escapeTime)+" 秒",16,DeskAmber,false,TextAnchor.MiddleCenter);
        }
        float top=hudH-CommandDockHeight;
        Block(new Rect(0,top,hudW,CommandDockHeight),DeskPanel);
        Block(new Rect(0,top,hudW,2),DeskEdge);
        float rosterWidth=Mathf.Min(570,hudW*.52f);
        DrawDeskRoster(new Rect(14,top+10,rosterWidth-24,113));
        float groupWidth=(rosterWidth-30)/4;
        if(!StageActive)for(int i=0;i<2;i++){
            int slot=i;
            float x=14+i*groupWidth*2;
            if(DeskButton(new Rect(x,top+128,groupWidth-5,36),SquadLabel(i)+" "+CountMembers(LivingMembers(squads[i]))+"人  F"+(i+1)))RecallSquad(slot);
            if(DeskButton(new Rect(x+groupWidth,top+128,groupWidth-5,36),"登録  F"+(i+3)))SaveSquad(slot);
        }
        if(StageActive){
            string desk=stageDeskRunner==null?"実況係 未配置":stageDeskRunner.name+(StageDeskReady?" 実況 接続済":stageDeskAnnounced?" 送出音量を調整中":" 実況卓へ移動中");
            Letter(new Rect(14,top+128,rosterWidth-28,26),desk,14,DeskPaper);
            float progress=stageDeskRunner==null?0:StageDeskReady?100:stageDeskAnnounced?100*Mathf.Clamp01((clock-stageLevelStarted)/StageLevelSet):0;
            Meter(new Rect(14,top+158,rosterWidth-32,3),progress,DeskAlly);
        }else if(stageWitness!=null && CanOrderStageWitness && shopView==ShopView.None){
            Rect note=new Rect(hudW-344,108,328,54);Block(note,DeskPanel);
            Letter(new Rect(note.x+12,note.y+2,304,23),"舞台の立会 / "+stageWitness.name,14,DeskPaper);
            Letter(new Rect(note.x+12,note.y+25,304,25),StageWitnessReady?"立会人到着 / 階段前で E":"舞台袖へ移動中",13,DeskQuiet);
        }
        float right=rosterWidth+8, width=hudW-right-16;
        int mask=SelectedMembers,count=CountMembers(mask);
        string who=count==0?"組員を選んでください":count==1?crew[FirstMember(mask)].name+" に指示":count+" 人に指示";
        Letter(new Rect(right,top+7,width-124,26),who,18,Color.white,bold:true);
        if(!StageActive && DeskButton(new Rect(hudW-136,top+7,120,28),hallOtherOrders?"主な命令  H":"追加命令  H",selected:hallOtherOrders))hallOtherOrders=!hallOtherOrders;
        DrawDeskOrders(new Rect(right,top+40,width,100),count);
        Letter(new Rect(right,top+145,width,23),StageActive?"1–6 担当を選択 / E 実況卓へ / Tab 舞台に戻る":"左ドラッグで班選択　　Shift で追加　　右クリックで移動",12,DeskQuiet);
        if(showFps)Letter(new Rect(hudW-100,168,84,23),Mathf.RoundToInt(fpsSmooth)+" FPS",12,Color.white,false,TextAnchor.MiddleRight);
    }

    void DrawDeskRoster(Rect area)
    {
        if(!crewPortraits)crewPortraits=Resources.Load<Texture2D>("KinseiCrewPortraits");
        float cell=area.width/6;
        for(int i=0;i<crew.Count;i++){
            Person person=crew[i];bool selected=IsMemberSelected(i);
            Rect card=new Rect(area.x+i*cell,area.y,cell-5,area.height);
            Block(card,selected?new Color(.26f,.22f,.15f):DeskSurface);
            Block(new Rect(card.x,card.y,card.width,2),selected?DeskAmber:DeskEdge);
            Rect image=new Rect(card.x+3,card.y+3,card.width-6,60);
            Block(image,DeskInk);
            if(crewPortraits && Event.current.type==EventType.Repaint){
                GUI.color=person.hp>0?Color.white:new Color(.45f,.45f,.45f);
                GUI.DrawTextureWithTexCoords(image,crewPortraits,new Rect(i/6f,.16f,1/6f,.70f));GUI.color=Color.white;
            }
            Rect key=new Rect(card.x+4,card.y+4,19,20);Block(key,DeskInk);
            Letter(key,(i+1).ToString(),13,Color.white,false,TextAnchor.MiddleCenter);
            Letter(new Rect(card.x+6,card.y+63,card.width-32,22),person.name,17,DeskPaper,bold:true);
            Letter(new Rect(card.xMax-28,card.y+64,23,21),Mathf.CeilToInt(person.hp).ToString(),10,person.hp>0?DeskQuiet:red,false,TextAnchor.MiddleRight);
            Letter(new Rect(card.x+6,card.y+84,card.width-12,20),DutyName(person).Replace("実況卓・接続済","実況・接続"),11,DeskQuiet);
            Meter(new Rect(card.x+5,card.yMax-5,card.width-10,3),100*person.hp/person.maxHp,person.hp>0?DeskAlly:red);
            if(GUI.Button(card,GUIContent.none,GUIStyle.none))SelectHallMember(i,Event.current.shift);
        }
    }

    void DrawDeskOrders(Rect area,int count)
    {
        int selected=SelectedMembers;
        Person member=count==1?crew[FirstMember(selected)]:null;
        bool single=member!=null;
        if(StageActive){
            string reason=!single?"実況係を一人選ぶ":member==stageWitness?"立会人以外を選ぶ":member==stageDeskRunner?"担当を外して随行へ":member.duty==Duty.Attend || member.duty==Duty.Backstage || member.duty==Duty.BoxOffice?"別の仕事を先に解く":"舞台の中継を任せる";
            bool ready=single && member!=stageWitness && (member==stageDeskRunner || member.duty!=Duty.Attend && member.duty!=Duty.Backstage && member.duty!=Duty.BoxOffice) && !StageSpeaking && stageBeat!=StageBeat.Settled;
            float tileWidth=Mathf.Min(235,area.width*.48f);
            if(DeskOrderTile(new Rect(area.x,area.y,tileWidth,area.height),member!=null && member==stageDeskRunner?"実況取消  E":"実況卓  E",1,reason,ready))OrderStageDesk();
            Rect status=new Rect(area.x+tileWidth+10,area.y,area.width-tileWidth-10,area.height);
            Block(status,DeskSurface);
            Letter(new Rect(status.x+12,status.y+7,status.width-24,25),"兄貴分 HP "+Mathf.CeilToInt(bossHp),15,DeskPaper,bold:true);
            Meter(new Rect(status.x+12,status.y+36,status.width-24,3),bossHp,DeskAmber);
            string cue=stageBeat switch {
                StageBeat.Cue=>"合図 / 舞台灯の輪から離れる",StageBeat.Swing=>"大振り / 輪の外へ",
                StageBeat.Opening=>stageAnswered?"打撃が届いた / 次の合図を待つ":"隙 / 近づいて F",
                StageBeat.ToMicrophone=>"兄貴分がマイクへ",StageBeat.Testimony=>"町内中継 / 放送中",
                StageBeat.Settled=>player.hp<=0?"決着 / 真壁が倒れた":"決着 / 兄貴分が倒れた",
                _=>"構え / 次の合図を待つ"
            };
            Letter(new Rect(status.x+12,status.y+46,status.width-24,47),cue,14,DeskPaper,false,TextAnchor.MiddleLeft,true);
            return;
        }
        bool attend=WestCanOrder?count>=1 && count<=2:finale?single && finaleStep!=FinaleStep.Collect && finaleStep!=FinaleStep.Choose:single && member==crew[0] && !accord;
        string attendLabel=WestCanOrder?WestOrderLabel:finale?FinaleOrderLabel:"梶の席へ  E";
        string attendReason=WestCanOrder?"迎えは一人か二人":finale?finaleStep==FinaleStep.Collect?"原盤は真壁が運ぶ":finaleStep==FinaleStep.Choose?"交換卓で真壁が選ぶ":"担当を一人選ぶ":accord?"梶との話は成立済":"交渉は辰を一人選ぶ";
        bool box=single && !finale && !HouseClaimed && (phase==Phase.Arrival || phase==Phase.Floor || phase==Phase.Choice);
        const float gap=8;
        if(HallFrontsVisible && !hallOtherOrders){
            float w=(area.width-gap)/2;
            for(int slot=0;slot<2;slot++){
                Rect r=new Rect(area.x+slot*(w+gap),area.y,w,area.height);
                bool closed=HallFrontReady(1-slot);
                int team=HallTeam(slot,out int arrived);
                if(DeskOrderTile(r,HallSites[slot]+"へ派遣  "+HallKeys[slot],slot,HallBenefits[slot],!closed && count>0,team>0))AssignHallFront(slot);
                string members="";
                for(int i=0;i<crew.Count;i++)if(HallFrontMember(i)==slot)members+=(members.Length>0?"・":"")+crew[i].name;
                Letter(new Rect(r.x+14,r.y+68,r.width-28,14),members.Length>0?members:"未派遣",11,DeskQuiet);
                Letter(new Rect(r.x+14,r.y+81,r.width-28,14),HallFrontStatus(slot),11,DeskPaper);
                Meter(new Rect(r.x+14,r.yMax-5,r.width-28,3),HallFrontProgress(slot)*100,DeskAlly);
            }
            return;
        }
        float buttonWidth=(area.width-gap*2)/3;
        if(!hallOtherOrders){
            Duty primary=attend?Duty.Attend:count>1?Duty.Guard:box?Duty.BoxOffice:Duty.Guard;
            string label=primary==Duty.Attend?attendLabel:primary==Duty.BoxOffice?"帳場の伝票  T":"持ち場  G";
            string explanation=primary==Duty.Attend?attendReason:primary==Duty.BoxOffice?"入口の帳場で受け取る":"班でホールを守る";
            if(DeskOrderTile(new Rect(area.x,area.y,buttonWidth,area.height),label,4,explanation,count>0))Assign(primary);
            if(DeskOrderTile(new Rect(area.x+buttonWidth+gap,area.y,buttonWidth,area.height),"随行  F",2,"真壁についてくる",count>0))Assign(Duty.Follow);
            if(DeskOrderTile(new Rect(area.x+(buttonWidth+gap)*2,area.y,buttonWidth,area.height),"休息  R",3,"表へ下げる",count>0))Assign(Duty.Rest);
            return;
        }
        int index=0;
        int columns=HallFrontsVisible?4:3;
        float auxiliaryWidth=(area.width-gap*(columns-1))/columns;
        void Button(string label,System.Action action,string reason="",bool enabled=true){
            int n=index++;Rect r=new Rect(area.x+(n%columns)*(auxiliaryWidth+gap),area.y+(n/columns)*53,auxiliaryWidth,47);
            if(DeskButton(r,label,reason,available:count>0 && enabled))action();
        }
        Button(attendLabel,()=>Assign(Duty.Attend),attendReason,attend);
        Button("持ち場  G",()=>Assign(Duty.Guard),"班でホールを守る");
        Button("伝票  T",()=>Assign(Duty.BoxOffice),!single?"一人を選ぶ":HouseClaimed?"伝票は受取済":"入口の帳場へ",box);
        Button(single && member==stageWitness?"立会取消  V":"舞台立会  V",()=>Assign(Duty.StageWitness),!single?"一人を選ぶ":!CanOrderStageWitness?"今は立会を出せない":"舞台袖で見届ける",single && CanOrderStageWitness);
        Button(single && member.duty==Duty.Backstage?"札口取消  B":"楽屋口  B",()=>Assign(Duty.Backstage),!single?"一人を選ぶ":!CanOrderBackstage?"到着時の通し札任務":"札を預けて引戸へ",single && CanOrderBackstage);
        Button("随行  F",()=>Assign(Duty.Follow),"真壁についてくる");
        if(HallFrontsVisible)Button("休息  R",()=>Assign(Duty.Rest),"表へ下げる");
    }
}
