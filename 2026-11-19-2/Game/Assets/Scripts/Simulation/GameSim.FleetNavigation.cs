using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        struct ParkedBody
        {
            public Vector3 center, right, forward;
            public float width, length;
            public bool parked;

            public Vector3 ClearPoint(Vector3 p)
            {
                var delta=p-center;
                float x=Vector3.Dot(delta,right),z=Vector3.Dot(delta,forward);
                if(Mathf.Abs(x)>=width || Mathf.Abs(z)>=length)return p;
                if(width-Mathf.Abs(x)<length-Mathf.Abs(z))return p+right*((x>=0?width:-width)-x);
                return p+forward*((z>=0?length:-length)-z);
            }

            public bool Cuts(Vector3 start,Vector3 end)
            {
                var startLocal=start-center;
                var travel=end-start;
                float near=0,far=1;
                return Slab(Vector3.Dot(startLocal,right),Vector3.Dot(travel,right),width,ref near,ref far) &&
                    Slab(Vector3.Dot(startLocal,forward),Vector3.Dot(travel,forward),length,ref near,ref far);
            }

            static bool Slab(float start,float velocity,float half,ref float near,ref float far)
            {
                if(Mathf.Abs(velocity)<.00001f)return Mathf.Abs(start)<half;
                float a=(-half-start)/velocity,b=(half-start)/velocity;
                near=Mathf.Max(near,Mathf.Min(a,b));far=Mathf.Min(far,Mathf.Max(a,b));
                return near<far;
            }
        }

        readonly ParkedBody[] parkedBodies=new ParkedBody[2];
        readonly Dictionary<int,WorldGeometry> fleetWalkMaps=new Dictionary<int,WorldGeometry>();
        WorldGeometry mapSource, fleetWalkMap;
        int parkingKey=-1;
        WorldGeometry WalkingMap => FleetEnabled && fleetWalkMap!=null ? fleetWalkMap : geometry;

        void RefreshFleetBodies()
        {
            if(!FleetEnabled)return;
            for(int i=0;i<2;i++)
            {
                var bus=GetBus(i);
                var rotation=Quaternion.Euler(0,bus.heading,0);
                parkedBodies[i]=new ParkedBody {
                    center=ApproachBlocks.BusCenter(bus.position,i,bus.heading),
                    right=rotation*Vector3.right,forward=rotation*Vector3.forward,
                    width=i==0?1.77f:1.29f,length=i==0?4.67f:2.94f,parked=bus.leg==AtStop
                };
            }
            UpdateParkingMap();
        }

        void UpdateParkingMap()
        {
            if(mapSource!=geometry)
            {
                mapSource=geometry;fleetWalkMaps.Clear();parkingKey=-1;fleetWalkMap=null;
            }
            int parked=(parkedBodies[0].parked?1:0)|(parkedBodies[1].parked?2:0);
            int key=parked|(FleetShuttleStop<<2)|((state.fleet.decision==3?1:0)<<4);
            if(key==parkingKey)return;
            parkingKey=key;
            if(parked==0)fleetWalkMap=geometry;
            else if(!fleetWalkMaps.TryGetValue(key,out fleetWalkMap))
            {
                var obstacles=new List<Rect>(2);
                foreach(var body in parkedBodies)
                {
                    if(!body.parked)continue;
                    // WorldGeometry adds a 30 cm pedestrian margin around physical bounds.
                    float w=body.width-.30f,l=body.length-.30f;
                    obstacles.Add(new Rect(body.center.x-w,body.center.z-l,2*w,2*l));
                }
                fleetWalkMap=new WorldGeometry(state.index,Route,true,obstacles.ToArray());
                fleetWalkMaps[key]=fleetWalkMap;
            }
            fleetWalkMap.SetWingDoors(WingDoorMask);
            foreach(var person in state.units)Brain(person).hasPath=false;
        }

        Vector3 MoveAroundFleet(Unit u,Vector3 next)
        {
            var result=next;
            foreach(var body in parkedBodies)
            {
                if(FlatSq(body.center,u.pos)>49)continue;
                // A crossing vehicle passes first. Someone already in its swept
                // footprint steps clear instead of waiting underneath a vehicle.
                if(!body.parked && !body.Cuts(u.pos,u.pos) && body.Cuts(u.pos,next))return u.pos;
                result=body.ClearPoint(result);
            }
            return result==next?next:Ground(result);
        }
    }
}
