using UnityEngine;

public sealed partial class KinseiSession
{
    bool hallOtherOrders;
    Texture2D hallSigns;
    int lastHallMember=-1;
    float lastHallClick;
    float HallCommandHeight => hallOtherOrders ? CommandPanelHeight + 38 : 146;
    static readonly Color HallInk = new(.042f,.060f,.069f,.94f);
    static readonly Color HallIvory = new(.96f,.93f,.84f);
    static readonly Color DoorCue = new(1f,.71f,.37f);
    static readonly Color RelayCue = new(.49f,.86f,.85f);
    static readonly string[] HallSites = {"通用口", "中継卓"};
    static readonly string[] HallBenefits = {"兄貴分の逃走を遅らせる", "弟を中継卓へ呼ぶ"};
    static readonly string[] HallKeys = {"X", "Z"};
    static Color FrontColor(int slot) => slot == 0 ? DoorCue : RelayCue;

    void SiteSign(Rect rect,int slot,Color color)
    {
        if(Event.current.type!=EventType.Repaint || !hallSigns)return;
        GUI.color=color;
        GUI.DrawTextureWithTexCoords(rect,hallSigns,new Rect(slot==1?0:.5f,0,.5f,1));
        GUI.color=Color.white;
    }

    void SelectHallMember(int i,bool extend)
    {
        SelectMember(i,extend);
        float now=Time.unscaledTime;
        if(!extend && crew[i].hp>0 && lastHallMember==i && now-lastHallClick<.4f){
            var position=crew[i].Position;
            mapOffset=new Vector2(Mathf.Clamp(position.x,-43,19),Mathf.Clamp(position.z+1.05f,-20.5f,4.5f));
            lastHallMember=-1;
            Mark("hall-focus-"+i);
        }else lastHallMember=extend?-1:i;
        lastHallClick=now;
    }

    void DrawHallBattle()
    {
        if(command) DrawHallRoutes();
        WorldMarks();
        if(command){DrawHallMapPin(0);DrawHallMapPin(1);}
        float w=hudW;
        Block(new Rect(0,0,w,60),HallInk);
        Block(new Rect(0,59,w,1),rule);
        Letter(new Rect(18,3,105,22),"キャバレー金星",12,brass);
        Letter(new Rect(18,23,120,32),command?"組員指揮":"真壁・現場",21,HallIvory,true);
        string objective=phase==Phase.Choice ? Objective() : "組員を送り、真壁が一方を援護する";
        if(HallFrontReady(0)){
            if(phase==Phase.Choice)objective="通用口へ向かい、兄貴分を追う";
            else objective=DoorInterception()?"通用口で組員が足止め中。弟と用心棒を退かせる":"逃走まで十八秒稼いだ。弟と用心棒を退かせる";
        }
        else if(HallFrontReady(1)){
            if(HallRelayCrew()==null)objective="中継卓に組員を送り直す";
            else objective=phase==Phase.Choice?"中継卓へ行き、組員に合図する":"弟が中継卓へ向かう。残る用心棒を退かせる";
        }
        Letter(new Rect(153,10,w-426,40),objective,20,HallIvory,true);
        if(Plate(new Rect(w-256,6,174,45),command?"現場へ　 Tab":"組員を指揮　 Tab"))ToggleCommand();
        if(Plate(new Rect(w-73,6,61,45),"幕間"))TogglePause();

        float top=hudH-(command?HallCommandHeight:43);
        if(command) HallOrders(top);
        else HallFieldHUD(top);
        float messageY=command?top-39:70;
        if(bannerUntil>clock && banner.Length>0){
            float width=Mathf.Min(w-(command?54:408),Mathf.Max(290,banner.Length*17+32));
            Rect box=new Rect((w-width)*.5f,messageY,width,32);
            Block(box,HallInk);Block(new Rect(box.x,box.y,3,box.height),brass);
            Letter(box,banner,16,HallIvory,false,TextAnchor.MiddleCenter);
        }
        if(phase==Phase.Choice && escapeTime>0){
            Rect timer=new Rect(w-179,71,162,32);Block(timer,HallInk);
            Letter(timer,"逃走まで　"+Mathf.CeilToInt(escapeTime)+" 秒",16,DoorCue,false,TextAnchor.MiddleCenter);
        }
        if(showFps)Letter(new Rect(w-115,109,95,24),Mathf.RoundToInt(fpsSmooth)+" FPS",13,HallIvory,false,TextAnchor.MiddleRight);
        if(!reducedMotion && hitFlash>clock)Block(new Rect(0,60,w,3),red);
    }

