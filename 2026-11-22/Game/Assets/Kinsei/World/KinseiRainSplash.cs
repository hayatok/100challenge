using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class KinseiRainSplash
{
    readonly Mesh mesh;
    readonly Material material;
    readonly MaterialPropertyBlock properties=new MaterialPropertyBlock();
    static readonly int Age=Shader.PropertyToID("_Age");
    static readonly int Reflection=Shader.PropertyToID("_Reflection");

    public KinseiRainSplash()
    {
        var shader=Resources.Load<Shader>("KinseiWaterCrown");
        if(!shader || !shader.isSupported)return;
        material=new Material(shader);
        var vertices=new List<Vector3>();
        var motion=new List<Vector4>();
        var triangles=new List<int>();
        // Broken, low tongues of water instead of a closed luminous ring.
        for(int arc=0;arc<3;arc++) {
            for(int i=0;i<=7;i++) {
                float t=i/7f;
                float angle=arc*2.12f+t*(.82f+.13f*arc);
                var radial=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
                float peak=Mathf.Sin(t*Mathf.PI)*(.014f+.006f*Mathf.Sin(9*t+arc));
                int index=vertices.Count;
                vertices.Add(radial*.049f); motion.Add(new Vector4(0,.003f,.203f,0));
                vertices.Add(radial*.054f); motion.Add(new Vector4(0,.003f+peak,.203f,1));
                if(i==0)continue;
                triangles.Add(index-2);triangles.Add(index);triangles.Add(index-1);
                triangles.Add(index-1);triangles.Add(index);triangles.Add(index+1);
            }
        }
        // Tiny octahedra retain their profile when viewed from either side.
        for(int i=0;i<4;i++) {
            float angle=.7f+i*2.37f;
            var center=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*(.047f+i*.008f);
            float radius=.0027f+.0004f*i;
            int start=vertices.Count;
            Vector3[] offsets={Vector3.up*1.65f,Vector3.right,Vector3.forward,Vector3.left,Vector3.back,Vector3.down};
            foreach(var offset in offsets) {
                vertices.Add(center+offset*radius);
                motion.Add(new Vector4(1,.031f+i*.008f,.216f+i*.027f,offset.y));
            }
            for(int j=0;j<4;j++) {
                int a=start+1+j,b=start+1+(j+1)%4;
                triangles.Add(start);triangles.Add(a);triangles.Add(b);
                triangles.Add(start+5);triangles.Add(b);triangles.Add(a);
            }
        }
        mesh=new Mesh{name="Broken splash lip and four droplets"};
        mesh.SetVertices(vertices);mesh.SetUVs(0,motion);mesh.SetTriangles(triangles,0);
        mesh.bounds=new Bounds(Vector3.up*.035f,new Vector3(.42f,.13f,.42f));
    }

    public void Draw(Camera eye,Plane[] frustum,RenderTexture reflection,Vector4 reflectionUV,Vector4[] contacts,float time,float surface)
    {
        if(!material)return;
        properties.SetTexture(Reflection,reflection);
        properties.SetVector("_ReflectionUV",reflectionUV);
        for(int i=0;i<contacts.Length;i++) {
            Vector4 step=contacts[i];
            float age=time-step.z;
            if(step.w==0 || age<0 || age>.30f)continue;
            var at=new Vector3(step.x,surface,step.y);
            if((eye.transform.position-at).sqrMagnitude>144 ||
                !GeometryUtility.TestPlanesAABB(frustum,new Bounds(at+mesh.bounds.center,mesh.bounds.size)))continue;
            properties.SetFloat(Age,age);
            float rotation=Mathf.Repeat(step.x*137+step.y*89,360);
            Graphics.DrawMesh(mesh,Matrix4x4.TRS(at,Quaternion.Euler(0,rotation,0),Vector3.one),
                material,0,eye,0,properties,ShadowCastingMode.Off,false,null,LightProbeUsage.Off);
        }
    }
    public void Release()
    {
        if(material)Object.Destroy(material);
        if(mesh)Object.Destroy(mesh);
    }
}
