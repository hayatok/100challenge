using UnityEngine;

public sealed partial class KinseiWorld
{
    Mesh paddedMesh, tubeGlass;
    Material welt, oxblood, ivoryKeys;
    Texture standby;

    static float Shaped(float t,float power) => Mathf.Sign(t)*Mathf.Pow(Mathf.Abs(t),power);

    // Superelliptic upholstery has broad faces, soft shoulders and continuous rounded ends.
    Mesh UpholsteryMesh()
    {
        const int sides=40, rows=20;
        var vertices=new Vector3[(sides+1)*(rows+1)];
        var uv=new Vector2[vertices.Length];
        var normals=new Vector3[vertices.Length];
        var indices=new int[sides*rows*6];
        int k=0;
        for(int j=0;j<=rows;j++)
        {
            float v=j/(float)rows,phi=(v-.5f)*Mathf.PI;
            float radius=Shaped(Mathf.Cos(phi),.35f);
            for(int i=0;i<=sides;i++)
            {
                float u=i/(float)sides,a=u*2*Mathf.PI;
                int n=j*(sides+1)+i;
                var p=new Vector3(radius*Shaped(Mathf.Cos(a),.35f),Shaped(Mathf.Sin(phi),.35f),radius*Shaped(Mathf.Sin(a),.35f));
                vertices[n]=p*.5f; normals[n]=new Vector3(Shaped(p.x,4.71f),Shaped(p.y,4.71f),Shaped(p.z,4.71f)).normalized;
                uv[n]=new Vector2(u,v);
                if(i==sides || j==rows) continue;
                indices[k++]=n;indices[k++]=n+sides+1;indices[k++]=n+1;
                indices[k++]=n+1;indices[k++]=n+sides+1;indices[k++]=n+sides+2;
            }
        }
        var mesh=new Mesh{name="Rolled rectangular cushions"};mesh.vertices=vertices;mesh.normals=normals;
        mesh.uv=uv;mesh.triangles=indices;mesh.RecalculateTangents();return mesh;
    }

    GameObject Surface(string name,Mesh mesh,Material finish,Transform parent,bool batch=true)
    {
        var item=new GameObject(name);item.transform.SetParent(parent,false);
        item.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=item.AddComponent<MeshRenderer>();renderer.sharedMaterial=finish;
        if(batch)fixedRenderers.Add(renderer);return item;
    }

    GameObject Cushion(string name,Vector3 position,Vector3 size,Material finish,Transform parent,bool solid=false)
    {
        if(!paddedMesh)paddedMesh=UpholsteryMesh();
        var item=Surface(name,paddedMesh,finish,parent,parent!=mirrorHinge);
        item.transform.localPosition=position;item.transform.localScale=size;
        if(solid)item.AddComponent<BoxCollider>();
        return item;
    }

    Vector3 FanPoint(float u,float radial)
    {
        float theta=Mathf.Lerp(-81,81,u)*Mathf.Deg2Rad;
        float lobe=Mathf.Sin((u*9%1)*Mathf.PI);
        float radius=radial*(.90f+.10f*lobe);
        return new Vector3(-5+Mathf.Sin(theta)*radius*2.83f,.71f+Mathf.Cos(theta)*radius*4.02f,5.76f-radial*.13f-lobe*radial*.065f);
    }

