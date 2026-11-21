using System.Collections.Generic;
using UnityEngine;

// Routes use elapsed game seconds and metre-scale waypoints in the connected southern district.
public sealed class KinseiDistrictPeople : MonoBehaviour
{
    sealed class Resident
    {
        public KinseiActor actor;
        public Stop[] day;
        public float duration, offset, workBlend;
        public bool working, walking;
        public Transform shoulder, elbow, wrist, head, carried;
    }
    struct Stop
    {
        public Vector3 position;
        public float dwell;
        public Vector3 facing;
        public Stop(float x,float z,float seconds=0,float yaw=0)
        {
            position=new Vector3(x,.065f,z);dwell=seconds;
            facing=Quaternion.Euler(0,yaw,0)*Vector3.forward;
        }
    }
    const float Pace=1.27f;
    readonly Resident[] locals=new Resident[6];
    readonly bool[] open={true,true,true};
    readonly List<Object> owned=new List<Object>();
    static readonly string[] Names={"葉山 澄子","兵藤 圭","村瀬 文","近所の常連・崎田","貸盤会員・五十嵐","夜勤帰りの鳥井"};
    static readonly string[] CounterLines={"赤い券、そこへ置いといて。クリームは今朝の仕込みや。","その盤、内袋も一緒にな。舞台の連中には貸しがある。","受像機の端、見てみ。堺側からもう一度合図が来る。"};
    static readonly string[] StreetLines={"針音堂に豆の空き缶を返すとこ。ご用なら歩きながら聞くわ。","今から隣に盤を届けるんや。取り置きの相談か？","調整表を照らし合わせに出たところよ。中継の話ならここで。"};
    static readonly string[] GuestLines={"澄子さんの店、奥の席がいちばん落ち着くんよ。","この一枚だけ今夜までやねん。針音堂に返したら金星へ行くわ。","夜勤明けでも送像所の試験映像だけは見て帰るんや。"};
    KinseiWorld district;
    float lastTime=float.NaN;
    public void Initialize(KinseiWorld world)
    {
        if(district || !world)return;
        district=world;
        for(int i=0;i<locals.Length;i++)
        {
            var obj=new GameObject(Names[i]);obj.transform.SetParent(transform,false);
            var resident=new Resident();locals[i]=resident;
            resident.actor=obj.AddComponent<KinseiActor>();
            resident.actor.Init("resident",new[]{0,1,4,2,7,3}[i]);
            resident.day=i<3?OwnerRoute(i):GuestRoute(i-3);
            resident.offset=i<3?0:new[]{12,42,75}[i-3];
            for(int j=0;j<resident.day.Length;j++)
            {
                var stop=resident.day[j];
                resident.duration+=stop.dwell+Vector3.Distance(stop.position,resident.day[(j+1)%resident.day.Length].position)/Pace;
            }
            var spine=obj.transform.Find("Pelvis/Spine");
            resident.head=spine.Find("Head");resident.shoulder=spine.Find("Right shoulder");
            resident.elbow=resident.shoulder.Find("Elbow");resident.wrist=resident.elbow.Find("Wrist");
            Dress(resident,i);
        }
        ResetNight();
    }

    static Stop[] OwnerRoute(int i)
    {
        float x=(i-1)*16;
        float at=x+new[]{-1.13f,-1.34f,-1.12f}[i];
        float next=i==2?0:x+16;
        // Walk around the right end of the counter, then along the open side gallery.
        return new[]{new Stop(at,-19.01f,43+i*16),new Stop(x+2.76f,-19.12f),new Stop(x+2.76f,-16.15f),
            new Stop(x+2.76f,-15.04f),new Stop(x+4.99f,-15.04f),new Stop(x+4.99f,-12.48f),
            new Stop(next-2,-12.48f,7,180),new Stop(x+4.99f,-12.48f),new Stop(x+4.99f,-15.04f),
            new Stop(x+2.76f,-15.04f),new Stop(x+2.76f,-19.12f)};
    }
    static Stop[] GuestRoute(int i)
    {
        var path=new List<Stop>();
        for(int j=0;j<3;j++)
        {
            float x=((i+j)%3-1)*16;
            float lane=-11.96f+i*.24f;
            path.Add(new Stop(x-5.10f,lane));
            path.Add(new Stop(x-5.10f,-15.04f));
            path.Add(new Stop(x-.65f,-15.04f));
            path.Add(new Stop(x-.65f,-17.34f,j==0?17:9,180));
            path.Add(new Stop(x+.72f,-17.15f));
            path.Add(new Stop(x+.72f,-15.04f));
            path.Add(new Stop(x+5.1f,-15.04f));
            path.Add(new Stop(x+5.1f,lane,2,90));
        }
        return path.ToArray();
    }

