using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public void Tick(float dt)
        {
            if(!IsReady || Result!=SimResult.Active || dt<=0 || float.IsNaN(dt)) return;
            dt=Mathf.Min(.5f,dt);
            while(dt>.00001f && Result==SimResult.Active)
            {
                float step=Mathf.Min(.08f,dt);
                Advance(step);dt-=step;
            }
        }
        void Advance(float dt)
        {
            state.clock+=dt; state.waveIn-=dt;
            if(state.waveIn<=0)
            {
                state.waveCount++;
                SpawnWave(Mathf.Clamp(2+state.index/3+state.waveCount/4+(int)Level-1,1,9));
                state.waveIn=Route.waveInterval*(Level==Difficulty.Story?1.4f:Level==Difficulty.Hard?.8f:1);
                SoundNotice("接近警報　第"+state.waveCount+"波");
            }
            AlarmAttracted=0;
            PrepareRequestActor();
            UpdateInfrastructure(dt);
            ScreenArea(dt);
            CheckDutySite();
            foreach(var u in state.units)
            {
                if(!u.active) continue;
                var a=Brain(u);
                if(u!=Controlled) u.moving=false;
                a.fireDelay=Mathf.Max(0,a.fireDelay-dt);a.stun=Mathf.Max(0,a.stun-dt);u.stagger=a.stun;
                if(a.impulse.sqrMagnitude>.001f)
                {
                    u.pos=geometry.Move(u.pos,u.pos+a.impulse*dt);
                    a.impulse=Vector3.MoveTowards(a.impulse,Vector3.zero,dt*16);a.hasPath=false;
                }
                if(IsSoldier(u))
                {
                    bool dodging=u.dodgeTime>0;
                    UpdateDodge(u,a,dt);
                    if(u.reload>0)
                    {
                        u.reload=Mathf.Max(0,u.reload-dt);
                        if(u.reload==0) {int take=Mathf.Min(18-u.ammo,u.reserve);u.ammo+=take;u.reserve-=take;}
                    }
                    if(u!=Controlled && a.stun==0 && !dodging) Soldier(u,a,dt);
                }
                else if(IsCivilian(u))
                {
                    if(a.auxiliary)RequestPatient(u);else Civilian(u,a,dt);
                }
                else Infected(u,a,dt);
                u.escortId=a.escort;u.carryingCargo=a.cargo;
            }
            HandleSector();
            bool alive=false;
            foreach(var s in soldiers) if(s.active){alive=true;break;}
            if(!alive || state.dutyFailed || state.vehicle<=0 || Route.population-state.losses<Route.quota || Remaining<=0)
            {
                if(Remaining<=0 && CanDepart) {Depart();return;}
                state.result=(int)SimResult.Defeat;state.controlled=-1;
                SoundNotice(!alive?"全隊員が行動不能":state.dutyFailed?state.dutyFailure:state.vehicle<=0?"輸送車が走行不能":"避難を継続できません"); Save();return;
            }
            if(!state.departureAnnounced && CanDepart)
            {
                state.departureAnnounced=true;
                SoundNotice("出発条件を満たしました。出発できます");
            }
            if(!state.checkpoint && Boarded>=Mathf.CeilToInt(Route.quota*.5f))
            {
                state.checkpoint=true;EvacStorage.Write(CheckpointSlot,state);
            }
            state.autosave+=dt;
            if(state.autosave>=20){state.autosave=0;Save();}
        }

        bool Walk(Unit u,Vector3 destination,float speed,float dt)
        {
            Vector3 goal=Ground(destination);
            if((goal-u.pos).sqrMagnitude<.28f) return true;
            Vector3 delta=PathPoint(u,goal)-u.pos;
            if(delta.sqrMagnitude<.000001f)return false;
            float slowdown=IsSoldier(u) && u.hp<40?.72f:1f;
            float distance=Mathf.Min(delta.magnitude,speed*slowdown*dt);
            u.pos=geometry.Move(u.pos,u.pos+delta.normalized*distance);
            u.yaw=Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg;u.moving=true;
            return (goal-u.pos).sqrMagnitude<.28f;
        }

        Vector3 PathPoint(Unit u,Vector3 goal)
        {
            var a=Brain(u);
            if(!a.hasPath || FlatSq(goal,a.pathGoal)>.25f || FlatSq(u.pos,a.waypoint)<.003f)
            {
                a.pathGoal=goal;a.waypoint=geometry.Waypoint(u.pos,goal);a.hasPath=true;
            }
            return a.waypoint;
        }

        void Soldier(Unit u,ActorMemory a,float dt)
        {
            var group=state.squads[u.squad];var order=(SquadOrder)group.order;
            if(TravelToAlarm(u,dt))return;
            if(WorkRequest(u,a,dt))return;
            if(a.escort>=0) {Guide(u,a,dt);return;}
            if(a.cargo) {Engineer(u,a,dt);return;}
            if(!group.assigned || (order==SquadOrder.Engineer && !SectorDispatched(u.squad)))
            {
                if(state.index==0) return;
                if(order!=SquadOrder.Guard) return;
            }
            if(order==SquadOrder.Supply)
            {
                if(Walk(u,Route.depot,3.6f,dt)) Supply(u,dt);
                return;
            }
            if(a.fireDelay==0 && u.reload<=0 && u.ammo>0)
            {
                float radius=order==SquadOrder.Guard?(state.index==6 && RequestStatus==RequestState.Completed?28:21):14;
                var target=NearestThreat(u.pos,radius);
                if(target!=null) HitShot(u,target,(target.pos-u.pos).normalized,true);
            }
            if(u.ammo==0) StartReload(u);
            if(group.assigned && a.route==0 && order!=SquadOrder.Move && order!=SquadOrder.Guard)
            {
                if(!Walk(u,group.destination,3.65f,dt)) return;
                a.route=1;
            }
            if(order==SquadOrder.Guide) Guide(u,a,dt);
            else if(order==SquadOrder.Engineer) Engineer(u,a,dt);
            else Walk(u,group.destination+new Vector3((u.id%3-1)*1.15f,0,(u.id%2)*.65f),3.6f,dt);
        }

        void SpawnWave(int count)
        {
            int live=0;
            foreach(var h in threats) if(h.active)live++;
            for(int i=0;i<count && live+i<150;i++)
            {
                float offset=state.waveCount%3==2 ? 7 : state.waveCount%3==1 ? -6 : 0;
                Vector3 p=Route.entrance+new Vector3(offset+(state.Draw()-.5f)*6,0,(state.Draw()-.5f)*3);
                var h=Spawn(UnitKind.Infected,p,"感染者",-1);
                float roll=state.Draw();
                h.variant=state.index>=2 && roll>.84f?2:roll<.27f?1:0;
                h.maxHp=h.hp=h.variant==2?145:h.variant==1?53:73;
            }
        }

        Unit NearestThreat(Vector3 p,float range)
        {
            Unit nearest=null;float best=range*range;
            foreach(var e in threats)
            {
                if(!e.active)continue;
                float d=FlatSq(p,e.pos);
                if(d<best && geometry.LineClear(p+Vector3.up*1.5f,e.pos+Vector3.up)){best=d;nearest=e;}
            }
            return nearest;
        }

        void Infected(Unit e,ActorMemory a,float dt)
        {
            e.visible=false;e.distracted=false;
            foreach(var s in soldiers)
                {
                    float sight=s.squad==0 && state.index==6 && RequestStatus==RequestState.Completed ? 31 : 24;
                    if(s.active && FlatSq(e.pos,s.pos)<sight*sight && geometry.LineClear(s.pos+Vector3.up*1.5f,e.pos+Vector3.up))
                    {e.visible=true;e.lastSeen=e.pos;e.lastSeenAt=Elapsed;break;}
                }
            if(a.stun>0) {e.windup=0;a.preparingCharge=false;a.chargeTime=0;return;}
            if(a.chargeTime>0){AdvanceCharge(e,a,dt);return;}
            var target=Find(a.target);
            a.lostTime-=dt;
            if((target!=null && !target.active) || a.lostTime<=0)
            {
                float best=18*18;
                target=null;
                foreach(var s in state.units)
                {
                    if(!s.active || s.kind==UnitKind.Infected)continue;
                    float d=FlatSq(s.pos,e.pos)*(IsSoldier(s)?.72f:1f);
                    if(d<best) {target=s;best=d;}
                }
                a.target=target==null?-1:target.id;
                a.lostTime=.55f+state.Draw()*.35f;
            }
            bool diverted=DivertedByAlarm(e,a,target);
            e.distracted=diverted;
            if(diverted)AlarmAttracted++;
            Vector3 goal=diverted?AlarmApproach(e):target==null?Route.exit:target.pos;
            float range=target==null?2.9f:1.45f;
            if(e.windup>0)
            {
                e.windup=Mathf.Max(0,e.windup-dt);
                if(e.windup==0)
                {
                    if(a.preparingCharge)
                    {
                        a.preparingCharge=false;a.chargeTime=.45f;return;
                    }
                    if(FlatSq(goal,e.pos)<(range+.35f)*(range+.35f))
                    {
                        float rate=Level==Difficulty.Story?.56f:Level==Difficulty.Hard?1.45f:1;
                        if(target==null)state.vehicle=Mathf.Max(0,state.vehicle-4*rate);
                        else Damage(target,(e.variant==2?18:10)*rate,target.pos-e.pos);
                    }
                    a.fireDelay=e.variant==1?.85f:1.22f;
                }
                return;
            }
            float distanceSq=FlatSq(goal,e.pos);
            if(!diverted && e.variant==1 && target!=null && a.fireDelay==0 && distanceSq>=9 && distanceSq<=42 &&
                geometry.LineClear(e.pos+Vector3.up,target.pos+Vector3.up))
            {
                a.chargeHeading=(goal-e.pos).normalized;
                e.yaw=Mathf.Atan2(a.chargeHeading.x,a.chargeHeading.z)*Mathf.Rad2Deg;
                a.preparingCharge=true;e.windup=.72f;return;
            }
            if(diverted && distanceSq<.36f)return;
            if(!diverted && distanceSq<range*range)
            {
                if(a.fireDelay==0) e.windup=e.variant==2?.86f:e.variant==1?.34f:.56f;
                return;
            }
            float speed=e.variant==1?3.28f:e.variant==2?1.7f:2.05f;
            Vector3 drift=Vector3.zero;
            foreach(var h in threats)
            {
                if(h==e || !h.active)continue;
                Vector3 difference=e.pos-h.pos;
                if(difference.sqrMagnitude>0 && difference.sqrMagnitude<.85f)
                {
                    drift+=difference.normalized*(1-Mathf.Min(1,difference.magnitude))*.95f;
                    if(h.stagger>.28f && difference.sqrMagnitude<.2f && e.variant!=2)
                    {a.stun=.21f;return;}
                }
            }
            if(Rail && (PowerMask&4)!=0 && Mathf.Abs(e.pos.z-Route.gate.z)<3.5f) speed*=.42f;
            Vector3 waypoint=PathPoint(e,goal);
            Vector3 velocity=((waypoint-e.pos).normalized+drift).normalized;
            float stride=Mathf.Min(speed*dt,(waypoint-e.pos).magnitude);
            e.pos=geometry.Move(e.pos,e.pos+velocity*stride);
            if(velocity.sqrMagnitude>.01f) {e.yaw=Mathf.Atan2(velocity.x,velocity.z)*Mathf.Rad2Deg;e.moving=true;}
        }

        void AdvanceCharge(Unit e,ActorMemory a,float dt)
        {
            float step=Mathf.Min(dt,a.chargeTime);
            var previous=e.pos;
            e.pos=geometry.Move(previous,previous+a.chargeHeading*(12f*step));
            e.moving=true;a.chargeTime=Mathf.Max(0,a.chargeTime-dt);
            var target=Find(a.target);
            if(target!=null && target.active && FlatSq(e.pos,target.pos)<1.1f*1.1f)
            {
                float damage=Level==Difficulty.Hard?22:Level==Difficulty.Story?9:15;
                Damage(target,damage,a.chargeHeading);a.chargeTime=0;
            }
            if(FlatSq(previous,e.pos)<step*step)a.chargeTime=0;
            if(a.chargeTime<=0){a.fireDelay=1.8f;a.stun=.28f;a.hasPath=false;}
        }

        void Damage(Unit u,float amount,Vector3 direction)
        {
            direction.y=0;
            if(direction.sqrMagnitude>.001f)u.lastHitDirection=direction.normalized;
            u.hp=Mathf.Max(0,u.hp-amount);
            if(IsSoldier(u))u.wounded=u.hp<80;
            if(IsCivilian(u) && u.hp>0 && u.hp<52) {u.wounded=true;Brain(u).injured=true;}
            if(u.hp>0)return;
            if(u.id==AlarmActorId)state.alarmDispatch=0;
            Unlink(u);u.active=false;u.moving=false;u.windup=0;
            if(Brain(u).requestCargo)
            {
                Brain(u).requestCargo=false;Brain(u).cargo=false;u.carryingCargo=false;
                state.requestDropped=true;state.requestDropPosition=u.pos;state.requestCarrier=-1;
            }
            if(u.kind==UnitKind.Infected)state.kills++;
            else if(IsCivilian(u))
            {
                if(Brain(u).auxiliary)
                {
                    state.requestState=(int)RequestState.Unfinished;
                    SoundNotice("追加要請の救助を続けられません");
                }
                else
                {
                    state.losses++;
                    if(DutyLossPreventsCompletion(u))
                    {
                        state.dutyFailed=true;
                        state.dutyFailure=u.name==DutyStage.required ? u.name+"を救出できませんでした" : "必要な人数を収容できません";
                    }
                }
            }
            else {if(u.id==state.controlled)Release();SoundNotice(u.name+"が行動不能");}
        }

        void HitShot(Unit shooter,Unit target,Vector3 direction,bool automated)
        {
            shooter.ammo--;shooter.shots++;
            Brain(shooter).fireDelay=automated?.64f:.17f;
            if(automated)shooter.yaw=Mathf.Atan2(direction.x,direction.z)*Mathf.Rad2Deg;
            if(target==null)return;
            float damage=automated?32:47;
            if(automated && shooter.hp<50) damage*=.84f;
            Damage(target,damage,direction);
            var a=Brain(target); a.stun=target.variant==2?.15f:.33f;
            a.impulse=new Vector3(direction.x,0,direction.z).normalized*(target.variant==2?1.7f:3.4f);
            target.stagger=a.stun;target.windup=0;a.chargeTime=0;a.preparingCharge=false;
        }

        bool StartReload(Unit u)
        {
            if(u==null || u.reload>0 || u.ammo>=18 || u.reserve<=0 || Brain(u).escort>=0 || Brain(u).cargo)return false;
            u.reload=1.55f;return true;
        }
        public bool Reload() => Result==SimResult.Active && StartReload(Controlled);
        public void Move(Vector3 worldDirection,float yaw,float dt)
        {
            Unit u=Controlled;
            if(u==null || Result!=SimResult.Active)return;
            var a=Brain(u);
            if(u.dodgeTime>0){u.yaw=yaw;return;}
            worldDirection.y=0;worldDirection=Vector3.ClampMagnitude(worldDirection,1);
            float speed=a.escort>=0?2.7f:a.cargo?3f:5.3f;
            if(u.hp<40)speed*=.72f;
            u.pos=geometry.Move(u.pos,u.pos+worldDirection*speed*Mathf.Clamp(dt,0,.25f));
            u.yaw=yaw;u.moving=worldDirection.sqrMagnitude>.001f;
        }
        public bool Dodge(Vector3 worldDirection)
        {
            var u=Controlled;
            if(u==null || Result!=SimResult.Active || u.dodgeTime>0 || u.hp<40)return false;
            var a=Brain(u);
            float cost=u.wounded?.68f:.56f;
            if(a.escort>=0 || a.cargo || u.stamina<cost || a.stun>0)return false;
            worldDirection.y=0;
            if(worldDirection.sqrMagnitude<.01f)
                worldDirection=Quaternion.Euler(0,u.yaw+90,0)*Vector3.forward;
            a.dodgeVelocity=worldDirection.normalized*(u.wounded?8.8f:11.6f);
            u.stamina-=cost;u.dodgeTime=.25f;a.exhausted=u.wounded?1.65f:1.2f;
            a.hasPath=false;u.moving=true;
            return true;
        }
        void UpdateDodge(Unit u,ActorMemory a,float dt)
        {
            if(u.dodgeTime>0)
            {
                float step=Mathf.Min(dt,u.dodgeTime);
                u.pos=geometry.Move(u.pos,u.pos+a.dodgeVelocity*step);
                u.dodgeTime=Mathf.Max(0,u.dodgeTime-step);
                u.moving=true;
            }
            if(a.exhausted>0){a.exhausted=Mathf.Max(0,a.exhausted-dt);return;}
            u.stamina=Mathf.Min(1,u.stamina+dt*(u.wounded?.12f:.19f));
        }
        public bool Shoot(Vector3 aimDirection)
        {
            var s=Controlled;
            if(s==null || s.dodgeTime>0 || Result!=SimResult.Active || s.reload>0 || s.ammo<=0 || Brain(s).escort>=0 || Brain(s).cargo || Brain(s).fireDelay>0)return false;
            LastShotHit=false;
            Vector3 aim=aimDirection.normalized;
            if(aim.sqrMagnitude<.9f)return false;
            Vector3 eye=s.pos+Vector3.up*1.52f;
            Unit target=null;float best=43;
            foreach(var e in threats)
            {
                if(!e.active)continue;
                Vector3 delta=e.pos+Vector3.up*1.13f-eye;
                float along=Vector3.Dot(delta,aim);
                if(along<=0 || along>best)continue;
                Vector3 off=delta-along*aim;
                float radius=e.variant==2?.68f:.52f;
                if(off.x*off.x+off.z*off.z>radius*radius || Mathf.Abs(off.y)>1.0f)continue;
                if(!geometry.LineClear(eye,eye+aim*along))continue;
                best=along;target=e;
            }
            HitShot(s,target,aim,false);LastShotHit=target!=null;return true;
        }

        void Supply(Unit u,float dt)
        {
            var a=Brain(u);a.supplyClock+=dt;
            if(a.supplyClock<1)return;
            a.supplyClock=0;
            int rounds=Mathf.Min(24,Mathf.Min(90-u.reserve,state.depotRounds));
            if(rounds>0){u.reserve+=rounds;state.depotRounds-=rounds;}
            if(u.hp<u.maxHp && (state.medPacks>0 || (state.built && state.site==1)))
            {
                bool clinic=state.built && state.site==1;
                if(!clinic)state.medPacks--;
                u.hp=Mathf.Min(u.maxHp,u.hp+(clinic?12:18));u.wounded=u.hp<80;
            }
            if(u.medkits==0 && state.medPacks>0){state.medPacks--;u.medkits++;}
            if(u.ammo<18)StartReload(u);            if(state.built && state.site==1)
            {
                foreach(var s in soldiers)
                    if(!s.active && FlatSq(u.pos,s.pos)<16) {s.hp=40;s.active=true;SoundNotice(s.name+"が復帰");break;}
            }
        }
    }
}