    void Scallop()
    {
        var lacquer=Mat("Gold peonies on carved lacquer","#F5D6AE",.22f,.43f);
        lacquer.mainTexture=Resources.Load<Texture2D>("Art/house-print-atlas");
        lacquer.mainTextureScale=new Vector2(.487f,.487f);lacquer.mainTextureOffset=new Vector2(.507f,.006f);
        const int n=108;
        var vertices=new Vector3[(n+1)*2];var uv=new Vector2[vertices.Length];var triangles=new int[n*6];
        for(int i=0;i<=n;i++)
        {
            float u=i/(float)n;
            for(int j=0;j<2;j++)
            {
                int k=2*i+j;vertices[k]=FanPoint(u,j==0?.009f:1f);
                uv[k]=new Vector2((vertices[k].x+7.85f)/5.7f,(vertices[k].y-.66f)/4.15f);
            }
            if(i==n)continue;
            int v=i*2,t=i*6;
            triangles[t]=v;triangles[t+1]=v+1;triangles[t+2]=v+3;
            triangles[t+3]=v;triangles[t+4]=v+3;triangles[t+5]=v+2;
            var a=FanPoint(u,1);var b=FanPoint((i+1f)/n,1);
            Rail(a+Vector3.back*.018f,b+Vector3.back*.018f,.025f,brass);
            if(i%3==1)Part("Scallop edge pearl",PrimitiveType.Sphere,a+Vector3.back*.035f,Vector3.one*.058f,glow);
        }
        var panel=new Mesh{name="Pleated fan with nine scalloped crowns"};
        panel.vertices=vertices;panel.uv=uv;panel.triangles=triangles;panel.RecalculateNormals();panel.RecalculateTangents();
        Surface("Botanical lacquer stage shell",panel,lacquer,transform);
        for(int i=0;i<=9;i++)
        {
            float u=i/9f;
            Rail(FanPoint(u,.04f)+Vector3.back*.025f,FanPoint(u,1)+Vector3.back*.025f,.018f,brass);
        }
    }

    void StageBand()
    {
        ivoryKeys=Mat("Old ivory keytops","#D6CDB4",.04f,.50f);
        var drum=Mat("Cherry pearl drum shells","#773B31",.35f,.70f);
        var kit=new Vector3(-6.95f,.5f,4.62f);
        var kick=Cylinder("Bass drum shell",kit+new Vector3(0,.4f,0),.4f,.55f,drum);
        kick.transform.localRotation=Quaternion.Euler(90,0,0);
        for(int side=-1;side<=1;side+=2)
        {
            var head=Cylinder("Bass drum hoop",kit+new Vector3(0,.4f,side*.28f),.41f,.035f,brass);
            head.transform.localRotation=kick.transform.localRotation;
            var skin=Cylinder("Bass drum hide",kit+new Vector3(0,.4f,side*.302f),.378f,.012f,side<0?cream:dark);
            skin.transform.localRotation=kick.transform.localRotation;
            var tom=kit+new Vector3(side*.25f,.91f,.03f);
            Cylinder("Tom shell",tom,.192f,.23f,drum);
            Cylinder("Tom hoop",tom+Vector3.up*.12f,.199f,.027f,brass);
            Cylinder("Tom batter head",tom+Vector3.up*.138f,.181f,.008f,ivoryKeys);
            var stand=kit+new Vector3(side*.60f,0,side*.17f);
            var cap=stand+Vector3.up*(side<0?1.26f:1.40f);
            Rail(stand,cap,.014f,brass);
            for(int f=0;f<3;f++){float a=f*Mathf.PI*2/3;Rail(stand+Vector3.up*.25f,stand+new Vector3(Mathf.Cos(a)*.22f,0,Mathf.Sin(a)*.22f),.012f,brass);}
            var cymbal=Part("Hammered ride cymbal",PrimitiveType.Sphere,cap,new Vector3(.65f,.055f,.65f),brass);cymbal.transform.Rotate(0,0,side*9);
            Part("Cymbal bell",PrimitiveType.Sphere,cap+Vector3.up*.024f,new Vector3(.13f,.065f,.13f),brass);
        }
        Cylinder("Drummer stool",kit+new Vector3(0,.50f,.61f),.22f,.08f,plum);
        var piano=new GameObject("Walnut upright piano").transform;piano.SetParent(transform,false);
        piano.localPosition=new Vector3(-3.09f,.50f,4.87f);piano.localRotation=Quaternion.Euler(0,-22,0);
        Box("Piano case",new Vector3(0,.59f,.05f),new Vector3(1.38f,1.18f,.47f),wood,false,piano);
        Cushion("Piano top lid",new Vector3(0,1.19f,.045f),new Vector3(1.46f,.065f,.54f),dark,piano);
        Box("Recessed front panel",new Vector3(0,.94f,-.202f),new Vector3(1.21f,.35f,.035f),dark,false,piano);
        Box("Keyboard rail",new Vector3(0,.69f,-.29f),new Vector3(1.42f,.12f,.29f),wood,false,piano);
        for(int i=0;i<36;i++)
        {
            float x=(i-17.5f)*.035f;
            Box("Ivory piano key",new Vector3(x,.765f,-.326f),new Vector3(.033f,.028f,.198f),ivoryKeys,false,piano);
            if(i%7!=2 && i%7!=6 && i<35)Box("Raised ebony sharp",new Vector3(x+.0175f,.791f,-.286f),new Vector3(.020f,.040f,.116f),dark,false,piano);
        }
        for(int side=-1;side<=1;side+=2)Rail(new Vector3(side*.63f,.04f,-.35f),new Vector3(side*.63f,.68f,-.35f),.035f,wood,piano);
        Box("Piano bench stretcher",new Vector3(0,.18f,-.71f),new Vector3(.48f,.34f,.23f),wood,false,piano);
        Cushion("Pianist leather bench",new Vector3(0,.39f,-.71f),new Vector3(.69f,.13f,.31f),plum,piano);
    }

