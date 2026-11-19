using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public const int MaxWaypoints = 4;
        internal Vector3[] Waypoints(int squad) => IsReady && squad >= 0 && squad < state.squads.Length ? state.squads[squad].waypoints : null;
        internal int WaypointIndex(Unit member) => member == null ? 0 : Brain(member).waypointIndex;

        internal Vector3 WaypointGround(Vector3 point) => WalkingMap.Clamp(point);
        internal Vector3 WaypointCorner(Vector3 start,Vector3 goal) => WalkingMap.Waypoint(start,goal);

        internal bool SendWaypoints(int squad,SquadOrder final,Vector3[] points)
        {
            if(points == null || points.Length < 2 || points.Length > MaxWaypoints ||
               !IsReady || !soldiers.Exists(u => u.active && u.squad == squad))return false;
            var route = new Vector3[points.Length];
            for(int i=0;i<route.Length;i++)
            {
                if(float.IsNaN(points[i].x) || float.IsInfinity(points[i].x) || float.IsNaN(points[i].z) || float.IsInfinity(points[i].z))return false;
                route[i]=WaypointGround(points[i]);
                if(i>0 && FlatSq(route[i],route[i-1])<1)return false;
            }
            if(!Order(squad,final,route[route.Length-1]))return false;
            state.squads[squad].waypoints=route;
            return true;
        }

        void ClearWaypoints(int squad)
        {
            state.squads[squad].waypoints=null;
            foreach(var u in soldiers)if(u.squad==squad)
            {
                var actor=Brain(u);
                actor.waypointIndex=0;
                actor.hasPath=false;
            }
        }

        internal bool HaltWaypoints(int squad)
        {
            var route=Waypoints(squad);
            var member=soldiers.Find(u=>u.active && u.squad==squad);
            return route!=null && route.Length>0 && member!=null && Order(squad,SquadOrder.Guard,member.pos);
        }

        internal int TeamRejoinIndex(Unit u)
        {
            int own=WaypointIndex(u);
            var route=Waypoints(u.squad);
            if(route==null || route.Length==0)return own;
            int slowest=route.Length;
            bool other=false;
            foreach(var mate in soldiers)
            {
                if(!mate.active || mate==u || mate.squad!=u.squad)continue;
                slowest=Mathf.Min(slowest,WaypointIndex(mate));
                other=true;
            }
            return other?Mathf.Max(own,Mathf.Min(slowest,route.Length-1)):own;
        }

        void PassManualWaypoint(Unit u,ActorMemory actor)
        {
            var points=Waypoints(u.squad);
            if(points==null || points.Length==0)return;
            actor.waypointIndex=TeamRejoinIndex(u);
            if(actor.waypointIndex<points.Length && FlatSq(u.pos,points[actor.waypointIndex])<2.25f)
                ReachWaypoint(u,actor,points.Length);
        }

        bool FollowWaypoints(Unit u,ActorMemory actor,float dt)
        {
            var points=Waypoints(u.squad);
            if(points==null || actor.waypointIndex>=points.Length)return false;
            DefendWhileMoving(u,actor,OrderFor(u.squad));
            if(Walk(u,points[actor.waypointIndex],3.65f,dt))ReachWaypoint(u,actor,points.Length);
            return true;
        }

        void ReachWaypoint(Unit u,ActorMemory actor,int count)
        {
            actor.waypointIndex++;
            actor.hasPath=false;
            if(actor.waypointIndex<count)return;
            foreach(var mate in soldiers)
                if(mate.active && mate.squad==u.squad && Brain(mate).waypointIndex<count)return;
            ClearWaypoints(u.squad);
        }
    }
}
