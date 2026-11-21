using System.Collections.Generic;
using UnityEngine;

// The MakeHuman hand has one cut at the wrist. Bridge its actual textured edge to the fixed shirt cuff.
internal sealed class KinseiWristCuff : MonoBehaviour
{
    Transform forearm,hand;
    Mesh extension;

    struct Edge
    {
        public int a,b,inside,uses;
    }

    public static void Fit(Transform wrist)
    {
        var part=wrist.Find("Anatomical hand");
        if(!part)return;
        var skin=part.GetComponent<SkinnedMeshRenderer>();
        if(!skin || !skin.sharedMesh)return;
        var turn=new GameObject("Forearm twist").transform;
        turn.SetParent(wrist.parent,false);
        turn.localPosition=wrist.localPosition+Vector3.up*.040f;
        var cuff=turn.gameObject.AddComponent<KinseiWristCuff>();
        cuff.forearm=wrist.parent;cuff.hand=wrist;cuff.UpdateTurn();
        cuff.Build(skin);
    }

    void UpdateTurn() { transform.rotation=Quaternion.Slerp(forearm.rotation,hand.rotation,.5f); }
    void LateUpdate() { UpdateTurn(); }

    void Build(SkinnedMeshRenderer skin)
    {
        Mesh source=skin.sharedMesh;
        Vector3[] pos=source.vertices,norm=source.normals;
        Vector2[] sourceUv=source.uv;
        int[] tri=source.triangles;
        // OBJ UV seams split vertices. Count geometric edges by coincident positions before testing use count.
        var ids=new Dictionary<Vector3,int>();var vertexId=new int[pos.Length];
        for(int i=0;i<pos.Length;i++) {
            if(!ids.TryGetValue(pos[i],out int id)){id=ids.Count;ids.Add(pos[i],id);}
            vertexId[i]=id;
        }
        var edges=new Dictionary<ulong,Edge>();
        for(int i=0;i<tri.Length;i+=3) for(int j=0;j<3;j++) {
            int a=tri[i+j],b=tri[i+(j+1)%3],inside=tri[i+(j+2)%3];
            uint u=(uint)vertexId[a],v=(uint)vertexId[b];
            ulong key=u<v?((ulong)u<<32)|v:((ulong)v<<32)|u;
            if(edges.TryGetValue(key,out Edge e)){e.uses++;edges[key]=e;}
            else edges.Add(key,new Edge{a=a,b=b,inside=inside,uses=1});
        }
        var rim=new List<Edge>();Vector3 center=Vector3.zero;
        foreach(Edge e in edges.Values)if(e.uses==1){rim.Add(e);center+=pos[e.a]+pos[e.b];}
        if(rim.Count==0)return;
        center/=rim.Count*2f;
        // The palmar cut moves as a rigid part of the hand. Twist belongs along the forearm.
        var handWeights=new BoneWeight[pos.Length];
        for(int i=0;i<pos.Length;i++)handWeights[i]=new BoneWeight{boneIndex0=0,weight0=1};
        source.boneWeights=handWeights;
        float[] heights={0,.021f,.032f,.040f,.052f,.069f,.088f};
        float[] width={1,1.02f,1.08f,1.19f,1.31f,1.44f,1.54f};
        var points=new List<Vector3>();var normals=new List<Vector3>();var uv=new List<Vector2>();
        var weights=new List<BoneWeight>();var faces=new List<int>();
        foreach(Edge edge in rim) {
            int start=points.Count;
            for(int k=0;k<heights.Length;k++) {
                float t=(float)k/(heights.Length-1);
                for(int side=0;side<2;side++) {
                    int n=side==0?edge.a:edge.b;
                    Vector3 radial=pos[n]-center;radial.y=0;
                    Vector3 p=radial*width[k]+center*(1-t);
                    p.y=Mathf.Lerp(pos[n].y+heights[k]-center.y,heights[k],t);
                    if(k==0)p=pos[n];
                    points.Add(p);
                    normals.Add(Vector3.Slerp(norm[n],radial.normalized,t));
                    uv.Add(Vector2.Lerp(sourceUv[n],sourceUv[edge.inside],.30f*t));
                    float w=k<=3?Mathf.SmoothStep(0,1,k/3f):Mathf.SmoothStep(0,1,(k-3)/3f);
                    weights.Add(new BoneWeight{boneIndex0=k<=3?0:1,weight0=1-w,boneIndex1=k<=3?1:2,weight1=w});
                }
                if(k==0)continue;
                int a=start+2*(k-1);
                faces.Add(a+1);faces.Add(a);faces.Add(a+2);
                faces.Add(a+1);faces.Add(a+2);faces.Add(a+3);
            }
        }
        var bones=new[]{hand,transform,forearm};
        var bind=new Matrix4x4[bones.Length];
        for(int i=0;i<bones.Length;i++)bind[i]=bones[i].worldToLocalMatrix*skin.transform.localToWorldMatrix;
        extension=new Mesh{name="Continuous anatomical wrist"};
        extension.SetVertices(points);extension.SetNormals(normals);extension.SetUVs(0,uv);extension.SetTriangles(faces,0);
        extension.boneWeights=weights.ToArray();extension.bindposes=bind;extension.RecalculateTangents();extension.RecalculateBounds();
        var go=new GameObject("Wrist beneath cotton");go.transform.SetParent(skin.transform,false);
        var render=go.AddComponent<SkinnedMeshRenderer>();render.sharedMesh=extension;render.sharedMaterial=skin.sharedMaterial;
        render.bones=bones;render.rootBone=hand;render.localBounds=skin.localBounds;render.quality=SkinQuality.Bone2;
    }
}
