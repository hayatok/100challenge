using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    /// <summary>The walkable street and the solid footprints shared by both perspectives.</summary>
    public sealed partial class WorldGeometry
    {
        const float HalfWidth = 15.4f, HalfLength = 90.5f, Radius = .30f, CornerGap = .055f;
        readonly List<Solid> solids = new List<Solid>();
        readonly List<Vector3> corners = new List<Vector3>();
        readonly float[,] paths;
        readonly float[] fromStart, toGoal;
        readonly struct Solid
        {
            public readonly Rect physical, walking;
            public readonly float height;
            public Solid(float x, float z, float width, float depth, float h)
            {
                physical = new Rect(x-width/2,z-depth/2,width,depth);
                walking = new Rect(physical.xMin-Radius,physical.yMin-Radius,width+2*Radius,depth+2*Radius);
                height = h;
            }
        }

        public WorldGeometry(int missionIndex) : this(missionIndex, RoutePlan.All[Mathf.Clamp(missionIndex,0,RoutePlan.All.Length-1)]) { }

        internal WorldGeometry(int missionIndex, RoutePlan route,bool fleet=false,Rect[] parkedFleet=null)
        {
            int index = Mathf.Clamp(missionIndex, 0, RoutePlan.All.Length-1);

            InitRoomWing(index);
            var bus = VehicleOrigin(route.exit);
            Vector2[][] furniture = {
                new[] { new Vector2(-7.8f,-24),new Vector2(8.2f,22) },
                new[] { new Vector2(-8.2f,24),new Vector2(6.8f,-23) },
                new[] { new Vector2(-5.6f,-22),new Vector2(6.7f,21) },
                new[] { new Vector2(-7,24),new Vector2(7.6f,-24) }
            };
            foreach (var item in furniture[index/2])
                Add(item.x,item.y,1.48f,1.95f,1.28f);
            if (index / 2 == 2)
            {
                Add(bus.x, bus.z+13.5f, 3.10f, 67f, 2.93f);
                foreach(float z in new[]{-32f,31f})
                    for(int x=-8;x<=7;x+=3) Add(x,z,.57f,2f,1.23f);
                Add(-10.4f,-20.8f,.64f,2.62f,1.05f);
                Add(6.7f,10.5f,.64f,2.62f,1.05f);
                Add(-9.8f,5,.64f,2.62f,1.05f);
                Add(-11,20,.31f,2.6f,4.7f);
                Add(-8,20,.31f,2.6f,4.7f);
                Add(-9.5f,21.26f,3,.16f,2.6f);
            }
            else if (!fleet) Add(bus.x,bus.z,3.1f,8.75f,2.9f);
            Add(route.depot.x+1.85f,route.depot.z,2.24f,1.50f,1.6f);
            Vector3 lot = SitePosition(route.depot);
            Add(lot.x,lot.z,2.95f,2.24f,1.15f);
            var works = UtilityPosition(route.works, false);
            Add(works.x,works.z,1.67f,1.15f,1.49f);
            var cache = UtilityPosition(route.cache, true);
            Add(cache.x,cache.z,2.19f,.86f,1.64f);
            foreach(float side in new[]{-1f,1f})
                Add(route.gate.x+side*1.38f,route.gate.z,.3f,1.27f,1.3f);
            foreach(float x in new[]{-12f,12f}) Add(x,index/2==2?34.5f:39f,.57f,2.50f,5.3f);
            if(parkedFleet!=null)
                foreach(var curb in parkedFleet)Add(curb.center.x,curb.center.y,curb.width,curb.height,2.8f);
            foreach(var box in DistrictLandmarks.Solids(index))Add(box.x,box.z,box.width,box.depth,box.height);
            foreach(var box in ApproachBlocks.Solids(index)) Add(box.x,box.z,box.width,box.depth,box.height);
            AddRefugeFurniture(index);
            foreach(var solid in solids)
            {
                var r=solid.walking;
                foreach(float x in new[]{r.xMin-CornerGap,r.xMax+CornerGap})
                    foreach(float z in new[]{r.yMin-CornerGap,r.yMax+CornerGap})
                    {
                        var p=new Vector3(x,0,z);
                        if((Clamp(p)-p).sqrMagnitude<.00001f) corners.Add(p);
                    }
            }
            int n=corners.Count;
            paths=new float[n,n];fromStart=new float[n];toGoal=new float[n];
            for(int i=0;i<n;i++)
                for(int j=0;j<=i;j++)
                    paths[i,j]=paths[j,i]=Clear(corners[i],corners[j],true) ?
                        Vector3.Distance(corners[i],corners[j]) : float.PositiveInfinity;
            for(int k=0;k<n;k++)
                for(int i=0;i<n;i++)
                    for(int j=0;j<n;j++)
                        paths[i,j]=Mathf.Min(paths[i,j],paths[i,k]+paths[k,j]);
        }

        void Add(float x,float z,float width,float depth,float height) =>
            solids.Add(new Solid(x,z,width,depth,height));

        internal static Vector3 UtilityPosition(Vector3 destination, bool cargo)
        {
            float offset = cargo ? 1.96f : -1.67f;
            if (Mathf.Abs(destination.x + offset) > 14f)
                return destination + new Vector3(0,0,cargo ? 1.58f : -1.62f);
            return destination + Vector3.right * offset;
        }

        internal static Vector3 SitePosition(Vector3 depot) => depot + new Vector3(3.5f,0,2.7f);

        internal static Vector3 VehicleOrigin(Vector3 exit) =>
            exit + new Vector3(exit.x<0?-2.02f:2.02f,0,2);

        public Vector3 Clamp(Vector3 point)
        {
            point = Bounds(point);
            if(point.z>=91)return ClampWing(point);
            for (int pass=0;pass<4;pass++)
            {
                bool changed=false;
                foreach(var solid in solids)
                {
                    var r=solid.walking;
                    if(!r.Contains(new Vector2(point.x,point.z))) continue;
                    Vector3 candidate=point;
                    float closest=float.PositiveInfinity;
                    TestEdge(ref candidate,ref closest,point,new Vector3(r.xMin-.003f,0,point.z));
                    TestEdge(ref candidate,ref closest,point,new Vector3(r.xMax+.003f,0,point.z));
                    TestEdge(ref candidate,ref closest,point,new Vector3(point.x,0,r.yMin-.003f));
                    TestEdge(ref candidate,ref closest,point,new Vector3(point.x,0,r.yMax+.003f));
                    point=candidate;changed=true;
                }
                if(!changed)break;
            }
            return point;
        }

        static Vector3 Bounds(Vector3 p) => new Vector3(Mathf.Clamp(p.x,-HalfWidth,HalfWidth),0,
            Mathf.Clamp(p.z,-HalfLength,151));

        static void TestEdge(ref Vector3 candidate,ref float closest,Vector3 start,Vector3 next)
        {
            if (Mathf.Abs(next.x)>HalfWidth || Mathf.Abs(next.z)>HalfLength) return;
            float d=(next-start).sqrMagnitude;
            if(d<closest){closest=d;candidate=next;}
        }

        public Vector3 Move(Vector3 start, Vector3 desiredEnd)
        {
            start=Clamp(start);
            var end=Bounds(desiredEnd);
            if(CrossesShutter(start,end,out float enter))end=Vector3.Lerp(start,end,Mathf.Max(0,enter-.01f));
            if(Clear(start,end,true))return end;
            Vector3 x=new Vector3(end.x,0,start.z), z=new Vector3(start.x,0,end.z);
            bool moveX=Clear(start,x,true),moveZ=Clear(start,z,true);
            if(moveX && moveZ)return (x-start).sqrMagnitude>(z-start).sqrMagnitude?x:z;
            if(moveX && (x-start).sqrMagnitude>.00001f)return x;
            if(moveZ && (z-start).sqrMagnitude>.00001f)return z;
            // Approach the face even when neither full axis step fits.
            float low=0,high=1;
            for(int i=0;i<7;i++)
            {
                float t=(low+high)*.5f;
                if(Clear(start,Vector3.Lerp(start,end,t),true))low=t;else high=t;
            }
            return Vector3.Lerp(start,end,low);
        }

        public Vector3 Waypoint(Vector3 start, Vector3 destination)
        {
            var goal=Clamp(destination);
            start=Clamp(start);
            if(start.z>=91 || goal.z>=91)
            {
                var seam=new Vector3(0,0,91);
                if(start.z>=91)return WingWaypoint(start,goal.z>=91?goal:seam-Vector3.forward*.5f);
                goal=seam;
            }
            if(ShutterDetour(start,goal,out var side))return side;
            if(Clear(start,goal,true))return goal;
            int n=corners.Count;
            for(int i=0;i<n;i++)
            {
                fromStart[i]=Clear(start,corners[i],true)?Vector3.Distance(start,corners[i]):float.PositiveInfinity;
                // Remaining on the vertex itself would stall instead of rounding the corner.
                if(fromStart[i]<.035f)fromStart[i]=float.PositiveInfinity;
                toGoal[i]=Clear(corners[i],goal,true)?Vector3.Distance(corners[i],goal):float.PositiveInfinity;
            }
            float best=float.PositiveInfinity;
            var result=start;
            for(int i=0;i<n;i++)
            {
                if(fromStart[i]>=best)continue;
                for(int j=0;j<n;j++)
                {
                    float length=fromStart[i]+paths[i,j]+toGoal[j];
                    if(length>=best)continue;
                    best=length;result=corners[i];
                }
            }
            return result;
        }

        public bool LineClear(Vector3 start,Vector3 end) => Clear(start,end,false);

        public static Vector3 VehicleClearance(Vector3 point,Vector3 door,int bus,float heading)
        {
            var rotation=Quaternion.Euler(0,heading,0);
            Vector3 center=ApproachBlocks.BusCenter(door,bus,heading);
            Vector3 local=Quaternion.Inverse(rotation)*(point-center);
            float width=bus==0?1.77f:1.29f, length=bus==0?4.67f:2.94f;
            if(Mathf.Abs(local.x)>=width || Mathf.Abs(local.z)>=length) return point;
            if(width-Mathf.Abs(local.x)<length-Mathf.Abs(local.z)) local.x=(local.x>=0?1:-1)*width;
            else local.z=(local.z>=0?1:-1)*length;
            return center+rotation*local;
        }

        public bool VaultEnd(Vector3 start,Vector3 direction,out Vector3 end,out float height)
        {
            end=start;height=0;
            direction.y=0;
            if(direction.sqrMagnitude<.16f) return false;
            direction.Normalize();
            const float reach=3.6f;
            Vector3 delta=direction*reach;
            float nearest=1;
            foreach(var solid in solids)
            {
                var r=solid.physical;
                float enter=0,exit=1;
                if(!Slice(start.x,delta.x,r.xMin,r.xMax,ref enter,ref exit) ||
                   !Slice(start.z,delta.z,r.yMin,r.yMax,ref enter,ref exit) || enter>=nearest)continue;
                nearest=enter;
                height=solid.height;
                end=start+direction*(exit*reach+Radius+.19f);
            }
            if(nearest*reach>1.0f || height<.31f || height>1.32f ||
               Vector3.Distance(start,end)>reach || (end-Clamp(end)).sqrMagnitude>.001f) return false;
            // Sample the whole swept arc so a second, taller object blocks the landing.
            Vector3 previous=start+Vector3.up*.28f;
            for(int i=1;i<=8;i++)
            {
                float t=i/8f;
                Vector3 next=Vector3.Lerp(start,end,t)+Vector3.up*(.28f+4*t*(1-t)*(height+.4f));
                if(!LineClear(previous,next)) return false;
                previous=next;
            }
            return true;
        }

        bool Clear(Vector3 start,Vector3 end,bool walking)
        {
            if(Mathf.Max(start.z,end.z)>91 && !WingClear(start,end,walking))return false;
            float dx=end.x-start.x,dz=end.z-start.z;
            foreach(var solid in solids)
            {
                var r=walking?solid.walking:solid.physical;
                float enter=0,exit=1;
                if(!Slice(start.x,dx,r.xMin,r.xMax,ref enter,ref exit) ||
                   !Slice(start.z,dz,r.yMin,r.yMax,ref enter,ref exit))continue;
                if(walking || Mathf.Min(Mathf.Lerp(start.y,end.y,enter),Mathf.Lerp(start.y,end.y,exit))<=solid.height)return false;
            }
            return true;
        }

        static bool Slice(float origin,float delta,float min,float max, ref float enter,ref float exit)
        {
            if(Mathf.Abs(delta)<.000001f)return origin>=min && origin<=max;
            float a=(min-origin)/delta,b=(max-origin)/delta;
            enter=Mathf.Max(enter,Mathf.Min(a,b));
            exit=Mathf.Min(exit,Mathf.Max(a,b));
            return enter<=exit;
        }
    }
}
