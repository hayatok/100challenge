using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        readonly List<Vector3> routeDraft=new List<Vector3>(GameSim.MaxWaypoints);
        readonly List<Vector3> routeTrace=new List<Vector3>(24);
        float traceRefresh;
        public bool EditingWaypoints { get; private set; }
        public int DraftCount => routeDraft.Count;
        public bool HasWaypoints => sim.Waypoints(SelectedSquad)?.Length>0;
        public void BeginWaypointEdit()
        {
            EndWaypointEdit();
            EditingWaypoints=true;
            choosingBeacon=false;
            sound.Signal("dial");
        }

        public void EndWaypointEdit()
        {
            EditingWaypoints=false;
            routeDraft.Clear();
            traceRefresh=0;
        }

        bool TryPlotWaypoint(Vector2 screen)
        {
            if(!EditingWaypoints)return false;
            if(routeDraft.Count<GameSim.MaxWaypoints && MapGround(screen,out var point))
            {
                var ground=sim.WaypointGround(point);
                if(routeDraft.Count==0 || (ground-routeDraft[routeDraft.Count-1]).sqrMagnitude>=1)
                {
                    routeDraft.Add(ground);
                    traceRefresh=0;
                    sound.Signal("dial");
                }
            }
            return true;
        }

        public void UndoWaypoint()
        {
            if(routeDraft.Count>0)routeDraft.RemoveAt(routeDraft.Count-1);
            traceRefresh=0;
        }

        public void SendWaypoints()
        {
            if(!sim.SendWaypoints(SelectedSquad,(SquadOrder)orderIndex,routeDraft.ToArray()))return;
            EndWaypointEdit();
            sound.Signal("dispatch");
        }

        public void HaltWaypoints()
        {
            if(sim.HaltWaypoints(SelectedSquad))sound.Signal("radio");
            EndWaypointEdit();
        }

        void WaypointMarkers()
        {
            if(Current==null)return;
            IReadOnlyList<Vector3> points=EditingWaypoints?routeDraft:sim.Waypoints(Current.squad);
            int index=EditingWaypoints?0:sim.WaypointIndex(Current);
            if(points==null || index>=points.Count)return;
            Color tint=EditingWaypoints?new Color(1,.78f,.4f):new Color(.44f,.95f,.88f);
            if(sim.Controlled==null)
            {
                if(Time.unscaledTime>=traceRefresh)
                {
                    traceRefresh=Time.unscaledTime+.85f;
                    routeTrace.Clear();
                    var start=Current.pos;
                    routeTrace.Add(start);
                    for(int i=index;i<points.Count;i++)
                    {
                        int bends=0;
                        while((start-points[i]).sqrMagnitude>.01f && bends++<24)
                        {
                            var corner=sim.WaypointCorner(start,points[i]);
                            if((corner-start).sqrMagnitude<.0001f)break;
                            routeTrace.Add(corner);
                            start=corner;
                        }
                        if((start-points[i]).sqrMagnitude>.01f)break;
                    }
                }
                for(int i=1;i<routeTrace.Count;i++)RouteSegment(routeTrace[i-1],routeTrace[i],tint);
            }
            for(int i=index;i<points.Count;i++)
            {
                string label=(i+1)+"/"+points.Count;
                if(i==points.Count-1)label+=" "+(EditingWaypoints?CurrentOrder:SquadOrderName(Current.squad));
                if(sim.Controlled!=null)
                {
                    var projected=eye.WorldToViewportPoint(points[i]+Vector3.up);
                    if(projected.z<=0 || projected.x<.08f || projected.x>.92f || projected.y<.12f || projected.y>.87f)
                    {
                        Vector3 to=points[i]-Current.pos;
                        float bearing=Mathf.DeltaAngle(Current.yaw,Mathf.Atan2(to.x,to.z)*Mathf.Rad2Deg);
                        string heading=Mathf.Abs(bearing)>140?"後方":bearing<0?"左手":"右手";
                        float height=Mathf.Clamp(Screen.height*.036f,18,32);
                        float width=height*8.8f, x=(Screen.width-width)*.5f, y=Screen.height*.28f;
                        Box(x,y,width,height,new Color(.06f,.09f,.08f,.85f));
                        worldText.fontSize=Mathf.RoundToInt(height*.62f);
                        worldText.normal.textColor=tint;
                        GUI.Label(new Rect(x,y,width,height),"班の経路 "+heading+" "+Mathf.RoundToInt(to.magnitude)+"m",worldText);
                        break;
                    }
                    label="班の経路 "+label+"　"+Mathf.RoundToInt(Vector3.Distance(Current.pos,points[i]))+"m";
                    WorldTag(points[i]+Vector3.up*1.4f,label,tint,true);
                    break;
                }
                WorldTag(points[i]+Vector3.up*.55f,label,tint,true);
            }
        }
    }
}
