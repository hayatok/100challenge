using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        struct FloorTriangle
        {
            public Vector3 a,b,c;
        }
        readonly Dictionary<string,List<FloorTriangle>> floorPieces = new Dictionary<string,List<FloorTriangle>>();
        readonly Dictionary<Vector2Int,List<FloorTriangle>> floorCells = new Dictionary<Vector2Int,List<FloorTriangle>>();

        void RememberActorFloor(string asset,Vector3[] corners)
        {
            if(asset.Contains("Roof") || !(asset.StartsWith("district") || asset.StartsWith("approach") ||
                asset.StartsWith("landmark") || asset.StartsWith("roomWing") || asset.StartsWith("columnRail") ||
                asset=="marketBoardingPoint"))return;
            var faces=new List<FloorTriangle>();
            for(int i=0;i<corners.Length;i+=3)
            {
                Vector3 a=corners[i],b=corners[i+1],c=corners[i+2];
                float low=Mathf.Min(a.y,Mathf.Min(b.y,c.y)),high=Mathf.Max(a.y,Mathf.Max(b.y,c.y));
                if(low<-.2f || high>.82f)continue;
                Vector3 n=Vector3.Cross(b-a,c-a);
                // Either winding occurs in the Blender exports. Reject walls and small trim.
                if(Mathf.Abs(n.y)<.016f || n.y*n.y<n.sqrMagnitude*.77f)continue;
                faces.Add(new FloorTriangle{a=a,b=b,c=c});
            }
            floorPieces[asset]=faces;
        }

        void IndexActorFloor()
        {
            floorCells.Clear();
            foreach(var piece in district.GetComponentsInChildren<MeshFilter>())
            {
                if(!piece.sharedMesh || !floorPieces.TryGetValue(piece.sharedMesh.name,out var faces))continue;
                Matrix4x4 localToWorld=piece.transform.localToWorldMatrix;
                foreach(var source in faces)
                {
                    var face=new FloorTriangle{a=localToWorld.MultiplyPoint3x4(source.a),
                        b=localToWorld.MultiplyPoint3x4(source.b),c=localToWorld.MultiplyPoint3x4(source.c)};
                    var lower=Vector3.Min(face.a,Vector3.Min(face.b,face.c));
                    var upper=Vector3.Max(face.a,Vector3.Max(face.b,face.c));
                    int x0=Mathf.Max(-9,Mathf.FloorToInt(lower.x*.5f));
                    int x1=Mathf.Min(9,Mathf.FloorToInt(upper.x*.5f));
                    int z0=Mathf.Max(-47,Mathf.FloorToInt(lower.z*.5f));
                    int z1=Mathf.Min(77,Mathf.FloorToInt(upper.z*.5f));
                    for(int z=z0;z<=z1;z++)
                        for(int x=x0;x<=x1;x++)
                        {
                            var cell=new Vector2Int(x,z);
                            if(!floorCells.TryGetValue(cell,out var list))floorCells[cell]=list=new List<FloorTriangle>();
                            list.Add(face);
                        }
                }
            }
        }

        float BodySupport(Vector3 center,Vector3 along,Vector3 across)
        {
            // Search the contact patch under both shoulders/hips. A single
            // centreline sample misses kerbs and grates under one side.
            float height=ActorFloor(center);
            for(int i=-1;i<=1;i++)
                for(int j=-1;j<=1;j++)
                    if(i!=0 || j!=0)
                        height=Mathf.Max(height,ActorFloor(center+i*along+j*across));
            return height;
        }

        float ActorFloor(Vector3 point)
        {
            var cell=new Vector2Int(Mathf.FloorToInt(point.x*.5f),Mathf.FloorToInt(point.z*.5f));
            if(!floorCells.TryGetValue(cell,out var faces))return 0;
            float height=-.2f;
            foreach(var face in faces)
            {
                Vector3 b=face.b-face.a,c=face.c-face.a,p=point-face.a;
                float determinant=b.x*c.z-b.z*c.x;
                float u=(p.x*c.z-p.z*c.x)/determinant,v=(b.x*p.z-b.z*p.x)/determinant;
                if(u>=-.00001f && v>=-.00001f && u+v<=1.00001f)
                    height=Mathf.Max(height,face.a.y+u*b.y+v*c.y);
            }
            return height>-.2f?height:0;
        }
    }
}
