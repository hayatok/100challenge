using UnityEngine;

public sealed partial class KinseiSession
{
    void Change(Phase next)
    {
        phase=next; phaseAge=0; lockedTarget=-1; Mark("phase-"+next);
    }

    void Simulate(float dt)
    {
        if(phase==Phase.Arrival && player.Position.z> -6.75f) {
            Change(Phase.Floor); entranceTime=clock;
            Say("梶の連れが二階に四人。辰なら話をつけられる",4.1f); sound.Cue("door");
        }
        // The same cast advances under both cameras.
        for(int i=0;i<crew.Count;i++) UpdateCrew(crew[i],i,dt);
        UpdateUpstairs(dt);
        if(phase==Phase.Floor) {
            foreach(var p in guards) Opponent(p,dt);
            if(brother.hp>0) Opponent(brother,dt);
            else Motion(brother,"surrender");
            bool cleared=brother.hp<=0 && guards.TrueForAll(g=>g.hp<=0);
            if(cleared) {
                Change(Phase.Choice); Motion(brother,"surrender"); sound.Cue("choice");
                Say("弟「もうええ……兄ちゃんに、顔だけ見せてくれ」",4.6f);
            }
        }
        if(phase==Phase.Choice) {
            escapeTime-=dt;
            if(escapeTime>3f) MovePerson(boss,bossDoor,1.45f,dt);
            else if(escapeTime>0) MovePerson(boss,bossDoor+new Vector3(2,0,.9f),1.5f,dt);
            else if(!boss.retired) {
                boss.retired=true;boss.root.gameObject.SetActive(false);
                Say("兄貴分が通用口を出た。弟はまだホールにいる。");
            }
            if(escorted && Flat(brother.Position,player.Position)>.85f)
                MovePerson(brother,player.Position,3.1f,dt);
            else Motion(brother,"surrender");
            if(escapeTime<=0 && crew[0].hp<=0) {
                End("loss","金星からの撤退","兄貴分は通用口を出た。辰が倒れ、梶との中継もかなわず、真壁は仲間を連れて引き揚げた。");return;
            }
            if(escapeTime<=0 && !escorted && !held) {
                End("loss","取り逃がした夜","兄貴分は金星を出た。梶の弟も席を立ち、店には真壁たちだけが残った。");return;
            }
        } else if(phase==Phase.Chase) {
            if(boss.hp<=0) {Motion(boss,"fall"); End("pursuit","金星を取り返す","兄貴分が舞台袖で膝をついた。翌朝、四十軒の帳面に金星の興行主として真壁の名が戻る。");return;}
            Opponent(boss,dt);
        } else if(phase==Phase.Mirror) {
            relayProgress=Mathf.Min(1,phaseAge/4.6f); club.SetMirror(relayProgress,relayImage,elder.actor.EyePosition);
            Motion(player,"mirror"); Face(player,new Vector3(-2.68f,0,.03f));
            Motion(brother,"brother-call");
            if(phaseAge>=4.6f) {
                accord=true;held=false; crew[0].duty=Duty.Follow;
                Say("梶「帰るで。……辰さん、おおきに」",4f);
                sound.Cue("accord"); Change(Phase.Release);
            }
        } else if(phase==Phase.Release) {
            if(elder.Position.z< -8.85f && brother.Position.z< -8.5f) {
                End("accord","兄弟を帰した夜","梶は弟の肩を抱いて四人と店を出た。辰が真壁の隣に戻る。兄貴分との決着は持ち越した。");return;
            }
        }
        if(player.hp<=0) End("loss","金星からの撤退","真壁は動けなくなった。仲間は表通りまで真壁を運び、今夜の興行を手放した。");
    }