    void BackBar()
    {
        var amberGlass=Mat("Amber bottle glass","#743A1B",.29f,.86f);
        var greenGlass=Mat("Bottle green","#294F41",.31f,.91f);
        for(int bay=0;bay<3;bay++)
        {
            float x=-.94f+bay*1.85f;
            Box("Recessed bar cabinet",new Vector3(x,1.37f,8.49f),new Vector3(1.81f,2.64f,.54f),wood,true);
            Cushion("Dark smoked backbar mirror",new Vector3(x,1.64f,8.192f),new Vector3(1.65f,1.64f,.065f),glass,transform);
            for(int row=0;row<2;row++)
            {
                float y=1f+row*.59f;
                Box("Glass shelf with brass lip",new Vector3(x,y,8.05f),new Vector3(1.68f,.038f,.38f),brass);
                Box("Warm concealed strip",new Vector3(x,y-.031f,8.10f),new Vector3(1.52f,.012f,.035f),glow);
                for(int i=0;i<5;i++)
                {
                    float h=.22f+((i*5+bay+row)%4)*.024f;
                    var p=new Vector3(x-.63f+i*.3f,y+.021f,8.02f+(i%2)*.055f);
                    Material bottle=(bay+row+i)%3==0?greenGlass:amberGlass;
                    Cylinder("Apéritif bottle",p+Vector3.up*h*.5f,.057f,h,bottle);
                    Part("Bottle shoulder",PrimitiveType.Sphere,p+Vector3.up*h,new Vector3(.112f,.086f,.112f),bottle);
                    Cylinder("Long bottle neck",p+Vector3.up*(h+.067f),.022f,.089f,bottle);
                    Cylinder("Sealed cork",p+Vector3.up*(h+.11f),.025f,.025f,brass);
                    BottleLabel(p+Vector3.up*h*.54f,(bay+row+i)%4,h*.47f);
                }
            }
            Box("Walnut cupboard pair",new Vector3(x,.43f,7.99f),new Vector3(1.74f,.77f,.40f),wood,true);
            for(int side=-1;side<=1;side+=2)
            {
                Box("Fielded cabinet panel",new Vector3(x+side*.43f,.44f,7.767f),new Vector3(.78f,.64f,.045f),dark);
                Cylinder("Door pull",new Vector3(x+side*.12f,.53f,7.724f),.022f,.06f,brass);
            }
            Box("Backbar worktop",new Vector3(x,.86f,7.98f),new Vector3(1.84f,.073f,.54f),dark);
        }
        Box("Terrace fascia",new Vector3(1.46f,3.03f,5.875f),new Vector3(6.8f,.32f,.08f),dark);
        for(int i=0;i<2;i++)Box("Terrace edge fillet",new Vector3(1.46f,2.91f+i*.22f,5.825f),new Vector3(6.84f,.018f,.035f),brass);
        LightAt("Bottle cabinet bounce",new Vector3(1.15f,1.94f,7.37f),new Color(.85f,.63f,.42f),1.48f,4.6f);
    }

