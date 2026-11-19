using UnityEngine;

namespace Evac
{
    public sealed partial class WorldGeometry
    {
        Rect shutterBounds;
        bool shutterClosed;
        public bool SetIncidentShutter(Vector3 center,bool closed)
        {
            var bounds=new Rect(center.x-1.58f,center.z-.45f,3.16f,.90f);
            if(closed==shutterClosed && (!closed || bounds==shutterBounds))return false;
            shutterClosed=closed;shutterBounds=bounds;return true;
        }
        bool CrossesShutter(Vector3 start,Vector3 end,out float enter)
        {
            enter=0;
            if(!shutterClosed || shutterBounds.Contains(new Vector2(start.x,start.z)))return false;
            float exit=1;
            return Slice(start.x,end.x-start.x,shutterBounds.xMin,shutterBounds.xMax,ref enter,ref exit) &&
                Slice(start.z,end.z-start.z,shutterBounds.yMin,shutterBounds.yMax,ref enter,ref exit);
        }
        bool ShutterDetour(Vector3 start,Vector3 goal,out Vector3 detour)
        {
            detour=start;
            if(!CrossesShutter(start,goal,out _))return false;
            float best=float.PositiveInfinity;
            for(int i=0;i<4;i++){
                var corner=new Vector3((i&1)==0?shutterBounds.xMin-.16f:shutterBounds.xMax+.16f,0,
                    (i&2)==0?shutterBounds.yMin-.16f:shutterBounds.yMax+.16f);
                if((Bounds(corner)-corner).sqrMagnitude>.001f || (corner-start).sqrMagnitude<.015f ||
                   CrossesShutter(start,corner,out _) || !Clear(start,corner,true))continue;
                float length=(corner-start).magnitude+(goal-corner).magnitude;
                if(CrossesShutter(corner,goal,out _))length+=1.1f;
                if(length<best){best=length;detour=corner;}
            }
            return !float.IsPositiveInfinity(best);
        }
    }
}