    void HallOrders(float top)
    {
        Block(new Rect(0,top,hudW,hudH-top),HallInk);
        Block(new Rect(0,top,hudW,1),brass);
        float width=(hudW-32)/6;
        for(int i=0;i<crew.Count;i++){
            Person p=crew[i]; bool selected=IsMemberSelected(i);
            Rect card=new Rect(16+i*width,top+6,width-4,45);
            Color tint=selected?gold:HallIvory;
            if(selected){
                Block(card,new Color(.27f,.22f,.17f));
                Block(new Rect(card.x,card.y,card.width,2),gold);
                Block(new Rect(card.x,card.y,3,card.height),gold);
            }
            Letter(new Rect(card.x+6,card.y,18,34),(i+1).ToString(),13,tint);
            Letter(new Rect(card.x+26,card.y,53,34),p.name,20,tint,true);
            int post=HallFrontMember(i);
            if(post<0)Letter(new Rect(card.x+78,card.y,card.width-82,34),DutyName(p),13,HallIvory);
            else SiteSign(new Rect(card.xMax-43,card.y+3,30,30),post,FrontColor(post));
            Meter(new Rect(card.x+6,card.yMax-5,card.width-12,3),100*p.hp/p.maxHp,selected?gold:mint);
            if(GUI.Button(card,GUIContent.none,GUIStyle.none))SelectHallMember(i,Event.current.shift);
        }
        if(hallOtherOrders){
            DrawSquadOrders(top-27);
            if(Plate(new Rect(16,hudH-47,236,42),"抗争の持ち場に戻る　H"))hallOtherOrders=false;
            return;
        }
        int count=CountMembers(SelectedMembers);
        float left=16, y=top+57;
        string who=count==1?crew[FirstMember(SelectedMembers)].name:count+"人";
        Letter(new Rect(left,y,141,37),count>0?who+"に指示":"組員を選ぶ",18,gold,true);
        Letter(new Rect(left,y+36,150,32),"Shift で複数選択",12,HallIvory);
        float cardW=(hudW-385)*.5f;
        for(int slot=0;slot<2;slot++){
            Rect card=new Rect(171+(1-slot)*(cardW+9),y,cardW,73);
            DrawHallCard(card,slot,true);
        }
        Rect other=new Rect(hudW-181,y,165,73);
        if(Plate(other,"ほかの指示　H"))hallOtherOrders=true;
    }

    void DrawHallCard(Rect card,int slot,bool button)
    {
        bool closed=HallFrontReady(1-slot);
        Color tint=closed?new Color(.55f,.56f,.56f):FrontColor(slot);
        bool hover=button && !closed && card.Contains(Event.current.mousePosition);
        Block(card,hover?new Color(.18f,.21f,.21f,.97f):HallInk);
        Block(new Rect(card.x,card.y,3,card.height),tint);
        float iconSize=button?44:30;
        SiteSign(new Rect(card.x+9,card.y+(button?8:3),iconSize,iconSize),slot,closed?tint:HallIvory);
        float x=card.x+18+iconSize;
        Letter(new Rect(x,card.y+2,94,31),HallSites[slot],20,HallIvory,true);
        Letter(new Rect(x+76,card.y+3,card.xMax-x-(button?119:83),27),HallFrontStatus(slot),13,closed?tint:HallIvory,false,TextAnchor.MiddleRight);
        if(button){
            if(!closed){
                Rect key=new Rect(card.xMax-34,card.y+5,26,25);Block(key,new Color(.23f,.24f,.23f));
                Letter(key,HallKeys[slot],15,HallIvory,false,TextAnchor.MiddleCenter);
                Letter(new Rect(x,card.y+32,card.xMax-x-12,23),HallBenefits[slot],14,HallIvory);
            }
        }
        if(!closed){
            Rect track=new Rect(card.x+10,card.yMax-8,card.width-20,3);
            Meter(track,100*HallFrontProgress(slot),tint);
            if(HallFrontReady(slot)){
                var tick=new Vector2(card.x+11,card.y+9);
                HallStroke(tick,tick+new Vector2(3,3),tint,2);
                HallStroke(tick+new Vector2(3,3),tick+new Vector2(10,-4),tint,2);
            }else{
                int team=HallTeam(slot,out int arrived);
                if(team>0){
                    float marker=track.x+CrewPreparationLimit*track.width;
                    Block(new Rect(marker,track.y-3,2,9),HallIvory);
                    if(arrived==0){
                        Vector2 arrow=new Vector2(track.x+Mathf.Max(5,track.width*HallFrontProgress(slot)),track.y+1);
                        HallStroke(arrow,arrow+new Vector2(-4,-3),HallIvory,2);
                        HallStroke(arrow,arrow+new Vector2(-4,3),HallIvory,2);
                    }
                }
            }
        }
        if(button && !closed && GUI.Button(card,GUIContent.none,GUIStyle.none))AssignHallFront(slot);
    }

