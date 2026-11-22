using System;
using System.Collections.Generic;
using UnityEngine;

// For each X/Z column take the MOST SUPERIOR right-trouser surface and the opposing inferior surface.
// Only palm vertices bracketed by both count. Exclude grazing planes and triangle back-side ambiguity.
sealed class TrouserSection {
    const float step=.025f;
    readonly Dictionary<Vector2Int,List<int>> bins=new();
    readonly int[] faces,uniqueHand;
    public TrouserSection(int[] faces,Vector3[] restHand){
        this.faces=faces;
        var seen=new HashSet<Vector3>();var indices=new List<int>();
        for(int i=0;i<restHand.Length;i++)if(seen.Add(restHand[i]))indices.Add(i);
        uniqueHand=indices.ToArray();
    }
        static Vector3 Closest(Vector3 p,Vector3 a,Vector3 b,Vector3 c){
            Vector3 ab=b-a,ac=c-a,ap=p-a;
            float d1=Vector3.Dot(ab,ap),d2=Vector3.Dot(ac,ap);
            if(d1<=0&&d2<=0)return a;
            Vector3 bp=p-b;float d3=Vector3.Dot(ab,bp),d4=Vector3.Dot(ac,bp);
            if(d3>=0&&d4<=d3)return b;
            float vc=d1*d4-d3*d2;
            if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
            Vector3 cp=p-c;float d5=Vector3.Dot(ab,cp),d6=Vector3.Dot(ac,cp);
            if(d6>=0&&d5<=d6)return c;
            float vb=d5*d2-d1*d6;
            if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
            float va=d3*d6-d5*d4;
            if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/(d4-d3+d5-d6));
            float total=va+vb+vc;return total==0?a:a+ab*(vb/total)+ac*(vc/total);
        }
    public float Read(Vector3[] cloth,Vector3[] hand,Matrix4x4 handToCloth,out int count,out float normalDepth,out int occupied){
        foreach(var list in bins.Values)list.Clear();
        for(int i=0;i<faces.Length;i+=3){
            var a=cloth[faces[i]];var b=cloth[faces[i+1]];var c=cloth[faces[i+2]];
            int x0=Mathf.FloorToInt(Mathf.Min(a.x,Mathf.Min(b.x,c.x))/step),x1=Mathf.FloorToInt(Mathf.Max(a.x,Mathf.Max(b.x,c.x))/step);
            int z0=Mathf.FloorToInt(Mathf.Min(a.z,Mathf.Min(b.z,c.z))/step),z1=Mathf.FloorToInt(Mathf.Max(a.z,Mathf.Max(b.z,c.z))/step);
            for(int x=x0;x<=x1;x++)for(int z=z0;z<=z1;z++){
                var cell=new Vector2Int(x,z);if(!bins.TryGetValue(cell,out var list))bins.Add(cell,list=new List<int>());list.Add(i);
            }
        }
        float deepest=0;count=0;normalDepth=0;occupied=0;
        foreach(int v in uniqueHand){
            var p=handToCloth.MultiplyPoint3x4(hand[v]);
            var key=new Vector2Int(Mathf.FloorToInt(p.x/step),Mathf.FloorToInt(p.z/step));
            if(!bins.TryGetValue(key,out var cells))continue;
            float hi=float.NegativeInfinity,lo=float.PositiveInfinity,topY=0,bottomY=0;int above=0,below=0;
            foreach(int i in cells){
                var a=cloth[faces[i]];var b=cloth[faces[i+1]]-a;var c=cloth[faces[i+2]]-a;
                float det=b.x*c.z-b.z*c.x;if(Mathf.Abs(det)<1e-9f)continue;
                float x=p.x-a.x,z=p.z-a.z,t=(x*c.z-z*c.x)/det,u=(b.x*z-b.z*x)/det;
                if(t<0 || u<0 || t+u>1)continue;
                float at=a.y+t*b.y+u*c.y; if(at>p.y)above++;else below++;
                if(at>hi){hi=at;topY=Vector3.Cross(b,c).normalized.y;}
                if(at<lo){lo=at;bottomY=Vector3.Cross(b,c).normalized.y;}
            }
            if(hi-p.y<=0 || p.y-lo<=0 || hi-lo<.002f || topY<=.25f || bottomY>=-.05f)continue;
            count++;deepest=Mathf.Max(deepest,hi-p.y);
            if((above%2)==0 || (below%2)==0)continue;
            float near=float.PositiveInfinity,sign=1;
            // Start in the same X/Z cell then consider every trouser triangle whose AABB can beat it.
            foreach(int i in cells){
                var a=cloth[faces[i]];var b=cloth[faces[i+1]];var c=cloth[faces[i+2]];
                var dt=p-Closest(p,a,b,c);if(dt.sqrMagnitude>=near)continue;
                near=dt.sqrMagnitude;sign=Vector3.Dot(dt,Vector3.Cross(b-a,c-a));
            }
            for(int i=0;i<faces.Length;i+=3){
                var a=cloth[faces[i]];var b=cloth[faces[i+1]];var c=cloth[faces[i+2]];
                float loX=Mathf.Min(a.x,Mathf.Min(b.x,c.x)),hiX=Mathf.Max(a.x,Mathf.Max(b.x,c.x));
                float dx=Mathf.Max(0,Mathf.Max(loX-p.x,p.x-hiX));if(dx*dx>=near)continue;
                float loY=Mathf.Min(a.y,Mathf.Min(b.y,c.y)),hiY=Mathf.Max(a.y,Mathf.Max(b.y,c.y));
                float dy=Mathf.Max(0,Mathf.Max(loY-p.y,p.y-hiY));if(dx*dx+dy*dy>=near)continue;
                float loZ=Mathf.Min(a.z,Mathf.Min(b.z,c.z)),hiZ=Mathf.Max(a.z,Mathf.Max(b.z,c.z));
                float dz=Mathf.Max(0,Mathf.Max(loZ-p.z,p.z-hiZ));if(dx*dx+dy*dy+dz*dz>=near)continue;
                var dt=p-Closest(p,a,b,c);if(dt.sqrMagnitude>=near)continue;
                near=dt.sqrMagnitude;sign=Vector3.Dot(dt,Vector3.Cross(b-a,c-a));
            }
            if(sign<0){normalDepth=Mathf.Max(normalDepth,Mathf.Sqrt(near));occupied++;}
        }
        return deepest;
    }
}
