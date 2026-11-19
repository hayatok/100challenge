using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed partial class WorldGeometry
    {
        static readonly List<Solid>[] roomSolids=new List<Solid>[8];
        List<Solid> room;
        int openDoors;
        public void SetWingDoors(int mask){openDoors=mask;}
        void InitRoomWing(int index)
        {
            if(roomSolids[index]==null)
            {
                var list=new List<Solid>();
                foreach(var box in RoomWingLayout.Solids(index))
                    list.Add(new Solid(box.x,box.z,box.width,box.depth,box.height));
                roomSolids[index]=list;
            }
            room=roomSolids[index];
        }

        static Solid Gate(int side)=>new Solid(side==0?-3.5f:3.5f,120,.35f,2.75f,2.5f);
        Vector3 ClampWing(Vector3 p)
        {
            for(int pass=0;pass<3;pass++)
            {
                var original=p;
                foreach(var box in room)PushOutside(ref p,box.walking);
                for(int side=0;side<2;side++)if((openDoors&(1<<side))==0)PushOutside(ref p,Gate(side).walking);
                if(p==original)break;
            }
            return p;
        }

        static void PushOutside(ref Vector3 p,Rect r)
        {
            if(!r.Contains(new Vector2(p.x,p.z)))return;
            float dx=p.x-r.center.x,dz=p.z-r.center.y;
            if(r.width*.5f-Mathf.Abs(dx)<r.height*.5f-Mathf.Abs(dz))p.x=r.center.x+(dx<0?-1:1)*(r.width*.5f+.004f);
            else p.z=r.center.y+(dz<0?-1:1)*(r.height*.5f+.004f);
        }

        static bool CutsWing(Solid s,Vector3 a,Vector3 b,bool walk)
        {
            var r=walk?s.walking:s.physical;
            float t=0,u=1;
            return Slice(a.x,b.x-a.x,r.xMin,r.xMax,ref t,ref u) && Slice(a.z,b.z-a.z,r.yMin,r.yMax,ref t,ref u)
                && (walk || Mathf.Min(Mathf.Lerp(a.y,b.y,t),Mathf.Lerp(a.y,b.y,u))<=s.height);
        }

        bool WingClear(Vector3 a,Vector3 b,bool walk)
        {
            foreach(var box in room)if(CutsWing(box,a,b,walk))return false;
            for(int i=0;i<2;i++)if((openDoors&(1<<i))==0 && CutsWing(Gate(i),a,b,walk))return false;
            return true;
        }

        // Each room has entrances on two sides. Connect visible furniture corners lazily,
        // keeping the street's larger all-pairs graph independent of interior changes.
        List<Vector3> wingNodes;
        List<int>[] wingEdges;
        int graphDoors=-1;
        float[] wingDistance;
        int[] firstNode;
        bool[] visited;
        void BuildWingGraph()
        {
            if(graphDoors==openDoors)return;
            graphDoors=openDoors;
            wingNodes=new List<Vector3>();
            foreach(var s in room)AddWingCorners(s);
            for(int i=0;i<2;i++)if((openDoors&(1<<i))==0)AddWingCorners(Gate(i));
            int n=wingNodes.Count;
            wingEdges=new List<int>[n];wingDistance=new float[n];firstNode=new int[n];visited=new bool[n];
            for(int i=0;i<n;i++){
                wingEdges[i]=new List<int>();
                for(int j=0;j<i;j++)if(WingClear(wingNodes[i],wingNodes[j],true)){
                    wingEdges[i].Add(j);wingEdges[j].Add(i);
                }
            }
        }
        void AddWingCorners(Solid s)
        {
            var r=s.walking;
            foreach(float x in new[]{r.xMin-.07f,r.xMax+.07f})
                foreach(float z in new[]{r.yMin-.07f,r.yMax+.07f}){
                    var p=new Vector3(x,0,z);
                    if(Mathf.Abs(x)<=14.35f && z>=91 && z<=150.6f && (ClampWing(p)-p).sqrMagnitude<.0001f)
                        wingNodes.Add(p);
                }
        }
        Vector3 WingWaypoint(Vector3 start,Vector3 goal)
        {
            if(WingClear(start,goal,true))return goal;
            BuildWingGraph();
            int n=wingNodes.Count;
            for(int i=0;i<n;i++){
                float d=Vector3.Distance(start,wingNodes[i]);
                wingDistance[i]=d>.025f && WingClear(start,wingNodes[i],true)?d:float.PositiveInfinity;
                firstNode[i]=i;visited[i]=false;
            }
            for(int step=0;step<n;step++){
                int k=-1;float best=float.PositiveInfinity;
                for(int i=0;i<n;i++){
                    float cost=wingDistance[i]+Vector3.Distance(wingNodes[i],goal);
                    if(!visited[i] && cost<best){best=cost;k=i;}
                }
                if(k<0)break;
                if(WingClear(wingNodes[k],goal,true))return wingNodes[firstNode[k]];
                visited[k]=true;
                foreach(var j in wingEdges[k]){
                    float cost=wingDistance[k]+Vector3.Distance(wingNodes[k],wingNodes[j]);
                    if(cost<wingDistance[j]){wingDistance[j]=cost;firstNode[j]=firstNode[k];}
                }
            }
            return start;
        }
    }
}
