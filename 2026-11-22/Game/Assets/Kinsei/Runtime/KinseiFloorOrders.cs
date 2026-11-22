using UnityEngine;

public sealed partial class KinseiSession
{
    const float FloorPairWindow=1.55f;
    const float FloorFlinchTime=.52f;
    readonly Rect[] guardTags=new Rect[2];
    string floorGuardReport="";

    string FloorGuardReport()
    {
        string line="";
        foreach(var g in guards){
            if(!g.floorYielded && g.hp>0)continue;
            if(line.Length>0)line+="　／　";
            line+=GuardName(g)+(g.floorYielded?"　降参":"　撃破");
        }
        return line.Length>0?"ホール　"+line:"";
    }

    bool IsHallGuard(Person target)=>!finale && phase==Phase.Floor && target!=null && guards.Contains(target);
    static string GuardName(Person guard)=>guard.name.Replace("用心棒・","");
    bool HasGuardOrder(Person guard)
    {
        foreach(var member in crew)
            if(member.hp>0 && member.duty==Duty.Designated && member.assignedGuard==guard)return true;
        return false;
    }

    Person GuardAtScreen(Vector2 click)
    {
        if(finale || phase!=Phase.Floor || !command)return null;
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        var gui=new Vector2(click.x,Screen.height-click.y)/scale;
        Person nearest=null;float best=Screen.height*.022f;
        foreach(var guard in guards){
            if(guard.hp<=0 || guard.floorYielded)continue;
            if(guardTags[guards.IndexOf(guard)].Contains(gui))return guard;
            var feet=cam.WorldToScreenPoint(guard.Position+Vector3.up*.18f);
            var head=cam.WorldToScreenPoint(guard.Position+Vector3.up*1.83f);
            if(feet.z<=0 || head.z<=0)continue;
            Vector2 span=(Vector2)(head-feet);
            float along=Mathf.Clamp01(Vector2.Dot(click-(Vector2)feet,span)/Mathf.Max(.01f,span.sqrMagnitude));
            float distance=Vector2.Distance(click,(Vector2)feet+span*along);
            if(distance<best){nearest=guard;best=distance;}
        }
        return nearest;
    }

    void DesignateGuard(Person guard)
    {
        if(!command || !IsHallGuard(guard) || guard.hp<=0 || guard.floorYielded)return;
        int mask=SelectedMembers;
        if(mask==0){Say("担当を任せる組員を選んでください");return;}
        for(int i=0;i<crew.Count;i++)if((mask&(1<<i))!=0){
            var p=crew[i];
            if(p.duty==Duty.StageWitness || p.duty==Duty.Attend || p.duty==Duty.BoxOffice || p.duty==Duty.Backstage){
                Say(p.name+"は"+DutyName(p)+"。別の組員を選ぶか先に随行へ");return;
            }
        }
        SetSelection(mask);
        for(int i=0;i<crew.Count;i++)if((mask&(1<<i))!=0){
            var p=crew[i];
            if(p.assignedGuard!=guard){p.path=null;p.lastNamedHit=float.NegativeInfinity;}
            p.duty=Duty.Designated;p.assignedGuard=guard;
        }
        string who=CountMembers(mask)==1?crew[chosen].name:CountMembers(mask)+"人";
        Say(who+"に"+GuardName(guard)+"を任せた。真壁も同じ相手へ");sound.Cue("dial");
        Mark("floor-order-"+GuardName(guard)+"-"+mask);
    }

    void ForgetGuard(Person p)
    {
        p.assignedGuard=null;p.lastNamedHit=float.NegativeInfinity;
        if(p.duty==Duty.Designated){p.duty=Duty.Follow;p.path=null;}
    }

    void ReleaseGuard(Person guard)
    {
        foreach(var p in crew)if(p.assignedGuard==guard)ForgetGuard(p);
    }

    void ClearFloorAssignments()
    {
        foreach(var p in crew)if(p.assignedGuard!=null || p.duty==Duty.Designated)ForgetGuard(p);
        foreach(var p in guards)p.lastPlayerHit=float.NegativeInfinity;
        guardTags[0]=guardTags[1]=default;
    }

    bool UpdateDesignated(Person p,int index,float dt)
    {
        var guard=p.assignedGuard;
        if(!IsHallGuard(guard) || guard.hp<=0 || guard.floorYielded){ForgetGuard(p);return false;}
        Vector3 away=p.Position-guard.Position;away.y=0;
        bool clear=ClearBetween(p,guard);
        if(away.magnitude>4.6f || !clear || Mathf.Abs(p.Position.y-guard.Position.y)>.7f){
            Vector3 goal=guard.Position;
            if(clear && away.sqrMagnitude>.01f){
                Vector3 stagger=Vector3.Cross(Vector3.up,away.normalized)*((index%3)-1)*.47f;
                var near=guard.Position+away.normalized*3.4f+stagger;
                if(walkways.Project(near,out var floor) && Mathf.Abs(floor.y-guard.Position.y)<.45f)goal=floor;
            }
            MovePerson(p,goal,3.1f,dt);return true;
        }
        FireCrewAt(p,index,guard);return true;
    }

    void FireCrewAt(Person p,int index,Person target)
    {
        Face(p,target.Position);p.actor.SetAttentionTarget(target.Position+Vector3.up*1.56f);
        if(clock<p.cooldown){if(clock-p.lastAction>.28f)Motion(p,"guard");return;}
        p.cooldown=clock+1.5f+index*.13f;
        Act(p,"shoot");Trace(p,target.Position+Vector3.up*1.15f,false);sound.Cue("distant");
        if(p.duty==Duty.Designated && target==p.assignedGuard){
            p.lastNamedHit=clock;Mark("floor-named-hit-"+index+"-"+GuardName(target));
            if(TryFloorYield(target))return;
        }
        target.hp=Mathf.Max(0,target.hp-(p.duty==Duty.Guard || p.duty==Duty.Designated?11:5));
        if(target==boss)bossHp=target.hp;
        if(target.hp<=0 && target!=brother){Act(target,"fall");ReleaseGuard(target);}
    }

    bool TryFloorYield(Person guard)
    {
        if(!IsHallGuard(guard) || guard.hp<=0 || guard.floorYielded || clock>guard.lastPlayerHit+FloorPairWindow)return false;
        foreach(var p in crew){
            if(p.hp<=0 || p.duty!=Duty.Designated || p.assignedGuard!=guard || clock>p.lastNamedHit+FloorPairWindow)continue;
            guard.floorYielded=true;guard.watching=null;guard.flinchUntil=0;
            guard.actor.SetAttentionTarget(player.actor.EyePosition);Act(guard,"floor-yield");
            ReleaseGuard(guard);
            if(lockedTarget==guard)lockedTarget=null;
            int speaker=guards.IndexOf(guard);
            sound.PlayFloorYield(speaker,guard.Position);
            Say(GuardName(guard)+(speaker==0?"「わかった。もう降りる。」":"「待ってくれ。わしは降りる。」"),2.8f);
            Mark("floor-yield-"+GuardName(guard));
            return true;
        }
        return false;
    }
}