    Mesh ScreenGlass()
    {
        const int arcs=48,rings=8;
        var vertices=new Vector3[1+rings*arcs];var uv=new Vector2[vertices.Length];
        var indices=new int[(arcs+(rings-1)*arcs*2)*3];int t=0;
        vertices[0]=new Vector3(0,0,-.042f);uv[0]=new Vector2(.5f,.5f);
        for(int j=1;j<=rings;j++)for(int i=0;i<arcs;i++)
        {
            float r=j/(float)rings,a=i*2*Mathf.PI/arcs;
            float x=Shaped(Mathf.Cos(a),.53f)*r,y=Shaped(Mathf.Sin(a),.53f)*r;
            int n=1+(j-1)*arcs+i,next=1+(j-1)*arcs+(i+1)%arcs;
            vertices[n]=new Vector3(x*.284f,y*.202f,-.042f*(1-r*r));uv[n]=new Vector2(.5f+x*.5f,.5f+y*.5f);
            if(j==1){indices[t++]=0;indices[t++]=next;indices[t++]=n;}
            else
            {
                indices[t++]=n-arcs;indices[t++]=next;indices[t++]=n;
                indices[t++]=n-arcs;indices[t++]=next-arcs;indices[t++]=next;
            }
        }
        var mesh=new Mesh{name="Crowned four-corner cathode-ray tube"};mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=indices;mesh.RecalculateNormals();mesh.RecalculateTangents();return mesh;
    }

    Camera terraceCamera;
    RenderTexture terraceImage;
    Material terraceScreen;
    float nextTerraceFrame;

    void PrepareTerraceCamera()
    {
        terraceImage=new RenderTexture(384,320,16){name="Kaji return relay",filterMode=FilterMode.Bilinear};
        var head=new GameObject("Upper booth return lens");head.transform.SetParent(transform,false);
        head.transform.localPosition=new Vector3(-.20f,4.37f,6.96f);
        head.transform.LookAt(transform.TransformPoint(new Vector3(1.14f,4.43f,7.4f)));
        terraceCamera=head.AddComponent<Camera>();terraceCamera.enabled=false;
        terraceCamera.clearFlags=CameraClearFlags.SolidColor;terraceCamera.backgroundColor=new Color(.055f,.021f,.028f);
        terraceCamera.fieldOfView=24;terraceCamera.nearClipPlane=.08f;terraceCamera.farClipPlane=12;
        terraceCamera.targetTexture=terraceImage;
    }

    void ShowPicture(Material screen,Texture image)
    {
        if(screen.mainTexture==image) return;
        screen.mainTexture=image;screen.SetTexture("_EmissionMap",image);
        screen.SetFloat("_Metallic",.04f);screen.SetFloat("_Glossiness",.63f);
        screen.EnableKeyword("_EMISSION");screen.SetColor("_EmissionColor",Color.white*.68f);
        screen.color=new Color(.62f,.65f,.61f);
    }

