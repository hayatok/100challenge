#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        internal int[] MakeAlarmTrial(Unit operatorUnit)
        {
            var victim=soldiers.Find(u=>u!=operatorUnit);
            operatorUnit.pos=AlarmPoint;victim.pos=Ground(AlarmPoint+Vector3.left*14);
            var inner=Spawn(UnitKind.Infected,AlarmPoint+Vector3.left*7,"near",-1);
            var outer=Spawn(UnitKind.Infected,new Vector3(-13,0,-19),"far",-1);
            var close=Spawn(UnitKind.Infected,victim.pos+Vector3.right*1.1f,"in contact",-1);
            foreach(var e in new[]{inner,outer,close}) {Brain(e).target=victim.id;Brain(e).lostTime=30;}
            return new[]{inner.id,outer.id,close.id,victim.id};
        }

        internal void FillStressWave() {SpawnWave(150);}
        internal void BoardQuotaBeforeFinalSector()
        {
            state.boarded=Mission.quota-1;
            var c=state.units.Find(u=>u.kind==UnitKind.Civilian && u.active);
            Board(c);
        }
        internal Unit PlaceRunnerTrial(Unit s)
        {
            s.pos=Ground(new Vector3(-4,0,0));
            var runner=Spawn(UnitKind.Infected,s.pos+Vector3.forward*5,"runner",-1);
            runner.variant=1;var a=Brain(runner);a.target=s.id;a.lostTime=3;
            return runner;
        }
    }

    public static class SimulationVerification
    {
        static void Check(bool ok,string message)
        {
            if(!ok)throw new InvalidOperationException(message);
        }

        public static string Run()
        {
            var folder=Path.Combine(Path.GetTempPath(),"evac-sim-test-"+Guid.NewGuid().ToString("N"));
            string previous=EvacStorage.TestDirectory;
            EvacStorage.TestDirectory=folder;
            var report=new StringBuilder();
            try
            {
                foreach(Difficulty level in new[]{Difficulty.Standard,Difficulty.Hard,Difficulty.Story})
                {
                    EvacStorage.TestDirectory=Path.Combine(folder,level.ToString());
                    report.AppendLine(level.ToString());
                    RunCampaign(level,report);
                }
                FirstPersonRescue(report);
                FailureCheckpoint(report);
                var early=new GameSim();early.StartMission(0,Difficulty.Standard);
                early.BoardQuotaBeforeFinalSector();
                Check(early.Boarded==early.Mission.quota && !early.CanDepart && !early.Notice.Contains("出発できます"),"Quota alone cannot announce departure");
                report.AppendLine("Departure signal waits for the final sector and its rescue conditions.");
                VerifyDefense(report);
                VerifyDodge(report);
                VerifyRush(report);
                VerifyAlarm(report);
                DutyVerification.Run(report);
                VerifyCrowd(report);
                return report.ToString();
            }
            finally
            {
                EvacStorage.TestDirectory=previous;
                if(Directory.Exists(folder))Directory.Delete(folder,true);
            }
        }

        static void RunCampaign(Difficulty difficulty,StringBuilder report)
        {
                var game=new GameSim();game.StartMission(0,difficulty);
                for(int index=0;index<8;index++)
                {
                    var mission=game.Mission;
                    if(difficulty==Difficulty.Standard)
                    {
                        if(index==1)
                        {
                            Check(game.Units.First(u=>u.name=="岡田").hp==51,"Named injury carried forward");
                            Check(game.Units.First(u=>u.name=="佐藤").hp==100,"Different soldier remained healthy");
                        }
                        VerifyRequest(ref game,index);
                    }
                    else if(difficulty==Difficulty.Hard && index==0) Check(game.DeclineRequest() && !game.AcceptRequest(),"Request decline");
                    else if(difficulty==Difficulty.Hard && index==6) Check(game.AcceptRequest(),"Optional request left pending");
                    game.Order(0,index==0?SquadOrder.Guide:SquadOrder.Guard,index==0?mission.assembly:mission.gate+Vector3.forward*5);
                    if(index>0)
                    {
                        game.Order(1,SquadOrder.Guide,mission.assembly);
                        game.Order(2,SquadOrder.Engineer,mission.works);
                    }
                    if(index==4)
                    {
                        Check(!game.SetPower(PowerCircuit.Barrier,true),"Third circuit energized before restoration");
                        game.SetPower(PowerCircuit.Drain,false);
                        Check(game.SetPower(PowerCircuit.Barrier,true),"Reallocation failed");
                        game.SetPower(PowerCircuit.Barrier,false);game.SetPower(PowerCircuit.Drain,true);
                    }
                    if(index==3) Check(game.Build(Facility.Clinic),"Clinic order");
                    int rescuedAtStart=game.CampaignRescued;
                    int deployed=-1;
                    for(int step=0;step<9000 && game.Result==SimResult.Active;step++)
                    {
                        if(deployed!=game.Sector)
                        {
                            deployed=game.Sector;
                            if(index>0)game.Order(0,SquadOrder.Guard,game.ActiveGate);
                            game.Order(index==0?0:1,SquadOrder.Guide,game.ActiveAssembly);
                            if(index>0)game.Order(2,SquadOrder.Engineer,game.ActiveWorks);
                        }
                        game.Tick(.1f);
                        // Enter the same simulation, spend an actual round, then save and resume mid-reload.
                        if(index==1 && step==5)
                        {
                            var s=game.Units.First(x=>x.kind==UnitKind.Soldier);
                            Check(game.Possess(s.id),"Possession");
                            Check(game.Shoot(Vector3.back) && game.Reload(),"FPS firing and reload");
                            game.Tick(.1f);
                            int ammo=s.ammo;float reload=s.reload;int who=s.id;
                            Check(game.Save(),"Suspend");
                            game=new GameSim();
                            Check(game.Load() && game.Controlled.id==who && game.Controlled.ammo==ammo &&
                                Mathf.Abs(game.Controlled.reload-reload)<.001f,"Mid-action save");
                            game.Release();
                        }
                        if(game.Notice.Contains("出発できます"))Check(game.CanDepart,"Premature departure notice");
                        if(game.CanDepart)
                        {
                            if(difficulty==Difficulty.Standard && index==0)
                            {
                                var injured=game.Units.First(u=>u.name=="岡田");injured.hp=51;injured.wounded=true;
                                var healthy=game.Units.First(u=>u.name=="佐藤");healthy.hp=100;healthy.wounded=false;
                            }
                            Check(game.Depart(),"Departure");break;
                        }
                    }
                    Check(game.Result==SimResult.Victory,"Mission "+(index+1)+" failed: "+game.Objective+" sector="+game.Sector+" boarded="+game.Boarded+" delivered="+game.Delivered+" fails="+game.Lost+" passage="+game.PassageOpen);
                    Check(game.Units.Count(c=>c.boarded)==game.Boarded,"Vehicle count mismatch");
                    Check(game.CampaignRescued==rescuedAtStart+game.Boarded && game.IsComplete(index),"Campaign transfer");
                    report.AppendLine("Mission "+(index+1)+" "+game.Boarded+"/"+mission.population+", "+game.Elapsed.ToString("0.0")+"s, supplies "+game.Stock+", kills "+game.Kills);
                    if(index<7) Check(game.Next(),"Next operation");
                }
                Check(!game.Next() && game.Unlocked==7,"Ending");
                if(difficulty==Difficulty.Standard)
                {
                    Check(game.CompletedRequests==8,"All optional requests recorded at ending");
                    var archived=new GameSim();
                    Check(archived.CompletedRequests==8 && archived.RequestOutcome(7)==RequestState.Completed,"Request archive restored");
                    report.AppendLine("Eight optional assignments completed, named injury carried across missions, and all eight ending records restored.");
                }
                if(difficulty==Difficulty.Hard)Check(game.RequestOutcome(0)==RequestState.Declined && game.RequestOutcome(6)==RequestState.Unfinished,"Declined and unfinished ending records");
                var replay=new GameSim();
                Check(replay.Load() && replay.Result==SimResult.Victory && replay.Mission.index==7,"Ending reload");
                replay.Retry(); Check(replay.Mission.index==7 && replay.Elapsed==0,"Replay");
        }

        static void VerifyRequest(ref GameSim game,int index)
        {
            Check(game.AcceptRequest() && !game.DeclineRequest(),"Accept and commit optional request");
            if(index==1)
            {
                var worker=game.Units.First(u=>u.kind==UnitKind.Soldier && u.squad==2);
                Check(game.Possess(worker.id),"Optional cargo FPS");
                for(int item=0;item<2;item++)
                {
                    WalkTo(game,game.RequestPoint);
                    Check(game.Interact() && game.Controlled.carryingCargo,"Collect named supply");
                    if(item==0)
                    {
                        Check(game.Save(),"Optional cargo suspend");game=new GameSim();
                        Check(game.Load() && game.Controlled.carryingCargo && game.RequestStatus==RequestState.Accepted,"Optional cargo restore");
                    }
                    WalkTo(game,game.RequestPoint);
                    Check(game.Interact() && !game.Controlled.carryingCargo,"Deliver named supply");
                }
                game.Release();
            }
            else
            {
                int lastOrder=-1;
                Vector3 assigned=Vector3.positiveInfinity;
                for(int i=0;i<1400 && game.RequestStatus==RequestState.Accepted && game.Result==SimResult.Active;i++)
                {
                    var point=game.RequestPoint;
                    if((point-assigned).sqrMagnitude>1 || lastOrder!=(int)game.RequestOrder)
                    {
                        assigned=point;lastOrder=(int)game.RequestOrder;
                        game.Order(game.RequestSquad,game.RequestOrder,point);
                    }
                    game.Tick(.1f);
                }
            }
            Check(game.RequestStatus==RequestState.Completed,"Request "+index+" "+game.RequestObjective);
        }
        static void VerifyCrowd(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(4,Difficulty.Standard);game.FillStressWave();
            Check(game.Units.Count(c=>c.kind==UnitKind.Infected && c.active)==150,"150 visible simulation actors");
            float[] samples=new float[90];
            var clock=new System.Diagnostics.Stopwatch();
            var roster=game.Units.Where(c=>c.kind==UnitKind.Soldier).ToArray();
            for(int i=0;i<samples.Length;i++)
            {
                clock.Restart();game.Possess(roster[i%roster.Length].id);
                game.Tick(1f/30);game.Release();clock.Stop();
                samples[i]=(float)clock.Elapsed.TotalMilliseconds;
            }
            Array.Sort(samples);
            report.AppendLine("150 infected, simulation-only Editor CPU tick plus handoff: p95 "+samples[85].ToString("0.00")+" ms, max "+samples[89].ToString("0.00")+" ms.");
        }
        static void VerifyDodge(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(0,Difficulty.Standard);
            var soldier=game.Units.First(x=>x.kind==UnitKind.Soldier);
            Check(game.Possess(soldier.id),"Dodge entry");
            var origin=soldier.pos;
            Check(game.Dodge(Vector3.right),"Dodge accepted");
            game.Tick(.08f);
            float stamina=soldier.stamina,remaining=soldier.dodgeTime;
            Check(stamina<.5f && remaining>0 && Vector3.Distance(origin,soldier.pos)>.4f,"Dodge movement and exertion");
            int id=soldier.id;game.Release();Check(game.Possess(id),"Dodge handoff");
            Check(game.Controlled.stamina==stamina && !game.Dodge(Vector3.right),"Handoff cannot refresh");
            Check(game.Save(),"Dodge save");
            var restored=new GameSim();Check(restored.Load(),"Dodge load");
            var u=restored.Controlled;
            Check(u.id==id && Mathf.Abs(u.stamina-stamina)<.001f && Mathf.Abs(u.dodgeTime-remaining)<.001f,"Dodge state restored");
            restored.Tick(.4f);Check(!restored.Dodge(Vector3.right),"Exhausted cannot dodge");
            for(int i=0;i<60;i++)restored.Tick(.1f);
            Check(u.stamina>.98f,"Personal recovery");
            WalkTo(restored,new Vector3(-15.2f,0,-25));
            Check(restored.Dodge(Vector3.left),"Dodge toward street wall");restored.Tick(.3f);
            Check(u.pos.x>=-15.401f,"Dodge respects collision boundary");
            for(int i=0;i<60;i++)restored.Tick(.1f);
            u.hp=30;u.wounded=true;
            Check(!restored.Dodge(Vector3.right),"Severe wound prevents dodge");
            u.hp=100;u.wounded=false;
            WalkTo(restored,restored.ActiveCache);
            Check(restored.Interact() && u.carryingCargo && !restored.Dodge(Vector3.right),"Load blocks dodge");
            report.AppendLine("Dodge displacement, exhaustion, save, handoff, recovery, injury, cargo and wall collision passed.");
        }

        static void VerifyRush(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(0,Difficulty.Standard);
            var soldier=game.Units.First(u=>u.kind==UnitKind.Soldier);
            game.Possess(soldier.id);
            var runner=game.PlaceRunnerTrial(soldier);
            game.Tick(.04f);
            Check(runner.windup>0 && game.Save(),"Rush warning");
            float health=soldier.hp;
            var baseline=new GameSim();Check(baseline.Load(),"Rush comparison");
            Check(game.Dodge(Vector3.right),"Dodge telegraphed charge");
            for(int i=0;i<16;i++){baseline.Tick(.1f);game.Tick(.1f);}
            Check(baseline.Controlled.hp<health && soldier.hp==health,"Untreated charge hit; lateral dodge missed");
            report.AppendLine("Telegraphed runner struck a stationary soldier; a lateral dodge avoided the same charge.");
        }
        static void VerifyAlarm(StringBuilder report)
        {
            var names=new System.Collections.Generic.HashSet<string>();
            foreach(int index in new[]{0,2,4,6})
            {
                var game=new GameSim();game.StartMission(index,Difficulty.Story);
                Check(names.Add(game.AlarmName),"Each district has a named device");
                var soldier=game.Units.First(u=>u.kind==UnitKind.Soldier);
                game.Possess(soldier.id);
                Check(!game.ActivateAlarm(),"Cannot trigger from the depot");
                game.Release();game.Order(0,SquadOrder.Move,game.ActiveDepot);
                Check(game.DispatchAlarm(0) && game.AlarmSerial==0,"Dispatch cannot trigger remotely");
                int id=game.AlarmActorId;var start=game.Find(id).pos;
                game.Tick(.35f);
                Check(Vector3.Distance(start,game.Find(id).pos)>.15f && game.AlarmSerial==0,"Dispatched operator walks");
                Check(game.CancelAlarmDispatch() && game.AlarmActorId<0,"Recall before activation");
                Check(game.DispatchAlarm(0),"Redispatch operator");id=game.AlarmActorId;
                game.Possess(id);var held=game.Controlled.pos;
                game.Tick(.35f);
                Check(game.Controlled.pos==held && game.AlarmActorId==id,"FPS retains physical control during dispatch");
                Check(game.Save(),"Suspend dispatch");
                var resumed=new GameSim();Check(resumed.Load() && resumed.AlarmActorId==id && resumed.Controlled.id==id,"Dispatch restored");
                resumed.Release();
                for(int i=0;i<240 && resumed.AlarmSerial==0;i++)resumed.Tick(.1f);
                Check(resumed.AlarmSerial==1 && resumed.AlarmActorId<0 &&
                    Vector3.Distance(resumed.Find(id).pos,resumed.AlarmPoint)<2.6f,"Only operator arrival sounds device");
                Check(resumed.OrderFor(0)==SquadOrder.Move && !resumed.DispatchAlarm(0),"Original orders and cooldown");
                for(int i=0;i<24;i++)resumed.Tick(.1f);
                Check(Vector3.Distance(resumed.Find(id).pos,resumed.AlarmPoint)>4,"Operator returns to previous assignment");
                if(index==0)
                {
                    resumed.Possess(id);WalkTo(resumed,resumed.AlarmPoint);
                    Check(!resumed.ActivateAlarm(),"A second hand cannot bypass cooldown");
                    for(int wait=0;wait<320 && resumed.Result==SimResult.Active && resumed.AlarmCooldownRemaining>0;wait++)
                        resumed.Tick(.1f);
                    Check(resumed.ActivateAlarm() && resumed.AlarmSerial==2,"Reuse after cooldown");
                }
            }

            var active=new GameSim();active.StartMission(0,Difficulty.Standard);
            var operatorUnit=active.Units.First(u=>u.kind==UnitKind.Soldier);
            active.Possess(operatorUnit.id);
            int[] actors=active.MakeAlarmTrial(operatorUnit);
            Check(active.Save(),"Baseline alarm fixture");
            var quiet=new GameSim();Check(quiet.Load(),"Quiet comparison");
            Check(active.InteractionHint.Contains(active.AlarmName) && active.Interact(),"Physical FPS alarm switch");
            for(int i=0;i<25;i++){active.Tick(.1f);quiet.Tick(.1f);}
            Check(active.Find(actors[0]).distracted && !active.Find(actors[1]).distracted &&
                !active.Find(actors[2]).distracted,"Only audible walkers out of melee divert");
            Check(active.Find(actors[0]).pos.x>quiet.Find(actors[0]).pos.x+5 &&
                active.Find(actors[3]).hp<100,"Divergence from control and close attack preserved");
            var remaining=active.AlarmActiveRemaining;int heard=active.AlarmAttracted;
            active.Release();active.Possess(operatorUnit.id);Check(active.Save(),"Save live sound");
            var loaded=new GameSim();Check(loaded.Load() && Mathf.Abs(loaded.AlarmActiveRemaining-remaining)<.001f &&
                loaded.AlarmAttracted==heard && loaded.AlarmSerial==1 && !loaded.ActivateAlarm(),"No replay or timer reset on reload");
            for(int i=0;i<55;i++)loaded.Tick(.1f);
            Check(loaded.AlarmActiveRemaining==0 && loaded.AlarmCooldownRemaining>0 && !loaded.Find(actors[0]).distracted,"Alarm expires and pursuit resumes");
            report.AppendLine("All four field alarms: physical dispatch, recall, return to orders, FPS operation, range, engaged enemies, timed diversion and save continuity passed.");
        }
        static void VerifyDefense(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(2,Difficulty.Hard);
            var s=game.Units.First(x=>x.kind==UnitKind.Soldier);
            Check(game.Possess(s.id),"Defense entry");
            WalkTo(game,game.ActiveGate);
            var enemy=game.Units.Where(x=>x.kind==UnitKind.Infected && x.active)
                .OrderBy(x=>(x.pos-s.pos).sqrMagnitude).First();
            Vector3 aim=(enemy.pos+Vector3.up*1.13f)-(s.pos+Vector3.up*1.52f);
            int rounds=s.ammo;
            Check(game.Shoot(aim) && game.LastShotHit && s.ammo==rounds-1 && enemy.stagger>0,"Aimed impact and stagger");
            float health=enemy.hp;
            game.Release();game.Tick(.1f);
            Check(game.Possess(s.id) && enemy.hp<=health && s.ammo<=rounds-1,"Transfer continuity");
            report.AppendLine("Hard difficulty: aimed shot, impact, stagger and handoff passed.");
        }
        static void FirstPersonRescue(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(0,Difficulty.Story);
            game.Order(0,SquadOrder.Move,game.Mission.depot);
            var soldier=game.Units.First(x=>x.kind==UnitKind.Soldier);
            Check(game.Possess(soldier.id),"FPS-only entry");
            int deployed=-1;bool carried=false;
            for(int step=0;step<2300 && !game.CanDepart;step++)
            {
                if(deployed!=game.Sector)
                {
                    deployed=game.Sector;WalkTo(game,game.ActiveAssembly);
                    var casualty=game.Units.FirstOrDefault(x=>x.kind==UnitKind.Civilian && x.active && x.wounded);
                    if(casualty!=null)
                    {
                        WalkTo(game,casualty.pos);
                        Check(game.Interact() && soldier.escortId==casualty.id,"Shoulder rescue");
                        Check(!game.Shoot(Vector3.forward) && !game.Dodge(Vector3.right),"Both hands occupied");
                        WalkTo(game,game.ActiveGate);WalkTo(game,game.ActiveExit);
                        Check(casualty.boarded,"Carried civilian boarded");
                        carried=true;
                    }
                }
                game.Tick(.1f);
            }
            Check(carried && game.Depart(),"FPS-only departure");            report.AppendLine("FPS-only mission 1: all three sectors, shoulder carry, route crossing and departure passed; squad remained at depot.");
        }
        static void WalkTo(GameSim game,Vector3 destination)
        {

            for(int i=0;i<420;i++)
            {
                var offset=destination-game.Controlled.pos;
                if(offset.sqrMagnitude<.25f)return;
                Vector3 delta=game.RouteWaypoint(game.Controlled.pos,destination)-game.Controlled.pos;
                game.Move(Vector3.ClampMagnitude(delta/.53f,1),Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg,.1f);
                game.Tick(.1f);
            }
            throw new InvalidOperationException("Walk target unreachable "+destination);
        }
        static void FailureCheckpoint(StringBuilder report)
        {
            var game=new GameSim();game.StartMission(0,Difficulty.Hard);
            game.Order(0,SquadOrder.Move,new Vector3(21,0,-31));
            for(int i=0;i<8000 && game.Result==SimResult.Active;i++)game.Tick(.1f);
            Check(game.Result==SimResult.Defeat,"Abandoned transport must fail");
            Check(game.LoadCheckpoint() && game.Result==SimResult.Active && game.Elapsed==0,"Checkpoint");
            report.AppendLine("Abandoned mission failed; checkpoint restored.");
        }

    }
}
#endif
