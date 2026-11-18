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
        internal void MarkDutyCasualty(string name)
        {
            var person=state.units.Find(u=>u.name==name);
            Damage(person,person.maxHp,Vector3.forward);
        }
    }

    internal static class DutyVerification
    {
        static void Require(bool condition,string reason)
        {
            if(!condition)throw new InvalidOperationException(reason);
        }

        internal static void Run(StringBuilder report)
        {
            var previous=EvacStorage.TestDirectory;
            EvacStorage.TestDirectory=Path.Combine(previous,"duty-check");
            try
            {
                var game=new GameSim();
                game.StartMission(2,Difficulty.Standard);
                var original=game.Units.First(x=>x.kind==UnitKind.Soldier);
                game.Possess(original.id);game.Move(Vector3.forward,36,.24f);game.Tick(.3f);
                Require(game.Save(),"Normal save before duty");
                var position=original.pos;
                string native=EvacStorage.TestDirectory;
                byte[] suspend=File.ReadAllBytes(Path.Combine(native,"evac-suspend.json"));
                byte[] checkpoint=File.ReadAllBytes(Path.Combine(native,"evac-checkpoint.json"));

                for(int district=0;district<4;district++)
                {
                    game.StartDuty(district,Difficulty.Standard);
                    Require(game.IsDuty && game.DutyIndex==district && !game.AcceptRequest(),"Independent duty setup");
                    Require(game.SectorCount==3 && game.Units.Count(u=>u.kind==UnitKind.Soldier)==9,"Duty crews and stages");
                    Play(ref game,district);
                    Require(game.Depart() && game.Result==SimResult.Victory && !game.Next(),"Duty departure");
                    Require(game.DutyCompleted(district) && !game.IsComplete(district*2),"Separate duty success");
                    report.AppendLine("Duty "+(district+1)+": "+game.Boarded+"/"+game.Mission.population+" boarded across three stages, "+game.Elapsed.ToString("0.0")+"s.");
                }
                var resumed=new GameSim();
                Require(resumed.LoadDuty() && resumed.IsDuty && resumed.Result==SimResult.Victory,"Completed duty resume");
                for(int i=0;i<4;i++)Require(resumed.DutyCompleted(i),"Each duty keeps its completion");
                Require(resumed.CampaignRescued==0 && resumed.Unlocked==0,"No regular progress awarded");

                // Relinquish both search routes and the defense. The independent timeout/loss checkpoint is recoverable.
                resumed.StartDuty(2,Difficulty.Hard);
                foreach(int squad in new[]{0,1,2})resumed.Order(squad,SquadOrder.Move,new Vector3(-13,0,-30));
                for(int i=0;i<3000 && resumed.Result==SimResult.Active;i++)resumed.Tick(.1f);
                Require(resumed.Result==SimResult.Defeat,"Abandoned search failed");
                Require(resumed.LoadCheckpoint() && resumed.IsDuty && resumed.DutyIndex==2 && resumed.Sector==0,"Duty failure checkpoint");
                resumed.Retry();Require(resumed.IsDuty && resumed.Result==SimResult.Active && resumed.Elapsed==0,"Duty retry stays on duty");
                Require(resumed.Load() && !resumed.IsDuty && resumed.Mission.index==2 &&
                    resumed.Controlled!=null && Vector3.Distance(resumed.Controlled.pos,position)<.001f,"Campaign resumes original soldier");
                Require(suspend.SequenceEqual(File.ReadAllBytes(Path.Combine(native,"evac-suspend.json"))) &&
                    checkpoint.SequenceEqual(File.ReadAllBytes(Path.Combine(native,"evac-checkpoint.json"))),"Normal save and checkpoint stayed byte-identical");
                TestAlternateRoutes(resumed);
                report.AppendLine("Duty archive, failure, checkpoint, retry, alternative routes and byte-identical regular saves passed.");
            }
            finally { EvacStorage.TestDirectory=previous; }
        }

        static void Play(ref GameSim game,int district)
        {
            int previous=-1;
            bool restored=false;
            for(int i=0;i<3000 && game.Result==SimResult.Active && !game.CanDepart;i++)
            {
                if(previous!=game.Sector)
                {
                    previous=game.Sector;
                    game.Order(0,SquadOrder.Guard,game.ActiveGate);
                    game.Order(1,SquadOrder.Guide,game.ActiveAssembly);
                    game.Order(2,SquadOrder.Engineer,game.EngineerDestination);
                    if(district==0 && previous==0)Require(game.Build(Facility.Clinic),"Construct duty clinic");
                    if(district==1 && previous==1)game.Order(2,SquadOrder.Engineer,game.ActiveWorks);
                }
                if(!restored && previous==1 && game.Elapsed>2)
                {
                    Require(game.Save(),"Duty suspend");
                    game=new GameSim();
                    Require(game.LoadDuty() && game.DutyIndex==district && game.Sector==1,"Mid-duty restore");
                    restored=true;
                }
                game.Tick(.1f);
            }
            Require(restored && game.CanDepart,"Duty "+district+" stuck at "+game.SectorName+": "+game.Objective+", boarded="+game.Boarded+", stock="+game.Delivered);
        }

        static void TestAlternateRoutes(GameSim game)
        {
            game.StartDuty(0,Difficulty.Story);
            game.Order(2,SquadOrder.Engineer,game.ActiveCache);
            for(int i=0;i<500 && game.Sector==0;i++)game.Tick(.1f);
            Require(game.Sector==1 && game.Delivered>=1 && game.Site==0,"Medicine delivered without a clinic");

            game.MarkDutyCasualty("患者・市川");
            game.Tick(.1f);
            Require(game.Result==SimResult.Defeat && game.Boarded==0,"Named patient casualty ends that assignment");
            game.StartDuty(1,Difficulty.Story);
            game.Order(2,SquadOrder.Engineer,game.ActiveWorks);
            for(int i=0;i<500 && game.Sector==0;i++)game.Tick(.1f);
            Require(game.Sector==1,"Disabled truck opens");
            game.Order(2,SquadOrder.Engineer,game.ActiveCache);
            game.Order(1,SquadOrder.Guide,game.ActiveAssembly);
            for(int i=0;i<700 && game.Sector==1;i++)game.Tick(.1f);
            Require(game.Sector==2 && game.Delivered>=2,"Two real cargo runs opened the transfer instead of bridge repair");
            game.StartDuty(2,Difficulty.Story);
            var s=game.Units.First(u=>u.kind==UnitKind.Soldier);
            game.Possess(s.id);
            var goal=game.AlarmPoint;
            for(int i=0;i<350 && (s.pos-goal).sqrMagnitude>1;i++)
            {
                Vector3 direction=game.RouteWaypoint(s.pos,goal)-s.pos;
                game.Move(Vector3.ClampMagnitude(direction/.53f,1),0,.1f);game.Tick(.1f);
            }
            Require(game.ActivateAlarm(),"FPS calls shelter from the PA");
            game.Tick(.1f);
            Require(game.Sector==1 && game.Controlled==s,"PA resolves search without dispatching guides");
        }
    }
}
#endif