    void Receiver(Transform parent,Material screenFinish)
    {
        if(!oxblood)
        {
            oxblood=Mat("Oxblood Bakelite","#602626",.15f,.76f);
            standby=Resources.Load<Texture2D>("Art/sakai-broadcast");
            tubeGlass=ScreenGlass();
        }
        Cushion("Bakelite telephone body",new Vector3(0,.235f,.075f),new Vector3(.83f,.585f,.45f),oxblood,parent);
        Cushion("Pressed champagne bezel",new Vector3(-.065f,.248f,-.133f),new Vector3(.662f,.501f,.081f),brass,parent);
        Cushion("Rubber CRT mask",new Vector3(-.065f,.248f,-.165f),new Vector3(.609f,.448f,.078f),dark,parent);
        var screen=Surface("中継管面",tubeGlass,screenFinish,parent,parent!=mirrorHinge);
        screen.transform.localPosition=new Vector3(-.065f,.248f,-.203f);
        for(int i=0;i<2;i++)
        {
            var dial=Cylinder("Knurled tuning dial",new Vector3(.329f,.25f-i*.114f,-.144f),.050f,.065f,brass,false,parent);
            dial.transform.localRotation=Quaternion.Euler(90,0,0);
            Box("Dial index",new Vector3(.329f,.267f-i*.114f,-.180f),new Vector3(.009f,.032f,.004f),dark,false,parent);
        }
        for(int i=0;i<5;i++)Box("Speaker grille slots",new Vector3(.329f,.365f+i*.016f,-.119f),new Vector3(.084f,.007f,.014f),dark,false,parent);
        var dialSide=Cylinder("Articulation wheel",new Vector3(.395f,.215f,.002f),.084f,.075f,brass,false,parent);dialSide.transform.localRotation=Quaternion.Euler(0,0,90);
        for(int i=0;i<8;i++)
        {
            float a=i*2*Mathf.PI/8;
            Part("Wheel finger grip",PrimitiveType.Sphere,new Vector3(.431f,.215f+Mathf.Sin(a)*.063f,.002f+Mathf.Cos(a)*.063f),new Vector3(.016f,.018f,.018f),oxblood,false,parent);
        }
        Cushion("Swivel table foot",new Vector3(0,-.068f,.075f),new Vector3(.58f,.073f,.39f),oxblood,parent);
    }

    void Chandelier(float z)
    {
        int start=fixedRenderers.Count;
        var centre=new Vector3(0,5.70f,z);
        Rail(centre+Vector3.up*.38f,centre,.032f,brass);
        for(int tier=0;tier<3;tier++)
        {
            int count=32-tier*8;float radius=.96f-tier*.26f;
            float y=5.70f-tier*.21f;
            Cylinder("Suspended stepped canopy",new Vector3(0,y,z),radius,.060f,brass);
            Cylinder("Opaline chandelier diffuser",new Vector3(0,y-.055f,z),radius*.94f,.062f,glow);
            for(int i=0;i<count;i++)
            {
                float a=(i+tier*.5f)*Mathf.PI*2/count;
                var mount=new Vector3(Mathf.Cos(a)*radius,y-.025f,z+Mathf.Sin(a)*radius);
                float drop=.20f+(i%2)*.055f;
                var prism=Box("Fluted champagne prism",mount-Vector3.up*drop*.5f,new Vector3(.055f,drop,.055f),i%4==0?glow:ivoryKeys);
                prism.transform.localRotation=Quaternion.Euler(0,-a*Mathf.Rad2Deg,0);
            }
        }
        foreach(var material in new[]{brass,glow,ivoryKeys})
        {
            var pieces=new System.Collections.Generic.List<CombineInstance>();
            for(int i=start;i<fixedRenderers.Count;i++)
            {
                var r=fixedRenderers[i];if(r.sharedMaterial!=material)continue;
                pieces.Add(new CombineInstance{mesh=r.GetComponent<MeshFilter>().sharedMesh,transform=transform.worldToLocalMatrix*r.transform.localToWorldMatrix});r.enabled=false;
            }
            var mesh=new Mesh{name="Chandelier tier casting",indexFormat=UnityEngine.Rendering.IndexFormat.UInt32};
            mesh.CombineMeshes(pieces.ToArray());var fixture=Surface("Chandelier / "+material.name,mesh,material,transform,false);overhead.Add(fixture);
        }
        fixedRenderers.RemoveRange(start,fixedRenderers.Count-start);
    }
}