    public void ResetNight()
    {
        lastTime=float.NaN;
        if(!district)return;
        for(int i=0;i<3;i++){open[i]=true;district.SetDistrictOpen(i,true);}
        Tick(0);
    }
    public bool IsOpen(int shop)=>shop>=0&&shop<3&&open[shop];

    public void Tick(float elapsedSeconds)
    {
        if(!district || float.IsNaN(elapsedSeconds) || float.IsInfinity(elapsedSeconds) || elapsedSeconds==lastTime)return;
        bool jump=float.IsNaN(lastTime)||elapsedSeconds<lastTime||elapsedSeconds-lastTime>1;
        float dt=jump?0:elapsedSeconds-lastTime;
        lastTime=elapsedSeconds;
        for(int i=0;i<locals.Length;i++)
        {
            var person=locals[i];
            float phase=Mathf.Repeat(Mathf.Max(0,elapsedSeconds)+person.offset,person.duration);
            int step=0;
            var stop=person.day[0];
            var next=person.day[1];
            float travel=0;
            for(;step<person.day.Length;step++)
            {
                stop=person.day[step];next=person.day[(step+1)%person.day.Length];
                travel=Vector3.Distance(stop.position,next.position)/Pace;
                if(phase<stop.dwell+travel || step==person.day.Length-1)break;
                phase-=stop.dwell+travel;
            }
            bool walking=phase>=stop.dwell && travel>.001f;
            var at=walking?Vector3.Lerp(stop.position,next.position,(phase-stop.dwell)/travel):stop.position;
            at.y=at.z> -14f?0:.065f;
            var facing=walking?(next.position-stop.position).normalized:stop.facing;
            Transform root=person.actor.transform;
            root.position=at;
            var orientation=Quaternion.LookRotation(facing,Vector3.up);
            root.rotation=jump?orientation:Quaternion.RotateTowards(root.rotation,orientation,dt*235);
            person.walking=walking;
            person.working=i<3 && !walking && step==0;
            if(i<3 && open[i]!=person.working)
            {open[i]=person.working;district.SetDistrictOpen(i,open[i]);}
            person.actor.Pose(walking?"walk":"idle",walking?Pace:0);
            person.workBlend=jump?(person.working?1:0):Mathf.MoveTowards(person.workBlend,person.working?1:0,dt*3.5f);
            if(i<3 && person.workBlend>0)Work(person,i,elapsedSeconds);
        }
    }
    public void LookAtNeighbours()
    {
        if(!district || Time.timeScale<=0)return;
        // Neighbours acknowledge each other when sharing a pavement or facing across a counter.
        for(int i=0;i<locals.Length;i++)
        {
            var person=locals[i];
            if(person==null || person.working)continue;
            Transform root=person.actor.transform;
            float best=2.8f*2.8f;Resident other=null;
            foreach(var candidate in locals)
            {
                if(candidate==null || candidate==person)continue;
                Vector3 delta=candidate.actor.transform.position-root.position;
                float sq=delta.sqrMagnitude;
                if(sq>=best || sq<.04f || Vector3.Dot(delta.normalized,root.forward)<.05f)continue;
                other=candidate;best=sq;
            }
            if(other==null)continue;
            Vector3 gaze=root.InverseTransformPoint(other.actor.EyePosition)-root.InverseTransformPoint(person.actor.EyePosition);
            float yaw=Mathf.Clamp(Mathf.Atan2(gaze.x,gaze.z)*Mathf.Rad2Deg,-45,45);
            float nod=person.walking?1:3+3*Mathf.Sin((lastTime+i)*2.3f);
            person.head.localRotation=Quaternion.Slerp(person.head.localRotation,Quaternion.Euler(nod,yaw,0),.65f);
        }
    }
    // Call on the interact key. Shop -1 identifies a neighbour without a counter.
    public bool TryInteract(Vector3 player,float radius,out int shop,out string line)
    {
        shop=-1;line=null;int nearest=-1;float best=radius*radius;
        for(int i=0;i<locals.Length;i++)
        {
            if(locals[i]==null)continue;
            var p=locals[i].actor.transform.position;
            float range=(p-player).sqrMagnitude;
            if(range>=best || Physics.Linecast(player+Vector3.up*1.4f,p+Vector3.up*1.4f,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore))continue;
            // A shopkeeper can speak across the counter but not through the rear wall.
            if(i<3 && locals[i].working && (player.z< -19.89f || Mathf.Abs(player.x-(i-1)*16)>4.52f))continue;
            nearest=i;best=range;
        }
        if(nearest<0)return false;
        shop=nearest<3?nearest:-1;
        string words=nearest<3?(locals[nearest].working?CounterLines[nearest]:StreetLines[nearest]):GuestLines[nearest-3];
        line=Names[nearest]+"「"+words+"」";
        return true;
    }

