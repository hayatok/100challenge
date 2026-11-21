using UnityEngine;

public sealed partial class KinseiSession
{
    const string BackstageVerb="通し札を受けて楽屋口を開ける";
    static readonly Vector3 BackstagePost=new(-9.77f,0,-.12f);
    float backstageTravel;
    bool pullingBackstage;

    bool CanOrderBackstage => !finale && phase==Phase.Arrival && backstageTravel==0 && !pullingBackstage;
    static bool AtBackstagePost(Person p) => p.hp>0 && Vector3.Distance(p.Position,BackstagePost)<.34f;
    Person BackstageRunner => crew.Find(p=>p.duty==Duty.Backstage);
    bool CanPullBackstage => CanOrderBackstage && !command && BackstageRunner is Person runner &&
        AtBackstagePost(runner) && player.Position.x< -9.18f && player.Position.y<.5f &&
        Flat(player.Position,club.BackstageHandle)<.69f;

    void ReleaseBackstagePost()
    {
        var person=BackstageRunner;
        if(person!=null){person.duty=Duty.Follow;person.path=null;}
        club.ShowBackstagePass(false);
    }

    void ResetBackstage()
    {
        bool rebuild=backstageTravel>=1;
        backstageTravel=0;
        pullingBackstage=false;
        club.SetBackstageDoor(0);
        club.ShowBackstagePass(false);
        if(rebuild && walkways.Ready)walkways.Rebuild(club.transform);
    }

    void BeginBackstagePull()
    {
        if(!CanPullBackstage)return;
        pullingBackstage=true;
        Face(player,club.BackstageHandle);
        Motion(player,"idle");
        sound.Cue("door");Mark("backstage-pull");
    }

    void TickBackstage(float dt)
    {
        if(!pullingBackstage){
            var runner=BackstageRunner;
            club.ShowBackstagePass(CanOrderBackstage && runner!=null && AtBackstagePost(runner));
            return;
        }
        backstageTravel=Mathf.MoveTowards(backstageTravel,1,dt/1.25f);
        club.SetBackstageDoor(Mathf.SmoothStep(0,1,backstageTravel));
        if(backstageTravel<1)return;
        pullingBackstage=false;
        walkways.Rebuild(club.transform);
        foreach(var p in everyone)p.path=null;
        ReleaseBackstagePost();
        Say("引戸が開いた。舞台の脇へ出られる");
        Mark("backstage-open");
    }

    void ApplyBackstageHands(Person person)
    {
        if(person==player && pullingBackstage){
            float grip=Mathf.Clamp01(backstageTravel/.13f)*Mathf.Clamp01((.55f-backstageTravel)/.18f);
            person.actor.ReachBackstageHandle(club.BackstageHandle,grip);
        } else if(person.duty==Duty.Backstage && AtBackstagePost(person))
            person.actor.ReachBackstageHandle(club.PassSlot,.82f);
    }

    void DrawBackstageMark()
    {
        if(!command || finale || phase!=Phase.Arrival)return;
        var viewport=cam.WorldToViewportPoint(new Vector3(-10.5f,.2f,1.72f));
        if(viewport.z<=0 || viewport.x<.07f || viewport.x>.93f || viewport.y<.29f || viewport.y>.83f)return;
        var rect=new Rect(viewport.x*hudW-76,(1-viewport.y)*hudH,152,25);
        string state=backstageTravel>=1?"開放":pullingBackstage?"開扉中":
            (BackstageRunner is Person p && AtBackstagePost(p)?"札あり":"閉鎖");
        Block(rect,ink);Letter(rect,"楽屋口　"+state,14,gold,false,TextAnchor.MiddleCenter);
    }
}