    void UpdateCrew(Person p,int index,float dt)
    {
        if(p.hp<=0) {
            if(index==0) {held=false;talkProgress=0;}
            Motion(p,"fall");return;
        }
        if(p.duty==Duty.Attend && !accord) {
            if(Vector3.Distance(p.Position,table)>.19f) MovePerson(p,table,3.65f,dt);
            else {
                Face(p,elder.Position); Motion(p,"talk"); talkProgress+=dt;
                Vector3 ash=club.SetAshtray(Mathf.InverseLerp(.65f,1.65f,talkProgress));
                p.actor.SetConversationTargets(elder.Position+Vector3.up*1.18f,ash);
                elder.actor.SetConversationTargets(p.Position+Vector3.up*1.18f,ash);
                if(!held && talkProgress>.55f) {held=true;Say("梶「弟の顔、ここに映してくれたら四人とも引かす」",5);Mark("kaji-held");}
            }
            return;
        }
        Vector3 at=p.destination;
        if(p.duty==Duty.Follow) {
            // A staggered grouping leaves the shoulder camera and the doorway open.
            var offset=new Vector3(index%2==0?-1.75f:1.75f,0,-1.7f-(index/2)*1.05f);
            at=player.Position+offset;
            if(player.Position.z< -6.3f && player.Position.z> -9)at.x=Mathf.Clamp(at.x,-.95f,.95f);
            at.x=Mathf.Clamp(at.x,-7.4f,7.4f);at.z=Mathf.Clamp(at.z,-13,8.05f);
        }
        if(Vector3.Distance(p.Position,at)>.25f) {MovePerson(p,at,p.duty==Duty.Rest?3.6f:3.1f,dt);return;}
        if(p.duty==Duty.Rest) {p.hp=Mathf.Min(100,p.hp+dt*3.2f); Motion(p,"idle");return;}
        if(phase!=Phase.Floor && phase!=Phase.Chase) {Motion(p,"idle");return;}
        Targets();
        Person near=null;float range=p.duty==Duty.Guard?7.9f:4.8f;
        foreach(var target in combatants) {
            float d=Vector3.Distance(p.Position,target.Position);
            if(d<range && ClearBetween(p,target)){range=d;near=target;}
        }
        if(near!=null) {
            Face(p,near.Position);
            p.actor.SetAttentionTarget(near.Position+Vector3.up*1.56f);
            if(clock>=p.cooldown) {
                p.cooldown=clock+1.5f+index*.13f;
                near.hp=Mathf.Max(0,near.hp-(p.duty==Duty.Guard?11:5));
                if(near==boss)bossHp=near.hp;
                if(near.hp<=0 && near!=brother)Act(near,"fall");
                Act(p,"shoot"); Trace(p,near.Position+Vector3.up*1.15f,false); sound.Cue("distant");
            } else if(clock-p.lastAction>.28f)Motion(p,"guard");
        } else Motion(p,"guard");
    }

    void UpdateUpstairs(float dt)
    {
        if(accord) {
            foreach(var p in upstairs) {
                if(p.retired)continue;
                MovePerson(p,new Vector3(.45f,0,-11),3.25f,dt);
                if(p.Position.z< -9.75f){p.retired=true;p.root.gameObject.SetActive(false);}
            }
            Vector3 exit=new Vector3(-.45f,0,-11);
            Vector3 meeting=new Vector3(.50f,0,-2f);
            if(elder.Position.y>.35f || elder.Position.z>-.8f){
                MovePerson(elder,meeting,3.2f,dt);
                if(Flat(brother.Position,meeting)>.24f)MovePerson(brother,meeting,1.9f,dt);
                else {Face(brother,elder.Position);Motion(brother,"idle");}
            } else {
                MovePerson(elder,exit,2.55f,dt);
                MovePerson(brother,elder.Position+new Vector3(.65f,0,.16f),2.9f,dt);
            }
            return;
        }
        if(held) {Face(elder,crew[0].Position); Motion(elder,"talk");}
        else Motion(elder,"sit");
        for(int i=0;i<upstairs.Count;i++) {
            var p=upstairs[i]; if(p.hp<=0){Motion(p,"fall");continue;}
            if(!held && (phase==Phase.Floor || phase==Phase.Choice || phase==Phase.Chase) && clock-entranceTime>25+i) {
                if(p.Position.y>.05f || p.Position.z>1.9f)
                    MovePerson(p,new Vector3((i-1.5f)*1.4f,0,.9f),2.25f,dt);
                else Opponent(p,dt);
            } else if(held && p.Position.y<2.8f)
                MovePerson(p,new Vector3((i-1.5f)*1.2f,3.2f,7.55f),2.7f,dt);
            else Motion(p,"idle");
        }
    }

