using UnityEngine;

public sealed partial class KinseiSession
{
    // Leave the stage steps, witness mark and the south-east approach to the desk open.
    static readonly Vector3[] AudiencePlaces={
        new(-.25f,0,2.70f),new(1.30f,0,2.12f),new(2.90f,0,2.80f),
        new(-4.55f,0,-.42f),new(-3.84f,0,-1.85f),new(-2.18f,0,-1.58f),
        new(.24f,0,-1.18f),new(1.79f,0,-.68f),new(3.24f,0,.16f),
        new(-5.12f,0,-2.88f),new(-.92f,0,-3.05f),new(2.05f,0,-2.51f)
    };
    readonly Person[] audienceMembers=new Person[AudiencePlaces.Length];
    readonly float[] audienceArrived=new float[AudiencePlaces.Length];

    bool CanWatchStage(Person p)
    {
        var at=p.Position;
        return p!=stageWitness && p!=stageDeskRunner && !p.retired && !p.floorYielded && p.hp>0 &&
            (p==brother || crew.Contains(p) || guards.Contains(p) || upstairs.Contains(p)) &&
            p.duty!=Duty.Attend && p.duty!=Duty.BoxOffice && p.duty!=Duty.Backstage &&
            at.x> -8.5f && at.x<8.6f && at.z> -7.5f && at.z<6 && at.y<.68f;
    }

    void BeginStageAudience()
    {
        System.Array.Clear(audienceMembers,0,audienceMembers.Length);
        for(int i=0;i<audienceArrived.Length;i++)audienceArrived[i]=-1;
        foreach(var p in everyone)SeatStageObserver(p);
    }

    void SeatStageObserver(Person p)
    {
        if(!CanWatchStage(p) || System.Array.IndexOf(audienceMembers,p)>=0)return;
        int best=-1;float shortest=float.MaxValue;
        for(int i=0;i<AudiencePlaces.Length;i++){
            float distance=Flat(p.Position,AudiencePlaces[i]);
            if(audienceMembers[i]!=null || distance>=shortest)continue;
            if(walkways.Ready && !walkways.GetPath(p.Position,AudiencePlaces[i],searchPath))continue;
            best=i;shortest=distance;
        }
        if(best<0)return;
        audienceMembers[best]=p;audienceArrived[best]=-1;p.path=null;
    }

    void TickStageAudience(float dt)
    {
        // A runner recruited from the street can join the spectators when relieved indoors.
        foreach(var member in crew)SeatStageObserver(member);
        for(int i=0;i<audienceMembers.Length;i++){
            var p=audienceMembers[i];
            if(p==null || p==stageDeskRunner || p.retired || p.hp<=0)continue;
            var target=AudiencePlaces[i];
            float remaining=Vector3.Distance(p.Position,target);
            if(remaining>.15f){
                audienceArrived[i]=-1;
                MovePerson(p,target,Mathf.Clamp(remaining*2,.48f,1.65f+.09f*(i%3)),dt);
                continue;
            }
            if(audienceArrived[i]<0)audienceArrived[i]=clock;
            float settled=clock-audienceArrived[i];
            float speaking=stageBeat==StageBeat.Testimony?4.8f-(stageBeatEnds-clock):-1;
            string pose="idle";
            Vector3 look=boss.Position;
            if(i%3==0 && settled>.25f && settled<2.6f){pose="audience-signal";look=StageWing;}
            else if(i%3==1 && settled>.4f && settled<2.1f){pose="audience-turn";look=StageDeskCentre;}
            if(speaking>=0){
                look=boss.Position;pose="idle";
                float reaction=speaking-(1.50f+.19f*(i%5));
                if(i%3==2 && reaction>0 && reaction<1.7f)pose="audience-clap";
                else if(i%3==1 && reaction>.45f && reaction<1.5f){look=StageDeskCentre;pose="audience-turn";}
            }
            var aim=look-p.Position;aim.y=0;
            if(aim.sqrMagnitude>.001f)p.root.rotation=Quaternion.RotateTowards(p.root.rotation,Quaternion.LookRotation(aim),dt*100);
            Motion(p,pose);
        }
    }
}
