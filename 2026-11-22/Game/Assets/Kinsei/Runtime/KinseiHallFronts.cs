using UnityEngine;

public sealed partial class KinseiSession
{
    const float CrewPreparationLimit=.62f;
    const string CrewRelayCall="中継係に合図する";
    readonly float[] hallProgress=new float[2];
    int securedFront=-1;
    Person hallMirrorOperator;

    bool HallFrontsVisible => !finale && (phase==Phase.Floor || phase==Phase.Choice && (escapeTime>0 || HallFrontReady(1)));
    Vector3 HallFrontPosition(int slot) => slot==0 ? new Vector3(3.7f,0,3.1f) : witness;
    float HallFrontProgress(int slot) => hallProgress[slot];
    bool HallFrontReady(int slot) => securedFront==slot;
    static string HallFrontName(int slot) => slot==0?"通用口":"中継卓";

    int HallFrontMember(int index)
    {
        if(index<0 || index>=crew.Count || crew[index].hp<=0)return -1;
        return crew[index].duty switch { Duty.HallDoor=>0, Duty.HallRelay=>1, _=>-1 };
    }

    // Leave the table's near side to the two people in the mirror shot, and the doorway to the boss.
    Vector3 HallPost(int slot,int index)
    {
        var front=HallFrontPosition(slot);
        if(slot==1){
            float flank=index%2==0?-1.85f:1.85f;
            return front+new Vector3(flank,0,-1.2f+index/2*1.12f);
        }
        float x=(index%3-1)*.80f;
        return front+new Vector3(x,0,-.72f-index/3*.75f);
    }

    bool OnHallFloor(Vector3 position,Vector3 spot,float reach) =>
        Mathf.Abs(position.y-spot.y)<.65f && Flat(position,spot)<=reach;

    Person HallThreat(int slot)
    {
        Person closest=null;
        var spot=HallFrontPosition(slot);
        float nearest=3.7f;
        foreach(var guard in guards){
            if(guard.hp<=0 || guard.floorYielded || guard.flinchUntil>clock ||
                Mathf.Abs(guard.Position.y-spot.y)>.65f)continue;
            float distance=Flat(guard.Position,spot);
            if(distance<nearest){closest=guard;nearest=distance;}
        }
        return closest;
    }

    int HallTeam(int slot,out int arrived)
    {
        int assigned=0;
        arrived=0;
        for(int i=0;i<crew.Count;i++){
            if(HallFrontMember(i)!=slot)continue;
            assigned++;
            if(OnHallFloor(crew[i].Position,HallPost(slot,i),.45f))arrived++;
        }
        return assigned;
    }

    string HallFrontStatus(int slot)
    {
        if(securedFront==slot){
            if(slot==0)return DoorInterception()?"兄貴分を足止め":"逃走猶予 ＋18秒";
            if(HallRelayCrew()==null)return "中継係を派遣";
            return OnHallFloor(brother.Position,BrotherAtDesk,.6f)?"弟が卓に到着":"弟が卓へ移動中";
        }
        if(securedFront>=0)return "撤収";
        int assigned=HallTeam(slot,out int arrived);
        var guard=HallThreat(slot);
        if(assigned==0)return guard!=null?GuardName(guard)+"が見張る":"手薄";
        if(arrived==0)return assigned+"人 移動中";
        if(!command && OnHallFloor(player.Position,HallFrontPosition(slot),2.45f))return guard!=null?GuardName(guard)+"をひるませる":"真壁が加勢中";
        if(hallProgress[slot]>=CrewPreparationLimit)return "真壁の加勢待ち";
        return guard!=null?GuardName(guard)+"と交戦":"持ち場を準備中";
    }

    void AssignHallFront(int slot)
    {
        if((uint)slot>1 || !HallFrontsVisible || !command)return;
        if(securedFront>=0 && securedFront!=slot){Say(HallFrontName(securedFront)+"を押さえた。反対の班は引き揚げた");return;}
        int members=SelectedMembers;
        if(members==0){Say("派遣する組員を選んでください");return;}
        for(int i=0;i<crew.Count;i++){
            if((members&(1<<i))==0)continue;
            var p=crew[i];
            if(p.duty==Duty.Attend || p.duty==Duty.StageWitness || p.duty==Duty.BoxOffice || p.duty==Duty.Backstage){
                Say(p.name+"は"+DutyName(p)+"。交代するなら先に随行へ");return;
            }
            if(walkways.Ready && !walkways.GetPath(p.Position,HallPost(slot,i),searchPath)){
                Say(p.name+"の立ち位置から"+HallFrontName(slot)+"に通れない");return;
            }
        }
        for(int i=0;i<crew.Count;i++){
            if((members&(1<<i))==0)continue;
            var p=crew[i];
            ForgetGuard(p);
            p.duty=slot==0?Duty.HallDoor:Duty.HallRelay;
            p.destination=HallPost(slot,i);p.path=null;
        }
        Say(CountMembers(members)==1?crew[FirstMember(members)].name+"が"+HallFrontName(slot)+"へ":CountMembers(members)+"人が"+HallFrontName(slot)+"へ");
        sound.Cue("dial");Mark("hall-dispatch-"+slot+"-"+members);
    }

