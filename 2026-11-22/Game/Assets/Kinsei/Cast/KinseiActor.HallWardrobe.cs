using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed partial class KinseiActor
{
    // Init calls this after detailed face/garments and before MergeSurfaces.
    void ApplyHallWardrobe(string role,int variant)
    {
        if(role!="guard" || (variant!=0 && variant!=1))return;
        bool navy=variant==0;
        cloth.color=navy?new Color(.23f,.28f,.40f):new Color(.46f,.285f,.295f);
        collar.color=navy?new Color(.25f,.30f,.43f):new Color(.48f,.305f,.31f);
        var texture=Resources.Load<Texture2D>("KinseiHallWardrobe/"+(navy?"KontaniPinstripe":"UraMulberryWool"));
        foreach(var m in new[]{cloth,collar}){m.mainTexture=texture;m.SetFloat("_Glossiness",navy?.19f:.13f);m.SetFloat("_BumpScale",navy?.34f:.52f);}
        shirt.color=new Color(.83f,.79f,.67f);tie.color=navy?new Color(.16f,.17f,.235f):new Color(.29f,.075f,.095f);tie.SetFloat("_Glossiness",.35f);
        if(navy)BuildKontaniSpectacles();
        foreach(var r in body.GetComponentsInChildren<Renderer>(true))
        {
            if(r.sharedMaterial!=cloth && r.sharedMaterial!=collar)continue;
            Mesh mesh=null;var skinned=r as SkinnedMeshRenderer;
            if(skinned!=null)mesh=skinned.sharedMesh;else{var f=r.GetComponent<MeshFilter>();if(f!=null)mesh=f.sharedMesh;}
            if(mesh!=null && mesh.isReadable)HallTextileUv(mesh);
        }
    }
    Material HallMaterial(string label,Color color,float smooth){var m=Mat(label,color,smooth);extraMaterials.Add(m);return m;}
    static void HallTextileUv(Mesh mesh)
    {
        var uv=mesh.uv;if(uv.Length!=mesh.vertexCount)return;
        bool ring=mesh.vertexCount>90;float rx=mesh.bounds.extents.x,rz=mesh.bounds.extents.z;
        float circumference=Mathf.PI*(3*(rx+rz)-Mathf.Sqrt((3*rx+rz)*(rx+3*rz)));
        for(int i=0;i<uv.Length;i++)uv[i]=new Vector2(uv[i].x*(ring?circumference:.5f)/.128f,uv[i].y/1.6f/.128f);
        mesh.uv=uv;mesh.RecalculateTangents();
    }
    // Second Init hook, immediately after KinseiWardrobeBinding.Dress.
    void DressHallTailoring(string role,int variant)
    {
        if(role!="guard" || (variant!=0 && variant!=1))return;
        SkinnedMeshRenderer tailored=null;
        foreach(var candidate in GetComponentsInChildren<SkinnedMeshRenderer>())
            if(candidate.transform.parent==transform && candidate.name.StartsWith("Tailored ")){tailored=candidate;break;}
        if(tailored==null)return;
        var atlas=Resources.Load<Texture2D>("KinseiHallWardrobe/"+(variant==0?"KontaniAtlas":"UraAtlas"));
        var hallNormal=Resources.Load<Texture2D>("KinseiHallWardrobe/"+(variant==0?"KontaniNormal":"UraNormal"));
        if(hallNormal!=null)tailored.sharedMaterial.SetTexture("_BumpMap",hallNormal);
        if(atlas!=null){tailored.sharedMaterial.mainTexture=atlas;tailored.sharedMaterial.color=Color.white;tailored.sharedMaterial.SetFloat("_Glossiness",variant==0?.20f:.15f);tailored.sharedMaterial.SetFloat("_BumpScale",variant==0?.48f:.58f);}
        if(variant!=1){FitHallCuffs(tailored);return;}
        var fit=Resources.Load<TextAsset>("KinseiHallWardrobe/UraLapelFit");
        Mesh garment=tailored.sharedMesh;
        if(fit!=null && garment!=null && garment.isReadable && fit.bytes.Length==4+garment.vertexCount*12)
        {
            using(var reader=new System.IO.BinaryReader(new System.IO.MemoryStream(fit.bytes)))
            {
                int count=reader.ReadInt32();
                if(count==garment.vertexCount){var vertices=new Vector3[count];for(int i=0;i<count;i++)vertices[i]=V(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());garment.vertices=vertices;garment.RecalculateNormals();garment.RecalculateTangents();garment.RecalculateBounds();}
            }
        }
        // Real garment's breast welt is on +X, at 1.26 m in canonical rest coordinates.
        var linen=HallMaterial("浦・生成り麻の折りチーフ",new Color(.86f,.79f,.60f),.11f);linen.mainTexture=Resources.Load<Texture2D>("KinseiCast/Wool");
        HallPanel("浦・一折りのチーフ",chest,linen,new[]{V(.057f,.244f,.128f),V(.064f,.278f,.133f),V(.080f,.287f,.136f),V(.118f,.248f,.127f)},.0012f);
        HallPanel("浦・チーフの返り",chest,linen,new[]{V(.064f,.278f,.136f),V(.080f,.287f,.139f),V(.099f,.257f,.137f),V(.076f,.266f,.139f)},.0013f);
        FitHallCuffs(tailored);
    }
    #if UNITY_EDITOR
    sealed class HallCuffSeam
    {
        public SkinnedMeshRenderer hand,bridge;
        public int[] handIndices;
    }
    readonly List<HallCuffSeam> hallCuffSeams=new List<HallCuffSeam>();
    // Runtime QA probe, in millimetres. Uses the actual current bones and bindposes;
    // it does not sample a neutral pose or alter motion to make the seam agree.
    public float MeasureHallCuffSeamMillimetres()
    {
        if(hallCuffSeams.Count==0)return -1;
        float maximum=0;
        foreach(var seam in hallCuffSeams)
        {
            Mesh source=seam.hand.sharedMesh,bridge=seam.bridge.sharedMesh;
            var a=source.vertices;var b=bridge.vertices;var aw=source.boneWeights;var bw=bridge.boneWeights;
            var ab=source.bindposes;var bb=bridge.bindposes;
            for(int i=0;i<seam.handIndices.Length;i++)
            {
                int j=seam.handIndices[i];
                Vector3 p=HallSkinPoint(a[j],aw[j],seam.hand.bones,ab),q=HallSkinPoint(b[i],bw[i],seam.bridge.bones,bb);
                maximum=Mathf.Max(maximum,Vector3.Distance(p,q));
            }
        }
        return maximum*1000;
    }
    static Vector3 HallSkinPoint(Vector3 point,BoneWeight weight,Transform[] bones,Matrix4x4[] bind)
    {
        Vector3 result=Vector3.zero;
        if(weight.weight0>0)result+=(bones[weight.boneIndex0].localToWorldMatrix*bind[weight.boneIndex0]).MultiplyPoint3x4(point)*weight.weight0;
        if(weight.weight1>0)result+=(bones[weight.boneIndex1].localToWorldMatrix*bind[weight.boneIndex1]).MultiplyPoint3x4(point)*weight.weight1;
        if(weight.weight2>0)result+=(bones[weight.boneIndex2].localToWorldMatrix*bind[weight.boneIndex2]).MultiplyPoint3x4(point)*weight.weight2;
        if(weight.weight3>0)result+=(bones[weight.boneIndex3].localToWorldMatrix*bind[weight.boneIndex3]).MultiplyPoint3x4(point)*weight.weight3;
        return result;
    }
    #endif
    // Clothing-only correction. No bone, IK target, pose clock or hand route changes.
    void FitHallCuffs(SkinnedMeshRenderer tailored)
    {
        Mesh garment=tailored.sharedMesh;
        if(garment==null || !garment.isReadable)return;
        var vertices=garment.vertices;var weights=garment.boneWeights;
        int[] triangles=garment.triangles;
        // The original standalone shirt-cuff UV islands have 100 vertices each.
        // Identify by connected topology and canonical rest bounds, not pixel color.
        var parent=new int[vertices.Length];for(int i=0;i<parent.Length;i++)parent[i]=i;
        for(int i=0;i<triangles.Length;i+=3){HallUnion(parent,triangles[i],triangles[i+1]);HallUnion(parent,triangles[i],triangles[i+2]);}
        var groups=new Dictionary<int,List<int>>();
        for(int i=0;i<vertices.Length;i++){int root=HallFind(parent,i);if(!groups.ContainsKey(root))groups[root]=new List<int>();groups[root].Add(i);}
        var remove=new HashSet<int>();
        foreach(var ids in groups.Values)
        {
            if(ids.Count<80 || ids.Count>140)continue;
            var bounds=new Bounds(vertices[ids[0]],Vector3.zero);foreach(int id in ids)bounds.Encapsulate(vertices[id]);
            if(bounds.min.y>.77f && bounds.max.y<.91f && bounds.size.y>.045f && Mathf.Abs(bounds.center.x)>.14f)
                foreach(int id in ids)remove.Add(id);
        }
        var kept=new List<int>();
        for(int i=0;i<triangles.Length;i+=3)if(!remove.Contains(triangles[i])){kept.Add(triangles[i]);kept.Add(triangles[i+1]);kept.Add(triangles[i+2]);}
        for(int side=-1;side<=1;side+=2)
        {
            int forearm=side<0?3:5;
            Transform wrist=side<0?lh:rh;
            Vector3 target=transform.InverseTransformPoint(wrist.position);
            Vector3 oldCenter=Vector3.zero;int samples=0;
            for(int i=0;i<vertices.Length;i++)if(!remove.Contains(i) && HallBoneWeight(weights[i],forearm)>.8f && vertices[i].y<target.y+.065f){oldCenter+=vertices[i];samples++;}
            if(samples>0)oldCenter/=samples;else oldCenter=target;
            for(int i=0;i<vertices.Length;i++)
            {
                if(remove.Contains(i)||HallBoneWeight(weights[i],forearm)<.8f)continue;
                Vector3 point=vertices[i];float terminal=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(target.y+.012f,target.y+.115f,point.y));
                if(terminal<=0)continue;
                // Recenter and slightly taper the oversized, forward-offset hem.
                point.x=Mathf.Lerp(point.x,target.x+(point.x-oldCenter.x)*.81f,terminal);
                point.z=Mathf.Lerp(point.z,target.z+(point.z-oldCenter.z)*.81f,terminal);
                point.y+=.017f*terminal;
                vertices[i]=point;
            }
            var hand=side<0?leftHandRenderer:rightHandRenderer;
            if(hand!=null)BuildHallWristConnection(hand,side);
        }
        garment.vertices=vertices;garment.triangles=kept.ToArray();garment.RecalculateNormals();garment.RecalculateTangents();garment.RecalculateBounds();
    }
    static int HallFind(int[] parent,int i){while(parent[i]!=i){parent[i]=parent[parent[i]];i=parent[i];}return i;}
    static void HallUnion(int[] parent,int a,int b){parent[HallFind(parent,a)]=HallFind(parent,b);}
    static float HallBoneWeight(BoneWeight w,int bone){return (w.boneIndex0==bone?w.weight0:0)+(w.boneIndex1==bone?w.weight1:0)+(w.boneIndex2==bone?w.weight2:0)+(w.boneIndex3==bone?w.weight3:0);}
    static long HallEdge(int a,int b){return ((long)Mathf.Min(a,b)<<32)|(uint)Mathf.Max(a,b);}
    void BuildHallWristConnection(SkinnedMeshRenderer hand,int side)
    {
        var source=hand.sharedMesh;if(source==null || !source.isReadable)return;
        var v=source.vertices;var sourceUv=source.uv;var sourceWeights=source.boneWeights;
        // Weld UV duplicates geometrically before finding the real open wrist border.
        var welded=new Dictionary<Vector3,int>();var map=new int[v.Length];var original=new List<int>();
        for(int i=0;i<v.Length;i++){int id;if(!welded.TryGetValue(v[i],out id)){id=original.Count;welded.Add(v[i],id);original.Add(i);}map[i]=id;}
        var edges=new Dictionary<long,int>();var tris=source.triangles;
        for(int i=0;i<tris.Length;i+=3)for(int e=0;e<3;e++){long key=HallEdge(map[tris[i+e]],map[tris[i+(e+1)%3]]);if(!edges.ContainsKey(key))edges[key]=0;edges[key]++;}
        var border=new HashSet<int>();
        foreach(var edge in edges)if(edge.Value==1){int a=original[(int)(edge.Key>>32)],b=original[(int)(edge.Key&0xffffffffL)];if(v[a].y>-.025f && v[b].y>-.025f){border.Add(a);border.Add(b);}}
        if(border.Count<8){Debug.LogWarning("Hall cuff: anatomical wrist border unavailable",this);return;}
        var ids=new List<int>(border);Vector3 center=Vector3.zero;foreach(int id in ids)center+=v[id];center/=ids.Count;
        // The imported cut wrist was offset from its bone by roughly 10 mm.
        // Refit only the proximal 55 mm; palm/finger/contact geometry stays unchanged.
        for(int i=0;i<v.Length;i++)
        {
            float t=Mathf.SmoothStep(0,1,Mathf.InverseLerp(-.055f,-.004f,v[i].y));
            if(t<=0)continue;
            v[i]=V(Mathf.Lerp(v[i].x,(v[i].x-center.x)*1.12f,t),v[i].y,Mathf.Lerp(v[i].z,(v[i].z-center.z)*1.12f,t));
        }
        source.vertices=v;source.RecalculateBounds();source.RecalculateTangents();
        center=Vector3.zero;foreach(int id in ids)center+=v[id];center/=ids.Count;
        ids.Sort((a,b)=>Mathf.Atan2(v[a].z-center.z,v[a].x-center.x).CompareTo(Mathf.Atan2(v[b].z-center.z,v[b].x-center.x)));
        int n=ids.Count;var points=new List<Vector3>();var uv=new List<Vector2>();var skinWeights=new List<BoneWeight>();var indices=new List<int>();
        const int rings=5;
        for(int ring=0;ring<rings;ring++)
        {
            float t=(float)ring/(rings-1),smooth=t*t*(3-2*t);
            for(int i=0;i<n;i++)
            {
                int id=ids[i];float angle=Mathf.Atan2(v[id].z-center.z,v[id].x-center.x);
                Vector3 upper=V(Mathf.Cos(angle)*.0235f,.067f,Mathf.Sin(angle)*.0215f);
                points.Add(Vector3.Lerp(v[id],upper,smooth));uv.Add(sourceUv[id]+Vector2.up*(t*.006f));
                BoneWeight w=sourceWeights[id];float follow=HallBoneWeight(w,0)*(1-smooth);
                skinWeights.Add(new BoneWeight{boneIndex0=0,weight0=follow,boneIndex1=1,weight1=1-follow});
            }
        }
        HallGridTriangles(indices,n,rings);
        #if UNITY_EDITOR
        var connection=HallSkinnedSurface("本人の手首につながる肌",hand,realisticSkin,points,uv,skinWeights,indices);
        hallCuffSeams.Add(new HallCuffSeam{hand=hand,bridge=connection,handIndices=ids.ToArray()});
        #else
        HallSkinnedSurface("本人の手首につながる肌",hand,realisticSkin,points,uv,skinWeights,indices);
        #endif
        // A fitted shirt cuff covers the skin bridge without an empty hole or a hard
        // wrist-fixed ring. Its lower edge follows the same wrist/forearm blend.
        points.Clear();uv.Clear();skinWeights.Clear();indices.Clear();
        float[] heights={.066f,.045f,.018f,-.003f,-.003f,.018f,.045f,.066f};
        for(int ring=0;ring<heights.Length;ring++)for(int i=0;i<n;i++)
        {
            float a=(float)i/n*Mathf.PI*2,y=heights[ring];bool inner=ring>=4;
            float rx=inner?.0242f:.0295f,rz=inner?.0222f:.0270f;
            float wrinkle=1+Mathf.Cos(a*2)*.016f;
            points.Add(V(Mathf.Cos(a)*rx*wrinkle,y,Mathf.Sin(a)*rz*wrinkle));uv.Add(new Vector2((float)i/n,y*8));
            float follow=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.010f,-.045f,y));
            skinWeights.Add(new BoneWeight{boneIndex0=0,weight0=follow,boneIndex1=1,weight1=1-follow});
        }
        HallGridTriangles(indices,n,heights.Length);
        for(int i=0;i<indices.Count;i+=3){int swap=indices[i];indices[i]=indices[i+2];indices[i+2]=swap;}
        HallSkinnedSurface("量感のある連続シャツ袖口",hand,shirt,points,uv,skinWeights,indices);
    }
    static void HallGridTriangles(List<int> indices,int columns,int rows)
    {
        for(int row=0;row<rows-1;row++)for(int i=0;i<columns;i++)
        {
            int a=row*columns+i,b=row*columns+(i+1)%columns,c=a+columns,d=b+columns;
            indices.Add(a);indices.Add(c);indices.Add(b);indices.Add(b);indices.Add(c);indices.Add(d);
        }
    }
    static SkinnedMeshRenderer HallSkinnedSurface(string label,SkinnedMeshRenderer source,Material material,List<Vector3> points,List<Vector2> uv,List<BoneWeight> weights,List<int> indices)
    {
        var mesh=new Mesh{name=label};mesh.SetVertices(points);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);mesh.boneWeights=weights.ToArray();mesh.bindposes=source.sharedMesh.bindposes;mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();
        var o=new GameObject(label);o.transform.SetParent(source.transform.parent,false);
        var renderer=o.AddComponent<SkinnedMeshRenderer>();renderer.sharedMesh=mesh;renderer.sharedMaterial=material;renderer.bones=source.bones;renderer.rootBone=source.rootBone;renderer.quality=SkinQuality.Bone2;renderer.localBounds=new Bounds(Vector3.zero,Vector3.one);return renderer;
    }
    void BuildKontaniSpectacles()
    {
        var acetate=HallMaterial("紺谷・べっ甲の縁",Color.white,.46f);acetate.mainTexture=Resources.Load<Texture2D>("KinseiHallWardrobe/Tortoiseshell");
        var honey=HallMaterial("紺谷・蜜色の細いブリッジ",new Color(.61f,.365f,.115f),.62f);honey.SetFloat("_Metallic",.56f);
        // The dedicated single-pass shader has no light/specular/Standard variants.
        // If unsupported or unavailable, omit the optical surfaces, keeping rims/bridge
        // instead of risking a white opaque fallback over either iris.
        Material clear=null;
        var lensShader=Resources.Load<Shader>("KinseiHallWardrobe/ClearLens");
        if(lensShader!=null && lensShader.isSupported)
        {
            clear=new Material(lensShader);clear.name="紺谷・中心完全透過レンズ";
            clear.SetColor("_EdgeTint",new Color(.32f,.30f,.25f,.028f));
            extraMaterials.Add(clear);
        }
        else Debug.LogWarning("Kinsei clear-lens shader unavailable: optical surfaces omitted; spectacle frames retained.",this);
        float eyeY=localEyeCenter.y+.002f,eyeX=AdultEye.x;
        for(int side=-1;side<=1;side+=2)
        {
            const int n=64;var path=new Vector3[n+1];
            for(int i=0;i<=n;i++){float a=i*Mathf.PI*2/n;float x=side*eyeX+HallRound(Mathf.Cos(a))*.0235f;float y=eyeY+HallRound(Mathf.Sin(a))*.0173f;path[i]=V(x,y,.125f-Mathf.Abs(x)*.28f);}
            HallTube("紺谷・丸四角のべっ甲リム",head,acetate,path,.00165f,true);HallLens(head,clear,side*eyeX,eyeY);
            float outer=side*(eyeX+.0238f);
            HallTube("紺谷・耳へ回るテンプル",head,acetate,new[]{V(outer,eyeY+.006f,.110f),V(side*.070f,eyeY+.006f,.082f),V(side*.081f,eyeY+.002f,.024f),V(side*.083f,eyeY-.008f,-.012f),V(side*.080f,eyeY-.026f,-.025f)},.0016f,false);
            Oval("紺谷・蝶番の鋲",head,honey,V(side*.053f,eyeY+.007f,.112f),V(.0016f,.0012f,.0010f));
            if(clear!=null)Oval("紺谷・透明鼻当て",head,clear,V(side*.010f,eyeY-.006f,.117f),V(.0021f,.0050f,.0021f));
        }
        HallTube("紺谷・細い蜜色ブリッジ",head,honey,new[]{V(-.007f,eyeY+.006f,.125f),V(-.004f,eyeY+.009f,.130f),V(.004f,eyeY+.009f,.130f),V(.007f,eyeY+.006f,.125f)},.00095f,false);
    }
    static float HallRound(float value){return Mathf.Sign(value)*Mathf.Pow(Mathf.Abs(value),.73f);}
    static void HallLens(Transform parent,Material material,float cx,float cy)
    {
        if(material==null)return;
        const int n=64;var v=new Vector3[n+1];var uv=new Vector2[n+1];var t=new int[n*3];v[0]=V(cx,cy,.126f-Mathf.Abs(cx)*.28f);uv[0]=new Vector2(.5f,.5f);
        for(int i=0;i<n;i++){float a=i*Mathf.PI*2/n,x=HallRound(Mathf.Cos(a))*.0224f,y=HallRound(Mathf.Sin(a))*.0162f;v[i+1]=V(cx+x,cy+y,.124f-Mathf.Abs(cx+x)*.28f);uv[i+1]=new Vector2(x/.045f+.5f,y/.033f+.5f);t[i*3]=0;t[i*3+1]=i+1;t[i*3+2]=(i+1)%n+1;}
        var mesh=new Mesh{name="Clear bowed spectacle lens",vertices=v,uv=uv,triangles=t};mesh.RecalculateNormals();mesh.RecalculateBounds();
        var o=MeshObject("紺谷・瞳の見える透明レンズ",parent,material,mesh);var r=o.GetComponent<MeshRenderer>();r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    }
    static void HallTube(string label,Transform parent,Material material,Vector3[] path,float radius,bool closed)
    {
        const int sides=8;var v=new List<Vector3>();var uv=new List<Vector2>();var t=new List<int>();
        for(int i=0;i<path.Length;i++)
        {
            Vector3 tangent=i==0?path[1]-path[0]:i==path.Length-1?path[i]-path[i-1]:path[i+1]-path[i-1];
            if(closed && (i==0||i==path.Length-1))tangent=path[1]-path[path.Length-2];
            var across=Vector3.Cross(tangent.normalized,Vector3.forward).normalized;if(across.sqrMagnitude<.1f)across=Vector3.up;var depth=Vector3.Cross(tangent.normalized,across).normalized;
            for(int j=0;j<sides;j++){float a=j*Mathf.PI*2/sides;v.Add(path[i]+radius*(across*Mathf.Cos(a)+depth*Mathf.Sin(a)));uv.Add(new Vector2((float)i/(path.Length-1)*3,(float)j/sides));}
        }
        for(int i=0;i<path.Length-1;i++)for(int j=0;j<sides;j++){int a=i*sides+j,b=i*sides+(j+1)%sides,c=a+sides,d=b+sides;t.Add(a);t.Add(b);t.Add(c);t.Add(b);t.Add(d);t.Add(c);}
        var mesh=new Mesh{name=label};mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(t,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();MeshObject(label,parent,material,mesh);
    }
    static float HallCross(Vector3 a,Vector3 b,Vector3 c){return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);}
    static void HallPanel(string label,Transform parent,Material material,Vector3[] outline,float thickness)
    {
        var v=new List<Vector3>();var uv=new List<Vector2>();var t=new List<int>();int n=outline.Length;
        for(int layer=0;layer<2;layer++)foreach(var point in outline){v.Add(point-Vector3.forward*(layer*thickness));uv.Add(new Vector2(point.x*2,point.y*1.6f));}
        float area=0;for(int i=0;i<n;i++){int j=(i+1)%n;area+=outline[i].x*outline[j].y-outline[j].x*outline[i].y;}bool reverse=area<0;
        var polygon=new List<int>();for(int i=0;i<n;i++)polygon.Add(reverse?n-1-i:i);
        int guard=n*n;
        while(polygon.Count>2 && guard-->0)
        {
            bool clipped=false;
            for(int k=0;k<polygon.Count;k++)
            {
                int a=polygon[(k+polygon.Count-1)%polygon.Count],b=polygon[k],c=polygon[(k+1)%polygon.Count];
                if(HallCross(outline[a],outline[b],outline[c])<=0)continue;
                bool inside=false;
                foreach(int other in polygon)if(other!=a && other!=b && other!=c && HallCross(outline[a],outline[b],outline[other])>=0 && HallCross(outline[b],outline[c],outline[other])>=0 && HallCross(outline[c],outline[a],outline[other])>=0){inside=true;break;}
                if(inside)continue;
                t.Add(a);t.Add(b);t.Add(c);t.Add(n+a);t.Add(n+c);t.Add(n+b);polygon.RemoveAt(k);clipped=true;break;
            }
            if(!clipped)break;
        }
        for(int i=0;i<n;i++){int j=(i+1)%n;t.Add(i);t.Add(n+i);t.Add(j);t.Add(j);t.Add(n+i);t.Add(n+j);}
        var mesh=new Mesh{name=label};mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(t,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();MeshObject(label,parent,material,mesh);
    }
}
