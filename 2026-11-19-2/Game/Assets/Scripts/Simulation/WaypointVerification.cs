using System;
using System.IO;
using UnityEngine;

namespace Evac
{
#if UNITY_EDITOR
    public partial class GameSim
    {
        public static string VerifyWaypointOrders()
        {
            string previous=EvacStorage.TestDirectory;
            var folder=Path.Combine(Path.GetTempPath(),"evac-waypoints-"+Guid.NewGuid().ToString("N"));
            EvacStorage.TestDirectory=folder;
            try { return new GameSim().CheckWaypointOrders(); }
            finally
            {
                EvacStorage.TestDirectory=previous;
                if(Directory.Exists(folder))Directory.Delete(folder,true);
            }
        }

        string CheckWaypointOrders()
        {
            StartMission(0,Difficulty.Story);
            var leader=soldiers[0];
            var mate=soldiers.Find(s=>s!=leader && s.squad==leader.squad);
            var points=new[]{new Vector3(-2,0,-6),new Vector3(3,0,4),new Vector3(-2,0,12)};
            Verify(!SendWaypoints(leader.squad,SquadOrder.Guard,new[]{points[0]}),"Single point was accepted");
            Verify(SendWaypoints(leader.squad,SquadOrder.Guard,points),"Route dispatch");
            Verify(Possess(leader.id),"Possess route leader");
            mate.ammo=1;
            int beforeShots=mate.shots;
            var close=Spawn(UnitKind.Infected,Ground(mate.pos+Vector3.forward*3),"route contact",-1);
            close.hp=close.maxHp=600;
            var firingStart=mate.pos;
            Tick(.1f);
            Verify(mate.shots==beforeShots+1 && close.hp<600 && mate.reload>0 && mate.moving &&
                (mate.pos-firingStart).sqrMagnitude>0 && Waypoints(mate.squad)?.Length==3 && WaypointIndex(mate)==0,
                "Routed guard failed to acquire, fire, move and reload before first turn");
            close.active=false;
            Vector3 origin=leader.pos;
            var prev=mate.pos;
            int reached=0;
            for(int i=0;i<900 && WaypointIndex(mate)<3;i++)
            {
                Tick(.1f);
                Verify((mate.pos-prev).magnitude<.6f,"Squad member teleported");
                prev=mate.pos;
                if(WaypointIndex(mate)>reached)
                {
                    Verify((mate.pos-WaypointGround(points[reached])).sqrMagnitude<1,"Skipped a turn");
                    reached++;
                }
            }
            Verify(reached==3 && leader.pos==origin,"AI squad continued while one member was controlled");
            Verify(Save() && Load(),"Save or resume mid-route");
            Verify(Controlled!=null && Waypoints(leader.squad)?.Length==3,"Active route lost on resume");
            Release();
            for(int i=0;i<900 && Waypoints(leader.squad)!=null;i++)Tick(.1f);
            Verify(Waypoints(leader.squad)==null && OrderFor(leader.squad)==SquadOrder.Guard,"Route did not finish in final order");
            Verify(SendWaypoints(leader.squad,SquadOrder.Move,points) && SendWaypoints(leader.squad,SquadOrder.Guard,new[]{points[2],points[0]}),"Could not replace route");
            Verify(Waypoints(leader.squad).Length==2 && HaltWaypoints(leader.squad) && Waypoints(leader.squad)==null,"Replacing and halting");
            return "Waypoint orders passed. Moving guard contact and reload, three actual turns, AI companion, direct possession, save and resume, final order, replace and halt.";
        }
    }
#endif
}