    void Opponent(Person p,float dt)
    {
        if(p.hp<=0) {Motion(p,"fall");return;}
        Person target=player;
        float distance=Vector3.Distance(p.Position,player.Position);
        foreach(var friend in crew) {
            if(friend.hp<=0 || friend.duty==Duty.Attend || friend.duty==Duty.Rest)continue;
            float d=Vector3.Distance(p.Position,friend.Position);
            if(d<distance-.65f){distance=d;target=friend;}
        }
        if(p.watching!=null) {
            if(p.flinchUntil>clock) {p.watching=null; p.cooldown=clock+.5f;return;}
            Face(p,p.mark); p.actor.SetAttentionTarget(p.mark+Vector3.up*1.56f); Motion(p,"aim");
            if(clock<p.signalEnds)return;
            var marked=p.watching; p.watching=null;
            Act(p,"shoot"); Trace(p,p.mark+Vector3.up*1.15f,true); sound.Cue("distant");
            if(Flat(marked.Position,p.mark)<.72f && ClearBetween(p,marked)) {
                marked.hp=Mathf.Max(0,marked.hp-(p==boss?9:4.5f));
                if(marked==player)hitFlash=clock+.17f;
            }
            return;
        }
        Face(p,target.Position); p.actor.SetAttentionTarget(target.Position+Vector3.up*1.56f);
        if(distance>6.2f) {
            var toward=target.Position-p.Position; toward.y=0;
            if(toward.sqrMagnitude>.01f && p.Position.z> -3.5f)
                MovePerson(p,p.Position+toward.normalized, .72f,dt);
            else Motion(p,"guard");
        } else if(clock>=p.cooldown && ClearBetween(p,target)) {
            p.cooldown=clock+(p==boss?1.6f:2.65f)+Mathf.Abs(p.root.GetSiblingIndex()%4)*.19f;
            p.watching=target; p.mark=target.Position;p.signalEnds=clock+(p==boss?.45f:.74f);
            Motion(p,"aim");
        } else if(clock-p.lastAction>.3f) Motion(p,"guard");
    }

    bool ClearBetween(Person from,Person to)
    {
        bool obstruction=Physics.Linecast(from.Position+Vector3.up*1.28f,to.Position+Vector3.up*1.14f,
            out var hit,~0,QueryTriggerInteraction.Ignore);
        return !obstruction || (motor!=null && hit.collider==motor && (to==player || from==player));
    }

    string Interaction()
    {
        if(command)return "";
        if(phase==Phase.Choice) {
            if(escorted && Flat(player.Position,witness)<1.6f && player.Position.y<1) return crew[0].hp<=0?"辰は動けない":held?"弟を中継鏡へ":"辰を二階の梶の席へ";
            if(!escorted && Flat(player.Position,brother.Position)<1.95f && player.Position.y<1) return "弟に肩を貸す";
            if(escapeTime>0 && Vector3.Distance(player.Position,boss.Position)<2.1f) return "兄貴分を追う";
        }
        return "";
    }
    void Interact()
    {
        if(phase!=Phase.Choice)return;
        string verb=Interaction();
        if(verb=="弟に肩を貸す") {
            escorted=true;Face(brother,player.Position); sound.Cue("dial");
            Say("弟「悪いな。あの卓の鏡まで頼む」");Mark("escort");
        } else if(verb=="兄貴分を追う") {
            boss.hp=bossHp=100;Change(Phase.Chase); Say("兄貴分「まだうちの若頭のつもりか」");sound.Cue("choice");
        } else if(verb=="弟を中継鏡へ") {
            if(motor!=null)motor.enabled=false;
            player.root.position=witness+new Vector3(.48f,0,.0f);
            if(motor!=null)motor.enabled=true;
            player.actor.SetMirrorTarget(new Vector3(-2.64f,1.26f,-.04f));
            brother.root.position=witness+new Vector3(-.88f,0,-.09f);
            Face(brother,new Vector3(-3.02f,1.41f,-.22f));
            angle=-14;tilt=8; snapCamera=true; relayCam.enabled=true;
            Change(Phase.Mirror); Say("弟「兄ちゃん……もうええ」",4.2f);sound.Cue("dial");
        } else if(verb=="辰は動けない") Say("中継には辰が要る。兄貴分を追え");
        else if(verb.Length>0) Say("指揮に切り替え、辰に梶との話を任せる");
    }
}