    void HallFieldHUD(float top)
    {
        for(int slot=0;slot<2;slot++){
            if(HallFrontReady(1-slot))continue;
            Rect row=new Rect(slot==1?16:hudW-288,top-54,272,45);
            DrawHallCard(row,slot,false);
            Vector3 spot=HallFrontPosition(slot);
            Vector3 direction=cam.transform.InverseTransformPoint(spot+Vector3.up*.8f);
            Rect compass=new Rect(slot==1?row.xMax+3:row.x-57,row.y,54,row.height);Block(compass,HallInk);
            Vector2 heading=new Vector2(direction.x,-direction.z).normalized;
            Vector2 centre=new Vector2(compass.center.x,compass.y+12);
            Vector2 tip=centre+heading*6, wing=new Vector2(-heading.y,heading.x)*4;
            HallStroke(tip,centre-heading*2+wing,HallIvory,2);
            HallStroke(tip,centre-heading*2-wing,HallIvory,2);
            Letter(new Rect(compass.x,compass.y+19,compass.width,21),Mathf.RoundToInt(Flat(player.Position,spot))+" m",12,HallIvory,false,TextAnchor.MiddleCenter);
            DrawFieldDestination(slot,spot);
        }
        Block(new Rect(0,top,hudW,43),HallInk);
        Letter(new Rect(17,top,123,33),"真壁　"+Mathf.CeilToInt(player.hp),18,HallIvory,true);
        Meter(new Rect(17,top+34,109,3),player.hp,player.hp<28?red:gold);
        string controls=phase==Phase.Floor && guards.Exists(HasGuardOrder)
            ?"Q　注視切替　　左クリック・Space　指名中の相手に合わせて撃つ"
            :"左クリック・Space　射撃　　 F　打撃　　 Q　注視　　 Tab　指揮";
        Letter(new Rect(156,top,hudW-170,40),GuardViewHint(controls),15,HallIvory);
        if(yieldingPortrait!=null)return;
        string verb=Interaction();
        if(verb.Length>0){
            float width=Mathf.Min(hudW-60,Mathf.Max(230,(verb.Length+5)*18));
            Rect prompt=new Rect((hudW-width)*.5f,hudH*.60f,width,39);
            Block(prompt,HallInk);Letter(prompt,"E　"+verb,18,gold,false,TextAnchor.MiddleCenter);
        }
        if(phase==Phase.Floor){
            float cx=hudW*.5f,cy=hudH*.51f;
            Color aim=lastHit>clock?red:HallIvory;
            Block(new Rect(cx-9,cy,6,2),aim);Block(new Rect(cx+4,cy,6,2),aim);
            Block(new Rect(cx,cy-8,2,5),aim);Block(new Rect(cx,cy+4,2,5),aim);
        }
    }

