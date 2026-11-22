using UnityEngine;

public sealed partial class KinseiSession
{
    bool hallOtherOrders;
    Texture2D hallSigns;
    int lastHallMember=-1;
    float lastHallClick;
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
            FocusCommandAt(crew[i].Position);
            lastHallMember=-1;
            Mark("hall-focus-"+i);
        }else lastHallMember=extend?-1:i;
        lastHallClick=now;
    }

    string HallFieldObjective()
    {
        string objective=phase==Phase.Choice ? Objective() : "組員を送り、真壁が一方を援護する";
        if(HallFrontReady(0)){
            if(phase==Phase.Choice)objective="通用口へ向かい、兄貴分を追う";
            else objective=DoorInterception()?"通用口で組員が足止め中。弟と用心棒を退かせる":"逃走まで十八秒稼いだ。弟と用心棒を退かせる";
        }
        else if(HallFrontReady(1)){
            if(HallRelayCrew()==null)objective="中継卓に組員を送り直す";
            else objective=phase==Phase.Choice?"中継卓へ行き、組員に合図する":"弟が中継卓へ向かう。残る用心棒を退かせる";
        }
        return objective;
    }

    void DrawHallBattle()
    {
        WorldMarks();
        DrawFieldHeader(HallFieldObjective());
        HallFieldHUD();
        DrawFieldVoice();
        if(phase==Phase.Choice && escapeTime>0){
            Rect timer=new Rect(hudW-233,66,217,33);Block(timer,HallInk);
            Letter(timer,"逃走まで　"+Mathf.CeilToInt(escapeTime)+" 秒",16,DoorCue,false,TextAnchor.MiddleCenter);
        }
        if(showFps)Letter(new Rect(hudW-115,105,99,24),Mathf.RoundToInt(fpsSmooth)+" FPS",13,HallIvory,false,TextAnchor.MiddleRight);
        if(!reducedMotion && hitFlash>clock)Block(new Rect(16,hudH-92,174,2),red);
    }

    void DrawHallCard(Rect card,int slot)
    {
        bool closed=HallFrontReady(1-slot);
        Color tint=closed?new Color(.55f,.56f,.56f):FrontColor(slot);
        Block(card,HallInk);
        Block(new Rect(card.x,card.y,3,card.height),tint);
        SiteSign(new Rect(card.x+9,card.y+3,30,30),slot,closed?tint:HallIvory);
        float x=card.x+48;
        Letter(new Rect(x,card.y+2,94,31),HallSites[slot],20,HallIvory,true);
        Letter(new Rect(x+76,card.y+3,card.xMax-x-83,27),HallFrontStatus(slot),13,closed?tint:HallIvory,false,TextAnchor.MiddleRight);
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
    }

    void HallFieldHUD()
    {
        for(int slot=0;slot<2;slot++){
            if(HallFrontReady(1-slot))continue;
            Rect row=new Rect(slot==1?16:hudW-288,hudH-142,272,45);
            DrawHallCard(row,slot);
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
        DrawFieldHealth();
        string controls=phase==Phase.Floor?CombatHint:"WASD　移動　　"+LookHint+"　　Tab　指揮";
        DrawFieldControls(GuardViewHint(controls));
        if(yieldingPortrait!=null)return;
        string verb=Interaction();
        if(verb.Length>0){
            float width=Mathf.Min(hudW-60,Mathf.Max(230,(verb.Length+5)*18));
            Rect prompt=new Rect((hudW-width)*.5f,hudH*.60f,width,39);
            Block(prompt,HallInk);Letter(prompt,"E　"+verb,18,gold,false,TextAnchor.MiddleCenter);
        }
        if(phase==Phase.Floor){
            DrawSight(lastHit>clock?red:HallIvory);
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
        tag=new Rect(Mathf.Clamp(floor.x-27,6,w-60),Mathf.Clamp(floor.y-27,65,h-CommandDockHeight-58),54,54);
        return pt.z>0 && floor.x>4 && floor.x<w-4 && floor.y>60 && floor.y<h-CommandDockHeight;
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
        bool hover=tag.Contains(Event.current.mousePosition);
        Block(tag,hover?Color.white:DeskPaper);
        Block(new Rect(tag.x,tag.yMax-3,tag.width,3),tint);
        SiteSign(new Rect(tag.center.x-16,tag.y+2,32,32),slot,DeskInk);
        Letter(new Rect(tag.x,tag.y+33,tag.width,18),HallSites[slot],12,DeskInk,false,TextAnchor.MiddleCenter);
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