    static void Work(Resident r,int shop,float clock)
    {
        // Pour a siphon, lower a tonearm, or trim the receiver using the right wrist.
        float cycle=clock*(shop==0?1.65f:shop==1?.82f:1.23f);
        float beat=(1-Mathf.Cos(cycle))*.5f;
        float lift=shop==0?13*beat:shop==1?5*beat:3*beat;
        float blend=r.workBlend;
        r.shoulder.localRotation=Quaternion.Slerp(r.shoulder.localRotation,Quaternion.Euler(-65-lift,shop==1?-18:-8,11),blend);
        r.elbow.localRotation=Quaternion.Slerp(r.elbow.localRotation,Quaternion.Euler(-38+lift,0,4),blend);
        r.wrist.localRotation=Quaternion.Slerp(r.wrist.localRotation,Quaternion.Euler(18+beat*6,0,shop==2?beat*48:beat*14),blend);
        r.head.localRotation=Quaternion.Slerp(r.head.localRotation,Quaternion.Euler(13,7+Mathf.Sin(cycle*.5f)*5,1),blend*.8f);
        if(shop==0 || shop==2)r.actor.WorkAtCounter(shop==0,cycle,blend);
    }
    Material Fabric(string name,Color color,bool grain=false)
    {
        var m=new Material(Shader.Find("Standard")){name=name,color=color};owned.Add(m);
        m.SetFloat("_Glossiness",.26f);
        if(grain){m.mainTexture=Resources.Load<Texture2D>("KinseiCast/Wool");m.mainTextureScale=new Vector2(2,2);m.SetTexture("_BumpMap",Resources.Load<Texture2D>("KinseiCast/WoolNormal"));m.SetFloat("_BumpScale",.27f);m.EnableKeyword("_NORMALMAP");}
        return m;
    }
    void Dress(Resident r,int id)
    {
        var actor=r.actor.transform;
        actor.localScale=new[]{new Vector3(.93f,.943f,.98f),new Vector3(.98f,1.035f,1),new Vector3(.90f,.974f,.94f),
            new Vector3(1.04f,.964f,1.1f),new Vector3(.94f,1,.95f),new Vector3(1.01f,1.03f,1)}[id];
        var spine=actor.Find("Pelvis/Spine");
        var pelvis=spine.parent;
        Color[] uniforms={new Color(.82f,.78f,.67f),new Color(.095f,.16f,.24f),new Color(.14f,.36f,.35f),
            new Color(.42f,.32f,.22f),new Color(.55f,.48f,.37f),new Color(.23f,.30f,.36f)};
        var cloth=Fabric(Names[id]+" working clothes",uniforms[id],true);
        var apron=Fabric("Brick linen",new Color(.53f,.17f,.10f),true);
        var bone=Fabric("Pearl and cotton",new Color(.80f,.75f,.62f));
        
        var skin=actor.GetComponentInChildren<KinseiWardrobeBinding>();
        if(skin)
        {
            // Preserve the authored trousers, hem and UVs. Replace the jacket with work clothes.
            var fitted=actor.Find("Tailored Navy suit");
            if(fitted)
            {
                var garment=fitted.GetComponent<SkinnedMeshRenderer>();
                var mesh=Instantiate(garment.sharedMesh);owned.Add(mesh);
                var v=mesh.vertices;var weights=mesh.boneWeights;var original=mesh.triangles;var pants=new List<int>();
                for(int k=0;k<original.Length;k+=3)
                {
                    bool trousers=true;
                    for(int j=0;j<3;j++) {
                        int vertex=original[k+j];int boneIndex=weights[vertex].boneIndex0;
                        if(v[vertex].y>=.95f || (boneIndex>=2 && boneIndex<=5)){trousers=false;break;}
                    }
                    if(trousers){pants.Add(original[k]);pants.Add(original[k+1]);pants.Add(original[k+2]);}
                }
                mesh.triangles=pants.ToArray();garment.sharedMesh=mesh;
            }
        }
        // Garment rings reference the same moving spine, shoulder, and elbow bones as the hands.
        bool woman=id==0||id==2;
        Seam(actor,new[]{pelvis,spine},new[]{0,0,0,1,1,1,1},
            new[]{new Vector4(0,.863f,.175f,.124f),new Vector4(0,.904f,.181f,.128f),new Vector4(0,1.012f,.157f,.111f),
            new Vector4(0,1.15f,.166f,.123f),new Vector4(0,1.30f,.188f,.132f),new Vector4(0,1.373f,.194f,.101f),
            new Vector4(0,1.442f,.066f,.061f)},cloth);
        foreach(int side in new[]{-1,1})
        {
            var shoulder=spine.Find(side<0?"Left shoulder":"Right shoulder");var elbow=shoulder.Find("Elbow");
            float sx=side*.196f;
            Seam(actor,new[]{shoulder,elbow},new[]{0,0,0,1,1,1}, new[]{new Vector4(sx,1.399f,.032f,.045f),
                new Vector4(sx,1.364f,.074f,.078f),new Vector4(sx,1.239f,.066f,.070f),
                new Vector4(sx,1.087f,.054f,.06f),new Vector4(sx,.990f,.047f,.051f),
                new Vector4(sx,woman?.875f:.848f,.041f,.044f)},cloth);
            if(woman) Seam(actor,new[]{elbow},new[]{0,0,0},new[]{new Vector4(sx,.889f,.046f,.048f),new Vector4(sx,.873f,.044f,.047f),new Vector4(sx,.836f,.036f,.040f)},bone);
        }
        if(id==0)
        {
            Seam(actor,new[]{pelvis,spine},new[]{0,0,0,1,1},new[]{new Vector4(0,.60f,.21f,.145f),new Vector4(0,.74f,.209f,.146f),
                new Vector4(0,.98f,.17f,.126f),new Vector4(0,1.03f,.168f,.12f),new Vector4(0,1.32f,.143f,.145f)},apron,.13f,.87f);
            for(int s=-1;s<=1;s+=2)Prop(spine,"Apron tape",PrimitiveType.Cube,new Vector3(s*.087f,.337f,.113f),new Vector3(.026f,.115f,.011f),apron);
        }
        if(id==1)
        {
            for(int j=0;j<9;j++)Prop(spine,"Striped jersey",PrimitiveType.Cube,new Vector3(0,.165f+j*.022f,.129f-j*.002f),new Vector3(.115f-j*.006f,.010f,.009f),bone);
            CurlHair(r.head,Fabric("Hair",new Color(.11f,.078f,.069f)));
        }
        if(id==2 || id==5)
        {
            Prop(spine,"Breast patch pocket",PrimitiveType.Cube,new Vector3(-.089f,.225f,.113f),new Vector3(.083f,.082f,.016f),cloth);
            Prop(spine,"Pocket pencil",PrimitiveType.Cube,new Vector3(-.10f,.28f,.121f),new Vector3(.008f,.054f,.008f),bone);
        }
        if(id==3 || id==5)
        {
            Prop(r.head,"Work cap",PrimitiveType.Sphere,new Vector3(0,.196f,0),new Vector3(.195f,.081f,.183f),cloth);
            Prop(r.head,"Cap peak",PrimitiveType.Sphere,new Vector3(0,.176f,.077f),new Vector3(.167f,.014f,.124f),cloth);
        }
        if(id==4)
        {
            var sleeve=Fabric("Returned record sleeve",Color.white);sleeve.mainTexture=Resources.Load<Texture2D>("KinseiDistrictArt/needle-sleeve");
            Prop(r.wrist,"Lent LP",PrimitiveType.Cube,new Vector3(.035f,-.201f,-.008f),new Vector3(.015f,.31f,.31f),sleeve);
        }
        if(id==0 || id==2)
        {
            var steel=Fabric("Brushed stainless steel",new Color(.63f,.65f,.66f));
            steel.SetFloat("_Metallic",.85f);steel.SetFloat("_Glossiness",.55f);
            var grip=new Vector3(0,-.108f,.065f);
            var angle=Quaternion.Euler(61,0,0);
            var axis=angle*Vector3.up;
            if(id==0)
            {
                r.carried=Prop(r.wrist,"Coffee spoon handle",PrimitiveType.Cylinder,grip,new Vector3(.006f,.083f,.006f),steel);
                r.carried.localRotation=angle;
                Prop(r.wrist,"Oval spoon bowl",PrimitiveType.Sphere,grip-axis*.099f,new Vector3(.026f,.043f,.006f),steel).localRotation=angle;
            }
            else
            {
                r.carried=Prop(r.wrist,"Insulated trimmer grip",PrimitiveType.Capsule,grip,new Vector3(.018f,.036f,.018f),cloth);
                r.carried.localRotation=angle;
                Prop(r.wrist,"Trimmer shaft",PrimitiveType.Cylinder,grip-axis*.061f,new Vector3(.0045f,.030f,.0045f),steel).localRotation=angle;
            }
        }
    }
    void CurlHair(Transform head,Material hair)
    {
        for(int j=0;j<19;j++)
        {
            float a=j*2.39996f;float y=(j+.5f)/19;
            float radial=Mathf.Sqrt(1-y*y);
            Prop(head,"Marcel curl",PrimitiveType.Sphere,new Vector3(.080f*radial*Mathf.Sin(a),.148f+y*.085f,.073f*radial*Mathf.Cos(a)),
                new Vector3(.052f,.040f,.046f),hair);
        }
    }
    static Transform Prop(Transform mount,string label,PrimitiveType type,Vector3 at,Vector3 size,Material material)
    {
        var go=GameObject.CreatePrimitive(type);go.name=label;
        var collider=go.GetComponent<Collider>();collider.enabled=false;Destroy(collider);
        go.transform.SetParent(mount,false);go.transform.localPosition=at;go.transform.localScale=size;
        var filter=go.GetComponent<MeshFilter>();filter.sharedMesh=Instantiate(filter.sharedMesh);
        go.GetComponent<Renderer>().sharedMaterial=material;return go.transform;
    }
    void Seam(Transform actor,Transform[] bones,int[] indices,Vector4[] rings,Material material,float from=0,float to=1)
    {
        const int seg=24;int width=seg+1;
        var points=new Vector3[rings.Length*width];var uv=new Vector2[points.Length];var weights=new BoneWeight[points.Length];
        var tri=new List<int>();
        for(int j=0;j<rings.Length;j++)
            for(int k=0;k<=seg;k++)
            {
                int n=j*width+k;
                float u=(float)k/seg;
                float angle=(Mathf.Lerp(from,to,u)-.5f)*Mathf.PI*2;
                var ring=rings[j];
                points[n]=new Vector3(ring.x+ring.z*Mathf.Sin(angle),ring.y,ring.w*Mathf.Cos(angle));
                uv[n]=new Vector2(u,(float)j/(rings.Length-1));
                bool bend=j>0 && indices[j-1]!=indices[j];
                weights[n]=new BoneWeight{boneIndex0=indices[j],weight0=bend?.62f:1,boneIndex1=bend?indices[j-1]:0,weight1=bend?.38f:0};
                if(j==0||k==0)continue;
                int b=n-width-1;bool rising=rings[j].y>rings[j-1].y;
                if(rising)tri.AddRange(new[]{b,b+1,b+width,b+1,n,b+width});
                else tri.AddRange(new[]{b,b+width,b+1,b+1,b+width,n});
            }
        var bind=new Matrix4x4[bones.Length];for(int i=0;i<bones.Length;i++)bind[i]=bones[i].worldToLocalMatrix*actor.localToWorldMatrix;
        var mesh=new Mesh{name=material.name};owned.Add(mesh);mesh.vertices=points;mesh.uv=uv;mesh.triangles=tri.ToArray();
        mesh.boneWeights=weights;mesh.bindposes=bind;mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();
        var go=new GameObject(material.name);go.transform.SetParent(actor,false);
        var renderer=go.AddComponent<SkinnedMeshRenderer>();renderer.sharedMesh=mesh;renderer.sharedMaterial=material;renderer.bones=bones;
        renderer.rootBone=actor.Find("Pelvis");renderer.localBounds=new Bounds(Vector3.zero,new Vector3(2.0f,2.5f,1.8f));
    }
    void OnDestroy(){foreach(var asset in owned)if(asset)Destroy(asset);}
}