    void UpdateHallCrew(Person p,int index,int slot,float dt)
    {
        bool operating=slot==1 && p==HallRelayCrew();
        Vector3 post=operating?MirrorOperatingPosition:HallPost(slot,index);
        if(!OnHallFloor(p.Position,post,operating?.15f:.33f)){MovePerson(p,post,3.4f,dt);return;}
        var threat=phase==Phase.Floor?HallThreat(slot):null;
        if(threat!=null && ClearBetween(p,threat)){FireCrewAt(p,index,threat);return;}
        Vector3 facing=slot==0?boss.Position:club.MirrorReceiver.position;
        Face(p,facing);p.actor.SetAttentionTarget(facing+Vector3.up*(slot==0?1.42f:.22f));
        Motion(p,slot==0 || phase==Phase.Floor?"guard":"idle");
    }

    void ReleaseHallTeam(int slot)
    {
        var duty=slot==0?Duty.HallDoor:Duty.HallRelay;
        foreach(var p in crew)if(p.duty==duty){p.duty=Duty.Follow;p.path=null;}
    }

    void ResetHallFronts()
    {
        securedFront=-1;hallMirrorOperator=null;
        hallProgress[0]=hallProgress[1]=0;
    }

    void TickHallFronts(float dt)
    {
        if(!HallFrontsVisible || securedFront>=0)return;
        for(int slot=0;slot<2;slot++){
            HallTeam(slot,out int arrived);
            if(arrived==0){
                hallProgress[slot]=Mathf.MoveTowards(hallProgress[slot],0,.09f*dt);
                continue;
            }
            bool supporting=!command && player.hp>0 && OnHallFloor(player.Position,HallFrontPosition(slot),2.45f);
            // The crew pushes up with Makabe's hit. Keep the opening visible on the guard himself.
            if(supporting)
                foreach(var defender in guards)
                    if(defender.flinchUntil>clock && OnHallFloor(defender.Position,HallFrontPosition(slot),3.7f))
                        defender.flinchUntil=Mathf.Max(defender.flinchUntil,defender.lastPlayerHit+FloorPairWindow);
            var guard=HallThreat(slot);
            bool opening=supporting && guard==null;
            float speed=(opening?.56f:guard!=null?.13f:.22f)+Mathf.Min(2,arrived-1)*.04f;
            float limit=opening?1:CrewPreparationLimit;
            if(hallProgress[slot]<limit)hallProgress[slot]=Mathf.Min(limit,hallProgress[slot]+speed*dt);
            if(hallProgress[slot]<1)continue;
            securedFront=slot;
            hallProgress[1-slot]=0;
            ReleaseHallTeam(1-slot);
            if(slot==0){
                escapeTime+=18;
                Say("通用口を押さえた。兄貴分がこちらへ来る。逃走まで十八秒稼いだ",4.5f);
            }else{
                escorted=true;brother.hp=0;brother.watching=null;brother.flinchUntil=0;brother.path=null;
                if(lockedTarget==brother)lockedTarget=null;
                Say("弟「こっちから兄ちゃんに届くんか」　中継係が卓に残り、弟が駆け寄る",4.5f);
            }
            sound.Cue("choice");Mark("hall-secured-"+slot);return;
        }
    }

    Person HallRelayCrew()
    {
        if(securedFront!=1)return null;
        Person closest=null;float best=float.PositiveInfinity;
        for(int i=0;i<crew.Count;i++){
            if(HallFrontMember(i)!=1)continue;
            float distance=(crew[i].Position-MirrorOperatingPosition).sqrMagnitude;
            if(distance<best){closest=crew[i];best=distance;}
        }
        return closest;
    }

    Vector3 BrotherAtDesk => witness+new Vector3(-.88f,0,-.09f);
    Vector3 MirrorOperatingPosition => witness+new Vector3(.48f,0,0);

    void MoveBrotherToRelay(float dt)
    {
        if(!OnHallFloor(brother.Position,BrotherAtDesk,.21f))MovePerson(brother,BrotherAtDesk,3.1f,dt);
        else {Face(brother,club.MirrorReceiver.position);Motion(brother,"brother-call");}
    }

    void StopBossAtDoor(float dt)
    {
        if(!OnHallFloor(boss.Position,bossDoor,.35f))MovePerson(boss,bossDoor,2.5f,dt);
        else {Face(boss,HallFrontPosition(0));Motion(boss,"guard");}
    }

    bool DoorInterception()
    {
        if(!HallFrontReady(0) || !OnHallFloor(boss.Position,bossDoor,1.6f))return false;
        HallTeam(0,out int arrived);
        return arrived>0;
    }
}
