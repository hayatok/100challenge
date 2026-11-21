using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiSession
{
    CharacterController motor;
    float fallVelocity, moveBlend, attackUntil, nextStep;
    Vector3 lastAim;
    readonly List<Person> combatants = new();
    UnityEngine.AI.NavMeshPath searchPath;
    readonly Color gold = new(.98f,.77f,.40f);
    readonly Color cream = new(1,.95f,.84f);
    readonly Color red = new(.97f,.36f,.29f);
    readonly Color mint = new(.43f,.88f,.81f);

    static float Flat(Vector3 a,Vector3 b) => Vector2.Distance(new Vector2(a.x,a.z),new Vector2(b.x,b.z));
    void Face(Person p,Vector3 target)
    {
        var dir=target-p.Position; dir.y=0;
        if(dir.sqrMagnitude>.001f) p.root.rotation=Quaternion.LookRotation(dir);
    }
    void Motion(Person p,string pose,float speed=0)
    {
        p.pose=pose; p.speed=speed;
    }
    void Act(Person p,string kind)
    {
        p.lastAction=clock; Motion(p,kind);
    }
    void MovePerson(Person p,Vector3 to,float rate,float dt)
    {
        var here=p.Position;
        bool enteringSeat=p.duty==Duty.Attend && here.y>3 && Vector3.Distance(here,to)<1.18f;
        if(!enteringSeat && FollowWalkway(p,to,rate,dt))return;
        Vector3 next=to;
        // Both levels join at the switchback on the east side of the hall.
        bool up=to.y>2, onStair=here.x>5.0f && here.x<7.05f && here.z>-.35f && here.z<5.96f;
        if(up && here.y<3.12f) {
            if(onStair || Flat(here,new Vector3(6,0,-.22f))<.24f) next=new Vector3(6,3.2f,6.08f);
            else next=new Vector3(6,0,-.2f);
        } else if(!up && here.y>.10f) {
            if(onStair || Flat(here,new Vector3(6,3.2f,6.02f))<.22f) next=new Vector3(6,0,-.42f);
            else next=new Vector3(6,3.2f,6.02f);
        }
        if(here.z< -8.3f && next.z> -7.65f) next=new Vector3(Mathf.Clamp(to.x,-.95f,.95f),0,-7.5f);
        var along=next-here; along.y=0;
        float dist=along.magnitude;
        if(dist<.07f) { Motion(p,"idle"); return; }
        Vector3 pos=here+along.normalized*Mathf.Min(dist,rate*dt);
        if(pos.x>5 && pos.x<7.05f && pos.z>=-.16f && pos.z<=5.95f)
            pos.y=Mathf.Lerp(0,3.2f,Mathf.InverseLerp(-.16f,5.75f,pos.z));
        else if(pos.z>=5.8f && (up || here.y>3)) pos.y=3.2f;
        else pos.y=here.y>2.9f && next.y>3?3.2f:0;
        p.root.position=pos;
        p.root.rotation=Quaternion.RotateTowards(p.root.rotation,Quaternion.LookRotation(along),dt*390);
        Motion(p,rate>2.8f?"run":"walk",rate);
    }

    bool FollowWalkway(Person p,Vector3 goal,float rate,float dt)
    {
        if(walkways==null || !walkways.Ready)return false;
        if(p.path==null || clock>=p.repathAt || (p.routeGoal-goal).sqrMagnitude>1.1f) {
            p.routeGoal=goal;p.repathAt=clock+.68f;
            p.path=walkways.GetPath(p.Position,goal,searchPath)?searchPath.corners:System.Array.Empty<Vector3>();
            p.corner=1;
        }
        while(p.corner<p.path.Length && Vector3.Distance(p.Position,p.path[p.corner])<.14f)p.corner++;
        if(p.corner>=p.path.Length)return false;
        var next=p.path[p.corner];
        var direction=next-p.Position;direction.y=0;
        var at=Vector3.MoveTowards(p.Position,next,rate*dt);
        if(walkways.Project(at,out var floor) && Mathf.Abs(floor.y-at.y)<.42f)at.y=floor.y;
        p.root.position=at;
        if(direction.sqrMagnitude>.0001f)p.root.rotation=Quaternion.RotateTowards(p.root.rotation,Quaternion.LookRotation(direction),dt*390);
        Motion(p,rate>2.8f?"run":"walk",rate);
        return true;
    }

    void PlayerInput(float dt)
    {
        if(phase==Phase.Mirror) return;
        if(motor==null || motor.gameObject!=player.root.gameObject) {
            motor=player.root.gameObject.AddComponent<CharacterController>();
            motor.center=Vector3.up*.9f; motor.height=1.8f; motor.radius=.28f;
            motor.stepOffset=.3f; motor.skinWidth=.035f;
            fallVelocity=0;
        }
        float turn=(Input.GetKey(KeyCode.RightArrow)?1:0)-(Input.GetKey(KeyCode.LeftArrow)?1:0);
        angle+=turn*102*dt;
        if(Input.GetMouseButton(1)) {
            angle+=Input.GetAxisRaw("Mouse X")*3.1f;
            tilt=Mathf.Clamp(tilt-Input.GetAxisRaw("Mouse Y")*2f,-32,43);
        }
        Vector3 move=new Vector3((Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0),0,
            (Input.GetKey(KeyCode.W)||Input.GetKey(KeyCode.UpArrow)?1:0)-(Input.GetKey(KeyCode.S)||Input.GetKey(KeyCode.DownArrow)?1:0));
        move=Quaternion.Euler(0,angle,0)*move.normalized;
        float rate=Input.GetKey(KeyCode.LeftShift)?4.1f:2.55f;
        if(motor.isGrounded) fallVelocity=-2f;
        fallVelocity=Mathf.Max(-16,fallVelocity-21*dt);
        Vector3 proposed=player.Position+move*rate*dt;
        proposed.x=Mathf.Clamp(proposed.x,-8.62f,8.62f); proposed.z=Mathf.Clamp(proposed.z,-14f,8.55f);
        var step=proposed-player.Position;
        motor.Move(new Vector3(step.x,fallVelocity*dt,step.z));
        if(move.sqrMagnitude>.1f) player.root.rotation=Quaternion.RotateTowards(player.root.rotation,Quaternion.LookRotation(move),dt*540);
        moveBlend=Mathf.MoveTowards(moveBlend,move.magnitude*rate,dt*12);
        if(moveBlend>1 && motor.isGrounded && clock>=nextStep) {
            sound.Cue("step"); nextStep=clock+(rate>3?.29f:.41f);
        }
        bool fighting=phase==Phase.Floor || phase==Phase.Chase;
        if(clock>attackUntil) Motion(player,moveBlend>.18f?(rate>3?"run":"walk"):(fighting?"guard":"idle"),moveBlend);
        if(Input.GetKeyDown(KeyCode.Q)) CycleTarget();
        if(Input.GetKeyDown(KeyCode.E)) Interact();
        if((Input.GetMouseButtonDown(0) || Input.GetKeyDown(KeyCode.Space)) && !OverHUD())
            Attack(false,Input.GetMouseButtonDown(0));
        if(Input.GetKeyDown(KeyCode.F)) Attack(true,false);
    }

    void Targets()
    {
        combatants.Clear();
        if(phase==Phase.Floor) {
            foreach(var g in guards) if(g.hp>0) combatants.Add(g);
            if(brother.hp>0)combatants.Add(brother);
            if(!held && phaseAge>24) foreach(var g in upstairs) if(!g.retired && g.hp>0 && g.Position.y<1) combatants.Add(g);
        } else if(phase==Phase.Chase) combatants.Add(boss);
    }
    void CycleTarget()
    {
        Targets(); if(combatants.Count==0)return;
        lockedTarget=(lockedTarget+1)%combatants.Count;
        var p=combatants[lockedTarget]; Vector3 d=p.Position-player.Position;
        angle=Mathf.Atan2(d.x,d.z)*Mathf.Rad2Deg;
        tilt=6; Face(player,p.Position);
        player.actor.SetAttentionTarget(p.Position+Vector3.up*1.56f);
        Say("注視　"+p.name,1.1f);
    }
    Person Pick(bool mouse,bool melee)
    {
        Targets();
        if(combatants.Count==0)return null;
        Person best=null; float score=float.MaxValue;
        Vector2 cursor=mouse?(Vector2)Input.mousePosition:new Vector2(Screen.width*.5f,Screen.height*.49f);
        foreach(var p in combatants)
        {
            var from=player.Position+Vector3.up*1.38f; var center=p.Position+Vector3.up*1.15f;
            float distance=Vector3.Distance(from,center);
            if(distance>(melee?2.0f:13.5f))continue;
            if(Physics.Linecast(from,center,out var hit,~0,QueryTriggerInteraction.Ignore) && hit.collider!=motor)continue;
            var pt=cam.WorldToScreenPoint(center);
            if(pt.z<.1f)continue;
            float pixel=Vector2.Distance(pt,cursor);
            float tolerance=melee?Screen.height*.5f:mouse?Mathf.Max(26,Screen.height/Mathf.Max(5,distance)*.8f):Screen.height*.29f;
            if(!mouse && lockedTarget>=0 && lockedTarget<combatants.Count && combatants[lockedTarget]==p)pixel=0;
            if(pixel<tolerance && pixel<score){score=pixel;best=p;}
        }
        return best;
    }
    void Attack(bool melee,bool mouse)
    {
        if(clock<shootDelay || (phase!=Phase.Floor && phase!=Phase.Chase))return;
        var target=Pick(mouse,melee);
        shootDelay=clock+(melee?.48f:.30f); attackUntil=clock+.32f;
        Act(player,melee?"punch":"shoot"); shots++;
        sound.Cue(melee?"strike":"shot");
        if(!melee) {
            flashTime=clock+.07f;
            Vector3 towards=target!=null?target.Position+Vector3.up*1.22f:
                cam.ScreenPointToRay(mouse?Input.mousePosition:new Vector3(Screen.width*.5f,Screen.height*.49f)).GetPoint(14);
            Trace(player,towards,false);
        }
        if(target==null)return;
        Face(player,target.Position);
        player.actor.SetAttentionTarget(target.Position+Vector3.up*1.56f);
        target.hp=Mathf.Max(0,target.hp-(melee?48:32));
        target.flinchUntil=clock+.23f;
        lastHit=clock+.19f;
        if(target==boss)bossHp=target.hp;
        if(target.hp<=0 && target!=brother) Act(target,"fall");
        Mark("hit-"+target.role+"-"+Mathf.RoundToInt(target.hp));
    }

    void Trace(Person from,Vector3 to,bool enemy)
    {
        var hand=from.Position+Vector3.up*1.31f+from.root.right*.16f+from.root.forward*.43f;
        actionLight.Shot(hand,to,enemy,reducedMotion);
    }

    void CommandInput()
    {
        Vector2 shift=new Vector2((Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0),
            (Input.GetKey(KeyCode.W)?1:0)-(Input.GetKey(KeyCode.S)?1:0));
        mapOffset+=shift.normalized*(7*Time.deltaTime);
        mapOffset.x=Mathf.Clamp(mapOffset.x,-5f,5f);mapOffset.y=Mathf.Clamp(mapOffset.y,-5.5f,4.5f);
        chartSize=Mathf.Clamp(chartSize-Input.mouseScrollDelta.y*.9f,6.7f,16.2f);
        for(int i=0;i<6;i++) if(Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1+i))) chosen=i;
        if(Input.GetKeyDown(KeyCode.E)) Assign(Duty.Attend);
        if(Input.GetKeyDown(KeyCode.F)) Assign(Duty.Follow);
        if(Input.GetKeyDown(KeyCode.R)) Assign(Duty.Rest);
        if(Input.GetKeyDown(KeyCode.G)) Assign(Duty.Guard);
        if(Input.GetMouseButtonDown(0) && !OverHUD()) {
            Vector2 hit=Input.mousePosition; float nearest=Screen.height*.057f;
            for(int i=0;i<crew.Count;i++) {
                var pt=cam.WorldToScreenPoint(crew[i].Position+Vector3.up);
                float d=Vector2.Distance(hit,pt); if(pt.z>0 && d<nearest){chosen=i;nearest=d;}
            }
        }
        if(Input.GetMouseButtonDown(1) && !OverHUD()) {
            var ray=cam.ScreenPointToRay(Input.mousePosition); var ground=new Plane(Vector3.up,0);
            if(ground.Raycast(ray,out float length)) {
                Vector3 dest=ray.GetPoint(length);
                if(Physics.Raycast(ray,out var floorHit,60) && floorHit.point.y>2.8f && floorHit.point.z>=5.8f)
                    dest=new Vector3(floorHit.point.x,3.2f,floorHit.point.z);
                dest.x=Mathf.Clamp(dest.x,-7.3f,7.3f); dest.z=Mathf.Clamp(dest.z,-12.5f,8.25f);
                Assign(Duty.Go,dest);
            }
        }
    }

    void Assign(Duty duty,Vector3 destination=default)
    {
        var p=crew[chosen]; if(p.hp<=0){Say(p.name+"は動けない");return;}
        if(duty==Duty.Go && walkways.Ready && !walkways.GetPath(p.Position,destination,searchPath)){
            Say("その地点には通路がつながっていない");return;
        }
        if(duty==Duty.Attend && p!=crew[0]){Say(p.name+"「梶さんに話が通るんは辰さんや」");return;}
        if(duty==Duty.Attend && accord){Say("梶との話はついた");return;}
        if(p==crew[0] && p.duty==Duty.Attend && duty!=Duty.Attend && !accord){
            held=false;talkProgress=0; Say("辰が席を離れた。梶の連れが立つ");
        }
        p.duty=duty; p.destination=destination;
        if(duty==Duty.Attend){p.destination=table;Say("辰「二階はわしに任せえ」");}
        else if(duty==Duty.Guard){p.destination=new Vector3(2.1f+(chosen%3)*.65f,0,-1.2f-(chosen/3)); Say(p.name+"をダンスホールへ回した");}
        else if(duty==Duty.Rest){p.destination=new Vector3((chosen%3-1)*1.0f,0,-9.6f-(chosen/3)); Say(p.name+"を表へ下げた");}
        else Say(p.name+(duty==Duty.Follow?"が真壁に合流する":"が指定位置へ向かう"));
        sound.Cue("dial"); Mark("order-"+chosen+"-"+duty);
    }

    bool OverHUD()
    {
        float y=1-Input.mousePosition.y/Screen.height;
        return y<.12f || (command && y>.76f);
    }
}