    void DrawFieldDestination(int slot,Vector3 spot)
    {
        if(Event.current.type!=EventType.Repaint || cam==null)return;
        var at=cam.WorldToViewportPoint(spot+Vector3.up*.15f);
        if(at.z<1 || at.x<.07f || at.x>.93f || at.y<.18f || at.y>.84f)return;
        Vector2 screen=new Vector2(at.x*hudW,(1-at.y)*hudH);
        Color tint=FrontColor(slot);
        Block(new Rect(screen.x-6,screen.y-2,12,3),tint);
        Block(new Rect(screen.x-1,screen.y-10,2,10),tint);
        Rect badge=new Rect(screen.x-15,screen.y+5,30,28);
        Block(badge,HallInk);SiteSign(badge,slot,tint);
    }

    bool HallMapTag(int slot,float w,float h,out Rect tag,out Vector2 floor)
    {
        Vector3 pt=cam.WorldToViewportPoint(HallFrontPosition(slot)+Vector3.up*.2f);
        floor=new Vector2(pt.x*w,(1-pt.y)*h);
        float x=slot==0?floor.x+15:floor.x-129;
        tag=new Rect(Mathf.Clamp(x,6,w-120),Mathf.Clamp(floor.y-19,65,h-HallCommandHeight-40),114,38);
        return pt.z>0 && floor.x>4 && floor.x<w-4 && floor.y>60 && floor.y<h-HallCommandHeight;
    }

    int HallPinAt(Vector2 mouse)
    {
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        Vector2 gui=new Vector2(mouse.x,Screen.height-mouse.y)/scale;
        for(int slot=0;slot<2;slot++){
            if(HallFrontReady(1-slot) || !HallMapTag(slot,Screen.width/scale,Screen.height/scale,out Rect tag,out Vector2 at))continue;
            tag.yMin-=4;tag.yMax+=4;
            if(tag.Contains(gui) || (at-gui).sqrMagnitude<12*12)return slot;
        }
        return -1;
    }

    void DrawHallMapPin(int slot)
    {
        if(HallFrontReady(1-slot) || !HallMapTag(slot,hudW,hudH,out Rect tag,out Vector2 at))return;
        Color tint=FrontColor(slot);
        Block(new Rect(at.x-4,at.y-4,8,8),tint);
        Vector2 edge=new Vector2(slot==0?tag.x:tag.xMax,tag.center.y);
        HallStroke(at,edge,tint,1);
        Block(tag,HallInk);Block(new Rect(tag.x,tag.yMax-2,tag.width,2),tint);
        SiteSign(new Rect(tag.x+4,tag.y+3,32,32),slot,tint);
        Letter(new Rect(tag.x+39,tag.y,tag.width-41,tag.height),HallSites[slot],16,HallIvory);
    }

    void DrawHallRoutes()
    {
        if(Event.current.type!=EventType.Repaint)return;
        for(int i=0;i<crew.Count;i++){
            int front=HallFrontMember(i);
            Person member=crew[i];
            if(front<0 || member.path==null)continue;
            Vector3 prev=member.Position;
            for(int corner=member.corner;corner<member.path.Length;corner++){
                Vector3 next=member.path[corner];
                var a=cam.WorldToViewportPoint(prev+Vector3.up*.12f);
                var b=cam.WorldToViewportPoint(next+Vector3.up*.12f);
                if(a.z>0 && b.z>0){
                    bool selected=IsMemberSelected(i);Color tint=FrontColor(front);tint.a=selected?.92f:.44f;
                    HallStroke(new Vector2(a.x*hudW,(1-a.y)*hudH),new Vector2(b.x*hudW,(1-b.y)*hudH),tint,selected?2.3f:1.5f);
                }
                prev=next;
            }
        }
    }

    void HallStroke(Vector2 a,Vector2 b,Color color,float thickness)
    {
        if(Event.current.type!=EventType.Repaint)return;
        Vector2 delta=b-a;
        if(delta.sqrMagnitude<1)return;
        var saved=GUI.matrix;
        // Both endpoints are in layout coordinates. Multiply before applying the
        // screen scale so the segment starts at the member at any resolution.
        var direction=Quaternion.Euler(0,0,Mathf.Atan2(delta.y,delta.x)*Mathf.Rad2Deg);
        GUI.matrix=saved*Matrix4x4.TRS(new Vector3(a.x,a.y,0),direction,Vector3.one);
        Block(new Rect(0,-thickness*.5f,delta.magnitude,thickness),color);
        GUI.matrix=saved;
    }
}
